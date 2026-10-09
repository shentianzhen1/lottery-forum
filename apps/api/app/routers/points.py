from fastapi import APIRouter

from app.routers.errors import not_implemented

router = APIRouter(prefix="/points", tags=["points"])


@router.get("/balance")
def balance() -> None:
    not_implemented("积分账本尚未实现")


@router.get("/entries")
def entries() -> None:
    not_implemented("积分变动记录尚未实现")
