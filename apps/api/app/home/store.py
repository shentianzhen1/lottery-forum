import sqlite3
from pathlib import Path

from app.db import connect


class HomeStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists home_banners (
                id text primary key,
                title text not null,
                subtitle text not null default '',
                image_key text not null default '',
                sort_order integer not null default 0,
                enabled integer not null default 1 check (enabled in (0, 1))
            );
            create table if not exists home_announcements (
                id text primary key,
                title text not null,
                body text not null default '',
                published_at text not null,
                pinned integer not null default 0 check (pinned in (0, 1))
            );
            create index if not exists idx_home_banners_enabled_sort
                on home_banners(enabled, sort_order);
            create index if not exists idx_home_announcements_pin_pub
                on home_announcements(pinned, published_at);
            """
        )

    def add_banner(
        self,
        banner_id: str,
        title: str,
        subtitle: str = "",
        image_key: str = "",
        sort_order: int = 0,
        enabled: bool = True,
    ) -> None:
        self.connection.execute(
            """
            insert into home_banners(id, title, subtitle, image_key, sort_order, enabled)
            values (?, ?, ?, ?, ?, ?)
            """,
            (banner_id, title, subtitle, image_key, sort_order, 1 if enabled else 0),
        )
        self.connection.commit()

    def add_announcement(
        self,
        announcement_id: str,
        title: str,
        body: str = "",
        published_at: str = "",
        pinned: bool = False,
    ) -> None:
        self.connection.execute(
            """
            insert into home_announcements(id, title, body, published_at, pinned)
            values (?, ?, ?, ?, ?)
            """,
            (announcement_id, title, body, published_at, 1 if pinned else 0),
        )
        self.connection.commit()

    def list_enabled_banners(self, limit: int = 5) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            select id, title, subtitle, image_key, sort_order, enabled
            from home_banners
            where enabled = 1
            order by sort_order asc, rowid asc
            limit ?
            """,
            (limit,),
        ).fetchall()

    def list_announcements(self, limit: int = 4) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            select id, title, body, published_at, pinned
            from home_announcements
            order by pinned desc, published_at desc, rowid desc
            limit ?
            """,
            (limit,),
        ).fetchall()

    def get_announcement(self, announcement_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            """
            select id, title, body, published_at, pinned
            from home_announcements
            where id = ?
            """,
            (announcement_id,),
        ).fetchone()

