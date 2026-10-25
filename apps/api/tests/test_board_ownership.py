"""版主归属期号与权限：期号挂版块，版主只能操作自己版块的期号；整期结算明细与写结算只限管理员。"""
import sqlite3

from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app
from app.rounds.store import RoundStore
from tests.test_admin_permission import FORBIDDEN, admin_token, auth, register

client = TestClient(app)


def moderator(username: str, lottery_id: str) -> tuple[str, str]:
    """Register, grant the threshold via ledger, open a board. Returns (token, board_id)."""
    body = register(username)
    services = app.state.services
    services.ledger.post(
        PostRequest(
            account_id=body["account_id"],
            direction=Direction.CREDIT,
            amount=services.moderator.store.threshold(),
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id=f"grant-{username}",
            idempotency_key=f"grant-{username}",
            operator_id="system",
        )
    )
    board = client.post(
        "/api/v1/moderator/boards", headers=auth(body["token"]), json={"lottery_id": lottery_id}
    )
    assert board.status_code == 200
    return body["token"], board.json()["board_id"]


def create(token: str, lottery_id: str, board_id: str | None = None):
    payload = {"lottery_id": lottery_id}
    if board_id is not None:
        payload["board_id"] = board_id
    return client.post("/api/v1/rounds", headers=auth(token), json=payload)


def test_moderator_creates_round_on_own_board_with_board_id_in_reads() -> None:
    token, board_id = moderator("own-mod-a", "fujian-31")
    created = create(token, "fujian-31", board_id)
    assert created.status_code == 200
    body = created.json()
    assert body["board_id"] == board_id and body["status"] == "UPCOMING"

    reader = register("own-reader")["token"]
    got = client.get(f"/api/v1/rounds/{body['round_id']}", headers=auth(reader))
    assert got.json()["board_id"] == board_id
    listed = client.get("/api/v1/rounds", headers=auth(reader), params={"lottery_id": "fujian-31"})
    match = [r for r in listed.json()["rounds"] if r["round_id"] == body["round_id"]]
    assert match and match[0]["board_id"] == board_id
    assert all("board_id" in r for r in listed.json()["rounds"])


def test_moderator_cannot_create_on_other_board_or_without_board() -> None:
    _, board_b = moderator("own-mod-b-owner", "demo-digit")
    token_c, _ = moderator("own-mod-c", "demo-digit")
    for response in (
        create(token_c, "demo-digit", board_b),
        create(token_c, "demo-digit"),
        create(token_c, "demo-digit", "no-such-board"),  # 403, not 404: no existence leak
    ):
        assert response.status_code == 403
        assert response.json()["detail"] == FORBIDDEN


def test_lottery_mismatch_rejected_for_owner_and_admin() -> None:
    token, board_id = moderator("own-mod-mismatch", "fujian-31")
    mismatch = create(token, "demo-digit", board_id)
    assert mismatch.status_code == 400
    assert mismatch.json()["detail"]["code"] == "BOARD_LOTTERY_MISMATCH"

    admin = admin_token()
    assert create(admin, "demo-digit", board_id).json()["detail"]["code"] == "BOARD_LOTTERY_MISMATCH"
    missing = create(admin, "demo-digit", "no-such-board")
    assert missing.status_code == 404
    assert missing.json()["detail"]["code"] == "BOARD_NOT_FOUND"


def test_moderator_advances_own_round_and_other_moderator_is_forbidden() -> None:
    token, board_id = moderator("own-mod-flow", "fujian-31")
    other, _ = moderator("own-mod-flow-other", "fujian-31")
    round_id = create(token, "fujian-31", board_id).json()["round_id"]

    for step, status in (("open", "OPEN"), ("close", "CLOSED"), ("draw", "DRAWN"), ("settling", "SETTLING")):
        blocked = client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(other))
        assert blocked.status_code == 403 and blocked.json()["detail"] == FORBIDDEN
        ok = client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(token))
        assert ok.status_code == 200 and ok.json()["status"] == status

    # Invalid transitions are still reported to the owner.
    again = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert again.status_code == 400 and again.json()["detail"]["code"] == "INVALID_TRANSITION"
    # Owner gets 403 for a missing round (same as #49 behaviour for non-admins).
    assert client.post("/api/v1/rounds/does-not-exist/open", headers=auth(token)).status_code == 403


def test_moderator_cannot_write_or_read_settlements_even_on_own_board() -> None:
    token, board_id = moderator("own-mod-settle", "demo-digit")
    bettor = register("own-settle-bettor")["token"]
    round_id = create(token, "demo-digit", board_id).json()["round_id"]
    assert client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token)).status_code == 200
    bet = client.post(
        "/api/v1/bets",
        headers=auth(bettor),
        json={
            "idempotency_key": "own-settle-1",
            "round_id": round_id,
            "play_id": "number-pick",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3],
        },
    )
    assert bet.status_code == 200 and bet.json()["status"] == "ACCEPTED"
    for step in ("close", "draw", "settling"):
        assert client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(token)).status_code == 200

    payload = {"results": [{"bet_id": bet.json()["bet_id"], "result": "WIN"}]}
    forbidden = client.post(f"/api/v1/settlements/{round_id}", headers=auth(token), json=payload)
    assert forbidden.status_code == 403 and forbidden.json()["detail"] == FORBIDDEN
    forbidden_read = client.get(f"/api/v1/settlements/{round_id}", headers=auth(token))
    assert forbidden_read.status_code == 403 and forbidden_read.json()["detail"] == FORBIDDEN

    admin_ok = client.post(f"/api/v1/settlements/{round_id}", headers=auth(admin_token()), json=payload)
    assert admin_ok.status_code == 200


def test_legacy_round_without_board_is_admin_only() -> None:
    admin = admin_token()
    token, _ = moderator("own-mod-legacy", "demo-digit")
    legacy = create(admin, "demo-digit")
    assert legacy.status_code == 200 and legacy.json()["board_id"] is None
    round_id = legacy.json()["round_id"]
    blocked = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert blocked.status_code == 403 and blocked.json()["detail"] == FORBIDDEN
    assert client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin)).status_code == 200


def test_admin_can_attach_any_board_and_advance_it() -> None:
    admin = admin_token()
    token, board_id = moderator("own-mod-admin-board", "fujian-31")
    created = create(admin, "fujian-31", board_id)
    assert created.status_code == 200 and created.json()["board_id"] == board_id
    round_id = created.json()["round_id"]
    assert client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin)).status_code == 200
    # The board owner can continue a round the admin attached to their board.
    assert client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token)).status_code == 200


def test_normal_user_without_board_still_forbidden() -> None:
    user = register("own-plain-user")["token"]
    response = create(user, "demo-digit")
    assert response.status_code == 403 and response.json()["detail"] == FORBIDDEN


def test_legacy_rounds_table_gets_nullable_board_id(tmp_path) -> None:
    path = tmp_path / "legacy.sqlite"
    raw = sqlite3.connect(path)
    raw.executescript(
        """
        create table rounds (
            round_id text primary key,
            lottery_id text not null,
            code text,
            status text not null,
            created_at text not null default (datetime('now'))
        );
        insert into rounds(round_id, lottery_id, code, status) values ('old-1', 'demo-digit', null, 'OPEN');
        """
    )
    raw.commit()
    raw.close()
    store = RoundStore(path)
    row = store.get("old-1")
    assert row is not None and row["board_id"] is None
