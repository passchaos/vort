#!/usr/bin/env python3
"""Validate JSON examples embedded in docs/validation-json.md."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


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

FIELD_TYPES = {
    "vort.validation_report": {
        "schema": str,
        "schema_version": int,
        "target": str,
        "ok": bool,
        "mode": str,
        "stage": str,
        "error": str,
        "recoverability_hint": str,
        "frame_index": (int, type(None)),
        "frame_offset": (int, type(None)),
        "uncompressed_offset": (int, type(None)),
        "frame_flags": (int, type(None)),
        "frame_mode": str,
        "stream_bytes": int,
        "sidecar_bytes": (int, type(None)),
    },
    "vort.sidecar_verify_report": {
        "schema": str,
        "schema_version": int,
        "rows": int,
        "ok_rows": int,
        "error_rows": int,
        "items": list,
    },
    "vort.sidecar_corrupt_smoke_report": {
        "schema": str,
        "schema_version": int,
        "rows": int,
        "metadata_ok_rows": int,
        "full_rejected_rows": int,
        "items": list,
    },
    "vort.validation_json_smoke": {
        "schema": str,
        "schema_version": int,
        "ok": bool,
        "checked_schemas": list,
        "cli_failure_hint": str,
        "report_rows": int,
        "corrupt_rows": int,
    },
    "vort.dashboard_index": {
        "schema": str,
        "schema_version": int,
        "artifact_count": int,
        "artifacts": list,
    },
    "vort.dashboard_producers": {
        "schema": str,
        "schema_version": int,
        "exact": dict,
        "contains": list,
    },
}

ITEM_FIELD_TYPES = {
    "vort.sidecar_verify_report": {
        "stream": str,
        "sidecar": str,
        "mode": str,
        "status": str,
        "error": str,
        "recoverability_hint": str,
        "validation_stage": str,
        "frame_index": (int, type(None)),
        "frame_mode": str,
    },
    "vort.sidecar_corrupt_smoke_report": {
        "case": str,
        "metadata_ok": bool,
        "full_rejected": bool,
        "full_error": str,
        "stream_bytes": int,
        "sidecar_bytes": int,
    },
    "vort.dashboard_index": {
        "name": str,
        "path": str,
        "category": str,
        "format": str,
        "producer_step": str,
        "size_bytes": int,
        "mtime_utc": str,
        "schema": (str, type(None)),
        "schema_version": (int, type(None)),
    },
}

FIELD_ENUMS = {
    "vort.validation_report": {
        "target": {"sidecar", "embedded"},
        "mode": {"metadata", "full"},
        "stage": {
            "index_decode",
            "index_structure",
            "dictionary_parse",
            "frame_bounds",
            "frame_header",
            "frame_metadata",
            "payload_decode",
        },
        "recoverability_hint": {
            "none",
            "index_mismatch",
            "payload_corrupt",
            "retry_with_dictionary",
            "truncated_input",
        },
        "frame_mode": {
            "",
            "store",
            "deflate",
            "rle",
            "dictionary_patch",
            "dictionary_deflate",
            "ldm",
            "unknown",
        },
    },
    "vort.validation_json_smoke": {
        "cli_failure_hint": {
            "none",
            "index_mismatch",
            "payload_corrupt",
            "retry_with_dictionary",
            "truncated_input",
        },
    },
}

ITEM_FIELD_ENUMS = {
    "vort.sidecar_verify_report": {
        "mode": {"metadata", "full"},
        "status": {"ok", "error"},
        "recoverability_hint": {
            "",
            "none",
            "index_mismatch",
            "payload_corrupt",
            "retry_with_dictionary",
            "truncated_input",
        },
        "validation_stage": {
            "",
            "index_decode",
            "index_structure",
            "dictionary_parse",
            "frame_bounds",
            "frame_header",
            "frame_metadata",
            "payload_decode",
        },
        "frame_mode": {
            "",
            "store",
            "deflate",
            "rle",
            "dictionary_patch",
            "dictionary_deflate",
            "ldm",
            "unknown",
        },
    },
    "vort.dashboard_index": {
        "category": {"validation", "corpus and ratio", "native parallel", "other"},
        "format": {"json", "md"},
    },
}


def require_fields(value: dict, fields: set[str], label: str) -> None:
    missing = fields - value.keys()
    if missing:
        raise AssertionError(f"{label} missing fields: {sorted(missing)}")


def require_types(value: dict[str, Any], types: dict[str, type | tuple[type, ...]], label: str) -> None:
    for field, expected in types.items():
        if not isinstance(value[field], expected):
            raise AssertionError(f"{label}.{field} expected {expected}, got {type(value[field])}")


def require_enums(value: dict[str, Any], enums: dict[str, set[str]], label: str) -> None:
    for field, allowed in enums.items():
        if value[field] not in allowed:
            raise AssertionError(f"{label}.{field} has unexpected value {value[field]!r}; allowed={sorted(allowed)}")


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
        require_types(value, FIELD_TYPES[schema], schema)
        require_enums(value, FIELD_ENUMS.get(schema, {}), schema)
        item_fields = ITEM_REQUIRED_FIELDS.get(schema)
        if item_fields:
            items_name = "artifacts" if schema == "vort.dashboard_index" else "items"
            items = value.get(items_name)
            if not isinstance(items, list) or not items:
                raise AssertionError(f"{schema} must include non-empty {items_name}")
            require_fields(items[0], item_fields, f"{schema}.{items_name}[0]")
            require_types(items[0], ITEM_FIELD_TYPES[schema], f"{schema}.{items_name}[0]")
            require_enums(items[0], ITEM_FIELD_ENUMS.get(schema, {}), f"{schema}.{items_name}[0]")
    print(f"validation_json_docs=ok examples={len(parsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
