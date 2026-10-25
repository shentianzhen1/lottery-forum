import json
import sqlite3
from uuid import uuid4

from app.bets.store import ALLOWED_STATUSES, BetStore
from app.db import atomic_command, require_shared_connection
from app.games.model import GameError
from app.games.registry import GameRegistry
from app.ledger.model import LedgerError
from app.ledger.service import LedgerService
from app.rounds.service import RoundError, RoundService
from app.settlements.store import SettlementStore

# Fixed demo stake for stake_enabled plays this slice. Not a final pricing rule.
STAKE = 10

# Fixed 2x multiplier this slice (minimal WIN payout). Snapshot is authoritative at settle.
ODDS_SNAPSHOT: dict[str, object] = {"status": "fixed", "multiplier": 2}


class BetError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message


class BetService:
    def __init__(
        self,
        store: BetStore,
        rounds: RoundService,
        games: GameRegistry,
        ledger: LedgerService,
        settlements: SettlementStore | None = None,
    ) -> None:
        self.store = store
        self.rounds = rounds
        self.games = games
        self.ledger = ledger
        self.settlements = settlements
        stores: list[object] = [store, rounds.store, ledger.store]
        if settlements is not None:
            stores.append(settlements)
        require_shared_connection(*stores)

    @atomic_command
    def place(
        self,
        account_id: str,
        payload: dict[str, object],
    ) -> dict[str, object]:
        idempotency_key = payload.get("idempotency_key")
        round_id = payload.get("round_id")
        play_id = payload.get("play_id")
        rule_version = payload.get("rule_version")
        if not isinstance(idempotency_key, str) or not idempotency_key:
            raise BetError("INVALID_ENTRY", "缺少幂等键")
        if not isinstance(round_id, str) or not round_id:
            raise BetError("INVALID_ENTRY", "缺少期号")
        if not isinstance(play_id, str) or not play_id:
            raise BetError("INVALID_ENTRY", "缺少玩法")
        if not isinstance(rule_version, str) or not rule_version:
            raise BetError("INVALID_ENTRY", "缺少规则版本")

        existing = self.store.find_by_idempotency(account_id, idempotency_key)
        if existing is not None:
            return self._bet(existing, message="已提交过，返回原投注")

        try:
            round_row = self.rounds.get(round_id)
        except RoundError as error:
            if error.code == "ROUND_NOT_FOUND":
                raise BetError("ROUND_NOT_FOUND", "期号不存在") from error
            raise BetError(error.code, error.message) from error
        if round_row["status"] != "OPEN":
            raise BetError("ROUND_CLOSED", "当期已截止，无法投注")

        spec = self.games.get_spec(play_id)
        if spec is None or not spec.enabled:
            raise BetError("GAME_NOT_FOUND", "玩法不存在或未启用")
        if not spec.lottery_id:
            raise BetError("PLAY_LOTTERY_UNBOUND", "玩法尚未绑定彩种")
        if spec.lottery_id != round_row["lottery_id"]:
            raise BetError("PLAY_LOTTERY_MISMATCH", "玩法与期号彩种不匹配")
        if spec.version != rule_version:
            raise BetError("RULE_VERSION_MISMATCH", "规则版本不匹配")
        if not spec.stake_enabled:
            raise BetError("STAKE_DISABLED", "该玩法尚未开放投注冻结")

        try:
            result = self.games.validate(play_id, payload)
        except GameError as error:
            if error.code == "GAME_NOT_FOUND":
                raise BetError("GAME_NOT_FOUND", "玩法不存在或未启用") from error
            raise BetError("INVALID_SELECTION", "选号未通过校验") from error

        hold_key = f"bet:{account_id}:{idempotency_key}"
        try:
            hold_id = self.ledger.hold(account_id, STAKE, hold_key, account_id)
        except LedgerError as error:
            if error.code == "INSUFFICIENT_POINTS":
                raise BetError("INSUFFICIENT_POINTS", "积分不足") from error
            raise BetError(error.code, error.message) from error

        bet_id = str(uuid4())
        try:
            self.store.add(
                bet_id=bet_id,
                account_id=account_id,
                round_id=round_id,
                play_id=play_id,
                rule_version=rule_version,
                status="ACCEPTED",
                selection=result.normalized,
                odds_snapshot=ODDS_SNAPSHOT,
                hold_id=hold_id,
                stake=STAKE,
                idempotency_key=idempotency_key,
            )
        except sqlite3.IntegrityError:
            existing = self.store.find_by_idempotency(account_id, idempotency_key)
            if existing is None:
                raise
            return self._bet(existing, message="已提交过，返回原投注")

        return self._bet(
            self.store.get(bet_id),
            message="投注已受理，积分已冻结，结算后按结果派奖",
        )

    def get(self, account_id: str, bet_id: str) -> dict[str, object]:
        row = self.store.get(bet_id)
        if row is None or row["account_id"] != account_id:
            raise BetError("BET_NOT_FOUND", "投注不存在")
        return self._bet(row)

    def list_mine(
        self,
        account_id: str,
        round_id: str | None = None,
        status: str | None = None,
    ) -> dict[str, object]:
        if status is not None and status not in ALLOWED_STATUSES:
            raise BetError("INVALID_STATUS", "投注状态无效")
        rows = self.store.list_for_account(account_id, round_id=round_id, status=status)
        return {"items": [self._bet(row) for row in rows]}

    @atomic_command
    def cancel(self, account_id: str, bet_id: str) -> dict[str, object]:
        row = self.store.get(bet_id)
        if row is None or row["account_id"] != account_id:
            raise BetError("BET_NOT_FOUND", "投注不存在")
        not_cancellable = BetError("BET_NOT_CANCELLABLE", "当前投注无法取消")
        if row["status"] != "ACCEPTED":
            raise not_cancellable
        try:
            round_row = self.rounds.get(row["round_id"])
        except RoundError as error:
            raise not_cancellable from error
        if round_row["status"] != "OPEN":
            raise not_cancellable
        if not self.store.transition(bet_id, "ACCEPTED", "CANCELLED"):
            raise not_cancellable
        if row["hold_id"]:
            self.ledger.release_if_active(account_id, row["hold_id"])
        return self._bet(self.store.get(bet_id), message="投注已取消，积分已解冻")

    def _bet(self, row: object, message: str | None = None) -> dict[str, object]:
        selection = json.loads(row["selection_json"])  # type: ignore[index]
        odds_snapshot = json.loads(row["odds_snapshot_json"])  # type: ignore[index]
        round_id = str(row["round_id"])  # type: ignore[index]
        round_code = ""
        try:
            round_code = str(self.rounds.get(round_id).get("code") or "")
        except RoundError:
            pass

        body: dict[str, object] = {
            "bet_id": row["bet_id"],  # type: ignore[index]
            "account_id": row["account_id"],  # type: ignore[index]
            "round_id": round_id,
            "round_code": round_code,
            "play_id": row["play_id"],  # type: ignore[index]
            "rule_version": row["rule_version"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
            "selection": selection,
            "odds_snapshot": odds_snapshot,
            "hold_id": row["hold_id"],  # type: ignore[index]
            "numbers": selection.get("numbers") if isinstance(selection, dict) else None,
            "stake": int(row["stake"]),  # type: ignore[index]
            "idempotency_key": row["idempotency_key"],  # type: ignore[index]
            "created_at": row["created_at"],  # type: ignore[index]
        }
        body.update(self._settlement_summary(row, odds_snapshot))
        if message is not None:
            body["message"] = message
        return body

    def _settlement_summary(
        self,
        row: object,
        odds_snapshot: object,
    ) -> dict[str, object]:
        empty: dict[str, object] = {
            "settlement_result": None,
            "settlement_finalized": False,
            "settlement_delta": None,
            "settlement_return": None,
            "settlement_recorded_at": None,
        }
        if self.settlements is None:
            return empty
        settlement = self.settlements.get_by_bet(str(row["bet_id"]))  # type: ignore[index]
        if settlement is None:
            return empty

        result = str(settlement["result"])
        finalized = str(row["status"]) == "SETTLED"  # type: ignore[index]
        stake = int(row["stake"])  # type: ignore[index]
        delta: int | None = None
        returned: int | None = None
        if finalized:
            if result == "WIN":
                multiplier = self._multiplier(odds_snapshot)
                delta = stake * (multiplier - 1)
                returned = stake * multiplier
            elif result == "LOSS":
                delta = -stake
                returned = 0
            elif result == "VOID":
                delta = 0
                returned = stake

        return {
            "settlement_result": result,
            "settlement_finalized": finalized,
            "settlement_delta": delta,
            "settlement_return": returned,
            "settlement_recorded_at": settlement["created_at"],
        }

    @staticmethod
    def _multiplier(odds_snapshot: object) -> int:
        if isinstance(odds_snapshot, dict):
            try:
                value = int(odds_snapshot.get("multiplier", 2))
                if value > 0:
                    return value
            except (TypeError, ValueError):
                pass
        return 2
