#!/usr/bin/env python3
"""Validate warmed incremental planned Brotli encoder reuse."""

import argparse
import csv
from pathlib import Path

COLUMNS = [
    "case", "input_bytes", "iterations", "one_shot_bytes", "reusable_bytes",
    "one_shot_ns", "reusable_ns",
    "speedup", "one_shot_checksum", "reusable_checksum",
    "retained_bytes",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        assert reader.fieldnames == COLUMNS
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == 2 and set(by_case) == {"single_block", "cross_block"}
    for row in rows:
        for key in COLUMNS[1:]:
            assert float(row[key]) > 0, row
    single = by_case["single_block"]
    assert int(single["reusable_bytes"]) <= int(single["one_shot_bytes"]) + 2, single
    assert float(single["speedup"]) >= 1.10, single
    cross = by_case["cross_block"]
    assert int(cross["input_bytes"]) == 8192, cross
    # Both public surfaces now share the history-aware block core and should
    # emit the same deterministic wire. Compression is checked against the
    # 8 KiB input rather than against the obsolete independent-block baseline.
    assert abs(int(cross["reusable_bytes"]) - int(cross["one_shot_bytes"])) <= 2, cross
    assert int(cross["reusable_bytes"]) * 2 < int(cross["input_bytes"]) + 64, cross
    assert cross["one_shot_checksum"] == cross["reusable_checksum"], cross
    print("br_incremental_planned_bench_gate=ok rows=2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
