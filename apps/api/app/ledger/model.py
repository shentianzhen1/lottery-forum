from dataclasses import dataclass
from enum import Enum


class Direction(str, Enum):
    CREDIT = "credit"
    DEBIT = "debit"


class Reason(str, Enum):
    OPENING_GRANT = "opening_grant"
    GAME_SETTLEMENT = "game_settlement"
    CORRECTION = "correction"


class LedgerError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


@dataclass(frozen=True)
class Entry:
    entry_id: str
    account_id: str
    direction: Direction
    amount: int
    reason: Reason
    reference_type: str
    reference_id: str
    idempotency_key: str
    operator_id: str
    note: str
    corrects_entry_id: str | None


@dataclass(frozen=True)
class PostRequest:
    account_id: str
    direction: Direction
    amount: int
    reason: Reason
    reference_type: str
    reference_id: str
    idempotency_key: str
    operator_id: str
    note: str = ""
    corrects_entry_id: str | None = None
