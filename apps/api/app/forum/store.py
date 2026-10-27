import sqlite3
import uuid
from pathlib import Path

from app.db import connect


DEFAULT_BOARDS = (
    ("general", "综合讨论", "平台交流、规则说明与新手讨论", "", 0),
    ("fujian31", "福建31", "福建31选号、开奖与复盘讨论", "fujian-31", 10),
    ("number-pick", "数字选号", "数字选号玩法交流", "number-pick", 20),
    ("pailie3", "排列三", "排列三彩种交流区", "pailie-3", 30),
    ("kuaile8", "快乐8", "快乐8彩种交流区", "kuaile-8", 40),
)


class ForumStore:
    def __init__(self, path: str | Path = ":memory:", connection: sqlite3.Connection | None = None) -> None:
        self.connection = connection or connect(path)
        self.connection.executescript(
            """
            create table if not exists forum_boards (
                id text primary key,
                title text not null,
                description text not null default '',
                lottery_id text not null default '',
                sort_order integer not null default 0,
                enabled integer not null default 1 check (enabled in (0, 1))
            );
            create table if not exists forum_threads (
                id text primary key,
                board_id text not null references forum_boards(id),
                author_id text not null references accounts(account_id),
                title text not null,
                body text not null,
                pinned integer not null default 0 check (pinned in (0, 1)),
                locked integer not null default 0 check (locked in (0, 1)),
                created_at text not null,
                updated_at text not null
            );
            create table if not exists forum_thread_tags (
                thread_id text not null references forum_threads(id) on delete cascade,
                tag text not null,
                primary key(thread_id, tag)
            );
            create table if not exists forum_replies (
                id text primary key,
                thread_id text not null references forum_threads(id) on delete cascade,
                author_id text not null references accounts(account_id),
                body text not null,
                created_at text not null
            );
            create index if not exists idx_forum_threads_board_update
                on forum_threads(board_id, updated_at desc);
            create index if not exists idx_forum_threads_update
                on forum_threads(updated_at desc);
            create index if not exists idx_forum_replies_thread_created
                on forum_replies(thread_id, created_at asc);
            create index if not exists idx_forum_tags_tag
                on forum_thread_tags(tag);
            """
        )
        self.connection.executemany(
            """
            insert or ignore into forum_boards(id, title, description, lottery_id, sort_order, enabled)
            values (?, ?, ?, ?, ?, 1)
            """,
            DEFAULT_BOARDS,
        )
        self.connection.commit()

    def list_boards(self) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            select b.id, b.title, b.description, b.lottery_id, b.sort_order,
                   count(t.id) as thread_count
            from forum_boards b
            left join forum_threads t on t.board_id = b.id
            where b.enabled = 1
            group by b.id
            order by b.sort_order asc, b.id asc
            """
        ).fetchall()

    def board(self, board_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            "select id, title, description, lottery_id from forum_boards where id = ? and enabled = 1",
            (board_id,),
        ).fetchone()

    def create_thread(
        self,
        *,
        board_id: str,
        author_id: str,
        title: str,
        body: str,
        tags: list[str],
        created_at: str,
    ) -> str:
        thread_id = str(uuid.uuid4())
        self.connection.execute(
            """
            insert into forum_threads(id, board_id, author_id, title, body, created_at, updated_at)
            values (?, ?, ?, ?, ?, ?, ?)
            """,
            (thread_id, board_id, author_id, title, body, created_at, created_at),
        )
        self.connection.executemany(
            "insert or ignore into forum_thread_tags(thread_id, tag) values (?, ?)",
            [(thread_id, tag) for tag in tags],
        )
        self.connection.commit()
        return thread_id

    def add_reply(self, *, thread_id: str, author_id: str, body: str, created_at: str) -> str:
        reply_id = str(uuid.uuid4())
        self.connection.execute(
            "insert into forum_replies(id, thread_id, author_id, body, created_at) values (?, ?, ?, ?, ?)",
            (reply_id, thread_id, author_id, body, created_at),
        )
        self.connection.execute(
            "update forum_threads set updated_at = ? where id = ?",
            (created_at, thread_id),
        )
        self.connection.commit()
        return reply_id

    def thread_exists(self, thread_id: str) -> bool:
        return self.connection.execute(
            "select 1 from forum_threads where id = ?",
            (thread_id,),
        ).fetchone() is not None

    def thread_locked(self, thread_id: str) -> bool:
        row = self.connection.execute(
            "select locked from forum_threads where id = ?",
            (thread_id,),
        ).fetchone()
        return bool(row["locked"]) if row else False

    def list_threads(self, *, board_id: str | None = None, query: str = "", limit: int = 20) -> list[sqlite3.Row]:
        filters = []
        params: list[object] = []
        if board_id:
            filters.append("t.board_id = ?")
            params.append(board_id)
        if query:
            pattern = f"%{query}%"
            filters.append(
                "(t.title like ? or t.body like ? or exists (select 1 from forum_thread_tags ft where ft.thread_id = t.id and ft.tag like ?))"
            )
            params.extend([pattern, pattern, pattern])
        where = f"where {' and '.join(filters)}" if filters else ""
        params.append(limit)
        return self.connection.execute(
            f"""
            select t.id, t.board_id, b.title as board_title, t.author_id,
                   a.username as author_username, t.title, t.body, t.pinned, t.locked,
                   t.created_at, t.updated_at,
                   (select count(*) from forum_replies r where r.thread_id = t.id) as reply_count
            from forum_threads t
            join forum_boards b on b.id = t.board_id
            join accounts a on a.account_id = t.author_id
            {where}
            order by t.pinned desc, t.updated_at desc, t.created_at desc
            limit ?
            """,
            params,
        ).fetchall()

    def get_thread(self, thread_id: str) -> sqlite3.Row | None:
        return self.connection.execute(
            """
            select t.id, t.board_id, b.title as board_title, t.author_id,
                   a.username as author_username, t.title, t.body, t.pinned, t.locked,
                   t.created_at, t.updated_at,
                   (select count(*) from forum_replies r where r.thread_id = t.id) as reply_count
            from forum_threads t
            join forum_boards b on b.id = t.board_id
            join accounts a on a.account_id = t.author_id
            where t.id = ?
            """,
            (thread_id,),
        ).fetchone()

    def list_replies(self, thread_id: str) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            select r.id, r.thread_id, r.author_id, a.username as author_username, r.body, r.created_at
            from forum_replies r
            join accounts a on a.account_id = r.author_id
            where r.thread_id = ?
            order by r.created_at asc, r.rowid asc
            """,
            (thread_id,),
        ).fetchall()

    def tags_for_thread(self, thread_id: str) -> list[str]:
        rows = self.connection.execute(
            "select tag from forum_thread_tags where thread_id = ? order by tag asc",
            (thread_id,),
        ).fetchall()
        return [row["tag"] for row in rows]

    def hot_topics(self, limit: int = 6) -> list[sqlite3.Row]:
        return self.connection.execute(
            """
            select ft.tag, count(*) as thread_count, max(t.updated_at) as updated_at
            from forum_thread_tags ft
            join forum_threads t on t.id = ft.thread_id
            group by ft.tag
            order by thread_count desc, updated_at desc, ft.tag asc
            limit ?
            """,
            (limit,),
        ).fetchall()
