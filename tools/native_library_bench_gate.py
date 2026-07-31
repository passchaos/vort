#!/usr/bin/env python3
"""Validate native LZ4/Zstd public-library benchmark CSV output."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

sys.dont_write_bytecode = True

EXPECTED_COLUMNS = [
    "codec",
    "mode",
    "case",
    "input_bytes",
    "encoded_bytes",
    "iterations",
    "encode_ns",
    "decode_ns",
    "encode_mib_s",
    "decode_mib_s",
    "checksum",
]
EXPECTED_CODECS = {"lz4", "zstd"}
EXPECTED_MODES = {
    "one_shot",
    "incremental",
    "incremental_direct",
    "chain_depth_0",
    "chain_depth_default",
    "match_budget_0",
    "match_budget_full",
    "dictionary_plain",
    "dictionary",
    "dictionary_set_plain",
    "dictionary_set",
    "dictionary_set_chunked_plain",
    "dictionary_set_chunked",
    "dictionary_set_reusable_plain",
    "dictionary_set_reusable",
}
EXPECTED_CASES = {"text", "structured", "repetitive"}
EXPECTED_EXTRA_ROWS = {
    ("lz4", "chain_depth_0", "chain_depth"),
    ("lz4", "chain_depth_default", "chain_depth"),
    ("zstd", "match_budget_0", "mixed_budget"),
    ("zstd", "match_budget_full", "mixed_budget"),
    ("lz4", "dictionary_plain", "dictionary"),
    ("lz4", "dictionary", "dictionary"),
    ("zstd", "dictionary_plain", "dictionary"),
    ("zstd", "dictionary", "dictionary"),
    ("lz4", "dictionary_set_plain", "dictionary_set"),
    ("lz4", "dictionary_set", "dictionary_set"),
    ("zstd", "dictionary_set_plain", "dictionary_set"),
    ("zstd", "dictionary_set", "dictionary_set"),
    ("lz4", "dictionary_set_chunked_plain", "dictionary_set_chunked"),
    ("lz4", "dictionary_set_chunked", "dictionary_set_chunked"),
    ("zstd", "dictionary_set_chunked_plain", "dictionary_set_chunked"),
    ("zstd", "dictionary_set_chunked", "dictionary_set_chunked"),
    ("lz4", "dictionary_set_reusable_plain", "dictionary_set_reusable"),
    ("lz4", "dictionary_set_reusable", "dictionary_set_reusable"),
    ("zstd", "dictionary_set_reusable_plain", "dictionary_set_reusable"),
    ("zstd", "dictionary_set_reusable", "dictionary_set_reusable"),
}


def positive_int(row: dict[str, str], key: str) -> int:
    value = int(row.get(key, "0"))
    if value <= 0:
        raise AssertionError(f"expected positive integer {key}, got row={row}")
    return value


def positive_float(row: dict[str, str], key: str) -> float:
    value = float(row.get(key, "0"))
    if value <= 0.0:
        raise AssertionError(f"expected positive float {key}, got row={row}")
    return value


def assert_close(actual: float, expected: float, label: str) -> None:
    # The Zig tool prints MiB/s with two decimals to keep the CSV stable and
    # readable.  The gate therefore checks the value against the recomputed
    # throughput with a small absolute rounding allowance rather than demanding
    # binary floating-point identity.
    tolerance = max(0.02, expected * 0.0005)
    if abs(actual - expected) > tolerance:
        raise AssertionError(f"{label} mismatch: expected {expected}, got {actual}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=Path("zig-out/vort-native-library-bench.csv"))
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"native_library_bench_gate=missing path={args.csv}", file=sys.stderr)
        return 1

    with args.csv.open(newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != EXPECTED_COLUMNS:
            raise AssertionError(f"bad CSV header: {reader.fieldnames!r}")
        rows = list(reader)

    expected = {
        (codec, mode, case)
        for codec in EXPECTED_CODECS
        for mode in {"one_shot", "incremental", "incremental_direct"}
        for case in EXPECTED_CASES
    } | EXPECTED_EXTRA_ROWS
    seen: set[tuple[str, str, str]] = set()
    expected_iterations: int | None = None

    for row in rows:
        identity = (row["codec"], row["mode"], row["case"])
        if identity in seen:
            raise AssertionError(f"duplicate benchmark row: {row}")
        seen.add(identity)
        if identity not in expected:
            raise AssertionError(f"unexpected benchmark row identity: {row}")

        input_bytes = positive_int(row, "input_bytes")
        encoded_bytes = positive_int(row, "encoded_bytes")
        iterations = positive_int(row, "iterations")
        encode_ns = positive_int(row, "encode_ns")
        decode_ns = positive_int(row, "decode_ns")
        encode_mib_s = positive_float(row, "encode_mib_s")
        decode_mib_s = positive_float(row, "decode_mib_s")
        positive_int(row, "checksum")

        if encoded_bytes <= 8:
            raise AssertionError(f"encoded frame is too small to contain native frame metadata: {row}")
        if expected_iterations is None:
            expected_iterations = iterations
        elif iterations != expected_iterations:
            raise AssertionError(f"mixed iteration counts: first={expected_iterations} row={row}")

        encoded_work_bytes = input_bytes * iterations
        expected_encode_mib_s = (encoded_work_bytes / (1024.0 * 1024.0)) / (encode_ns / 1_000_000_000.0)
        expected_decode_mib_s = (encoded_work_bytes / (1024.0 * 1024.0)) / (decode_ns / 1_000_000_000.0)
        assert_close(encode_mib_s, expected_encode_mib_s, f"{identity} encode_mib_s")
        assert_close(decode_mib_s, expected_decode_mib_s, f"{identity} decode_mib_s")

    if seen != expected or len(rows) != len(expected):
        raise AssertionError(f"bad codec/mode/case matrix: seen={sorted(seen)!r}")

    row_by_identity = {(row["codec"], row["mode"], row["case"]): row for row in rows}
    chain0 = row_by_identity[("lz4", "chain_depth_0", "chain_depth")]
    chain_default = row_by_identity[("lz4", "chain_depth_default", "chain_depth")]
    if int(chain_default["encoded_bytes"]) >= int(chain0["encoded_bytes"]):
        raise AssertionError(
            "expected default lz4 chain depth to improve chain_depth size: "
            f"depth0={chain0['encoded_bytes']} default={chain_default['encoded_bytes']}"
        )

    budget0 = row_by_identity[("zstd", "match_budget_0", "mixed_budget")]
    budget_full = row_by_identity[("zstd", "match_budget_full", "mixed_budget")]
    if int(budget_full["encoded_bytes"]) >= int(budget0["encoded_bytes"]):
        raise AssertionError(
            "expected full zstd match search budget to improve mixed_budget size: "
            f"budget0={budget0['encoded_bytes']} full={budget_full['encoded_bytes']}"
        )

    for codec in ("lz4", "zstd"):
        plain = row_by_identity[(codec, "dictionary_plain", "dictionary")]
        dictionary = row_by_identity[(codec, "dictionary", "dictionary")]
        if int(dictionary["encoded_bytes"]) >= int(plain["encoded_bytes"]):
            raise AssertionError(
                f"expected {codec} dictionary row to improve dictionary size: "
                f"plain={plain['encoded_bytes']} dictionary={dictionary['encoded_bytes']}"
            )

        set_plain = row_by_identity[(codec, "dictionary_set_plain", "dictionary_set")]
        dictionary_set = row_by_identity[(codec, "dictionary_set", "dictionary_set")]
        if int(dictionary_set["encoded_bytes"]) >= int(set_plain["encoded_bytes"]):
            raise AssertionError(
                f"expected {codec} dictionary-set row to improve dictionary_set size: "
                f"plain={set_plain['encoded_bytes']} dictionary_set={dictionary_set['encoded_bytes']}"
            )

        chunked_plain = row_by_identity[(codec, "dictionary_set_chunked_plain", "dictionary_set_chunked")]
        chunked_set = row_by_identity[(codec, "dictionary_set_chunked", "dictionary_set_chunked")]
        if int(chunked_set["encoded_bytes"]) >= int(chunked_plain["encoded_bytes"]):
            raise AssertionError(
                f"expected {codec} chunked dictionary-set row to improve dictionary_set_chunked size: "
                f"plain={chunked_plain['encoded_bytes']} dictionary_set={chunked_set['encoded_bytes']}"
            )

        reusable_plain = row_by_identity[(codec, "dictionary_set_reusable_plain", "dictionary_set_reusable")]
        reusable_set = row_by_identity[(codec, "dictionary_set_reusable", "dictionary_set_reusable")]
        if int(reusable_set["encoded_bytes"]) >= int(reusable_plain["encoded_bytes"]):
            raise AssertionError(
                f"expected {codec} reusable dictionary-set row to improve dictionary_set_reusable size: "
                f"plain={reusable_plain['encoded_bytes']} dictionary_set={reusable_set['encoded_bytes']}"
            )

    print(f"native_library_bench_gate=ok rows={len(rows)} iterations={expected_iterations}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
