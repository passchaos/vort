#!/usr/bin/env python3
"""Validate focused DEFLATE Huffman lookup benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "decoder",
    "lookup_bits",
    "symbols_per_iter",
    "iterations",
    "input_bytes",
    "elapsed_ns",
    "symbols_per_s",
    "mib_per_s",
    "checksum",
}
EXPECTED = {
    "fixed-literal": {"table", "fixed_fast", "fast9"},
    "fixed-distance": {"table", "fixed_fast", "fast5", "fast8"},
    "dynamic-mixed": {"table", "fast9", "fast11", "fast12"},
    "dynamic-long-tail": {"table", "fast9", "fast11", "fast12"},
    "dynamic-distance": {"table", "fast5", "fast8"},
}
LOOKUP_BITS = {"table": 0, "fixed_fast": 9, "fast5": 5, "fast8": 8, "fast9": 9, "fast11": 11, "fast12": 12}


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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-huffman-lookup-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_huffman_lookup_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_huffman_lookup_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    by_case: dict[str, set[str]] = {case: set() for case in EXPECTED}
    seen = set()
    for row in rows:
        case = row.get("case", "")
        decoder = row.get("decoder", "")
        if case not in EXPECTED or decoder not in EXPECTED[case]:
            print(f"deflate_huffman_lookup_bench_gate=unexpected row={row}", file=sys.stderr)
            return 1
        key = (case, decoder)
        if key in seen:
            print(f"deflate_huffman_lookup_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        by_case[case].add(decoder)
        if int(row.get("lookup_bits", "-1")) != LOOKUP_BITS[decoder]:
            print(f"deflate_huffman_lookup_bench_gate=bad_lookup row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, field) for field in ("symbols_per_iter", "iterations", "input_bytes", "elapsed_ns", "checksum")):
            print(f"deflate_huffman_lookup_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, field) for field in ("symbols_per_s", "mib_per_s")):
            print(f"deflate_huffman_lookup_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1
    for case, decoders in EXPECTED.items():
        if by_case[case] != decoders:
            print(f"deflate_huffman_lookup_bench_gate=missing case={case} decoders={sorted(decoders - by_case[case])}", file=sys.stderr)
            return 1
    print(f"deflate_huffman_lookup_bench_gate=ok cases={len(EXPECTED)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
