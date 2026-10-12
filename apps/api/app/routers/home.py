from fastapi import APIRouter, HTTPException, Request

from app.home.service import HomeError

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/banners")
def list_banners(request: Request) -> dict[str, object]:
    return {"banners": request.app.state.services.home.list_banners()}


@router.get("/announcements")
def list_announcements(request: Request) -> dict[str, object]:
    return {"announcements": request.app.state.services.home.list_announcements()}


@router.get("/announcements/{announcement_id}")
def get_announcement(announcement_id: str, request: Request) -> dict[str, object]:
    try:
        return request.app.state.services.home.get_announcement(announcement_id)
    except HomeError as error:
        status = 404 if error.code == "ANNOUNCEMENT_NOT_FOUND" else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error
