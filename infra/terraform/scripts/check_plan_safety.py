#!/usr/bin/env python3
"""Analyze Terraform plan JSON for destructive changes.

Reads terraform show -json output and fails when destroys or replacements
are detected. Does not print sensitive before/after values.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class PlanSafetyResult:
    adds: int = 0
    changes: int = 0
    destroys: int = 0
    replacements: int = 0
    add_addresses: list[str] = field(default_factory=list)
    change_addresses: list[str] = field(default_factory=list)
    destroy_addresses: list[str] = field(default_factory=list)
    replacement_addresses: list[str] = field(default_factory=list)

    @property
    def is_safe(self) -> bool:
        return self.destroys == 0 and self.replacements == 0

    def to_summary_text(self) -> str:
        lines = [
            "Terraform Plan Safety Summary",
            "",
            f"Adds: {self.adds}",
            f"Changes: {self.changes}",
            f"Destroys: {self.destroys}",
            f"Replacements: {self.replacements}",
            "",
            f"Safety gate: {'Passed' if self.is_safe else 'Failed'}",
        ]
        if self.destroy_addresses:
            lines.extend(["", "Destroy addresses:"])
            lines.extend(f"- {address}" for address in self.destroy_addresses)
        if self.replacement_addresses:
            lines.extend(["", "Replacement addresses:"])
            lines.extend(f"- {address}" for address in self.replacement_addresses)
        return "\n".join(lines) + "\n"

    def to_summary_json(self) -> dict[str, Any]:
        return {
            "adds": self.adds,
            "changes": self.changes,
            "destroys": self.destroys,
            "replacements": self.replacements,
            "safe": self.is_safe,
            "add_addresses": self.add_addresses,
            "change_addresses": self.change_addresses,
            "destroy_addresses": self.destroy_addresses,
            "replacement_addresses": self.replacement_addresses,
        }


def classify_actions(actions: list[str]) -> str:
    """Classify a Terraform change action list into add/change/destroy/replacement."""
    if not actions:
        return "noop"

    normalized = [action for action in actions if action != "read"]
    if not normalized:
        return "noop"

    has_create = "create" in normalized
    has_delete = "delete" in normalized
    has_update = "update" in normalized

    if has_delete and has_create:
        return "replacement"
    if has_delete:
        return "destroy"
    if has_create and not has_update:
        return "add"
    if has_update:
        return "change"
    if has_create:
        return "add"
    return "noop"


def analyze_plan(plan: dict[str, Any]) -> PlanSafetyResult:
    result = PlanSafetyResult()
    resource_changes = plan.get("resource_changes")
    if resource_changes is None:
        raise ValueError("plan JSON missing 'resource_changes'")

    for change in resource_changes:
        address = change.get("address", "<unknown>")
        change_block = change.get("change") or {}
        actions = change_block.get("actions")
        if not isinstance(actions, list):
            raise ValueError(f"resource change for {address} missing 'actions' list")

        category = classify_actions(actions)
        if category == "add":
            result.adds += 1
            result.add_addresses.append(address)
        elif category == "change":
            result.changes += 1
            result.change_addresses.append(address)
        elif category == "destroy":
            result.destroys += 1
            result.destroy_addresses.append(address)
        elif category == "replacement":
            result.replacements += 1
            result.replacement_addresses.append(address)

    return result


def load_plan(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("plan JSON root must be an object")
    return data


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fail when a Terraform plan JSON contains destroys or replacements.",
    )
    parser.add_argument("plan_json", type=Path, help="Path to terraform show -json output")
    parser.add_argument(
        "--summary-file",
        type=Path,
        help="Optional path to write a sanitized text summary",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print sanitized JSON summary to stdout",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        plan = load_plan(args.plan_json)
        result = analyze_plan(plan)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    summary_text = result.to_summary_text()
    if args.summary_file:
        args.summary_file.write_text(summary_text, encoding="utf-8")

    if args.json:
        print(json.dumps(result.to_summary_json(), indent=2))
    else:
        print(summary_text, end="")

    return 0 if result.is_safe else 1


if __name__ == "__main__":
    raise SystemExit(main())
