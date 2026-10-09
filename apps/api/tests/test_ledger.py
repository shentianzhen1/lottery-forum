import pytest

from app.ledger.model import Direction, LedgerError, PostRequest, Reason
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


def service() -> LedgerService:
    return LedgerService(SqliteLedgerStore())


def request(**overrides: object) -> PostRequest:
    values: dict[str, object] = {
        "account_id": "user-1",
        "direction": Direction.CREDIT,
        "amount": 100,
        "reason": Reason.OPENING_GRANT,
        "reference_type": "system",
        "reference_id": "grant-1",
        "idempotency_key": "grant-1",
        "operator_id": "system",
    }
    values.update(overrides)
    return PostRequest(**values)  # type: ignore[arg-type]


def test_credit_projects_balance_and_keeps_entry() -> None:
    ledger = service()
    entry = ledger.post(request())
    assert ledger.balance("user-1") == 100
    assert ledger.entries("user-1") == [entry]


def test_duplicate_idempotency_key_does_not_double_post() -> None:
    ledger = service()
    first = ledger.post(request())
    second = ledger.post(request())
    assert second == first
    assert ledger.balance("user-1") == 100
    assert len(ledger.entries("user-1")) == 1


def test_same_key_with_different_payload_conflicts() -> None:
    ledger = service()
    ledger.post(request())
    with pytest.raises(LedgerError) as caught:
        ledger.post(request(amount=80))
    assert caught.value.code == "IDEMPOTENCY_CONFLICT"
    assert ledger.balance("user-1") == 100


def test_debit_cannot_make_balance_negative() -> None:
    ledger = service()
    ledger.post(request())
    with pytest.raises(LedgerError) as caught:
        ledger.post(
            request(
                direction=Direction.DEBIT,
                amount=101,
                reason=Reason.GAME_SETTLEMENT,
                reference_type="game",
                reference_id="round-1",
                idempotency_key="round-1",
            )
        )
    assert caught.value.code == "INSUFFICIENT_POINTS"
    assert ledger.balance("user-1") == 100


def test_correction_is_a_new_reversing_entry() -> None:
    ledger = service()
    original = ledger.post(request())
    correction = ledger.post(
        request(
            direction=Direction.DEBIT,
            reason=Reason.CORRECTION,
            reference_type="entry",
            reference_id=original.entry_id,
            idempotency_key="correct-1",
            operator_id="auditor-1",
            corrects_entry_id=original.entry_id,
        )
    )
    assert correction.corrects_entry_id == original.entry_id
    assert ledger.balance("user-1") == 0
    assert len(ledger.entries("user-1")) == 2


def test_opening_grant_cannot_debit() -> None:
    ledger = service()
    with pytest.raises(LedgerError) as caught:
        ledger.post(request(direction=Direction.DEBIT, amount=1))
    assert caught.value.code == "INVALID_REASON"


def test_entries_are_not_deleted_by_store_api() -> None:
    ledger = service()
    ledger.post(request())
    assert not hasattr(ledger.store, "delete")
    assert len(ledger.entries("user-1")) == 1
