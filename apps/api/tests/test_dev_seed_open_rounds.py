"""本地造 OPEN 期种子：环境变量打开才生效，同彩种已有 OPEN 则跳过，默认无副作用。"""
from pathlib import Path

import pytest

from app.moderator.dev_seed import SEED_MODERATORS_ENV
from app.rounds.dev_seed import SEED_LOTTERIES, SEED_OPEN_ROUNDS_ENV, env_enabled
from app.state import build_state


def _open_count(state, lottery_id: str) -> int:
    return sum(1 for r in state.rounds.list(lottery_id) if r["status"] == "OPEN")


def test_env_enabled_truthy_values() -> None:
    assert env_enabled("1") and env_enabled("true") and env_enabled("YES")
    assert not env_enabled("") and not env_enabled("0") and not env_enabled("no")


def test_open_seed_unset_creates_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv(SEED_OPEN_ROUNDS_ENV, raising=False)
    monkeypatch.delenv(SEED_MODERATORS_ENV, raising=False)
    state = build_state(tmp_path / "noseed.sqlite")
    for lottery_id in SEED_LOTTERIES:
        assert state.rounds.list(lottery_id) == []
    monkeypatch.setenv(SEED_OPEN_ROUNDS_ENV, "  ")
    blank = build_state(tmp_path / "blank.sqlite")
    for lottery_id in SEED_LOTTERIES:
        assert blank.rounds.list(lottery_id) == []


@pytest.mark.parametrize("flag", ["1", "true", "YES"])
def test_open_seed_creates_one_open_per_lottery(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, flag: str
) -> None:
    monkeypatch.setenv(SEED_OPEN_ROUNDS_ENV, flag)
    monkeypatch.delenv(SEED_MODERATORS_ENV, raising=False)
    db = tmp_path / f"open-{flag}.sqlite"
    state = build_state(db)
    for lottery_id in SEED_LOTTERIES:
        rounds = state.rounds.list(lottery_id)
        assert len(rounds) == 1
        assert rounds[0]["status"] == "OPEN"
        assert rounds[0]["code"] == f"dev-seed-open:{lottery_id}"
        assert rounds[0]["board_id"] is None  # no moderator seed → legacy null board
    # restart idempotent: still one OPEN each
    restarted = build_state(db)
    for lottery_id in SEED_LOTTERIES:
        assert _open_count(restarted, lottery_id) == 1
        assert len(restarted.rounds.list(lottery_id)) == 1


def test_open_seed_attaches_board_when_moderator_seeded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(SEED_MODERATORS_ENV, "alice:fujian-31,bob:demo-digit")
    monkeypatch.setenv(SEED_OPEN_ROUNDS_ENV, "1")
    state = build_state(tmp_path / "with-board.sqlite")
    for lottery_id in SEED_LOTTERIES:
        rounds = state.rounds.list(lottery_id)
        assert len(rounds) == 1 and rounds[0]["status"] == "OPEN"
        assert rounds[0]["board_id"] is not None
        board = state.moderator.store.get(rounds[0]["board_id"])
        assert board is not None and board["lottery_id"] == lottery_id


def test_open_seed_skips_when_open_already_exists(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv(SEED_OPEN_ROUNDS_ENV, raising=False)
    monkeypatch.delenv(SEED_MODERATORS_ENV, raising=False)
    db = tmp_path / "preexist.sqlite"
    state = build_state(db)
    created = state.rounds.create("demo-digit", code="manual")
    state.rounds.open(created["round_id"])  # type: ignore[arg-type]
    monkeypatch.setenv(SEED_OPEN_ROUNDS_ENV, "1")
    restarted = build_state(db)
    demo = restarted.rounds.list("demo-digit")
    assert len(demo) == 1 and demo[0]["code"] == "manual"
    # fujian-31 still gets a seed OPEN
    assert _open_count(restarted, "fujian-31") == 1
