import sqlite3
from pathlib import Path

from app.db import connect

ALLOWED_RESULTS = ("WIN", "LOSS", "VOID")


class SettlementStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists settlements (
                settlement_id text primary key,
                round_id text not null,
                bet_id text not null,
                result text not null check (result in ('WIN', 'LOSS', 'VOID')),
                created_at text not null default (datetime('now')),
                unique (bet_id)
            );
            create index if not exists idx_settlements_round on settlements(round_id);
            """
        )

    def add(self, settlement_id: str, round_id: str, bet_id: str, result: str) -> None:
        self.connection.execute(
            """
            insert into settlements(settlement_id, round_id, bet_id, result)
            values (?, ?, ?, ?)
            """,
            (settlement_id, round_id, bet_id, result),
        )
        self.connection.commit()

    def get_by_bet(self, bet_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from settlements where bet_id = ?",
            (bet_id,),
        ).fetchone()

    def list_for_round(self, round_id: str) -> list[sqlite3.Row]:
        return self.connection.execute(
            "select * from settlements where round_id = ? order by rowid",
            (round_id,),
        ).fetchall()
