#!/usr/bin/env python3
"""Validate the focused XZ/liblzma encode benchmark schema and coverage."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


EXPECTED = {"text256k", "json256k", "binary256k", "wide128k", "wide1m"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    names = {row["case"] for row in rows}
    if names != EXPECTED or len(rows) != len(EXPECTED):
        raise SystemExit(f"unexpected XZ benchmark cases: {sorted(names)}")
    version = {row["reference_version"] for row in rows}
    if len(version) != 1 or not next(iter(version)):
        raise SystemExit("missing or inconsistent liblzma version")
    for row in rows:
        for field in (
            "input_bytes",
            "vort_bytes",
            "reference_bytes",
            "iterations",
            "rounds",
            "vort_ns",
            "reference_ns",
            "checksum",
        ):
            if int(row[field]) <= 0:
                raise SystemExit(f"{row['case']}: invalid {field}")
        for field in (
            "size_over_reference",
            "vort_mib_s",
            "reference_mib_s",
            "vort_over_reference",
        ):
            if float(row[field]) <= 0:
                raise SystemExit(f"{row['case']}: invalid {field}")
        if len(row["input_sha256"]) != 64:
            raise SystemExit(f"{row['case']}: invalid input hash")
    by_name = {row["case"]: row for row in rows}
    if int(by_name["wide128k"]["vort_bytes"]) >= int(by_name["wide128k"]["input_bytes"]):
        raise SystemExit("wide128k did not benefit from the configured dictionary")
    if int(by_name["wide1m"]["vort_bytes"]) >= int(by_name["wide1m"]["input_bytes"]):
        raise SystemExit("wide1m did not benefit from the configured dictionary")
    print(
        "xz_encode_bench_gate=ok "
        f"cases={len(rows)} reference_version={next(iter(version))}"
    )


if __name__ == "__main__":
    main()
