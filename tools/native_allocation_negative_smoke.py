#!/usr/bin/env python3
"""Negative tests for native allocation smoke gate."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "zig-out" / "vort-native-allocation-report.json"
SMOKE = ROOT / "tools" / "native_allocation_smoke.py"


def run_bad_report(report: dict, needle: str, tmp: Path) -> None:
    path = tmp / "bad-report.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    proc = subprocess.run(
        [sys.executable, str(SMOKE), "--report", str(path)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if proc.returncode == 0:
        raise AssertionError(f"negative report unexpectedly passed: {needle}\n{proc.stdout}")
    if needle not in proc.stdout:
        raise AssertionError(f"negative report output did not mention {needle!r}:\n{proc.stdout}")


def clone_report() -> dict:
    return json.loads(REPORT.read_text())


def case_rows(report: dict) -> list[dict]:
    rows = report.get("cases")
    if not isinstance(rows, list):
        raise AssertionError("native allocation report missing cases")
    return rows


def find_case(report: dict, name: str) -> dict:
    for row in case_rows(report):
        if row.get("case") == name:
            return row
    raise AssertionError(f"missing case {name}")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        over_budget = clone_report()
        find_case(over_budget, "concat_alloc")["allocations"] = 2
        run_bad_report(over_budget, "concat_alloc", tmp)

        missing_required = clone_report()
        missing_required["cases"] = [row for row in case_rows(missing_required) if row.get("case") != "concat_into"]
        missing_required["case_count"] = len(missing_required["cases"])
        run_bad_report(missing_required, "concat_into", tmp)

        imbalanced = clone_report()
        find_case(imbalanced, "concat_alloc")["deallocations"] = 0
        run_bad_report(imbalanced, "concat_alloc", tmp)

    print("native_allocation_negative_smoke=ok cases=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
