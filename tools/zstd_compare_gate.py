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
    "vort_native_best_bytes",
    "vort_native_embedded_bytes",
    "vort_over_zstd",
    "vort_native_best_over_zstd",
    "vort_native_over_zstd",
    "zstd_decode_ms",
    "vort_raw_fixed_decode_ms",
    "vort_native_best_decode_ms",
    "vort_native_decode_ms",
    "zstd_decode_mib_s",
    "vort_raw_fixed_decode_mib_s",
    "vort_native_best_decode_mib_s",
    "vort_native_decode_mib_s",
    "vort_decode_vs_zstd",
    "vort_native_best_decode_vs_zstd",
    "vort_native_decode_vs_zstd",
    "decode_repeats",
    "native_block_len",
    "source_mode",
    "size_mode",
    "case_limit",
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
    parser.add_argument("--expect-source-mode")
    parser.add_argument("--expect-size-mode")
    parser.add_argument("--expect-optimize")
    parser.add_argument("--expect-case-limit")
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
    summed_native_best = sum(non_negative_int(row["vort_native_best_bytes"]) for row in data_rows)
    summed_native = sum(non_negative_int(row["vort_native_embedded_bytes"]) for row in data_rows)
    summed_zstd_decode_ms = sum(positive_float(row["zstd_decode_ms"]) for row in data_rows)
    summed_vort_decode_ms = sum(positive_float(row["vort_raw_fixed_decode_ms"]) for row in data_rows)
    summed_native_best_decode_ms = sum(positive_float(row["vort_native_best_decode_ms"]) for row in data_rows)
    summed_native_decode_ms = sum(positive_float(row["vort_native_decode_ms"]) for row in data_rows)
    if positive_int(total["input_bytes"]) != summed_input:
        raise AssertionError("TOTAL input_bytes mismatch")
    if positive_int(total["zstd_bytes"]) != summed_zstd:
        raise AssertionError("TOTAL zstd_bytes mismatch")
    if non_negative_int(total["vort_raw_fixed_bytes"]) != summed_vort:
        raise AssertionError("TOTAL vort_raw_fixed_bytes mismatch")
    if non_negative_int(total["vort_native_best_bytes"]) != summed_native_best:
        raise AssertionError("TOTAL vort_native_best_bytes mismatch")
    if non_negative_int(total["vort_native_embedded_bytes"]) != summed_native:
        raise AssertionError("TOTAL vort_native_embedded_bytes mismatch")
    if abs(positive_float(total["zstd_decode_ms"]) - summed_zstd_decode_ms) > 1e-6:
        raise AssertionError("TOTAL zstd_decode_ms mismatch")
    if abs(positive_float(total["vort_raw_fixed_decode_ms"]) - summed_vort_decode_ms) > 1e-6:
        raise AssertionError("TOTAL vort_raw_fixed_decode_ms mismatch")
    if abs(positive_float(total["vort_native_best_decode_ms"]) - summed_native_best_decode_ms) > 1e-6:
        raise AssertionError("TOTAL vort_native_best_decode_ms mismatch")
    if abs(positive_float(total["vort_native_decode_ms"]) - summed_native_decode_ms) > 1e-6:
        raise AssertionError("TOTAL vort_native_decode_ms mismatch")

    expected_ratio = summed_vort / summed_zstd
    actual_ratio = float(total["vort_over_zstd"])
    if abs(actual_ratio - expected_ratio) > 1e-9:
        raise AssertionError(f"TOTAL ratio mismatch: expected {expected_ratio}, got {actual_ratio}")
    expected_native_best_ratio = summed_native_best / summed_zstd
    actual_native_best_ratio = float(total["vort_native_best_over_zstd"])
    if abs(actual_native_best_ratio - expected_native_best_ratio) > 1e-9:
        raise AssertionError(f"TOTAL native best ratio mismatch: expected {expected_native_best_ratio}, got {actual_native_best_ratio}")
    expected_native_ratio = summed_native / summed_zstd
    actual_native_ratio = float(total["vort_native_over_zstd"])
    if abs(actual_native_ratio - expected_native_ratio) > 1e-9:
        raise AssertionError(f"TOTAL native ratio mismatch: expected {expected_native_ratio}, got {actual_native_ratio}")
    total_zstd_decode_mib_s = positive_float(total["zstd_decode_mib_s"])
    total_vort_decode_mib_s = positive_float(total["vort_raw_fixed_decode_mib_s"])
    total_native_best_decode_mib_s = positive_float(total["vort_native_best_decode_mib_s"])
    total_native_decode_mib_s = positive_float(total["vort_native_decode_mib_s"])
    expected_zstd_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_zstd_decode_ms / 1000.0)
    expected_vort_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_vort_decode_ms / 1000.0)
    expected_native_best_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_native_best_decode_ms / 1000.0)
    expected_native_decode_mib_s = (summed_input / (1024.0 * 1024.0)) / (summed_native_decode_ms / 1000.0)
    if abs(total_zstd_decode_mib_s - expected_zstd_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL zstd_decode_mib_s mismatch")
    if abs(total_vort_decode_mib_s - expected_vort_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL vort_raw_fixed_decode_mib_s mismatch")
    if abs(total_native_best_decode_mib_s - expected_native_best_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL vort_native_best_decode_mib_s mismatch")
    if abs(total_native_decode_mib_s - expected_native_decode_mib_s) > 1e-9:
        raise AssertionError("TOTAL vort_native_decode_mib_s mismatch")
    expected_decode_ratio = total_vort_decode_mib_s / total_zstd_decode_mib_s
    actual_decode_ratio = positive_float(total["vort_decode_vs_zstd"])
    if abs(actual_decode_ratio - expected_decode_ratio) > 1e-9:
        raise AssertionError("TOTAL vort_decode_vs_zstd mismatch")
    expected_native_best_decode_ratio = total_native_best_decode_mib_s / total_zstd_decode_mib_s
    actual_native_best_decode_ratio = positive_float(total["vort_native_best_decode_vs_zstd"])
    if abs(actual_native_best_decode_ratio - expected_native_best_decode_ratio) > 1e-9:
        raise AssertionError("TOTAL vort_native_best_decode_vs_zstd mismatch")
    expected_native_decode_ratio = total_native_decode_mib_s / total_zstd_decode_mib_s
    actual_native_decode_ratio = positive_float(total["vort_native_decode_vs_zstd"])
    if abs(actual_native_decode_ratio - expected_native_decode_ratio) > 1e-9:
        raise AssertionError("TOTAL vort_native_decode_vs_zstd mismatch")
    decode_repeats = positive_int(total["decode_repeats"])
    native_block_len = positive_int(total["native_block_len"])
    source_mode = total["source_mode"]
    size_mode = total["size_mode"]
    case_limit = total["case_limit"]
    optimize = total["optimize"]
    if args.expect_source_mode is not None and source_mode != args.expect_source_mode:
        raise AssertionError(f"source_mode mismatch: expected {args.expect_source_mode!r}, got {source_mode!r}")
    if args.expect_size_mode is not None and size_mode != args.expect_size_mode:
        raise AssertionError(f"size_mode mismatch: expected {args.expect_size_mode!r}, got {size_mode!r}")
    if args.expect_optimize is not None and optimize != args.expect_optimize:
        raise AssertionError(f"optimize mismatch: expected {args.expect_optimize!r}, got {optimize!r}")
    if args.expect_case_limit is not None and case_limit != args.expect_case_limit:
        raise AssertionError(f"case_limit mismatch: expected {args.expect_case_limit!r}, got {case_limit!r}")
    if total["zstd_version"] in {"", "missing"}:
        raise AssertionError("zstd version missing from retained artifact")
    for row in rows:
        if not row["vort_commit"] or not row["zig_version"] or not row["cpu_model"] or not row["optimize"]:
            raise AssertionError(f"missing metadata in row {row!r}")
        if positive_int(row["decode_repeats"]) != decode_repeats:
            raise AssertionError(f"decode repeat count drift in row {row!r}")
        if positive_int(row["native_block_len"]) != native_block_len:
            raise AssertionError(f"native block length drift in row {row!r}")
        if row["source_mode"] != source_mode or row["size_mode"] != size_mode or row["case_limit"] != case_limit or row["optimize"] != optimize:
            raise AssertionError(f"metadata drift in row {row!r}")
        positive_float(row["zstd_decode_mib_s"])
        positive_float(row["vort_raw_fixed_decode_mib_s"])
        positive_float(row["vort_native_best_decode_mib_s"])
        positive_float(row["vort_native_decode_mib_s"])
        positive_float(row["vort_decode_vs_zstd"])
        positive_float(row["vort_native_best_decode_vs_zstd"])
        positive_float(row["vort_native_decode_vs_zstd"])

    markdown = args.markdown.read_text()
    if (
        "**TOTAL**" not in markdown
        or "Vort commit" not in markdown
        or "Optimize" not in markdown
        or "Decode repeats" not in markdown
        or "Native block length" not in markdown
        or "source mode" not in markdown
        or "size mode" not in markdown
        or "case limit" not in markdown
        or "CLI-internal decode loops" not in markdown
        or "Vort raw decode / zstd" not in markdown
        or "Vort native best" not in markdown
        or "Vort native embedded" not in markdown
    ):
        raise AssertionError("markdown summary missing retained metadata or TOTAL row")

    summary: dict[str, Any] = {
        "schema": "vort.zstd_compare_gate",
        "schema_version": 1,
        "ok": True,
        "rows": len(rows),
        "data_rows": len(data_rows),
        "decode_repeats": decode_repeats,
        "native_block_len": native_block_len,
        "source_mode": source_mode,
        "size_mode": size_mode,
        "case_limit": case_limit,
        "optimize": optimize,
        "total_ratio": actual_ratio,
        "total_native_best_ratio": actual_native_best_ratio,
        "total_native_ratio": actual_native_ratio,
        "total_zstd_decode_mib_s": total_zstd_decode_mib_s,
        "total_vort_raw_fixed_decode_mib_s": total_vort_decode_mib_s,
        "total_vort_decode_vs_zstd": actual_decode_ratio,
        "total_vort_native_best_decode_mib_s": total_native_best_decode_mib_s,
        "total_vort_native_best_decode_vs_zstd": actual_native_best_decode_ratio,
        "total_vort_native_decode_mib_s": total_native_decode_mib_s,
        "total_vort_native_decode_vs_zstd": actual_native_decode_ratio,
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
        f"native_best_ratio={actual_native_best_ratio:.4f} "
        f"native_ratio={actual_native_ratio:.4f} "
        f"decode_vs_zstd={actual_decode_ratio:.4f} "
        f"native_best_decode_vs_zstd={actual_native_best_decode_ratio:.4f} "
        f"native_decode_vs_zstd={actual_native_decode_ratio:.4f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
