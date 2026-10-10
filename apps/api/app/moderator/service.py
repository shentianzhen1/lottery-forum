from uuid import uuid4

from app.ledger.service import LedgerService
from app.moderator.store import ModeratorStore


class ModeratorService:
    def __init__(self, store: ModeratorStore, ledger: LedgerService) -> None:
        self.store = store
        self.ledger = ledger

    def open_board(self, account_id: str, lottery_id: str) -> dict[str, object]:
        if not lottery_id:
            return {"code": "INVALID_LOTTERY", "message": "必须选择彩种版块"}
        existing = self.store.find(account_id, lottery_id)
        if existing is not None:
            return self._board(existing)
        threshold = self.store.threshold()
        if self.ledger.available(account_id) < threshold:
            return {"code": "INSUFFICIENT_POINTS", "message": "可用积分未达到版主门槛"}
        hold_id = self.ledger.hold(
            account_id,
            threshold,
            f"moderator:{account_id}:{lottery_id}",
            account_id,
        )
        board_id = str(uuid4())
        self.store.add(board_id, account_id, lottery_id, hold_id)
        return self._board(self.store.find(account_id, lottery_id))

    def boards(self, account_id: str) -> list[dict[str, object]]:
        return [self._board(row) for row in self.store.boards_for(account_id)]

    def _board(self, row: object) -> dict[str, object]:
        return {
            "board_id": row["board_id"],  # type: ignore[index]
            "lottery_id": row["lottery_id"],  # type: ignore[index]
            "hold_id": row["hold_id"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
            "approval": "not_required",
            "payout_formula": "unset",
        }
