#!/usr/bin/env python3
"""Validate progressive Brotli command/distance benchmark coverage."""

import argparse
import csv
from pathlib import Path


COLUMNS = [
    "case", "input_bytes", "encoded_bytes", "iterations",
    "elapsed_ns", "mib_s", "command_block_types",
    "distance_context_trees", "checksum",
]
CASES = {"structured_q4", "alternating_q5", "distance_q8"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        assert reader.fieldnames == COLUMNS
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == len(CASES) and set(by_case) == CASES
    for row in rows:
        for key in COLUMNS[1:]:
            assert float(row[key]) > 0, row
    assert int(by_case["distance_q8"]["encoded_bytes"]) > 16_384
    assert float(by_case["structured_q4"]["mib_s"]) >= 100.0
    assert float(by_case["alternating_q5"]["mib_s"]) >= 100.0
    assert float(by_case["distance_q8"]["mib_s"]) >= 10.0
    print(f"br_progressive_huffman_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
