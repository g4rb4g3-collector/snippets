"""KVStore — minimalny wrapper na SQLite jako key-value store.

Jedna tabela, do 4 stringowych kluczy (key1..key4) i wartość JSON.
Metody set/get/update/delete przyjmują dynamicznie 1..4 klucze pozycyjnie.
Operacje można grupować w transakcję przez `with store.transaction():`.

Przykład:
    store = KVStore("data.db")
    store.set("users", "active", value={"name": "Ala"})
    store.get("users", "active")            # -> {"name": "Ala"}
    with store.transaction():
        store.update("users", "active", value={"name": "Ola"})
        store.delete("users", "active")
"""
import json
import sqlite3
from contextlib import contextmanager
from typing import Any, Iterator

_MAX_KEYS = 4
_MISSING = ""  # sentinel for unused key positions; klucze nie mogą być pustym stringiem


class KVStore:
    def __init__(self, path: str = ":memory:"):
        self._conn = sqlite3.connect(path)
        self._tx_depth = 0
        self._conn.execute(
            """
            CREATE TABLE IF NOT EXISTS kv (
                key1 TEXT NOT NULL,
                key2 TEXT NOT NULL DEFAULT '',
                key3 TEXT NOT NULL DEFAULT '',
                key4 TEXT NOT NULL DEFAULT '',
                value TEXT NOT NULL,
                PRIMARY KEY (key1, key2, key3, key4)
            )
            """
        )
        self._conn.commit()

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> "KVStore":
        return self

    def __exit__(self, *_: Any) -> None:
        self.close()

    def _commit(self) -> None:
        if self._tx_depth == 0:
            self._conn.commit()

    @contextmanager
    def transaction(self) -> Iterator["KVStore"]:
        """Grupuje operacje w jedną transakcję. Rollback przy wyjątku.

        Wspiera zagnieżdżanie — tylko najbardziej zewnętrzne `with` faktycznie
        commituje/rollbackuje; wyjątek w wewnętrznym bloku przerywa też zewnętrzny.
        """
        self._tx_depth += 1
        try:
            yield self
        except Exception:
            if self._tx_depth == 1:
                self._conn.rollback()
            self._tx_depth -= 1
            raise
        else:
            self._tx_depth -= 1
            if self._tx_depth == 0:
                self._conn.commit()

    @staticmethod
    def _normalize(keys: tuple) -> tuple:
        if not 1 <= len(keys) <= _MAX_KEYS:
            raise ValueError(f"expected 1..{_MAX_KEYS} keys, got {len(keys)}")
        for k in keys:
            if not isinstance(k, str):
                raise TypeError(f"keys must be str, got {type(k).__name__}")
            if k == _MISSING:
                raise ValueError("key cannot be empty string")
        return keys + (_MISSING,) * (_MAX_KEYS - len(keys))

    def set(self, *keys: str, value: Any) -> None:
        full = self._normalize(keys)
        self._conn.execute(
            "INSERT OR REPLACE INTO kv (key1, key2, key3, key4, value) "
            "VALUES (?, ?, ?, ?, ?)",
            (*full, json.dumps(value)),
        )
        self._commit()

    def get(self, *keys: str, default: Any = None) -> Any:
        full = self._normalize(keys)
        row = self._conn.execute(
            "SELECT value FROM kv WHERE key1=? AND key2=? AND key3=? AND key4=?",
            full,
        ).fetchone()
        return default if row is None else json.loads(row[0])

    def update(self, *keys: str, value: Any) -> bool:
        """Aktualizuje istniejący wpis. Zwraca True jeśli wpis istniał."""
        full = self._normalize(keys)
        cur = self._conn.execute(
            "UPDATE kv SET value=? WHERE key1=? AND key2=? AND key3=? AND key4=?",
            (json.dumps(value), *full),
        )
        self._commit()
        return cur.rowcount > 0

    def delete(self, *keys: str) -> bool:
        """Usuwa wpis. Zwraca True jeśli wpis istniał."""
        full = self._normalize(keys)
        cur = self._conn.execute(
            "DELETE FROM kv WHERE key1=? AND key2=? AND key3=? AND key4=?",
            full,
        )
        self._commit()
        return cur.rowcount > 0
