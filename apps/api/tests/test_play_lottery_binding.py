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


def open_round(lottery_id: str, code: str) -> str:
    token = admin_token()
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": lottery_id, "code": code},
    )
    assert created.status_code == 200
    round_id = created.json()["round_id"]
    opened = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert opened.status_code == 200
    return round_id


def assert_no_freeze(token: str) -> None:
    balance = client.get("/api/v1/points/balance", headers=auth(token))
    assert balance.status_code == 200
    assert balance.json()["balance"] == 100
    assert balance.json()["frozen"] == 0
    assert balance.json()["available"] == 100


def test_fujian_play_cannot_use_demo_digit_round() -> None:
    token = user_token("binding-fj-on-demo")
    round_id = open_round("demo-digit", "binding-demo")
    response = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json={
            "idempotency_key": "binding-fj-demo",
            "round_id": round_id,
            "play_id": "fujian-31",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3, 4, 5, 6, 7],
        },
    )
    assert response.status_code == 400
    assert response.json()["detail"] == {
        "code": "PLAY_LOTTERY_MISMATCH",
        "message": "玩法与期号彩种不匹配",
    }
    assert_no_freeze(token)


def test_demo_play_cannot_use_fujian_round() -> None:
    token = user_token("binding-demo-on-fj")
    round_id = open_round("fujian-31", "binding-fj")
    response = client.post(
        "/api/v1/bets",
        headers=auth(token),
        json={
            "idempotency_key": "binding-demo-fj",
            "round_id": round_id,
            "play_id": "number-pick",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3],
        },
    )
    assert response.status_code == 400
    assert response.json()["detail"] == {
        "code": "PLAY_LOTTERY_MISMATCH",
        "message": "玩法与期号彩种不匹配",
    }
    assert_no_freeze(token)
