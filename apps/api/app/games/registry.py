from app.games.model import GameError, GameSpec, ValidationResult
from app.games.samples import Fujian31AnyPick, Fujian31Pick, NumberPick, RankingPick


class GameRegistry:
    def __init__(self) -> None:
        plugins: list[object] = [
            NumberPick(),
            RankingPick(),
            Fujian31Pick(),
            Fujian31AnyPick(2),
            Fujian31AnyPick(3),
            Fujian31AnyPick(4),
            Fujian31AnyPick(5),
        ]
        self._plugins = {plugin.spec.game_id: plugin for plugin in plugins}  # type: ignore[attr-defined]

    def list_enabled(self) -> list[GameSpec]:
        return [plugin.spec for plugin in self._plugins.values() if plugin.spec.enabled]

    def get_spec(self, game_id: str) -> GameSpec | None:
        plugin = self._plugins.get(game_id)
        return plugin.spec if plugin is not None else None

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

    def records_selections(self, game_id: str) -> bool:
        plugin = self._plugins.get(game_id)
        return plugin is not None and plugin.spec.records_selections
