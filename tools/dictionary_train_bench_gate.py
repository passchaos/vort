#!/usr/bin/env python3
"""Validate dictionary training benchmark coverage and a latency ceiling."""

import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True)
    parser.add_argument("--enforce-throughput", action="store_true")
    parser.add_argument("--cover-only", action="store_true")
    args = parser.parse_args()
    with Path(args.csv).open(newline="") as file:
        rows = list(csv.DictReader(file))
    expected_rows = {
        (mode, case)
        for mode in (
            "basic",
            "validated",
            "validated_separate",
            "validated_targets",
            "cover_optimized_separate",
            "cover_optimized_linear",
            "cover_optimized",
            "zstd_validated",
        )
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
        ("cover_optimized_separate", "text"): 129600,
        ("cover_optimized_separate", "json"): 103500,
        ("cover_optimized_separate", "binary"): 1296880,
        ("cover_optimized_linear", "text"): 129600,
        ("cover_optimized_linear", "json"): 103500,
        ("cover_optimized_linear", "binary"): 1296880,
        ("cover_optimized", "text"): 129600,
        ("cover_optimized", "json"): 103500,
        ("cover_optimized", "binary"): 1296880,
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
            allocations > 420 or resize_events > 45 or allocated_bytes > 2 * 1024 * 1024
        ):
            raise SystemExit(f"validated Zstd training allocation budget regressed: {row!r}")
        minimum_throughput = {
            "basic": 300_000,
            "validated": 100_000,
            "validated_separate": 15_000,
            "validated_targets": 75_000,
            "cover_optimized_separate": 800_000,
            "cover_optimized_linear": 1_000_000,
            "cover_optimized": 1_000_000,
            "zstd_validated": 50_000,
        }[row["mode"]]
        if args.enforce_throughput and int(row["bytes_per_second"]) < minimum_throughput:
            raise SystemExit(f"dictionary training throughput regressed: {row!r}")
    by_key = {(row["mode"], row["case"]): row for row in rows}
    for case in ("text", "json", "binary"):
        separate = int(by_key[("validated_separate", case)]["bytes_per_second"])
        shared = int(by_key[("validated_targets", case)]["bytes_per_second"])
        if shared * 2 < separate * 5:
            raise SystemExit(f"multi-target dictionary scan reuse regressed for {case}: {shared}/{separate}")
        cover_separate = by_key[("cover_optimized_separate", case)]
        cover_shared = by_key[("cover_optimized_linear", case)]
        cover_separate_throughput = int(cover_separate["bytes_per_second"])
        cover_shared_throughput = int(cover_shared["bytes_per_second"])
        if cover_shared_throughput * 10 < cover_separate_throughput * 11:
            raise SystemExit(
                f"COVER context reuse throughput regressed for {case}: "
                f"{cover_shared_throughput}/{cover_separate_throughput}"
            )
        if int(cover_shared["checksum"]) != int(cover_separate["checksum"]):
            raise SystemExit(f"COVER context reuse changed output for {case}")
        if int(cover_shared["allocations"]) >= int(cover_separate["allocations"]):
            raise SystemExit(f"COVER context reuse allocation count regressed for {case}")
        if int(cover_shared["allocated_bytes"]) * 4 > int(cover_separate["allocated_bytes"]) * 3:
            raise SystemExit(f"COVER context reuse allocated bytes regressed for {case}")
        cover_linear = cover_shared
        cover_indexed = by_key[("cover_optimized", case)]
        linear_throughput = int(cover_linear["bytes_per_second"])
        indexed_throughput = int(cover_indexed["bytes_per_second"])
        if indexed_throughput * 100 < linear_throughput * 95:
            raise SystemExit(
                f"COVER indexed validation regressed control throughput for {case}: "
                f"{indexed_throughput}/{linear_throughput}"
            )
        if case == "binary" and indexed_throughput < linear_throughput * 2:
            raise SystemExit(
                f"COVER indexed validation binary speedup regressed: "
                f"{indexed_throughput}/{linear_throughput}"
            )
        if int(cover_linear["checksum"]) != int(cover_indexed["checksum"]):
            raise SystemExit(f"COVER indexed validation changed output for {case}")
    marker = "cover_dictionary_train_bench_gate" if args.cover_only else "dictionary_train_bench_gate"
    print(f"{marker}=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
