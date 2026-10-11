"""派奖：SETTLING → SETTLED；VOID 解冻、LOSS 划入版主、WIN 连本带利共 2 倍（盈利 stake×(倍率−1)）。"""
from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app
from tests.test_admin_permission import FORBIDDEN, admin_token, auth, register

client = TestClient(app)


def moderator(username: str, lottery_id: str = "demo-digit") -> tuple[str, str, str]:
    """Returns (token, account_id, board_id)."""
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
        "/api/v1/moderator/boards",
        headers=auth(body["token"]),
        json={"lottery_id": lottery_id},
    )
    assert board.status_code == 200
    return body["token"], body["account_id"], board.json()["board_id"]


def open_round_with_board(board_id: str, lottery_id: str = "demo-digit") -> str:
    created = client.post(
        "/api/v1/rounds",
        headers=auth(admin_token()),
        json={"lottery_id": lottery_id, "board_id": board_id, "code": "finalize"},
    )
    assert created.status_code == 200
    return created.json()["round_id"]


def place(token: str, round_id: str, key: str) -> str:
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
    assert response.status_code == 200, response.text
    return response.json()["bet_id"]


def advance_to_settling(round_id: str) -> None:
    for step in ("open", "close", "draw", "settling"):
        assert client.post(
            f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token())
        ).status_code == 200


def record(round_id: str, results: list[dict[str, str]]) -> None:
    response = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(admin_token()),
        json={"results": results},
    )
    assert response.status_code == 200, response.text


def balance(token: str) -> dict:
    return client.get("/api/v1/points/balance", headers=auth(token)).json()


def drain_available(account_id: str, leave: int, key: str) -> None:
    """Debit until available == leave (balance - frozen)."""
    avail = app.state.services.ledger.available(account_id)
    amount = avail - leave
    if amount <= 0:
        return
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


def test_void_releases_hold_and_marks_bet_settled() -> None:
    _, mod_id, board_id = moderator("fin-void-mod")
    player = register("fin-void-player")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-void-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "VOID"}])

    before = balance(player["token"])
    assert before["balance"] == 100 and before["frozen"] == 10 and before["available"] == 90

    finalized = client.post(
        f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token())
    )
    assert finalized.status_code == 200
    assert finalized.json()["status"] == "SETTLED"
    assert finalized.json()["applied"]["void"] == 1

    after = balance(player["token"])
    assert after["balance"] == 100 and after["frozen"] == 0 and after["available"] == 100
    bet = client.get(f"/api/v1/bets/{bet_id}", headers=auth(player["token"]))
    assert bet.json()["status"] == "SETTLED"
    # moderator wallet unchanged on VOID
    mod_token = client.post(
        "/api/v1/auth/login",
        json={"username": "fin-void-mod", "password": "secret-pass"},
    ).json()["token"]
    # threshold frozen; opening_grant 100 + threshold; available = 100 (threshold held)
    mod_bal = balance(mod_token)
    assert mod_bal["frozen"] == app.state.services.moderator.store.threshold()
    del mod_id


def test_loss_debits_player_credits_moderator() -> None:
    _, mod_account_id, board_id = moderator("fin-loss-mod")
    player = register("fin-loss-player")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-loss-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "LOSS"}])

    mod_before = app.state.services.ledger.balance(mod_account_id)
    player_before = balance(player["token"])
    assert player_before["frozen"] == 10

    finalized = client.post(
        f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token())
    )
    assert finalized.status_code == 200
    body = finalized.json()
    assert body["status"] == "SETTLED"
    assert body["applied"]["loss"] == 1

    player_after = balance(player["token"])
    assert player_after["balance"] == 90
    assert player_after["frozen"] == 0
    assert player_after["available"] == 90
    assert client.get(f"/api/v1/bets/{bet_id}", headers=auth(player["token"])).json()["status"] == "SETTLED"

    mod_after = app.state.services.ledger.balance(mod_account_id)
    assert mod_after == mod_before + 10

    # retry is idempotent: no double debit/credit
    again = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert again.status_code == 200
    assert again.json()["status"] == "SETTLED"
    assert balance(player["token"])["balance"] == 90
    assert app.state.services.ledger.balance(mod_account_id) == mod_after


def test_win_pays_from_moderator_available() -> None:
    """WIN: release hold, debit mod profit stake×(2−1), credit player; threshold freeze untouched."""
    _, mod_account_id, board_id = moderator("fin-win-mod")
    player = register("fin-win-player")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-win-1")
    body = client.get(f"/api/v1/bets/{bet_id}", headers=auth(player["token"])).json()
    assert body["odds_snapshot"] == {"status": "fixed", "multiplier": 2}

    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "WIN"}])

    threshold = app.state.services.moderator.store.threshold()
    mod_before = app.state.services.ledger.balance(mod_account_id)
    mod_avail_before = app.state.services.ledger.available(mod_account_id)
    mod_frozen_before = app.state.services.ledger.frozen(mod_account_id)
    assert mod_frozen_before == threshold
    assert mod_avail_before == 100  # opening grant remains available after threshold hold

    finalized = client.post(
        f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token())
    )
    assert finalized.status_code == 200, finalized.text
    assert finalized.json()["status"] == "SETTLED"
    assert finalized.json()["applied"]["win"] == 1

    # stake 10 released + profit 10 credited → balance 110, frozen 0, available 110
    player_after = balance(player["token"])
    assert player_after["balance"] == 110
    assert player_after["frozen"] == 0
    assert player_after["available"] == 110
    assert client.get(f"/api/v1/bets/{bet_id}", headers=auth(player["token"])).json()["status"] == "SETTLED"

    mod_after = app.state.services.ledger.balance(mod_account_id)
    assert mod_after == mod_before - 10
    assert app.state.services.ledger.frozen(mod_account_id) == threshold
    assert app.state.services.ledger.available(mod_account_id) == mod_avail_before - 10

    # idempotent retry
    again = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert again.status_code == 200
    assert balance(player["token"])["balance"] == 110
    assert app.state.services.ledger.balance(mod_account_id) == mod_after


def test_win_insufficient_moderator_blocks_no_state_change() -> None:
    _, mod_account_id, board_id = moderator("fin-win-poor")
    player = register("fin-win-poor-p")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-win-poor-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "WIN"}])

    drain_available(mod_account_id, leave=9, key="drain-fin-win-poor")  # need 10 profit
    mod_bal = app.state.services.ledger.balance(mod_account_id)
    mod_frozen = app.state.services.ledger.frozen(mod_account_id)

    blocked = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert blocked.status_code == 400
    assert blocked.json()["detail"]["code"] == "INSUFFICIENT_MODERATOR_POINTS"
    assert blocked.json()["detail"]["message"] == "版主可用积分不足，无法派奖"
    assert client.get(f"/api/v1/rounds/{round_id}", headers=auth(player["token"])).json()["status"] == "SETTLING"
    assert balance(player["token"])["frozen"] == 10
    assert app.state.services.ledger.balance(mod_account_id) == mod_bal
    assert app.state.services.ledger.frozen(mod_account_id) == mod_frozen


def test_win_exact_available_passes() -> None:
    """When moderator available exactly equals WIN profit total, settle proceeds."""
    _, mod_account_id, board_id = moderator("fin-win-exact")
    player = register("fin-win-exact-p")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-win-exact-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "WIN"}])

    drain_available(mod_account_id, leave=10, key="drain-fin-win-exact")  # need exactly 10
    assert app.state.services.ledger.available(mod_account_id) == 10

    ok = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert ok.status_code == 200, ok.text
    assert ok.json()["status"] == "SETTLED"
    assert balance(player["token"])["balance"] == 110
    assert app.state.services.ledger.available(mod_account_id) == 0


def test_null_board_with_win_blocked() -> None:
    player = register("fin-noboard-win")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(admin_token()),
        json={"lottery_id": "demo-digit", "code": "no-board-win"},
    )
    round_id = created.json()["round_id"]
    assert created.json()["board_id"] is None
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-noboard-win-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "WIN"}])

    blocked = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert blocked.status_code == 400
    assert blocked.json()["detail"]["code"] == "BOARD_REQUIRED"
    assert client.get(f"/api/v1/rounds/{round_id}", headers=auth(player["token"])).json()["status"] == "SETTLING"


def test_incomplete_settlements_blocked() -> None:
    _, _, board_id = moderator("fin-inc-mod")
    player = register("fin-inc-player")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_a = place(player["token"], round_id, "fin-inc-a")
    bet_b = place(player["token"], round_id, "fin-inc-b")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_a, "result": "VOID"}])  # bet_b missing

    blocked = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert blocked.status_code == 400
    assert blocked.json()["detail"]["code"] == "SETTLEMENT_INCOMPLETE"
    del bet_b


def test_null_board_with_loss_blocked() -> None:
    player = register("fin-noboard-player")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(admin_token()),
        json={"lottery_id": "demo-digit", "code": "no-board"},
    )
    round_id = created.json()["round_id"]
    assert created.json()["board_id"] is None
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-noboard-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "LOSS"}])

    blocked = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert blocked.status_code == 400
    assert blocked.json()["detail"]["code"] == "BOARD_REQUIRED"


def test_null_board_void_only_ok() -> None:
    """Legacy round without board can settle if every result is VOID (no LOSS transfer)."""
    player = register("fin-noboard-void")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(admin_token()),
        json={"lottery_id": "demo-digit"},
    )
    round_id = created.json()["round_id"]
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    bet_id = place(player["token"], round_id, "fin-noboard-void-1")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(round_id, [{"bet_id": bet_id, "result": "VOID"}])

    ok = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert ok.status_code == 200
    assert ok.json()["status"] == "SETTLED"
    assert balance(player["token"])["available"] == 100


def test_settled_admin_only() -> None:
    _, _, board_id = moderator("fin-perm-mod")
    player = register("fin-perm-player")
    round_id = open_round_with_board(board_id)
    advance_to_settling(round_id)

    mod_token = client.post(
        "/api/v1/auth/login",
        json={"username": "fin-perm-mod", "password": "secret-pass"},
    ).json()["token"]
    for token in (player["token"], mod_token):
        blocked = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(token))
        assert blocked.status_code == 403
        assert blocked.json()["detail"] == FORBIDDEN

    assert client.post(f"/api/v1/rounds/{round_id}/settled").status_code == 401


def test_mixed_void_and_loss() -> None:
    _, mod_account_id, board_id = moderator("fin-mix-mod")
    p1 = register("fin-mix-p1")
    p2 = register("fin-mix-p2")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    void_bet = place(p1["token"], round_id, "fin-mix-void")
    loss_bet = place(p2["token"], round_id, "fin-mix-loss")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(
        round_id,
        [
            {"bet_id": void_bet, "result": "VOID"},
            {"bet_id": loss_bet, "result": "LOSS"},
        ],
    )
    mod_before = app.state.services.ledger.balance(mod_account_id)
    ok = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert ok.status_code == 200
    assert ok.json()["applied"] == {"void": 1, "loss": 1, "win": 0, "skipped": 0}
    assert balance(p1["token"])["available"] == 100
    assert balance(p2["token"])["balance"] == 90 and balance(p2["token"])["frozen"] == 0
    assert app.state.services.ledger.balance(mod_account_id) == mod_before + 10


def test_mixed_void_loss_and_win() -> None:
    _, mod_account_id, board_id = moderator("fin-mix3-mod")
    p1 = register("fin-mix3-p1")
    p2 = register("fin-mix3-p2")
    p3 = register("fin-mix3-p3")
    round_id = open_round_with_board(board_id)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin_token()))
    void_bet = place(p1["token"], round_id, "fin-mix3-void")
    loss_bet = place(p2["token"], round_id, "fin-mix3-loss")
    win_bet = place(p3["token"], round_id, "fin-mix3-win")
    for step in ("close", "draw", "settling"):
        client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin_token()))
    record(
        round_id,
        [
            {"bet_id": void_bet, "result": "VOID"},
            {"bet_id": loss_bet, "result": "LOSS"},
            {"bet_id": win_bet, "result": "WIN"},
        ],
    )
    # preflight uses available BEFORE LOSS credit; need ≥10 profit for WIN
    assert app.state.services.ledger.available(mod_account_id) >= 10
    mod_before = app.state.services.ledger.balance(mod_account_id)
    ok = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert ok.status_code == 200, ok.text
    assert ok.json()["applied"] == {"void": 1, "loss": 1, "win": 1, "skipped": 0}
    assert balance(p1["token"])["available"] == 100
    assert balance(p2["token"])["balance"] == 90
    assert balance(p3["token"])["balance"] == 110 and balance(p3["token"])["frozen"] == 0
    # LOSS +10, WIN profit -10 → net 0
    assert app.state.services.ledger.balance(mod_account_id) == mod_before


def test_empty_round_can_settle() -> None:
    _, _, board_id = moderator("fin-empty-mod")
    round_id = open_round_with_board(board_id)
    advance_to_settling(round_id)
    ok = client.post(f"/api/v1/rounds/{round_id}/settled", headers=auth(admin_token()))
    assert ok.status_code == 200
    assert ok.json()["status"] == "SETTLED"
