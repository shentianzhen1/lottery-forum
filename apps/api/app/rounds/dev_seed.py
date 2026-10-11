"""本地开发 / 测试专用：启动时造 OPEN 期号。默认关闭，线上不要设置。

Only active when ``LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS`` is a truthy value
(``1`` / ``true`` / ``yes``, case-insensitive). When set, at startup seed one
``OPEN`` round each for ``demo-digit`` and ``fujian-31``:

1. if that lottery already has an ``OPEN`` round → skip (idempotent);
2. else create ``UPCOMING`` then advance to ``OPEN``;
3. if a moderator board for that lottery already exists (e.g. from
   ``LOTTERY_FORUM_DEV_SEED_MODERATORS``), attach its ``board_id``; otherwise
   create a legacy round with ``board_id=null`` (bets still work; WIN/LOSS
   finalize needs a board — open the moderator seed too).

There is no HTTP endpoint for this; when the env var is unset nothing happens.
"""
from __future__ import annotations

import logging
import os
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.moderator.store import ModeratorStore
    from app.rounds.service import RoundService

SEED_OPEN_ROUNDS_ENV = "LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS"
SEED_LOTTERIES = ("demo-digit", "fujian-31")
SEED_CODE_PREFIX = "dev-seed-open"

logger = logging.getLogger("lottery_forum.dev_seed")


def env_enabled(raw: str | None = None) -> bool:
    value = (raw if raw is not None else os.environ.get(SEED_OPEN_ROUNDS_ENV, "")).strip().lower()
    return value in ("1", "true", "yes")


def _board_id_for(moderator_store: "ModeratorStore | None", lottery_id: str) -> str | None:
    if moderator_store is None:
        return None
    return moderator_store.board_id_for_lottery(lottery_id)


def _has_open(rounds: "RoundService", lottery_id: str) -> bool:
    return any(row["status"] == "OPEN" for row in rounds.list(lottery_id))


def seed_open_rounds_from_env(
    rounds: "RoundService",
    moderator_store: "ModeratorStore | None" = None,
) -> list[dict[str, object]]:
    if not env_enabled():
        return []
    logger.warning("%s is set: seeding local OPEN rounds (dev/test only)", SEED_OPEN_ROUNDS_ENV)
    seeded: list[dict[str, object]] = []
    for lottery_id in SEED_LOTTERIES:
        if _has_open(rounds, lottery_id):
            existing = next(r for r in rounds.list(lottery_id) if r["status"] == "OPEN")
            seeded.append({"lottery_id": lottery_id, "skipped": True, **existing})
            continue
        board_id = _board_id_for(moderator_store, lottery_id)
        created = rounds.create(
            lottery_id,
            code=f"{SEED_CODE_PREFIX}:{lottery_id}",
            board_id=board_id,
        )
        opened = rounds.open(created["round_id"])  # type: ignore[arg-type]
        seeded.append({"lottery_id": lottery_id, "skipped": False, **opened})
    return seeded
