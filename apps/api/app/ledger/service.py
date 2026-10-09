"""积分账本规则。余额只由分录投影，历史分录不删除。"""

from uuid import uuid4

from app.ledger.model import Direction, Entry, LedgerError, PostRequest, Reason
from app.ledger.store import LedgerStore


class LedgerService:
    def __init__(self, store: LedgerStore) -> None:
        self.store = store

    def post(self, request: PostRequest) -> Entry:
        self._validate(request)
        existing = self.store.find_by_idempotency(request.account_id, request.idempotency_key)
        if existing is not None:
            self._ensure_same_payload(existing, request)
            return existing
        self.store.ensure_account(request.account_id)
        balance = self.store.balance(request.account_id)
        if request.direction is Direction.DEBIT and balance < request.amount:
            raise LedgerError("INSUFFICIENT_POINTS", "积分余额不足")
        entry = Entry(
            entry_id=str(uuid4()),
            account_id=request.account_id,
            direction=request.direction,
            amount=request.amount,
            reason=request.reason,
            reference_type=request.reference_type,
            reference_id=request.reference_id,
            idempotency_key=request.idempotency_key,
            operator_id=request.operator_id,
            note=request.note,
            corrects_entry_id=request.corrects_entry_id,
        )
        self.store.append(entry)
        return entry

    def balance(self, account_id: str) -> int:
        self.store.ensure_account(account_id)
        return self.store.balance(account_id)

    def entries(self, account_id: str) -> list[Entry]:
        return self.store.entries(account_id)

    def _validate(self, request: PostRequest) -> None:
        if not request.account_id or not request.operator_id or not request.idempotency_key:
            raise LedgerError("INVALID_ENTRY", "账户、操作者和幂等键不能为空")
        if request.amount <= 0:
            raise LedgerError("INVALID_AMOUNT", "积分数量必须是正整数")
        if request.reason is Reason.OPENING_GRANT and request.direction is not Direction.CREDIT:
            raise LedgerError("INVALID_REASON", "开户发放只能入账")
        if request.reason is Reason.CORRECTION and not request.corrects_entry_id:
            raise LedgerError("CORRECTION_REQUIRES_SOURCE", "纠错必须引用原分录")
        if request.reason is not Reason.CORRECTION and request.corrects_entry_id:
            raise LedgerError("INVALID_REASON", "只有纠错可以引用原分录")
        if request.corrects_entry_id:
            source = self.store.get(request.corrects_entry_id)
            if source is None or source.account_id != request.account_id:
                raise LedgerError("SOURCE_NOT_FOUND", "被纠错的原分录不存在")
            if request.direction is source.direction or request.amount != source.amount:
                raise LedgerError("INVALID_CORRECTION", "纠错必须是等额反向分录")

    def _ensure_same_payload(self, existing: Entry, request: PostRequest) -> None:
        same = (
            existing.direction is request.direction
            and existing.amount == request.amount
            and existing.reason is request.reason
            and existing.reference_type == request.reference_type
            and existing.reference_id == request.reference_id
        )
        if not same:
            raise LedgerError("IDEMPOTENCY_CONFLICT", "相同幂等键不能用于不同记账请求")
