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


def run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_producer_map(path: Path, *, include_exact: bool = True, include_smoke: bool = True, required_name: str | None = None) -> None:
    artifact_metadata = {}
    if include_smoke:
        artifact_metadata["vort-header-inspect-smoke.json"] = {
            "expected_format": "json",
            "smoke_gate": "zig build run-header-inspect-dashboard",
        }
    payload = {
        "schema": "vort.dashboard_producers",
        "schema_version": 1,
        "allow_missing": {"exact": [], "contains": []},
        "required_smoke_gates": [required_name] if required_name else [],
        "artifact_metadata": artifact_metadata,
        "exact": {},
        "contains": [],
    }
    if include_exact:
        payload["exact"]["vort-header-inspect-smoke.json"] = "zig build run-header-inspect-dashboard"
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def write_header_summary(path: Path, *, ok: bool = True, missing: list[dict[str, object]] | None = None) -> None:
    missing = missing or []
    payload = {
        "schema": "vort.header_inspect_smoke",
        "schema_version": 1,
        "ok": ok,
        "required_workflow_count": 1,
        "missing_workflow_count": len(missing),
        "missing_workflows": missing,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


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


def expect_failure(args: list[str], needle: str) -> None:
    result = run(args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"expected failure containing {needle!r}, got success: {result.stdout!r}")
    if needle not in result.stdout:
        raise AssertionError(f"expected {needle!r} in failure output, got {result.stdout!r}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()
    checks: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="vort-dashboard-strict-") as tmp:
        root = Path(tmp)
        artifact = root / "vort-header-inspect-smoke.json"
        producer_map = root / "producers.json"
        write_header_summary(artifact)
        write_producer_map(producer_map)

        ok = run(dashboard_args(root, producer_map, "--strict-producers", "--strict-smoke-gates", "--strict-header-inspect"))
        if "dashboard_index=" not in ok.stdout:
            raise AssertionError(f"dashboard index success output missing marker: {ok.stdout!r}")
        manifest = json.loads((root / "vort-dashboard-index.json").read_text())
        assert manifest["header_inspect_present"] is True
        assert manifest["header_inspect_ok"] is True
        assert manifest["header_inspect_missing_workflow_count"] == 0
        checks.append({"name": "all_strict_ok", "mode": "all", "expected_failure": False, "matched": True})

        no_producer = root / "no-producer.json"
        write_producer_map(no_producer, include_exact=False)
        expect_failure(dashboard_args(root, no_producer, "--strict-producers"), "dashboard_index_missing_producers=vort-header-inspect-smoke.json")
        checks.append({"name": "missing_producer", "mode": "strict-producers", "expected_failure": True, "matched": True})

        no_smoke = root / "no-smoke.json"
        write_producer_map(no_smoke, include_smoke=False, required_name="vort-header-inspect-smoke.json")
        expect_failure(dashboard_args(root, no_smoke, "--strict-smoke-gates"), "dashboard_index_missing_smoke_gates=vort-header-inspect-smoke.json")
        checks.append({"name": "missing_smoke_gate", "mode": "strict-smoke-gates", "expected_failure": True, "matched": True})

        missing_root = root / "missing-header"
        missing_root.mkdir()
        write_producer_map(missing_root / "producers.json")
        expect_failure(
            dashboard_args(missing_root, missing_root / "producers.json", "--strict-header-inspect"),
            "dashboard_index_missing_header_inspect=1",
        )
        checks.append({"name": "missing_header_inspect", "mode": "strict-header-inspect", "expected_failure": True, "matched": True})

        bad_root = root / "bad-header"
        bad_root.mkdir()
        bad_artifact = bad_root / "vort-header-inspect-smoke.json"
        bad_producer = bad_root / "producers.json"
        write_producer_map(bad_producer)
        write_header_summary(bad_artifact, ok=False)
        expect_failure(dashboard_args(bad_root, bad_producer, "--strict-header-inspect"), "dashboard_index_header_inspect_failed=1")
        checks.append({"name": "failed_header_inspect", "mode": "strict-header-inspect", "expected_failure": True, "matched": True})

        missing_workflow_root = root / "missing-workflow"
        missing_workflow_root.mkdir()
        missing_workflow_artifact = missing_workflow_root / "vort-header-inspect-smoke.json"
        missing_workflow_producer = missing_workflow_root / "producers.json"
        write_producer_map(missing_workflow_producer)
        write_header_summary(
            missing_workflow_artifact,
            missing=[{"command": "inspect-raw-header-file", "workflow": "file", "format": "raw"}],
        )
        expect_failure(
            dashboard_args(missing_workflow_root, missing_workflow_producer, "--strict-header-inspect"),
            "dashboard_index_header_inspect_missing_workflows=1:inspect-raw-header-file:file",
        )
        checks.append({"name": "missing_header_workflow", "mode": "strict-header-inspect", "expected_failure": True, "matched": True})

    summary = {
        "schema": "vort.dashboard_strict_smoke",
        "schema_version": 1,
        "ok": True,
        "check_count": len(checks),
        "checks": checks,
    }
    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print("dashboard_strict_smoke=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
