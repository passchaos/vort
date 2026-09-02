#!/usr/bin/env python3
"""Validate the optional Vort/libsnappy caller-owned decode comparison."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

EXPECTED_COLUMNS = [
    "case",
    "input_bytes",
    "encoded_bytes",
    "iterations",
    "vort_ns",
    "reference_ns",
    "vort_mib_s",
    "reference_mib_s",
    "vort_over_reference",
    "checksum",
    "literal_count",
    "literal_bytes",
    "copy_count",
    "copy_bytes",
    "copy1_count",
    "copy2_count",
    "copy4_count",
]
EXPECTED_CASES = {
    "tiny",
    "text",
    "structured",
    "repetitive",
    "incompressible",
    "rle64k",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()

    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != EXPECTED_COLUMNS:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)

    by_case = {row["case"]: row for row in rows}
    if len(rows) != len(EXPECTED_CASES) or set(by_case) != EXPECTED_CASES:
        raise AssertionError(f"bad cases: {sorted(by_case)!r}")
    for name, row in by_case.items():
        for key in (
            "input_bytes",
            "encoded_bytes",
            "iterations",
            "vort_ns",
            "reference_ns",
            "checksum",
            "literal_count",
            "literal_bytes",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        for key in (
            "vort_mib_s",
            "reference_mib_s",
            "vort_over_reference",
        ):
            if float(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if int(row["literal_bytes"]) + int(row["copy_bytes"]) != int(
            row["input_bytes"]
        ):
            raise AssertionError(f"token byte mismatch: {row}")
        if int(row["copy1_count"]) + int(row["copy2_count"]) + int(
            row["copy4_count"]
        ) != int(row["copy_count"]):
            raise AssertionError(f"copy count mismatch: {row}")

    required_leaders = {"tiny", "text", "structured", "incompressible", "rle64k"}
    for name in required_leaders:
        if float(by_case[name]["vort_over_reference"]) < 1.10:
            raise AssertionError(f"Vort no longer leads {name}: {by_case[name]}")
    # The locked distance-32 COPY_2 row used to be the only observed weak
    # shape. The word-replay kernel now clears reference parity, so keep that
    # result as a dedicated regression contract.
    if float(by_case["repetitive"]["vort_over_reference"]) < 1.02:
        raise AssertionError(f"repetitive regression: {by_case['repetitive']}")

    print(
        "snappy_reference_bench_gate=ok "
        f"rows={len(rows)} repetitive_ratio={by_case['repetitive']['vort_over_reference']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
