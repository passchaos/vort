#!/usr/bin/env python3
"""Validate the explicit fast-compressed Zstandard Pareto artifact."""

import argparse
import csv
import hashlib
from pathlib import Path

from encode_bench_gate import COLUMNS, PROVENANCE_COLUMNS


EXPECTED_VORT_BYTES = {
    "text": 80,
    "json": 694,
    "binary": 8_607,
    "level3_tradeoff": 2_038,
    "multiblock": 34_228,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path, required=True)
    args = parser.parse_args()

    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)

    assert {row["case"] for row in rows} == set(EXPECTED_VORT_BYTES), rows
    assert len(rows) == len(EXPECTED_VORT_BYTES), rows
    assert {int(row["level"]) for row in rows} == {1}, rows
    assert len({row["reference_version"] for row in rows}) == 1, rows
    assert len({row["input_sha256"] for row in rows}) == len(rows), rows

    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    assert len(provenance) == 1 and all(next(iter(provenance))), provenance
    executable_sha256 = hashlib.sha256(args.executable.read_bytes()).hexdigest()

    for row in rows:
        assert row["provenance_version"] == "1", row
        assert row["optimize"] == "ReleaseFast", row
        assert row["executable_sha256"] == executable_sha256, row
        assert "--native-selection fast_compressed" in row["command"], row
        assert int(row["iterations"]) == 100, row
        assert int(row["rounds"]) == 5, row
        assert int(row["vort_bytes"]) == EXPECTED_VORT_BYTES[row["case"]], row
        assert int(row["vort_bytes"]) < int(row["input_bytes"]), row
        assert int(row["reference_bytes"]) > 0, row
        assert int(row["vort_ns"]) > 0 and int(row["reference_ns"]) > 0, row
        assert float(row["vort_mib_s"]) > 0, row
        assert float(row["reference_mib_s"]) > 0, row
        assert float(row["vort_over_reference"]) > 0, row
        assert int(row["checksum"]) > 0, row

    print(
        "zstd_fast_compressed_bench_gate=ok "
        f"rows={len(rows)} reference_version={rows[0]['reference_version']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
