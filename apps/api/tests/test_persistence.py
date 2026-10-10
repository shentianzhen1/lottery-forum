from pathlib import Path

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.ledger.model import Direction, PostRequest, Reason
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


def test_balance_survives_reopening_the_database(tmp_path: Path) -> None:
    database = tmp_path / "wallet.sqlite"
    first = LedgerService(SqliteLedgerStore(database))
    first.post(
        PostRequest(
            account_id="user-1",
            direction=Direction.CREDIT,
            amount=40,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id="grant-1",
            idempotency_key="grant-1",
            operator_id="system",
        )
    )
    first.store.connection.close()
    second = LedgerService(SqliteLedgerStore(database))
    assert second.balance("user-1") == 40
    assert len(second.entries("user-1")) == 1


def test_account_and_ledger_share_reopened_database(tmp_path: Path) -> None:
    database = tmp_path / "shared.sqlite"
    accounts = AccountStore(database)
    ledger = LedgerService(SqliteLedgerStore(database))
    auth = AuthService(accounts, ledger)
    account, _token = auth.register("ada", "secret-pass")
    ledger.post(
        PostRequest(
            account_id=account.account_id,
            direction=Direction.CREDIT,
            amount=15,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id="grant-ada",
            idempotency_key="grant-ada",
            operator_id="system",
        )
    )
    accounts.connection.close()
    ledger.store.connection.close()
    reopened_accounts = AccountStore(database)
    reopened_ledger = LedgerService(SqliteLedgerStore(database))
    stored = reopened_accounts.by_username("ada")
    assert stored is not None
    assert stored.account_id == account.account_id
    assert reopened_ledger.balance(account.account_id) == 115
    assert reopened_ledger.entries(account.account_id)[0].account_id == stored.account_id
