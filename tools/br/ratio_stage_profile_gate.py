#!/usr/bin/env python3
"""Validate the bounded Brotli ratio-stage profile CSV."""

import argparse
import csv
import hashlib
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

COLUMNS = [
    "case", "reference_version", "input_bytes", "input_sha256", "encoded_sha256", "iterations",
    "selected_bytes", "lazy_bytes", "optimal_bytes", "stored_bytes",
    "optimal_attempted", "optimal_selected", "lazy_tokens", "lazy_matches", "lazy_commands",
    "optimal_tokens", "optimal_matches", "optimal_commands",
    "optimal_index_bytes", "optimal_positions", "optimal_chain_nodes",
    "optimal_prefix_rejections", "optimal_bound_rejections",
    "optimal_prefix_mismatch_histogram",
    "optimal_bound_length_histogram", "optimal_bound_distance_cost_histogram",
    "optimal_bound_slack_histogram",
    "optimal_match_length_calls", "optimal_valid_match_candidates",
    "optimal_length_choices_built", "optimal_candidate_budget_stops",
    "lazy_plan_ns", "lazy_command_ns", "lazy_wire_ns",
    "optimal_plan_ns", "optimal_index_ns", "optimal_search_ns",
    "optimal_reconstruct_ns", "optimal_command_ns", "optimal_wire_ns",
    "selection_ns", "total_ns", "stage_ns", "unaccounted_ns",
] + PROVENANCE_COLUMNS
CASES = {"source4k": 4 * 1024, "source16k": 16 * 1024, "source32k": 32 * 1024}
TIMINGS = [
    "lazy_plan_ns", "lazy_command_ns", "lazy_wire_ns",
    "optimal_plan_ns", "optimal_command_ns", "optimal_wire_ns",
    "selection_ns",
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
    assert len(rows) == len(CASES) and set(by_case) == set(CASES), sorted(by_case)
    validate_provenance(rows, executable=args.executable, codec_thread_policy="single")
    assert len({row["reference_version"] for row in rows}) == 1, rows
    assert integer(rows[0], "reference_version") > 0, rows[0]
    assert len({row["input_sha256"] for row in rows}) == len(rows), rows
    assert len({row["encoded_sha256"] for row in rows}) == len(rows), rows
    for name, input_bytes in CASES.items():
        row = by_case[name]
        assert integer(row, "input_bytes") == input_bytes, row
        assert len(row["input_sha256"]) == hashlib.sha256().digest_size * 2, row
        assert set(row["input_sha256"]) <= set("0123456789abcdef"), row
        assert len(row["encoded_sha256"]) == hashlib.sha256().digest_size * 2, row
        assert set(row["encoded_sha256"]) <= set("0123456789abcdef"), row
        assert integer(row, "iterations") > 0, row
        for key in (
            "selected_bytes", "lazy_bytes", "optimal_bytes", "stored_bytes",
            "lazy_tokens", "lazy_matches", "lazy_commands",
            "optimal_tokens", "optimal_matches", "optimal_commands",
            "optimal_index_bytes", "optimal_positions", "optimal_chain_nodes",
            "optimal_match_length_calls", "optimal_valid_match_candidates",
            "optimal_length_choices_built", "total_ns", "stage_ns",
        ):
            assert integer(row, key) > 0, (key, row)
        for key in TIMINGS + ["optimal_index_ns", "optimal_search_ns", "optimal_reconstruct_ns", "unaccounted_ns"]:
            assert integer(row, key) >= 0, (key, row)
        assert integer(row, "optimal_attempted") == 1, row
        assert integer(row, "optimal_selected") in (0, 1), row
        assert integer(row, "optimal_positions") == input_bytes, row
        assert integer(row, "selected_bytes") == min(
            integer(row, "lazy_bytes"), integer(row, "optimal_bytes"), integer(row, "stored_bytes")
        ), row
        assert integer(row, "optimal_selected") == (integer(row, "optimal_bytes") < integer(row, "lazy_bytes")), row
        assert integer(row, "stage_ns") == sum(integer(row, key) for key in TIMINGS), row
        assert integer(row, "stage_ns") + integer(row, "unaccounted_ns") == integer(row, "total_ns"), row
        inner_ns = sum(integer(row, key) for key in ("optimal_index_ns", "optimal_search_ns", "optimal_reconstruct_ns"))
        assert inner_ns <= integer(row, "optimal_plan_ns"), row
        chain_nodes = integer(row, "optimal_chain_nodes")
        prefix = integer(row, "optimal_prefix_rejections")
        bound = integer(row, "optimal_bound_rejections")
        matches = integer(row, "optimal_match_length_calls")
        assert prefix + bound + matches == chain_nodes, row
        assert sum(histogram(row, "optimal_prefix_mismatch_histogram", 4)) == prefix, row
        assert sum(histogram(row, "optimal_bound_length_histogram", 6)) == bound, row
        assert sum(histogram(row, "optimal_bound_distance_cost_histogram", 15)) == bound, row
        assert sum(histogram(row, "optimal_bound_slack_histogram", 9)) == bound, row
        assert integer(row, "optimal_valid_match_candidates") == matches, row
        assert integer(row, "optimal_candidate_budget_stops") <= input_bytes, row
    print(f"br_ratio_stage_profile_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
