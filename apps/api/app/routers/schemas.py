from pydantic import BaseModel, Field


class Credentials(BaseModel):
    username: str = Field(min_length=1, max_length=32)
    password: str = Field(min_length=1, max_length=72)


class SelectionRequest(BaseModel):
    numbers: list[int]
    idempotency_key: str = Field(min_length=1, max_length=80)
