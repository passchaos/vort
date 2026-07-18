#!/usr/bin/env python3
"""Validate chunked zlib benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "encoder",
    "input_bytes",
    "zlib_bytes",
    "chunk_bytes",
    "chunk_count",
    "include_empty_chunks",
    "iterations",
    "repeat",
    "contiguous_mib_s",
    "chunk_join_mib_s",
    "chunk_direct_mib_s",
    "direct_strategy",
    "direct_over_contiguous",
    "direct_over_join",
    "join_over_contiguous",
    "mix",
}

EXPECTED_CASES = {
    "png-rgb8-dynamic-64b": {
        "encoder": "best",
        "input_bytes": (96 * 3 + 1) * 64,
        "chunk_bytes": 64,
        "include_empty_chunks": "false",
        "direct_strategy": "stack-join",
    },
    "png-rgb8-dynamic-1b-empty": {
        "encoder": "best",
        "input_bytes": (48 * 3 + 1) * 48,
        "chunk_bytes": 1,
        "include_empty_chunks": "true",
        "direct_strategy": "stack-join",
    },
    "png-rgb8-literal-large-4k": {
        "encoder": "dynamic_literal",
        "input_bytes": (512 * 3 + 1) * 256,
        "chunk_bytes": 4096,
        "include_empty_chunks": "false",
        "direct_strategy": "chunked-reader",
    },
    "png-rgb8-match-large-4k": {
        "encoder": "best",
        "input_bytes": (512 * 3 + 1) * 256,
        "chunk_bytes": 4096,
        "include_empty_chunks": "false",
        "direct_strategy": "chunked-reader",
    },
    "png-rgba8-stored-256b": {
        "encoder": "stored",
        "input_bytes": (128 * 4 + 1) * 96,
        "chunk_bytes": 256,
        "include_empty_chunks": "false",
        "direct_strategy": "stored-direct",
    },
    "png-indexed-stored-1b-empty": {
        "encoder": "stored",
        "input_bytes": (96 + 1) * 64,
        "chunk_bytes": 1,
        "include_empty_chunks": "true",
        "direct_strategy": "stack-join",
    },
    "png-indexed-stored-7b-empty": {
        "encoder": "stored",
        "input_bytes": (257 + 1) * 48,
        "chunk_bytes": 7,
        "include_empty_chunks": "true",
        "direct_strategy": "stack-join",
    },
    "png-literal-16b": {
        "encoder": "dynamic_literal",
        "input_bytes": (80 * 3 + 1) * 80,
        "chunk_bytes": 16,
        "include_empty_chunks": "false",
        "direct_strategy": "stack-join",
    },
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


def expected_chunk_count(zlib_bytes: int, chunk_bytes: int, include_empty: bool) -> int:
    non_empty = max(1, math.ceil(zlib_bytes / chunk_bytes))
    return non_empty * 2 + 1 if include_empty else non_empty


def check_ratio(row: dict[str, str], numerator: str, denominator: str, ratio_key: str) -> bool:
    reported = float(row[ratio_key])
    computed = float(row[numerator]) / float(row[denominator])
    return abs(reported - computed) <= 0.005


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-chunked-zlib-bench-report-repeat3.csv"))
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"chunked_zlib_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"chunked_zlib_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    by_case = {row.get("case", ""): row for row in rows}
    missing = sorted(set(EXPECTED_CASES) - set(by_case))
    extra = sorted(set(by_case) - set(EXPECTED_CASES))
    if missing or extra or len(rows) != len(EXPECTED_CASES):
        print(f"chunked_zlib_bench_gate=bad_cases missing={missing} extra={extra} rows={len(rows)}", file=sys.stderr)
        return 1

    for case, expected in EXPECTED_CASES.items():
        row = by_case[case]
        if row.get("encoder") != expected["encoder"]:
            print(f"chunked_zlib_bench_gate=bad_encoder case={case} row={row}", file=sys.stderr)
            return 1
        for key in ("input_bytes", "chunk_bytes"):
            if int(row.get(key, "-1")) != expected[key]:
                print(f"chunked_zlib_bench_gate=bad_{key} case={case} row={row}", file=sys.stderr)
                return 1
        if row.get("include_empty_chunks") != expected["include_empty_chunks"]:
            print(f"chunked_zlib_bench_gate=bad_empty_flag case={case} row={row}", file=sys.stderr)
            return 1
        if row.get("direct_strategy") != expected["direct_strategy"]:
            print(f"chunked_zlib_bench_gate=bad_direct_strategy case={case} row={row}", file=sys.stderr)
            return 1

        if not all(positive_int(row, key) for key in ("zlib_bytes", "chunk_count", "iterations", "repeat", "mix")):
            print(f"chunked_zlib_bench_gate=bad_positive_int case={case} row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, key) for key in ("contiguous_mib_s", "chunk_join_mib_s", "chunk_direct_mib_s", "direct_over_contiguous", "direct_over_join", "join_over_contiguous")):
            print(f"chunked_zlib_bench_gate=bad_positive_float case={case} row={row}", file=sys.stderr)
            return 1

        zlib_bytes = int(row["zlib_bytes"])
        chunk_bytes = int(row["chunk_bytes"])
        include_empty = row["include_empty_chunks"] == "true"
        if int(row["chunk_count"]) != expected_chunk_count(zlib_bytes, chunk_bytes, include_empty):
            print(f"chunked_zlib_bench_gate=bad_chunk_count case={case} row={row}", file=sys.stderr)
            return 1
        if zlib_bytes < 6:
            print(f"chunked_zlib_bench_gate=zlib_too_small case={case} row={row}", file=sys.stderr)
            return 1
        if not check_ratio(row, "chunk_direct_mib_s", "contiguous_mib_s", "direct_over_contiguous"):
            print(f"chunked_zlib_bench_gate=bad_direct_contiguous_ratio case={case} row={row}", file=sys.stderr)
            return 1
        if not check_ratio(row, "chunk_direct_mib_s", "chunk_join_mib_s", "direct_over_join"):
            print(f"chunked_zlib_bench_gate=bad_direct_join_ratio case={case} row={row}", file=sys.stderr)
            return 1
        if not check_ratio(row, "chunk_join_mib_s", "contiguous_mib_s", "join_over_contiguous"):
            print(f"chunked_zlib_bench_gate=bad_join_contiguous_ratio case={case} row={row}", file=sys.stderr)
            return 1

    print(f"chunked_zlib_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
