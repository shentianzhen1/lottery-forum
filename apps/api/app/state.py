from dataclasses import dataclass

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


@dataclass
class AppState:
    auth: AuthService
    ledger: LedgerService
    games: GameRegistry
    participation: GameParticipation


def build_state() -> AppState:
    ledger = LedgerService(SqliteLedgerStore())
    games = GameRegistry()
    return AppState(AuthService(AccountStore(), ledger), ledger, games, GameParticipation(games, ledger))
