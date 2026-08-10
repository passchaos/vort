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
DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT = "vort-dashboard-config-index-smoke.json"
DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT = "vort-dashboard-config-index-negative-smoke.json"
DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT = "vort-dashboard-category-negative-smoke.json"
DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT = "vort-dashboard-producers-required-smoke.json"
DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT = "vort-dashboard-producers-negative-smoke.json"
VALIDATION_JSON_SMOKE_ARTIFACT = "vort-validation-json-smoke.json"
VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT = "vort-validation-json-docs-negative-smoke.json"
SIDECAR_CORRUPT_ARTIFACT = "vort-sidecar-corrupt-smoke.json"
HUFFMAN_LENGTH_ARTIFACT = "vort-huffman-length-report.csv"
CHECKSUM_BENCH_ARTIFACT = "vort-checksum-bench.csv"
CHUNK_CURSOR_BENCH_ARTIFACT = "vort-chunk-cursor-bench.csv"
DEFLATE_MATCH_COPY_BENCH_ARTIFACT = "vort-deflate-match-copy-bench.csv"
DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT = "vort-deflate-huffman-build-bench.csv"
DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT = "vort-deflate-huffman-lookup-bench.csv"
FUZZ_CORPUS_ARTIFACT = "vort-deflate-wrapper-fuzz-corpus.json"
FUZZ_COVERAGE_ARTIFACT = "vort-fuzz-corpus-coverage-smoke.json"
DECODE_STAGE_ARTIFACT = "vort-deflate-decode-stage-report.json"
PYTHON_ZLIB_DIFF_ARTIFACT = "vort-python-zlib-diff-smoke.json"
ZLIB_RELAXED_ARTIFACT = "vort-zlib-relaxed-report.json"
SNAPPY_REPORT_ARTIFACT = "vort-snappy-report.csv"
PNG_SCRATCH_ARTIFACT = "vort-png-scratch-report.json"
BR_STATIC_CANDIDATES_ARTIFACT = "vort-br-static-dictionary-candidates.json"
BR_STATIC_UPSTREAM_ARTIFACT = "vort-br-static-dictionary-candidate-upstream-smoke.json"
BR_STATIC_NODE_ARTIFACT = "vort-br-static-dictionary-node-probe.json"
BR_STATIC_AUDIT_ARTIFACT = "vort-br-static-dictionary-source-audit.json"
BR_STATIC_AUDIT_NEGATIVE_ARTIFACT = "vort-br-static-dictionary-source-audit-negative-smoke.json"
NATIVE_FUZZ_ARTIFACT = "vort-native-fuzz-corpus.json"
NATIVE_FUZZ_COVERAGE_ARTIFACT = "vort-native-fuzz-corpus-coverage-smoke.json"
NATIVE_ALLOCATION_REPORT_ARTIFACT = "vort-native-allocation-report.json"
NATIVE_ALLOCATION_SMOKE_ARTIFACT = "vort-native-allocation-smoke.json"
NATIVE_ALLOCATION_NEGATIVE_ARTIFACT = "vort-native-allocation-negative-smoke.json"
ZSTD_COMPARE_ARTIFACT = "vort-zstd-compare-gate.json"
ZSTD_COMPARE_STANDARD_ARTIFACT = "vort-zstd-compare-standard-gate.json"
ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT = "vort-zstd-compare-block-sweep-gate.json"
NATIVE_SUMMARY_ERROR_ARTIFACT = "vort-native-summary-error-dashboard.json"
NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT = "vort-native-summary-error-negative-smoke.json"
NATIVE_CODEC_PROBES_ARTIFACT = "vort-native-codec-probes.json"
LZ4_NATIVE_SUMMARY_ARTIFACT = "vort-lz4-native-stream-summary.json"
ZSTD_NATIVE_SUMMARY_ARTIFACT = "vort-zstd-native-stream-summary.json"
NATIVE_TIER_RANGE_ARTIFACT = "vort-native-tier-range-bench-gate.json"
NATIVE_TIER_RANGE_FILES_ARTIFACT = "vort-native-tier-range-files-bench-gate.json"
NATIVE_TIER_RANGE_CORPUS_ARTIFACT = "vort-native-tier-range-corpus-bench-gate.json"
NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT = "vort-native-tier-range-corpus-discovery.json"
NATIVE_TIER_RANGE_ARTIFACTS = (
    (NATIVE_TIER_RANGE_ARTIFACT, "zig build run-native-tier-range-bench-gate"),
    (NATIVE_TIER_RANGE_FILES_ARTIFACT, "zig build run-native-tier-range-files-bench-gate"),
    (NATIVE_TIER_RANGE_CORPUS_ARTIFACT, "zig build run-native-tier-range-corpus-bench-gate"),
    (NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT, "zig build run-native-tier-range-corpus-bench-gate"),
)
NATIVE_TIER_RANGE_FLOORS = {
    "built_in": {"seek_fast": 60.0, "balanced": 16.0, "ratio": 12.0},
    "project_files": {"seek_fast": 40.0, "balanced": 8.0, "ratio": 4.0},
    "standard_corpus": {"seek_fast": 30.0, "balanced": 6.5, "ratio": 3.5},
    "custom": {"seek_fast": 20.0, "balanced": 6.0, "ratio": 3.0},
}


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_producer_map(
    path: Path,
    *,
    include_header_exact: bool = True,
    include_header_smoke: bool = True,
    include_strict_exact: bool = True,
    include_strict_smoke: bool = True,
    include_dashboard_configuration_exact: bool = True,
    include_dashboard_configuration_smoke: bool = True,
    include_validation_json_exact: bool = True,
    include_validation_json_smoke: bool = True,
    include_sidecar_corrupt_exact: bool = True,
    include_sidecar_corrupt_smoke: bool = True,
    include_huffman_exact: bool = True,
    include_huffman_smoke: bool = True,
    include_checksum_bench_exact: bool = True,
    include_checksum_bench_smoke: bool = True,
    include_chunk_cursor_bench_exact: bool = True,
    include_chunk_cursor_bench_smoke: bool = True,
    include_deflate_match_copy_bench_exact: bool = True,
    include_deflate_match_copy_bench_smoke: bool = True,
    include_deflate_huffman_build_bench_exact: bool = True,
    include_deflate_huffman_build_bench_smoke: bool = True,
    include_deflate_huffman_lookup_bench_exact: bool = True,
    include_deflate_huffman_lookup_bench_smoke: bool = True,
    include_fuzz_corpus_exact: bool = True,
    include_fuzz_corpus_smoke: bool = True,
    include_fuzz_coverage_exact: bool = True,
    include_fuzz_coverage_smoke: bool = True,
    include_decode_stage_exact: bool = True,
    include_decode_stage_smoke: bool = True,
    include_python_zlib_exact: bool = True,
    include_python_zlib_smoke: bool = True,
    include_zlib_relaxed_exact: bool = True,
    include_zlib_relaxed_smoke: bool = True,
    include_snappy_report_exact: bool = True,
    include_snappy_report_smoke: bool = True,
    include_png_scratch_exact: bool = True,
    include_png_scratch_smoke: bool = True,
    include_br_static_exact: bool = True,
    include_br_static_smoke: bool = True,
    include_native_fuzz_exact: bool = True,
    include_native_fuzz_smoke: bool = True,
    include_native_allocation_exact: bool = True,
    include_native_allocation_smoke: bool = True,
    include_zstd_compare_exact: bool = True,
    include_zstd_compare_smoke: bool = True,
    include_native_summary_error_exact: bool = True,
    include_native_summary_error_smoke: bool = True,
    include_native_summary_error_negative_exact: bool = True,
    include_native_summary_error_negative_smoke: bool = True,
    include_native_codec_probes_exact: bool = True,
    include_native_codec_probes_smoke: bool = True,
    include_lz4_native_summary_exact: bool = True,
    include_lz4_native_summary_smoke: bool = True,
    include_zstd_native_summary_exact: bool = True,
    include_zstd_native_summary_smoke: bool = True,
    include_native_tier_exact: bool = True,
    include_native_tier_smoke: bool = True,
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
    if include_dashboard_configuration_smoke:
        for artifact, smoke_gate in (
            (DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT, "zig build run-dashboard-config-index-smoke"),
            (DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT, "zig build run-dashboard-config-index-negative-smoke"),
            (DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT, "zig build run-dashboard-category-negative-smoke"),
            (DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT, "zig build run-dashboard-producers-required-smoke"),
            (DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT, "zig build run-dashboard-producers-negative-smoke"),
        ):
            artifact_metadata[artifact] = {"expected_format": "json", "smoke_gate": smoke_gate}
    if include_validation_json_smoke:
        artifact_metadata[VALIDATION_JSON_SMOKE_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-validation-json-dashboard",
        }
        artifact_metadata[VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-validation-json-docs-negative-smoke",
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
    if include_checksum_bench_smoke:
        artifact_metadata[CHECKSUM_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build -Doptimize=ReleaseFast run-checksum-bench-gate",
        }
    if include_chunk_cursor_bench_smoke:
        artifact_metadata[CHUNK_CURSOR_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-chunk-cursor-bench-gate",
        }
    if include_deflate_match_copy_bench_smoke:
        artifact_metadata[DEFLATE_MATCH_COPY_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-match-copy-bench-gate",
        }
    if include_deflate_huffman_build_bench_smoke:
        artifact_metadata[DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-huffman-build-bench-gate",
        }
    if include_deflate_huffman_lookup_bench_smoke:
        artifact_metadata[DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-huffman-lookup-bench-gate",
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
    if include_zlib_relaxed_smoke:
        artifact_metadata[ZLIB_RELAXED_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-zlib-relaxed-report-gate",
        }
    if include_snappy_report_smoke:
        artifact_metadata[SNAPPY_REPORT_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-snappy-report-gate",
        }
    if include_png_scratch_smoke:
        artifact_metadata[PNG_SCRATCH_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-png-scratch-report-dashboard",
        }
    if include_br_static_smoke:
        for artifact, smoke_gate in (
            (BR_STATIC_CANDIDATES_ARTIFACT, "zig build run-br-static-dictionary-candidate-report-smoke"),
            (BR_STATIC_UPSTREAM_ARTIFACT, "zig build run-br-static-dictionary-candidate-upstream-smoke"),
            (BR_STATIC_NODE_ARTIFACT, "zig build run-br-static-dictionary-node-probe"),
            (BR_STATIC_AUDIT_ARTIFACT, "zig build run-br-static-dictionary-source-audit"),
            (BR_STATIC_AUDIT_NEGATIVE_ARTIFACT, "zig build run-br-static-dictionary-source-audit-negative-smoke"),
        ):
            artifact_metadata[artifact] = {"expected_format": "json", "smoke_gate": smoke_gate}
    if include_native_fuzz_smoke:
        artifact_metadata[NATIVE_FUZZ_ARTIFACT] = {"expected_format": "json", "smoke_gate": "zig build run-native-fuzz-corpus-dashboard"}
        artifact_metadata[NATIVE_FUZZ_COVERAGE_ARTIFACT] = {"expected_format": "json", "smoke_gate": "zig build run-native-fuzz-corpus-coverage-smoke"}
    if include_native_allocation_smoke:
        for artifact, smoke_gate in (
            (NATIVE_ALLOCATION_REPORT_ARTIFACT, "zig build run-native-allocation-report-dashboard"),
            (NATIVE_ALLOCATION_SMOKE_ARTIFACT, "zig build run-native-allocation-smoke"),
            (NATIVE_ALLOCATION_NEGATIVE_ARTIFACT, "zig build run-native-allocation-negative-smoke"),
        ):
            artifact_metadata[artifact] = {
                "expected_format": "json",
                "smoke_gate": smoke_gate,
            }
    if include_zstd_compare_smoke:
        for artifact, smoke_gate in (
            (ZSTD_COMPARE_ARTIFACT, "zig build run-zstd-compare-gate"),
            (ZSTD_COMPARE_STANDARD_ARTIFACT, "zig build run-zstd-compare-standard-gate"),
            (ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT, "zig build run-zstd-compare-block-sweep-gate"),
        ):
            artifact_metadata[artifact] = {
                "expected_format": "json",
                "smoke_gate": smoke_gate,
            }
    if include_native_summary_error_smoke:
        artifact_metadata[NATIVE_SUMMARY_ERROR_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-native-summary-error-dashboard",
        }
    if include_native_summary_error_negative_smoke:
        artifact_metadata[NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-native-summary-error-negative-smoke",
        }
    if include_native_codec_probes_smoke:
        artifact_metadata[NATIVE_CODEC_PROBES_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-native-codec-probes-dashboard",
        }
    if include_lz4_native_summary_smoke:
        artifact_metadata[LZ4_NATIVE_SUMMARY_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-lz4-native-summary-dashboard",
        }
    if include_zstd_native_summary_smoke:
        artifact_metadata[ZSTD_NATIVE_SUMMARY_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-zstd-native-summary-dashboard",
        }
    if include_native_tier_smoke:
        for artifact, smoke_gate in NATIVE_TIER_RANGE_ARTIFACTS:
            artifact_metadata[artifact] = {
                "expected_format": "json",
                "smoke_gate": smoke_gate,
            }
    exact = {}
    if include_header_exact:
        exact[HEADER_INSPECT_ARTIFACT] = "zig build run-header-inspect-dashboard"
    if include_strict_exact:
        exact[DASHBOARD_STRICT_ARTIFACT] = "zig build run-dashboard-strict-smoke"
    if include_dashboard_configuration_exact:
        exact[DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT] = "zig build run-dashboard-config-index-smoke"
        exact[DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT] = "zig build run-dashboard-config-index-negative-smoke"
        exact[DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT] = "zig build run-dashboard-category-negative-smoke"
        exact[DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT] = "zig build run-dashboard-producers-required-smoke"
        exact[DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT] = "zig build run-dashboard-producers-negative-smoke"
    if include_validation_json_exact:
        exact[VALIDATION_JSON_SMOKE_ARTIFACT] = "zig build run-validation-json-dashboard"
        exact[VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT] = "zig build run-validation-json-docs-negative-smoke"
    if include_sidecar_corrupt_exact:
        exact[SIDECAR_CORRUPT_ARTIFACT] = "zig build run-sidecar-corrupt-dashboard"
    if include_huffman_exact:
        exact[HUFFMAN_LENGTH_ARTIFACT] = "zig build run-huffman-length-report-dashboard"
    if include_checksum_bench_exact:
        exact[CHECKSUM_BENCH_ARTIFACT] = "zig build -Doptimize=ReleaseFast run-checksum-bench-gate"
    if include_chunk_cursor_bench_exact:
        exact[CHUNK_CURSOR_BENCH_ARTIFACT] = "zig build run-chunk-cursor-bench-gate"
    if include_deflate_match_copy_bench_exact:
        exact[DEFLATE_MATCH_COPY_BENCH_ARTIFACT] = "zig build run-deflate-match-copy-bench-gate"
    if include_deflate_huffman_build_bench_exact:
        exact[DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT] = "zig build run-deflate-huffman-build-bench-gate"
    if include_deflate_huffman_lookup_bench_exact:
        exact[DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT] = "zig build run-deflate-huffman-lookup-bench-gate"
    if include_fuzz_corpus_exact:
        exact[FUZZ_CORPUS_ARTIFACT] = "zig build run-deflate-wrapper-fuzz-corpus-dashboard"
    if include_fuzz_coverage_exact:
        exact[FUZZ_COVERAGE_ARTIFACT] = "zig build run-fuzz-corpus-coverage-smoke"
    if include_decode_stage_exact:
        exact[DECODE_STAGE_ARTIFACT] = "zig build run-deflate-decode-stage-report-dashboard"
    if include_python_zlib_exact:
        exact[PYTHON_ZLIB_DIFF_ARTIFACT] = "zig build run-python-zlib-diff-dashboard"
    if include_zlib_relaxed_exact:
        exact[ZLIB_RELAXED_ARTIFACT] = "zig build run-zlib-relaxed-report-gate"
    if include_snappy_report_exact:
        exact[SNAPPY_REPORT_ARTIFACT] = "zig build run-snappy-report-gate"
    if include_png_scratch_exact:
        exact[PNG_SCRATCH_ARTIFACT] = "zig build run-png-scratch-report-dashboard"
    if include_br_static_exact:
        exact[BR_STATIC_CANDIDATES_ARTIFACT] = "zig build run-br-static-dictionary-candidate-report-smoke"
        exact[BR_STATIC_UPSTREAM_ARTIFACT] = "zig build run-br-static-dictionary-candidate-upstream-smoke"
        exact[BR_STATIC_NODE_ARTIFACT] = "zig build run-br-static-dictionary-node-probe"
        exact[BR_STATIC_AUDIT_ARTIFACT] = "zig build run-br-static-dictionary-source-audit"
        exact[BR_STATIC_AUDIT_NEGATIVE_ARTIFACT] = "zig build run-br-static-dictionary-source-audit-negative-smoke"
    if include_native_fuzz_exact:
        exact[NATIVE_FUZZ_ARTIFACT] = "zig build run-native-fuzz-corpus-dashboard"
        exact[NATIVE_FUZZ_COVERAGE_ARTIFACT] = "zig build run-native-fuzz-corpus-coverage-smoke"
    if include_native_allocation_exact:
        exact[NATIVE_ALLOCATION_REPORT_ARTIFACT] = "zig build run-native-allocation-report-dashboard"
        exact[NATIVE_ALLOCATION_SMOKE_ARTIFACT] = "zig build run-native-allocation-smoke"
        exact[NATIVE_ALLOCATION_NEGATIVE_ARTIFACT] = "zig build run-native-allocation-negative-smoke"
    if include_zstd_compare_exact:
        exact[ZSTD_COMPARE_ARTIFACT] = "zig build run-zstd-compare-gate"
        exact[ZSTD_COMPARE_STANDARD_ARTIFACT] = "zig build run-zstd-compare-standard-gate"
        exact[ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT] = "zig build run-zstd-compare-block-sweep-gate"
    if include_native_summary_error_exact:
        exact[NATIVE_SUMMARY_ERROR_ARTIFACT] = "zig build run-native-summary-error-dashboard"
    if include_native_summary_error_negative_exact:
        exact[NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT] = "zig build run-native-summary-error-negative-smoke"
    if include_native_codec_probes_exact:
        exact[NATIVE_CODEC_PROBES_ARTIFACT] = "zig build run-native-codec-probes-dashboard"
    if include_lz4_native_summary_exact:
        exact[LZ4_NATIVE_SUMMARY_ARTIFACT] = "zig build run-lz4-native-summary-dashboard"
    if include_zstd_native_summary_exact:
        exact[ZSTD_NATIVE_SUMMARY_ARTIFACT] = "zig build run-zstd-native-summary-dashboard"
    if include_native_tier_exact:
        for artifact, smoke_gate in NATIVE_TIER_RANGE_ARTIFACTS:
            exact[artifact] = smoke_gate
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


def write_dashboard_configuration_artifacts(root: Path) -> None:
    config_index_smoke = {
        "schema": "vort.dashboard_config_index_smoke",
        "schema_version": 1,
        "ok": True,
        "config_count": 3,
        "configs": [
            {
                "path": "tools/dashboard_category_expected_artifacts.json",
                "schema_name": "vort.dashboard_category_expected_artifacts",
                "docs_section": "## `vort.dashboard_category_expected_artifacts`",
                "validation_step": "zig build run-dashboard-category-smoke",
                "consumer": "tools/dashboard_category_smoke.py",
                "path_exists": True,
                "schema_matches": True,
                "docs_section_present": True,
                "validation_step_present": True,
                "consumer_exists": True,
                "manifest_schema_present": True,
                "validation_json_smoke_checked": True,
                "matched": True,
            },
            {
                "path": "tools/dashboard_producers_required_artifacts.json",
                "schema_name": "vort.dashboard_producers_required_artifacts",
                "docs_section": "## `vort.dashboard_producers_required_artifacts`",
                "validation_step": "zig build run-dashboard-producers-required-smoke",
                "consumer": "tools/dashboard_producers_required_smoke.py",
                "path_exists": True,
                "schema_matches": True,
                "docs_section_present": True,
                "validation_step_present": True,
                "consumer_exists": True,
                "manifest_schema_present": True,
                "validation_json_smoke_checked": True,
                "matched": True,
            },
            {
                "path": "tools/dashboard_strict_expected_modes.json",
                "schema_name": "vort.dashboard_strict_expected_modes",
                "docs_section": "## `vort.dashboard_strict_expected_modes`",
                "validation_step": "zig build run-dashboard-strict-smoke",
                "consumer": "tools/dashboard_strict_smoke.py",
                "path_exists": True,
                "schema_matches": True,
                "docs_section_present": True,
                "validation_step_present": True,
                "consumer_exists": True,
                "manifest_schema_present": True,
                "validation_json_smoke_checked": True,
                "matched": True,
            },
        ],
    }
    config_negative = {
        "schema": "vort.dashboard_config_index_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 2,
        "cases": [
            check_row("missing_config_path", "synthetic", True, True, 1, '"path_exists": false', '"path_exists": false'),
            check_row("schema_mismatch", "synthetic", True, True, 1, '"schema_matches": false', '"schema_matches": false'),
        ],
    }
    category_negative = {
        "schema": "vort.dashboard_category_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 3,
        "cases": [
            check_row("classifier_category_mismatch", "synthetic", True, True, 1, "classifier category='benchmark', expected 'validation'", "classifier category='benchmark', expected 'validation'"),
            check_row("missing_required_artifact", "synthetic", True, True, 1, "missing dashboard artifact 'vort-header-inspect-smoke.json'", "missing dashboard artifact 'vort-header-inspect-smoke.json'"),
            check_row("missing_required_smoke_gate", "synthetic", True, True, 1, "missing smoke_gate for 'vort-header-inspect-smoke.json'", "missing smoke_gate for 'vort-header-inspect-smoke.json'"),
        ],
    }
    required_cases = [
        {
            "name": HEADER_INSPECT_ARTIFACT,
            "expected_format": "json",
            "configured_expected_format": "json",
            "producer_step": "zig build run-header-inspect-dashboard",
            "configured_producer_step": "zig build run-header-inspect-dashboard",
            "smoke_gate": "zig build run-header-inspect-dashboard",
            "configured_smoke_gate": "zig build run-header-inspect-dashboard",
            "required_smoke_gate": True,
            "configured_required_smoke_gate": True,
            "matched": True,
        },
        {
            "name": DASHBOARD_STRICT_ARTIFACT,
            "expected_format": "json",
            "configured_expected_format": "json",
            "producer_step": "zig build run-dashboard-strict-smoke",
            "configured_producer_step": "zig build run-dashboard-strict-smoke",
            "smoke_gate": "zig build run-dashboard-strict-smoke",
            "configured_smoke_gate": "zig build run-dashboard-strict-smoke",
            "required_smoke_gate": True,
            "configured_required_smoke_gate": True,
            "matched": True,
        },
        {
            "name": DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT,
            "expected_format": "json",
            "configured_expected_format": "json",
            "producer_step": "zig build run-dashboard-config-index-smoke",
            "configured_producer_step": "zig build run-dashboard-config-index-smoke",
            "smoke_gate": "zig build run-dashboard-config-index-smoke",
            "configured_smoke_gate": "zig build run-dashboard-config-index-smoke",
            "required_smoke_gate": False,
            "configured_required_smoke_gate": False,
            "matched": True,
        },
        {
            "name": DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT,
            "expected_format": "json",
            "configured_expected_format": "json",
            "producer_step": "zig build run-dashboard-producers-required-smoke",
            "configured_producer_step": "zig build run-dashboard-producers-required-smoke",
            "smoke_gate": "zig build run-dashboard-producers-required-smoke",
            "configured_smoke_gate": "zig build run-dashboard-producers-required-smoke",
            "required_smoke_gate": False,
            "configured_required_smoke_gate": False,
            "matched": True,
        },
    ]
    producers_required = {
        "schema": "vort.dashboard_producers_required_smoke",
        "schema_version": 1,
        "ok": True,
        "artifact_count": len(required_cases),
        "required_smoke_gate_count": sum(1 for case in required_cases if case["required_smoke_gate"]),
        "cases": required_cases,
    }
    producers_negative = {
        "schema": "vort.dashboard_producers_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 2,
        "cases": [
            check_row("expected_format_mismatch", "synthetic", True, True, 1, "expected format 'md' but found '.json'", "expected format 'md' but found '.json'"),
            check_row("missing_producer_step", "synthetic", True, True, 1, "dashboard_index_missing_producers=vort-validation-producer-unmapped.json", "dashboard_index_missing_producers=vort-validation-producer-unmapped.json"),
        ],
    }
    for name, payload in (
        (DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT, config_index_smoke),
        (DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT, config_negative),
        (DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT, category_negative),
        (DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT, producers_required),
        (DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT, producers_negative),
    ):
        (root / name).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_validation_json_artifacts(root: Path) -> None:
    validation_smoke = {
        "schema": "vort.validation_json_smoke",
        "schema_version": 1,
        "ok": True,
        "checked_schemas": [
            "vort.validation_report",
            "vort.dashboard_index",
            "vort.dashboard_strict_smoke",
            "vort.header_inspect_smoke",
            "vort.gzip_header_info",
        ],
        "cli_success_ok": True,
        "cli_failure_ok": False,
        "cli_failure_hint": "payload_corrupt",
        "report_rows": 1,
        "corrupt_rows": 2,
    }
    docs_negative = {
        "schema": "vort.validation_json_docs_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 2,
        "cases": [
            {
                "name": "missing_reason_config",
                "expected_failure": True,
                "expected_error": "differs from dashboard index enum",
                "actual_error": "differs from dashboard index enum",
                "matched": True,
            },
            {
                "name": "boolean_formula_positive_field",
                "expected_failure": True,
                "expected_error": "does not match boolean formula",
                "actual_error": "does not match boolean formula",
                "matched": True,
            },
        ],
    }
    (root / VALIDATION_JSON_SMOKE_ARTIFACT).write_text(json.dumps(validation_smoke, indent=2, sort_keys=True) + "\n")
    (root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).write_text(json.dumps(docs_negative, indent=2, sort_keys=True) + "\n")


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


def write_checksum_bench_csv(path: Path, *, healthy: bool = True) -> None:
    algorithms = [
        "adler32",
        "crc32-scalar",
        "crc32-slice4",
        "crc32-slice8",
        "crc32-slice16",
        "crc32-slice32",
        "crc32-slice32-seg64",
        "crc32-slice32-seg256",
        "crc32-slice32-seg1024",
        "crc32-slice32-seg4096",
        "crc32-slice32-span-threshold256",
        "crc32-slice32-span-threshold1024",
        "crc32-slice32-span-threshold2048",
        "crc32-slice32-span-threshold4096",
        "crc32-slice32-selective4096",
        "crc32-best",
        "crc32c-scalar",
        "crc32c-slice8",
        "crc32c-slice16",
        "crc32c-slice32",
        "crc32c-best",
    ]
    columns = ["algorithm", "bytes", "iterations", "elapsed_s", "throughput_mib_s", "mix"]
    lines = [",".join(columns)]
    for algorithm in algorithms:
        if not healthy and algorithm == "crc32c-best":
            continue
        mix = "287916550677" if algorithm.startswith("crc32c-") else "267872580117"
        if algorithm == "adler32":
            mix = "255981175488"
        lines.append(",".join([algorithm, str(1 << 20), "128", "0.1", "1000.0", mix]))
    path.write_text("\n".join(lines) + "\n")


def write_chunk_cursor_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "operation",
        "kernel",
        "payload_bytes",
        "chunk_bytes",
        "chunk_count",
        "include_empty_chunks",
        "iterations",
        "elapsed_ns",
        "bytes_per_s",
        "mib_per_s",
        "checksum",
    ]
    cases = {
        "read-1b-empty": ("read-byte", 8 * 1024, 1, "true"),
        "copy-1b-empty": ("copy-to", 8 * 1024, 1, "true"),
        "copy-7b-empty": ("copy-to", 32 * 1024, 7, "true"),
        "copy-256b": ("copy-to", 64 * 1024, 256, "false"),
    }
    kernels = ("current", "skip_empty_advance")

    def chunk_count(payload_bytes: int, chunk_bytes: int, include_empty: str) -> int:
        non_empty = (payload_bytes + chunk_bytes - 1) // chunk_bytes
        return non_empty * 2 + 1 if include_empty == "true" else non_empty

    lines = [",".join(columns)]
    for case, (operation, payload_bytes, chunk_bytes, include_empty) in cases.items():
        for kernel in kernels:
            if not healthy and case == "copy-256b" and kernel == "skip_empty_advance":
                continue
            lines.append(
                ",".join(
                    [
                        case,
                        operation,
                        kernel,
                        str(payload_bytes),
                        str(chunk_bytes),
                        str(chunk_count(payload_bytes, chunk_bytes, include_empty)),
                        include_empty,
                        "128",
                        "1000",
                        "1000000.0",
                        "1.0",
                        "12345",
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_deflate_match_copy_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "class",
        "kernel",
        "length",
        "distance",
        "ops_per_iter",
        "iterations",
        "output_bytes",
        "elapsed_ns",
        "output_mib_per_s",
        "checksum",
    ]
    cases = {
        "rle-long": "rle",
        "small-distance-long": "small_distance",
        "nonoverlap-len3": "non_overlapping",
        "nonoverlap-len6": "non_overlapping",
        "nonoverlap-len32": "non_overlapping",
        "overlap-text-like": "overlapping",
        "overlap-distance-heavy": "overlapping",
    }
    kernels = ("current", "nonoverlap_first", "small_unrolled")
    lines = [",".join(columns)]
    for case, class_name in cases.items():
        for kernel in kernels:
            if not healthy and case == "overlap-distance-heavy" and kernel == "small_unrolled":
                continue
            lines.append(",".join([case, class_name, kernel, "258", "16", "1024", "64", "16777216", "1000", "1000.0", "12345"]))
    path.write_text("\n".join(lines) + "\n")


def write_deflate_huffman_build_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = ["case", "build", "lookup_bits", "symbols", "iterations", "elapsed_ns", "builds_per_s", "checksum"]
    expected = {
        "literal-mixed": [("table", 0, 286), ("fast9", 9, 286), ("fast11", 11, 286), ("fast12", 12, 286)],
        "literal-long-tail": [("table", 0, 286), ("fast9", 9, 286), ("fast11", 11, 286), ("fast12", 12, 286)],
        "distance-mixed": [("table", 0, 30), ("fast5", 5, 30), ("fast8", 8, 30)],
        "code-length": [("table", 0, 6), ("fast5", 5, 6), ("fast7", 7, 6)],
    }
    lines = [",".join(columns)]
    for case, rows in expected.items():
        for build, lookup_bits, symbols in rows:
            if not healthy and case == "code-length" and build == "fast7":
                continue
            lines.append(",".join([case, build, str(lookup_bits), str(symbols), "4096", "1000", "1000.0", "12345"]))
    path.write_text("\n".join(lines) + "\n")


def write_deflate_huffman_lookup_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = ["case", "decoder", "lookup_bits", "symbols_per_iter", "iterations", "input_bytes", "elapsed_ns", "symbols_per_s", "mib_per_s", "checksum"]
    expected = {
        "fixed-literal": [("table", 0), ("fixed_fast", 9), ("fast9", 9)],
        "fixed-distance": [("table", 0), ("fixed_fast", 9), ("fast5", 5), ("fast8", 8)],
        "code-length": [("table", 0), ("fast5", 5), ("fast7", 7)],
        "dynamic-mixed": [("table", 0), ("fast9", 9), ("fast11", 11), ("fast12", 12)],
        "dynamic-long-tail": [("table", 0), ("fast9", 9), ("fast11", 11), ("fast12", 12)],
        "dynamic-distance": [("table", 0), ("fast5", 5), ("fast8", 8)],
    }
    lines = [",".join(columns)]
    for case, rows in expected.items():
        for decoder, lookup_bits in rows:
            if not healthy and case == "dynamic-distance" and decoder == "fast8":
                continue
            lines.append(",".join([case, decoder, str(lookup_bits), "131072", "96", "1048576", "1000", "1000.0", "1.0", "12345"]))
    path.write_text("\n".join(lines) + "\n")


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
                "repeat": 1,
                "raw_mib_s": 1.0,
                "raw_exact_mib_s": 1.0,
                "raw_into_mib_s": 1.0,
                "zlib_mib_s": 1.0,
                "zlib_exact_mib_s": 1.0,
                "zlib_into_mib_s": 1.0,
                "zlib_into_no_adler_mib_s": 1.0,
                "zlib_into_no_adler_over_strict": 1.0,
                "gzip_mib_s": 1.0,
                "gzip_no_crc_mib_s": 1.0,
                "gzip_no_crc_over_strict": 1.0,
                "gzip_exact_mib_s": 1.0,
                "gzip_exact_no_crc_mib_s": 1.0,
                "gzip_exact_no_crc_over_strict": 1.0,
                "gzip_into_mib_s": 1.0,
                "gzip_into_no_crc_mib_s": 1.0,
                "gzip_into_no_crc_over_strict": 1.0,
                "gzip_into_no_isize_mib_s": 1.0,
                "gzip_into_no_isize_over_strict": 1.0,
                "gzip_into_relaxed_mib_s": 1.0,
                "gzip_into_relaxed_over_strict": 1.0,
                "adler32_mib_s": 1.0,
                "zlib_adler_time_ratio": 1.0,
                "crc32_mib_s": 1.0,
                "gzip_crc_time_ratio": 1.0,
                "raw_stored_mib_s": 0.0,
                "raw_stored_exact_mib_s": 0.0,
                "raw_stored_into_mib_s": 0.0,
                "zlib_stored_mib_s": 0.0,
                "zlib_stored_exact_mib_s": 0.0,
                "zlib_stored_into_mib_s": 0.0,
                "gzip_stored_mib_s": 0.0,
                "gzip_stored_exact_mib_s": 0.0,
                "gzip_stored_into_mib_s": 0.0,
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
                "raw_stored_alloc_time_ratio": 0.0,
                "zlib_stored_alloc_time_ratio": 0.0,
                "gzip_stored_alloc_time_ratio": 0.0,
                "raw_stored_alloc_exact_time_ratio": 0.0,
                "zlib_stored_alloc_exact_time_ratio": 0.0,
                "gzip_stored_alloc_exact_time_ratio": 0.0,
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
        "schema_version": 3,
        "ok": ok,
        "payloads": 3,
        "large_file_payloads": 1,
        "file_hex_encode_cases": 3,
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


def write_zlib_relaxed_report(path: Path) -> None:
    payload = {
        "schema": "vort.zlib_relaxed_report",
        "schema_version": 4,
        "strict_rejections": 2,
        "relaxed_successes": 5,
        "dictionary_successes": 2,
        "zlib_concatenated_successes": 3,
        "zlib_decoder_successes": 8,
        "limited_rejections": 1,
        "gzip_strict_rejections": 3,
        "gzip_relaxed_successes": 9,
        "gzip_concatenated_successes": 4,
        "gzip_decoder_successes": 4,
        "gzip_limited_rejections": 1,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_snappy_report_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "mode",
        "case",
        "input_bytes",
        "encoded_bytes",
        "ratio",
        "iterations",
        "encode_ns",
        "decode_ns",
        "encode_mib_s",
        "decode_mib_s",
        "checksum",
    ]
    cases = {
        "tiny": (12, 14, 30),
        "text": (31744, 1622, 1640),
        "structured": (38400, 1974, 1992),
        "repetitive": (32768, 512, 530),
        "incompressible": (4096, 4100, 4118),
    }
    modes = ("raw_block", "framed", "raw_block_reusable", "framed_reusable")
    lines = [",".join(columns)]
    for mode in modes:
        for case, (input_bytes, raw_bytes, framed_bytes) in cases.items():
            encoded_bytes = raw_bytes if "raw_block" in mode else framed_bytes
            if not healthy and mode == "framed_reusable" and case == "repetitive":
                encoded_bytes = input_bytes
            ratio = encoded_bytes / input_bytes
            lines.append(
                ",".join(
                    [
                        mode,
                        case,
                        str(input_bytes),
                        str(encoded_bytes),
                        f"{ratio:.6f}",
                        "25",
                        "1000",
                        "1000",
                        "1.0",
                        "1.0",
                        "12345",
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_png_scratch_report(path: Path) -> None:
    cases = [
        {
            "case": "png_rgb8_noninterlaced",
            "interlace": "none",
            "width": 5,
            "height": 5,
            "bit_depth": 8,
            "color_type": "truecolor",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 80,
            "filtered_row_scratch_bytes": 15,
            "previous_row_scratch_bytes": 15,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 75,
            "working_scratch_bytes": 110,
            "streaming_working_scratch_bytes": 30,
            "fixed_dynamic_streaming_working_scratch_bytes": 32798,
            "streaming_scratch_savings_bytes": 80,
            "streaming_scratch_ratio_x10000": 2727,
            "total_caller_owned_bytes": 185,
            "streaming_total_caller_owned_bytes": 105,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 32873,
        },
        {
            "case": "png_rgb8_adam7",
            "interlace": "adam7",
            "width": 5,
            "height": 5,
            "bit_depth": 8,
            "color_type": "truecolor",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 86,
            "filtered_row_scratch_bytes": 15,
            "previous_row_scratch_bytes": 15,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 75,
            "working_scratch_bytes": 116,
            "streaming_working_scratch_bytes": 30,
            "fixed_dynamic_streaming_working_scratch_bytes": 32798,
            "streaming_scratch_savings_bytes": 86,
            "streaming_scratch_ratio_x10000": 2586,
            "total_caller_owned_bytes": 191,
            "streaming_total_caller_owned_bytes": 105,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 32873,
        },
    ]
    payload = {"schema": "vort.png_scratch_report", "schema_version": 1, "case_count": len(cases), "cases": cases}
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_fuzz_corpus_artifacts(root: Path) -> None:
    report = {
        "schema": "vort.fuzz_corpus_report",
        "schema_version": 1,
        "ok": True,
        "mode": "native",
        "cases": 3,
        "accepted": 1,
        "rejected": 2,
        "exact_error_expectations": 2,
        "matched_rows": 3,
        "mode_count_rows": 1,
        "error_count_rows": 2,
        "items": [],
        "mode_counts": [{"mode": "native", "cases": 3, "accepted": 1, "rejected": 2, "exact_error_expectations": 2, "matched_rows": 3}],
        "error_counts": [{"mode": "native", "error": "InvalidMagic", "count": 1}, {"mode": "native", "error": "TruncatedFrame", "count": 1}],
    }
    coverage = {
        "schema": "vort.fuzz_corpus_coverage_smoke",
        "schema_version": 1,
        "ok": True,
        "report": str(root / NATIVE_FUZZ_ARTIFACT),
        "coverage": "tools/native_fuzz_corpus_expected_coverage.json",
        "mode_requirement_count": 1,
        "error_requirement_count": 2,
        "mode_requirements": [{"mode": "native", "min_cases": 1, "actual_cases": 3, "min_accepted": 1, "actual_accepted": 1, "min_rejected": 1, "actual_rejected": 2, "min_exact_error_expectations": 1, "actual_exact_error_expectations": 2, "min_matched_rows": 1, "actual_matched_rows": 3, "matched": True}],
        "error_requirements": [{"mode": "native", "error": "InvalidMagic", "min_count": 1, "actual_count": 1, "matched": True}, {"mode": "native", "error": "TruncatedFrame", "min_count": 1, "actual_count": 1, "matched": True}],
    }
    (root / NATIVE_FUZZ_ARTIFACT).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    (root / NATIVE_FUZZ_COVERAGE_ARTIFACT).write_text(json.dumps(coverage, indent=2, sort_keys=True) + "\n")


def write_br_static_dictionary_artifacts(root: Path) -> None:
    candidates = {
        "schema": "vort.br_static_dictionary_candidate_report",
        "schema_version": 1,
        "source_mode": "anchors",
        "source_limit": 0,
        "source_entry_count": 83,
        "raw_word_count": 143,
        "upstream_raw_word_count": 0,
        "transform_count": 6,
        "candidate_count": 775,
        "kind_rows": [{"transform_kind": "identity", "candidate_count": 81}, {"transform_kind": "affix_identity", "candidate_count": 417}, {"transform_kind": "omit_last_1", "candidate_count": 139}, {"transform_kind": "uppercase_first", "candidate_count": 138}],
        "length_rows": [{"copy_len": 4, "candidate_count": 480}, {"copy_len": 5, "candidate_count": 295}],
        "candidates": [{"word": "test", "copy_len": 4, "transform_kind": "identity"}],
    }
    upstream = {
        "schema": "vort.br_static_dictionary_candidate_upstream_smoke",
        "schema_version": 1,
        "ok": True,
        "source_mode": "upstream",
        "source_limit": 8,
        "source_entry_count": 83,
        "raw_word_count": 143,
        "anchor_raw_word_count": 143,
        "upstream_raw_word_count": 8,
        "candidate_count": 775,
        "stdout": "br_static_dictionary_candidate_report=ok source_entries=83 raw_words=143 candidates=775",
    }
    node = {
        "schema": "vort.br_static_dictionary_node_probe",
        "schema_version": 1,
        "ok": True,
        "candidate_source_mode": "anchors",
        "candidate_source_limit": 0,
        "candidate_upstream_raw_word_count": 0,
        "all_candidates": False,
        "start_index": 0,
        "probed_count": 48,
        "node_decode_successes": 48,
        "size_winner_count": 1,
        "kind_rows": [{"transform_kind": "identity", "probed_count": 48}],
        "size_rows": [{"size_class": "smaller", "probed_count": 48}],
        "size_winner_rows": [{"size_class": "smaller", "probed_count": 48}],
    }
    audit = {
        "schema": "vort.br_static_dictionary_source_audit",
        "schema_version": 1,
        "ok": True,
        "entry_count": 83,
        "anchor_count": 83,
        "generated_table_matches_source": True,
        "generated_zig_bytes": 4096,
        "generated_zig_path": "zig-out/vort-br-static-dictionary-generated.zig",
        "length_count": 2,
        "transform_count": 4,
        "operation_counts": {"identity": 80, "uppercase_first": 3},
        "source_checked": False,
        "source_dir": "",
    }
    negative = {
        "schema": "vort.br_static_dictionary_source_audit_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 1,
        "cases": [{"name": "bad_anchor_count", "expected_failure": True, "expected_error": "anchor_count mismatch", "actual_error": "anchor_count mismatch", "matched": True}],
    }
    for artifact, payload in (
        (BR_STATIC_CANDIDATES_ARTIFACT, candidates),
        (BR_STATIC_UPSTREAM_ARTIFACT, upstream),
        (BR_STATIC_NODE_ARTIFACT, node),
        (BR_STATIC_AUDIT_ARTIFACT, audit),
        (BR_STATIC_AUDIT_NEGATIVE_ARTIFACT, negative),
    ):
        (root / artifact).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_allocation_artifacts(root: Path) -> None:
    report = {
        "schema": "vort.native_allocation_report",
        "schema_version": 1,
        "case_count": 3,
        "cases": [
            {"case": "zero_decode", "input_bytes": 16, "output_bytes": 16, "allocations": 0, "deallocations": 0, "allocated_bytes": 0, "freed_bytes": 0},
            {"case": "zero_range", "input_bytes": 32, "output_bytes": 8, "allocations": 0, "deallocations": 0, "allocated_bytes": 0, "freed_bytes": 0},
            {"case": "budgeted_index", "input_bytes": 64, "output_bytes": 16, "allocations": 1, "deallocations": 1, "allocated_bytes": 80, "freed_bytes": 80},
        ],
    }
    smoke = {
        "schema": "vort.native_allocation_smoke",
        "schema_version": 1,
        "ok": True,
        "report": str(root / NATIVE_ALLOCATION_REPORT_ARTIFACT),
        "required_zero_allocation_cases": 2,
        "required_budget_cases": 1,
        "cases": [
            {"case": "zero_decode", "present": True, "matched": True, "allocations": 0, "deallocations": 0, "allocated_bytes": 0, "freed_bytes": 0},
            {"case": "zero_range", "present": True, "matched": True, "allocations": 0, "deallocations": 0, "allocated_bytes": 0, "freed_bytes": 0},
        ],
        "budget_cases": [
            {"case": "budgeted_index", "present": True, "matched": True, "balanced": True, "allocations": 1, "deallocations": 1, "allocated_bytes": 80, "freed_bytes": 80, "max_allocations": 1, "max_deallocations": 1, "max_allocated_bytes": 80, "max_freed_bytes": 80},
        ],
    }
    negative = {
        "schema": "vort.native_allocation_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 1,
        "cases": [
            {"name": "zero_case_allocates", "expected_failure": True, "expected_error": "expected zero allocations", "actual_error": "expected zero allocations", "matched": True},
        ],
    }
    (root / NATIVE_ALLOCATION_REPORT_ARTIFACT).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    (root / NATIVE_ALLOCATION_SMOKE_ARTIFACT).write_text(json.dumps(smoke, indent=2, sort_keys=True) + "\n")
    (root / NATIVE_ALLOCATION_NEGATIVE_ARTIFACT).write_text(json.dumps(negative, indent=2, sort_keys=True) + "\n")



def write_zstd_compare_artifacts(root: Path) -> None:
    compare = {
        "schema": "vort.zstd_compare_gate",
        "schema_version": 1,
        "ok": True,
        "data_rows": 2,
        "case_limit": "none",
        "csv": "zig-out/vort-zstd-compare.csv",
        "markdown": "zig-out/vort-zstd-compare.md",
        "native_block_len": 8192,
        "optimize": "Debug",
        "size_mode": "full",
        "source_mode": "default-samples",
        "decode_repeats": 3,
        "total_ratio": 1.04,
        "total_native_ratio": 1.18,
        "total_native_stream_ratio": 1.16,
        "total_embedded_over_native_best": 1.15,
        "total_embedded_over_native_best_bytes": 11279,
        "total_embedded_over_native_best_pct": 15.0,
        "total_embedded_over_native_stream": 1.02,
        "total_embedded_over_native_stream_bytes": 1312,
        "total_embedded_over_native_stream_pct": 1.5,
        "total_stream_over_native_best": 1.13,
        "total_stream_over_native_best_bytes": 9967,
        "total_stream_over_native_best_pct": 13.3,
        "total_zstd_decode_mib_s": 90.0,
        "total_vort_decode_vs_zstd": 0.71,
        "total_vort_raw_fixed_decode_mib_s": 64.0,
        "total_vort_native_decode_mib_s": 73.0,
        "total_vort_native_decode_vs_zstd": 0.81,
        "total_vort_native_best_decode_mib_s": 96.0,
        "total_vort_native_best_decode_vs_zstd": 1.07,
        "rows": [],
    }
    standard = dict(compare)
    standard.update({
        "case_limit": "3",
        "csv": "zig-out/vort-zstd-compare-standard.csv",
        "markdown": "zig-out/vort-zstd-compare-standard.md",
        "source_mode": "standard-suite",
        "size_mode": "bounded-128KiB",
        "data_rows": 3,
        "total_native_ratio": 1.13,
        "total_native_stream_ratio": 1.12,
        "total_vort_decode_vs_zstd": 0.74,
    })
    sweep = {
        "schema": "vort.zstd_compare_block_sweep_gate",
        "schema_version": 1,
        "ok": True,
        "data_rows": 15,
        "total_rows": 5,
        "case_limit": "3",
        "csv": "zig-out/vort-zstd-compare-block-sweep.csv",
        "markdown": "zig-out/vort-zstd-compare-block-sweep.md",
        "optimize": "Debug",
        "source_mode": "standard-suite",
        "size_mode": "bounded-128KiB",
        "path_count": 3,
        "block_len_count": 5,
        "block_lens": [4096, 8192, 16384, 32768, 65536],
        "best_block_len": 65536,
        "best_seekability_tier": "ratio",
        "best_native_stream_bytes": 110784,
        "best_native_stream_ratio": 1.01,
        "best_stream_over_native_best": 1.02,
        "best_stream_over_native_best_bytes": 2621,
        "best_embedded_over_native_stream": 1.003,
        "best_embedded_over_native_stream_bytes": 288,
        "best_range_decode_mib_s": 3.47,
        "best_range_decode_full_input_mib_s": 111.0,
        "rows": [],
    }
    (root / ZSTD_COMPARE_ARTIFACT).write_text(json.dumps(compare, indent=2, sort_keys=True) + "\n")
    (root / ZSTD_COMPARE_STANDARD_ARTIFACT).write_text(json.dumps(standard, indent=2, sort_keys=True) + "\n")
    (root / ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT).write_text(json.dumps(sweep, indent=2, sort_keys=True) + "\n")


def write_native_summary_error_dashboard(path: Path, *, healthy: bool = True) -> None:
    required_phases = ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"]
    payload = {
        "schema": "vort.native_summary_error_dashboard",
        "schema_version": 1,
        "ok": healthy,
        "case_count": 14 if healthy else 1,
        "lz4_case_count": 7 if healthy else 1,
        "zstd_case_count": 7 if healthy else 0,
        "error_counts": {"ChecksumMismatch": 1 if healthy else 0, "CorruptFrame": 4 if healthy else 1, "InvalidMagic": 1, "TruncatedFrame": 8 if healthy else 0},
        "phase_counts": {"magic": 2 if healthy else 1, "skippable_payload": 2 if healthy else 0, "frame_header": 3 if healthy else 0, "frame_body": 2 if healthy else 0, "frame_checksum": 2 if healthy else 0, "frame": 2 if healthy else 0},
        "lz4_error_counts": {"ChecksumMismatch": 1 if healthy else 0, "CorruptFrame": 2 if healthy else 1, "TruncatedFrame": 4 if healthy else 0},
        "zstd_error_counts": {"CorruptFrame": 2 if healthy else 0, "InvalidMagic": 1 if healthy else 0, "TruncatedFrame": 4 if healthy else 0},
        "lz4_phase_counts": {"magic": 1 if healthy else 1, "skippable_payload": 1 if healthy else 0, "frame_header": 2 if healthy else 0, "frame_body": 1 if healthy else 0, "frame_checksum": 1 if healthy else 0, "frame": 1 if healthy else 0},
        "zstd_phase_counts": {"magic": 1 if healthy else 0, "skippable_payload": 1 if healthy else 0, "frame_header": 1 if healthy else 0, "frame_body": 1 if healthy else 0, "frame_checksum": 1 if healthy else 0, "frame": 1 if healthy else 0},
        "required_codec_phases": {"lz4": required_phases, "zstd": required_phases},
        "offset_min": 0,
        "offset_max": 20 if healthy else 0,
        "lz4_offset_min": 0,
        "lz4_offset_max": 20 if healthy else 0,
        "zstd_offset_min": 0,
        "zstd_offset_max": 14 if healthy else 0,
        "phase_offset_ranges": {
            "frame": {"min": 6, "max": 7},
            "frame_body": {"min": 11, "max": 13},
            "frame_checksum": {"min": 14, "max": 20},
            "frame_header": {"min": 5, "max": 11},
            "magic": {"min": 0, "max": 3},
            "skippable_payload": {"min": 13, "max": 13},
        }
        if healthy
        else {"magic": {"min": 0, "max": 0}},
        "cases": [
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
            }
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_summary_error_negative_smoke(path: Path, *, healthy: bool = True) -> None:
    payload = {
        "schema": "vort.native_summary_error_negative_smoke",
        "schema_version": 1,
        "ok": healthy,
        "case_count": 3 if healthy else 0,
        "cases": [
            {
                "name": "bad_error_counts",
                "expected_failure": True,
                "expected_error": "error_counts mismatch",
                "actual_error": "error_counts mismatch" if healthy else "<success>",
                "matched": healthy,
            }
        ],
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_codec_probes(path: Path) -> None:
    probes = [
        {
            "label": "lz4-native-probe",
            "executable": "zig-out/bin/lz4-native-probe",
            "ok": True,
            "returncode": 0,
            "timed_out": False,
            "timeout_seconds": 120.0,
            "cases": 113,
            "marker": "lz4_native_probe",
            "output": "lz4_native_probe_ok cases=113",
            "reported_capabilities": ["chunked", "dictionary", "incremental", "lib-generated", "malformed", "reusable-chunked"],
            "reported_capability_cases": {"chunked": 63, "dictionary": 113, "incremental": 63, "lib-generated": 63, "malformed": 113, "reusable-chunked": 63},
            "reported_capability_count": 6,
        },
        {
            "label": "lz4-native-dictionary-probe",
            "executable": "zig-out/bin/lz4-native-dictionary-probe",
            "ok": True,
            "returncode": 0,
            "timed_out": False,
            "timeout_seconds": 120.0,
            "cases": 11,
            "marker": "lz4_native_dictionary_probe",
            "output": "lz4_native_dictionary_probe_ok cases=11",
            "reported_capabilities": ["dictionary", "dictionary-training"],
            "reported_capability_cases": {"dictionary": 11, "dictionary-training": 1},
            "reported_capability_count": 2,
        },
        {
            "label": "zstd-native-frame-probe",
            "executable": "zig-out/bin/zstd-native-frame-probe",
            "ok": True,
            "returncode": 0,
            "timed_out": False,
            "timeout_seconds": 120.0,
            "cases": 213,
            "marker": "zstd_native_frame_probe",
            "output": "zstd_native_frame_probe_ok cases=213",
            "reported_capabilities": ["chunked", "fse-repeat", "huffman", "incremental", "lib-generated", "malformed", "reusable-chunked", "sequence-tables"],
            "reported_capability_cases": {"chunked": 132, "fse-repeat": 8, "huffman": 12, "incremental": 138, "lib-generated": 124, "malformed": 213, "reusable-chunked": 134, "sequence-tables": 7},
            "reported_capability_count": 8,
        },
        {
            "label": "zstd-native-dictionary-probe",
            "executable": "zig-out/bin/zstd-native-dictionary-probe",
            "ok": True,
            "returncode": 0,
            "timed_out": False,
            "timeout_seconds": 120.0,
            "cases": 25,
            "marker": "zstd_native_dictionary_probe",
            "output": "zstd_native_dictionary_probe_ok cases=25",
            "reported_capabilities": ["dictionary", "lib-generated"],
            "reported_capability_cases": {"dictionary": 25, "lib-generated": 25},
            "reported_capability_count": 2,
        },
    ]
    payload = {
        "schema": "vort.native_codec_probes",
        "schema_version": 1,
        "ok": True,
        "probe_count": 4,
        "total_cases": 362,
        "coverage_count": 4,
        "coverage": [
            {"codec": "lz4", "surface": "frame", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"codec": "lz4", "surface": "dictionary", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 11},
            {"codec": "zstd", "surface": "frame", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 213},
            {"codec": "zstd", "surface": "dictionary", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 25},
        ],
        "capability_count": 16,
        "capabilities": [
            {"capability": "lib-generated", "present": True, "ok": True, "probe_count": 3, "ok_probe_count": 3, "cases": 212},
            {"capability": "native-generated", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"capability": "incremental", "present": True, "ok": True, "probe_count": 2, "ok_probe_count": 2, "cases": 201},
            {"capability": "chunked", "present": True, "ok": True, "probe_count": 2, "ok_probe_count": 2, "cases": 195},
            {"capability": "reusable-chunked", "present": True, "ok": True, "probe_count": 2, "ok_probe_count": 2, "cases": 197},
            {"capability": "fse-repeat", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 8},
            {"capability": "dictionary", "present": True, "ok": True, "probe_count": 3, "ok_probe_count": 3, "cases": 149},
            {"capability": "dictionary-training", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 1},
            {"capability": "dictionary-set", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"capability": "skippable", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"capability": "malformed", "present": True, "ok": True, "probe_count": 2, "ok_probe_count": 2, "cases": 326},
            {"capability": "checksum", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"capability": "bounded-limits", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
            {"capability": "huffman", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 12},
            {"capability": "sequence-tables", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 7},
            {"capability": "block", "present": True, "ok": True, "probe_count": 1, "ok_probe_count": 1, "cases": 113},
        ],
        "probes": probes,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")

def write_zstd_native_summary(path: Path, *, healthy: bool = True) -> None:
    payload = {
        "schema": "vort.zstd_native_stream_summary",
        "schema_version": 1,
        "compressed_bytes": 48 if healthy else 0,
        "frame_count": 2 if healthy else 1,
        "skippable_frame_count": 1 if healthy else 0,
        "checksum_frame_count": 1 if healthy else 0,
        "dictionary_id_frame_count": 1 if healthy else 0,
        "content_size_frame_count": 2 if healthy else 0,
        "declared_content_bytes": 6 if healthy else 0,
        "block_count": 2 if healthy else 1,
        "compressed_block_count": 0,
        "rle_block_count": 0,
        "raw_block_count": 2 if healthy else 1,
        "payload_bytes": 6 if healthy else 0,
        "skippable_payload_bytes": 16 if healthy else 0,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_lz4_native_summary(path: Path, *, healthy: bool = True) -> None:
    payload = {
        "schema": "vort.lz4_native_stream_summary",
        "schema_version": 1,
        "compressed_bytes": 64 if healthy else 0,
        "frame_count": 2 if healthy else 1,
        "skippable_frame_count": 1 if healthy else 0,
        "content_size_frame_count": 2 if healthy else 0,
        "checksum_frame_count": 2 if healthy else 0,
        "block_checksum_frame_count": 1 if healthy else 0,
        "dictionary_id_frame_count": 1 if healthy else 0,
        "declared_content_bytes": 6 if healthy else 0,
        "block_count": 2 if healthy else 1,
        "compressed_block_count": 0,
        "raw_block_count": 2 if healthy else 1,
        "payload_bytes": 6 if healthy else 0,
        "skippable_payload_bytes": 16 if healthy else 0,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_tier_range_summary(path: Path, *, ok: bool = True, source: str = "built_in", rows: int = 9, fixture_count: int = 3) -> None:
    floors = NATIVE_TIER_RANGE_FLOORS.get(source, NATIVE_TIER_RANGE_FLOORS["custom"])
    payload = {
        "schema": "vort.native_tier_range_bench_gate",
        "schema_version": 1,
        "source": source,
        "ok": ok,
        "rows": rows if ok else 0,
        "fixture_count": fixture_count if ok else 0,
        "tier_count": 3,
        "fixtures": ["repetitive", "structured", "text"],
        "tiers": ["seek_fast", "balanced", "ratio"],
        "enforce_throughput": False,
        "min_range_mib_s_by_tier": {"seek_fast": 80.0, "balanced": 25.0, "ratio": 20.0},
        "min_full_input_mib_s_by_tier": {"seek_fast": 700.0, "balanced": 250.0, "ratio": 180.0},
        "range_mib_s_floor_by_tier": floors,
        "total_stream_bytes_by_tier": {"seek_fast": 9000, "balanced": 5000, "ratio": 4000},
        "total_index_entries_by_tier": {"seek_fast": 32, "balanced": 12, "ratio": 8},
        "csv": "zig-out/vort-native-tier-range-bench.csv",
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_tier_corpus_discovery_summary(path: Path, *, ok: bool = True) -> None:
    payload = {
        "schema": "vort.native_tier_range_corpus_discovery",
        "schema_version": 1,
        "ok": ok,
        "source_mode": "discovered",
        "full": False,
        "limit": 3,
        "candidate_count": 5,
        "source_count": 1 if ok else 0,
        "sources": ["/tmp/silesia-small.tar"] if ok else [],
        "selected_case_count": 3 if ok else 0,
        "selected_cases": [
            {"label": "ooffice-128k", "bytes": 131072},
            {"label": "nci-128k", "bytes": 131072},
            {"label": "mozilla-128k", "bytes": 131072},
        ]
        if ok
        else [],
        "csv": "zig-out/vort-native-tier-range-corpus-bench.csv" if ok else "",
        "missing_reason": "" if ok else "no_standard_corpora_discovered",
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_tier_range_summaries(root: Path) -> None:
    write_native_tier_range_summary(root / NATIVE_TIER_RANGE_ARTIFACT, source="built_in", rows=9, fixture_count=3)
    write_native_tier_range_summary(root / NATIVE_TIER_RANGE_FILES_ARTIFACT, source="project_files", rows=6, fixture_count=2)
    write_native_tier_range_summary(root / NATIVE_TIER_RANGE_CORPUS_ARTIFACT, source="standard_corpus", rows=9, fixture_count=3)
    write_native_tier_corpus_discovery_summary(root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT)


def write_healthy_artifacts(root: Path) -> None:
    write_header_summary(root / HEADER_INSPECT_ARTIFACT)
    write_dashboard_strict_summary(root / DASHBOARD_STRICT_ARTIFACT)
    write_dashboard_configuration_artifacts(root)
    write_validation_json_artifacts(root)
    write_sidecar_corrupt_report(root / SIDECAR_CORRUPT_ARTIFACT)
    write_huffman_length_csv(root / HUFFMAN_LENGTH_ARTIFACT)
    write_checksum_bench_csv(root / CHECKSUM_BENCH_ARTIFACT)
    write_chunk_cursor_bench_csv(root / CHUNK_CURSOR_BENCH_ARTIFACT)
    write_deflate_match_copy_bench_csv(root / DEFLATE_MATCH_COPY_BENCH_ARTIFACT)
    write_deflate_huffman_build_bench_csv(root / DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT)
    write_deflate_huffman_lookup_bench_csv(root / DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT)
    write_fuzz_corpus_report(root / FUZZ_CORPUS_ARTIFACT)
    write_fuzz_coverage_report(root / FUZZ_COVERAGE_ARTIFACT)
    write_decode_stage_report(root / DECODE_STAGE_ARTIFACT)
    write_python_zlib_diff_report(root / PYTHON_ZLIB_DIFF_ARTIFACT)
    write_zlib_relaxed_report(root / ZLIB_RELAXED_ARTIFACT)
    write_snappy_report_csv(root / SNAPPY_REPORT_ARTIFACT)
    write_png_scratch_report(root / PNG_SCRATCH_ARTIFACT)
    write_native_fuzz_corpus_artifacts(root)
    write_br_static_dictionary_artifacts(root)
    write_native_allocation_artifacts(root)
    write_zstd_compare_artifacts(root)
    write_native_summary_error_dashboard(root / NATIVE_SUMMARY_ERROR_ARTIFACT)
    write_native_summary_error_negative_smoke(root / NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT)
    write_native_codec_probes(root / NATIVE_CODEC_PROBES_ARTIFACT)
    write_lz4_native_summary(root / LZ4_NATIVE_SUMMARY_ARTIFACT)
    write_zstd_native_summary(root / ZSTD_NATIVE_SUMMARY_ARTIFACT)
    write_native_tier_range_summaries(root)


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


def markdown_check_row(name: str, expected_output: str, markdown: str, needles: list[str]) -> dict[str, object]:
    """Create a strict-smoke row for human-facing Markdown dashboard sections.

    These checks intentionally record each required snippet by index rather than
    embedding full Markdown table text in the JSON artifact. That keeps the
    summary compact while still making a missing section/header/row obvious in
    CI output.
    """
    matched = all(needle in markdown for needle in needles)
    actual_output = ",".join(
        f"{index}:{'ok' if needle in markdown else 'missing'}"
        for index, needle in enumerate(needles)
    )
    return check_row(name, "dashboard-markdown", False, matched, 0, expected_output, actual_output)


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
        write_producer_map(
            producer_map,
            required_names=[
                HEADER_INSPECT_ARTIFACT,
                DASHBOARD_STRICT_ARTIFACT,
                DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT,
                DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT,
                DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT,
                DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT,
                DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT,
                VALIDATION_JSON_SMOKE_ARTIFACT,
                VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT,
            ],
        )

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
        assert manifest["validation_healthy"] is True
        assert manifest["header_inspect_present"] is True
        assert manifest["header_inspect_ok"] is True
        assert manifest["header_inspect_missing_workflow_count"] == 0
        assert manifest["native_summary_error_present"] is True
        assert manifest["native_summary_error_healthy"] is True
        assert manifest["native_summary_error_case_count"] == 14
        assert manifest["native_summary_error_negative_present"] is True
        assert manifest["native_summary_error_negative_healthy"] is True
        assert manifest["native_summary_error_negative_case_count"] == 3
        assert manifest["lz4_native_summary_present"] is True
        assert manifest["lz4_native_summary_healthy"] is True
        assert manifest["zstd_native_summary_present"] is True
        assert manifest["zstd_native_summary_healthy"] is True
        assert manifest["native_tier_range_present"] is True
        assert manifest["native_tier_range_healthy"] is True
        assert manifest["native_tier_range_summary_count"] == 3
        assert manifest["native_tier_range_rows"] == 24
        assert manifest["native_tier_range_built_in_summary_count"] == 1
        assert manifest["native_tier_range_project_files_summary_count"] == 1
        assert manifest["native_tier_range_standard_corpus_summary_count"] == 1
        assert manifest["native_tier_range_missing_sources"] == []
        assert manifest["native_tier_range_seek_fast_min_range_mib_s"] >= 80.0
        assert manifest["native_tier_corpus_discovery_present"] is True
        assert manifest["native_tier_corpus_discovery_healthy"] is True
        assert manifest["native_tier_corpus_discovery_source_mode"] == "discovered"
        assert manifest["native_tier_corpus_discovery_source_count"] == 1
        assert manifest["native_tier_corpus_discovery_selected_case_count"] == 3
        assert [case["label"] for case in manifest["native_tier_corpus_discovery_selected_cases"]] == [
            "ooffice-128k",
            "nci-128k",
            "mozilla-128k",
        ]
        assert manifest["native_tier_corpus_discovery_missing_reason"] == ""
        assert any(
            artifact["name"] == NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT
            and artifact["schema"] == "vort.native_tier_range_corpus_discovery"
            and artifact["ok"] is True
            for artifact in manifest["artifacts"]
        )
        source_details = {row["source"]: row for row in manifest["native_tier_range_source_details"]}
        assert source_details["built_in"]["summary_count"] == 1
        assert source_details["built_in"]["range_mib_s_floor_by_tier"]["seek_fast"] == 60.0
        assert source_details["project_files"]["rows"] == 6
        assert source_details["project_files"]["range_mib_s_floor_by_tier"]["balanced"] == 8.0
        assert source_details["standard_corpus"]["fixture_count"] == 3
        assert source_details["standard_corpus"]["range_mib_s_floor_by_tier"]["ratio"] == 3.5
        assert source_details["custom"]["summary_count"] == 0
        assert source_details["legacy"]["summary_count"] == 0
        dashboard_markdown = (root / "vort-dashboard-index.md").read_text()
        checks.append(check_row("all_strict_ok", "all", False, True, ok.returncode, "dashboard_index=", ok.stdout))
        checks.append(
            markdown_check_row(
                "dashboard_artifact_inventory_markdown_table",
                "dashboard artifact inventory Markdown table",
                dashboard_markdown,
                [
                    "## Dashboard artifact inventory",
                    "| category | artifacts | json | markdown | csv | producer steps | smoke gates |",
                    "| `validation` |",
                    "| `corpus and ratio` |",
                    "| `benchmark` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "validation_unhealthy_reasons_markdown_table",
                "validation unhealthy reasons Markdown table",
                dashboard_markdown,
                [
                    "## Validation unhealthy reasons",
                    "| category | count | detail |",
                    "| active reasons | 0 | none |",
                    "| aggregate health | 1 | validation healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "producer_smoke_gate_markdown_table",
                "producer and smoke-gate Markdown table",
                dashboard_markdown,
                [
                    "## Producer and smoke-gate coverage",
                    "| category | covered | missing | detail |",
                    "| producer steps | 45/45 | 0 | allowed missing 0 |",
                    "| smoke gates | 45/45 | 0 | required missing 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "dashboard_strict_mode_markdown_table",
                "dashboard strict mode Markdown table",
                dashboard_markdown,
                [
                    "## Dashboard strict mode coverage",
                    "| category | count | detail |",
                    "| strict checks | 1 | expected failures/matched 0/1 |",
                    "| modes | 1 | expected/missing 1/0 |",
                    "| requirement deltas | 0 | checks/expected/matched 0/0/0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "dashboard_configuration_markdown_table",
                "dashboard configuration Markdown table",
                dashboard_markdown,
                [
                    "## Dashboard configuration coverage",
                    "| category | count | detail |",
                    "| config index | 3 | matched 3, negative 2/2 |",
                    "| category guardrails | 3 | matched 3, present `True` |",
                    "| required producers | 4 | matched 4, required smoke gates 2 |",
                    "| producer guardrails | 2 | matched 2, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "validation_json_markdown_table",
                "validation JSON schema Markdown table",
                dashboard_markdown,
                [
                    "## Validation JSON schema coverage",
                    "| category | count | detail |",
                    "| checked schemas | 5 | smoke present `True`, ok `True` |",
                    "| CLI validation | 1 | failure-ok `False`, hint `payload_corrupt` |",
                    "| report rows | 1 | corrupt rows 2 |",
                    "| docs negative cases | 2/2 | present `True`, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_summary_success_markdown_table",
                "native summary success Markdown table",
                dashboard_markdown,
                [
                    "## Native stream summary coverage",
                    "| codec | frames | skippable | checksum | block checksum | dictionary | content size | blocks raw/rle/compressed | payload/skippable bytes |",
                    "| `lz4` | 2 | 1 | 2 | 1 | 1 | 2 | 2/0/0 | 6/16 |",
                    "| `zstd` | 2 | 1 | 1 | 0 | 1 | 2 | 2/0/0 | 6/16 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_summary_error_markdown_tables",
                "native summary error Markdown tables",
                dashboard_markdown,
                [
                    "## Native summary error codec coverage",
                    "| codec | cases | errors | phases | required phases | missing phases |",
                    "| `lz4` | 7 | `ChecksumMismatch`=1<br>`CorruptFrame`=2<br>`TruncatedFrame`=4 |",
                    "| `zstd` | 7 | `CorruptFrame`=2<br>`InvalidMagic`=1<br>`TruncatedFrame`=4 |",
                    "## Native summary error phase offsets",
                    "| phase | cases | offset range |",
                    "| `frame_checksum` | 2 | `14..20` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_tier_range_markdown_table",
                "native tier range Markdown table",
                dashboard_markdown,
                [
                    "## Native tier range source health",
                    "| source | summaries | ok | rows | fixtures | enforced | missing | min range MiB/s seek_fast/balanced/ratio | floor MiB/s seek_fast/balanced/ratio |",
                    "| `built_in` | 1 | 1 | 9 | 3 | 0 | `False` |",
                    "| `project_files` | 1 | 1 | 6 | 2 | 0 | `False` |",
                    "| `standard_corpus` | 1 | 1 | 9 | 3 | 0 | `False` |",
                    "60.00/16.00/12.00",
                    "40.00/8.00/4.00",
                    "30.00/6.50/3.50",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_tier_discovery_markdown_table",
                "native tier discovery Markdown table",
                dashboard_markdown,
                [
                    "## Native tier corpus discovery",
                    "| category | count | detail |",
                    "| sources | 1/5 | mode `discovered`, full `False`, limit `3` |",
                    "| selected cases | 3 | `ooffice-128k`, `nci-128k`, `mozilla-128k` |",
                    "| corpus paths | 1 | `/tmp/silesia-small.tar` |",
                    "| output csv | 1 | `zig-out/vort-native-tier-range-corpus-bench.csv` |",
                    "| missing reason | 0 | `none` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_codec_probe_markdown_tables",
                "native codec probe Markdown tables",
                dashboard_markdown,
                [
                    "## Native codec probe coverage",
                    "| codec | surface | present | ok | probes | cases |",
                    "| `lz4` | `frame` | `True` | `True` | 1/1 | 113 |",
                    "| `zstd` | `frame` | `True` | `True` | 1/1 | 213 |",
                    "## Native codec probe capabilities",
                    "| capability | present | ok | probes | cases |",
                    "| `lib-generated` | `True` | `True` | 3/3 | 212 |",
                    "| `fse-repeat` | `True` | `True` | 1/1 | 8 |",
                    "## Native codec probe executables",
                    "| probe | ok | cases | returncode | timed out |",
                    "| `zstd-native-frame-probe` | `True` | 213 | 0 | `False` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "header_inspect_markdown_table",
                "header inspect Markdown table",
                dashboard_markdown,
                [
                    "## Header inspect coverage",
                    "| category | total | raw | zlib | gzip |",
                    "| positive cases | 3 | 1 | 1 | 1 |",
                    "| negative cases | 3 | 1 | 1 | 1 |",
                    "| workflow/feature | count | detail |",
                    "| commands | 3 | successes/failures 3/3 |",
                    "| workflows | 3 | successes 3, required/missing 1/0 |",
                    "| dictionary cases | 1 | optional/FHCRC 1/1 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "sidecar_corrupt_markdown_table",
                "sidecar corrupt Markdown table",
                dashboard_markdown,
                [
                    "## Sidecar corrupt smoke coverage",
                    "| category | count | detail |",
                    "| corrupt rows | 2 | healthy `True` |",
                    "| metadata checks | 2 | failed 0 |",
                    "| full decode rejection | 2 | not rejected 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "huffman_length_markdown_table",
                "huffman length Markdown table",
                dashboard_markdown,
                [
                    "## Huffman length oracle coverage",
                    "| implementation | optimal rows | non-optimal rows | worst gap bits |",
                    "| production | 1/1 | 0 | 0 |",
                    "| package-merge | 1/1 | 0 | 0 |",
                    "| validation | count | detail |",
                    "| malformed rows | 0 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "checksum_bench_markdown_table",
                "checksum benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Checksum benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 21 | expected 21, present `True` |",
                    "| workload rows | 21 | positive rows 21 |",
                    "| digest mix groups | 2 | crc32/crc32c 1/1, missing algorithms 0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "chunk_cursor_bench_markdown_table",
                "chunk cursor benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Chunk cursor benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 8 | expected 8, present `True` |",
                    "| shape rows | 8 | positive rows 8 |",
                    "| missing pairs | 0 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_match_copy_bench_markdown_table",
                "deflate match-copy benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Deflate match-copy benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 21 | expected 21, present `True` |",
                    "| class rows | 21 | positive rows 21 |",
                    "| missing pairs | 0 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_huffman_build_bench_markdown_table",
                "deflate Huffman build benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Deflate Huffman build benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 14 | expected 14, present `True` |",
                    "| lookup rows | 14 | positive rows 14 |",
                    "| missing pairs | 0 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_huffman_lookup_bench_markdown_table",
                "deflate Huffman lookup benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Deflate Huffman lookup benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 21 | expected 21, present `True` |",
                    "| lookup rows | 21 | positive rows 21 |",
                    "| missing pairs | 0 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "zstd_compare_markdown_table",
                "zstd compare Markdown table",
                dashboard_markdown,
                [
                    "## Zstd compare gate coverage",
                    "| category | count | detail |",
                    "| compare rows | 2 | native/native-stream ratios 1.180/1.160, decode-vs-zstd 0.710 |",
                    "| standard rows | 3 | native/native-stream ratios 1.130/1.120, decode-vs-zstd 0.740 |",
                    "| block sweep rows | 15 | best block 65536 bytes, range/full MiB/s 3.47/111.00 |",
                    "| gate health | 1 | compare/standard/sweep present True/True/True |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_allocation_markdown_table",
                "native allocation Markdown table",
                dashboard_markdown,
                [
                    "## Native allocation coverage",
                    "| category | count | detail |",
                    "| report cases | 3 | present `True` |",
                    "| zero-allocation cases | 2/2 | smoke present `True` |",
                    "| budget cases | 1/1 | healthy `True` |",
                    "| negative smoke cases | 1/1 | present `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_fuzz_corpus_markdown_table",
                "native fuzz corpus Markdown table",
                dashboard_markdown,
                [
                    "## Native fuzz corpus coverage",
                    "| category | count | detail |",
                    "| native cases | 3 | accepted/rejected 1/2 |",
                    "| matched rows | 3 | unmatched 0 |",
                    "| exact error expectations | 2 | mode/error rows 1/2 |",
                    "| coverage requirements | 3 | modes/errors 1/2 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "static_dictionary_markdown_table",
                "static dictionary Markdown table",
                dashboard_markdown,
                [
                    "## Static dictionary coverage",
                    "| category | count | detail |",
                    "| candidates | 775 | raw words 143 |",
                    "| upstream smoke | 775 | raw words 143, present `True` |",
                    "| node probe | 48/48 | size winners 1 |",
                    "| source audit | 83 | anchors 83, generated bytes 4096 |",
                    "| negative smoke | 1/1 | healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "png_scratch_markdown_table",
                "PNG scratch Markdown table",
                dashboard_markdown,
                [
                    "## PNG scratch coverage",
                    "| category | count | detail |",
                    "| cases | 2 | Adam7 1, healthy `True` |",
                    "| streaming achieved | 2/2 | fixed/dynamic 2/2 |",
                    "| zlib scratch savings | 166 | zlib scratch 166 |",
                    "| max working scratch | 116 | streaming/fixed-dynamic 30/32798 |",
                    "| min streaming ratio x10000 | 2586 | lower is better |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "zlib_relaxed_markdown_table",
                "zlib relaxed Markdown table",
                dashboard_markdown,
                [
                    "## Zlib relaxed compatibility coverage",
                    "| wrapper | strict rejections | relaxed successes | concatenated successes | decoder successes | limited rejections | extra |",
                    "| zlib | 2 | 5 | 3 | 8 | 1 | dictionary 2 |",
                    "| gzip | 3 | 9 | 4 | 4 | 1 | total 21 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "snappy_report_markdown_table",
                "Snappy report Markdown table",
                dashboard_markdown,
                [
                    "## Snappy report coverage",
                    "| category | count | detail |",
                    "| rows | 20 | expected 20, present `True` |",
                    "| positive timing rows | 20 | repetitive shrunk 4 |",
                    "| reusable size matches | 5 | missing pairs 0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "python_zlib_diff_markdown_table",
                "Python zlib differential Markdown table",
                dashboard_markdown,
                [
                    "## Python zlib differential coverage",
                    "| category | count | detail |",
                    "| payloads | 3 | large-file/match-heavy/dynamic 1/1/1 |",
                    "| file hex encodes | 3 | dictionary cases 1 |",
                    "| dictionary encodes | 2 | zlib/raw 1/1 |",
                    "| malformed cases | 2 | wrapper/deflate 1/1 |",
                    "| CLI outcomes | 10 | successes/expected-failures 8/2 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "decode_stage_markdown_table",
                "decode-stage Markdown table",
                dashboard_markdown,
                [
                    "## Decode-stage smoke coverage",
                    "| category | count | detail |",
                    "| timing rows | 1 | ok `True` |",
                    "| error rows | 3 | matched/unmatched 3/0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "fuzz_corpus_markdown_table",
                "fuzz corpus Markdown table",
                dashboard_markdown,
                [
                    "## Fuzz corpus coverage",
                    "| category | count | detail |",
                    "| corpus cases | 3 | matched/unmatched 3/0 |",
                    "| exact error expectations | 2 | mode/error rows 3/2 |",
                    "| coverage requirements | 5 | modes/errors 3/2 |",
                ],
            )
        )

        missing_native_tier_root = root / "missing-native-tier"
        missing_native_tier_root.mkdir()
        write_healthy_artifacts(missing_native_tier_root)
        for artifact in (NATIVE_TIER_RANGE_ARTIFACT, NATIVE_TIER_RANGE_FILES_ARTIFACT, NATIVE_TIER_RANGE_CORPUS_ARTIFACT):
            (missing_native_tier_root / artifact).unlink()
        missing_native_tier_producer = missing_native_tier_root / "producers.json"
        write_producer_map(missing_native_tier_producer)
        missing_native_tier_result = run(dashboard_args(missing_native_tier_root, missing_native_tier_producer, "--strict-validation-health"), check=False)
        missing_native_tier_manifest = json.loads((missing_native_tier_root / "vort-dashboard-index.json").read_text())
        native_tier_missing_matched = (
            missing_native_tier_result.returncode != 0
            and "dashboard_index_validation_unhealthy=missing_native_tier_range_artifact" in missing_native_tier_result.stdout
            and missing_native_tier_manifest["validation_healthy"] is False
            and missing_native_tier_manifest["native_tier_range_present"] is False
            and missing_native_tier_manifest["native_tier_range_healthy"] is False
            and missing_native_tier_manifest["native_tier_range_rows"] == 0
        )
        checks.append(check_row("missing_native_tier_range_summary", "native-tier-range-health", True, native_tier_missing_matched, missing_native_tier_result.returncode, "dashboard_index_validation_unhealthy=missing_native_tier_range_artifact", missing_native_tier_result.stdout))

        missing_native_tier_source_root = root / "missing-native-tier-source"
        missing_native_tier_source_root.mkdir()
        write_healthy_artifacts(missing_native_tier_source_root)
        (missing_native_tier_source_root / NATIVE_TIER_RANGE_ARTIFACT).unlink()
        missing_native_tier_source_producer = missing_native_tier_source_root / "producers.json"
        write_producer_map(missing_native_tier_source_producer)
        missing_native_tier_source_result = run(dashboard_args(missing_native_tier_source_root, missing_native_tier_source_producer, "--strict-validation-health"), check=False)
        missing_native_tier_source_manifest = json.loads((missing_native_tier_source_root / "vort-dashboard-index.json").read_text())
        native_tier_source_missing_matched = (
            missing_native_tier_source_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_tier_range_failed" in missing_native_tier_source_result.stdout
            and missing_native_tier_source_manifest["validation_healthy"] is False
            and missing_native_tier_source_manifest["native_tier_range_present"] is True
            and missing_native_tier_source_manifest["native_tier_range_healthy"] is False
            and missing_native_tier_source_manifest["native_tier_range_summary_count"] == 2
            and missing_native_tier_source_manifest["native_tier_range_built_in_summary_count"] == 0
            and missing_native_tier_source_manifest["native_tier_range_missing_sources"] == ["built_in"]
        )
        checks.append(check_row("missing_native_tier_range_source", "native-tier-range-health", True, native_tier_source_missing_matched, missing_native_tier_source_result.returncode, "dashboard_index_validation_unhealthy=native_tier_range_failed", missing_native_tier_source_result.stdout))

        failed_native_tier_root = root / "failed-native-tier"
        failed_native_tier_root.mkdir()
        write_healthy_artifacts(failed_native_tier_root)
        write_native_tier_range_summary(failed_native_tier_root / NATIVE_TIER_RANGE_ARTIFACT, ok=False)
        failed_native_tier_producer = failed_native_tier_root / "producers.json"
        write_producer_map(failed_native_tier_producer)
        failed_native_tier_result = run(dashboard_args(failed_native_tier_root, failed_native_tier_producer, "--strict-validation-health"), check=False)
        failed_native_tier_manifest = json.loads((failed_native_tier_root / "vort-dashboard-index.json").read_text())
        native_tier_failed_matched = (
            failed_native_tier_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_tier_range_failed" in failed_native_tier_result.stdout
            and failed_native_tier_manifest["validation_healthy"] is False
            and failed_native_tier_manifest["native_tier_range_present"] is True
            and failed_native_tier_manifest["native_tier_range_healthy"] is False
            and failed_native_tier_manifest["native_tier_range_ok_count"] == 2
        )
        checks.append(check_row("failed_native_tier_range_summary", "native-tier-range-health", True, native_tier_failed_matched, failed_native_tier_result.returncode, "dashboard_index_validation_unhealthy=native_tier_range_failed", failed_native_tier_result.stdout))

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
            elif fixture == "missing_dashboard_configuration_artifact":
                (fixture_root / DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "dashboard_configuration_failed":
                write_dashboard_configuration_artifacts(fixture_root)
                payload = json.loads((fixture_root / DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_validation_json_smoke_artifact":
                (fixture_root / VALIDATION_JSON_SMOKE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "validation_json_failed":
                write_validation_json_artifacts(fixture_root)
                payload = json.loads((fixture_root / VALIDATION_JSON_SMOKE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / VALIDATION_JSON_SMOKE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_validation_json_docs_negative_artifact":
                (fixture_root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "validation_json_docs_negative_failed":
                write_validation_json_artifacts(fixture_root)
                payload = json.loads((fixture_root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
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
            elif fixture == "missing_checksum_bench_artifact":
                (fixture_root / CHECKSUM_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "checksum_bench_failed":
                write_checksum_bench_csv(fixture_root / CHECKSUM_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_chunk_cursor_bench_artifact":
                (fixture_root / CHUNK_CURSOR_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "chunk_cursor_bench_failed":
                write_chunk_cursor_bench_csv(fixture_root / CHUNK_CURSOR_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_deflate_match_copy_bench_artifact":
                (fixture_root / DEFLATE_MATCH_COPY_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_match_copy_bench_failed":
                write_deflate_match_copy_bench_csv(fixture_root / DEFLATE_MATCH_COPY_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_deflate_huffman_build_bench_artifact":
                (fixture_root / DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_huffman_build_bench_failed":
                write_deflate_huffman_build_bench_csv(fixture_root / DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_deflate_huffman_lookup_bench_artifact":
                (fixture_root / DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_huffman_lookup_bench_failed":
                write_deflate_huffman_lookup_bench_csv(fixture_root / DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT, healthy=False)
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
            elif fixture == "missing_native_fuzz_corpus_artifact":
                (fixture_root / NATIVE_FUZZ_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_fuzz_corpus_failed":
                write_native_fuzz_corpus_artifacts(fixture_root)
                payload = json.loads((fixture_root / NATIVE_FUZZ_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / NATIVE_FUZZ_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_native_fuzz_coverage_artifact":
                (fixture_root / NATIVE_FUZZ_COVERAGE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_fuzz_coverage_failed":
                write_native_fuzz_corpus_artifacts(fixture_root)
                payload = json.loads((fixture_root / NATIVE_FUZZ_COVERAGE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / NATIVE_FUZZ_COVERAGE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_png_scratch_artifact":
                (fixture_root / PNG_SCRATCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "png_scratch_failed":
                write_png_scratch_report(fixture_root / PNG_SCRATCH_ARTIFACT)
                payload = json.loads((fixture_root / PNG_SCRATCH_ARTIFACT).read_text())
                payload["cases"][0]["stored_streaming_status"] = "scratch-required"
                (fixture_root / PNG_SCRATCH_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_zlib_relaxed_artifact":
                (fixture_root / ZLIB_RELAXED_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "zlib_relaxed_failed":
                write_zlib_relaxed_report(fixture_root / ZLIB_RELAXED_ARTIFACT)
                payload = json.loads((fixture_root / ZLIB_RELAXED_ARTIFACT).read_text())
                payload["relaxed_successes"] = 0
                (fixture_root / ZLIB_RELAXED_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_snappy_report_artifact":
                (fixture_root / SNAPPY_REPORT_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "snappy_report_failed":
                write_snappy_report_csv(fixture_root / SNAPPY_REPORT_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_native_allocation_artifact":
                (fixture_root / NATIVE_ALLOCATION_REPORT_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_allocation_failed":
                write_native_allocation_artifacts(fixture_root)
                payload = json.loads((fixture_root / NATIVE_ALLOCATION_SMOKE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / NATIVE_ALLOCATION_SMOKE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
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
            elif fixture == "missing_native_codec_probes_artifact":
                (fixture_root / NATIVE_CODEC_PROBES_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_codec_probes_failed":
                write_native_codec_probes(fixture_root / NATIVE_CODEC_PROBES_ARTIFACT)
                payload = json.loads((fixture_root / NATIVE_CODEC_PROBES_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / NATIVE_CODEC_PROBES_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_zstd_compare_artifact":
                (fixture_root / ZSTD_COMPARE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "zstd_compare_failed":
                write_zstd_compare_artifacts(fixture_root)
                payload = json.loads((fixture_root / ZSTD_COMPARE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / ZSTD_COMPARE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_br_static_dictionary_artifact":
                (fixture_root / BR_STATIC_CANDIDATES_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "br_static_dictionary_failed":
                write_br_static_dictionary_artifacts(fixture_root)
                payload = json.loads((fixture_root / BR_STATIC_NODE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / BR_STATIC_NODE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_native_summary_error_dashboard_artifact":
                (fixture_root / NATIVE_SUMMARY_ERROR_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_summary_error_dashboard_undercovered":
                write_native_summary_error_dashboard(fixture_root / NATIVE_SUMMARY_ERROR_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_native_summary_error_negative_artifact":
                (fixture_root / NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_summary_error_negative_failed":
                write_native_summary_error_negative_smoke(fixture_root / NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_lz4_native_summary_artifact":
                (fixture_root / LZ4_NATIVE_SUMMARY_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "lz4_native_summary_undercovered":
                write_lz4_native_summary(fixture_root / LZ4_NATIVE_SUMMARY_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_zstd_native_summary_artifact":
                (fixture_root / ZSTD_NATIVE_SUMMARY_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "zstd_native_summary_undercovered":
                write_zstd_native_summary(fixture_root / ZSTD_NATIVE_SUMMARY_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_native_tier_range_artifact":
                for artifact in (NATIVE_TIER_RANGE_ARTIFACT, NATIVE_TIER_RANGE_FILES_ARTIFACT, NATIVE_TIER_RANGE_CORPUS_ARTIFACT):
                    (fixture_root / artifact).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_tier_range_failed":
                write_native_tier_range_summaries(fixture_root)
                payload = json.loads((fixture_root / NATIVE_TIER_RANGE_ARTIFACT).read_text())
                payload["ok"] = False
                (fixture_root / NATIVE_TIER_RANGE_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
                write_producer_map(producer_map)
            elif fixture == "missing_native_tier_corpus_discovery_artifact":
                (fixture_root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_tier_corpus_discovery_failed":
                write_native_tier_corpus_discovery_summary(fixture_root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT, ok=False)
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
        "ok": all(bool(row["matched"]) for row in checks),
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
    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print("dashboard_strict_smoke=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
