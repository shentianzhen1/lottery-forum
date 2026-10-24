import sqlite3
from pathlib import Path

from app.db import connect


class DrawResultStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists draw_results (
                result_id text primary key,
                observation_id text not null unique,
                provider text not null,
                lottery_id text not null,
                raw_code text not null,
                normalized_code text not null,
                draw_date text not null,
                main_numbers_json text not null,
                extra_numbers_json text not null,
                content_hash text not null,
                source_version integer not null,
                confirmed_by text not null,
                confirmed_at text not null,
                status text not null check (status in ('CONFIRMED')),
                created_at text not null default (datetime('now')),
                unique (lottery_id, normalized_code),
                foreign key (observation_id) references draw_observations(observation_id)
            );
            create index if not exists idx_draw_results_lookup
              on draw_results(lottery_id, normalized_code, confirmed_at);
            """
        )

    def add(
        self,
        *,
        result_id: str,
        observation_id: str,
        provider: str,
        lottery_id: str,
        raw_code: str,
        normalized_code: str,
        draw_date: str,
        main_numbers_json: str,
        extra_numbers_json: str,
        content_hash: str,
        source_version: int,
        confirmed_by: str,
        confirmed_at: str,
    ) -> None:
        self.connection.execute(
            """
            insert into draw_results(
                result_id, observation_id, provider, lottery_id, raw_code,
                normalized_code, draw_date, main_numbers_json, extra_numbers_json,
                content_hash, source_version, confirmed_by, confirmed_at, status
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'CONFIRMED')
            """,
            (
                result_id,
                observation_id,
                provider,
                lottery_id,
                raw_code,
                normalized_code,
                draw_date,
                main_numbers_json,
                extra_numbers_json,
                content_hash,
                source_version,
                confirmed_by,
                confirmed_at,
            ),
        )
        self.connection.commit()

    def get_by_observation(self, observation_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from draw_results where observation_id = ?",
            (observation_id,),
        ).fetchone()

    def get_by_issue(self, lottery_id: str, normalized_code: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select * from draw_results where lottery_id = ? and normalized_code = ?",
            (lottery_id, normalized_code),
        ).fetchone()

    def list_results(
        self,
        *,
        lottery_id: str | None = None,
        normalized_code: str | None = None,
    ) -> list[sqlite3.Row]:
        clauses: list[str] = []
        values: list[str] = []
        if lottery_id:
            clauses.append("lottery_id = ?")
            values.append(lottery_id)
        if normalized_code:
            clauses.append("normalized_code = ?")
            values.append(normalized_code)
        where = f" where {' and '.join(clauses)}" if clauses else ""
        return self.connection.execute(
            f"select * from draw_results{where} order by confirmed_at desc, rowid desc",
            values,
        ).fetchall()
