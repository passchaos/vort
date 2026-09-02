#!/usr/bin/env python3
"""Validate file-backed Brotli encode benchmark evidence."""
import argparse
import csv
from pathlib import Path

from planned_encode_bench_gate import COLUMNS


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    assert rows and all(row["case"].startswith("file") for row in rows), rows
    for row in rows:
        for key in ("input_bytes", "vort_bytes", "lazy_bytes", "ratio_bytes", "reference_bytes", "iterations", "vort_ns", "lazy_ns", "ratio_ns", "reference_ns", "checksum"):
            assert int(row[key]) > 0, row
        assert int(row["ratio_bytes"]) <= int(row["lazy_bytes"]), row
        # The checked-in fixture is deliberately small and repetitive. It
        # makes path parsing and external decoding deterministic without adding
        # a heavyweight corpus dependency to the default build.
        assert int(row["ratio_bytes"]) <= int(row["reference_bytes"]), row
    print(f"br_planned_encode_path_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
