from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

FUJIAN_ANY_IDS = {
    "fujian-31-any-2",
    "fujian-31-any-3",
    "fujian-31-any-4",
    "fujian-31-any-5",
}


def test_lists_sample_games_without_settlement() -> None:
    response = client.get("/api/v1/games")
    assert response.status_code == 200
    games = {item["game_id"]: item for item in response.json()["games"]}
    assert set(games) == {"number-pick", "ranking-pick", "fujian-31", *FUJIAN_ANY_IDS}
    assert games["fujian-31"]["settles_points"] is False
    for play_id in FUJIAN_ANY_IDS:
        assert games[play_id]["settles_points"] is False
        assert games[play_id]["name"].startswith("福建31任选")


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


def test_fujian_31_takes_the_temporary_stake() -> None:
    registered = client.post("/api/v1/auth/register", json={"username": "fj-user", "password": "secret-pass"})
    token = registered.json()["token"]
    response = client.post(
        "/api/v1/games/fujian-31/entries",
        headers={"Authorization": f"Bearer {token}"},
        json={"numbers": [1, 2, 3, 4, 5, 6, 7], "idempotency_key": "fj-1"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["stake"] == 10
    assert body["payout"] == 0
    assert body["normalized"] == {"numbers": [1, 2, 3, 4, 5, 6, 7], "pair_count": 21}
    assert body["balance"] == 90


def test_fujian_31_any_n_validate_and_reject() -> None:
    cases = (
        ("fujian-31-any-2", [5, 1], 1),
        ("fujian-31-any-3", [9, 2, 4], 3),
        ("fujian-31-any-4", [8, 3, 1, 12], 6),
        ("fujian-31-any-5", [31, 1, 2, 3, 4], 10),
    )
    for play_id, numbers, pair_count in cases:
        ok = client.post(f"/api/v1/games/{play_id}/validate", json={"numbers": numbers})
        assert ok.status_code == 200, play_id
        assert ok.json()["normalized"] == {"numbers": sorted(numbers), "pair_count": pair_count}

        wrong_count = client.post(f"/api/v1/games/{play_id}/validate", json={"numbers": numbers[:-1]})
        assert wrong_count.status_code == 400
        assert wrong_count.json()["detail"]["code"] == "INVALID_SELECTION"

        dup = client.post(
            f"/api/v1/games/{play_id}/validate",
            json={"numbers": [numbers[0]] * len(numbers)},
        )
        assert dup.status_code == 400
        assert dup.json()["detail"]["code"] == "INVALID_SELECTION"

        out_of_range = client.post(
            f"/api/v1/games/{play_id}/validate",
            json={"numbers": [0] + numbers[1:]},
        )
        assert out_of_range.status_code == 400
        assert out_of_range.json()["detail"]["code"] == "INVALID_SELECTION"


def test_unknown_game_is_not_found() -> None:
    response = client.post("/api/v1/games/cash-draw/validate", json={})
    assert response.status_code == 404
