import pytest

from app.games.model import GameError
from app.games.registry import GameRegistry


def test_preview_lotteries_are_registered_but_not_enabled() -> None:
    registry = GameRegistry()

    p3 = registry.get_spec("pailie-3")
    kl8 = registry.get_spec("kuaile-8")

    assert p3 is not None
    assert p3.name == "排列三"
    assert p3.lottery_id == "pailie-3"
    assert p3.enabled is False
    assert p3.stake_enabled is False

    assert kl8 is not None
    assert kl8.name == "快乐8"
    assert kl8.lottery_id == "kuaile-8"
    assert kl8.enabled is False
    assert kl8.stake_enabled is False

    enabled_ids = {spec.game_id for spec in registry.list_enabled()}
    assert "pailie-3" not in enabled_ids
    assert "kuaile-8" not in enabled_ids


@pytest.mark.parametrize("game_id", ["pailie-3", "kuaile-8"])
def test_preview_lotteries_reject_validation(game_id: str) -> None:
    registry = GameRegistry()

    with pytest.raises(GameError) as caught:
        registry.validate(game_id, {"numbers": [1, 2, 3]})

    assert caught.value.code == "GAME_NOT_FOUND"
