#!/usr/bin/env python3
"""Validate dictionary training benchmark coverage and a latency ceiling."""

import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True)
    parser.add_argument("--enforce-throughput", action="store_true")
    args = parser.parse_args()
    with Path(args.csv).open(newline="") as file:
        rows = list(csv.DictReader(file))
    if {row["case"] for row in rows} != {"text", "json", "binary"}:
        raise SystemExit("dictionary training benchmark coverage mismatch")
    expected_checksums = {"text": 1044020, "json": 842200, "binary": 335880}
    for row in rows:
        if int(row["checksum"]) != expected_checksums[row["case"]] or int(row["best_ns"]) <= 0:
            raise SystemExit(f"invalid benchmark row: {row!r}")
        if args.enforce_throughput and int(row["bytes_per_second"]) < 300_000:
            raise SystemExit(f"dictionary training throughput regressed: {row!r}")
    print(f"dictionary_train_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
