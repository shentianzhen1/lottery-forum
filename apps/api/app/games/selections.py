import json
import sqlite3
import threading
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


class SelectionConflict(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class SelectionStore:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.lock = threading.RLock()
        self.connection.execute("pragma busy_timeout = 5000")
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

    def save(
        self,
        account_id: str,
        game_id: str,
        numbers: list[int],
        pair_count: int,
        idempotency_key: str,
    ) -> Selection:
        with self.lock:
            existing = self.find(account_id, game_id, idempotency_key)
            if existing is not None:
                self._ensure_same(existing, numbers)
                return existing
            try:
                return self.add(account_id, game_id, numbers, pair_count, idempotency_key)
            except sqlite3.IntegrityError:
                existing = self.find(account_id, game_id, idempotency_key)
                if existing is None:
                    raise
                self._ensure_same(existing, numbers)
                return existing

    def for_account(
        self,
        account_id: str,
        game_id: str,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[Selection], int]:
        limit = min(max(limit, 1), 100)
        offset = max(offset, 0)
        with self.lock:
            total = self.connection.execute(
                "select count(*) as total from game_selections where account_id = ? and game_id = ?",
                (account_id, game_id),
            ).fetchone()["total"]
            rows = self.connection.execute(
                """
                select * from game_selections
                where account_id = ? and game_id = ?
                order by rowid limit ? offset ?
                """,
                (account_id, game_id, limit, offset),
            ).fetchall()
            return [self._selection(row) for row in rows], int(total)

    def _ensure_same(self, existing: Selection, numbers: list[int]) -> None:
        if existing.numbers != numbers:
            raise SelectionConflict("IDEMPOTENCY_CONFLICT", "相同幂等键不能保存不同号码")

    def _selection(self, row: sqlite3.Row) -> Selection:
        return Selection(
            row["selection_id"],
            row["account_id"],
            row["game_id"],
            json.loads(row["numbers"]),
            row["pair_count"],
            row["idempotency_key"],
        )
