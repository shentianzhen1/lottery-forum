"""用户积分接口。账本规则已在领域层测试，鉴权完成前不开放查询。"""

from fastapi import APIRouter

from app.routers.errors import not_implemented

router = APIRouter(prefix="/points", tags=["points"])


@router.get("/balance")
def balance() -> None:
    not_implemented("积分查询尚未开放，鉴权未实现")


@router.get("/entries")
def entries() -> None:
    not_implemented("积分变动查询尚未开放，鉴权未实现")
