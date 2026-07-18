#!/usr/bin/env python3
"""Validate chunk cursor microbenchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "operation",
    "kernel",
    "payload_bytes",
    "chunk_bytes",
    "chunk_count",
    "include_empty_chunks",
    "iterations",
    "elapsed_ns",
    "bytes_per_s",
    "mib_per_s",
    "checksum",
}

EXPECTED_CASES = {
    "read-1b-empty": {"operation": "read-byte", "payload_bytes": 8 * 1024, "chunk_bytes": 1, "include_empty_chunks": "true"},
    "copy-1b-empty": {"operation": "copy-to", "payload_bytes": 8 * 1024, "chunk_bytes": 1, "include_empty_chunks": "true"},
    "copy-7b-empty": {"operation": "copy-to", "payload_bytes": 32 * 1024, "chunk_bytes": 7, "include_empty_chunks": "true"},
    "copy-256b": {"operation": "copy-to", "payload_bytes": 64 * 1024, "chunk_bytes": 256, "include_empty_chunks": "false"},
}
EXPECTED_KERNELS = {"current", "skip_empty_advance"}


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


def expected_chunk_count(payload_bytes: int, chunk_bytes: int, include_empty: bool) -> int:
    non_empty = (payload_bytes + chunk_bytes - 1) // chunk_bytes
    return non_empty * 2 + 1 if include_empty else non_empty


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-chunk-cursor-bench.csv"))
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"chunk_cursor_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"chunk_cursor_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    expected_rows = len(EXPECTED_CASES) * len(EXPECTED_KERNELS)
    if len(rows) != expected_rows:
        print(f"chunk_cursor_bench_gate=bad_row_count rows={len(rows)} expected={expected_rows}", file=sys.stderr)
        return 1

    seen = set()
    for row in rows:
        case = row.get("case", "")
        kernel = row.get("kernel", "")
        key = (case, kernel)
        if key in seen:
            print(f"chunk_cursor_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        if case not in EXPECTED_CASES or kernel not in EXPECTED_KERNELS:
            print(f"chunk_cursor_bench_gate=unexpected row={row}", file=sys.stderr)
            return 1

        expected = EXPECTED_CASES[case]
        for field in ("operation", "include_empty_chunks"):
            if row.get(field) != expected[field]:
                print(f"chunk_cursor_bench_gate=bad_field field={field} row={row}", file=sys.stderr)
                return 1
        for field in ("payload_bytes", "chunk_bytes"):
            if int(row.get(field, "-1")) != expected[field]:
                print(f"chunk_cursor_bench_gate=bad_field field={field} row={row}", file=sys.stderr)
                return 1
        if int(row["chunk_count"]) != expected_chunk_count(expected["payload_bytes"], expected["chunk_bytes"], expected["include_empty_chunks"] == "true"):
            print(f"chunk_cursor_bench_gate=bad_chunk_count row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, field) for field in ("iterations", "elapsed_ns", "checksum")):
            print(f"chunk_cursor_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, field) for field in ("bytes_per_s", "mib_per_s")):
            print(f"chunk_cursor_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1

    missing = sorted((case, kernel) for case in EXPECTED_CASES for kernel in EXPECTED_KERNELS if (case, kernel) not in seen)
    if missing:
        print(f"chunk_cursor_bench_gate=missing rows={missing}", file=sys.stderr)
        return 1

    print(f"chunk_cursor_bench_gate=ok cases={len(EXPECTED_CASES)} kernels={len(EXPECTED_KERNELS)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
