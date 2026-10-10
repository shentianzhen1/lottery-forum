from fastapi.testclient import TestClient

from app.ledger.model import Direction, PostRequest, Reason
from app.main import app

client = TestClient(app)


def register(username: str = "ada") -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    assert response.status_code == 200
    return response.json()["token"]


def test_register_grants_opening_points() -> None:
    token = register("opening-user")
    response = client.get("/api/v1/points/balance", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["balance"] == 100


def test_logout_invalidates_token() -> None:
    token = register("logout-user")
    headers = {"Authorization": f"Bearer {token}"}
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 200
    assert client.get("/api/v1/points/balance", headers=headers).status_code == 401


def test_credentials_have_length_limits() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "long-user", "password": "x" * 73},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_CREDENTIALS"


def test_login_is_limited_after_repeated_failures() -> None:
    register("limited-user")
    for _ in range(5):
        client.post("/api/v1/auth/login", json={"username": "limited-user", "password": "wrong-pass"})
    limited = client.post("/api/v1/auth/login", json={"username": "limited-user", "password": "secret-pass"})
    assert limited.status_code == 401
    assert limited.json()["detail"]["code"] == "LOGIN_LIMITED"


def test_points_require_login() -> None:
    assert client.get("/api/v1/points/balance").status_code == 401
    assert client.get("/api/v1/points/entries").status_code == 401
    assert client.get("/api/v1/users/me").status_code == 401


def test_login_and_read_own_entries() -> None:
    register("bao")
    login = client.post("/api/v1/auth/login", json={"username": "bao", "password": "secret-pass"})
    token = login.json()["token"]
    account_id = login.json()["account_id"]
    app.state.services.ledger.post(
        PostRequest(
            account_id=account_id,
            direction=Direction.CREDIT,
            amount=30,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id="grant-bao",
            idempotency_key="grant-bao",
            operator_id="system",
        )
    )
    entries = client.get("/api/v1/points/entries", headers={"Authorization": f"Bearer {token}"})
    assert entries.status_code == 200
    assert any(row["amount"] == 30 for row in entries.json()["entries"])


def test_wrong_password_rejected() -> None:
    register("chen")
    response = client.post("/api/v1/auth/login", json={"username": "chen", "password": "nope-pass"})
    assert response.status_code == 401


def test_cash_routes_remain_absent() -> None:
    token = register("dai")
    for path in ("/api/v1/recharge", "/api/v1/withdraw", "/api/v1/points/transfer"):
        response = client.post(path, headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 404
