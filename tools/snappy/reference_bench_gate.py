#!/usr/bin/env python3
"""Validate the optional Vort/libsnappy caller-owned decode comparison."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

EXPECTED_COLUMNS = [
    "case",
    "input_bytes",
    "input_sha256",
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
] + PROVENANCE_COLUMNS
EXPECTED_CASES = {
    "tiny",
    "text",
    "structured",
    "repetitive",
    "incompressible",
    "rle64k",
}
COPY_HEAVY_CASES = {"text", "structured", "repetitive", "rle64k"}
MINIMUM_CASE_RATIO = 1.0
MINIMUM_COPY_HEAVY_GEOMEAN = 1.10
MINIMUM_MATRIX_GEOMEAN = 1.25


def geometric_mean(values: list[float]) -> float:
    return math.exp(math.fsum(math.log(value) for value in values) / len(values))


def validate_performance(by_case: dict[str, dict[str, str]]) -> tuple[float, float, str]:
    ratios = {
        name: float(row["vort_over_reference"])
        for name, row in by_case.items()
    }
    weakest = min(ratios, key=ratios.get)
    if ratios[weakest] < MINIMUM_CASE_RATIO:
        raise AssertionError(f"Vort no longer leads {weakest}: {by_case[weakest]}")
    copy_geomean = geometric_mean([ratios[name] for name in COPY_HEAVY_CASES])
    if copy_geomean < MINIMUM_COPY_HEAVY_GEOMEAN:
        raise AssertionError(
            f"copy-heavy geomean regression: {copy_geomean:.4f} < "
            f"{MINIMUM_COPY_HEAVY_GEOMEAN:.2f}"
        )
    matrix_geomean = geometric_mean(list(ratios.values()))
    if matrix_geomean < MINIMUM_MATRIX_GEOMEAN:
        raise AssertionError(
            f"matrix geomean regression: {matrix_geomean:.4f} < "
            f"{MINIMUM_MATRIX_GEOMEAN:.2f}"
        )
    return copy_geomean, matrix_geomean, weakest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()

    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != EXPECTED_COLUMNS:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)
    validate_provenance(
        rows, executable=args.executable, codec_thread_policy="single"
    )

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

    copy_geomean, matrix_geomean, weakest = validate_performance(by_case)

    print(
        "snappy_reference_bench_gate=ok "
        f"rows={len(rows)} weakest={weakest} "
        f"weakest_ratio={by_case[weakest]['vort_over_reference']} "
        f"copy_geomean={copy_geomean:.4f} matrix_geomean={matrix_geomean:.4f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
