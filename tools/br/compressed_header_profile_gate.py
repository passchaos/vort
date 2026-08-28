#!/usr/bin/env python3
"""Validate the Brotli compressed-header stage profile CSV."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "case", "reference_version", "quality", "input_bytes",
    "encoded_bytes", "iterations", "headers", "header_bits", "parse_ns",
    "block_switch_ns", "context_map_ns", "literal_tree_ns",
    "command_tree_ns", "distance_tree_ns", "total_ns",
    "block_switch_share", "context_map_share", "literal_tree_share",
    "command_tree_share", "distance_tree_share", "code_length_header_ns",
    "code_length_rle_ns", "canonical_build_ns", "simple_tree_ns",
    "literal_block_types", "command_block_types", "distance_block_types", "literal_trees",
    "command_trees", "distance_trees", "tree_symbols",
    "tree_entries", "complex_trees", "simple_trees",
    "code_length_symbols", "repeat_symbols", "repeated_lengths",
    "literal_code_length_header_ns", "literal_code_length_rle_ns",
    "literal_canonical_build_ns", "literal_simple_tree_ns",
    "literal_complex_trees", "literal_simple_trees",
    "literal_active_entries", "literal_code_length_symbols",
    "literal_repeat_symbols", "literal_repeated_lengths",
    "command_code_length_header_ns", "command_code_length_rle_ns",
    "command_canonical_build_ns", "command_simple_tree_ns",
    "command_complex_trees", "command_simple_trees",
    "command_active_entries", "command_code_length_symbols",
    "command_repeat_symbols", "command_repeated_lengths",
    "distance_code_length_header_ns", "distance_code_length_rle_ns",
    "distance_canonical_build_ns", "distance_simple_tree_ns",
    "distance_complex_trees", "distance_simple_trees",
    "distance_active_entries", "distance_code_length_symbols",
    "distance_repeat_symbols", "distance_repeated_lengths",
    "checksum",
]
CASES = {
    "text_q0", "structured_q3", "structured_q4",
    "structured_q11", "clustered_q8",
}
STAGES = [
    "block_switch_ns", "context_map_ns", "literal_tree_ns",
    "command_tree_ns", "distance_tree_ns",
]
SHARES = [
    "block_switch_share", "context_map_share", "literal_tree_share",
    "command_tree_share", "distance_tree_share",
]


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
    if len({row["reference_version"] for row in rows}) != 1:
        raise AssertionError("inconsistent libbrotli versions")

    for row in rows:
        for key in (
            "input_bytes", "encoded_bytes", "iterations", "headers",
            "header_bits", "parse_ns", "total_ns", "literal_block_types",
            "command_block_types", "distance_block_types",
            "literal_trees", "command_trees", "distance_trees",
            "checksum",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if sum(int(row[key]) for key in STAGES) != int(row["total_ns"]):
            raise AssertionError(f"stage total mismatch: {row}")
        prefix_ns = sum(int(row[key]) for key in (
            "code_length_header_ns", "code_length_rle_ns",
            "canonical_build_ns", "simple_tree_ns",
        ))
        tree_ns = sum(int(row[key]) for key in (
            "literal_tree_ns", "command_tree_ns", "distance_tree_ns",
        ))
        if prefix_ns > tree_ns:
            raise AssertionError(f"prefix substage exceeds parent timing: {row}")
        share_total = sum(float(row[key]) for key in SHARES)
        if not 0.999 <= share_total <= 1.001:
            raise AssertionError(f"stage share mismatch: {row}")
        if int(row["tree_symbols"]) + int(row["tree_entries"]) <= 0:
            raise AssertionError(f"empty tree shape: {row}")
        for metric in ("complex_trees", "simple_trees",
                       "code_length_symbols", "repeat_symbols", "repeated_lengths"):
            if sum(int(row[f"{family}_{metric}"]) for family in ("literal", "command", "distance")) != int(row[metric]):
                raise AssertionError(f"family {metric} mismatch: {row}")
        for metric in ("code_length_header_ns", "code_length_rle_ns",
                       "canonical_build_ns", "simple_tree_ns"):
            if sum(int(row[f"{family}_{metric}"]) for family in ("literal", "command", "distance")) != int(row[metric]):
                raise AssertionError(f"family {metric} timing mismatch: {row}")

    if int(by_case["clustered_q8"]["literal_trees"]) < 32:
        raise AssertionError(f"clustered case lost high tree count: {by_case['clustered_q8']}")
    print(
        "br_compressed_header_profile_gate=ok "
        f"rows={len(rows)} reference_version={rows[0]['reference_version']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
