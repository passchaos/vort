#!/usr/bin/env python3
"""Validate the optional Vort/libbrotli caller-owned decode comparison."""

import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

COLUMNS = [
    "case", "reference_version", "input_bytes", "input_sha256", "encoded_bytes",
    "iterations", "vort_ns", "reference_ns", "vort_mib_s",
    "reference_mib_s", "vort_over_reference", "checksum", "size_ns",
    "alloc_ns", "exact_alloc_ns", "dictionary_cases",
    "static_dictionary_copies", "static_dictionary_bytes",
    "lz77_copies", "lz77_bytes",
    "non_overlapping_lz77_copies", "non_overlapping_lz77_bytes",
    "short_non_overlapping_lz77_copies",
    "short_non_overlapping_lz77_bytes",
    "literal_lsb6_bytes", "literal_msb6_bytes",
    "literal_utf8_bytes", "literal_signed_bytes",
    "max_literal_context_trees", "max_command_block_types",
    "max_distance_context_trees",
    "command_count", "zero_insert_commands", "single_literal_insert_commands",
    "implicit_distance_commands", "copy_length_log2_histogram",
] + PROVENANCE_COLUMNS
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
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--enforce-throughput", action="store_true")
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != COLUMNS:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)
    validate_provenance(
        rows, executable=args.executable, codec_thread_policy="single"
    )
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
        # The isolated high-tree path now gives literal, command, and distance
        # trees in-table lookups and inlines the lookup wrapper. Keep margin
        # below the fixed-core ~0.56x result while preventing a regression to
        # the former ~0.46x implementation.
        "clustered_q8": 0.54,
    }
    if args.enforce_throughput:
        for name, floor in floors.items():
            if float(by_case[name]["vort_over_reference"]) < floor:
                raise AssertionError(f"decode regression {name}: {by_case[name]}")
    if args.enforce_throughput:
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
        if int(clustered["size_ns"]) > int(clustered["vort_ns"]) * 3:
            raise AssertionError(f"clustered summary regression: {clustered}")
    clustered = by_case["clustered_q8"]
    if int(clustered["max_literal_context_trees"]) < 32 or int(clustered["max_distance_context_trees"]) < 8:
        raise AssertionError(f"clustered header coverage regression: {clustered}")
    if int(clustered["static_dictionary_copies"]) <= 1000 or int(clustered["static_dictionary_bytes"]) <= 4096:
        raise AssertionError(f"clustered dictionary workload regression: {clustered}")
    if int(clustered["lz77_copies"]) <= 12000 or int(clustered["lz77_bytes"]) <= 900000:
        raise AssertionError(f"clustered LZ77 workload regression: {clustered}")
    if int(clustered["non_overlapping_lz77_copies"]) <= 12000 or int(clustered["non_overlapping_lz77_bytes"]) <= 900000:
        raise AssertionError(f"clustered non-overlapping LZ77 coverage regression: {clustered}")
    if int(clustered["short_non_overlapping_lz77_copies"]) <= 10000 or int(clustered["short_non_overlapping_lz77_bytes"]) <= 70000:
        raise AssertionError(f"clustered short LZ77 coverage regression: {clustered}")
    if (int(clustered["command_count"]) <= 16000 or
            int(clustered["zero_insert_commands"]) <= 10000 or
            int(clustered["single_literal_insert_commands"]) <= 2000 or
            int(clustered["implicit_distance_commands"]) <= 100):
        raise AssertionError(f"clustered command-shape coverage regression: {clustered}")
    for row in rows:
        command_count = int(row["command_count"])
        zero_insert_commands = int(row["zero_insert_commands"])
        single_literal_insert_commands = int(row["single_literal_insert_commands"])
        implicit_distance_commands = int(row["implicit_distance_commands"])
        copy_length_histogram = [
            int(value) for value in row["copy_length_log2_histogram"].split(";")
        ]
        if len(copy_length_histogram) != 9 or any(value < 0 for value in copy_length_histogram):
            raise AssertionError(f"bad copy-length histogram: {row}")
        if sum(copy_length_histogram) != command_count:
            raise AssertionError(f"bad command histogram total: {row}")
        if zero_insert_commands + single_literal_insert_commands > command_count:
            raise AssertionError(f"bad insert command subsets: {row}")
        if implicit_distance_commands > command_count:
            raise AssertionError(f"bad implicit-distance subset: {row}")
        if int(row["lz77_copies"]) + int(row["static_dictionary_copies"]) > command_count:
            raise AssertionError(f"bad command copy accounting: {row}")
        if int(row["non_overlapping_lz77_copies"]) > int(row["lz77_copies"]) or int(row["non_overlapping_lz77_bytes"]) > int(row["lz77_bytes"]):
            raise AssertionError(f"bad non-overlapping LZ77 subset: {row}")
        if int(row["short_non_overlapping_lz77_copies"]) > int(row["non_overlapping_lz77_copies"]) or int(row["short_non_overlapping_lz77_bytes"]) > int(row["non_overlapping_lz77_bytes"]):
            raise AssertionError(f"bad short LZ77 subset: {row}")
        literal_bytes = sum(int(row[key]) for key in ("literal_lsb6_bytes", "literal_msb6_bytes", "literal_utf8_bytes", "literal_signed_bytes"))
        token_bytes = literal_bytes + int(row["lz77_bytes"]) + int(row["static_dictionary_bytes"])
        if token_bytes != 0 and token_bytes != int(row["input_bytes"]):
            raise AssertionError(f"bad Brotli payload accounting: {row}")
    if int(clustered["literal_utf8_bytes"]) <= 16000:
        raise AssertionError(f"clustered UTF-8 context workload regression: {clustered}")
    print(f"br_reference_bench_gate=ok rows={len(rows)} reference_version={next(iter(versions))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
