#!/usr/bin/env python3
"""Validate the focused pure-Vort Zstd decode profile."""
import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
SPLIT_PATHS = ["all_fse", "generic", "non_huffman_literals", "below_policy", "one_stream", "incomplete_lookup"]
BATCH_COLUMNS = ["far_batch8_windows", "far_batch8_all_far", "far_batch8_all_far_common", "far_batch8_all_far_same_offset"]
COLUMNS = ["case", "api_mode", "input_bytes", "input_sha256", "encoded_bytes", "iterations", "vort_ns", "vort_mib_s", "checksum", "reusable_sequence_table_hits", "reusable_huffman_tree_hits", "block_count", "compressed_blocks", "literals_kind", "sequence_count", "ll_mode", "of_mode", "ml_mode", "sequence_blocks", "raw_literal_blocks", "rle_literal_blocks", "compressed_literal_blocks", "treeless_literal_blocks", "compressed_table_modes", "no_low_probability_tables", "low_probability_tables", "repeat_table_modes", "rle_table_modes", "predefined_table_modes", "fse_accuracy_log_histogram", "no_low_fse_accuracy_log_histogram", "split_path_order", "split_path_blocks", "split_path_sequences", "split_path_literal_bytes", "split_path_match_bytes", "total_sequences", "literal_bytes", "match_bytes", "zero_literal_sequences", "overlapping_matches", "overlapping_match_bytes", "non_overlapping_matches", "non_overlapping_match_bytes", "vector32_eligible_matches", "vector32_eligible_bytes", "match_length_histogram", "offset_histogram", "medium_length_histogram"] + BATCH_COLUMNS + PROVENANCE_COLUMNS
CASES = {"numbered_json", "huffman80k", "ascii64k", "large_json", "binary_mixed"}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == len(CASES) and set(by_case) == CASES, sorted(by_case)
    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    assert len(provenance) == 1 and all(next(iter(provenance))), provenance
    assert rows[0]["optimize"] == "ReleaseFast", rows[0]
    assert rows[0]["provenance_version"] == "1", rows[0]
    assert (rows[0]["cpu_affinity"] == "unavailable") == (int(rows[0]["affinity_cpu_count"]) == 0), rows[0]
    assert int(rows[0]["benchmark_threads"]) == 1, rows[0]
    assert rows[0]["codec_thread_policy"] == "single", rows[0]
    assert len(rows[0]["executable_sha256"]) == 64, rows[0]
    if args.executable is not None:
        assert hashlib.sha256(args.executable.read_bytes()).hexdigest() == rows[0]["executable_sha256"], rows[0]
    for row in rows:
        assert row["api_mode"] == "one-shot", row
        assert len(row["input_sha256"]) == 64 and set(row["input_sha256"]) <= set("0123456789abcdef"), row
        for key in ("input_bytes", "encoded_bytes", "iterations", "vort_ns", "checksum", "block_count", "compressed_blocks"):
            assert int(row[key]) > 0, row
        assert int(row["reusable_sequence_table_hits"]) == 0, row
        assert int(row["reusable_huffman_tree_hits"]) == 0, row
        assert float(row["vort_mib_s"]) > 0, row
        sequence_blocks = int(row["sequence_blocks"])
        literal_blocks = sum(int(row[key]) for key in ("raw_literal_blocks", "rle_literal_blocks", "compressed_literal_blocks", "treeless_literal_blocks"))
        assert literal_blocks == int(row["compressed_blocks"]), row
        table_modes = sum(int(row[key]) for key in ("compressed_table_modes", "repeat_table_modes", "rle_table_modes", "predefined_table_modes"))
        assert table_modes == sequence_blocks * 3, row
        assert sum(int(value) for value in row["fse_accuracy_log_histogram"].split(";")) == int(row["compressed_table_modes"]), row
        assert int(row["no_low_probability_tables"]) + int(row["low_probability_tables"]) == int(row["compressed_table_modes"]), row
        assert sum(int(value) for value in row["no_low_fse_accuracy_log_histogram"].split(";")) == int(row["no_low_probability_tables"]), row
        assert row["split_path_order"].split(";") == SPLIT_PATHS, row
        split_blocks = [int(value) for value in row["split_path_blocks"].split(";")]
        split_sequences = [int(value) for value in row["split_path_sequences"].split(";")]
        split_literal_bytes = [int(value) for value in row["split_path_literal_bytes"].split(";")]
        split_match_bytes = [int(value) for value in row["split_path_match_bytes"].split(";")]
        assert all(len(values) == len(SPLIT_PATHS) for values in (split_blocks, split_sequences, split_literal_bytes, split_match_bytes)), row
        assert sum(split_blocks) == sequence_blocks, row
        assert sum(split_sequences) == int(row["total_sequences"]), row
        assert sum(split_literal_bytes) <= int(row["literal_bytes"]), row
        assert sum(split_match_bytes) == int(row["match_bytes"]), row
        sequences = int(row["total_sequences"])
        overlapping = int(row["overlapping_matches"])
        non_overlapping = int(row["non_overlapping_matches"])
        assert overlapping + non_overlapping == sequences, row
        assert sum(int(value) for value in row["match_length_histogram"].split(";")) == sequences, row
        assert sum(int(value) for value in row["offset_histogram"].split(";")) == sequences, row
        medium_total = sum(int(value) for value in row["medium_length_histogram"].split(";"))
        assert medium_total <= sequences, row
        far_windows = int(row["far_batch8_windows"])
        far_all = int(row["far_batch8_all_far"])
        far_common = int(row["far_batch8_all_far_common"])
        far_same_offset = int(row["far_batch8_all_far_same_offset"])
        assert 0 <= far_windows <= sequences, row
        assert 0 <= far_common <= far_all <= far_windows, row
        assert 0 <= far_same_offset <= far_all, row
        if sequences < 8:
            assert far_windows == 0, row
        assert int(row["overlapping_match_bytes"]) + int(row["non_overlapping_match_bytes"]) == int(row["match_bytes"]), row
        assert int(row["vector32_eligible_matches"]) <= non_overlapping, row
        assert int(row["vector32_eligible_bytes"]) <= int(row["non_overlapping_match_bytes"]), row
        assert int(row["literal_bytes"]) + int(row["match_bytes"]) == int(row["input_bytes"]), row
    huffman = by_case["huffman80k"]
    assert huffman["literals_kind"] == "raw" and int(huffman["sequence_count"]) >= 1000, huffman
    ascii_huffman = by_case["ascii64k"]
    assert ascii_huffman["literals_kind"] == "compressed", ascii_huffman
    assert int(ascii_huffman["sequence_count"]) == 0, ascii_huffman
    assert (huffman["ll_mode"], huffman["of_mode"], huffman["ml_mode"]) == ("compressed", "compressed", "compressed"), huffman
    for name in ("large_json", "binary_mixed"):
        row = by_case[name]
        assert int(row["block_count"]) >= 4 and int(row["compressed_blocks"]) >= 4, row
        assert int(row["sequence_count"]) >= 1000, row
        assert row["of_mode"] == "compressed", row
    assert int(by_case["large_json"]["far_batch8_all_far"]) > 0, by_case["large_json"]
    print(f"zstd_decode_profile_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
