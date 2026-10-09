from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_lists_two_sample_games_without_settlement() -> None:
    response = client.get("/api/v1/games")
    assert response.status_code == 200
    games = {item["game_id"]: item for item in response.json()["games"]}
    assert set(games) == {"number-pick", "ranking-pick"}
    assert all(item["settles_points"] is False for item in games.values())


def test_number_pick_rejects_duplicates() -> None:
    response = client.post("/api/v1/games/number-pick/validate", json={"numbers": [1, 1, 2]})
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INVALID_SELECTION"


def test_ranking_pick_normalizes_without_posting_points() -> None:
    response = client.post("/api/v1/games/ranking-pick/validate", json={"ranking": ["丙", "甲", "丁"]})
    assert response.status_code == 200
    assert response.json()["normalized"] == {"ranking": ["丙", "甲", "丁"]}
    assert response.json()["settles_points"] is False


def test_unknown_game_is_not_found() -> None:
    response = client.post("/api/v1/games/cash-draw/validate", json={})
    assert response.status_code == 404
