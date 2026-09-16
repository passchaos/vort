#!/usr/bin/env python3
"""Validate the optional Vort/libzstd caller-owned decode comparison."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
EXPECTED_COLUMNS = [
    "case", "reference_version", "input_bytes", "input_sha256", "encoded_bytes",
    "iterations", "vort_ns", "reference_ns", "vort_mib_s",
    "reference_mib_s", "vort_over_reference", "checksum",
    "block_count", "raw_blocks", "rle_blocks", "compressed_blocks",
    "first_block_type", "literals_kind", "sequence_count",
    "ll_mode", "of_mode", "ml_mode", "header_inspect_ns",
    "block_inspect_ns", "sequence_inspect_ns",
    "alloc_ns", "alloc_mib_s", "into_over_alloc",
] + PROVENANCE_COLUMNS
EXPECTED_CASES = {
    "tiny", "text", "structured", "repetitive",
    "incompressible", "rle64k", "raw256k",
    "numbered_json", "huffman80k", "ascii64k",
    "large_text", "large_json", "binary_mixed",
}


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
    by_case = {row["case"]: row for row in rows}
    if len(rows) != len(EXPECTED_CASES) or set(by_case) != EXPECTED_CASES:
        raise AssertionError(f"bad cases: {sorted(by_case)!r}")
    versions = {row["reference_version"] for row in rows}
    if len(versions) != 1 or not next(iter(versions)):
        raise AssertionError(f"bad reference versions: {versions!r}")
    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    if len(provenance) != 1 or not all(next(iter(provenance))):
        raise AssertionError(f"inconsistent provenance: {provenance!r}")
    if rows[0]["optimize"] != "ReleaseFast":
        raise AssertionError(f"non-ReleaseFast benchmark: {rows[0]!r}")
    if rows[0]["provenance_version"] != "1":
        raise AssertionError(f"unsupported provenance: {rows[0]!r}")
    affinity_consistent = (rows[0]["cpu_affinity"] == "unavailable") == (int(rows[0]["affinity_cpu_count"]) == 0)
    if not affinity_consistent or int(rows[0]["benchmark_threads"]) != 1 or rows[0]["codec_thread_policy"] != "single":
        raise AssertionError(f"invalid CPU/thread provenance: {rows[0]!r}")
    if len(rows[0]["executable_sha256"]) != 64:
        raise AssertionError(f"invalid executable hash: {rows[0]!r}")
    if args.executable is not None and hashlib.sha256(args.executable.read_bytes()).hexdigest() != rows[0]["executable_sha256"]:
        raise AssertionError(f"executable hash mismatch: {rows[0]!r}")

    for row in rows:
        if len(row["input_sha256"]) != 64 or not set(row["input_sha256"]) <= set("0123456789abcdef"):
            raise AssertionError(f"invalid input hash: {row!r}")
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
        # The FSE-weight linear Huffman-tree builder raised this row from the
        # former ~0.34x baseline to ~0.45x; retain conservative scheduler slack.
        # The isolated persistent-reservoir four-stream decoder raises the
        # locked zero-sequence Huffman row from ~0.60x to ~0.94x. Retain
        # scheduler slack without weakening any unrelated floor.
        # The isolated small LL-predefined/OF-FSE/ML-predefined frame decoder
        # raises the locked numbered-JSON row from ~0.44x to ~0.69x.
        # The bounded split-literal all-FSE/Huffman path raises the locked
        # multi-block JSON row from ~0.61x to ~0.74x after its one-byte literal
        # copies were removed from the generic memmove path.
        "numbered_json": 0.60, "huffman80k": 0.44, "ascii64k": 0.88,
        "large_text": 0.85, "large_json": 0.65, "binary_mixed": 0.36,
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
