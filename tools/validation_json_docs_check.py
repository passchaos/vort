#!/usr/bin/env python3
"""Validate JSON examples embedded in docs/validation-json.md."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "validation-json.md"


EXPECTED_SCHEMAS = {
    "vort.validation_report",
    "vort.sidecar_verify_report",
    "vort.sidecar_corrupt_smoke_report",
    "vort.validation_json_smoke",
    "vort.dashboard_index",
    "vort.dashboard_producers",
}

REQUIRED_FIELDS = {
    "vort.validation_report": {
        "schema",
        "schema_version",
        "target",
        "ok",
        "mode",
        "stage",
        "error",
        "recoverability_hint",
        "frame_index",
        "frame_offset",
        "uncompressed_offset",
        "frame_flags",
        "frame_mode",
        "stream_bytes",
        "sidecar_bytes",
    },
    "vort.sidecar_verify_report": {
        "schema",
        "schema_version",
        "rows",
        "ok_rows",
        "error_rows",
        "items",
    },
    "vort.sidecar_corrupt_smoke_report": {
        "schema",
        "schema_version",
        "rows",
        "metadata_ok_rows",
        "full_rejected_rows",
        "items",
    },
    "vort.validation_json_smoke": {
        "schema",
        "schema_version",
        "ok",
        "checked_schemas",
        "cli_failure_hint",
        "report_rows",
        "corrupt_rows",
    },
    "vort.dashboard_index": {
        "schema",
        "schema_version",
        "artifact_count",
        "artifacts",
    },
    "vort.dashboard_producers": {
        "schema",
        "schema_version",
        "exact",
        "contains",
    },
}

ITEM_REQUIRED_FIELDS = {
    "vort.sidecar_verify_report": {
        "stream",
        "sidecar",
        "mode",
        "status",
        "error",
        "recoverability_hint",
        "validation_stage",
        "frame_index",
        "frame_mode",
    },
    "vort.sidecar_corrupt_smoke_report": {
        "case",
        "metadata_ok",
        "full_rejected",
        "full_error",
        "stream_bytes",
        "sidecar_bytes",
    },
    "vort.dashboard_index": {
        "name",
        "path",
        "category",
        "format",
        "producer_step",
        "size_bytes",
        "mtime_utc",
        "schema",
        "schema_version",
    },
}


def require_fields(value: dict, fields: set[str], label: str) -> None:
    missing = fields - value.keys()
    if missing:
        raise AssertionError(f"{label} missing fields: {sorted(missing)}")


def main() -> int:
    text = DOC.read_text()
    blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
    parsed = [json.loads(block) for block in blocks]
    schemas = {value.get("schema") for value in parsed if isinstance(value, dict)}
    missing = EXPECTED_SCHEMAS - schemas
    if missing:
        raise AssertionError(f"missing schema examples: {sorted(missing)}")
    if len(parsed) != len(EXPECTED_SCHEMAS):
        raise AssertionError(f"expected {len(EXPECTED_SCHEMAS)} examples, found {len(parsed)}")
    for value in parsed:
        schema = value.get("schema")
        if schema not in REQUIRED_FIELDS:
            raise AssertionError(f"unexpected schema example: {schema!r}")
        require_fields(value, REQUIRED_FIELDS[schema], schema)
        item_fields = ITEM_REQUIRED_FIELDS.get(schema)
        if item_fields:
            items_name = "artifacts" if schema == "vort.dashboard_index" else "items"
            items = value.get(items_name)
            if not isinstance(items, list) or not items:
                raise AssertionError(f"{schema} must include non-empty {items_name}")
            require_fields(items[0], item_fields, f"{schema}.{items_name}[0]")
    print(f"validation_json_docs=ok examples={len(parsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
