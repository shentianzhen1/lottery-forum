from app.home.store import HomeStore

HOME_BANNER_LIMIT = 5
HOME_ANNOUNCEMENT_LIMIT = 4


class HomeError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class HomeService:
    def __init__(self, store: HomeStore) -> None:
        self.store = store

    def list_banners(self) -> list[dict[str, object]]:
        rows = self.store.list_enabled_banners(HOME_BANNER_LIMIT)
        return [self._banner(row) for row in rows]

    def list_announcements(self) -> list[dict[str, object]]:
        rows = self.store.list_announcements(HOME_ANNOUNCEMENT_LIMIT)
        return [self._announcement(row) for row in rows]

    def get_announcement(self, announcement_id: str) -> dict[str, object]:
        row = self.store.get_announcement(announcement_id)
        if row is None:
            raise HomeError("ANNOUNCEMENT_NOT_FOUND", "公告不存在")
        return self._announcement(row)

    def seed_demo(self) -> None:
        """Optional demo rows for local demos; tests insert explicitly."""
        if self.store.list_enabled_banners(1) or self.store.list_announcements(1):
            return
        self.store.add_banner(
            "banner-demo-1",
            "多种玩法 积分体验",
            "积分账户，不提供充值提现",
            "home/default",
            sort_order=1,
            enabled=True,
        )
        self.store.add_announcement(
            "ann-demo-1",
            "欢迎体验彩票论坛",
            "本平台使用积分账户，不提供充值、提现或兑付。",
            published_at="2026-10-11T00:00:00Z",
            pinned=True,
        )

    def _banner(self, row: object) -> dict[str, object]:
        return {
            "id": row["id"],  # type: ignore[index]
            "title": row["title"],  # type: ignore[index]
            "subtitle": row["subtitle"],  # type: ignore[index]
            "image_key": row["image_key"],  # type: ignore[index]
            "sort_order": int(row["sort_order"]),  # type: ignore[index]
            "enabled": bool(row["enabled"]),  # type: ignore[index]
        }

    def _announcement(self, row: object) -> dict[str, object]:
        return {
            "id": row["id"],  # type: ignore[index]
            "title": row["title"],  # type: ignore[index]
            "body": row["body"],  # type: ignore[index]
            "published_at": row["published_at"],  # type: ignore[index]
            "pinned": bool(row["pinned"]),  # type: ignore[index]
        }
