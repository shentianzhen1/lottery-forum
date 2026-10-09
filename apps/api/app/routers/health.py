from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "service": "lottery-forum-api",
        "landscape_first": True,
        "implemented": ["health"],
        "not_implemented": ["auth", "points_ledger", "moderator", "games"],
    }
