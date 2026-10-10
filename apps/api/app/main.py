import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

from app.routers import auth, games, health, moderator, points, users
from app.state import build_state

logger = logging.getLogger("lottery_forum")


def create_app() -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        database = Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
        app.state.services = build_state(database)
        logger.info("api started")
        yield
        logger.info("api stopped")

    app = FastAPI(
        title="彩票论坛",
        version="0.1.0",
        description="横屏优先的多玩法基础平台。当前不提供现金充值、提现、兑付或用户间积分转账。",
        lifespan=lifespan,
    )
    app.include_router(health.router)
    app.include_router(auth.router, prefix="/api/v1")
    app.include_router(users.router, prefix="/api/v1")
    app.include_router(points.router, prefix="/api/v1")
    app.include_router(games.router, prefix="/api/v1")
    app.include_router(moderator.router, prefix="/api/v1")
    app.state.services = build_state()
    return app


app = create_app()
