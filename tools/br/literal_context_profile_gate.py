#!/usr/bin/env python3
"""Validate the focused Brotli literal-context proposal profile."""

import argparse
import csv
import hashlib
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

COLUMNS = [
    "case", "input_bytes", "input_sha256", "iterations", "literal_count", "active_symbols",
    "suffix_tree_count", "suffix_mode", "suffix_savings_bits",
    "up_to_16_tree_count", "up_to_16_mode", "up_to_16_savings_bits",
    "full_tree_count", "full_mode", "full_savings_bits",
    "suffix_payload_scores", "suffix_payload_reuses", "cluster_trials", "cluster_rounds",
    "assignment_contexts", "assignment_comparisons", "score_cache_hits", "score_cache_misses",
    "tree_score_cache_hits", "tree_score_cache_misses",
    "tree_score_cache_cold_misses", "tree_score_cache_conflict_misses",
    "tree_score_uncached_calls",
    "tree_score_calls", "tree_simple_scores", "tree_complex_scores", "tree_active_entries", "tree_active_buckets",
    "small_huffman_calls", "small_huffman_failures", "package_merge_calls",
    "complex_prefix_calls", "complex_prefix_rle_tokens", "complex_prefix_code_length_active",
    "complex_prefix_input_lengths", "complex_prefix_zero_runs", "complex_prefix_nonzero_runs",
    "complex_prefix_zero_lengths", "complex_prefix_nonzero_lengths", "complex_prefix_literal_tokens",
    "complex_prefix_repeat16_tokens", "complex_prefix_repeat17_tokens", "complex_prefix_repeat_chain_buckets",
    "analysis_ns", "baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns", "cluster_init_ns",
    "cluster_prepare_ns", "cluster_assignment_ns", "cluster_finalize_ns", "cluster_score_ns",
    "tree_alphabet_ns", "tree_lengths_ns", "tree_weighted_ns", "tree_prefix_ns", "tree_score_stage_ns",
    "small_huffman_leaf_order_ns", "small_huffman_merge_ns", "small_huffman_depth_ns",
    "small_huffman_output_ns", "small_huffman_stage_ns",
    "complex_prefix_rle_ns", "complex_prefix_code_length_tree_ns", "complex_prefix_header_ns",
    "complex_prefix_encoder_ns", "complex_prefix_payload_ns", "complex_prefix_stage_ns",
    "complex_prefix_shape_ns",
    "stage_ns", "cluster_stage_ns", "total_ns", "unattributed_ns", "cluster_unattributed_ns",
] + PROVENANCE_COLUMNS
CASES = {"source4k": 4 * 1024, "source16k": 16 * 1024, "source32k": 32 * 1024}
TOP_STAGES = ["analysis_ns", "baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns"]
CLUSTER_STAGES = [
    "cluster_init_ns", "cluster_prepare_ns", "cluster_assignment_ns",
    "cluster_finalize_ns", "cluster_score_ns",
]
TREE_SCORE_STAGES = ["tree_alphabet_ns", "tree_lengths_ns", "tree_weighted_ns", "tree_prefix_ns"]
# Pure scores cover uncached baseline/suffix calls and cached cluster misses.
TREE_SCORE_PARENTS = ["baseline_ns", "suffix_ns", "cluster_score_ns"]
SMALL_HUFFMAN_STAGES = [
    "small_huffman_leaf_order_ns", "small_huffman_merge_ns",
    "small_huffman_depth_ns", "small_huffman_output_ns",
]
COMPLEX_PREFIX_STAGES = [
    "complex_prefix_rle_ns", "complex_prefix_code_length_tree_ns",
    "complex_prefix_header_ns", "complex_prefix_encoder_ns", "complex_prefix_payload_ns",
]


def integer(row: dict[str, str], key: str) -> int:
    try:
        return int(row[key])
    except (KeyError, ValueError) as exc:
        raise AssertionError(f"invalid {key}: {row}") from exc


def histogram(row: dict[str, str], key: str, length: int) -> list[int]:
    values = [int(value) for value in row[key].split(";")]
    assert len(values) == length, (key, row[key])
    assert all(value >= 0 for value in values), (key, row[key])
    return values


def validate_candidate(row: dict[str, str], prefix: str) -> None:
    trees = integer(row, f"{prefix}_tree_count")
    mode = integer(row, f"{prefix}_mode")
    savings = integer(row, f"{prefix}_savings_bits")
    if trees == 0:
        assert mode == 0 and savings == 0, (prefix, row)
    else:
        assert 2 <= trees <= 64, (prefix, row)
        assert 0 <= mode <= 3, (prefix, row)
        assert savings >= 128, (prefix, row)


def validate_historical_dominance(row: dict[str, str]) -> None:
    # These ratios describe the earlier source32k profile, rather than timing
    # conservation. Preserve them for explicit historical comparisons while
    # allowing a correct optimization to change the default profile's hotspot.
    cluster_score = integer(row, "cluster_score_ns")
    assert cluster_score == max(integer(row, key) for key in CLUSTER_STAGES), row
    assert cluster_score * 2 > integer(row, "cluster_ns"), row
    tree_major = [integer(row, key) for key in ("tree_alphabet_ns", "tree_lengths_ns", "tree_prefix_ns")]
    assert min(tree_major) * 5 > max(tree_major) * 4, row
    assert min(tree_major) > integer(row, "tree_weighted_ns") * 8, row
    prefix_rle = integer(row, "complex_prefix_rle_ns")
    assert prefix_rle == max(integer(row, key) for key in COMPLEX_PREFIX_STAGES), row
    assert prefix_rle * 3 > integer(row, "complex_prefix_stage_ns"), row


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    parser.add_argument(
        "--require-historical-dominance", action="store_true",
        help="also require the earlier source32k hotspot ratios",
    )
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == len(CASES) and set(by_case) == set(CASES), sorted(by_case)
    validate_provenance(rows, executable=args.executable, codec_thread_policy="single")
    assert len({row["input_sha256"] for row in rows}) == len(rows), rows

    for name, input_bytes in CASES.items():
        row = by_case[name]
        iterations = integer(row, "iterations")
        assert integer(row, "input_bytes") == input_bytes, row
        assert len(row["input_sha256"]) == hashlib.sha256().digest_size * 2, row
        assert set(row["input_sha256"]) <= set("0123456789abcdef"), row
        assert iterations > 0, row
        assert 128 <= integer(row, "literal_count") <= input_bytes, row
        assert 1 <= integer(row, "active_symbols") <= 256, row
        for prefix in ("suffix", "up_to_16", "full"):
            validate_candidate(row, prefix)
        assert integer(row, "suffix_payload_scores") > 0, row
        assert integer(row, "suffix_payload_reuses") > 0, row
        assert integer(row, "cluster_trials") == 88 * iterations, row
        assert integer(row, "cluster_rounds") >= integer(row, "cluster_trials"), row
        assert integer(row, "assignment_contexts") > 0, row
        assert integer(row, "assignment_comparisons") >= integer(row, "assignment_contexts"), row
        scored = integer(row, "score_cache_hits") + integer(row, "score_cache_misses")
        assert 0 < scored <= integer(row, "cluster_trials"), row
        assert integer(row, "score_cache_misses") > 0, row
        tree_scored = integer(row, "tree_score_cache_hits") + integer(row, "tree_score_cache_misses")
        assert tree_scored > 0, row
        assert integer(row, "tree_score_cache_misses") > 0, row
        assert integer(row, "tree_score_cache_misses") == (
            integer(row, "tree_score_cache_cold_misses") +
            integer(row, "tree_score_cache_conflict_misses")
        ), row
        uncached_calls = integer(row, "tree_score_uncached_calls")
        assert uncached_calls >= 0, row
        # These focused rows require valid Analysis above, so every iteration
        # scores one global baseline and two nonempty trees per suffix payload.
        # Only cluster scores use the memo; generic early-return profiles do
        # not satisfy this baseline-per-iteration relation.
        assert uncached_calls == iterations + 2 * integer(row, "suffix_payload_scores"), row
        assert integer(row, "tree_score_calls") == integer(row, "tree_score_cache_misses") + uncached_calls, row
        assert integer(row, "tree_simple_scores") + integer(row, "tree_complex_scores") == integer(row, "tree_score_calls"), row
        assert integer(row, "tree_active_entries") >= integer(row, "tree_score_calls"), row
        active_buckets = histogram(row, "tree_active_buckets", 6)
        assert sum(active_buckets) == integer(row, "tree_score_calls"), row
        minimum_entries = sum(count * minimum for count, minimum in zip(active_buckets, (1, 5, 17, 33, 65, 129)))
        maximum_entries = sum(count * maximum for count, maximum in zip(active_buckets, (4, 16, 32, 64, 128, 256)))
        assert minimum_entries <= integer(row, "tree_active_entries") <= maximum_entries, row
        assert integer(row, "small_huffman_calls") == sum(active_buckets[1:5]), row
        assert integer(row, "package_merge_calls") == active_buckets[5] + integer(row, "small_huffman_failures"), row
        assert integer(row, "complex_prefix_calls") == integer(row, "tree_complex_scores"), row
        assert integer(row, "complex_prefix_rle_tokens") >= integer(row, "complex_prefix_calls"), row
        assert integer(row, "complex_prefix_calls") <= integer(row, "complex_prefix_code_length_active") <= 18 * integer(row, "complex_prefix_calls"), row
        assert integer(row, "complex_prefix_input_lengths") == integer(row, "complex_prefix_zero_lengths") + integer(row, "complex_prefix_nonzero_lengths"), row
        assert 0 < integer(row, "complex_prefix_zero_runs") <= integer(row, "complex_prefix_zero_lengths"), row
        assert 0 < integer(row, "complex_prefix_nonzero_runs") <= integer(row, "complex_prefix_nonzero_lengths"), row
        repeat_tokens = integer(row, "complex_prefix_repeat16_tokens") + integer(row, "complex_prefix_repeat17_tokens")
        assert integer(row, "complex_prefix_rle_tokens") == integer(row, "complex_prefix_literal_tokens") + repeat_tokens, row
        chain_buckets = histogram(row, "complex_prefix_repeat_chain_buckets", 4)
        assert chain_buckets[3] == 0, row
        assert chain_buckets[0] + 2 * chain_buckets[1] + 3 * chain_buckets[2] == repeat_tokens, row
        positive_prefix_stages = [key for key in COMPLEX_PREFIX_STAGES if key != "complex_prefix_encoder_ns"]
        for key in TOP_STAGES + CLUSTER_STAGES + TREE_SCORE_STAGES + SMALL_HUFFMAN_STAGES + positive_prefix_stages + ["stage_ns", "cluster_stage_ns", "tree_score_stage_ns", "small_huffman_stage_ns", "complex_prefix_stage_ns", "total_ns"]:
            assert integer(row, key) > 0, (key, row)
        assert integer(row, "complex_prefix_encoder_ns") == 0, row
        assert integer(row, "stage_ns") == sum(integer(row, key) for key in TOP_STAGES), row
        assert integer(row, "cluster_stage_ns") == sum(integer(row, key) for key in CLUSTER_STAGES), row
        assert integer(row, "tree_score_stage_ns") == sum(integer(row, key) for key in TREE_SCORE_STAGES), row
        assert integer(row, "tree_score_stage_ns") <= sum(integer(row, key) for key in TREE_SCORE_PARENTS), row
        assert integer(row, "small_huffman_stage_ns") == sum(integer(row, key) for key in SMALL_HUFFMAN_STAGES), row
        assert integer(row, "small_huffman_stage_ns") <= integer(row, "tree_lengths_ns"), row
        assert integer(row, "complex_prefix_stage_ns") == sum(integer(row, key) for key in COMPLEX_PREFIX_STAGES), row
        assert integer(row, "complex_prefix_stage_ns") <= integer(row, "tree_prefix_ns"), row
        assert integer(row, "complex_prefix_shape_ns") > 0, row
        assert integer(row, "unattributed_ns") >= 0, row
        assert integer(row, "cluster_unattributed_ns") >= 0, row
        assert integer(row, "stage_ns") + integer(row, "unattributed_ns") == integer(row, "total_ns"), row
        assert integer(row, "cluster_stage_ns") + integer(row, "cluster_unattributed_ns") == integer(row, "cluster_ns"), row

    source32 = by_case["source32k"]
    assert integer(source32, "suffix_tree_count") >= 2, source32
    assert integer(source32, "full_tree_count") >= integer(source32, "suffix_tree_count"), source32
    assert integer(source32, "tree_score_cache_hits") > 0, source32
    if args.require_historical_dominance:
        validate_historical_dominance(source32)
    dominant = "/".join(
        max(stages, key=lambda key: integer(source32, key))
        for stages in (CLUSTER_STAGES, TREE_SCORE_STAGES, COMPLEX_PREFIX_STAGES)
    )
    print(f"br_literal_context_profile_gate=ok rows=3 dominant={dominant}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
