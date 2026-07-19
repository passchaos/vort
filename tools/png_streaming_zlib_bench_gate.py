#!/usr/bin/env python3
"""Validate PNG streaming zlib scanline benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "encoder",
    "pattern",
    "width",
    "height",
    "row_bytes",
    "image_bytes",
    "zlib_bytes",
    "chunk_bytes",
    "chunk_count",
    "iterations",
    "repeat",
    "contiguous_mib_s",
    "chunked_mib_s",
    "chunked_over_contiguous",
    "mix",
}

EXPECTED_CASES = {
    "png-stream-rle-dynamic": {
        "encoder": "dynamic",
        "pattern": "zero",
        "width": 2048,
        "height": 64,
        "row_bytes": 2048,
        "image_bytes": 131072,
        "chunk_bytes": 64,
    },
    "png-stream-up-filter-dynamic": {
        "encoder": "dynamic",
        "pattern": "vertical_delta",
        "width": 2048,
        "height": 64,
        "row_bytes": 2048,
        "image_bytes": 131072,
        "chunk_bytes": 64,
    },
    "png-stream-sub-filter-dynamic": {
        "encoder": "dynamic",
        "pattern": "horizontal_delta",
        "width": 2048,
        "height": 64,
        "row_bytes": 2048,
        "image_bytes": 131072,
        "chunk_bytes": 64,
    },
    "png-stream-average-filter-dynamic": {
        "encoder": "dynamic",
        "pattern": "average_delta",
        "width": 2048,
        "height": 64,
        "row_bytes": 2048,
        "image_bytes": 131072,
        "chunk_bytes": 64,
    },
    "png-stream-paeth-filter-dynamic": {
        "encoder": "dynamic",
        "pattern": "paeth_delta",
        "width": 2048,
        "height": 64,
        "row_bytes": 2048,
        "image_bytes": 131072,
        "chunk_bytes": 64,
    },
    "png-stream-small-distance-dynamic": {
        "encoder": "dynamic",
        "pattern": "abcd",
        "width": 1024,
        "height": 64,
        "row_bytes": 4096,
        "image_bytes": 262144,
        "chunk_bytes": 64,
    },
    "png-stream-row-repeat-dynamic": {
        "encoder": "dynamic",
        "pattern": "repeated_row",
        "width": 1024,
        "height": 96,
        "row_bytes": 3072,
        "image_bytes": 294912,
        "chunk_bytes": 32,
    },
    "png-stream-row-repeat-fixed": {
        "encoder": "fixed",
        "pattern": "repeated_row",
        "width": 1024,
        "height": 64,
        "row_bytes": 3072,
        "image_bytes": 196608,
        "chunk_bytes": 32,
    },
    "png-stream-wide-rle-dynamic": {
        "encoder": "dynamic",
        "pattern": "zero",
        "width": 65536,
        "height": 16,
        "row_bytes": 65536,
        "image_bytes": 1048576,
        "chunk_bytes": 64,
    },
}
MIN_THROUGHPUT_MIB_S = {
    # These gates run in ReleaseFast via the build step. The row-repeat rows used
    # to sit around 150 MiB/s before overlapping pending matches were copied by
    # row-buffer doubling; keep a conservative floor well below the current
    # ~1.17--1.22 GiB/s evidence but high enough to catch a byte-at-a-time
    # replay regression.
    "png-stream-row-repeat-dynamic": {
        "contiguous_mib_s": 700.0,
        "chunked_mib_s": 700.0,
    },
    "png-stream-row-repeat-fixed": {
        "contiguous_mib_s": 700.0,
        "chunked_mib_s": 700.0,
    },
    "png-stream-wide-rle-dynamic": {
        "contiguous_mib_s": 700.0,
        "chunked_mib_s": 700.0,
    },
    "png-stream-up-filter-dynamic": {
        "contiguous_mib_s": 1000.0,
        "chunked_mib_s": 1000.0,
    },
    "png-stream-average-filter-dynamic": {
        "contiguous_mib_s": 250.0,
        "chunked_mib_s": 250.0,
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-png-streaming-zlib-bench-report-repeat3.csv"))
    parser.add_argument(
        "--enforce-throughput",
        action="store_true",
        help="enforce ReleaseFast MiB/s floors in addition to schema and row-shape checks",
    )
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"png_streaming_zlib_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"png_streaming_zlib_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    by_case = {row.get("case", ""): row for row in rows}
    missing = sorted(set(EXPECTED_CASES) - set(by_case))
    extra = sorted(set(by_case) - set(EXPECTED_CASES))
    if missing or extra or len(rows) != len(EXPECTED_CASES):
        print(f"png_streaming_zlib_bench_gate=bad_cases missing={missing} extra={extra} rows={len(rows)}", file=sys.stderr)
        return 1

    for case, expected in EXPECTED_CASES.items():
        row = by_case[case]
        for key, value in expected.items():
            actual = row.get(key, "")
            if isinstance(value, int):
                try:
                    actual_value = int(actual)
                except ValueError:
                    print(f"png_streaming_zlib_bench_gate=bad_int_field case={case} key={key} row={row}", file=sys.stderr)
                    return 1
                if actual_value != value:
                    print(f"png_streaming_zlib_bench_gate=bad_field case={case} key={key} expected={value} actual={actual_value}", file=sys.stderr)
                    return 1
            elif actual != value:
                print(f"png_streaming_zlib_bench_gate=bad_field case={case} key={key} expected={value} actual={actual}", file=sys.stderr)
                return 1

        if int(row["row_bytes"]) * int(row["height"]) != int(row["image_bytes"]):
            print(f"png_streaming_zlib_bench_gate=bad_image_bytes case={case} row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, key) for key in ("zlib_bytes", "chunk_count", "iterations", "repeat", "mix")):
            print(f"png_streaming_zlib_bench_gate=bad_positive_int case={case} row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, key) for key in ("contiguous_mib_s", "chunked_mib_s", "chunked_over_contiguous")):
            print(f"png_streaming_zlib_bench_gate=bad_positive_float case={case} row={row}", file=sys.stderr)
            return 1

        reported_ratio = float(row["chunked_over_contiguous"])
        computed_ratio = float(row["chunked_mib_s"]) / float(row["contiguous_mib_s"])
        if abs(reported_ratio - computed_ratio) > 0.005:
            print(
                f"png_streaming_zlib_bench_gate=bad_ratio case={case} reported={reported_ratio:.6f} computed={computed_ratio:.6f}",
                file=sys.stderr,
            )
            return 1
        floors = MIN_THROUGHPUT_MIB_S.get(case) if args.enforce_throughput else None
        if floors is not None:
            for key, floor in floors.items():
                if float(row[key]) < floor:
                    print(
                        f"png_streaming_zlib_bench_gate=throughput_regression case={case} key={key} floor={floor} row={row}",
                        file=sys.stderr,
                    )
                    return 1

    print(f"png_streaming_zlib_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
