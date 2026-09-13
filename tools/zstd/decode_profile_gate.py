#!/usr/bin/env python3
"""Validate the focused pure-Vort Zstd decode profile."""
import argparse
import csv
import hashlib
from pathlib import Path

PROVENANCE_COLUMNS = ["provenance_version", "optimize", "zig_version", "target_arch", "target_os", "target_abi", "target_cpu", "cpu_model", "cpu_affinity", "affinity_cpu_count", "benchmark_threads", "codec_thread_policy", "executable_sha256", "command"]
COLUMNS = ["case", "input_bytes", "input_sha256", "encoded_bytes", "iterations", "vort_ns", "vort_mib_s", "checksum", "block_count", "compressed_blocks", "literals_kind", "sequence_count", "ll_mode", "of_mode", "ml_mode"] + PROVENANCE_COLUMNS
CASES = {"numbered_json", "huffman80k", "ascii64k", "large_json", "binary_mixed"}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--executable", type=Path)
    args = parser.parse_args()
    with args.csv.open(newline="") as file:
        reader = csv.DictReader(file)
        assert reader.fieldnames == COLUMNS, reader.fieldnames
        rows = list(reader)
    by_case = {row["case"]: row for row in rows}
    assert len(rows) == len(CASES) and set(by_case) == CASES, sorted(by_case)
    provenance = {tuple(row[key] for key in PROVENANCE_COLUMNS) for row in rows}
    assert len(provenance) == 1 and all(next(iter(provenance))), provenance
    assert rows[0]["optimize"] == "ReleaseFast", rows[0]
    assert rows[0]["provenance_version"] == "1", rows[0]
    assert (rows[0]["cpu_affinity"] == "unavailable") == (int(rows[0]["affinity_cpu_count"]) == 0), rows[0]
    assert int(rows[0]["benchmark_threads"]) == 1, rows[0]
    assert rows[0]["codec_thread_policy"] == "single", rows[0]
    assert len(rows[0]["executable_sha256"]) == 64, rows[0]
    if args.executable is not None:
        assert hashlib.sha256(args.executable.read_bytes()).hexdigest() == rows[0]["executable_sha256"], rows[0]
    for row in rows:
        assert len(row["input_sha256"]) == 64 and set(row["input_sha256"]) <= set("0123456789abcdef"), row
        for key in ("input_bytes", "encoded_bytes", "iterations", "vort_ns", "checksum", "block_count", "compressed_blocks"):
            assert int(row[key]) > 0, row
        assert float(row["vort_mib_s"]) > 0, row
    huffman = by_case["huffman80k"]
    assert huffman["literals_kind"] == "raw" and int(huffman["sequence_count"]) >= 1000, huffman
    ascii_huffman = by_case["ascii64k"]
    assert ascii_huffman["literals_kind"] == "compressed", ascii_huffman
    assert int(ascii_huffman["sequence_count"]) == 0, ascii_huffman
    assert (huffman["ll_mode"], huffman["of_mode"], huffman["ml_mode"]) == ("compressed", "compressed", "compressed"), huffman
    for name in ("large_json", "binary_mixed"):
        row = by_case[name]
        assert int(row["block_count"]) >= 4 and int(row["compressed_blocks"]) >= 4, row
        assert int(row["sequence_count"]) >= 1000, row
        assert row["of_mode"] == "compressed", row
    print(f"zstd_decode_profile_gate=ok rows={len(rows)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
