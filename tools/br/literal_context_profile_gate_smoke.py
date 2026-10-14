#!/usr/bin/env python3
"""Negative smoke tests for the literal-context profile gate."""

import argparse
import csv
import subprocess
import sys
import tempfile
from pathlib import Path


def run_gate(gate: Path, csv_path: Path) -> bool:
    result = subprocess.run(
        [sys.executable, str(gate), "--csv", str(csv_path)],
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

    with tempfile.TemporaryDirectory(prefix="vort-br-literal-context-profile-") as directory:
        root = Path(directory)
        for index, mutation in enumerate(mutations):
            path = root / f"invalid-{index}.csv"
            write_rows(path, fieldnames, mutation)
            if run_gate(args.gate, path):
                raise AssertionError(f"invalid fixture accepted: {index}")
    print(f"br_literal_context_profile_gate_smoke=ok cases={len(mutations)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
