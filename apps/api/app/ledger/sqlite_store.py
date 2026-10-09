import sqlite3
from pathlib import Path

from app.ledger.model import Direction, Entry, Reason


class SqliteLedgerStore:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("pragma foreign_keys = on")
        self.connection.executescript(
            """
            create table if not exists points_accounts (
                account_id text primary key,
                balance integer not null default 0 check (balance >= 0)
            );
            create table if not exists points_entries (
                entry_id text primary key,
                account_id text not null references points_accounts(account_id),
                direction text not null check (direction in ('credit', 'debit')),
                amount integer not null check (amount > 0),
                reason text not null check (reason in ('opening_grant', 'game_settlement', 'correction')),
                reference_type text not null,
                reference_id text not null,
                idempotency_key text not null,
                operator_id text not null,
                note text not null default '',
                corrects_entry_id text references points_entries(entry_id),
                unique (account_id, idempotency_key)
            );
            """
        )

    def ensure_account(self, account_id: str) -> None:
        self.connection.execute(
            "insert or ignore into points_accounts(account_id, balance) values (?, 0)",
            (account_id,),
        )
        self.connection.commit()

    def balance(self, account_id: str) -> int:
        row = self.connection.execute(
            "select balance from points_accounts where account_id = ?",
            (account_id,),
        ).fetchone()
        return int(row["balance"]) if row else 0

    def append(self, entry: Entry) -> None:
        delta = entry.amount if entry.direction is Direction.CREDIT else -entry.amount
        with self.connection:
            self.connection.execute(
                """
                insert into points_entries (
                    entry_id, account_id, direction, amount, reason, reference_type,
                    reference_id, idempotency_key, operator_id, note, corrects_entry_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                "update points_accounts set balance = balance + ? where account_id = ?",
                (delta, entry.account_id),
            )

    def entries(self, account_id: str) -> list[Entry]:
        rows = self.connection.execute(
            "select * from points_entries where account_id = ? order by rowid",
            (account_id,),
        ).fetchall()
        return [self._entry(row) for row in rows]

    def find_by_idempotency(self, account_id: str, idempotency_key: str) -> Entry | None:
        row = self.connection.execute(
            "select * from points_entries where account_id = ? and idempotency_key = ?",
            (account_id, idempotency_key),
        ).fetchone()
        return self._entry(row) if row else None

    def get(self, entry_id: str) -> Entry | None:
        row = self.connection.execute(
            "select * from points_entries where entry_id = ?",
            (entry_id,),
        ).fetchone()
        return self._entry(row) if row else None

    def _entry(self, row: sqlite3.Row) -> Entry:
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
