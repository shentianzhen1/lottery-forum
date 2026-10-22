"""A command must not leave a committed prefix when a later step fails."""
import pytest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier

from app.db import connect
from app.bets.service import BetError
from app.bets.service import BetService
from app.settlements.service import SettlementError
from app.state import build_state
from app.ledger.model import Direction, PostRequest, Reason


@pytest.fixture
def state(tmp_path):
    services = build_state(tmp_path / "atomic.sqlite")
    yield services
    services.bets.store.connection.close()


def player_and_round(state):
    player = state.auth.create_account("atomic-player", "secret-pass")
    round_id = state.rounds.create("demo-digit")["round_id"]
    state.rounds.open(round_id)
    return player.account_id, round_id


def payload(round_id, key="atomic-bet"):
    return dict(round_id=round_id, idempotency_key=key, play_id="number-pick",
                rule_version="0.1.0", numbers=[1, 2, 3])


def snapshot(state):
    connection = state.bets.store.connection
    tables = ("bets", "rounds", "points_accounts", "points_holds", "points_entries", "settlements")
    return {table: [tuple(row) for row in connection.execute(f"select * from {table} order by rowid")]
            for table in tables}


def fail_after(monkeypatch, obj, name):
    original = getattr(obj, name)
    def fail(*args, **kwargs):
        original(*args, **kwargs)
        raise RuntimeError("injected failure after write")
    monkeypatch.setattr(obj, name, fail)


def test_place_failure_rolls_back_bet_and_hold(state, monkeypatch):
    account_id, round_id = player_and_round(state)
    before = snapshot(state)
    with monkeypatch.context() as patch:
        fail_after(patch, state.bets.store, "add")
        with pytest.raises(RuntimeError, match="injected"):
            state.bets.place(account_id, payload(round_id))
    assert snapshot(state) == before
    assert state.bets.place(account_id, payload(round_id))["status"] == "ACCEPTED"
    assert state.ledger.frozen(account_id) == 10


def test_cancel_failure_rolls_back_status_and_release(state, monkeypatch):
    account_id, round_id = player_and_round(state)
    bet = state.bets.place(account_id, payload(round_id))
    before = snapshot(state)
    with monkeypatch.context() as patch:
        fail_after(patch, state.ledger, "release_if_active")
        with pytest.raises(RuntimeError, match="injected"):
            state.bets.cancel(account_id, bet["bet_id"])
    assert snapshot(state) == before
    assert state.bets.cancel(account_id, bet["bet_id"])["status"] == "CANCELLED"
    assert state.ledger.frozen(account_id) == 0


def test_record_batch_failure_does_not_persist_prefix(state):
    account_id, round_id = player_and_round(state)
    bet = state.bets.place(account_id, payload(round_id))
    for step in ("close", "draw", "settling"):
        getattr(state.rounds, step)(round_id)
    before = snapshot(state)
    with pytest.raises(SettlementError):
        state.settlements.record(round_id, [dict(bet_id=bet["bet_id"], result="VOID"),
                                           dict(bet_id="missing", result="VOID")])
    assert snapshot(state) == before


@pytest.mark.parametrize("result", ["WIN", "LOSS", "VOID"])
def test_finalize_failure_rolls_back_whole_round(state, monkeypatch, result):
    account_id, _unused_round = player_and_round(state)
    moderator = state.auth.create_account("atomic-moderator", "secret-pass")
    state.ledger.post(PostRequest(
        account_id=moderator.account_id, direction=Direction.CREDIT, amount=10000,
        reason=Reason.OPENING_GRANT, reference_type="test", reference_id="fund",
        idempotency_key="fund", operator_id="system"))
    board = state.moderator.open_board(moderator.account_id, "demo-digit")
    round_id = state.rounds.create("demo-digit", board_id=board["board_id"])["round_id"]
    state.rounds.open(round_id)
    bets = [state.bets.place(account_id, payload(round_id, key=f"final-{n}")) for n in range(2)]
    for step in ("close", "draw", "settling"):
        getattr(state.rounds, step)(round_id)
    state.settlements.record(round_id, [dict(bet_id=b["bet_id"], result=result) for b in bets])
    before = snapshot(state)
    # Fail after the final state transition: even all previous bet effects must roll back.
    with monkeypatch.context() as patch:
        fail_after(patch, state.rounds.store, "set_status")
        with pytest.raises(RuntimeError, match="injected"):
            state.settlements.finalize(round_id, operator_id="admin")
    assert snapshot(state) == before
    assert state.settlements.finalize(round_id, operator_id="admin")["status"] == "SETTLED"
    after = snapshot(state)
    state.settlements.finalize(round_id, operator_id="admin")
    assert snapshot(state) == after


def test_nested_ledger_commit_cannot_escape_outer_rollback(state):
    account_id, _ = player_and_round(state)
    before = snapshot(state)
    with pytest.raises(RuntimeError, match="outer failure"):
        with state.bets.store.connection.atomic():
            state.ledger.hold(account_id, 10, "nested", account_id)
            raise RuntimeError("outer failure")
    assert snapshot(state) == before


def test_nested_savepoint_failure_can_be_caught_without_losing_outer_write(tmp_path):
    connection = connect(tmp_path / "savepoints.sqlite")
    try:
        connection.execute("create table example (value integer)")
        with connection.atomic():
            connection.execute("insert into example values (1)")
            with pytest.raises(ValueError):
                with connection.atomic():
                    connection.execute("insert into example values (2)")
                    connection.commit()  # Must not commit the outer insert.
                    raise ValueError("nested failure")
            connection.execute("insert into example values (3)")
        assert [r[0] for r in connection.execute("select value from example")] == [1, 3]
    finally:
        connection.close()


@pytest.mark.parametrize("separate_connections", [False, True])
def test_concurrent_bets_never_overspend_or_leave_orphan_holds(tmp_path, separate_connections):
    path = tmp_path / "concurrent.sqlite"
    first = build_state(path)
    second = build_state(path) if separate_connections else first
    try:
        account_id, round_id = player_and_round(first)
        start = Barrier(12)
        def place(n):
            start.wait(timeout=10)
            service = first if n % 2 == 0 else second
            try:
                return service.bets.place(account_id, payload(round_id, key=f"race-{n}"))
            except BetError as error:
                assert error.code == "INSUFFICIENT_POINTS"
                return None
        with ThreadPoolExecutor(max_workers=12) as pool:
            results = list(pool.map(place, range(12)))
        assert len([result for result in results if result]) == 10
        assert first.ledger.available(account_id) == 0
        assert first.ledger.frozen(account_id) == 100
        assert len(first.bets.store.list_for_round(round_id)) == 10
        assert first.bets.store.connection.execute(
            "select count(*) from points_holds where status='active'"
        ).fetchone()[0] == 10
    finally:
        first.bets.store.connection.close()
        if second is not first:
            second.bets.store.connection.close()


def test_place_failure_is_not_visible_after_reopening_database(state, monkeypatch):
    account_id, round_id = player_and_round(state)
    path = state.bets.store.connection.execute("pragma database_list").fetchone()[2]
    with monkeypatch.context() as patch:
        fail_after(patch, state.bets.store, "add")
        with pytest.raises(RuntimeError):
            state.bets.place(account_id, payload(round_id))
    reopened = build_state(Path(path))
    try:
        assert reopened.ledger.frozen(account_id) == 0
        assert reopened.bets.store.list_for_round(round_id) == []
    finally:
        reopened.bets.store.connection.close()


def test_concurrent_same_key_returns_one_bet_and_one_hold(state):
    account_id, round_id = player_and_round(state)
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(lambda _: state.bets.place(account_id, payload(round_id)), range(6)))
    assert len({result["bet_id"] for result in results}) == 1
    assert len(state.bets.store.list_for_round(round_id)) == 1
    assert state.ledger.frozen(account_id) == 10


def test_concurrent_cancel_succeeds_once(state):
    account_id, round_id = player_and_round(state)
    bet = state.bets.place(account_id, payload(round_id))
    def cancel(_):
        try:
            state.bets.cancel(account_id, bet["bet_id"])
            return True
        except BetError as error:
            assert error.code == "BET_NOT_CANCELLABLE"
            return False
    with ThreadPoolExecutor(max_workers=6) as pool:
        assert sum(pool.map(cancel, range(6))) == 1
    assert state.ledger.frozen(account_id) == 0
    assert state.ledger.balance(account_id) == 100


def test_transactional_service_rejects_split_store_connections(state, tmp_path):
    other = build_state(tmp_path / "other.sqlite")
    try:
        with pytest.raises(ValueError, match="share one connection"):
            BetService(state.bets.store, other.rounds, state.games, state.ledger)
    finally:
        other.bets.store.connection.close()
