#!/usr/bin/env python3
"""Validate indexed versus exhaustive Brotli static-dictionary evidence."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "case",
    "input_bytes",
    "index_entries",
    "index_bytes",
    "encoded_bytes",
    "iterations",
    "indexed_ns",
    "reference_ns",
    "speedup",
    "checksum",
]
CASES = {"omit_first", "literal_prefix", "dictionary_phrase"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        assert reader.fieldnames == COLUMNS
        rows = list(reader)
    assert {row["case"] for row in rows} == CASES
    assert len(rows) == len(CASES)
    for row in rows:
        assert int(row["input_bytes"]) >= 5, row
        assert int(row["index_entries"]) == 59_904, row
        assert int(row["index_bytes"]) == 370_692, row
        assert int(row["encoded_bytes"]) > 0, row
        assert int(row["iterations"]) > 0, row
        assert int(row["indexed_ns"]) > 0, row
        assert int(row["reference_ns"]) > int(row["indexed_ns"]), row
        assert float(row["speedup"]) >= 100.0, row
        assert int(row["checksum"]) > 0, row
    print(f"br_complete_dictionary_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
