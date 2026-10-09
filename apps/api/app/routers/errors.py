from fastapi import HTTPException


def not_implemented(message: str) -> None:
    raise HTTPException(
        status_code=501,
        detail={"code": "NOT_IMPLEMENTED", "message": message},
    )
