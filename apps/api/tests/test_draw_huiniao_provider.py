import httpx
from fastapi.testclient import TestClient

from app.draws.provider_huiniao import DrawProviderError, HuiniaoDrawProvider
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


def sample_row() -> dict[str, object]:
    return {
        "code": "26281",
        "day": "2026-10-22",
        "one": "03",
        "two": "10",
        "three": "11",
        "four": "12",
        "five": "24",
        "six": "25",
        "seven": "30",
        "eight": "22",
        "open_time": "2026-10-22 00:00:00",
        "next_code": "2026282",
    }


def provider_response(row: dict[str, object] | None = None) -> dict[str, object]:
    value = row or sample_row()
    return provider_response_rows([value])


def provider_response_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    return {
        "code": 1,
        "info": "成功",
        "data": {
            "last": rows[0] if rows else {},
            "data": {
                "list": rows,
                "currentPage": "1",
                "currentLimit": str(len(rows)),
                "totalPage": 1,
                "totalCount": len(rows),
            },
        },
    }


def test_huiniao_provider_parses_fujian31_and_normalizes_issue() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["type"] == "fj31x7"
        assert request.url.params["page"] == "1"
        assert request.url.params["limit"] == "1"
        return httpx.Response(200, json=provider_response())

    with httpx.Client(transport=httpx.MockTransport(handler)) as http_client:
        provider = HuiniaoDrawProvider(http_client)
        items = provider.fetch_recent(1)

    assert len(items) == 1
    item = items[0]
    assert item["provider"] == "huiniao"
    assert item["lottery_id"] == "fujian-31"
    assert item["raw_code"] == "26281"
    assert item["normalized_code"] == "2026281"
    assert item["draw_date"] == "2026-10-22"
    assert item["main_numbers"] == [3, 10, 11, 12, 24, 25, 30]
    assert item["extra_numbers"] == [22]
    assert item["raw_payload"] == sample_row()


def test_huiniao_provider_rejects_issue_year_mismatch() -> None:
    bad = sample_row()
    bad["code"] = "25281"

    def handler(request: httpx.Request) -> httpx.Response:
        del request
        return httpx.Response(200, json=provider_response(bad))

    with httpx.Client(transport=httpx.MockTransport(handler)) as http_client:
        provider = HuiniaoDrawProvider(http_client)
        try:
            provider.fetch_recent(1)
        except DrawProviderError as error:
            assert error.code == "DRAW_PROVIDER_ISSUE_CODE_INVALID"
        else:
            raise AssertionError("year-mismatched provider issue must be rejected")


def test_huiniao_provider_rejects_schema_drift_before_persist() -> None:
    bad = sample_row()
    bad.pop("seven")

    def handler(request: httpx.Request) -> httpx.Response:
        del request
        return httpx.Response(200, json=provider_response(bad))

    with httpx.Client(transport=httpx.MockTransport(handler)) as http_client:
        provider = HuiniaoDrawProvider(http_client)
        try:
            provider.fetch_recent(1)
        except DrawProviderError as error:
            assert error.code == "DRAW_PROVIDER_SCHEMA_CHANGED"
        else:
            raise AssertionError("schema drift must be rejected")


def test_huiniao_provider_rejects_invalid_draw_numbers() -> None:
    bad = sample_row()
    bad["two"] = "03"

    def handler(request: httpx.Request) -> httpx.Response:
        del request
        return httpx.Response(200, json=provider_response(bad))

    with httpx.Client(transport=httpx.MockTransport(handler)) as http_client:
        provider = HuiniaoDrawProvider(http_client)
        try:
            provider.fetch_recent(1)
        except DrawProviderError as error:
            assert error.code == "DRAW_PROVIDER_INVALID_DRAW"
        else:
            raise AssertionError("duplicate draw numbers must be rejected at provider boundary")


def test_huiniao_pull_is_admin_only() -> None:
    response = client.post("/api/v1/draws/providers/huiniao/pull", params={"limit": 1})
    assert response.status_code == 401


def test_huiniao_pull_records_pending_observation_without_result_or_ledger_change() -> None:
    token = admin_token()
    services = app.state.services
    original_provider = services.draw_ingestion.huiniao

    class FakeProvider:
        provider_name = "huiniao"
        lottery_id = "fujian-31"

        def fetch_recent(self, limit: int) -> list[dict[str, object]]:
            assert limit == 1
            return [
                {
                    "provider": "huiniao",
                    "lottery_id": "fujian-31",
                    "raw_code": "26991",
                    "normalized_code": "2026991",
                    "draw_date": "2026-10-24",
                    "main_numbers": [1, 4, 8, 12, 17, 23, 31],
                    "extra_numbers": [9],
                    "raw_payload": {"fixture": "huiniao-safe-pull", "code": "26991"},
                }
            ]

    before_points = client.get("/api/v1/points/balance", headers=auth(token))
    assert before_points.status_code == 200

    services.draw_ingestion.huiniao = FakeProvider()
    try:
        response = client.post(
            "/api/v1/draws/providers/huiniao/pull",
            headers=auth(token),
            params={"limit": 1},
        )
    finally:
        services.draw_ingestion.huiniao = original_provider

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "huiniao"
    assert body["received"] == 1
    assert body["created"] == 1
    assert body["duplicates"] == 0
    assert body["auto_confirmed"] == 0
    assert body["ledger_touched"] is False
    assert body["items"][0]["status"] == "PENDING_REVIEW"

    after_points = client.get("/api/v1/points/balance", headers=auth(token))
    assert after_points.status_code == 200
    assert after_points.json() == before_points.json()

    results = client.get(
        "/api/v1/draws/results",
        headers=auth(token),
        params={"lottery_id": "fujian-31", "normalized_code": "2026991"},
    )
    assert results.status_code == 200
    assert results.json()["items"] == []


def test_huiniao_pull_rejects_entire_batch_before_any_persist() -> None:
    token = admin_token()
    services = app.state.services
    original_provider = services.draw_ingestion.huiniao

    valid = sample_row()
    valid.update({"code": "26981", "day": "2026-10-24"})
    invalid = sample_row()
    invalid.update({"code": "26982", "day": "2026-10-24", "two": "03"})

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["limit"] == "2"
        return httpx.Response(200, json=provider_response_rows([valid, invalid]))

    with httpx.Client(transport=httpx.MockTransport(handler)) as http_client:
        services.draw_ingestion.huiniao = HuiniaoDrawProvider(http_client)
        try:
            response = client.post(
                "/api/v1/draws/providers/huiniao/pull",
                headers=auth(token),
                params={"limit": 2},
            )
        finally:
            services.draw_ingestion.huiniao = original_provider

    assert response.status_code == 502
    assert response.json()["detail"]["code"] == "DRAW_PROVIDER_INVALID_DRAW"

    for normalized_code in ("2026981", "2026982"):
        listed = client.get(
            "/api/v1/draws/observations",
            headers=auth(token),
            params={
                "lottery_id": "fujian-31",
                "normalized_code": normalized_code,
                "provider": "huiniao",
            },
        )
        assert listed.status_code == 200
        assert listed.json()["items"] == []
