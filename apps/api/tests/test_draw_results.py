from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)
ADMIN_USERNAME = "pytest-admin"


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def admin_token() -> str:
    creds = {"username": ADMIN_USERNAME, "password": "admin-secret-pass"}
    response = client.post("/api/v1/auth/login", json=creds)
    if response.status_code != 200:
        response = client.post("/api/v1/auth/register", json=creds)
    assert response.status_code == 200
    return response.json()["token"]


def user_token(username: str) -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    assert response.status_code == 200
    return response.json()["token"]


def observation_payload(
    normalized_code: str,
    *,
    main_numbers: list[int] | None = None,
    raw_payload: dict[str, object] | None = None,
) -> dict[str, object]:
    return {
        "provider": "confirmation-fixture",
        "lottery_id": "fujian-31",
        "raw_code": normalized_code[-5:],
        "normalized_code": normalized_code,
        "draw_date": "2026-10-23",
        "main_numbers": main_numbers or [2, 6, 9, 14, 18, 27, 31],
        "extra_numbers": [12],
        "raw_payload": raw_payload or {"fixture": True, "code": normalized_code[-5:]},
    }


def record_observation(token: str, normalized_code: str, **kwargs: object) -> dict[str, object]:
    response = client.post(
        "/api/v1/draws/observations",
        headers=auth(token),
        json=observation_payload(normalized_code, **kwargs),
    )
    assert response.status_code == 200
    return response.json()


def test_confirm_is_admin_only() -> None:
    admin = admin_token()
    observation = record_observation(admin, "2026921")
    path = f"/api/v1/draws/observations/{observation['observation_id']}/confirm"

    assert client.post(path).status_code == 401
    normal = user_token("draw-confirm-normal-user")
    forbidden = client.post(path, headers=auth(normal))
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"]["code"] == "FORBIDDEN"


def test_confirm_creates_result_snapshot_and_keeps_observation_immutable() -> None:
    token = admin_token()
    observation = record_observation(token, "2026922")
    response = client.post(
        f"/api/v1/draws/observations/{observation['observation_id']}/confirm",
        headers=auth(token),
    )
    assert response.status_code == 200
    result = response.json()
    assert result["observation_id"] == observation["observation_id"]
    assert result["lottery_id"] == "fujian-31"
    assert result["normalized_code"] == "2026922"
    assert result["main_numbers"] == observation["main_numbers"]
    assert result["extra_numbers"] == observation["extra_numbers"]
    assert result["content_hash"] == observation["content_hash"]
    assert result["source_version"] == 1
    assert result["status"] == "CONFIRMED"
    assert result["duplicate"] is False
    assert result["confirmed_by"]

    listed = client.get(
        "/api/v1/draws/results",
        headers=auth(token),
        params={"lottery_id": "fujian-31", "normalized_code": "2026922"},
    )
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1
    assert listed.json()["items"][0]["result_id"] == result["result_id"]

    source = client.get(
        "/api/v1/draws/observations",
        headers=auth(token),
        params={"normalized_code": "2026922", "provider": "confirmation-fixture"},
    )
    assert source.status_code == 200
    assert source.json()["items"][0]["status"] == "PENDING_REVIEW"


def test_confirm_same_observation_is_idempotent() -> None:
    token = admin_token()
    observation = record_observation(token, "2026923")
    path = f"/api/v1/draws/observations/{observation['observation_id']}/confirm"
    first = client.post(path, headers=auth(token))
    second = client.post(path, headers=auth(token))
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["result_id"] == second.json()["result_id"]
    assert first.json()["duplicate"] is False
    assert second.json()["duplicate"] is True


def test_different_version_cannot_replace_confirmed_issue() -> None:
    token = admin_token()
    first = record_observation(token, "2026924")
    corrected = record_observation(
        token,
        "2026924",
        main_numbers=[2, 6, 9, 14, 19, 27, 31],
        raw_payload={"fixture": True, "code": "26924", "corrected": True},
    )
    assert first["version"] == 1
    assert corrected["version"] == 2

    confirmed = client.post(
        f"/api/v1/draws/observations/{first['observation_id']}/confirm",
        headers=auth(token),
    )
    assert confirmed.status_code == 200

    conflict = client.post(
        f"/api/v1/draws/observations/{corrected['observation_id']}/confirm",
        headers=auth(token),
    )
    assert conflict.status_code == 409
    assert conflict.json()["detail"] == {
        "code": "DRAW_RESULT_ALREADY_CONFIRMED",
        "message": "该期已有已确认开奖结果",
    }

    listed = client.get(
        "/api/v1/draws/results",
        headers=auth(token),
        params={"normalized_code": "2026924"},
    )
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1
    assert listed.json()["items"][0]["observation_id"] == first["observation_id"]


def test_confirm_unknown_observation_returns_404() -> None:
    token = admin_token()
    response = client.post(
        "/api/v1/draws/observations/not-found/confirm",
        headers=auth(token),
    )
    assert response.status_code == 404
    assert response.json()["detail"] == {
        "code": "DRAW_OBSERVATION_NOT_FOUND",
        "message": "开奖观察不存在",
    }


def test_confirming_result_does_not_touch_points() -> None:
    token = admin_token()
    observation = record_observation(token, "2026925")
    before = client.get("/api/v1/points/balance", headers=auth(token))
    assert before.status_code == 200

    response = client.post(
        f"/api/v1/draws/observations/{observation['observation_id']}/confirm",
        headers=auth(token),
    )
    assert response.status_code == 200

    after = client.get("/api/v1/points/balance", headers=auth(token))
    assert after.status_code == 200
    assert after.json() == before.json()
