from app.games.model import GameError, GameSpec, ValidationResult
from app.games.samples import Fujian31Pick, NumberPick, RankingPick


class GameRegistry:
    def __init__(self) -> None:
        self._plugins = {
            NumberPick.spec.game_id: NumberPick(),
            RankingPick.spec.game_id: RankingPick(),
            Fujian31Pick.spec.game_id: Fujian31Pick(),
        }

    def list_enabled(self) -> list[GameSpec]:
        return [plugin.spec for plugin in self._plugins.values() if plugin.spec.enabled]

    def validate(self, game_id: str, payload: dict[str, object]) -> ValidationResult:
        plugin = self._plugins.get(game_id)
        if plugin is None or not plugin.spec.enabled:
            raise GameError("GAME_NOT_FOUND", "玩法不存在或未启用")
        result = plugin.validate(payload)
        if result.settles_points:
            raise GameError("SETTLEMENT_DISABLED", "玩法结算尚未接入积分账本")
        return result

    def stake_enabled(self, game_id: str) -> bool:
        plugin = self._plugins.get(game_id)
        return plugin is not None and plugin.spec.stake_enabled
