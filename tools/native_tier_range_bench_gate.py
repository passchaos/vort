#!/usr/bin/env python3
"""Validate native seekability tier range benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {
    "fixture",
    "tier",
    "block_len",
    "input_bytes",
    "stream_bytes",
    "index_entries",
    "range_offset",
    "range_len",
    "iterations",
    "repeat",
    "elapsed_ns",
    "range_mib_s",
    "full_input_mib_s",
    "checksum",
}
EXPECTED_FIXTURES = {"text", "structured", "repetitive"}
EXPECTED_TIERS = {
    "seek_fast": 8 * 1024,
    "balanced": 32 * 1024,
    "ratio": 64 * 1024,
}
MIN_RELEASEFAST_RANGE_MIB_S = {
    "seek_fast": 20.0,
    "balanced": 6.0,
    "ratio": 3.0,
}


def positive_int(row: dict[str, str], key: str) -> int:
    value = int(row.get(key, "0"))
    if value <= 0:
        raise AssertionError(f"expected positive integer {key}, got row={row}")
    return value


def non_negative_int(row: dict[str, str], key: str) -> int:
    value = int(row.get(key, "0"))
    if value < 0:
        raise AssertionError(f"expected non-negative integer {key}, got row={row}")
    return value


def positive_float(row: dict[str, str], key: str) -> float:
    value = float(row.get(key, "0"))
    if value <= 0.0:
        raise AssertionError(f"expected positive float {key}, got row={row}")
    return value


def assert_close(actual: float, expected: float, label: str, tolerance: float = 1e-4) -> None:
    if abs(actual - expected) > tolerance:
        raise AssertionError(f"{label} mismatch: expected {expected}, got {actual}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-native-tier-range-bench.csv"))
    parser.add_argument("--enforce-throughput", action="store_true")
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.open(newline="")))
    if not rows:
        raise AssertionError("native tier range bench CSV has no rows")
    if set(rows[0].keys()) != EXPECTED_COLUMNS:
        raise AssertionError(f"bad CSV header: {list(rows[0].keys())!r}")

    seen = {(row["fixture"], row["tier"]) for row in rows}
    expected = {(fixture, tier) for fixture in EXPECTED_FIXTURES for tier in EXPECTED_TIERS}
    if seen != expected or len(rows) != len(expected):
        raise AssertionError(f"bad fixture/tier matrix: seen={sorted(seen)!r}")

    for row in rows:
        fixture = row["fixture"]
        tier = row["tier"]
        if fixture not in EXPECTED_FIXTURES or tier not in EXPECTED_TIERS:
            raise AssertionError(f"unexpected row identity: {row}")
        block_len = positive_int(row, "block_len")
        if block_len != EXPECTED_TIERS[tier]:
            raise AssertionError(f"tier {tier} block_len={block_len}, expected {EXPECTED_TIERS[tier]}")
        input_bytes = positive_int(row, "input_bytes")
        stream_bytes = positive_int(row, "stream_bytes")
        index_entries = positive_int(row, "index_entries")
        range_offset = non_negative_int(row, "range_offset")
        range_len = positive_int(row, "range_len")
        iterations = positive_int(row, "iterations")
        repeat = positive_int(row, "repeat")
        elapsed_ns = positive_int(row, "elapsed_ns")
        range_mib_s = positive_float(row, "range_mib_s")
        full_input_mib_s = positive_float(row, "full_input_mib_s")
        positive_int(row, "checksum")
        if stream_bytes <= 8:
            raise AssertionError(f"stream too small: {row}")
        if index_entries < (input_bytes + block_len - 1) // block_len:
            raise AssertionError(f"index entries below expected block count: {row}")
        if range_offset + range_len > input_bytes:
            raise AssertionError(f"range exceeds input: {row}")
        expected_range = ((range_len * iterations) / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
        expected_full = ((input_bytes * iterations) / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
        assert_close(range_mib_s, expected_range, f"{fixture}/{tier} range_mib_s")
        assert_close(full_input_mib_s, expected_full, f"{fixture}/{tier} full_input_mib_s")
        if args.enforce_throughput and range_mib_s < MIN_RELEASEFAST_RANGE_MIB_S[tier]:
            raise AssertionError(f"range throughput below ReleaseFast floor for {tier}: {range_mib_s}")
        if repeat < 1:
            raise AssertionError(f"repeat must be positive: {row}")

    print(f"native_tier_range_bench_gate=ok rows={len(rows)} enforce={args.enforce_throughput}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
