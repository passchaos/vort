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
        for mode in ("basic", "validated", "validated_separate", "validated_targets", "zstd_validated")
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
        ("validated_separate", "text"): 3191280,
        ("validated_separate", "json"): 2525080,
        ("validated_separate", "binary"): 3808660,
        ("validated_targets", "text"): 3191280,
        ("validated_targets", "json"): 2525080,
        ("validated_targets", "binary"): 3808660,
        ("zstd_validated", "text"): 423100,
        ("zstd_validated", "json"): 486380,
        ("zstd_validated", "binary"): 862560,
    }
    for row in rows:
        expected_checksum = expected_checksums[(row["mode"], row["case"])]
        allocations = int(row["allocations"])
        deallocations = int(row["deallocations"])
        resize_events = int(row["resizes"])
        allocated_bytes = int(row["allocated_bytes"])
        freed_bytes = int(row["freed_bytes"])
        if (
            int(row["checksum"]) != expected_checksum
            or int(row["best_ns"]) <= 0
            or allocations != deallocations
            or allocated_bytes != freed_bytes
            or min(allocations, resize_events, allocated_bytes) < 0
        ):
            raise SystemExit(f"invalid benchmark row: {row!r}")
        if row["mode"] == "zstd_validated" and (
            allocations > 500 or resize_events > 60 or allocated_bytes > 8 * 1024 * 1024
        ):
            raise SystemExit(f"validated Zstd training allocation budget regressed: {row!r}")
        minimum_throughput = {
            "basic": 300_000,
            "validated": 100_000,
            "validated_separate": 15_000,
            "validated_targets": 75_000,
            "zstd_validated": 50_000,
        }[row["mode"]]
        if args.enforce_throughput and int(row["bytes_per_second"]) < minimum_throughput:
            raise SystemExit(f"dictionary training throughput regressed: {row!r}")
    by_key = {(row["mode"], row["case"]): row for row in rows}
    for case in ("text", "json", "binary"):
        separate = int(by_key[("validated_separate", case)]["bytes_per_second"])
        shared = int(by_key[("validated_targets", case)]["bytes_per_second"])
        if shared < separate * 2:
            raise SystemExit(f"multi-target dictionary scan reuse regressed for {case}: {shared}/{separate}")
    print(f"dictionary_train_bench_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
