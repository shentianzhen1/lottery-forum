from dataclasses import dataclass

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


@dataclass
class AppState:
    auth: AuthService
    ledger: LedgerService


def build_state() -> AppState:
    ledger = LedgerService(SqliteLedgerStore())
    return AppState(AuthService(AccountStore(), ledger), ledger)
