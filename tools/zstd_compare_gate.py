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
    "zstd_decode_ms",
    "vort_raw_fixed_decode_ms",
    "zstd_decode_mib_s",
    "vort_raw_fixed_decode_mib_s",
    "vort_decode_vs_zstd",
    "decode_repeats",
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


def positive_float(value: str) -> float:
    parsed = float(value)
    if parsed <= 0.0:
        raise AssertionError(f"expected positive float, got {value!r}")
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
    summed_zstd_decode_ms = sum(positive_float(row["zstd_decode_ms"]) for row in data_rows)
    summed_vort_decode_ms = sum(positive_float(row["vort_raw_fixed_decode_ms"]) for row in data_rows)
    if positive_int(total["input_bytes"]) != summed_input:
        raise AssertionError("TOTAL input_bytes mismatch")
    if positive_int(total["zstd_bytes"]) != summed_zstd:
        raise AssertionError("TOTAL zstd_bytes mismatch")
    if non_negative_int(total["vort_raw_fixed_bytes"]) != summed_vort:
        raise AssertionError("TOTAL vort_raw_fixed_bytes mismatch")
    if abs(positive_float(total["zstd_decode_ms"]) - summed_zstd_decode_ms) > 1e-6:
        raise AssertionError("TOTAL zstd_decode_ms mismatch")
    if abs(positive_float(total["vort_raw_fixed_decode_ms"]) - summed_vort_decode_ms) > 1e-6:
        raise AssertionError("TOTAL vort_raw_fixed_decode_ms mismatch")

    expected_ratio = summed_vort / summed_zstd
    actual_ratio = float(total["vort_over_zstd"])
    if abs(actual_ratio - expected_ratio) > 1e-9:
        raise AssertionError(f"TOTAL ratio mismatch: expected {expected_ratio}, got {actual_ratio}")
    total_zstd_decode_mib_s = positive_float(total["zstd_decode_mib_s"])
    total_vort_decode_mib_s = positive_float(total["vort_raw_fixed_decode_mib_s"])
    expected_zstd_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_zstd_decode_ms / 1000.0)
    expected_vort_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_vort_decode_ms / 1000.0)
    if abs(total_zstd_decode_mib_s - expected_zstd_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL zstd_decode_mib_s mismatch")
    if abs(total_vort_decode_mib_s - expected_vort_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL vort_raw_fixed_decode_mib_s mismatch")
    expected_decode_ratio = total_vort_decode_mib_s / total_zstd_decode_mib_s
    actual_decode_ratio = positive_float(total["vort_decode_vs_zstd"])
    if abs(actual_decode_ratio - expected_decode_ratio) > 1e-9:
        raise AssertionError("TOTAL vort_decode_vs_zstd mismatch")
    decode_repeats = positive_int(total["decode_repeats"])
    if total["zstd_version"] in {"", "missing"}:
        raise AssertionError("zstd version missing from retained artifact")
    for row in rows:
        if not row["vort_commit"] or not row["zig_version"] or not row["cpu_model"] or not row["optimize"]:
            raise AssertionError(f"missing metadata in row {row!r}")
        if positive_int(row["decode_repeats"]) != decode_repeats:
            raise AssertionError(f"decode repeat count drift in row {row!r}")
        positive_float(row["zstd_decode_mib_s"])
        positive_float(row["vort_raw_fixed_decode_mib_s"])
        positive_float(row["vort_decode_vs_zstd"])

    markdown = args.markdown.read_text()
    if (
        "**TOTAL**" not in markdown
        or "Vort commit" not in markdown
        or "Optimize" not in markdown
        or "Decode repeats" not in markdown
        or "Decode timings include process startup" not in markdown
        or "Vort decode / zstd" not in markdown
    ):
        raise AssertionError("markdown summary missing retained metadata or TOTAL row")

    summary: dict[str, Any] = {
        "schema": "vort.zstd_compare_gate",
        "schema_version": 1,
        "ok": True,
        "rows": len(rows),
        "data_rows": len(data_rows),
        "decode_repeats": decode_repeats,
        "total_ratio": actual_ratio,
        "total_zstd_decode_mib_s": total_zstd_decode_mib_s,
        "total_vort_raw_fixed_decode_mib_s": total_vort_decode_mib_s,
        "total_vort_decode_vs_zstd": actual_decode_ratio,
        "csv": str(args.csv),
        "markdown": str(args.markdown),
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(
        "zstd_compare_gate=ok "
        f"rows={len(rows)} "
        f"total_ratio={actual_ratio:.4f} "
        f"decode_vs_zstd={actual_decode_ratio:.4f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
