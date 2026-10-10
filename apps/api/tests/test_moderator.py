from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app

client = TestClient(app)


def token_for(username: str, points: int = 0) -> tuple[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    token = response.json()["token"]
    account_id = response.json()["account_id"]
    if points:
        app.state.services.ledger.post(
            PostRequest(
                account_id=account_id,
                direction=Direction.CREDIT,
                amount=points,
                reason=Reason.OPENING_GRANT,
                reference_type="system",
                reference_id=f"grant-{username}",
                idempotency_key=f"grant-{username}",
                operator_id="system",
            )
        )
    return token, account_id


def test_default_threshold_is_10000() -> None:
    assert client.get("/api/v1/moderator/settings").json() == {"threshold": 10000}


def test_below_threshold_does_not_open_or_freeze() -> None:
    token, account_id = token_for("mod-low", 9800)
    response = client.post(
        "/api/v1/moderator/boards",
        headers={"Authorization": f"Bearer {token}"},
        json={"lottery_id": "fujian-31"},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INSUFFICIENT_POINTS"
    assert app.state.services.ledger.frozen(account_id) == 0


def test_qualified_account_opens_without_approval_and_freezes_threshold() -> None:
    token, account_id = token_for("mod-ok", 10000)
    response = client.post(
        "/api/v1/moderator/boards",
        headers={"Authorization": f"Bearer {token}"},
        json={"lottery_id": "fujian-31"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["approval"] == "not_required"
    assert body["payout_formula"] == "unset"
    assert app.state.services.ledger.balance(account_id) == 10100
    assert app.state.services.ledger.frozen(account_id) == 10000
    assert app.state.services.ledger.available(account_id) == 100
    again = client.post(
        "/api/v1/moderator/boards",
        headers={"Authorization": f"Bearer {token}"},
        json={"lottery_id": "fujian-31"},
    )
    assert again.json()["board_id"] == body["board_id"]
    assert app.state.services.ledger.frozen(account_id) == 10000
