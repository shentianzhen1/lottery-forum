from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def token(username: str) -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    return response.json()["token"]


def test_apply_is_pending_and_visible_only_to_owner() -> None:
    owner = token("mod-a")
    other = token("mod-b")
    created = client.post(
        "/api/v1/moderator/applications",
        headers={"Authorization": f"Bearer {owner}"},
        json={"statement": "希望维护玩法说明和公告。"},
    )
    assert created.status_code == 200
    assert created.json()["status"] == "pending"
    own = client.get("/api/v1/moderator/applications", headers={"Authorization": f"Bearer {owner}"})
    other_view = client.get("/api/v1/moderator/applications", headers={"Authorization": f"Bearer {other}"})
    assert len(own.json()["applications"]) == 1
    assert other_view.json()["applications"] == []


def test_duplicate_pending_application_is_rejected() -> None:
    owner = token("mod-c")
    headers = {"Authorization": f"Bearer {owner}"}
    payload = {"statement": "第二次申请不应并列待审核。"}
    assert client.post("/api/v1/moderator/applications", headers=headers, json=payload).status_code == 200
    duplicate = client.post("/api/v1/moderator/applications", headers=headers, json=payload)
    assert duplicate.status_code == 400
    assert duplicate.json()["detail"]["code"] == "APPLICATION_PENDING"


def test_no_self_approval_route() -> None:
    owner = token("mod-d")
    created = client.post(
        "/api/v1/moderator/applications",
        headers={"Authorization": f"Bearer {owner}"},
        json={"statement": "只提交申请，不自行通过。"},
    )
    application_id = created.json()["application_id"]
    response = client.post(
        f"/api/v1/moderator/applications/{application_id}/approve",
        headers={"Authorization": f"Bearer {owner}"},
    )
    assert response.status_code == 404
