"""本地造版主种子：环境变量打开才生效，积分走账本分录，重启幂等，默认无任何副作用。"""
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.ledger.model import Direction, Reason
from app.main import app
from app.moderator.dev_seed import SEED_MODERATORS_ENV, SEED_PASSWORD_ENV, parse_pairs
from app.state import build_state

client = TestClient(app)


def _counts(state) -> tuple[int, int, int]:
    conn = state.auth.accounts.connection
    return (
        conn.execute("select count(*) from accounts").fetchone()[0],
        conn.execute("select count(*) from points_entries").fetchone()[0],
        conn.execute("select count(*) from moderator_boards").fetchone()[0],
    )


def test_seed_unset_creates_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(SEED_MODERATORS_ENV, raising=False)
    state = build_state(tmp_path / "noseed.sqlite")
    assert _counts(state) == (0, 0, 0)
    monkeypatch.setenv(SEED_MODERATORS_ENV, "  ")
    assert _counts(build_state(tmp_path / "blank.sqlite")) == (0, 0, 0)


def test_seed_creates_moderators_with_ledger_entries_and_is_idempotent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(SEED_MODERATORS_ENV, "alice:fujian-31, bob:demo-digit")
    monkeypatch.delenv(SEED_PASSWORD_ENV, raising=False)
    db = tmp_path / "seed.sqlite"
    state = build_state(db)
    threshold = state.moderator.store.threshold()

    for username, lottery_id in (("alice", "fujian-31"), ("bob", "demo-digit")):
        account = state.auth.accounts.by_username(username)
        assert account is not None and account.role == "user"
        entries = state.ledger.entries(account.account_id)
        seed = [e for e in entries if e.reference_type == "dev_seed"]
        assert len(seed) == 1
        assert seed[0].direction is Direction.CREDIT and seed[0].amount == threshold
        assert seed[0].reason is Reason.OPENING_GRANT
        assert seed[0].idempotency_key == f"dev-seed:moderator:{lottery_id}"
        assert state.ledger.balance(account.account_id) == threshold + 100
        assert state.ledger.frozen(account.account_id) == threshold
        boards = state.moderator.boards(account.account_id)
        assert [b["lottery_id"] for b in boards] == [lottery_id]
        # default local password works
        state.auth.login(username, "secret-pass")

    before = _counts(state)
    restarted = build_state(db)
    assert _counts(restarted) == before == (2, 4, 2)
    alice = restarted.auth.accounts.by_username("alice")
    assert restarted.ledger.balance(alice.account_id) == threshold + 100
    assert restarted.ledger.frozen(alice.account_id) == threshold


def test_seed_password_env_and_existing_account_kept(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    db = tmp_path / "pw.sqlite"
    monkeypatch.delenv(SEED_MODERATORS_ENV, raising=False)
    state = build_state(db)
    state.auth.register("carol", "carol-own-pass")
    monkeypatch.setenv(SEED_MODERATORS_ENV, "carol:fujian-31,dave:fujian-31")
    monkeypatch.setenv(SEED_PASSWORD_ENV, "dave-local-pass")
    seeded = build_state(db)
    seeded.auth.login("carol", "carol-own-pass")
    seeded.auth.login("dave", "dave-local-pass")
    carol = seeded.auth.accounts.by_username("carol")
    assert seeded.moderator.boards(carol.account_id)[0]["lottery_id"] == "fujian-31"


def test_parse_pairs_rejects_malformed() -> None:
    assert parse_pairs("a:x, ,b:y") == [("a", "x"), ("b", "y")]
    for bad in ("alice", "alice:", ":fujian-31"):
        with pytest.raises(ValueError):
            parse_pairs(bad)


def test_no_http_route_can_credit_points() -> None:
    paths = {route.path for route in app.routes}
    assert not any("seed" in path or "grant" in path or "credit" in path for path in paths)
