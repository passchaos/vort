#!/usr/bin/env python3
"""Validate checksum benchmark CSV shape and portable/hardware dispatch rows."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "algorithm",
    "bytes",
    "iterations",
    "elapsed_s",
    "throughput_mib_s",
    "mix",
}
EXPECTED_ALGORITHMS = {
    "adler32",
    "crc32-scalar",
    "crc32-slice4",
    "crc32-slice8",
    "crc32-slice16",
    "crc32-slice32",
    "crc32-slice32-seg64",
    "crc32-slice32-seg256",
    "crc32-slice32-seg1024",
    "crc32-slice32-seg4096",
    "crc32-slice32-span-threshold256",
    "crc32-slice32-span-threshold1024",
    "crc32-best",
    "crc32c-scalar",
    "crc32c-slice8",
    "crc32c-slice16",
    "crc32c-slice32",
    "crc32c-best",
}
EXPECTED_BYTES = 1 << 20
EXPECTED_ITERATIONS = 128


def positive_int(row: dict[str, str], key: str) -> bool:
    try:
        return int(row.get(key, "0")) > 0
    except ValueError:
        return False


def positive_float(row: dict[str, str], key: str) -> bool:
    try:
        return float(row.get(key, "0")) > 0.0
    except ValueError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-checksum-bench.csv"))
    args = parser.parse_args()
    if not args.csv.exists():
        print(f"checksum_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            print(f"checksum_bench_gate=bad_header fields={reader.fieldnames}", file=sys.stderr)
            return 1
        rows = list(reader)

    if len(rows) != len(EXPECTED_ALGORITHMS):
        print(f"checksum_bench_gate=bad_row_count rows={len(rows)}", file=sys.stderr)
        return 1

    seen: set[str] = set()
    mixes_by_family: dict[str, set[str]] = {"crc32": set(), "crc32c": set()}
    for row in rows:
        name = row.get("algorithm", "")
        if name in seen:
            print(f"checksum_bench_gate=duplicate row={row}", file=sys.stderr)
            return 1
        seen.add(name)
        if name not in EXPECTED_ALGORITHMS:
            print(f"checksum_bench_gate=unexpected_algorithm row={row}", file=sys.stderr)
            return 1
        if int(row.get("bytes", "0")) != EXPECTED_BYTES or int(row.get("iterations", "0")) != EXPECTED_ITERATIONS:
            print(f"checksum_bench_gate=bad_workload row={row}", file=sys.stderr)
            return 1
        if not all(positive_float(row, field) for field in ("elapsed_s", "throughput_mib_s")):
            print(f"checksum_bench_gate=bad_float row={row}", file=sys.stderr)
            return 1
        if not positive_int(row, "mix"):
            print(f"checksum_bench_gate=bad_mix row={row}", file=sys.stderr)
            return 1
        if name.startswith("crc32-"):
            mixes_by_family["crc32"].add(row["mix"])
        if name.startswith("crc32c-"):
            mixes_by_family["crc32c"].add(row["mix"])

    if seen != EXPECTED_ALGORITHMS:
        print(f"checksum_bench_gate=bad_algorithm_set algorithms={sorted(seen)}", file=sys.stderr)
        return 1
    for family, mixes in mixes_by_family.items():
        # All implementations in a family hash the same perturbed inputs each
        # iteration; equal digest mixes prove benchmark-only fast paths are still
        # producing identical checksums while the unit tests cover exact vectors.
        if len(mixes) != 1:
            print(f"checksum_bench_gate={family}_mix_mismatch mixes={sorted(mixes)}", file=sys.stderr)
            return 1

    print(f"checksum_bench_gate=ok algorithms={len(seen)} bytes={EXPECTED_BYTES} iterations={EXPECTED_ITERATIONS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
