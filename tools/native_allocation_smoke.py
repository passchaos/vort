#!/usr/bin/env python3
"""Gate native allocation report regressions for zero-allocation paths."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "zig-out" / "vort-native-allocation-report.json"

ZERO_ALLOCATION_CASES = [
    "concat_into",
    "concat_auto_into_embedded_dict",
    "concat_limited_reject",
    "any_decoder_compressed_scratch",
    "any_decoder_dictionary_deflate_scratch",
    "zlib_decoder_png_like_scratch",
    "zlib_decoder_png_like_chunks_scratch",
    "zlib_decoder_png_varied_chunks_scratch",
    "zlib_decoder_png_scanline_scratch",
    "zlib_decoder_png_reconstruct_scratch",
    "png_zlib_scanline_pipeline_scratch",
    "png_streaming_zlib_scanline_pipeline_scratch",
    "png_streaming_zlib_chunked_scanline_pipeline_scratch",
    "png_zlib_image_decode_scratch",
    "png_streaming_zlib_image_decode_scratch",
    "png_streaming_zlib_chunked_image_decode_scratch",
    "png_zlib_subbyte_image_decode_scratch",
    "png_adam7_metadata_scratch",
    "png_adam7_placement_scratch",
    "png_adam7_image_decode_scratch",
    "png_adam7_streaming_image_decode_scratch",
    "png_adam7_subbyte_image_decode_scratch",
    "png_adam7_streaming_subbyte_image_decode_scratch",
    "png_adam7_rgba16_image_decode_scratch",
    "png_adam7_streaming_rgba16_image_decode_scratch",
    "png_adam7_corrupt_reject_scratch",
    "png_zlib_wrapper_reject_scratch",
    "png_adam7_wrapper_reject_scratch",
    "zlib_decoder_dictionary_chunks_scratch",
    "gzip_decoder_scratch",
    "gzip_decoder_concatenated_chunks_scratch",
    "indexed_range_into_index_buffer",
    "indexed_partial_range_into_scratch",
    "sidecar_partial_range_into_scratch",
    "batch_range_into_index_buffer",
    "dictionary_range_into_index_buffer",
    "dictionary_deflate_range_into_patch_scratch",
    "dictionary_deflate_partial_range_into_scratch",
    "dictionary_deflate_auto_range_into_buffers",
    "dictionary_deflate_self_range_into_buffers",
    "ldm_partial_range_into_scratch",
    "sidecar_ldm_partial_range_into_scratch",
    "embedded_validation_with_buffers",
    "embedded_validation_report_with_buffers",
    "embedded_compressed_validation_with_buffers",
    "embedded_compressed_validation_report_with_buffers",
    "sidecar_compressed_validation_with_buffers",
    "sidecar_compressed_validation_report_with_buffers",
    "embedded_ldm_validation_with_buffers",
    "sidecar_ldm_validation_with_buffers",
    "dictionary_deflate_validation_with_buffers",
    "dictionary_deflate_validation_report_with_buffers",
]

ALLOCATION_BUDGETS = {
    "concat_alloc": {"max_allocations": 1, "max_deallocations": 1, "max_allocated_bytes": 49, "max_freed_bytes": 49},
    "indexed_range_alloc_full_deflate": {"max_allocations": 2, "max_deallocations": 2, "max_allocated_bytes": 103, "max_freed_bytes": 103},
    "indexed_range_into_full_deflate": {"max_allocations": 1, "max_deallocations": 1, "max_allocated_bytes": 80, "max_freed_bytes": 80},
    "batch_range_into_fast_paths": {"max_allocations": 1, "max_deallocations": 1, "max_allocated_bytes": 80, "max_freed_bytes": 80},
    "embedded_validation_borrowed_dict": {"max_allocations": 8, "max_deallocations": 8, "max_allocated_bytes": 2081, "max_freed_bytes": 2081},
    "zstd_seekable_into": {"max_allocations": 19, "max_deallocations": 19, "max_allocated_bytes": 227790, "max_freed_bytes": 227790},
    "zstd_seekable_reusable_warm_into": {"max_allocations": 0, "max_deallocations": 0, "max_allocated_bytes": 0, "max_freed_bytes": 0},
}

SEEKABLE_REUSE_CASES = (
    "zstd_seekable_into",
    "zstd_seekable_reusable_warm_into",
)


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def int_value(row: dict[str, Any], key: str) -> int:
    value = row.get(key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise AssertionError(f"{key} must be an integer in {row!r}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="native allocation report JSON path")
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    report_path = Path(args.report)
    report = load_json(report_path)
    if report.get("schema") != "vort.native_allocation_report":
        raise AssertionError("unexpected native allocation report schema")
    rows = {row.get("case"): row for row in report.get("cases", []) if isinstance(row, dict) and isinstance(row.get("case"), str)}

    case_rows: list[dict[str, object]] = []
    for name in ZERO_ALLOCATION_CASES:
        row = rows.get(name)
        if row is None:
            case_rows.append({"case": name, "present": False, "allocations": None, "deallocations": None, "allocated_bytes": None, "freed_bytes": None, "matched": False})
            continue
        allocations = int_value(row, "allocations")
        deallocations = int_value(row, "deallocations")
        allocated_bytes = int_value(row, "allocated_bytes")
        freed_bytes = int_value(row, "freed_bytes")
        case_rows.append({
            "case": name,
            "present": True,
            "allocations": allocations,
            "deallocations": deallocations,
            "allocated_bytes": allocated_bytes,
            "freed_bytes": freed_bytes,
            "matched": allocations == 0 and deallocations == 0 and allocated_bytes == 0 and freed_bytes == 0,
        })

    budget_rows: list[dict[str, object]] = []
    for name, budget in ALLOCATION_BUDGETS.items():
        row = rows.get(name)
        if row is None:
            budget_rows.append({
                "case": name,
                "present": False,
                "allocations": None,
                "deallocations": None,
                "allocated_bytes": None,
                "freed_bytes": None,
                "max_allocations": budget["max_allocations"],
                "max_deallocations": budget["max_deallocations"],
                "max_allocated_bytes": budget["max_allocated_bytes"],
                "max_freed_bytes": budget["max_freed_bytes"],
                "balanced": False,
                "matched": False,
            })
            continue
        allocations = int_value(row, "allocations")
        deallocations = int_value(row, "deallocations")
        allocated_bytes = int_value(row, "allocated_bytes")
        freed_bytes = int_value(row, "freed_bytes")
        balanced = allocations == deallocations and allocated_bytes == freed_bytes
        budget_rows.append({
            "case": name,
            "present": True,
            "allocations": allocations,
            "deallocations": deallocations,
            "allocated_bytes": allocated_bytes,
            "freed_bytes": freed_bytes,
            "max_allocations": budget["max_allocations"],
            "max_deallocations": budget["max_deallocations"],
            "max_allocated_bytes": budget["max_allocated_bytes"],
            "max_freed_bytes": budget["max_freed_bytes"],
            "balanced": balanced,
            "matched": (
                allocations <= budget["max_allocations"]
                and deallocations <= budget["max_deallocations"]
                and allocated_bytes <= budget["max_allocated_bytes"]
                and freed_bytes <= budget["max_freed_bytes"]
                and balanced
            ),
        })

    seekable_rows = [rows.get(name) for name in SEEKABLE_REUSE_CASES]
    seekable_reuse_matched = all(row is not None for row in seekable_rows)
    if seekable_reuse_matched:
        one_shot, warmed = seekable_rows
        assert one_shot is not None and warmed is not None
        seekable_reuse_matched = (
            int_value(one_shot, "input_bytes") == int_value(warmed, "input_bytes")
            and int_value(one_shot, "output_bytes") == int_value(warmed, "output_bytes")
            and int_value(one_shot, "allocations") == int_value(one_shot, "deallocations")
            and int_value(one_shot, "allocated_bytes") == int_value(one_shot, "freed_bytes")
            and int_value(warmed, "allocations") == int_value(warmed, "deallocations")
            and int_value(warmed, "allocated_bytes") == int_value(warmed, "freed_bytes")
            and int_value(warmed, "allocations") + 16 <= int_value(one_shot, "allocations")
            and int_value(warmed, "allocated_bytes") < int_value(one_shot, "allocated_bytes")
        )

    summary = {
        "schema": "vort.native_allocation_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in case_rows) and all(bool(row["matched"]) for row in budget_rows) and seekable_reuse_matched,
        "report": report_path.as_posix(),
        "required_zero_allocation_cases": len(case_rows),
        "required_budget_cases": len(budget_rows),
        "cases": case_rows,
        "budget_cases": budget_rows,
        "seekable_reuse_matched": seekable_reuse_matched,
    }

    if args.summary:
        summary_path = Path(args.summary)
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"native_allocation_smoke=ok zero_allocation_cases={len(case_rows)} budget_cases={len(budget_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
