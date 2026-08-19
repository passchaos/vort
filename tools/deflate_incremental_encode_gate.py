#!/usr/bin/env python3
"""Validate multi-corpus incremental DEFLATE benchmark evidence."""

from __future__ import annotations

import argparse
import csv
import pathlib
import sys

CASES = {"json-log", "source", "repetitive", "binary", "cross-window"}
MODES = {"persistent-lazy", "rebuild-lazy"}
COMPRESSIBLE = {"json-log", "source", "repetitive"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, required=True)
    parser.add_argument("--expect-competitor", choices=("zlib", "zlib-ng"), required=True)
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.read_text().splitlines()))
    expected_header = {"case", "mode", "input_bytes", "output_bytes", "iterations", "elapsed_s", "throughput_mib_s", "mix"}
    if not rows or set(rows[0]) != expected_header:
        raise SystemExit("invalid incremental benchmark CSV header")
    competitor_modes = {row["mode"] for row in rows if row["mode"].startswith("zlib")}
    expected_prefix = "zlib-ng-" if args.expect_competitor == "zlib-ng" else "zlib-"
    competitor = next((mode for mode in competitor_modes if mode.startswith(expected_prefix)), None)
    if competitor is None:
        raise SystemExit(f"missing expected {args.expect_competitor} competitor row")

    by_key = {(row["case"], row["mode"]): row for row in rows}
    expected = {(case, mode) for case in CASES for mode in MODES | {competitor}}
    missing = expected - set(by_key)
    if missing:
        raise SystemExit(f"missing benchmark coverage: {sorted(missing)}")

    persistent_over_rebuild = []
    for case in CASES:
        persistent = by_key[(case, "persistent-lazy")]
        rebuild = by_key[(case, "rebuild-lazy")]
        rival = by_key[(case, competitor)]
        persistent_speed = float(persistent["throughput_mib_s"])
        rebuild_speed = float(rebuild["throughput_mib_s"])
        persistent_size = int(persistent["output_bytes"])
        rebuild_size = int(rebuild["output_bytes"])
        if persistent_size > rebuild_size * 1.01:
            raise SystemExit(f"{case}: persistent size regressed >1% against rebuild")
        if case in COMPRESSIBLE and persistent_size > int(rival["output_bytes"]) * 3:
            raise SystemExit(f"{case}: persistent size exceeds 3x {competitor}")
        if case == "binary" and persistent_speed <= float(rival["throughput_mib_s"]):
            raise SystemExit(f"binary: persistent throughput does not beat {competitor}")
        if case != "binary":
            persistent_over_rebuild.append(persistent_speed / rebuild_speed)

    geometric = product(persistent_over_rebuild) ** (1.0 / len(persistent_over_rebuild))
    if geometric < 1.0:
        raise SystemExit(f"persistent geometric throughput regressed against rebuild: {geometric:.3f}")

    print(
        "incremental deflate gate: "
        f"cases={len(CASES)} competitor={competitor} "
        f"nonbinary_geomean_over_rebuild={geometric:.3f}"
    )
    return 0


def product(values: list[float]) -> float:
    result = 1.0
    for value in values:
        result *= value
    return result


if __name__ == "__main__":
    sys.exit(main())
