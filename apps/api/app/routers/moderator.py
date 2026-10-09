from fastapi import APIRouter

from app.routers.errors import not_implemented

router = APIRouter(prefix="/moderator", tags=["moderator"])


@router.get("/applications")
def applications() -> None:
    not_implemented("版主申请尚未实现")
