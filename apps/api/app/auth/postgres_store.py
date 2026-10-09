import psycopg
from psycopg.rows import dict_row

from app.auth.store import Account
from app.ledger.postgres_store import apply_migrations


class PostgresAccountStore:
    def __init__(self, database_url: str) -> None:
        self.connection = psycopg.connect(database_url, row_factory=dict_row)
        apply_migrations(self.connection)

    def create(self, account: Account) -> None:
        self.connection.execute(
            "insert into accounts(account_id, username, password_hash, role) values (%s, %s, %s, %s)",
            (account.account_id, account.username, account.password_hash, account.role),
        )
        self.connection.commit()

    def by_username(self, username: str) -> Account | None:
        row = self.connection.execute(
            "select * from accounts where username = %s",
            (username,),
        ).fetchone()
        return self._account(row) if row else None

    def by_id(self, account_id: str) -> Account | None:
        row = self.connection.execute(
            "select * from accounts where account_id = %s",
            (account_id,),
        ).fetchone()
        return self._account(row) if row else None

    def save_session(self, token_hash: str, account_id: str) -> None:
        self.connection.execute(
            "insert into sessions(token_hash, account_id) values (%s, %s)",
            (token_hash, account_id),
        )
        self.connection.commit()

    def account_for_token(self, token_hash: str) -> Account | None:
        row = self.connection.execute(
            """
            select accounts.* from sessions
            join accounts on accounts.account_id = sessions.account_id
            where sessions.token_hash = %s
            """,
            (token_hash,),
        ).fetchone()
        return self._account(row) if row else None

    def _account(self, row: dict) -> Account:
        return Account(row["account_id"], row["username"], row["password_hash"], row["role"])
