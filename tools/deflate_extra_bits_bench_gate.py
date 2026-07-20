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
    "kernel",
    "bits",
    "reads_per_iter",
    "iterations",
    "input_bytes",
    "elapsed_ns",
    "reads_per_s",
    "mib_per_s",
    "checksum",
}
EXPECTED_CASES = {
    "extra-1",
    "extra-3",
    "extra-5",
    "extra-9",
    "extra-13",
    "mixed-readme-length",
    "mixed-roadmap-length",
    "mixed-readme-distance",
    "mixed-roadmap-distance",
    "distance-readme-symbol-extra",
    "distance-roadmap-symbol-extra",
}
EXPECTED_READERS = {"buffered", "chunked_4096", "span_4096", "chunked_64", "span_64", "chunked_1", "span_1"}
EXPECTED_DISTANCE_KERNELS = {"current", "fused18"}
EXPECTED_EXTRA_KERNELS = {"current", "staged"}
EXPECTED_BITS = {
    "extra-1": 1,
    "extra-3": 3,
    "extra-5": 5,
    "extra-9": 9,
    "extra-13": 13,
    "mixed-readme-length": 0,
    "mixed-roadmap-length": 0,
    "mixed-readme-distance": 0,
    "mixed-roadmap-distance": 0,
    "distance-readme-symbol-extra": 0,
    "distance-roadmap-symbol-extra": 0,
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
    expected_rows = (
        (5 + 2) * len(EXPECTED_READERS)
        + 2 * len(EXPECTED_READERS) * len(EXPECTED_EXTRA_KERNELS)
        + 2 * len(EXPECTED_READERS) * len(EXPECTED_DISTANCE_KERNELS)
    )
    if len(rows) != expected_rows:
        print(f"deflate_extra_bits_bench_gate=bad_row_count rows={len(rows)}", file=sys.stderr)
        return 1
    seen = set()
    by_key = {}
    cases = set()
    readers = set()
    for row in rows:
        case = row.get("case", "")
        reader = row.get("reader", "")
        kernel = row.get("kernel", "")
        key = (case, reader, kernel)
        if key in seen:
            print(f"deflate_extra_bits_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        by_key[key] = row
        cases.add(case)
        readers.add(reader)
        if case not in EXPECTED_BITS or int(row.get("bits", "-1")) != EXPECTED_BITS[case]:
            print(f"deflate_extra_bits_bench_gate=bad_bits row={row}", file=sys.stderr)
            return 1
        if case.startswith("distance-"):
            expected_kernel = EXPECTED_DISTANCE_KERNELS
        elif case.endswith("-length"):
            expected_kernel = EXPECTED_EXTRA_KERNELS
        else:
            expected_kernel = {"single" if case.startswith("extra-") else "mixed-extra"}
        if kernel not in expected_kernel:
            print(f"deflate_extra_bits_bench_gate=bad_kernel row={row}", file=sys.stderr)
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
    for case in ("mixed-readme-length", "mixed-roadmap-length"):
        for reader in EXPECTED_READERS:
            current = by_key[(case, reader, "current")]
            staged = by_key[(case, reader, "staged")]
            if current["checksum"] != staged["checksum"]:
                print(
                    "deflate_extra_bits_bench_gate=checksum_mismatch "
                    f"case={case} reader={reader} current={current['checksum']} staged={staged['checksum']}",
                    file=sys.stderr,
                )
                return 1
    for case in ("distance-readme-symbol-extra", "distance-roadmap-symbol-extra"):
        for reader in EXPECTED_READERS:
            current = by_key[(case, reader, "current")]
            fused = by_key[(case, reader, "fused18")]
            if current["checksum"] != fused["checksum"]:
                print(
                    "deflate_extra_bits_bench_gate=checksum_mismatch "
                    f"case={case} reader={reader} current={current['checksum']} fused18={fused['checksum']}",
                    file=sys.stderr,
                )
                return 1
    print(f"deflate_extra_bits_bench_gate=ok cases={len(cases)} readers={len(readers)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
