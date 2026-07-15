#!/usr/bin/env python3
"""Smoke-test validation JSON docs checker negative drift cases."""

from __future__ import annotations

import argparse
import copy
import json
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
