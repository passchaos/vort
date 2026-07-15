#!/usr/bin/env python3
"""Validate retained fuzz corpus dashboard coverage against a minimum matrix."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "zig-out" / "vort-deflate-wrapper-fuzz-corpus.json"
DEFAULT_COVERAGE = ROOT / "tools" / "fuzz_corpus_expected_coverage.json"


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def int_field(row: dict[str, Any], field: str) -> int:
    value = row.get(field)
    if not isinstance(value, int) or isinstance(value, bool):
        raise AssertionError(f"{field} must be an integer in {row!r}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="fuzz corpus report JSON path")
    parser.add_argument("--coverage", default=str(DEFAULT_COVERAGE), help="expected coverage matrix JSON path")
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    schemas_def = load_manifest()
    report_path = Path(args.report)
    coverage_path = Path(args.coverage)
    report = load_json(report_path)
    coverage = load_json(coverage_path)
    validate_value_against_manifest(report, schemas_def)
    validate_value_against_manifest(coverage, schemas_def)
    if report.get("schema") != "vort.fuzz_corpus_report":
        raise AssertionError("unexpected fuzz corpus report schema")
    if coverage.get("schema") != "vort.fuzz_corpus_expected_coverage":
        raise AssertionError("unexpected fuzz corpus expected coverage schema")

    mode_counts = {row["mode"]: row for row in report.get("mode_counts", []) if isinstance(row, dict) and isinstance(row.get("mode"), str)}
    error_counts = {
        (row["mode"], row["error"]): row
        for row in report.get("error_counts", [])
        if isinstance(row, dict) and isinstance(row.get("mode"), str) and isinstance(row.get("error"), str)
    }

    mode_rows: list[dict[str, object]] = []
    for requirement in coverage.get("mode_requirements", []):
        if not isinstance(requirement, dict):
            raise AssertionError("mode_requirements entries must be objects")
        mode = requirement.get("mode")
        if not isinstance(mode, str):
            raise AssertionError("mode requirement mode must be a string")
        actual = mode_counts.get(mode, {})
        row = {
            "mode": mode,
            "min_cases": int_field(requirement, "min_cases"),
            "actual_cases": int(actual.get("cases", 0)) if isinstance(actual.get("cases", 0), int) else 0,
            "min_accepted": int_field(requirement, "min_accepted"),
            "actual_accepted": int(actual.get("accepted", 0)) if isinstance(actual.get("accepted", 0), int) else 0,
            "min_rejected": int_field(requirement, "min_rejected"),
            "actual_rejected": int(actual.get("rejected", 0)) if isinstance(actual.get("rejected", 0), int) else 0,
            "min_exact_error_expectations": int_field(requirement, "min_exact_error_expectations"),
            "actual_exact_error_expectations": int(actual.get("exact_error_expectations", 0)) if isinstance(actual.get("exact_error_expectations", 0), int) else 0,
            "min_matched_rows": int_field(requirement, "min_matched_rows"),
            "actual_matched_rows": int(actual.get("matched_rows", 0)) if isinstance(actual.get("matched_rows", 0), int) else 0,
            "matched": False,
        }
        row["matched"] = (
            row["actual_cases"] >= row["min_cases"]
            and row["actual_accepted"] >= row["min_accepted"]
            and row["actual_rejected"] >= row["min_rejected"]
            and row["actual_exact_error_expectations"] >= row["min_exact_error_expectations"]
            and row["actual_matched_rows"] >= row["min_matched_rows"]
        )
        mode_rows.append(row)

    error_rows: list[dict[str, object]] = []
    for requirement in coverage.get("error_requirements", []):
        if not isinstance(requirement, dict):
            raise AssertionError("error_requirements entries must be objects")
        mode = requirement.get("mode")
        error = requirement.get("error")
        if not isinstance(mode, str) or not isinstance(error, str):
            raise AssertionError("error requirement mode/error must be strings")
        actual = error_counts.get((mode, error), {})
        actual_count = actual.get("count", 0) if isinstance(actual, dict) else 0
        if not isinstance(actual_count, int) or isinstance(actual_count, bool):
            actual_count = 0
        min_count = int_field(requirement, "min_count")
        error_rows.append(
            {
                "mode": mode,
                "error": error,
                "min_count": min_count,
                "actual_count": actual_count,
                "matched": actual_count >= min_count,
            }
        )

    summary = {
        "schema": "vort.fuzz_corpus_coverage_smoke",
        "schema_version": 1,
        "ok": bool(report.get("ok")) and all(bool(row["matched"]) for row in mode_rows) and all(bool(row["matched"]) for row in error_rows),
        "report": report_path.as_posix(),
        "coverage": coverage_path.as_posix(),
        "mode_requirement_count": len(mode_rows),
        "error_requirement_count": len(error_rows),
        "mode_requirements": mode_rows,
        "error_requirements": error_rows,
    }
    validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        summary_path = Path(args.summary)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"fuzz_corpus_coverage_smoke=ok modes={summary['mode_requirement_count']} errors={summary['error_requirement_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
