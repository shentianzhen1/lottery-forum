from app.moderator.store import Application, ModeratorStore


class ModeratorError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class ModeratorService:
    def __init__(self, store: ModeratorStore) -> None:
        self.store = store

    def apply(self, account_id: str, statement: str) -> Application:
        text = statement.strip()
        if len(text) < 10 or len(text) > 200:
            raise ModeratorError("INVALID_STATEMENT", "申请说明需要 10 到 200 个字符")
        if self.store.pending_for_account(account_id) is not None:
            raise ModeratorError("APPLICATION_PENDING", "已有待审核申请")
        return self.store.add(account_id, text)

    def own(self, account_id: str) -> list[Application]:
        return self.store.for_account(account_id)
