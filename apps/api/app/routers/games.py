from fastapi import APIRouter, HTTPException, Request

from app.games.model import GameError

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
