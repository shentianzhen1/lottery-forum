import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4


@dataclass(frozen=True)
class Selection:
    selection_id: str
    account_id: str
    game_id: str
    numbers: list[int]
    pair_count: int
    idempotency_key: str


class SelectionStore:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute(
            """
            create table if not exists game_selections (
                selection_id text primary key,
                account_id text not null,
                game_id text not null,
                numbers text not null,
                pair_count integer not null,
                idempotency_key text not null,
                stake integer not null default 0,
                payout integer not null default 0,
                unique (account_id, game_id, idempotency_key)
            )
            """
        )

    def find(self, account_id: str, game_id: str, idempotency_key: str) -> Selection | None:
        row = self.connection.execute(
            "select * from game_selections where account_id = ? and game_id = ? and idempotency_key = ?",
            (account_id, game_id, idempotency_key),
        ).fetchone()
        return self._selection(row) if row else None

    def add(self, account_id: str, game_id: str, numbers: list[int], pair_count: int, idempotency_key: str) -> Selection:
        selection = Selection(str(uuid4()), account_id, game_id, numbers, pair_count, idempotency_key)
        self.connection.execute(
            """
            insert into game_selections(
                selection_id, account_id, game_id, numbers, pair_count, idempotency_key, stake, payout
            ) values (?, ?, ?, ?, ?, ?, 0, 0)
            """,
            (selection.selection_id, account_id, game_id, json.dumps(numbers), pair_count, idempotency_key),
        )
        self.connection.commit()
        return selection

    def for_account(self, account_id: str, game_id: str) -> list[Selection]:
        rows = self.connection.execute(
            "select * from game_selections where account_id = ? and game_id = ? order by rowid",
            (account_id, game_id),
        ).fetchall()
        return [self._selection(row) for row in rows]

    def _selection(self, row: sqlite3.Row) -> Selection:
        return Selection(
            row["selection_id"],
            row["account_id"],
            row["game_id"],
            json.loads(row["numbers"]),
            row["pair_count"],
            row["idempotency_key"],
        )
