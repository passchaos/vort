#!/usr/bin/env python3
"""Validate JSON examples embedded in docs/validation-json.md."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "validation-json.md"
MANIFEST = ROOT / "tools" / "validation_json_schema_manifest.json"
DASHBOARD_PRODUCERS = ROOT / "tools" / "dashboard_producers.json"

TYPE_MAP: dict[str, type | tuple[type, ...]] = {
    "bool": bool,
    "dict": dict,
    "int": int,
    "int?": (int, type(None)),
    "list": list,
    "str": str,
    "str?": (str, type(None)),
}


def load_manifest() -> dict[str, Any]:
    manifest = json.loads(MANIFEST.read_text())
    if manifest.get("schema") != "vort.validation_json_schema_manifest":
        raise AssertionError("unexpected validation schema manifest")
    if manifest.get("schema_version") != 1:
        raise AssertionError("unsupported validation schema manifest version")
    schemas = manifest.get("schemas")
    if not isinstance(schemas, dict) or not schemas:
        raise AssertionError("validation schema manifest must contain schemas")
    return schemas


def require_fields(value: dict[str, Any], fields: set[str], label: str) -> None:
    missing = fields - value.keys()
    if missing:
        raise AssertionError(f"{label} missing fields: {sorted(missing)}")


def require_types(value: dict[str, Any], field_types: dict[str, str], label: str) -> None:
    for field, type_name in field_types.items():
        expected = TYPE_MAP.get(type_name)
        if expected is None:
            raise AssertionError(f"{label}.{field} has unknown type spec {type_name!r}")
        if not isinstance(value[field], expected):
            raise AssertionError(f"{label}.{field} expected {type_name}, got {type(value[field])}")


def require_enums(value: dict[str, Any], enums: dict[str, list[str]], label: str) -> None:
    for field, allowed_values in enums.items():
        allowed = set(allowed_values)
        if value[field] not in allowed:
            raise AssertionError(f"{label}.{field} has unexpected value {value[field]!r}; allowed={sorted(allowed)}")


def validate_value_against_manifest(value: dict[str, Any], schemas_def: dict[str, Any]) -> None:
    schema = value.get("schema")
    schema_def = schemas_def.get(schema)
    if not isinstance(schema_def, dict):
        raise AssertionError(f"unexpected schema example: {schema!r}")
    fields = schema_def.get("fields")
    if not isinstance(fields, dict):
        raise AssertionError(f"schema {schema!r} must define fields")
    require_fields(value, set(fields), schema)
    require_types(value, fields, schema)
    require_enums(value, schema_def.get("enums", {}), schema)

    item_collection = schema_def.get("item_collection")
    if item_collection:
        item_fields = schema_def.get("item_fields")
        if not isinstance(item_fields, dict):
            raise AssertionError(f"schema {schema!r} must define item_fields")
        items = value.get(item_collection)
        if not isinstance(items, list) or not items:
            raise AssertionError(f"{schema} must include non-empty {item_collection}")
        require_fields(items[0], set(item_fields), f"{schema}.{item_collection}[0]")
        require_types(items[0], item_fields, f"{schema}.{item_collection}[0]")
        require_enums(items[0], schema_def.get("item_enums", {}), f"{schema}.{item_collection}[0]")


def main() -> int:
    schemas_def = load_manifest()
    expected_schemas = set(schemas_def)
    text = DOC.read_text()
    blocks = re.findall(r"```json\n(.*?)\n```", text, re.S)
    parsed = [json.loads(block) for block in blocks]
    schemas = {value.get("schema") for value in parsed if isinstance(value, dict)}
    missing = expected_schemas - schemas
    if missing:
        raise AssertionError(f"missing schema examples: {sorted(missing)}")
    if len(parsed) != len(expected_schemas):
        raise AssertionError(f"expected {len(expected_schemas)} examples, found {len(parsed)}")
    for value in parsed:
        validate_value_against_manifest(value, schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_PRODUCERS.read_text()), schemas_def)
    print(f"validation_json_docs=ok examples={len(parsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
