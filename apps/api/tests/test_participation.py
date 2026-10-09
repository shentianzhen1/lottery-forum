from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app

client = TestClient(app)


def token_and_account(username: str) -> tuple[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    body = response.json()
    return body["token"], body["account_id"]


def grant(account_id: str, amount: int, key: str) -> None:
    app.state.services.ledger.post(
        PostRequest(
            account_id=account_id,
            direction=Direction.CREDIT,
            amount=amount,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id=key,
            idempotency_key=key,
            operator_id="system",
        )
    )


def test_entry_debits_stake_and_pays_nothing() -> None:
    token, account_id = token_and_account("player-a")
    grant(account_id, 10, "grant-a")
    response = client.post(
        "/api/v1/games/number-pick/entries",
        headers={"Authorization": f"Bearer {token}"},
        json={"numbers": [1, 2, 3], "idempotency_key": "play-a"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["stake"] == 10
    assert body["payout"] == 0
    assert body["balance"] == 0


def test_repeat_entry_does_not_debit_twice() -> None:
    token, account_id = token_and_account("player-b")
    grant(account_id, 20, "grant-b")
    payload = {"numbers": [4, 5, 6], "idempotency_key": "play-b"}
    headers = {"Authorization": f"Bearer {token}"}
    first = client.post("/api/v1/games/number-pick/entries", headers=headers, json=payload)
    second = client.post("/api/v1/games/number-pick/entries", headers=headers, json=payload)
    assert first.json()["entry_id"] == second.json()["entry_id"]
    assert second.json()["balance"] == 10


def test_entry_requires_points_and_login() -> None:
    assert client.post("/api/v1/games/number-pick/entries", json={"numbers": [1, 2, 3]}).status_code == 401
    token, _account_id = token_and_account("player-c")
    response = client.post(
        "/api/v1/games/number-pick/entries",
        headers={"Authorization": f"Bearer {token}"},
        json={"numbers": [1, 2, 3], "idempotency_key": "play-c"},
    )
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "INSUFFICIENT_POINTS"
