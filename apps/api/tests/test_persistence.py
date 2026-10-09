from pathlib import Path

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
