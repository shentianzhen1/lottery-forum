from fastapi import APIRouter, Depends, HTTPException, Request

from app.bets.service import BetError
from app.routers.auth import current_account

router = APIRouter(prefix="/bets", tags=["bets"])


@router.post("")
def place_bet(
    payload: dict[str, object],
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    try:
        return request.app.state.services.bets.place(
            account.account_id,  # type: ignore[attr-defined]
            payload,
        )
    except BetError as error:
        status = 404 if error.code in {"BET_NOT_FOUND", "ROUND_NOT_FOUND", "GAME_NOT_FOUND"} else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error


@router.get("/{bet_id}")
def get_bet(
    bet_id: str,
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    try:
        return request.app.state.services.bets.get(
            account.account_id,  # type: ignore[attr-defined]
            bet_id,
        )
    except BetError as error:
        status = 404 if error.code == "BET_NOT_FOUND" else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error
