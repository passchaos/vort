#!/usr/bin/env python3
"""Validate level-aware Zstd primary/adaptive scheduling evidence."""
import argparse
import csv
from pathlib import Path

COLUMNS = [
    "level", "input_bytes", "encoded_bytes", "iterations", "rounds",
    "parallel_ns", "serial_ns", "speedup", "parallel_checksum",
    "serial_checksum",
]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    assert {int(row["level"]) for row in rows} == {1, 2, 3}, rows
    assert len(rows) == 3, rows
    for row in rows:
        for key in ("input_bytes", "encoded_bytes", "iterations", "rounds", "parallel_ns", "serial_ns", "parallel_checksum", "serial_checksum"):
            assert int(row[key]) > 0, row
        assert int(row["parallel_checksum"]) == int(row["serial_checksum"]), row
        assert float(row["speedup"]) > 1.01, row
    by_level = {int(row["level"]): row for row in rows}
    assert int(by_level[1]["encoded_bytes"]) == 28_328, by_level
    assert int(by_level[2]["encoded_bytes"]) == 28_328, by_level
    assert int(by_level[3]["encoded_bytes"]) == 27_758, by_level
    print(f"zstd_level_schedule_bench_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
