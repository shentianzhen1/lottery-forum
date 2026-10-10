import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.auth.passwords import hash_password, verify_password
from app.auth.store import Account, AccountStore
from app.ledger.model import Direction, LedgerError, PostRequest, Reason
from app.ledger.service import LedgerService

OPENING_POINTS = 100
SESSION_HOURS = 24
MAX_LOGIN_FAILURES = 5


class AuthError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class AuthService:
    def __init__(self, accounts: AccountStore, ledger: LedgerService) -> None:
        self.accounts = accounts
        self.ledger = ledger
        self.failures: dict[str, int] = {}

    def register(self, username: str, password: str) -> tuple[Account, str]:
        cleaned = username.strip()
        self._check_lengths(cleaned, password)
        if self.accounts.by_username(cleaned) is not None:
            raise AuthError("USERNAME_TAKEN", "用户名已存在")
        account = Account(str(uuid4()), cleaned, hash_password(password), "user")
        self.accounts.create(account)
        self.ledger.post(
            PostRequest(
                account_id=account.account_id,
                direction=Direction.CREDIT,
                amount=OPENING_POINTS,
                reason=Reason.OPENING_GRANT,
                reference_type="system",
                reference_id=f"opening:{account.account_id}",
                idempotency_key=f"opening:{account.account_id}",
                operator_id="system",
            )
        )
        return account, self._session(account.account_id)

    def login(self, username: str, password: str) -> tuple[Account, str]:
        cleaned = username.strip()
        self._check_lengths(cleaned, password)
        if self.failures.get(cleaned, 0) >= MAX_LOGIN_FAILURES:
            raise AuthError("LOGIN_LIMITED", "登录失败次数过多")
        account = self.accounts.by_username(cleaned)
        if account is None or not verify_password(password, account.password_hash):
            self.failures[cleaned] = self.failures.get(cleaned, 0) + 1
            raise AuthError("INVALID_LOGIN", "用户名或密码不正确")
        self.failures.pop(cleaned, None)
        return account, self._session(account.account_id)

    def logout(self, token: str) -> None:
        self.accounts.delete_session(_token_hash(token))

    def account_from_token(self, token: str) -> Account:
        account = self.accounts.account_for_token(_token_hash(token), _now())
        if account is None:
            raise AuthError("UNAUTHENTICATED", "登录已失效")
        return account

    def _session(self, account_id: str) -> str:
        token = secrets.token_urlsafe(32)
        expires_at = (datetime.now(timezone.utc) + timedelta(hours=SESSION_HOURS)).isoformat()
        self.accounts.save_session(_token_hash(token), account_id, expires_at)
        return token

    def _check_lengths(self, username: str, password: str) -> None:
        if not 3 <= len(username) <= 32 or not 8 <= len(password) <= 72:
            raise AuthError("INVALID_CREDENTIALS", "用户名需 3 到 32 个字符，密码需 8 到 72 个字符")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def auth_error_from_ledger(error: LedgerError) -> AuthError:
    return AuthError(error.code, error.message)
