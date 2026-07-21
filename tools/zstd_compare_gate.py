#!/usr/bin/env python3
"""Validate retained zstd comparison artifacts."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

DEFAULT_CSV = Path("zig-out/vort-zstd-compare.csv")
DEFAULT_MARKDOWN = Path("zig-out/vort-zstd-compare.md")
REQUIRED_FIELDS = [
    "path",
    "input_bytes",
    "zstd_bytes",
    "vort_raw_fixed_bytes",
    "vort_over_zstd",
    "zstd_version",
    "vort_commit",
    "zig_version",
    "cpu_model",
    "optimize",
]


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise AssertionError(f"expected positive integer, got {value!r}")
    return parsed


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise AssertionError(f"expected non-negative integer, got {value!r}")
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--markdown", type=Path, default=DEFAULT_MARKDOWN)
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.open(newline="")))
    if not rows:
        raise AssertionError("zstd compare CSV has no rows")
    if set(rows[0].keys()) != set(REQUIRED_FIELDS):
        raise AssertionError(f"unexpected zstd compare CSV fields: {list(rows[0].keys())!r}")

    data_rows = [row for row in rows if row["path"] != "TOTAL"]
    total_rows = [row for row in rows if row["path"] == "TOTAL"]
    if len(data_rows) < 1 or len(total_rows) != 1:
        raise AssertionError(f"expected data rows plus one TOTAL row, got data={len(data_rows)} total={len(total_rows)}")

    total = total_rows[0]
    summed_input = sum(positive_int(row["input_bytes"]) for row in data_rows)
    summed_zstd = sum(positive_int(row["zstd_bytes"]) for row in data_rows)
    summed_vort = sum(non_negative_int(row["vort_raw_fixed_bytes"]) for row in data_rows)
    if positive_int(total["input_bytes"]) != summed_input:
        raise AssertionError("TOTAL input_bytes mismatch")
    if positive_int(total["zstd_bytes"]) != summed_zstd:
        raise AssertionError("TOTAL zstd_bytes mismatch")
    if non_negative_int(total["vort_raw_fixed_bytes"]) != summed_vort:
        raise AssertionError("TOTAL vort_raw_fixed_bytes mismatch")

    expected_ratio = summed_vort / summed_zstd
    actual_ratio = float(total["vort_over_zstd"])
    if abs(actual_ratio - expected_ratio) > 1e-9:
        raise AssertionError(f"TOTAL ratio mismatch: expected {expected_ratio}, got {actual_ratio}")
    if total["zstd_version"] in {"", "missing"}:
        raise AssertionError("zstd version missing from retained artifact")
    for row in rows:
        if not row["vort_commit"] or not row["zig_version"] or not row["cpu_model"] or not row["optimize"]:
            raise AssertionError(f"missing metadata in row {row!r}")

    markdown = args.markdown.read_text()
    if "**TOTAL**" not in markdown or "Vort commit" not in markdown or "Optimize" not in markdown:
        raise AssertionError("markdown summary missing retained metadata or TOTAL row")

    summary: dict[str, Any] = {
        "schema": "vort.zstd_compare_gate",
        "schema_version": 1,
        "ok": True,
        "rows": len(rows),
        "data_rows": len(data_rows),
        "total_ratio": actual_ratio,
        "csv": str(args.csv),
        "markdown": str(args.markdown),
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"zstd_compare_gate=ok rows={len(rows)} total_ratio={actual_ratio:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
