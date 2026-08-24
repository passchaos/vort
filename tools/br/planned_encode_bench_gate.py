#!/usr/bin/env python3
"""Validate planner-backed Brotli encoding A/B evidence."""
import argparse, csv
from pathlib import Path

COLUMNS = ["case", "reference_version", "quality", "input_bytes", "vort_bytes", "lazy_bytes", "reference_bytes", "iterations", "vort_ns", "lazy_ns", "reference_ns", "vort_mib_s", "lazy_mib_s", "reference_mib_s", "vort_over_reference", "lazy_over_reference", "vort_size_over_reference", "lazy_size_over_reference", "checksum"]
CASES = {"json", "source", "log"}
MAX_LAZY_BYTES = {"json": 62, "source": 84, "log": 82}

def main():
    p=argparse.ArgumentParser(); p.add_argument("--csv", type=Path, required=True); a=p.parse_args()
    with a.csv.open(newline="") as f: r=csv.DictReader(f); assert r.fieldnames == COLUMNS; rows=list(r)
    assert {x["case"] for x in rows} == CASES and len(rows) == len(CASES)
    for row in rows:
        for key in ("input_bytes","vort_bytes","lazy_bytes","reference_bytes","iterations","vort_ns","lazy_ns","reference_ns","checksum"):
            assert int(row[key]) > 0, row
        for key in ("vort_mib_s","lazy_mib_s","reference_mib_s","vort_over_reference","lazy_over_reference","vort_size_over_reference","lazy_size_over_reference"):
            assert float(row[key]) > 0, row
        assert int(row["vort_bytes"]) < int(row["input_bytes"]), row
        assert int(row["lazy_bytes"]) <= int(row["vort_bytes"]), row
        assert int(row["lazy_bytes"]) <= MAX_LAZY_BYTES[row["case"]], row
    print(f"br_planned_encode_bench_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__": raise SystemExit(main())
