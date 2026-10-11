from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def token_for(username: str) -> str:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass"},
    )
    assert response.status_code == 200
    return response.json()["token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_create_get_and_happy_path_to_closed() -> None:
    token = token_for("round-happy")
    created = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "fujian-31", "code": "20261010-01"},
    )
    assert created.status_code == 200
    body = created.json()
    assert body["lottery_id"] == "fujian-31"
    assert body["code"] == "20261010-01"
    assert body["status"] == "UPCOMING"
    round_id = body["round_id"]

    got = client.get(f"/api/v1/rounds/{round_id}", headers=auth(token))
    assert got.status_code == 200
    assert got.json()["status"] == "UPCOMING"

    opened = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert opened.status_code == 200
    assert opened.json()["status"] == "OPEN"

    closed = client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    assert closed.status_code == 200
    assert closed.json()["status"] == "CLOSED"


def test_reject_skip_backwards_and_from_closed() -> None:
    token = token_for("round-bad")
    round_id = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "demo-digit"},
    ).json()["round_id"]

    # cannot close from UPCOMING (skip OPEN)
    skip = client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    assert skip.status_code == 400
    assert skip.json()["detail"]["code"] == "INVALID_TRANSITION"

    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    # cannot open again from OPEN (backwards / illegal)
    again = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert again.status_code == 400
    assert again.json()["detail"]["code"] == "INVALID_TRANSITION"

    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    # cannot reopen or close again from CLOSED
    from_closed_open = client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    assert from_closed_open.status_code == 400
    assert from_closed_open.json()["detail"]["code"] == "INVALID_TRANSITION"
    from_closed_close = client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    assert from_closed_close.status_code == 400
    assert from_closed_close.json()["detail"]["code"] == "INVALID_TRANSITION"


def test_unauthorized_without_token() -> None:
    assert client.post("/api/v1/rounds", json={"lottery_id": "x"}).status_code == 401
    assert client.get("/api/v1/rounds/missing").status_code == 401
    assert client.post("/api/v1/rounds/missing/open").status_code == 401
    assert client.post("/api/v1/rounds/missing/close").status_code == 401


def test_missing_round_returns_not_found() -> None:
    token = token_for("round-missing")
    response = client.get("/api/v1/rounds/does-not-exist", headers=auth(token))
    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "ROUND_NOT_FOUND"


def test_list_rounds_optional() -> None:
    token = token_for("round-list")
    client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "fujian-31", "code": "a"},
    )
    client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "demo-digit", "code": "b"},
    )
    all_rounds = client.get("/api/v1/rounds", headers=auth(token))
    assert all_rounds.status_code == 200
    assert len(all_rounds.json()["rounds"]) >= 2
    filtered = client.get("/api/v1/rounds", headers=auth(token), params={"lottery_id": "demo-digit"})
    assert filtered.status_code == 200
    assert all(item["lottery_id"] == "demo-digit" for item in filtered.json()["rounds"])


def test_create_requires_lottery_id() -> None:
    token = token_for("round-nolottery")
    response = client.post("/api/v1/rounds", headers=auth(token), json={})
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_LOTTERY"


def test_no_draw_endpoint() -> None:
    token = token_for("round-nodraw")
    round_id = client.post(
        "/api/v1/rounds",
        headers=auth(token),
        json={"lottery_id": "fujian-31"},
    ).json()["round_id"]
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(token))
    client.post(f"/api/v1/rounds/{round_id}/close", headers=auth(token))
    draw = client.post(f"/api/v1/rounds/{round_id}/draw", headers=auth(token))
    assert draw.status_code == 404
