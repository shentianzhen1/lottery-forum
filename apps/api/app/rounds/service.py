"""Round state machine (UPCOMING → OPEN → CLOSED → DRAWN → SETTLING) with board ownership."""
from typing import Callable
from uuid import uuid4

from app.rounds.store import RoundStore

# Closed → Drawn → Settling → Settled. WIN payout: fixed 2x via SettlementService.finalize.
TRANSITIONS: dict[str, str] = {
    "UPCOMING": "OPEN",
    "OPEN": "CLOSED",
    "CLOSED": "DRAWN",
    "DRAWN": "SETTLING",
    "SETTLING": "SETTLED",
}

# board_id -> moderator board row (board_id, account_id, lottery_id, ...) or None.
BoardLookup = Callable[[str], object | None]


class RoundError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class RoundService:
    def __init__(self, store: RoundStore, boards: BoardLookup | None = None) -> None:
        self.store = store
        self.boards: BoardLookup = boards or (lambda board_id: None)

    # --- ownership ----------------------------------------------------------
    def board_owner(self, board_id: str | None) -> str | None:
        """Account id owning the board, or None when board missing / not given."""
        if not board_id:
            return None
        board = self.boards(board_id)
        return board["account_id"] if board is not None else None  # type: ignore[index]

    def round_owner(self, round_id: str) -> str | None:
        """Owner of the round's board. None for missing rounds and legacy rounds (board_id null)."""
        row = self.store.get(round_id)
        if row is None:
            return None
        return self.board_owner(row["board_id"])

    # --- commands -----------------------------------------------------------
    def create(
        self,
        lottery_id: str,
        code: str | None = None,
        board_id: str | None = None,
    ) -> dict[str, object]:
        if not lottery_id:
            raise RoundError("INVALID_LOTTERY", "必须选择彩种")
        if board_id:
            board = self.boards(board_id)
            if board is None:
                raise RoundError("BOARD_NOT_FOUND", "版块不存在")
            if board["lottery_id"] != lottery_id:  # type: ignore[index]
                raise RoundError("BOARD_LOTTERY_MISMATCH", "期号彩种与版块彩种不一致")
        round_id = str(uuid4())
        self.store.add(round_id, lottery_id, code or None, "UPCOMING", board_id or None)
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

    def draw(self, round_id: str) -> dict[str, object]:
        return self._advance(round_id, expected_from="CLOSED", to="DRAWN")

    def settling(self, round_id: str) -> dict[str, object]:
        return self._advance(round_id, expected_from="DRAWN", to="SETTLING")

    def settled(self, round_id: str) -> dict[str, object]:
        """SETTLING → SETTLED. Callers must apply VOID/LOSS ledger effects first."""
        return self._advance(round_id, expected_from="SETTLING", to="SETTLED")

    def _advance(self, round_id: str, expected_from: str, to: str) -> dict[str, object]:
        row = self.store.get(round_id)
        if row is None:
            raise RoundError("ROUND_NOT_FOUND", "期号不存在")
        current = row["status"]
        allowed = TRANSITIONS.get(current)
        if allowed != to or current != expected_from:
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
            "board_id": row["board_id"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
        }
