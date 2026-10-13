#!/usr/bin/env python3
"""Positive and negative smoke tests for the context-tree report gate."""
import copy
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "context_tree_report_gate", ROOT / "tools/br/context_tree_report_gate.py"
)
gate = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(gate)


def row(name: str, *, trees: int = 1, context_model: int = 0) -> dict[str, str]:
    values = {column: "x" for column in gate.COLUMNS}
    values.update({
        "case": name,
        "input_bytes": "32768",
        "input_sha256": "0" * 64,
        "encoded_bytes": "16384",
        "size_ratio": "0.500000",
        "window_bits": "16",
        "literal_block_types": "1",
        "literal_context_trees": str(trees),
        "context_model": str(context_model),
        "literal_lsb6_bytes": "100" if context_model else "0",
        "literal_msb6_bytes": "0",
        "literal_utf8_bytes": "0",
        "literal_signed_bytes": "0",
        "command_block_types": "1",
        "distance_block_types": "1",
        "distance_context_trees": "1",
        "static_dictionary_copies": "0",
        "lz77_copies": "1",
        "provenance_version": "1",
        "optimize": "ReleaseFast",
        "zig_version": "0.16.0",
        "target_arch": "x86_64",
        "target_os": "linux",
        "target_abi": "gnu",
        "target_cpu": "baseline",
        "cpu_model": "test",
        "cpu_affinity": "2",
        "affinity_cpu_count": "1",
        "benchmark_threads": "1",
        "codec_thread_policy": "single",
        "executable_sha256": "1" * 64,
        "command": "context-tree-report",
    })
    return values


rows = [row(name) for name in sorted(gate.REQUIRED_CASES)]
for index, value in enumerate(rows):
    if value["case"] == "dictionary":
        rows[index] = row("dictionary", trees=8, context_model=1)
        rows[index]["literal_utf8_bytes"] = "100"
        rows[index]["literal_lsb6_bytes"] = "0"
    if value["case"] == "source32k":
        rows[index] = row("source32k", trees=2, context_model=1)
gate.validate(rows)

for mutate in (
    lambda candidate: candidate.pop(),
    lambda candidate: candidate.append(copy.deepcopy(candidate[0])),
    lambda candidate: candidate[0].__setitem__("input_sha256", "bad"),
    lambda candidate: candidate[0].__setitem__("literal_context_trees", "0"),
    lambda candidate: next(row for row in candidate if row["case"] == "dictionary").__setitem__("context_model", "0"),
    lambda candidate: candidate[0].__setitem__("optimize", "Debug"),
):
    candidate = copy.deepcopy(rows)
    mutate(candidate)
    try:
        gate.validate(candidate)
    except (AssertionError, ValueError):
        pass
    else:
        raise AssertionError("negative context-tree gate case unexpectedly passed")

print("br_context_tree_report_gate_smoke=ok negative_cases=6")
