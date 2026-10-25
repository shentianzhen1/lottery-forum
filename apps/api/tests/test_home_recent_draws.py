from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_home_recent_draws_is_public_and_sanitized() -> None:
    services = app.state.services
    observation = services.draws.record(
        {
            "provider": "pytest-official-manual",
            "lottery_id": "fujian-31",
            "raw_code": "99991",
            "normalized_code": "2099991",
            "draw_date": "2099-12-31",
            "main_numbers": [1, 4, 8, 12, 17, 23, 31],
            "extra_numbers": [9],
            "raw_payload": {"fixture": "public-home-draw"},
        }
    )
    services.draw_results.confirm(observation["observation_id"], "pytest-admin-id")

    response = client.get(
        "/api/v1/home/draws/recent",
        params={"lottery_id": "fujian-31", "limit": 1},
    )

    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    item = items[0]
    assert item == {
        "lottery_id": "fujian-31",
        "normalized_code": "2099991",
        "draw_date": "2099-12-31",
        "main_numbers": [1, 4, 8, 12, 17, 23, 31],
        "extra_numbers": [9],
        "status": "CONFIRMED",
    }
    assert "provider" not in item
    assert "confirmed_by" not in item
    assert "observation_id" not in item
    assert "content_hash" not in item


def test_home_recent_draws_rejects_large_limit() -> None:
    response = client.get("/api/v1/home/draws/recent", params={"limit": 6})
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_LIMIT"
