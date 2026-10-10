import sqlite3
from pathlib import Path

from app.db import connect


class ModeratorStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists moderator_settings (
                setting_id text primary key,
                threshold integer not null check (threshold > 0)
            );
            insert or ignore into moderator_settings(setting_id, threshold) values ('default', 10000);
            create table if not exists moderator_boards (
                board_id text primary key,
                account_id text not null,
                lottery_id text not null,
                hold_id text not null,
                status text not null check (status in ('open')),
                unique (account_id, lottery_id)
            );
            """
        )

    def threshold(self) -> int:
        row = self.connection.execute(
            "select threshold from moderator_settings where setting_id = 'default'"
        ).fetchone()
        return int(row["threshold"])

    def set_threshold(self, amount: int) -> None:
        self.connection.execute(
            "update moderator_settings set threshold = ? where setting_id = 'default'",
            (amount,),
        )
        self.connection.commit()

    def find(self, account_id: str, lottery_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from moderator_boards where account_id = ? and lottery_id = ?",
            (account_id, lottery_id),
        ).fetchone()

    def add(self, board_id: str, account_id: str, lottery_id: str, hold_id: str) -> None:
        self.connection.execute(
            """
            insert into moderator_boards(board_id, account_id, lottery_id, hold_id, status)
            values (?, ?, ?, ?, 'open')
            """,
            (board_id, account_id, lottery_id, hold_id),
        )
        self.connection.commit()

    def boards_for(self, account_id: str) -> list[sqlite3.Row]:
        return self.connection.execute(
            "select * from moderator_boards where account_id = ? order by rowid",
            (account_id,),
        ).fetchall()
