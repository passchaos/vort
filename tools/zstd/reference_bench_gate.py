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
    "ll_mode", "of_mode", "ml_mode", "header_inspect_ns",
    "block_inspect_ns", "sequence_inspect_ns",
    "alloc_ns", "alloc_mib_s", "into_over_alloc",
]
EXPECTED_CASES = {
    "tiny", "text", "structured", "repetitive",
    "incompressible", "rle64k", "raw256k",
    "numbered_json", "huffman80k", "ascii64k",
    "large_text", "large_json", "binary_mixed",
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
            "header_inspect_ns", "block_inspect_ns", "sequence_inspect_ns",
            "alloc_ns",
        ):
            if int(row[key]) <= 0:
                raise AssertionError(f"non-positive {key}: {row}")
        if int(row["raw_blocks"]) + int(row["rle_blocks"]) + int(
            row["compressed_blocks"]
        ) != int(row["block_count"]):
            raise AssertionError(f"block count mismatch: {row}")
        for key in (
            "vort_mib_s", "reference_mib_s", "vort_over_reference",
            "alloc_mib_s", "into_over_alloc",
        ):
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
    if int(by_case["numbered_json"]["sequence_count"]) <= 1:
        raise AssertionError(f"expected multi-sequence row: {by_case['numbered_json']}")
    if by_case["numbered_json"]["of_mode"] != "compressed":
        raise AssertionError(f"expected FSE row: {by_case['numbered_json']}")
    if int(by_case["huffman80k"]["sequence_count"]) < 100:
        raise AssertionError(f"expected large sequence row: {by_case['huffman80k']}")
    if by_case["ascii64k"]["literals_kind"] != "compressed":
        raise AssertionError(f"expected Huffman literals row: {by_case['ascii64k']}")
    for name in ("large_text", "large_json", "binary_mixed"):
        if int(by_case[name]["block_count"]) < 4 or int(by_case[name]["compressed_blocks"]) < 4:
            raise AssertionError(f"expected multi-block compressed row: {by_case[name]}")

    # This gate is evidence-first: the first matrix establishes real gaps
    # rather than pretending Vort already leads. Bound catastrophic regressions
    # while retaining exact per-case ratios for follow-up fast-path work.
    floors = {
        "tiny": 0.10, "text": 0.60, "structured": 0.25,
        "repetitive": 0.28, "incompressible": 5.0, "rle64k": 0.75,
        "raw256k": 0.85,
        "numbered_json": 0.16, "huffman80k": 0.37, "ascii64k": 0.07,
        "large_text": 0.85, "large_json": 0.24, "binary_mixed": 0.30,
    }
    for name, floor in floors.items():
        if float(by_case[name]["vort_over_reference"]) < floor:
            raise AssertionError(f"decode regression {name}: {by_case[name]}")

    # Known-size one-block frames should allocate once and decode directly,
    # rather than paying the former full size-preflight plus second decode.
    # Keep enough scheduler slack for the short optional gate while ensuring
    # the compressed allocator path remains within 2.5x of caller-owned decode.
    for name in compressed | {
        "numbered_json", "huffman80k", "ascii64k", "large_text",
        "large_json", "binary_mixed",
    }:
        if float(by_case[name]["into_over_alloc"]) > 2.5:
            raise AssertionError(f"allocator decode regression {name}: {by_case[name]}")
    for name in ("large_text", "large_json", "binary_mixed"):
        if float(by_case[name]["into_over_alloc"]) > 1.25:
            raise AssertionError(f"multi-block allocator regression {name}: {by_case[name]}")
    if float(by_case["incompressible"]["into_over_alloc"]) > 3.0:
        raise AssertionError(
            f"raw allocator decode regression: {by_case['incompressible']}"
        )

    print(
        "zstd_reference_bench_gate=ok "
        f"rows={len(rows)} reference_version={next(iter(versions))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
