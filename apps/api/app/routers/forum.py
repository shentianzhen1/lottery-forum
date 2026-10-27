from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.forum.service import ForumError
from app.routers.auth import current_account

router = APIRouter(prefix="/forum", tags=["forum"])


class CreateThreadBody(BaseModel):
    board_id: str
    title: str
    body: str
    tags: list[str] = Field(default_factory=list)


class CreateReplyBody(BaseModel):
    body: str


def _raise(error: ForumError) -> None:
    status = 404 if error.code in {"BOARD_NOT_FOUND", "THREAD_NOT_FOUND"} else 400
    if error.code == "THREAD_LOCKED":
        status = 409
    raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message})


@router.get("/home")
def forum_home(request: Request) -> dict[str, object]:
    return request.app.state.services.forum.home()


@router.get("/boards")
def list_boards(request: Request) -> dict[str, object]:
    return {"boards": request.app.state.services.forum.boards()}


@router.get("/threads")
def list_threads(
    request: Request,
    board_id: str | None = Query(default=None),
    q: str = Query(default="", max_length=80),
    limit: int = Query(default=20, ge=1, le=50),
) -> dict[str, object]:
    try:
        rows = request.app.state.services.forum.threads(board_id=board_id, query=q, limit=limit)
    except ForumError as error:
        _raise(error)
    return {"threads": rows}


@router.get("/threads/{thread_id}")
def get_thread(thread_id: str, request: Request) -> dict[str, object]:
    try:
        return request.app.state.services.forum.thread(thread_id)
    except ForumError as error:
        _raise(error)


@router.post("/threads")
def create_thread(
    body: CreateThreadBody,
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    try:
        return request.app.state.services.forum.create_thread(
            account_id=getattr(account, "account_id"),
            board_id=body.board_id,
            title=body.title,
            body=body.body,
            tags=body.tags,
        )
    except ForumError as error:
        _raise(error)


@router.post("/threads/{thread_id}/replies")
def create_reply(
    thread_id: str,
    body: CreateReplyBody,
    request: Request,
    account: object = Depends(current_account),
) -> dict[str, object]:
    try:
        return request.app.state.services.forum.reply(
            account_id=getattr(account, "account_id"),
            thread_id=thread_id,
            body=body.body,
        )
    except ForumError as error:
        _raise(error)
