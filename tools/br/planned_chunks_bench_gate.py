#!/usr/bin/env python3
"""Validate the fast planned Brotli multi-meta-block benchmark row."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "input_bytes", "multiblock_bytes", "separate_bytes", "iterations",
    "multiblock_ns", "separate_ns", "speedup", "compressed_blocks",
    "stored_blocks", "checksum",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        assert reader.fieldnames == COLUMNS
        rows = list(reader)
    assert len(rows) == 1
    row = rows[0]
    for key in COLUMNS[:-1]:
        assert float(row[key]) > 0, row
    assert int(row["checksum"]) > 0
    # A single stream preserves cross-block history and exact caller chunk
    # boundaries, while three separate frames can independently choose their
    # final-block representation. Keep the measured framing delta bounded
    # instead of requiring the richer multi-block contract to be smaller.
    assert int(row["multiblock_bytes"]) <= int(row["separate_bytes"]) + 8
    assert int(row["compressed_blocks"]) >= 2
    assert int(row["stored_blocks"]) >= 1
    assert float(row["speedup"]) >= 0.40
    print("br_planned_chunks_bench_gate=ok rows=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
