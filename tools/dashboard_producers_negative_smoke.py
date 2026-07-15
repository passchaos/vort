#!/usr/bin/env python3
"""Smoke-test dashboard producer-map drift failures."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_INDEX = ROOT / "tools" / "dashboard_index.py"


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_artifact(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema": "vort.dashboard_producers_negative_fixture",
                "schema_version": 1,
                "ok": True,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )


def write_producer_map(
    path: Path,
    *,
    exact: dict[str, str] | None = None,
    contains: list[dict[str, str]] | None = None,
    artifact_metadata: dict[str, dict[str, str]] | None = None,
    required_smoke_gates: list[str] | None = None,
    allow_missing_exact: list[str] | None = None,
) -> None:
    payload = {
        "schema": "vort.dashboard_producers",
        "schema_version": 1,
        "allow_missing": {"exact": list(allow_missing_exact or []), "contains": []},
        "required_smoke_gates": list(required_smoke_gates or []),
        "artifact_metadata": dict(artifact_metadata or {}),
        "exact": dict(exact or {}),
        "contains": list(contains or []),
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


def case_row(
    name: str,
    expected_failure: bool,
    expected_output: str,
    result: subprocess.CompletedProcess[str],
    *,
    manifest_check: bool = True,
) -> dict[str, object]:
    actual = truncate_output(result.stdout)
    matched = (result.returncode != 0) == expected_failure and expected_output in result.stdout and manifest_check
    return {
        "name": name,
        "expected_failure": expected_failure,
        "expected_output": expected_output,
        "actual_output": actual["output"],
        "actual_output_bytes": actual["bytes"],
        "actual_output_limit": actual["limit"],
        "actual_output_truncated": actual["truncated"],
        "returncode": result.returncode,
        "matched": matched,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    cases: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="vort-dashboard-producers-negative-") as tmp:
        root = Path(tmp)

        format_root = root / "format-mismatch"
        format_root.mkdir()
        format_name = "vort-validation-producer-format.json"
        write_artifact(format_root / format_name)
        format_map = format_root / "producers.json"
        write_producer_map(
            format_map,
            exact={format_name: "zig build run-format-fixture"},
            artifact_metadata={format_name: {"expected_format": "md", "smoke_gate": "zig build run-format-fixture"}},
        )
        cases.append(
            case_row(
                "expected_format_mismatch",
                True,
                f"{format_name} expected format 'md' but found '.json'",
                run(dashboard_args(format_root, format_map)),
            )
        )

        missing_producer_root = root / "missing-producer"
        missing_producer_root.mkdir()
        missing_producer_name = "vort-validation-producer-unmapped.json"
        write_artifact(missing_producer_root / missing_producer_name)
        missing_producer_map = missing_producer_root / "producers.json"
        write_producer_map(missing_producer_map)
        cases.append(
            case_row(
                "missing_producer_step",
                True,
                f"dashboard_index_missing_producers={missing_producer_name}",
                run(dashboard_args(missing_producer_root, missing_producer_map, "--strict-producers")),
            )
        )

        present_gate_root = root / "missing-present-smoke-gate"
        present_gate_root.mkdir()
        present_gate_name = "vort-validation-producer-required.json"
        write_artifact(present_gate_root / present_gate_name)
        present_gate_map = present_gate_root / "producers.json"
        write_producer_map(
            present_gate_map,
            exact={present_gate_name: "zig build run-required-fixture"},
            artifact_metadata={present_gate_name: {"expected_format": "json"}},
            required_smoke_gates=[present_gate_name],
        )
        cases.append(
            case_row(
                "missing_present_smoke_gate",
                True,
                f"dashboard_index_missing_smoke_gates={present_gate_name}",
                run(dashboard_args(present_gate_root, present_gate_map, "--strict-smoke-gates")),
            )
        )

        absent_gate_root = root / "missing-absent-smoke-gate"
        absent_gate_root.mkdir()
        absent_gate_name = "vort-validation-producer-absent.json"
        absent_gate_map = absent_gate_root / "producers.json"
        write_producer_map(absent_gate_map, required_smoke_gates=[absent_gate_name])
        cases.append(
            case_row(
                "missing_absent_smoke_gate",
                True,
                f"dashboard_index_missing_smoke_gates={absent_gate_name}",
                run(dashboard_args(absent_gate_root, absent_gate_map, "--strict-smoke-gates")),
            )
        )

        allow_root = root / "allow-missing"
        allow_root.mkdir()
        allow_name = "vort-validation-producer-allowed.json"
        write_artifact(allow_root / allow_name)
        allow_map = allow_root / "producers.json"
        write_producer_map(
            allow_map,
            artifact_metadata={allow_name: {"expected_format": "json", "smoke_gate": "zig build run-allowed-fixture"}},
            allow_missing_exact=[allow_name],
        )
        allow_result = run(dashboard_args(allow_root, allow_map, "--strict-producers"))
        allow_manifest = json.loads((allow_root / "vort-dashboard-index.json").read_text())
        allow_record = next(item for item in allow_manifest["artifacts"] if item["name"] == allow_name)
        cases.append(
            case_row(
                "allow_missing_exact",
                False,
                "dashboard_index=",
                allow_result,
                manifest_check=allow_manifest["producer_step_allowed_missing"] == [allow_name]
                and allow_record["producer_missing_allowed"] is True,
            )
        )

        contains_root = root / "contains-producer"
        contains_root.mkdir()
        contains_name = "vort-validation-producer-contains.json"
        write_artifact(contains_root / contains_name)
        contains_map = contains_root / "producers.json"
        contains_step = "zig build run-contains-fixture"
        write_producer_map(
            contains_map,
            contains=[{"match": "producer-contains", "producer_step": contains_step}],
            artifact_metadata={contains_name: {"expected_format": "json", "smoke_gate": contains_step}},
        )
        contains_result = run(dashboard_args(contains_root, contains_map, "--strict-producers"))
        contains_manifest = json.loads((contains_root / "vort-dashboard-index.json").read_text())
        contains_record = next(item for item in contains_manifest["artifacts"] if item["name"] == contains_name)
        cases.append(
            case_row(
                "contains_producer_step",
                False,
                "dashboard_index=",
                contains_result,
                manifest_check=contains_record["producer_step"] == contains_step and contains_record["smoke_gate"] == contains_step,
            )
        )

    summary = {
        "schema": "vort.dashboard_producers_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in cases),
        "case_count": len(cases),
        "cases": cases,
    }
    schemas_def = load_manifest()
    expected_case_names = set(schemas_def["vort.dashboard_producers_negative_smoke"]["item_enums"]["name"])
    actual_case_names = {str(row["name"]) for row in cases}
    missing_cases = sorted(expected_case_names - actual_case_names)
    extra_cases = sorted(actual_case_names - expected_case_names)
    if missing_cases or extra_cases:
        raise AssertionError(f"dashboard producer negative case coverage mismatch: missing={missing_cases!r} extra={extra_cases!r}")
    validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"dashboard_producers_negative_smoke=ok cases={summary['case_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
