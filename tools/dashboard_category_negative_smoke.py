#!/usr/bin/env python3
"""Smoke-test dashboard category expectation drift failures."""

from __future__ import annotations

import argparse
import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
CATEGORY_SMOKE = ROOT / "tools" / "dashboard_category_smoke.py"
EXPECTED = ROOT / "tools" / "dashboard_category_expected_artifacts.json"


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


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


def case_row(name: str, expected_output: str, result: subprocess.CompletedProcess[str]) -> dict[str, object]:
    actual = truncate_output(result.stdout)
    return {
        "name": name,
        "expected_failure": True,
        "expected_output": expected_output,
        "actual_output": actual["output"],
        "actual_output_bytes": actual["bytes"],
        "actual_output_limit": actual["limit"],
        "actual_output_truncated": actual["truncated"],
        "returncode": result.returncode,
        "matched": result.returncode != 0 and expected_output in result.stdout,
    }


def fixture_manifest(path: Path, *, category: str = "validation", producer_step: str = "zig build fixture", smoke_gate: str = "zig build fixture") -> None:
    write_json(
        path,
        {
            "schema": "vort.dashboard_index",
            "schema_version": 1,
            "artifacts": [
                {
                    "name": "vort-header-inspect-smoke.json",
                    "category": category,
                    "producer_step": producer_step,
                    "smoke_gate": smoke_gate,
                }
            ],
        },
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    base_expected = json.loads(EXPECTED.read_text())
    cases: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix="vort-dashboard-category-negative-") as tmp:
        root = Path(tmp)

        wrong_classifier_expected = copy.deepcopy(base_expected)
        wrong_classifier_expected["expected_artifacts"] = [
            {
                "name": "vort-rust-deflate-benchmark-summary.md",
                "category": "validation",
                "require_present": False,
                "require_producer_step": False,
                "require_smoke_gate": False,
            }
        ]
        wrong_classifier_path = root / "wrong-classifier.json"
        write_json(wrong_classifier_path, wrong_classifier_expected)
        wrong_classifier_manifest = root / "wrong-classifier-manifest.json"
        fixture_manifest(wrong_classifier_manifest)
        cases.append(
            case_row(
                "classifier_category_mismatch",
                "classifier category='benchmark', expected 'validation'",
                run(["python3", str(CATEGORY_SMOKE), str(wrong_classifier_manifest), "--expected", str(wrong_classifier_path)]),
            )
        )

        missing_required_expected = copy.deepcopy(base_expected)
        missing_required_expected["expected_artifacts"] = [
            {
                "name": "vort-header-inspect-smoke.json",
                "category": "validation",
                "require_present": True,
                "require_producer_step": True,
                "require_smoke_gate": True,
            }
        ]
        missing_required_path = root / "missing-required.json"
        write_json(missing_required_path, missing_required_expected)
        missing_required_manifest = root / "missing-required-manifest.json"
        write_json(missing_required_manifest, {"schema": "vort.dashboard_index", "schema_version": 1, "artifacts": []})
        cases.append(
            case_row(
                "missing_required_artifact",
                "missing dashboard artifact 'vort-header-inspect-smoke.json'",
                run(["python3", str(CATEGORY_SMOKE), str(missing_required_manifest), "--expected", str(missing_required_path)]),
            )
        )

        manifest_category_path = root / "manifest-category.json"
        fixture_manifest(manifest_category_path, category="other")
        cases.append(
            case_row(
                "manifest_category_mismatch",
                "vort-header-inspect-smoke.json category='other', expected 'validation'",
                run(["python3", str(CATEGORY_SMOKE), str(manifest_category_path), "--expected", str(missing_required_path)]),
            )
        )

        missing_producer_path = root / "missing-producer.json"
        fixture_manifest(missing_producer_path, producer_step="")
        cases.append(
            case_row(
                "missing_required_producer_step",
                "vort-header-inspect-smoke.json missing producer_step",
                run(["python3", str(CATEGORY_SMOKE), str(missing_producer_path), "--expected", str(missing_required_path)]),
            )
        )

        missing_smoke_path = root / "missing-smoke.json"
        fixture_manifest(missing_smoke_path, smoke_gate="")
        cases.append(
            case_row(
                "missing_required_smoke_gate",
                "vort-header-inspect-smoke.json missing smoke_gate",
                run(["python3", str(CATEGORY_SMOKE), str(missing_smoke_path), "--expected", str(missing_required_path)]),
            )
        )

    summary = {
        "schema": "vort.dashboard_category_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in cases),
        "case_count": len(cases),
        "cases": cases,
    }
    schemas_def = load_manifest()
    expected_case_names = set(schemas_def["vort.dashboard_category_negative_smoke"]["item_enums"]["name"])
    actual_case_names = {str(row["name"]) for row in cases}
    missing_cases = sorted(expected_case_names - actual_case_names)
    extra_cases = sorted(actual_case_names - expected_case_names)
    if missing_cases or extra_cases:
        raise AssertionError(f"dashboard category negative case coverage mismatch: missing={missing_cases!r} extra={extra_cases!r}")
    validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json(path, summary)

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"dashboard_category_negative_smoke=ok cases={summary['case_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
