import hashlib
import secrets
from uuid import uuid4

from app.auth.passwords import hash_password, verify_password
from app.auth.store import Account, AccountStore
from app.ledger.model import LedgerError
from app.ledger.service import LedgerService


class AuthError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class AuthService:
    def __init__(self, accounts: AccountStore, ledger: LedgerService) -> None:
        self.accounts = accounts
        self.ledger = ledger

    def register(self, username: str, password: str) -> tuple[Account, str]:
        cleaned = username.strip()
        if len(cleaned) < 3 or len(password) < 8:
            raise AuthError("INVALID_CREDENTIALS", "用户名至少 3 个字符，密码至少 8 个字符")
        if self.accounts.by_username(cleaned) is not None:
            raise AuthError("USERNAME_TAKEN", "用户名已存在")
        account = Account(str(uuid4()), cleaned, hash_password(password), "user")
        self.accounts.create(account)
        self.ledger.balance(account.account_id)
        return account, self._session(account.account_id)

    def login(self, username: str, password: str) -> tuple[Account, str]:
        account = self.accounts.by_username(username.strip())
        if account is None or not verify_password(password, account.password_hash):
            raise AuthError("INVALID_LOGIN", "用户名或密码不正确")
        return account, self._session(account.account_id)

    def account_from_token(self, token: str) -> Account:
        account = self.accounts.account_for_token(_token_hash(token))
        if account is None:
            raise AuthError("UNAUTHENTICATED", "登录已失效")
        return account

    def _session(self, account_id: str) -> str:
        token = secrets.token_urlsafe(32)
        self.accounts.save_session(_token_hash(token), account_id)
        return token


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def auth_error_from_ledger(error: LedgerError) -> AuthError:
    return AuthError(error.code, error.message)
