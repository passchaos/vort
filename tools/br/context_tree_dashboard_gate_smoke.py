#!/usr/bin/env python3
"""Negative smoke tests for the context-tree dashboard gate."""
import copy

import context_tree_dashboard_gate as gate
import context_tree_report_gate as report_gate
from context_tree_dashboard import BUCKETS


def valid() -> dict[str, object]:
    cases = []
    for name in sorted(report_gate.REQUIRED_CASES):
        context = name in {"dictionary", "source32k"}
        cases.append({
            "case": name, "input_bytes": 100, "encoded_bytes": 50,
            "size_ratio": 0.5, "literal_block_types": 1,
            "literal_context_trees": 11 if name == "dictionary" else (2 if context else 1),
            "context_model": context,
            "mode_bytes": {"lsb6": 0, "msb6": 0, "utf8": 10 if context else 0, "signed": 0},
        })
    distribution = {bucket: 0 for bucket in BUCKETS}
    distribution["1"] = 4
    distribution["2-4"] = 1
    distribution["9-16"] = 1
    provenance = {column: "x" for column in report_gate.PROVENANCE_COLUMNS}
    provenance["optimize"] = "ReleaseFast"
    return {
        "schema": "vort.br_context_tree_dashboard", "version": 1,
        "row_count": 6, "required_cases": sorted(report_gate.REQUIRED_CASES),
        "total_input_bytes": 600, "total_encoded_bytes": 300,
        "weighted_size_ratio": 0.5, "context_model_cases": 2,
        "tree_distribution": distribution,
        "mode_bytes": {"lsb6": 0, "msb6": 0, "utf8": 20, "signed": 0},
        "provenance": provenance, "cases": cases,
    }


markdown = "# Vort Brotli context-tree dashboard\n## Tree-count distribution\n| dictionary |\n"
gate.validate(valid(), markdown)

for mutate in (
    lambda data: data.__setitem__("schema", "bad"),
    lambda data: data.__setitem__("row_count", 5),
    lambda data: data["tree_distribution"].__setitem__("9-16", 0),
    lambda data: data["mode_bytes"].__setitem__("utf8", 0),
    lambda data: next(case for case in data["cases"] if case["case"] == "dictionary").__setitem__("literal_context_trees", 1),
    lambda data: data["provenance"].__setitem__("optimize", "Debug"),
):
    candidate = copy.deepcopy(valid())
    mutate(candidate)
    try:
        gate.validate(candidate, markdown)
    except (AssertionError, KeyError, TypeError, ValueError):
        pass
    else:
        raise AssertionError("negative dashboard case unexpectedly passed")

print("br_context_tree_dashboard_gate_smoke=ok negative_cases=6")
