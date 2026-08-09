#!/usr/bin/env python3
"""Negative smoke for native summary error dashboard aggregate invariants."""

from __future__ import annotations

import copy

from native_summary_error_dashboard import build_summary, validate_summary


def expect_failure(name: str, payload: dict[str, object], needle: str) -> None:
    try:
        validate_summary(payload)
    except AssertionError as exc:
        if needle not in str(exc):
            raise AssertionError(f"{name}: expected {needle!r}, got {exc!r}") from exc
        return
    raise AssertionError(f"{name}: expected validation failure")


def main() -> int:
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
    summary = build_summary(cases)
    validate_summary(summary)

    bad_error_counts = copy.deepcopy(summary)
    bad_error_counts["error_counts"] = {"CorruptFrame": 2}
    expect_failure("bad_error_counts", bad_error_counts, "error_counts mismatch")

    bad_phase_counts = copy.deepcopy(summary)
    bad_phase_counts["phase_counts"] = {"magic": 2}
    expect_failure("bad_phase_counts", bad_phase_counts, "phase_counts mismatch")

    bad_case_count = copy.deepcopy(summary)
    bad_case_count["case_count"] = 99
    expect_failure("bad_case_count", bad_case_count, "case_count mismatch")

    print("native_summary_error_negative_smoke=ok cases=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
