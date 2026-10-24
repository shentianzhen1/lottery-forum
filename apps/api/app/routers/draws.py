from fastapi import APIRouter, Depends, HTTPException, Request

from app.draws.service import DrawObservationError
from app.routers.auth import require_admin

router = APIRouter(prefix="/draws", tags=["draws"])


@router.post("/observations")
def record_observation(
    payload: dict[str, object],
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.draws.record(payload)
    except DrawObservationError as error:
        raise HTTPException(
            status_code=400,
            detail={"code": error.code, "message": error.message},
        ) from error


@router.get("/observations")
def list_observations(
    request: Request,
    lottery_id: str | None = None,
    normalized_code: str | None = None,
    provider: str | None = None,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    return request.app.state.services.draws.list_observations(
        lottery_id=lottery_id,
        normalized_code=normalized_code,
        provider=provider,
    )
