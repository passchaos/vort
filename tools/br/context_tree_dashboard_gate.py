#!/usr/bin/env python3
"""Validate Brotli context-tree dashboard JSON and Markdown."""
import argparse
import json
from pathlib import Path

import context_tree_report_gate as report_gate
from context_tree_dashboard import BUCKETS


def validate(data: dict[str, object], markdown: str) -> None:
    assert data["schema"] == "vort.br_context_tree_dashboard"
    assert data["version"] == 1
    row_count = int(data["row_count"])
    assert row_count >= len(report_gate.REQUIRED_CASES)
    assert set(data["required_cases"]) == report_gate.REQUIRED_CASES
    assert int(data["total_input_bytes"]) > 0
    assert 0 < int(data["total_encoded_bytes"]) <= int(data["total_input_bytes"]) + 4 * row_count
    assert 0 < float(data["weighted_size_ratio"]) <= 1.1
    assert 1 <= int(data["context_model_cases"]) <= row_count
    distribution = data["tree_distribution"]
    assert set(distribution) == set(BUCKETS)
    assert sum(int(distribution[bucket]) for bucket in BUCKETS) == row_count
    assert int(distribution["9-16"]) >= 1
    cases = data["cases"]
    assert len(cases) == row_count
    assert len({case["case"] for case in cases}) == row_count
    assert report_gate.REQUIRED_CASES <= {case["case"] for case in cases}
    dictionary = next(case for case in cases if case["case"] == "dictionary")
    assert dictionary["context_model"] and int(dictionary["literal_context_trees"]) >= 8
    mode_bytes = data["mode_bytes"]
    assert set(mode_bytes) == {"lsb6", "msb6", "utf8", "signed"}
    assert int(mode_bytes["utf8"]) > 0
    provenance = data["provenance"]
    assert set(provenance) == set(report_gate.PROVENANCE_COLUMNS)
    assert provenance["optimize"] == "ReleaseFast"
    assert "# Vort Brotli context-tree dashboard" in markdown
    assert "## Tree-count distribution" in markdown
    assert "| dictionary |" in markdown


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    args = parser.parse_args()
    data = json.loads(args.json.read_text())
    validate(data, args.markdown.read_text())
    print(f"br_context_tree_dashboard_gate=ok rows={data['row_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
