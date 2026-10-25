from app.games.model import GameError, GameSpec, ValidationResult


class NumberPick:
    spec = GameSpec(
        "number-pick",
        "数字选号",
        "number",
        "0.1.0",
        True,
        True,
        lottery_id="demo-digit",
    )

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
    spec = GameSpec(
        "ranking-pick",
        "排名竞猜",
        "ranking",
        "0.1.0",
        True,
        True,
        lottery_id="demo-digit",
    )

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        ranking = payload.get("ranking")
        if not isinstance(ranking, list) or len(ranking) != 3:
            raise GameError("INVALID_SELECTION", "排名竞猜需要 3 个不重复选项")
        if any(item not in self.options for item in ranking) or len(set(ranking)) != 3:
            raise GameError("INVALID_SELECTION", "排名选项无效或重复")
        return ValidationResult(self.spec.game_id, {"ranking": ranking})


class Fujian31Pick:
    """福建31选7（play_id 仍为 fujian-31，与彩种/期号 id 相同）。"""

    spec = GameSpec(
        "fujian-31",
        "福建31选7",
        "number",
        "0.1.0",
        True,
        True,
        True,
        lottery_id="fujian-31",
    )

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        numbers = payload.get("numbers")
        if not isinstance(numbers, list) or len(numbers) != 7:
            raise GameError("INVALID_SELECTION", "福建31选7需要 7 个不重复号码")
        if any(not isinstance(item, int) or isinstance(item, bool) or item < 1 or item > 31 for item in numbers):
            raise GameError("INVALID_SELECTION", "号码必须是 1 到 31 的整数")
        if len(set(numbers)) != 7:
            raise GameError("INVALID_SELECTION", "号码不能重复")
        ordered = sorted(numbers)
        return ValidationResult(self.spec.game_id, {"numbers": ordered, "pair_count": 21})


class Fujian31AnyPick:
    """福建31任选 N（play_id = fujian-31-any-N）；期号彩种仍挂 fujian-31。"""

    def __init__(self, pick_count: int) -> None:
        if pick_count < 2 or pick_count > 5:
            raise ValueError(f"任选个数须为 2–5，收到 {pick_count}")
        self.pick_count = pick_count
        self.spec = GameSpec(
            f"fujian-31-any-{pick_count}",
            f"福建31任选{pick_count}",
            "number",
            "0.1.0",
            True,
            True,
            True,
            lottery_id="fujian-31",
        )

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        numbers = payload.get("numbers")
        n = self.pick_count
        if not isinstance(numbers, list) or len(numbers) != n:
            raise GameError("INVALID_SELECTION", f"福建31任选{n}需要 {n} 个不重复号码")
        if any(not isinstance(item, int) or isinstance(item, bool) or item < 1 or item > 31 for item in numbers):
            raise GameError("INVALID_SELECTION", "号码必须是 1 到 31 的整数")
        if len(set(numbers)) != n:
            raise GameError("INVALID_SELECTION", "号码不能重复")
        ordered = sorted(numbers)
        pair_count = n * (n - 1) // 2
        return ValidationResult(self.spec.game_id, {"numbers": ordered, "pair_count": pair_count})


class CatalogPreview:
    """Visible-to-planning lottery placeholder that cannot accept bets yet."""

    def __init__(self, game_id: str, name: str, lottery_id: str) -> None:
        self.spec = GameSpec(
            game_id,
            name,
            "number",
            "0.0.0-preview",
            False,
            False,
            False,
            lottery_id=lottery_id,
        )

    def validate(self, payload: dict[str, object]) -> ValidationResult:
        del payload
        raise GameError("GAME_NOT_FOUND", "玩法不存在或未启用")
