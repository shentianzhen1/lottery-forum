from fastapi import APIRouter, Depends, HTTPException, Request

from app.routers.auth import require_admin
from app.settlements.service import SettlementError

router = APIRouter(prefix="/settlements", tags=["settlements"])


def _raise_settlement(error: SettlementError) -> None:
    status = 404 if error.code in {"ROUND_NOT_FOUND", "BET_NOT_FOUND"} else 400
    raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error


@router.post("/{round_id}")
def record_settlements(
    round_id: str,
    payload: dict[str, object],
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    # Admin only, including moderators of the round's board: the board moderator is the payer
    # (版主赔付) and must not judge their own payout results.
    del account
    results = payload.get("results", [])
    if not isinstance(results, list):
        raise HTTPException(
            status_code=400,
            detail={"code": "INVALID_RESULTS", "message": "须提供至少一条结算结果"},
        )
    try:
        return request.app.state.services.settlements.record(round_id, results)
    except SettlementError as error:
        _raise_settlement(error)


@router.get("/{round_id}")
def list_settlements(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    # Whole-round settlement rows contain other players' bet ids/results, so this
    # endpoint remains an administrative view. Players read only their own
    # settlement summary through /bets.
    del account
    try:
        return request.app.state.services.settlements.list_for_round(round_id)
    except SettlementError as error:
        _raise_settlement(error)
