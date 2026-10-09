from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_saves_fujian_selection_without_stake_or_payout() -> None:
    registered = client.post("/api/v1/auth/register", json={"username": "sel-user", "password": "secret-pass"})
    token = registered.json()["token"]
    account_id = registered.json()["account_id"]
    headers = {"Authorization": f"Bearer {token}"}
    saved = client.post(
        "/api/v1/games/fujian-31/selections",
        headers=headers,
        json={"numbers": [4, 2, 9, 1, 8, 3, 7], "idempotency_key": "sel-1"},
    )
    assert saved.status_code == 200
    body = saved.json()
    assert body["numbers"] == [1, 2, 3, 4, 7, 8, 9]
    assert body["pair_count"] == 21
    assert body["stake"] == 0
    assert body["payout"] == 0
    repeated = client.post(
        "/api/v1/games/fujian-31/selections",
        headers=headers,
        json={"numbers": [4, 2, 9, 1, 8, 3, 7], "idempotency_key": "sel-1"},
    )
    assert repeated.json()["selection_id"] == body["selection_id"]
    listed = client.get("/api/v1/games/fujian-31/selections", headers=headers)
    assert len(listed.json()["selections"]) == 1
    assert app.state.services.ledger.balance(account_id) == 0
