#!/usr/bin/env python3
"""Validate warmed incremental planned Brotli encoder reuse."""

import argparse
import csv
from pathlib import Path

COLUMNS = [
    "input_bytes", "iterations", "one_shot_bytes", "reusable_bytes",
    "one_shot_ns", "reusable_ns",
    "speedup", "one_shot_checksum", "reusable_checksum",
    "retained_bytes",
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
    assert int(row["reusable_bytes"]) <= int(row["one_shot_bytes"]) + 2, row
    assert float(row["speedup"]) >= 1.10, row
    print("br_incremental_planned_bench_gate=ok rows=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
