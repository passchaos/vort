#!/usr/bin/env python3
"""Validate preset-dictionary decode benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "format",
    "encoder",
    "input_bytes",
    "dict_bytes",
    "compressed_bytes",
    "iterations",
    "repeat",
    "output_bytes",
    "elapsed_ns",
    "decode_mib_s",
    "checksum",
}
EXPECTED_ROWS = {
    ("history-replay-raw-dynamic", "raw", "dynamic"),
    ("history-replay-raw-best", "raw", "best"),
    ("history-replay-zlib-fixed", "zlib", "fixed"),
    ("history-replay-zlib-dynamic", "zlib", "dynamic"),
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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-dictionary-decode-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"dictionary_decode_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"dictionary_decode_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    seen = {(row.get("case", ""), row.get("format", ""), row.get("encoder", "")) for row in rows}
    if seen != EXPECTED_ROWS or len(rows) != len(EXPECTED_ROWS):
        print(f"dictionary_decode_bench_gate=bad_rows seen={sorted(seen)}", file=sys.stderr)
        return 1
    for row in rows:
        if not all(positive_int(row, key) for key in ("input_bytes", "dict_bytes", "compressed_bytes", "iterations", "repeat", "output_bytes", "elapsed_ns", "checksum")):
            print(f"dictionary_decode_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if int(row["output_bytes"]) != int(row["input_bytes"]) * int(row["iterations"]):
            print(f"dictionary_decode_bench_gate=bad_output_bytes row={row}", file=sys.stderr)
            return 1
        if not positive_float(row, "decode_mib_s"):
            print(f"dictionary_decode_bench_gate=bad_throughput row={row}", file=sys.stderr)
            return 1
    print(f"dictionary_decode_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
