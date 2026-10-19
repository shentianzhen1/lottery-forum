import sqlite3
import threading
from contextlib import contextmanager
from functools import wraps
from pathlib import Path


class AtomicConnection(sqlite3.Connection):
    """One serialized connection with command-owned commits and nested savepoints.

    Store methods may keep commit() for standalone use. Inside atomic(), only the
    outer command commits; a nested ledger operation cannot commit its caller.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.lock = threading.RLock()
        self._atomic_depth = 0

    def execute(self, *args, **kwargs):
        with self.lock:
            return super().execute(*args, **kwargs)

    def executemany(self, *args, **kwargs):
        with self.lock:
            return super().executemany(*args, **kwargs)

    def executescript(self, *args, **kwargs):
        with self.lock:
            if self._atomic_depth:
                raise RuntimeError("Schema scripts cannot run inside a command transaction")
            return super().executescript(*args, **kwargs)

    def commit(self):
        with self.lock:
            if not self._atomic_depth:
                super().commit()

    def rollback(self):
        with self.lock:
            if self._atomic_depth:
                raise RuntimeError("Rollback is owned by the command transaction")
            super().rollback()

    @contextmanager
    def atomic(self):
        with self.lock:
            outer = self._atomic_depth == 0
            savepoint = f"command_{self._atomic_depth}"
            if outer:
                # Never silently commit an unrelated pending write.
                if self.in_transaction:
                    raise RuntimeError("Uncommitted writes before command transaction")
                super().execute("begin immediate")
            else:
                super().execute(f"savepoint {savepoint}")
            self._atomic_depth += 1
            try:
                yield
                if outer:
                    super().commit()
                else:
                    super().execute(f"release savepoint {savepoint}")
            except BaseException:
                if outer:
                    super().rollback()
                else:
                    super().execute(f"rollback to savepoint {savepoint}")
                    super().execute(f"release savepoint {savepoint}")
                raise
            finally:
                self._atomic_depth -= 1


def require_shared_connection(*stores) -> AtomicConnection:
    connection = stores[0].connection
    if not isinstance(connection, AtomicConnection):
        raise ValueError("Transactional services require app.db.connect()")
    if any(store.connection is not connection for store in stores[1:]):
        raise ValueError("Command stores must share one connection")
    return connection


def atomic_command(method):
    """Transaction boundary for services with a SQLite store attribute."""
    @wraps(method)
    def wrapped(self, *args, **kwargs):
        with require_shared_connection(self.store).atomic():
            return method(self, *args, **kwargs)
    return wrapped


def connect(path: str | Path) -> AtomicConnection:
    # Standalone statements must not leave an implicit transaction open between
    # execute() and a store's legacy commit(); commands opt into atomic() instead.
    connection = sqlite3.connect(
        path, check_same_thread=False, factory=AtomicConnection, isolation_level=None,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("pragma foreign_keys = on")
    connection.execute("pragma busy_timeout = 5000")
    return connection
