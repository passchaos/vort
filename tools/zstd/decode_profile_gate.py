#!/usr/bin/env python3
"""Validate the focused pure-Vort Zstd decode profile."""
import argparse
import csv
from pathlib import Path

COLUMNS = ["case", "input_bytes", "encoded_bytes", "iterations", "vort_ns", "vort_mib_s", "checksum", "literals_kind", "sequence_count", "ll_mode", "of_mode", "ml_mode"]
CASES = {"numbered_json", "huffman80k", "large_json", "binary_mixed"}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == len(CASES) and set(by_case) == CASES, sorted(by_case)
    for row in rows:
        for key in ("input_bytes", "encoded_bytes", "iterations", "vort_ns", "checksum"):
            assert int(row[key]) > 0, row
        assert float(row["vort_mib_s"]) > 0, row
    huffman = by_case["huffman80k"]
    assert huffman["literals_kind"] == "raw" and int(huffman["sequence_count"]) >= 1000, huffman
    assert (huffman["ll_mode"], huffman["of_mode"], huffman["ml_mode"]) == ("compressed", "compressed", "compressed"), huffman
    for name in ("large_json", "binary_mixed"):
        row = by_case[name]
        assert int(row["sequence_count"]) >= 1000, row
        assert row["of_mode"] == "compressed", row
    print(f"zstd_decode_profile_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
