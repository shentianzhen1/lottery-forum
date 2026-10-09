from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_user_points_and_moderator_are_explicitly_unimplemented() -> None:
    paths = (
        "/api/v1/users/me",
        "/api/v1/points/balance",
        "/api/v1/points/entries",
        "/api/v1/moderator/applications",
    )
    for path in paths:
        response = client.get(path)
        assert response.status_code == 501
        assert response.json()["detail"]["code"] == "NOT_IMPLEMENTED"
