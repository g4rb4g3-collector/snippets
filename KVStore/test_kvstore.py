"""Testy KVStore — uruchamiane przez `python -m unittest test_kvstore`."""
import unittest

from kvstore import KVStore


class TestKVStore(unittest.TestCase):
    def setUp(self) -> None:
        self.store = KVStore(":memory:")

    def tearDown(self) -> None:
        self.store.close()

    def test_set_and_get_one_key(self) -> None:
        self.store.set("a", value={"n": 1})
        self.assertEqual(self.store.get("a"), {"n": 1})

    def test_set_and_get_four_keys(self) -> None:
        self.store.set("a", "b", "c", "d", value=[1, 2, 3])
        self.assertEqual(self.store.get("a", "b", "c", "d"), [1, 2, 3])

    def test_different_arities_are_distinct(self) -> None:
        self.store.set("a", value="one")
        self.store.set("a", "b", value="two")
        self.store.set("a", "b", "c", value="three")
        self.store.set("a", "b", "c", "d", value="four")
        self.assertEqual(self.store.get("a"), "one")
        self.assertEqual(self.store.get("a", "b"), "two")
        self.assertEqual(self.store.get("a", "b", "c"), "three")
        self.assertEqual(self.store.get("a", "b", "c", "d"), "four")

    def test_get_missing_returns_default(self) -> None:
        self.assertIsNone(self.store.get("nope"))
        self.assertEqual(self.store.get("nope", default=42), 42)

    def test_set_overwrites(self) -> None:
        self.store.set("a", "b", value=1)
        self.store.set("a", "b", value=2)
        self.assertEqual(self.store.get("a", "b"), 2)

    def test_update_existing(self) -> None:
        self.store.set("a", value={"v": 1})
        self.assertTrue(self.store.update("a", value={"v": 2}))
        self.assertEqual(self.store.get("a"), {"v": 2})

    def test_update_missing_returns_false(self) -> None:
        self.assertFalse(self.store.update("nope", value=1))

    def test_delete_existing(self) -> None:
        self.store.set("a", "b", value=1)
        self.assertTrue(self.store.delete("a", "b"))
        self.assertIsNone(self.store.get("a", "b"))

    def test_delete_missing_returns_false(self) -> None:
        self.assertFalse(self.store.delete("nope"))

    def test_json_value_types(self) -> None:
        for v in [None, True, 0, 1.5, "txt", [1, 2], {"a": [1, {"b": None}]}]:
            self.store.set("k", value=v)
            self.assertEqual(self.store.get("k"), v)

    def test_no_keys_raises(self) -> None:
        with self.assertRaises(ValueError):
            self.store.set(value=1)

    def test_too_many_keys_raises(self) -> None:
        with self.assertRaises(ValueError):
            self.store.set("a", "b", "c", "d", "e", value=1)

    def test_non_string_key_raises(self) -> None:
        with self.assertRaises(TypeError):
            self.store.set("a", 2, value=1)

    def test_empty_string_key_raises(self) -> None:
        with self.assertRaises(ValueError):
            self.store.set("a", "", value=1)

    def test_context_manager(self) -> None:
        with KVStore(":memory:") as s:
            s.set("x", value=1)
            self.assertEqual(s.get("x"), 1)


if __name__ == "__main__":
    unittest.main()
