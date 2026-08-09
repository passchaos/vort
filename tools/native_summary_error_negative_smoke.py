#!/usr/bin/env python3
"""Negative smoke for native summary error dashboard aggregate invariants."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

from native_summary_error_dashboard import build_summary, validate_summary


def check_failure(name: str, payload: dict[str, object], needle: str) -> dict[str, object]:
    try:
        validate_summary(payload)
    except AssertionError as exc:
        actual_error = str(exc)
        return {
            "name": name,
            "expected_failure": True,
            "expected_error": needle,
            "actual_error": actual_error,
            "matched": needle in actual_error,
        }
    return {
        "name": name,
        "expected_failure": True,
        "expected_error": needle,
        "actual_error": "<success>",
        "matched": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    cases = [
        {
            "name": "lz4_bad_magic",
            "codec": "lz4",
            "schema": "vort.lz4_native_stream_summary_error",
            "schema_version": 1,
            "ok": False,
            "compressed_bytes": 7,
            "error": "CorruptFrame",
            "phase": "magic",
            "offset": 0,
        },
        {
            "name": "zstd_truncated_skippable",
            "codec": "zstd",
            "schema": "vort.zstd_native_stream_summary_error",
            "schema_version": 1,
            "ok": False,
            "compressed_bytes": 13,
            "error": "TruncatedFrame",
            "phase": "skippable_payload",
            "offset": 13,
        },
    ]
    base_summary = build_summary(cases)
    validate_summary(base_summary)

    smoke_cases: list[dict[str, object]] = []
    bad_error_counts = copy.deepcopy(base_summary)
    bad_error_counts["error_counts"] = {"CorruptFrame": 2}
    smoke_cases.append(check_failure("bad_error_counts", bad_error_counts, "error_counts mismatch"))

    bad_phase_counts = copy.deepcopy(base_summary)
    bad_phase_counts["phase_counts"] = {"magic": 2}
    smoke_cases.append(check_failure("bad_phase_counts", bad_phase_counts, "phase_counts mismatch"))

    bad_case_count = copy.deepcopy(base_summary)
    bad_case_count["case_count"] = 99
    smoke_cases.append(check_failure("bad_case_count", bad_case_count, "case_count mismatch"))

    bad_offset_ranges = copy.deepcopy(base_summary)
    bad_offset_ranges["phase_offset_ranges"] = {"magic": {"min": 99, "max": 99}}
    smoke_cases.append(check_failure("bad_offset_ranges", bad_offset_ranges, "phase_offset_ranges mismatch"))

    bad_lz4_offset_range = copy.deepcopy(base_summary)
    bad_lz4_offset_range["lz4_offset_max"] = 99
    smoke_cases.append(check_failure("bad_lz4_offset_range", bad_lz4_offset_range, "lz4_offset_max mismatch"))

    bad_zstd_offset_range = copy.deepcopy(base_summary)
    bad_zstd_offset_range["zstd_offset_min"] = 99
    smoke_cases.append(check_failure("bad_zstd_offset_range", bad_zstd_offset_range, "zstd_offset_min mismatch"))

    summary = {
        "schema": "vort.native_summary_error_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in smoke_cases),
        "case_count": len(smoke_cases),
        "cases": smoke_cases,
    }
    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"native_summary_error_negative_smoke=ok cases={summary['case_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
