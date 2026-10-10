from uuid import uuid4

from app.rounds.store import RoundStore

# This slice only advances through CLOSED. Later states exist in the model
# but transitions into them are not exposed yet.
TRANSITIONS: dict[str, str] = {
    "UPCOMING": "OPEN",
    "OPEN": "CLOSED",
}


class RoundError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class RoundService:
    def __init__(self, store: RoundStore) -> None:
        self.store = store

    def create(self, lottery_id: str, code: str | None = None) -> dict[str, object]:
        if not lottery_id:
            raise RoundError("INVALID_LOTTERY", "必须选择彩种")
        round_id = str(uuid4())
        self.store.add(round_id, lottery_id, code or None, "UPCOMING")
        return self.get(round_id)

    def get(self, round_id: str) -> dict[str, object]:
        row = self.store.get(round_id)
        if row is None:
            raise RoundError("ROUND_NOT_FOUND", "期号不存在")
        return self._round(row)

    def list(self, lottery_id: str | None = None) -> list[dict[str, object]]:
        return [self._round(row) for row in self.store.list_for(lottery_id)]

    def open(self, round_id: str) -> dict[str, object]:
        return self._advance(round_id, expected_from="UPCOMING", to="OPEN")

    def close(self, round_id: str) -> dict[str, object]:
        return self._advance(round_id, expected_from="OPEN", to="CLOSED")

    def _advance(self, round_id: str, expected_from: str, to: str) -> dict[str, object]:
        row = self.store.get(round_id)
        if row is None:
            raise RoundError("ROUND_NOT_FOUND", "期号不存在")
        current = row["status"]
        allowed = TRANSITIONS.get(current)
        if allowed != to:
            raise RoundError(
                "INVALID_TRANSITION",
                f"期号状态不能从 {current} 变为 {to}",
            )
        if current != expected_from:
            raise RoundError(
                "INVALID_TRANSITION",
                f"期号状态不能从 {current} 变为 {to}",
            )
        self.store.set_status(round_id, to)
        return self.get(round_id)

    def _round(self, row: object) -> dict[str, object]:
        return {
            "round_id": row["round_id"],  # type: ignore[index]
            "lottery_id": row["lottery_id"],  # type: ignore[index]
            "code": row["code"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
        }
