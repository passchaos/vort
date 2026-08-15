#!/usr/bin/env python3
"""Validate deflate match-copy microbenchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "class",
    "kernel",
    "length",
    "distance",
    "ops_per_iter",
    "iterations",
    "output_bytes",
    "elapsed_ns",
    "output_mib_per_s",
    "checksum",
}
EXPECTED_KERNELS = {"current", "nonoverlap_first", "small_unrolled", "overcopy16"}
EXPECTED_CASES = {
    "rle-long",
    "small-distance-long",
    "nonoverlap-len3",
    "nonoverlap-len6",
    "nonoverlap-len32",
    "overlap-text-like",
    "overlap-distance-heavy",
}
EXPECTED_CLASSES = {"rle", "small_distance", "non_overlapping", "overlapping"}


def positive_int(row: dict[str, str], key: str) -> bool:
    try:
        return int(row.get(key, "0")) > 0
    except ValueError:
        return False


def positive_float(row: dict[str, str], key: str) -> bool:
    try:
        return float(row.get(key, "0")) > 0.0
    except ValueError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-match-copy-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_match_copy_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_match_copy_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    expected_rows = len(EXPECTED_CASES) * len(EXPECTED_KERNELS)
    if len(rows) != expected_rows:
        print(f"deflate_match_copy_bench_gate=bad_row_count rows={len(rows)} expected={expected_rows}", file=sys.stderr)
        return 1
    seen = set()
    cases = set()
    kernels = set()
    classes = set()
    for row in rows:
        key = (row.get("case", ""), row.get("kernel", ""))
        if key in seen:
            print(f"deflate_match_copy_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        cases.add(row.get("case", ""))
        kernels.add(row.get("kernel", ""))
        classes.add(row.get("class", ""))
        if not all(positive_int(row, field) for field in ("length", "distance", "ops_per_iter", "iterations", "output_bytes", "elapsed_ns", "checksum")):
            print(f"deflate_match_copy_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not positive_float(row, "output_mib_per_s"):
            print(f"deflate_match_copy_bench_gate=bad_throughput row={row}", file=sys.stderr)
            return 1
    if cases != EXPECTED_CASES or kernels != EXPECTED_KERNELS or not classes <= EXPECTED_CLASSES:
        print(f"deflate_match_copy_bench_gate=bad_sets cases={sorted(cases)} kernels={sorted(kernels)} classes={sorted(classes)}", file=sys.stderr)
        return 1
    print(f"deflate_match_copy_bench_gate=ok cases={len(cases)} kernels={len(kernels)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
