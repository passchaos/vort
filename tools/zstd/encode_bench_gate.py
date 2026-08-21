#!/usr/bin/env python3
"""Validate Vort/libzstd Zstandard encode evidence."""
import argparse
import csv
from pathlib import Path

COLUMNS = ["case", "reference_version", "level", "input_bytes", "vort_bytes", "reference_bytes", "size_over_reference", "iterations", "rounds", "vort_ns", "reference_ns", "vort_mib_s", "reference_mib_s", "vort_over_reference", "checksum"]
CASES = {"text", "json", "binary"}
LEVELS = {1, 3, 9}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    assert {(row["case"], int(row["level"])) for row in rows} == {(case, level) for case in CASES for level in LEVELS}
    assert len(rows) == len(CASES) * len(LEVELS)
    assert len({row["reference_version"] for row in rows}) == 1
    for row in rows:
        for key in ("input_bytes", "vort_bytes", "reference_bytes", "iterations", "rounds", "vort_ns", "reference_ns", "checksum"):
            assert int(row[key]) > 0, row
        for key in ("size_over_reference", "vort_mib_s", "reference_mib_s", "vort_over_reference"):
            assert float(row[key]) > 0, row
        assert int(row["vort_bytes"]) < int(row["input_bytes"]), row
        # Level support must be real rather than silently ignored: require at
        # least two distinct reference sizes, while recording Vort's current
        # size behavior explicitly for the next planner work.
    # At least one corpus must expose a real reference level tradeoff. Some
    # highly repetitive inputs legitimately converge to the same wire size.
    assert any(
        len({int(row["reference_bytes"]) for row in rows if row["case"] == case}) >= 2
        for case in CASES
    ), rows
    # Higher public levels must spend at least as much measured planning time
    # on the locked structured corpus. Size may remain equal until the planner
    # can express more than 32 sequences, but the level must no longer be a
    # completely ignored parameter.
    json_rows = {int(row["level"]): row for row in rows if row["case"] == "json"}
    assert int(json_rows[3]["vort_ns"]) > int(json_rows[1]["vort_ns"]), json_rows
    assert int(json_rows[9]["vort_ns"]) > int(json_rows[3]["vort_ns"]), json_rows
    # The expanded planner must retain the measured JSON improvement over the
    # old 32-sequence 16,893-byte baseline on every level.
    assert int(json_rows[1]["vort_bytes"]) <= 13_688, json_rows
    assert int(json_rows[3]["vort_bytes"]) <= 13_688, json_rows
    assert int(json_rows[9]["vort_bytes"]) <= 13_506, json_rows
    assert int(json_rows[1]["vort_bytes"]) <= 1_505, json_rows
    assert int(json_rows[3]["vort_bytes"]) <= 1_350, json_rows
    assert int(json_rows[9]["vort_bytes"]) <= 1_239, json_rows
    binary_rows = {int(row["level"]): row for row in rows if row["case"] == "binary"}
    assert int(binary_rows[1]["vort_bytes"]) <= 9_274, binary_rows
    assert int(binary_rows[3]["vort_bytes"]) <= 9_116, binary_rows
    assert int(binary_rows[9]["vort_bytes"]) <= 9_116, binary_rows
    print(f"zstd_encode_bench_gate=ok rows={len(rows)} reference_version={rows[0]['reference_version']}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
