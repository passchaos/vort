#!/usr/bin/env python3
"""Smoke-test dashboard artifact categories that are easy to regress."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from dashboard_index import category_for

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ROOT / "tools" / "dashboard_category_expected_artifacts.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", help="dashboard manifest JSON path")
    parser.add_argument("--expected", default=str(EXPECTED), help="category expectation matrix path")
    args = parser.parse_args(argv[1:])

    manifest = json.loads(Path(args.manifest).read_text())
    if manifest.get("schema") != "vort.dashboard_index":
        raise AssertionError(f"unexpected dashboard schema: {manifest.get('schema')!r}")
    expected_payload = json.loads(Path(args.expected).read_text())
    if expected_payload.get("schema") != "vort.dashboard_category_expected_artifacts":
        raise AssertionError(f"unexpected dashboard category expected schema: {expected_payload.get('schema')!r}")
    if expected_payload.get("schema_version") != 1:
        raise AssertionError("unsupported dashboard category expected schema version")

    artifacts = {item["name"]: item for item in manifest.get("artifacts", [])}
    rows = expected_payload.get("expected_artifacts")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("expected_artifacts must be a non-empty list")
    checked = []
    skipped = []
    classifier_checked = []
    seen = set()
    for row in rows:
        if not isinstance(row, dict):
            raise AssertionError("expected_artifacts entries must be objects")
        name = row.get("name")
        category = row.get("category")
        if not isinstance(name, str) or not isinstance(category, str):
            raise AssertionError("expected artifact name/category must be strings")
        if name in seen:
            raise AssertionError(f"duplicate expected artifact {name!r}")
        seen.add(name)
        classifier_category = category_for(Path(name))
        if classifier_category != category:
            raise AssertionError(f"{name} classifier category={classifier_category!r}, expected {category!r}")
        classifier_checked.append(name)
        item = artifacts.get(name)
        require_present = bool(row.get("require_present"))
        if not item and require_present:
            raise AssertionError(f"missing dashboard artifact {name!r}")
        if not item:
            skipped.append(name)
            continue
        if item.get("category") != category:
            raise AssertionError(f"{name} category={item.get('category')!r}, expected {category!r}")
        if row.get("require_producer_step") and not item.get("producer_step"):
            raise AssertionError(f"{name} missing producer_step")
        if row.get("require_smoke_gate") and not item.get("smoke_gate"):
            raise AssertionError(f"{name} missing smoke_gate")
        checked.append(name)

    categories = sorted({artifacts[name]["category"] for name in checked})
    expected_categories = sorted({row["category"] for row in rows if isinstance(row, dict)})
    print(
        f"dashboard_category_smoke=ok checked={len(checked)} skipped={len(skipped)} "
        f"classifier_checked={len(classifier_checked)} categories={','.join(categories)} "
        f"expected_categories={','.join(expected_categories)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
