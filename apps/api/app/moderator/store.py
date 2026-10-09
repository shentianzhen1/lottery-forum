import sqlite3
from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4


@dataclass(frozen=True)
class Application:
    application_id: str
    account_id: str
    statement: str
    status: str


class ModeratorStore:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.executescript(
            """
            create table if not exists moderator_applications (
                application_id text primary key,
                account_id text not null,
                statement text not null,
                status text not null check (status in ('pending', 'approved', 'rejected'))
            );
            """
        )

    def add(self, account_id: str, statement: str) -> Application:
        application = Application(str(uuid4()), account_id, statement, "pending")
        self.connection.execute(
            "insert into moderator_applications(application_id, account_id, statement, status) values (?, ?, ?, ?)",
            (application.application_id, application.account_id, application.statement, application.status),
        )
        self.connection.commit()
        return application

    def for_account(self, account_id: str) -> list[Application]:
        rows = self.connection.execute(
            "select * from moderator_applications where account_id = ? order by rowid",
            (account_id,),
        ).fetchall()
        return [self._application(row) for row in rows]

    def pending_for_account(self, account_id: str) -> Application | None:
        row = self.connection.execute(
            "select * from moderator_applications where account_id = ? and status = 'pending'",
            (account_id,),
        ).fetchone()
        return self._application(row) if row else None

    def _application(self, row: sqlite3.Row) -> Application:
        return Application(row["application_id"], row["account_id"], row["statement"], row["status"])
