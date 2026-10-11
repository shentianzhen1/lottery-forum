from uuid import uuid4

from app.bets.store import BetStore
from app.ledger.model import Direction, LedgerError, PostRequest, Reason
from app.ledger.service import LedgerService
from app.rounds.service import RoundError, RoundService
from app.settlements.store import ALLOWED_RESULTS, SettlementStore


class SettlementError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class SettlementService:
    """Record WIN/LOSS/VOID for bets in a SETTLING round, and finalize to SETTLED.

    Recording settlements does NOT write prize ledger posts.
    Finalizing (SETTLING → SETTLED) applies VOID/LOSS hold+ledger effects.
    WIN payout is still blocked (payout_formula unset).
    """

    def __init__(
        self,
        store: SettlementStore,
        rounds: RoundService,
        bets: BetStore,
        ledger: LedgerService | None = None,
    ) -> None:
        self.store = store
        self.rounds = rounds
        self.bets = bets
        self.ledger = ledger

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
            "message": "结算结果已记录（进 SETTLED 前不派奖；VOID/LOSS 在 finalize 时入账）",
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

    def finalize(self, round_id: str, operator_id: str) -> dict[str, object]:
        """Apply VOID/LOSS effects and advance SETTLING → SETTLED. Admin-only at the router.

        - Every bet on the round must have a settlement, else SETTLEMENT_INCOMPLETE.
        - Any WIN blocks with PAYOUT_FORMULA_UNSET (no payout this slice).
        - Any LOSS requires round.board_id, else BOARD_REQUIRED.
        - VOID: release player hold; mark bet SETTLED.
        - LOSS: debit player stake, credit board moderator, release hold; mark bet SETTLED.
        - Idempotent: already-SETTLED round returns as-is; already-SETTLED bets are skipped;
          ledger posts use per-bet idempotency keys; hold release is soft.
        """
        if self.ledger is None:
            raise SettlementError("LEDGER_UNAVAILABLE", "账本未接入，无法完成结算")

        try:
            round_row = self.rounds.get(round_id)
        except RoundError as error:
            if error.code == "ROUND_NOT_FOUND":
                raise SettlementError("ROUND_NOT_FOUND", "期号不存在") from error
            raise SettlementError(error.code, error.message) from error

        if round_row["status"] == "SETTLED":
            return {
                **round_row,
                "message": "期号已结算，返回原状态",
                "applied": {"void": 0, "loss": 0, "skipped": 0},
            }
        if round_row["status"] != "SETTLING":
            raise SettlementError(
                "ROUND_NOT_SETTLING",
                f"期号须为结算中才能进入已结算（当前 {round_row['status']}）",
            )

        bets = list(self.bets.list_for_round(round_id))
        settlements = {row["bet_id"]: row for row in self.store.list_for_round(round_id)}

        missing = [bet["bet_id"] for bet in bets if bet["bet_id"] not in settlements]
        if missing:
            raise SettlementError(
                "SETTLEMENT_INCOMPLETE",
                f"期号下还有 {len(missing)} 笔投注未落结算记录",
            )

        results = [settlements[bet["bet_id"]]["result"] for bet in bets]
        if any(result == "WIN" for result in results):
            raise SettlementError(
                "PAYOUT_FORMULA_UNSET",
                "存在中奖投注，赔付公式未定，不能进入已结算",
            )

        board_id = round_row.get("board_id")
        has_loss = any(result == "LOSS" for result in results)
        if has_loss and not board_id:
            raise SettlementError(
                "BOARD_REQUIRED",
                "期号未挂版块，无法将未中注额划入版主钱包",
            )

        moderator_id: str | None = None
        if has_loss:
            moderator_id = self.rounds.board_owner(board_id)
            if moderator_id is None:
                raise SettlementError("BOARD_NOT_FOUND", "期号所属版块不存在")

        applied = {"void": 0, "loss": 0, "skipped": 0}
        for bet in bets:
            if bet["status"] == "SETTLED":
                applied["skipped"] += 1
                continue
            result = settlements[bet["bet_id"]]["result"]
            if result == "VOID":
                self._apply_void(bet)
                applied["void"] += 1
            elif result == "LOSS":
                assert moderator_id is not None
                self._apply_loss(bet, moderator_id, operator_id)
                applied["loss"] += 1
            else:
                # WIN already rejected above; defensive.
                raise SettlementError("PAYOUT_FORMULA_UNSET", "存在中奖投注，赔付公式未定，不能进入已结算")

        finalized = self.rounds.settled(round_id)
        return {
            **finalized,
            "message": "期号已结算（VOID 解冻退回；LOSS 划入版主；WIN 未派奖）",
            "applied": applied,
        }

    def _apply_void(self, bet: object) -> None:
        hold_id = bet["hold_id"]  # type: ignore[index]
        account_id = bet["account_id"]  # type: ignore[index]
        bet_id = bet["bet_id"]  # type: ignore[index]
        if hold_id:
            self.ledger.release_if_active(account_id, hold_id)  # type: ignore[union-attr]
        self.bets.set_status(bet_id, "SETTLED")

    def _apply_loss(self, bet: object, moderator_id: str, operator_id: str) -> None:
        assert self.ledger is not None
        account_id = bet["account_id"]  # type: ignore[index]
        bet_id = bet["bet_id"]  # type: ignore[index]
        hold_id = bet["hold_id"]  # type: ignore[index]
        stake = int(bet["stake"])  # type: ignore[index]

        # Release freeze first so available covers the debit of the stake.
        if hold_id:
            self.ledger.release_if_active(account_id, hold_id)

        try:
            self.ledger.post(
                PostRequest(
                    account_id=account_id,
                    direction=Direction.DEBIT,
                    amount=stake,
                    reason=Reason.GAME_SETTLEMENT,
                    reference_type="bet",
                    reference_id=bet_id,
                    idempotency_key=f"loss-debit:{bet_id}",
                    operator_id=operator_id,
                    note="未中：核销投注冻结并扣除注额",
                )
            )
            self.ledger.post(
                PostRequest(
                    account_id=moderator_id,
                    direction=Direction.CREDIT,
                    amount=stake,
                    reason=Reason.GAME_SETTLEMENT,
                    reference_type="bet",
                    reference_id=bet_id,
                    idempotency_key=f"loss-credit:{bet_id}",
                    operator_id=operator_id,
                    note="未中：玩家注额划入版主钱包",
                )
            )
        except LedgerError as error:
            raise SettlementError(error.code, error.message) from error

        self.bets.set_status(bet_id, "SETTLED")

    def _row(self, row: object) -> dict[str, object]:
        return {
            "settlement_id": row["settlement_id"],  # type: ignore[index]
            "round_id": row["round_id"],  # type: ignore[index]
            "bet_id": row["bet_id"],  # type: ignore[index]
            "result": row["result"],  # type: ignore[index]
        }
