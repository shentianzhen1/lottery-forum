import json
import sqlite3
from uuid import uuid4

from app.bets.store import BetStore
from app.games.model import GameError
from app.games.registry import GameRegistry
from app.ledger.model import LedgerError
from app.ledger.service import LedgerService
from app.rounds.service import RoundError, RoundService

# Fixed demo stake for stake_enabled plays this slice. Not a final pricing rule.
STAKE = 10

# Placeholder odds only — no cash amounts, no formal payout.
ODDS_SNAPSHOT: dict[str, object] = {"status": "unset"}


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
    ) -> None:
        self.store = store
        self.rounds = rounds
        self.games = games
        self.ledger = ledger

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
            # Concurrent same-key: hold is idempotent; return the original bet.
            existing = self.store.find_by_idempotency(account_id, idempotency_key)
            if existing is None:
                raise
            return self._bet(existing, message="已提交过，返回原投注")

        return self._bet(
            self.store.get(bet_id),
            message="投注已受理（积分已冻结占位，暂不派奖）",
        )

    def get(self, account_id: str, bet_id: str) -> dict[str, object]:
        row = self.store.get(bet_id)
        if row is None or row["account_id"] != account_id:
            raise BetError("BET_NOT_FOUND", "投注不存在")
        return self._bet(row)

    def _bet(self, row: object, message: str | None = None) -> dict[str, object]:
        body: dict[str, object] = {
            "bet_id": row["bet_id"],  # type: ignore[index]
            "account_id": row["account_id"],  # type: ignore[index]
            "round_id": row["round_id"],  # type: ignore[index]
            "play_id": row["play_id"],  # type: ignore[index]
            "rule_version": row["rule_version"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
            "selection": json.loads(row["selection_json"]),  # type: ignore[index]
            "odds_snapshot": json.loads(row["odds_snapshot_json"]),  # type: ignore[index]
            "hold_id": row["hold_id"],  # type: ignore[index]
            "stake": int(row["stake"]),  # type: ignore[index]
            "idempotency_key": row["idempotency_key"],  # type: ignore[index]
        }
        if message is not None:
            body["message"] = message
        return body
