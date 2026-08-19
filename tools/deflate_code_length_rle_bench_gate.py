#!/usr/bin/env python3
"""Validate fused dynamic-header code-length RLE planning."""

import argparse
import csv
import pathlib
import sys

sys.dont_write_bytecode = True
CASES = {"sparse", "mixed", "boundary", "dense"}
MODES = {"fused", "reference"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        expected_columns = {"case", "mode", "iterations", "elapsed_ns", "plans_per_s", "checksum"}
        if set(reader.fieldnames or []) != expected_columns:
            raise SystemExit(f"bad code-length RLE benchmark header: {reader.fieldnames}")
        rows = list(reader)
    by_key = {(row["case"], row["mode"]): row for row in rows}
    expected = {(case, mode) for case in CASES for mode in MODES}
    if set(by_key) != expected:
        raise SystemExit(f"code-length RLE coverage mismatch: missing={sorted(expected - set(by_key))}")
    ratios = []
    for case in CASES:
        fused = by_key[(case, "fused")]
        reference = by_key[(case, "reference")]
        if fused["checksum"] != reference["checksum"]:
            raise SystemExit(f"{case}: fused/reference checksum mismatch")
        ratio = float(fused["plans_per_s"]) / float(reference["plans_per_s"])
        ratios.append(ratio)
    geometric = product(ratios) ** (1.0 / len(ratios))
    if geometric <= 1.0:
        raise SystemExit(f"fused planner geometric mean not faster ({geometric:.3f})")
    print(f"code-length RLE gate: cases={len(CASES)} geomean={geometric:.3f}x")
    return 0


def product(values: list[float]) -> float:
    result = 1.0
    for value in values:
        result *= value
    return result


if __name__ == "__main__":
    sys.exit(main())
