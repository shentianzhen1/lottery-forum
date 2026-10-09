from dataclasses import dataclass


class GameError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


@dataclass(frozen=True)
class GameSpec:
    game_id: str
    name: str
    kind: str
    version: str
    enabled: bool
    stake_enabled: bool = False


@dataclass(frozen=True)
class ValidationResult:
    game_id: str
    normalized: dict[str, object]
    settles_points: bool = False
