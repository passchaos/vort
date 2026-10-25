#!/usr/bin/env python3
"""Exercise all scoring ranges, historical ratios and malformed profiles."""

import argparse
import csv
import subprocess
import sys
import tempfile
from pathlib import Path


def run_gate(gate: Path, csv_path: Path, *, historical: bool = False) -> bool:
    command = [sys.executable, str(gate), "--csv", str(csv_path)]
    if historical:
        command.append("--require-historical-dominance")
    result = subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def write_rows(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def timing_fixture(rows: list[dict[str, str]], *, historical: bool = False) -> list[dict[str, str]]:
    # Preserve the input, counters and provenance from the producer's fixture.
    # Only replace source32k's times with consistent synthetic nested ranges.
    changed = [row.copy() for row in rows]
    row = next(row for row in changed if row["case"] == "source32k")
    times = {
        "analysis_ns": 10, "baseline_ns": 40, "suffix_ns": 40, "sparse_ns": 10,
        "cluster_init_ns": 20, "cluster_prepare_ns": 20,
        "cluster_assignment_ns": 20, "cluster_finalize_ns": 20, "cluster_score_ns": 20,
        "tree_alphabet_ns": 20, "tree_lengths_ns": 20, "tree_weighted_ns": 20, "tree_prefix_ns": 20,
        "small_huffman_leaf_order_ns": 1, "small_huffman_merge_ns": 1,
        "small_huffman_depth_ns": 1, "small_huffman_output_ns": 1,
        "complex_prefix_rle_ns": 1, "complex_prefix_code_length_tree_ns": 1,
        "complex_prefix_header_ns": 1, "complex_prefix_encoder_ns": 0, "complex_prefix_payload_ns": 1,
        "complex_prefix_shape_ns": 1, "unattributed_ns": 20, "cluster_unattributed_ns": 0,
    }
    if historical:
        times.update(
            cluster_init_ns=5, cluster_prepare_ns=5, cluster_assignment_ns=5,
            cluster_finalize_ns=5, cluster_score_ns=120,
            tree_alphabet_ns=30, tree_lengths_ns=30, tree_weighted_ns=1, tree_prefix_ns=30,
            complex_prefix_rle_ns=10, complex_prefix_code_length_tree_ns=2,
            complex_prefix_header_ns=2, complex_prefix_payload_ns=2,
        )
    times["cluster_stage_ns"] = sum(times[key] for key in (
        "cluster_init_ns", "cluster_prepare_ns", "cluster_assignment_ns",
        "cluster_finalize_ns", "cluster_score_ns",
    ))
    times["cluster_ns"] = times["cluster_stage_ns"]
    times["stage_ns"] = sum(times[key] for key in (
        "analysis_ns", "baseline_ns", "suffix_ns", "sparse_ns", "cluster_ns",
    ))
    times["total_ns"] = times["stage_ns"] + times["unattributed_ns"]
    times["tree_score_stage_ns"] = sum(times[key] for key in (
        "tree_alphabet_ns", "tree_lengths_ns", "tree_weighted_ns", "tree_prefix_ns",
    ))
    times["small_huffman_stage_ns"] = 4
    times["complex_prefix_stage_ns"] = sum(times[key] for key in (
        "complex_prefix_rle_ns", "complex_prefix_code_length_tree_ns",
        "complex_prefix_header_ns", "complex_prefix_encoder_ns", "complex_prefix_payload_ns",
    ))
    row.update({key: str(value) for key, value in times.items()})
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--gate", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        fieldnames = reader.fieldnames
        rows = list(reader)
    if fieldnames is None or not run_gate(args.gate, args.csv):
        raise AssertionError("valid fixture rejected")

    mutations = []
    mutations.append(rows[:-1])
    for field, value in (
        ("cluster_trials", "1"),
        ("stage_ns", "1"),
        ("full_mode", "9"),
        ("cluster_score_ns", "1"),
        ("tree_prefix_ns", "1"),
        ("tree_score_calls", "1"),
        ("tree_score_uncached_calls", "-1"),
        ("tree_active_buckets", "1;2"),
        ("small_huffman_calls", "1"),
        ("complex_prefix_calls", "1"),
        ("complex_prefix_rle_ns", "1"),
        ("complex_prefix_repeat_chain_buckets", "1;2;3;4"),
        ("optimize", "Debug"),
    ):
        changed = [row.copy() for row in rows]
        changed[-1][field] = value
        mutations.append(changed)

    all_scores = timing_fixture(rows)
    source32 = next(row for row in all_scores if row["case"] == "source32k")
    assert int(source32["tree_score_stage_ns"]) > int(source32["cluster_score_ns"])
    assert int(source32["tree_score_uncached_calls"]) > 0
    historical = timing_fixture(rows, historical=True)
    # Keep all sum equations valid so the parent-range and negative-remainder
    # cases exercise containment, rather than merely rejecting a changed sum.
    changed = [row.copy() for row in all_scores]
    row = next(row for row in changed if row["case"] == "source32k")
    row.update(tree_alphabet_ns="41", tree_score_stage_ns="101")
    mutations.append(changed)
    changed = [row.copy() for row in all_scores]
    row = next(row for row in changed if row["case"] == "source32k")
    row.update(unattributed_ns="-1", total_ns=str(int(row["stage_ns"]) - 1))
    mutations.append(changed)
    changed = [row.copy() for row in all_scores]
    row = next(row for row in changed if row["case"] == "source32k")
    row.update(
        cluster_unattributed_ns="-1", cluster_ns=str(int(row["cluster_stage_ns"]) - 1),
        stage_ns=str(int(row["stage_ns"]) - 1), total_ns=str(int(row["total_ns"]) - 1),
    )
    mutations.append(changed)

    changed = [row.copy() for row in all_scores]
    row = next(row for row in changed if row["case"] == "source32k")
    row["tree_score_uncached_calls"] = str(int(row["tree_score_uncached_calls"]) + 1)
    mutations.append(changed)
    # Move a real uncached call into cache misses, keeping the global scorer
    # total, its histograms and miss=cold+conflict intact. The default-path
    # baseline/suffix count must still reject this false cache attribution.
    changed = [row.copy() for row in all_scores]
    row = next(row for row in changed if row["case"] == "source32k")
    row["tree_score_uncached_calls"] = str(int(row["tree_score_uncached_calls"]) - 1)
    row["tree_score_cache_misses"] = str(int(row["tree_score_cache_misses"]) + 1)
    row["tree_score_cache_cold_misses"] = str(int(row["tree_score_cache_cold_misses"]) + 1)
    mutations.append(changed)

    with tempfile.TemporaryDirectory(prefix="vort-br-literal-context-profile-") as directory:
        root = Path(directory)
        for name, fixture in (("all-scores", all_scores), ("historical", historical)):
            path = root / f"valid-{name}.csv"
            write_rows(path, fieldnames, fixture)
            if not run_gate(args.gate, path):
                raise AssertionError(f"valid timing fixture rejected: {name}")
        historical_path = root / "valid-historical.csv"
        if not run_gate(args.gate, historical_path, historical=True):
            raise AssertionError("valid historical ratios rejected")
        if run_gate(args.gate, root / "valid-all-scores.csv", historical=True):
            raise AssertionError("changed dominance accepted by historical lock")
        missing_column = root / "invalid-missing-uncached.csv"
        missing_fields = [field for field in fieldnames if field != "tree_score_uncached_calls"]
        missing_rows = [{key: value for key, value in row.items() if key in missing_fields} for row in rows]
        write_rows(missing_column, missing_fields, missing_rows)
        if run_gate(args.gate, missing_column):
            raise AssertionError("missing uncached column accepted")
        for index, mutation in enumerate(mutations):
            path = root / f"invalid-{index}.csv"
            write_rows(path, fieldnames, mutation)
            if run_gate(args.gate, path):
                raise AssertionError(f"invalid fixture accepted: {index}")
    print(f"br_literal_context_profile_gate_smoke=ok cases={len(mutations) + 2} positives=4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
