from fastapi import APIRouter

from app.routers.errors import not_implemented

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
def current_user() -> None:
    not_implemented("账户与鉴权尚未实现")
