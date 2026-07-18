#!/usr/bin/env python3
"""Validate dynamic deflate decode profile CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "case",
    "input_bytes",
    "raw_bytes",
    "dynamic_hlit",
    "dynamic_hdist",
    "dynamic_literal_max_bits",
    "dynamic_distance_max_bits",
    "literal_lookup_bits",
    "payload_ns",
    "output_bytes",
    "literal_symbols",
    "length_symbols",
    "match_bytes",
    "distance_symbols",
    "length_symbol_histogram",
    "distance_symbol_histogram",
    "top_length_symbols",
    "top_distance_symbols",
    "top_length_extra_symbols",
    "top_distance_extra_symbols",
    "length_extra_width_reads",
    "distance_extra_width_reads",
    "length_extra_width_bits",
    "distance_extra_width_bits",
    "length_extra_reads",
    "distance_extra_reads",
    "length_extra_bits",
    "distance_extra_bits",
    "literal_fast_hits",
    "literal_fast_misses",
    "distance_fast_hits",
    "distance_fast_misses",
    "literal_lookup_covered",
    "literal_lookup_size",
    "distance_lookup_covered",
    "distance_lookup_size",
    "literal_lookup_coverage_ratio",
    "distance_lookup_coverage_ratio",
    "match_rle_count",
    "match_rle_bytes",
    "match_small_distance_count",
    "match_small_distance_bytes",
    "match_non_overlapping_count",
    "match_non_overlapping_bytes",
    "match_overlapping_count",
    "match_overlapping_bytes",
    "match_rle_byte_ratio",
    "match_small_distance_byte_ratio",
    "match_non_overlapping_byte_ratio",
    "match_overlapping_byte_ratio",
    "literal_fast_miss_ratio",
    "distance_fast_miss_ratio",
    "extra_bits_per_match",
    "mix",
}

REQUIRED_CASES = {"README.md", "docs/roadmap.md"}


def parse_int(row: dict[str, str], key: str) -> int:
    try:
        return int(row.get(key, ""))
    except ValueError as exc:
        raise AssertionError(f"bad integer {key}={row.get(key)!r} row={row}") from exc


def parse_float(row: dict[str, str], key: str) -> float:
    try:
        return float(row.get(key, ""))
    except ValueError as exc:
        raise AssertionError(f"bad float {key}={row.get(key)!r} row={row}") from exc


def parse_hist(value: str, expected_len: int, label: str) -> list[int]:
    parts = value.split(";") if value else []
    if len(parts) != expected_len:
        raise AssertionError(f"{label} expected {expected_len} entries, got {len(parts)}: {value!r}")
    try:
        return [int(part) for part in parts]
    except ValueError as exc:
        raise AssertionError(f"{label} has non-integer value: {value!r}") from exc


def parse_top(value: str, label: str) -> list[tuple[int, int]]:
    parts = value.split(";") if value else []
    if len(parts) != 3:
        raise AssertionError(f"{label} expected 3 entries, got {len(parts)}: {value!r}")
    out: list[tuple[int, int]] = []
    for part in parts:
        symbol, sep, count = part.partition(":")
        if sep != ":":
            raise AssertionError(f"{label} malformed entry {part!r}")
        out.append((int(symbol), int(count)))
    if any(count <= 0 for _, count in out):
        raise AssertionError(f"{label} should have positive top counts: {value!r}")
    return out


def validate_row(row: dict[str, str]) -> None:
    for key in (
        "input_bytes",
        "raw_bytes",
        "dynamic_hlit",
        "dynamic_hdist",
        "payload_ns",
        "output_bytes",
        "literal_symbols",
        "length_symbols",
        "match_bytes",
        "distance_symbols",
        "literal_fast_hits",
        "distance_fast_hits",
        "literal_lookup_covered",
        "literal_lookup_size",
        "distance_lookup_covered",
        "distance_lookup_size",
        "mix",
    ):
        if parse_int(row, key) <= 0:
            raise AssertionError(f"{key} must be positive row={row}")
    literal_hist = parse_hist(row["length_symbol_histogram"], 29, "length_symbol_histogram")
    distance_hist = parse_hist(row["distance_symbol_histogram"], 30, "distance_symbol_histogram")
    length_width_reads = parse_hist(row["length_extra_width_reads"], 14, "length_extra_width_reads")
    distance_width_reads = parse_hist(row["distance_extra_width_reads"], 14, "distance_extra_width_reads")
    length_width_bits = parse_hist(row["length_extra_width_bits"], 14, "length_extra_width_bits")
    distance_width_bits = parse_hist(row["distance_extra_width_bits"], 14, "distance_extra_width_bits")
    if sum(literal_hist) != parse_int(row, "length_symbols"):
        raise AssertionError(f"length histogram sum mismatch row={row}")
    if sum(distance_hist) != parse_int(row, "distance_symbols"):
        raise AssertionError(f"distance histogram sum mismatch row={row}")
    if sum(length_width_reads) != parse_int(row, "length_symbols"):
        raise AssertionError(f"length width read sum mismatch row={row}")
    if sum(distance_width_reads) != parse_int(row, "distance_symbols"):
        raise AssertionError(f"distance width read sum mismatch row={row}")
    if sum(length_width_bits) != parse_int(row, "length_extra_bits"):
        raise AssertionError(f"length width bit sum mismatch row={row}")
    if sum(distance_width_bits) != parse_int(row, "distance_extra_bits"):
        raise AssertionError(f"distance width bit sum mismatch row={row}")
    literal_lookup_covered = parse_int(row, "literal_lookup_covered")
    literal_lookup_size = parse_int(row, "literal_lookup_size")
    distance_lookup_covered = parse_int(row, "distance_lookup_covered")
    distance_lookup_size = parse_int(row, "distance_lookup_size")
    if literal_lookup_covered > literal_lookup_size:
        raise AssertionError(f"literal lookup coverage exceeds size row={row}")
    if distance_lookup_covered > distance_lookup_size:
        raise AssertionError(f"distance lookup coverage exceeds size row={row}")
    if literal_lookup_size != (1 << parse_int(row, "literal_lookup_bits")):
        raise AssertionError(f"literal lookup size mismatch row={row}")
    if distance_lookup_size != 256:
        raise AssertionError(f"distance lookup size mismatch row={row}")
    literal_coverage_ratio = parse_float(row, "literal_lookup_coverage_ratio")
    distance_coverage_ratio = parse_float(row, "distance_lookup_coverage_ratio")
    if not (0.0 < literal_coverage_ratio <= 1.0):
        raise AssertionError(f"literal lookup coverage ratio out of range row={row}")
    if not (0.0 < distance_coverage_ratio <= 1.0):
        raise AssertionError(f"distance lookup coverage ratio out of range row={row}")
    match_class_count = (
        parse_int(row, "match_rle_count")
        + parse_int(row, "match_small_distance_count")
        + parse_int(row, "match_non_overlapping_count")
        + parse_int(row, "match_overlapping_count")
    )
    match_class_bytes = (
        parse_int(row, "match_rle_bytes")
        + parse_int(row, "match_small_distance_bytes")
        + parse_int(row, "match_non_overlapping_bytes")
        + parse_int(row, "match_overlapping_bytes")
    )
    if match_class_count != parse_int(row, "distance_symbols"):
        raise AssertionError(f"match class count sum mismatch row={row}")
    if match_class_bytes != parse_int(row, "match_bytes"):
        raise AssertionError(f"match class byte sum mismatch row={row}")
    for key in (
        "match_rle_byte_ratio",
        "match_small_distance_byte_ratio",
        "match_non_overlapping_byte_ratio",
        "match_overlapping_byte_ratio",
    ):
        value = parse_float(row, key)
        if not (0.0 <= value <= 1.0):
            raise AssertionError(f"{key} out of range row={row}")
    parse_top(row["top_length_symbols"], "top_length_symbols")
    parse_top(row["top_distance_symbols"], "top_distance_symbols")
    parse_top(row["top_length_extra_symbols"], "top_length_extra_symbols")
    parse_top(row["top_distance_extra_symbols"], "top_distance_extra_symbols")
    if parse_float(row, "extra_bits_per_match") <= 0:
        raise AssertionError(f"extra_bits_per_match must be positive row={row}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-deflate-dynamic-decode-profile.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"deflate_dynamic_decode_profile_gate=missing path={args.csv}", file=sys.stderr)
        return 1
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"deflate_dynamic_decode_profile_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    missing = sorted(REQUIRED_CASES - set(by_case))
    if missing:
        print(f"deflate_dynamic_decode_profile_gate=missing_cases cases={','.join(missing)}", file=sys.stderr)
        return 1
    try:
        for case in REQUIRED_CASES:
            validate_row(by_case[case])
    except AssertionError as exc:
        print(f"deflate_dynamic_decode_profile_gate=failed reason={exc}", file=sys.stderr)
        return 1
    print(f"deflate_dynamic_decode_profile_gate=ok rows={len(rows)} required={len(REQUIRED_CASES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
