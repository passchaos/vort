#!/usr/bin/env python3
"""Validate multi-corpus incremental DEFLATE benchmark evidence."""

from __future__ import annotations

import argparse
import csv
import pathlib
import sys

CASES = {"json-log", "source", "repetitive", "binary", "cross-window"}
MODES = {"persistent-lazy", "rebuild-lazy"}
STAGED_MODES = {"matcher-lazy", "tree-emit", "history-retain", "staged-pipeline", "stage-reset"}
STAGED_CASES = {"json-log", "source"}
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
    missing_stages = {(case, mode) for case in STAGED_CASES for mode in STAGED_MODES} - set(by_key)
    if missing_stages:
        raise SystemExit(f"missing staged benchmark coverage: {sorted(missing_stages)}")

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
        if case == "repetitive" and persistent_size > int(rival["output_bytes"]):
            raise SystemExit(f"repetitive: persistent size does not match/beat {competitor}")
        if case == "binary" and persistent_speed <= float(rival["throughput_mib_s"]):
            raise SystemExit(f"binary: persistent throughput does not beat {competitor}")
        if case != "binary":
            persistent_over_rebuild.append(persistent_speed / rebuild_speed)
        if case in STAGED_CASES:
            staged = by_key[(case, "staged-pipeline")]
            emitted = by_key[(case, "tree-emit")]
            if int(staged["output_bytes"]) != persistent_size or int(emitted["output_bytes"]) != persistent_size:
                raise SystemExit(f"{case}: staged output size differs from production")
            staged_mix = staged["mix"]
            if any(by_key[(case, mode)]["mix"] != staged_mix for mode in STAGED_MODES):
                raise SystemExit(f"{case}: staged token checksums disagree")

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
