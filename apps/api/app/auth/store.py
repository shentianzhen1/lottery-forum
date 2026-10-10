import sqlite3
from dataclasses import dataclass
from pathlib import Path

from app.db import connect


@dataclass(frozen=True)
class Account:
    account_id: str
    username: str
    password_hash: str
    role: str


class AccountStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists accounts (
                account_id text primary key,
                username text not null unique,
                password_hash text not null,
                role text not null
            );
            create table if not exists sessions (
                token_hash text primary key,
                account_id text not null references accounts(account_id),
                expires_at text not null default ''
            );
            """
        )
        columns = {row[1] for row in self.connection.execute("pragma table_info(sessions)")}
        if "expires_at" not in columns:
            self.connection.execute("alter table sessions add column expires_at text not null default ''")

    def create(self, account: Account) -> None:
        self.connection.execute(
            "insert into accounts(account_id, username, password_hash, role) values (?, ?, ?, ?)",
            (account.account_id, account.username, account.password_hash, account.role),
        )
        self.connection.commit()

    def by_username(self, username: str) -> Account | None:
        row = self.connection.execute(
            "select * from accounts where username = ?",
            (username,),
        ).fetchone()
        return self._account(row) if row else None

    def by_id(self, account_id: str) -> Account | None:
        row = self.connection.execute(
            "select * from accounts where account_id = ?",
            (account_id,),
        ).fetchone()
        return self._account(row) if row else None

    def save_session(self, token_hash: str, account_id: str, expires_at: str) -> None:
        self.connection.execute(
            "insert into sessions(token_hash, account_id, expires_at) values (?, ?, ?)",
            (token_hash, account_id, expires_at),
        )
        self.connection.commit()

    def delete_session(self, token_hash: str) -> None:
        self.connection.execute("delete from sessions where token_hash = ?", (token_hash,))
        self.connection.commit()

    def account_for_token(self, token_hash: str, now: str) -> Account | None:
        row = self.connection.execute(
            """
            select accounts.* from sessions
            join accounts on accounts.account_id = sessions.account_id
            where sessions.token_hash = ? and sessions.expires_at > ?
            """,
            (token_hash, now),
        ).fetchone()
        return self._account(row) if row else None

    def _account(self, row: sqlite3.Row) -> Account:
        return Account(
            account_id=row["account_id"],
            username=row["username"],
            password_hash=row["password_hash"],
            role=row["role"],
        )
