#!/usr/bin/env python3
"""Validate chunked Huffman decode benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "reader",
    "decoder",
    "lookup_bits",
    "chunk_bytes",
    "chunk_count",
    "symbols_per_iter",
    "iterations",
    "input_bytes",
    "elapsed_ns",
    "symbols_per_s",
    "mib_per_s",
    "checksum",
}
EXPECTED_CASES = {
    "fixed-literal": {"decoder": "fixed_fast", "lookup_bits": 9},
    "dynamic-mixed": {"decoder": "fast11", "lookup_bits": 11},
    "dynamic-long-tail": {"decoder": "fast12", "lookup_bits": 12},
}
EXPECTED_READERS = {
    "buffered": 0,
    "chunked_4096": 4096,
    "coalesced_4096": 4096,
    "chunked_64": 64,
    "coalesced_64": 64,
    "chunked_1": 1,
    "coalesced_1": 1,
}
SYMBOLS_PER_ITER = 128 * 1024


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
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-chunked-huffman-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_chunked_huffman_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_chunked_huffman_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    expected_rows = len(EXPECTED_CASES) * len(EXPECTED_READERS)
    if len(rows) != expected_rows:
        print(f"deflate_chunked_huffman_bench_gate=bad_row_count rows={len(rows)} expected={expected_rows}", file=sys.stderr)
        return 1

    seen = set()
    for row in rows:
        case = row.get("case", "")
        reader = row.get("reader", "")
        key = (case, reader)
        if key in seen:
            print(f"deflate_chunked_huffman_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(key)
        if case not in EXPECTED_CASES or reader not in EXPECTED_READERS:
            print(f"deflate_chunked_huffman_bench_gate=unexpected row={row}", file=sys.stderr)
            return 1
        expected = EXPECTED_CASES[case]
        if row.get("decoder") != expected["decoder"]:
            print(f"deflate_chunked_huffman_bench_gate=bad_decoder row={row}", file=sys.stderr)
            return 1
        if int(row.get("lookup_bits", "-1")) != expected["lookup_bits"]:
            print(f"deflate_chunked_huffman_bench_gate=bad_lookup row={row}", file=sys.stderr)
            return 1
        if int(row.get("chunk_bytes", "-1")) != EXPECTED_READERS[reader]:
            print(f"deflate_chunked_huffman_bench_gate=bad_chunk_bytes row={row}", file=sys.stderr)
            return 1
        if int(row.get("symbols_per_iter", "0")) != SYMBOLS_PER_ITER:
            print(f"deflate_chunked_huffman_bench_gate=bad_symbols row={row}", file=sys.stderr)
            return 1
        if reader == "buffered":
            if int(row.get("chunk_count", "-1")) != 0:
                print(f"deflate_chunked_huffman_bench_gate=bad_buffered_chunks row={row}", file=sys.stderr)
                return 1
        elif not positive_int(row, "chunk_count"):
            print(f"deflate_chunked_huffman_bench_gate=bad_chunk_count row={row}", file=sys.stderr)
            return 1
        if not all(positive_int(row, field) for field in ("iterations", "input_bytes", "elapsed_ns", "checksum")):
            print(f"deflate_chunked_huffman_bench_gate=bad_int row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, field) for field in ("symbols_per_s", "mib_per_s")):
            print(f"deflate_chunked_huffman_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1

    missing = sorted((case, reader) for case in EXPECTED_CASES for reader in EXPECTED_READERS if (case, reader) not in seen)
    if missing:
        print(f"deflate_chunked_huffman_bench_gate=missing rows={missing}", file=sys.stderr)
        return 1

    print(f"deflate_chunked_huffman_bench_gate=ok cases={len(EXPECTED_CASES)} readers={len(EXPECTED_READERS)} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
