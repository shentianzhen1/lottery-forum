"""本地开发 / 测试专用：启动时造版主。默认关闭，线上不要设置。

Only active when ``LOTTERY_FORUM_DEV_SEED_MODERATORS`` is set, e.g.
``alice:fujian-31,bob:demo-digit`` (username:lottery_id pairs). For each pair, at startup:

1. create the account if missing (password from ``LOTTERY_FORUM_DEV_SEED_PASSWORD``, default
   ``secret-pass``; existing accounts keep their password) — normal 100 opening grant applies;
2. credit exactly the moderator threshold via a ledger entry (reason ``opening_grant``,
   reference_type ``dev_seed``, idempotency key ``dev-seed:moderator:<lottery_id>``);
3. open the board through ``ModeratorService.open_board`` (freezes the threshold as usual).

Every step is idempotent, so restarting with the same env does not add points or boards.
There is no HTTP endpoint for this; when the env var is unset nothing happens.
"""
import logging
import os

from app.auth.service import AuthService
from app.ledger.model import Direction, PostRequest, Reason
from app.ledger.service import LedgerService
from app.moderator.service import ModeratorService

SEED_MODERATORS_ENV = "LOTTERY_FORUM_DEV_SEED_MODERATORS"
SEED_PASSWORD_ENV = "LOTTERY_FORUM_DEV_SEED_PASSWORD"
DEFAULT_SEED_PASSWORD = "secret-pass"

logger = logging.getLogger("lottery_forum.dev_seed")


def parse_pairs(raw: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        username, sep, lottery_id = item.partition(":")
        if not sep or not username.strip() or not lottery_id.strip():
            raise ValueError(f"{SEED_MODERATORS_ENV} 格式应为 username:lottery_id，收到 {item!r}")
        pairs.append((username.strip(), lottery_id.strip()))
    return pairs


def seed_moderators_from_env(
    auth: AuthService,
    ledger: LedgerService,
    moderator: ModeratorService,
) -> list[dict[str, object]]:
    raw = os.environ.get(SEED_MODERATORS_ENV, "").strip()
    if not raw:
        return []
    password = os.environ.get(SEED_PASSWORD_ENV) or DEFAULT_SEED_PASSWORD
    logger.warning("%s is set: seeding local moderators (dev/test only)", SEED_MODERATORS_ENV)
    seeded: list[dict[str, object]] = []
    for username, lottery_id in parse_pairs(raw):
        account = auth.accounts.by_username(username) or auth.create_account(username, password)
        threshold = moderator.store.threshold()
        key = f"dev-seed:moderator:{lottery_id}"
        ledger.post(
            PostRequest(
                account_id=account.account_id,
                direction=Direction.CREDIT,
                amount=threshold,
                reason=Reason.OPENING_GRANT,
                reference_type="dev_seed",
                reference_id=key,
                idempotency_key=key,
                operator_id="dev_seed",
                note="本地开发种子：版主门槛积分，仅限本地/测试",
            )
        )
        board = moderator.open_board(account.account_id, lottery_id)
        if "code" in board:
            raise RuntimeError(f"dev seed 无法为 {username} 开版块 {lottery_id}: {board}")
        seeded.append({"username": username, "account_id": account.account_id, **board})
    return seeded
