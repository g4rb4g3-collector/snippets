"""Przykładowe użycie KVStore."""
from kvstore import KVStore

with KVStore(":memory:") as store:
    store.set("config", value={"theme": "dark", "lang": "pl"})
    store.set("users", "ala", value={"email": "ala@example.com"})
    store.set("users", "ala", "sessions", "s1", value={"ip": "1.2.3.4"})

    print("config:", store.get("config"))
    print("user:  ", store.get("users", "ala"))
    print("session:", store.get("users", "ala", "sessions", "s1"))

    store.update("users", "ala", value={"email": "ala@new.example.com"})
    print("updated:", store.get("users", "ala"))

    store.delete("users", "ala", "sessions", "s1")
    print("after delete:", store.get("users", "ala", "sessions", "s1"))
