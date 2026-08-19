#!/usr/bin/env python3
"""Validate compact package-merge benchmark coverage and speedups."""

import argparse
import csv
import pathlib
import sys

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {"case", "mode", "symbols", "active", "max_bits", "iterations", "elapsed_ns", "builds_per_s", "checksum"}
EXPECTED = {
    "literal-sparse-18": {"production", "full-width"},
    "literal-sparse-48": {"production", "full-width"},
    "literal-dense": {"production"},
    "distance": {"production"},
    "code-length": {"production"},
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            raise SystemExit(f"bad huffman length benchmark header: {reader.fieldnames}")
        rows = list(reader)
    by_key = {(row["case"], row["mode"]): row for row in rows}
    expected = {(case, mode) for case, modes in EXPECTED.items() for mode in modes}
    if set(by_key) != expected:
        raise SystemExit(f"huffman length coverage mismatch: missing={sorted(expected - set(by_key))}")
    for row in rows:
        for key in ("symbols", "active", "max_bits", "iterations", "elapsed_ns"):
            if int(row[key]) <= 0:
                raise SystemExit(f"invalid {key}: {row}")
        if float(row["builds_per_s"]) <= 0:
            raise SystemExit(f"invalid throughput: {row}")
    ratios = []
    for case in ("literal-sparse-18", "literal-sparse-48"):
        production = by_key[(case, "production")]
        reference = by_key[(case, "full-width")]
        if production["checksum"] != reference["checksum"]:
            raise SystemExit(f"{case}: compact/full checksum mismatch")
        ratio = float(production["builds_per_s"]) / float(reference["builds_per_s"])
        if ratio <= 1.0:
            raise SystemExit(f"{case}: compact package merge not faster ({ratio:.3f})")
        ratios.append(ratio)
    print(f"huffman length gate: sparse18={ratios[0]:.2f}x sparse48={ratios[1]:.2f}x rows={len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
