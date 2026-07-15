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
        checks.append(check_row("all_strict_ok", "all", False, True, ok.returncode, "dashboard_index=", ok.stdout))

        no_producer = root / "no-producer.json"
        write_producer_map(no_producer, include_exact=False)
        no_producer_result = expect_failure(dashboard_args(root, no_producer, "--strict-producers"), "dashboard_index_missing_producers=vort-header-inspect-smoke.json")
        checks.append(check_row("missing_producer", "strict-producers", True, True, no_producer_result.returncode, "dashboard_index_missing_producers=vort-header-inspect-smoke.json", no_producer_result.stdout))
        validation_unhealthy_result = expect_failure(
            dashboard_args(root, no_producer, "--strict-validation-health"),
            "dashboard_index_validation_unhealthy=missing_producers",
        )
        checks.append(check_row("validation_unhealthy", "strict-validation-health", True, True, validation_unhealthy_result.returncode, "dashboard_index_validation_unhealthy=missing_producers", validation_unhealthy_result.stdout))

        no_smoke = root / "no-smoke.json"
        write_producer_map(no_smoke, include_smoke=False, required_name="vort-header-inspect-smoke.json")
        no_smoke_result = expect_failure(dashboard_args(root, no_smoke, "--strict-smoke-gates"), "dashboard_index_missing_smoke_gates=vort-header-inspect-smoke.json")
        checks.append(check_row("missing_smoke_gate", "strict-smoke-gates", True, True, no_smoke_result.returncode, "dashboard_index_missing_smoke_gates=vort-header-inspect-smoke.json", no_smoke_result.stdout))

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
