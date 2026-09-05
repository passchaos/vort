#!/usr/bin/env python3
"""Validate package-merge benchmark coverage, equivalence, and speedups."""

import argparse
import csv
import pathlib
import sys

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = {"case", "mode", "symbols", "active", "max_bits", "iterations", "elapsed_ns", "builds_per_s", "checksum", "cost_checksum"}
EXPECTED = {
    "literal-sparse-18": {"production", "full-width"},
    "literal-sparse-48": {"production", "full-width"},
    "literal-dense": {"production", "full-width", "root-traversal"},
    "zstd-known-32": {"production", "known-active"},
    "zstd-known-64": {"production", "known-active"},
    "zstd-known-128": {"production", "known-active", "root-traversal"},
    "zstd-known-256": {"production", "known-active", "root-traversal"},
    "zstd-sort-64": {"bucket-sort", "comparison-sort"},
    "zstd-sort-128": {"bucket-sort", "comparison-sort"},
    "zstd-sort-256": {"bucket-sort", "comparison-sort"},
    "distance": {"production"},
    "code-length": {"production"},
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if set(reader.fieldnames or []) != EXPECTED_COLUMNS:
            raise SystemExit(f"bad huffman length benchmark header: {reader.fieldnames}")
        rows = list(reader)
    by_key = {(row["case"], row["mode"]): row for row in rows}
    expected = {(case, mode) for case, modes in EXPECTED.items() for mode in modes}
    if set(by_key) != expected:
        raise SystemExit(f"huffman length coverage mismatch: missing={sorted(expected - set(by_key))}")
    for row in rows:
        for key in ("symbols", "active", "max_bits", "iterations", "elapsed_ns"):
            if int(row[key]) <= 0:
                raise SystemExit(f"invalid {key}: {row}")
        if float(row["builds_per_s"]) <= 0:
            raise SystemExit(f"invalid throughput: {row}")
    ratios = []
    for case in ("literal-sparse-18", "literal-sparse-48"):
        production = by_key[(case, "production")]
        reference = by_key[(case, "full-width")]
        if production["checksum"] != reference["checksum"]:
            raise SystemExit(f"{case}: compact/full checksum mismatch")
        ratio = float(production["builds_per_s"]) / float(reference["builds_per_s"])
        if ratio <= 1.0:
            raise SystemExit(f"{case}: compact package merge not faster ({ratio:.3f})")
        ratios.append(ratio)
    dense = by_key[("literal-dense", "production")]
    dense_reference = by_key[("literal-dense", "full-width")]
    if dense["cost_checksum"] != dense_reference["cost_checksum"]:
        raise SystemExit("literal-dense: weighted cost differs from full-width reference")
    dense_ratio = float(dense["builds_per_s"]) / float(dense_reference["builds_per_s"])
    if dense_ratio <= 1.0:
        raise SystemExit(f"literal-dense: back-reference package merge not faster ({dense_ratio:.3f})")
    recovery_ratios = []
    for case in ("literal-dense", "zstd-known-128", "zstd-known-256"):
        production = by_key[(case, "production")]
        traversal = by_key[(case, "root-traversal")]
        if production["checksum"] != traversal["checksum"] or production["cost_checksum"] != traversal["cost_checksum"]:
            raise SystemExit(f"{case}: linear/root-traversal recovery mismatch")
        ratio = float(production["builds_per_s"]) / float(traversal["builds_per_s"])
        if ratio < 1.10:
            raise SystemExit(f"{case}: linear recovery speedup too small ({ratio:.3f})")
        recovery_ratios.append(ratio)
    recovery_geomean = (recovery_ratios[0] * recovery_ratios[1] * recovery_ratios[2]) ** (1 / 3)
    if recovery_geomean < 1.20:
        raise SystemExit(f"linear recovery geometric speedup too small ({recovery_geomean:.3f})")
    known_ratios = []
    for case in ("zstd-known-32", "zstd-known-64", "zstd-known-128", "zstd-known-256"):
        scanned = by_key[(case, "production")]
        known = by_key[(case, "known-active")]
        if scanned["checksum"] != known["checksum"] or scanned["cost_checksum"] != known["cost_checksum"]:
            raise SystemExit(f"{case}: known-active/scanned result mismatch")
        ratio = float(known["builds_per_s"]) / float(scanned["builds_per_s"])
        if ratio < 0.98:
            raise SystemExit(f"{case}: known-active package merge regressed ({ratio:.3f})")
        known_ratios.append(ratio)
    known_geomean = (known_ratios[0] * known_ratios[1] * known_ratios[2] * known_ratios[3]) ** 0.25
    if known_geomean < 1.01:
        raise SystemExit(f"known-active package merge speedup too small ({known_geomean:.3f})")
    dense_known_geomean = (known_ratios[2] * known_ratios[3]) ** 0.5
    if dense_known_geomean < 1.005:
        raise SystemExit(f"dense known-active package merge speedup too small ({dense_known_geomean:.3f})")
    sort_ratios = []
    for case in ("zstd-sort-64", "zstd-sort-128", "zstd-sort-256"):
        bucket = by_key[(case, "bucket-sort")]
        comparison = by_key[(case, "comparison-sort")]
        if bucket["checksum"] != comparison["checksum"] or bucket["cost_checksum"] != comparison["cost_checksum"]:
            raise SystemExit(f"{case}: bucket/comparison sort mismatch")
        ratio = float(bucket["builds_per_s"]) / float(comparison["builds_per_s"])
        if ratio < 1.05:
            raise SystemExit(f"{case}: Huffman bucket sort speedup too small ({ratio:.3f})")
        sort_ratios.append(ratio)
    sort_geomean = (sort_ratios[0] * sort_ratios[1] * sort_ratios[2]) ** (1 / 3)
    if sort_geomean < 1.10:
        raise SystemExit(f"Huffman bucket sort geometric speedup too small ({sort_geomean:.3f})")
    print(f"huffman length gate: sparse18={ratios[0]:.2f}x sparse48={ratios[1]:.2f}x dense={dense_ratio:.2f}x recovery-dense={recovery_ratios[0]:.2f}x recovery128={recovery_ratios[1]:.2f}x recovery256={recovery_ratios[2]:.2f}x known32={known_ratios[0]:.2f}x known64={known_ratios[1]:.2f}x known128={known_ratios[2]:.2f}x known256={known_ratios[3]:.2f}x sort64={sort_ratios[0]:.2f}x sort128={sort_ratios[1]:.2f}x sort256={sort_ratios[2]:.2f}x rows={len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
