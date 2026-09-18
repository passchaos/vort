#!/usr/bin/env python3
"""Validate deterministic parallel native Zstd seekable-encode evidence."""
import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = [
    "provenance_version", "optimize", "zig_version", "target_arch",
    "target_os", "target_abi", "target_cpu", "cpu_model",
    "cpu_affinity", "affinity_cpu_count", "benchmark_threads",
    "codec_thread_policy", "executable_sha256", "command",
]
COLUMNS = [
    "workers", "input_bytes", "input_sha256", "frame_size",
    "frame_count", "encoded_bytes", "iterations", "rounds",
    "parallel_ns", "serial_ns", "parallel_mib_s", "serial_mib_s",
    "speedup", "parallel_checksum", "serial_checksum",
] + PROVENANCE_COLUMNS


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)

    assert {int(row["workers"]) for row in rows} == {1, 2, 4, 8}, rows
    assert len(rows) == 4, rows
    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    assert len(provenance) == 1 and all(next(iter(provenance))), provenance
    first = rows[0]
    assert first["optimize"] == "ReleaseFast", first
    assert first["provenance_version"] == "1", first
    assert first["codec_thread_policy"] == "caller-worker-count", first
    assert (first["cpu_affinity"] == "unavailable") == (int(first["affinity_cpu_count"]) == 0), first
    assert len(first["executable_sha256"]) == 64, first
    if args.executable is not None:
        assert hashlib.sha256(args.executable.read_bytes()).hexdigest() == first["executable_sha256"], first

    shared = {
        (row["input_bytes"], row["input_sha256"], row["frame_size"], row["frame_count"], row["encoded_bytes"])
        for row in rows
    }
    assert len(shared) == 1, shared
    assert len(first["input_sha256"]) == 64 and set(first["input_sha256"]) <= set("0123456789abcdef"), first
    assert int(first["frame_count"]) >= 8, first
    assert int(first["encoded_bytes"]) < int(first["input_bytes"]), first
    for row in rows:
        for key in ("workers", "input_bytes", "frame_size", "frame_count", "encoded_bytes", "iterations", "rounds", "parallel_ns", "serial_ns", "parallel_checksum", "serial_checksum"):
            assert int(row[key]) > 0, row
        for key in ("parallel_mib_s", "serial_mib_s", "speedup"):
            assert float(row[key]) > 0, row
        assert int(row["parallel_checksum"]) == int(row["serial_checksum"]), row

    best = max(rows, key=lambda row: float(row["speedup"]))
    print(
        "zstd_seekable_parallel_bench_gate=ok "
        f"rows={len(rows)} best_workers={best['workers']} "
        f"best_speedup={float(best['speedup']):.4f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
