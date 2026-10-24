#!/usr/bin/env python3
"""Validate Brotli ratio context-tree coverage and provenance."""
import argparse
import csv
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import PROVENANCE_COLUMNS, validate_provenance

BASE_COLUMNS = [
    "case", "input_bytes", "input_sha256", "encoded_bytes", "size_ratio",
    "window_bits", "literal_block_types", "literal_context_trees",
    "context_model", "literal_lsb6_bytes", "literal_msb6_bytes",
    "literal_utf8_bytes", "literal_signed_bytes", "command_block_types",
    "distance_block_types", "distance_context_trees",
    "static_dictionary_copies", "lz77_copies",
]
COLUMNS = BASE_COLUMNS + PROVENANCE_COLUMNS
REQUIRED_CASES = {
    "context-text", "dictionary", "source32k", "readme32k", "roadmap32k",
    "corpus-small",
}


def validate(rows: list[dict[str, str]], executable: Path | None = None) -> None:
    assert len(rows) >= len(REQUIRED_CASES)
    names = [row["case"] for row in rows]
    assert len(names) == len(set(names)), names
    assert REQUIRED_CASES <= set(names), names
    validate_provenance(rows, executable=executable, codec_thread_policy="single")
    context_models = 0
    high_tree_cases = 0
    for row in rows:
        input_bytes = int(row["input_bytes"])
        encoded_bytes = int(row["encoded_bytes"])
        ratio = float(row["size_ratio"])
        window_bits = int(row["window_bits"])
        literal_blocks = int(row["literal_block_types"])
        literal_trees = int(row["literal_context_trees"])
        context_model = int(row["context_model"])
        mode_bytes = sum(int(row[key]) for key in (
            "literal_lsb6_bytes", "literal_msb6_bytes", "literal_utf8_bytes",
            "literal_signed_bytes",
        ))
        assert input_bytes > 0 and 0 < encoded_bytes <= input_bytes + 4, row
        assert abs(ratio - encoded_bytes / input_bytes) <= 0.000001, row
        assert 10 <= window_bits <= 24, row
        assert 1 <= literal_blocks <= 256 and 1 <= literal_trees <= 256, row
        assert 1 <= int(row["command_block_types"]) <= 256, row
        assert 1 <= int(row["distance_block_types"]) <= 256, row
        assert 1 <= int(row["distance_context_trees"]) <= 256, row
        assert int(row["static_dictionary_copies"]) >= 0, row
        assert int(row["lz77_copies"]) >= 0, row
        assert 0 <= mode_bytes <= input_bytes, row
        assert context_model in (0, 1), row
        assert context_model == int(literal_blocks == 1 and literal_trees > 1), row
        context_models += context_model
        high_tree_cases += int(context_model == 1 and literal_trees >= 8)
    assert context_models >= 1, rows
    assert high_tree_cases >= 1, rows
    source = next(row for row in rows if row["case"] == "source32k")
    assert int(source["input_bytes"]) == 32 * 1024, source
    assert int(source["context_model"]) == 1 and int(source["literal_context_trees"]) >= 2, source
    dictionary = next(row for row in rows if row["case"] == "dictionary")
    assert int(dictionary["context_model"]) == 1, dictionary
    assert int(dictionary["literal_context_trees"]) >= 8, dictionary
    assert int(dictionary["literal_utf8_bytes"]) > 0, dictionary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    validate(rows, args.executable)
    print(f"br_context_tree_report_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
