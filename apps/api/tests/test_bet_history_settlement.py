from fastapi.testclient import TestClient

from app.main import app
from tests.test_admin_permission import admin_token, auth, register
from tests.test_settled_finalize import moderator, open_round_with_board, place, record

client = TestClient(app)


def test_own_bet_history_exposes_result_only_after_own_bet_and_marks_finalize() -> None:
    _, _, board_id = moderator("history-settle-mod")
    player = register("history-settle-player")
    other = register("history-settle-other")
    round_id = open_round_with_board(board_id)

    assert client.post(
        f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token())
    ).status_code == 200
    bet_id = place(player["token"], round_id, "history-settle-win")
    for step in ("close", "draw", "settling"):
        assert client.post(
            f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token())
        ).status_code == 200

    record(round_id, [{"bet_id": bet_id, "result": "WIN"}])

    before_finalize = client.get("/api/v1/bets", headers=auth(player["token"]))
    assert before_finalize.status_code == 200
    row = next(item for item in before_finalize.json()["items"] if item["bet_id"] == bet_id)
    assert row["round_code"] == "finalize"
    assert row["status"] == "ACCEPTED"
    assert row["settlement_result"] == "WIN"
    assert row["settlement_finalized"] is False
    assert row["settlement_delta"] is None
    assert row["settlement_return"] is None
    assert row["settlement_recorded_at"]

    other_rows = client.get("/api/v1/bets", headers=auth(other["token"])).json()["items"]
    assert all(item["bet_id"] != bet_id for item in other_rows)

    finalized = client.post(
        f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token())
    )
    assert finalized.status_code == 200
    assert finalized.json()["status"] == "SETTLED"

    after_finalize = client.get(f"/api/v1/bets/{bet_id}", headers=auth(player["token"]))
    assert after_finalize.status_code == 200
    settled = after_finalize.json()
    assert settled["status"] == "SETTLED"
    assert settled["settlement_result"] == "WIN"
    assert settled["settlement_finalized"] is True
    assert settled["settlement_delta"] == 10
    assert settled["settlement_return"] == 20
