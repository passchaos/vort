#!/usr/bin/env python3
"""Smoke-test validation JSON docs checker negative drift cases."""

from __future__ import annotations

import argparse
import copy
import json
import re
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any

import validation_json_docs_check as docs_check


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def with_patched_path(name: str, path: Path, action: Callable[[], None]) -> None:
    original = getattr(docs_check, name)
    setattr(docs_check, name, path)
    try:
        action()
    finally:
        setattr(docs_check, name, original)


def negative_case(name: str, expected_error: str, action: Callable[[], None]) -> dict[str, object]:
    try:
        action()
    except AssertionError as exc:
        actual_error = str(exc)
        matched = expected_error in actual_error
        return {
            "name": name,
            "expected_failure": True,
            "expected_error": expected_error,
            "actual_error": actual_error,
            "matched": matched,
        }
    return {
        "name": name,
        "expected_failure": True,
        "expected_error": expected_error,
        "actual_error": "<success>",
        "matched": False,
    }


def dashboard_index_doc_example() -> dict[str, Any]:
    for block in re.findall(r"```json\n(.*?)\n```", docs_check.DOC.read_text(), re.S):
        payload = json.loads(block)
        if isinstance(payload, dict) and payload.get("schema") == "vort.dashboard_index":
            return payload
    raise AssertionError("missing vort.dashboard_index docs example")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    schemas_def = docs_check.load_manifest()
    base_modes = json.loads(docs_check.DASHBOARD_STRICT_MODES.read_text())
    base_reasons = json.loads(docs_check.DASHBOARD_STRICT_REASONS.read_text())
    reason_count = len(base_reasons["expected_reasons"])
    cases: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix="vort-validation-docs-negative-") as tmp:
        root = Path(tmp)

        def missing_reason_config() -> None:
            payload = copy.deepcopy(base_reasons)
            payload["expected_reasons"] = payload["expected_reasons"][:-1]
            path = root / "missing-reason.json"
            write_json(path, payload)
            docs_check.validate_value_against_manifest(payload, schemas_def)
            with_patched_path(
                "DASHBOARD_STRICT_REASONS",
                path,
                lambda: docs_check.require_dashboard_validation_reason_manifest_consistency(schemas_def),
            )

        cases.append(negative_case("missing_reason_config", "differs from dashboard index enum", missing_reason_config))

        def strict_validation_min_checks_shortfall() -> None:
            payload = copy.deepcopy(base_modes)
            for row in payload["expected_modes"]:
                if row["mode"] == "strict-validation-health":
                    row["min_checks"] = reason_count - 1
            path = root / "strict-validation-min-checks-shortfall.json"
            write_json(path, payload)
            docs_check.validate_value_against_manifest(payload, schemas_def)
            with_patched_path(
                "DASHBOARD_STRICT_MODES",
                path,
                lambda: docs_check.require_dashboard_validation_reason_manifest_consistency(schemas_def),
            )

        cases.append(
            negative_case(
                "strict_validation_min_checks_shortfall",
                "strict-validation-health min_checks",
                strict_validation_min_checks_shortfall,
            )
        )

        def strict_validation_mode_missing() -> None:
            payload = copy.deepcopy(base_modes)
            payload["expected_modes"] = [row for row in payload["expected_modes"] if row["mode"] != "strict-validation-health"]
            path = root / "strict-validation-mode-missing.json"
            write_json(path, payload)
            with_patched_path(
                "DASHBOARD_STRICT_MODES",
                path,
                lambda: docs_check.require_dashboard_validation_reason_manifest_consistency(schemas_def),
            )

        cases.append(
            negative_case(
                "strict_validation_mode_missing",
                "must include strict-validation-health",
                strict_validation_mode_missing,
            )
        )

        def reason_check_pair_mismatch() -> None:
            payload = copy.deepcopy(base_reasons)
            payload["expected_reasons"][0]["check"] = payload["expected_reasons"][1]["check"]
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(negative_case("reason_check_pair_mismatch", "does not match check", reason_check_pair_mismatch))

        def reason_fixture_pair_mismatch() -> None:
            payload = copy.deepcopy(base_reasons)
            payload["expected_reasons"][0]["fixture"] = payload["expected_reasons"][1]["fixture"]
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(negative_case("reason_fixture_pair_mismatch", "does not match fixture", reason_fixture_pair_mismatch))

        def validation_smoke_checked_schema_enum() -> None:
            payload = {
                "schema": "vort.validation_json_smoke",
                "schema_version": 1,
                "ok": True,
                "checked_schemas": ["vort.unknown_schema"],
                "cli_success_ok": True,
                "cli_failure_ok": False,
                "cli_failure_hint": "payload_corrupt",
                "report_rows": 1,
                "corrupt_rows": 1,
            }
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(
            negative_case(
                "validation_smoke_checked_schema_enum",
                "checked_schemas has unexpected items",
                validation_smoke_checked_schema_enum,
            )
        )

        def native_summary_error_phase_enum() -> None:
            payload = {
                "schema": "vort.lz4_native_stream_summary_error",
                "schema_version": 1,
                "ok": False,
                "compressed_bytes": 7,
                "error": "CorruptFrame",
                "phase": "unknown",
                "offset": 0,
            }
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(
            negative_case(
                "native_summary_error_phase_enum",
                "phase has unexpected value",
                native_summary_error_phase_enum,
            )
        )

        def boolean_formula_positive_field() -> None:
            payload = {
                "schema": "vort.dashboard_index",
                "schema_version": 1,
                "artifact_count": 1,
                "producer_step_covered": 1,
                "producer_step_missing": [],
                "producer_step_allowed_missing": [],
                "producer_healthy": True,
                "smoke_gate_covered": 1,
                "smoke_gate_missing": [],
                "smoke_gate_healthy": True,
                "smoke_gate_required_missing": [],
                "validation_healthy": True,
                "validation_unhealthy_reasons": [],
                "header_inspect_present": True,
                "header_inspect_ok": True,
                "header_inspect_healthy": True,
                "header_inspect_case_count": 3,
                "header_inspect_raw_cases": 1,
                "header_inspect_zlib_cases": 1,
                "header_inspect_gzip_cases": 1,
                "header_inspect_negative_cases": 3,
                "header_inspect_raw_negative_cases": 1,
                "header_inspect_zlib_negative_cases": 1,
                "header_inspect_gzip_negative_cases": 1,
                "header_inspect_command_count": 3,
                "header_inspect_command_successes": 3,
                "header_inspect_command_failures": 3,
                "header_inspect_workflow_count": 3,
                "header_inspect_workflow_successes": 3,
                "header_inspect_dictionary_cases": 1,
                "header_inspect_optional_header_cases": 1,
                "header_inspect_fhcrc_cases": 1,
                "header_inspect_required_workflow_count": 1,
                "header_inspect_missing_workflow_count": 0,
                "header_inspect_missing_workflows": [],
                "dashboard_strict_present": True,
                "dashboard_strict_ok": True,
                "dashboard_strict_healthy": True,
                "dashboard_strict_check_count": 1,
                "dashboard_strict_mode_count": 1,
                "dashboard_strict_expected_failure_count": 0,
                "dashboard_strict_matched_count": 1,
                "dashboard_strict_expected_mode_count": 1,
                "dashboard_strict_missing_mode_count": 0,
                "dashboard_strict_missing_checks": 0,
                "dashboard_strict_missing_expected_failures": 0,
                "dashboard_strict_missing_matched": 0,
                "dashboard_strict_missing_modes": [],
                "sidecar_corrupt_present": True,
                "sidecar_corrupt_healthy": True,
                "sidecar_corrupt_rows": 1,
                "sidecar_corrupt_metadata_ok_rows": 1,
                "sidecar_corrupt_full_rejected_rows": 1,
                "sidecar_corrupt_metadata_failed_rows": 0,
                "sidecar_corrupt_full_not_rejected_rows": 0,
                "huffman_length_present": True,
                "huffman_length_healthy": True,
                "huffman_length_row_count": 0,
                "huffman_length_optimal_rows": 0,
                "huffman_length_non_optimal_rows": 0,
                "huffman_length_malformed_rows": 0,
                "huffman_length_worst_gap_bits": 0,
                "huffman_length_package_merge_optimal_rows": 0,
                "huffman_length_package_merge_non_optimal_rows": 0,
                "huffman_length_package_merge_worst_gap_bits": 0,
                "fuzz_corpus_present": True,
                "fuzz_corpus_ok": True,
                "fuzz_corpus_coverage_present": True,
                "fuzz_corpus_coverage_ok": True,
                "fuzz_corpus_healthy": True,
                "fuzz_corpus_cases": 1,
                "fuzz_corpus_matched_rows": 1,
                "fuzz_corpus_unmatched_rows": 0,
                "fuzz_corpus_exact_error_expectations": 1,
                "fuzz_corpus_mode_count_rows": 1,
                "fuzz_corpus_error_count_rows": 1,
                "fuzz_corpus_coverage_mode_requirements": 1,
                "fuzz_corpus_coverage_error_requirements": 1,
                "decode_stage_present": True,
                "decode_stage_ok": True,
                "decode_stage_healthy": True,
                "decode_stage_rows": 1,
                "decode_stage_error_rows": 1,
                "decode_stage_matched_error_rows": 1,
                "decode_stage_unmatched_error_rows": 0,
                "zstd_compare_present": True,
                "zstd_compare_standard_present": True,
                "zstd_compare_block_sweep_present": True,
                "zstd_compare_healthy": True,
                "zstd_compare_rows": 1,
                "zstd_compare_standard_rows": 1,
                "zstd_compare_block_sweep_rows": 1,
                "zstd_compare_native_ratio": 1.0,
                "zstd_compare_native_stream_ratio": 1.0,
                "zstd_compare_standard_native_ratio": 1.0,
                "zstd_compare_standard_native_stream_ratio": 1.0,
                "zstd_compare_decode_vs_zstd": 1.0,
                "zstd_compare_standard_decode_vs_zstd": 1.0,
                "zstd_compare_best_block_len": 4096,
                "zstd_compare_best_range_decode_mib_s": 1.0,
                "zstd_compare_best_range_decode_full_input_mib_s": 1.0,
                "native_allocation_present": True,
                "native_allocation_smoke_present": True,
                "native_allocation_negative_present": True,
                "native_allocation_healthy": True,
                "native_allocation_report_case_count": 1,
                "native_allocation_required_zero_allocation_cases": 1,
                "native_allocation_zero_allocation_matched": 1,
                "native_allocation_required_budget_cases": 1,
                "native_allocation_budget_matched": 1,
                "native_allocation_negative_case_count": 1,
                "native_allocation_negative_matched": 1,
                "python_zlib_diff_present": True,
                "python_zlib_diff_ok": True,
                "python_zlib_diff_healthy": True,
                "python_zlib_diff_payloads": 1,
                "python_zlib_diff_large_file_payloads": 1,
                "python_zlib_diff_file_hex_encode_cases": 1,
                "python_zlib_diff_match_heavy_payloads": 1,
                "python_zlib_diff_dynamic_payloads": 1,
                "python_zlib_diff_dictionary_cases": 1,
                "python_zlib_diff_zlib_dict_encode_cases": 1,
                "python_zlib_diff_raw_dict_encode_cases": 1,
                "python_zlib_diff_malformed_wrapper_cases": 1,
                "python_zlib_diff_malformed_deflate_cases": 1,
                "python_zlib_diff_cli_successes": 1,
                "python_zlib_diff_expected_failures": 1,
                "native_codec_probes_present": True,
                "native_codec_probes_ok": True,
                "native_codec_probes_healthy": True,
                "native_codec_probes_probe_count": 4,
                "native_codec_probes_ok_probe_count": 4,
                "native_codec_probes_timed_out_probes": 0,
                "native_codec_probes_capability_count": 16,
                "native_codec_probes_ok_capability_count": 16,
                "native_codec_probes_lib_generated_cases": 126,
                "native_codec_probes_incremental_cases": 135,
                "native_codec_probes_chunked_cases": 131,
                "native_codec_probes_reusable_chunked_cases": 128,
                "native_codec_probes_fse_repeat_cases": 8,
                "native_codec_probes_dictionary_cases": 139,
                "native_codec_probes_malformed_cases": 223,
                "native_codec_probes_total_cases": 257,
                "native_codec_probes_zstd_frame_cases": 118,
                "native_codec_probes_zstd_dictionary_cases": 25,
                "native_summary_error_present": True,
                "native_summary_error_healthy": True,
                "native_summary_error_case_count": 14,
                "native_summary_error_lz4_case_count": 7,
                "native_summary_error_zstd_case_count": 7,
                "native_summary_error_checksum_mismatch_count": 1,
                "native_summary_error_corrupt_frame_count": 4,
                "native_summary_error_truncated_frame_count": 8,
                "native_summary_error_magic_phase_count": 2,
                "native_summary_error_skippable_payload_phase_count": 2,
                "native_summary_error_frame_body_phase_count": 2,
                "native_summary_error_frame_checksum_phase_count": 2,
                "native_summary_error_frame_phase_count": 2,
                "native_summary_error_error_counts": {"ChecksumMismatch": 1, "CorruptFrame": 4, "InvalidMagic": 1, "TruncatedFrame": 8},
                "native_summary_error_phase_counts": {"frame": 2, "frame_body": 2, "frame_checksum": 2, "frame_header": 3, "magic": 2, "skippable_payload": 2},
                "native_summary_error_lz4_error_counts": {"ChecksumMismatch": 1, "CorruptFrame": 2, "TruncatedFrame": 4},
                "native_summary_error_zstd_error_counts": {"CorruptFrame": 2, "InvalidMagic": 1, "TruncatedFrame": 4},
                "native_summary_error_lz4_phase_counts": {"frame": 1, "frame_body": 1, "frame_checksum": 1, "frame_header": 2, "magic": 1, "skippable_payload": 1},
                "native_summary_error_zstd_phase_counts": {"frame": 1, "frame_body": 1, "frame_checksum": 1, "magic": 1, "skippable_payload": 1},
                "native_summary_error_offset_min": 0,
                "native_summary_error_offset_max": 32,
                "native_summary_error_lz4_offset_min": 0,
                "native_summary_error_lz4_offset_max": 32,
                "native_summary_error_zstd_offset_min": 0,
                "native_summary_error_zstd_offset_max": 13,
                "native_summary_error_phase_offset_ranges": {"frame": {"min": 7, "max": 7}, "frame_body": {"min": 9, "max": 9}, "frame_checksum": {"min": 15, "max": 15}, "frame_header": {"min": 5, "max": 5}, "magic": {"min": 0, "max": 7}, "skippable_payload": {"min": 13, "max": 13}},
                "native_summary_error_required_codec_phases": {"lz4": ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"], "zstd": ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"]},
                "native_summary_error_lz4_missing_phases": [],
                "native_summary_error_zstd_missing_phases": [],
                "native_summary_error_negative_present": True,
                "native_summary_error_negative_healthy": True,
                "native_summary_error_negative_case_count": 3,
                "lz4_native_summary_present": True,
                "lz4_native_summary_healthy": True,
                "lz4_native_summary_frame_count": 2,
                "lz4_native_summary_skippable_frame_count": 1,
                "lz4_native_summary_checksum_frame_count": 2,
                "lz4_native_summary_block_checksum_frame_count": 1,
                "lz4_native_summary_dictionary_id_frame_count": 1,
                "lz4_native_summary_content_size_frame_count": 2,
                "lz4_native_summary_declared_content_bytes": 6,
                "lz4_native_summary_block_count": 2,
                "lz4_native_summary_raw_block_count": 2,
                "lz4_native_summary_compressed_block_count": 0,
                "lz4_native_summary_compressed_bytes": 64,
                "lz4_native_summary_payload_bytes": 6,
                "lz4_native_summary_skippable_payload_bytes": 16,
                "zstd_native_summary_present": True,
                "zstd_native_summary_healthy": True,
                "zstd_native_summary_frame_count": 2,
                "zstd_native_summary_skippable_frame_count": 1,
                "zstd_native_summary_checksum_frame_count": 1,
                "zstd_native_summary_dictionary_id_frame_count": 1,
                "zstd_native_summary_content_size_frame_count": 2,
                "zstd_native_summary_declared_content_bytes": 6,
                "zstd_native_summary_block_count": 2,
                "zstd_native_summary_raw_block_count": 2,
                "zstd_native_summary_rle_block_count": 0,
                "zstd_native_summary_compressed_block_count": 0,
                "zstd_native_summary_compressed_bytes": 48,
                "zstd_native_summary_payload_bytes": 6,
                "zstd_native_summary_skippable_payload_bytes": 16,
                "native_tier_range_present": True,
                "native_tier_range_healthy": True,
                "native_tier_range_summary_count": 1,
                "native_tier_range_ok_count": 1,
                "native_tier_range_rows": 9,
                "native_tier_range_fixture_count": 3,
                "native_tier_range_enforced_count": 1,
                "native_tier_range_built_in_summary_count": 1,
                "native_tier_range_project_files_summary_count": 1,
                "native_tier_range_standard_corpus_summary_count": 1,
                "native_tier_range_custom_summary_count": 0,
                "native_tier_range_legacy_summary_count": 0,
                "native_tier_range_built_in_rows": 9,
                "native_tier_range_project_files_rows": 6,
                "native_tier_range_standard_corpus_rows": 9,
                "native_tier_range_custom_rows": 0,
                "native_tier_range_legacy_rows": 0,
                "native_tier_range_missing_sources": [],
                "native_tier_corpus_discovery_present": True,
                "native_tier_corpus_discovery_ok": True,
                "native_tier_corpus_discovery_healthy": True,
                "native_tier_corpus_discovery_source_mode": "discovered",
                "native_tier_corpus_discovery_full": False,
                "native_tier_corpus_discovery_limit": 3,
                "native_tier_corpus_discovery_candidate_count": 5,
                "native_tier_corpus_discovery_source_count": 1,
                "native_tier_corpus_discovery_sources": ["/tmp/silesia-small.tar"],
                "native_tier_corpus_discovery_selected_case_count": 3,
                "native_tier_corpus_discovery_selected_cases": [
                    {"label": "ooffice-128k", "bytes": 131072},
                    {"label": "nci-128k", "bytes": 131072},
                    {"label": "mozilla-128k", "bytes": 131072},
                ],
                "native_tier_corpus_discovery_csv": "zig-out/vort-native-tier-range-corpus-bench.csv",
                "native_tier_corpus_discovery_missing_reason": "",
                "native_tier_range_source_details": [
                    {
                        "source": "built_in",
                        "summary_count": 1,
                        "ok_count": 1,
                        "rows": 9,
                        "fixture_count": 3,
                        "enforced_count": 1,
                        "missing": False,
                        "min_range_mib_s_by_tier": {"seek_fast": 80.0, "balanced": 25.0, "ratio": 20.0},
                        "range_mib_s_floor_by_tier": {"seek_fast": 60.0, "balanced": 16.0, "ratio": 12.0},
                    },
                    {
                        "source": "project_files",
                        "summary_count": 1,
                        "ok_count": 1,
                        "rows": 6,
                        "fixture_count": 2,
                        "enforced_count": 1,
                        "missing": False,
                        "min_range_mib_s_by_tier": {"seek_fast": 70.0, "balanced": 20.0, "ratio": 12.0},
                        "range_mib_s_floor_by_tier": {"seek_fast": 40.0, "balanced": 8.0, "ratio": 4.0},
                    },
                    {
                        "source": "standard_corpus",
                        "summary_count": 1,
                        "ok_count": 1,
                        "rows": 9,
                        "fixture_count": 3,
                        "enforced_count": 1,
                        "missing": False,
                        "min_range_mib_s_by_tier": {"seek_fast": 60.0, "balanced": 18.0, "ratio": 9.0},
                        "range_mib_s_floor_by_tier": {"seek_fast": 30.0, "balanced": 6.5, "ratio": 3.5},
                    },
                    {
                        "source": "custom",
                        "summary_count": 0,
                        "ok_count": 0,
                        "rows": 0,
                        "fixture_count": 0,
                        "enforced_count": 0,
                        "missing": False,
                        "min_range_mib_s_by_tier": {"seek_fast": 0.0, "balanced": 0.0, "ratio": 0.0},
                        "range_mib_s_floor_by_tier": {"seek_fast": 0.0, "balanced": 0.0, "ratio": 0.0},
                    },
                    {
                        "source": "legacy",
                        "summary_count": 0,
                        "ok_count": 0,
                        "rows": 0,
                        "fixture_count": 0,
                        "enforced_count": 0,
                        "missing": False,
                        "min_range_mib_s_by_tier": {"seek_fast": 0.0, "balanced": 0.0, "ratio": 0.0},
                        "range_mib_s_floor_by_tier": {"seek_fast": 0.0, "balanced": 0.0, "ratio": 0.0},
                    },
                ],
                "native_tier_range_seek_fast_min_range_mib_s": 80.0,
                "native_tier_range_balanced_min_range_mib_s": 25.0,
                "native_tier_range_ratio_min_range_mib_s": 20.0,
                "native_tier_range_seek_fast_min_full_input_mib_s": 700.0,
                "native_tier_range_balanced_min_full_input_mib_s": 250.0,
                "native_tier_range_ratio_min_full_input_mib_s": 180.0,
                "artifacts": [
                    {
                        "name": "vort-huffman-length-report.csv",
                        "path": "vort-huffman-length-report.csv",
                        "category": "validation",
                        "format": "csv",
                        "expected_format": "csv",
                        "producer_step": "zig build run-huffman-length-report-dashboard",
                        "producer_missing_allowed": False,
                        "smoke_gate": "zig build run-huffman-length-report-dashboard",
                        "size_bytes": 1,
                        "mtime_utc": "2026-07-15T00:00:00Z",
                        "schema": None,
                        "schema_version": None,
                        "rows": 0,
                        "ok": None,
                        "required_workflow_count": None,
                        "missing_workflow_count": None,
                    }
                ],
            }
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(
            negative_case(
                "boolean_formula_positive_field",
                "huffman_length_healthy=True does not match boolean formula",
                boolean_formula_positive_field,
            )
        )

        def boolean_formula_empty_string_field() -> None:
            payload = dashboard_index_doc_example()
            payload.update(
                {
                    "native_tier_corpus_discovery_present": True,
                    "native_tier_corpus_discovery_ok": True,
                    "native_tier_corpus_discovery_healthy": True,
                    "native_tier_corpus_discovery_source_mode": "discovered",
                    "native_tier_corpus_discovery_candidate_count": 5,
                    "native_tier_corpus_discovery_source_count": 1,
                    "native_tier_corpus_discovery_sources": ["/tmp/silesia-small.tar"],
                    "native_tier_corpus_discovery_selected_case_count": 1,
                    "native_tier_corpus_discovery_selected_cases": [{"label": "ooffice-128k", "bytes": 131072}],
                    "native_tier_corpus_discovery_missing_reason": "stale_summary",
                }
            )
            docs_check.validate_value_against_manifest(payload, schemas_def)

        cases.append(
            negative_case(
                "boolean_formula_empty_string_field",
                "native_tier_corpus_discovery_healthy=True does not match boolean formula",
                boolean_formula_empty_string_field,
            )
        )

    summary = {
        "schema": "vort.validation_json_docs_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in cases),
        "case_count": len(cases),
        "cases": cases,
    }
    docs_check.validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json(path, summary)

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"validation_json_docs_negative_smoke=ok cases={summary['case_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
