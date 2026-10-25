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


def observation(
    *,
    provider: str,
    normalized_code: str,
    numbers: list[int],
    extra: list[int] | None = None,
    draw_date: str = "2026-10-25",
    marker: str = "v1",
) -> dict[str, object]:
    return {
        "provider": provider,
        "lottery_id": "fujian-31",
        "raw_code": normalized_code[-5:],
        "normalized_code": normalized_code,
        "draw_date": draw_date,
        "main_numbers": numbers,
        "extra_numbers": extra or [9],
        "raw_payload": {
            "provider": provider,
            "issue": normalized_code,
            "marker": marker,
        },
    }


def record(token: str, payload: dict[str, object]) -> dict[str, object]:
    response = client.post(
        "/api/v1/draws/observations",
        headers=auth(token),
        json=payload,
    )
    assert response.status_code == 200
    return response.json()


def report(token: str, normalized_code: str):
    return client.get(
        "/api/v1/draws/reconciliation",
        headers=auth(token),
        params={
            "lottery_id": "fujian-31",
            "normalized_code": normalized_code,
        },
    )


def test_reconciliation_is_admin_only() -> None:
    response = client.get(
        "/api/v1/draws/reconciliation",
        params={"lottery_id": "fujian-31", "normalized_code": "2026970"},
    )
    assert response.status_code == 401


def test_reconciliation_reports_no_data_and_single_source() -> None:
    token = admin_token()
    empty = report(token, "2026971")
    assert empty.status_code == 200
    assert empty.json()["status"] == "NO_DATA"
    assert empty.json()["source_count"] == 0
    assert empty.json()["read_only"] is True

    record(
        token,
        observation(
            provider="huiniao",
            normalized_code="2026972",
            numbers=[1, 4, 8, 12, 17, 23, 31],
        ),
    )
    single = report(token, "2026972")
    assert single.status_code == 200
    body = single.json()
    assert body["status"] == "SINGLE_SOURCE"
    assert body["providers"] == ["huiniao"]
    assert body["source_count"] == 1
    assert body["confirmed_result"] is None


def test_reconciliation_matches_sources_ignoring_number_order() -> None:
    token = admin_token()
    code = "2026973"
    record(
        token,
        observation(
            provider="huiniao",
            normalized_code=code,
            numbers=[1, 4, 8, 12, 17, 23, 31],
        ),
    )
    official = record(
        token,
        observation(
            provider="fjtc-official-manual",
            normalized_code=code,
            numbers=[31, 23, 17, 12, 8, 4, 1],
        ),
    )

    response = report(token, code)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "MATCH"
    assert body["source_count"] == 2
    assert body["providers"] == ["fjtc-official-manual", "huiniao"]

    confirmed = client.post(
        f"/api/v1/draws/observations/{official['observation_id']}/confirm",
        headers=auth(token),
    )
    assert confirmed.status_code == 200

    after_confirm = report(token, code).json()
    assert after_confirm["status"] == "MATCH"
    assert after_confirm["confirmed_result"]["status"] == "CONFIRMED"
    assert after_confirm["confirmed_matches"] == ["fjtc-official-manual", "huiniao"]
    assert after_confirm["confirmed_conflicts"] == []


def test_reconciliation_reports_cross_source_conflict() -> None:
    token = admin_token()
    code = "2026974"
    record(
        token,
        observation(
            provider="huiniao",
            normalized_code=code,
            numbers=[1, 4, 8, 12, 17, 23, 31],
        ),
    )
    record(
        token,
        observation(
            provider="fjtc-official-manual",
            normalized_code=code,
            numbers=[2, 4, 8, 12, 17, 23, 31],
        ),
    )

    response = report(token, code)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "CONFLICT"
    assert body["source_count"] == 2
    assert body["confirmed_result"] is None


def test_reconciliation_uses_latest_version_per_provider() -> None:
    token = admin_token()
    code = "2026975"
    record(
        token,
        observation(
            provider="huiniao",
            normalized_code=code,
            numbers=[2, 4, 8, 12, 17, 23, 31],
            marker="wrong-v1",
        ),
    )
    corrected = record(
        token,
        observation(
            provider="huiniao",
            normalized_code=code,
            numbers=[1, 4, 8, 12, 17, 23, 31],
            marker="corrected-v2",
        ),
    )
    record(
        token,
        observation(
            provider="fjtc-official-manual",
            normalized_code=code,
            numbers=[1, 4, 8, 12, 17, 23, 31],
        ),
    )

    response = report(token, code)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "MATCH"
    huiniao = next(source for source in body["sources"] if source["provider"] == "huiniao")
    assert huiniao["version"] == 2
    assert huiniao["observation_id"] == corrected["observation_id"]
    assert huiniao["main_numbers"] == [1, 4, 8, 12, 17, 23, 31]
