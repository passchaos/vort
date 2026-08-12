#!/usr/bin/env python3
"""Smoke-test dashboard_index strict-mode gates."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_INDEX = ROOT / "tools" / "dashboard_index.py"
EXPECTED_MODES = ROOT / "tools" / "dashboard_strict_expected_modes.json"
VALIDATION_REASONS = ROOT / "tools" / "dashboard_strict_validation_reasons.json"
HEADER_INSPECT_ARTIFACT = "vort-header-inspect-smoke.json"
HEADER_INSPECT_MARKDOWN_ARTIFACT = "vort-header-inspect-smoke.md"
DASHBOARD_STRICT_ARTIFACT = "vort-dashboard-strict-smoke.json"
DASHBOARD_STRICT_MARKDOWN_ARTIFACT = "vort-dashboard-strict-smoke.md"
DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT = "vort-dashboard-config-index-smoke.json"
DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT = "vort-dashboard-config-index-negative-smoke.json"
DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT = "vort-dashboard-category-negative-smoke.json"
DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT = "vort-dashboard-producers-required-smoke.json"
DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT = "vort-dashboard-producers-negative-smoke.json"
VALIDATION_JSON_SMOKE_ARTIFACT = "vort-validation-json-smoke.json"
VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT = "vort-validation-json-docs-negative-smoke.json"
SIDECAR_CORRUPT_ARTIFACT = "vort-sidecar-corrupt-smoke.json"
SIDECAR_CORRUPT_MARKDOWN_ARTIFACT = "vort-sidecar-corrupt-smoke.md"
HUFFMAN_LENGTH_ARTIFACT = "vort-huffman-length-report.csv"
LEVEL_REPORT_CSV_ARTIFACT = "vort-level-report.csv"
LEVEL_REPORT_MARKDOWN_ARTIFACT = "vort-level-report.md"
DYNAMIC_PLAN_ARTIFACT = "vort-dynamic-plan-report.csv"
DYNAMIC_PLAN_BUILTINS_ARTIFACT = "vort-dynamic-plan-builtins-report.csv"
CHECKSUM_BENCH_ARTIFACT = "vort-checksum-bench.csv"
CHUNK_CURSOR_BENCH_ARTIFACT = "vort-chunk-cursor-bench.csv"
DEFLATE_MATCH_COPY_BENCH_ARTIFACT = "vort-deflate-match-copy-bench.csv"
DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT = "vort-deflate-huffman-build-bench.csv"
DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT = "vort-deflate-huffman-lookup-bench.csv"
DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT = "vort-deflate-chunked-huffman-bench.csv"
DEFLATE_EXTRA_BITS_BENCH_ARTIFACT = "vort-deflate-extra-bits-bench.csv"
DICTIONARY_DECODE_BENCH_ARTIFACT = "vort-dictionary-decode-bench.csv"
PNG_SCANLINE_BENCH_ARTIFACT = "vort-png-scanline-bench.csv"
CHUNKED_ZLIB_BENCH_ARTIFACT = "vort-chunked-zlib-bench-report-repeat3.csv"
CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT = "vort-chunked-zlib-bench-report.md"
PNG_STREAMING_ZLIB_BENCH_ARTIFACT = "vort-png-streaming-zlib-bench-report-repeat3.csv"
DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT = "vort-deflate-dynamic-decode-profile.csv"
FUZZ_CORPUS_ARTIFACT = "vort-deflate-wrapper-fuzz-corpus.json"
FUZZ_CORPUS_MARKDOWN_ARTIFACT = "vort-deflate-wrapper-fuzz-corpus.md"
FUZZ_COVERAGE_ARTIFACT = "vort-fuzz-corpus-coverage-smoke.json"
DECODE_STAGE_ARTIFACT = "vort-deflate-decode-stage-report.json"
DECODE_STAGE_CSV_ARTIFACT = "vort-deflate-decode-stage-report.csv"
DECODE_STAGE_MARKDOWN_ARTIFACT = "vort-deflate-decode-stage-report.md"
PYTHON_ZLIB_DIFF_ARTIFACT = "vort-python-zlib-diff-smoke.json"
ZLIB_RELAXED_ARTIFACT = "vort-zlib-relaxed-report.json"
ZLIB_RELAXED_MARKDOWN_ARTIFACT = "vort-zlib-relaxed-report.md"
ZLIB_RELAXED_GATE_ARTIFACT = "vort-zlib-relaxed-report-gate.json"
SNAPPY_REPORT_ARTIFACT = "vort-snappy-report.csv"
PNG_SCRATCH_ARTIFACT = "vort-png-scratch-report.json"
PNG_SCRATCH_MARKDOWN_ARTIFACT = "vort-png-scratch-report.md"
BR_STATIC_CANDIDATES_ARTIFACT = "vort-br-static-dictionary-candidates.json"
BR_STATIC_CANDIDATES_MARKDOWN_ARTIFACT = "vort-br-static-dictionary-candidates.md"
BR_STATIC_UPSTREAM_ARTIFACT = "vort-br-static-dictionary-candidate-upstream-smoke.json"
BR_STATIC_UPSTREAM_REPORT_ARTIFACT = "vort-br-static-dictionary-candidates-upstream.json"
BR_STATIC_UPSTREAM_MARKDOWN_ARTIFACT = "vort-br-static-dictionary-candidates-upstream.md"
BR_STATIC_NODE_ARTIFACT = "vort-br-static-dictionary-node-probe.json"
BR_STATIC_NODE_MARKDOWN_ARTIFACT = "vort-br-static-dictionary-node-probe.md"
BR_STATIC_AUDIT_ARTIFACT = "vort-br-static-dictionary-source-audit.json"
BR_STATIC_AUDIT_NEGATIVE_ARTIFACT = "vort-br-static-dictionary-source-audit-negative-smoke.json"
BR_STATIC_REPORT_CSV_ARTIFACT = "vort-br-static-dictionary-report.csv"
BR_STATIC_REPORT_JSON_ARTIFACT = "vort-br-static-dictionary-report.json"
BR_STATIC_REPORT_MARKDOWN_ARTIFACT = "vort-br-static-dictionary-report.md"
BR_STATIC_REPORT_NEGATIVE_ARTIFACT = "vort-br-static-dictionary-report-negative-smoke.json"
NATIVE_FUZZ_ARTIFACT = "vort-native-fuzz-corpus.json"
NATIVE_FUZZ_MARKDOWN_ARTIFACT = "vort-native-fuzz-corpus.md"
NATIVE_FUZZ_COVERAGE_ARTIFACT = "vort-native-fuzz-corpus-coverage-smoke.json"
NATIVE_ALLOCATION_REPORT_ARTIFACT = "vort-native-allocation-report.json"
NATIVE_ALLOCATION_REPORT_MARKDOWN_ARTIFACT = "vort-native-allocation-report.md"
NATIVE_ALLOCATION_SMOKE_ARTIFACT = "vort-native-allocation-smoke.json"
NATIVE_ALLOCATION_NEGATIVE_ARTIFACT = "vort-native-allocation-negative-smoke.json"
NATIVE_LIBRARY_BENCH_ARTIFACT = "vort-native-library-bench.csv"
ZSTD_COMPARE_ARTIFACT = "vort-zstd-compare-gate.json"
ZSTD_COMPARE_STANDARD_ARTIFACT = "vort-zstd-compare-standard-gate.json"
ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT = "vort-zstd-compare-block-sweep-gate.json"
ZSTD_COMPARE_CSV_ARTIFACT = "vort-zstd-compare.csv"
ZSTD_COMPARE_MARKDOWN_ARTIFACT = "vort-zstd-compare.md"
ZSTD_COMPARE_STANDARD_CSV_ARTIFACT = "vort-zstd-compare-standard.csv"
ZSTD_COMPARE_STANDARD_MARKDOWN_ARTIFACT = "vort-zstd-compare-standard.md"
ZSTD_COMPARE_BLOCK_SWEEP_CSV_ARTIFACT = "vort-zstd-compare-block-sweep.csv"
ZSTD_COMPARE_BLOCK_SWEEP_MARKDOWN_ARTIFACT = "vort-zstd-compare-block-sweep.md"
NATIVE_SUMMARY_ERROR_ARTIFACT = "vort-native-summary-error-dashboard.json"
NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT = "vort-native-summary-error-negative-smoke.json"
NATIVE_CODEC_PROBES_ARTIFACT = "vort-native-codec-probes.json"
NATIVE_CODEC_PROBES_MARKDOWN_ARTIFACT = "vort-native-codec-probes.md"
LZ4_NATIVE_SUMMARY_ARTIFACT = "vort-lz4-native-stream-summary.json"
ZSTD_NATIVE_SUMMARY_ARTIFACT = "vort-zstd-native-stream-summary.json"
NATIVE_TIER_RANGE_ARTIFACT = "vort-native-tier-range-bench-gate.json"
NATIVE_TIER_RANGE_FILES_ARTIFACT = "vort-native-tier-range-files-bench-gate.json"
NATIVE_TIER_RANGE_CORPUS_ARTIFACT = "vort-native-tier-range-corpus-bench-gate.json"
NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT = "vort-native-tier-range-corpus-discovery.json"
NATIVE_TIER_RANGE_CSV_ARTIFACT = "vort-native-tier-range-bench.csv"
NATIVE_TIER_RANGE_FILES_CSV_ARTIFACT = "vort-native-tier-range-files-bench.csv"
NATIVE_TIER_RANGE_CORPUS_CSV_ARTIFACT = "vort-native-tier-range-corpus-bench.csv"
NATIVE_TIER_RANGE_ARTIFACTS = (
    (NATIVE_TIER_RANGE_ARTIFACT, "zig build run-native-tier-range-bench-gate"),
    (NATIVE_TIER_RANGE_CSV_ARTIFACT, "zig build run-native-tier-range-bench-gate"),
    (NATIVE_TIER_RANGE_FILES_ARTIFACT, "zig build run-native-tier-range-files-bench-gate"),
    (NATIVE_TIER_RANGE_FILES_CSV_ARTIFACT, "zig build run-native-tier-range-files-bench-gate"),
    (NATIVE_TIER_RANGE_CORPUS_ARTIFACT, "zig build run-native-tier-range-corpus-bench-gate"),
    (NATIVE_TIER_RANGE_CORPUS_CSV_ARTIFACT, "zig build run-native-tier-range-corpus-bench-gate"),
    (NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT, "zig build run-native-tier-range-corpus-bench-gate"),
)
NATIVE_TIER_RANGE_FLOORS = {
    "built_in": {"seek_fast": 60.0, "balanced": 16.0, "ratio": 12.0},
    "project_files": {"seek_fast": 40.0, "balanced": 8.0, "ratio": 4.0},
    "standard_corpus": {"seek_fast": 30.0, "balanced": 6.5, "ratio": 3.5},
    "custom": {"seek_fast": 20.0, "balanced": 6.0, "ratio": 3.0},
}
NATIVE_TIER_RANGE_TIERS = {"seek_fast": 8192, "balanced": 32768, "ratio": 65536}
NATIVE_TIER_RANGE_FIXTURES = {
    "built_in": ["text", "structured", "repetitive"],
    "project_files": ["README.md", "roadmap.md"],
    "standard_corpus": ["ooffice-128k", "nci-128k", "mozilla-128k"],
}
NATIVE_TIER_RANGE_CSV_BY_SOURCE = {
    "built_in": NATIVE_TIER_RANGE_CSV_ARTIFACT,
    "project_files": NATIVE_TIER_RANGE_FILES_CSV_ARTIFACT,
    "standard_corpus": NATIVE_TIER_RANGE_CORPUS_CSV_ARTIFACT,
}
NATIVE_TIER_RANGE_INPUT_BYTES = 131072
NATIVE_TIER_RANGE_STREAM_BYTES = 4096
NATIVE_TIER_RANGE_RANGE_OFFSET = 1024
NATIVE_TIER_RANGE_RANGE_LEN = 4096
NATIVE_TIER_RANGE_ITERATIONS = 400
NATIVE_TIER_RANGE_REPEAT = 3
NATIVE_TIER_RANGE_ELAPSED_NS = 19_000_000
NATIVE_TIER_RANGE_RANGE_MIB_S = ((NATIVE_TIER_RANGE_RANGE_LEN * NATIVE_TIER_RANGE_ITERATIONS) / (1024.0 * 1024.0)) / (NATIVE_TIER_RANGE_ELAPSED_NS / 1_000_000_000.0)
NATIVE_TIER_RANGE_FULL_INPUT_MIB_S = ((NATIVE_TIER_RANGE_INPUT_BYTES * NATIVE_TIER_RANGE_ITERATIONS) / (1024.0 * 1024.0)) / (NATIVE_TIER_RANGE_ELAPSED_NS / 1_000_000_000.0)


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_csv_header_manifest(root: Path) -> Path:
    rows: list[dict[str, object]] = []
    for path in sorted(root.glob("vort-*.csv")):
        with path.open(newline="") as f:
            header = next(csv.reader(f), [])
        rows.append({
            "name": path.name,
            "column_count": len(header),
            "signature": hashlib.sha256("\x1f".join(header).encode("utf-8")).hexdigest()[:16],
        })
    payload = {
        "schema": "vort.dashboard_csv_header_manifest",
        "schema_version": 1,
        "artifact_count": len(rows),
        "artifacts": rows,
    }
    path = root / "dashboard-csv-header-manifest.json"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    return path


def write_markdown_heading_manifest(root: Path) -> Path:
    rows: list[dict[str, object]] = []
    for path in sorted(root.glob("vort-*.md")):
        lines = path.read_text(errors="replace").splitlines()
        headings = [line.strip() for line in lines if line.startswith("#")]
        rows.append({
            "name": path.name,
            "heading_count": len(headings),
            "first_heading": headings[0] if headings else "",
            "signature": hashlib.sha256("\x1f".join(headings).encode("utf-8")).hexdigest()[:16],
            "table_row_count": sum(1 for line in lines if line.strip().startswith("|")),
            "table_separator_count": sum(1 for line in lines if re.match(r"^\s*\|\s*:?-{3,}:?", line)),
        })
    payload = {
        "schema": "vort.dashboard_markdown_heading_manifest",
        "schema_version": 1,
        "artifact_count": len(rows),
        "artifacts": rows,
    }
    path = root / "dashboard-markdown-heading-manifest.json"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    return path


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
    include_level_report_exact: bool = True,
    include_level_report_smoke: bool = True,
    include_dynamic_plan_exact: bool = True,
    include_dynamic_plan_smoke: bool = True,
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
    include_deflate_chunked_huffman_bench_exact: bool = True,
    include_deflate_chunked_huffman_bench_smoke: bool = True,
    include_deflate_extra_bits_bench_exact: bool = True,
    include_deflate_extra_bits_bench_smoke: bool = True,
    include_dictionary_decode_bench_exact: bool = True,
    include_dictionary_decode_bench_smoke: bool = True,
    include_png_scanline_bench_exact: bool = True,
    include_png_scanline_bench_smoke: bool = True,
    include_chunked_zlib_bench_exact: bool = True,
    include_chunked_zlib_bench_smoke: bool = True,
    include_png_streaming_zlib_bench_exact: bool = True,
    include_png_streaming_zlib_bench_smoke: bool = True,
    include_deflate_dynamic_decode_profile_exact: bool = True,
    include_deflate_dynamic_decode_profile_smoke: bool = True,
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
    include_native_library_bench_exact: bool = True,
    include_native_library_bench_smoke: bool = True,
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
        artifact_metadata[HEADER_INSPECT_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-header-inspect-dashboard",
        }
    if include_strict_smoke:
        artifact_metadata[DASHBOARD_STRICT_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-dashboard-strict-smoke",
        }
        artifact_metadata[DASHBOARD_STRICT_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
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
        artifact_metadata[SIDECAR_CORRUPT_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-sidecar-corrupt-dashboard",
        }
    if include_huffman_smoke:
        artifact_metadata[HUFFMAN_LENGTH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-huffman-length-report-dashboard",
        }
        artifact_metadata["vort-huffman-length-report.md"] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-huffman-length-report-dashboard",
        }
    if include_level_report_smoke:
        artifact_metadata[LEVEL_REPORT_CSV_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-level-report-csv",
        }
        artifact_metadata[LEVEL_REPORT_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-level-report-dashboard",
        }
    if include_dynamic_plan_smoke:
        artifact_metadata[DYNAMIC_PLAN_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-dynamic-plan-report-csv",
        }
        artifact_metadata[DYNAMIC_PLAN_BUILTINS_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-dynamic-plan-builtins-report-csv",
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
    if include_deflate_chunked_huffman_bench_smoke:
        artifact_metadata[DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-chunked-huffman-bench-gate",
        }
    if include_deflate_extra_bits_bench_smoke:
        artifact_metadata[DEFLATE_EXTRA_BITS_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-extra-bits-bench-gate",
        }
    if include_dictionary_decode_bench_smoke:
        artifact_metadata[DICTIONARY_DECODE_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-dictionary-decode-bench-gate",
        }
    if include_png_scanline_bench_smoke:
        artifact_metadata[PNG_SCANLINE_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-png-scanline-bench-gate",
        }
    if include_chunked_zlib_bench_smoke:
        artifact_metadata[CHUNKED_ZLIB_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-chunked-zlib-bench-report-gate",
        }
        artifact_metadata[CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-chunked-zlib-bench-report-gate",
        }
    if include_png_streaming_zlib_bench_smoke:
        artifact_metadata[PNG_STREAMING_ZLIB_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-png-streaming-zlib-bench-report-gate",
        }
    if include_deflate_dynamic_decode_profile_smoke:
        artifact_metadata[DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-dynamic-decode-profile-gate",
        }
    if include_fuzz_corpus_smoke:
        artifact_metadata[FUZZ_CORPUS_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-deflate-wrapper-fuzz-corpus-dashboard",
        }
        artifact_metadata[FUZZ_CORPUS_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
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
        artifact_metadata[DECODE_STAGE_CSV_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-deflate-decode-stage-report-dashboard",
        }
        artifact_metadata[DECODE_STAGE_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-deflate-decode-stage-report-dashboard",
        }
    if include_python_zlib_smoke:
        artifact_metadata[PYTHON_ZLIB_DIFF_ARTIFACT] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-python-zlib-diff-dashboard",
        }
    if include_zlib_relaxed_smoke:
        for artifact, expected_format in ((ZLIB_RELAXED_ARTIFACT, "json"), (ZLIB_RELAXED_MARKDOWN_ARTIFACT, "md"), (ZLIB_RELAXED_GATE_ARTIFACT, "json")):
            artifact_metadata[artifact] = {
                "expected_format": expected_format,
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
        artifact_metadata[PNG_SCRATCH_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
            "smoke_gate": "zig build run-png-scratch-report-dashboard",
        }
    if include_br_static_smoke:
        for artifact, expected_format, smoke_gate in (
            (BR_STATIC_CANDIDATES_ARTIFACT, "json", "zig build run-br-static-dictionary-candidate-report-smoke"),
            (BR_STATIC_CANDIDATES_MARKDOWN_ARTIFACT, "md", "zig build run-br-static-dictionary-candidate-report-smoke"),
            (BR_STATIC_UPSTREAM_ARTIFACT, "json", "zig build run-br-static-dictionary-candidate-upstream-smoke"),
            (BR_STATIC_UPSTREAM_REPORT_ARTIFACT, "json", "zig build run-br-static-dictionary-candidate-upstream-smoke"),
            (BR_STATIC_UPSTREAM_MARKDOWN_ARTIFACT, "md", "zig build run-br-static-dictionary-candidate-upstream-smoke"),
            (BR_STATIC_NODE_ARTIFACT, "json", "zig build run-br-static-dictionary-node-probe"),
            (BR_STATIC_NODE_MARKDOWN_ARTIFACT, "md", "zig build run-br-static-dictionary-node-probe"),
            (BR_STATIC_AUDIT_ARTIFACT, "json", "zig build run-br-static-dictionary-source-audit"),
            (BR_STATIC_AUDIT_NEGATIVE_ARTIFACT, "json", "zig build run-br-static-dictionary-source-audit-negative-smoke"),
            (BR_STATIC_REPORT_CSV_ARTIFACT, "csv", "zig build run-br-static-dictionary-report-smoke"),
            (BR_STATIC_REPORT_JSON_ARTIFACT, "json", "zig build run-br-static-dictionary-report-smoke"),
            (BR_STATIC_REPORT_MARKDOWN_ARTIFACT, "md", "zig build run-br-static-dictionary-report-smoke"),
            (BR_STATIC_REPORT_NEGATIVE_ARTIFACT, "json", "zig build run-br-static-dictionary-report-negative-smoke"),
        ):
            artifact_metadata[artifact] = {"expected_format": expected_format, "smoke_gate": smoke_gate}
    if include_native_fuzz_smoke:
        artifact_metadata[NATIVE_FUZZ_ARTIFACT] = {"expected_format": "json", "smoke_gate": "zig build run-native-fuzz-corpus-dashboard"}
        artifact_metadata[NATIVE_FUZZ_MARKDOWN_ARTIFACT] = {"expected_format": "md", "smoke_gate": "zig build run-native-fuzz-corpus-dashboard"}
        artifact_metadata[NATIVE_FUZZ_COVERAGE_ARTIFACT] = {"expected_format": "json", "smoke_gate": "zig build run-native-fuzz-corpus-coverage-smoke"}
    if include_native_allocation_smoke:
        for artifact, expected_format, smoke_gate in (
            (NATIVE_ALLOCATION_REPORT_ARTIFACT, "json", "zig build run-native-allocation-report-dashboard"),
            (NATIVE_ALLOCATION_REPORT_MARKDOWN_ARTIFACT, "md", "zig build run-native-allocation-report-dashboard"),
            (NATIVE_ALLOCATION_SMOKE_ARTIFACT, "json", "zig build run-native-allocation-smoke"),
            (NATIVE_ALLOCATION_NEGATIVE_ARTIFACT, "json", "zig build run-native-allocation-negative-smoke"),
        ):
            artifact_metadata[artifact] = {
                "expected_format": expected_format,
                "smoke_gate": smoke_gate,
            }
    if include_native_library_bench_smoke:
        artifact_metadata[NATIVE_LIBRARY_BENCH_ARTIFACT] = {
            "expected_format": "csv",
            "smoke_gate": "zig build run-native-library-bench-gate",
        }
    if include_zstd_compare_smoke:
        for artifact, expected_format, smoke_gate in (
            (ZSTD_COMPARE_ARTIFACT, "json", "zig build run-zstd-compare-gate"),
            (ZSTD_COMPARE_CSV_ARTIFACT, "csv", "zig build run-zstd-compare-gate"),
            (ZSTD_COMPARE_MARKDOWN_ARTIFACT, "md", "zig build run-zstd-compare-gate"),
            (ZSTD_COMPARE_STANDARD_ARTIFACT, "json", "zig build run-zstd-compare-standard-gate"),
            (ZSTD_COMPARE_STANDARD_CSV_ARTIFACT, "csv", "zig build run-zstd-compare-standard-gate"),
            (ZSTD_COMPARE_STANDARD_MARKDOWN_ARTIFACT, "md", "zig build run-zstd-compare-standard-gate"),
            (ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT, "json", "zig build run-zstd-compare-block-sweep-gate"),
            (ZSTD_COMPARE_BLOCK_SWEEP_CSV_ARTIFACT, "csv", "zig build run-zstd-compare-block-sweep-gate"),
            (ZSTD_COMPARE_BLOCK_SWEEP_MARKDOWN_ARTIFACT, "md", "zig build run-zstd-compare-block-sweep-gate"),
        ):
            artifact_metadata[artifact] = {
                "expected_format": expected_format,
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
        artifact_metadata[NATIVE_CODEC_PROBES_MARKDOWN_ARTIFACT] = {
            "expected_format": "md",
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
                "expected_format": "csv" if artifact.endswith(".csv") else "json",
                "smoke_gate": smoke_gate,
            }
    exact = {}
    if include_header_exact:
        exact[HEADER_INSPECT_ARTIFACT] = "zig build run-header-inspect-dashboard"
        exact[HEADER_INSPECT_MARKDOWN_ARTIFACT] = "zig build run-header-inspect-dashboard"
    if include_strict_exact:
        exact[DASHBOARD_STRICT_ARTIFACT] = "zig build run-dashboard-strict-smoke"
        exact[DASHBOARD_STRICT_MARKDOWN_ARTIFACT] = "zig build run-dashboard-strict-smoke"
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
        exact[SIDECAR_CORRUPT_MARKDOWN_ARTIFACT] = "zig build run-sidecar-corrupt-dashboard"
    if include_huffman_exact:
        exact[HUFFMAN_LENGTH_ARTIFACT] = "zig build run-huffman-length-report-dashboard"
        exact["vort-huffman-length-report.md"] = "zig build run-huffman-length-report-dashboard"
    if include_level_report_exact:
        exact[LEVEL_REPORT_CSV_ARTIFACT] = "zig build run-level-report-csv"
        exact[LEVEL_REPORT_MARKDOWN_ARTIFACT] = "zig build run-level-report-dashboard"
    if include_dynamic_plan_exact:
        exact[DYNAMIC_PLAN_ARTIFACT] = "zig build run-dynamic-plan-report-csv"
        exact[DYNAMIC_PLAN_BUILTINS_ARTIFACT] = "zig build run-dynamic-plan-builtins-report-csv"
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
    if include_deflate_chunked_huffman_bench_exact:
        exact[DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT] = "zig build run-deflate-chunked-huffman-bench-gate"
    if include_deflate_extra_bits_bench_exact:
        exact[DEFLATE_EXTRA_BITS_BENCH_ARTIFACT] = "zig build run-deflate-extra-bits-bench-gate"
    if include_dictionary_decode_bench_exact:
        exact[DICTIONARY_DECODE_BENCH_ARTIFACT] = "zig build run-dictionary-decode-bench-gate"
    if include_png_scanline_bench_exact:
        exact[PNG_SCANLINE_BENCH_ARTIFACT] = "zig build run-png-scanline-bench-gate"
    if include_chunked_zlib_bench_exact:
        exact[CHUNKED_ZLIB_BENCH_ARTIFACT] = "zig build run-chunked-zlib-bench-report-gate"
        exact[CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT] = "zig build run-chunked-zlib-bench-report-gate"
    if include_png_streaming_zlib_bench_exact:
        exact[PNG_STREAMING_ZLIB_BENCH_ARTIFACT] = "zig build run-png-streaming-zlib-bench-report-gate"
    if include_deflate_dynamic_decode_profile_exact:
        exact[DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT] = "zig build run-deflate-dynamic-decode-profile-gate"
    if include_fuzz_corpus_exact:
        exact[FUZZ_CORPUS_ARTIFACT] = "zig build run-deflate-wrapper-fuzz-corpus-dashboard"
        exact[FUZZ_CORPUS_MARKDOWN_ARTIFACT] = "zig build run-deflate-wrapper-fuzz-corpus-dashboard"
    if include_fuzz_coverage_exact:
        exact[FUZZ_COVERAGE_ARTIFACT] = "zig build run-fuzz-corpus-coverage-smoke"
    if include_decode_stage_exact:
        exact[DECODE_STAGE_ARTIFACT] = "zig build run-deflate-decode-stage-report-dashboard"
        exact[DECODE_STAGE_CSV_ARTIFACT] = "zig build run-deflate-decode-stage-report-dashboard"
        exact[DECODE_STAGE_MARKDOWN_ARTIFACT] = "zig build run-deflate-decode-stage-report-dashboard"
    if include_python_zlib_exact:
        exact[PYTHON_ZLIB_DIFF_ARTIFACT] = "zig build run-python-zlib-diff-dashboard"
    if include_zlib_relaxed_exact:
        exact[ZLIB_RELAXED_ARTIFACT] = "zig build run-zlib-relaxed-report-gate"
        exact[ZLIB_RELAXED_MARKDOWN_ARTIFACT] = "zig build run-zlib-relaxed-report-gate"
        exact[ZLIB_RELAXED_GATE_ARTIFACT] = "zig build run-zlib-relaxed-report-gate"
    if include_snappy_report_exact:
        exact[SNAPPY_REPORT_ARTIFACT] = "zig build run-snappy-report-gate"
    if include_png_scratch_exact:
        exact[PNG_SCRATCH_ARTIFACT] = "zig build run-png-scratch-report-dashboard"
        exact[PNG_SCRATCH_MARKDOWN_ARTIFACT] = "zig build run-png-scratch-report-dashboard"
    if include_br_static_exact:
        exact[BR_STATIC_CANDIDATES_ARTIFACT] = "zig build run-br-static-dictionary-candidate-report-smoke"
        exact[BR_STATIC_CANDIDATES_MARKDOWN_ARTIFACT] = "zig build run-br-static-dictionary-candidate-report-smoke"
        exact[BR_STATIC_UPSTREAM_ARTIFACT] = "zig build run-br-static-dictionary-candidate-upstream-smoke"
        exact[BR_STATIC_UPSTREAM_REPORT_ARTIFACT] = "zig build run-br-static-dictionary-candidate-upstream-smoke"
        exact[BR_STATIC_UPSTREAM_MARKDOWN_ARTIFACT] = "zig build run-br-static-dictionary-candidate-upstream-smoke"
        exact[BR_STATIC_NODE_ARTIFACT] = "zig build run-br-static-dictionary-node-probe"
        exact[BR_STATIC_NODE_MARKDOWN_ARTIFACT] = "zig build run-br-static-dictionary-node-probe"
        exact[BR_STATIC_AUDIT_ARTIFACT] = "zig build run-br-static-dictionary-source-audit"
        exact[BR_STATIC_AUDIT_NEGATIVE_ARTIFACT] = "zig build run-br-static-dictionary-source-audit-negative-smoke"
        exact[BR_STATIC_REPORT_CSV_ARTIFACT] = "zig build run-br-static-dictionary-report-dashboard"
        exact[BR_STATIC_REPORT_JSON_ARTIFACT] = "zig build run-br-static-dictionary-report-dashboard"
        exact[BR_STATIC_REPORT_MARKDOWN_ARTIFACT] = "zig build run-br-static-dictionary-report-dashboard"
        exact[BR_STATIC_REPORT_NEGATIVE_ARTIFACT] = "zig build run-br-static-dictionary-report-negative-smoke"
    if include_native_fuzz_exact:
        exact[NATIVE_FUZZ_ARTIFACT] = "zig build run-native-fuzz-corpus-dashboard"
        exact[NATIVE_FUZZ_MARKDOWN_ARTIFACT] = "zig build run-native-fuzz-corpus-dashboard"
        exact[NATIVE_FUZZ_COVERAGE_ARTIFACT] = "zig build run-native-fuzz-corpus-coverage-smoke"
    if include_native_allocation_exact:
        exact[NATIVE_ALLOCATION_REPORT_ARTIFACT] = "zig build run-native-allocation-report-dashboard"
        exact[NATIVE_ALLOCATION_REPORT_MARKDOWN_ARTIFACT] = "zig build run-native-allocation-report-dashboard"
        exact[NATIVE_ALLOCATION_SMOKE_ARTIFACT] = "zig build run-native-allocation-smoke"
        exact[NATIVE_ALLOCATION_NEGATIVE_ARTIFACT] = "zig build run-native-allocation-negative-smoke"
    if include_native_library_bench_exact:
        exact[NATIVE_LIBRARY_BENCH_ARTIFACT] = "zig build run-native-library-bench-gate"
    if include_zstd_compare_exact:
        exact[ZSTD_COMPARE_ARTIFACT] = "zig build run-zstd-compare-gate"
        exact[ZSTD_COMPARE_CSV_ARTIFACT] = "zig build run-zstd-compare-gate"
        exact[ZSTD_COMPARE_MARKDOWN_ARTIFACT] = "zig build run-zstd-compare-gate"
        exact[ZSTD_COMPARE_STANDARD_ARTIFACT] = "zig build run-zstd-compare-standard-gate"
        exact[ZSTD_COMPARE_STANDARD_CSV_ARTIFACT] = "zig build run-zstd-compare-standard-gate"
        exact[ZSTD_COMPARE_STANDARD_MARKDOWN_ARTIFACT] = "zig build run-zstd-compare-standard-gate"
        exact[ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT] = "zig build run-zstd-compare-block-sweep-gate"
        exact[ZSTD_COMPARE_BLOCK_SWEEP_CSV_ARTIFACT] = "zig build run-zstd-compare-block-sweep-gate"
        exact[ZSTD_COMPARE_BLOCK_SWEEP_MARKDOWN_ARTIFACT] = "zig build run-zstd-compare-block-sweep-gate"
    if include_native_summary_error_exact:
        exact[NATIVE_SUMMARY_ERROR_ARTIFACT] = "zig build run-native-summary-error-dashboard"
    if include_native_summary_error_negative_exact:
        exact[NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT] = "zig build run-native-summary-error-negative-smoke"
    if include_native_codec_probes_exact:
        exact[NATIVE_CODEC_PROBES_ARTIFACT] = "zig build run-native-codec-probes-dashboard"
        exact[NATIVE_CODEC_PROBES_MARKDOWN_ARTIFACT] = "zig build run-native-codec-probes-dashboard"
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
    cases = [
        {
            "name": "raw_fixed",
            "schema_name": "vort.raw_deflate_header_info",
            "command": "inspect-raw-header-file",
            "sample": "cb48cdc9c90700",
            "argv": ["inspect-raw-header-file", "raw.bin"],
            "workflow": "file",
            "detail": "fixed",
            "format": "raw",
            "bytes": 7,
            "data_offset": 1,
            "has_dictionary": False,
            "has_optional_fields": False,
            "header_crc": False,
        },
        {
            "name": "zlib_dictionary",
            "schema_name": "vort.zlib_header_info",
            "command": "inspect-zlib-header-file",
            "sample": "78bb08610235cb4027013a2e067d",
            "argv": ["inspect-zlib-header-file", "zlib.bin"],
            "workflow": "file",
            "detail": "FDICT",
            "format": "zlib",
            "bytes": 14,
            "data_offset": 6,
            "has_dictionary": True,
            "has_optional_fields": False,
            "header_crc": False,
        },
        {
            "name": "gzip_optional",
            "schema_name": "vort.gzip_header_info",
            "command": "inspect-gzip-header-file",
            "sample": "1f8b081e000000000003a2b2",
            "argv": ["inspect-gzip-header-file", "gzip.bin"],
            "workflow": "file",
            "detail": "FEXTRA/FNAME/FCOMMENT/FHCRC",
            "format": "gzip",
            "bytes": 25,
            "data_offset": 10,
            "has_dictionary": False,
            "has_optional_fields": True,
            "header_crc": True,
        },
    ]
    if undercovered:
        cases = [case for case in cases if case["format"] != "raw"]
    negative_items = [
        {
            "name": "raw_reserved_btype",
            "format": "raw",
            "command": "inspect-raw-header-file",
            "sample": "07",
            "argv": ["inspect-raw-header-file", "raw-bad.bin"],
            "expected_error": "InvalidDeflateBlockType",
            "matched": True,
        },
        {
            "name": "zlib_bad_fcheck",
            "format": "zlib",
            "command": "inspect-zlib-header-file",
            "sample": "7802",
            "argv": ["inspect-zlib-header-file", "zlib-bad.bin"],
            "expected_error": "BadZlibHeader",
            "matched": True,
        },
        {
            "name": "gzip_bad_fhcrc",
            "format": "gzip",
            "command": "inspect-gzip-header-file",
            "sample": "1f8b0802000000000403a2b2",
            "argv": ["inspect-gzip-header-file", "gzip-bad.bin"],
            "expected_error": "BadGzipHeader",
            "matched": True,
        },
    ]
    command_coverage = [
        {"command": "inspect-raw-header-file", "format": "raw", "successes": raw_cases, "failures": raw_negative_cases},
        {"command": "inspect-zlib-header-file", "format": "zlib", "successes": zlib_cases, "failures": zlib_negative_cases},
        {"command": "inspect-gzip-header-file", "format": "gzip", "successes": gzip_cases, "failures": gzip_negative_cases},
    ]
    workflow_coverage = [
        {"command": "inspect-raw-header-file", "workflow": "file", "format": "raw", "successes": raw_cases},
        {"command": "inspect-zlib-header-file", "workflow": "file", "format": "zlib", "successes": zlib_cases},
        {"command": "inspect-gzip-header-file", "workflow": "file", "format": "gzip", "successes": gzip_cases},
    ]
    required_workflows = [{"command": "inspect-raw-header-file", "workflow": "file", "format": "raw"}]
    payload = {
        "schema": "vort.header_inspect_smoke",
        "schema_version": 1,
        "ok": ok,
        "cases": cases,
        "negative_items": negative_items,
        "command_coverage": command_coverage,
        "workflow_coverage": workflow_coverage,
        "required_workflows": required_workflows,
        "help_workflows": required_workflows,
        "help_workflow_count": len(required_workflows),
        "negative_error_counts": {"BadGzipHeader": 1, "BadZlibHeader": 1, "InvalidDeflateBlockType": 1},
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


def write_header_markdown(path: Path, *, ok: bool = True, undercovered: bool = False) -> None:
    raw_case_rows = [] if undercovered else ["| raw_fixed | `vort.raw_deflate_header_info` | 7 | fixed | `inspect-raw-header-file` | `cb48cdc9c90700` |"]
    raw_cases = 0 if undercovered else 1
    lines = [
        "# Vort header inspect smoke",
        "",
        f"- ok: `{ok}`",
        f"- cases: {raw_cases + 2} (raw={raw_cases}, zlib=1, gzip=1)",
        "- dictionary cases: 1",
        "- optional gzip header cases: 1",
        "- FHCRC cases: 1",
        "- malformed negative cases: 3",
        "",
        "## Format summary",
        "",
        "| format | cases | bytes | dictionary | optional headers | FHCRC |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        f"| raw | {raw_cases} | {7 if raw_cases else 0} | 0 | 0 | 0 |",
        "| zlib | 1 | 14 | 1 | 0 | 0 |",
        "| gzip | 1 | 25 | 0 | 1 | 1 |",
        "",
        "## Command coverage",
        "",
        "| command | format | successes | failures |",
        "| --- | --- | ---: | ---: |",
        f"| `inspect-raw-header-file` | raw | {raw_cases} | 1 |",
        "| `inspect-zlib-header-file` | zlib | 1 | 1 |",
        "| `inspect-gzip-header-file` | gzip | 1 | 1 |",
        "",
        "## Workflow coverage",
        "",
        "| command | workflow | format | successes |",
        "| --- | --- | --- | ---: |",
        f"| `inspect-raw-header-file` | file | raw | {raw_cases} |",
        "| `inspect-zlib-header-file` | file | zlib | 1 |",
        "| `inspect-gzip-header-file` | file | gzip | 1 |",
        "",
        "### Required workflow coverage",
        "",
        "- required rows: 1",
        "- missing rows: 0",
        "",
        "## Successful inspections",
        "",
        "### raw",
        "",
        "| name | schema | bytes | details | command | sample |",
        "| --- | --- | ---: | --- | --- | --- |",
        *raw_case_rows,
        "",
        "### zlib",
        "",
        "| name | schema | bytes | details | command | sample |",
        "| --- | --- | ---: | --- | --- | --- |",
        "| zlib_dictionary | `vort.zlib_header_info` | 14 | FDICT | `inspect-zlib-header-file` | `78bb08610235cb4027013a2e067d` |",
        "",
        "### gzip",
        "",
        "| name | schema | bytes | details | command | sample |",
        "| --- | --- | ---: | --- | --- | --- |",
        "| gzip_optional | `vort.gzip_header_info` | 25 | FEXTRA/FNAME/FCOMMENT/FHCRC | `inspect-gzip-header-file` | `1f8b081e000000000003a2b2` |",
        "",
        "## Expected failures",
        "",
        "| format | failures |",
        "| --- | ---: |",
        "| raw | 1 |",
        "| zlib | 1 |",
        "| gzip | 1 |",
        "",
        "### Error summary",
        "",
        "| expected error | failures |",
        "| --- | ---: |",
        "| `BadGzipHeader` | 1 |",
        "| `BadZlibHeader` | 1 |",
        "| `InvalidDeflateBlockType` | 1 |",
        "",
        "### raw",
        "",
        "| name | command | sample | expected error |",
        "| --- | --- | --- | --- |",
        "| raw_reserved_btype | `inspect-raw-header-file` | `07` | `InvalidDeflateBlockType` |",
        "",
        "### zlib",
        "",
        "| name | command | sample | expected error |",
        "| --- | --- | --- | --- |",
        "| zlib_bad_fcheck | `inspect-zlib-header-file` | `7802` | `BadZlibHeader` |",
        "",
        "### gzip",
        "",
        "| name | command | sample | expected error |",
        "| --- | --- | --- | --- |",
        "| gzip_bad_fhcrc | `inspect-gzip-header-file` | `1f8b0802000000000403a2b2` | `BadGzipHeader` |",
    ]
    path.write_text("\n".join(lines) + "\n")


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
    write_markdown(path.with_name(DASHBOARD_STRICT_MARKDOWN_ARTIFACT), payload)


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
        "observed_schema_count": 5,
        "observed_schemas": [
            "vort.validation_report",
            "vort.dashboard_index",
            "vort.dashboard_strict_smoke",
            "vort.header_inspect_smoke",
            "vort.gzip_header_info",
        ],
        "unchecked_observed_schema_count": 0,
        "unchecked_observed_schemas": [],
        "json_artifact_count": 5,
        "json_artifact_excluded_count": 2,
        "json_artifact_excluded_names": ["vort-dashboard-index.json", "vort-validation-json-smoke.json"],
        "json_artifact_parsed_count": 5,
        "json_artifact_schema_count": 5,
        "json_artifact_parse_failed_count": 0,
        "json_artifact_parse_failed": [],
        "json_artifact_missing_schema_count": 0,
        "json_artifact_missing_schema": [],
        "json_artifact_manifest_validated_count": 5,
        "json_artifact_manifest_failed_count": 0,
        "json_artifact_manifest_failed_names": [],
        "json_artifact_manifest_accounting_mismatch": 0,
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


def write_sidecar_corrupt_markdown(path: Path, *, ok: bool = True) -> None:
    rows = [
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
    ]
    lines = [
        "# Sidecar corrupt-payload smoke report",
        "",
        f"- rows: {len(rows)}",
        f"- metadata-ok rows: {sum(1 for row in rows if row['metadata_ok'])}",
        f"- full-rejected rows: {sum(1 for row in rows if row['full_rejected'])}",
        "",
        "| case | metadata ok | full rejected | full error | stream bytes | sidecar bytes |",
        "| --- | --- | --- | --- | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            "| {case} | {metadata_ok} | {full_rejected} | {full_error} | {stream_bytes} | {sidecar_bytes} |".format(
                case=row["case"],
                metadata_ok="true" if row["metadata_ok"] else "false",
                full_rejected="true" if row["full_rejected"] else "false",
                full_error=row["full_error"],
                stream_bytes=row["stream_bytes"],
                sidecar_bytes=row["sidecar_bytes"],
            )
        )
    path.write_text("\n".join(lines) + "\n")


def write_huffman_length_markdown(
    path: Path,
    *,
    row_count: int = 1,
    optimal_rows: int = 1,
    non_optimal_rows: int = 0,
    worst_gap_bits: int = 0,
    package_merge_optimal_rows: int = 1,
    package_merge_non_optimal_rows: int = 0,
    package_merge_worst_gap_bits: int = 0,
) -> None:
    row_is_optimal = non_optimal_rows == 0 and package_merge_non_optimal_rows == 0
    lines = [
        "# Huffman length-limit report",
        "",
        f"- rows: {row_count}",
        f"- optimal rows: {optimal_rows}",
        f"- non-optimal rows: {non_optimal_rows}",
        f"- worst gap bits: {worst_gap_bits}",
        "",
        f"- package-merge optimal rows: {package_merge_optimal_rows}",
        f"- package-merge non-optimal rows: {package_merge_non_optimal_rows}",
        f"- package-merge worst gap bits: {package_merge_worst_gap_bits}",
        "",
        "| case | symbols | max bits | optimal cost | actual cost | gap bits | package-merge cost | package-merge gap | Kraft | optimal? | package-merge optimal? | lengths | oracle lengths | package-merge lengths |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|",
    ]
    if row_count > 0:
        actual_cost = "5" if row_is_optimal else "6"
        gap_bits = "0" if row_is_optimal else "1"
        optimal = "true" if row_is_optimal else "false"
        lengths = "1;2;2" if row_is_optimal else "2;2;2"
        lines.append(
            f"| strict-smoke | 3 | 2 | 5 | {actual_cost} | {gap_bits} | {actual_cost} | {gap_bits} | 4/4 | {optimal} | {optimal} | {lengths} | 1;2;2 | {lengths} |"
        )
    path.write_text("\n".join(lines) + "\n")


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


def level_report_rows(*, healthy: bool = True) -> list[dict[str, str]]:
    cases = {
        "text": {"input": 2816, "base_raw": 65, "crc": 1058255176},
        "structured": {"input": 3136, "base_raw": 52, "crc": 682749180},
        "repeated": {"input": 2048, "base_raw": 16, "crc": 1144877804},
    }
    levels = [
        ("fastest", "hash", 40),
        ("fast", "hash", 28),
        ("default", "lazy", 0),
        ("best", "optimal", 2),
    ]
    strategies = [
        ("default", 0),
        ("filtered", 4),
        ("huffman_only", 320),
        ("rle", 12),
    ]

    rows: list[dict[str, str]] = []
    for case, case_info in cases.items():
        input_bytes = int(case_info["input"])
        base_raw = int(case_info["base_raw"])
        crc = int(case_info["crc"])
        for level, parser, level_delta in levels:
            for strategy, strategy_delta in strategies:
                if not healthy and case == "repeated" and level == "best" and strategy == "rle":
                    continue
                huffman_only = strategy == "huffman_only"
                raw_best_bytes = input_bytes + 2 if huffman_only else base_raw + level_delta + strategy_delta
                adaptive_bytes = raw_best_bytes
                literal_tokens = input_bytes if huffman_only else 1
                match_tokens = 0 if huffman_only else 1
                tokens = literal_tokens + match_tokens
                matched_bytes = 0 if huffman_only else input_bytes - 1
                match_coverage = (matched_bytes * 10_000) // input_bytes
                avg_match_len = 0 if match_tokens == 0 else (matched_bytes * 100) // match_tokens
                fixed_bits = input_bytes * 8
                rows.append(
                    {
                        "case": case,
                        "input_bytes": str(input_bytes),
                        "level": level,
                        "strategy": strategy,
                        "parser": parser,
                        "block_selection": "stored_fixed_dynamic",
                        "window_len": "32768",
                        "max_chain": "160",
                        "nice_len": "80",
                        "max_candidates": "6",
                        "lazy_min_gain": "1",
                        "min_match": "3",
                        "max_match": "258",
                        "min_savings_bits": "1",
                        "split_min": "8192",
                        "split_max": "65535",
                        "split_step": "8192",
                        "stored_fast_path": "false",
                        "tokens": str(tokens),
                        "literal_tokens": str(literal_tokens),
                        "match_tokens": str(match_tokens),
                        "matched_bytes": str(matched_bytes),
                        "match_coverage_x10000": str(match_coverage),
                        "avg_match_len_x100": str(avg_match_len),
                        "fixed_bits": str(fixed_bits),
                        "fixed_bits_per_byte_x100": str((fixed_bits * 100) // input_bytes),
                        "raw_best_bytes": str(raw_best_bytes),
                        "raw_best_ratio_x10000": str((raw_best_bytes * 10_000) // input_bytes),
                        "adaptive_bytes": str(adaptive_bytes),
                        "adaptive_ratio_x10000": str((adaptive_bytes * 10_000) // input_bytes),
                        "roundtrip_crc32": str(crc),
                    }
                )
    return rows


def write_level_report_csv(path: Path, *, healthy: bool = True) -> None:
    rows = level_report_rows(healthy=healthy)
    columns = [
        "case",
        "input_bytes",
        "level",
        "strategy",
        "parser",
        "block_selection",
        "window_len",
        "max_chain",
        "nice_len",
        "max_candidates",
        "lazy_min_gain",
        "min_match",
        "max_match",
        "min_savings_bits",
        "split_min",
        "split_max",
        "split_step",
        "stored_fast_path",
        "tokens",
        "literal_tokens",
        "match_tokens",
        "matched_bytes",
        "match_coverage_x10000",
        "avg_match_len_x100",
        "fixed_bits",
        "fixed_bits_per_byte_x100",
        "raw_best_bytes",
        "raw_best_ratio_x10000",
        "adaptive_bytes",
        "adaptive_ratio_x10000",
        "roundtrip_crc32",
    ]
    lines = [",".join(columns)]
    lines.extend(",".join(row[column] for column in columns) for row in rows)
    path.write_text("\n".join(lines) + "\n")


def write_level_report_markdown(path: Path, *, healthy: bool = True) -> None:
    rows = level_report_rows(healthy=healthy)

    def row_key(row: dict[str, str]) -> tuple[int, int, int]:
        return (int(row["raw_best_bytes"]), int(row["adaptive_bytes"]), int(row["tokens"]))

    def adaptive_key(row: dict[str, str]) -> tuple[int, int, int]:
        return (int(row["adaptive_bytes"]), int(row["raw_best_bytes"]), int(row["tokens"]))

    def percent(value: str) -> str:
        scaled = int(value)
        return f"{scaled // 100}.{scaled % 100:02d}%"

    def fixed2(value: str) -> str:
        scaled = int(value)
        return f"{scaled // 100}.{scaled % 100:02d}"

    lines = [
        "# Vort compression level report",
        "",
        f"Rows: {len(rows)}",
        "",
        "## Best rows by case",
        "",
        "| case | best raw | raw config | best adaptive | adaptive config | match coverage | tokens |",
        "|---|---:|---|---:|---|---:|---:|",
    ]
    for case in ("text", "structured", "repeated"):
        case_rows = [row for row in rows if row["case"] == case]
        if not case_rows:
            continue
        best_raw = min(case_rows, key=row_key)
        best_adaptive = min(case_rows, key=adaptive_key)
        lines.append(
            f"|{case} | {best_raw['raw_best_bytes']} | "
            f"{best_raw['level']}/{best_raw['strategy']}/{best_raw['parser']} | "
            f"{best_adaptive['adaptive_bytes']} | "
            f"{best_adaptive['level']}/{best_adaptive['strategy']}/{best_adaptive['parser']} | "
            f"{percent(best_adaptive['match_coverage_x10000'])} | {best_adaptive['tokens']} |"
        )
    lines.append("")
    lines.extend(
        [
            "| case | level | strategy | parser | raw bytes | raw ratio | adaptive bytes | adaptive ratio | match coverage | avg match len | fixed bits/byte | tokens | stored fast path |",
            "|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    for row in rows:
        lines.append(
            f"|{row['case']} | {row['level']} | {row['strategy']} | {row['parser']} | "
            f"{row['raw_best_bytes']} | {percent(row['raw_best_ratio_x10000'])} | "
            f"{row['adaptive_bytes']} | {percent(row['adaptive_ratio_x10000'])} | "
            f"{percent(row['match_coverage_x10000'])} | {fixed2(row['avg_match_len_x100'])} | "
            f"{fixed2(row['fixed_bits_per_byte_x100'])} | {row['tokens']} | {row['stored_fast_path']} |"
        )
    path.write_text("\n".join(lines) + "\n")



def write_dynamic_plan_csv(path: Path, rows: list[dict[str, str]], *, healthy: bool = True) -> None:
    columns = [
        "path",
        "input_bytes",
        "token_count",
        "literal_tokens",
        "match_tokens",
        "matched_bytes",
        "avg_match_len_x100",
        "avg_match_distance",
        "short_match_tokens",
        "far_match_tokens",
        "stored_bytes",
        "fixed_bytes",
        "dynamic_bytes",
        "dynamic_header_bits",
        "dynamic_literal_bits",
        "dynamic_length_bits",
        "dynamic_distance_bits",
        "dynamic_length_extra_bits",
        "dynamic_distance_extra_bits",
        "dynamic_extra_bits",
        "length_symbol_hist",
        "distance_symbol_hist",
        "length_extra_hist",
        "distance_extra_hist",
        "hlit",
        "hdist",
        "hclen",
        "code_length_ops",
        "stats_ns",
        "dynamic_encode_ns",
        "best_encode_ns",
        "dynamic_zlib_bytes",
        "best_zlib_bytes",
        "best_preset_token_count",
        "best_preset_literal_tokens",
        "best_preset_match_tokens",
        "best_preset_matched_bytes",
        "best_preset_avg_match_len_x100",
        "best_preset_avg_match_distance",
        "best_preset_short_match_tokens",
        "best_preset_far_match_tokens",
        "best_preset_zlib_bytes",
        "best_preset_header_bits",
        "best_preset_literal_bits",
        "best_preset_length_bits",
        "best_preset_distance_bits",
        "best_preset_length_extra_bits",
        "best_preset_distance_extra_bits",
        "best_preset_extra_bits",
        "best_preset_length_symbol_hist",
        "best_preset_distance_symbol_hist",
        "best_preset_length_extra_hist",
        "best_preset_distance_extra_hist",
        "best_preset_default_size_ratio",
        "best_preset_default_token_ratio",
        "best_preset_default_avg_len_ratio",
        "best_preset_default_avg_distance_ratio",
        "best_preset_default_header_ratio",
        "best_preset_default_literal_ratio",
        "best_preset_default_match_symbol_ratio",
        "best_preset_default_length_extra_ratio",
        "best_preset_default_distance_extra_ratio",
        "best_preset_default_extra_ratio",
        "fixed_dynamic_size_ratio",
        "best_dynamic_time_ratio",
        "stats_dynamic_time_ratio",
        "dynamic_bits_mod8",
        "dynamic_bits_to_save_byte",
        "best_preset_bits_mod8",
        "best_preset_bits_to_save_byte",
    ]
    length_symbol_hist = "1" + ";0" * 28
    distance_symbol_hist = "1" + ";0" * 29
    length_extra_hist = "1;0;0;0;0;0"
    distance_extra_hist = "1" + ";0" * 13
    lines = [",".join(columns)]
    for row in rows:
        values = {
            "input_bytes": "1024",
            "token_count": "11",
            "literal_tokens": "3",
            "match_tokens": "8",
            "matched_bytes": "1000",
            "avg_match_len_x100": "12500",
            "avg_match_distance": "4",
            "short_match_tokens": "2",
            "far_match_tokens": "3",
            "stored_bytes": "1029",
            "fixed_bytes": "80",
            "dynamic_bytes": "50",
            "dynamic_header_bits": "100",
            "dynamic_literal_bits": "20",
            "dynamic_length_bits": "12",
            "dynamic_distance_bits": "10",
            "dynamic_length_extra_bits": "4",
            "dynamic_distance_extra_bits": "6",
            "dynamic_extra_bits": "10",
            "length_symbol_hist": length_symbol_hist,
            "distance_symbol_hist": distance_symbol_hist,
            "length_extra_hist": length_extra_hist,
            "distance_extra_hist": distance_extra_hist,
            "hlit": "286",
            "hdist": "30",
            "hclen": "18",
            "code_length_ops": "16",
            "stats_ns": "1000",
            "dynamic_encode_ns": "2000",
            "best_encode_ns": "3000",
            "dynamic_zlib_bytes": "56",
            "best_zlib_bytes": "55",
            "best_preset_token_count": "10",
            "best_preset_literal_tokens": "3",
            "best_preset_match_tokens": "7",
            "best_preset_matched_bytes": "990",
            "best_preset_avg_match_len_x100": "14142",
            "best_preset_avg_match_distance": "5",
            "best_preset_short_match_tokens": "2",
            "best_preset_far_match_tokens": "3",
            "best_preset_zlib_bytes": "54",
            "best_preset_header_bits": "90",
            "best_preset_literal_bits": "18",
            "best_preset_length_bits": "10",
            "best_preset_distance_bits": "9",
            "best_preset_length_extra_bits": "3",
            "best_preset_distance_extra_bits": "5",
            "best_preset_extra_bits": "8",
            "best_preset_length_symbol_hist": length_symbol_hist,
            "best_preset_distance_symbol_hist": distance_symbol_hist,
            "best_preset_length_extra_hist": length_extra_hist,
            "best_preset_distance_extra_hist": distance_extra_hist,
            "best_preset_default_size_ratio": f"{54 / 55:.4f}",
            "best_preset_default_token_ratio": f"{10 / 11:.4f}",
            "best_preset_default_avg_len_ratio": f"{14142 / 12500:.4f}",
            "best_preset_default_avg_distance_ratio": f"{5 / 4:.4f}",
            "best_preset_default_header_ratio": f"{90 / 100:.4f}",
            "best_preset_default_literal_ratio": f"{18 / 20:.4f}",
            "best_preset_default_match_symbol_ratio": f"{(10 + 9) / (12 + 10):.4f}",
            "best_preset_default_length_extra_ratio": f"{3 / 4:.4f}",
            "best_preset_default_distance_extra_ratio": f"{5 / 6:.4f}",
            "best_preset_default_extra_ratio": f"{8 / 10:.4f}",
            "fixed_dynamic_size_ratio": f"{80 / 50:.4f}",
            "best_dynamic_time_ratio": f"{3000 / 2000:.4f}",
            "stats_dynamic_time_ratio": f"{1000 / 2000:.4f}",
            "dynamic_bits_mod8": "3",
            "dynamic_bits_to_save_byte": "3",
            "best_preset_bits_mod8": "5",
            "best_preset_bits_to_save_byte": "5",
        }
        values.update(row)
        if not healthy and values["path"] == rows[-1]["path"]:
            values["token_count"] = "12"
        lines.append(",".join(values[column] for column in columns))
    path.write_text("\n".join(lines) + "\n")


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
    bytes_value = 1 << 20
    iterations = 128
    elapsed_s = 0.1
    throughput_mib_s = ((bytes_value * iterations) / (1024.0 * 1024.0)) / elapsed_s
    for algorithm in algorithms:
        if not healthy and algorithm == "crc32c-best":
            continue
        mix = "287916550677" if algorithm.startswith("crc32c-") else "267872580117"
        if algorithm == "adler32":
            mix = "255981175488"
        lines.append(",".join([algorithm, str(bytes_value), str(iterations), f"{elapsed_s:.1f}", f"{throughput_mib_s:.2f}", mix]))
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
            iterations = 128
            elapsed_ns = 1_000
            bytes_per_s = (payload_bytes * iterations) / (elapsed_ns / 1_000_000_000.0)
            mib_per_s = bytes_per_s / (1024.0 * 1024.0)
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
                        str(iterations),
                        str(elapsed_ns),
                        f"{bytes_per_s:.2f}",
                        f"{mib_per_s:.2f}",
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
            length = 258
            ops_per_iter = 1024
            iterations = 64
            output_bytes = length * ops_per_iter * iterations
            elapsed_ns = 1_000_000
            output_mib_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
            lines.append(
                ",".join(
                    [
                        case,
                        class_name,
                        kernel,
                        str(length),
                        "16",
                        str(ops_per_iter),
                        str(iterations),
                        str(output_bytes),
                        str(elapsed_ns),
                        f"{output_mib_s:.2f}",
                        "12345",
                    ]
                )
            )
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
            iterations = 4096
            elapsed_ns = 1_000_000
            builds_per_s = iterations / (elapsed_ns / 1_000_000_000.0)
            checksum = symbols + lookup_bits * 100_000 + len(build) * 1_000 + len(case)
            lines.append(
                ",".join(
                    [
                        case,
                        build,
                        str(lookup_bits),
                        str(symbols),
                        str(iterations),
                        str(elapsed_ns),
                        f"{builds_per_s:.2f}",
                        str(checksum),
                    ]
                )
            )
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
            symbols_per_iter = 131072
            iterations = 96
            input_bytes = 1048576
            elapsed_ns = 1_000_000
            symbols_per_s = (symbols_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0)
            mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
            checksum = len(case) * 1_000_000 + symbols_per_iter
            lines.append(
                ",".join(
                    [
                        case,
                        decoder,
                        str(lookup_bits),
                        str(symbols_per_iter),
                        str(iterations),
                        str(input_bytes),
                        str(elapsed_ns),
                        f"{symbols_per_s:.2f}",
                        f"{mib_per_s:.2f}",
                        str(checksum),
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_deflate_chunked_huffman_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = ["case", "reader", "decoder", "lookup_bits", "chunk_bytes", "chunk_count", "symbols_per_iter", "iterations", "input_bytes", "elapsed_ns", "symbols_per_s", "mib_per_s", "checksum"]
    cases = {"fixed-literal": ("fixed_fast", 9), "dynamic-mixed": ("fast11", 11), "dynamic-long-tail": ("fast12", 12)}
    readers = {"buffered": 0, "chunked_4096": 4096, "coalesced_4096": 4096, "joined_4096": 4096, "windowed1024_4096": 4096, "windowed4096_4096": 4096, "span_4096": 4096, "chunked_64": 64, "coalesced_64": 64, "joined_64": 64, "windowed1024_64": 64, "windowed4096_64": 64, "span_64": 64, "chunked_1": 1, "coalesced_1": 1, "joined_1": 1, "windowed1024_1": 1, "windowed4096_1": 1, "span_1": 1}
    lines = [",".join(columns)]
    for case, (decoder, lookup_bits) in cases.items():
        for reader, chunk_bytes in readers.items():
            if not healthy and case == "dynamic-long-tail" and reader == "span_1":
                continue
            symbols_per_iter = 128 * 1024
            iterations = 64
            input_bytes_per_iteration = 8192
            input_bytes = input_bytes_per_iteration * iterations
            elapsed_ns = 1_000_000
            chunk_count = 0 if reader == "buffered" else (input_bytes_per_iteration + max(1, chunk_bytes) - 1) // max(1, chunk_bytes)
            symbols_per_s = (symbols_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0)
            mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
            checksum = len(case) * 1_000_000 + symbols_per_iter
            lines.append(
                ",".join(
                    [
                        case,
                        reader,
                        decoder,
                        str(lookup_bits),
                        str(chunk_bytes),
                        str(chunk_count),
                        str(symbols_per_iter),
                        str(iterations),
                        str(input_bytes),
                        str(elapsed_ns),
                        f"{symbols_per_s:.2f}",
                        f"{mib_per_s:.2f}",
                        str(checksum),
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_deflate_extra_bits_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "reader",
        "kernel",
        "bits",
        "reads_per_iter",
        "iterations",
        "repeat",
        "input_bytes",
        "elapsed_ns",
        "reads_per_s",
        "mib_per_s",
        "checksum",
    ]
    cases = {
        "extra-1": (1, ("single",)),
        "extra-3": (3, ("single",)),
        "extra-5": (5, ("single",)),
        "extra-9": (9, ("single",)),
        "extra-13": (13, ("single",)),
        "mixed-readme-length": (0, ("current", "staged")),
        "mixed-roadmap-length": (0, ("current", "staged")),
        "mixed-readme-distance": (0, ("mixed-extra",)),
        "mixed-roadmap-distance": (0, ("mixed-extra",)),
        "distance-readme-symbol-extra": (0, ("current", "fused18")),
        "distance-roadmap-symbol-extra": (0, ("current", "fused18")),
    }
    readers = ("buffered", "chunked_4096", "span_4096", "chunked_64", "span_64", "chunked_1", "span_1")
    lines = [",".join(columns)]
    for case, (bits, kernels) in cases.items():
        for reader in readers:
            checksum = len(case) * 1_000_000 + 131072
            for kernel in kernels:
                if not healthy and case == "distance-roadmap-symbol-extra" and reader == "span_1" and kernel == "fused18":
                    continue
                reads_per_iter = 131072
                iterations = 32
                input_bytes = 1048576
                elapsed_ns = 1_000_000
                reads_per_s = (reads_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0)
                mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
                lines.append(
                    ",".join(
                        [
                            case,
                            reader,
                            kernel,
                            str(bits),
                            str(reads_per_iter),
                            str(iterations),
                            "3",
                            str(input_bytes),
                            str(elapsed_ns),
                            f"{reads_per_s:.2f}",
                            f"{mib_per_s:.2f}",
                            str(checksum),
                        ]
                    )
                )
    path.write_text("\n".join(lines) + "\n")


def write_dictionary_decode_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "format",
        "encoder",
        "mode",
        "input_bytes",
        "dict_bytes",
        "compressed_bytes",
        "iterations",
        "repeat",
        "output_bytes",
        "elapsed_ns",
        "decode_mib_s",
        "checksum",
    ]
    rows = [
        ("history-replay-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("history-replay-raw-dynamic-exact_alloc", "raw", "dynamic", "exact_alloc"),
        ("history-replay-raw-dynamic-into", "raw", "dynamic", "into"),
        ("history-replay-raw-best-alloc", "raw", "best", "alloc"),
        ("history-replay-zlib-fixed-alloc", "zlib", "fixed", "alloc"),
        ("history-replay-zlib-fixed-exact_alloc", "zlib", "fixed", "exact_alloc"),
        ("history-replay-zlib-fixed-into", "zlib", "fixed", "into"),
        ("history-replay-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("history-replay-zlib-dynamic-exact_alloc", "zlib", "dynamic", "exact_alloc"),
        ("history-replay-zlib-dynamic-into", "zlib", "dynamic", "into"),
        ("json-prefix-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("json-prefix-raw-dynamic-into", "raw", "dynamic", "into"),
        ("json-prefix-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("json-prefix-zlib-dynamic-into", "zlib", "dynamic", "into"),
        ("log-prefix-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("log-prefix-raw-dynamic-into", "raw", "dynamic", "into"),
        ("log-prefix-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("log-prefix-zlib-dynamic-into", "zlib", "dynamic", "into"),
    ]
    lines = [",".join(columns)]
    for case, fmt, encoder, mode in rows:
        if not healthy and case == "log-prefix-zlib-dynamic-into":
            continue
        input_bytes = 1024
        iterations = 16
        output_bytes = input_bytes * iterations
        elapsed_ns = 1_000_000
        decode_mib_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
        payload = case
        for marker in ("-raw-", "-zlib-"):
            if marker in payload:
                payload = payload.split(marker, 1)[0]
                break
        checksum = len(payload) * 1_000_000 + input_bytes
        lines.append(
            ",".join(
                [
                    case,
                    fmt,
                    encoder,
                    mode,
                    str(input_bytes),
                    "128",
                    "64",
                    str(iterations),
                    "3",
                    str(output_bytes),
                    str(elapsed_ns),
                    f"{decode_mib_s:.2f}",
                    str(checksum),
                ]
            )
        )
    path.write_text("\n".join(lines) + "\n")


def write_png_scanline_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = ["stage", "bpp", "iterations", "repeat", "input_bytes", "output_bytes", "elapsed_ns", "output_mib_per_s", "checksum"]
    stages = ("none", "sub", "up", "average", "paeth")
    bpps = ("1", "2", "3", "4", "6", "8")
    lines = [",".join(columns)]
    for stage in stages:
        for bpp in bpps:
            if not healthy and stage == "paeth" and bpp == "8":
                continue
            iterations = 64
            repeat = 1
            input_bytes = 8192
            output_bytes = 8192
            elapsed_ns = 1_000_000
            output_mib_per_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
            checksum = int(bpp) * 1_000_000 + output_bytes
            lines.append(
                ",".join(
                    [
                        stage,
                        bpp,
                        str(iterations),
                        str(repeat),
                        str(input_bytes),
                        str(output_bytes),
                        str(elapsed_ns),
                        f"{output_mib_per_s:.2f}",
                        str(checksum),
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_chunked_zlib_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "encoder",
        "input_bytes",
        "zlib_bytes",
        "chunk_bytes",
        "chunk_count",
        "include_empty_chunks",
        "iterations",
        "repeat",
        "contiguous_mib_s",
        "chunk_join_mib_s",
        "chunk_direct_mib_s",
        "chunk_exact_mib_s",
        "direct_strategy",
        "direct_over_contiguous",
        "direct_over_join",
        "join_over_contiguous",
        "exact_over_direct",
        "mix",
    ]
    cases = {
        "png-rgb8-dynamic-64b": ("best", (96 * 3 + 1) * 64, 1180, 64, "false", "stack-join"),
        "png-rgb8-dynamic-1b-empty": ("best", (48 * 3 + 1) * 48, 1136, 1, "true", "stack-join"),
        "png-rgb8-literal-large-4k": ("dynamic_literal", (512 * 3 + 1) * 256, 4096, 4096, "false", "span-reader"),
        "png-rgb8-match-large-4k": ("best", (512 * 3 + 1) * 256, 4096, 4096, "false", "span-reader"),
        "png-rgba8-stored-256b": ("stored", (128 * 4 + 1) * 96, 49184, 256, "false", "stored-direct"),
        "png-indexed-stored-1b-empty": ("stored", (96 + 1) * 64, 6208, 1, "true", "stack-join"),
        "png-indexed-stored-7b-empty": ("stored", (257 + 1) * 48, 12392, 7, "true", "stack-join"),
        "png-literal-16b": ("dynamic_literal", (80 * 3 + 1) * 80, 256, 16, "false", "stack-join"),
    }

    def chunk_count(zlib_bytes: int, chunk_bytes: int, include_empty: str) -> int:
        non_empty = max(1, (zlib_bytes + chunk_bytes - 1) // chunk_bytes)
        return non_empty * 2 + 1 if include_empty == "true" else non_empty

    lines = [",".join(columns)]
    for case, (encoder, input_bytes, zlib_bytes, chunk_bytes, include_empty, direct_strategy) in cases.items():
        if not healthy and case == "png-literal-16b":
            continue
        contiguous = 100.0
        join = 90.0
        direct = 80.0
        exact = 70.0
        values = [
            case,
            encoder,
            str(input_bytes),
            str(zlib_bytes),
            str(chunk_bytes),
            str(chunk_count(zlib_bytes, chunk_bytes, include_empty)),
            include_empty,
            "64",
            "3",
            f"{contiguous:.2f}",
            f"{join:.2f}",
            f"{direct:.2f}",
            f"{exact:.2f}",
            direct_strategy,
            f"{direct / contiguous:.4f}",
            f"{direct / join:.4f}",
            f"{join / contiguous:.4f}",
            f"{exact / direct:.4f}",
            "12345",
        ]
        lines.append(",".join(values))
    path.write_text("\n".join(lines) + "\n")


def write_chunked_zlib_bench_markdown(path: Path, *, healthy: bool = True) -> None:
    with tempfile.NamedTemporaryFile("w+", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        write_chunked_zlib_bench_csv(tmp_path, healthy=healthy)
        with tmp_path.open(newline="") as f:
            rows = list(csv.DictReader(f))
    finally:
        tmp_path.unlink(missing_ok=True)
    lines = [
        "# Chunked zlib decode benchmark",
        "",
        "| case | encoder | input bytes | zlib bytes | chunk bytes | chunks | empty chunks | iterations | repeat | contiguous MiB/s | join MiB/s | direct MiB/s | exact alloc MiB/s | direct strategy | direct/contiguous | direct/join | join/contiguous | exact/direct |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['case']} | {row['encoder']} | {int(row['input_bytes'])} | {int(row['zlib_bytes'])} | "
            f"{int(row['chunk_bytes'])} | {int(row['chunk_count'])} | {row['include_empty_chunks']} | "
            f"{int(row['iterations'])} | {int(row['repeat'])} | {float(row['contiguous_mib_s']):.2f} | "
            f"{float(row['chunk_join_mib_s']):.2f} | {float(row['chunk_direct_mib_s']):.2f} | "
            f"{float(row['chunk_exact_mib_s']):.2f} | {row['direct_strategy']} | "
            f"{float(row['direct_over_contiguous']):.3f} | {float(row['direct_over_join']):.3f} | "
            f"{float(row['join_over_contiguous']):.3f} | {float(row['exact_over_direct']):.3f} |"
        )
    path.write_text("\n".join(lines) + "\n")


def write_png_streaming_zlib_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "encoder",
        "pattern",
        "width",
        "height",
        "row_bytes",
        "image_bytes",
        "zlib_bytes",
        "chunk_bytes",
        "chunk_count",
        "iterations",
        "repeat",
        "contiguous_mib_s",
        "chunked_mib_s",
        "chunked_over_contiguous",
        "mix",
    ]
    cases = {
        "png-stream-rle-dynamic": ("dynamic", "zero", 2048, 64, 2048, 131072, 150, 64),
        "png-stream-up-filter-dynamic": ("dynamic", "vertical_delta", 2048, 64, 2048, 131072, 624, 64),
        "png-stream-sub-filter-dynamic": ("dynamic", "horizontal_delta", 2048, 64, 2048, 131072, 640, 64),
        "png-stream-average-filter-dynamic": ("dynamic", "average_delta", 2048, 64, 2048, 131072, 704, 64),
        "png-stream-paeth-filter-dynamic": ("dynamic", "paeth_delta", 2048, 64, 2048, 131072, 704, 64),
        "png-stream-paeth-rgba8-dynamic": ("dynamic", "paeth_delta", 1024, 64, 4096, 262144, 1024, 64),
        "png-stream-small-distance-dynamic": ("dynamic", "abcd", 1024, 64, 4096, 262144, 1024, 64),
        "png-stream-row-repeat-dynamic": ("dynamic", "repeated_row", 1024, 96, 3072, 294912, 1152, 32),
        "png-stream-row-repeat-fixed": ("fixed", "repeated_row", 1024, 64, 3072, 196608, 1024, 32),
        "png-stream-wide-rle-dynamic": ("dynamic", "zero", 65536, 16, 65536, 1048576, 4096, 64),
    }
    lines = [",".join(columns)]
    for case, (encoder, pattern, width, height, row_bytes, image_bytes, zlib_bytes, chunk_bytes) in cases.items():
        if not healthy and case == "png-stream-wide-rle-dynamic":
            continue
        contiguous = 100.0
        chunked = 95.0
        chunk_count = max(1, (zlib_bytes + chunk_bytes - 1) // chunk_bytes)
        lines.append(
            ",".join(
                [
                    case,
                    encoder,
                    pattern,
                    str(width),
                    str(height),
                    str(row_bytes),
                    str(image_bytes),
                    str(zlib_bytes),
                    str(chunk_bytes),
                    str(chunk_count),
                    "64",
                    "3",
                    f"{contiguous:.2f}",
                    f"{chunked:.2f}",
                    f"{chunked / contiguous:.4f}",
                    "12345",
                ]
            )
        )
    path.write_text("\n".join(lines) + "\n")


def write_deflate_dynamic_decode_profile_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case",
        "input_bytes",
        "raw_bytes",
        "dynamic_hlit",
        "dynamic_hdist",
        "dynamic_literal_max_bits",
        "dynamic_distance_max_bits",
        "literal_lookup_bits",
        "payload_ns",
        "output_bytes",
        "literal_symbols",
        "length_symbols",
        "match_bytes",
        "distance_symbols",
        "length_symbol_histogram",
        "distance_symbol_histogram",
        "top_length_symbols",
        "top_distance_symbols",
        "top_length_extra_symbols",
        "top_distance_extra_symbols",
        "length_extra_width_reads",
        "distance_extra_width_reads",
        "length_extra_width_bits",
        "distance_extra_width_bits",
        "length_extra_reads",
        "distance_extra_reads",
        "length_extra_bits",
        "length_code_bits",
        "distance_extra_bits",
        "distance_code_bits",
        "distance_code_plus_extra_bits",
        "literal_fast_hits",
        "literal_fast_misses",
        "distance_fast_hits",
        "distance_fast_misses",
        "literal_lookup_covered",
        "literal_lookup_size",
        "distance_lookup_covered",
        "distance_lookup_size",
        "literal_lookup_coverage_ratio",
        "distance_lookup_coverage_ratio",
        "dominant_match_class",
        "dominant_match_byte_ratio",
        "match_rle_count",
        "match_rle_bytes",
        "match_small_distance_count",
        "match_small_distance_bytes",
        "match_non_overlapping_count",
        "match_non_overlapping_bytes",
        "match_overlapping_count",
        "match_overlapping_bytes",
        "match_rle_byte_ratio",
        "match_small_distance_byte_ratio",
        "match_non_overlapping_byte_ratio",
        "match_overlapping_byte_ratio",
        "match_class_length_extra_reads",
        "match_class_length_extra_bits",
        "match_class_distance_extra_reads",
        "match_class_distance_extra_bits",
        "match_class_distance_code_bits",
        "match_rle_extra_bits_per_match",
        "match_small_distance_extra_bits_per_match",
        "match_non_overlapping_extra_bits_per_match",
        "match_overlapping_extra_bits_per_match",
        "match_rle_extra_bits_per_byte",
        "match_small_distance_extra_bits_per_byte",
        "match_non_overlapping_extra_bits_per_byte",
        "match_overlapping_extra_bits_per_byte",
        "match_rle_distance_code_plus_extra_bits_per_match",
        "match_small_distance_code_plus_extra_bits_per_match",
        "match_non_overlapping_distance_code_plus_extra_bits_per_match",
        "match_overlapping_distance_code_plus_extra_bits_per_match",
        "literal_fast_miss_ratio",
        "distance_fast_miss_ratio",
        "extra_bits_per_match",
        "distance_code_plus_extra_bits_per_match",
        "mix",
    ]

    def zeros(count: int) -> list[str]:
        return ["0"] * count

    def row(case: str, *, chunked: bool = False) -> dict[str, str]:
        length_symbols = 4
        distance_symbols = 4
        length_hist = zeros(29)
        distance_hist = zeros(30)
        length_hist[0] = str(length_symbols)
        distance_hist[0] = str(distance_symbols)
        length_width_reads = zeros(14)
        distance_width_reads = zeros(14)
        length_width_bits = zeros(14)
        distance_width_bits = zeros(14)
        length_width_reads[0] = str(length_symbols)
        distance_width_reads[0] = str(distance_symbols)
        length_width_bits[0] = "8"
        distance_width_bits[0] = "12"
        input_bytes = (512 * 3 + 1) * 256 if chunked else 4096
        raw_bytes = 70000 if chunked else 512
        return {
            "case": case,
            "input_bytes": str(input_bytes),
            "raw_bytes": str(raw_bytes),
            "dynamic_hlit": "286",
            "dynamic_hdist": "30",
            "dynamic_literal_max_bits": "9",
            "dynamic_distance_max_bits": "5",
            "literal_lookup_bits": "9",
            "payload_ns": "1000",
            "output_bytes": str(input_bytes),
            "literal_symbols": "10",
            "length_symbols": str(length_symbols),
            "match_bytes": "400",
            "distance_symbols": str(distance_symbols),
            "length_symbol_histogram": ";".join(length_hist),
            "distance_symbol_histogram": ";".join(distance_hist),
            "top_length_symbols": "0:4;1:1;2:1",
            "top_distance_symbols": "0:4;1:1;2:1",
            "top_length_extra_symbols": "0:4;1:1;2:1",
            "top_distance_extra_symbols": "0:4;1:1;2:1",
            "length_extra_width_reads": ";".join(length_width_reads),
            "distance_extra_width_reads": ";".join(distance_width_reads),
            "length_extra_width_bits": ";".join(length_width_bits),
            "distance_extra_width_bits": ";".join(distance_width_bits),
            "length_extra_reads": "4",
            "distance_extra_reads": "4",
            "length_extra_bits": "8",
            "length_code_bits": "10",
            "distance_extra_bits": "12",
            "distance_code_bits": "20",
            "distance_code_plus_extra_bits": "32",
            "literal_fast_hits": "10",
            "literal_fast_misses": "0",
            "distance_fast_hits": "4",
            "distance_fast_misses": "0",
            "literal_lookup_covered": "512",
            "literal_lookup_size": "512",
            "distance_lookup_covered": "128",
            "distance_lookup_size": "256",
            "literal_lookup_coverage_ratio": "1.000000",
            "distance_lookup_coverage_ratio": "0.500000",
            "dominant_match_class": "non_overlapping",
            "dominant_match_byte_ratio": "1.000000",
            "match_rle_count": "0",
            "match_rle_bytes": "0",
            "match_small_distance_count": "0",
            "match_small_distance_bytes": "0",
            "match_non_overlapping_count": "4",
            "match_non_overlapping_bytes": "400",
            "match_overlapping_count": "0",
            "match_overlapping_bytes": "0",
            "match_rle_byte_ratio": "0.000000",
            "match_small_distance_byte_ratio": "0.000000",
            "match_non_overlapping_byte_ratio": "1.000000",
            "match_overlapping_byte_ratio": "0.000000",
            "match_class_length_extra_reads": "0;0;4;0",
            "match_class_length_extra_bits": "0;0;8;0",
            "match_class_distance_extra_reads": "0;0;4;0",
            "match_class_distance_extra_bits": "0;0;12;0",
            "match_class_distance_code_bits": "0;0;20;0",
            "match_rle_extra_bits_per_match": "0.000000",
            "match_small_distance_extra_bits_per_match": "0.000000",
            "match_non_overlapping_extra_bits_per_match": "5.000000",
            "match_overlapping_extra_bits_per_match": "0.000000",
            "match_rle_extra_bits_per_byte": "0.000000",
            "match_small_distance_extra_bits_per_byte": "0.000000",
            "match_non_overlapping_extra_bits_per_byte": "0.050000",
            "match_overlapping_extra_bits_per_byte": "0.000000",
            "match_rle_distance_code_plus_extra_bits_per_match": "0.000000",
            "match_small_distance_code_plus_extra_bits_per_match": "0.000000",
            "match_non_overlapping_distance_code_plus_extra_bits_per_match": "8.000000",
            "match_overlapping_distance_code_plus_extra_bits_per_match": "0.000000",
            "literal_fast_miss_ratio": "0.000000",
            "distance_fast_miss_ratio": "0.000000",
            "extra_bits_per_match": "5.000000",
            "distance_code_plus_extra_bits_per_match": "8.000000",
            "mix": "12345",
        }

    rows = [row("README.md"), row("docs/roadmap.md"), row("chunked-window-match", chunked=True)]
    if not healthy:
        rows.pop()
    lines = [",".join(columns)]
    for item in rows:
        lines.append(",".join(item[column] for column in columns))
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


def write_fuzz_corpus_markdown(path: Path, *, ok: bool = True) -> None:
    matched_rows = 3 if ok else 2
    actual_zlib_error = "InvalidDeflateBlockType" if ok else "ChecksumMismatch"
    zlib_matched = "true" if ok else "false"
    lines = [
        "# Deflate wrapper fuzz corpus report",
        "",
        "- mode: `mixed`",
        "- cases: 3",
        "- accepted: 1",
        "- rejected: 2",
        "- exact error expectations: 2",
        f"- matched rows: {matched_rows}",
        "",
        "## Mode summary",
        "",
        "| mode | cases | accepted | rejected | exact error expectations | matched rows |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        "| deflate | 1 | 0 | 1 | 1 | 1 |",
        f"| zlib | 1 | 0 | 1 | 1 | {1 if ok else 0} |",
        "| gzip | 1 | 1 | 0 | 0 | 1 |",
        "",
        "## Error summary",
        "",
        "| mode | error | count |",
        "| --- | --- | ---: |",
        "| deflate | `InvalidDeflateBlockType` | 1 |",
        f"| zlib | `{actual_zlib_error}` | 1 |",
        "",
        "## Samples",
        "",
        "| index | mode | input bytes | expected | expected error | outcome | actual error | matched |",
        "| ---: | --- | ---: | --- | --- | --- | --- | --- |",
        "| 0 | deflate | 2 | reject | `InvalidDeflateBlockType` | rejected | `InvalidDeflateBlockType` | true |",
        f"| 1 | zlib | 2 | reject | `InvalidDeflateBlockType` | rejected | `{actual_zlib_error}` | {zlib_matched} |",
        "| 2 | gzip | 3 | accept | `` | accepted | `` | true |",
    ]
    path.write_text("\n".join(lines) + "\n")


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
                "raw_block_type": "fixed",
                "raw_header_bits": 3,
                "raw_header_bytes": 1,
                "dynamic_hlit": 0,
                "dynamic_hdist": 0,
                "dynamic_hclen": 0,
                "dynamic_literal_nonzero": 0,
                "dynamic_literal_zero": 0,
                "dynamic_literal_max_bits": 0,
                "dynamic_distance_nonzero": 0,
                "dynamic_distance_zero": 0,
                "dynamic_distance_max_bits": 0,
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


def write_decode_stage_markdown(path: Path, *, ok: bool = True) -> None:
    actual_zlib_error = "ChecksumMismatch" if ok else "TrailingData"
    zlib_matched = "true" if ok else "false"
    lines = [
        "# Deflate decode stage report",
        "",
        "| case | input bytes | raw bytes | block | header bits/bytes | HLIT/HDIST/HCLEN | lit nz/zero/max | dist nz/zero/max | iterations | repeat | raw alloc MiB/s |",
        "| --- | ---: | ---: | --- | ---: | --- | --- | --- | ---: | ---: | ---: |",
        "| strict-smoke | 3 | 5 | fixed | 3/1 | 0/0/0 | 0/0/0 | 0/0/0 | 1 | 1 | 1.00 |",
        "",
        "## Error path smoke",
        "",
        "These rows keep representative malformed/truncated/checksum wrapper inputs visible in the decode-stage dashboard without mixing them into throughput timings.",
        "",
        "| case | wrapper | input bytes | expected error | actual error | matched |",
        "| --- | --- | ---: | --- | --- | --- |",
        "| raw-empty | raw | 0 | `TruncatedFrame` | `TruncatedFrame` | `true` |",
        f"| zlib-bad-adler | zlib | 11 | `ChecksumMismatch` | `{actual_zlib_error}` | `{zlib_matched}` |",
        "| gzip-bad-crc | gzip | 23 | `ChecksumMismatch` | `ChecksumMismatch` | `true` |",
    ]
    path.write_text("\n".join(lines) + "\n")


def write_decode_stage_csv(path: Path, *, healthy: bool = True) -> None:
    columns = [
        "case", "input_bytes", "zlib_bytes", "gzip_bytes", "raw_bytes", "raw_block_type", "raw_header_bits", "raw_header_bytes",
        "dynamic_hlit", "dynamic_hdist", "dynamic_hclen", "dynamic_literal_nonzero", "dynamic_literal_zero", "dynamic_literal_max_bits",
        "dynamic_distance_nonzero", "dynamic_distance_zero", "dynamic_distance_max_bits", "iterations", "repeat",
        "raw_mib_s", "raw_exact_mib_s", "raw_into_mib_s", "zlib_mib_s", "zlib_exact_mib_s", "zlib_into_mib_s",
        "zlib_into_no_adler_mib_s", "zlib_into_no_adler_over_strict", "gzip_mib_s", "gzip_no_crc_mib_s", "gzip_no_crc_over_strict",
        "gzip_exact_mib_s", "gzip_exact_no_crc_mib_s", "gzip_exact_no_crc_over_strict", "gzip_into_mib_s", "gzip_into_no_crc_mib_s",
        "gzip_into_no_crc_over_strict", "gzip_into_no_isize_mib_s", "gzip_into_no_isize_over_strict", "gzip_into_relaxed_mib_s",
        "gzip_into_relaxed_over_strict", "adler32_mib_s", "zlib_adler_time_ratio", "crc32_mib_s", "gzip_crc_time_ratio",
        "raw_stored_mib_s", "raw_stored_exact_mib_s", "raw_stored_into_mib_s", "zlib_stored_mib_s", "zlib_stored_exact_mib_s",
        "zlib_stored_into_mib_s", "gzip_stored_mib_s", "gzip_stored_exact_mib_s", "gzip_stored_into_mib_s", "zlib_wrapper_time_ratio",
        "zlib_wrapper_exact_time_ratio", "zlib_wrapper_into_time_ratio", "gzip_wrapper_time_ratio", "gzip_wrapper_into_time_ratio",
        "raw_alloc_exact_time_ratio", "raw_alloc_into_time_ratio", "zlib_alloc_exact_time_ratio", "zlib_alloc_into_time_ratio",
        "gzip_alloc_exact_time_ratio", "gzip_alloc_into_time_ratio", "raw_stored_alloc_time_ratio", "zlib_stored_alloc_time_ratio",
        "gzip_stored_alloc_time_ratio", "raw_stored_alloc_exact_time_ratio", "zlib_stored_alloc_exact_time_ratio", "gzip_stored_alloc_exact_time_ratio", "mix",
    ]
    cases = ["tiny", "repetitive", "overlap-rle", "distance-heavy", "text", "dynamic-literal-only", "dynamic-match", "binary", "stored-binary", "structured"]
    lines = [",".join(columns)]
    for case in cases:
        if not healthy and case == "structured":
            continue
        block_type = "stored" if case == "stored-binary" else "fixed" if case == "tiny" else "dynamic"
        dynamic = block_type == "dynamic"
        values = {
            "case": case, "input_bytes": "1024", "zlib_bytes": "64", "gzip_bytes": "76", "raw_bytes": "58", "raw_block_type": block_type,
            "raw_header_bits": "3", "raw_header_bytes": "1", "dynamic_hlit": "286" if dynamic else "0", "dynamic_hdist": "3" if dynamic else "0",
            "dynamic_hclen": "18" if dynamic else "0", "dynamic_literal_nonzero": "6" if dynamic else "0", "dynamic_literal_zero": "280" if dynamic else "0",
            "dynamic_literal_max_bits": "4" if dynamic else "0", "dynamic_distance_nonzero": "2" if dynamic else "0", "dynamic_distance_zero": "1" if dynamic else "0",
            "dynamic_distance_max_bits": "1" if dynamic else "0", "iterations": "64", "repeat": "1", "mix": "12345",
        }
        for col in columns:
            values.setdefault(col, "1.0")
        lines.append(",".join(values[col] for col in columns))
    path.write_text("\n".join(lines) + "\n")


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
        "cli_successes": 90 if ok else 0,
        "expected_failures": 35 if ok else 0,
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
    markdown_lines = [
        "# relaxed wrapper decode report",
        "",
        "| metric | value |",
        "| --- | ---: |",
        "| zlib strict rejections | 2 |",
        "| zlib relaxed successes | 5 |",
        "| zlib dictionary successes | 2 |",
        "| zlib concatenated successes | 3 |",
        "| zlib decoder successes | 8 |",
        "| zlib limited rejections | 1 |",
        "| gzip strict rejections | 3 |",
        "| gzip relaxed successes | 9 |",
        "| gzip concatenated successes | 4 |",
        "| gzip decoder successes | 4 |",
        "| gzip limited rejections | 1 |",
    ]
    path.with_suffix(".md").write_text("\n".join(markdown_lines) + "\n")


def write_zlib_relaxed_gate(path: Path, *, ok: bool = True) -> None:
    checks = {
        "strict_rejections": ok,
        "relaxed_successes": ok,
        "dictionary_successes": ok,
        "zlib_concatenated_successes": ok,
        "zlib_decoder_successes": ok,
        "limited_rejections": ok,
        "gzip_strict_rejections": ok,
        "gzip_relaxed_successes": ok,
        "gzip_concatenated_successes": ok,
        "gzip_decoder_successes": ok,
        "gzip_limited_rejections": ok,
    }
    payload = {"schema": "vort.zlib_relaxed_report_gate", "schema_version": 1, "ok": ok, "report": "zig-out/vort-zlib-relaxed-report.json", "checks": checks}
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
    iterations = 25
    encode_ns = 1_000_000
    decode_ns = 1_000_000

    def throughput_mib_s(input_bytes: int, elapsed_ns: int) -> str:
        mib = (input_bytes * iterations) / (1024.0 * 1024.0)
        return f"{mib / (elapsed_ns / 1_000_000_000.0):.4f}"

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
                        str(iterations),
                        str(encode_ns),
                        str(decode_ns),
                        throughput_mib_s(input_bytes, encode_ns),
                        throughput_mib_s(input_bytes, decode_ns),
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
            "case": "png_indexed1_noninterlaced",
            "interlace": "none",
            "width": 13,
            "height": 3,
            "bit_depth": 1,
            "color_type": "indexed",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 9,
            "filtered_row_scratch_bytes": 2,
            "previous_row_scratch_bytes": 2,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 6,
            "working_scratch_bytes": 13,
            "streaming_working_scratch_bytes": 4,
            "fixed_dynamic_streaming_working_scratch_bytes": 32772,
            "streaming_scratch_savings_bytes": 9,
            "streaming_scratch_ratio_x10000": 3076,
            "total_caller_owned_bytes": 19,
            "streaming_total_caller_owned_bytes": 10,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 32778,
        },
        {
            "case": "png_rgba16_noninterlaced",
            "interlace": "none",
            "width": 5,
            "height": 5,
            "bit_depth": 16,
            "color_type": "truecolor_alpha",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 205,
            "filtered_row_scratch_bytes": 40,
            "previous_row_scratch_bytes": 40,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 200,
            "working_scratch_bytes": 285,
            "streaming_working_scratch_bytes": 80,
            "fixed_dynamic_streaming_working_scratch_bytes": 32848,
            "streaming_scratch_savings_bytes": 205,
            "streaming_scratch_ratio_x10000": 2807,
            "total_caller_owned_bytes": 485,
            "streaming_total_caller_owned_bytes": 280,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 33048,
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
        {
            "case": "png_indexed2_adam7",
            "interlace": "adam7",
            "width": 5,
            "height": 5,
            "bit_depth": 2,
            "color_type": "indexed",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 24,
            "filtered_row_scratch_bytes": 2,
            "previous_row_scratch_bytes": 2,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 10,
            "working_scratch_bytes": 28,
            "streaming_working_scratch_bytes": 4,
            "fixed_dynamic_streaming_working_scratch_bytes": 32772,
            "streaming_scratch_savings_bytes": 24,
            "streaming_scratch_ratio_x10000": 1428,
            "total_caller_owned_bytes": 38,
            "streaming_total_caller_owned_bytes": 14,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 32782,
        },
        {
            "case": "png_rgba16_adam7",
            "interlace": "adam7",
            "width": 5,
            "height": 5,
            "bit_depth": 16,
            "color_type": "truecolor_alpha",
            "stored_streaming_status": "achieved",
            "fixed_dynamic_streaming_status": "achieved",
            "zlib_scratch_bytes": 211,
            "filtered_row_scratch_bytes": 40,
            "previous_row_scratch_bytes": 40,
            "fixed_dynamic_history_scratch_bytes": 32768,
            "image_output_bytes": 200,
            "working_scratch_bytes": 291,
            "streaming_working_scratch_bytes": 80,
            "fixed_dynamic_streaming_working_scratch_bytes": 32848,
            "streaming_scratch_savings_bytes": 211,
            "streaming_scratch_ratio_x10000": 2749,
            "total_caller_owned_bytes": 491,
            "streaming_total_caller_owned_bytes": 280,
            "fixed_dynamic_streaming_total_caller_owned_bytes": 33048,
        },
    ]
    payload = {"schema": "vort.png_scratch_report", "schema_version": 1, "case_count": len(cases), "cases": cases}
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    markdown_lines = [
        "# PNG scratch footprint report",
        "",
        "| case | interlace | dimensions | bit depth | color type | stored streaming | fixed/dynamic streaming | zlib scratch | filtered row scratch | previous row scratch | fixed/dynamic history scratch | image output | working scratch | stored/row streaming scratch | fixed/dynamic streaming scratch | scratch savings | target ratio x10000 | total caller-owned | stored/row streaming total | fixed/dynamic streaming total |",
        "| --- | --- | ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in cases:
        markdown_lines.append(
            f"| {row['case']} | {row['interlace']} | {row['width']}x{row['height']} | {row['bit_depth']} | {row['color_type']} | {row['stored_streaming_status']} | {row['fixed_dynamic_streaming_status']} | {row['zlib_scratch_bytes']} | {row['filtered_row_scratch_bytes']} | {row['previous_row_scratch_bytes']} | {row['fixed_dynamic_history_scratch_bytes']} | {row['image_output_bytes']} | {row['working_scratch_bytes']} | {row['streaming_working_scratch_bytes']} | {row['fixed_dynamic_streaming_working_scratch_bytes']} | {row['streaming_scratch_savings_bytes']} | {row['streaming_scratch_ratio_x10000']} | {row['total_caller_owned_bytes']} | {row['streaming_total_caller_owned_bytes']} | {row['fixed_dynamic_streaming_total_caller_owned_bytes']} |"
        )
    path.with_suffix(".md").write_text("\n".join(markdown_lines) + "\n")


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
        "items": [
            {"index": 0, "mode": "native", "input_bytes": 16, "expected": "accept", "expected_error": "", "outcome": "accepted", "actual_error": "", "matched": True},
            {"index": 1, "mode": "native", "input_bytes": 17, "expected": "reject", "expected_error": "InvalidMagic", "outcome": "rejected", "actual_error": "InvalidMagic", "matched": True},
            {"index": 2, "mode": "native", "input_bytes": 18, "expected": "reject", "expected_error": "TruncatedFrame", "outcome": "rejected", "actual_error": "TruncatedFrame", "matched": True},
        ],
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
    markdown_lines = [
        "# Deflate wrapper fuzz corpus report",
        "",
        "- mode: `native`",
        "- cases: 3",
        "- accepted: 1",
        "- rejected: 2",
        "- exact error expectations: 2",
        "- matched rows: 3",
        "",
        "## Mode summary",
        "",
        "| mode | cases | accepted | rejected | exact error expectations | matched rows |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
        "| native | 3 | 1 | 2 | 2 | 3 |",
        "",
        "## Error summary",
        "",
        "| mode | error | count |",
        "| --- | --- | ---: |",
        "| native | `InvalidMagic` | 1 |",
        "| native | `TruncatedFrame` | 1 |",
        "",
        "## Samples",
        "",
        "| index | mode | input bytes | expected | expected error | outcome | actual error | matched |",
        "| ---: | --- | ---: | --- | --- | --- | --- | --- |",
    ]
    for row in report["items"]:
        markdown_lines.append(
            f"| {row['index']} | {row['mode']} | {row['input_bytes']} | {row['expected']} | `{row['expected_error']}` | {row['outcome']} | `{row['actual_error']}` | true |"
        )
    (root / NATIVE_FUZZ_MARKDOWN_ARTIFACT).write_text("\n".join(markdown_lines) + "\n")
    (root / NATIVE_FUZZ_COVERAGE_ARTIFACT).write_text(json.dumps(coverage, indent=2, sort_keys=True) + "\n")


def write_br_static_candidates_markdown(path: Path, payload: dict[str, object]) -> None:
    lines = [
        "# Brotli static dictionary candidate report",
        "",
        f"- Source mode: {payload['source_mode']}",
        f"- Source limit: {payload['source_limit']}",
        f"- Source entries: {payload['source_entry_count']}",
        f"- Anchor raw words: {payload['anchor_raw_word_count']}",
        f"- Upstream raw words: {payload['upstream_raw_word_count']}",
        f"- Unique raw words: {payload['raw_word_count']}",
        f"- Supported transforms considered: {payload['transform_count']}",
        f"- Candidate entries: {payload['candidate_count']}",
        f"- Rows shown: {min(80, len(payload['candidates']))}",
        "",
        "## Transform-kind summary",
        "",
        "| Transform kind | Candidates |",
        "| --- | ---: |",
    ]
    for row in payload["kind_rows"]:
        lines.append(f"| `{row['transform_kind']}` | {row['candidate_count']} |")
    lines.extend([
        "",
        "## Copy-length summary",
        "",
        "| Copy length | Candidates |",
        "| ---: | ---: |",
    ])
    for row in payload["length_rows"]:
        lines.append(f"| {row['copy_len']} | {row['candidate_count']} |")
    lines.extend([
        "",
        "## Candidate rows",
        "",
        "| Transform | Copy length | Word index | Kind | Raw word | Candidate word |",
        "| ---: | ---: | ---: | --- | --- | --- |",
    ])
    for row in payload["candidates"][:80]:
        lines.append(
            f"| {row['transform']} | {row['copy_len']} | {row['word_index']} | `{row['transform_kind']}` | `{row['raw_word']}` | `{row['transformed_word']}` |"
        )
    path.write_text("\n".join(lines) + "\n")


def write_br_static_node_markdown(path: Path, payload: dict[str, object]) -> None:
    lines = [
        "# Brotli static dictionary Node probe",
        "",
        f"- Candidate entries: {payload['candidate_count']}",
        f"- Candidate source mode: {payload['candidate_source_mode']}",
        f"- Candidate source limit: {payload['candidate_source_limit']}",
        f"- Candidate raw words: {payload['candidate_raw_word_count']}",
        f"- Probe start index: {payload['start_index']}",
        f"- Probe limit: {payload['limit']}",
        f"- Probed entries: {payload['probed_count']}",
        f"- Node decode successes: {payload['node_decode_successes']}",
        f"- Vort decode successes: {payload['vort_decode_successes']}",
        f"- Vort decode failures: {payload['vort_decode_failures']}",
        f"- Size winners: {payload['size_winner_count']}",
        "",
        "## Transform-kind summary",
        "",
        "| Transform kind | Probed | Node OK | Vort OK | Vort failures |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for row in payload["kind_rows"]:
        lines.append(
            f"| `{row['transform_kind']}` | {row['probed_count']} | {row['node_decode_successes']} | {row['vort_decode_successes']} | {row['vort_decode_failures']} |"
        )
    lines.extend([
        "",
        "## Size summary",
        "",
        "| Size class | Probed |",
        "| --- | ---: |",
    ])
    for row in payload["size_rows"]:
        lines.append(f"| `{row['size_class']}` | {row['probed_count']} |")
    lines.extend([
        "",
        "## Candidate rows",
        "",
        "| # | Transform | Copy length | Word index | Candidate | Payload bytes | Brotli bytes | Size class | Classification | Error |",
        "| ---: | ---: | ---: | ---: | --- | ---: | ---: | --- | --- | --- |",
    ])
    for row in payload["rows"]:
        lines.append(
            f"| {row['index']} | {row['transform']} | {row['copy_len']} | {row['word_index']} | `{row['candidate_word']}` | {row['payload_bytes']} | {row['br_bytes']} | `{row['size_class']}` | `{row['classification']}` | `{row['error']}` |"
        )
    path.write_text("\n".join(lines) + "\n")


def write_br_static_dictionary_artifacts(root: Path) -> None:
    candidates = {
        "schema": "vort.br_static_dictionary_candidate_report",
        "schema_version": 1,
        "source_mode": "anchors",
        "source_limit": 0,
        "source_entry_count": 83,
        "raw_word_count": 143,
        "anchor_raw_word_count": 143,
        "upstream_raw_word_count": 0,
        "transform_count": 6,
        "candidate_count": 775,
        "kind_rows": [{"transform_kind": "identity", "candidate_count": 81}, {"transform_kind": "affix_identity", "candidate_count": 417}, {"transform_kind": "omit_last_1", "candidate_count": 139}, {"transform_kind": "uppercase_first", "candidate_count": 138}],
        "length_rows": [{"copy_len": 4, "candidate_count": 480}, {"copy_len": 5, "candidate_count": 295}],
        "candidates": [{"raw_word": "test", "transformed_word": "test", "word_index": 0, "transform": 0, "copy_len": 4, "transform_kind": "identity"}],
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
    upstream_report = dict(candidates)
    upstream_report.update({
        "source_mode": "upstream",
        "source_limit": 8,
        "upstream_raw_word_count": 8,
    })
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
        "limit": 48,
        "candidate_count": 775,
        "candidate_raw_word_count": 143,
        "node_decode_successes": 48,
        "vort_decode_successes": 48,
        "vort_decode_failures": 0,
        "size_winner_count": 1,
        "kind_rows": [{"transform_kind": "identity", "probed_count": 48, "node_decode_successes": 48, "vort_decode_successes": 48, "vort_decode_failures": 0}],
        "size_rows": [{"size_class": "smaller", "probed_count": 48}],
        "size_winner_rows": [{"size_class": "smaller", "probed_count": 48}],
        "rows": [{"index": index, "transform": 0, "copy_len": 4, "word_index": index, "candidate_word": f"test{index}", "payload_bytes": 5, "br_bytes": 4, "size_class": "smaller", "classification": "vort_accepts_node_frame", "error": ""} for index in range(48)],
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
    report_entries = [
        {"transform": 0, "copy_len": 5, "word_index": 0, "word_bytes": 5, "word": "first"},
        {"transform": 1, "copy_len": 5, "word_index": 43, "word_bytes": 6, "word": "words "},
        {"transform": 6, "copy_len": 5, "word_index": 44, "word_bytes": 6, "word": " games"},
        {"transform": 9, "copy_len": 7, "word_index": 5, "word_bytes": 7, "word": "Content"},
        {"transform": 12, "copy_len": 5, "word_index": 43, "word_bytes": 4, "word": "word"},
        {"transform": 20, "copy_len": 7, "word_index": 37, "word_bytes": 8, "word": "history."},
    ]
    report = {
        "schema": "vort.br_static_dictionary_report",
        "schema_version": 1,
        "entry_count": len(report_entries),
        "transform_count": 6,
        "length_count": 2,
        "category_counts": {"identity": 1, "transform": 3, "phrase": 2},
        "matrix_rows": [
            {"transform": 0, "identity": 1, "transform_entries": 0, "phrase": 0, "total": 1},
            {"transform": 1, "identity": 0, "transform_entries": 0, "phrase": 1, "total": 1},
            {"transform": 6, "identity": 0, "transform_entries": 0, "phrase": 1, "total": 1},
            {"transform": 9, "identity": 0, "transform_entries": 1, "phrase": 0, "total": 1},
            {"transform": 12, "identity": 0, "transform_entries": 1, "phrase": 0, "total": 1},
            {"transform": 20, "identity": 0, "transform_entries": 1, "phrase": 0, "total": 1},
        ],
        "entries": report_entries,
    }
    report_negative = {
        "schema": "vort.br_static_dictionary_report_negative_smoke",
        "schema_version": 1,
        "ok": True,
        "case_count": 1,
        "cases": [{"name": "missing_required_tuple", "expected_output": "missing required coverage rows", "returncode": 1, "matched": True}],
    }
    write_br_static_candidates_markdown(root / BR_STATIC_CANDIDATES_MARKDOWN_ARTIFACT, candidates)
    write_br_static_candidates_markdown(root / BR_STATIC_UPSTREAM_MARKDOWN_ARTIFACT, upstream_report)
    write_br_static_node_markdown(root / BR_STATIC_NODE_MARKDOWN_ARTIFACT, node)
    for artifact, payload in (
        (BR_STATIC_CANDIDATES_ARTIFACT, candidates),
        (BR_STATIC_UPSTREAM_ARTIFACT, upstream),
        (BR_STATIC_UPSTREAM_REPORT_ARTIFACT, upstream_report),
        (BR_STATIC_NODE_ARTIFACT, node),
        (BR_STATIC_AUDIT_ARTIFACT, audit),
        (BR_STATIC_AUDIT_NEGATIVE_ARTIFACT, negative),
        (BR_STATIC_REPORT_JSON_ARTIFACT, report),
        (BR_STATIC_REPORT_NEGATIVE_ARTIFACT, report_negative),
    ):
        (root / artifact).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    report_columns = ["transform", "copy_len", "word_index", "word_bytes", "word"]
    report_lines = [",".join(report_columns)]
    report_lines.extend(",".join(str(row[column]) for column in report_columns) for row in report_entries)
    (root / BR_STATIC_REPORT_CSV_ARTIFACT).write_text("\n".join(report_lines) + "\n")
    markdown_lines = [
        "# Brotli static dictionary subset",
        "",
        "- Entries: 6",
        "- Distinct transforms: 6",
        "- Distinct lengths: 2",
        "- Identity entries: 1",
        "- Transform entries: 3",
        "- Phrase entries: 2",
        "",
        "| Transform | Identity | Transform entries | Phrase | Total |",
        "| ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in report["matrix_rows"]:
        markdown_lines.append(f"| {row['transform']} | {row['identity']} | {row['transform_entries']} | {row['phrase']} | {row['total']} |")
    markdown_lines.extend([
        "",
        "| Transform | Copy length | Word index | Bytes | Word |",
        "| ---: | ---: | ---: | ---: | --- |",
    ])
    for row in report_entries:
        markdown_lines.append(
            f"| {row['transform']} | {row['copy_len']} | {row['word_index']} | {row['word_bytes']} | `{row['word']}` |"
        )
    (root / BR_STATIC_REPORT_MARKDOWN_ARTIFACT).write_text("\n".join(markdown_lines) + "\n")


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
    markdown_lines = [
        "# Native allocation strict-smoke report",
        "",
        "| case | input bytes | output bytes | allocations | deallocations | allocated bytes | freed bytes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in report["cases"]:
        markdown_lines.append(
            f"| {row['case']} | {row['input_bytes']} | {row['output_bytes']} | {row['allocations']} | {row['deallocations']} | {row['allocated_bytes']} | {row['freed_bytes']} |"
        )
    (root / NATIVE_ALLOCATION_REPORT_MARKDOWN_ARTIFACT).write_text("\n".join(markdown_lines) + "\n")
    (root / NATIVE_ALLOCATION_SMOKE_ARTIFACT).write_text(json.dumps(smoke, indent=2, sort_keys=True) + "\n")
    (root / NATIVE_ALLOCATION_NEGATIVE_ARTIFACT).write_text(json.dumps(negative, indent=2, sort_keys=True) + "\n")



def write_zstd_compare_artifacts(root: Path) -> None:
    compare_fields = [
        "path",
        "input_bytes",
        "zstd_bytes",
        "vort_raw_fixed_bytes",
        "vort_native_best_bytes",
        "vort_native_stream_bytes",
        "vort_native_embedded_bytes",
        "vort_over_zstd",
        "vort_native_best_over_zstd",
        "vort_native_stream_over_zstd",
        "vort_native_over_zstd",
        "vort_stream_over_native_best",
        "vort_stream_over_native_best_bytes",
        "vort_stream_over_native_best_pct",
        "vort_embedded_over_native_stream",
        "vort_embedded_over_native_stream_bytes",
        "vort_embedded_over_native_stream_pct",
        "vort_embedded_over_native_best",
        "vort_embedded_over_native_best_bytes",
        "vort_embedded_over_native_best_pct",
        "zstd_decode_ms",
        "vort_raw_fixed_decode_ms",
        "vort_native_best_decode_ms",
        "vort_native_decode_ms",
        "zstd_decode_mib_s",
        "vort_raw_fixed_decode_mib_s",
        "vort_native_best_decode_mib_s",
        "vort_native_decode_mib_s",
        "vort_decode_vs_zstd",
        "vort_native_best_decode_vs_zstd",
        "vort_native_decode_vs_zstd",
        "decode_repeats",
        "native_block_len",
        "source_mode",
        "size_mode",
        "case_limit",
        "zstd_version",
        "vort_commit",
        "zig_version",
        "cpu_model",
        "optimize",
    ]
    sweep_fields = [
        "path",
        "block_len",
        "seekability_tier",
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

    def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
        lines = [",".join(fields)]
        for row in rows:
            lines.append(",".join(str(row.get(field, "")) for field in fields))
        path.write_text("\n".join(lines) + "\n")

    def write_compare_csv(path: Path, gate: dict[str, object], data_count: int) -> None:
        total = {
            "path": "TOTAL",
            "input_bytes": 1000,
            "zstd_bytes": 100,
            "vort_raw_fixed_bytes": 104,
            "vort_native_best_bytes": 102,
            "vort_native_stream_bytes": 116,
            "vort_native_embedded_bytes": 118,
            "vort_over_zstd": gate["total_ratio"],
            "vort_native_best_over_zstd": gate["total_native_best_ratio"],
            "vort_native_stream_over_zstd": gate["total_native_stream_ratio"],
            "vort_native_over_zstd": gate["total_native_ratio"],
            "vort_stream_over_native_best": gate["total_stream_over_native_best"],
            "vort_stream_over_native_best_bytes": gate["total_stream_over_native_best_bytes"],
            "vort_stream_over_native_best_pct": gate["total_stream_over_native_best_pct"],
            "vort_embedded_over_native_stream": gate["total_embedded_over_native_stream"],
            "vort_embedded_over_native_stream_bytes": gate["total_embedded_over_native_stream_bytes"],
            "vort_embedded_over_native_stream_pct": gate["total_embedded_over_native_stream_pct"],
            "vort_embedded_over_native_best": gate["total_embedded_over_native_best"],
            "vort_embedded_over_native_best_bytes": gate["total_embedded_over_native_best_bytes"],
            "vort_embedded_over_native_best_pct": gate["total_embedded_over_native_best_pct"],
            "zstd_decode_ms": 1.0,
            "vort_raw_fixed_decode_ms": 1.0,
            "vort_native_best_decode_ms": 1.0,
            "vort_native_decode_ms": 1.0,
            "zstd_decode_mib_s": gate["total_zstd_decode_mib_s"],
            "vort_raw_fixed_decode_mib_s": gate["total_vort_raw_fixed_decode_mib_s"],
            "vort_native_best_decode_mib_s": gate["total_vort_native_best_decode_mib_s"],
            "vort_native_decode_mib_s": gate["total_vort_native_decode_mib_s"],
            "vort_decode_vs_zstd": gate["total_vort_decode_vs_zstd"],
            "vort_native_best_decode_vs_zstd": gate["total_vort_native_best_decode_vs_zstd"],
            "vort_native_decode_vs_zstd": gate["total_vort_native_decode_vs_zstd"],
            "decode_repeats": gate["decode_repeats"],
            "native_block_len": gate["native_block_len"],
            "source_mode": gate["source_mode"],
            "size_mode": gate["size_mode"],
            "case_limit": gate["case_limit"],
            "zstd_version": "zstd-smoke",
            "vort_commit": "strict-smoke",
            "zig_version": "0.16.0",
            "cpu_model": "strict-smoke-cpu",
            "optimize": gate["optimize"],
        }
        rows = []
        for index in range(data_count):
            row = dict(total)
            row["path"] = f"case-{index}"
            rows.append(row)
        rows.append(total)
        write_csv(path, compare_fields, rows)
        return rows

    def ratio_text(value: object) -> str:
        number = float(value)
        return "n/a" if number < 0 else f"{number:.4f}"

    def float_text(value: object) -> str:
        return f"{float(value):.2f}"

    def write_compare_markdown(path: Path, gate: dict[str, object], rows: list[dict[str, object]]) -> None:
        lines = [
            "# Vort vs zstd size and decode smoke",
            "",
            f"- source mode: `{gate['source_mode']}`",
            f"- size mode: `{gate['size_mode']}`",
            f"- case limit: `{gate['case_limit']}`",
            f"- Decode repeats: `{gate['decode_repeats']}`",
            f"- Native block length: `{gate['native_block_len']}`",
            "",
            "| path | input bytes | zstd bytes | Vort raw fixed bytes | Vort native best bytes | Vort native stream bytes | Vort native embedded bytes | stream overhead bytes | embedded-index bytes | total embedded overhead bytes | stream / native best | embedded / stream | embedded / native best | Vort raw / zstd | Vort native best / zstd | Vort native stream / zstd | Vort native embedded / zstd | zstd decode MiB/s | Vort raw fixed decode MiB/s | Vort native best decode MiB/s | Vort native embedded decode MiB/s | Vort raw decode / zstd | Vort native best decode / zstd | Vort native embedded decode / zstd |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
        for row in rows:
            path_cell = "**TOTAL**" if row["path"] == "TOTAL" else f"`{row['path']}`"
            lines.append(
                f"| {path_cell} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_raw_fixed_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_stream_bytes']} | {row['vort_native_embedded_bytes']} | "
                f"{row['vort_stream_over_native_best_bytes']} | {row['vort_embedded_over_native_stream_bytes']} | {row['vort_embedded_over_native_best_bytes']} | "
                f"{ratio_text(row['vort_stream_over_native_best'])} | {ratio_text(row['vort_embedded_over_native_stream'])} | {ratio_text(row['vort_embedded_over_native_best'])} | "
                f"{ratio_text(row['vort_over_zstd'])} | {ratio_text(row['vort_native_best_over_zstd'])} | {ratio_text(row['vort_native_stream_over_zstd'])} | {ratio_text(row['vort_native_over_zstd'])} | "
                f"{float_text(row['zstd_decode_mib_s'])} | {float_text(row['vort_raw_fixed_decode_mib_s'])} | {float_text(row['vort_native_best_decode_mib_s'])} | {float_text(row['vort_native_decode_mib_s'])} | "
                f"{ratio_text(row['vort_decode_vs_zstd'])} | {ratio_text(row['vort_native_best_decode_vs_zstd'])} | {ratio_text(row['vort_native_decode_vs_zstd'])} |"
            )
        path.write_text("\n".join(lines) + "\n")

    def write_sweep_csv(path: Path, gate: dict[str, object]) -> None:
        rows = []
        for block_len in gate["block_lens"]:
            tier = {8192: "seek_fast", 32768: "balanced", 65536: "ratio"}.get(block_len, "custom")
            for index in range(gate["path_count"]):
                rows.append({
                    "path": f"case-{index}",
                    "block_len": block_len,
                    "seekability_tier": tier,
                    "input_bytes": 1000,
                    "zstd_bytes": 100,
                    "vort_native_best_bytes": 100,
                    "vort_native_stream_bytes": 110 + block_len // 4096,
                    "vort_native_embedded_bytes": 112 + block_len // 4096,
                    "vort_native_best_over_zstd": 1.0,
                    "vort_native_stream_over_zstd": 1.1,
                    "vort_native_embedded_over_zstd": 1.12,
                    "vort_stream_over_native_best": 1.1,
                    "vort_stream_over_native_best_bytes": 10,
                    "vort_stream_over_native_best_pct": 10.0,
                    "vort_embedded_over_native_stream": 1.02,
                    "vort_embedded_over_native_stream_bytes": 2,
                    "vort_embedded_over_native_stream_pct": 2.0,
                    "range_offset": 0,
                    "range_len": 100,
                    "range_iterations": 5,
                    "vort_range_decode_ms": 1.0,
                    "vort_range_decode_mib_s": 10.0,
                    "vort_range_decode_full_input_mib_s": 100.0,
                    "source_mode": gate["source_mode"],
                    "size_mode": gate["size_mode"],
                    "case_limit": gate["case_limit"],
                    "zstd_version": "zstd-smoke",
                    "vort_commit": "strict-smoke",
                    "zig_version": "0.16.0",
                    "cpu_model": "strict-smoke-cpu",
                    "optimize": gate["optimize"],
                })
            total_stream = gate["best_native_stream_bytes"] if block_len == gate["best_block_len"] else gate["best_native_stream_bytes"] + block_len
            rows.append({
                "path": "TOTAL",
                "block_len": block_len,
                "seekability_tier": tier,
                "input_bytes": 3000,
                "zstd_bytes": 300,
                "vort_native_best_bytes": 300,
                "vort_native_stream_bytes": total_stream,
                "vort_native_embedded_bytes": total_stream + gate["best_embedded_over_native_stream_bytes"],
                "vort_native_best_over_zstd": 1.0,
                "vort_native_stream_over_zstd": gate["best_native_stream_ratio"] if block_len == gate["best_block_len"] else 1.2,
                "vort_native_embedded_over_zstd": 1.21,
                "vort_stream_over_native_best": gate["best_stream_over_native_best"] if block_len == gate["best_block_len"] else 1.2,
                "vort_stream_over_native_best_bytes": gate["best_stream_over_native_best_bytes"] if block_len == gate["best_block_len"] else 100,
                "vort_stream_over_native_best_pct": 2.0,
                "vort_embedded_over_native_stream": gate["best_embedded_over_native_stream"] if block_len == gate["best_block_len"] else 1.01,
                "vort_embedded_over_native_stream_bytes": gate["best_embedded_over_native_stream_bytes"],
                "vort_embedded_over_native_stream_pct": 1.0,
                "range_offset": 0,
                "range_len": 300,
                "range_iterations": 5,
                "vort_range_decode_ms": 1.0,
                "vort_range_decode_mib_s": gate["best_range_decode_mib_s"] if block_len == gate["best_block_len"] else 10.0,
                "vort_range_decode_full_input_mib_s": gate["best_range_decode_full_input_mib_s"] if block_len == gate["best_block_len"] else 100.0,
                "source_mode": gate["source_mode"],
                "size_mode": gate["size_mode"],
                "case_limit": gate["case_limit"],
                "zstd_version": "zstd-smoke",
                "vort_commit": "strict-smoke",
                "zig_version": "0.16.0",
                "cpu_model": "strict-smoke-cpu",
                "optimize": gate["optimize"],
            })
        write_csv(path, sweep_fields, rows)
        return rows

    def pct_text(value: object) -> str:
        return f"{float(value):.2f}%"

    def write_sweep_markdown(path: Path, gate: dict[str, object], rows: list[dict[str, object]]) -> None:
        lines = [
            "# Vort native block length sweep vs zstd",
            "",
            f"- source mode: `{gate['source_mode']}`",
            f"- size mode: `{gate['size_mode']}`",
            f"- case limit: `{gate['case_limit']}`",
            f"- Swept native block lengths: `{','.join(str(item) for item in gate['block_lens'])}`",
            "",
            f"Best total native stream bytes in this smoke: block length `{gate['best_block_len']}` with `{gate['best_native_stream_bytes']}` bytes.",
            "",
            "## TOTAL by block length",
            "",
            "| tier | block length | input bytes | zstd bytes | native best bytes | native stream bytes | native embedded bytes | stream / zstd | embedded / zstd | stream / native best | stream overhead bytes | stream overhead pct | embedded / stream | embedded-index bytes | range decode MiB/s |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
        for row in rows:
            if row["path"] == "TOTAL":
                lines.append(
                    f"| `{row['seekability_tier']}` | {row['block_len']} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_stream_bytes']} | {row['vort_native_embedded_bytes']} | "
                    f"{ratio_text(row['vort_native_stream_over_zstd'])} | {ratio_text(row['vort_native_embedded_over_zstd'])} | {ratio_text(row['vort_stream_over_native_best'])} | {row['vort_stream_over_native_best_bytes']} | {pct_text(row['vort_stream_over_native_best_pct'])} | "
                    f"{ratio_text(row['vort_embedded_over_native_stream'])} | {row['vort_embedded_over_native_stream_bytes']} | {float_text(row['vort_range_decode_mib_s'])} |"
                )
        lines.extend([
            "",
            "## Per-input rows",
            "",
            "| path | tier | block length | input bytes | zstd bytes | native best bytes | native stream bytes | native embedded bytes | stream / native best | embedded / stream | range offset | range decode MiB/s |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        ])
        for row in rows:
            if row["path"] != "TOTAL":
                lines.append(
                    f"| `{row['path']}` | `{row['seekability_tier']}` | {row['block_len']} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_stream_bytes']} | {row['vort_native_embedded_bytes']} | "
                    f"{ratio_text(row['vort_stream_over_native_best'])} | {ratio_text(row['vort_embedded_over_native_stream'])} | {row['range_offset']} | {float_text(row['vort_range_decode_mib_s'])} |"
                )
        path.write_text("\n".join(lines) + "\n")

    compare = {
        "schema": "vort.zstd_compare_gate",
        "schema_version": 1,
        "ok": True,
        "data_rows": 2,
        "rows": 3,
        "case_limit": "none",
        "csv": "zig-out/vort-zstd-compare.csv",
        "markdown": "zig-out/vort-zstd-compare.md",
        "native_block_len": 8192,
        "optimize": "Debug",
        "size_mode": "full",
        "source_mode": "default-samples",
        "decode_repeats": 3,
        "total_ratio": 1.04,
        "total_native_best_ratio": 1.02,
        "total_native_ratio": 1.18,
        "total_native_stream_ratio": 1.16,
        "total_embedded_over_native_best": 118.0 / 102.0,
        "total_embedded_over_native_best_bytes": 16,
        "total_embedded_over_native_best_pct": (118.0 / 102.0 - 1.0) * 100.0,
        "total_embedded_over_native_stream": 118.0 / 116.0,
        "total_embedded_over_native_stream_bytes": 2,
        "total_embedded_over_native_stream_pct": (118.0 / 116.0 - 1.0) * 100.0,
        "total_stream_over_native_best": 116.0 / 102.0,
        "total_stream_over_native_best_bytes": 14,
        "total_stream_over_native_best_pct": (116.0 / 102.0 - 1.0) * 100.0,
        "total_zstd_decode_mib_s": 90.0,
        "total_vort_decode_vs_zstd": 0.71,
        "total_vort_raw_fixed_decode_mib_s": 64.0,
        "total_vort_native_decode_mib_s": 73.0,
        "total_vort_native_decode_vs_zstd": 0.81,
        "total_vort_native_best_decode_mib_s": 96.0,
        "total_vort_native_best_decode_vs_zstd": 1.07,
    }
    standard = dict(compare)
    standard.update({
        "case_limit": "3",
        "csv": "zig-out/vort-zstd-compare-standard.csv",
        "markdown": "zig-out/vort-zstd-compare-standard.md",
        "source_mode": "standard-suite",
        "size_mode": "bounded-128KiB",
        "data_rows": 3,
        "rows": 4,
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
        "rows": 20,
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
    }
    (root / ZSTD_COMPARE_ARTIFACT).write_text(json.dumps(compare, indent=2, sort_keys=True) + "\n")
    (root / ZSTD_COMPARE_STANDARD_ARTIFACT).write_text(json.dumps(standard, indent=2, sort_keys=True) + "\n")
    (root / ZSTD_COMPARE_BLOCK_SWEEP_ARTIFACT).write_text(json.dumps(sweep, indent=2, sort_keys=True) + "\n")
    compare_rows = write_compare_csv(root / ZSTD_COMPARE_CSV_ARTIFACT, compare, int(compare["data_rows"]))
    standard_rows = write_compare_csv(root / ZSTD_COMPARE_STANDARD_CSV_ARTIFACT, standard, int(standard["data_rows"]))
    write_compare_markdown(root / ZSTD_COMPARE_MARKDOWN_ARTIFACT, compare, compare_rows)
    write_compare_markdown(root / ZSTD_COMPARE_STANDARD_MARKDOWN_ARTIFACT, standard, standard_rows)
    sweep_rows = write_sweep_csv(root / ZSTD_COMPARE_BLOCK_SWEEP_CSV_ARTIFACT, sweep)
    write_sweep_markdown(root / ZSTD_COMPARE_BLOCK_SWEEP_MARKDOWN_ARTIFACT, sweep, sweep_rows)


def write_native_summary_error_dashboard(path: Path, *, healthy: bool = True) -> None:
    required_phases = ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"]
    def case(codec: str, name: str, error: str, phase: str, offset: int, compressed_bytes: int) -> dict[str, object]:
        return {
            "name": name,
            "codec": codec,
            "schema": f"vort.{codec}_native_stream_summary_error",
            "schema_version": 1,
            "ok": False,
            "compressed_bytes": compressed_bytes,
            "error": error,
            "phase": phase,
            "offset": offset,
        }

    healthy_cases = [
        case("lz4", "lz4_bad_magic", "CorruptFrame", "magic", 0, 7),
        case("lz4", "lz4_truncated_header", "TruncatedFrame", "frame_header", 5, 5),
        case("lz4", "lz4_truncated_skippable", "TruncatedFrame", "skippable_payload", 13, 13),
        case("lz4", "lz4_header_checksum", "ChecksumMismatch", "frame_header", 11, 11),
        case("lz4", "lz4_truncated_body", "TruncatedFrame", "frame_body", 13, 13),
        case("lz4", "lz4_truncated_checksum", "TruncatedFrame", "frame_checksum", 20, 20),
        case("lz4", "lz4_invalid_block_header", "CorruptFrame", "frame", 7, 11),
        case("zstd", "zstd_bad_magic", "InvalidMagic", "magic", 0, 8),
        case("zstd", "zstd_truncated_header", "TruncatedFrame", "magic", 3, 3),
        case("zstd", "zstd_truncated_skippable", "TruncatedFrame", "skippable_payload", 13, 13),
        case("zstd", "zstd_reserved_descriptor", "CorruptFrame", "frame_header", 5, 5),
        case("zstd", "zstd_truncated_body", "TruncatedFrame", "frame_body", 11, 11),
        case("zstd", "zstd_truncated_checksum", "TruncatedFrame", "frame_checksum", 14, 14),
        case("zstd", "zstd_invalid_block_header", "CorruptFrame", "frame", 6, 9),
    ]
    cases = healthy_cases if healthy else healthy_cases[:1]

    def counts(field: str, *, codec: str | None = None) -> dict[str, int]:
        result: dict[str, int] = {}
        for row in cases:
            if codec is not None and row["codec"] != codec:
                continue
            key = str(row[field])
            result[key] = result.get(key, 0) + 1
        return result

    def offsets(*, codec: str | None = None, phase: str | None = None) -> list[int]:
        return [
            int(row["offset"])
            for row in cases
            if (codec is None or row["codec"] == codec) and (phase is None or row["phase"] == phase)
        ]

    def offset_range(values: list[int]) -> dict[str, int]:
        return {"min": min(values), "max": max(values)} if values else {"min": 0, "max": 0}

    payload = {
        "schema": "vort.native_summary_error_dashboard",
        "schema_version": 1,
        "ok": healthy,
        "case_count": len(cases),
        "lz4_case_count": len([row for row in cases if row["codec"] == "lz4"]),
        "zstd_case_count": len([row for row in cases if row["codec"] == "zstd"]),
        "error_counts": counts("error"),
        "phase_counts": counts("phase"),
        "lz4_error_counts": counts("error", codec="lz4"),
        "zstd_error_counts": counts("error", codec="zstd"),
        "lz4_phase_counts": counts("phase", codec="lz4"),
        "zstd_phase_counts": counts("phase", codec="zstd"),
        "required_codec_phases": {"lz4": required_phases, "zstd": required_phases},
        "offset_min": offset_range(offsets())["min"],
        "offset_max": offset_range(offsets())["max"],
        "lz4_offset_min": offset_range(offsets(codec="lz4"))["min"],
        "lz4_offset_max": offset_range(offsets(codec="lz4"))["max"],
        "zstd_offset_min": offset_range(offsets(codec="zstd"))["min"],
        "zstd_offset_max": offset_range(offsets(codec="zstd"))["max"],
        "phase_offset_ranges": {phase: offset_range(offsets(phase=phase)) for phase in sorted(counts("phase"))},
        "cases": cases,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_native_summary_error_negative_smoke(path: Path, *, healthy: bool = True) -> None:
    cases = [
        ("bad_error_counts", "error_counts mismatch"),
        ("bad_phase_counts", "phase_counts mismatch"),
        ("bad_case_count", "case_count mismatch"),
    ]
    payload = {
        "schema": "vort.native_summary_error_negative_smoke",
        "schema_version": 1,
        "ok": healthy,
        "case_count": 3 if healthy else 0,
        "cases": [
            {
                "name": name,
                "expected_failure": True,
                "expected_error": expected_error,
                "actual_error": expected_error if healthy else "<success>",
                "matched": healthy,
            }
            for name, expected_error in cases
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
    markdown_path = path.with_suffix(".md")
    markdown_lines = [
        "# Native codec probes",
        "",
        "- ok: `true`",
        f"- total cases: `{payload['total_cases']}`",
        "",
        "## Coverage",
        "",
        "| codec | surface | present | ok | probes | cases |",
        "| --- | --- | --- | --- | ---: | ---: |",
    ]
    for row in payload["coverage"]:
        markdown_lines.append(
            f"| {row['codec']} | {row['surface']} | `true` | `true` | {row['ok_probe_count']}/{row['probe_count']} | {row['cases']} |"
        )
    markdown_lines.extend([
        "",
        "## Capabilities",
        "",
        "| capability | present | ok | probes | cases |",
        "| --- | --- | --- | ---: | ---: |",
    ])
    for row in payload["capabilities"]:
        markdown_lines.append(
            f"| {row['capability']} | `true` | `true` | {row['ok_probe_count']}/{row['probe_count']} | {row['cases']} |"
        )
    markdown_lines.extend([
        "",
        "## Probes",
        "",
        "| probe | ok | cases | returncode | timed out | timeout seconds |",
        "| --- | --- | ---: | ---: | --- | ---: |",
    ])
    for probe in payload["probes"]:
        markdown_lines.append(
            f"| {probe['label']} | `true` | {probe['cases']} | 0 | `false` | {probe['timeout_seconds']:g} |"
        )
    markdown_lines.append("")
    markdown_path.write_text("\n".join(markdown_lines))

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


def write_native_library_bench_csv(path: Path, *, healthy: bool = True) -> None:
    columns = ["codec", "mode", "case", "input_bytes", "encoded_bytes", "iterations", "encode_ns", "decode_ns", "encode_mib_s", "decode_mib_s", "checksum"]
    expected_cases = ("text", "structured", "repetitive")
    rows: list[tuple[str, str, str, int, int]] = []
    for codec in ("lz4", "zstd"):
        for mode in ("one_shot", "incremental", "incremental_direct", "incremental_fallback", "lib_decode", "native_lib_decode"):
            for case in expected_cases:
                rows.append((codec, mode, case, 4096, 1024))
    rows.extend(
        [
            ("lz4", "chain_depth_0", "chain_depth", 4096, 1800),
            ("lz4", "chain_depth_default", "chain_depth", 4096, 900),
            ("zstd", "match_budget_0", "mixed_budget", 4096, 1800),
            ("zstd", "match_budget_full", "mixed_budget", 4096, 900),
            ("zstd", "high_byte_binary", "high_byte_binary", 4096, 1000),
        ]
    )
    for codec in ("lz4", "zstd"):
        for case in ("lib_generated", "lib_generated_no_size", "lib_generated_checksum", "lib_generated_no_size_checksum"):
            rows.append((codec, case, case, 4096, 1000))
    rows.extend(
        [
            ("lz4", "lib_generated_independent", "lib_generated_independent", 4096, 1000),
            ("lz4", "lib_generated_independent_no_size_checksum", "lib_generated_independent_no_size_checksum", 4096, 1000),
            ("zstd", "sequence_huffman_literals_plain", "sequence_huffman_literals", 4096, 1800),
            ("zstd", "sequence_huffman_literals", "sequence_huffman_literals", 4096, 900),
        ]
    )
    for codec in ("lz4", "zstd"):
        for case in ("dictionary", "trained_dictionary", "dictionary_set", "dictionary_set_chunked", "dictionary_set_chunked_append", "dictionary_set_chunked_append_exact", "dictionary_set_reusable", "dictionary_set_reusable_append_exact", "dictionary_set_direct", "dictionary_set_fallback"):
            rows.append((codec, f"{case}_plain", case, 4096, 1800))
            rows.append((codec, case, case, 4096, 900))
    if not healthy:
        rows.pop()
    iterations = 25
    encode_ns = 1000
    decode_ns = 2000
    def mib_s(input_bytes: int, elapsed_ns: int) -> str:
        return f"{(input_bytes * iterations / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0):.4f}"
    lines = [",".join(columns)]
    for codec, mode, case, input_bytes, encoded_bytes in rows:
        lines.append(
            ",".join(
                [
                    codec,
                    mode,
                    case,
                    str(input_bytes),
                    str(encoded_bytes),
                    str(iterations),
                    str(encode_ns),
                    str(decode_ns),
                    mib_s(input_bytes, encode_ns),
                    mib_s(input_bytes, decode_ns),
                    "12345",
                ]
            )
        )
    path.write_text("\n".join(lines) + "\n")


def write_native_tier_range_csv(path: Path, fixtures: list[str]) -> None:
    columns = ["fixture", "tier", "block_len", "input_bytes", "stream_bytes", "index_entries", "range_offset", "range_len", "iterations", "repeat", "elapsed_ns", "range_mib_s", "full_input_mib_s", "checksum"]
    lines = [",".join(columns)]
    for fixture in fixtures:
        for tier, block_len in NATIVE_TIER_RANGE_TIERS.items():
            lines.append(
                ",".join(
                    [
                        fixture,
                        tier,
                        str(block_len),
                        str(NATIVE_TIER_RANGE_INPUT_BYTES),
                        str(NATIVE_TIER_RANGE_STREAM_BYTES),
                        str((NATIVE_TIER_RANGE_INPUT_BYTES + block_len - 1) // block_len),
                        str(NATIVE_TIER_RANGE_RANGE_OFFSET),
                        str(NATIVE_TIER_RANGE_RANGE_LEN),
                        str(NATIVE_TIER_RANGE_ITERATIONS),
                        str(NATIVE_TIER_RANGE_REPEAT),
                        str(NATIVE_TIER_RANGE_ELAPSED_NS),
                        f"{NATIVE_TIER_RANGE_RANGE_MIB_S:.6f}",
                        f"{NATIVE_TIER_RANGE_FULL_INPUT_MIB_S:.6f}",
                        "12345",
                    ]
                )
            )
    path.write_text("\n".join(lines) + "\n")


def write_native_tier_range_summary(path: Path, *, ok: bool = True, source: str = "built_in", rows: int = 9, fixture_count: int = 3) -> None:
    floors = NATIVE_TIER_RANGE_FLOORS.get(source, NATIVE_TIER_RANGE_FLOORS["custom"])
    fixtures = NATIVE_TIER_RANGE_FIXTURES.get(source, NATIVE_TIER_RANGE_FIXTURES["built_in"])
    csv_name = NATIVE_TIER_RANGE_CSV_BY_SOURCE.get(source, NATIVE_TIER_RANGE_CSV_ARTIFACT)
    total_stream_bytes_by_tier = {
        tier: NATIVE_TIER_RANGE_STREAM_BYTES * fixture_count if ok else 0
        for tier in NATIVE_TIER_RANGE_TIERS
    }
    total_index_entries_by_tier = {
        tier: ((NATIVE_TIER_RANGE_INPUT_BYTES + block_len - 1) // block_len) * fixture_count if ok else 0
        for tier, block_len in NATIVE_TIER_RANGE_TIERS.items()
    }
    # The dashboard strict smoke fixtures intentionally derive their summary
    # aggregates from the CSV constants so summary-vs-CSV drift checks exercise
    # the same contract real benchmark producers must satisfy.
    min_range_mib_s_by_tier = {tier: round(NATIVE_TIER_RANGE_RANGE_MIB_S, 6) if ok else 0.0 for tier in NATIVE_TIER_RANGE_TIERS}
    min_full_input_mib_s_by_tier = {tier: round(NATIVE_TIER_RANGE_FULL_INPUT_MIB_S, 6) if ok else 0.0 for tier in NATIVE_TIER_RANGE_TIERS}
    payload = {
        "schema": "vort.native_tier_range_bench_gate",
        "schema_version": 1,
        "source": source,
        "ok": ok,
        "rows": rows if ok else 0,
        "fixture_count": fixture_count if ok else 0,
        "tier_count": 3,
        "fixtures": sorted(fixtures) if ok else [],
        "tiers": list(NATIVE_TIER_RANGE_TIERS) if ok else [],
        "enforce_throughput": False,
        "min_range_mib_s_by_tier": min_range_mib_s_by_tier,
        "min_full_input_mib_s_by_tier": min_full_input_mib_s_by_tier,
        "range_mib_s_floor_by_tier": floors,
        "total_stream_bytes_by_tier": total_stream_bytes_by_tier,
        "total_index_entries_by_tier": total_index_entries_by_tier,
        "csv": f"zig-out/{csv_name}",
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
    write_native_tier_range_csv(root / NATIVE_TIER_RANGE_CSV_ARTIFACT, ["text", "structured", "repetitive"])
    write_native_tier_range_csv(root / NATIVE_TIER_RANGE_FILES_CSV_ARTIFACT, ["README.md", "roadmap.md"])
    write_native_tier_range_csv(root / NATIVE_TIER_RANGE_CORPUS_CSV_ARTIFACT, ["ooffice-128k", "nci-128k", "mozilla-128k"])
    write_native_tier_corpus_discovery_summary(root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT)


def write_healthy_artifacts(root: Path) -> None:
    write_header_summary(root / HEADER_INSPECT_ARTIFACT)
    write_header_markdown(root / HEADER_INSPECT_MARKDOWN_ARTIFACT)
    write_dashboard_strict_summary(root / DASHBOARD_STRICT_ARTIFACT)
    write_dashboard_configuration_artifacts(root)
    write_validation_json_artifacts(root)
    write_sidecar_corrupt_report(root / SIDECAR_CORRUPT_ARTIFACT)
    write_sidecar_corrupt_markdown(root / SIDECAR_CORRUPT_MARKDOWN_ARTIFACT)
    write_huffman_length_csv(root / HUFFMAN_LENGTH_ARTIFACT)
    write_huffman_length_markdown(root / "vort-huffman-length-report.md")
    write_level_report_csv(root / LEVEL_REPORT_CSV_ARTIFACT)
    write_level_report_markdown(root / LEVEL_REPORT_MARKDOWN_ARTIFACT)
    write_dynamic_plan_csv(root / DYNAMIC_PLAN_ARTIFACT, [{"path": "README.md"}, {"path": "docs/roadmap.md"}])
    write_dynamic_plan_csv(
        root / DYNAMIC_PLAN_BUILTINS_ARTIFACT,
        [
            {"path": "tiny"},
            {"path": "repetitive"},
            {"path": "overlap-rle"},
            {"path": "distance-heavy"},
            {"path": "dynamic-match"},
            {"path": "text"},
            {"path": "binary"},
        ],
    )
    write_checksum_bench_csv(root / CHECKSUM_BENCH_ARTIFACT)
    write_chunk_cursor_bench_csv(root / CHUNK_CURSOR_BENCH_ARTIFACT)
    write_deflate_match_copy_bench_csv(root / DEFLATE_MATCH_COPY_BENCH_ARTIFACT)
    write_deflate_huffman_build_bench_csv(root / DEFLATE_HUFFMAN_BUILD_BENCH_ARTIFACT)
    write_deflate_huffman_lookup_bench_csv(root / DEFLATE_HUFFMAN_LOOKUP_BENCH_ARTIFACT)
    write_deflate_chunked_huffman_bench_csv(root / DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT)
    write_deflate_extra_bits_bench_csv(root / DEFLATE_EXTRA_BITS_BENCH_ARTIFACT)
    write_dictionary_decode_bench_csv(root / DICTIONARY_DECODE_BENCH_ARTIFACT)
    write_png_scanline_bench_csv(root / PNG_SCANLINE_BENCH_ARTIFACT)
    write_chunked_zlib_bench_csv(root / CHUNKED_ZLIB_BENCH_ARTIFACT)
    write_chunked_zlib_bench_markdown(root / CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT)
    write_png_streaming_zlib_bench_csv(root / PNG_STREAMING_ZLIB_BENCH_ARTIFACT)
    write_deflate_dynamic_decode_profile_csv(root / DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT)
    write_fuzz_corpus_report(root / FUZZ_CORPUS_ARTIFACT)
    write_fuzz_corpus_markdown(root / FUZZ_CORPUS_MARKDOWN_ARTIFACT)
    write_fuzz_coverage_report(root / FUZZ_COVERAGE_ARTIFACT)
    write_decode_stage_report(root / DECODE_STAGE_ARTIFACT)
    write_decode_stage_csv(root / DECODE_STAGE_CSV_ARTIFACT)
    write_decode_stage_markdown(root / DECODE_STAGE_MARKDOWN_ARTIFACT)
    write_python_zlib_diff_report(root / PYTHON_ZLIB_DIFF_ARTIFACT)
    write_zlib_relaxed_report(root / ZLIB_RELAXED_ARTIFACT)
    write_zlib_relaxed_gate(root / ZLIB_RELAXED_GATE_ARTIFACT)
    write_snappy_report_csv(root / SNAPPY_REPORT_ARTIFACT)
    write_png_scratch_report(root / PNG_SCRATCH_ARTIFACT)
    write_native_fuzz_corpus_artifacts(root)
    write_br_static_dictionary_artifacts(root)
    write_native_allocation_artifacts(root)
    write_native_library_bench_csv(root / NATIVE_LIBRARY_BENCH_ARTIFACT)
    write_zstd_compare_artifacts(root)
    write_native_summary_error_dashboard(root / NATIVE_SUMMARY_ERROR_ARTIFACT)
    write_native_summary_error_negative_smoke(root / NATIVE_SUMMARY_ERROR_NEGATIVE_ARTIFACT)
    write_native_codec_probes(root / NATIVE_CODEC_PROBES_ARTIFACT)
    write_lz4_native_summary(root / LZ4_NATIVE_SUMMARY_ARTIFACT)
    write_zstd_native_summary(root / ZSTD_NATIVE_SUMMARY_ARTIFACT)
    write_native_tier_range_summaries(root)


def dashboard_args(root: Path, producer_map: Path, *extra: str) -> list[str]:
    csv_header_manifest = write_csv_header_manifest(root)
    markdown_heading_manifest = write_markdown_heading_manifest(root)
    return dashboard_args_with_manifests(root, producer_map, csv_header_manifest, markdown_heading_manifest, *extra)


def dashboard_args_with_manifests(
    root: Path,
    producer_map: Path,
    csv_header_manifest: Path,
    markdown_heading_manifest: Path,
    *extra: str,
) -> list[str]:
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
        "--csv-header-manifest",
        str(csv_header_manifest),
        "--markdown-heading-manifest",
        str(markdown_heading_manifest),
        *extra,
    ]


def markdown_manifest_drift_fixture(
    root: Path,
    fixture_name: str,
    target_artifact: str,
    manifest_field: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted Markdown manifest field.

    The general non-JSON health fixture already proves that malformed Markdown
    artifacts fail aggregate health. These targeted fixtures instead keep the
    artifacts healthy and corrupt only the expected layout manifest, so the
    table-row and separator-row drift gates are covered directly.
    """

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    csv_manifest = write_csv_header_manifest(fixture_root)
    markdown_manifest = write_markdown_heading_manifest(fixture_root)
    payload = json.loads(markdown_manifest.read_text())
    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, list):
        raise AssertionError("synthetic Markdown manifest did not contain artifact rows")
    for artifact in artifacts:
        if isinstance(artifact, dict) and artifact.get("name") == target_artifact:
            value = artifact.get(manifest_field)
            if manifest_field in {"heading_count", "table_row_count", "table_separator_count"}:
                if not isinstance(value, int) or isinstance(value, bool):
                    raise AssertionError(f"{target_artifact} manifest field {manifest_field!r} is not an integer")
                artifact[manifest_field] = value + 1
            elif manifest_field in {"first_heading", "signature"}:
                if not isinstance(value, str) or not value:
                    raise AssertionError(f"{target_artifact} manifest field {manifest_field!r} is not a non-empty string")
                artifact[manifest_field] = f"{value} drift"
            else:
                raise AssertionError(f"unsupported Markdown manifest drift field {manifest_field!r}")
            break
    else:
        raise AssertionError(f"missing {target_artifact} in synthetic Markdown manifest")
    markdown_manifest.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def csv_manifest_drift_fixture(
    root: Path,
    fixture_name: str,
    target_artifact: str,
    manifest_field: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted CSV header manifest field."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    csv_manifest = write_csv_header_manifest(fixture_root)
    markdown_manifest = write_markdown_heading_manifest(fixture_root)
    payload = json.loads(csv_manifest.read_text())
    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, list):
        raise AssertionError("synthetic CSV header manifest did not contain artifact rows")
    for artifact in artifacts:
        if isinstance(artifact, dict) and artifact.get("name") == target_artifact:
            if manifest_field == "column_count":
                value = artifact.get("column_count")
                if not isinstance(value, int) or isinstance(value, bool):
                    raise AssertionError(f"{target_artifact} CSV manifest column_count is not an integer")
                artifact["column_count"] = value + 1
            elif manifest_field == "signature":
                value = artifact.get("signature")
                if not isinstance(value, str) or not value:
                    raise AssertionError(f"{target_artifact} CSV manifest signature is not a non-empty string")
                artifact["signature"] = f"{value}-drift"
            else:
                raise AssertionError(f"unsupported CSV manifest drift field {manifest_field!r}")
            break
    else:
        raise AssertionError(f"missing {target_artifact} in synthetic CSV header manifest")
    csv_manifest.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def csv_manifest_membership_fixture(
    root: Path,
    fixture_name: str,
    artifact_name: str,
    mutation: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with synthetic CSV manifest membership drift."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    target = fixture_root / artifact_name
    write_synthetic_csv_artifact(target)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    add_synthetic_csv_artifact_metadata(producer_map, artifact_name)
    csv_manifest = write_csv_header_manifest(fixture_root)
    markdown_manifest = write_markdown_heading_manifest(fixture_root)

    if mutation == "missing":
        target.unlink()
        payload = json.loads(producer_map.read_text())
        payload.get("exact", {}).pop(artifact_name, None)
        payload.get("artifact_metadata", {}).pop(artifact_name, None)
        producer_map.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    elif mutation == "unknown":
        remove_csv_manifest_artifact(csv_manifest, artifact_name)
    else:
        raise AssertionError(f"unsupported CSV manifest membership mutation {mutation!r}")

    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def add_synthetic_csv_artifact_metadata(producer_map: Path, artifact_name: str) -> None:
    payload = json.loads(producer_map.read_text())
    payload.setdefault("exact", {})[artifact_name] = "synthetic non-json CSV artifact audit fixture"
    payload.setdefault("artifact_metadata", {})[artifact_name] = {
        "expected_format": "csv",
        "smoke_gate": "synthetic non-json CSV artifact audit fixture",
    }
    producer_map.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_synthetic_csv_artifact(path: Path) -> None:
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["case", "value"])
        writer.writerow(["ok", "1"])


def remove_csv_manifest_artifact(manifest_path: Path, artifact_name: str) -> None:
    payload = json.loads(manifest_path.read_text())
    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, list):
        raise AssertionError("synthetic CSV header manifest did not contain artifact rows")
    filtered = [artifact for artifact in artifacts if not (isinstance(artifact, dict) and artifact.get("name") == artifact_name)]
    if len(filtered) == len(artifacts):
        raise AssertionError(f"missing {artifact_name} in synthetic CSV header manifest")
    payload["artifacts"] = filtered
    payload["artifact_count"] = len(filtered)
    manifest_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def add_synthetic_markdown_artifact_metadata(producer_map: Path, artifact_name: str) -> None:
    payload = json.loads(producer_map.read_text())
    payload.setdefault("exact", {})[artifact_name] = "synthetic non-json Markdown artifact audit fixture"
    payload.setdefault("artifact_metadata", {})[artifact_name] = {
        "expected_format": "md",
        "smoke_gate": "synthetic non-json Markdown artifact audit fixture",
    }
    producer_map.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_synthetic_markdown_artifact(path: Path) -> None:
    path.write_text("# Synthetic Markdown artifact\n\n| case | value |\n| --- | ---: |\n| ok | 1 |\n")


def remove_markdown_manifest_artifact(manifest_path: Path, artifact_name: str) -> None:
    payload = json.loads(manifest_path.read_text())
    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, list):
        raise AssertionError("synthetic Markdown heading manifest did not contain artifact rows")
    filtered = [artifact for artifact in artifacts if not (isinstance(artifact, dict) and artifact.get("name") == artifact_name)]
    if len(filtered) == len(artifacts):
        raise AssertionError(f"missing {artifact_name} in synthetic Markdown heading manifest")
    payload["artifacts"] = filtered
    payload["artifact_count"] = len(filtered)
    manifest_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def markdown_manifest_membership_fixture(
    root: Path,
    fixture_name: str,
    artifact_name: str,
    mutation: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with synthetic Markdown heading-manifest membership drift."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    target = fixture_root / artifact_name
    write_synthetic_markdown_artifact(target)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    add_synthetic_markdown_artifact_metadata(producer_map, artifact_name)
    csv_manifest = write_csv_header_manifest(fixture_root)
    markdown_manifest = write_markdown_heading_manifest(fixture_root)

    if mutation == "missing":
        target.unlink()
        payload = json.loads(producer_map.read_text())
        payload.get("exact", {}).pop(artifact_name, None)
        payload.get("artifact_metadata", {}).pop(artifact_name, None)
        producer_map.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    elif mutation == "unknown":
        remove_markdown_manifest_artifact(markdown_manifest, artifact_name)
    else:
        raise AssertionError(f"unsupported Markdown manifest membership mutation {mutation!r}")

    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def markdown_artifact_layout_fixture(
    root: Path,
    fixture_name: str,
    artifact_name: str,
    mutation: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally malformed synthetic Markdown artifact.

    Mutations with no heading are removed from the heading manifest so the
    fixture isolates the artifact layout rule rather than also exercising
    manifest-missing drift. Mutations that still have headings regenerate the
    manifest after the mutation, keeping table-count and heading signatures
    aligned while the structural rule fails.
    """

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    target = fixture_root / artifact_name
    write_synthetic_markdown_artifact(target)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    add_synthetic_markdown_artifact_metadata(producer_map, artifact_name)
    csv_manifest = write_csv_header_manifest(fixture_root)

    if mutation == "empty":
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
        remove_markdown_manifest_artifact(markdown_manifest, artifact_name)
        target.write_text("")
    elif mutation == "marker_missing":
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
        remove_markdown_manifest_artifact(markdown_manifest, artifact_name)
        target.write_text("plain text without markdown markers\n")
    elif mutation == "heading_missing":
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
        remove_markdown_manifest_artifact(markdown_manifest, artifact_name)
        target.write_text("| case | value |\n| --- | ---: |\n| ok | 1 |\n")
    elif mutation == "heading_not_first":
        target.write_text("| case | value |\n| --- | ---: |\n| ok | 1 |\n\n# Synthetic Markdown artifact\n")
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
    elif mutation == "table_missing":
        target.write_text("# Synthetic Markdown artifact\n\nplain text without a table\n")
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
    elif mutation == "table_separator_missing":
        target.write_text("# Synthetic Markdown artifact\n\n| case | value |\n| ok | 1 |\n")
        markdown_manifest = write_markdown_heading_manifest(fixture_root)
    else:
        raise AssertionError(f"unsupported synthetic Markdown artifact mutation {mutation!r}")

    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def csv_artifact_layout_fixture(
    root: Path,
    fixture_name: str,
    artifact_name: str,
    mutation: str,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally malformed synthetic CSV artifact.

    A synthetic artifact avoids coupling these non-JSON audit checks to the
    level-report or benchmark-specific health gates. Each mutation isolates one
    CSV layout rule while producer/smoke metadata remains healthy.
    """

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    target = fixture_root / artifact_name
    write_synthetic_csv_artifact(target)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    add_synthetic_csv_artifact_metadata(producer_map, artifact_name)
    csv_manifest = write_csv_header_manifest(fixture_root)
    markdown_manifest = write_markdown_heading_manifest(fixture_root)

    if mutation in {"empty", "blank_header", "duplicate_header"}:
        # These malformed headers are rejected before the artifact can be
        # matched against the header manifest. Removing the synthetic row keeps
        # each fixture focused on the CSV layout rule rather than also testing
        # expected-manifest-missing behavior.
        remove_csv_manifest_artifact(csv_manifest, artifact_name)

    if mutation == "empty":
        target.write_text("")
    elif mutation == "blank_header":
        with target.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["", "value"])
            writer.writerow(["ok", "1"])
    elif mutation == "duplicate_header":
        with target.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["case", "case"])
            writer.writerow(["ok", "1"])
    elif mutation == "no_data":
        with target.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["case", "value"])
    elif mutation == "ragged":
        with target.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["case", "value"])
            writer.writerow(["ok"])
    else:
        raise AssertionError(f"unsupported synthetic CSV artifact mutation {mutation!r}")

    result = run(
        dashboard_args_with_manifests(
            fixture_root,
            producer_map,
            csv_manifest,
            markdown_manifest,
            "--strict-validation-health",
        ),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def rewrite_csv_rows(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def native_allocation_drift_fixture(
    root: Path,
    fixture_name: str,
    mutate_report=None,
    mutate_smoke=None,
    mutate_negative=None,
    mutate_markdown=None,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted native allocation artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    report_path = fixture_root / NATIVE_ALLOCATION_REPORT_ARTIFACT
    smoke_path = fixture_root / NATIVE_ALLOCATION_SMOKE_ARTIFACT
    negative_path = fixture_root / NATIVE_ALLOCATION_NEGATIVE_ARTIFACT
    markdown_path = fixture_root / NATIVE_ALLOCATION_REPORT_MARKDOWN_ARTIFACT
    if mutate_report is not None:
        report = json.loads(report_path.read_text())
        mutate_report(report)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if mutate_smoke is not None:
        smoke = json.loads(smoke_path.read_text())
        mutate_smoke(smoke)
        smoke_path.write_text(json.dumps(smoke, indent=2, sort_keys=True) + "\n")
    if mutate_negative is not None:
        negative = json.loads(negative_path.read_text())
        mutate_negative(negative)
        negative_path.write_text(json.dumps(negative, indent=2, sort_keys=True) + "\n")
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def native_fuzz_corpus_drift_fixture(
    root: Path,
    fixture_name: str,
    mutate_report=None,
    mutate_coverage=None,
    mutate_markdown=None,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted native fuzz corpus artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    report_path = fixture_root / NATIVE_FUZZ_ARTIFACT
    coverage_path = fixture_root / NATIVE_FUZZ_COVERAGE_ARTIFACT
    markdown_path = fixture_root / NATIVE_FUZZ_MARKDOWN_ARTIFACT
    if mutate_report is not None:
        report = json.loads(report_path.read_text())
        mutate_report(report)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if mutate_coverage is not None:
        coverage = json.loads(coverage_path.read_text())
        mutate_coverage(coverage)
        coverage_path.write_text(json.dumps(coverage, indent=2, sort_keys=True) + "\n")
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def decode_stage_drift_fixture(
    root: Path,
    fixture_name: str,
    mutate_report=None,
    mutate_csv=None,
    mutate_markdown=None,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted decode-stage artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    report_path = fixture_root / DECODE_STAGE_ARTIFACT
    csv_path = fixture_root / DECODE_STAGE_CSV_ARTIFACT
    markdown_path = fixture_root / DECODE_STAGE_MARKDOWN_ARTIFACT
    if mutate_report is not None:
        report = json.loads(report_path.read_text())
        mutate_report(report)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if mutate_csv is not None:
        with csv_path.open(newline="") as f:
            reader = csv.DictReader(f)
            fieldnames = list(reader.fieldnames or [])
            rows = list(reader)
        mutate_csv(rows, fieldnames, csv_path)
        rewrite_csv_rows(csv_path, rows, fieldnames)
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def fuzz_corpus_drift_fixture(
    root: Path,
    fixture_name: str,
    mutate_report=None,
    mutate_coverage=None,
    mutate_markdown=None,
) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted fuzz corpus artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    report_path = fixture_root / FUZZ_CORPUS_ARTIFACT
    coverage_path = fixture_root / FUZZ_COVERAGE_ARTIFACT
    markdown_path = fixture_root / FUZZ_CORPUS_MARKDOWN_ARTIFACT
    if mutate_report is not None:
        report = json.loads(report_path.read_text())
        mutate_report(report)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if mutate_coverage is not None:
        coverage = json.loads(coverage_path.read_text())
        mutate_coverage(coverage)
        coverage_path.write_text(json.dumps(coverage, indent=2, sort_keys=True) + "\n")
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def dynamic_plan_drift_fixture(root: Path, fixture_name: str, mutate_csv) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted dynamic-plan CSV artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    csv_path = fixture_root / DYNAMIC_PLAN_ARTIFACT
    with csv_path.open(newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        rows = list(reader)
    mutate_csv(rows, fieldnames, csv_path)
    rewrite_csv_rows(csv_path, rows, fieldnames)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def level_report_drift_fixture(root: Path, fixture_name: str, mutate_csv=None, mutate_markdown=None) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted compression level report."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    csv_path = fixture_root / LEVEL_REPORT_CSV_ARTIFACT
    markdown_path = fixture_root / LEVEL_REPORT_MARKDOWN_ARTIFACT
    if mutate_csv is not None:
        with csv_path.open(newline="") as f:
            reader = csv.DictReader(f)
            fieldnames = list(reader.fieldnames or [])
            rows = list(reader)
        mutate_csv(rows, fieldnames, csv_path, markdown_path)
        rewrite_csv_rows(csv_path, rows, fieldnames)
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def huffman_length_drift_fixture(root: Path, fixture_name: str, mutate_csv=None, mutate_markdown=None) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted Huffman length report."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    csv_path = fixture_root / HUFFMAN_LENGTH_ARTIFACT
    markdown_path = fixture_root / "vort-huffman-length-report.md"
    if mutate_csv is not None:
        with csv_path.open(newline="") as f:
            reader = csv.DictReader(f)
            fieldnames = list(reader.fieldnames or [])
            rows = list(reader)
        mutate_csv(rows, fieldnames, csv_path, markdown_path)
        if rows is not None:
            rewrite_csv_rows(csv_path, rows, fieldnames)
    if mutate_markdown is not None:
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def sidecar_corrupt_drift_fixture(root: Path, fixture_name: str, mutate_report=None, mutate_markdown=None) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted sidecar corrupt artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    report_path = fixture_root / SIDECAR_CORRUPT_ARTIFACT
    if mutate_report is not None:
        report = json.loads(report_path.read_text())
        mutate_report(report)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if mutate_markdown is not None:
        markdown_path = fixture_root / SIDECAR_CORRUPT_MARKDOWN_ARTIFACT
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def header_inspect_drift_fixture(root: Path, fixture_name: str, mutate_summary, mutate_markdown=None) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted header-inspect artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    summary_path = fixture_root / HEADER_INSPECT_ARTIFACT
    summary = json.loads(summary_path.read_text())
    mutate_summary(summary)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    if mutate_markdown is not None:
        markdown_path = fixture_root / HEADER_INSPECT_MARKDOWN_ARTIFACT
        mutate_markdown(markdown_path)
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


def validation_json_smoke_drift_fixture(root: Path, fixture_name: str, mutate) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    """Run dashboard_index with one intentionally drifted validation JSON smoke artifact."""

    fixture_root = root / fixture_name
    fixture_root.mkdir()
    write_healthy_artifacts(fixture_root)
    payload_path = fixture_root / VALIDATION_JSON_SMOKE_ARTIFACT
    payload = json.loads(payload_path.read_text())
    mutate(payload)
    payload_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    producer_map = fixture_root / "producers.json"
    write_producer_map(producer_map)
    result = run(
        dashboard_args(fixture_root, producer_map, "--strict-validation-health"),
        check=False,
    )
    manifest = json.loads((fixture_root / "vort-dashboard-index.json").read_text())
    return result, manifest


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
                HEADER_INSPECT_MARKDOWN_ARTIFACT,
                DASHBOARD_STRICT_ARTIFACT,
                DASHBOARD_STRICT_MARKDOWN_ARTIFACT,
                DASHBOARD_CONFIG_INDEX_SMOKE_ARTIFACT,
                DASHBOARD_CONFIG_INDEX_NEGATIVE_ARTIFACT,
                DASHBOARD_CATEGORY_NEGATIVE_ARTIFACT,
                DASHBOARD_PRODUCERS_REQUIRED_ARTIFACT,
                DASHBOARD_PRODUCERS_NEGATIVE_ARTIFACT,
                VALIDATION_JSON_SMOKE_ARTIFACT,
                VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT,
                SIDECAR_CORRUPT_ARTIFACT,
                SIDECAR_CORRUPT_MARKDOWN_ARTIFACT,
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
        assert manifest["sidecar_corrupt_present"] is True
        assert manifest["sidecar_corrupt_markdown_present"] is True
        assert manifest["sidecar_corrupt_healthy"] is True
        assert manifest["sidecar_corrupt_rows"] == 2
        assert manifest["sidecar_corrupt_item_rows"] == 2
        assert manifest["sidecar_corrupt_item_count_mismatch"] == 0
        assert manifest["sidecar_corrupt_markdown_rows"] == 2
        assert manifest["sidecar_corrupt_markdown_matched"] == 2
        assert manifest["sidecar_corrupt_markdown_unmatched"] == 0
        assert manifest["python_zlib_diff_inline_payloads"] == 2
        assert manifest["python_zlib_diff_large_file_payload_overflow"] == 0
        assert manifest["python_zlib_diff_payload_cli_success_expected"] == 50
        assert manifest["python_zlib_diff_cli_success_expected"] == 90
        assert manifest["python_zlib_diff_expected_failure_expected"] == 35
        assert manifest["python_zlib_diff_cli_total_expected"] == 125
        assert manifest["python_zlib_diff_cli_success_exact_mismatch"] == 0
        assert manifest["python_zlib_diff_expected_failure_exact_mismatch"] == 0
        assert manifest["python_zlib_diff_cli_outcome_exact_mismatch"] == 0
        assert manifest["header_inspect_present"] is True
        assert manifest["header_inspect_ok"] is True
        assert manifest["header_inspect_missing_workflow_count"] == 0
        assert manifest["native_summary_error_present"] is True
        assert manifest["native_summary_error_healthy"] is True
        assert manifest["native_summary_error_case_count"] == 14
        assert manifest["native_summary_error_negative_present"] is True
        assert manifest["native_summary_error_negative_healthy"] is True
        assert manifest["native_summary_error_negative_case_count"] == 3
        assert manifest["native_summary_error_negative_rows"] == 3
        assert manifest["native_summary_error_negative_count_mismatch"] == 0
        assert manifest["native_summary_error_negative_matched"] == 3
        assert manifest["native_summary_error_negative_expected_failures"] == 3
        assert manifest["br_static_dictionary_negative_rows"] == 1
        assert manifest["br_static_dictionary_negative_count_mismatch"] == 0
        assert manifest["br_static_dictionary_negative_unmatched"] == 0
        assert manifest["br_static_dictionary_report_negative_rows"] == 1
        assert manifest["br_static_dictionary_report_negative_count_mismatch"] == 0
        assert manifest["br_static_dictionary_report_negative_unmatched"] == 0
        assert manifest["native_codec_probes_probe_rows"] == 4
        assert manifest["native_codec_probes_probe_case_sum"] == 362
        assert manifest["native_codec_probes_probe_count_mismatch"] == 0
        assert manifest["native_codec_probes_probe_case_sum_mismatch"] == 0
        assert manifest["native_codec_probes_missing_required_probes"] == 0
        assert manifest["native_codec_probes_duplicate_probe_rows"] == 0
        assert manifest["native_codec_probes_coverage_count"] == 4
        assert manifest["native_codec_probes_coverage_count_mismatch"] == 0
        assert manifest["native_codec_probes_missing_required_coverage"] == 0
        assert manifest["native_codec_probes_duplicate_coverage_rows"] == 0
        assert manifest["native_codec_probes_capability_rows"] == 16
        assert manifest["native_codec_probes_capability_count_mismatch"] == 0
        assert manifest["native_codec_probes_capability_row_unhealthy"] == 0
        assert manifest["native_codec_probes_missing_required_capabilities"] == 0
        assert manifest["native_codec_probes_duplicate_capability_rows"] == 0
        assert manifest["lz4_native_summary_present"] is True
        assert manifest["lz4_native_summary_healthy"] is True
        assert manifest["zstd_native_summary_present"] is True
        assert manifest["zstd_native_summary_healthy"] is True
        assert manifest["native_tier_range_present"] is True
        assert manifest["native_tier_range_healthy"] is True
        assert manifest["native_tier_range_summary_count"] == 3
        assert manifest["native_tier_range_rows"] == 24
        assert manifest["native_tier_range_csv_present_count"] == 3
        assert manifest["native_tier_range_csv_healthy_count"] == 3
        assert manifest["native_tier_range_csv_rows"] == 24
        assert manifest["native_tier_range_csv_positive_rows"] == 24
        assert manifest["native_tier_range_csv_shape_rows"] == 24
        assert manifest["native_tier_range_csv_throughput_rows"] == 24
        assert manifest["native_tier_range_csv_missing_sources"] == []
        assert manifest["native_tier_range_csv_missing_pairs"] == []
        assert manifest["native_tier_range_csv_duplicate_pairs"] == []
        assert manifest["native_tier_range_csv_unknown_pairs"] == []
        assert manifest["native_tier_range_source_count_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_row_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_fixture_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_tier_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_path_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_stream_bytes_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_index_entries_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_min_range_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_min_full_mismatch"] == 0
        assert manifest["native_tier_range_summary_csv_mismatch_total"] == 0
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
        assert manifest["native_tier_corpus_discovery_selected_case_mismatch"] == 0
        assert manifest["native_tier_corpus_discovery_csv_path_mismatch"] == 0
        assert manifest["native_tier_corpus_discovery_summary_fixture_mismatch"] == 0
        assert manifest["native_tier_corpus_discovery_csv_fixture_mismatch"] == 0
        assert manifest["native_tier_corpus_discovery_csv_byte_mismatch"] == 0
        assert manifest["native_tier_corpus_discovery_mismatch_total"] == 0
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
                    "| producer steps | 88/88 | 0 | allowed missing 0 |",
                    "| smoke gates | 88/88 | 0 | required missing 0 |",
                    "| CSV artifacts | 26/26 | data rows 554, header cells 645, header signatures 22, manifest 26/26, parse failed 0, empty 0, blank headers 0, duplicate headers 0, no-data 0, ragged 0, header drift 0/0/0/0 |",
                    "| Markdown artifacts | 20/20 | manifest 20/20, read failed 0, empty 0, marker missing 0, heading missing 0, heading not first 0, table missing 0, separator missing 0, heading drift 0/0/0/0/0, table drift 0/0, healthy `True` |",
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
                    "| strict checks | 1 | rows 1, expected failures/matched 0/1 |",
                    "| modes | 1 | rows 1, expected/missing 1/0 |",
                    "| requirement deltas | 0 | checks/expected/matched 0/0/0, count mismatch 0 |",
                    f"| Markdown rows | {len(load_expected_validation_reasons(VALIDATION_REASONS)) + 12}/{len(load_expected_validation_reasons(VALIDATION_REASONS)) + 12} | present `True`, unmatched 0 |",
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
                    "| config index | 3 | rows 3, matched 3, mismatch 0, row-unmatched 0 |",
                    "| config negative | 2 | rows 2, matched 2, mismatch 0, row-unmatched 0 |",
                    "| category guardrails | 3 | rows 3, matched 3, mismatch 0, row-unmatched 0 |",
                    "| required producers | 4 | rows 4, matched 4, mismatch 0, row-unmatched 0, required smoke gates 2 |",
                    "| producer guardrails | 2 | rows 2, matched 2, mismatch 0, row-unmatched 0, healthy `True` |",
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
                    "| checked schemas | 5 | unique 5, duplicates 0, smoke present `True`, ok `True` |",
                    "| observed schemas | 5 | rows 5, mismatch 0, unchecked 0, unchecked rows 0, unchecked mismatch 0 |",
                    "| JSON artifact manifest audit | 5/5 | parsed 5, schema 5, excluded 2, parse/missing/manifest failures 0/0/0, accounting mismatch 0 |",
                    "| CLI validation | 1 | failure-ok `False`, hint `payload_corrupt` |",
                    "| report rows | 1 | corrupt rows 2 |",
                    "| docs negative cases | 2/2 | rows 2, mismatch 0, row-unmatched 0, present `True`, healthy `True` |",
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
                    "| codec | frames | skippable | checksum | block checksum | dictionary | content size | blocks raw/rle/compressed | payload/skippable bytes | declared slack | mismatches | overflow |",
                    "| `lz4` | 2 | 1 | 2 | 1 | 1 | 2 | 2/0/0 | 6/16 | 0 | 0 | 0 |",
                    "| `zstd` | 2 | 1 | 1 | 0 | 1 | 2 | 2/0/0 | 6/16 | 0 | 0 | 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_summary_error_markdown_tables",
                "native summary error Markdown tables",
                dashboard_markdown,
                [
                    "## Native summary error aggregate drift",
                    "| category | count | detail |",
                    "| case rows | 14 | declared 14, mismatch 0 |",
                    "| codec case drift | 0 | lz4/zstd 7/7 |",
                    "| count drift | 0 | errors 0, phases 0 |",
                    "| codec count drift | 0 | errors 0, phases 0 |",
                    "| offset drift | 0 | healthy `True` |",
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
                    "## Native tier range CSV coverage",
                    "| csv artifacts | 3 | healthy 3, missing sources 0 |",
                    "| csv rows | 24 | positive/shape 24/24 |",
                    "| throughput rows | 24 | pair drift 0, duplicate/unknown 0/0 |",
                    "| summary/CSV mismatches | 0 | source count 0, rows/fixtures/tiers/path 0/0/0/0, stream/index/min range/min full 0/0/0/0 |",
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
                    "| discovery mismatches | 0 | selected/csv path/summary fixtures/csv fixtures/csv bytes 0/0/0/0/0 |",
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
                    "## Native codec probe Markdown drift",
                    "| Markdown checks | 29/29 | present `True`, unmatched 0 |",
                    "| coverage rows | 4/4 | case sum 362/362 |",
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
                    "| JSON row checks | 3/3 | negatives 3/3, count mismatch 0 |",
                    "| drift checks | 0 | duplicates cases/negatives/commands/workflows/required/help 0/0/0/0/0/0, command missing/unknown 0/0 |",
                    "| Markdown rows | 36/36 | present `True`, unmatched 0 |",
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
                    "| JSON item rows | 2 | count/malformed/duplicate 0/0/0 |",
                    "| Markdown rows | 2/2 | present `True`, unmatched/malformed/duplicate/unknown 0/0/0/0 |",
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
                    "| malformed rows | 0 | blank/duplicate cases 0/0, healthy `True` |",
                    "| Markdown summary | 7/7 | present `True` |",
                    "| Markdown case rows | 1/1 | unmatched 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "level_report_markdown_table",
                "level report Markdown table",
                dashboard_markdown,
                [
                    "## Compression level report coverage",
                    "| category | count | detail |",
                    "| rows | 48 | expected 48, present `True` |",
                    "| row checks | 48 | positive/token/ratio/roundtrip 48/48/48/48 |",
                    "| pair drift | 0 | duplicate/unknown 0/0 |",
                    "| Markdown summary | 4/4 | present `True`, healthy `True` |",
                    "| Markdown detail rows | 48/48 | unmatched 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "dynamic_plan_markdown_table",
                "dynamic plan Markdown table",
                dashboard_markdown,
                [
                    "## Dynamic plan report coverage",
                    "| category | count | detail |",
                    "| rows | 9 | expected 9, sources 2/2 |",
                    "| row checks | 9 | token/histogram/ratio 9/9/9 |",
                    "| bit/zlib checks | 9/9 | malformed 0, missing/duplicate/unknown paths 0/0/0, healthy `True` |",
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
                    "| workload rows | 21 | positive/throughput rows 21/21 |",
                    "| digest mix groups | 2 | crc32/crc32c 1/1, missing/duplicate/unknown algorithms 0/0/0, healthy `True` |",
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
                    "| shape rows | 8 | positive/throughput rows 8/8 |",
                    "| checksum matches | 4 | expected cases 4 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
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
                    "| class rows | 21 | positive/output/throughput rows 21/21/21 |",
                    "| checksum matches | 7 | expected cases 7 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
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
                    "| lookup rows | 14 | positive/throughput rows 14/14 |",
                    "| checksum variant cases | 4 | expected cases 4 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
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
                    "| lookup rows | 21 | positive/throughput rows 21/21 |",
                    "| checksum matches | 6 | expected cases 6 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_chunked_huffman_bench_markdown_table",
                "deflate chunked Huffman benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Deflate chunked Huffman benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 57 | expected 57, present `True` |",
                    "| shape rows | 57 | positive/throughput rows 57/57 |",
                    "| chunk counts | 57 | buffered rows 3 |",
                    "| checksum matches | 3 | expected cases 3 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_extra_bits_bench_markdown_table",
                "deflate extra-bit benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Deflate extra-bit benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 105 | expected 105, present `True` |",
                    "| shape rows | 105 | positive/throughput rows 105/105 |",
                    "| checksum matches | 11 | paired checksums 28/28 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "dictionary_decode_bench_markdown_table",
                "dictionary decode benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Dictionary decode benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 18 | expected 18, present `True` |",
                    "| shape rows | 18 | positive/throughput rows 18/18 |",
                    "| output-size rows | 18 | checksum payloads 3 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "png_scanline_bench_markdown_table",
                "PNG scanline benchmark Markdown table",
                dashboard_markdown,
                [
                    "## PNG scanline benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 30 | expected 30, present `True` |",
                    "| shape rows | 30 | positive/throughput rows 30/30 |",
                    "| input/output rows | 30 | checksum bpp groups 6 |",
                    "| pair drift | 0 | duplicate/unknown 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "chunked_zlib_bench_markdown_table",
                "chunked zlib benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Chunked zlib benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 8 | expected 8, present `True` |",
                    "| shape rows | 8 | positive rows 8 |",
                    "| ratio rows | 8 | chunk-count rows 8, missing/duplicate/unknown cases 0/0/0, healthy `True` |",
                    "| Markdown rows | 8/8 | present `True`, unmatched 0 |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "png_streaming_zlib_bench_markdown_table",
                "PNG streaming zlib benchmark Markdown table",
                dashboard_markdown,
                [
                    "## PNG streaming zlib benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 10 | expected 10, present `True` |",
                    "| shape rows | 10 | positive rows 10 |",
                    "| ratio rows | 10 | image-size rows 10 |",
                    "| chunk counts | 10 | missing/duplicate/unknown cases 0/0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "deflate_dynamic_decode_profile_markdown_table",
                "deflate dynamic decode profile Markdown table",
                dashboard_markdown,
                [
                    "## Deflate dynamic decode profile coverage",
                    "| category | count | detail |",
                    "| rows | 3 | required 3, present `True` |",
                    "| required row checks | 3 | histograms/lookups 3/3 |",
                    "| match class rows | 3 | ratio rows 3 |",
                    "| chunked-window rows | 1 | missing required/duplicate cases 0/0, healthy `True` |",
                ],
            )
        )
        checks.append(
            markdown_check_row(
                "native_library_bench_markdown_table",
                "native library benchmark Markdown table",
                dashboard_markdown,
                [
                    "## Native library benchmark coverage",
                    "| category | count | detail |",
                    "| rows | 93 | expected 93, present `True` |",
                    "| positive rows | 93 | throughput/iteration 93/93 |",
                    "| improvement checks | 46/46 | pair drift 0, duplicate/unknown 0/0, healthy `True` |",
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
                    "| CSV drift checks | 27/27 | artifacts 3/3, unmatched 0, duplicate identities 0 |",
                    "| Markdown drift checks | 26/26 | artifacts 3/3, unmatched 0 |",
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
                    "| report rows | 3/3 | balanced 3, count mismatch 0, duplicate rows 0, duplicate names 0, unbalanced 0 |",
                    "| zero-allocation cases | 2/2 | smoke present `True`, duplicate cases 0 |",
                    "| zero/report drift | 2/2 | unmatched 0 |",
                    "| budget cases | 1/1 | healthy `True`, duplicate cases 0 |",
                    "| budget/report drift | 1/1 | unmatched 0 |",
                    "| smoke classification | 3/3 | overlap 0, missing 0, extra 0 |",
                    "| negative smoke cases | 1/1 | present `True`, duplicate names 0, unmatched 0 |",
                    "| Markdown rows | 3/3 | present `True`, unmatched 0, malformed 0, duplicate 0, unknown 0 |",
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
                    "| report rows | 3/3 | matched 3, count mismatch 0, unmatched 0 |",
                    "| exact error expectations | 2 | mode/error rows 1/2 |",
                    "| summary drift | 0 | mode missing/duplicate/unknown 0/0/0, error missing/duplicate/unknown 0/0/0 |",
                    "| coverage requirements | 3 | matched modes/errors 1/2, unmatched 0 |",
                    "| Markdown rows | 15/15 | present `True`, unmatched 0 |",
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
                    "| candidates | 775 | raw words 143, Markdown 14/14 |",
                    "| candidate sample rows | 1/1 | unmatched 0, present `True` |",
                    "| upstream smoke | 775 | raw words 143, present `True` |",
                    "| upstream report | 775 | raw words 143, upstream words 8, present `True` |",
                    "| upstream Markdown | 14/14 | sample 1/1, unmatched 0, present `True` |",
                    "| node probe | 48/48 | size winners 1, Markdown 13/13 |",
                    "| node rows | 48/48 | unmatched 0, present `True` |",
                    "| source audit | 83 | anchors 83, generated bytes 4096 |",
                    "| negative smoke | 1/1 | rows 1, mismatch 0, unmatched 0, healthy `True` |",
                    "| report entries | 6 | csv 6/6, Markdown 6/6 |",
                    "| report matrix rows | 6/6 | unmatched 0, present `True` |",
                    "| report entry rows | 6/6 | unmatched 0, present `True` |",
                    "| report negative smoke | 1/1 | rows 1, mismatch 0, unmatched 0, report healthy `True` |",
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
                    "| cases | 6 | Adam7 3, healthy `True` |",
                    "| report rows | 6/6 | consistent 6, count mismatch 0, inconsistent 0 |",
                    "| case drift | 0 | duplicate/unknown 0/0 |",
                    "| streaming achieved | 6/6 | fixed/dynamic 6/6 |",
                    "| zlib scratch savings | 615 | zlib scratch 615 |",
                    "| max working scratch | 291 | streaming/fixed-dynamic 80/32848 |",
                    "| min streaming ratio x10000 | 1428 | lower is better |",
                    "| Markdown rows | 6/6 | present `True`, unmatched 0 |",
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
                    "| gate | 11 | 11 | 0 | 0 | 0 | ok `True` |",
                    "| gate/report drift | 11 | 11 | 0 | 0 | 0 | expected checks |",
                    "| gate recompute | 11 | 11 | 0 | 0 | 0 | rule/exact/floor 0/0/0 |",
                    "| Markdown rows | 11 | 11 | 0 | 0 | 0 | present `True`, unknown/value 0/0 |",
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
                    "| positive timing rows | 20 | ratio/throughput 20/20 |",
                    "| repetitive shrunk | 4 | expected modes 4 |",
                    "| framed overhead matches | 5 | expected cases 5 |",
                    "| reusable size/checksum matches | 5/5 | missing/duplicate/unknown pairs 0/0/0, healthy `True` |",
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
                    "| payloads | 3 | inline/large-file/match-heavy/dynamic 2/1/1/1, large overflow 0 |",
                    "| file hex encodes | 3 | expected 3, mismatch 0 |",
                    "| dictionary encodes | 2 | zlib/raw 1/1, dictionary cases 1 |",
                    "| malformed cases | 2 | wrapper/deflate 1/1, expected floor 2 |",
                    "| CLI outcomes | 125 | successes/expected-failures 90/35, shortfalls 0/0/0, exact expected 90/35/125, exact mismatch 0/0/0 |",
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
                    "| report rows | 1/1 | error items 3/3, count mismatch 0 |",
                    "| csv rows | 10 | positive/header 10/10 |",
                    "| csv block types | 8 | fixed/stored 1/1, missing/duplicate/unknown cases 0/0/0 |",
                    "| Markdown rows | 8/8 | present `True`, unmatched 0 |",
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
                    "| report rows | 3/3 | accepted/rejected 1/2, count mismatch 0 |",
                    "| exact error expectations | 2 | mode/error rows 3/2 |",
                    "| summary drift | 0 | mode missing/duplicate/unknown 0/0/0, error missing/duplicate/unknown 0/0/0 |",
                    "| coverage requirements | 5 | matched modes/errors 3/2, unmatched 0 |",
                    "| Markdown rows | 17/17 | present `True`, unmatched 0 |",
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

        mismatched_native_tier_root = root / "mismatched-native-tier-csv"
        mismatched_native_tier_root.mkdir()
        write_healthy_artifacts(mismatched_native_tier_root)
        mismatched_native_tier_payload = json.loads((mismatched_native_tier_root / NATIVE_TIER_RANGE_ARTIFACT).read_text())
        mismatched_native_tier_payload["total_stream_bytes_by_tier"]["seek_fast"] += 1
        (mismatched_native_tier_root / NATIVE_TIER_RANGE_ARTIFACT).write_text(json.dumps(mismatched_native_tier_payload, indent=2, sort_keys=True) + "\n")
        mismatched_native_tier_producer = mismatched_native_tier_root / "producers.json"
        write_producer_map(mismatched_native_tier_producer)
        mismatched_native_tier_result = run(dashboard_args(mismatched_native_tier_root, mismatched_native_tier_producer, "--strict-validation-health"), check=False)
        mismatched_native_tier_manifest = json.loads((mismatched_native_tier_root / "vort-dashboard-index.json").read_text())
        native_tier_mismatched_matched = (
            mismatched_native_tier_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_tier_range_failed" in mismatched_native_tier_result.stdout
            and mismatched_native_tier_manifest["validation_healthy"] is False
            and mismatched_native_tier_manifest["native_tier_range_present"] is True
            and mismatched_native_tier_manifest["native_tier_range_healthy"] is False
            and mismatched_native_tier_manifest["native_tier_range_summary_csv_stream_bytes_mismatch"] == 1
            and mismatched_native_tier_manifest["native_tier_range_summary_csv_mismatch_total"] == 1
        )
        checks.append(check_row("mismatched_native_tier_range_summary_csv", "native-tier-range-health", True, native_tier_mismatched_matched, mismatched_native_tier_result.returncode, "dashboard_index_validation_unhealthy=native_tier_range_failed", mismatched_native_tier_result.stdout))

        mismatched_native_tier_discovery_root = root / "mismatched-native-tier-discovery"
        mismatched_native_tier_discovery_root.mkdir()
        write_healthy_artifacts(mismatched_native_tier_discovery_root)
        mismatched_discovery_payload = json.loads((mismatched_native_tier_discovery_root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT).read_text())
        mismatched_discovery_payload["selected_cases"][0]["bytes"] += 1
        (mismatched_native_tier_discovery_root / NATIVE_TIER_RANGE_CORPUS_DISCOVERY_ARTIFACT).write_text(json.dumps(mismatched_discovery_payload, indent=2, sort_keys=True) + "\n")
        mismatched_native_tier_discovery_producer = mismatched_native_tier_discovery_root / "producers.json"
        write_producer_map(mismatched_native_tier_discovery_producer)
        mismatched_native_tier_discovery_result = run(dashboard_args(mismatched_native_tier_discovery_root, mismatched_native_tier_discovery_producer, "--strict-validation-health"), check=False)
        mismatched_native_tier_discovery_manifest = json.loads((mismatched_native_tier_discovery_root / "vort-dashboard-index.json").read_text())
        native_tier_discovery_mismatched_matched = (
            mismatched_native_tier_discovery_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_tier_corpus_discovery_failed" in mismatched_native_tier_discovery_result.stdout
            and mismatched_native_tier_discovery_manifest["validation_healthy"] is False
            and mismatched_native_tier_discovery_manifest["native_tier_corpus_discovery_present"] is True
            and mismatched_native_tier_discovery_manifest["native_tier_corpus_discovery_healthy"] is False
            and mismatched_native_tier_discovery_manifest["native_tier_corpus_discovery_csv_byte_mismatch"] == 1
            and mismatched_native_tier_discovery_manifest["native_tier_corpus_discovery_mismatch_total"] == 1
        )
        checks.append(check_row("mismatched_native_tier_discovery_case", "native-tier-range-health", True, native_tier_discovery_mismatched_matched, mismatched_native_tier_discovery_result.returncode, "dashboard_index_validation_unhealthy=native_tier_corpus_discovery_failed", mismatched_native_tier_discovery_result.stdout))

        csv_layout_cases = [
            (
                "empty",
                "mismatched_csv_artifact_empty",
                "vort-non-json-csv-empty.csv",
                "csv_artifact_empty",
            ),
            (
                "blank_header",
                "mismatched_csv_artifact_blank_header",
                "vort-non-json-csv-blank-header.csv",
                "csv_artifact_blank_headers",
            ),
            (
                "duplicate_header",
                "mismatched_csv_artifact_duplicate_header",
                "vort-non-json-csv-duplicate-header.csv",
                "csv_artifact_duplicate_headers",
            ),
            (
                "no_data",
                "mismatched_csv_artifact_no_data",
                "vort-non-json-csv-no-data.csv",
                "csv_artifact_no_data_rows",
            ),
            (
                "ragged",
                "mismatched_csv_artifact_ragged_row",
                "vort-non-json-csv-ragged-row.csv",
                "csv_artifact_ragged_rows",
            ),
        ]
        for mutation, check_name, artifact_name, mismatch_field in csv_layout_cases:
            csv_layout_result, csv_layout_manifest = csv_artifact_layout_fixture(
                root,
                f"mismatched-csv-artifact-{mutation.replace('_', '-')}",
                artifact_name,
                mutation,
            )
            csv_layout_matched = (
                csv_layout_result.returncode != 0
                and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in csv_layout_result.stdout
                and csv_layout_manifest["validation_healthy"] is False
                and csv_layout_manifest["non_json_artifact_healthy"] is False
                and csv_layout_manifest[mismatch_field] == [artifact_name]
                and all(
                    csv_layout_manifest[field] == []
                    for field in (
                        "csv_artifact_empty",
                        "csv_artifact_blank_headers",
                        "csv_artifact_duplicate_headers",
                        "csv_artifact_no_data_rows",
                        "csv_artifact_ragged_rows",
                    )
                    if field != mismatch_field
                )
                and csv_layout_manifest["csv_header_missing"] == []
                and csv_layout_manifest["csv_header_unknown"] == []
                and csv_layout_manifest["csv_header_column_mismatch"] == []
                and csv_layout_manifest["csv_header_signature_mismatch"] == []
            )
            checks.append(
                check_row(
                    check_name,
                    "non-json-artifact-health",
                    True,
                    csv_layout_matched,
                    csv_layout_result.returncode,
                    "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                    csv_layout_result.stdout,
                )
            )

        markdown_layout_cases = [
            (
                "empty",
                "mismatched_markdown_artifact_empty",
                "vort-non-json-markdown-empty.md",
                {"markdown_artifact_empty"},
            ),
            (
                "marker_missing",
                "mismatched_markdown_artifact_marker_missing",
                "vort-non-json-markdown-marker-missing.md",
                {
                    "markdown_artifact_marker_missing",
                    "markdown_artifact_heading_missing",
                    "markdown_artifact_table_missing",
                },
            ),
            (
                "heading_missing",
                "mismatched_markdown_artifact_heading_missing",
                "vort-non-json-markdown-heading-missing.md",
                {"markdown_artifact_heading_missing"},
            ),
            (
                "heading_not_first",
                "mismatched_markdown_artifact_heading_not_first",
                "vort-non-json-markdown-heading-not-first.md",
                {"markdown_artifact_heading_not_first"},
            ),
            (
                "table_missing",
                "mismatched_markdown_artifact_table_missing",
                "vort-non-json-markdown-table-missing.md",
                {"markdown_artifact_table_missing"},
            ),
            (
                "table_separator_missing",
                "mismatched_markdown_artifact_table_separator_missing",
                "vort-non-json-markdown-table-separator-missing.md",
                {"markdown_artifact_table_separator_missing"},
            ),
        ]
        markdown_layout_fields = {
            "markdown_artifact_empty",
            "markdown_artifact_marker_missing",
            "markdown_artifact_heading_missing",
            "markdown_artifact_heading_not_first",
            "markdown_artifact_table_missing",
            "markdown_artifact_table_separator_missing",
        }
        for mutation, check_name, artifact_name, expected_fields in markdown_layout_cases:
            markdown_layout_result, markdown_layout_manifest = markdown_artifact_layout_fixture(
                root,
                f"mismatched-markdown-artifact-{mutation.replace('_', '-')}",
                artifact_name,
                mutation,
            )
            markdown_layout_matched = (
                markdown_layout_result.returncode != 0
                and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in markdown_layout_result.stdout
                and markdown_layout_manifest["validation_healthy"] is False
                and markdown_layout_manifest["non_json_artifact_healthy"] is False
                and all(markdown_layout_manifest[field] == [artifact_name] for field in expected_fields)
                and all(markdown_layout_manifest[field] == [] for field in markdown_layout_fields - expected_fields)
                and markdown_layout_manifest["markdown_heading_manifest_missing"] == []
                and markdown_layout_manifest["markdown_heading_manifest_unknown"] == []
                and markdown_layout_manifest["markdown_heading_count_mismatch"] == []
                and markdown_layout_manifest["markdown_first_heading_mismatch"] == []
                and markdown_layout_manifest["markdown_heading_signature_mismatch"] == []
                and markdown_layout_manifest["markdown_table_count_mismatch"] == []
                and markdown_layout_manifest["markdown_table_separator_count_mismatch"] == []
            )
            checks.append(
                check_row(
                    check_name,
                    "non-json-artifact-health",
                    True,
                    markdown_layout_matched,
                    markdown_layout_result.returncode,
                    "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                    markdown_layout_result.stdout,
                )
            )

        csv_manifest_membership_cases = [
            (
                "missing",
                "mismatched_csv_header_manifest_missing",
                "vort-non-json-csv-manifest-missing.csv",
                "csv_header_missing",
            ),
            (
                "unknown",
                "mismatched_csv_header_manifest_unknown",
                "vort-non-json-csv-manifest-unknown.csv",
                "csv_header_unknown",
            ),
        ]
        for mutation, check_name, artifact_name, mismatch_field in csv_manifest_membership_cases:
            csv_membership_result, csv_membership_manifest = csv_manifest_membership_fixture(
                root,
                f"mismatched-csv-header-manifest-{mutation}",
                artifact_name,
                mutation,
            )
            csv_membership_matched = (
                csv_membership_result.returncode != 0
                and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in csv_membership_result.stdout
                and csv_membership_manifest["validation_healthy"] is False
                and csv_membership_manifest["non_json_artifact_healthy"] is False
                and csv_membership_manifest[mismatch_field] == [artifact_name]
                and all(
                    csv_membership_manifest[field] == []
                    for field in (
                        "csv_header_missing",
                        "csv_header_unknown",
                        "csv_header_column_mismatch",
                        "csv_header_signature_mismatch",
                    )
                    if field != mismatch_field
                )
            )
            checks.append(
                check_row(
                    check_name,
                    "non-json-artifact-health",
                    True,
                    csv_membership_matched,
                    csv_membership_result.returncode,
                    "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                    csv_membership_result.stdout,
                )
            )

        csv_header_column_result, csv_header_column_manifest_result = csv_manifest_drift_fixture(
            root,
            "mismatched-csv-header-column",
            LEVEL_REPORT_CSV_ARTIFACT,
            "column_count",
        )
        csv_header_column_matched = (
            csv_header_column_result.returncode != 0
            and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in csv_header_column_result.stdout
            and csv_header_column_manifest_result["validation_healthy"] is False
            and csv_header_column_manifest_result["non_json_artifact_healthy"] is False
            and csv_header_column_manifest_result["csv_header_column_mismatch"] == [LEVEL_REPORT_CSV_ARTIFACT]
            and csv_header_column_manifest_result["csv_header_signature_mismatch"] == []
        )
        checks.append(
            check_row(
                "mismatched_csv_header_column_manifest",
                "non-json-artifact-health",
                True,
                csv_header_column_matched,
                csv_header_column_result.returncode,
                "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                csv_header_column_result.stdout,
            )
        )

        csv_header_signature_result, csv_header_signature_manifest_result = csv_manifest_drift_fixture(
            root,
            "mismatched-csv-header-signature",
            LEVEL_REPORT_CSV_ARTIFACT,
            "signature",
        )
        csv_header_signature_matched = (
            csv_header_signature_result.returncode != 0
            and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in csv_header_signature_result.stdout
            and csv_header_signature_manifest_result["validation_healthy"] is False
            and csv_header_signature_manifest_result["non_json_artifact_healthy"] is False
            and csv_header_signature_manifest_result["csv_header_column_mismatch"] == []
            and csv_header_signature_manifest_result["csv_header_signature_mismatch"] == [LEVEL_REPORT_CSV_ARTIFACT]
        )
        checks.append(
            check_row(
                "mismatched_csv_header_signature_manifest",
                "non-json-artifact-health",
                True,
                csv_header_signature_matched,
                csv_header_signature_result.returncode,
                "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                csv_header_signature_result.stdout,
            )
        )

        markdown_manifest_membership_cases = [
            (
                "missing",
                "mismatched_markdown_heading_manifest_missing",
                "vort-non-json-markdown-manifest-missing.md",
                "markdown_heading_manifest_missing",
            ),
            (
                "unknown",
                "mismatched_markdown_heading_manifest_unknown",
                "vort-non-json-markdown-manifest-unknown.md",
                "markdown_heading_manifest_unknown",
            ),
        ]
        for mutation, check_name, artifact_name, mismatch_field in markdown_manifest_membership_cases:
            markdown_membership_result, markdown_membership_manifest = markdown_manifest_membership_fixture(
                root,
                f"mismatched-markdown-heading-manifest-{mutation}",
                artifact_name,
                mutation,
            )
            markdown_membership_matched = (
                markdown_membership_result.returncode != 0
                and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in markdown_membership_result.stdout
                and markdown_membership_manifest["validation_healthy"] is False
                and markdown_membership_manifest["non_json_artifact_healthy"] is False
                and markdown_membership_manifest[mismatch_field] == [artifact_name]
                and all(
                    markdown_membership_manifest[field] == []
                    for field in (
                        "markdown_heading_manifest_missing",
                        "markdown_heading_manifest_unknown",
                        "markdown_heading_count_mismatch",
                        "markdown_first_heading_mismatch",
                        "markdown_heading_signature_mismatch",
                        "markdown_table_count_mismatch",
                        "markdown_table_separator_count_mismatch",
                    )
                    if field != mismatch_field
                )
            )
            checks.append(
                check_row(
                    check_name,
                    "non-json-artifact-health",
                    True,
                    markdown_membership_matched,
                    markdown_membership_result.returncode,
                    "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                    markdown_membership_result.stdout,
                )
            )

        markdown_heading_drift_cases = [
            (
                "heading_count",
                "mismatched_markdown_heading_count_manifest",
                "markdown_heading_count_mismatch",
            ),
            (
                "first_heading",
                "mismatched_markdown_first_heading_manifest",
                "markdown_first_heading_mismatch",
            ),
            (
                "signature",
                "mismatched_markdown_heading_signature_manifest",
                "markdown_heading_signature_mismatch",
            ),
        ]
        for manifest_field, check_name, mismatch_field in markdown_heading_drift_cases:
            markdown_heading_result, markdown_heading_manifest = markdown_manifest_drift_fixture(
                root,
                f"mismatched-markdown-heading-{manifest_field.replace('_', '-')}",
                LEVEL_REPORT_MARKDOWN_ARTIFACT,
                manifest_field,
            )
            markdown_heading_matched = (
                markdown_heading_result.returncode != 0
                and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in markdown_heading_result.stdout
                and markdown_heading_manifest["validation_healthy"] is False
                and markdown_heading_manifest["non_json_artifact_healthy"] is False
                and markdown_heading_manifest[mismatch_field] == [LEVEL_REPORT_MARKDOWN_ARTIFACT]
                and all(
                    markdown_heading_manifest[field] == []
                    for field in (
                        "markdown_heading_manifest_missing",
                        "markdown_heading_manifest_unknown",
                        "markdown_heading_count_mismatch",
                        "markdown_first_heading_mismatch",
                        "markdown_heading_signature_mismatch",
                        "markdown_table_count_mismatch",
                        "markdown_table_separator_count_mismatch",
                    )
                    if field != mismatch_field
                )
            )
            checks.append(
                check_row(
                    check_name,
                    "non-json-artifact-health",
                    True,
                    markdown_heading_matched,
                    markdown_heading_result.returncode,
                    "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                    markdown_heading_result.stdout,
                )
            )

        markdown_table_count_result, markdown_table_count_manifest_result = markdown_manifest_drift_fixture(
            root,
            "mismatched-markdown-table-count",
            LEVEL_REPORT_MARKDOWN_ARTIFACT,
            "table_row_count",
        )
        markdown_table_count_matched = (
            markdown_table_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in markdown_table_count_result.stdout
            and markdown_table_count_manifest_result["validation_healthy"] is False
            and markdown_table_count_manifest_result["non_json_artifact_healthy"] is False
            and markdown_table_count_manifest_result["markdown_table_count_mismatch"] == [LEVEL_REPORT_MARKDOWN_ARTIFACT]
            and markdown_table_count_manifest_result["markdown_table_separator_count_mismatch"] == []
        )
        checks.append(
            check_row(
                "mismatched_markdown_table_count_manifest",
                "non-json-artifact-health",
                True,
                markdown_table_count_matched,
                markdown_table_count_result.returncode,
                "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                markdown_table_count_result.stdout,
            )
        )

        markdown_separator_count_result, markdown_separator_count_manifest_result = markdown_manifest_drift_fixture(
            root,
            "mismatched-markdown-separator-count",
            LEVEL_REPORT_MARKDOWN_ARTIFACT,
            "table_separator_count",
        )
        markdown_separator_count_matched = (
            markdown_separator_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=non_json_artifact_failed" in markdown_separator_count_result.stdout
            and markdown_separator_count_manifest_result["validation_healthy"] is False
            and markdown_separator_count_manifest_result["non_json_artifact_healthy"] is False
            and markdown_separator_count_manifest_result["markdown_table_count_mismatch"] == []
            and markdown_separator_count_manifest_result["markdown_table_separator_count_mismatch"] == [LEVEL_REPORT_MARKDOWN_ARTIFACT]
        )
        checks.append(
            check_row(
                "mismatched_markdown_table_separator_manifest",
                "non-json-artifact-health",
                True,
                markdown_separator_count_matched,
                markdown_separator_count_result.returncode,
                "dashboard_index_validation_unhealthy=non_json_artifact_failed",
                markdown_separator_count_result.stdout,
            )
        )

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

        header_report_count_result, header_report_count_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-report-count-mismatch",
            lambda payload: payload.__setitem__("case_count", int(payload["case_count"]) + 1),
        )
        header_report_count_matched = (
            header_report_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_report_count_result.stdout
            and header_report_count_manifest["validation_healthy"] is False
            and header_report_count_manifest["header_inspect_healthy"] is False
            and header_report_count_manifest["header_inspect_report_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_report_count_mismatch",
                "strict-validation-health",
                True,
                header_report_count_matched,
                header_report_count_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_report_count_result.stdout,
            )
        )

        header_duplicate_case_result, header_duplicate_case_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-case",
            lambda payload: payload["cases"].append(dict(payload["cases"][0])),
        )
        header_duplicate_case_matched = (
            header_duplicate_case_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_case_result.stdout
            and header_duplicate_case_manifest["validation_healthy"] is False
            and header_duplicate_case_manifest["header_inspect_healthy"] is False
            and header_duplicate_case_manifest["header_inspect_duplicate_case_names"] == ["raw_fixed"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_case",
                "strict-validation-health",
                True,
                header_duplicate_case_matched,
                header_duplicate_case_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_case_result.stdout,
            )
        )

        header_markdown_unmatched_result, header_markdown_unmatched_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-markdown-unmatched",
            lambda payload: None,
            lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("## Command coverage", "## Cmd coverage drift", 1)
            ),
        )
        header_markdown_unmatched_matched = (
            header_markdown_unmatched_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_markdown_unmatched_result.stdout
            and header_markdown_unmatched_manifest["validation_healthy"] is False
            and header_markdown_unmatched_manifest["header_inspect_healthy"] is False
            and header_markdown_unmatched_manifest["header_inspect_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_markdown_unmatched",
                "strict-validation-health",
                True,
                header_markdown_unmatched_matched,
                header_markdown_unmatched_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_markdown_unmatched_result.stdout,
            )
        )

        header_command_missing_result, header_command_missing_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-command-coverage-missing",
            lambda payload: payload.__setitem__(
                "command_coverage",
                [row for row in payload["command_coverage"] if row.get("command") != "inspect-raw-header-file"],
            ),
        )
        header_command_missing_matched = (
            header_command_missing_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_command_missing_result.stdout
            and header_command_missing_manifest["validation_healthy"] is False
            and header_command_missing_manifest["header_inspect_healthy"] is False
            and header_command_missing_manifest["header_inspect_command_coverage_missing_rows"] == ["inspect-raw-header-file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_command_coverage_missing",
                "strict-validation-health",
                True,
                header_command_missing_matched,
                header_command_missing_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_command_missing_result.stdout,
            )
        )

        header_command_unknown_result, header_command_unknown_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-command-coverage-unknown",
            lambda payload: payload["command_coverage"].append(
                {"command": "inspect-extra-header-file", "format": "raw", "successes": 0, "failures": 0}
            ),
        )
        header_command_unknown_matched = (
            header_command_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_command_unknown_result.stdout
            and header_command_unknown_manifest["validation_healthy"] is False
            and header_command_unknown_manifest["header_inspect_healthy"] is False
            and header_command_unknown_manifest["header_inspect_command_coverage_unknown_rows"] == ["inspect-extra-header-file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_command_coverage_unknown",
                "strict-validation-health",
                True,
                header_command_unknown_matched,
                header_command_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_command_unknown_result.stdout,
            )
        )

        header_command_mismatch_result, header_command_mismatch_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-command-coverage-mismatch",
            lambda payload: payload["command_coverage"][0].__setitem__(
                "successes",
                int(payload["command_coverage"][0]["successes"]) + 1,
            ),
        )
        header_command_mismatch_matched = (
            header_command_mismatch_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_command_mismatch_result.stdout
            and header_command_mismatch_manifest["validation_healthy"] is False
            and header_command_mismatch_manifest["header_inspect_healthy"] is False
            and header_command_mismatch_manifest["header_inspect_command_coverage_mismatch"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_command_coverage_mismatch",
                "strict-validation-health",
                True,
                header_command_mismatch_matched,
                header_command_mismatch_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_command_mismatch_result.stdout,
            )
        )

        header_error_count_result, header_error_count_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-negative-error-count-mismatch",
            lambda payload: payload["negative_error_counts"].__setitem__(
                "BadZlibHeader",
                int(payload["negative_error_counts"]["BadZlibHeader"]) + 1,
            ),
        )
        header_error_count_matched = (
            header_error_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_error_count_result.stdout
            and header_error_count_manifest["validation_healthy"] is False
            and header_error_count_manifest["header_inspect_healthy"] is False
            and header_error_count_manifest["header_inspect_negative_error_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_negative_error_count_mismatch",
                "strict-validation-health",
                True,
                header_error_count_matched,
                header_error_count_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_error_count_result.stdout,
            )
        )

        header_help_workflow_result, header_help_workflow_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-help-required-workflow-mismatch",
            lambda payload: payload.__setitem__("help_workflows", []),
        )
        header_help_workflow_matched = (
            header_help_workflow_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_help_workflow_result.stdout
            and header_help_workflow_manifest["validation_healthy"] is False
            and header_help_workflow_manifest["header_inspect_healthy"] is False
            and header_help_workflow_manifest["header_inspect_help_required_workflow_mismatch"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_help_required_workflow_mismatch",
                "strict-validation-health",
                True,
                header_help_workflow_matched,
                header_help_workflow_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_help_workflow_result.stdout,
            )
        )

        header_duplicate_negative_result, header_duplicate_negative_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-negative",
            lambda payload: payload["negative_items"].append(dict(payload["negative_items"][0])),
        )
        header_duplicate_negative_matched = (
            header_duplicate_negative_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_negative_result.stdout
            and header_duplicate_negative_manifest["validation_healthy"] is False
            and header_duplicate_negative_manifest["header_inspect_healthy"] is False
            and header_duplicate_negative_manifest["header_inspect_duplicate_negative_names"] == ["raw_reserved_btype"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_negative",
                "strict-validation-health",
                True,
                header_duplicate_negative_matched,
                header_duplicate_negative_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_negative_result.stdout,
            )
        )

        header_duplicate_command_result, header_duplicate_command_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-command",
            lambda payload: payload["command_coverage"].append(dict(payload["command_coverage"][0])),
        )
        header_duplicate_command_matched = (
            header_duplicate_command_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_command_result.stdout
            and header_duplicate_command_manifest["validation_healthy"] is False
            and header_duplicate_command_manifest["header_inspect_healthy"] is False
            and header_duplicate_command_manifest["header_inspect_duplicate_command_coverage_rows"] == ["inspect-raw-header-file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_command_coverage",
                "strict-validation-health",
                True,
                header_duplicate_command_matched,
                header_duplicate_command_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_command_result.stdout,
            )
        )

        header_duplicate_workflow_result, header_duplicate_workflow_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-workflow",
            lambda payload: payload["workflow_coverage"].append(dict(payload["workflow_coverage"][0])),
        )
        header_duplicate_workflow_matched = (
            header_duplicate_workflow_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_workflow_result.stdout
            and header_duplicate_workflow_manifest["validation_healthy"] is False
            and header_duplicate_workflow_manifest["header_inspect_healthy"] is False
            and header_duplicate_workflow_manifest["header_inspect_duplicate_workflow_coverage_rows"] == ["inspect-raw-header-file:file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_workflow_coverage",
                "strict-validation-health",
                True,
                header_duplicate_workflow_matched,
                header_duplicate_workflow_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_workflow_result.stdout,
            )
        )

        header_duplicate_required_result, header_duplicate_required_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-required-workflow",
            lambda payload: payload["required_workflows"].append(dict(payload["required_workflows"][0])),
        )
        header_duplicate_required_matched = (
            header_duplicate_required_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_required_result.stdout
            and header_duplicate_required_manifest["validation_healthy"] is False
            and header_duplicate_required_manifest["header_inspect_healthy"] is False
            and header_duplicate_required_manifest["header_inspect_duplicate_required_workflow_rows"] == ["inspect-raw-header-file:file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_required_workflow",
                "strict-validation-health",
                True,
                header_duplicate_required_matched,
                header_duplicate_required_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_required_result.stdout,
            )
        )

        header_duplicate_help_result, header_duplicate_help_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-duplicate-help-workflow",
            lambda payload: payload["help_workflows"].append(dict(payload["help_workflows"][0])),
        )
        header_duplicate_help_matched = (
            header_duplicate_help_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_duplicate_help_result.stdout
            and header_duplicate_help_manifest["validation_healthy"] is False
            and header_duplicate_help_manifest["header_inspect_healthy"] is False
            and header_duplicate_help_manifest["header_inspect_duplicate_help_workflow_rows"] == ["inspect-raw-header-file:file:raw"]
        )
        checks.append(
            check_row(
                "header_inspect_duplicate_help_workflow",
                "strict-validation-health",
                True,
                header_duplicate_help_matched,
                header_duplicate_help_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_duplicate_help_result.stdout,
            )
        )

        header_missing_workflow_drift_result, header_missing_workflow_drift_manifest = header_inspect_drift_fixture(
            root,
            "header-inspect-missing-workflow-drift",
            lambda payload: payload["missing_workflows"].append(
                {"command": "inspect-raw-header-file", "workflow": "file", "format": "raw"}
            ),
        )
        header_missing_workflow_drift_matched = (
            header_missing_workflow_drift_result.returncode != 0
            and "dashboard_index_validation_unhealthy=header_inspect_undercovered" in header_missing_workflow_drift_result.stdout
            and header_missing_workflow_drift_manifest["validation_healthy"] is False
            and header_missing_workflow_drift_manifest["header_inspect_healthy"] is False
            and header_missing_workflow_drift_manifest["header_inspect_missing_workflow_count"] == 0
            and header_missing_workflow_drift_manifest["header_inspect_missing_workflow_drift"] == 1
        )
        checks.append(
            check_row(
                "header_inspect_missing_workflow_drift",
                "strict-validation-health",
                True,
                header_missing_workflow_drift_matched,
                header_missing_workflow_drift_result.returncode,
                "dashboard_index_validation_unhealthy=header_inspect_undercovered",
                header_missing_workflow_drift_result.stdout,
            )
        )

        sidecar_item_malformed_result, sidecar_item_malformed_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-item-malformed",
            lambda payload: payload["items"][0].__setitem__("metadata_ok", "true"),
        )
        sidecar_item_malformed_matched = (
            sidecar_item_malformed_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_item_malformed_result.stdout
            and sidecar_item_malformed_manifest["validation_healthy"] is False
            and sidecar_item_malformed_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_item_malformed_manifest["sidecar_corrupt_item_malformed_rows"] == 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_item_malformed",
                "strict-validation-health",
                True,
                sidecar_item_malformed_matched,
                sidecar_item_malformed_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_item_malformed_result.stdout,
            )
        )

        sidecar_item_duplicate_result, sidecar_item_duplicate_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-item-duplicate",
            lambda payload: payload["items"].append(dict(payload["items"][0])),
        )
        sidecar_item_duplicate_matched = (
            sidecar_item_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_item_duplicate_result.stdout
            and sidecar_item_duplicate_manifest["validation_healthy"] is False
            and sidecar_item_duplicate_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_item_duplicate_manifest["sidecar_corrupt_item_duplicate_cases"] == ["deflate"]
        )
        checks.append(
            check_row(
                "sidecar_corrupt_item_duplicate",
                "strict-validation-health",
                True,
                sidecar_item_duplicate_matched,
                sidecar_item_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_item_duplicate_result.stdout,
            )
        )

        sidecar_markdown_unmatched_result, sidecar_markdown_unmatched_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-markdown-unmatched",
            mutate_markdown=lambda path: path.write_text(path.read_text().replace("InvalidMatch", "InvalidMatchDrift", 1)),
        )
        sidecar_markdown_unmatched_matched = (
            sidecar_markdown_unmatched_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_markdown_unmatched_result.stdout
            and sidecar_markdown_unmatched_manifest["validation_healthy"] is False
            and sidecar_markdown_unmatched_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_markdown_unmatched_manifest["sidecar_corrupt_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_markdown_unmatched",
                "strict-validation-health",
                True,
                sidecar_markdown_unmatched_matched,
                sidecar_markdown_unmatched_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_markdown_unmatched_result.stdout,
            )
        )

        sidecar_markdown_malformed_result, sidecar_markdown_malformed_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-markdown-malformed",
            mutate_markdown=lambda path: path.write_text(path.read_text().replace("44 | 48", "NaN | 48", 1)),
        )
        sidecar_markdown_malformed_matched = (
            sidecar_markdown_malformed_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_markdown_malformed_result.stdout
            and sidecar_markdown_malformed_manifest["validation_healthy"] is False
            and sidecar_markdown_malformed_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_markdown_malformed_manifest["sidecar_corrupt_markdown_malformed_rows"] == 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_markdown_malformed",
                "strict-validation-health",
                True,
                sidecar_markdown_malformed_matched,
                sidecar_markdown_malformed_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_markdown_malformed_result.stdout,
            )
        )

        sidecar_markdown_duplicate_result, sidecar_markdown_duplicate_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-markdown-duplicate",
            mutate_markdown=lambda path: path.write_text(
                path.read_text().replace(
                    "| deflate | true | true | TruncatedFrame | 44 | 48 |\n",
                    "| deflate | true | true | TruncatedFrame | 44 | 48 |\n| deflate | true | true | TruncatedFrame | 44 | 48 |\n",
                    1,
                )
            ),
        )
        sidecar_markdown_duplicate_matched = (
            sidecar_markdown_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_markdown_duplicate_result.stdout
            and sidecar_markdown_duplicate_manifest["validation_healthy"] is False
            and sidecar_markdown_duplicate_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_markdown_duplicate_manifest["sidecar_corrupt_markdown_duplicate_cases"] == ["deflate"]
        )
        checks.append(
            check_row(
                "sidecar_corrupt_markdown_duplicate",
                "strict-validation-health",
                True,
                sidecar_markdown_duplicate_matched,
                sidecar_markdown_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_markdown_duplicate_result.stdout,
            )
        )

        sidecar_markdown_unknown_result, sidecar_markdown_unknown_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-markdown-unknown",
            mutate_markdown=lambda path: path.write_text(
                path.read_text() + "| extra | true | true | ExtraError | 1 | 2 |\n"
            ),
        )
        sidecar_markdown_unknown_matched = (
            sidecar_markdown_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_markdown_unknown_result.stdout
            and sidecar_markdown_unknown_manifest["validation_healthy"] is False
            and sidecar_markdown_unknown_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_markdown_unknown_manifest["sidecar_corrupt_markdown_unknown_cases"] == ["extra"]
        )
        checks.append(
            check_row(
                "sidecar_corrupt_markdown_unknown",
                "strict-validation-health",
                True,
                sidecar_markdown_unknown_matched,
                sidecar_markdown_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_markdown_unknown_result.stdout,
            )
        )

        sidecar_metadata_count_result, sidecar_metadata_count_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-metadata-count",
            lambda payload: payload.__setitem__("metadata_ok_rows", int(payload["metadata_ok_rows"]) - 1),
        )
        sidecar_metadata_count_matched = (
            sidecar_metadata_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_metadata_count_result.stdout
            and sidecar_metadata_count_manifest["validation_healthy"] is False
            and sidecar_metadata_count_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_metadata_count_manifest["sidecar_corrupt_metadata_failed_rows"] == 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_metadata_failed_count",
                "strict-validation-health",
                True,
                sidecar_metadata_count_matched,
                sidecar_metadata_count_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_metadata_count_result.stdout,
            )
        )

        sidecar_full_rejected_count_result, sidecar_full_rejected_count_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-full-rejected-count",
            lambda payload: payload.__setitem__("full_rejected_rows", int(payload["full_rejected_rows"]) - 1),
        )
        sidecar_full_rejected_count_matched = (
            sidecar_full_rejected_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_full_rejected_count_result.stdout
            and sidecar_full_rejected_count_manifest["validation_healthy"] is False
            and sidecar_full_rejected_count_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_full_rejected_count_manifest["sidecar_corrupt_full_not_rejected_rows"] == 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_full_not_rejected_count",
                "strict-validation-health",
                True,
                sidecar_full_rejected_count_matched,
                sidecar_full_rejected_count_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_full_rejected_count_result.stdout,
            )
        )

        sidecar_item_count_result, sidecar_item_count_manifest = sidecar_corrupt_drift_fixture(
            root,
            "sidecar-corrupt-item-count",
            lambda payload: payload.__setitem__("rows", int(payload["rows"]) + 1),
        )
        sidecar_item_count_matched = (
            sidecar_item_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=sidecar_corrupt_failed" in sidecar_item_count_result.stdout
            and sidecar_item_count_manifest["validation_healthy"] is False
            and sidecar_item_count_manifest["sidecar_corrupt_healthy"] is False
            and sidecar_item_count_manifest["sidecar_corrupt_item_count_mismatch"] >= 1
        )
        checks.append(
            check_row(
                "sidecar_corrupt_item_count_mismatch",
                "strict-validation-health",
                True,
                sidecar_item_count_matched,
                sidecar_item_count_result.returncode,
                "dashboard_index_validation_unhealthy=sidecar_corrupt_failed",
                sidecar_item_count_result.stdout,
            )
        )

        huffman_malformed_result, huffman_malformed_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-malformed",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__("gap_bits", "bad"),
        )
        huffman_malformed_matched = (
            huffman_malformed_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_malformed_result.stdout
            and huffman_malformed_manifest["validation_healthy"] is False
            and huffman_malformed_manifest["huffman_length_healthy"] is False
            and huffman_malformed_manifest["huffman_length_malformed_rows"] == 1
        )
        checks.append(
            check_row(
                "huffman_length_malformed_row",
                "strict-validation-health",
                True,
                huffman_malformed_matched,
                huffman_malformed_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_malformed_result.stdout,
            )
        )

        huffman_blank_case_result, huffman_blank_case_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-blank-case",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__("case", ""),
        )
        huffman_blank_case_matched = (
            huffman_blank_case_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_blank_case_result.stdout
            and huffman_blank_case_manifest["validation_healthy"] is False
            and huffman_blank_case_manifest["huffman_length_healthy"] is False
            and huffman_blank_case_manifest["huffman_length_blank_case_rows"] == 1
        )
        checks.append(
            check_row(
                "huffman_length_blank_case",
                "strict-validation-health",
                True,
                huffman_blank_case_matched,
                huffman_blank_case_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_blank_case_result.stdout,
            )
        )

        huffman_duplicate_result, huffman_duplicate_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-duplicate-case",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows.append(dict(rows[0])),
        )
        huffman_duplicate_matched = (
            huffman_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_duplicate_result.stdout
            and huffman_duplicate_manifest["validation_healthy"] is False
            and huffman_duplicate_manifest["huffman_length_healthy"] is False
            and huffman_duplicate_manifest["huffman_length_duplicate_cases"] == ["strict-smoke"]
        )
        checks.append(
            check_row(
                "huffman_length_duplicate_case",
                "strict-validation-health",
                True,
                huffman_duplicate_matched,
                huffman_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_duplicate_result.stdout,
            )
        )

        def make_huffman_non_optimal(rows: list[dict[str, str]], fieldnames: list[str], csv_path: Path, markdown_path: Path) -> None:
            rows[0].update({
                "actual_cost": "6",
                "gap_bits": "1",
                "optimal": "false",
                "lengths": "2;2;2",
                "package_merge_cost": "6",
                "package_merge_gap_bits": "1",
                "package_merge_optimal": "false",
                "package_merge_lengths": "2;2;2",
            })
            write_huffman_length_markdown(
                markdown_path,
                optimal_rows=0,
                non_optimal_rows=1,
                worst_gap_bits=1,
                package_merge_optimal_rows=0,
                package_merge_non_optimal_rows=1,
                package_merge_worst_gap_bits=1,
            )

        huffman_non_optimal_result, huffman_non_optimal_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-non-optimal",
            mutate_csv=make_huffman_non_optimal,
        )
        huffman_non_optimal_matched = (
            huffman_non_optimal_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_non_optimal_result.stdout
            and huffman_non_optimal_manifest["validation_healthy"] is False
            and huffman_non_optimal_manifest["huffman_length_healthy"] is False
            and huffman_non_optimal_manifest["huffman_length_non_optimal_rows"] == 1
            and huffman_non_optimal_manifest["huffman_length_package_merge_non_optimal_rows"] == 1
        )
        checks.append(
            check_row(
                "huffman_length_non_optimal_row",
                "strict-validation-health",
                True,
                huffman_non_optimal_matched,
                huffman_non_optimal_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_non_optimal_result.stdout,
            )
        )

        huffman_markdown_summary_result, huffman_markdown_summary_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-markdown-summary",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("- rows: 1", "- rows: 2", 1)
            ),
        )
        huffman_markdown_summary_matched = (
            huffman_markdown_summary_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_markdown_summary_result.stdout
            and huffman_markdown_summary_manifest["validation_healthy"] is False
            and huffman_markdown_summary_manifest["huffman_length_healthy"] is False
            and huffman_markdown_summary_manifest["huffman_length_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "huffman_length_markdown_summary_unmatched",
                "strict-validation-health",
                True,
                huffman_markdown_summary_matched,
                huffman_markdown_summary_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_markdown_summary_result.stdout,
            )
        )

        huffman_markdown_case_result, huffman_markdown_case_manifest = huffman_length_drift_fixture(
            root,
            "huffman-length-markdown-case",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("| strict-smoke |", "| strict-smoke-drift |", 1)
            ),
        )
        huffman_markdown_case_matched = (
            huffman_markdown_case_result.returncode != 0
            and "dashboard_index_validation_unhealthy=huffman_length_failed" in huffman_markdown_case_result.stdout
            and huffman_markdown_case_manifest["validation_healthy"] is False
            and huffman_markdown_case_manifest["huffman_length_healthy"] is False
            and huffman_markdown_case_manifest["huffman_length_markdown_case_unmatched"] == 1
        )
        checks.append(
            check_row(
                "huffman_length_markdown_case_unmatched",
                "strict-validation-health",
                True,
                huffman_markdown_case_matched,
                huffman_markdown_case_result.returncode,
                "dashboard_index_validation_unhealthy=huffman_length_failed",
                huffman_markdown_case_result.stdout,
            )
        )

        level_missing_result, level_missing_manifest = level_report_drift_fixture(
            root,
            "level-report-missing-pair",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows.pop(),
        )
        level_missing_matched = (
            level_missing_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_missing_result.stdout
            and level_missing_manifest["validation_healthy"] is False
            and level_missing_manifest["level_report_healthy"] is False
            and level_missing_manifest["level_report_missing_pairs"] == ["repeated/best/rle"]
        )
        checks.append(
            check_row(
                "level_report_missing_pair",
                "strict-validation-health",
                True,
                level_missing_matched,
                level_missing_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_missing_result.stdout,
            )
        )

        level_duplicate_result, level_duplicate_manifest = level_report_drift_fixture(
            root,
            "level-report-duplicate-pair",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows.append(dict(rows[0])),
        )
        level_duplicate_matched = (
            level_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_duplicate_result.stdout
            and level_duplicate_manifest["validation_healthy"] is False
            and level_duplicate_manifest["level_report_healthy"] is False
            and level_duplicate_manifest["level_report_duplicate_pairs"] == ["text/fastest/default"]
        )
        checks.append(
            check_row(
                "level_report_duplicate_pair",
                "strict-validation-health",
                True,
                level_duplicate_matched,
                level_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_duplicate_result.stdout,
            )
        )

        level_unknown_result, level_unknown_manifest = level_report_drift_fixture(
            root,
            "level-report-unknown-pair",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__("case", "unknown"),
        )
        level_unknown_matched = (
            level_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_unknown_result.stdout
            and level_unknown_manifest["validation_healthy"] is False
            and level_unknown_manifest["level_report_healthy"] is False
            and level_unknown_manifest["level_report_unknown_pairs"] == ["unknown/fastest/default"]
        )
        checks.append(
            check_row(
                "level_report_unknown_pair",
                "strict-validation-health",
                True,
                level_unknown_matched,
                level_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_unknown_result.stdout,
            )
        )

        level_token_result, level_token_manifest = level_report_drift_fixture(
            root,
            "level-report-token-accounting",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__(
                "tokens",
                str(int(rows[0]["tokens"]) + 1),
            ),
        )
        level_token_matched = (
            level_token_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_token_result.stdout
            and level_token_manifest["validation_healthy"] is False
            and level_token_manifest["level_report_healthy"] is False
            and level_token_manifest["level_report_token_accounting_rows"] == 47
        )
        checks.append(
            check_row(
                "level_report_token_accounting_mismatch",
                "strict-validation-health",
                True,
                level_token_matched,
                level_token_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_token_result.stdout,
            )
        )

        level_ratio_result, level_ratio_manifest = level_report_drift_fixture(
            root,
            "level-report-ratio",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__(
                "raw_best_ratio_x10000",
                str(int(rows[0]["raw_best_ratio_x10000"]) + 1),
            ),
        )
        level_ratio_matched = (
            level_ratio_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_ratio_result.stdout
            and level_ratio_manifest["validation_healthy"] is False
            and level_ratio_manifest["level_report_healthy"] is False
            and level_ratio_manifest["level_report_ratio_rows"] == 47
        )
        checks.append(
            check_row(
                "level_report_ratio_mismatch",
                "strict-validation-health",
                True,
                level_ratio_matched,
                level_ratio_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_ratio_result.stdout,
            )
        )

        level_roundtrip_result, level_roundtrip_manifest = level_report_drift_fixture(
            root,
            "level-report-roundtrip",
            mutate_csv=lambda rows, fieldnames, csv_path, markdown_path: rows[0].__setitem__("roundtrip_crc32", "0"),
        )
        level_roundtrip_matched = (
            level_roundtrip_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_roundtrip_result.stdout
            and level_roundtrip_manifest["validation_healthy"] is False
            and level_roundtrip_manifest["level_report_healthy"] is False
            and level_roundtrip_manifest["level_report_roundtrip_rows"] == 47
        )
        checks.append(
            check_row(
                "level_report_roundtrip_mismatch",
                "strict-validation-health",
                True,
                level_roundtrip_matched,
                level_roundtrip_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_roundtrip_result.stdout,
            )
        )

        level_markdown_summary_result, level_markdown_summary_manifest = level_report_drift_fixture(
            root,
            "level-report-markdown-summary",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("Rows: 48", "Rows: 49", 1)
            ),
        )
        level_markdown_summary_matched = (
            level_markdown_summary_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_markdown_summary_result.stdout
            and level_markdown_summary_manifest["validation_healthy"] is False
            and level_markdown_summary_manifest["level_report_healthy"] is False
            and level_markdown_summary_manifest["level_report_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "level_report_markdown_summary_mismatch",
                "strict-validation-health",
                True,
                level_markdown_summary_matched,
                level_markdown_summary_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_markdown_summary_result.stdout,
            )
        )

        level_markdown_detail_result, level_markdown_detail_manifest = level_report_drift_fixture(
            root,
            "level-report-markdown-detail",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("|text | fastest |", "|text-drift | fastest |", 1)
            ),
        )
        level_markdown_detail_matched = (
            level_markdown_detail_result.returncode != 0
            and "dashboard_index_validation_unhealthy=level_report_failed" in level_markdown_detail_result.stdout
            and level_markdown_detail_manifest["validation_healthy"] is False
            and level_markdown_detail_manifest["level_report_healthy"] is False
            and level_markdown_detail_manifest["level_report_markdown_detail_unmatched"] == 1
        )
        checks.append(
            check_row(
                "level_report_markdown_detail_mismatch",
                "strict-validation-health",
                True,
                level_markdown_detail_matched,
                level_markdown_detail_result.returncode,
                "dashboard_index_validation_unhealthy=level_report_failed",
                level_markdown_detail_result.stdout,
            )
        )

        dynamic_missing_result, dynamic_missing_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-missing-path",
            mutate_csv=lambda rows, fieldnames, csv_path: rows.pop(),
        )
        dynamic_missing_matched = (
            dynamic_missing_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_missing_result.stdout
            and dynamic_missing_manifest["validation_healthy"] is False
            and dynamic_missing_manifest["dynamic_plan_healthy"] is False
            and dynamic_missing_manifest["dynamic_plan_missing_paths"] == ["project_files:docs/roadmap.md"]
        )
        checks.append(
            check_row(
                "dynamic_plan_missing_path",
                "strict-validation-health",
                True,
                dynamic_missing_matched,
                dynamic_missing_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_missing_result.stdout,
            )
        )

        dynamic_duplicate_result, dynamic_duplicate_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-duplicate-path",
            mutate_csv=lambda rows, fieldnames, csv_path: rows.append(dict(rows[0])),
        )
        dynamic_duplicate_matched = (
            dynamic_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_duplicate_result.stdout
            and dynamic_duplicate_manifest["validation_healthy"] is False
            and dynamic_duplicate_manifest["dynamic_plan_healthy"] is False
            and dynamic_duplicate_manifest["dynamic_plan_duplicate_paths"] == ["project_files:README.md"]
        )
        checks.append(
            check_row(
                "dynamic_plan_duplicate_path",
                "strict-validation-health",
                True,
                dynamic_duplicate_matched,
                dynamic_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_duplicate_result.stdout,
            )
        )

        dynamic_unknown_result, dynamic_unknown_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-unknown-path",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__("path", "unknown-path"),
        )
        dynamic_unknown_matched = (
            dynamic_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_unknown_result.stdout
            and dynamic_unknown_manifest["validation_healthy"] is False
            and dynamic_unknown_manifest["dynamic_plan_healthy"] is False
            and dynamic_unknown_manifest["dynamic_plan_unknown_paths"] == ["project_files:unknown-path"]
        )
        checks.append(
            check_row(
                "dynamic_plan_unknown_path",
                "strict-validation-health",
                True,
                dynamic_unknown_matched,
                dynamic_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_unknown_result.stdout,
            )
        )

        dynamic_malformed_result, dynamic_malformed_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-malformed-row",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__("input_bytes", "bad"),
        )
        dynamic_malformed_matched = (
            dynamic_malformed_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_malformed_result.stdout
            and dynamic_malformed_manifest["validation_healthy"] is False
            and dynamic_malformed_manifest["dynamic_plan_healthy"] is False
            and dynamic_malformed_manifest["dynamic_plan_malformed_rows"] == 1
        )
        checks.append(
            check_row(
                "dynamic_plan_malformed_row",
                "strict-validation-health",
                True,
                dynamic_malformed_matched,
                dynamic_malformed_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_malformed_result.stdout,
            )
        )

        dynamic_token_result, dynamic_token_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-token-accounting",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__(
                "token_count",
                str(int(rows[0]["token_count"]) + 1),
            ),
        )
        dynamic_token_matched = (
            dynamic_token_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_token_result.stdout
            and dynamic_token_manifest["validation_healthy"] is False
            and dynamic_token_manifest["dynamic_plan_healthy"] is False
            and dynamic_token_manifest["dynamic_plan_token_accounting_rows"] == 8
        )
        checks.append(
            check_row(
                "dynamic_plan_token_accounting_mismatch",
                "strict-validation-health",
                True,
                dynamic_token_matched,
                dynamic_token_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_token_result.stdout,
            )
        )

        dynamic_histogram_result, dynamic_histogram_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-histogram",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__("length_symbol_hist", "bad"),
        )
        dynamic_histogram_matched = (
            dynamic_histogram_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_histogram_result.stdout
            and dynamic_histogram_manifest["validation_healthy"] is False
            and dynamic_histogram_manifest["dynamic_plan_healthy"] is False
            and dynamic_histogram_manifest["dynamic_plan_histogram_rows"] == 8
        )
        checks.append(
            check_row(
                "dynamic_plan_histogram_mismatch",
                "strict-validation-health",
                True,
                dynamic_histogram_matched,
                dynamic_histogram_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_histogram_result.stdout,
            )
        )

        dynamic_ratio_result, dynamic_ratio_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-ratio",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__("fixed_dynamic_size_ratio", "999.0000"),
        )
        dynamic_ratio_matched = (
            dynamic_ratio_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_ratio_result.stdout
            and dynamic_ratio_manifest["validation_healthy"] is False
            and dynamic_ratio_manifest["dynamic_plan_healthy"] is False
            and dynamic_ratio_manifest["dynamic_plan_ratio_rows"] == 8
        )
        checks.append(
            check_row(
                "dynamic_plan_ratio_mismatch",
                "strict-validation-health",
                True,
                dynamic_ratio_matched,
                dynamic_ratio_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_ratio_result.stdout,
            )
        )

        dynamic_slack_result, dynamic_slack_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-slack",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__(
                "dynamic_bits_to_save_byte",
                str((int(rows[0]["dynamic_bits_mod8"]) + 1) % 8),
            ),
        )
        dynamic_slack_matched = (
            dynamic_slack_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_slack_result.stdout
            and dynamic_slack_manifest["validation_healthy"] is False
            and dynamic_slack_manifest["dynamic_plan_healthy"] is False
            and dynamic_slack_manifest["dynamic_plan_slack_rows"] == 8
        )
        checks.append(
            check_row(
                "dynamic_plan_slack_mismatch",
                "strict-validation-health",
                True,
                dynamic_slack_matched,
                dynamic_slack_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_slack_result.stdout,
            )
        )

        dynamic_wrapper_result, dynamic_wrapper_manifest = dynamic_plan_drift_fixture(
            root,
            "dynamic-plan-wrapper",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__(
                "dynamic_zlib_bytes",
                str(int(rows[0]["dynamic_zlib_bytes"]) + 1),
            ),
        )
        dynamic_wrapper_matched = (
            dynamic_wrapper_result.returncode != 0
            and "dashboard_index_validation_unhealthy=dynamic_plan_failed" in dynamic_wrapper_result.stdout
            and dynamic_wrapper_manifest["validation_healthy"] is False
            and dynamic_wrapper_manifest["dynamic_plan_healthy"] is False
            and dynamic_wrapper_manifest["dynamic_plan_wrapper_rows"] == 8
        )
        checks.append(
            check_row(
                "dynamic_plan_wrapper_mismatch",
                "strict-validation-health",
                True,
                dynamic_wrapper_matched,
                dynamic_wrapper_result.returncode,
                "dashboard_index_validation_unhealthy=dynamic_plan_failed",
                dynamic_wrapper_result.stdout,
            )
        )

        fuzz_report_count_result, fuzz_report_count_manifest = fuzz_corpus_drift_fixture(
            root,
            "fuzz-corpus-report-count",
            mutate_report=lambda payload: payload.__setitem__("cases", int(payload["cases"]) + 1),
        )
        fuzz_report_count_matched = (
            fuzz_report_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=fuzz_corpus_failed" in fuzz_report_count_result.stdout
            and fuzz_report_count_manifest["validation_healthy"] is False
            and fuzz_report_count_manifest["fuzz_corpus_healthy"] is False
            and fuzz_report_count_manifest["fuzz_corpus_report_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "fuzz_corpus_report_count_mismatch",
                "strict-validation-health",
                True,
                fuzz_report_count_matched,
                fuzz_report_count_result.returncode,
                "dashboard_index_validation_unhealthy=fuzz_corpus_failed",
                fuzz_report_count_result.stdout,
            )
        )

        fuzz_matched_rows_result, fuzz_matched_rows_manifest = fuzz_corpus_drift_fixture(
            root,
            "fuzz-corpus-matched-rows",
            mutate_report=lambda payload: payload.__setitem__("matched_rows", int(payload["matched_rows"]) - 1),
        )
        fuzz_matched_rows_matched = (
            fuzz_matched_rows_result.returncode != 0
            and "dashboard_index_validation_unhealthy=fuzz_corpus_failed" in fuzz_matched_rows_result.stdout
            and fuzz_matched_rows_manifest["validation_healthy"] is False
            and fuzz_matched_rows_manifest["fuzz_corpus_healthy"] is False
            and fuzz_matched_rows_manifest["fuzz_corpus_unmatched_rows"] == 1
        )
        checks.append(
            check_row(
                "fuzz_corpus_matched_rows_mismatch",
                "strict-validation-health",
                True,
                fuzz_matched_rows_matched,
                fuzz_matched_rows_result.returncode,
                "dashboard_index_validation_unhealthy=fuzz_corpus_failed",
                fuzz_matched_rows_result.stdout,
            )
        )

        fuzz_coverage_result, fuzz_coverage_manifest = fuzz_corpus_drift_fixture(
            root,
            "fuzz-corpus-coverage-unmatched",
            mutate_coverage=lambda payload: payload["mode_requirements"][0].__setitem__("matched", False),
        )
        fuzz_coverage_matched = (
            fuzz_coverage_result.returncode != 0
            and "dashboard_index_validation_unhealthy=fuzz_coverage_failed" in fuzz_coverage_result.stdout
            and fuzz_coverage_manifest["validation_healthy"] is False
            and fuzz_coverage_manifest["fuzz_corpus_healthy"] is False
            and fuzz_coverage_manifest["fuzz_corpus_coverage_unmatched"] == 1
        )
        checks.append(
            check_row(
                "fuzz_corpus_coverage_unmatched",
                "strict-validation-health",
                True,
                fuzz_coverage_matched,
                fuzz_coverage_result.returncode,
                "dashboard_index_validation_unhealthy=fuzz_coverage_failed",
                fuzz_coverage_result.stdout,
            )
        )

        fuzz_markdown_result, fuzz_markdown_manifest = fuzz_corpus_drift_fixture(
            root,
            "fuzz-corpus-markdown-unmatched",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("## Samples", "## Sample drift", 1)
            ),
        )
        fuzz_markdown_matched = (
            fuzz_markdown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=fuzz_corpus_failed" in fuzz_markdown_result.stdout
            and fuzz_markdown_manifest["validation_healthy"] is False
            and fuzz_markdown_manifest["fuzz_corpus_healthy"] is False
            and fuzz_markdown_manifest["fuzz_corpus_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "fuzz_corpus_markdown_unmatched",
                "strict-validation-health",
                True,
                fuzz_markdown_matched,
                fuzz_markdown_result.returncode,
                "dashboard_index_validation_unhealthy=fuzz_corpus_failed",
                fuzz_markdown_result.stdout,
            )
        )

        native_fuzz_report_count_result, native_fuzz_report_count_manifest = native_fuzz_corpus_drift_fixture(
            root,
            "native-fuzz-report-count",
            mutate_report=lambda payload: payload.__setitem__("cases", int(payload["cases"]) + 1),
        )
        native_fuzz_report_count_matched = (
            native_fuzz_report_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed" in native_fuzz_report_count_result.stdout
            and native_fuzz_report_count_manifest["validation_healthy"] is False
            and native_fuzz_report_count_manifest["native_fuzz_corpus_healthy"] is False
            and native_fuzz_report_count_manifest["native_fuzz_corpus_report_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "native_fuzz_corpus_report_count_mismatch",
                "strict-validation-health",
                True,
                native_fuzz_report_count_matched,
                native_fuzz_report_count_result.returncode,
                "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed",
                native_fuzz_report_count_result.stdout,
            )
        )

        native_fuzz_matched_rows_result, native_fuzz_matched_rows_manifest = native_fuzz_corpus_drift_fixture(
            root,
            "native-fuzz-matched-rows",
            mutate_report=lambda payload: payload.__setitem__("matched_rows", int(payload["matched_rows"]) - 1),
        )
        native_fuzz_matched_rows_matched = (
            native_fuzz_matched_rows_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed" in native_fuzz_matched_rows_result.stdout
            and native_fuzz_matched_rows_manifest["validation_healthy"] is False
            and native_fuzz_matched_rows_manifest["native_fuzz_corpus_healthy"] is False
            and native_fuzz_matched_rows_manifest["native_fuzz_corpus_unmatched_rows"] == 1
        )
        checks.append(
            check_row(
                "native_fuzz_corpus_matched_rows_mismatch",
                "strict-validation-health",
                True,
                native_fuzz_matched_rows_matched,
                native_fuzz_matched_rows_result.returncode,
                "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed",
                native_fuzz_matched_rows_result.stdout,
            )
        )

        native_fuzz_coverage_result, native_fuzz_coverage_manifest = native_fuzz_corpus_drift_fixture(
            root,
            "native-fuzz-coverage-unmatched",
            mutate_coverage=lambda payload: payload["mode_requirements"][0].__setitem__("matched", False),
        )
        native_fuzz_coverage_matched = (
            native_fuzz_coverage_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_fuzz_coverage_failed" in native_fuzz_coverage_result.stdout
            and native_fuzz_coverage_manifest["validation_healthy"] is False
            and native_fuzz_coverage_manifest["native_fuzz_corpus_healthy"] is False
            and native_fuzz_coverage_manifest["native_fuzz_corpus_coverage_unmatched"] == 1
        )
        checks.append(
            check_row(
                "native_fuzz_corpus_coverage_unmatched",
                "strict-validation-health",
                True,
                native_fuzz_coverage_matched,
                native_fuzz_coverage_result.returncode,
                "dashboard_index_validation_unhealthy=native_fuzz_coverage_failed",
                native_fuzz_coverage_result.stdout,
            )
        )

        native_fuzz_markdown_result, native_fuzz_markdown_manifest = native_fuzz_corpus_drift_fixture(
            root,
            "native-fuzz-markdown-unmatched",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("## Samples", "## Native sample drift", 1)
            ),
        )
        native_fuzz_markdown_matched = (
            native_fuzz_markdown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed" in native_fuzz_markdown_result.stdout
            and native_fuzz_markdown_manifest["validation_healthy"] is False
            and native_fuzz_markdown_manifest["native_fuzz_corpus_healthy"] is False
            and native_fuzz_markdown_manifest["native_fuzz_corpus_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "native_fuzz_corpus_markdown_unmatched",
                "strict-validation-health",
                True,
                native_fuzz_markdown_matched,
                native_fuzz_markdown_result.returncode,
                "dashboard_index_validation_unhealthy=native_fuzz_corpus_failed",
                native_fuzz_markdown_result.stdout,
            )
        )

        native_allocation_count_result, native_allocation_count_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-report-count",
            mutate_report=lambda payload: payload.__setitem__("case_count", int(payload["case_count"]) + 1),
        )
        native_allocation_count_matched = (
            native_allocation_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_count_result.stdout
            and native_allocation_count_manifest["validation_healthy"] is False
            and native_allocation_count_manifest["native_allocation_healthy"] is False
            and native_allocation_count_manifest["native_allocation_report_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_report_count_mismatch",
                "strict-validation-health",
                True,
                native_allocation_count_matched,
                native_allocation_count_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_count_result.stdout,
            )
        )

        native_allocation_unbalanced_result, native_allocation_unbalanced_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-report-unbalanced",
            mutate_report=lambda payload: payload["cases"][2].__setitem__(
                "allocated_bytes",
                int(payload["cases"][2]["allocated_bytes"]) + 1,
            ),
        )
        native_allocation_unbalanced_matched = (
            native_allocation_unbalanced_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_unbalanced_result.stdout
            and native_allocation_unbalanced_manifest["validation_healthy"] is False
            and native_allocation_unbalanced_manifest["native_allocation_healthy"] is False
            and native_allocation_unbalanced_manifest["native_allocation_report_unbalanced_rows"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_report_unbalanced",
                "strict-validation-health",
                True,
                native_allocation_unbalanced_matched,
                native_allocation_unbalanced_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_unbalanced_result.stdout,
            )
        )

        native_allocation_zero_result, native_allocation_zero_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-zero-unmatched",
            mutate_smoke=lambda payload: payload["cases"][0].__setitem__("matched", False),
        )
        native_allocation_zero_matched = (
            native_allocation_zero_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_zero_result.stdout
            and native_allocation_zero_manifest["validation_healthy"] is False
            and native_allocation_zero_manifest["native_allocation_healthy"] is False
            and native_allocation_zero_manifest["native_allocation_zero_report_unmatched"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_zero_report_unmatched",
                "strict-validation-health",
                True,
                native_allocation_zero_matched,
                native_allocation_zero_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_zero_result.stdout,
            )
        )

        native_allocation_budget_result, native_allocation_budget_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-budget-unmatched",
            mutate_smoke=lambda payload: payload["budget_cases"][0].__setitem__("max_allocated_bytes", 0),
        )
        native_allocation_budget_matched = (
            native_allocation_budget_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_budget_result.stdout
            and native_allocation_budget_manifest["validation_healthy"] is False
            and native_allocation_budget_manifest["native_allocation_healthy"] is False
            and native_allocation_budget_manifest["native_allocation_budget_report_unmatched"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_budget_report_unmatched",
                "strict-validation-health",
                True,
                native_allocation_budget_matched,
                native_allocation_budget_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_budget_result.stdout,
            )
        )

        native_allocation_markdown_malformed_result, native_allocation_markdown_malformed_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-markdown-malformed",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("| zero_decode | 16 | 16 |", "| zero_decode | NaN | 16 |", 1)
            ),
        )
        native_allocation_markdown_malformed_matched = (
            native_allocation_markdown_malformed_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_markdown_malformed_result.stdout
            and native_allocation_markdown_malformed_manifest["validation_healthy"] is False
            and native_allocation_markdown_malformed_manifest["native_allocation_healthy"] is False
            and native_allocation_markdown_malformed_manifest["native_allocation_markdown_malformed_rows"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_markdown_malformed",
                "strict-validation-health",
                True,
                native_allocation_markdown_malformed_matched,
                native_allocation_markdown_malformed_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_markdown_malformed_result.stdout,
            )
        )

        native_allocation_markdown_unknown_result, native_allocation_markdown_unknown_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-markdown-unknown",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text() + "| extra | 1 | 1 | 0 | 0 | 0 | 0 |\n"
            ),
        )
        native_allocation_markdown_unknown_matched = (
            native_allocation_markdown_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_markdown_unknown_result.stdout
            and native_allocation_markdown_unknown_manifest["validation_healthy"] is False
            and native_allocation_markdown_unknown_manifest["native_allocation_healthy"] is False
            and native_allocation_markdown_unknown_manifest["native_allocation_markdown_unknown_cases"] == ["extra"]
        )
        checks.append(
            check_row(
                "native_allocation_markdown_unknown",
                "strict-validation-health",
                True,
                native_allocation_markdown_unknown_matched,
                native_allocation_markdown_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_markdown_unknown_result.stdout,
            )
        )

        native_allocation_report_duplicate_result, native_allocation_report_duplicate_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-report-duplicate",
            mutate_report=lambda payload: payload["cases"].append(dict(payload["cases"][0])),
        )
        native_allocation_report_duplicate_matched = (
            native_allocation_report_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_report_duplicate_result.stdout
            and native_allocation_report_duplicate_manifest["validation_healthy"] is False
            and native_allocation_report_duplicate_manifest["native_allocation_healthy"] is False
            and native_allocation_report_duplicate_manifest["native_allocation_report_duplicate_case_names"] == ["zero_decode"]
        )
        checks.append(
            check_row(
                "native_allocation_report_duplicate_case",
                "strict-validation-health",
                True,
                native_allocation_report_duplicate_matched,
                native_allocation_report_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_report_duplicate_result.stdout,
            )
        )

        native_allocation_zero_duplicate_result, native_allocation_zero_duplicate_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-zero-duplicate",
            mutate_smoke=lambda payload: payload["cases"].append(dict(payload["cases"][0])),
        )
        native_allocation_zero_duplicate_matched = (
            native_allocation_zero_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_zero_duplicate_result.stdout
            and native_allocation_zero_duplicate_manifest["validation_healthy"] is False
            and native_allocation_zero_duplicate_manifest["native_allocation_healthy"] is False
            and native_allocation_zero_duplicate_manifest["native_allocation_zero_duplicate_cases"] == ["zero_decode"]
        )
        checks.append(
            check_row(
                "native_allocation_zero_duplicate_case",
                "strict-validation-health",
                True,
                native_allocation_zero_duplicate_matched,
                native_allocation_zero_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_zero_duplicate_result.stdout,
            )
        )

        native_allocation_budget_duplicate_result, native_allocation_budget_duplicate_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-budget-duplicate",
            mutate_smoke=lambda payload: payload["budget_cases"].append(dict(payload["budget_cases"][0])),
        )
        native_allocation_budget_duplicate_matched = (
            native_allocation_budget_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_budget_duplicate_result.stdout
            and native_allocation_budget_duplicate_manifest["validation_healthy"] is False
            and native_allocation_budget_duplicate_manifest["native_allocation_healthy"] is False
            and native_allocation_budget_duplicate_manifest["native_allocation_budget_duplicate_cases"] == ["budgeted_index"]
        )
        checks.append(
            check_row(
                "native_allocation_budget_duplicate_case",
                "strict-validation-health",
                True,
                native_allocation_budget_duplicate_matched,
                native_allocation_budget_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_budget_duplicate_result.stdout,
            )
        )

        native_allocation_negative_unmatched_result, native_allocation_negative_unmatched_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-negative-unmatched",
            mutate_negative=lambda payload: payload["cases"][0].__setitem__("matched", False),
        )
        native_allocation_negative_unmatched_matched = (
            native_allocation_negative_unmatched_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_negative_unmatched_result.stdout
            and native_allocation_negative_unmatched_manifest["validation_healthy"] is False
            and native_allocation_negative_unmatched_manifest["native_allocation_healthy"] is False
            and native_allocation_negative_unmatched_manifest["native_allocation_negative_unmatched"] == 1
        )
        checks.append(
            check_row(
                "native_allocation_negative_unmatched",
                "strict-validation-health",
                True,
                native_allocation_negative_unmatched_matched,
                native_allocation_negative_unmatched_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_negative_unmatched_result.stdout,
            )
        )

        native_allocation_markdown_duplicate_result, native_allocation_markdown_duplicate_manifest = native_allocation_drift_fixture(
            root,
            "native-allocation-markdown-duplicate",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace(
                    "| zero_decode | 16 | 16 | 0 | 0 | 0 | 0 |\n",
                    "| zero_decode | 16 | 16 | 0 | 0 | 0 | 0 |\n| zero_decode | 16 | 16 | 0 | 0 | 0 | 0 |\n",
                    1,
                )
            ),
        )
        native_allocation_markdown_duplicate_matched = (
            native_allocation_markdown_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=native_allocation_failed" in native_allocation_markdown_duplicate_result.stdout
            and native_allocation_markdown_duplicate_manifest["validation_healthy"] is False
            and native_allocation_markdown_duplicate_manifest["native_allocation_healthy"] is False
            and native_allocation_markdown_duplicate_manifest["native_allocation_markdown_duplicate_cases"] == ["zero_decode"]
        )
        checks.append(
            check_row(
                "native_allocation_markdown_duplicate",
                "strict-validation-health",
                True,
                native_allocation_markdown_duplicate_matched,
                native_allocation_markdown_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=native_allocation_failed",
                native_allocation_markdown_duplicate_result.stdout,
            )
        )

        decode_report_count_result, decode_report_count_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-report-count",
            mutate_report=lambda payload: payload.__setitem__("rows", int(payload["rows"]) + 1),
        )
        decode_report_count_matched = (
            decode_report_count_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_report_count_result.stdout
            and decode_report_count_manifest["validation_healthy"] is False
            and decode_report_count_manifest["decode_stage_healthy"] is False
            and decode_report_count_manifest["decode_stage_report_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "decode_stage_report_count_mismatch",
                "strict-validation-health",
                True,
                decode_report_count_matched,
                decode_report_count_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_report_count_result.stdout,
            )
        )

        decode_error_match_result, decode_error_match_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-error-match",
            mutate_report=lambda payload: payload.__setitem__("matched_error_rows", int(payload["matched_error_rows"]) - 1),
        )
        decode_error_match_matched = (
            decode_error_match_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_error_match_result.stdout
            and decode_error_match_manifest["validation_healthy"] is False
            and decode_error_match_manifest["decode_stage_healthy"] is False
            and decode_error_match_manifest["decode_stage_matched_error_rows"] == 2
        )
        checks.append(
            check_row(
                "decode_stage_error_match_mismatch",
                "strict-validation-health",
                True,
                decode_error_match_matched,
                decode_error_match_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_error_match_result.stdout,
            )
        )

        decode_csv_missing_result, decode_csv_missing_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-csv-missing",
            mutate_csv=lambda rows, fieldnames, csv_path: rows.pop(),
        )
        decode_csv_missing_matched = (
            decode_csv_missing_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_csv_missing_result.stdout
            and decode_csv_missing_manifest["validation_healthy"] is False
            and decode_csv_missing_manifest["decode_stage_healthy"] is False
            and decode_csv_missing_manifest["decode_stage_csv_missing_cases"] == ["structured"]
        )
        checks.append(
            check_row(
                "decode_stage_csv_missing_case",
                "strict-validation-health",
                True,
                decode_csv_missing_matched,
                decode_csv_missing_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_csv_missing_result.stdout,
            )
        )

        decode_csv_duplicate_result, decode_csv_duplicate_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-csv-duplicate",
            mutate_csv=lambda rows, fieldnames, csv_path: rows.append(dict(rows[0])),
        )
        decode_csv_duplicate_matched = (
            decode_csv_duplicate_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_csv_duplicate_result.stdout
            and decode_csv_duplicate_manifest["validation_healthy"] is False
            and decode_csv_duplicate_manifest["decode_stage_healthy"] is False
            and decode_csv_duplicate_manifest["decode_stage_csv_duplicate_cases"] == ["tiny"]
        )
        checks.append(
            check_row(
                "decode_stage_csv_duplicate_case",
                "strict-validation-health",
                True,
                decode_csv_duplicate_matched,
                decode_csv_duplicate_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_csv_duplicate_result.stdout,
            )
        )

        decode_csv_unknown_result, decode_csv_unknown_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-csv-unknown",
            mutate_csv=lambda rows, fieldnames, csv_path: rows[0].__setitem__("case", "unknown"),
        )
        decode_csv_unknown_matched = (
            decode_csv_unknown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_csv_unknown_result.stdout
            and decode_csv_unknown_manifest["validation_healthy"] is False
            and decode_csv_unknown_manifest["decode_stage_healthy"] is False
            and decode_csv_unknown_manifest["decode_stage_csv_unknown_cases"] == ["unknown"]
        )
        checks.append(
            check_row(
                "decode_stage_csv_unknown_case",
                "strict-validation-health",
                True,
                decode_csv_unknown_matched,
                decode_csv_unknown_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_csv_unknown_result.stdout,
            )
        )

        decode_markdown_result, decode_markdown_manifest = decode_stage_drift_fixture(
            root,
            "decode-stage-markdown-unmatched",
            mutate_markdown=lambda markdown_path: markdown_path.write_text(
                markdown_path.read_text().replace("## Error path smoke", "## Error path drift", 1)
            ),
        )
        decode_markdown_matched = (
            decode_markdown_result.returncode != 0
            and "dashboard_index_validation_unhealthy=decode_stage_failed" in decode_markdown_result.stdout
            and decode_markdown_manifest["validation_healthy"] is False
            and decode_markdown_manifest["decode_stage_healthy"] is False
            and decode_markdown_manifest["decode_stage_markdown_unmatched"] == 1
        )
        checks.append(
            check_row(
                "decode_stage_markdown_unmatched",
                "strict-validation-health",
                True,
                decode_markdown_matched,
                decode_markdown_result.returncode,
                "dashboard_index_validation_unhealthy=decode_stage_failed",
                decode_markdown_result.stdout,
            )
        )

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
            elif fixture == "non_json_artifact_failed":
                audit_probe = fixture_root / "vort-non-json-audit-probe.md"
                audit_probe.write_text("\n")
                write_producer_map(producer_map)
                payload = json.loads(producer_map.read_text())
                payload.setdefault("exact", {})[audit_probe.name] = "synthetic non-json artifact audit fixture"
                payload.setdefault("artifact_metadata", {})[audit_probe.name] = {
                    "expected_format": "md",
                    "smoke_gate": "synthetic non-json artifact audit fixture",
                }
                producer_map.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
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
                write_sidecar_corrupt_markdown(fixture_root / SIDECAR_CORRUPT_MARKDOWN_ARTIFACT, ok=False)
                write_producer_map(producer_map)
            elif fixture == "missing_huffman_length_artifact":
                (fixture_root / HUFFMAN_LENGTH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "huffman_length_failed":
                write_huffman_length_csv(fixture_root / HUFFMAN_LENGTH_ARTIFACT, optimal=False)
                write_huffman_length_markdown(
                    fixture_root / "vort-huffman-length-report.md",
                    optimal_rows=0,
                    non_optimal_rows=1,
                    worst_gap_bits=1,
                    package_merge_optimal_rows=0,
                    package_merge_non_optimal_rows=1,
                    package_merge_worst_gap_bits=1,
                )
                write_producer_map(producer_map)
            elif fixture == "missing_level_report_artifact":
                (fixture_root / LEVEL_REPORT_CSV_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "level_report_failed":
                write_level_report_csv(fixture_root / LEVEL_REPORT_CSV_ARTIFACT, healthy=False)
                write_level_report_markdown(fixture_root / LEVEL_REPORT_MARKDOWN_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_dynamic_plan_artifact":
                (fixture_root / DYNAMIC_PLAN_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "dynamic_plan_failed":
                write_dynamic_plan_csv(fixture_root / DYNAMIC_PLAN_ARTIFACT, [{"path": "README.md"}, {"path": "docs/roadmap.md"}], healthy=False)
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
            elif fixture == "missing_deflate_chunked_huffman_bench_artifact":
                (fixture_root / DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_chunked_huffman_bench_failed":
                write_deflate_chunked_huffman_bench_csv(fixture_root / DEFLATE_CHUNKED_HUFFMAN_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_deflate_extra_bits_bench_artifact":
                (fixture_root / DEFLATE_EXTRA_BITS_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_extra_bits_bench_failed":
                write_deflate_extra_bits_bench_csv(fixture_root / DEFLATE_EXTRA_BITS_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_dictionary_decode_bench_artifact":
                (fixture_root / DICTIONARY_DECODE_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "dictionary_decode_bench_failed":
                write_dictionary_decode_bench_csv(fixture_root / DICTIONARY_DECODE_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_png_scanline_bench_artifact":
                (fixture_root / PNG_SCANLINE_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "png_scanline_bench_failed":
                write_png_scanline_bench_csv(fixture_root / PNG_SCANLINE_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_chunked_zlib_bench_artifact":
                (fixture_root / CHUNKED_ZLIB_BENCH_ARTIFACT).unlink()
                (fixture_root / CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "chunked_zlib_bench_failed":
                write_chunked_zlib_bench_csv(fixture_root / CHUNKED_ZLIB_BENCH_ARTIFACT, healthy=False)
                write_chunked_zlib_bench_markdown(fixture_root / CHUNKED_ZLIB_BENCH_MARKDOWN_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_png_streaming_zlib_bench_artifact":
                (fixture_root / PNG_STREAMING_ZLIB_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "png_streaming_zlib_bench_failed":
                write_png_streaming_zlib_bench_csv(fixture_root / PNG_STREAMING_ZLIB_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_deflate_dynamic_decode_profile_artifact":
                (fixture_root / DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "deflate_dynamic_decode_profile_failed":
                write_deflate_dynamic_decode_profile_csv(fixture_root / DEFLATE_DYNAMIC_DECODE_PROFILE_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_fuzz_corpus_artifact":
                (fixture_root / FUZZ_CORPUS_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "fuzz_corpus_failed":
                write_fuzz_corpus_report(fixture_root / FUZZ_CORPUS_ARTIFACT, ok=False)
                write_fuzz_corpus_markdown(fixture_root / FUZZ_CORPUS_MARKDOWN_ARTIFACT, ok=False)
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
                write_zlib_relaxed_gate(fixture_root / ZLIB_RELAXED_GATE_ARTIFACT, ok=False)
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
            elif fixture == "missing_native_library_bench_artifact":
                (fixture_root / NATIVE_LIBRARY_BENCH_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "native_library_bench_failed":
                write_native_library_bench_csv(fixture_root / NATIVE_LIBRARY_BENCH_ARTIFACT, healthy=False)
                write_producer_map(producer_map)
            elif fixture == "missing_decode_stage_artifact":
                (fixture_root / DECODE_STAGE_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "decode_stage_failed":
                write_decode_stage_report(fixture_root / DECODE_STAGE_ARTIFACT, ok=False)
                write_decode_stage_csv(fixture_root / DECODE_STAGE_CSV_ARTIFACT, healthy=False)
                write_decode_stage_markdown(fixture_root / DECODE_STAGE_MARKDOWN_ARTIFACT, ok=False)
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
                (fixture_root / BR_STATIC_REPORT_JSON_ARTIFACT).unlink()
                (fixture_root / BR_STATIC_CANDIDATES_MARKDOWN_ARTIFACT).unlink()
                (fixture_root / BR_STATIC_UPSTREAM_REPORT_ARTIFACT).unlink()
                (fixture_root / BR_STATIC_UPSTREAM_MARKDOWN_ARTIFACT).unlink()
                (fixture_root / BR_STATIC_NODE_MARKDOWN_ARTIFACT).unlink()
                write_producer_map(producer_map)
            elif fixture == "br_static_dictionary_failed":
                write_br_static_dictionary_artifacts(fixture_root)
                payload = json.loads((fixture_root / BR_STATIC_REPORT_JSON_ARTIFACT).read_text())
                payload["entry_count"] = 999
                (fixture_root / BR_STATIC_REPORT_JSON_ARTIFACT).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
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
                payload["total_stream_bytes_by_tier"]["seek_fast"] += 1
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

        validation_json_docs_row_mismatch_root = root / "validation-json-docs-negative-row-mismatch"
        validation_json_docs_row_mismatch_root.mkdir()
        write_healthy_artifacts(validation_json_docs_row_mismatch_root)
        validation_json_docs_row_mismatch_payload = json.loads(
            (validation_json_docs_row_mismatch_root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).read_text()
        )
        validation_json_docs_row_mismatch_payload["cases"].append(
            {
                "name": "synthetic_unmatched_docs_negative_case",
                "expected_failure": True,
                "expected_error": "synthetic unmatched",
                "actual_error": "different synthetic error",
                "matched": False,
            }
        )
        (validation_json_docs_row_mismatch_root / VALIDATION_JSON_DOCS_NEGATIVE_ARTIFACT).write_text(
            json.dumps(validation_json_docs_row_mismatch_payload, indent=2, sort_keys=True) + "\n"
        )
        validation_json_docs_row_mismatch_producer = validation_json_docs_row_mismatch_root / "producers.json"
        write_producer_map(validation_json_docs_row_mismatch_producer)
        validation_json_docs_row_mismatch_result = run(
            dashboard_args(validation_json_docs_row_mismatch_root, validation_json_docs_row_mismatch_producer, "--strict-validation-health"),
            check=False,
        )
        validation_json_docs_row_mismatch_manifest = json.loads(
            (validation_json_docs_row_mismatch_root / "vort-dashboard-index.json").read_text()
        )
        validation_json_docs_row_mismatch_matched = (
            validation_json_docs_row_mismatch_result.returncode != 0
            and "dashboard_index_validation_unhealthy=validation_json_docs_negative_failed" in validation_json_docs_row_mismatch_result.stdout
            and validation_json_docs_row_mismatch_manifest["validation_healthy"] is False
            and validation_json_docs_row_mismatch_manifest["validation_json_healthy"] is False
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_present"] is True
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_ok"] is True
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_case_count"] == 2
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_rows"] == 3
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_matched"] == 2
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_count_mismatch"] == 1
            and validation_json_docs_row_mismatch_manifest["validation_json_docs_negative_row_unmatched"] == 1
        )
        checks.append(
            check_row(
                "validation_json_docs_negative_row_mismatch",
                "strict-validation-health",
                True,
                validation_json_docs_row_mismatch_matched,
                validation_json_docs_row_mismatch_result.returncode,
                "dashboard_index_validation_unhealthy=validation_json_docs_negative_failed",
                validation_json_docs_row_mismatch_result.stdout,
            )
        )

        validation_json_count_mismatch_root = root / "validation-json-observed-schema-count-mismatch"
        validation_json_count_mismatch_root.mkdir()
        write_healthy_artifacts(validation_json_count_mismatch_root)
        validation_json_count_mismatch_payload = json.loads((validation_json_count_mismatch_root / VALIDATION_JSON_SMOKE_ARTIFACT).read_text())
        validation_json_count_mismatch_payload["observed_schema_count"] += 1
        (validation_json_count_mismatch_root / VALIDATION_JSON_SMOKE_ARTIFACT).write_text(
            json.dumps(validation_json_count_mismatch_payload, indent=2, sort_keys=True) + "\n"
        )
        validation_json_count_mismatch_producer = validation_json_count_mismatch_root / "producers.json"
        write_producer_map(validation_json_count_mismatch_producer)
        validation_json_count_mismatch_result = run(
            dashboard_args(validation_json_count_mismatch_root, validation_json_count_mismatch_producer, "--strict-validation-health"),
            check=False,
        )
        validation_json_count_mismatch_manifest = json.loads((validation_json_count_mismatch_root / "vort-dashboard-index.json").read_text())
        validation_json_count_mismatch_matched = (
            validation_json_count_mismatch_result.returncode != 0
            and "dashboard_index_validation_unhealthy=validation_json_failed" in validation_json_count_mismatch_result.stdout
            and validation_json_count_mismatch_manifest["validation_healthy"] is False
            and validation_json_count_mismatch_manifest["validation_json_present"] is True
            and validation_json_count_mismatch_manifest["validation_json_ok"] is True
            and validation_json_count_mismatch_manifest["validation_json_healthy"] is False
            and validation_json_count_mismatch_manifest["validation_json_observed_schema_count_mismatch"] == 1
        )
        checks.append(
            check_row(
                "validation_json_observed_schema_count_mismatch",
                "strict-validation-health",
                True,
                validation_json_count_mismatch_matched,
                validation_json_count_mismatch_result.returncode,
                "dashboard_index_validation_unhealthy=validation_json_failed",
                validation_json_count_mismatch_result.stdout,
            )
        )

        validation_json_drift_cases = [
            (
                "unchecked-observed-schema",
                "validation_json_unchecked_observed_schema",
                {
                    "unchecked_observed_schema_count": 1,
                    "unchecked_observed_schemas": ["vort.unchecked_schema"],
                },
                {
                    "validation_json_unchecked_observed_schema_count": 1,
                    "validation_json_unchecked_observed_schema_rows": 1,
                    "validation_json_unchecked_observed_schemas": ["vort.unchecked_schema"],
                },
            ),
            (
                "json-artifact-parse-failed",
                "validation_json_artifact_parse_failed",
                {
                    "json_artifact_parse_failed_count": 1,
                    "json_artifact_parse_failed": ["synthetic-bad.json"],
                },
                {
                    "validation_json_json_artifact_parse_failed_count": 1,
                    "validation_json_json_artifact_parse_failed": ["synthetic-bad.json"],
                },
            ),
            (
                "json-artifact-missing-schema",
                "validation_json_artifact_missing_schema",
                {
                    "json_artifact_missing_schema_count": 1,
                    "json_artifact_missing_schema": ["synthetic-missing-schema.json"],
                },
                {
                    "validation_json_json_artifact_missing_schema_count": 1,
                    "validation_json_json_artifact_missing_schema": ["synthetic-missing-schema.json"],
                },
            ),
            (
                "json-artifact-manifest-failed",
                "validation_json_artifact_manifest_failed",
                {
                    "json_artifact_manifest_failed_count": 1,
                    "json_artifact_manifest_failed_names": ["synthetic-manifest-failed.json"],
                },
                {
                    "validation_json_json_artifact_manifest_failed_count": 1,
                    "validation_json_json_artifact_manifest_failed_names": ["synthetic-manifest-failed.json"],
                },
            ),
            (
                "json-artifact-manifest-accounting-mismatch",
                "validation_json_artifact_manifest_accounting_mismatch",
                {
                    "json_artifact_manifest_accounting_mismatch": 1,
                },
                {
                    "validation_json_json_artifact_manifest_accounting_mismatch": 1,
                },
            ),
        ]
        for fixture_name, check_name, updates, expected_manifest_fields in validation_json_drift_cases:
            result, manifest = validation_json_smoke_drift_fixture(
                root,
                f"validation-json-{fixture_name}",
                lambda payload, updates=updates: payload.update(updates),
            )
            matched = (
                result.returncode != 0
                and "dashboard_index_validation_unhealthy=validation_json_failed" in result.stdout
                and manifest["validation_healthy"] is False
                and manifest["validation_json_present"] is True
                and manifest["validation_json_ok"] is True
                and manifest["validation_json_healthy"] is False
                and all(manifest[field] == expected for field, expected in expected_manifest_fields.items())
            )
            checks.append(
                check_row(
                    check_name,
                    "strict-validation-health",
                    True,
                    matched,
                    result.returncode,
                    "dashboard_index_validation_unhealthy=validation_json_failed",
                    result.stdout,
                )
            )

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
