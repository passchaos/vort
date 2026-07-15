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
    "bool?": (bool, type(None)),
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


def require_field_pairs(value: dict[str, Any], field_pairs: dict[str, Any], label: str) -> None:
    for source_field, pair_def in field_pairs.items():
        if not isinstance(pair_def, dict):
            raise AssertionError(f"{label}.{source_field} pair rule must be an object")
        target_field = pair_def.get("target")
        allowed = pair_def.get("allowed")
        if not isinstance(target_field, str) or not isinstance(allowed, dict):
            raise AssertionError(f"{label}.{source_field} pair rule must define target and allowed map")
        source_value = value.get(source_field)
        expected_target = allowed.get(source_value)
        if expected_target is None:
            raise AssertionError(f"{label}.{source_field} has no pair rule for {source_value!r}")
        actual_target = value.get(target_field)
        if actual_target != expected_target:
            raise AssertionError(
                f"{label}.{target_field}={actual_target!r} does not match {source_field}={source_value!r}; expected {expected_target!r}"
            )


def require_list_field_pairs(value: dict[str, Any], list_field_pairs: dict[str, Any], label: str) -> None:
    for list_field, source_fields in list_field_pairs.items():
        if not isinstance(source_fields, list) or not all(isinstance(field, str) for field in source_fields):
            raise AssertionError(f"{label}.{list_field} list pair rule must be a list of field names")
        expected = [value.get(field) for field in source_fields]
        actual = value.get(list_field)
        if actual != expected:
            raise AssertionError(f"{label}.{list_field}={actual!r} does not match fields {source_fields!r}; expected {expected!r}")


def require_count_rules(value: dict[str, Any], count_rules: dict[str, Any], label: str) -> None:
    for count_field, rule in count_rules.items():
        if not isinstance(rule, dict):
            raise AssertionError(f"{label}.{count_field} count rule must be an object")
        collection_name = rule.get("collection")
        if not isinstance(collection_name, str):
            raise AssertionError(f"{label}.{count_field} count rule must define collection")
        items = value.get(collection_name)
        if not isinstance(items, list):
            raise AssertionError(f"{label}.{collection_name} must be a list for count rule {count_field}")
        expected = len(items)
        if "field" in rule:
            field = rule.get("field")
            if not isinstance(field, str):
                raise AssertionError(f"{label}.{count_field} count rule field must be a string")
            match_value = rule.get("equals")
            expected = sum(1 for item in items if isinstance(item, dict) and item.get(field) == match_value)
        actual = value.get(count_field)
        if actual != expected:
            raise AssertionError(f"{label}.{count_field}={actual!r} does not match count rule; expected {expected!r}")


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
    require_count_rules(value, schema_def.get("count_rules", {}), schema)

    item_collection = schema_def.get("item_collection")
    if item_collection:
        item_fields = schema_def.get("item_fields")
        if not isinstance(item_fields, dict):
            raise AssertionError(f"schema {schema!r} must define item_fields")
        validate_item_collection(
            value,
            item_collection,
            item_fields,
            schema_def.get("item_enums", {}),
            schema_def.get("item_field_pairs", {}),
            schema_def.get("item_list_field_pairs", {}),
            schema,
        )

    collections = schema_def.get("collections", {})
    if collections:
        if not isinstance(collections, dict):
            raise AssertionError(f"schema {schema!r} collections must be an object")
        for collection_name, collection_def in collections.items():
            if not isinstance(collection_def, dict):
                raise AssertionError(f"schema {schema!r} collection {collection_name!r} must be an object")
            item_fields = collection_def.get("fields")
            if not isinstance(item_fields, dict):
                raise AssertionError(f"schema {schema!r} collection {collection_name!r} must define fields")
            validate_item_collection(
                value,
                collection_name,
                item_fields,
                collection_def.get("enums", {}),
                collection_def.get("field_pairs", {}),
                collection_def.get("list_field_pairs", {}),
                schema,
            )


def validate_item_collection(
    value: dict[str, Any],
    collection_name: str,
    item_fields: dict[str, str],
    item_enums: dict[str, list[str]],
    item_field_pairs: dict[str, Any],
    item_list_field_pairs: dict[str, Any],
    schema: str,
) -> None:
    items = value.get(collection_name)
    if not isinstance(items, list) or not items:
        raise AssertionError(f"{schema} must include non-empty {collection_name}")
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise AssertionError(f"{schema}.{collection_name}[{index}] must be an object")
        label = f"{schema}.{collection_name}[{index}]"
        require_fields(item, set(item_fields), label)
        require_types(item, item_fields, label)
        require_enums(item, item_enums, label)
        require_field_pairs(item, item_field_pairs, label)
        require_list_field_pairs(item, item_list_field_pairs, label)


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
