from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_lists_two_sample_games_without_settlement() -> None:
    response = client.get("/api/v1/games")
    assert response.status_code == 200
    games = {item["game_id"]: item for item in response.json()["games"]}
    assert set(games) == {"number-pick", "ranking-pick", "fujian-31"}
    assert games["fujian-31"]["settles_points"] is False


def test_number_pick_rejects_duplicates() -> None:
    response = client.post("/api/v1/games/number-pick/validate", json={"numbers": [1, 1, 2]})
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_SELECTION"


def test_ranking_pick_normalizes_without_posting_points() -> None:
    response = client.post("/api/v1/games/ranking-pick/validate", json={"ranking": ["丙", "甲", "丁"]})
    assert response.status_code == 200
    assert response.json()["normalized"] == {"ranking": ["丙", "甲", "丁"]}
    assert response.json()["settles_points"] is False


def test_fujian_31_normalizes_and_counts_pairs() -> None:
    response = client.post("/api/v1/games/fujian-31/validate", json={"numbers": [7, 1, 31, 8, 2, 9, 3]})
    assert response.status_code == 200
    assert response.json()["normalized"] == {"numbers": [1, 2, 3, 7, 8, 9, 31], "pair_count": 21}


def test_fujian_31_does_not_take_the_temporary_stake() -> None:
    registered = client.post("/api/v1/auth/register", json={"username": "fj-user", "password": "secret-pass"})
    token = registered.json()["token"]
    response = client.post(
        "/api/v1/games/fujian-31/entries",
        headers={"Authorization": f"Bearer {token}"},
        json={"numbers": [1, 2, 3, 4, 5, 6, 7], "idempotency_key": "fj-1"},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "STAKE_DISABLED"


def test_unknown_game_is_not_found() -> None:
    response = client.post("/api/v1/games/cash-draw/validate", json={})
    assert response.status_code == 404
