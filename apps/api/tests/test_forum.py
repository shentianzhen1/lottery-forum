from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def register(prefix: str) -> tuple[str, str]:
    username = f"{prefix}-{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    assert response.status_code == 200
    return username, response.json()["token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_forum_home_is_public_and_has_real_boards_without_fake_threads() -> None:
    response = client.get("/api/v1/forum/home")
    assert response.status_code == 200
    body = response.json()
    ids = {row["id"] for row in body["boards"]}
    assert {"general", "fujian31", "number-pick", "pailie3", "kuaile8"} <= ids
    assert isinstance(body["latest_threads"], list)
    assert isinstance(body["hot_topics"], list)


def test_posting_requires_login() -> None:
    response = client.post(
        "/api/v1/forum/threads",
        json={"board_id": "fujian31", "title": "本期讨论", "body": "交流一下选号思路"},
    )
    assert response.status_code == 401


def test_logged_in_user_can_post_search_read_and_reply() -> None:
    username, token = register("forum-author")
    created = client.post(
        "/api/v1/forum/threads",
        headers=auth(token),
        json={
            "board_id": "fujian31",
            "title": "福建31 本期选号交流",
            "body": "只讨论思路，不展示虚假热度。",
            "tags": ["福建31讨论", "选号交流", "#选号交流"],
        },
    )
    assert created.status_code == 200
    thread = created.json()
    assert thread["author_username"] == username
    assert thread["tags"] == ["选号交流", "福建31讨论"]
    assert thread["reply_count"] == 0

    search = client.get("/api/v1/forum/threads", params={"q": "选号交流"})
    assert search.status_code == 200
    assert any(row["id"] == thread["id"] for row in search.json()["threads"])

    reply = client.post(
        f"/api/v1/forum/threads/{thread['id']}/replies",
        headers=auth(token),
        json={"body": "补充一条自己的分析。"},
    )
    assert reply.status_code == 200
    assert reply.json()["author_username"] == username

    detail = client.get(f"/api/v1/forum/threads/{thread['id']}")
    assert detail.status_code == 200
    assert detail.json()["reply_count"] == 1
    assert len(detail.json()["replies"]) == 1

    home = client.get("/api/v1/forum/home").json()
    topics = {row["tag"]: row["thread_count"] for row in home["hot_topics"]}
    assert topics["福建31讨论"] >= 1


def test_unknown_board_is_rejected() -> None:
    _, token = register("forum-invalid")
    response = client.post(
        "/api/v1/forum/threads",
        headers=auth(token),
        json={"board_id": "missing", "title": "测试标题", "body": "测试正文"},
    )
    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "BOARD_NOT_FOUND"
