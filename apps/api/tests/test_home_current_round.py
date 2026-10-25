from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_home_current_round_is_public_and_sanitized() -> None:
    lottery_id = "pytest-home-current"
    services = app.state.services
    upcoming = services.rounds.create(lottery_id, "NEXT-002")
    current = services.rounds.create(lottery_id, "NOW-001")
    services.rounds.open(current["round_id"])

    response = client.get(
        "/api/v1/home/rounds/current",
        params={"lottery_id": lottery_id},
    )

    assert response.status_code == 200
    row = response.json()["round"]
    assert row == {
        "lottery_id": lottery_id,
        "code": "NOW-001",
        "status": "OPEN",
        "accepts_bets": True,
    }
    assert "round_id" not in row
    assert "board_id" not in row
    assert upcoming["round_id"] != current["round_id"]


def test_home_current_round_returns_empty_when_lottery_has_no_rounds() -> None:
    response = client.get(
        "/api/v1/home/rounds/current",
        params={"lottery_id": "pytest-home-empty"},
    )

    assert response.status_code == 200
    assert response.json() == {"round": None}
