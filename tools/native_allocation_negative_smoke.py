#!/usr/bin/env python3
"""Negative tests for native allocation smoke gate."""

from __future__ import annotations

import json
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "zig-out" / "vort-native-allocation-report.json"
SMOKE = ROOT / "tools" / "native_allocation_smoke.py"


def run_bad_report(name: str, report: dict, needle: str, tmp: Path) -> dict:
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
    matched = proc.returncode != 0 and needle in proc.stdout
    if proc.returncode == 0:
        raise AssertionError(f"negative report unexpectedly passed: {needle}\n{proc.stdout}")
    if needle not in proc.stdout:
        raise AssertionError(f"negative report output did not mention {needle!r}:\n{proc.stdout}")
    return {
        "name": name,
        "expected_failure": True,
        "returncode": proc.returncode,
        "matched": matched,
    }


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
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()
    cases: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)

        over_budget = clone_report()
        find_case(over_budget, "concat_alloc")["allocations"] = 2
        cases.append(run_bad_report("over_budget", over_budget, "concat_alloc", tmp))

        missing_required = clone_report()
        missing_required["cases"] = [row for row in case_rows(missing_required) if row.get("case") != "concat_into"]
        missing_required["case_count"] = len(missing_required["cases"])
        cases.append(run_bad_report("missing_required_case", missing_required, "concat_into", tmp))

        imbalanced = clone_report()
        find_case(imbalanced, "concat_alloc")["deallocations"] = 0
        cases.append(run_bad_report("imbalanced_deallocation", imbalanced, "concat_alloc", tmp))

        seekable_reuse_regression = clone_report()
        one_shot = find_case(seekable_reuse_regression, "zstd_seekable_into")
        warmed = find_case(seekable_reuse_regression, "zstd_seekable_reusable_warm_into")
        # Preserve balance and a fifteen-call improvement so this specifically
        # proves that the sixteen-call reuse floor is enforced.
        warmed["allocations"] = one_shot["allocations"] - 15
        warmed["deallocations"] = one_shot["deallocations"] - 15
        cases.append(run_bad_report("seekable_reuse_regression", seekable_reuse_regression, "seekable_reuse_matched", tmp))

    summary = {
        "schema": "vort.native_allocation_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(case["matched"]) for case in cases),
        "case_count": len(cases),
        "cases": cases,
    }
    if args.summary:
        summary_path = Path(args.summary)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"native_allocation_negative_smoke=ok cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
