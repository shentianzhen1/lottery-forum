from fastapi.testclient import TestClient

from app.main import app
from tests.test_bets import admin_token, auth, bet_payload, open_round, token_and_account

client = TestClient(app)

CONTRACT_FIELDS = {"bet_id", "play_id", "numbers", "stake", "status"}


def available(token: str) -> int:
    body = client.get("/api/v1/points/balance", headers=auth(token)).json()
    return int(body["available"])


def place(token: str, round_id: str, key: str) -> dict[str, object]:
    response = client.post("/api/v1/bets", headers=auth(token), json=bet_payload(round_id, key=key))
    assert response.status_code == 200
    return response.json()


def test_cancel_releases_hold_and_returns_contract_fields() -> None:
    token, _ = token_and_account("cancel-ok")
    round_id = open_round(token)
    before = available(token)
    bet = place(token, round_id, "c1")
    assert available(token) == before - 10
    response = client.post(f"/api/v1/bets/{bet['bet_id']}/cancel", headers=auth(token))
    assert response.status_code == 200
    body = response.json()
    assert CONTRACT_FIELDS <= body.keys()
    assert body["status"] == "CANCELLED"
    assert body["bet_id"] == bet["bet_id"]
    assert body["play_id"] == "number-pick"
    assert body["numbers"] == [1, 2, 3]
    assert body["stake"] == 10
    assert body["message"] == "投注已取消，积分已解冻"
    assert available(token) == before
    assert client.get(f"/api/v1/bets/{bet['bet_id']}", headers=auth(token)).json()["status"] == "CANCELLED"


def test_cancel_twice_blocked_no_double_release() -> None:
    token, _ = token_and_account("cancel-twice")
    round_id = open_round(token)
    before = available(token)
    bet = place(token, round_id, "c2")
    assert client.post(f"/api/v1/bets/{bet['bet_id']}/cancel", headers=auth(token)).status_code == 200
    again = client.post(f"/api/v1/bets/{bet['bet_id']}/cancel", headers=auth(token))
    assert again.status_code == 400
    assert again.json()["detail"] == {"code": "BET_NOT_CANCELLABLE", "message": "当前投注无法取消"}
    assert available(token) == before


def test_cancel_after_close_blocked() -> None:
    token, _ = token_and_account("cancel-closed")
    round_id = open_round(token)
    before = available(token)
    bet = place(token, round_id, "c3")
    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(admin_token()))
    response = client.post(f"/api/v1/bets/{bet['bet_id']}/cancel", headers=auth(token))
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "BET_NOT_CANCELLABLE"
    assert available(token) == before - 10


def test_cancel_other_users_bet_or_missing_is_404() -> None:
    owner, _ = token_and_account("cancel-owner")
    other, _ = token_and_account("cancel-other")
    round_id = open_round(owner)
    bet = place(owner, round_id, "c4")
    for path in (f"/api/v1/bets/{bet['bet_id']}/cancel", "/api/v1/bets/does-not-exist/cancel"):
        response = client.post(path, headers=auth(other))
        assert response.status_code == 404
        assert response.json()["detail"]["code"] == "BET_NOT_FOUND"
    assert client.get(f"/api/v1/bets/{bet['bet_id']}", headers=auth(owner)).json()["status"] == "ACCEPTED"


def test_list_only_mine_filtered_by_round_and_status() -> None:
    me, _ = token_and_account("list-me")
    other, _ = token_and_account("list-other")
    round_a = open_round(me)
    round_b = open_round(me)
    keep = place(me, round_a, "l1")
    gone = place(me, round_a, "l2")
    place(me, round_b, "l3")
    place(other, round_a, "l4")
    client.post(f"/api/v1/bets/{gone['bet_id']}/cancel", headers=auth(me))

    response = client.get(
        "/api/v1/bets", headers=auth(me), params={"round_id": round_a, "status": "ACCEPTED"}
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert [item["bet_id"] for item in items] == [keep["bet_id"]]
    assert CONTRACT_FIELDS <= items[0].keys()
    assert items[0]["numbers"] == [1, 2, 3]

    all_mine = client.get("/api/v1/bets", headers=auth(me)).json()["items"]
    assert len(all_mine) == 3

    bad = client.get("/api/v1/bets", headers=auth(me), params={"status": "NOPE"})
    assert bad.status_code == 400
    assert bad.json()["detail"]["code"] == "INVALID_STATUS"


def test_cancelled_bet_excluded_from_settlement() -> None:
    token, _ = token_and_account("cancel-settle")
    round_id = open_round(token)
    bet = place(token, round_id, "c5")
    client.post(f"/api/v1/bets/{bet['bet_id']}/cancel", headers=auth(token))
    admin = auth(admin_token())
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=admin)
    record = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=admin,
        json={"results": [{"bet_id": bet["bet_id"], "result": "LOSS"}]},
    )
    assert record.status_code == 400
    assert record.json()["detail"]["code"] == "BET_CANCELLED"
    final = client.post(f"/api/v1/rounds/{round_id}/settled", headers=admin)
    assert final.status_code == 200, final.json()
    assert final.json()["status"] == "SETTLED"
