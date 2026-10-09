"""用户积分接口。只允许登录用户查询自己的账本。"""

from fastapi import APIRouter, Depends, Request

from app.routers.auth import current_account

router = APIRouter(prefix="/points", tags=["points"])


@router.get("/balance")
def balance(request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    book_balance = request.app.state.services.ledger.balance(account.account_id)  # type: ignore[attr-defined]
    frozen = request.app.state.services.ledger.frozen(account.account_id)  # type: ignore[attr-defined]
    return {
        "account_id": account.account_id,  # type: ignore[attr-defined]
        "balance": book_balance,
        "frozen": frozen,
        "available": book_balance - frozen,
    }


@router.get("/entries")
def entries(request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    rows = request.app.state.services.ledger.entries(account.account_id)  # type: ignore[attr-defined]
    return {
        "account_id": account.account_id,  # type: ignore[attr-defined]
        "entries": [
            {
                "entry_id": row.entry_id,
                "direction": row.direction.value,
                "amount": row.amount,
                "reason": row.reason.value,
                "reference_type": row.reference_type,
                "reference_id": row.reference_id,
                "created_by": row.operator_id,
            }
            for row in rows
        ],
    }
