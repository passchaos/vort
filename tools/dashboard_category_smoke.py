#!/usr/bin/env python3
"""Smoke-test dashboard artifact categories that are easy to regress."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <dashboard-manifest.json>", file=sys.stderr)
        return 2

    manifest = json.loads(Path(argv[1]).read_text())
    if manifest.get("schema") != "vort.dashboard_index":
        raise AssertionError(f"unexpected dashboard schema: {manifest.get('schema')!r}")

    artifacts = {item["name"]: item for item in manifest.get("artifacts", [])}
    expected = {
        "vort-header-inspect-smoke.json": "validation",
        "vort-header-inspect-smoke.md": "validation",
        "vort-dashboard-strict-smoke.json": "validation",
        "vort-dashboard-strict-smoke.md": "validation",
        "vort-dashboard-producers-negative-smoke.json": "validation",
    }
    for name, category in expected.items():
        item = artifacts.get(name)
        if not item:
            raise AssertionError(f"missing dashboard artifact {name!r}")
        if item.get("category") != category:
            raise AssertionError(f"{name} category={item.get('category')!r}, expected {category!r}")
        if not item.get("producer_step"):
            raise AssertionError(f"{name} missing producer_step")
        if not item.get("smoke_gate"):
            raise AssertionError(f"{name} missing smoke_gate")

    print("dashboard_category_smoke=ok header_inspect=validation dashboard_strict=validation dashboard_producers=validation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
