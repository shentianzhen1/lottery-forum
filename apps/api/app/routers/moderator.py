from fastapi import APIRouter, Depends, HTTPException, Request

from app.moderator.service import ModeratorError
from app.routers.auth import current_account

router = APIRouter(prefix="/moderator", tags=["moderator"])


@router.get("/applications")
def applications(request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    rows = request.app.state.services.moderator.own(account.account_id)  # type: ignore[attr-defined]
    return {
        "applications": [
            {
                "application_id": row.application_id,
                "statement": row.statement,
                "status": row.status,
            }
            for row in rows
        ]
    }


@router.post("/applications")
def apply(body: dict[str, str], request: Request, account: object = Depends(current_account)) -> dict[str, str]:
    try:
        created = request.app.state.services.moderator.apply(
            account.account_id,  # type: ignore[attr-defined]
            body.get("statement", ""),
        )
    except ModeratorError as error:
        raise HTTPException(status_code=400, detail={"code": error.code, "message": error.message}) from error
    return {
        "application_id": created.application_id,
        "status": created.status,
        "statement": created.statement,
    }
