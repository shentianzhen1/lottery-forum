import os
import tempfile
from pathlib import Path

_test_dir = Path(tempfile.mkdtemp(prefix="lottery-forum-test-"))
os.environ["LOTTERY_FORUM_DB"] = str(_test_dir / "wallet.sqlite")
