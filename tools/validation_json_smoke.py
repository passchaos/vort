#!/usr/bin/env python3
"""Smoke-test Vort validation JSON schemas.

The build step passes the freshly built CLI and sidecar-report executables. This
script keeps the schema checks independent from shell quoting and verifies both
successful and failing validation JSON records.
"""

from __future__ import annotations

import json
import csv
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from validation_json_docs_check import load_manifest, validate_value_against_manifest

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_INDEX = ROOT / "tools" / "dashboard_index.py"


def run(args: list[str], *, check: bool = True, stdout: int | None = subprocess.PIPE) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=stdout, stderr=subprocess.STDOUT)


def first_json_line(text: str) -> dict:
    for line in text.splitlines():
        if line.startswith("{"):
            return json.loads(line)
    raise AssertionError(f"no JSON object found in output:\n{text}")


def write_huffman_length_csv(path: Path) -> None:
    row = {
        "case": "validation-json-smoke",
        "symbol_count": "3",
        "max_bits": "2",
        "optimal_cost": "5",
        "actual_cost": "5",
        "gap_bits": "0",
        "kraft_cost": "4",
        "kraft_limit": "4",
        "optimal": "true",
        "lengths": "1;2;2",
        "optimal_lengths": "1;2;2",
        "package_merge_cost": "5",
        "package_merge_gap_bits": "0",
        "package_merge_optimal": "true",
        "package_merge_lengths": "1;2;2",
    }
    columns = list(row)
    path.write_text(",".join(columns) + "\n" + ",".join(row[column] for column in columns) + "\n")


def write_huffman_length_markdown(path: Path) -> None:
    # Keep this fixture in lockstep with the CSV row above so the dashboard
    # smoke covers Markdown/CSV drift instead of only artifact presence.
    path.write_text(
        "\n".join(
            [
                "# Huffman length smoke",
                "",
                "- rows: 1",
                "- optimal rows: 1",
                "- non-optimal rows: 0",
                "- worst gap bits: 0",
                "",
                "- package-merge optimal rows: 1",
                "- package-merge non-optimal rows: 0",
                "- package-merge worst gap bits: 0",
                "",
            ]
        )
        + "\n"
    )


def main() -> int:
    if len(sys.argv) not in (3, 5):
        print("usage: validation_json_smoke.py <vort-cli> <sidecar-report> [--summary <path>]", file=sys.stderr)
        return 2

    cli = sys.argv[1]
    report_exe = sys.argv[2]
    summary_path: Path | None = None
    if len(sys.argv) == 5:
        if sys.argv[3] != "--summary":
            print("usage: validation_json_smoke.py <vort-cli> <sidecar-report> [--summary <path>]", file=sys.stderr)
            return 2
        summary_path = Path(sys.argv[4])

    summary: dict[str, object] = {
        "schema": "vort.validation_json_smoke",
        "schema_version": 1,
        "ok": False,
        "checked_schemas": [],
    }
    schemas_def = load_manifest()
    with tempfile.TemporaryDirectory(prefix="vort-validation-json-") as tmp:
        root = Path(tmp)
        input_path = root / "input.txt"
        stream_path = root / "stream.vort"
        bad_stream_path = root / "stream-bad.vort"
        sidecar_path = root / "stream.vidx"
        report_path = root / "vort-sidecar-verify-report.json"
        corrupt_path = root / "vort-sidecar-corrupt-smoke.json"
        dashboard_path = root / "vort-dashboard-index.md"
        dashboard_manifest_path = root / "vort-dashboard-index.json"
        docs_negative_path = root / "vort-validation-json-docs-negative-smoke.json"
        dashboard_category_negative_path = root / "vort-dashboard-category-negative-smoke.json"
        dashboard_config_index_path = root / "vort-dashboard-config-index-smoke.json"
        dashboard_config_index_negative_path = root / "vort-dashboard-config-index-negative-smoke.json"
        native_tier_corpus_discovery_path = root / "vort-native-tier-range-corpus-discovery.json"
        huffman_length_csv_path = root / "vort-huffman-length-report.csv"
        huffman_length_markdown_path = root / "vort-huffman-length-report.md"
        level_report_csv_path = ROOT / "zig-out" / "vort-level-report.csv"
        level_report_markdown_path = ROOT / "zig-out" / "vort-level-report.md"
        fuzz_report_path = ROOT / "zig-out" / "vort-deflate-wrapper-fuzz-corpus.json"
        fuzz_coverage_path = ROOT / "tools" / "fuzz_corpus_expected_coverage.json"
        fuzz_coverage_smoke_path = ROOT / "zig-out" / "vort-fuzz-corpus-coverage-smoke.json"
        decode_stage_path = ROOT / "zig-out" / "vort-deflate-decode-stage-report.json"
        decode_stage_csv_path = ROOT / "zig-out" / "vort-deflate-decode-stage-report.csv"
        checksum_bench_path = ROOT / "zig-out" / "vort-checksum-bench.csv"
        chunk_cursor_bench_path = ROOT / "zig-out" / "vort-chunk-cursor-bench.csv"
        deflate_match_copy_bench_path = ROOT / "zig-out" / "vort-deflate-match-copy-bench.csv"
        deflate_huffman_build_bench_path = ROOT / "zig-out" / "vort-deflate-huffman-build-bench.csv"
        deflate_huffman_lookup_bench_path = ROOT / "zig-out" / "vort-deflate-huffman-lookup-bench.csv"
        deflate_chunked_huffman_bench_path = ROOT / "zig-out" / "vort-deflate-chunked-huffman-bench.csv"
        deflate_extra_bits_bench_path = ROOT / "zig-out" / "vort-deflate-extra-bits-bench.csv"
        dictionary_decode_bench_path = ROOT / "zig-out" / "vort-dictionary-decode-bench.csv"
        png_scanline_bench_path = ROOT / "zig-out" / "vort-png-scanline-bench.csv"
        chunked_zlib_bench_path = ROOT / "zig-out" / "vort-chunked-zlib-bench-report-repeat3.csv"
        png_streaming_zlib_bench_path = ROOT / "zig-out" / "vort-png-streaming-zlib-bench-report-repeat3.csv"
        deflate_dynamic_decode_profile_path = ROOT / "zig-out" / "vort-deflate-dynamic-decode-profile.csv"
        python_zlib_diff_path = ROOT / "zig-out" / "vort-python-zlib-diff-smoke.json"
        native_codec_probes_path = ROOT / "zig-out" / "vort-native-codec-probes.json"
        native_summary_error_dashboard_path = ROOT / "zig-out" / "vort-native-summary-error-dashboard.json"
        native_summary_error_negative_path = ROOT / "zig-out" / "vort-native-summary-error-negative-smoke.json"
        lz4_native_summary_path = ROOT / "zig-out" / "vort-lz4-native-stream-summary.json"
        zstd_native_summary_path = ROOT / "zig-out" / "vort-zstd-native-stream-summary.json"
        zlib_relaxed_path = ROOT / "zig-out" / "vort-zlib-relaxed-report.json"
        zlib_relaxed_gate_path = ROOT / "zig-out" / "vort-zlib-relaxed-report-gate.json"
        snappy_report_path = ROOT / "zig-out" / "vort-snappy-report.csv"
        native_allocation_path = ROOT / "zig-out" / "vort-native-allocation-report.json"
        native_library_bench_path = ROOT / "zig-out" / "vort-native-library-bench.csv"
        native_allocation_smoke_path = ROOT / "zig-out" / "vort-native-allocation-smoke.json"
        native_allocation_negative_smoke_path = ROOT / "zig-out" / "vort-native-allocation-negative-smoke.json"
        png_scratch_path = ROOT / "zig-out" / "vort-png-scratch-report.json"
        input_bytes = (b"validation json schema smoke\n" * 64) + (b"abcdef" * 128)
        input_path.write_bytes(input_bytes)

        run([cli, "encode-vort-sidecar-best-file", str(input_path), str(stream_path), str(sidecar_path), "256"])

        ok = json.loads(run([cli, "verify-vort-sidecar-index-file", str(stream_path), str(sidecar_path), "full", "json"]).stdout)
        assert ok["schema"] == "vort.validation_report"
        assert ok["schema_version"] == 1
        assert ok["target"] == "sidecar"
        assert ok["ok"] is True
        validate_value_against_manifest(ok, schemas_def)

        bad = bytearray(stream_path.read_bytes())
        bad[32] ^= 1
        bad_stream_path.write_bytes(bad)
        failed = run(
            [cli, "verify-vort-sidecar-index-file", str(bad_stream_path), str(sidecar_path), "full", "json"],
            check=False,
        )
        assert failed.returncode != 0
        failure = first_json_line(failed.stdout)
        assert failure["schema"] == "vort.validation_report"
        assert failure["schema_version"] == 1
        assert failure["ok"] is False
        assert failure["recoverability_hint"] == "payload_corrupt"
        assert failure["frame_mode"]
        validate_value_against_manifest(failure, schemas_def)

        run([report_exe, "--json", str(report_path), str(stream_path), str(sidecar_path)])
        report = json.loads(report_path.read_text())
        assert report["schema"] == "vort.sidecar_verify_report"
        assert report["schema_version"] == 1
        assert report["rows"] == 1
        validate_value_against_manifest(report, schemas_def)

        run([report_exe, "--self-test-corrupt", "--json", str(corrupt_path)])
        corrupt = json.loads(corrupt_path.read_text())
        assert corrupt["schema"] == "vort.sidecar_corrupt_smoke_report"
        assert corrupt["schema_version"] == 1
        assert corrupt["rows"] >= 1
        validate_value_against_manifest(corrupt, schemas_def)

        dashboard_config_index = json.loads((ROOT / "tools" / "dashboard_config_index.json").read_text())
        assert dashboard_config_index["schema"] == "vort.dashboard_config_index"
        assert dashboard_config_index["configs"]
        validate_value_against_manifest(dashboard_config_index, schemas_def)
        br_static_dictionary_candidate_report = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-candidates.json").read_text())
        assert br_static_dictionary_candidate_report["schema"] == "vort.br_static_dictionary_candidate_report"
        assert br_static_dictionary_candidate_report["source_mode"] == "anchors"
        assert br_static_dictionary_candidate_report["source_limit"] == 0
        assert br_static_dictionary_candidate_report["upstream_raw_word_count"] == 0
        assert br_static_dictionary_candidate_report["candidate_count"] >= 1
        assert br_static_dictionary_candidate_report["candidates"]
        assert sum(row["candidate_count"] for row in br_static_dictionary_candidate_report["kind_rows"]) == br_static_dictionary_candidate_report["candidate_count"]
        assert sum(row["candidate_count"] for row in br_static_dictionary_candidate_report["length_rows"]) == br_static_dictionary_candidate_report["candidate_count"]
        validate_value_against_manifest(br_static_dictionary_candidate_report, schemas_def)
        br_static_dictionary_candidate_upstream = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-candidate-upstream-smoke.json").read_text())
        assert br_static_dictionary_candidate_upstream["schema"] == "vort.br_static_dictionary_candidate_upstream_smoke"
        assert br_static_dictionary_candidate_upstream["ok"] is True
        assert br_static_dictionary_candidate_upstream["source_mode"] == "upstream"
        assert br_static_dictionary_candidate_upstream["source_limit"] == 8
        assert br_static_dictionary_candidate_upstream["upstream_raw_word_count"] == 8
        validate_value_against_manifest(br_static_dictionary_candidate_upstream, schemas_def)
        br_static_dictionary_node_probe = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-node-probe.json").read_text())
        assert br_static_dictionary_node_probe["schema"] == "vort.br_static_dictionary_node_probe"
        assert br_static_dictionary_node_probe["ok"] is True
        assert br_static_dictionary_node_probe["candidate_source_mode"] == "anchors"
        assert br_static_dictionary_node_probe["candidate_source_limit"] == 0
        assert br_static_dictionary_node_probe["candidate_upstream_raw_word_count"] == 0
        assert br_static_dictionary_node_probe["all_candidates"] is False
        assert br_static_dictionary_node_probe["start_index"] == 0
        assert br_static_dictionary_node_probe["probed_count"] >= 1
        assert br_static_dictionary_node_probe["node_decode_successes"] == br_static_dictionary_node_probe["probed_count"]
        assert br_static_dictionary_node_probe["kind_rows"]
        assert br_static_dictionary_node_probe["size_rows"]
        assert sum(row["probed_count"] for row in br_static_dictionary_node_probe["kind_rows"]) == br_static_dictionary_node_probe["probed_count"]
        assert sum(row["probed_count"] for row in br_static_dictionary_node_probe["size_rows"]) == br_static_dictionary_node_probe["probed_count"]
        assert br_static_dictionary_node_probe["size_winner_count"] == len(br_static_dictionary_node_probe["size_winner_rows"])
        assert all(row["size_class"] == "smaller" for row in br_static_dictionary_node_probe["size_winner_rows"])
        validate_value_against_manifest(br_static_dictionary_node_probe, schemas_def)
        br_static_dictionary_required = json.loads((ROOT / "tools" / "br_static_dictionary_required_coverage.json").read_text())
        assert br_static_dictionary_required["schema"] == "vort.br_static_dictionary_required_coverage"
        assert br_static_dictionary_required["entries"]
        validate_value_against_manifest(br_static_dictionary_required, schemas_def)
        br_static_dictionary_source_anchors = json.loads((ROOT / "tools" / "br_static_dictionary_source_anchors.json").read_text())
        assert br_static_dictionary_source_anchors["schema"] == "vort.br_static_dictionary_source_anchors"
        assert br_static_dictionary_source_anchors["entry_count"] == len(br_static_dictionary_source_anchors["entries"])
        assert br_static_dictionary_source_anchors["entry_count"] >= len(br_static_dictionary_required["entries"])
        validate_value_against_manifest(br_static_dictionary_source_anchors, schemas_def)
        br_static_dictionary_source_audit = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-source-audit.json").read_text())
        assert br_static_dictionary_source_audit["schema"] == "vort.br_static_dictionary_source_audit"
        assert br_static_dictionary_source_audit["ok"] is True
        assert br_static_dictionary_source_audit["entry_count"] == br_static_dictionary_source_anchors["entry_count"]
        assert br_static_dictionary_source_audit["anchor_count"] == br_static_dictionary_source_anchors["entry_count"]
        assert br_static_dictionary_source_audit["generated_table_matches_source"] is True
        assert br_static_dictionary_source_audit["generated_zig_bytes"] > 0
        assert br_static_dictionary_source_audit["generated_zig_path"].endswith("vort-br-static-dictionary-generated.zig")
        validate_value_against_manifest(br_static_dictionary_source_audit, schemas_def)
        br_static_dictionary_source_audit_negative = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-source-audit-negative-smoke.json").read_text())
        assert br_static_dictionary_source_audit_negative["schema"] == "vort.br_static_dictionary_source_audit_negative_smoke"
        assert br_static_dictionary_source_audit_negative["ok"] is True
        assert br_static_dictionary_source_audit_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in br_static_dictionary_source_audit_negative["cases"])
        validate_value_against_manifest(br_static_dictionary_source_audit_negative, schemas_def)
        br_static_dictionary_report = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-report.json").read_text())
        assert br_static_dictionary_report["schema"] == "vort.br_static_dictionary_report"
        assert br_static_dictionary_report["entry_count"] == len(br_static_dictionary_report["entries"])
        assert br_static_dictionary_report["entry_count"] > 0
        assert sum(br_static_dictionary_report["category_counts"].values()) == br_static_dictionary_report["entry_count"]
        assert sum(row["total"] for row in br_static_dictionary_report["matrix_rows"]) == br_static_dictionary_report["entry_count"]
        validate_value_against_manifest(br_static_dictionary_report, schemas_def)
        with (ROOT / "zig-out" / "vort-br-static-dictionary-report.csv").open(newline="") as f:
            br_static_dictionary_report_csv = list(csv.DictReader(f))
        assert len(br_static_dictionary_report_csv) == br_static_dictionary_report["entry_count"]
        br_static_dictionary_report_markdown = (ROOT / "zig-out" / "vort-br-static-dictionary-report.md").read_text()
        assert f"- Entries: {br_static_dictionary_report['entry_count']}" in br_static_dictionary_report_markdown
        br_static_dictionary_report_negative = json.loads((ROOT / "zig-out" / "vort-br-static-dictionary-report-negative-smoke.json").read_text())
        assert br_static_dictionary_report_negative["schema"] == "vort.br_static_dictionary_report_negative_smoke"
        assert br_static_dictionary_report_negative["ok"] is True
        assert br_static_dictionary_report_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in br_static_dictionary_report_negative["cases"])
        validate_value_against_manifest(br_static_dictionary_report_negative, schemas_def)
        dashboard_producers = json.loads((ROOT / "tools" / "dashboard_producers.json").read_text())
        assert dashboard_producers["schema"] == "vort.dashboard_producers"
        validate_value_against_manifest(dashboard_producers, schemas_def)
        fuzz_report = json.loads(fuzz_report_path.read_text())
        assert fuzz_report["schema"] == "vort.fuzz_corpus_report"
        assert fuzz_report["schema_version"] == 1
        assert fuzz_report["ok"] is True
        assert fuzz_report["cases"] >= 1
        assert fuzz_report["exact_error_expectations"] >= 1
        assert fuzz_report["matched_rows"] == fuzz_report["cases"]
        validate_value_against_manifest(fuzz_report, schemas_def)
        fuzz_coverage = json.loads(fuzz_coverage_path.read_text())
        assert fuzz_coverage["schema"] == "vort.fuzz_corpus_expected_coverage"
        assert fuzz_coverage["mode_requirements"]
        assert fuzz_coverage["error_requirements"]
        validate_value_against_manifest(fuzz_coverage, schemas_def)
        fuzz_coverage_smoke = json.loads(fuzz_coverage_smoke_path.read_text())
        assert fuzz_coverage_smoke["schema"] == "vort.fuzz_corpus_coverage_smoke"
        assert fuzz_coverage_smoke["ok"] is True
        assert fuzz_coverage_smoke["mode_requirement_count"] == len(fuzz_coverage["mode_requirements"])
        assert fuzz_coverage_smoke["error_requirement_count"] == len(fuzz_coverage["error_requirements"])
        validate_value_against_manifest(fuzz_coverage_smoke, schemas_def)
        with decode_stage_csv_path.open(newline="") as f:
            decode_stage_csv_rows = list(csv.DictReader(f))
        assert len(decode_stage_csv_rows) == 10
        decode_stage = json.loads(decode_stage_path.read_text())
        assert decode_stage["schema"] == "vort.deflate_decode_stage_report"
        assert decode_stage["schema_version"] == 1
        assert decode_stage["ok"] is True
        assert decode_stage["rows"] >= 1
        assert decode_stage["error_rows"] >= 1
        assert decode_stage["matched_error_rows"] == decode_stage["error_rows"]
        assert decode_stage["unmatched_error_rows"] == 0
        validate_value_against_manifest(decode_stage, schemas_def)
        python_zlib_diff = json.loads(python_zlib_diff_path.read_text())
        assert python_zlib_diff["schema"] == "vort.python_zlib_diff_smoke"
        assert python_zlib_diff["schema_version"] == 3
        assert python_zlib_diff["ok"] is True
        assert python_zlib_diff["payloads"] >= 1
        assert python_zlib_diff["large_file_payloads"] >= 1
        assert python_zlib_diff["file_hex_encode_cases"] >= 1
        assert python_zlib_diff["match_heavy_payloads"] >= 1
        assert python_zlib_diff["dynamic_payloads"] >= 1
        assert python_zlib_diff["dictionary_cases"] >= 1
        assert python_zlib_diff["zlib_dict_encode_cases"] >= 1
        assert python_zlib_diff["raw_dict_encode_cases"] >= 1
        assert python_zlib_diff["cli_successes"] >= 1
        assert python_zlib_diff["expected_failures"] >= 1
        validate_value_against_manifest(python_zlib_diff, schemas_def)
        native_codec_probes = json.loads(native_codec_probes_path.read_text())
        assert native_codec_probes["schema"] == "vort.native_codec_probes"
        assert native_codec_probes["schema_version"] == 1
        assert native_codec_probes["ok"] is True
        assert native_codec_probes["probe_count"] == 4
        assert native_codec_probes["coverage_count"] == 4
        assert native_codec_probes["capability_count"] >= 10
        assert native_codec_probes["total_cases"] >= 4
        assert all(probe["ok"] is True for probe in native_codec_probes["probes"])
        assert all(probe["timed_out"] is False for probe in native_codec_probes["probes"])
        assert all(probe["timeout_seconds"] > 0 for probe in native_codec_probes["probes"])
        assert all(probe["reported_capability_count"] == len(probe["reported_capabilities"]) for probe in native_codec_probes["probes"])
        assert all(probe["reported_capability_count"] >= 1 for probe in native_codec_probes["probes"])
        assert all(set(probe["reported_capabilities"]) == set(probe["reported_capability_cases"]) for probe in native_codec_probes["probes"])
        coverage_by_key = {
            (row["codec"], row["surface"]): row
            for row in native_codec_probes["coverage"]
        }
        assert set(coverage_by_key) == {
            ("lz4", "frame"),
            ("lz4", "dictionary"),
            ("zstd", "frame"),
            ("zstd", "dictionary"),
        }
        assert all(row["present"] is True for row in coverage_by_key.values())
        assert all(row["ok"] is True for row in coverage_by_key.values())
        assert all(row["probe_count"] == 1 for row in coverage_by_key.values())
        assert all(row["ok_probe_count"] == 1 for row in coverage_by_key.values())
        assert sum(row["cases"] for row in coverage_by_key.values()) == native_codec_probes["total_cases"]
        capabilities_by_name = {
            row["capability"]: row
            for row in native_codec_probes["capabilities"]
        }
        for capability in (
            "lib-generated",
            "native-generated",
            "incremental",
            "chunked",
            "reusable-chunked",
            "fse-repeat",
            "dictionary",
            "dictionary-training",
            "dictionary-set",
            "skippable",
            "malformed",
            "checksum",
            "bounded-limits",
            "huffman",
            "sequence-tables",
            "block",
        ):
            assert capabilities_by_name[capability]["present"] is True
            assert capabilities_by_name[capability]["ok"] is True
            assert capabilities_by_name[capability]["probe_count"] >= 1
            assert capabilities_by_name[capability]["ok_probe_count"] == capabilities_by_name[capability]["probe_count"]
            assert capabilities_by_name[capability]["cases"] >= 1
        validate_value_against_manifest(native_codec_probes, schemas_def)
        native_summary_error_dashboard = json.loads(native_summary_error_dashboard_path.read_text())
        assert native_summary_error_dashboard["schema"] == "vort.native_summary_error_dashboard"
        assert native_summary_error_dashboard["schema_version"] == 1
        assert native_summary_error_dashboard["ok"] is True
        assert native_summary_error_dashboard["case_count"] >= 14
        assert native_summary_error_dashboard["lz4_case_count"] >= 7
        assert native_summary_error_dashboard["zstd_case_count"] >= 7
        assert native_summary_error_dashboard["error_counts"]["ChecksumMismatch"] >= 1
        assert native_summary_error_dashboard["error_counts"]["CorruptFrame"] >= 4
        assert native_summary_error_dashboard["error_counts"]["TruncatedFrame"] >= 8
        assert native_summary_error_dashboard["phase_counts"]["magic"] >= 2
        assert native_summary_error_dashboard["phase_counts"]["skippable_payload"] >= 2
        assert native_summary_error_dashboard["phase_counts"]["frame_body"] >= 2
        assert native_summary_error_dashboard["phase_counts"]["frame_checksum"] >= 2
        assert native_summary_error_dashboard["phase_counts"]["frame"] >= 2
        validate_value_against_manifest(native_summary_error_dashboard, schemas_def)
        native_summary_error_negative = json.loads(native_summary_error_negative_path.read_text())
        assert native_summary_error_negative["schema"] == "vort.native_summary_error_negative_smoke"
        assert native_summary_error_negative["ok"] is True
        assert native_summary_error_negative["case_count"] >= 14
        assert all(row["matched"] is True for row in native_summary_error_negative["cases"])
        validate_value_against_manifest(native_summary_error_negative, schemas_def)
        lz4_native_summary = json.loads(lz4_native_summary_path.read_text())
        assert lz4_native_summary["schema"] == "vort.lz4_native_stream_summary"
        assert lz4_native_summary["schema_version"] == 1
        assert lz4_native_summary["frame_count"] >= 2
        assert lz4_native_summary["skippable_frame_count"] >= 1
        assert lz4_native_summary["content_size_frame_count"] >= 2
        assert lz4_native_summary["checksum_frame_count"] >= 2
        assert lz4_native_summary["block_checksum_frame_count"] >= 1
        assert lz4_native_summary["dictionary_id_frame_count"] >= 1
        assert lz4_native_summary["declared_content_bytes"] >= lz4_native_summary["payload_bytes"]
        assert lz4_native_summary["block_count"] >= 2
        assert lz4_native_summary["raw_block_count"] >= 1
        assert lz4_native_summary["compressed_bytes"] > 0
        assert lz4_native_summary["payload_bytes"] > 0
        assert lz4_native_summary["skippable_payload_bytes"] > 0
        validate_value_against_manifest(lz4_native_summary, schemas_def)

        native_summary_error_cases = [
            ("summary-lz4-native-file", root / "bad-lz4-summary.lz4", b"not-lz4", "vort.lz4_native_stream_summary_error", "CorruptFrame", "magic", 0),
            ("summary-zstd-native-file", root / "bad-zstd-summary.zst", b"not-zstd", "vort.zstd_native_stream_summary_error", "InvalidMagic", "magic", 0),
        ]
        native_summary_error_payloads: list[dict[str, object]] = []
        for command, path, payload, schema_name, error_name, phase, offset in native_summary_error_cases:
            path.write_bytes(payload)
            result = run([cli, command, str(path), "json"], check=False)
            assert result.returncode != 0
            error_payload = json.loads(result.stdout)
            assert error_payload["schema"] == schema_name
            assert error_payload["schema_version"] == 1
            assert error_payload["ok"] is False
            assert error_payload["compressed_bytes"] == len(payload)
            assert error_payload["error"] == error_name
            assert error_payload["phase"] == phase
            assert error_payload["offset"] == offset
            validate_value_against_manifest(error_payload, schemas_def)
            native_summary_error_payloads.append(error_payload)

        zstd_native_summary = json.loads(zstd_native_summary_path.read_text())
        assert zstd_native_summary["schema"] == "vort.zstd_native_stream_summary"
        assert zstd_native_summary["schema_version"] == 1
        assert zstd_native_summary["frame_count"] >= 2
        assert zstd_native_summary["skippable_frame_count"] >= 1
        assert zstd_native_summary["checksum_frame_count"] >= 1
        assert zstd_native_summary["dictionary_id_frame_count"] >= 1
        assert zstd_native_summary["content_size_frame_count"] >= 2
        assert zstd_native_summary["declared_content_bytes"] >= zstd_native_summary["payload_bytes"]
        assert zstd_native_summary["block_count"] >= 2
        assert zstd_native_summary["raw_block_count"] >= 1
        assert zstd_native_summary["compressed_bytes"] > 0
        assert zstd_native_summary["payload_bytes"] > 0
        assert zstd_native_summary["skippable_payload_bytes"] > 0
        validate_value_against_manifest(zstd_native_summary, schemas_def)
        zlib_relaxed = json.loads(zlib_relaxed_path.read_text())
        assert zlib_relaxed["schema"] == "vort.zlib_relaxed_report"
        assert zlib_relaxed["schema_version"] >= 2
        assert zlib_relaxed["strict_rejections"] >= 2
        assert zlib_relaxed["relaxed_successes"] >= 5
        assert zlib_relaxed["dictionary_successes"] >= 2
        assert zlib_relaxed["zlib_concatenated_successes"] >= 3
        assert zlib_relaxed["zlib_decoder_successes"] >= 8
        assert zlib_relaxed["limited_rejections"] >= 1
        assert zlib_relaxed["gzip_strict_rejections"] >= 3
        assert zlib_relaxed["gzip_relaxed_successes"] >= 9
        assert zlib_relaxed["gzip_concatenated_successes"] >= 4
        assert zlib_relaxed["gzip_decoder_successes"] >= 4
        assert zlib_relaxed["gzip_limited_rejections"] >= 1
        validate_value_against_manifest(zlib_relaxed, schemas_def)
        zlib_relaxed_gate = json.loads(zlib_relaxed_gate_path.read_text())
        assert zlib_relaxed_gate["schema"] == "vort.zlib_relaxed_report_gate"
        assert zlib_relaxed_gate["ok"] is True
        assert all(zlib_relaxed_gate["checks"].values())
        with checksum_bench_path.open(newline="") as f:
            checksum_bench_rows = list(csv.DictReader(f))
        assert len(checksum_bench_rows) == 21
        with chunk_cursor_bench_path.open(newline="") as f:
            chunk_cursor_bench_rows = list(csv.DictReader(f))
        assert len(chunk_cursor_bench_rows) == 8
        with deflate_match_copy_bench_path.open(newline="") as f:
            deflate_match_copy_bench_rows = list(csv.DictReader(f))
        assert len(deflate_match_copy_bench_rows) == 21
        with deflate_huffman_build_bench_path.open(newline="") as f:
            deflate_huffman_build_bench_rows = list(csv.DictReader(f))
        assert len(deflate_huffman_build_bench_rows) == 14
        with deflate_huffman_lookup_bench_path.open(newline="") as f:
            deflate_huffman_lookup_bench_rows = list(csv.DictReader(f))
        assert len(deflate_huffman_lookup_bench_rows) == 21
        with deflate_chunked_huffman_bench_path.open(newline="") as f:
            deflate_chunked_huffman_bench_rows = list(csv.DictReader(f))
        assert len(deflate_chunked_huffman_bench_rows) == 57
        with deflate_extra_bits_bench_path.open(newline="") as f:
            deflate_extra_bits_bench_rows = list(csv.DictReader(f))
        assert len(deflate_extra_bits_bench_rows) == 105
        with dictionary_decode_bench_path.open(newline="") as f:
            dictionary_decode_bench_rows = list(csv.DictReader(f))
        assert len(dictionary_decode_bench_rows) == 18
        with png_scanline_bench_path.open(newline="") as f:
            png_scanline_bench_rows = list(csv.DictReader(f))
        assert len(png_scanline_bench_rows) == 30
        with chunked_zlib_bench_path.open(newline="") as f:
            chunked_zlib_bench_rows = list(csv.DictReader(f))
        assert len(chunked_zlib_bench_rows) == 8
        with png_streaming_zlib_bench_path.open(newline="") as f:
            png_streaming_zlib_bench_rows = list(csv.DictReader(f))
        assert len(png_streaming_zlib_bench_rows) == 10
        with deflate_dynamic_decode_profile_path.open(newline="") as f:
            deflate_dynamic_decode_profile_rows = list(csv.DictReader(f))
        assert len(deflate_dynamic_decode_profile_rows) >= 3
        assert {"README.md", "docs/roadmap.md", "chunked-window-match"}.issubset({row["case"] for row in deflate_dynamic_decode_profile_rows})
        with snappy_report_path.open(newline="") as f:
            snappy_report_rows = list(csv.DictReader(f))
        assert len(snappy_report_rows) == 20
        with native_library_bench_path.open(newline="") as f:
            native_library_bench_rows = list(csv.DictReader(f))
        assert len(native_library_bench_rows) == 93
        native_allocation = json.loads(native_allocation_path.read_text())
        assert native_allocation["schema"] == "vort.native_allocation_report"
        assert native_allocation["schema_version"] == 1
        assert native_allocation["case_count"] >= 1
        assert native_allocation["cases"]
        validate_value_against_manifest(native_allocation, schemas_def)
        native_allocation_smoke = json.loads(native_allocation_smoke_path.read_text())
        assert native_allocation_smoke["schema"] == "vort.native_allocation_smoke"
        assert native_allocation_smoke["schema_version"] == 1
        assert native_allocation_smoke["ok"] is True
        assert native_allocation_smoke["required_zero_allocation_cases"] >= 1
        assert native_allocation_smoke["cases"]
        validate_value_against_manifest(native_allocation_smoke, schemas_def)
        native_allocation_negative_smoke = json.loads(native_allocation_negative_smoke_path.read_text())
        assert native_allocation_negative_smoke["schema"] == "vort.native_allocation_negative_smoke"
        assert native_allocation_negative_smoke["schema_version"] == 1
        assert native_allocation_negative_smoke["ok"] is True
        assert native_allocation_negative_smoke["case_count"] >= 1
        assert native_allocation_negative_smoke["cases"]
        validate_value_against_manifest(native_allocation_negative_smoke, schemas_def)
        png_scratch = json.loads(png_scratch_path.read_text())
        assert png_scratch["schema"] == "vort.png_scratch_report"
        assert png_scratch["schema_version"] == 1
        assert png_scratch["case_count"] >= 1
        assert png_scratch["cases"]
        assert any(case["interlace"] == "adam7" for case in png_scratch["cases"])
        assert all(case["stored_streaming_status"] == "achieved" for case in png_scratch["cases"])
        assert all(case["fixed_dynamic_streaming_status"] == "achieved" for case in png_scratch["cases"])
        assert all(case["fixed_dynamic_history_scratch_bytes"] == 32768 for case in png_scratch["cases"])
        assert all(
            case["fixed_dynamic_streaming_working_scratch_bytes"]
            == case["fixed_dynamic_history_scratch_bytes"] + case["filtered_row_scratch_bytes"] + case["previous_row_scratch_bytes"]
            for case in png_scratch["cases"]
        )
        assert all(case["streaming_working_scratch_bytes"] < case["working_scratch_bytes"] for case in png_scratch["cases"])
        assert all(case["streaming_scratch_savings_bytes"] == case["zlib_scratch_bytes"] for case in png_scratch["cases"])
        assert all(case["streaming_total_caller_owned_bytes"] < case["total_caller_owned_bytes"] for case in png_scratch["cases"])
        assert all(
            case["fixed_dynamic_streaming_total_caller_owned_bytes"]
            == case["fixed_dynamic_streaming_working_scratch_bytes"] + case["image_output_bytes"]
            for case in png_scratch["cases"]
        )
        validate_value_against_manifest(png_scratch, schemas_def)
        run([
            "python3",
            str(ROOT / "tools" / "dashboard_config_index_smoke.py"),
            "--summary",
            str(dashboard_config_index_path),
        ])
        dashboard_config_index_smoke = json.loads(dashboard_config_index_path.read_text())
        assert dashboard_config_index_smoke["schema"] == "vort.dashboard_config_index_smoke"
        assert dashboard_config_index_smoke["ok"] is True
        assert dashboard_config_index_smoke["config_count"] == dashboard_config_index["config_count"]
        assert all(row["matched"] is True for row in dashboard_config_index_smoke["configs"])
        validate_value_against_manifest(dashboard_config_index_smoke, schemas_def)

        run([
            "python3",
            str(ROOT / "tools" / "dashboard_config_index_negative_smoke.py"),
            "--summary",
            str(dashboard_config_index_negative_path),
        ])
        dashboard_config_index_negative = json.loads(dashboard_config_index_negative_path.read_text())
        assert dashboard_config_index_negative["schema"] == "vort.dashboard_config_index_negative_smoke"
        assert dashboard_config_index_negative["ok"] is True
        assert dashboard_config_index_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in dashboard_config_index_negative["cases"])
        validate_value_against_manifest(dashboard_config_index_negative, schemas_def)

        dashboard_category_expected = json.loads((ROOT / "tools" / "dashboard_category_expected_artifacts.json").read_text())
        assert dashboard_category_expected["schema"] == "vort.dashboard_category_expected_artifacts"
        assert dashboard_category_expected["expected_artifacts"]
        validate_value_against_manifest(dashboard_category_expected, schemas_def)
        native_tier_corpus_discovery = {
            "schema": "vort.native_tier_range_corpus_discovery",
            "schema_version": 1,
            "ok": True,
            "source_mode": "paths",
            "full": False,
            "limit": 2,
            "candidate_count": 1,
            "source_count": 1,
            "sources": ["README.md"],
            "selected_case_count": 1,
            "selected_cases": [{"label": "README.md-128k", "bytes": 1024}],
            "csv": "zig-out/vort-native-tier-range-corpus-bench.csv",
            "missing_reason": "",
        }
        native_tier_corpus_discovery_path.write_text(json.dumps(native_tier_corpus_discovery, indent=2, sort_keys=True) + "\n")
        validate_value_against_manifest(native_tier_corpus_discovery, schemas_def)
        dashboard_strict_modes = json.loads((ROOT / "tools" / "dashboard_strict_expected_modes.json").read_text())
        assert dashboard_strict_modes["schema"] == "vort.dashboard_strict_expected_modes"
        assert dashboard_strict_modes["expected_modes"]
        validate_value_against_manifest(dashboard_strict_modes, schemas_def)
        dashboard_strict_reasons = json.loads((ROOT / "tools" / "dashboard_strict_validation_reasons.json").read_text())
        assert dashboard_strict_reasons["schema"] == "vort.dashboard_strict_validation_reasons"
        assert dashboard_strict_reasons["expected_reasons"]
        validate_value_against_manifest(dashboard_strict_reasons, schemas_def)
        dashboard_strict_path = root / "vort-dashboard-strict-smoke.json"
        dashboard_strict_markdown_path = root / "vort-dashboard-strict-smoke.md"
        dashboard_producers_negative_path = root / "vort-dashboard-producers-negative-smoke.json"
        dashboard_producers_required_path = root / "vort-dashboard-producers-required-smoke.json"
        run([
            "python3",
            str(ROOT / "tools" / "dashboard_strict_smoke.py"),
            "--summary",
            str(dashboard_strict_path),
            "--markdown",
            str(dashboard_strict_markdown_path),
        ])
        dashboard_strict = json.loads(dashboard_strict_path.read_text())
        assert dashboard_strict["schema"] == "vort.dashboard_strict_smoke"
        assert dashboard_strict["ok"] is True
        assert dashboard_strict["check_count"] >= 1
        assert dashboard_strict["mode_count"] >= 1
        assert dashboard_strict["expected_mode_count"] >= 1
        assert dashboard_strict["missing_mode_count"] == 0
        assert dashboard_strict["missing_modes"] == []
        assert dashboard_strict["mode_requirements"]
        assert all(row["missing_checks"] == 0 and row["missing_expected_failures"] == 0 and row["missing_matched"] == 0 for row in dashboard_strict["mode_requirements"])
        assert sum(row["checks"] for row in dashboard_strict["mode_counts"]) == dashboard_strict["check_count"]
        assert any(row["mode"] == "strict-header-inspect" and row["checks"] >= 1 for row in dashboard_strict["mode_counts"])
        expected_validation_reasons = set(
            schemas_def["vort.dashboard_index"]["list_item_enums"]["validation_unhealthy_reasons"]
        )
        configured_validation_reasons = {row["reason"] for row in dashboard_strict_reasons["expected_reasons"]}
        covered_validation_reasons = {row["reason"] for row in dashboard_strict["validation_unhealthy_reason_checks"]}
        assert configured_validation_reasons == expected_validation_reasons
        assert dashboard_strict["validation_unhealthy_reason_count"] == len(expected_validation_reasons)
        assert covered_validation_reasons == expected_validation_reasons
        assert all(row["matched"] is True for row in dashboard_strict["validation_unhealthy_reason_checks"])
        assert any(row["mode"] == "strict-validation-health" and row["checks"] >= len(expected_validation_reasons) for row in dashboard_strict["mode_counts"])
        assert any(row["mode"] == "dashboard-markdown" and row["checks"] >= 20 and row["matched"] >= 20 for row in dashboard_strict["mode_counts"])
        assert any(row["name"] == "dashboard_artifact_inventory_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "validation_unhealthy_reasons_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "producer_smoke_gate_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "dashboard_strict_mode_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "dashboard_configuration_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "validation_json_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_summary_success_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_summary_error_markdown_tables" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_tier_range_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_tier_discovery_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_codec_probe_markdown_tables" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "header_inspect_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "sidecar_corrupt_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "huffman_length_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "zstd_compare_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "native_allocation_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "zlib_relaxed_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "snappy_report_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "python_zlib_diff_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "decode_stage_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert any(row["name"] == "fuzz_corpus_markdown_table" and row["matched"] is True for row in dashboard_strict["checks"])
        assert all(
            "expected_output" in row
            and "actual_output" in row
            and "actual_output_bytes" in row
            and "actual_output_limit" in row
            and "actual_output_truncated" in row
            and "returncode" in row
            for row in dashboard_strict["checks"]
        )
        assert any(row["actual_output_truncated"] is True for row in dashboard_strict["checks"])
        dashboard_strict_markdown = dashboard_strict_markdown_path.read_text()
        assert "missing_header_workflow" in dashboard_strict_markdown
        assert "dashboard_artifact_inventory_markdown_table" in dashboard_strict_markdown
        assert "validation_unhealthy_reasons_markdown_table" in dashboard_strict_markdown
        assert "producer_smoke_gate_markdown_table" in dashboard_strict_markdown
        assert "dashboard_strict_mode_markdown_table" in dashboard_strict_markdown
        assert "dashboard_configuration_markdown_table" in dashboard_strict_markdown
        assert "validation_json_markdown_table" in dashboard_strict_markdown
        assert "native_summary_success_markdown_table" in dashboard_strict_markdown
        assert "native_summary_error_markdown_tables" in dashboard_strict_markdown
        assert "native_tier_range_markdown_table" in dashboard_strict_markdown
        assert "native_tier_discovery_markdown_table" in dashboard_strict_markdown
        assert "native_codec_probe_markdown_tables" in dashboard_strict_markdown
        assert "header_inspect_markdown_table" in dashboard_strict_markdown
        assert "sidecar_corrupt_markdown_table" in dashboard_strict_markdown
        assert "huffman_length_markdown_table" in dashboard_strict_markdown
        assert "zstd_compare_markdown_table" in dashboard_strict_markdown
        assert "native_allocation_markdown_table" in dashboard_strict_markdown
        assert "zlib_relaxed_markdown_table" in dashboard_strict_markdown
        assert "snappy_report_markdown_table" in dashboard_strict_markdown
        assert "python_zlib_diff_markdown_table" in dashboard_strict_markdown
        assert "decode_stage_markdown_table" in dashboard_strict_markdown
        assert "fuzz_corpus_markdown_table" in dashboard_strict_markdown
        assert "validation_missing_dashboard_strict_modes" in dashboard_strict_markdown
        validate_value_against_manifest(dashboard_strict, schemas_def)

        run([
            "python3",
            str(ROOT / "tools" / "dashboard_producers_negative_smoke.py"),
            "--summary",
            str(dashboard_producers_negative_path),
        ])
        dashboard_producers_negative = json.loads(dashboard_producers_negative_path.read_text())
        assert dashboard_producers_negative["schema"] == "vort.dashboard_producers_negative_smoke"
        assert dashboard_producers_negative["ok"] is True
        assert dashboard_producers_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in dashboard_producers_negative["cases"])
        validate_value_against_manifest(dashboard_producers_negative, schemas_def)

        dashboard_producers_required = json.loads((ROOT / "tools" / "dashboard_producers_required_artifacts.json").read_text())
        assert dashboard_producers_required["schema"] == "vort.dashboard_producers_required_artifacts"
        assert dashboard_producers_required["required_artifacts"]
        validate_value_against_manifest(dashboard_producers_required, schemas_def)
        run([
            "python3",
            str(ROOT / "tools" / "dashboard_producers_required_smoke.py"),
            "--summary",
            str(dashboard_producers_required_path),
        ])
        dashboard_producers_required_smoke = json.loads(dashboard_producers_required_path.read_text())
        assert dashboard_producers_required_smoke["schema"] == "vort.dashboard_producers_required_smoke"
        assert dashboard_producers_required_smoke["ok"] is True
        assert dashboard_producers_required_smoke["artifact_count"] == len(dashboard_producers_required["required_artifacts"])
        assert all(row["matched"] is True for row in dashboard_producers_required_smoke["cases"])
        validate_value_against_manifest(dashboard_producers_required_smoke, schemas_def)

        run([
            "python3",
            str(ROOT / "tools" / "dashboard_category_negative_smoke.py"),
            "--summary",
            str(dashboard_category_negative_path),
        ])
        dashboard_category_negative = json.loads(dashboard_category_negative_path.read_text())
        assert dashboard_category_negative["schema"] == "vort.dashboard_category_negative_smoke"
        assert dashboard_category_negative["ok"] is True
        assert dashboard_category_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in dashboard_category_negative["cases"])
        validate_value_against_manifest(dashboard_category_negative, schemas_def)

        run([
            "python3",
            str(ROOT / "tools" / "validation_json_docs_negative_smoke.py"),
            "--summary",
            str(docs_negative_path),
        ])
        docs_negative = json.loads(docs_negative_path.read_text())
        assert docs_negative["schema"] == "vort.validation_json_docs_negative_smoke"
        assert docs_negative["ok"] is True
        assert docs_negative["case_count"] >= 1
        assert all(row["matched"] is True for row in docs_negative["cases"])
        validate_value_against_manifest(docs_negative, schemas_def)
        validation_json_dashboard_smoke = {
            "schema": "vort.validation_json_smoke",
            "schema_version": 1,
            "ok": True,
            "checked_schemas": [
                ok["schema"],
                report["schema"],
                corrupt["schema"],
                dashboard_strict["schema"],
                docs_negative["schema"],
                "vort.dashboard_index",
                "vort.header_inspect_smoke",
            ],
            "cli_success_ok": ok["ok"],
            "cli_failure_ok": failure["ok"],
            "cli_failure_hint": failure["recoverability_hint"],
            "report_rows": report["rows"],
            "corrupt_rows": corrupt["rows"],
        }
        (root / "vort-validation-json-smoke.json").write_text(json.dumps(validation_json_dashboard_smoke, indent=2, sort_keys=True) + "\n")
        validate_value_against_manifest(validation_json_dashboard_smoke, schemas_def)

        header_summary_path = root / "vort-header-inspect-smoke.json"
        required_workflows = json.loads((ROOT / "tools" / "header_inspect_required_workflows.json").read_text())
        assert required_workflows["schema"] == "vort.header_inspect_required_workflows"
        assert required_workflows["required_workflows"]
        validate_value_against_manifest(required_workflows, schemas_def)
        raw_header = json.loads(run([cli, "inspect-raw-header-hex", "cb48cdc9c90700", "json"]).stdout)
        assert raw_header["schema"] == "vort.raw_deflate_header_info"
        assert raw_header["schema_version"] == 1
        assert raw_header["block_type"] == "fixed"
        validate_value_against_manifest(raw_header, schemas_def)
        zlib_header = json.loads(run([cli, "inspect-zlib-header-hex", "7801cb48cdc9c90700062c0215", "json"]).stdout)
        assert zlib_header["schema"] == "vort.zlib_header_info"
        assert zlib_header["schema_version"] == 1
        assert zlib_header["window_bits"] == 15
        validate_value_against_manifest(zlib_header, schemas_def)
        wrapped_zlib_header = json.loads(run([cli, "inspect-zlib-deflate-header-hex", "7801cb48cdc9c90700062c0215", "json"]).stdout)
        assert wrapped_zlib_header["schema"] == "vort.wrapped_deflate_header_info"
        assert wrapped_zlib_header["schema_version"] == 1
        assert wrapped_zlib_header["wrapper"] == "zlib"
        assert wrapped_zlib_header["scope"] == "zlib_stream"
        assert wrapped_zlib_header["member_index"] == 0
        assert wrapped_zlib_header["deflate_span_kind"] == "header_tail"
        assert wrapped_zlib_header["stream_footer_offset"] > wrapped_zlib_header["deflate_offset"]
        assert wrapped_zlib_header["stream_deflate_bytes"] == wrapped_zlib_header["stream_footer_offset"] - wrapped_zlib_header["deflate_offset"]
        assert wrapped_zlib_header["exact_deflate_bytes"] == wrapped_zlib_header["stream_deflate_bytes"]
        assert wrapped_zlib_header["stream_output_bytes"] == 5
        assert wrapped_zlib_header["stream_end_offset"] == wrapped_zlib_header["stream_footer_offset"] + 4
        assert wrapped_zlib_header["stream_end_offset"] == wrapped_zlib_header["wrapper_bytes"]
        assert wrapped_zlib_header["stream_footer_adler32"] == 0x062C0215
        assert wrapped_zlib_header["stream_adler32"] == wrapped_zlib_header["stream_footer_adler32"]
        assert wrapped_zlib_header["stream_adler32_matches"] is True
        for key in (
            "member_deflate_bytes",
            "member_output_bytes",
            "member_footer_offset",
            "member_end_offset",
            "member_footer_crc32",
            "member_crc32",
            "member_crc32_matches",
            "member_footer_isize",
            "member_isize",
            "member_isize_matches",
        ):
            assert wrapped_zlib_header[key] is None
        assert wrapped_zlib_header["raw_header"]["schema"] == "vort.raw_deflate_header_info"
        validate_value_against_manifest(wrapped_zlib_header, schemas_def)
        wrapped_zlib_dict_header_without_dict = json.loads(
            run([cli, "inspect-zlib-deflate-header-hex", "78f908610235cb4027013a2e067d", "json"]).stdout
        )
        assert wrapped_zlib_dict_header_without_dict["wrapper"] == "zlib"
        assert wrapped_zlib_dict_header_without_dict["exact_deflate_bytes"] is None
        assert wrapped_zlib_dict_header_without_dict["stream_deflate_bytes"] is None
        validate_value_against_manifest(wrapped_zlib_dict_header_without_dict, schemas_def)
        wrapped_zlib_dict_header = json.loads(
            run([cli, "inspect-zlib-dict-deflate-header-hex", "78f908610235cb4027013a2e067d", "hello ", "json"]).stdout
        )
        assert wrapped_zlib_dict_header["schema"] == "vort.wrapped_deflate_header_info"
        assert wrapped_zlib_dict_header["wrapper"] == "zlib"
        assert wrapped_zlib_dict_header["stream_output_bytes"] == len("hello hello hello")
        assert wrapped_zlib_dict_header["exact_deflate_bytes"] == wrapped_zlib_dict_header["stream_deflate_bytes"]
        assert wrapped_zlib_dict_header["stream_end_offset"] == wrapped_zlib_dict_header["wrapper_bytes"]
        assert wrapped_zlib_dict_header["stream_adler32_matches"] is True
        validate_value_against_manifest(wrapped_zlib_dict_header, schemas_def)
        wrapped_gzip_header = json.loads(
            run([cli, "inspect-gzip-deflate-header-hex", "1f8b0800000000000403cb48cdc9c9070086a6103605000000", "json"]).stdout
        )
        assert wrapped_gzip_header["schema"] == "vort.wrapped_deflate_header_info"
        assert wrapped_gzip_header["schema_version"] == 1
        assert wrapped_gzip_header["wrapper"] == "gzip"
        assert wrapped_gzip_header["scope"] == "gzip_member"
        assert wrapped_gzip_header["member_index"] == 0
        assert wrapped_gzip_header["deflate_span_kind"] == "header_tail"
        for key in (
            "stream_deflate_bytes",
            "stream_output_bytes",
            "stream_footer_offset",
            "stream_end_offset",
            "stream_footer_adler32",
            "stream_adler32",
            "stream_adler32_matches",
        ):
            assert wrapped_gzip_header[key] is None
        assert wrapped_gzip_header["member_footer_offset"] > wrapped_gzip_header["deflate_offset"]
        assert wrapped_gzip_header["member_deflate_bytes"] == wrapped_gzip_header["member_footer_offset"] - wrapped_gzip_header["deflate_offset"]
        assert wrapped_gzip_header["exact_deflate_bytes"] == wrapped_gzip_header["member_deflate_bytes"]
        assert wrapped_gzip_header["member_output_bytes"] == 5
        assert wrapped_gzip_header["member_end_offset"] == wrapped_gzip_header["member_footer_offset"] + 8
        assert wrapped_gzip_header["member_end_offset"] == wrapped_gzip_header["wrapper_bytes"]
        assert wrapped_gzip_header["member_footer_crc32"] == 0x3610A686
        assert wrapped_gzip_header["member_crc32"] == wrapped_gzip_header["member_footer_crc32"]
        assert wrapped_gzip_header["member_crc32_matches"] is True
        assert wrapped_gzip_header["member_footer_isize"] == 5
        assert wrapped_gzip_header["member_isize"] == 5
        assert wrapped_gzip_header["member_isize_matches"] is True
        assert wrapped_gzip_header["raw_header"]["schema"] == "vort.raw_deflate_header_info"
        validate_value_against_manifest(wrapped_gzip_header, schemas_def)
        gzip_header = json.loads(
            run([cli, "inspect-gzip-header-hex", "1f8b0800000000000403cb48cdc9c9070086a6103605000000", "json"]).stdout
        )
        assert gzip_header["schema"] == "vort.gzip_header_info"
        assert gzip_header["schema_version"] == 1
        assert gzip_header["mtime"] == 0
        validate_value_against_manifest(gzip_header, schemas_def)
        run(["python3", str(ROOT / "tools" / "header_inspect_smoke.py"), cli, "--summary", str(header_summary_path)])
        header_summary = json.loads(header_summary_path.read_text())
        assert header_summary["schema"] == "vort.header_inspect_smoke"
        assert header_summary["schema_version"] == 1
        assert header_summary["ok"] is True
        assert header_summary["raw_cases"] >= 1
        assert header_summary["cases"][0]["schema_name"] in (
            "vort.raw_deflate_header_info",
            "vort.zlib_header_info",
            "vort.gzip_header_info",
        )
        assert header_summary["cases"][0]["command"].startswith("inspect-")
        assert header_summary["cases"][0]["sample"]
        assert header_summary["cases"][0]["detail"]
        assert header_summary["cases"][0]["argv"] == [
            header_summary["cases"][0]["command"],
            header_summary["cases"][0]["sample"],
        ]
        assert header_summary["negative_cases"] >= 1
        assert header_summary["raw_negative_cases"] >= 1
        assert len(header_summary["negative_items"]) == header_summary["negative_cases"]
        assert header_summary["negative_items"][0]["matched"] is True
        assert header_summary["negative_items"][0]["argv"] == [
            header_summary["negative_items"][0]["command"],
            header_summary["negative_items"][0]["sample"],
        ]
        assert header_summary["dictionary_cases"] >= 1
        assert header_summary["optional_header_cases"] >= 1
        assert header_summary["help_workflow_count"] == header_summary["required_workflow_count"]
        assert {(row["command"], row["workflow"]) for row in header_summary["help_workflows"]} == {
            (row["command"], row["workflow"]) for row in header_summary["required_workflows"]
        }
        validate_value_against_manifest(header_summary, schemas_def)
        write_huffman_length_csv(huffman_length_csv_path)
        write_huffman_length_markdown(huffman_length_markdown_path)
        shutil.copyfile(level_report_csv_path, root / "vort-level-report.csv")
        shutil.copyfile(level_report_markdown_path, root / "vort-level-report.md")
        shutil.copyfile(checksum_bench_path, root / "vort-checksum-bench.csv")
        shutil.copyfile(chunk_cursor_bench_path, root / "vort-chunk-cursor-bench.csv")
        shutil.copyfile(deflate_match_copy_bench_path, root / "vort-deflate-match-copy-bench.csv")
        shutil.copyfile(deflate_huffman_build_bench_path, root / "vort-deflate-huffman-build-bench.csv")
        shutil.copyfile(deflate_huffman_lookup_bench_path, root / "vort-deflate-huffman-lookup-bench.csv")
        shutil.copyfile(deflate_chunked_huffman_bench_path, root / "vort-deflate-chunked-huffman-bench.csv")
        shutil.copyfile(deflate_extra_bits_bench_path, root / "vort-deflate-extra-bits-bench.csv")
        shutil.copyfile(dictionary_decode_bench_path, root / "vort-dictionary-decode-bench.csv")
        shutil.copyfile(png_scanline_bench_path, root / "vort-png-scanline-bench.csv")
        shutil.copyfile(chunked_zlib_bench_path, root / "vort-chunked-zlib-bench-report-repeat3.csv")
        shutil.copyfile(png_streaming_zlib_bench_path, root / "vort-png-streaming-zlib-bench-report-repeat3.csv")
        shutil.copyfile(deflate_dynamic_decode_profile_path, root / "vort-deflate-dynamic-decode-profile.csv")
        shutil.copyfile(fuzz_report_path, root / "vort-deflate-wrapper-fuzz-corpus.json")
        shutil.copyfile(fuzz_coverage_smoke_path, root / "vort-fuzz-corpus-coverage-smoke.json")
        shutil.copyfile(decode_stage_path, root / "vort-deflate-decode-stage-report.json")
        shutil.copyfile(decode_stage_csv_path, root / "vort-deflate-decode-stage-report.csv")
        for artifact_name in (
            "vort-zstd-compare-gate.json",
            "vort-zstd-compare-standard-gate.json",
            "vort-zstd-compare-block-sweep-gate.json",
            "vort-native-fuzz-corpus.json",
            "vort-native-fuzz-corpus-coverage-smoke.json",
            "vort-br-static-dictionary-candidates.json",
            "vort-br-static-dictionary-candidate-upstream-smoke.json",
            "vort-br-static-dictionary-node-probe.json",
            "vort-br-static-dictionary-source-audit.json",
            "vort-br-static-dictionary-source-audit-negative-smoke.json",
            "vort-br-static-dictionary-report.csv",
            "vort-br-static-dictionary-report.json",
            "vort-br-static-dictionary-report.md",
            "vort-br-static-dictionary-report-negative-smoke.json",
            "vort-native-tier-range-bench.csv",
            "vort-native-tier-range-files-bench.csv",
            "vort-native-tier-range-corpus-bench.csv",
        ):
            shutil.copyfile(ROOT / "zig-out" / artifact_name, root / artifact_name)
        shutil.copyfile(zlib_relaxed_path, root / "vort-zlib-relaxed-report.json")
        shutil.copyfile(zlib_relaxed_gate_path, root / "vort-zlib-relaxed-report-gate.json")
        shutil.copyfile(snappy_report_path, root / "vort-snappy-report.csv")
        shutil.copyfile(png_scratch_path, root / "vort-png-scratch-report.json")
        shutil.copyfile(native_library_bench_path, root / "vort-native-library-bench.csv")
        shutil.copyfile(native_allocation_path, root / "vort-native-allocation-report.json")
        shutil.copyfile(native_allocation_smoke_path, root / "vort-native-allocation-smoke.json")
        shutil.copyfile(native_allocation_negative_smoke_path, root / "vort-native-allocation-negative-smoke.json")
        shutil.copyfile(python_zlib_diff_path, root / "vort-python-zlib-diff-smoke.json")
        shutil.copyfile(native_codec_probes_path, root / "vort-native-codec-probes.json")
        shutil.copyfile(native_summary_error_dashboard_path, root / "vort-native-summary-error-dashboard.json")
        shutil.copyfile(native_summary_error_negative_path, root / "vort-native-summary-error-negative-smoke.json")
        shutil.copyfile(lz4_native_summary_path, root / "vort-lz4-native-stream-summary.json")
        shutil.copyfile(zstd_native_summary_path, root / "vort-zstd-native-stream-summary.json")

        run(
            [
                "python3",
                str(DASHBOARD_INDEX),
                "--dir",
                str(root),
                "--output",
                str(dashboard_path),
                "--manifest",
                str(dashboard_manifest_path),
                "--strict-header-inspect",
            ]
        )
        dashboard = json.loads(dashboard_manifest_path.read_text())
        assert dashboard["schema"] == "vort.dashboard_index"
        assert dashboard["schema_version"] == 1
        assert dashboard["artifact_count"] >= 3
        assert dashboard["producer_healthy"] == (len(dashboard["producer_step_missing"]) == 0)
        assert dashboard["smoke_gate_healthy"] == (len(dashboard["smoke_gate_required_missing"]) == 0)
        assert dashboard["header_inspect_present"] is True
        assert dashboard["header_inspect_ok"] is True
        assert dashboard["header_inspect_healthy"] is True
        assert dashboard["header_inspect_required_workflow_count"] == header_summary["required_workflow_count"]
        assert dashboard["header_inspect_missing_workflow_count"] == header_summary["missing_workflow_count"]
        assert dashboard["header_inspect_missing_workflows"] == header_summary["missing_workflows"]
        assert dashboard["header_inspect_case_count"] == header_summary["case_count"]
        assert dashboard["header_inspect_raw_cases"] == header_summary["raw_cases"]
        assert dashboard["header_inspect_zlib_cases"] == header_summary["zlib_cases"]
        assert dashboard["header_inspect_gzip_cases"] == header_summary["gzip_cases"]
        assert dashboard["header_inspect_negative_cases"] == header_summary["negative_cases"]
        assert dashboard["header_inspect_raw_negative_cases"] == header_summary["raw_negative_cases"]
        assert dashboard["header_inspect_zlib_negative_cases"] == header_summary["zlib_negative_cases"]
        assert dashboard["header_inspect_gzip_negative_cases"] == header_summary["gzip_negative_cases"]
        assert dashboard["header_inspect_command_count"] == header_summary["command_count"]
        assert dashboard["header_inspect_command_successes"] == header_summary["command_successes"]
        assert dashboard["header_inspect_command_failures"] == header_summary["command_failures"]
        assert dashboard["header_inspect_workflow_count"] == header_summary["workflow_count"]
        assert dashboard["header_inspect_workflow_successes"] == header_summary["workflow_successes"]
        assert dashboard["header_inspect_dictionary_cases"] == header_summary["dictionary_cases"]
        assert dashboard["header_inspect_optional_header_cases"] == header_summary["optional_header_cases"]
        assert dashboard["header_inspect_fhcrc_cases"] == header_summary["fhcrc_cases"]
        assert dashboard["dashboard_strict_present"] is True
        assert dashboard["dashboard_strict_ok"] is True
        assert dashboard["dashboard_strict_healthy"] is True
        assert dashboard["dashboard_strict_check_count"] == dashboard_strict["check_count"]
        assert dashboard["dashboard_strict_mode_count"] == dashboard_strict["mode_count"]
        assert dashboard["dashboard_strict_expected_failure_count"] == sum(row["expected_failures"] for row in dashboard_strict["mode_counts"])
        assert dashboard["dashboard_strict_matched_count"] == sum(row["matched"] for row in dashboard_strict["mode_counts"])
        assert dashboard["dashboard_strict_expected_mode_count"] == dashboard_strict["expected_mode_count"]
        assert dashboard["dashboard_strict_missing_mode_count"] == dashboard_strict["missing_mode_count"]
        assert dashboard["dashboard_strict_missing_checks"] == sum(row["missing_checks"] for row in dashboard_strict["mode_requirements"])
        assert dashboard["dashboard_strict_missing_expected_failures"] == sum(row["missing_expected_failures"] for row in dashboard_strict["mode_requirements"])
        assert dashboard["dashboard_strict_missing_matched"] == sum(row["missing_matched"] for row in dashboard_strict["mode_requirements"])
        assert dashboard["dashboard_strict_missing_modes"] == dashboard_strict["missing_modes"]
        assert dashboard["dashboard_configuration_healthy"] is True
        assert dashboard["dashboard_config_index_present"] is True
        assert dashboard["dashboard_config_index_ok"] is True
        assert dashboard["dashboard_config_index_config_count"] == dashboard_config_index_smoke["config_count"]
        assert dashboard["dashboard_config_index_matched"] == dashboard_config_index_smoke["config_count"]
        assert dashboard["dashboard_config_index_unmatched"] == 0
        assert dashboard["dashboard_config_index_negative_present"] is True
        assert dashboard["dashboard_config_index_negative_ok"] is True
        assert dashboard["dashboard_config_index_negative_case_count"] == dashboard_config_index_negative["case_count"]
        assert dashboard["dashboard_config_index_negative_matched"] == dashboard_config_index_negative["case_count"]
        assert dashboard["dashboard_config_index_negative_unmatched"] == 0
        assert dashboard["dashboard_category_negative_present"] is True
        assert dashboard["dashboard_category_negative_ok"] is True
        assert dashboard["dashboard_category_negative_case_count"] == dashboard_category_negative["case_count"]
        assert dashboard["dashboard_category_negative_matched"] == dashboard_category_negative["case_count"]
        assert dashboard["dashboard_category_negative_unmatched"] == 0
        assert dashboard["dashboard_producers_required_present"] is True
        assert dashboard["dashboard_producers_required_ok"] is True
        assert dashboard["dashboard_producers_required_artifact_count"] == dashboard_producers_required_smoke["artifact_count"]
        assert dashboard["dashboard_producers_required_matched"] == dashboard_producers_required_smoke["artifact_count"]
        assert dashboard["dashboard_producers_required_unmatched"] == 0
        assert dashboard["dashboard_producers_required_smoke_gate_count"] == dashboard_producers_required_smoke["required_smoke_gate_count"]
        assert dashboard["dashboard_producers_negative_present"] is True
        assert dashboard["dashboard_producers_negative_ok"] is True
        assert dashboard["dashboard_producers_negative_case_count"] == dashboard_producers_negative["case_count"]
        assert dashboard["dashboard_producers_negative_matched"] == dashboard_producers_negative["case_count"]
        assert dashboard["dashboard_producers_negative_unmatched"] == 0
        assert dashboard["validation_json_present"] is True
        assert dashboard["validation_json_ok"] is True
        assert dashboard["validation_json_healthy"] is True
        assert dashboard["validation_json_checked_schema_count"] == len(validation_json_dashboard_smoke["checked_schemas"])
        assert dashboard["validation_json_cli_success_ok"] == validation_json_dashboard_smoke["cli_success_ok"]
        assert dashboard["validation_json_cli_failure_ok"] == validation_json_dashboard_smoke["cli_failure_ok"]
        assert dashboard["validation_json_cli_failure_hint"] == validation_json_dashboard_smoke["cli_failure_hint"]
        assert dashboard["validation_json_report_rows"] == validation_json_dashboard_smoke["report_rows"]
        assert dashboard["validation_json_corrupt_rows"] == validation_json_dashboard_smoke["corrupt_rows"]
        assert dashboard["validation_json_docs_negative_present"] is True
        assert dashboard["validation_json_docs_negative_ok"] is True
        assert dashboard["validation_json_docs_negative_case_count"] == docs_negative["case_count"]
        assert dashboard["validation_json_docs_negative_matched"] == docs_negative["case_count"]
        assert dashboard["validation_json_docs_negative_unmatched"] == 0
        assert dashboard["sidecar_corrupt_present"] is True
        assert dashboard["sidecar_corrupt_healthy"] is True
        assert dashboard["sidecar_corrupt_rows"] == corrupt["rows"]
        assert dashboard["sidecar_corrupt_metadata_ok_rows"] == corrupt["metadata_ok_rows"]
        assert dashboard["sidecar_corrupt_full_rejected_rows"] == corrupt["full_rejected_rows"]
        assert dashboard["sidecar_corrupt_metadata_failed_rows"] == 0
        assert dashboard["sidecar_corrupt_full_not_rejected_rows"] == 0
        assert dashboard["huffman_length_present"] is True
        assert dashboard["huffman_length_healthy"] is True
        assert dashboard["huffman_length_row_count"] == 1
        assert dashboard["huffman_length_optimal_rows"] == 1
        assert dashboard["huffman_length_non_optimal_rows"] == 0
        assert dashboard["huffman_length_malformed_rows"] == 0
        assert dashboard["huffman_length_worst_gap_bits"] == 0
        assert dashboard["huffman_length_package_merge_optimal_rows"] == 1
        assert dashboard["huffman_length_package_merge_non_optimal_rows"] == 0
        assert dashboard["huffman_length_package_merge_worst_gap_bits"] == 0
        assert dashboard["huffman_length_markdown_present"] is True
        assert dashboard["huffman_length_markdown_summary_rows"] == 7
        assert dashboard["huffman_length_markdown_matched"] == 7
        assert dashboard["huffman_length_markdown_unmatched"] == 0
        assert dashboard["level_report_present"] is True
        assert dashboard["level_report_healthy"] is True
        assert dashboard["level_report_rows"] == 48
        assert dashboard["level_report_expected_rows"] == 48
        assert dashboard["level_report_positive_rows"] == 48
        assert dashboard["level_report_shape_rows"] == 48
        assert dashboard["level_report_token_accounting_rows"] == 48
        assert dashboard["level_report_ratio_rows"] == 48
        assert dashboard["level_report_roundtrip_rows"] == 48
        assert dashboard["level_report_missing_pairs"] == []
        assert dashboard["level_report_markdown_present"] is True
        assert dashboard["level_report_markdown_summary_rows"] == 4
        assert dashboard["level_report_markdown_matched"] == 4
        assert dashboard["level_report_markdown_unmatched"] == 0
        assert dashboard["fuzz_corpus_present"] is True
        assert dashboard["fuzz_corpus_ok"] is True
        assert dashboard["fuzz_corpus_coverage_present"] is True
        assert dashboard["fuzz_corpus_coverage_ok"] is True
        assert dashboard["fuzz_corpus_healthy"] is True
        assert dashboard["fuzz_corpus_cases"] == fuzz_report["cases"]
        assert dashboard["fuzz_corpus_matched_rows"] == fuzz_report["matched_rows"]
        assert dashboard["fuzz_corpus_unmatched_rows"] == 0
        assert dashboard["fuzz_corpus_exact_error_expectations"] == fuzz_report["exact_error_expectations"]
        assert dashboard["fuzz_corpus_mode_count_rows"] == fuzz_report["mode_count_rows"]
        assert dashboard["fuzz_corpus_error_count_rows"] == fuzz_report["error_count_rows"]
        assert dashboard["fuzz_corpus_coverage_mode_requirements"] == fuzz_coverage_smoke["mode_requirement_count"]
        assert dashboard["fuzz_corpus_coverage_error_requirements"] == fuzz_coverage_smoke["error_requirement_count"]
        assert dashboard["decode_stage_present"] is True
        assert dashboard["decode_stage_ok"] is True
        assert dashboard["decode_stage_healthy"] is True
        assert dashboard["decode_stage_rows"] == decode_stage["rows"]
        assert dashboard["decode_stage_error_rows"] == decode_stage["error_rows"]
        assert dashboard["decode_stage_matched_error_rows"] == decode_stage["matched_error_rows"]
        assert dashboard["decode_stage_unmatched_error_rows"] == decode_stage["unmatched_error_rows"]
        assert dashboard["zstd_compare_present"] is True
        assert dashboard["zstd_compare_standard_present"] is True
        assert dashboard["zstd_compare_block_sweep_present"] is True
        assert dashboard["zstd_compare_healthy"] is True
        assert dashboard["zstd_compare_rows"] > 0
        assert dashboard["zstd_compare_standard_rows"] > 0
        assert dashboard["zstd_compare_block_sweep_rows"] > 0
        assert dashboard["zstd_compare_best_block_len"] > 0
        assert dashboard["zstd_compare_best_range_decode_mib_s"] > 0
        assert dashboard["zstd_compare_best_range_decode_full_input_mib_s"] > 0
        assert dashboard["native_fuzz_corpus_present"] is True
        assert dashboard["native_fuzz_corpus_coverage_present"] is True
        assert dashboard["native_fuzz_corpus_healthy"] is True
        assert dashboard["native_fuzz_corpus_cases"] >= 1
        assert dashboard["native_fuzz_corpus_accepted"] >= 1
        assert dashboard["native_fuzz_corpus_rejected"] >= 1
        assert dashboard["native_fuzz_corpus_matched_rows"] == dashboard["native_fuzz_corpus_cases"]
        assert dashboard["native_fuzz_corpus_unmatched_rows"] == 0
        assert dashboard["native_fuzz_corpus_exact_error_expectations"] >= 1
        assert dashboard["native_fuzz_corpus_coverage_mode_requirements"] >= 1
        assert dashboard["native_fuzz_corpus_coverage_error_requirements"] >= 1
        assert dashboard["br_static_dictionary_present"] is True
        assert dashboard["br_static_dictionary_upstream_present"] is True
        assert dashboard["br_static_dictionary_node_present"] is True
        assert dashboard["br_static_dictionary_audit_present"] is True
        assert dashboard["br_static_dictionary_negative_present"] is True
        assert dashboard["br_static_dictionary_report_present"] is True
        assert dashboard["br_static_dictionary_report_csv_present"] is True
        assert dashboard["br_static_dictionary_report_markdown_present"] is True
        assert dashboard["br_static_dictionary_report_negative_present"] is True
        assert dashboard["br_static_dictionary_core_healthy"] is True
        assert dashboard["br_static_dictionary_report_healthy"] is True
        assert dashboard["br_static_dictionary_healthy"] is True
        assert dashboard["br_static_dictionary_candidate_count"] == br_static_dictionary_candidate_report["candidate_count"]
        assert dashboard["br_static_dictionary_raw_word_count"] == br_static_dictionary_candidate_report["raw_word_count"]
        assert dashboard["br_static_dictionary_upstream_candidate_count"] == br_static_dictionary_candidate_upstream["candidate_count"]
        assert dashboard["br_static_dictionary_upstream_raw_word_count"] == br_static_dictionary_candidate_upstream["raw_word_count"]
        assert dashboard["br_static_dictionary_node_probed_count"] == br_static_dictionary_node_probe["probed_count"]
        assert dashboard["br_static_dictionary_node_decode_successes"] == br_static_dictionary_node_probe["node_decode_successes"]
        assert dashboard["br_static_dictionary_node_size_winner_count"] == br_static_dictionary_node_probe["size_winner_count"]
        assert dashboard["br_static_dictionary_audit_entry_count"] == br_static_dictionary_source_audit["entry_count"]
        assert dashboard["br_static_dictionary_audit_anchor_count"] == br_static_dictionary_source_audit["anchor_count"]
        assert dashboard["br_static_dictionary_audit_generated_zig_bytes"] == br_static_dictionary_source_audit["generated_zig_bytes"]
        assert dashboard["br_static_dictionary_negative_case_count"] == br_static_dictionary_source_audit_negative["case_count"]
        assert dashboard["br_static_dictionary_negative_matched"] == br_static_dictionary_source_audit_negative["case_count"]
        assert dashboard["br_static_dictionary_report_entry_count"] == br_static_dictionary_report["entry_count"]
        assert dashboard["br_static_dictionary_report_json_entries"] == len(br_static_dictionary_report["entries"])
        assert dashboard["br_static_dictionary_report_transform_count"] == br_static_dictionary_report["transform_count"]
        assert dashboard["br_static_dictionary_report_length_count"] == br_static_dictionary_report["length_count"]
        assert dashboard["br_static_dictionary_report_identity_count"] == br_static_dictionary_report["category_counts"]["identity"]
        assert dashboard["br_static_dictionary_report_transform_entry_count"] == br_static_dictionary_report["category_counts"]["transform"]
        assert dashboard["br_static_dictionary_report_phrase_count"] == br_static_dictionary_report["category_counts"]["phrase"]
        assert dashboard["br_static_dictionary_report_category_total"] == br_static_dictionary_report["entry_count"]
        assert dashboard["br_static_dictionary_report_category_mismatch_rows"] == 0
        assert dashboard["br_static_dictionary_report_matrix_rows"] == len(br_static_dictionary_report["matrix_rows"])
        assert dashboard["br_static_dictionary_report_matrix_total"] == br_static_dictionary_report["entry_count"]
        assert dashboard["br_static_dictionary_report_matrix_mismatch_rows"] == 0
        assert dashboard["br_static_dictionary_report_csv_rows"] == br_static_dictionary_report["entry_count"]
        assert dashboard["br_static_dictionary_report_csv_matched"] == br_static_dictionary_report["entry_count"]
        assert dashboard["br_static_dictionary_report_csv_unmatched"] == 0
        assert dashboard["br_static_dictionary_report_markdown_summary_rows"] == 6
        assert dashboard["br_static_dictionary_report_markdown_matched"] == 6
        assert dashboard["br_static_dictionary_report_markdown_unmatched"] == 0
        assert dashboard["br_static_dictionary_report_negative_case_count"] == br_static_dictionary_report_negative["case_count"]
        assert dashboard["br_static_dictionary_report_negative_matched"] == br_static_dictionary_report_negative["case_count"]
        assert dashboard["br_static_dictionary_report_negative_unmatched"] == 0
        assert dashboard["png_scratch_present"] is True
        assert dashboard["png_scratch_healthy"] is True
        assert dashboard["png_scratch_case_count"] == png_scratch["case_count"]
        assert dashboard["png_scratch_adam7_cases"] >= 1
        assert dashboard["png_scratch_stored_achieved"] == png_scratch["case_count"]
        assert dashboard["png_scratch_fixed_achieved"] == png_scratch["case_count"]
        assert dashboard["png_scratch_total_zlib_scratch"] == dashboard["png_scratch_total_streaming_savings"]
        assert dashboard["png_scratch_max_working_scratch"] > dashboard["png_scratch_max_streaming_working_scratch"]
        assert dashboard["png_scratch_max_fixed_dynamic_streaming_working_scratch"] >= 32768
        assert dashboard["png_scratch_min_streaming_ratio"] > 0
        assert dashboard["zlib_relaxed_present"] is True
        assert dashboard["zlib_relaxed_healthy"] is True
        assert dashboard["zlib_relaxed_gate_present"] is True
        assert dashboard["zlib_relaxed_gate_ok"] is True
        assert dashboard["zlib_relaxed_gate_check_count"] == len(zlib_relaxed_gate["checks"])
        assert dashboard["zlib_relaxed_gate_passed_count"] == len(zlib_relaxed_gate["checks"])
        assert dashboard["zlib_relaxed_gate_failed_checks"] == []
        assert dashboard["zlib_relaxed_strict_rejections"] == zlib_relaxed["strict_rejections"]
        assert dashboard["zlib_relaxed_successes"] == zlib_relaxed["relaxed_successes"]
        assert dashboard["zlib_relaxed_dictionary_successes"] == zlib_relaxed["dictionary_successes"]
        assert dashboard["zlib_relaxed_concatenated_successes"] == zlib_relaxed["zlib_concatenated_successes"]
        assert dashboard["zlib_relaxed_decoder_successes"] == zlib_relaxed["zlib_decoder_successes"]
        assert dashboard["zlib_relaxed_limited_rejections"] == zlib_relaxed["limited_rejections"]
        assert dashboard["gzip_relaxed_strict_rejections"] == zlib_relaxed["gzip_strict_rejections"]
        assert dashboard["gzip_relaxed_successes"] == zlib_relaxed["gzip_relaxed_successes"]
        assert dashboard["gzip_relaxed_concatenated_successes"] == zlib_relaxed["gzip_concatenated_successes"]
        assert dashboard["gzip_relaxed_decoder_successes"] == zlib_relaxed["gzip_decoder_successes"]
        assert dashboard["gzip_relaxed_limited_rejections"] == zlib_relaxed["gzip_limited_rejections"]
        assert dashboard["snappy_report_present"] is True
        assert dashboard["snappy_report_healthy"] is True
        assert dashboard["snappy_report_rows"] == len(snappy_report_rows)
        assert dashboard["snappy_report_expected_rows"] == 20
        assert dashboard["snappy_report_positive_timing_rows"] == len(snappy_report_rows)
        assert dashboard["snappy_report_repetitive_shrunk_rows"] == 4
        assert dashboard["snappy_report_reusable_size_matched_cases"] == 5
        assert dashboard["snappy_report_missing_pairs"] == []
        assert dashboard["checksum_bench_present"] is True
        assert dashboard["checksum_bench_healthy"] is True
        assert dashboard["checksum_bench_rows"] == len(checksum_bench_rows)
        assert dashboard["checksum_bench_expected_rows"] == 21
        assert dashboard["checksum_bench_positive_rows"] == len(checksum_bench_rows)
        assert dashboard["checksum_bench_workload_rows"] == len(checksum_bench_rows)
        assert dashboard["checksum_bench_crc32_mix_groups"] == 1
        assert dashboard["checksum_bench_crc32c_mix_groups"] == 1
        assert dashboard["checksum_bench_missing_algorithms"] == []
        assert dashboard["chunk_cursor_bench_present"] is True
        assert dashboard["chunk_cursor_bench_healthy"] is True
        assert dashboard["chunk_cursor_bench_rows"] == len(chunk_cursor_bench_rows)
        assert dashboard["chunk_cursor_bench_expected_rows"] == 8
        assert dashboard["chunk_cursor_bench_positive_rows"] == len(chunk_cursor_bench_rows)
        assert dashboard["chunk_cursor_bench_shape_rows"] == len(chunk_cursor_bench_rows)
        assert dashboard["chunk_cursor_bench_missing_pairs"] == []
        assert dashboard["deflate_match_copy_bench_present"] is True
        assert dashboard["deflate_match_copy_bench_healthy"] is True
        assert dashboard["deflate_match_copy_bench_rows"] == len(deflate_match_copy_bench_rows)
        assert dashboard["deflate_match_copy_bench_expected_rows"] == 21
        assert dashboard["deflate_match_copy_bench_positive_rows"] == len(deflate_match_copy_bench_rows)
        assert dashboard["deflate_match_copy_bench_expected_class_rows"] == len(deflate_match_copy_bench_rows)
        assert dashboard["deflate_match_copy_bench_missing_pairs"] == []
        assert dashboard["deflate_huffman_build_bench_present"] is True
        assert dashboard["deflate_huffman_build_bench_healthy"] is True
        assert dashboard["deflate_huffman_build_bench_rows"] == len(deflate_huffman_build_bench_rows)
        assert dashboard["deflate_huffman_build_bench_expected_rows"] == 14
        assert dashboard["deflate_huffman_build_bench_positive_rows"] == len(deflate_huffman_build_bench_rows)
        assert dashboard["deflate_huffman_build_bench_lookup_rows"] == len(deflate_huffman_build_bench_rows)
        assert dashboard["deflate_huffman_build_bench_missing_pairs"] == []
        assert dashboard["deflate_huffman_lookup_bench_present"] is True
        assert dashboard["deflate_huffman_lookup_bench_healthy"] is True
        assert dashboard["deflate_huffman_lookup_bench_rows"] == len(deflate_huffman_lookup_bench_rows)
        assert dashboard["deflate_huffman_lookup_bench_expected_rows"] == 21
        assert dashboard["deflate_huffman_lookup_bench_positive_rows"] == len(deflate_huffman_lookup_bench_rows)
        assert dashboard["deflate_huffman_lookup_bench_lookup_rows"] == len(deflate_huffman_lookup_bench_rows)
        assert dashboard["deflate_huffman_lookup_bench_missing_pairs"] == []
        assert dashboard["deflate_chunked_huffman_bench_present"] is True
        assert dashboard["deflate_chunked_huffman_bench_healthy"] is True
        assert dashboard["deflate_chunked_huffman_bench_rows"] == len(deflate_chunked_huffman_bench_rows)
        assert dashboard["deflate_chunked_huffman_bench_expected_rows"] == 57
        assert dashboard["deflate_chunked_huffman_bench_positive_rows"] == len(deflate_chunked_huffman_bench_rows)
        assert dashboard["deflate_chunked_huffman_bench_shape_rows"] == len(deflate_chunked_huffman_bench_rows)
        assert dashboard["deflate_chunked_huffman_bench_buffered_zero_chunk_rows"] == 3
        assert dashboard["deflate_chunked_huffman_bench_missing_pairs"] == []
        assert dashboard["deflate_extra_bits_bench_present"] is True
        assert dashboard["deflate_extra_bits_bench_healthy"] is True
        assert dashboard["deflate_extra_bits_bench_rows"] == len(deflate_extra_bits_bench_rows)
        assert dashboard["deflate_extra_bits_bench_expected_rows"] == 105
        assert dashboard["deflate_extra_bits_bench_positive_rows"] == len(deflate_extra_bits_bench_rows)
        assert dashboard["deflate_extra_bits_bench_shape_rows"] == len(deflate_extra_bits_bench_rows)
        assert dashboard["deflate_extra_bits_bench_paired_checksum_rows"] == 28
        assert dashboard["deflate_extra_bits_bench_expected_paired_checksum_rows"] == 28
        assert dashboard["deflate_extra_bits_bench_missing_pairs"] == []
        assert dashboard["dictionary_decode_bench_present"] is True
        assert dashboard["dictionary_decode_bench_healthy"] is True
        assert dashboard["dictionary_decode_bench_rows"] == len(dictionary_decode_bench_rows)
        assert dashboard["dictionary_decode_bench_expected_rows"] == 18
        assert dashboard["dictionary_decode_bench_positive_rows"] == len(dictionary_decode_bench_rows)
        assert dashboard["dictionary_decode_bench_shape_rows"] == len(dictionary_decode_bench_rows)
        assert dashboard["dictionary_decode_bench_output_size_rows"] == len(dictionary_decode_bench_rows)
        assert dashboard["dictionary_decode_bench_missing_pairs"] == []
        assert dashboard["png_scanline_bench_present"] is True
        assert dashboard["png_scanline_bench_healthy"] is True
        assert dashboard["png_scanline_bench_rows"] == len(png_scanline_bench_rows)
        assert dashboard["png_scanline_bench_expected_rows"] == 30
        assert dashboard["png_scanline_bench_positive_rows"] == len(png_scanline_bench_rows)
        assert dashboard["png_scanline_bench_shape_rows"] == len(png_scanline_bench_rows)
        assert dashboard["png_scanline_bench_io_match_rows"] == len(png_scanline_bench_rows)
        assert dashboard["png_scanline_bench_missing_pairs"] == []
        assert dashboard["chunked_zlib_bench_present"] is True
        assert dashboard["chunked_zlib_bench_healthy"] is True
        assert dashboard["chunked_zlib_bench_rows"] == len(chunked_zlib_bench_rows)
        assert dashboard["chunked_zlib_bench_expected_rows"] == 8
        assert dashboard["chunked_zlib_bench_positive_rows"] == len(chunked_zlib_bench_rows)
        assert dashboard["chunked_zlib_bench_shape_rows"] == len(chunked_zlib_bench_rows)
        assert dashboard["chunked_zlib_bench_chunk_count_rows"] == len(chunked_zlib_bench_rows)
        assert dashboard["chunked_zlib_bench_ratio_rows"] == len(chunked_zlib_bench_rows)
        assert dashboard["chunked_zlib_bench_missing_cases"] == []
        assert dashboard["png_streaming_zlib_bench_present"] is True
        assert dashboard["png_streaming_zlib_bench_healthy"] is True
        assert dashboard["png_streaming_zlib_bench_rows"] == len(png_streaming_zlib_bench_rows)
        assert dashboard["png_streaming_zlib_bench_expected_rows"] == 10
        assert dashboard["png_streaming_zlib_bench_positive_rows"] == len(png_streaming_zlib_bench_rows)
        assert dashboard["png_streaming_zlib_bench_shape_rows"] == len(png_streaming_zlib_bench_rows)
        assert dashboard["png_streaming_zlib_bench_image_size_rows"] == len(png_streaming_zlib_bench_rows)
        assert dashboard["png_streaming_zlib_bench_ratio_rows"] == len(png_streaming_zlib_bench_rows)
        assert dashboard["png_streaming_zlib_bench_missing_cases"] == []
        assert dashboard["deflate_dynamic_decode_profile_present"] is True
        assert dashboard["deflate_dynamic_decode_profile_healthy"] is True
        assert dashboard["deflate_dynamic_decode_profile_rows"] == len(deflate_dynamic_decode_profile_rows)
        assert dashboard["deflate_dynamic_decode_profile_required_rows"] == 3
        assert dashboard["deflate_dynamic_decode_profile_positive_rows"] == 3
        assert dashboard["deflate_dynamic_decode_profile_histogram_rows"] == 3
        assert dashboard["deflate_dynamic_decode_profile_lookup_rows"] == 3
        assert dashboard["deflate_dynamic_decode_profile_match_class_rows"] == 3
        assert dashboard["deflate_dynamic_decode_profile_chunked_window_rows"] == 1
        assert dashboard["deflate_dynamic_decode_profile_missing_cases"] == []
        assert dashboard["native_allocation_present"] is True
        assert dashboard["native_allocation_smoke_present"] is True
        assert dashboard["native_allocation_negative_present"] is True
        assert dashboard["native_allocation_healthy"] is True
        assert dashboard["native_allocation_report_case_count"] == native_allocation["case_count"]
        assert dashboard["native_allocation_required_zero_allocation_cases"] == native_allocation_smoke["required_zero_allocation_cases"]
        assert dashboard["native_allocation_zero_allocation_matched"] == len(native_allocation_smoke["cases"])
        assert dashboard["native_allocation_required_budget_cases"] == native_allocation_smoke["required_budget_cases"]
        assert dashboard["native_allocation_budget_matched"] == len(native_allocation_smoke["budget_cases"])
        assert dashboard["native_allocation_negative_case_count"] == native_allocation_negative_smoke["case_count"]
        assert dashboard["native_allocation_negative_matched"] == native_allocation_negative_smoke["case_count"]
        assert dashboard["python_zlib_diff_present"] is True
        assert dashboard["python_zlib_diff_ok"] is True
        assert dashboard["python_zlib_diff_healthy"] is True
        assert dashboard["python_zlib_diff_payloads"] == python_zlib_diff["payloads"]
        assert dashboard["python_zlib_diff_large_file_payloads"] == python_zlib_diff["large_file_payloads"]
        assert dashboard["python_zlib_diff_file_hex_encode_cases"] == python_zlib_diff["file_hex_encode_cases"]
        assert dashboard["python_zlib_diff_match_heavy_payloads"] == python_zlib_diff["match_heavy_payloads"]
        assert dashboard["python_zlib_diff_dynamic_payloads"] == python_zlib_diff["dynamic_payloads"]
        assert dashboard["python_zlib_diff_dictionary_cases"] == python_zlib_diff["dictionary_cases"]
        assert dashboard["python_zlib_diff_zlib_dict_encode_cases"] == python_zlib_diff["zlib_dict_encode_cases"]
        assert dashboard["python_zlib_diff_raw_dict_encode_cases"] == python_zlib_diff["raw_dict_encode_cases"]
        assert dashboard["python_zlib_diff_malformed_wrapper_cases"] == python_zlib_diff["malformed_wrapper_cases"]
        assert dashboard["python_zlib_diff_malformed_deflate_cases"] == python_zlib_diff["malformed_deflate_cases"]
        assert dashboard["python_zlib_diff_cli_successes"] == python_zlib_diff["cli_successes"]
        assert dashboard["python_zlib_diff_expected_failures"] == python_zlib_diff["expected_failures"]
        assert dashboard["native_codec_probes_present"] is True
        assert dashboard["native_codec_probes_ok"] is True
        assert dashboard["native_codec_probes_healthy"] is True
        assert dashboard["native_codec_probes_probe_count"] == native_codec_probes["probe_count"]
        assert dashboard["native_codec_probes_ok_probe_count"] == native_codec_probes["probe_count"]
        assert dashboard["native_codec_probes_timed_out_probes"] == 0
        assert dashboard["native_codec_probes_capability_count"] == native_codec_probes["capability_count"]
        assert dashboard["native_codec_probes_ok_capability_count"] == native_codec_probes["capability_count"]
        assert dashboard["native_codec_probes_lib_generated_cases"] == capabilities_by_name["lib-generated"]["cases"]
        assert dashboard["native_codec_probes_incremental_cases"] == capabilities_by_name["incremental"]["cases"]
        assert dashboard["native_codec_probes_chunked_cases"] == capabilities_by_name["chunked"]["cases"]
        assert dashboard["native_codec_probes_reusable_chunked_cases"] == capabilities_by_name["reusable-chunked"]["cases"]
        assert dashboard["native_codec_probes_fse_repeat_cases"] == capabilities_by_name["fse-repeat"]["cases"]
        assert dashboard["native_codec_probes_dictionary_cases"] == capabilities_by_name["dictionary"]["cases"]
        assert dashboard["native_codec_probes_malformed_cases"] == capabilities_by_name["malformed"]["cases"]
        assert dashboard["native_codec_probes_total_cases"] == native_codec_probes["total_cases"]
        probes_by_label = {
            probe["label"]: probe
            for probe in native_codec_probes["probes"]
        }
        assert dashboard["native_codec_probes_zstd_frame_cases"] == probes_by_label["zstd-native-frame-probe"]["cases"]
        assert dashboard["native_codec_probes_zstd_dictionary_cases"] == probes_by_label["zstd-native-dictionary-probe"]["cases"]
        assert dashboard["native_summary_error_present"] is True
        assert dashboard["native_summary_error_healthy"] is True
        assert dashboard["native_summary_error_case_count"] == native_summary_error_dashboard["case_count"]
        assert dashboard["native_summary_error_lz4_case_count"] == native_summary_error_dashboard["lz4_case_count"]
        assert dashboard["native_summary_error_zstd_case_count"] == native_summary_error_dashboard["zstd_case_count"]
        assert dashboard["native_summary_error_checksum_mismatch_count"] == native_summary_error_dashboard["error_counts"]["ChecksumMismatch"]
        assert dashboard["native_summary_error_corrupt_frame_count"] == native_summary_error_dashboard["error_counts"]["CorruptFrame"]
        assert dashboard["native_summary_error_truncated_frame_count"] == native_summary_error_dashboard["error_counts"]["TruncatedFrame"]
        assert dashboard["native_summary_error_magic_phase_count"] == native_summary_error_dashboard["phase_counts"]["magic"]
        assert dashboard["native_summary_error_skippable_payload_phase_count"] == native_summary_error_dashboard["phase_counts"]["skippable_payload"]
        assert dashboard["native_summary_error_frame_body_phase_count"] == native_summary_error_dashboard["phase_counts"]["frame_body"]
        assert dashboard["native_summary_error_frame_checksum_phase_count"] == native_summary_error_dashboard["phase_counts"]["frame_checksum"]
        assert dashboard["native_summary_error_frame_phase_count"] == native_summary_error_dashboard["phase_counts"]["frame"]
        assert dashboard["native_summary_error_error_counts"] == native_summary_error_dashboard["error_counts"]
        assert dashboard["native_summary_error_phase_counts"] == native_summary_error_dashboard["phase_counts"]
        assert dashboard["native_summary_error_lz4_error_counts"] == native_summary_error_dashboard["lz4_error_counts"]
        assert dashboard["native_summary_error_zstd_error_counts"] == native_summary_error_dashboard["zstd_error_counts"]
        assert dashboard["native_summary_error_lz4_phase_counts"] == native_summary_error_dashboard["lz4_phase_counts"]
        assert dashboard["native_summary_error_zstd_phase_counts"] == native_summary_error_dashboard["zstd_phase_counts"]
        assert dashboard["native_summary_error_offset_min"] == native_summary_error_dashboard["offset_min"]
        assert dashboard["native_summary_error_offset_max"] == native_summary_error_dashboard["offset_max"]
        assert dashboard["native_summary_error_lz4_offset_min"] == native_summary_error_dashboard["lz4_offset_min"]
        assert dashboard["native_summary_error_lz4_offset_max"] == native_summary_error_dashboard["lz4_offset_max"]
        assert dashboard["native_summary_error_zstd_offset_min"] == native_summary_error_dashboard["zstd_offset_min"]
        assert dashboard["native_summary_error_zstd_offset_max"] == native_summary_error_dashboard["zstd_offset_max"]
        assert dashboard["native_summary_error_phase_offset_ranges"] == native_summary_error_dashboard["phase_offset_ranges"]
        assert dashboard["native_summary_error_required_codec_phases"] == native_summary_error_dashboard["required_codec_phases"]
        assert dashboard["native_summary_error_lz4_missing_phases"] == []
        assert dashboard["native_summary_error_zstd_missing_phases"] == []
        assert dashboard["native_summary_error_negative_present"] is True
        assert dashboard["native_summary_error_negative_healthy"] is True
        assert dashboard["native_summary_error_negative_case_count"] == native_summary_error_negative["case_count"]
        dashboard_markdown = dashboard_path.read_text()
        assert "## Native summary error codec coverage" in dashboard_markdown
        assert "| codec | cases | errors | phases | required phases | missing phases |" in dashboard_markdown
        for codec in ("lz4", "zstd"):
            assert f"| `{codec}` | {native_summary_error_dashboard[f'{codec}_case_count']} |" in dashboard_markdown
            assert f"native_summary_error_{codec}_missing_phases" not in dashboard_markdown
            for name in native_summary_error_dashboard[f"{codec}_error_counts"]:
                assert f"`{name}`=" in dashboard_markdown
            for name in native_summary_error_dashboard[f"{codec}_phase_counts"]:
                assert f"`{name}`=" in dashboard_markdown
        assert "## Native summary error phase offsets" in dashboard_markdown
        assert "| phase | cases | offset range |" in dashboard_markdown
        for phase, offset_range in native_summary_error_dashboard["phase_offset_ranges"].items():
            assert f"| `{phase}` | {native_summary_error_dashboard['phase_counts'][phase]} | `{offset_range['min']}..{offset_range['max']}` |" in dashboard_markdown
        assert dashboard["lz4_native_summary_present"] is True
        assert dashboard["lz4_native_summary_healthy"] is True
        assert dashboard["lz4_native_summary_frame_count"] == lz4_native_summary["frame_count"]
        assert dashboard["lz4_native_summary_skippable_frame_count"] == lz4_native_summary["skippable_frame_count"]
        assert dashboard["lz4_native_summary_checksum_frame_count"] == lz4_native_summary["checksum_frame_count"]
        assert dashboard["lz4_native_summary_block_checksum_frame_count"] == lz4_native_summary["block_checksum_frame_count"]
        assert dashboard["lz4_native_summary_dictionary_id_frame_count"] == lz4_native_summary["dictionary_id_frame_count"]
        assert dashboard["lz4_native_summary_content_size_frame_count"] == lz4_native_summary["content_size_frame_count"]
        assert dashboard["lz4_native_summary_declared_content_bytes"] == lz4_native_summary["declared_content_bytes"]
        assert dashboard["lz4_native_summary_block_count"] == lz4_native_summary["block_count"]
        assert dashboard["lz4_native_summary_raw_block_count"] == lz4_native_summary["raw_block_count"]
        assert dashboard["lz4_native_summary_compressed_block_count"] == lz4_native_summary["compressed_block_count"]
        assert dashboard["lz4_native_summary_compressed_bytes"] == lz4_native_summary["compressed_bytes"]
        assert dashboard["lz4_native_summary_payload_bytes"] == lz4_native_summary["payload_bytes"]
        assert dashboard["lz4_native_summary_skippable_payload_bytes"] == lz4_native_summary["skippable_payload_bytes"]
        assert dashboard["zstd_native_summary_present"] is True
        assert dashboard["zstd_native_summary_healthy"] is True
        assert dashboard["zstd_native_summary_frame_count"] == zstd_native_summary["frame_count"]
        assert dashboard["zstd_native_summary_skippable_frame_count"] == zstd_native_summary["skippable_frame_count"]
        assert dashboard["zstd_native_summary_checksum_frame_count"] == zstd_native_summary["checksum_frame_count"]
        assert dashboard["zstd_native_summary_dictionary_id_frame_count"] == zstd_native_summary["dictionary_id_frame_count"]
        assert dashboard["zstd_native_summary_content_size_frame_count"] == zstd_native_summary["content_size_frame_count"]
        assert dashboard["zstd_native_summary_declared_content_bytes"] == zstd_native_summary["declared_content_bytes"]
        assert dashboard["zstd_native_summary_block_count"] == zstd_native_summary["block_count"]
        assert dashboard["zstd_native_summary_raw_block_count"] == zstd_native_summary["raw_block_count"]
        assert dashboard["zstd_native_summary_rle_block_count"] == zstd_native_summary["rle_block_count"]
        assert dashboard["zstd_native_summary_compressed_block_count"] == zstd_native_summary["compressed_block_count"]
        assert dashboard["zstd_native_summary_compressed_bytes"] == zstd_native_summary["compressed_bytes"]
        assert dashboard["zstd_native_summary_payload_bytes"] == zstd_native_summary["payload_bytes"]
        assert dashboard["zstd_native_summary_skippable_payload_bytes"] == zstd_native_summary["skippable_payload_bytes"]
        assert dashboard["native_tier_range_csv_present_count"] == 3
        assert dashboard["native_tier_range_csv_healthy_count"] == 3
        assert dashboard["native_tier_range_csv_rows"] == 24
        assert dashboard["native_tier_range_csv_positive_rows"] == 24
        assert dashboard["native_tier_range_csv_shape_rows"] == 24
        assert dashboard["native_tier_range_csv_throughput_rows"] == 24
        assert dashboard["native_tier_range_csv_missing_sources"] == []
        assert dashboard["native_tier_range_csv_missing_pairs"] == []
        assert dashboard["native_tier_corpus_discovery_present"] is True
        assert dashboard["native_tier_corpus_discovery_ok"] is True
        assert dashboard["native_tier_corpus_discovery_healthy"] is True
        assert dashboard["native_tier_corpus_discovery_source_count"] == len(native_tier_corpus_discovery["sources"])
        assert dashboard["native_tier_corpus_discovery_selected_case_count"] == len(native_tier_corpus_discovery["selected_cases"])
        assert dashboard["validation_healthy"] == (
            dashboard["producer_healthy"]
            and dashboard["smoke_gate_healthy"]
            and dashboard["header_inspect_healthy"]
            and dashboard["dashboard_strict_healthy"]
            and dashboard["dashboard_configuration_healthy"]
            and dashboard["validation_json_healthy"]
            and dashboard["sidecar_corrupt_healthy"]
            and dashboard["huffman_length_healthy"]
            and dashboard["level_report_healthy"]
            and dashboard["fuzz_corpus_healthy"]
            and dashboard["decode_stage_healthy"]
            and dashboard["native_allocation_healthy"]
            and dashboard["python_zlib_diff_healthy"]
            and dashboard["native_codec_probes_healthy"]
            and dashboard["png_scratch_healthy"]
            and dashboard["zlib_relaxed_healthy"]
            and dashboard["checksum_bench_healthy"]
            and dashboard["chunk_cursor_bench_healthy"]
            and dashboard["deflate_match_copy_bench_healthy"]
            and dashboard["deflate_huffman_build_bench_healthy"]
            and dashboard["deflate_huffman_lookup_bench_healthy"]
            and dashboard["deflate_chunked_huffman_bench_healthy"]
            and dashboard["deflate_extra_bits_bench_healthy"]
            and dashboard["dictionary_decode_bench_healthy"]
            and dashboard["png_scanline_bench_healthy"]
            and dashboard["chunked_zlib_bench_healthy"]
            and dashboard["png_streaming_zlib_bench_healthy"]
            and dashboard["deflate_dynamic_decode_profile_healthy"]
            and dashboard["native_library_bench_healthy"]
            and dashboard["snappy_report_healthy"]
            and dashboard["zstd_compare_healthy"]
            and dashboard["native_fuzz_corpus_healthy"]
            and dashboard["br_static_dictionary_healthy"]
            and dashboard["native_summary_error_healthy"]
            and dashboard["native_summary_error_negative_healthy"]
            and dashboard["lz4_native_summary_healthy"]
            and dashboard["zstd_native_summary_healthy"]
            and dashboard["native_tier_range_healthy"]
            and dashboard["native_tier_corpus_discovery_healthy"]
        )
        assert dashboard["validation_unhealthy_reasons"] == ([] if dashboard["validation_healthy"] else dashboard["validation_unhealthy_reasons"])
        validate_value_against_manifest(dashboard, schemas_def)
        strict_missing_root = root / "strict-missing"
        strict_missing_root.mkdir()
        strict_missing_dashboard = strict_missing_root / "vort-dashboard-index.md"
        strict_missing_manifest = strict_missing_root / "vort-dashboard-index.json"
        strict_missing = run(
            [
                "python3",
                str(DASHBOARD_INDEX),
                "--dir",
                str(strict_missing_root),
                "--output",
                str(strict_missing_dashboard),
                "--manifest",
                str(strict_missing_manifest),
                "--strict-header-inspect",
            ],
            check=False,
        )
        assert strict_missing.returncode != 0
        assert "dashboard_index_missing_header_inspect=1" in strict_missing.stdout
        summary = {
            "schema": "vort.validation_json_smoke",
            "schema_version": 1,
            "ok": True,
            "checked_schemas": [
                ok["schema"],
                report["schema"],
                corrupt["schema"],
                br_static_dictionary_candidate_report["schema"],
                br_static_dictionary_candidate_upstream["schema"],
                br_static_dictionary_node_probe["schema"],
                br_static_dictionary_required["schema"],
                br_static_dictionary_source_anchors["schema"],
                br_static_dictionary_source_audit["schema"],
                br_static_dictionary_source_audit_negative["schema"],
                br_static_dictionary_report["schema"],
                br_static_dictionary_report_negative["schema"],
                dashboard_strict_modes["schema"],
                dashboard_strict_reasons["schema"],
                dashboard_strict["schema"],
                dashboard_producers["schema"],
                dashboard_producers_negative["schema"],
                dashboard_producers_required["schema"],
                dashboard_producers_required_smoke["schema"],
                decode_stage["schema"],
                python_zlib_diff["schema"],
                native_codec_probes["schema"],
                native_summary_error_dashboard["schema"],
                native_summary_error_negative["schema"],
                lz4_native_summary["schema"],
                native_summary_error_payloads[0]["schema"],
                zstd_native_summary["schema"],
                native_summary_error_payloads[1]["schema"],
                zlib_relaxed["schema"],
                png_scratch["schema"],
                fuzz_report["schema"],
                fuzz_coverage["schema"],
                fuzz_coverage_smoke["schema"],
                dashboard_category_expected["schema"],
                dashboard_category_negative["schema"],
                dashboard_config_index["schema"],
                dashboard_config_index_negative["schema"],
                dashboard_config_index_smoke["schema"],
                dashboard["schema"],
                native_tier_corpus_discovery["schema"],
                header_summary["schema"],
                required_workflows["schema"],
                docs_negative["schema"],
                raw_header["schema"],
                wrapped_zlib_header["schema"],
                zlib_header["schema"],
                gzip_header["schema"],
            ],
            "cli_success_ok": ok["ok"],
            "cli_failure_ok": failure["ok"],
            "cli_failure_hint": failure["recoverability_hint"],
            "report_rows": report["rows"],
            "corrupt_rows": corrupt["rows"],
        }
        validate_value_against_manifest(summary, schemas_def)

    if summary_path is not None:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"validation_json_smoke=ok schemas={','.join(summary['checked_schemas'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
