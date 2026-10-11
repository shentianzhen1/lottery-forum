from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app

client = TestClient(app)


def token_and_account(username: str) -> tuple[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    assert response.status_code == 200
    body = response.json()
    return body["token"], body["account_id"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def open_round(token: str, lottery_id: str = "demo-digit") -> str:
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": lottery_id, "code": "bet-demo"},
    )
    assert created.status_code == 200
    round_id = created.json()["round_id"]
    opened = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert opened.status_code == 200
    assert opened.json()["status"] == "OPEN"
    return round_id


def bet_payload(round_id: str, key: str = "bet-1", **extra: object) -> dict[str, object]:
    body: dict[str, object] = {
        "idempotency_key": key,
        "round_id": round_id,
        "play_id": "number-pick",
        "rule_version": "0.1.0",
        "numbers": [1, 2, 3],
    }
    body.update(extra)
    return body


def drain(account_id: str, amount: int, key: str) -> None:
    app.state.services.ledger.post(
        PostRequest(
            account_id=account_id,
            direction=Direction.DEBIT,
            amount=amount,
            reason=Reason.GAME_SETTLEMENT,
            reference_type="test",
            reference_id=key,
            idempotency_key=key,
            operator_id="system",
        )
    )


def test_happy_path_on_open_round() -> None:
    token, account_id = token_and_account("bet-happy")
    round_id = open_round(token)
    response = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id))
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ACCEPTED"
    assert body["play_id"] == "number-pick"
    assert body["round_id"] == round_id
    assert body["stake"] == 10
    assert body["hold_id"]
    assert body["odds_snapshot"] == {"status": "unset"}
    assert body["selection"] == {"numbers": [1, 2, 3]}
    assert body["message"] == "投注已受理（积分已冻结占位，暂不派奖）"
    balance = client.get("/api/v1/points/balance", headers=auth(token))
    assert balance.status_code == 200
    assert balance.json()["balance"] == 100
    assert balance.json()["frozen"] == 10
    assert balance.json()["available"] == 90
    del account_id


def test_round_closed_on_closed_and_upcoming() -> None:
    token, _ = token_and_account("bet-closed")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "demo-digit"},
    ).json()
    round_id = created["round_id"]
    # UPCOMING
    upcoming = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id, key="up"))
    assert upcoming.status_code == 400
    assert upcoming.json()["detail"]["code"] == "ROUND_CLOSED"
    assert upcoming.json()["detail"]["message"] == "当期已截止，无法投注"

    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    closed = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id, key="cl"))
    assert closed.status_code == 400
    assert closed.json()["detail"]["code"] == "ROUND_CLOSED"


def test_validation_fail() -> None:
    token, _ = token_and_account("bet-invalid")
    round_id = open_round(token)
    response = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json=bet_payload(round_id, numbers=[1, 1, 1]),
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_SELECTION"
    assert response.json()["detail"]["message"] == "选号未通过校验"
    balance = client.get("/api/v1/points/balance", headers=auth(token)).json()
    assert balance["frozen"] == 0


def test_insufficient_points() -> None:
    token, account_id = token_and_account("bet-poor")
    drain(account_id, 100, "drain-bet-poor")
    round_id = open_round(token)
    response = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id))
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INSUFFICIENT_POINTS"
    assert response.json()["detail"]["message"] == "积分不足"


def test_idempotency_returns_original_without_double_freeze() -> None:
    token, _ = token_and_account("bet-idem")
    round_id = open_round(token)
    payload = bet_payload(round_id, key="same-key")
    first = client.post("/api/v1/bets", headers=auth(token), json=payload)
    second = client.post("/api/v1/bets", headers=auth(token), json=payload)
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["bet_id"] == second.json()["bet_id"]
    assert second.json()["message"] == "已提交过，返回原投注"
    balance = client.get("/api/v1/points/balance", headers=auth(token)).json()
    assert balance["frozen"] == 10
    assert balance["available"] == 90


def test_get_by_id() -> None:
    token, _ = token_and_account("bet-get")
    round_id = open_round(token)
    placed = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id, key="get-1"))
    bet_id = placed.json()["bet_id"]
    got = client.get(f"/api/v1/bets/{bet_id}", headers=auth(token))
    assert got.status_code == 200
    assert got.json()["bet_id"] == bet_id
    assert got.json()["status"] == "ACCEPTED"
    missing = client.get("/api/v1/bets/does-not-exist", headers=auth(token))
    assert missing.status_code == 404
    assert missing.json()["detail"]["code"] == "BET_NOT_FOUND"


def test_unauthorized_and_no_cancel() -> None:
    assert client.post("/api/v1/bets", json=bet_payload("x")).status_code == 401
    assert client.get("/api/v1/bets/x").status_code == 401
    token, _ = token_and_account("bet-nocancel")
    round_id = open_round(token)
    bet_id = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json=bet_payload(round_id, key="nc"),
    ).json()["bet_id"]
    cancel = client.post(f"/api/v1/bets/{bet_id}/cancel", headers=auth(token))
    assert cancel.status_code == 404


def test_stake_disabled_play_rejected() -> None:
    token, _ = token_and_account("bet-fujian")
    round_id = open_round(token, lottery_id="fujian-31")
    response = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json={
            "idempotency_key": "fj-1",
            "round_id": round_id,
            "play_id": "fujian-31",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3, 4, 5, 6, 7],
        },
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "STAKE_DISABLED"
