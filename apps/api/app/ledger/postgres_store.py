from pathlib import Path

import psycopg
from psycopg.rows import dict_row

from app.ledger.model import Direction, Entry, Reason

MIGRATIONS = Path(__file__).resolve().parents[2] / "migrations"


def connect(database_url: str) -> psycopg.Connection:
    connection = psycopg.connect(database_url, row_factory=dict_row)
    apply_migrations(connection)
    return connection


def apply_migrations(connection: psycopg.Connection) -> None:
    for path in sorted(MIGRATIONS.glob("*.sql")):
        connection.execute(path.read_text())
    connection.commit()


class PostgresLedgerStore:
    def __init__(self, database_url: str) -> None:
        self.connection = connect(database_url)

    def ensure_account(self, account_id: str) -> None:
        self.connection.execute(
            "insert into points_accounts(account_id, balance) values (%s, 0) on conflict (account_id) do nothing",
            (account_id,),
        )
        self.connection.commit()

    def balance(self, account_id: str) -> int:
        row = self.connection.execute(
            "select balance from points_accounts where account_id = %s",
            (account_id,),
        ).fetchone()
        return int(row["balance"]) if row else 0

    def append(self, entry: Entry) -> None:
        delta = entry.amount if entry.direction is Direction.CREDIT else -entry.amount
        with self.connection.transaction():
            self.connection.execute(
                """
                insert into points_entries (
                    entry_id, account_id, direction, amount, reason, reference_type,
                    reference_id, idempotency_key, operator_id, note, corrects_entry_id
                ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    entry.entry_id,
                    entry.account_id,
                    entry.direction.value,
                    entry.amount,
                    entry.reason.value,
                    entry.reference_type,
                    entry.reference_id,
                    entry.idempotency_key,
                    entry.operator_id,
                    entry.note,
                    entry.corrects_entry_id,
                ),
            )
            self.connection.execute(
                "update points_accounts set balance = balance + %s where account_id = %s",
                (delta, entry.account_id),
            )

    def entries(self, account_id: str) -> list[Entry]:
        rows = self.connection.execute(
            "select * from points_entries where account_id = %s order by created_at, entry_id",
            (account_id,),
        ).fetchall()
        return [self._entry(row) for row in rows]

    def find_by_idempotency(self, account_id: str, idempotency_key: str) -> Entry | None:
        row = self.connection.execute(
            "select * from points_entries where account_id = %s and idempotency_key = %s",
            (account_id, idempotency_key),
        ).fetchone()
        return self._entry(row) if row else None

    def get(self, entry_id: str) -> Entry | None:
        row = self.connection.execute(
            "select * from points_entries where entry_id = %s",
            (entry_id,),
        ).fetchone()
        return self._entry(row) if row else None

    def _entry(self, row: dict) -> Entry:
        return Entry(
            entry_id=row["entry_id"],
            account_id=row["account_id"],
            direction=Direction(row["direction"]),
            amount=row["amount"],
            reason=Reason(row["reason"]),
            reference_type=row["reference_type"],
            reference_id=row["reference_id"],
            idempotency_key=row["idempotency_key"],
            operator_id=row["operator_id"],
            note=row["note"],
            corrects_entry_id=row["corrects_entry_id"],
        )
