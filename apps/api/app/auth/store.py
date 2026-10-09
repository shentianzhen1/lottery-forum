import sqlite3
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Account:
    account_id: str
    username: str
    password_hash: str
    role: str


class AccountStore:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
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
                account_id text not null references accounts(account_id)
            );
            """
        )

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

    def save_session(self, token_hash: str, account_id: str) -> None:
        self.connection.execute(
            "insert into sessions(token_hash, account_id) values (?, ?)",
            (token_hash, account_id),
        )
        self.connection.commit()

    def account_for_token(self, token_hash: str) -> Account | None:
        row = self.connection.execute(
            """
            select accounts.* from sessions
            join accounts on accounts.account_id = sessions.account_id
            where sessions.token_hash = ?
            """,
            (token_hash,),
        ).fetchone()
        return self._account(row) if row else None

    def _account(self, row: sqlite3.Row) -> Account:
        return Account(
            account_id=row["account_id"],
            username=row["username"],
            password_hash=row["password_hash"],
            role=row["role"],
        )
