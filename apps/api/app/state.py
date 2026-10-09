from dataclasses import dataclass

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.games.selections import SelectionStore
from app.ledger.service import LedgerService
import os
from pathlib import Path

from app.ledger.sqlite_store import SqliteLedgerStore


@dataclass
class AppState:
    auth: AuthService
    ledger: LedgerService
    games: GameRegistry
    participation: GameParticipation
    selections: SelectionStore


def build_state() -> AppState:
    database = Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
    if database.name != ":memory:":
        database.parent.mkdir(parents=True, exist_ok=True)
    ledger = LedgerService(SqliteLedgerStore(database))
    games = GameRegistry()
    return AppState(
        AuthService(AccountStore(database), ledger),
        ledger,
        games,
        GameParticipation(games, ledger),
        SelectionStore(database),
    )
