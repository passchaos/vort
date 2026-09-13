#!/usr/bin/env python3
"""Validate level-aware Zstd primary/adaptive scheduling evidence."""
import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
COLUMNS = [
    "level", "input_bytes", "input_sha256", "encoded_bytes", "iterations", "rounds",
    "parallel_ns", "serial_ns", "speedup", "parallel_checksum",
    "serial_checksum",
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
    assert {int(row["level"]) for row in rows} == {1, 2, 3}, rows
    assert len(rows) == 3, rows
    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    assert len(provenance) == 1 and all(next(iter(provenance))), provenance
    assert rows[0]["optimize"] == "ReleaseFast", rows[0]
    assert rows[0]["provenance_version"] == "1", rows[0]
    assert (rows[0]["cpu_affinity"] == "unavailable") == (int(rows[0]["affinity_cpu_count"]) == 0), rows[0]
    assert int(rows[0]["benchmark_threads"]) == 1, rows[0]
    assert rows[0]["codec_thread_policy"] == "internal-auto", rows[0]
    assert len(rows[0]["executable_sha256"]) == 64, rows[0]
    if args.executable is not None:
        assert hashlib.sha256(args.executable.read_bytes()).hexdigest() == rows[0]["executable_sha256"], rows[0]
    assert len({row["input_sha256"] for row in rows}) == 1, rows
    assert len(rows[0]["input_sha256"]) == 64, rows[0]
    for row in rows:
        for key in ("input_bytes", "encoded_bytes", "iterations", "rounds", "parallel_ns", "serial_ns", "parallel_checksum", "serial_checksum"):
            assert int(row[key]) > 0, row
        assert int(row["parallel_checksum"]) == int(row["serial_checksum"]), row
        assert float(row["speedup"]) > 1.01, row
    by_level = {int(row["level"]): row for row in rows}
    assert int(by_level[1]["encoded_bytes"]) == 27_363, by_level
    assert int(by_level[2]["encoded_bytes"]) == 27_363, by_level
    assert int(by_level[3]["encoded_bytes"]) == 27_517, by_level
    print(f"zstd_level_schedule_bench_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
