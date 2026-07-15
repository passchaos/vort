#!/usr/bin/env python3
"""Smoke-test dashboard config-index drift failures."""

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
CONFIG_SMOKE = ROOT / "tools" / "dashboard_config_index_smoke.py"
BASE_INDEX = ROOT / "tools" / "dashboard_config_index.json"


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


def truncate_output(text: str, limit: int = 240) -> dict[str, object]:
    normalized = text.replace("\n", "\\n")
    truncated = len(normalized) > limit
    output = normalized[: limit - 1] + "…" if truncated else normalized
    return {"output": output, "bytes": len(normalized), "limit": limit, "truncated": truncated}


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


def run_config_smoke(index_path: Path) -> subprocess.CompletedProcess[str]:
    return run(["python3", str(CONFIG_SMOKE), "--config-index", str(index_path)])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    base = json.loads(BASE_INDEX.read_text())
    cases: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix="vort-dashboard-config-index-negative-") as tmp:
        root = Path(tmp)

        missing_path = copy.deepcopy(base)
        missing_path["configs"] = [dict(missing_path["configs"][0])]
        missing_path["configs"][0]["path"] = "tools/no-such-dashboard-config.json"
        missing_path["config_count"] = len(missing_path["configs"])
        missing_path_file = root / "missing-path.json"
        write_json(missing_path_file, missing_path)
        cases.append(case_row("missing_config_path", '"path_exists": false', run_config_smoke(missing_path_file)))

        schema_mismatch_config = root / "schema-mismatch-config.json"
        write_json(schema_mismatch_config, {"schema": "vort.dashboard_category_expected_artifacts", "schema_version": 1, "expected_artifacts": []})
        schema_mismatch = copy.deepcopy(base)
        schema_mismatch["configs"] = [dict(schema_mismatch["configs"][0])]
        schema_mismatch["configs"][0]["path"] = schema_mismatch_config.relative_to(ROOT).as_posix() if schema_mismatch_config.is_relative_to(ROOT) else schema_mismatch_config.as_posix()
        schema_mismatch["configs"][0]["schema_name"] = "vort.dashboard_config_index"
        schema_mismatch["config_count"] = len(schema_mismatch["configs"])
        schema_mismatch_file = root / "schema-mismatch.json"
        write_json(schema_mismatch_file, schema_mismatch)
        cases.append(case_row("schema_mismatch", '"schema_matches": false', run_config_smoke(schema_mismatch_file)))

        missing_docs = copy.deepcopy(base)
        missing_docs["configs"] = [dict(missing_docs["configs"][0])]
        missing_docs["configs"][0]["docs_section"] = "## `vort.no_such_dashboard_config`"
        missing_docs["config_count"] = len(missing_docs["configs"])
        missing_docs_file = root / "missing-docs.json"
        write_json(missing_docs_file, missing_docs)
        cases.append(case_row("missing_docs_section", '"docs_section_present": false', run_config_smoke(missing_docs_file)))

        missing_build = copy.deepcopy(base)
        missing_build["configs"] = [dict(missing_build["configs"][0])]
        missing_build["configs"][0]["validation_step"] = "zig build run-no-such-dashboard-config-step"
        missing_build["config_count"] = len(missing_build["configs"])
        missing_build_file = root / "missing-build.json"
        write_json(missing_build_file, missing_build)
        cases.append(case_row("missing_build_step", '"validation_step_present": false', run_config_smoke(missing_build_file)))

        missing_consumer = copy.deepcopy(base)
        missing_consumer["configs"] = [dict(missing_consumer["configs"][0])]
        missing_consumer["configs"][0]["consumer"] = "tools/no_such_dashboard_consumer.py"
        missing_consumer["config_count"] = len(missing_consumer["configs"])
        missing_consumer_file = root / "missing-consumer.json"
        write_json(missing_consumer_file, missing_consumer)
        cases.append(case_row("missing_consumer", '"consumer_exists": false', run_config_smoke(missing_consumer_file)))

        unchecked_schema_config = root / "unchecked-schema-config.json"
        write_json(unchecked_schema_config, {"schema": "vort.validation_json_schema_manifest", "schema_version": 1, "schemas": {}})
        unchecked = copy.deepcopy(base)
        unchecked["configs"] = [dict(unchecked["configs"][0])]
        unchecked["configs"][0].update(
            {
                "path": unchecked_schema_config.as_posix(),
                "schema_name": "vort.validation_json_schema_manifest",
                "docs_section": "## `vort.validation_json_schema_manifest`",
                "validation_step": "zig build run-dashboard-config-index-smoke",
                "consumer": "tools/dashboard_config_index_smoke.py",
            }
        )
        unchecked["config_count"] = len(unchecked["configs"])
        unchecked_file = root / "unchecked-schema.json"
        write_json(unchecked_file, unchecked)
        cases.append(case_row("unchecked_validation_json_schema", '"validation_json_smoke_checked": false', run_config_smoke(unchecked_file)))

    summary = {
        "schema": "vort.dashboard_config_index_negative_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in cases),
        "case_count": len(cases),
        "cases": cases,
    }
    schemas_def = load_manifest()
    expected_case_names = set(schemas_def["vort.dashboard_config_index_negative_smoke"]["item_enums"]["name"])
    actual_case_names = {str(row["name"]) for row in cases}
    missing_cases = sorted(expected_case_names - actual_case_names)
    extra_cases = sorted(actual_case_names - expected_case_names)
    if missing_cases or extra_cases:
        raise AssertionError(f"dashboard config index negative case coverage mismatch: missing={missing_cases!r} extra={extra_cases!r}")
    validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json(path, summary)

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"dashboard_config_index_negative_smoke=ok cases={summary['case_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
