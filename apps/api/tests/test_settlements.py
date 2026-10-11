from fastapi.testclient import TestClient

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


def advance_to_settling(token: str, lottery_id: str = "demo-digit") -> str:
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": lottery_id, "code": "settle-demo"},
    )
    assert created.status_code == 200
    round_id = created.json()["round_id"]
    assert client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token)).status_code == 200
    assert client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token)).status_code == 200
    assert client.post(f"/api/v1/rounds/{round_id}/draw", headers=auth(token)).status_code == 200
    settling = client.post(f"/api/v1/rounds/{round_id}/settling", headers=auth(token))
    assert settling.status_code == 200
    assert settling.json()["status"] == "SETTLING"
    return round_id


def place_bet_on_open(token: str, round_id: str, key: str) -> str:
    # round must still be OPEN when placing
    response = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json={
            "idempotency_key": key,
            "round_id": round_id,
            "play_id": "number-pick",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3],
        },
    )
    assert response.status_code == 200
    return response.json()["bet_id"]


def open_then_bet_then_settling(token: str) -> tuple[str, str]:
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "demo-digit", "code": "settle-bet"},
    )
    round_id = created.json()["round_id"]
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    bet_id = place_bet_on_open(token, round_id, key="settle-key-1")
    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    client.post(f"/api/v1/rounds/{round_id}/draw", headers=auth(token))
    client.post(f"/api/v1/rounds/{round_id}/settling", headers=auth(token))
    return round_id, bet_id


def test_record_win_loss_void_without_balance_change() -> None:
    token, _ = token_and_account("settle-happy")
    round_id, bet_id = open_then_bet_then_settling(token)

    before = client.get("/api/v1/points/balance", headers=auth(token)).json()
    assert before["balance"] == 100
    assert before["frozen"] == 10
    assert before["available"] == 90

    recorded = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "WIN"}]},
    )
    assert recorded.status_code == 200
    body = recorded.json()
    assert body["round_id"] == round_id
    assert len(body["settlements"]) == 1
    assert body["settlements"][0]["bet_id"] == bet_id
    assert body["settlements"][0]["result"] == "WIN"
    assert "不派奖" in body["message"]

    after = client.get("/api/v1/points/balance", headers=auth(token)).json()
    assert after["balance"] == before["balance"]
    assert after["frozen"] == before["frozen"]
    assert after["available"] == before["available"]

    # bet stays ACCEPTED — not advanced to SETTLED
    bet = client.get(f"/api/v1/bets/{bet_id}", headers=auth(token))
    assert bet.status_code == 200
    assert bet.json()["status"] == "ACCEPTED"

    listed = client.get(f"/api/v1/settlements/{round_id}", headers=auth(token))
    assert listed.status_code == 200
    assert len(listed.json()["settlements"]) == 1


def test_idempotent_same_result_conflict_on_different() -> None:
    token, _ = token_and_account("settle-idem")
    round_id, bet_id = open_then_bet_then_settling(token)

    first = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "LOSS"}]},
    )
    assert first.status_code == 200
    settlement_id = first.json()["settlements"][0]["settlement_id"]

    again = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "LOSS"}]},
    )
    assert again.status_code == 200
    assert again.json()["settlements"][0]["settlement_id"] == settlement_id

    conflict = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "VOID"}]},
    )
    assert conflict.status_code == 400
    assert conflict.json()["detail"]["code"] == "SETTLEMENT_CONFLICT"


def test_reject_when_round_not_settling() -> None:
    token, _ = token_and_account("settle-early")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "demo-digit"},
    )
    round_id = created.json()["round_id"]
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    bet_id = place_bet_on_open(token, round_id, key="early-1")
    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))

    on_closed = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "VOID"}]},
    )
    assert on_closed.status_code == 400
    assert on_closed.json()["detail"]["code"] == "ROUND_NOT_SETTLING"

    client.post(f"/api/v1/rounds/{round_id}/draw", headers=auth(token))
    on_drawn = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "VOID"}]},
    )
    assert on_drawn.status_code == 400
    assert on_drawn.json()["detail"]["code"] == "ROUND_NOT_SETTLING"


def test_reject_invalid_result_and_missing_bet() -> None:
    token, _ = token_and_account("settle-bad")
    round_id = advance_to_settling(token)

    bad = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": "x", "result": "PUSH"}]},
    )
    assert bad.status_code == 400
    assert bad.json()["detail"]["code"] == "INVALID_RESULT"

    missing = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": "does-not-exist", "result": "VOID"}]},
    )
    assert missing.status_code == 404
    assert missing.json()["detail"]["code"] == "BET_NOT_FOUND"


def test_unauthorized_without_token() -> None:
    assert client.post("/api/v1/settlements/r1", json={"results": []}).status_code == 401
    assert client.get("/api/v1/settlements/r1").status_code == 401


def test_void_result_ok() -> None:
    token, _ = token_and_account("settle-void")
    round_id, bet_id = open_then_bet_then_settling(token)
    response = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(token),
        json={"results": [{"bet_id": bet_id, "result": "VOID"}]},
    )
    assert response.status_code == 200
    assert response.json()["settlements"][0]["result"] == "VOID"
