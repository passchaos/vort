#!/usr/bin/env python3
"""Validate focused PNG scanline reconstruction benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "stage",
    "bpp",
    "iterations",
    "input_bytes",
    "output_bytes",
    "elapsed_ns",
    "output_mib_per_s",
    "checksum",
}
EXPECTED_STAGES = {"none", "sub", "up", "average", "paeth"}
EXPECTED_BPP = {"1", "2", "3", "4", "6", "8"}
MIN_RELEASEFAST_MIB_S = {
    ("up", "1"): 10_000.0,
    ("up", "2"): 10_000.0,
    ("up", "3"): 10_000.0,
    ("up", "4"): 10_000.0,
    ("up", "6"): 10_000.0,
    ("up", "8"): 10_000.0,
    ("average", "1"): 300.0,
    ("average", "2"): 600.0,
    ("average", "3"): 900.0,
    ("average", "4"): 1_000.0,
    ("average", "6"): 1_200.0,
    ("average", "8"): 1_500.0,
    ("paeth", "1"): 225.0,
    ("paeth", "4"): 350.0,
    ("paeth", "6"): 350.0,
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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-png-scanline-bench.csv"))
    parser.add_argument(
        "--enforce-throughput",
        action="store_true",
        help="enforce ReleaseFast throughput floors for optimized Up/Average/Paeth rows",
    )
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"png_scanline_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"png_scanline_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    if len(rows) != len(EXPECTED_STAGES) * len(EXPECTED_BPP):
        print(f"png_scanline_bench_gate=bad_row_count rows={len(rows)}", file=sys.stderr)
        return 1

    stages = {row.get("stage", "") for row in rows}
    bpps = {row.get("bpp", "") for row in rows}
    if stages != EXPECTED_STAGES:
        print(f"png_scanline_bench_gate=bad_stages stages={sorted(stages)}", file=sys.stderr)
        return 1
    if bpps != EXPECTED_BPP:
        print(f"png_scanline_bench_gate=bad_bpp bpp={sorted(bpps)}", file=sys.stderr)
        return 1

    seen = set()
    for row in rows:
        key = (row["stage"], row["bpp"])
        if key in seen:
            print(f"png_scanline_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        if not all(positive_int(row, field) for field in ("iterations", "input_bytes", "output_bytes", "elapsed_ns", "checksum")):
            print(f"png_scanline_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if row["input_bytes"] != row["output_bytes"]:
            print(f"png_scanline_bench_gate=io_mismatch row={row}", file=sys.stderr)
            return 1
        if not positive_float(row, "output_mib_per_s"):
            print(f"png_scanline_bench_gate=bad_throughput row={row}", file=sys.stderr)
            return 1
        floor = MIN_RELEASEFAST_MIB_S.get(key) if args.enforce_throughput else None
        if floor is not None and float(row["output_mib_per_s"]) < floor:
            print(f"png_scanline_bench_gate=throughput_regression key={key} floor={floor} row={row}", file=sys.stderr)
            return 1

    print(f"png_scanline_bench_gate=ok stages={len(stages)} bpp={len(bpps)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
