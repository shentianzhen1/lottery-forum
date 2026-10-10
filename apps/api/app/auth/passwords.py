import hashlib
import hmac
import os


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    n, r, p = 2**14, 8, 1
    digest = hashlib.scrypt(password.encode(), salt=salt, n=n, r=r, p=p)
    return f"scrypt${n}${r}${p}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    if stored.startswith("scrypt$"):
        _, n, r, p, salt_hex, digest_hex = stored.split("$")
        digest = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt_hex), n=int(n), r=int(r), p=int(p))
        return hmac.compare_digest(digest.hex(), digest_hex)
    salt_hex, digest_hex = stored.split("$", 1)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt_hex), 120_000)
    return hmac.compare_digest(digest.hex(), digest_hex)
