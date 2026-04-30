"""Mikrobenchmark KVStore: writes (autocommit vs transaction), reads, update, delete.

Każdy scenariusz na świeżym pliku DB. JSON value = mały dict.
"""
import os
import tempfile
import time

from kvstore import KVStore

N = 10_000


def bench(label: str, fn) -> None:
    t0 = time.perf_counter()
    fn()
    dt = time.perf_counter() - t0
    print(f"{label:42s}  {dt:6.3f} s   {N/dt:>10,.0f} op/s")


def with_db(fn) -> None:
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    try:
        store = KVStore(path)
        try:
            fn(store)
        finally:
            store.close()
    finally:
        os.unlink(path)


def writes_autocommit(store: KVStore) -> None:
    for i in range(N):
        store.set("k", str(i), value={"i": i, "name": "abc"})


def writes_in_tx(store: KVStore) -> None:
    with store.transaction():
        for i in range(N):
            store.set("k", str(i), value={"i": i, "name": "abc"})


def reads(store: KVStore) -> None:
    with store.transaction():
        for i in range(N):
            store.set("k", str(i), value={"i": i})
    t0 = time.perf_counter()
    for i in range(N):
        store.get("k", str(i))
    dt = time.perf_counter() - t0
    print(f"{'reads (point lookup, on-disk)':42s}  {dt:6.3f} s   {N/dt:>10,.0f} op/s")


def updates_in_tx(store: KVStore) -> None:
    with store.transaction():
        for i in range(N):
            store.set("k", str(i), value={"i": i})
    t0 = time.perf_counter()
    with store.transaction():
        for i in range(N):
            store.update("k", str(i), value={"i": i, "u": True})
    dt = time.perf_counter() - t0
    print(f"{'updates in one tx (on-disk)':42s}  {dt:6.3f} s   {N/dt:>10,.0f} op/s")


def deletes_in_tx(store: KVStore) -> None:
    with store.transaction():
        for i in range(N):
            store.set("k", str(i), value={"i": i})
    t0 = time.perf_counter()
    with store.transaction():
        for i in range(N):
            store.delete("k", str(i))
    dt = time.perf_counter() - t0
    print(f"{'deletes in one tx (on-disk)':42s}  {dt:6.3f} s   {N/dt:>10,.0f} op/s")


def memory_writes_autocommit() -> None:
    s = KVStore(":memory:")
    try:
        for i in range(N):
            s.set("k", str(i), value={"i": i})
    finally:
        s.close()


def memory_writes_in_tx() -> None:
    s = KVStore(":memory:")
    try:
        with s.transaction():
            for i in range(N):
                s.set("k", str(i), value={"i": i})
    finally:
        s.close()


print(f"N = {N}")
with_db(lambda s: bench("writes autocommit (on-disk)", lambda: writes_autocommit(s)))
with_db(lambda s: bench("writes in one tx (on-disk)", lambda: writes_in_tx(s)))
with_db(reads)
with_db(updates_in_tx)
with_db(deletes_in_tx)
bench("writes autocommit (:memory:)", memory_writes_autocommit)
bench("writes in one tx (:memory:)", memory_writes_in_tx)
