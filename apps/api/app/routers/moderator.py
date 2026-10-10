from fastapi import APIRouter, Depends, HTTPException, Request

from app.routers.auth import current_account

router = APIRouter(prefix="/moderator", tags=["moderator"])


@router.get("/settings")
def settings(request: Request) -> dict[str, int]:
    return {"threshold": request.app.state.services.moderator.store.threshold()}


@router.post("/boards")
def open_board(
    payload: dict[str, str],
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    result = request.app.state.services.moderator.open_board(
        account.account_id,  # type: ignore[attr-defined]
        payload.get("lottery_id", ""),
    )
    if "code" in result:
        raise HTTPException(status_code=400, detail=result)
    return result


@router.get("/boards/me")
def my_boards(request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    return {
        "account_id": account.account_id,  # type: ignore[attr-defined]
        "boards": request.app.state.services.moderator.boards(account.account_id),  # type: ignore[attr-defined]
    }
