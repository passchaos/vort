#!/usr/bin/env python3
"""Validate the caller-owned byte-progressive Brotli copy benchmark."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "input_bytes", "encoded_bytes", "iterations", "elapsed_ns",
    "mib_s", "checksum",
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
    for key in COLUMNS:
        assert float(row[key]) > 0, row
    assert int(row["input_bytes"]) == 65_536
    assert int(row["encoded_bytes"]) < 64
    assert float(row["mib_s"]) >= 100.0
    print("br_progressive_copy_bench_gate=ok rows=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
