#!/usr/bin/env python3
"""Validate the optional Vort/liblz4 caller-owned block decode comparison."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

EXPECTED_COLUMNS = [
    "case",
    "reference_version",
    "input_bytes",
    "encoded_bytes",
    "vort_encoded_bytes",
    "iterations",
    "vort_ns",
    "reference_ns",
    "vort_mib_s",
    "reference_mib_s",
    "vort_over_reference",
    "checksum",
    "literal_count",
    "literal_bytes",
    "match_count",
    "match_bytes",
    "vort_literal_count",
    "vort_literal_bytes",
    "vort_match_count",
    "vort_match_bytes",
]
EXPECTED_CASES = {
    "tiny",
    "text",
    "structured",
    "repetitive",
    "incompressible",
    "incompressible256k",
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

    versions = {row["reference_version"] for row in rows}
    if len(versions) != 1 or not next(iter(versions)):
        raise AssertionError(f"bad reference versions: {versions!r}")
    for row in rows:
        for key in (
            "input_bytes",
            "encoded_bytes",
            "vort_encoded_bytes",
            "iterations",
            "vort_ns",
            "reference_ns",
            "checksum",
            "literal_count",
            "literal_bytes",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if int(row["literal_bytes"]) + int(row["match_bytes"]) != int(
            row["input_bytes"]
        ):
            raise AssertionError(f"token byte mismatch: {row}")
        if int(row["vort_literal_bytes"]) + int(row["vort_match_bytes"]) != int(
            row["input_bytes"]
        ):
            raise AssertionError(f"Vort token byte mismatch: {row}")
        if int(row["input_bytes"]) >= 12 and int(row["vort_literal_bytes"]) < 5:
            raise AssertionError(f"Vort terminal literals missing: {row}")
        for key in (
            "vort_mib_s",
            "reference_mib_s",
            "vort_over_reference",
        ):
            if float(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")

    for name in EXPECTED_CASES - {"incompressible", "incompressible256k"}:
        if float(by_case[name]["vort_over_reference"]) < 1.10:
            raise AssertionError(f"Vort no longer leads {name}: {by_case[name]}")
    if float(by_case["incompressible"]["vort_over_reference"]) < 0.90:
        raise AssertionError(
            f"incompressible decode regressed: {by_case['incompressible']}"
        )
    large_raw = by_case["incompressible256k"]
    if int(large_raw["literal_count"]) != 1 or int(large_raw["match_count"]) != 0:
        raise AssertionError(f"expected literal-only large row: {large_raw}")
    if float(large_raw["vort_over_reference"]) < 0.70:
        raise AssertionError(f"large incompressible decode regressed: {large_raw}")

    print(
        "lz4_reference_bench_gate=ok "
        f"rows={len(rows)} reference_version={next(iter(versions))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
