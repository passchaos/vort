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


def validate_rows(rows, *, require_ratio_no_worse_than_reference=False):
    assert rows and all(row["case"].startswith("file") for row in rows), rows
    for row in rows:
        validate_reference_parameters(row)
        for key in ("input_bytes", "vort_bytes", "lazy_bytes", "ratio_bytes", "reference_bytes", "iterations", "vort_ns", "lazy_ns", "ratio_ns", "reference_ns", "checksum"):
            assert int(row[key]) > 0, row
        assert int(row["ratio_bytes"]) <= int(row["lazy_bytes"]), row
        if require_ratio_no_worse_than_reference:
            assert int(row["ratio_bytes"]) <= int(row["reference_bytes"]), row


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--limit", type=int, default=128 * 1024)
    parser.add_argument(
        "--require-ratio-no-worse-than-reference", action="store_true",
        help="Require the auxiliary legacy ratio stream to be no larger than the reference stream",
    )
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
    if args.input is not None:
        payload = args.input.read_bytes()[: args.limit]
        assert len(rows) == 1, rows
        assert int(rows[0]["input_bytes"]) == len(payload), rows[0]
        assert rows[0]["input_sha256"] == hashlib.sha256(payload).hexdigest(), rows[0]
    validate_rows(rows, require_ratio_no_worse_than_reference=args.require_ratio_no_worse_than_reference)
    print(f"br_planned_encode_path_gate=ok rows={len(rows)} ratio_reference_requirement={str(args.require_ratio_no_worse_than_reference).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
