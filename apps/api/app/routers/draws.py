from fastapi import APIRouter, Depends, HTTPException, Request

from app.draws.result_service import DrawResultError
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


@router.post("/observations/{observation_id}/confirm")
def confirm_observation(
    observation_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    try:
        return request.app.state.services.draw_results.confirm(
            observation_id,
            getattr(account, "account_id"),
        )
    except DrawResultError as error:
        if error.code == "DRAW_OBSERVATION_NOT_FOUND":
            status = 404
        elif error.code == "DRAW_RESULT_ALREADY_CONFIRMED":
            status = 409
        else:
            status = 400
        raise HTTPException(
            status_code=status,
            detail={"code": error.code, "message": error.message},
        ) from error


@router.get("/results")
def list_results(
    request: Request,
    lottery_id: str | None = None,
    normalized_code: str | None = None,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    return request.app.state.services.draw_results.list_results(
        lottery_id=lottery_id,
        normalized_code=normalized_code,
    )
