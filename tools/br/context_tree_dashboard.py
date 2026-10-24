#!/usr/bin/env python3
"""Aggregate Brotli context-tree CSV evidence into JSON and Markdown."""
import argparse
import csv
import json
from pathlib import Path

import context_tree_report_gate as report_gate

BUCKETS = ("1", "2-4", "5-8", "9-16", "17-32", "33-64", "65+")


def tree_bucket(value: int) -> str:
    if value == 1:
        return "1"
    if value <= 4:
        return "2-4"
    if value <= 8:
        return "5-8"
    if value <= 16:
        return "9-16"
    if value <= 32:
        return "17-32"
    if value <= 64:
        return "33-64"
    return "65+"


def aggregate(rows: list[dict[str, str]]) -> dict[str, object]:
    report_gate.validate(rows)
    distribution = {bucket: 0 for bucket in BUCKETS}
    mode_bytes = {"lsb6": 0, "msb6": 0, "utf8": 0, "signed": 0}
    cases = []
    total_input = 0
    total_encoded = 0
    context_models = 0
    for row in rows:
        trees = int(row["literal_context_trees"])
        distribution[tree_bucket(trees)] += 1
        total_input += int(row["input_bytes"])
        total_encoded += int(row["encoded_bytes"])
        context_models += int(row["context_model"])
        for key, column in (
            ("lsb6", "literal_lsb6_bytes"), ("msb6", "literal_msb6_bytes"),
            ("utf8", "literal_utf8_bytes"), ("signed", "literal_signed_bytes"),
        ):
            mode_bytes[key] += int(row[column])
        cases.append({
            "case": row["case"],
            "input_bytes": int(row["input_bytes"]),
            "encoded_bytes": int(row["encoded_bytes"]),
            "size_ratio": float(row["size_ratio"]),
            "literal_block_types": int(row["literal_block_types"]),
            "literal_context_trees": trees,
            "context_model": bool(int(row["context_model"])),
            "mode_bytes": {
                "lsb6": int(row["literal_lsb6_bytes"]),
                "msb6": int(row["literal_msb6_bytes"]),
                "utf8": int(row["literal_utf8_bytes"]),
                "signed": int(row["literal_signed_bytes"]),
            },
        })
    first = rows[0]
    return {
        "schema": "vort.br_context_tree_dashboard",
        "version": 1,
        "row_count": len(rows),
        "required_cases": sorted(report_gate.REQUIRED_CASES),
        "total_input_bytes": total_input,
        "total_encoded_bytes": total_encoded,
        "weighted_size_ratio": total_encoded / total_input,
        "context_model_cases": context_models,
        "tree_distribution": distribution,
        "mode_bytes": mode_bytes,
        "provenance": {key: first[key] for key in report_gate.PROVENANCE_COLUMNS},
        "cases": cases,
    }


def markdown(data: dict[str, object]) -> str:
    lines = [
        "# Vort Brotli context-tree dashboard",
        "",
        f"- Rows: {data['row_count']}",
        f"- Context-model rows: {data['context_model_cases']}",
        f"- Weighted encoded/input ratio: {data['weighted_size_ratio']:.6f}",
        "",
        "## Tree-count distribution",
        "",
        "| Trees | Rows |",
        "|---:|---:|",
    ]
    for bucket in BUCKETS:
        lines.append(f"| {bucket} | {data['tree_distribution'][bucket]} |")
    lines.extend([
        "",
        "## Cases",
        "",
        "| Case | Input | Encoded | Ratio | Literal blocks | Context trees | Context model | LSB6 | MSB6 | UTF8 | Signed |",
        "|---|---:|---:|---:|---:|---:|:---:|---:|---:|---:|---:|",
    ])
    for case in data["cases"]:
        modes = case["mode_bytes"]
        lines.append(
            f"| {case['case']} | {case['input_bytes']} | {case['encoded_bytes']} | "
            f"{case['size_ratio']:.6f} | {case['literal_block_types']} | "
            f"{case['literal_context_trees']} | {'yes' if case['context_model'] else 'no'} | "
            f"{modes['lsb6']} | {modes['msb6']} | {modes['utf8']} | {modes['signed']} |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == report_gate.COLUMNS
        rows = list(reader)
    data = aggregate(rows)
    args.markdown.write_text(markdown(data))
    args.json.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    print(f"br_context_tree_dashboard=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
