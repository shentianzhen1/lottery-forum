from fastapi import APIRouter, Request

router = APIRouter(tags=["health"])


@router.get("/health")
def health(request: Request) -> dict[str, object]:
    database = "ok"
    try:
        request.app.state.services.ledger.store.connection.execute("select 1")
    except Exception:
        database = "error"
    return {
        "status": "ok" if database == "ok" else "degraded",
        "service": "lottery-forum-api",
        "database": database,
        "landscape_first": True,
        "implemented": ["health", "auth", "points_read", "game_validation", "game_stake"],
        "not_implemented": ["moderator", "game_payout", "points_mutation_api"],
    }
