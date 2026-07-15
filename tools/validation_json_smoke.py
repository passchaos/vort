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
            ]
        )
        dashboard = json.loads(dashboard_manifest_path.read_text())
        assert dashboard["schema"] == "vort.dashboard_index"
        assert dashboard["schema_version"] == 1
        assert dashboard["artifact_count"] >= 2
        validate_value_against_manifest(dashboard, schemas_def)

        header_summary_path = root / "vort-header-inspect-smoke.json"
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
        assert header_summary["negative_cases"] >= 1
        assert len(header_summary["negative_items"]) == header_summary["negative_cases"]
        assert header_summary["negative_items"][0]["matched"] is True
        assert header_summary["dictionary_cases"] >= 1
        assert header_summary["optional_header_cases"] >= 1
        validate_value_against_manifest(header_summary, schemas_def)
        summary = {
            "schema": "vort.validation_json_smoke",
            "schema_version": 1,
            "ok": True,
            "checked_schemas": [
                ok["schema"],
                report["schema"],
                corrupt["schema"],
                dashboard["schema"],
                header_summary["schema"],
                raw_header["schema"],
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
