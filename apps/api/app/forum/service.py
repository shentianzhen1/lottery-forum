from __future__ import annotations

from datetime import datetime, timezone

from app.forum.store import ForumStore


class ForumError(ValueError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class ForumService:
    def __init__(self, store: ForumStore) -> None:
        self.store = store

    def home(self) -> dict[str, object]:
        return {
            "boards": [self._board(row) for row in self.store.list_boards()],
            "latest_threads": [self._thread(row) for row in self.store.list_threads(limit=8)],
            "hot_topics": [
                {
                    "tag": row["tag"],
                    "thread_count": row["thread_count"],
                    "updated_at": row["updated_at"],
                }
                for row in self.store.hot_topics()
            ],
        }

    def boards(self) -> list[dict[str, object]]:
        return [self._board(row) for row in self.store.list_boards()]

    def threads(self, *, board_id: str | None = None, query: str = "", limit: int = 20) -> list[dict[str, object]]:
        if board_id and self.store.board(board_id) is None:
            raise ForumError("BOARD_NOT_FOUND", "板块不存在")
        cleaned_query = query.strip()[:80]
        bounded_limit = max(1, min(limit, 50))
        return [self._thread(row) for row in self.store.list_threads(board_id=board_id, query=cleaned_query, limit=bounded_limit)]

    def thread(self, thread_id: str) -> dict[str, object]:
        row = self.store.get_thread(thread_id)
        if row is None:
            raise ForumError("THREAD_NOT_FOUND", "帖子不存在")
        payload = self._thread(row)
        payload["replies"] = [
            {
                "id": reply["id"],
                "thread_id": reply["thread_id"],
                "author_id": reply["author_id"],
                "author_username": reply["author_username"],
                "body": reply["body"],
                "created_at": reply["created_at"],
            }
            for reply in self.store.list_replies(thread_id)
        ]
        return payload

    def create_thread(
        self,
        *,
        account_id: str,
        board_id: str,
        title: str,
        body: str,
        tags: list[str] | None = None,
    ) -> dict[str, object]:
        board_id = board_id.strip()
        if self.store.board(board_id) is None:
            raise ForumError("BOARD_NOT_FOUND", "板块不存在")
        title = title.strip()
        body = body.strip()
        if len(title) < 2 or len(title) > 80:
            raise ForumError("INVALID_TITLE", "标题长度需为2到80个字符")
        if len(body) < 2 or len(body) > 5000:
            raise ForumError("INVALID_BODY", "正文长度需为2到5000个字符")
        cleaned_tags = self._clean_tags(tags or [])
        thread_id = self.store.create_thread(
            board_id=board_id,
            author_id=account_id,
            title=title,
            body=body,
            tags=cleaned_tags,
            created_at=self._now(),
        )
        return self.thread(thread_id)

    def reply(self, *, account_id: str, thread_id: str, body: str) -> dict[str, object]:
        if not self.store.thread_exists(thread_id):
            raise ForumError("THREAD_NOT_FOUND", "帖子不存在")
        if self.store.thread_locked(thread_id):
            raise ForumError("THREAD_LOCKED", "帖子已锁定")
        body = body.strip()
        if len(body) < 1 or len(body) > 2000:
            raise ForumError("INVALID_REPLY", "回复长度需为1到2000个字符")
        reply_id = self.store.add_reply(
            thread_id=thread_id,
            author_id=account_id,
            body=body,
            created_at=self._now(),
        )
        thread = self.thread(thread_id)
        for reply in thread["replies"]:
            if reply["id"] == reply_id:
                return reply
        raise RuntimeError("reply was not persisted")

    def _board(self, row) -> dict[str, object]:
        return {
            "id": row["id"],
            "title": row["title"],
            "description": row["description"],
            "lottery_id": row["lottery_id"],
            "thread_count": row["thread_count"],
        }

    def _thread(self, row) -> dict[str, object]:
        return {
            "id": row["id"],
            "board_id": row["board_id"],
            "board_title": row["board_title"],
            "author_id": row["author_id"],
            "author_username": row["author_username"],
            "title": row["title"],
            "body": row["body"],
            "tags": self.store.tags_for_thread(row["id"]),
            "pinned": bool(row["pinned"]),
            "locked": bool(row["locked"]),
            "reply_count": row["reply_count"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    @staticmethod
    def _clean_tags(tags: list[str]) -> list[str]:
        cleaned: list[str] = []
        for raw in tags[:5]:
            tag = raw.strip().lstrip("#")[:20]
            if tag and tag not in cleaned:
                cleaned.append(tag)
        return cleaned

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat(timespec="seconds")
