import os
import tempfile
from pathlib import Path

_test_dir = Path(tempfile.mkdtemp(prefix="lottery-forum-test-"))
os.environ["LOTTERY_FORUM_DB"] = str(_test_dir / "wallet.sqlite")
# Settlement/round writes are admin-only; tests use this env-granted admin username.
os.environ["LOTTERY_FORUM_ADMIN_USERNAMES"] = "pytest-admin"
