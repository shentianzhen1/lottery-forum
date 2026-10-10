from fastapi import APIRouter, Depends, HTTPException, Request

from app.games.model import GameError
from app.games.selections import SelectionConflict
from app.ledger.model import LedgerError
from app.routers.auth import current_account

router = APIRouter(prefix="/games", tags=["games"])


@router.get("")
def list_games(request: Request) -> dict[str, object]:
    specs = request.app.state.services.games.list_enabled()
    return {
        "games": [
            {
                "game_id": spec.game_id,
                "name": spec.name,
                "kind": spec.kind,
                "version": spec.version,
                "settles_points": False,
            }
            for spec in specs
        ]
    }


@router.post("/{game_id}/validate")
def validate_game(game_id: str, body: dict[str, object], request: Request) -> dict[str, object]:
    try:
        result = request.app.state.services.games.validate(game_id, body)
    except GameError as error:
        status = 404 if error.code == "GAME_NOT_FOUND" else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error
    return {
        "game_id": result.game_id,
        "normalized": result.normalized,
        "settles_points": False,
    }


@router.post("/{game_id}/selections")
def save_selection(
    game_id: str,
    body: dict[str, object],
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    idempotency_key = body.get("idempotency_key")
    if not isinstance(idempotency_key, str) or not idempotency_key:
        raise HTTPException(status_code=400, detail={"code": "INVALID_ENTRY", "message": "缺少幂等键"})
    if game_id != "fujian-31":
        raise HTTPException(status_code=404, detail={"code": "GAME_NOT_FOUND", "message": "该玩法尚未开放选号记录"})
    try:
        result = request.app.state.services.games.validate(game_id, body)
    except GameError as error:
        raise HTTPException(status_code=400, detail={"code": error.code, "message": error.message}) from error
    account_id = account.account_id  # type: ignore[attr-defined]
    numbers = result.normalized["numbers"]
    try:
        existing = request.app.state.services.selections.save(
            account_id,
            game_id,
            numbers,  # type: ignore[arg-type]
            int(result.normalized["pair_count"]),
            idempotency_key,
        )
    except SelectionConflict as error:
        raise HTTPException(status_code=409, detail={"code": error.code, "message": error.message}) from error
    return {
        "selection_id": existing.selection_id,
        "numbers": existing.numbers,
        "pair_count": existing.pair_count,
        "stake": 0,
        "payout": 0,
    }


@router.get("/{game_id}/selections")
def list_selections(
    game_id: str,
    request: Request,
    account: object = Depends(current_account),
    limit: int = 20,
    offset: int = 0,
) -> dict[str, object]:
    rows, total = request.app.state.services.selections.for_account(
        account.account_id,  # type: ignore[attr-defined]
        game_id,
        limit,
        offset,
    )
    return {
        "selections": [
            {"selection_id": row.selection_id, "numbers": row.numbers, "pair_count": row.pair_count, "stake": 0, "payout": 0}
            for row in rows
        ],
        "limit": min(max(limit, 1), 100),
        "offset": max(offset, 0),
        "total": total,
    }


@router.post("/{game_id}/entries")
def enter_game(
    game_id: str,
    body: dict[str, object],
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    idempotency_key = body.get("idempotency_key")
    if not isinstance(idempotency_key, str) or not idempotency_key:
        raise HTTPException(status_code=400, detail={"code": "INVALID_ENTRY", "message": "缺少幂等键"})
    try:
        participation = request.app.state.services.participation.enter(
            account.account_id,  # type: ignore[attr-defined]
            game_id,
            body,
            idempotency_key,
        )
    except GameError as error:
        status = 404 if error.code == "GAME_NOT_FOUND" else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error
    except LedgerError as error:
        raise HTTPException(status_code=409, detail={"code": error.code, "message": error.message}) from error
    return {
        "entry_id": participation.entry.entry_id,
        "stake": participation.stake,
        "payout": participation.payout,
        "normalized": participation.normalized,
        "balance": request.app.state.services.ledger.balance(account.account_id),  # type: ignore[attr-defined]
    }
