#!/usr/bin/env python3
"""Validate Deflate benchmark schema, inputs, and composite artifacts."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import sys
import zlib
from pathlib import Path

from benchmark_provenance import verify_artifact_manifest
from benchmark_provenance_gate import (
    PROVENANCE_COLUMNS,
    PROVENANCE_V2_COLUMNS,
    validate_provenance,
)
from rust_deflate_benchmark_common import FDEFLATE, MINIZ_OXIDE, ROOT, payloads


COMMON_COLUMNS = [
    "engine", "format", "case", "input_bytes", "input_sha256",
    "frame_bytes",
]
TIMING_COLUMNS = [
    "iterations", "repeat", "elapsed_ns", "elapsed_s", "throughput_mib_s", "mix",
]
DECODE_COLUMNS = COMMON_COLUMNS + TIMING_COLUMNS + PROVENANCE_COLUMNS + PROVENANCE_V2_COLUMNS
ENCODE_COLUMNS = COMMON_COLUMNS + ["ratio"] + TIMING_COLUMNS + PROVENANCE_COLUMNS + PROVENANCE_V2_COLUMNS
DECODE_ENGINES = {
    ("vort", "zlib"),
    ("vort-into", "zlib"),
    ("vort-exact", "zlib"),
    ("vort-raw", "raw"),
    ("vort-raw-into", "raw"),
    ("vort-raw-exact", "raw"),
    ("vort-gzip", "gzip"),
    ("vort-gzip-exact", "gzip"),
    ("vort-gzip-into", "gzip"),
    ("fdeflate", "zlib"),
    ("miniz_oxide", "zlib"),
    ("miniz_oxide-raw", "raw"),
}
ENCODE_ENGINES = {
    *(
        (engine, "zlib")
        for engine in (
            "vort-fastest", "vort-fast", "vort-default", "vort-best",
            "vort-dynamic-default", "vort-dynamic-literal",
            "vort-fixed-fast", "vort-split-default",
            "vort-adaptive-default", "fdeflate", "miniz_oxide",
        )
    ),
    *(
        (engine, "raw")
        for engine in (
            "vort-raw-fastest", "vort-raw-fast", "vort-raw-default",
            "vort-raw-best", "vort-raw-dynamic-default",
            "vort-raw-fixed-fast", "vort-raw-split-default",
            "vort-raw-adaptive-default", "fdeflate-raw",
            "miniz_oxide-raw",
        )
    ),
}


def validate_matrix(rows: list[dict[str, str]], kind: str, repeat: int) -> None:
    expected_payloads = dict(payloads(encode=kind == "encode"))
    expected_engines = ENCODE_ENGINES if kind == "encode" else DECODE_ENGINES
    identities: set[tuple[str, str, str]] = set()
    observed: dict[str, set[tuple[str, str]]] = {}
    for row in rows:
        identity = (row["case"], row["engine"], row["format"])
        if identity in identities:
            raise AssertionError(f"duplicate row: {identity!r}")
        identities.add(identity)
        observed.setdefault(row["case"], set()).add((row["engine"], row["format"]))
        payload = expected_payloads.get(row["case"])
        if payload is None:
            raise AssertionError(f"unexpected case: {row['case']!r}")
        if int(row["input_bytes"]) != len(payload):
            raise AssertionError(f"input size mismatch: {row!r}")
        if row["input_sha256"] != hashlib.sha256(payload).hexdigest():
            raise AssertionError(f"input hash mismatch: {row!r}")
        if int(row["frame_bytes"]) <= 0 or int(row["iterations"]) <= 0:
            raise AssertionError(f"non-positive work: {row!r}")
        if int(row["repeat"]) != repeat:
            raise AssertionError(f"unexpected repeat count: {row!r}")
        elapsed_ns = int(row["elapsed_ns"])
        elapsed_s = float(row["elapsed_s"])
        throughput = float(row["throughput_mib_s"])
        if elapsed_ns <= 0 or elapsed_s <= 0 or throughput <= 0:
            raise AssertionError(f"non-positive timing: {row!r}")
        if abs(elapsed_s - elapsed_ns / 1_000_000_000) > 0.00000051:
            raise AssertionError(f"elapsed time mismatch: {row!r}")
        expected_throughput = (
            int(row["input_bytes"]) * int(row["iterations"])
            / (1024 * 1024)
            / (elapsed_ns / 1_000_000_000)
        )
        if abs(throughput - expected_throughput) > 0.011:
            raise AssertionError(f"throughput mismatch: {row!r}")
        if int(row["mix"]) <= 0:
            raise AssertionError(f"non-positive checksum mix: {row!r}")
        if kind == "encode":
            ratio = float(row["ratio"])
            if ratio <= 0:
                raise AssertionError(f"non-positive ratio: {row!r}")
            expected_ratio = int(row["frame_bytes"]) / max(int(row["input_bytes"]), 1)
            if abs(ratio - expected_ratio) > 0.000051:
                raise AssertionError(f"compression ratio mismatch: {row!r}")
    if set(observed) != set(expected_payloads):
        raise AssertionError(f"bad cases: {sorted(observed)!r}")
    for case, engines in observed.items():
        if engines != expected_engines:
            raise AssertionError(f"bad engines for {case}: {sorted(engines)!r}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--kind", choices=("decode", "encode"), required=True)
    parser.add_argument("--vort-executable", type=Path, required=True)
    parser.add_argument("--repeat", type=int, default=3)
    args = parser.parse_args()

    with args.csv.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, strict=True)
        expected_columns = ENCODE_COLUMNS if args.kind == "encode" else DECODE_COLUMNS
        if reader.fieldnames != expected_columns:
            raise AssertionError(f"bad columns: {reader.fieldnames!r}")
        rows = list(reader)

    provenance = validate_provenance(
        rows, executable=args.vort_executable, codec_thread_policy="single"
    )
    if provenance["provenance_version"] != "2":
        raise AssertionError(f"Deflate benchmark requires provenance v2: {provenance!r}")
    runner_name = f"vort-rust-deflate-{args.kind}-runner"
    runner_package = (
        "vort-rust-deflate-encode-bench"
        if args.kind == "encode"
        else "vort-rust-deflate-bench"
    )
    runner_project = ROOT / ".zig-cache" / runner_name
    runner_executable = runner_project / "target" / "release" / (
        runner_package + (".exe" if os.name == "nt" else "")
    )
    driver = ROOT / "tools" / (
        "rust_deflate_encode_bench.py"
        if args.kind == "encode"
        else "rust_deflate_bench.py"
    )
    manifest = verify_artifact_manifest(
        provenance,
        {
            "python_driver": ("file", driver),
            "python_provenance": ("file", ROOT / "tools" / "benchmark_provenance.py"),
            "python_provenance_gate": ("file", ROOT / "tools" / "benchmark_provenance_gate.py"),
            "python_deflate_common": ("file", ROOT / "tools" / "rust_deflate_benchmark_common.py"),
            "python_interpreter": ("executable", Path(sys.executable).resolve()),
            "vort_benchmark": ("executable", args.vort_executable),
            "rust_runner_source": ("generated-source-tree", runner_project),
            "rust_runner": ("executable", runner_executable),
            "fdeflate_source": ("source-tree", FDEFLATE),
            "miniz_oxide_source": ("source-tree", MINIZ_OXIDE),
        },
        expected_extra_environment=(
            {
                "python_zlib_compile_version": zlib.ZLIB_VERSION,
                "python_zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
            }
            if args.kind == "decode"
            else None
        ),
    )

    validate_matrix(rows, args.kind, args.repeat)

    print(
        f"rust_deflate_bench_gate=ok kind={args.kind} rows={len(rows)} "
        f"artifacts={len(manifest['artifacts'])} repeat={args.repeat}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
