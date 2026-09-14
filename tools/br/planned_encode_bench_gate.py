#!/usr/bin/env python3
"""Validate planner-backed Brotli encoding A/B evidence."""
import argparse, csv, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

COLUMNS = ["case", "reference_version", "quality", "input_bytes", "input_sha256", "extended_dictionary_probes", "vort_bytes", "lazy_bytes", "ratio_bytes", "ratio_dictionary_copies", "ratio_dictionary_bytes", "reference_bytes", "iterations", "vort_ns", "lazy_ns", "ratio_ns", "reference_ns", "vort_mib_s", "lazy_mib_s", "ratio_mib_s", "reference_mib_s", "vort_over_reference", "lazy_over_reference", "ratio_over_reference", "vort_size_over_reference", "lazy_size_over_reference", "ratio_size_over_reference", "checksum"] + PROVENANCE_COLUMNS
CASES = {"json", "source", "log", "dictionary", "mixed", "uppercase", "incompressible", "records_q8", "source32k"}
DICTIONARY_CASES = {"dictionary", "mixed", "uppercase"}
MAX_LAZY_BYTES = {"json": 62, "source": 84, "log": 82}
MAX_RATIO_BYTES = {"dictionary": 24, "mixed": 29, "uppercase": 11, "incompressible": 38}

def main():
    p=argparse.ArgumentParser(); p.add_argument("--csv", type=Path, required=True); p.add_argument("--executable", type=Path); a=p.parse_args()
    with a.csv.open(newline="") as f: r=csv.DictReader(f); assert r.fieldnames == COLUMNS; rows=list(r)
    assert {x["case"] for x in rows} == CASES and len(rows) == len(CASES)
    validate_provenance(rows, executable=a.executable, codec_thread_policy="single")
    by_case = {row["case"]: row for row in rows}
    for row in rows:
        for key in ("input_bytes","vort_bytes","lazy_bytes","ratio_bytes","reference_bytes","iterations","vort_ns","lazy_ns","ratio_ns","reference_ns","checksum"):
            assert int(row[key]) > 0, row
        for key in ("ratio_dictionary_copies", "ratio_dictionary_bytes"):
            assert int(row[key]) >= 0, row
        assert 0 <= int(row["extended_dictionary_probes"]) <= 4096, row
        if int(row["input_bytes"]) > 4096:
            assert int(row["extended_dictionary_probes"]) == 0, row
        for key in ("vort_mib_s","lazy_mib_s","ratio_mib_s","reference_mib_s","vort_over_reference","lazy_over_reference","ratio_over_reference","vort_size_over_reference","lazy_size_over_reference","ratio_size_over_reference"):
            assert float(row[key]) > 0, row
        assert int(row["vort_bytes"]) <= int(row["input_bytes"]) + 4, row
        assert int(row["lazy_bytes"]) <= int(row["vort_bytes"]), row
        assert int(row["ratio_bytes"]) <= int(row["lazy_bytes"]), row
        if row["case"] in MAX_LAZY_BYTES:
            assert int(row["lazy_bytes"]) <= MAX_LAZY_BYTES[row["case"]], row
        if row["case"] in MAX_RATIO_BYTES:
            assert int(row["ratio_bytes"]) <= MAX_RATIO_BYTES[row["case"]], row
        if row["case"] in DICTIONARY_CASES:
            assert int(row["ratio_dictionary_copies"]) > 0, row
            assert int(row["ratio_dictionary_bytes"]) > 0, row
    source32k = by_case["source32k"]
    assert int(source32k["input_bytes"]) == 32 * 1024, source32k
    assert int(source32k["quality"]) == 8, source32k
    assert int(source32k["ratio_bytes"]) <= int(source32k["lazy_bytes"]) - 100, source32k
    assert float(source32k["ratio_size_over_reference"]) <= 1.02, source32k
    records_q8 = by_case["records_q8"]
    assert int(records_q8["input_bytes"]) == 32 * 1024, records_q8
    assert int(records_q8["quality"]) == 8, records_q8
    assert int(records_q8["ratio_bytes"]) <= 3134, records_q8
    assert int(records_q8["reference_bytes"]) <= int(records_q8["lazy_bytes"]) - 200, records_q8
    print(f"br_planned_encode_bench_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__": raise SystemExit(main())
