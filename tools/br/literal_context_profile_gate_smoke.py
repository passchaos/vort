#!/usr/bin/env python3
"""Exercise all scoring ranges, historical ratios and malformed profiles."""

import argparse
import csv
import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True


def load_gate(path: Path):
    spec = importlib.util.spec_from_file_location("literal_context_profile_gate_target", path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"gate cannot be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def accounting_fixture(misses: int, map_only: int, partial: int, calls: int, *, checks: int | None = None) -> dict[str, str]:
    return {
        "score_cache_misses": str(misses),
        "cluster_lb_checks": str(misses if checks is None else checks),
        "cluster_maps_pruned": str(map_only),
        "cluster_tree_scores_pruned": str(partial),
        "tree_score_cache_hits": str(max(calls - 1, 0)),
        "tree_score_cache_misses": str(int(calls != 0)),
    }


def accounting_smoke(gate) -> int:
    for row in (
        accounting_fixture(3, 1, 1, 3),  # One complete map plus one partial map.
        accounting_fixture(1, 0, 1, 1),  # A partial map's single completed call.
        accounting_fixture(1, 0, 0, 2, checks=0),  # Exhaustive reference policy.
    ):
        gate.validate_cluster_tree_accounting(row)
    invalid = (
        accounting_fixture(1, 0, -1, 2),
        accounting_fixture(3, 1, 2, 4, checks=2),  # Two partial maps but one available check.
        accounting_fixture(2, 1, 2, 4),  # Pruned map counts exceed map misses.
        accounting_fixture(2, 0, 0, 4, checks=3),
        accounting_fixture(1, 0, 1, 0),  # Partial pruning before any exact tree call.
        accounting_fixture(1, 0, 0, 1),  # A completed map with only one tree call.
        accounting_fixture(2, 0, 1, 2),  # Calls cannot satisfy both minima separately.
        accounting_fixture(3, 1, 0, 3),  # Missing the partial-map attribution.
    )
    for index, row in enumerate(invalid):
        try:
            gate.validate_cluster_tree_accounting(row)
        except AssertionError:
            continue
        raise AssertionError(f"invalid cluster tree accounting accepted: {index}")
    return len(invalid)


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
    gate = load_gate(args.gate)
    if len(gate.LEGACY_COLUMNS) != 97 or len(gate.COLUMNS) != 98:
        raise AssertionError("unexpected legacy/new CSV widths")
    accounting_negatives = accounting_smoke(gate)
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        fieldnames = reader.fieldnames
        rows = list(reader)
    if fieldnames is None or not run_gate(args.gate, args.csv):
        raise AssertionError("valid fixture rejected")
    rows = [dict(row, cluster_tree_scores_pruned=row.get("cluster_tree_scores_pruned", "0")) for row in rows]
    fieldnames = gate.COLUMNS

    mutations = []
    mutations.append(rows[:-1])
    for field, value in (
        ("cluster_trials", "1"),
        ("cluster_tree_scores_pruned", "-1"),
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

    for field, value in (
        ("cluster_lb_checks", int(source32["score_cache_misses"]) + 1),
        ("cluster_tree_scores_pruned", int(source32["cluster_lb_checks"]) - int(source32["cluster_maps_pruned"]) + 1),
    ):
        changed = [row.copy() for row in all_scores]
        row = next(row for row in changed if row["case"] == "source32k")
        row[field] = str(value)
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
        # Legacy rows describe completed maps. Model the old two-tree minimum
        # by adding one cached request per partial map; exact scorer totals and
        # timing equations stay intact in this synthetic compatibility fixture.
        legacy_rows = []
        for row in all_scores:
            legacy = {field: row[field] for field in gate.LEGACY_COLUMNS}
            legacy["tree_score_cache_hits"] = str(int(legacy["tree_score_cache_hits"]) + int(row["cluster_tree_scores_pruned"]))
            legacy_rows.append(legacy)
        legacy_path = root / "valid-legacy97.csv"
        write_rows(legacy_path, gate.LEGACY_COLUMNS, legacy_rows)
        if not run_gate(args.gate, legacy_path):
            raise AssertionError("valid legacy 97-column profile rejected")
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
    print(f"br_literal_context_profile_gate_smoke=ok cases={len(mutations) + accounting_negatives + 2} positives=5 accounting_negatives={accounting_negatives} widths=97/98")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
