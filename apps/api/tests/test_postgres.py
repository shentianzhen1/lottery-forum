import os

import pytest

from app.ledger.postgres_store import MIGRATIONS


def test_migrations_cover_wallet_and_accounts() -> None:
    sql = "\n".join(path.read_text() for path in sorted(MIGRATIONS.glob("*.sql")))
    assert "points_entries" in sql
    assert "accounts" in sql
    assert "sessions" in sql
    assert "recharge" not in sql
    assert "withdraw" not in sql


@pytest.mark.skipif(not os.environ.get("DATABASE_URL"), reason="未设置 DATABASE_URL，本环境未连接 PostgreSQL")
def test_postgres_wallet_survives_new_connection() -> None:
    from app.auth.service import AuthService
    from app.auth.postgres_store import PostgresAccountStore
    from app.ledger.model import Direction, PostRequest, Reason
    from app.ledger.postgres_store import PostgresLedgerStore
    from app.ledger.service import LedgerService

    database_url = os.environ["DATABASE_URL"]
    ledger = LedgerService(PostgresLedgerStore(database_url))
    auth = AuthService(PostgresAccountStore(database_url), ledger)
    account, _token = auth.register("pg-user", "secret-pass")
    ledger.post(
        PostRequest(
            account_id=account.account_id,
            direction=Direction.CREDIT,
            amount=25,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id="pg-grant",
            idempotency_key="pg-grant",
            operator_id="system",
        )
    )
    ledger.store.connection.close()
    reopened = LedgerService(PostgresLedgerStore(database_url))
    assert reopened.balance(account.account_id) == 25
    reopened.store.connection.close()
