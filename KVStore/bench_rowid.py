"""Porównanie KVStore: domyślny schemat (rowid) vs `WITHOUT ROWID`.

Tworzymy plik DB ręcznie z odpowiednim CREATE TABLE, potem podpinamy
KVStore (jego CREATE TABLE IF NOT EXISTS jest no-op).
"""
import os
import sqlite3
import tempfile
import time

from kvstore import KVStore

N = 50_000


def fresh_path() -> str:
    fd, p = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    return p


def make_store(without_rowid: bool) -> tuple[str, KVStore]:
    path = fresh_path()
    if without_rowid:
        c = sqlite3.connect(path)
        c.execute(
            """
            CREATE TABLE kv (
                key1 TEXT NOT NULL,
                key2 TEXT NOT NULL DEFAULT '',
                key3 TEXT NOT NULL DEFAULT '',
                key4 TEXT NOT NULL DEFAULT '',
                value TEXT NOT NULL,
                PRIMARY KEY (key1, key2, key3, key4)
            ) WITHOUT ROWID
            """
        )
        c.commit()
        c.close()
    return path, KVStore(path)


def run(label: str, without_rowid: bool) -> None:
    path, store = make_store(without_rowid)
    try:
        t0 = time.perf_counter()
        with store.transaction():
            for i in range(N):
                store.set("game", "users", str(i), value={"i": i, "email": f"u{i}@x"})
        write_dt = time.perf_counter() - t0

        t0 = time.perf_counter()
        for i in range(N):
            store.get("game", "users", str(i))
        read_dt = time.perf_counter() - t0

        t0 = time.perf_counter()
        store.items("game", "users")
        scan_dt = time.perf_counter() - t0

        store.close()
        size = os.path.getsize(path)
        print(
            f"{label:16s} | writes(tx) {N / write_dt:>9,.0f} op/s "
            f"| reads {N / read_dt:>9,.0f} op/s "
            f"| items() {scan_dt * 1000:>6.1f} ms "
            f"| size {size / 1024:>7.1f} KB"
        )
    finally:
        os.unlink(path)


print(f"N = {N}")
run("with rowid", False)
run("WITHOUT ROWID", True)
