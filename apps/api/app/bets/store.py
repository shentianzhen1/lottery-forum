import json
import sqlite3
from pathlib import Path

from app.db import connect

ALLOWED_STATUSES = (
    "CREATED",
    "ACCEPTED",
    "LOCKED",
    "SETTLED",
    "REJECTED",
    "CANCELLED",
    "REFUNDED",
)


class BetStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists bets (
                bet_id text primary key,
                account_id text not null,
                round_id text not null,
                play_id text not null,
                rule_version text not null,
                status text not null check (
                    status in (
                        'CREATED', 'ACCEPTED', 'LOCKED', 'SETTLED',
                        'REJECTED', 'CANCELLED', 'REFUNDED'
                    )
                ),
                selection_json text not null,
                odds_snapshot_json text not null,
                hold_id text,
                stake integer not null check (stake > 0),
                idempotency_key text not null,
                created_at text not null default (datetime('now')),
                unique (account_id, idempotency_key)
            );
            create index if not exists idx_bets_round on bets(round_id);
            create index if not exists idx_bets_account on bets(account_id);
            """
        )

    def find_by_idempotency(self, account_id: str, idempotency_key: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from bets where account_id = ? and idempotency_key = ?",
            (account_id, idempotency_key),
        ).fetchone()

    def get(self, bet_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from bets where bet_id = ?",
            (bet_id,),
        ).fetchone()

    def add(
        self,
        bet_id: str,
        account_id: str,
        round_id: str,
        play_id: str,
        rule_version: str,
        status: str,
        selection: dict[str, object],
        odds_snapshot: dict[str, object],
        hold_id: str | None,
        stake: int,
        idempotency_key: str,
    ) -> None:
        self.connection.execute(
            """
            insert into bets(
                bet_id, account_id, round_id, play_id, rule_version, status,
                selection_json, odds_snapshot_json, hold_id, stake, idempotency_key
            )
            values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                bet_id,
                account_id,
                round_id,
                play_id,
                rule_version,
                status,
                json.dumps(selection, ensure_ascii=False),
                json.dumps(odds_snapshot, ensure_ascii=False),
                hold_id,
                stake,
                idempotency_key,
            ),
        )
        self.connection.commit()
