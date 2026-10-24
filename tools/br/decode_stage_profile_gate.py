#!/usr/bin/env python3
"""Validate the focused high-tree-count Brotli decode-stage profile."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "case", "reference_version", "quality", "input_bytes", "encoded_bytes",
    "iterations", "literal_trees", "command_block_types", "distance_trees",
    "npostfix", "ndirect", "header_ns", "literal_lookup_ns",
    "command_lookup_ns", "distance_lookup_ns", "lookup_ns", "payload_ns",
    "total_ns", "unattributed_ns", "header_share", "lookup_share",
    "payload_share", "unattributed_share", "checksum",
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
    if len(rows) != 1 or rows[0]["case"] != "clustered_q8":
        raise AssertionError(f"bad rows: {rows!r}")
    row = rows[0]
    expected_shape = {
        "quality": 8,
        "input_bytes": 1024 * 1024,
        "literal_trees": 52,
        "command_block_types": 3,
        "distance_trees": 17,
        "npostfix": 0,
        "ndirect": 0,
    }
    for key, expected in expected_shape.items():
        if int(row[key]) != expected:
            raise AssertionError(f"bad {key}: {row!r}")
    for key in (
        "reference_version", "encoded_bytes", "iterations", "header_ns",
        "literal_lookup_ns", "command_lookup_ns", "distance_lookup_ns",
        "lookup_ns", "payload_ns", "total_ns", "checksum",
    ):
        if int(row[key], 16 if key == "reference_version" else 10) <= 0:
            raise AssertionError(f"non-positive {key}: {row!r}")
    lookup_ns = sum(int(row[key]) for key in (
        "literal_lookup_ns", "command_lookup_ns", "distance_lookup_ns",
    ))
    if lookup_ns != int(row["lookup_ns"]):
        raise AssertionError(f"lookup total mismatch: {row!r}")
    stage_ns = int(row["header_ns"]) + lookup_ns + int(row["payload_ns"])
    if stage_ns + int(row["unattributed_ns"]) != int(row["total_ns"]):
        raise AssertionError(f"stage total mismatch: {row!r}")
    share_total = sum(float(row[key]) for key in (
        "header_share", "lookup_share", "payload_share", "unattributed_share",
    ))
    if not 0.999 <= share_total <= 1.001:
        raise AssertionError(f"share total mismatch: {row!r}")
    if float(row["payload_share"]) <= 0.5:
        raise AssertionError(f"payload no longer dominates target: {row!r}")
    print(
        "br_decode_stage_profile_gate=ok "
        f"reference_version={row['reference_version']} encoded_bytes={row['encoded_bytes']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
