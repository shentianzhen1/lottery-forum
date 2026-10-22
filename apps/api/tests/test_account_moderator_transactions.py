"""Account creation and moderator opening must not commit a partial command."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier

import pytest

from app.auth.service import AuthError, AuthService
from app.ledger.model import Direction, PostRequest, Reason
from app.moderator.service import ModeratorService
from app.state import build_state


@pytest.fixture
def state(tmp_path):
    services = build_state(tmp_path / "accounts.sqlite")
    yield services
    services.auth.accounts.connection.close()


def snapshot(state):
    tables = ("accounts", "sessions", "points_accounts", "points_entries", "points_holds", "moderator_boards")
    return {table: [tuple(row) for row in state.auth.accounts.connection.execute(
        f"select * from {table} order by rowid"
    )] for table in tables}


def inject_failure(patch, obj, method, after_write):
    original = getattr(obj, method)
    def fail(*args, **kwargs):
        if after_write:
            original(*args, **kwargs)
        raise RuntimeError("injected command failure")
    patch.setattr(obj, method, fail)


def fund_moderator(state):
    account = state.auth.create_account("tx-moderator", "secret-pass")
    state.ledger.post(PostRequest(
        account_id=account.account_id, direction=Direction.CREDIT, amount=10000,
        reason=Reason.OPENING_GRANT, reference_type="test", reference_id="fund",
        idempotency_key="fund", operator_id="system"))
    return account.account_id


@pytest.mark.parametrize("after_write", [False, True])
def test_create_account_grant_failure_rolls_back_and_can_retry(state, monkeypatch, after_write):
    before = snapshot(state)
    with monkeypatch.context() as patch:
        inject_failure(patch, state.ledger, "post", after_write)
        with pytest.raises(RuntimeError, match="injected"):
            state.auth.create_account("create-retry", "secret-pass")
    assert snapshot(state) == before
    account = state.auth.create_account("create-retry", "secret-pass")
    assert state.ledger.balance(account.account_id) == 100
    assert len(state.ledger.entries(account.account_id)) == 1


@pytest.mark.parametrize("after_write", [False, True])
def test_register_session_failure_rolls_back_account_and_grant(state, monkeypatch, after_write):
    before = snapshot(state)
    with monkeypatch.context() as patch:
        inject_failure(patch, state.auth.accounts, "save_session", after_write)
        with pytest.raises(RuntimeError, match="injected"):
            state.auth.register("register-retry", "secret-pass")
    assert snapshot(state) == before
    account, token = state.auth.register("register-retry", "secret-pass")
    assert state.auth.account_from_token(token).account_id == account.account_id
    assert state.ledger.balance(account.account_id) == 100
    assert len(state.ledger.entries(account.account_id)) == 1


@pytest.mark.parametrize("after_write", [False, True])
def test_open_board_write_failure_rolls_back_hold_and_can_retry(state, monkeypatch, after_write):
    account_id = fund_moderator(state)
    before = snapshot(state)
    with monkeypatch.context() as patch:
        inject_failure(patch, state.moderator.store, "add", after_write)
        with pytest.raises(RuntimeError, match="injected"):
            state.moderator.open_board(account_id, "fujian-31")
    assert snapshot(state) == before
    board = state.moderator.open_board(account_id, "fujian-31")
    assert state.moderator.open_board(account_id, "fujian-31")["board_id"] == board["board_id"]
    assert state.ledger.frozen(account_id) == 10000
    assert len(state.moderator.boards(account_id)) == 1


@pytest.mark.parametrize("separate_connections", [False, True])
def test_concurrent_registration_returns_username_taken_not_database_error(tmp_path, separate_connections):
    path = tmp_path / "concurrent-accounts.sqlite"
    first = build_state(path)
    second = build_state(path) if separate_connections else first
    try:
        start = Barrier(6)
        def register(n):
            start.wait(timeout=10)
            service = first if n % 2 == 0 else second
            try:
                return service.auth.register("same-username", "secret-pass")[0]
            except AuthError as error:
                assert error.code == "USERNAME_TAKEN"
                return None
        with ThreadPoolExecutor(max_workers=6) as pool:
            successes = [r for r in pool.map(register, range(6)) if r is not None]
        assert len(successes) == 1
        account_id = successes[0].account_id
        assert first.ledger.balance(account_id) == 100
        assert len(first.ledger.entries(account_id)) == 1
        assert first.auth.accounts.connection.execute("select count(*) from sessions").fetchone()[0] == 1
    finally:
        first.auth.accounts.connection.close()
        if second is not first:
            second.auth.accounts.connection.close()


@pytest.mark.parametrize("separate_connections", [False, True])
@pytest.mark.parametrize("same_lottery", [False, True])
def test_concurrent_board_open_is_idempotent_and_cannot_overfreeze(tmp_path, separate_connections, same_lottery):
    path = tmp_path / "concurrent-boards.sqlite"
    first = build_state(path)
    second = build_state(path) if separate_connections else first
    try:
        account_id = fund_moderator(first)
        start = Barrier(6)
        def open_board(n):
            start.wait(timeout=10)
            service = first if n % 2 == 0 else second
            lottery_id = "fujian-31" if same_lottery or n % 2 == 0 else "demo-digit"
            return service.moderator.open_board(account_id, lottery_id)
        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(open_board, range(6)))
        successes = [r for r in results if "code" not in r]
        assert len({r["board_id"] for r in successes}) == 1
        if same_lottery:
            assert len(successes) == 6
        else:
            assert all(r["code"] == "INSUFFICIENT_POINTS" for r in results if "code" in r)
        assert first.ledger.frozen(account_id) == 10000
        assert first.ledger.available(account_id) == 100
        assert len(first.moderator.boards(account_id)) == 1
        assert first.auth.accounts.connection.execute("select count(*) from points_holds").fetchone()[0] == 1
    finally:
        first.auth.accounts.connection.close()
        if second is not first:
            second.auth.accounts.connection.close()


@pytest.mark.parametrize("command", ["register", "open_board"])
def test_failed_command_leaves_no_partial_state_after_database_reopen(state, monkeypatch, command):
    if command == "open_board":
        account_id = fund_moderator(state)
    before = snapshot(state)
    path = Path(state.auth.accounts.connection.execute("pragma database_list").fetchone()[2])
    with monkeypatch.context() as patch:
        if command == "register":
            inject_failure(patch, state.auth.accounts, "save_session", True)
            call = lambda: state.auth.register("durable-register", "secret-pass")
        else:
            inject_failure(patch, state.moderator.store, "add", True)
            call = lambda: state.moderator.open_board(account_id, "fujian-31")
        with pytest.raises(RuntimeError, match="injected"):
            call()
    reopened = build_state(path)
    try:
        assert snapshot(reopened) == before
    finally:
        reopened.auth.accounts.connection.close()


@pytest.mark.parametrize("service", ["auth", "moderator"])
def test_commands_reject_split_store_connections(state, tmp_path, service):
    other = build_state(tmp_path / "separate.sqlite")
    try:
        with pytest.raises(ValueError, match="share one connection"):
            if service == "auth":
                AuthService(state.auth.accounts, other.ledger)
            else:
                ModeratorService(state.moderator.store, other.ledger)
    finally:
        other.auth.accounts.connection.close()
