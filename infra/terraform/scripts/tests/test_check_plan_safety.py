"""Unit tests for check_plan_safety.py using synthetic plan JSON fixtures."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from check_plan_safety import analyze_plan, classify_actions, load_plan, main

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SCRIPT = SCRIPTS_DIR / "check_plan_safety.py"


class ClassifyActionsTests(unittest.TestCase):
    def test_noop_read_only(self) -> None:
        self.assertEqual(classify_actions(["read"]), "noop")

    def test_add_create(self) -> None:
        self.assertEqual(classify_actions(["create"]), "add")
        self.assertEqual(classify_actions(["read", "create"]), "add")

    def test_change_update(self) -> None:
        self.assertEqual(classify_actions(["update"]), "change")

    def test_destroy_delete(self) -> None:
        self.assertEqual(classify_actions(["delete"]), "destroy")

    def test_replacement_delete_create(self) -> None:
        self.assertEqual(classify_actions(["delete", "create"]), "replacement")

    def test_replacement_create_delete(self) -> None:
        self.assertEqual(classify_actions(["create", "delete"]), "replacement")


class AnalyzePlanTests(unittest.TestCase):
    def _analyze(self, fixture_name: str):
        plan = load_plan(FIXTURES / fixture_name)
        return analyze_plan(plan)

    def test_noop(self) -> None:
        result = self._analyze("noop.json")
        self.assertTrue(result.is_safe)
        self.assertEqual(result.adds, 0)
        self.assertEqual(result.changes, 0)

    def test_create_only(self) -> None:
        result = self._analyze("create_only.json")
        self.assertTrue(result.is_safe)
        self.assertEqual(result.adds, 2)
        self.assertEqual(result.changes, 0)

    def test_update_only(self) -> None:
        result = self._analyze("update_only.json")
        self.assertTrue(result.is_safe)
        self.assertEqual(result.changes, 1)

    def test_delete_only(self) -> None:
        result = self._analyze("delete_only.json")
        self.assertFalse(result.is_safe)
        self.assertEqual(result.destroys, 1)

    def test_replacement_delete_create(self) -> None:
        result = self._analyze("replacement_delete_create.json")
        self.assertFalse(result.is_safe)
        self.assertEqual(result.replacements, 1)

    def test_replacement_create_delete(self) -> None:
        result = self._analyze("replacement_create_delete.json")
        self.assertFalse(result.is_safe)
        self.assertEqual(result.replacements, 1)

    def test_mixed_safe(self) -> None:
        result = self._analyze("mixed_safe.json")
        self.assertTrue(result.is_safe)
        self.assertEqual(result.adds, 1)
        self.assertEqual(result.changes, 1)

    def test_mixed_unsafe(self) -> None:
        result = self._analyze("mixed_unsafe.json")
        self.assertFalse(result.is_safe)
        self.assertEqual(result.adds, 1)
        self.assertEqual(result.destroys, 1)
        self.assertEqual(result.replacements, 1)

    def test_malformed_missing_actions(self) -> None:
        plan = load_plan(FIXTURES / "malformed.json")
        with self.assertRaises(ValueError):
            analyze_plan(plan)


class MainExitCodeTests(unittest.TestCase):
    def _run(self, fixture_name: str) -> int:
        return main([str(FIXTURES / fixture_name)])

    def test_safe_exit_code(self) -> None:
        self.assertEqual(self._run("mixed_safe.json"), 0)

    def test_unsafe_exit_code(self) -> None:
        self.assertEqual(self._run("delete_only.json"), 1)

    def test_malformed_exit_code(self) -> None:
        self.assertEqual(self._run("malformed.json"), 2)

    def test_subprocess_safe_fixture(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), str(FIXTURES / "noop.json")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0)
        self.assertIn("Safety gate: Passed", completed.stdout)

    def test_subprocess_unsafe_fixture(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), str(FIXTURES / "mixed_unsafe.json")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 1)
        self.assertIn("Safety gate: Failed", completed.stdout)
        self.assertNotIn("password", completed.stdout.lower())


if __name__ == "__main__":
    unittest.main()
