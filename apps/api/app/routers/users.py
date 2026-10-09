from fastapi import APIRouter, Depends, Request

from app.routers.auth import current_account

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
def current_user(request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    return {
        "account_id": account.account_id,  # type: ignore[attr-defined]
        "username": account.username,  # type: ignore[attr-defined]
        "role": account.role,  # type: ignore[attr-defined]
        "points_balance": request.app.state.services.ledger.balance(account.account_id),  # type: ignore[attr-defined]
    }
