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
    provider: str = "fixture-provider",
) -> dict[str, object]:
    return {
        "provider": provider,
        "lottery_id": "fujian-31",
        "raw_code": normalized_code[-5:],
        "normalized_code": normalized_code,
        "draw_date": "2026-10-22",
        "main_numbers": main_numbers or [3, 10, 11, 12, 24, 25, 30],
        "extra_numbers": [22],
        "raw_payload": raw_payload or {"fixture": True, "code": normalized_code[-5:]},
    }


def test_draw_observations_are_admin_only() -> None:
    payload = observation_payload("2026901")
    assert client.post("/api/v1/draws/observations", json=payload).status_code == 401

    token = user_token("draw-observer-user")
    forbidden = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"]["code"] == "FORBIDDEN"


def test_record_valid_observation_and_list_it() -> None:
    token = admin_token()
    payload = observation_payload("2026902")
    response = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "fixture-provider"
    assert body["lottery_id"] == "fujian-31"
    assert body["normalized_code"] == "2026902"
    assert body["main_numbers"] == [3, 10, 11, 12, 24, 25, 30]
    assert body["extra_numbers"] == [22]
    assert body["version"] == 1
    assert body["status"] == "PENDING_REVIEW"
    assert body["duplicate"] is False
    assert len(body["content_hash"]) == 64

    listed = client.get(
        "/api/v1/draws/observations",
        headers=auth(token),
        params={"lottery_id": "fujian-31", "normalized_code": "2026902", "provider": "fixture-provider"},
    )
    assert listed.status_code == 200
    items = listed.json()["items"]
    assert len(items) == 1
    assert items[0]["observation_id"] == body["observation_id"]


def test_identical_observation_is_idempotent() -> None:
    token = admin_token()
    payload = observation_payload("2026903")
    first = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    second = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["observation_id"] == second.json()["observation_id"]
    assert first.json()["content_hash"] == second.json()["content_hash"]
    assert first.json()["version"] == 1
    assert second.json()["version"] == 1
    assert first.json()["duplicate"] is False
    assert second.json()["duplicate"] is True


def test_changed_same_issue_creates_new_version_without_overwrite() -> None:
    token = admin_token()
    first_payload = observation_payload("2026904")
    corrected_payload = observation_payload(
        "2026904",
        main_numbers=[3, 10, 11, 12, 23, 25, 30],
        raw_payload={"fixture": True, "code": "26904", "corrected": True},
    )
    first = client.post("/api/v1/draws/observations", headers=auth(token), json=first_payload)
    corrected = client.post("/api/v1/draws/observations", headers=auth(token), json=corrected_payload)
    assert first.status_code == 200
    assert corrected.status_code == 200
    assert first.json()["version"] == 1
    assert corrected.json()["version"] == 2
    assert first.json()["observation_id"] != corrected.json()["observation_id"]
    assert first.json()["content_hash"] != corrected.json()["content_hash"]
    assert corrected.json()["status"] == "PENDING_REVIEW"

    listed = client.get(
        "/api/v1/draws/observations",
        headers=auth(token),
        params={"normalized_code": "2026904", "provider": "fixture-provider"},
    )
    assert listed.status_code == 200
    items = listed.json()["items"]
    assert len(items) == 2
    assert {item["version"] for item in items} == {1, 2}
    assert {tuple(item["main_numbers"]) for item in items} == {
        (3, 10, 11, 12, 24, 25, 30),
        (3, 10, 11, 12, 23, 25, 30),
    }


def test_invalid_numbers_are_rejected_without_persisting() -> None:
    token = admin_token()
    payload = observation_payload("2026905", main_numbers=[1, 1, 2, 3, 4, 5, 6])
    response = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_DRAW_NUMBERS"

    listed = client.get(
        "/api/v1/draws/observations",
        headers=auth(token),
        params={"normalized_code": "2026905"},
    )
    assert listed.status_code == 200
    assert listed.json()["items"] == []


def test_unsupported_lottery_is_rejected() -> None:
    token = admin_token()
    payload = observation_payload("2026906")
    payload["lottery_id"] = "demo-digit"
    response = client.post("/api/v1/draws/observations", headers=auth(token), json=payload)
    assert response.status_code == 400
    assert response.json()["detail"] == {
        "code": "DRAW_LOTTERY_UNSUPPORTED",
        "message": "当前开奖采集仅支持福建31",
    }


def test_recording_observation_does_not_touch_points() -> None:
    token = admin_token()
    before = client.get("/api/v1/points/balance", headers=auth(token))
    assert before.status_code == 200

    response = client.post(
        "/api/v1/draws/observations",
        headers=auth(token),
        json=observation_payload("2026907"),
    )
    assert response.status_code == 200

    after = client.get("/api/v1/points/balance", headers=auth(token))
    assert after.status_code == 200
    assert after.json() == before.json()
