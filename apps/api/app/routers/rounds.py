"""Rounds API.

Permissions (版主归属期号与权限):
- POST /rounds: admin may create with or without board_id (any board). A non-admin must pass the
  board_id of a board they own; otherwise 403 FORBIDDEN.
- open/close/draw/settling: admin, or the owner of the round's board. Legacy rounds without
  board_id are admin-only.
- The permission check runs before any existence check, so a non-admin who does not own the
  target gets 403 even when the round/board does not exist (no existence leak).
- Settlements stay admin-only (see routers/settlements.py).
- POST /rounds/{id}/settled: admin only. Applies VOID/LOSS ledger effects then SETTLING→SETTLED.
"""
from fastapi import APIRouter, Depends, HTTPException, Request

from app.auth.service import ADMIN_ROLE
from app.routers.auth import current_account, require_admin
from app.rounds.service import RoundError
from app.settlements.service import SettlementError

router = APIRouter(prefix="/rounds", tags=["rounds"])

FORBIDDEN_DETAIL = {"code": "FORBIDDEN", "message": "无权限执行此操作"}
NOT_FOUND_CODES = {"ROUND_NOT_FOUND", "BOARD_NOT_FOUND"}


def _raise_round(error: RoundError) -> None:
    status = 404 if error.code in NOT_FOUND_CODES else 400
    raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error


def _forbidden() -> None:
    raise HTTPException(status_code=403, detail=FORBIDDEN_DETAIL)


def _is_admin(account: object) -> bool:
    return getattr(account, "role", None) == ADMIN_ROLE


def _require_round_operator(request: Request, round_id: str, account: object) -> None:
    """Admin, or owner of the round's board. Legacy (board_id null) and missing rounds: admin only."""
    if _is_admin(account):
        return
    owner = request.app.state.services.rounds.round_owner(round_id)
    if owner is None or owner != account.account_id:  # type: ignore[attr-defined]
        _forbidden()


@router.post("")
def create_round(
    payload: dict[str, str],
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    rounds = request.app.state.services.rounds
    board_id = payload.get("board_id") or None
    if not _is_admin(account):
        owner = rounds.board_owner(board_id)
        if owner is None or owner != account.account_id:  # type: ignore[attr-defined]
            _forbidden()
    try:
        return rounds.create(payload.get("lottery_id", ""), payload.get("code"), board_id)
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


def _advance(request: Request, round_id: str, account: object, step: str) -> dict[str, object]:
    _require_round_operator(request, round_id, account)
    try:
        return getattr(request.app.state.services.rounds, step)(round_id)
    except RoundError as error:
        _raise_round(error)


@router.post("/{round_id}/open")
def open_round(round_id: str, request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    return _advance(request, round_id, account, "open")


@router.post("/{round_id}/close")
def close_round(round_id: str, request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    return _advance(request, round_id, account, "close")


@router.post("/{round_id}/draw")
def draw_round(round_id: str, request: Request, account: object = Depends(current_account)) -> dict[str, object]:
    return _advance(request, round_id, account, "draw")


@router.post("/{round_id}/settling")
def settling_round(
    round_id: str, request: Request, account: object = Depends(current_account)
) -> dict[str, object]:
    return _advance(request, round_id, account, "settling")


@router.post("/{round_id}/settled")
def settled_round(
    round_id: str,
    request: Request,
    account: object = Depends(require_admin),
) -> dict[str, object]:
    """Admin-only: finalize VOID/LOSS and advance SETTLING → SETTLED."""
    try:
        return request.app.state.services.settlements.finalize(
            round_id, operator_id=account.account_id  # type: ignore[attr-defined]
        )
    except SettlementError as error:
        status = 404 if error.code in {"ROUND_NOT_FOUND", "BOARD_NOT_FOUND", "BET_NOT_FOUND"} else 400
        raise HTTPException(
            status_code=status, detail={"code": error.code, "message": error.message}
        ) from error
    except RoundError as error:
        _raise_round(error)
