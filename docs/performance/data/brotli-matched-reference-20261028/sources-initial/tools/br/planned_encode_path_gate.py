#!/usr/bin/env python3
"""Validate file-backed Brotli encode benchmark evidence."""
import argparse
import csv
import hashlib
import sys
from pathlib import Path

from planned_encode_bench_gate import validate_columns, validate_reference_parameters

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_provenance_gate import validate_provenance


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--limit", type=int, default=128 * 1024)
    args = parser.parse_args()
    if args.limit <= 0:
        raise AssertionError(f"invalid input limit: {args.limit}")
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        validate_columns(reader.fieldnames)
        rows = list(reader)
    validate_provenance(
        rows, executable=args.executable, codec_thread_policy="single"
    )
    assert rows and all(row["case"].startswith("file") for row in rows), rows
    if args.input is not None:
        payload = args.input.read_bytes()[: args.limit]
        assert len(rows) == 1, rows
        assert int(rows[0]["input_bytes"]) == len(payload), rows[0]
        assert rows[0]["input_sha256"] == hashlib.sha256(payload).hexdigest(), rows[0]
    for row in rows:
        validate_reference_parameters(row)
        for key in ("input_bytes", "vort_bytes", "lazy_bytes", "ratio_bytes", "reference_bytes", "iterations", "vort_ns", "lazy_ns", "ratio_ns", "reference_ns", "checksum"):
            assert int(row[key]) > 0, row
        assert int(row["ratio_bytes"]) <= int(row["lazy_bytes"]), row
        # The checked-in fixture is deliberately small and repetitive. It
        # makes path parsing and external decoding deterministic without adding
        # a heavyweight corpus dependency to the default build.
        assert int(row["ratio_bytes"]) <= int(row["reference_bytes"]), row
    print(f"br_planned_encode_path_gate=ok rows={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
