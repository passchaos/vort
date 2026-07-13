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


def run(args: list[str], *, check: bool = True, stdout: int | None = subprocess.PIPE) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=stdout, stderr=subprocess.STDOUT)


def first_json_line(text: str) -> dict:
    for line in text.splitlines():
        if line.startswith("{"):
            return json.loads(line)
    raise AssertionError(f"no JSON object found in output:\n{text}")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: validation_json_smoke.py <vort-cli> <sidecar-report>", file=sys.stderr)
        return 2

    cli = sys.argv[1]
    report_exe = sys.argv[2]
    with tempfile.TemporaryDirectory(prefix="vort-validation-json-") as tmp:
        root = Path(tmp)
        input_path = root / "input.txt"
        stream_path = root / "stream.vort"
        bad_stream_path = root / "stream-bad.vort"
        sidecar_path = root / "stream.vidx"
        report_path = root / "report.json"
        corrupt_path = root / "corrupt.json"
        input_bytes = (b"validation json schema smoke\n" * 64) + (b"abcdef" * 128)
        input_path.write_bytes(input_bytes)

        run([cli, "encode-vort-sidecar-best-file", str(input_path), str(stream_path), str(sidecar_path), "256"])

        ok = json.loads(run([cli, "verify-vort-sidecar-index-file", str(stream_path), str(sidecar_path), "full", "json"]).stdout)
        assert ok["schema"] == "vort.validation_report"
        assert ok["schema_version"] == 1
        assert ok["target"] == "sidecar"
        assert ok["ok"] is True

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

        run([report_exe, "--json", str(report_path), str(stream_path), str(sidecar_path)])
        report = json.loads(report_path.read_text())
        assert report["schema"] == "vort.sidecar_verify_report"
        assert report["schema_version"] == 1
        assert report["rows"] == 1

        run([report_exe, "--self-test-corrupt", "--json", str(corrupt_path)])
        corrupt = json.loads(corrupt_path.read_text())
        assert corrupt["schema"] == "vort.sidecar_corrupt_smoke_report"
        assert corrupt["schema_version"] == 1
        assert corrupt["rows"] >= 1

    print("validation_json_smoke=ok schemas=vort.validation_report,vort.sidecar_verify_report,vort.sidecar_corrupt_smoke_report")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
