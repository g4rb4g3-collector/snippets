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

    def test_transaction_commits_on_success(self) -> None:
        with self.store.transaction():
            self.store.set("a", value=1)
            self.store.set("b", value=2)
        self.assertEqual(self.store.get("a"), 1)
        self.assertEqual(self.store.get("b"), 2)

    def test_transaction_rolls_back_on_exception(self) -> None:
        self.store.set("a", value="orig")
        with self.assertRaises(RuntimeError):
            with self.store.transaction():
                self.store.update("a", value="new")
                self.store.set("b", value=99)
                raise RuntimeError("boom")
        self.assertEqual(self.store.get("a"), "orig")
        self.assertIsNone(self.store.get("b"))

    def test_transaction_nested_commits_once(self) -> None:
        with self.store.transaction():
            self.store.set("a", value=1)
            with self.store.transaction():
                self.store.set("b", value=2)
            self.store.set("c", value=3)
        self.assertEqual(self.store.get("a"), 1)
        self.assertEqual(self.store.get("b"), 2)
        self.assertEqual(self.store.get("c"), 3)

    def test_items_no_prefix_returns_all(self) -> None:
        self.store.set("a", value=1)
        self.store.set("b", "c", value=2)
        self.store.set("b", "c", "d", value=3)
        result = self.store.items()
        self.assertCountEqual(result, [
            (("a",), 1),
            (("b", "c"), 2),
            (("b", "c", "d"), 3),
        ])

    def test_items_with_prefix_returns_suffix_only(self) -> None:
        self.store.set("game1", "users", "ala", value={"email": "a"})
        self.store.set("game1", "users", "bob", value={"email": "b"})
        self.store.set("game2", "users", "ola", value={"email": "o"})
        result = self.store.items("game1", "users")
        self.assertCountEqual(result, [
            (("ala",), {"email": "a"}),
            (("bob",), {"email": "b"}),
        ])

    def test_items_excludes_row_exactly_on_prefix(self) -> None:
        self.store.set("a", "b", value="exact")
        self.store.set("a", "b", "c", value="deeper")
        self.assertEqual(self.store.items("a", "b"), [(("c",), "deeper")])

    def test_items_includes_deeper_descendants(self) -> None:
        self.store.set("a", "b", "c", value=1)
        self.store.set("a", "b", "c", "d", value=2)
        result = self.store.items("a")
        self.assertCountEqual(result, [
            (("b", "c"), 1),
            (("b", "c", "d"), 2),
        ])

    def test_items_returns_empty_when_no_match(self) -> None:
        self.store.set("a", value=1)
        self.assertEqual(self.store.items("nope"), [])

    def test_items_validates_prefix_length(self) -> None:
        with self.assertRaises(ValueError):
            self.store.items("a", "b", "c", "d")

    def test_transaction_nested_inner_exception_rolls_back_all(self) -> None:
        with self.assertRaises(RuntimeError):
            with self.store.transaction():
                self.store.set("a", value=1)
                with self.store.transaction():
                    self.store.set("b", value=2)
                    raise RuntimeError("boom")
        self.assertIsNone(self.store.get("a"))
        self.assertIsNone(self.store.get("b"))


if __name__ == "__main__":
    unittest.main()
