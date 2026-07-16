#!/usr/bin/env python3
"""Smoke-test dashboard_index strict-mode gates."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_INDEX = ROOT / "tools" / "dashboard_index.py"
EXPECTED_MODES = ROOT / "tools" / "dashboard_strict_expected_modes.json"
VALIDATION_REASONS = ROOT / "tools" / "dashboard_strict_validation_reasons.json"
HEADER_INSPECT_ARTIFACT = "vort-header-inspect-smoke.json"
DASHBOARD_STRICT_ARTIFACT = "vort-dashboard-strict-smoke.json"
SIDECAR_CORRUPT_ARTIFACT = "vort-sidecar-corrupt-smoke.json"
HUFFMAN_LENGTH_ARTIFACT = "vort-huffman-length-report.csv"
FUZZ_CORPUS_ARTIFACT = "vort-deflate-wrapper-fuzz-corpus.json"
FUZZ_COVERAGE_ARTIFACT = "vort-fuzz-corpus-coverage-smoke.json"
DECODE_STAGE_ARTIFACT = "vort-deflate-decode-stage-report.json"
PYTHON_ZLIB_DIFF_ARTIFACT = "vort-python-zlib-diff-smoke.json"


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_producer_map(
    path: Path,
    *,
    include_header_exact: bool = True,
    include_header_smoke: bool = True,
    include_strict_exact: bool = True,
    include_strict_smoke: bool = True,
    include_sidecar_corrupt_exact: bool = True,
    include_sidecar_corrupt_smoke: bool = True,
    include_huffman_exact: bool = True,
    include_huffman_smoke: bool = True,
    include_fuzz_corpus_exact: bool = True,
    include_fuzz_corpus_smoke: bool = True,
    include_fuzz_coverage_exact: bool = True,
    include_fuzz_coverage_smoke: bool = True,
    include_decode_stage_exact: bool = True,
    include_decode_stage_smoke: bool = True,
    include_python_zlib_exact: bool = True,
    include_python_zlib_smoke: bool = True,
    required_names: list[str] | None = None,
) -> None:
    artifact_metadata = {}
    if include_header_smoke:
        artifact_metadata[HEADER_INSPECT_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-header-inspect-dashboard",
        }
    if include_strict_smoke:
        artifact_metadata[DASHBOARD_STRICT_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-dashboard-strict-smoke",
        }
    if include_sidecar_corrupt_smoke:
        artifact_metadata[SIDECAR_CORRUPT_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-sidecar-corrupt-dashboard",
        }
    if include_huffman_smoke:
        artifact_metadata[HUFFMAN_LENGTH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-huffman-length-report-dashboard",
        }
    if include_fuzz_corpus_smoke:
        artifact_metadata[FUZZ_CORPUS_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-deflate-wrapper-fuzz-corpus-dashboard",
        }
    if include_fuzz_coverage_smoke:
        artifact_metadata[FUZZ_COVERAGE_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-fuzz-corpus-coverage-smoke",
        }
    if include_decode_stage_smoke:
        artifact_metadata[DECODE_STAGE_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-deflate-decode-stage-report-dashboard",
        }
    if include_python_zlib_smoke:
        artifact_metadata[PYTHON_ZLIB_DIFF_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-python-zlib-diff-dashboard",
        }
    exact = {}
    if include_header_exact:
        exact[HEADER_INSPECT_ARTIFACT] = "zig build run-header-inspect-dashboard"
    if include_strict_exact:
        exact[DASHBOARD_STRICT_ARTIFACT] = "zig build run-dashboard-strict-smoke"
    if include_sidecar_corrupt_exact:
        exact[SIDECAR_CORRUPT_ARTIFACT] = "zig build run-sidecar-corrupt-dashboard"
    if include_huffman_exact:
        exact[HUFFMAN_LENGTH_ARTIFACT] = "zig build run-huffman-length-report-dashboard"
    if include_fuzz_corpus_exact:
        exact[FUZZ_CORPUS_ARTIFACT] = "zig build run-deflate-wrapper-fuzz-corpus-dashboard"
    if include_fuzz_coverage_exact:
        exact[FUZZ_COVERAGE_ARTIFACT] = "zig build run-fuzz-corpus-coverage-smoke"
    if include_decode_stage_exact:
        exact[DECODE_STAGE_ARTIFACT] = "zig build run-deflate-decode-stage-report-dashboard"
    if include_python_zlib_exact:
        exact[PYTHON_ZLIB_DIFF_ARTIFACT] = "zig build run-python-zlib-diff-dashboard"
    payload = {
        "schema": "vort.dashboard_producers",
        "schema_version": 1,
        "allow_missing": {"exact": [], "contains": []},
        "required_smoke_gates": list(required_names or []),
        "artifact_metadata": artifact_metadata,
        "exact": exact,
        "contains": [],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_header_summary(
    path: Path,
    *,
    ok: bool = True,
    missing: list[dict[str, object]] | None = None,
    undercovered: bool = False,
) -> None:
    missing = missing or []
    raw_cases = 0 if undercovered else 1
    zlib_cases = 1
    gzip_cases = 1
    raw_negative_cases = 1
    zlib_negative_cases = 1
    gzip_negative_cases = 1
    command_successes = raw_cases + zlib_cases + gzip_cases
    command_failures = raw_negative_cases + zlib_negative_cases + gzip_negative_cases
    workflow_successes = command_successes
    payload = {
        "schema": "vort.header_inspect_smoke",
        "schema_version": 1,
        "ok": ok,
        "case_count": raw_cases + zlib_cases + gzip_cases,
        "raw_cases": raw_cases,
        "zlib_cases": zlib_cases,
        "gzip_cases": gzip_cases,
        "negative_cases": command_failures,
        "raw_negative_cases": raw_negative_cases,
        "zlib_negative_cases": zlib_negative_cases,
        "gzip_negative_cases": gzip_negative_cases,
        "command_count": 3,
        "command_successes": command_successes,
        "command_failures": command_failures,
        "workflow_count": 3,
        "workflow_successes": workflow_successes,
        "dictionary_cases": 1,
        "optional_header_cases": 1,
        "fhcrc_cases": 1,
        "required_workflow_count": 1,
        "missing_workflow_count": len(missing),
        "missing_workflows": missing,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_dashboard_strict_summary(path: Path, *, ok: bool = True, missing_modes: list[dict[str, object]] | None = None) -> None:
    missing_modes = missing_modes or []
    validation_reason_rows = load_expected_validation_reasons(VALIDATION_REASONS)
    validation_reason_checks = [
        {"reason": row["reason"], "check": row["check"], "matched": True}
        for row in validation_reason_rows
    ]
    mode_counts = [
        {
            "mode": "all",
            "checks": 1,
            "expected_failures": 0,
            "matched": 1,
        }
    ]
    expected_modes = [
        {
            "mode": "all",
            "min_checks": 1,
            "min_expected_failures": 0,
            "min_matched": 1,
        }
    ]
    mode_requirements = [
        {
            "mode": "all",
            "checks": 1,
            "min_checks": 1,
            "missing_checks": 0,
            "expected_failures": 0,
            "min_expected_failures": 0,
            "missing_expected_failures": 0,
            "matched": 1,
            "min_matched": 1,
            "missing_matched": 0,
        }
    ]
    for row in missing_modes:
        mode = str(row.get("mode", "strict-validation-health"))
        min_checks = int(row.get("min_checks", 1))
        min_expected_failures = int(row.get("min_expected_failures", 1))
        min_matched = int(row.get("min_matched", 1))
        expected_modes.append(
            {
                "mode": mode,
                "min_checks": min_checks,
                "min_expected_failures": min_expected_failures,
                "min_matched": min_matched,
            }
        )
        mode_requirements.append(
            {
                "mode": mode,
                "checks": 0,
                "min_checks": min_checks,
                "missing_checks": min_checks,
                "expected_failures": 0,
                "min_expected_failures": min_expected_failures,
                "missing_expected_failures": min_expected_failures,
                "matched": 0,
                "min_matched": min_matched,
                "missing_matched": min_matched,
            }
        )
    payload = {
        "schema": "vort.dashboard_strict_smoke",
        "schema_version": 1,
        "ok": ok,
        "check_count": sum(row["checks"] for row in mode_counts),
        "checks": [
            {
                "name": "all_strict_ok",
                "mode": "all",
                "expected_failure": False,
                "matched": True,
                "returncode": 0,
                "expected_output": "dashboard_index=",
                "actual_output": "dashboard_index=ok",
                "actual_output_bytes": len("dashboard_index=ok"),
                "actual_output_limit": 240,
                "actual_output_truncated": False,
            }
        ],
        "mode_count": len(mode_counts),
        "mode_counts": mode_counts,
        "expected_mode_count": len(expected_modes),
        "expected_modes": expected_modes,
        "mode_requirements": mode_requirements,
        "missing_mode_count": len(missing_modes),
        "missing_modes": missing_modes,
        "validation_unhealthy_reason_count": len(validation_reason_checks),
        "validation_unhealthy_reason_checks": validation_reason_checks,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_sidecar_corrupt_report(path: Path, *, ok: bool = True) -> None:
    payload = {
        "schema": "vort.sidecar_corrupt_smoke_report",
        "schema_version": 1,
        "rows": 2,
        "metadata_ok_rows": 2 if ok else 1,
        "full_rejected_rows": 2 if ok else 1,
        "items": [
            {
                "case": "deflate",
                "metadata_ok": True,
                "full_rejected": True,
                "full_error": "TruncatedFrame",
                "stream_bytes": 44,
                "sidecar_bytes": 48,
            },
            {
                "case": "ldm",
                "metadata_ok": ok,
                "full_rejected": ok,
                "full_error": "InvalidMatch" if ok else "",
                "stream_bytes": 128,
                "sidecar_bytes": 48,
            },
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_huffman_length_csv(path: Path, *, optimal: bool = True) -> None:
    row = {
        "case": "strict-smoke",
        "symbol_count": "3",
        "max_bits": "2",
        "optimal_cost": "5",
        "actual_cost": "5" if optimal else "6",
        "gap_bits": "0" if optimal else "1",
        "kraft_cost": "4",
        "kraft_limit": "4",
        "optimal": "true" if optimal else "false",
        "lengths": "1;2;2" if optimal else "2;2;2",
        "optimal_lengths": "1;2;2",
        "package_merge_cost": "5" if optimal else "6",
        "package_merge_gap_bits": "0" if optimal else "1",
        "package_merge_optimal": "true" if optimal else "false",
        "package_merge_lengths": "1;2;2" if optimal else "2;2;2",
    }
    columns = list(row)
    path.write_text(",".join(columns) + "\n" + ",".join(row[column] for column in columns) + "\n")


def write_fuzz_corpus_report(path: Path, *, ok: bool = True) -> None:
    matched_rows = 3 if ok else 2
    payload = {
        "schema": "vort.fuzz_corpus_report",
        "schema_version": 1,
        "ok": ok,
        "mode": "mixed",
        "cases": 3,
        "accepted": 1,
        "rejected": 2,
        "exact_error_expectations": 2,
        "matched_rows": matched_rows,
        "mode_count_rows": 3,
        "error_count_rows": 2,
        "items": [
            {
                "index": 0,
                "mode": "deflate",
                "input_bytes": 2,
                "expected": "reject",
                "expected_error": "InvalidDeflateBlockType",
                "actual_error": "InvalidDeflateBlockType",
                "outcome": "rejected",
                "matched": True,
            },
            {
                "index": 1,
                "mode": "zlib",
                "input_bytes": 2,
                "expected": "reject",
                "expected_error": "InvalidDeflateBlockType",
                "actual_error": "InvalidDeflateBlockType" if ok else "ChecksumMismatch",
                "outcome": "rejected",
                "matched": ok,
            },
            {
                "index": 2,
                "mode": "gzip",
                "input_bytes": 3,
                "expected": "accept",
                "expected_error": "",
                "actual_error": "",
                "outcome": "accepted",
                "matched": True,
            },
        ],
        "mode_counts": [
            {"mode": "deflate", "cases": 1, "accepted": 0, "rejected": 1, "exact_error_expectations": 1, "matched_rows": 1},
            {"mode": "zlib", "cases": 1, "accepted": 0, "rejected": 1, "exact_error_expectations": 1, "matched_rows": 1 if ok else 0},
            {"mode": "gzip", "cases": 1, "accepted": 1, "rejected": 0, "exact_error_expectations": 0, "matched_rows": 1},
        ],
        "error_counts": [
            {"mode": "deflate", "error": "InvalidDeflateBlockType", "count": 1},
            {"mode": "zlib", "error": "InvalidDeflateBlockType" if ok else "ChecksumMismatch", "count": 1},
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_fuzz_coverage_report(path: Path, *, ok: bool = True) -> None:
    payload = {
        "schema": "vort.fuzz_corpus_coverage_smoke",
        "schema_version": 1,
        "ok": ok,
        "report": str(path.with_name(FUZZ_CORPUS_ARTIFACT)),
        "coverage": str(ROOT / "tools" / "fuzz_corpus_expected_coverage.json"),
        "mode_requirement_count": 3,
        "error_requirement_count": 2,
        "mode_requirements": [
            {
                "mode": "deflate",
                "min_cases": 1,
                "actual_cases": 1,
                "min_accepted": 0,
                "actual_accepted": 0,
                "min_rejected": 1,
                "actual_rejected": 1,
                "min_exact_error_expectations": 1,
                "actual_exact_error_expectations": 1,
                "min_matched_rows": 1,
                "actual_matched_rows": 1,
                "matched": True,
            },
            {
                "mode": "zlib",
                "min_cases": 1,
                "actual_cases": 1,
                "min_accepted": 0,
                "actual_accepted": 0,
                "min_rejected": 1,
                "actual_rejected": 1,
                "min_exact_error_expectations": 1,
                "actual_exact_error_expectations": 1,
                "min_matched_rows": 1,
                "actual_matched_rows": 1 if ok else 0,
                "matched": ok,
            },
            {
                "mode": "gzip",
                "min_cases": 1,
                "actual_cases": 1,
                "min_accepted": 1,
                "actual_accepted": 1,
                "min_rejected": 0,
                "actual_rejected": 0,
                "min_exact_error_expectations": 0,
                "actual_exact_error_expectations": 0,
                "min_matched_rows": 1,
                "actual_matched_rows": 1,
                "matched": True,
            },
        ],
        "error_requirements": [
            {"mode": "deflate", "error": "InvalidDeflateBlockType", "min_count": 1, "actual_count": 1, "matched": True},
            {"mode": "zlib", "error": "InvalidDeflateBlockType", "min_count": 1, "actual_count": 1 if ok else 0, "matched": ok},
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_decode_stage_report(path: Path, *, ok: bool = True) -> None:
    payload = {
        "schema": "vort.deflate_decode_stage_report",
        "schema_version": 1,
        "ok": ok,
        "rows": 1,
        "error_rows": 3,
        "matched_error_rows": 3 if ok else 2,
        "unmatched_error_rows": 0 if ok else 1,
        "items": [
            {
                "case": "strict-smoke",
                "input_bytes": 3,
                "zlib_bytes": 11,
                "gzip_bytes": 23,
                "raw_bytes": 5,
                "iterations": 1,
                "raw_mib_s": 1.0,
                "raw_exact_mib_s": 1.0,
                "raw_into_mib_s": 1.0,
                "zlib_mib_s": 1.0,
                "zlib_exact_mib_s": 1.0,
                "zlib_into_mib_s": 1.0,
                "gzip_mib_s": 1.0,
                "gzip_exact_mib_s": 1.0,
                "gzip_into_mib_s": 1.0,
                "zlib_wrapper_time_ratio": 1.0,
                "zlib_wrapper_exact_time_ratio": 1.0,
                "zlib_wrapper_into_time_ratio": 1.0,
                "gzip_wrapper_time_ratio": 1.0,
                "gzip_wrapper_exact_time_ratio": 1.0,
                "gzip_wrapper_into_time_ratio": 1.0,
                "raw_alloc_exact_time_ratio": 1.0,
                "raw_alloc_into_time_ratio": 1.0,
                "zlib_alloc_exact_time_ratio": 1.0,
                "zlib_alloc_into_time_ratio": 1.0,
                "gzip_alloc_exact_time_ratio": 1.0,
                "gzip_alloc_into_time_ratio": 1.0,
                "mix": 3,
            }
        ],
        "error_items": [
            {
                "case": "raw-empty",
                "wrapper": "raw",
                "input_bytes": 0,
                "expected_error": "TruncatedFrame",
                "actual_error": "TruncatedFrame",
                "matched": True,
            },
            {
                "case": "zlib-bad-adler",
                "wrapper": "zlib",
                "input_bytes": 11,
                "expected_error": "ChecksumMismatch",
                "actual_error": "ChecksumMismatch" if ok else "TrailingData",
                "matched": ok,
            },
            {
                "case": "gzip-bad-crc",
                "wrapper": "gzip",
                "input_bytes": 23,
                "expected_error": "ChecksumMismatch",
                "actual_error": "ChecksumMismatch",
                "matched": True,
            },
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_python_zlib_diff_report(path: Path, *, ok: bool = True) -> None:
    payload = {
        "schema": "vort.python_zlib_diff_smoke",
        "schema_version": 1,
        "ok": ok,
        "payloads": 3,
        "match_heavy_payloads": 1,
        "dynamic_payloads": 1,
        "dictionary_cases": 1,
        "zlib_dict_encode_cases": 1,
        "raw_dict_encode_cases": 1,
        "malformed_wrapper_cases": 1,
        "malformed_deflate_cases": 1,
        "cli_successes": 8 if ok else 0,
        "expected_failures": 2 if ok else 0,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_healthy_artifacts(root: Path) -> None:
    write_header_summary(root / HEADER_INSPECT_ARTIFACT)
    write_dashboard_strict_summary(root / DASHBOARD_STRICT_ARTIFACT)
    write_sidecar_corrupt_report(root / SIDECAR_CORRUPT_ARTIFACT)
    write_huffman_length_csv(root / HUFFMAN_LENGTH_ARTIFACT)
    write_fuzz_corpus_report(root / FUZZ_CORPUS_ARTIFACT)
    write_fuzz_coverage_report(root / FUZZ_COVERAGE_ARTIFACT)
    write_decode_stage_report(root / DECODE_STAGE_ARTIFACT)
    write_python_zlib_diff_report(root / PYTHON_ZLIB_DIFF_ARTIFACT)


def dashboard_args(root: Path, producer_map: Path, *extra: str) -> list[str]:
    return [
        "python3",
        str(DASHBOARD_INDEX),
        "--dir",
        str(root),
        "--output",
        str(root / "vort-dashboard-index.md"),
        "--manifest",
        str(root / "vort-dashboard-index.json"),
        "--producer-map",
        str(producer_map),
        *extra,
    ]


def expect_failure(args: list[str], needle: str) -> subprocess.CompletedProcess[str]:
    result = run(args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"expected failure containing {needle!r}, got success: {result.stdout!r}")
    if needle not in result.stdout:
        raise AssertionError(f"expected {needle!r} in failure output, got {result.stdout!r}")
    return result


def truncate_output(text: str, limit: int = 240) -> dict[str, object]:
    normalized = text.replace("\n", "\\n")
    truncated = len(normalized) > limit
    output = normalized[: limit - 1] + "…" if truncated else normalized
    return {
        "output": output,
        "bytes": len(normalized),
        "limit": limit,
        "truncated": truncated,
    }


def check_row(
    name: str,
    mode: str,
    expected_failure: bool,
    matched: bool,
    returncode: int,
    expected_output: str,
    actual_output: str,
) -> dict[str, object]:
    actual = truncate_output(actual_output)
    return {
        "name": name,
        "mode": mode,
        "expected_failure": expected_failure,
        "matched": matched,
        "returncode": returncode,
        "expected_output": expected_output,
        "actual_output": actual["output"],
        "actual_output_bytes": actual["bytes"],
        "actual_output_limit": actual["limit"],
        "actual_output_truncated": actual["truncated"],
    }


def build_mode_counts(checks: list[dict[str, object]]) -> list[dict[str, object]]:
    modes = sorted({str(row["mode"]) for row in checks})
    return [
        {
            "mode": mode,
            "checks": sum(1 for row in checks if row["mode"] == mode),
            "expected_failures": sum(1 for row in checks if row["mode"] == mode and row["expected_failure"]),
            "matched": sum(1 for row in checks if row["mode"] == mode and row["matched"]),
        }
        for mode in modes
    ]


def load_expected_modes() -> list[dict[str, object]]:
    payload = json.loads(EXPECTED_MODES.read_text())
    if payload.get("schema") != "vort.dashboard_strict_expected_modes":
        raise AssertionError("unexpected dashboard strict expected modes schema")
    if payload.get("schema_version") != 1:
        raise AssertionError("unsupported dashboard strict expected modes schema version")
    rows = payload.get("expected_modes")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("expected_modes must be a non-empty list")
    normalized: list[dict[str, object]] = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise AssertionError(f"expected_modes[{index}] must be an object")
        mode = row.get("mode")
        if not isinstance(mode, str):
            raise AssertionError(f"expected_modes[{index}].mode must be a string")
        if mode in seen:
            raise AssertionError(f"duplicate expected mode {mode!r}")
        seen.add(mode)
        normalized.append(
            {
                "mode": mode,
                "min_checks": int(row.get("min_checks", 0)),
                "min_expected_failures": int(row.get("min_expected_failures", 0)),
                "min_matched": int(row.get("min_matched", 0)),
            }
        )
    return normalized


def load_expected_validation_reasons(path: Path) -> list[dict[str, str]]:
    payload = json.loads(path.read_text())
    if payload.get("schema") != "vort.dashboard_strict_validation_reasons":
        raise AssertionError("unexpected dashboard strict validation reasons schema")
    if payload.get("schema_version") != 1:
        raise AssertionError("unsupported dashboard strict validation reasons schema version")
    rows = payload.get("expected_reasons")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("expected_reasons must be a non-empty list")

    normalized: list[dict[str, str]] = []
    seen_reasons: set[str] = set()
    seen_checks: set[str] = set()
    seen_fixtures: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise AssertionError(f"expected_reasons[{index}] must be an object")
        reason = row.get("reason")
        check = row.get("check")
        fixture = row.get("fixture")
        if not isinstance(reason, str):
            raise AssertionError(f"expected_reasons[{index}].reason must be a string")
        if not isinstance(check, str):
            raise AssertionError(f"expected_reasons[{index}].check must be a string")
        if not isinstance(fixture, str):
            raise AssertionError(f"expected_reasons[{index}].fixture must be a string")
        for label, value, seen in (
            ("reason", reason, seen_reasons),
            ("check", check, seen_checks),
            ("fixture", fixture, seen_fixtures),
        ):
            if value in seen:
                raise AssertionError(f"duplicate expected validation {label} {value!r}")
            seen.add(value)
        normalized.append({"reason": reason, "check": check, "fixture": fixture})
    return normalized


def mode_requirements(mode_counts: list[dict[str, object]], expected_modes: list[dict[str, object]]) -> list[dict[str, object]]:
    counts = {str(row["mode"]): row for row in mode_counts}
    rows: list[dict[str, object]] = []
    for expected in expected_modes:
        actual = counts.get(str(expected["mode"]), {})
        checks = int(actual.get("checks") or 0)
        expected_failures = int(actual.get("expected_failures") or 0)
        matched = int(actual.get("matched") or 0)
        min_checks = int(expected["min_checks"])
        min_expected_failures = int(expected["min_expected_failures"])
        min_matched = int(expected["min_matched"])
        rows.append(
            {
                "mode": expected["mode"],
                "checks": checks,
                "min_checks": min_checks,
                "missing_checks": max(0, min_checks - checks),
                "expected_failures": expected_failures,
                "min_expected_failures": min_expected_failures,
                "missing_expected_failures": max(0, min_expected_failures - expected_failures),
                "matched": matched,
                "min_matched": min_matched,
                "missing_matched": max(0, min_matched - matched),
            }
        )
    return rows


def missing_expected_modes(requirements: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        {
            "mode": row["mode"],
            "min_checks": row["min_checks"],
            "min_expected_failures": row["min_expected_failures"],
            "min_matched": row["min_matched"],
        }
        for row in requirements
        if row["missing_checks"] or row["missing_expected_failures"] or row["missing_matched"]
    ]


def write_markdown(path: Path, summary: dict[str, object]) -> None:
    lines = [
        "# Vort dashboard strict smoke",
        "",
        f"- ok: `{summary['ok']}`",
        f"- checks: {summary['check_count']}",
        "",
        "## Mode summary",
        "",
        "| mode | checks | expected failures | matched |",
        "| --- | ---: | ---: | ---: |",
    ]
    for row in summary["mode_counts"]:
        lines.append(f"| `{row['mode']}` | {row['checks']} | {row['expected_failures']} | {row['matched']} |")
    lines.extend([
        "",
        "### Expected mode matrix",
        "",
        f"- expected modes: {summary['expected_mode_count']}",
        f"- missing modes: {summary['missing_mode_count']}",
        "",
        "| mode | checks | min checks | missing checks | expected failures | min expected failures | missing expected failures | matched | min matched | missing matched |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ])
    for row in summary["mode_requirements"]:
        lines.append(
            f"| `{row['mode']}` | {row['checks']} | {row['min_checks']} | {row['missing_checks']} | {row['expected_failures']} | {row['min_expected_failures']} | {row['missing_expected_failures']} | {row['matched']} | {row['min_matched']} | {row['missing_matched']} |"
        )
    if summary["missing_modes"]:
        lines.extend(["", "| mode | min checks | min expected failures | min matched |", "| --- | ---: | ---: | ---: |"])
        for row in summary["missing_modes"]:
            lines.append(f"| `{row['mode']}` | {row['min_checks']} | {row['min_expected_failures']} | {row['min_matched']} |")
    lines.extend([
        "",
        "### Validation unhealthy reason coverage",
        "",
        f"- covered reasons: {summary['validation_unhealthy_reason_count']}",
        "",
        "| reason | check | matched |",
        "| --- | --- | --- |",
    ])
    for row in summary["validation_unhealthy_reason_checks"]:
        lines.append(f"| `{row['reason']}` | `{row['check']}` | `{row['matched']}` |")
    lines.extend([
        "",
        "## Checks",
        "",
        "| name | mode | expected failure | returncode | expected output | actual bytes | actual output | truncated | matched |",
        "| --- | --- | --- | ---: | --- | ---: | --- | --- | --- |",
    ])
    for row in summary["checks"]:
        lines.append(
            f"| `{row['name']}` | `{row['mode']}` | `{row['expected_failure']}` | {row['returncode']} | `{row['expected_output']}` | {row['actual_output_bytes']} | `{row['actual_output']}` | `{row['actual_output_truncated']}` | `{row['matched']}` |"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    parser.add_argument("--markdown", help="optional Markdown summary output path")
    args = parser.parse_args()
    checks: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="vort-dashboard-strict-") as tmp:
        root = Path(tmp)
        producer_map = root / "producers.json"
        write_healthy_artifacts(root)
        write_producer_map(producer_map, required_names=[HEADER_INSPECT_ARTIFACT, DASHBOARD_STRICT_ARTIFACT])

        ok = run(
            dashboard_args(
                root,
                producer_map,
                "--strict-producers",
                "--strict-smoke-gates",
                "--strict-header-inspect",
                "--strict-validation-health",
            )
        )
        if "dashboard_index=" not in ok.stdout:
            raise AssertionError(f"dashboard index success output missing marker: {ok.stdout!r}")
        manifest = json.loads((root / "vort-dashboard-index.json").read_text())
        assert manifest["header_inspect_present"] is True
        assert manifest["header_inspect_ok"] is True
        assert manifest["header_inspect_missing_workflow_count"] == 0
        checks.append(check_row("all_strict_ok", "all", False, True, ok.returncode, "dashboard_index=", ok.stdout))

        no_producer = root / "no-producer.json"
        write_producer_map(no_producer, include_header_exact=False, required_names=[HEADER_INSPECT_ARTIFACT, DASHBOARD_STRICT_ARTIFACT])
        no_producer_result = expect_failure(dashboard_args(root, no_producer, "--strict-producers"), f"dashboard_index_missing_producers={HEADER_INSPECT_ARTIFACT}")
        checks.append(check_row("missing_producer", "strict-producers", True, True, no_producer_result.returncode, f"dashboard_index_missing_producers={HEADER_INSPECT_ARTIFACT}", no_producer_result.stdout))

        no_smoke = root / "no-smoke.json"
        write_producer_map(no_smoke, include_header_smoke=False, required_names=[HEADER_INSPECT_ARTIFACT])
        no_smoke_result = expect_failure(dashboard_args(root, no_smoke, "--strict-smoke-gates"), f"dashboard_index_missing_smoke_gates={HEADER_INSPECT_ARTIFACT}")
        checks.append(check_row("missing_smoke_gate", "strict-smoke-gates", True, True, no_smoke_result.returncode, f"dashboard_index_missing_smoke_gates={HEADER_INSPECT_ARTIFACT}", no_smoke_result.stdout))

        missing_root = root / "missing-header"
        missing_root.mkdir()
        write_producer_map(missing_root / "producers.json")
        missing_header_result = expect_failure(
            dashboard_args(missing_root, missing_root / "producers.json", "--strict-header-inspect"),
            "dashboard_index_missing_header_inspect=1",
        )
        checks.append(check_row("missing_header_inspect", "strict-header-inspect", True, True, missing_header_result.returncode, "dashboard_index_missing_header_inspect=1", missing_header_result.stdout))

        bad_root = root / "bad-header"
        bad_root.mkdir()
        bad_artifact = bad_root / "vort-header-inspect-smoke.json"
        bad_producer = bad_root / "producers.json"
        write_producer_map(bad_producer)
        write_header_summary(bad_artifact, ok=False)
        bad_header_result = expect_failure(dashboard_args(bad_root, bad_producer, "--strict-header-inspect"), "dashboard_index_header_inspect_failed=1")
        checks.append(check_row("failed_header_inspect", "strict-header-inspect", True, True, bad_header_result.returncode, "dashboard_index_header_inspect_failed=1", bad_header_result.stdout))

        missing_workflow_root = root / "missing-workflow"
        missing_workflow_root.mkdir()
        missing_workflow_artifact = missing_workflow_root / "vort-header-inspect-smoke.json"
        missing_workflow_producer = missing_workflow_root / "producers.json"
        write_producer_map(missing_workflow_producer)
        write_header_summary(
            missing_workflow_artifact,
            missing=[{"command": "inspect-raw-header-file", "workflow": "file", "format": "raw"}],
        )
        missing_workflow_result = expect_failure(
            dashboard_args(missing_workflow_root, missing_workflow_producer, "--strict-header-inspect"),
            "dashboard_index_header_inspect_missing_workflows=1:inspect-raw-header-file:file",
        )
        checks.append(check_row("missing_header_workflow", "strict-header-inspect", True, True, missing_workflow_result.returncode, "dashboard_index_header_inspect_missing_workflows=1:inspect-raw-header-file:file", missing_workflow_result.stdout))

        expected_validation_reasons = load_expected_validation_reasons(VALIDATION_REASONS)
        validation_reason_checks: list[dict[str, object]] = []

        def add_validation_reason_check(root: Path, producer_map: Path, name: str, reason: str) -> None:
            expected = f"dashboard_index_validation_unhealthy={reason}"
            result = expect_failure(dashboard_args(root, producer_map, "--strict-validation-health"), expected)
            marker = "dashboard_index_validation_unhealthy="
            reason_line = next((line for line in result.stdout.splitlines() if line.startswith(marker)), "")
            actual_reasons = [item for item in reason_line.removeprefix(marker).split(",") if item]
            # Each fixture intentionally isolates one health failure. This keeps
            # a broad aggregate gate from masking a missing fine-grained reason
            # behind another, easier-to-trigger dashboard problem.
            if actual_reasons != [reason]:
                raise AssertionError(f"{name} expected isolated reason {reason!r}, got {actual_reasons!r}")
            row = check_row(name, "strict-validation-health", True, True, result.returncode, expected, result.stdout)
            checks.append(row)
            validation_reason_checks.append({"reason": reason, "check": name, "matched": row["matched"]})

        def prepare_validation_reason_fixture(row: dict[str, str]) -> tuple[Path, Path]:
            fixture = row["fixture"]
            fixture_root = root / f"validation-{fixture.replace('_', '-')}"
            fixture_root.mkdir()
            producer_map = fixture_root / "producers.json"
            write_healthy_artifacts(fixture_root)
            if fixture == "missing_producer_steps":
                write_producer_map(producer_map, include_header_exact=False)
            elif fixture == "missing_required_smoke_gates":
                write_producer_map(producer_map, include_header_smoke=False, required_names=[HEADER_INSPECT_ARTIFACT])
            elif fixture == "missing_header_inspect_artifact":
                (fixture_root / HEADER_INSPECT_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "header_inspect_failed":
                write_header_summary(fixture_root / HEADER_INSPECT_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_header_workflows":
                write_header_summary(
                    fixture_root / HEADER_INSPECT_ARTIFACT,
                    missing=[{"command": "inspect-raw-header-file", "workflow": "file", "format": "raw"}],
                )
                write_producer_map(producer_map)
            elif fixture == "header_inspect_undercovered":
                write_header_summary(fixture_root / HEADER_INSPECT_ARTIFACT, undercovered=True)
                write_producer_map(producer_map)
            elif fixture == "missing_dashboard_strict_artifact":
                (fixture_root / DASHBOARD_STRICT_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "dashboard_strict_failed":
                write_dashboard_strict_summary(fixture_root / DASHBOARD_STRICT_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_dashboard_strict_modes":
                minimum = len(expected_validation_reasons)
                write_dashboard_strict_summary(
                    fixture_root / DASHBOARD_STRICT_ARTIFACT,
                    missing_modes=[
                        {
                            "mode": "strict-validation-health",
                            "min_checks": minimum,
                            "min_expected_failures": minimum,
                            "min_matched": minimum,
                        }
                    ],
                )
                write_producer_map(producer_map)
            elif fixture == "missing_sidecar_corrupt_artifact":
                (fixture_root / SIDECAR_CORRUPT_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "sidecar_corrupt_failed":
                write_sidecar_corrupt_report(fixture_root / SIDECAR_CORRUPT_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_huffman_length_artifact":
                (fixture_root / HUFFMAN_LENGTH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "huffman_length_failed":
                write_huffman_length_csv(fixture_root / HUFFMAN_LENGTH_ARTIFACT, optimal=False)
                write_producer_map(producer_map)
            elif fixture == "missing_fuzz_corpus_artifact":
                (fixture_root / FUZZ_CORPUS_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "fuzz_corpus_failed":
                write_fuzz_corpus_report(fixture_root / FUZZ_CORPUS_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_fuzz_coverage_artifact":
                (fixture_root / FUZZ_COVERAGE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "fuzz_coverage_failed":
                write_fuzz_coverage_report(fixture_root / FUZZ_COVERAGE_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_decode_stage_artifact":
                (fixture_root / DECODE_STAGE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "decode_stage_failed":
                write_decode_stage_report(fixture_root / DECODE_STAGE_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_python_zlib_diff_artifact":
                (fixture_root / PYTHON_ZLIB_DIFF_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "python_zlib_diff_failed":
                write_python_zlib_diff_report(fixture_root / PYTHON_ZLIB_DIFF_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            else:
                raise AssertionError(f"unsupported validation reason fixture {fixture!r}")
            return fixture_root, producer_map

        for row in expected_validation_reasons:
            fixture_root, fixture_producer_map = prepare_validation_reason_fixture(row)
            add_validation_reason_check(fixture_root, fixture_producer_map, row["check"], row["reason"])

        covered_validation_reasons = {str(row["reason"]) for row in validation_reason_checks}
        configured_validation_reasons = [row["reason"] for row in expected_validation_reasons]
        missing_validation_reasons = [reason for reason in configured_validation_reasons if reason not in covered_validation_reasons]
        extra_validation_reasons = sorted(covered_validation_reasons - set(configured_validation_reasons))
        if missing_validation_reasons or extra_validation_reasons:
            raise AssertionError(
                f"validation unhealthy reason coverage mismatch: missing={missing_validation_reasons!r} extra={extra_validation_reasons!r}"
            )

        long_output = "dashboard_index_synthetic_long_output=" + ("x" * 512)
        checks.append(check_row("truncated_output", "synthetic", False, True, 0, "dashboard_index_synthetic_long_output=", long_output))
        if not checks[-1]["actual_output_truncated"]:
            raise AssertionError("synthetic long-output check did not exercise truncation")

    mode_counts = build_mode_counts(checks)
    expected_modes = load_expected_modes()
    mode_requirement_rows = mode_requirements(mode_counts, expected_modes)
    missing_modes = missing_expected_modes(mode_requirement_rows)
    if missing_modes:
        raise AssertionError(f"missing dashboard strict mode coverage: {missing_modes!r}")
    summary = {
        "schema": "vort.dashboard_strict_smoke",
        "schema_version": 1,
        "ok": True,
        "check_count": len(checks),
        "checks": checks,
        "mode_count": len(mode_counts),
        "mode_counts": mode_counts,
        "expected_mode_count": len(expected_modes),
        "expected_modes": expected_modes,
        "mode_requirements": mode_requirement_rows,
        "missing_mode_count": len(missing_modes),
        "missing_modes": missing_modes,
        "validation_unhealthy_reason_count": len(validation_reason_checks),
        "validation_unhealthy_reason_checks": validation_reason_checks,
    }
    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    if args.markdown:
        write_markdown(Path(args.markdown), summary)
    print("dashboard_strict_smoke=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
