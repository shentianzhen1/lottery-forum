from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "service": "lottery-forum-api",
        "landscape_first": True,
        "implemented": ["health", "auth", "points_read", "game_validation"],
        "not_implemented": ["moderator", "game_settlement", "points_mutation_api"],
    }
