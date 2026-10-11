from uuid import uuid4

from app.bets.store import BetStore
from app.rounds.service import RoundError, RoundService
from app.settlements.store import ALLOWED_RESULTS, SettlementStore


class SettlementError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class SettlementService:
    """Record WIN/LOSS/VOID for bets in a SETTLING round.

    This slice does NOT write prize ledger posts, does NOT debit moderator
    holds, and does NOT advance bet status to SETTLED.
    """

    def __init__(
        self,
        store: SettlementStore,
        rounds: RoundService,
        bets: BetStore,
    ) -> None:
        self.store = store
        self.rounds = rounds
        self.bets = bets

    def record(self, round_id: str, results: list[dict[str, object]]) -> dict[str, object]:
        try:
            round_row = self.rounds.get(round_id)
        except RoundError as error:
            if error.code == "ROUND_NOT_FOUND":
                raise SettlementError("ROUND_NOT_FOUND", "期号不存在") from error
            raise SettlementError(error.code, error.message) from error

        if round_row["status"] != "SETTLING":
            raise SettlementError(
                "ROUND_NOT_SETTLING",
                f"期号须为结算中才能落结算记录（当前 {round_row['status']}）",
            )

        if not isinstance(results, list) or not results:
            raise SettlementError("INVALID_RESULTS", "须提供至少一条结算结果")

        recorded: list[dict[str, object]] = []
        for item in results:
            if not isinstance(item, dict):
                raise SettlementError("INVALID_RESULTS", "结算结果格式无效")
            bet_id = item.get("bet_id")
            result = item.get("result")
            if not isinstance(bet_id, str) or not bet_id:
                raise SettlementError("INVALID_RESULTS", "缺少投注编号")
            if not isinstance(result, str) or result not in ALLOWED_RESULTS:
                raise SettlementError(
                    "INVALID_RESULT",
                    "结算结果只允许 WIN、LOSS 或 VOID",
                )

            bet = self.bets.get(bet_id)
            if bet is None:
                raise SettlementError("BET_NOT_FOUND", "投注不存在")
            if bet["round_id"] != round_id:
                raise SettlementError("BET_ROUND_MISMATCH", "投注不属于该期号")

            existing = self.store.get_by_bet(bet_id)
            if existing is not None:
                if existing["result"] != result:
                    raise SettlementError(
                        "SETTLEMENT_CONFLICT",
                        "同一投注已有不同结算结果",
                    )
                recorded.append(self._row(existing))
                continue

            settlement_id = str(uuid4())
            self.store.add(settlement_id, round_id, bet_id, result)
            recorded.append(self._row(self.store.get_by_bet(bet_id)))

        return {
            "round_id": round_id,
            "settlements": recorded,
            "message": "结算结果已记录（本片不派奖、不扣版主冻结池）",
        }

    def list_for_round(self, round_id: str) -> dict[str, object]:
        try:
            self.rounds.get(round_id)
        except RoundError as error:
            if error.code == "ROUND_NOT_FOUND":
                raise SettlementError("ROUND_NOT_FOUND", "期号不存在") from error
            raise SettlementError(error.code, error.message) from error
        return {
            "round_id": round_id,
            "settlements": [self._row(row) for row in self.store.list_for_round(round_id)],
        }

    def _row(self, row: object) -> dict[str, object]:
        return {
            "settlement_id": row["settlement_id"],  # type: ignore[index]
            "round_id": row["round_id"],  # type: ignore[index]
            "bet_id": row["bet_id"],  # type: ignore[index]
            "result": row["result"],  # type: ignore[index]
        }
