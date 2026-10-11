from fastapi import APIRouter, Request

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/banners")
def list_banners(request: Request) -> dict[str, object]:
    return {"banners": request.app.state.services.home.list_banners()}


@router.get("/announcements")
def list_announcements(request: Request) -> dict[str, object]:
    return {"announcements": request.app.state.services.home.list_announcements()}
