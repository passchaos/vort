#!/usr/bin/env python3
"""Validate the optional Vort/libbrotli caller-owned decode comparison."""

import argparse
import csv
from pathlib import Path

COLUMNS = [
    "case", "reference_version", "input_bytes", "encoded_bytes",
    "iterations", "vort_ns", "reference_ns", "vort_mib_s",
    "reference_mib_s", "vort_over_reference", "checksum", "size_ns",
    "alloc_ns", "exact_alloc_ns", "dictionary_cases",
    "max_literal_context_trees", "max_command_block_types",
    "max_distance_context_trees",
]
CASES = {
    "tiny", "text", "structured", "repetitive", "random4k",
    "text_q3", "structured_q3", "repetitive_q3",
    "structured_q4",
    "text_q11", "structured_q11", "repetitive_q11",
    "clustered_q8",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != COLUMNS:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    if len(rows) != len(CASES) or set(by_case) != CASES:
        raise AssertionError(f"bad cases: {sorted(by_case)!r}")
    versions = {row["reference_version"] for row in rows}
    if len(versions) != 1 or not next(iter(versions)):
        raise AssertionError(f"bad versions: {versions!r}")
    for row in rows:
        for key in (
            "input_bytes", "encoded_bytes", "iterations", "vort_ns",
            "reference_ns", "checksum", "size_ns", "exact_alloc_ns",
            "alloc_ns", "dictionary_cases",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if int(row["dictionary_cases"]) != 21 * 5 * 121:
            raise AssertionError(f"bad dictionary differential count: {row}")
        for key in ("vort_mib_s", "reference_mib_s", "vort_over_reference"):
            if float(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
    floors = {
        "tiny": 1.0, "text": 1.25, "structured": 1.0,
        "repetitive": 1.35, "random4k": 1.5,
        "text_q3": 1.45, "structured_q3": 1.15, "repetitive_q3": 1.70,
        "structured_q4": 1.10,
        "text_q11": 1.55, "structured_q11": 1.05, "repetitive_q11": 1.75,
        # The clustered row is a coverage guard for Vort's current compact
        # tables, not yet a performance-parity claim against libbrotli's wide
        # decode tables. Keep a conservative floor so regressions remain loud.
        "clustered_q8": 0.09,
    }
    for name, floor in floors.items():
        if float(by_case[name]["vort_over_reference"]) < floor:
            raise AssertionError(f"decode regression {name}: {by_case[name]}")
    for name in (
        "text", "structured", "repetitive",
        "text_q3", "structured_q3", "repetitive_q3",
        "structured_q4",
        "text_q11", "structured_q11", "repetitive_q11",
        "clustered_q8",
    ):
        if int(by_case[name]["exact_alloc_ns"]) > int(by_case[name]["vort_ns"]) * 2:
            raise AssertionError(f"exact alloc regression {name}: {by_case[name]}")
        if int(by_case[name]["alloc_ns"]) > int(by_case[name]["vort_ns"]) * 2:
            raise AssertionError(f"alloc regression {name}: {by_case[name]}")
    clustered = by_case["clustered_q8"]
    if int(clustered["max_literal_context_trees"]) < 32 or int(clustered["max_distance_context_trees"]) < 8:
        raise AssertionError(f"clustered header coverage regression: {clustered}")
    print(f"br_reference_bench_gate=ok rows={len(rows)} reference_version={next(iter(versions))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
