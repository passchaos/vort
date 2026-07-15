#!/usr/bin/env python3
"""Validate the dashboard external-configuration index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validation_json_docs_check import load_manifest, validate_value_against_manifest


ROOT = Path(__file__).resolve().parents[1]
CONFIG_INDEX = ROOT / "tools" / "dashboard_config_index.json"
DOC = ROOT / "docs" / "validation-json.md"
BUILD = ROOT / "build.zig"


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", help="optional JSON summary output path")
    args = parser.parse_args()

    schemas_def = load_manifest()
    docs_text = DOC.read_text()
    build_text = BUILD.read_text()
    checked_schema_values = set(schemas_def["vort.validation_json_smoke"]["list_item_enums"]["checked_schemas"])
    index = load_json(CONFIG_INDEX)
    if index.get("schema") != "vort.dashboard_config_index":
        raise AssertionError("unexpected dashboard config index schema")
    if index.get("schema_version") != 1:
        raise AssertionError("unsupported dashboard config index schema version")
    validate_value_against_manifest(index, schemas_def)

    rows = index.get("configs")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("dashboard config index must include non-empty configs")
    configs: list[dict[str, object]] = []
    seen_paths: set[str] = set()
    seen_schemas: set[str] = set()
    for position, row in enumerate(rows):
        if not isinstance(row, dict):
            raise AssertionError(f"configs[{position}] must be an object")
        path_text = row.get("path")
        schema_name = row.get("schema_name")
        docs_section = row.get("docs_section")
        validation_step = row.get("validation_step")
        consumer = row.get("consumer")
        if not all(isinstance(value, str) for value in (path_text, schema_name, docs_section, validation_step, consumer)):
            raise AssertionError(f"configs[{position}] fields must be strings")
        if path_text in seen_paths:
            raise AssertionError(f"duplicate dashboard config path {path_text!r}")
        if schema_name in seen_schemas:
            raise AssertionError(f"duplicate dashboard config schema {schema_name!r}")
        seen_paths.add(path_text)
        seen_schemas.add(schema_name)

        config_path = ROOT / path_text
        consumer_path = ROOT / consumer
        path_exists = config_path.exists()
        config_payload = load_json(config_path) if path_exists else {}
        schema_matches = config_payload.get("schema") == schema_name
        manifest_schema_present = schema_name in schemas_def
        docs_section_present = docs_section in docs_text
        validation_step_name = validation_step.removeprefix("zig build ")
        validation_step_present = validation_step.startswith("zig build run-") and f'b.step("{validation_step_name}"' in build_text
        consumer_exists = consumer_path.exists()
        validation_json_smoke_checked = schema_name in checked_schema_values
        matched = all(
            (
                path_exists,
                schema_matches,
                manifest_schema_present,
                docs_section_present,
                validation_step_present,
                consumer_exists,
                validation_json_smoke_checked,
            )
        )
        if path_exists and manifest_schema_present:
            validate_value_against_manifest(config_payload, schemas_def)
        configs.append(
            {
                "path": path_text,
                "schema_name": schema_name,
                "docs_section": docs_section,
                "validation_step": validation_step,
                "consumer": consumer,
                "path_exists": path_exists,
                "schema_matches": schema_matches,
                "manifest_schema_present": manifest_schema_present,
                "docs_section_present": docs_section_present,
                "validation_step_present": validation_step_present,
                "consumer_exists": consumer_exists,
                "validation_json_smoke_checked": validation_json_smoke_checked,
                "matched": matched,
            }
        )

    configured_count = index.get("config_count")
    if configured_count != len(configs):
        raise AssertionError(f"dashboard config index config_count={configured_count!r}, expected {len(configs)}")

    summary = {
        "schema": "vort.dashboard_config_index_smoke",
        "schema_version": 1,
        "ok": all(bool(row["matched"]) for row in configs),
        "config_count": len(configs),
        "configs": configs,
    }
    validate_value_against_manifest(summary, schemas_def)

    if args.summary:
        path = Path(args.summary)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if not summary["ok"]:
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 1
    print(f"dashboard_config_index_smoke=ok configs={summary['config_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
