#!/usr/bin/env python3
"""Validate the Vort/liblz4 LZ4HC frame encode benchmark."""

import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance


COLUMNS = [
    "case", "reference_version", "block_mode", "level", "input_bytes",
    "input_sha256", "dictionary_bytes", "encoded_bytes", "iterations",
    "vort_ns", "reference_ns", "vort_mib_s", "reference_mib_s",
    "vort_over_reference", "compressed_ratio", "checksum",
] + PROVENANCE_COLUMNS
CASES = {
    "independent_l9", "linked_l9", "linked_l12",
    "dictionary_independent_l9", "dictionary_linked_l9",
    "dictionary_linked_l12",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != COLUMNS:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)
    validate_provenance(rows, executable=args.executable, codec_thread_policy="single")
    by_case = {row["case"]: row for row in rows}
    if len(rows) != len(CASES) or set(by_case) != CASES:
        raise AssertionError(f"bad cases: {sorted(by_case)!r}")
    versions = {row["reference_version"] for row in rows}
    if len(versions) != 1 or not next(iter(versions)):
        raise AssertionError(f"bad versions: {versions!r}")
    for row in rows:
        for key in (
            "level", "input_bytes", "encoded_bytes", "iterations",
            "vort_ns", "reference_ns", "checksum",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row!r}")
        for key in ("vort_mib_s", "reference_mib_s", "vort_over_reference", "compressed_ratio"):
            if float(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row!r}")
        if row["block_mode"] not in {"independent", "linked"}:
            raise AssertionError(f"bad mode: {row!r}")
        has_dictionary = row["case"].startswith("dictionary_")
        if (int(row["dictionary_bytes"]) > 0) != has_dictionary:
            raise AssertionError(f"dictionary shape mismatch: {row!r}")
        if int(row["encoded_bytes"]) >= int(row["input_bytes"]):
            raise AssertionError(f"benchmark lost compression: {row!r}")
    print(
        "lz4_hc_reference_bench_gate=ok "
        f"rows={len(rows)} reference_version={next(iter(versions))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
