#!/usr/bin/env python3
"""Validate native Zstd candidate-stage benchmark coverage."""

import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
COLUMNS = [
    "case", "level", "input_bytes", "input_sha256", "candidate", "block_size", "block_count", "search_budget",
    "stage", "available_blocks", "sequences", "encoded_bytes",
    "literals_bytes", "sequence_bytes",
    "single_positions", "single_literal_empty_inserts", "single_literal_replacements", "single_literal_rejections",
    "single_indexed_empty_inserts", "single_indexed_replacements", "single_indexed_rejections",
    "single_indexed_min_cost_rejections", "single_indexed_short_min_cost_rejections",
    "single_rep0_empty_inserts", "single_rep0_replacements", "single_rep0_rejections", "single_rep0_min_cost_rejections",
    "single_indexed_searches", "single_chain_nodes",
    "single_prefix_rejections", "single_matches", "single_shifted_matches", "single_window_stops",
    "single_chain_limit_stops", "single_indexed_length_histogram",
    "single_rep0_probes", "single_rep0_prefix_rejections", "single_rep0_prefix_mismatch_histogram", "single_rep0_matches",
    "single_rep0_length_histogram",
    "optimal_input_bytes", "optimal_index_bytes", "optimal_positions", "optimal_chain_nodes",
    "optimal_prefix_rejections", "optimal_prefix_mismatch_histogram", "optimal_bound_rejections",
    "optimal_bound_length_histogram", "optimal_bound_distance_cost_histogram", "optimal_bound_slack_histogram",
    "optimal_match_length_calls", "optimal_valid_match_candidates", "optimal_length_choices_built",
    "optimal_length_extension_histogram", "optimal_candidate_budget_stops", "optimal_index_ns",
    "optimal_search_ns", "optimal_reconstruct_ns", "optimal_total_ns", "iterations",
    "rounds", "warmup", "median_ns", "ns_per_block", "checksum",
] + PROVENANCE_COLUMNS
CASES = {"text", "json", "binary"}
WIDE_SEQUENCE_CASE = "wide_sequences"
CANDIDATES = {"primary", "adaptive_0", "adaptive_1"}
STAGES = {
    "duplicate_index", "mixed", "double_fast", "greedy", "lazy", "optimal",
    "rep_beam", "rep_beam_single", "repeated", "multi_duplicate",
    "single_duplicate",
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
SINGLE_BEAM_MAX_BYTES = {
    ("text", "primary"): 210,
    ("text", "adaptive_0"): 2919,
    ("text", "adaptive_1"): 1659,
    ("json", "primary"): 636,
    ("json", "adaptive_0"): 3672,
    ("json", "adaptive_1"): 2156,
    ("binary", "primary"): 8600,
    ("binary", "adaptive_0"): 15138,
    ("binary", "adaptive_1"): 11776,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
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
        assert len(row["input_sha256"]) == 64 and set(row["input_sha256"]) <= set("0123456789abcdef"), row
        assert int(row["level"]) == 9, row
        expected_budget = 96 if row["candidate"] == "primary" else 64
        assert int(row["search_budget"]) == expected_budget, row
        for key in ("input_bytes", "block_size", "block_count", "iterations", "rounds", "warmup", "median_ns"):
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
        if row["stage"] in {"double_fast", "greedy", "lazy", "optimal", "rep_beam", "rep_beam_single"}:
            assert sequences > 0, row
        if row["stage"] == "double_fast":
            if row["case"] == WIDE_SEQUENCE_CASE:
                assert int(row["block_size"]) == 128 * 1024, row
                assert int(row["block_count"]) == 1, row
                assert available_blocks == 1, row
                assert sequences > 512, row
                assert encoded_bytes <= 33_754, row
            else:
                assert encoded_bytes <= DOUBLE_FAST_MAX_BYTES[(row["case"], row["candidate"])], row
        if row["stage"] == "rep_beam":
            assert encoded_bytes <= REP_BEAM_MAX_BYTES[(row["case"], row["candidate"])], row
        if row["stage"] == "rep_beam_single":
            assert encoded_bytes <= SINGLE_BEAM_MAX_BYTES[(row["case"], row["candidate"])], row
            positions = int(row["single_positions"])
            assert sum(int(row[key]) for key in (
                "single_literal_empty_inserts", "single_literal_replacements", "single_literal_rejections",
            )) == positions, row
            indexed_nodes = int(row["single_chain_nodes"])
            indexed_prefix = int(row["single_prefix_rejections"])
            indexed_matches = int(row["single_matches"])
            shifted_matches = int(row["single_shifted_matches"])
            assert sum(int(row[key]) for key in (
                "single_indexed_empty_inserts", "single_indexed_replacements", "single_indexed_rejections",
            )) == indexed_matches, row
            assert int(row["single_indexed_min_cost_rejections"]) <= int(row["single_indexed_rejections"]), row
            assert int(row["single_indexed_short_min_cost_rejections"]) <= int(row["single_indexed_min_cost_rejections"]), row
            indexed_window_stops = int(row["single_window_stops"])
            assert positions == int(row["input_bytes"]), row
            assert indexed_prefix + indexed_matches + indexed_window_stops == indexed_nodes, row
            assert sum(int(value) for value in row["single_indexed_length_histogram"].split(";")) == indexed_matches, row
            assert 0 <= shifted_matches <= indexed_matches, row
            rep0_probes = int(row["single_rep0_probes"])
            rep0_prefix = int(row["single_rep0_prefix_rejections"])
            rep0_matches = int(row["single_rep0_matches"])
            assert sum(int(row[key]) for key in (
                "single_rep0_empty_inserts", "single_rep0_replacements", "single_rep0_rejections",
            )) == rep0_matches, row
            assert int(row["single_rep0_min_cost_rejections"]) <= int(row["single_rep0_rejections"]), row
            assert rep0_prefix + rep0_matches == rep0_probes, row
            assert sum(int(value) for value in row["single_rep0_prefix_mismatch_histogram"].split(";")) == rep0_prefix, row
            assert sum(int(value) for value in row["single_rep0_length_histogram"].split(";")) == rep0_matches, row
        else:
            for key in (
                "single_positions", "single_literal_empty_inserts", "single_literal_replacements", "single_literal_rejections",
                "single_indexed_empty_inserts", "single_indexed_replacements", "single_indexed_rejections",
                "single_indexed_min_cost_rejections", "single_indexed_short_min_cost_rejections",
                "single_rep0_empty_inserts", "single_rep0_replacements", "single_rep0_rejections", "single_rep0_min_cost_rejections",
                "single_indexed_searches", "single_chain_nodes",
                "single_prefix_rejections", "single_matches", "single_shifted_matches", "single_window_stops",
                "single_chain_limit_stops", "single_rep0_probes",
                "single_rep0_prefix_rejections", "single_rep0_matches",
            ):
                assert int(row[key]) == 0, row
            assert row["single_indexed_length_histogram"] == "0;0;0;0;0;0", row
            assert row["single_rep0_prefix_mismatch_histogram"] == "0;0;0;0", row
            assert row["single_rep0_length_histogram"] == "0;0;0;0;0;0", row
        if row["stage"] == "optimal":
            optimal_input = int(row["optimal_input_bytes"])
            optimal_positions = int(row["optimal_positions"])
            optimal_chain_nodes = int(row["optimal_chain_nodes"])
            optimal_prefix_rejections = int(row["optimal_prefix_rejections"])
            optimal_bound_rejections = int(row["optimal_bound_rejections"])
            optimal_match_length_calls = int(row["optimal_match_length_calls"])
            optimal_valid_matches = int(row["optimal_valid_match_candidates"])
            assert optimal_input == int(row["input_bytes"]), row
            assert optimal_positions == optimal_input, row
            assert int(row["optimal_index_bytes"]) > 0, row
            assert optimal_chain_nodes == optimal_prefix_rejections + optimal_bound_rejections + optimal_match_length_calls, row
            assert sum(int(value) for value in row["optimal_prefix_mismatch_histogram"].split(";")) == optimal_prefix_rejections, row
            assert sum(int(value) for value in row["optimal_bound_length_histogram"].split(";")) == optimal_bound_rejections, row
            assert sum(int(value) for value in row["optimal_bound_distance_cost_histogram"].split(";")) == optimal_bound_rejections, row
            assert sum(int(value) for value in row["optimal_bound_slack_histogram"].split(";")) == optimal_bound_rejections, row
            assert optimal_valid_matches <= optimal_match_length_calls, row
            assert sum(int(value) for value in row["optimal_length_extension_histogram"].split(";")) == optimal_valid_matches, row
            assert int(row["optimal_length_choices_built"]) >= optimal_valid_matches, row
            assert int(row["optimal_candidate_budget_stops"]) <= optimal_bound_rejections + optimal_valid_matches, row
            inner_ns = sum(int(row[key]) for key in (
                "optimal_index_ns", "optimal_search_ns", "optimal_reconstruct_ns",
            ))
            assert 0 < inner_ns <= int(row["optimal_total_ns"]), row
        else:
            for key in (
                "optimal_input_bytes", "optimal_index_bytes", "optimal_positions", "optimal_chain_nodes",
                "optimal_prefix_rejections", "optimal_bound_rejections", "optimal_match_length_calls",
                "optimal_valid_match_candidates", "optimal_length_choices_built", "optimal_candidate_budget_stops",
                "optimal_index_ns", "optimal_search_ns", "optimal_reconstruct_ns", "optimal_total_ns",
            ):
                assert int(row[key]) == 0, row
            assert row["optimal_prefix_mismatch_histogram"] == "0;0;0;0", row
            assert row["optimal_bound_length_histogram"] == "0;0;0;0;0;0", row
            assert row["optimal_bound_distance_cost_histogram"] == "0;0;0;0;0;0;0;0;0;0;0;0;0;0;0", row
            assert row["optimal_bound_slack_histogram"] == "0;0;0;0;0;0;0;0;0", row
            assert row["optimal_length_extension_histogram"] == "0;0;0;0;0;0;0;0;0", row

    shifted_by_shape = {
        (row["case"], row["candidate"]): int(row["single_shifted_matches"])
        for row in rows
        if row["stage"] == "rep_beam_single"
    }
    assert shifted_by_shape[("json", "primary")] > 0, shifted_by_shape
    assert shifted_by_shape[("binary", "primary")] > 0, shifted_by_shape

    # The current level-9 policy is the subject of this benchmark. Pinning its
    # candidate labels to 128 KiB/4 KiB/8 KiB makes policy drift visible instead
    # of producing apparently comparable stage measurements.
    sizes = {(row["candidate"], int(row["block_size"])) for row in rows}
    assert sizes == {("primary", 128 * 1024), ("adaptive_0", 4 * 1024), ("adaptive_1", 8 * 1024)}, sizes
    for case in CASES | {WIDE_SEQUENCE_CASE}:
        assert len({row["input_sha256"] for row in rows if row["case"] == case}) == 1, case
    print(f"zstd_native_encode_stage_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
