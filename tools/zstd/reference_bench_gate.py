#!/usr/bin/env python3
"""Validate the optional Vort/libzstd caller-owned decode comparison."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

EXPECTED_COLUMNS = [
    "case", "reference_version", "input_bytes", "encoded_bytes",
    "iterations", "vort_ns", "reference_ns", "vort_mib_s",
    "reference_mib_s", "vort_over_reference", "checksum",
    "block_count", "raw_blocks", "rle_blocks", "compressed_blocks",
    "first_block_type", "literals_kind", "sequence_count",
    "ll_mode", "of_mode", "ml_mode",
]
EXPECTED_CASES = {
    "tiny", "text", "structured", "repetitive",
    "incompressible", "rle64k", "raw256k",
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
            "input_bytes", "encoded_bytes", "iterations", "vort_ns",
            "reference_ns", "checksum", "block_count",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if int(row["raw_blocks"]) + int(row["rle_blocks"]) + int(
            row["compressed_blocks"]
        ) != int(row["block_count"]):
            raise AssertionError(f"block count mismatch: {row}")
        for key in ("vort_mib_s", "reference_mib_s", "vort_over_reference"):
            if float(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")

    compressed = {"text", "structured", "repetitive", "rle64k"}
    for name in compressed:
        row = by_case[name]
        if row["first_block_type"] != "compressed":
            raise AssertionError(f"expected compressed row: {row}")
        if row["literals_kind"] != "raw" or int(row["sequence_count"]) != 1:
            raise AssertionError(f"unexpected locked sequence shape: {row}")
    for name in {"tiny", "incompressible", "raw256k"}:
        if int(by_case[name]["raw_blocks"]) == 0:
            raise AssertionError(f"expected raw-block row: {by_case[name]}")

    # This gate is evidence-first: the first matrix establishes real gaps
    # rather than pretending Vort already leads. Bound catastrophic regressions
    # while retaining exact per-case ratios for follow-up fast-path work.
    floors = {
        "tiny": 0.70, "text": 0.40, "structured": 0.14,
        "repetitive": 0.16, "incompressible": 5.0, "rle64k": 0.35,
        "raw256k": 0.85,
    }
    for name, floor in floors.items():
        if float(by_case[name]["vort_over_reference"]) < floor:
            raise AssertionError(f"decode regression {name}: {by_case[name]}")

    print(
        "zstd_reference_bench_gate=ok "
        f"rows={len(rows)} reference_version={next(iter(versions))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
