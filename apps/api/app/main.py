from fastapi import FastAPI

from app.routers import health, moderator, points, users

app = FastAPI(
    title="彩票论坛",
    version="0.1.0",
    description="横屏优先的多玩法基础平台。当前不提供现金充值、提现、兑付或用户间积分转账。",
)
app.include_router(health.router)
app.include_router(users.router, prefix="/api/v1")
app.include_router(points.router, prefix="/api/v1")
app.include_router(moderator.router, prefix="/api/v1")
