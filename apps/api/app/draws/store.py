import sqlite3
from pathlib import Path

from app.db import connect


class DrawObservationStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists draw_observations (
                observation_id text primary key,
                provider text not null,
                lottery_id text not null,
                raw_code text not null,
                normalized_code text not null,
                draw_date text not null,
                main_numbers_json text not null,
                extra_numbers_json text not null,
                raw_payload_json text not null,
                content_hash text not null,
                fetched_at text not null,
                version integer not null,
                status text not null check (status in ('PENDING_REVIEW')),
                created_at text not null default (datetime('now')),
                unique (provider, lottery_id, normalized_code, content_hash),
                unique (provider, lottery_id, normalized_code, version)
            );
            create index if not exists idx_draw_observations_lookup
              on draw_observations(lottery_id, normalized_code, provider, version);
            """
        )

    def find_exact(
        self,
        provider: str,
        lottery_id: str,
        normalized_code: str,
        content_hash: str,
    ) -> sqlite3.Row | None:
        return self.connection.execute(
            """
            select * from draw_observations
            where provider = ? and lottery_id = ? and normalized_code = ? and content_hash = ?
            """,
            (provider, lottery_id, normalized_code, content_hash),
        ).fetchone()

    def next_version(self, provider: str, lottery_id: str, normalized_code: str) -> int:
        row = self.connection.execute(
            """
            select coalesce(max(version), 0) as current_version
            from draw_observations
            where provider = ? and lottery_id = ? and normalized_code = ?
            """,
            (provider, lottery_id, normalized_code),
        ).fetchone()
        return int(row["current_version"]) + 1

    def add(
        self,
        *,
        observation_id: str,
        provider: str,
        lottery_id: str,
        raw_code: str,
        normalized_code: str,
        draw_date: str,
        main_numbers_json: str,
        extra_numbers_json: str,
        raw_payload_json: str,
        content_hash: str,
        fetched_at: str,
        version: int,
        status: str,
    ) -> None:
        self.connection.execute(
            """
            insert into draw_observations(
                observation_id, provider, lottery_id, raw_code, normalized_code,
                draw_date, main_numbers_json, extra_numbers_json, raw_payload_json,
                content_hash, fetched_at, version, status
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                observation_id,
                provider,
                lottery_id,
                raw_code,
                normalized_code,
                draw_date,
                main_numbers_json,
                extra_numbers_json,
                raw_payload_json,
                content_hash,
                fetched_at,
                version,
                status,
            ),
        )
        self.connection.commit()

    def get(self, observation_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from draw_observations where observation_id = ?",
            (observation_id,),
        ).fetchone()

    def list(
        self,
        *,
        lottery_id: str | None = None,
        normalized_code: str | None = None,
        provider: str | None = None,
    ) -> list[sqlite3.Row]:
        clauses: list[str] = []
        values: list[str] = []
        if lottery_id:
            clauses.append("lottery_id = ?")
            values.append(lottery_id)
        if normalized_code:
            clauses.append("normalized_code = ?")
            values.append(normalized_code)
        if provider:
            clauses.append("provider = ?")
            values.append(provider)
        where = f" where {' and '.join(clauses)}" if clauses else ""
        return self.connection.execute(
            f"select * from draw_observations{where} order by created_at desc, rowid desc",
            values,
        ).fetchall()
