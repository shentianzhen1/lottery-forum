import os
from pathlib import Path

from app.auth.postgres_store import PostgresAccountStore
from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.ledger.postgres_store import PostgresLedgerStore
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


class AppState:
    def __init__(self, auth: AuthService, ledger: LedgerService, games: GameRegistry, participation: GameParticipation) -> None:
        self.auth = auth
        self.ledger = ledger
        self.games = games
        self.participation = participation


def build_state() -> AppState:
    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        ledger = LedgerService(PostgresLedgerStore(database_url))
        accounts = PostgresAccountStore(database_url)
    else:
        database = Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
        if str(database) != ":memory:":
            database.parent.mkdir(parents=True, exist_ok=True)
        ledger = LedgerService(SqliteLedgerStore(database))
        accounts = AccountStore(database)
    games = GameRegistry()
    return AppState(AuthService(accounts, ledger), ledger, games, GameParticipation(games, ledger))
