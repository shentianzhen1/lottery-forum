import os
from dataclasses import dataclass
from pathlib import Path

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.db import connect
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.games.selections import SelectionStore
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore
from app.moderator.service import ModeratorService
from app.moderator.store import ModeratorStore
from app.rounds.service import RoundService
from app.rounds.store import RoundStore


@dataclass
class AppState:
    auth: AuthService
    ledger: LedgerService
    games: GameRegistry
    participation: GameParticipation
    selections: SelectionStore
    moderator: ModeratorService
    rounds: RoundService


def build_state(database: Path | None = None) -> AppState:
    database = database or Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
    if database.name != ":memory:":
        database.parent.mkdir(parents=True, exist_ok=True)
    connection = connect(database)
    ledger = LedgerService(SqliteLedgerStore(connection=connection))
    games = GameRegistry()
    return AppState(
        AuthService(AccountStore(connection=connection), ledger),
        ledger,
        games,
        GameParticipation(games, ledger),
        SelectionStore(connection=connection),
        ModeratorService(ModeratorStore(connection=connection), ledger),
        RoundService(RoundStore(connection=connection)),
    )
