#!/usr/bin/env python3
"""Validate dependency-free Snappy benchmark/report CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = [
    "mode",
    "case",
    "input_bytes",
    "encoded_bytes",
    "ratio",
    "iterations",
    "encode_ns",
    "decode_ns",
    "encode_mib_s",
    "decode_mib_s",
    "checksum",
]
EXPECTED_MODES = {"raw_block", "framed"}
EXPECTED_CASES = {"tiny", "text", "structured", "repetitive", "incompressible"}


def positive_int(row: dict[str, str], key: str) -> int:
    value = int(row.get(key, "0"))
    if value <= 0:
        raise AssertionError(f"expected positive integer {key}, got row={row}")
    return value


def nonnegative_float(row: dict[str, str], key: str) -> float:
    value = float(row.get(key, "0"))
    if value < 0.0:
        raise AssertionError(f"expected nonnegative float {key}, got row={row}")
    return value


def positive_float(row: dict[str, str], key: str) -> float:
    value = nonnegative_float(row, key)
    if value <= 0.0:
        raise AssertionError(f"expected positive float {key}, got row={row}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-snappy-report.csv"))
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"snappy_report_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != EXPECTED_COLUMNS:
            raise AssertionError(f"bad CSV header: {reader.fieldnames!r}")
        rows = list(reader)

    expected = {(mode, case) for mode in EXPECTED_MODES for case in EXPECTED_CASES}
    seen: set[tuple[str, str]] = set()
    rows_by_key: dict[tuple[str, str], dict[str, str]] = {}
    expected_iterations: int | None = None

    for row in rows:
        identity = (row["mode"], row["case"])
        if identity in seen:
            raise AssertionError(f"duplicate row: {row}")
        if identity not in expected:
            raise AssertionError(f"unexpected row identity: {row}")
        seen.add(identity)
        rows_by_key[identity] = row

        input_bytes = positive_int(row, "input_bytes")
        encoded_bytes = positive_int(row, "encoded_bytes")
        ratio = positive_float(row, "ratio")
        iterations = positive_int(row, "iterations")
        encode_ns = positive_int(row, "encode_ns")
        decode_ns = positive_int(row, "decode_ns")
        encode_mib_s = positive_float(row, "encode_mib_s")
        decode_mib_s = positive_float(row, "decode_mib_s")
        positive_int(row, "checksum")

        if expected_iterations is None:
            expected_iterations = iterations
        elif iterations != expected_iterations:
            raise AssertionError(f"mixed iteration counts: {iterations} vs {expected_iterations}")

        recomputed_ratio = encoded_bytes / input_bytes
        if abs(ratio - recomputed_ratio) > 0.00001:
            raise AssertionError(f"bad ratio for row={row}, expected {recomputed_ratio}")
        if encode_ns <= 0 or decode_ns <= 0 or encode_mib_s <= 0.0 or decode_mib_s <= 0.0:
            raise AssertionError(f"bad timing row={row}")

    missing = expected - seen
    if missing:
        raise AssertionError(f"missing rows: {sorted(missing)}")

    for mode in EXPECTED_MODES:
        repetitive = rows_by_key[(mode, "repetitive")]
        if float(repetitive["ratio"]) >= 0.35:
            raise AssertionError(f"repetitive {mode} row did not shrink enough: {repetitive}")

    for case in EXPECTED_CASES:
        raw = rows_by_key[("raw_block", case)]
        framed = rows_by_key[("framed", case)]
        if int(framed["encoded_bytes"]) < int(raw["encoded_bytes"]):
            raise AssertionError(f"framed row unexpectedly smaller than raw row: raw={raw} framed={framed}")

    print(f"snappy_report_gate=ok rows={len(rows)} iterations={expected_iterations}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
