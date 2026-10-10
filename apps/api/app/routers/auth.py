from fastapi import APIRouter, Header, HTTPException, Request

from app.auth.service import AuthError

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register")
def register(body: dict[str, str], request: Request) -> dict[str, str]:
    try:
        account, token = request.app.state.services.auth.register(
            body.get("username", ""),
            body.get("password", ""),
        )
    except AuthError as error:
        raise HTTPException(status_code=400, detail={"code": error.code, "message": error.message}) from error
    return {"account_id": account.account_id, "username": account.username, "token": token}


@router.post("/login")
def login(body: dict[str, str], request: Request) -> dict[str, str]:
    try:
        account, token = request.app.state.services.auth.login(
            body.get("username", ""),
            body.get("password", ""),
        )
    except AuthError as error:
        raise HTTPException(status_code=401, detail={"code": error.code, "message": error.message}) from error
    return {"account_id": account.account_id, "username": account.username, "token": token}


@router.post("/logout")
def logout(request: Request, authorization: str | None = Header(default=None)) -> dict[str, str]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail={"code": "UNAUTHENTICATED", "message": "需要登录"})
    request.app.state.services.auth.logout(authorization.removeprefix("Bearer ").strip())
    return {"status": "logged_out"}


def current_account(request: Request, authorization: str | None = Header(default=None)) -> object:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail={"code": "UNAUTHENTICATED", "message": "需要登录"})
    try:
        return request.app.state.services.auth.account_from_token(authorization.removeprefix("Bearer ").strip())
    except AuthError as error:
        raise HTTPException(status_code=401, detail={"code": error.code, "message": error.message}) from error
