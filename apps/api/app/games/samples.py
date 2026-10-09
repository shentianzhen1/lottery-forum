from app.games.model import GameError, GameSpec, ValidationResult


class NumberPick:
    spec = GameSpec("number-pick", "数字选号", "number", "0.1.0", True)

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        numbers = payload.get("numbers")
        if not isinstance(numbers, list) or len(numbers) != 3:
            raise GameError("INVALID_SELECTION", "数字选号需要 3 个不重复数字")
        if any(not isinstance(item, int) or isinstance(item, bool) or item < 0 or item > 9 for item in numbers):
            raise GameError("INVALID_SELECTION", "数字必须是 0 到 9 的整数")
        if len(set(numbers)) != 3:
            raise GameError("INVALID_SELECTION", "数字不能重复")
        return ValidationResult(self.spec.game_id, {"numbers": numbers})


class RankingPick:
    options = ("甲", "乙", "丙", "丁")
    spec = GameSpec("ranking-pick", "排名竞猜", "ranking", "0.1.0", True)

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        ranking = payload.get("ranking")
        if not isinstance(ranking, list) or len(ranking) != 3:
            raise GameError("INVALID_SELECTION", "排名竞猜需要 3 个不重复选项")
        if any(item not in self.options for item in ranking) or len(set(ranking)) != 3:
            raise GameError("INVALID_SELECTION", "排名选项无效或重复")
        return ValidationResult(self.spec.game_id, {"ranking": ranking})
