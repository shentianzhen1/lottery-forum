import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

ADMIN_USERNAME = "pytest-admin"
FORBIDDEN = {"code": "FORBIDDEN", "message": "无权限执行此操作"}


def admin_token() -> str:
    creds = {"username": ADMIN_USERNAME, "password": "admin-secret-pass"}
    response = client.post("/api/v1/auth/login", json=creds)
    if response.status_code != 200:
        response = client.post("/api/v1/auth/register", json=creds)
    assert response.status_code == 200
    return response.json()["token"]


def register(username: str, **extra: object) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "secret-pass", **extra},
    )
    assert response.status_code == 200
    return response.json()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def create_round(token: str, lottery_id: str = "demo-digit") -> str:
    created = client.post("/api/v1/rounds", headers=auth(token), json={"lottery_id": lottery_id})
    assert created.status_code == 200
    return created.json()["round_id"]


def test_admin_role_from_env_and_users_me() -> None:
    me = client.get("/api/v1/users/me", headers=auth(admin_token()))
    assert me.status_code == 200
    assert me.json()["role"] == "admin"


def test_register_cannot_self_assign_admin() -> None:
    body = register("perm-sneaky", role="admin")
    me = client.get("/api/v1/users/me", headers=auth(body["token"]))
    assert me.json()["role"] == "user"
    stored = app.state.services.auth.accounts.by_username("perm-sneaky")
    assert stored is not None and stored.role == "user"
    forbidden = client.post("/api/v1/rounds", headers=auth(body["token"]), json={"lottery_id": "demo-digit"})
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"] == FORBIDDEN


def test_env_admin_list_is_read_live(monkeypatch: pytest.MonkeyPatch) -> None:
    body = register("perm-later-admin")
    token = body["token"]
    assert client.get("/api/v1/users/me", headers=auth(token)).json()["role"] == "user"
    monkeypatch.setenv("LOTTERY_FORUM_ADMIN_USERNAMES", " pytest-admin , perm-later-admin ,")
    assert client.get("/api/v1/users/me", headers=auth(token)).json()["role"] == "admin"
    assert client.post("/api/v1/rounds", headers=auth(token), json={"lottery_id": "demo-digit"}).status_code == 200


def test_seeded_admin_role_in_store_is_honoured() -> None:
    body = register("perm-seeded")
    services = app.state.services
    services.auth.accounts.connection.execute(
        "update accounts set role = 'admin' where username = ?", ("perm-seeded",)
    )
    services.auth.accounts.connection.commit()
    me = client.get("/api/v1/users/me", headers=auth(body["token"]))
    assert me.json()["role"] == "admin"


def test_admin_can_do_each_write_op() -> None:
    admin = admin_token()
    user = register("perm-admin-ops-bettor")["token"]
    round_id = create_round(admin)
    assert client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin)).status_code == 200
    bet = client.post(
        "/api/v1/bets",
        headers=auth(user),
        json={
            "idempotency_key": "perm-ops-1",
            "round_id": round_id,
            "play_id": "number-pick",
            "rule_version": "0.1.0",
            "numbers": [1, 2, 3],
        },
    )
    assert bet.status_code == 200
    for step, status in (("close", "CLOSED"), ("draw", "DRAWN"), ("settling", "SETTLING")):
        response = client.post(f"/api/v1/rounds/{round_id}/{step}", headers=auth(admin))
        assert response.status_code == 200
        assert response.json()["status"] == status
    settled = client.post(
        f"/api/v1/settlements/{round_id}",
        headers=auth(admin),
        json={"results": [{"bet_id": bet.json()["bet_id"], "result": "LOSS"}]},
    )
    assert settled.status_code == 200


def test_normal_user_forbidden_on_every_write_op_and_state_unchanged() -> None:
    admin = admin_token()
    user = register("perm-normal")["token"]
    round_id = create_round(admin)

    attempts = [
        ("/api/v1/rounds", {"lottery_id": "demo-digit"}),
        (f"/api/v1/rounds/{round_id}/open", None),
        (f"/api/v1/rounds/{round_id}/close", None),
        (f"/api/v1/rounds/{round_id}/draw", None),
        (f"/api/v1/rounds/{round_id}/settling", None),
        (f"/api/v1/settlements/{round_id}", {"results": [{"bet_id": "x", "result": "WIN"}]}),
    ]
    for path, payload in attempts:
        response = client.post(path, headers=auth(user), json=payload)
        assert response.status_code == 403, path
        assert response.json()["detail"] == FORBIDDEN, path

    # forbidden even for a missing round (no existence leak / no 404 before authz)
    missing = client.post("/api/v1/rounds/does-not-exist/open", headers=auth(user))
    assert missing.status_code == 403

    got = client.get(f"/api/v1/rounds/{round_id}", headers=auth(user))
    assert got.json()["status"] == "UPCOMING"


def test_missing_or_invalid_token_still_401() -> None:
    for path in ("/api/v1/rounds", "/api/v1/rounds/r/open", "/api/v1/settlements/r"):
        assert client.post(path, json={}).status_code == 401
        bad = client.post(path, headers=auth("not-a-token"), json={})
        assert bad.status_code == 401


def test_reads_and_bets_still_work_for_normal_user() -> None:
    admin = admin_token()
    user = register("perm-reader")["token"]
    round_id = create_round(admin)
    client.post(f"/api/v1/rounds/{round_id}/open", headers=auth(admin))

    assert client.get("/api/v1/rounds", headers=auth(user)).status_code == 200
    got = client.get(f"/api/v1/rounds/{round_id}", headers=auth(user))
    assert got.status_code == 200 and got.json()["status"] == "OPEN"

    bet = client.post(
        "/api/v1/bets",
        headers=auth(user),
        json={
            "idempotency_key": "perm-reader-1",
            "round_id": round_id,
            "play_id": "number-pick",
            "rule_version": "0.1.0",
            "numbers": [4, 5, 6],
        },
    )
    assert bet.status_code == 200
    assert bet.json()["status"] == "ACCEPTED"

    listed = client.get(f"/api/v1/settlements/{round_id}", headers=auth(user))
    assert listed.status_code == 403
    assert listed.json()["detail"] == FORBIDDEN
