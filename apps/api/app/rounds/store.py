import sqlite3
from pathlib import Path

from app.db import connect

ALLOWED_STATUSES = ("UPCOMING", "OPEN", "CLOSED", "DRAWN", "SETTLING", "SETTLED")


class RoundStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists rounds (
                round_id text primary key,
                lottery_id text not null,
                code text,
                status text not null check (
                    status in ('UPCOMING', 'OPEN', 'CLOSED', 'DRAWN', 'SETTLING', 'SETTLED')
                ),
                created_at text not null default (datetime('now'))
            );
            create index if not exists idx_rounds_lottery on rounds(lottery_id);
            """
        )

    def add(self, round_id: str, lottery_id: str, code: str | None, status: str = "UPCOMING") -> None:
        self.connection.execute(
            """
            insert into rounds(round_id, lottery_id, code, status)
            values (?, ?, ?, ?)
            """,
            (round_id, lottery_id, code, status),
        )
        self.connection.commit()

    def get(self, round_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from rounds where round_id = ?",
            (round_id,),
        ).fetchone()

    def list_for(self, lottery_id: str | None = None) -> list[sqlite3.Row]:
        if lottery_id:
            return self.connection.execute(
                "select * from rounds where lottery_id = ? order by rowid",
                (lottery_id,),
            ).fetchall()
        return self.connection.execute("select * from rounds order by rowid").fetchall()

    def set_status(self, round_id: str, status: str) -> None:
        self.connection.execute(
            "update rounds set status = ? where round_id = ?",
            (status, round_id),
        )
        self.connection.commit()
