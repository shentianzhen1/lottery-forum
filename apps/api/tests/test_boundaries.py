from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_moderator_is_explicitly_unimplemented() -> None:
    response = client.get("/api/v1/moderator/applications")
    assert response.status_code == 501
    assert response.json()["detail"]["code"] == "NOT_IMPLEMENTED"


def test_points_and_profile_require_authentication() -> None:
    for path in ("/api/v1/users/me", "/api/v1/points/balance", "/api/v1/points/entries"):
        response = client.get(path)
        assert response.status_code == 401
        assert response.json()["detail"]["code"] == "UNAUTHENTICATED"
