from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_reports_boundary() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "lottery-forum-api"
    assert body["landscape_first"] is True
    assert "health" in body["implemented"]
    assert "auth" in body["implemented"]
    assert "moderator" in body["not_implemented"]
    assert response.headers["x-request-id"]


def test_cash_routes_are_absent() -> None:
    for path in ("/api/v1/recharge", "/api/v1/withdraw", "/api/v1/points/transfer"):
        response = client.post(path)
        assert response.status_code == 404
