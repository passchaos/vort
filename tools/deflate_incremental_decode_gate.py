#!/usr/bin/env python3
"""Validate reusable incremental gzip decode benchmark coverage and bounds."""

from __future__ import annotations

import argparse
import csv
import math
import pathlib
import sys

sys.dont_write_bytecode = True


CASES = {"http-4k", "json-32k", "text-64k", "binary-64k"}
CHUNKING = {"full", "fragmented-7x31"}
EXPECTED_HEADER = {
    "case",
    "implementation",
    "chunking",
    "input_bytes",
    "output_bytes",
    "input_chunk",
    "output_chunk",
    "iterations",
    "elapsed_ns",
    "ns_per_decode",
    "throughput_mib_s",
    "mix",
    "semantic_blocks_started",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, required=True)
    parser.add_argument(
        "--expect-competitor", choices=("zlib", "zlib-ng"), required=True
    )
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.read_text().splitlines()))
    if not rows or set(rows[0]) != EXPECTED_HEADER:
        raise SystemExit("invalid incremental decode benchmark CSV header")

    expected_prefix = (
        "zlib-ng-" if args.expect_competitor == "zlib-ng" else "zlib-"
    )
    competitors = {
        row["implementation"]
        for row in rows
        if row["implementation"].startswith(expected_prefix)
    }
    if len(competitors) != 1:
        raise SystemExit(f"expected one {args.expect_competitor} implementation")
    competitor = competitors.pop()
    by_key = {
        (row["case"], row["chunking"], row["implementation"]): row
        for row in rows
    }
    expected = {
        (case, chunking, implementation)
        for case in CASES
        for chunking in CHUNKING
        for implementation in ("vort-symbol", "vort-semantic", competitor)
    }
    missing = expected - set(by_key)
    extra = set(by_key) - expected
    if missing or extra or len(rows) != len(expected):
        raise SystemExit(
            f"invalid benchmark coverage: missing={sorted(missing)} extra={sorted(extra)}"
        )

    ratios: dict[str, list[float]] = {chunking: [] for chunking in CHUNKING}
    semantic_text_full_ratio: float | None = None
    for case in CASES:
        for chunking in CHUNKING:
            symbol = by_key[(case, chunking, "vort-symbol")]
            ours = by_key[(case, chunking, "vort-semantic")]
            rival = by_key[(case, chunking, competitor)]
            for field in ("input_bytes", "output_bytes", "iterations", "mix"):
                if ours[field] != rival[field]:
                    raise SystemExit(f"{case}/{chunking}: mismatched {field}")
            for row in (ours, rival):
                if int(row["input_bytes"]) <= 0 or int(row["output_bytes"]) <= 0:
                    raise SystemExit(f"{case}/{chunking}: empty benchmark payload")
                if int(row["iterations"]) <= 0 or int(row["elapsed_ns"]) <= 0:
                    raise SystemExit(f"{case}/{chunking}: invalid timing sample")
                if int(row["ns_per_decode"]) <= 0 or float(row["throughput_mib_s"]) <= 0:
                    raise SystemExit(f"{case}/{chunking}: invalid derived timing")
            if chunking == "fragmented-7x31":
                if int(ours["input_chunk"]) != 7 or int(ours["output_chunk"]) != 31:
                    raise SystemExit(f"{case}: fragmented Vort shape changed")
            if int(symbol["semantic_blocks_started"]) != 0:
                raise SystemExit(f"{case}/{chunking}: symbol baseline entered semantic path")
            semantic_started = int(ours["semantic_blocks_started"])
            if case == "text-64k" and chunking == "full" and semantic_started <= 0:
                raise SystemExit(f"{case}/{chunking}: semantic path was not selected")
            if ours["mix"] != symbol["mix"]:
                raise SystemExit(f"{case}/{chunking}: semantic/symbol output mismatch")
            ours_ns = float(ours["ns_per_decode"])
            rival_ns = float(rival["ns_per_decode"])
            ratio = ours_ns / rival_ns
            if ratio > 4.0:
                raise SystemExit(
                    f"{case}/{chunking}: Vort exceeds 4x {competitor} latency: {ratio:.3f}x"
                )
            ratios[chunking].append(ratio)

            # Whole-input rows are the intended fast-path workload. Require the
            # semantic window to improve the same binary's compact fallback,
            # while fragmented input remains a correctness/fallback exercise.
            if chunking == "full" and case == "text-64k":
                semantic_ratio = ours_ns / float(symbol["ns_per_decode"])
                semantic_text_full_ratio = semantic_ratio
                if semantic_ratio > 0.95:
                    raise SystemExit(
                        f"{case}/{chunking}: semantic path did not beat symbol "
                        f"baseline by 5%: {semantic_ratio:.3f}x"
                    )

    if semantic_text_full_ratio is None:
        raise SystemExit("missing text-64k/full semantic comparison")
    print(
        "incremental gzip decode gate: "
        f"cases={len(CASES)} competitor={competitor} "
        f"full_geomean_latency_ratio={math.prod(ratios['full']) ** (1 / len(CASES)):.3f} "
        f"semantic_text_full_latency_ratio={semantic_text_full_ratio:.3f} "
        "fragmented_geomean_latency_ratio="
        f"{math.prod(ratios['fragmented-7x31']) ** (1 / len(CASES)):.3f}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
