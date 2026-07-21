#!/usr/bin/env python3
"""Validate retained native block-length sweep artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

DEFAULT_CSV = Path("zig-out/vort-zstd-compare-block-sweep.csv")
DEFAULT_MARKDOWN = Path("zig-out/vort-zstd-compare-block-sweep.md")
REQUIRED_FIELDS = [
    "path",
    "block_len",
    "input_bytes",
    "zstd_bytes",
    "vort_native_best_bytes",
    "vort_native_stream_bytes",
    "vort_native_embedded_bytes",
    "vort_native_best_over_zstd",
    "vort_native_stream_over_zstd",
    "vort_native_embedded_over_zstd",
    "vort_stream_over_native_best",
    "vort_stream_over_native_best_bytes",
    "vort_stream_over_native_best_pct",
    "vort_embedded_over_native_stream",
    "vort_embedded_over_native_stream_bytes",
    "vort_embedded_over_native_stream_pct",
    "range_offset",
    "range_len",
    "range_iterations",
    "vort_range_decode_ms",
    "vort_range_decode_mib_s",
    "vort_range_decode_full_input_mib_s",
    "source_mode",
    "size_mode",
    "case_limit",
    "zstd_version",
    "vort_commit",
    "zig_version",
    "cpu_model",
    "optimize",
]


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise AssertionError(f"expected positive integer, got {value!r}")
    return parsed


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise AssertionError(f"expected non-negative integer, got {value!r}")
    return parsed


def positive_float(value: str) -> float:
    parsed = float(value)
    if parsed <= 0.0:
        raise AssertionError(f"expected positive float, got {value!r}")
    return parsed


def assert_close(actual: float, expected: float, label: str, tolerance: float = 1e-9) -> None:
    if abs(actual - expected) > tolerance:
        raise AssertionError(f"{label} mismatch: expected {expected}, got {actual}")


def validate_size_math(row: dict[str, str], label: str) -> tuple[int, int, int, int, int, int]:
    block_len = positive_int(row["block_len"])
    input_bytes = positive_int(row["input_bytes"])
    zstd_bytes = positive_int(row["zstd_bytes"])
    native_best_bytes = non_negative_int(row["vort_native_best_bytes"])
    native_stream_bytes = non_negative_int(row["vort_native_stream_bytes"])
    native_embedded_bytes = non_negative_int(row["vort_native_embedded_bytes"])
    assert_close(float(row["vort_native_best_over_zstd"]), native_best_bytes / zstd_bytes, f"{label} native-best/zstd")
    assert_close(float(row["vort_native_stream_over_zstd"]), native_stream_bytes / zstd_bytes, f"{label} native-stream/zstd")
    assert_close(float(row["vort_native_embedded_over_zstd"]), native_embedded_bytes / zstd_bytes, f"{label} native-embedded/zstd")
    stream_over_best_bytes = native_stream_bytes - native_best_bytes
    embedded_over_stream_bytes = native_embedded_bytes - native_stream_bytes
    if int(row["vort_stream_over_native_best_bytes"]) != stream_over_best_bytes:
        raise AssertionError(f"{label} stream/native-best byte delta mismatch")
    if int(row["vort_embedded_over_native_stream_bytes"]) != embedded_over_stream_bytes:
        raise AssertionError(f"{label} embedded/native-stream byte delta mismatch")
    assert_close(float(row["vort_stream_over_native_best"]), native_stream_bytes / native_best_bytes, f"{label} stream/native-best")
    assert_close(float(row["vort_stream_over_native_best_pct"]), ((native_stream_bytes / native_best_bytes) - 1.0) * 100.0, f"{label} stream/native-best pct")
    assert_close(float(row["vort_embedded_over_native_stream"]), native_embedded_bytes / native_stream_bytes, f"{label} embedded/native-stream")
    assert_close(float(row["vort_embedded_over_native_stream_pct"]), ((native_embedded_bytes / native_stream_bytes) - 1.0) * 100.0, f"{label} embedded/native-stream pct")
    range_len = positive_int(row["range_len"])
    range_iterations = positive_int(row["range_iterations"])
    range_decode_ms = positive_float(row["vort_range_decode_ms"])
    range_decode_mib_s = positive_float(row["vort_range_decode_mib_s"])
    range_decode_full_input_mib_s = positive_float(row["vort_range_decode_full_input_mib_s"])
    expected_range_mib_s = (range_len / (1024.0 * 1024.0)) / (range_decode_ms / 1000.0)
    expected_full_input_mib_s = (input_bytes / (1024.0 * 1024.0)) / (range_decode_ms / 1000.0)
    assert_close(range_decode_mib_s, expected_range_mib_s, f"{label} range decode MiB/s")
    assert_close(range_decode_full_input_mib_s, expected_full_input_mib_s, f"{label} range full-input MiB/s")
    if range_iterations <= 0:
        raise AssertionError(f"{label} range iterations must be positive")
    return block_len, input_bytes, zstd_bytes, native_best_bytes, native_stream_bytes, native_embedded_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--markdown", type=Path, default=DEFAULT_MARKDOWN)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--expect-source-mode")
    parser.add_argument("--expect-size-mode")
    parser.add_argument("--expect-optimize")
    parser.add_argument("--expect-case-limit")
    parser.add_argument("--expect-block-lens")
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.open(newline="")))
    if not rows:
        raise AssertionError("block sweep CSV has no rows")
    if list(rows[0].keys()) != REQUIRED_FIELDS:
        raise AssertionError(f"unexpected block sweep CSV fields: {list(rows[0].keys())!r}")

    data_rows = [row for row in rows if row["path"] != "TOTAL"]
    total_rows = [row for row in rows if row["path"] == "TOTAL"]
    if len(data_rows) < 1 or len(total_rows) < 1:
        raise AssertionError(f"expected data rows plus TOTAL rows, got data={len(data_rows)} total={len(total_rows)}")

    source_mode = total_rows[0]["source_mode"]
    size_mode = total_rows[0]["size_mode"]
    case_limit = total_rows[0]["case_limit"]
    optimize = total_rows[0]["optimize"]
    zstd_version = total_rows[0]["zstd_version"]
    if args.expect_source_mode is not None and source_mode != args.expect_source_mode:
        raise AssertionError(f"source_mode mismatch: expected {args.expect_source_mode!r}, got {source_mode!r}")
    if args.expect_size_mode is not None and size_mode != args.expect_size_mode:
        raise AssertionError(f"size_mode mismatch: expected {args.expect_size_mode!r}, got {size_mode!r}")
    if args.expect_optimize is not None and optimize != args.expect_optimize:
        raise AssertionError(f"optimize mismatch: expected {args.expect_optimize!r}, got {optimize!r}")
    if args.expect_case_limit is not None and case_limit != args.expect_case_limit:
        raise AssertionError(f"case_limit mismatch: expected {args.expect_case_limit!r}, got {case_limit!r}")
    if zstd_version in {"", "missing"}:
        raise AssertionError("zstd version missing from block sweep artifact")

    block_lens = sorted({positive_int(row["block_len"]) for row in rows})
    if args.expect_block_lens is not None:
        expected_block_lens = [int(item) for item in args.expect_block_lens.split(",") if item]
        if block_lens != expected_block_lens:
            raise AssertionError(f"block lens mismatch: expected {expected_block_lens!r}, got {block_lens!r}")
    if len(total_rows) != len(block_lens):
        raise AssertionError(f"expected one TOTAL row per block length, got total={len(total_rows)} block_lens={len(block_lens)}")

    paths = sorted({row["path"] for row in data_rows})
    expected_data_rows = len(paths) * len(block_lens)
    if len(data_rows) != expected_data_rows:
        raise AssertionError(f"expected full path/block matrix: data={len(data_rows)} expected={expected_data_rows}")

    for row in rows:
        validate_size_math(row, f"{row['path']} block_len={row['block_len']}")
        if row["source_mode"] != source_mode or row["size_mode"] != size_mode or row["case_limit"] != case_limit or row["optimize"] != optimize:
            raise AssertionError(f"metadata drift in row {row!r}")
        if not row["vort_commit"] or not row["zig_version"] or not row["cpu_model"]:
            raise AssertionError(f"missing metadata in row {row!r}")

    total_by_block = {positive_int(row["block_len"]): row for row in total_rows}
    for block_len in block_lens:
        block_rows = [row for row in data_rows if positive_int(row["block_len"]) == block_len]
        total = total_by_block[block_len]
        summed_input = sum(positive_int(row["input_bytes"]) for row in block_rows)
        summed_zstd = sum(positive_int(row["zstd_bytes"]) for row in block_rows)
        summed_best = sum(non_negative_int(row["vort_native_best_bytes"]) for row in block_rows)
        summed_stream = sum(non_negative_int(row["vort_native_stream_bytes"]) for row in block_rows)
        summed_embedded = sum(non_negative_int(row["vort_native_embedded_bytes"]) for row in block_rows)
        summed_range_len = sum(positive_int(row["range_len"]) for row in block_rows)
        summed_range_decode_ms = sum(positive_float(row["vort_range_decode_ms"]) for row in block_rows)
        if positive_int(total["input_bytes"]) != summed_input:
            raise AssertionError(f"TOTAL input mismatch for block_len={block_len}")
        if positive_int(total["zstd_bytes"]) != summed_zstd:
            raise AssertionError(f"TOTAL zstd mismatch for block_len={block_len}")
        if non_negative_int(total["vort_native_best_bytes"]) != summed_best:
            raise AssertionError(f"TOTAL native best mismatch for block_len={block_len}")
        if non_negative_int(total["vort_native_stream_bytes"]) != summed_stream:
            raise AssertionError(f"TOTAL native stream mismatch for block_len={block_len}")
        if non_negative_int(total["vort_native_embedded_bytes"]) != summed_embedded:
            raise AssertionError(f"TOTAL native embedded mismatch for block_len={block_len}")
        if positive_int(total["range_len"]) != summed_range_len:
            raise AssertionError(f"TOTAL range_len mismatch for block_len={block_len}")
        assert_close(positive_float(total["vort_range_decode_ms"]), summed_range_decode_ms, f"TOTAL range decode ms block_len={block_len}", 1e-6)

    best_total = min(total_rows, key=lambda row: non_negative_int(row["vort_native_stream_bytes"]))
    best_block_len = positive_int(best_total["block_len"])
    best_native_stream_bytes = non_negative_int(best_total["vort_native_stream_bytes"])
    best_native_stream_ratio = positive_float(best_total["vort_native_stream_over_zstd"])
    best_range_decode_mib_s = positive_float(best_total["vort_range_decode_mib_s"])
    best_range_decode_full_input_mib_s = positive_float(best_total["vort_range_decode_full_input_mib_s"])
    best_stream_over_native_best = positive_float(best_total["vort_stream_over_native_best"])
    best_stream_over_native_best_bytes = int(best_total["vort_stream_over_native_best_bytes"])
    best_embedded_over_native_stream = positive_float(best_total["vort_embedded_over_native_stream"])
    best_embedded_over_native_stream_bytes = int(best_total["vort_embedded_over_native_stream_bytes"])

    markdown = args.markdown.read_text()
    if (
        "Best total native stream bytes" not in markdown
        or "TOTAL by block length" not in markdown
        or "Per-input rows" not in markdown
        or "embedded-index bytes" not in markdown
        or "stream overhead bytes" not in markdown
        or "range decode MiB/s" not in markdown
    ):
        raise AssertionError("block sweep markdown missing retained sections or columns")

    summary: dict[str, Any] = {
        "schema": "vort.zstd_compare_block_sweep_gate",
        "schema_version": 1,
        "ok": True,
        "rows": len(rows),
        "data_rows": len(data_rows),
        "total_rows": len(total_rows),
        "path_count": len(paths),
        "block_len_count": len(block_lens),
        "block_lens": block_lens,
        "source_mode": source_mode,
        "size_mode": size_mode,
        "case_limit": case_limit,
        "optimize": optimize,
        "best_block_len": best_block_len,
        "best_native_stream_bytes": best_native_stream_bytes,
        "best_native_stream_ratio": best_native_stream_ratio,
        "best_range_decode_mib_s": best_range_decode_mib_s,
        "best_range_decode_full_input_mib_s": best_range_decode_full_input_mib_s,
        "best_stream_over_native_best": best_stream_over_native_best,
        "best_stream_over_native_best_bytes": best_stream_over_native_best_bytes,
        "best_embedded_over_native_stream": best_embedded_over_native_stream,
        "best_embedded_over_native_stream_bytes": best_embedded_over_native_stream_bytes,
        "csv": str(args.csv),
        "markdown": str(args.markdown),
    }
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(
        "zstd_compare_block_sweep_gate=ok "
        f"rows={len(rows)} "
        f"block_lens={','.join(str(n) for n in block_lens)} "
        f"best_block_len={best_block_len} "
        f"best_native_stream_ratio={best_native_stream_ratio:.4f} "
        f"best_range_decode_mib_s={best_range_decode_mib_s:.2f} "
        f"best_stream_over_best={best_stream_over_native_best:.4f} "
        f"best_stream_over_best_bytes={best_stream_over_native_best_bytes} "
        f"best_embedded_over_stream={best_embedded_over_native_stream:.4f} "
        f"best_embedded_over_stream_bytes={best_embedded_over_native_stream_bytes}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
