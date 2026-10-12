from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _home():
    return app.state.services.home


def test_banners_empty_without_seed() -> None:
    response = client.get("/api/v1/home/banners")
    assert response.status_code == 200
    assert response.json() == {"banners": []}


def test_announcements_empty_without_seed() -> None:
    response = client.get("/api/v1/home/announcements")
    assert response.status_code == 200
    assert response.json() == {"announcements": []}


def test_banners_public_no_auth() -> None:
    # same as GET /games — home reads are public
    response = client.get("/api/v1/home/banners")
    assert response.status_code == 200
    assert "banners" in response.json()


def test_banners_enabled_sorted_and_max_five() -> None:
    store = _home().store
    store.add_banner("b-off", "关闭", "x", "img", sort_order=0, enabled=False)
    store.add_banner("b-3", "三", "s3", "i3", sort_order=30, enabled=True)
    store.add_banner("b-1", "一", "s1", "i1", sort_order=10, enabled=True)
    store.add_banner("b-2", "二", "s2", "i2", sort_order=20, enabled=True)
    store.add_banner("b-4", "四", "s4", "i4", sort_order=40, enabled=True)
    store.add_banner("b-5", "五", "s5", "i5", sort_order=50, enabled=True)
    store.add_banner("b-6", "六超限", "s6", "i6", sort_order=60, enabled=True)

    response = client.get("/api/v1/home/banners")
    assert response.status_code == 200
    banners = response.json()["banners"]
    assert len(banners) == 5
    assert [b["id"] for b in banners] == ["b-1", "b-2", "b-3", "b-4", "b-5"]
    assert all(b["enabled"] is True for b in banners)
    assert banners[0] == {
        "id": "b-1",
        "title": "一",
        "subtitle": "s1",
        "image_key": "i1",
        "sort_order": 10,
        "enabled": True,
    }


def test_announcements_pinned_first_then_published_desc_max_four() -> None:
    store = _home().store
    store.add_announcement("a-old", "旧", "body-old", "2026-01-01T00:00:00Z", pinned=False)
    store.add_announcement("a-mid", "中", "body-mid", "2026-06-01T00:00:00Z", pinned=False)
    store.add_announcement("a-new", "新", "body-new", "2026-09-01T00:00:00Z", pinned=False)
    store.add_announcement("a-pin", "置顶公告", "body-pin", "2026-03-01T00:00:00Z", pinned=True)
    store.add_announcement("a-extra", "超限", "body-extra", "2026-08-01T00:00:00Z", pinned=False)

    response = client.get("/api/v1/home/announcements")
    assert response.status_code == 200
    items = response.json()["announcements"]
    assert len(items) == 4
    assert items[0]["id"] == "a-pin"
    assert items[0]["pinned"] is True
    assert items[0]["title"] == "置顶公告"
    assert [i["id"] for i in items[1:]] == ["a-new", "a-extra", "a-mid"]
    assert items[1]["body"] == "body-new"


def test_seed_demo_loads_when_empty() -> None:
    # Use a fresh service path via seed_demo on current empty-or-not store;
    # after prior tests store may already have rows — only assert shape when seeding empty DB.
    from app.db import connect
    from app.home.service import HomeService
    from app.home.store import HomeStore

    connection = connect(":memory:")
    service = HomeService(HomeStore(connection=connection))
    assert service.list_banners() == []
    assert service.list_announcements() == []
    service.seed_demo()
    banners = service.list_banners()
    announcements = service.list_announcements()
    assert len(banners) == 1
    assert banners[0]["title"] == "多种玩法 积分体验"
    assert len(announcements) == 1
    assert announcements[0]["pinned"] is True
    # idempotent
    service.seed_demo()
    assert len(service.list_banners()) == 1


def test_announcement_detail_by_id() -> None:
    store = _home().store
    store.add_announcement(
        "a-detail",
        "详情标题",
        "详情正文全文",
        "2026-10-12T12:00:00Z",
        pinned=True,
    )

    response = client.get("/api/v1/home/announcements/a-detail")
    assert response.status_code == 200
    assert response.json() == {
        "id": "a-detail",
        "title": "详情标题",
        "body": "详情正文全文",
        "published_at": "2026-10-12T12:00:00Z",
        "pinned": True,
    }


def test_announcement_detail_not_found() -> None:
    response = client.get("/api/v1/home/announcements/does-not-exist")
    assert response.status_code == 404
    assert response.json()["detail"] == {
        "code": "ANNOUNCEMENT_NOT_FOUND",
        "message": "公告不存在",
    }


def test_announcement_detail_public_no_auth() -> None:
    store = _home().store
    store.add_announcement("a-public", "公开", "body", "2026-10-01T00:00:00Z", pinned=False)
    # no Authorization header
    response = client.get("/api/v1/home/announcements/a-public")
    assert response.status_code == 200
    assert response.json()["id"] == "a-public"
    assert response.json()["title"] == "公开"
