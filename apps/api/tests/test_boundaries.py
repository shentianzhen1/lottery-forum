from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_moderator_open_requires_authentication() -> None:
    response = client.post("/api/v1/moderator/boards", json={"lottery_id": "fujian-31"})
    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "UNAUTHENTICATED"


def test_points_and_profile_require_authentication() -> None:
    for path in ("/api/v1/users/me", "/api/v1/points/balance", "/api/v1/points/entries"):
        response = client.get(path)
        assert response.status_code == 401
        assert response.json()["detail"]["code"] == "UNAUTHENTICATED"
