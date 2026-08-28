#!/usr/bin/env python3
"""Validate the focused pure-Vort LZ4 block decode profile."""
import argparse
import csv
from pathlib import Path

COLUMNS = ["case", "input_bytes", "encoded_bytes", "iterations", "vort_ns", "vort_mib_s", "checksum", "literal_count", "literal_bytes", "match_count", "match_bytes"]
CASES = {"text", "structured", "repetitive", "incompressible256k"}

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
        for key in ("input_bytes", "encoded_bytes", "iterations", "vort_ns", "checksum", "literal_count", "literal_bytes"):
            assert int(row[key]) > 0, row
        assert float(row["vort_mib_s"]) > 0, row
    raw = by_case["incompressible256k"]
    assert int(raw["literal_count"]) == 1 and int(raw["literal_bytes"]) == 256 * 1024, raw
    assert int(raw["match_count"]) == 0 and int(raw["match_bytes"]) == 0, raw
    for name in ("text", "structured", "repetitive"):
        row = by_case[name]
        assert int(row["match_count"]) > 0 and int(row["match_bytes"]) > 0, row
    print(f"lz4_decode_profile_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
