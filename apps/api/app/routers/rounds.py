from fastapi import APIRouter, Depends, HTTPException, Request

from app.routers.auth import current_account, require_admin
from app.rounds.service import RoundError

router = APIRouter(prefix="/rounds", tags=["rounds"])


def _raise_round(error: RoundError) -> None:
    status = 404 if error.code == "ROUND_NOT_FOUND" else 400
    raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error


@router.post("")
def create_round(
    payload: dict[str, str],
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account  # admin only
    try:
        return request.app.state.services.rounds.create(
            payload.get("lottery_id", ""),
            payload.get("code"),
        )
    except RoundError as error:
        _raise_round(error)


@router.get("")
def list_rounds(
    request: Request,
    lottery_id: str | None = None,
    account: object = Depends(current_account),
) -> dict[str, object]:
    del account
    return {"rounds": request.app.state.services.rounds.list(lottery_id)}


@router.get("/{round_id}")
def get_round(
    round_id: str,
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.rounds.get(round_id)
    except RoundError as error:
        _raise_round(error)


@router.post("/{round_id}/open")
def open_round(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.rounds.open(round_id)
    except RoundError as error:
        _raise_round(error)


@router.post("/{round_id}/close")
def close_round(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.rounds.close(round_id)
    except RoundError as error:
        _raise_round(error)


@router.post("/{round_id}/draw")
def draw_round(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.rounds.draw(round_id)
    except RoundError as error:
        _raise_round(error)


@router.post("/{round_id}/settling")
def settling_round(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    del account
    try:
        return request.app.state.services.rounds.settling(round_id)
    except RoundError as error:
        _raise_round(error)
