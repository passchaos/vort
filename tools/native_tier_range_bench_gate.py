#!/usr/bin/env python3
"""Validate native seekability tier range benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import json
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
DEFAULT_EXPECTED_FIXTURES = {"text", "structured", "repetitive"}
EXPECTED_TIERS = {
    "seek_fast": 8 * 1024,
    "balanced": 32 * 1024,
    "ratio": 64 * 1024,
}
DEFAULT_RELEASEFAST_RANGE_MIB_S = {
    "seek_fast": 20.0,
    "balanced": 6.0,
    "ratio": 3.0,
}
SUMMARY_SOURCES = ("built_in", "project_files", "standard_corpus", "custom")
SOURCE_RELEASEFAST_RANGE_MIB_S = {
    # Built-in fixtures are deterministic and intentionally simple, so they can
    # carry the tightest floors without making corpus-dependent dashboards
    # flaky.  The file/corpus buckets stay conservative enough for noisy local
    # developer machines while still proving that each source is actually timed
    # rather than merely shape-checked.
    "built_in": {"seek_fast": 60.0, "balanced": 16.0, "ratio": 12.0},
    "project_files": {"seek_fast": 40.0, "balanced": 8.0, "ratio": 4.0},
    "standard_corpus": {"seek_fast": 30.0, "balanced": 6.5, "ratio": 3.5},
    "custom": DEFAULT_RELEASEFAST_RANGE_MIB_S,
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


def releasefast_floors(source: str) -> dict[str, float]:
    return SOURCE_RELEASEFAST_RANGE_MIB_S.get(source, DEFAULT_RELEASEFAST_RANGE_MIB_S)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-native-tier-range-bench.csv"))
    parser.add_argument("--enforce-throughput", action="store_true")
    parser.add_argument("--expect-fixtures", help="comma-separated fixture names; defaults to built-in fixtures")
    parser.add_argument("--allow-any-fixtures", action="store_true", help="derive expected fixtures from CSV rows")
    parser.add_argument("--source", choices=SUMMARY_SOURCES, default="custom", help="summary source bucket for dashboard aggregation")
    parser.add_argument("--summary", type=Path)
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.open(newline="")))
    if not rows:
        raise AssertionError("native tier range bench CSV has no rows")
    if set(rows[0].keys()) != EXPECTED_COLUMNS:
        raise AssertionError(f"bad CSV header: {list(rows[0].keys())!r}")

    if args.allow_any_fixtures:
        expected_fixtures = {row["fixture"] for row in rows}
    else:
        expected_fixtures = set(args.expect_fixtures.split(",")) if args.expect_fixtures else DEFAULT_EXPECTED_FIXTURES
    if not expected_fixtures:
        raise AssertionError("expected fixture set must be non-empty")

    seen = {(row["fixture"], row["tier"]) for row in rows}
    expected = {(fixture, tier) for fixture in expected_fixtures for tier in EXPECTED_TIERS}
    if seen != expected or len(rows) != len(expected):
        raise AssertionError(f"bad fixture/tier matrix: seen={sorted(seen)!r}")

    tier_min_range_mib_s = {tier: float("inf") for tier in EXPECTED_TIERS}
    tier_min_full_input_mib_s = {tier: float("inf") for tier in EXPECTED_TIERS}
    tier_total_stream_bytes = {tier: 0 for tier in EXPECTED_TIERS}
    tier_total_index_entries = {tier: 0 for tier in EXPECTED_TIERS}
    range_mib_s_floor_by_tier = releasefast_floors(args.source)

    for row in rows:
        fixture = row["fixture"]
        tier = row["tier"]
        if fixture not in expected_fixtures or tier not in EXPECTED_TIERS:
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
        tier_min_range_mib_s[tier] = min(tier_min_range_mib_s[tier], range_mib_s)
        tier_min_full_input_mib_s[tier] = min(tier_min_full_input_mib_s[tier], full_input_mib_s)
        tier_total_stream_bytes[tier] += stream_bytes
        tier_total_index_entries[tier] += index_entries
        if args.enforce_throughput and range_mib_s < range_mib_s_floor_by_tier[tier]:
            raise AssertionError(
                f"range throughput below ReleaseFast floor for {args.source}/{tier}: "
                f"{range_mib_s} < {range_mib_s_floor_by_tier[tier]}"
            )
        if repeat < 1:
            raise AssertionError(f"repeat must be positive: {row}")

    ordered_tiers = ["seek_fast", "balanced", "ratio"]
    summary = {
        "schema": "vort.native_tier_range_bench_gate",
        "schema_version": 1,
        "source": args.source,
        "ok": True,
        "rows": len(rows),
        "fixture_count": len(expected_fixtures),
        "tier_count": len(EXPECTED_TIERS),
        "fixtures": sorted(expected_fixtures),
        "tiers": ordered_tiers,
        "enforce_throughput": args.enforce_throughput,
        "allow_any_fixtures": args.allow_any_fixtures,
        "min_range_mib_s_by_tier": {tier: tier_min_range_mib_s[tier] for tier in ordered_tiers},
        "min_full_input_mib_s_by_tier": {tier: tier_min_full_input_mib_s[tier] for tier in ordered_tiers},
        "range_mib_s_floor_by_tier": {tier: range_mib_s_floor_by_tier[tier] for tier in ordered_tiers},
        "total_stream_bytes_by_tier": {tier: tier_total_stream_bytes[tier] for tier in ordered_tiers},
        "total_index_entries_by_tier": {tier: tier_total_index_entries[tier] for tier in ordered_tiers},
        "csv": str(args.csv),
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    print(f"native_tier_range_bench_gate=ok rows={len(rows)} enforce={args.enforce_throughput}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
