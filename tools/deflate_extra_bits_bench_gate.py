#!/usr/bin/env python3
"""Validate focused DEFLATE extra-bit reader benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "reader",
    "bits",
    "reads_per_iter",
    "iterations",
    "input_bytes",
    "elapsed_ns",
    "reads_per_s",
    "mib_per_s",
    "checksum",
}
EXPECTED_CASES = {"extra-1", "extra-3", "extra-5", "extra-9", "extra-13", "mixed-readme-distance", "mixed-roadmap-distance"}
EXPECTED_READERS = {"buffered", "chunked_4096", "span_4096", "chunked_64", "span_64", "chunked_1", "span_1"}
EXPECTED_BITS = {
    "extra-1": 1,
    "extra-3": 3,
    "extra-5": 5,
    "extra-9": 9,
    "extra-13": 13,
    "mixed-readme-distance": 0,
    "mixed-roadmap-distance": 0,
}


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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-extra-bits-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_extra_bits_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_extra_bits_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    if len(rows) != len(EXPECTED_CASES) * len(EXPECTED_READERS):
        print(f"deflate_extra_bits_bench_gate=bad_row_count rows={len(rows)}", file=sys.stderr)
        return 1
    seen = set()
    cases = set()
    readers = set()
    for row in rows:
        case = row.get("case", "")
        reader = row.get("reader", "")
        key = (case, reader)
        if key in seen:
            print(f"deflate_extra_bits_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        cases.add(case)
        readers.add(reader)
        if case not in EXPECTED_BITS or int(row.get("bits", "-1")) != EXPECTED_BITS[case]:
            print(f"deflate_extra_bits_bench_gate=bad_bits row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, field) for field in ("reads_per_iter", "iterations", "input_bytes", "elapsed_ns", "checksum")):
            print(f"deflate_extra_bits_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, field) for field in ("reads_per_s", "mib_per_s")):
            print(f"deflate_extra_bits_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1
    if cases != EXPECTED_CASES or readers != EXPECTED_READERS:
        print(f"deflate_extra_bits_bench_gate=bad_sets cases={sorted(cases)} readers={sorted(readers)}", file=sys.stderr)
        return 1
    print(f"deflate_extra_bits_bench_gate=ok cases={len(cases)} readers={len(readers)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
