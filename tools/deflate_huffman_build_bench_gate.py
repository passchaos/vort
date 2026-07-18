#!/usr/bin/env python3
"""Validate focused DEFLATE Huffman table/build benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {"case", "build", "lookup_bits", "symbols", "iterations", "elapsed_ns", "builds_per_s", "checksum"}
EXPECTED = {
    "literal-mixed": {"table", "fast9", "fast11", "fast12"},
    "literal-long-tail": {"table", "fast9", "fast11", "fast12"},
    "distance-mixed": {"table", "fast5", "fast8"},
}
LOOKUP_BITS = {"table": 0, "fast5": 5, "fast8": 8, "fast9": 9, "fast11": 11, "fast12": 12}


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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-huffman-build-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_huffman_build_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_huffman_build_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    by_case = {case: set() for case in EXPECTED}
    seen = set()
    for row in rows:
        case = row.get("case", "")
        build = row.get("build", "")
        if case not in EXPECTED or build not in EXPECTED[case]:
            print(f"deflate_huffman_build_bench_gate=unexpected row={row}", file=sys.stderr)
            return 1
        key = (case, build)
        if key in seen:
            print(f"deflate_huffman_build_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        by_case[case].add(build)
        if int(row.get("lookup_bits", "-1")) != LOOKUP_BITS[build]:
            print(f"deflate_huffman_build_bench_gate=bad_lookup row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, field) for field in ("symbols", "iterations", "elapsed_ns", "checksum")):
            print(f"deflate_huffman_build_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not positive_float(row, "builds_per_s"):
            print(f"deflate_huffman_build_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1
    for case, expected in EXPECTED.items():
        if by_case[case] != expected:
            print(f"deflate_huffman_build_bench_gate=missing case={case} builds={sorted(expected - by_case[case])}", file=sys.stderr)
            return 1
    print(f"deflate_huffman_build_bench_gate=ok cases={len(EXPECTED)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
