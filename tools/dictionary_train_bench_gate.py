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
    expected_rows = {
        (mode, case)
        for mode in ("basic", "validated")
        for case in ("text", "json", "binary")
    }
    if len(rows) != len(expected_rows) or {(row["mode"], row["case"]) for row in rows} != expected_rows:
        raise SystemExit("dictionary training benchmark coverage mismatch")
    expected_checksums = {
        ("basic", "text"): 1044020,
        ("basic", "json"): 838180,
        ("basic", "binary"): 335880,
        ("validated", "text"): 1018100,
        ("validated", "json"): 803940,
        ("validated", "binary"): 1276760,
    }
    for row in rows:
        expected_checksum = expected_checksums[(row["mode"], row["case"])]
        if int(row["checksum"]) != expected_checksum or int(row["best_ns"]) <= 0:
            raise SystemExit(f"invalid benchmark row: {row!r}")
        minimum_throughput = 300_000 if row["mode"] == "basic" else 100_000
        if args.enforce_throughput and int(row["bytes_per_second"]) < minimum_throughput:
            raise SystemExit(f"dictionary training throughput regressed: {row!r}")
    print(f"dictionary_train_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
