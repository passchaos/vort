#!/usr/bin/env python3
"""Validate native Zstd candidate-stage benchmark coverage."""

import argparse
import csv
from pathlib import Path

COLUMNS = [
    "case", "level", "candidate", "block_size", "block_count", "search_budget",
    "stage", "available_blocks", "sequences", "encoded_bytes",
    "literals_bytes", "sequence_bytes", "iterations",
    "rounds", "warmup", "median_ns", "ns_per_block", "checksum",
]
CASES = {"text", "json", "binary"}
WIDE_SEQUENCE_CASE = "wide_sequences"
CANDIDATES = {"primary", "adaptive_0", "adaptive_1"}
STAGES = {
    "duplicate_index", "mixed", "double_fast", "greedy", "lazy", "optimal",
    "rep_beam", "repeated", "multi_duplicate", "single_duplicate",
}
DOUBLE_FAST_MAX_BYTES = {
    ("text", "primary"): 210,
    ("text", "adaptive_0"): 2919,
    ("text", "adaptive_1"): 1659,
    ("json", "primary"): 687,
    ("json", "adaptive_0"): 3673,
    ("json", "adaptive_1"): 2158,
    ("binary", "primary"): 8600,
    ("binary", "adaptive_0"): 15138,
    ("binary", "adaptive_1"): 11776,
}
REP_BEAM_MAX_BYTES = {
    ("text", "primary"): 210,
    ("text", "adaptive_0"): 2919,
    ("text", "adaptive_1"): 1659,
    ("json", "primary"): 633,
    ("json", "adaptive_0"): 3672,
    ("json", "adaptive_1"): 2156,
    ("binary", "primary"): 8600,
    ("binary", "adaptive_0"): 15138,
    ("binary", "adaptive_1"): 11776,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)

    expected = {
        (case, candidate, stage)
        for case in CASES
        for candidate in CANDIDATES
        for stage in STAGES
    }
    expected.add((WIDE_SEQUENCE_CASE, "primary", "double_fast"))
    assert {(row["case"], row["candidate"], row["stage"]) for row in rows} == expected
    assert len(rows) == len(expected)
    for row in rows:
        assert int(row["level"]) == 9, row
        expected_budget = 96 if row["candidate"] == "primary" else 64
        assert int(row["search_budget"]) == expected_budget, row
        for key in ("block_size", "block_count", "iterations", "rounds", "warmup", "median_ns"):
            assert int(row[key]) > 0, row
        assert int(row["ns_per_block"]) >= 0, row
        available_blocks = int(row["available_blocks"])
        sequences = int(row["sequences"])
        encoded_bytes = int(row["encoded_bytes"])
        literals_bytes = int(row["literals_bytes"])
        sequence_bytes = int(row["sequence_bytes"])
        assert 0 <= available_blocks <= int(row["block_count"]), row
        if row["stage"] == "duplicate_index":
            assert sequences == 0, row
            assert encoded_bytes == 0, row
            assert literals_bytes == 0 and sequence_bytes == 0, row
        else:
            assert sequences >= 0, row
            assert (available_blocks == 0) == (encoded_bytes == 0), row
            if available_blocks:
                assert encoded_bytes == 3 * available_blocks + literals_bytes + sequence_bytes, row
            else:
                assert literals_bytes == 0 and sequence_bytes == 0, row
        if row["stage"] in {"double_fast", "greedy", "lazy", "optimal", "rep_beam"}:
            assert sequences > 0, row
        if row["stage"] == "double_fast":
            if row["case"] == WIDE_SEQUENCE_CASE:
                assert int(row["block_size"]) == 128 * 1024, row
                assert int(row["block_count"]) == 1, row
                assert available_blocks == 1, row
                assert sequences > 512, row
                assert encoded_bytes <= 39_598, row
            else:
                assert encoded_bytes <= DOUBLE_FAST_MAX_BYTES[(row["case"], row["candidate"])], row
        if row["stage"] == "rep_beam":
            assert encoded_bytes <= REP_BEAM_MAX_BYTES[(row["case"], row["candidate"])], row

    # The current level-9 policy is the subject of this benchmark. Pinning its
    # candidate labels to 128 KiB/4 KiB/8 KiB makes policy drift visible instead
    # of producing apparently comparable stage measurements.
    sizes = {(row["candidate"], int(row["block_size"])) for row in rows}
    assert sizes == {("primary", 128 * 1024), ("adaptive_0", 4 * 1024), ("adaptive_1", 8 * 1024)}, sizes
    print(f"zstd_native_encode_stage_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
