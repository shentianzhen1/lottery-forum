import pytest

from app.ledger.model import Direction, LedgerError, PostRequest, Reason
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore


def ledger() -> LedgerService:
    service = LedgerService(SqliteLedgerStore())
    service.post(
        PostRequest(
            account_id="user-1",
            direction=Direction.CREDIT,
            amount=50,
            reason=Reason.OPENING_GRANT,
            reference_type="system",
            reference_id="grant",
            idempotency_key="grant",
            operator_id="system",
        )
    )
    return service


def test_hold_reduces_available_without_changing_book_balance() -> None:
    service = ledger()
    service.hold("user-1", 20, "hold-1", "system")
    assert service.balance("user-1") == 50
    assert service.frozen("user-1") == 20
    assert service.available("user-1") == 30


def test_debit_cannot_spend_frozen_points() -> None:
    service = ledger()
    service.hold("user-1", 40, "hold-1", "system")
    with pytest.raises(LedgerError) as caught:
        service.post(
            PostRequest(
                account_id="user-1",
                direction=Direction.DEBIT,
                amount=20,
                reason=Reason.GAME_SETTLEMENT,
                reference_type="game",
                reference_id="round",
                idempotency_key="round",
                operator_id="user-1",
            )
        )
    assert caught.value.code == "INSUFFICIENT_POINTS"
    assert service.balance("user-1") == 50


def test_release_restores_available_and_keeps_hold_record() -> None:
    service = ledger()
    hold_id = service.hold("user-1", 20, "hold-1", "system")
    service.release("user-1", hold_id)
    assert service.frozen("user-1") == 0
    assert service.available("user-1") == 50
    assert service.store.find_hold("user-1", "hold-1")["status"] == "released"
