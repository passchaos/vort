#!/usr/bin/env python3
"""Smoke-test Vort validation JSON schemas.

The build step passes the freshly built CLI and sidecar-report executables. This
script keeps the schema checks independent from shell quoting and verifies both
successful and failing validation JSON records.
"""

from __future__ import annotations

import json
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

        dashboard_category_expected = json.loads((ROOT / "tools" / "dashboard_category_expected_artifacts.json").read_text())
        assert dashboard_category_expected["schema"] == "vort.dashboard_category_expected_artifacts"
        assert dashboard_category_expected["expected_artifacts"]
        validate_value_against_manifest(dashboard_category_expected, schemas_def)
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
        assert dashboard["validation_healthy"] == (
            dashboard["producer_healthy"]
            and dashboard["smoke_gate_healthy"]
            and dashboard["header_inspect_healthy"]
            and dashboard["dashboard_strict_healthy"]
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
                dashboard_strict_modes["schema"],
                dashboard_strict_reasons["schema"],
                dashboard_strict["schema"],
                dashboard_producers_negative["schema"],
                dashboard_producers_required["schema"],
                dashboard_producers_required_smoke["schema"],
                dashboard_category_expected["schema"],
                dashboard["schema"],
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
