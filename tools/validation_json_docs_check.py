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
DASHBOARD_CONFIG_INDEX = ROOT / "tools" / "dashboard_config_index.json"
DASHBOARD_CATEGORY_EXPECTED_ARTIFACTS = ROOT / "tools" / "dashboard_category_expected_artifacts.json"
DASHBOARD_PRODUCERS = ROOT / "tools" / "dashboard_producers.json"
DASHBOARD_PRODUCER_REQUIRED_ARTIFACTS = ROOT / "tools" / "dashboard_producers_required_artifacts.json"
HEADER_INSPECT_WORKFLOWS = ROOT / "tools" / "header_inspect_required_workflows.json"
DASHBOARD_STRICT_MODES = ROOT / "tools" / "dashboard_strict_expected_modes.json"
DASHBOARD_STRICT_REASONS = ROOT / "tools" / "dashboard_strict_validation_reasons.json"

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
        if isinstance(expected_target, list):
            if actual_target not in expected_target:
                raise AssertionError(
                    f"{label}.{target_field}={actual_target!r} does not match {source_field}={source_value!r}; expected one of {expected_target!r}"
                )
            continue
        if actual_target != expected_target:
            raise AssertionError(
                f"{label}.{target_field}={actual_target!r} does not match {source_field}={source_value!r}; expected {expected_target!r}"
            )


def require_list_field_pairs(value: dict[str, Any], list_field_pairs: dict[str, Any], label: str) -> None:
    for list_field, source_fields in list_field_pairs.items():
        prefix_mode = False
        if isinstance(source_fields, dict):
            prefix_mode = bool(source_fields.get("prefix"))
            source_fields = source_fields.get("fields")
        if not isinstance(source_fields, list) or not all(isinstance(field, str) for field in source_fields):
            raise AssertionError(f"{label}.{list_field} list pair rule must be a list of field names")
        expected = [value.get(field) for field in source_fields]
        actual = value.get(list_field)
        if prefix_mode:
            if not isinstance(actual, list) or actual[: len(expected)] != expected:
                raise AssertionError(f"{label}.{list_field}={actual!r} does not start with fields {source_fields!r}; expected prefix {expected!r}")
            continue
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


def require_dict_sum_rules(value: dict[str, Any], dict_sum_rules: dict[str, str], label: str) -> None:
    for count_field, dict_field in dict_sum_rules.items():
        if not isinstance(dict_field, str):
            raise AssertionError(f"{label}.{count_field} dict sum rule must name a dict field")
        counts = value.get(dict_field)
        if not isinstance(counts, dict):
            raise AssertionError(f"{label}.{dict_field} must be a dict for sum rule {count_field}")
        if not all(isinstance(count, int) and not isinstance(count, bool) for count in counts.values()):
            raise AssertionError(f"{label}.{dict_field} values must all be integers")
        expected = sum(counts.values())
        actual = value.get(count_field)
        if actual != expected:
            raise AssertionError(f"{label}.{count_field}={actual!r} does not match sum({dict_field}); expected {expected!r}")


def require_collection_sum_rules(value: dict[str, Any], collection_sum_rules: dict[str, Any], label: str) -> None:
    for total_field, rule in collection_sum_rules.items():
        if not isinstance(rule, dict):
            raise AssertionError(f"{label}.{total_field} collection sum rule must be an object")
        collection_name = rule.get("collection")
        field = rule.get("field")
        if not isinstance(collection_name, str) or not isinstance(field, str):
            raise AssertionError(f"{label}.{total_field} collection sum rule must define collection and field")
        items = value.get(collection_name)
        if not isinstance(items, list):
            raise AssertionError(f"{label}.{collection_name} must be a list for collection sum rule {total_field}")
        total = 0
        for index, item in enumerate(items):
            if not isinstance(item, dict):
                raise AssertionError(f"{label}.{collection_name}[{index}] must be an object for collection sum rule")
            item_value = item.get(field)
            if not isinstance(item_value, int) or isinstance(item_value, bool):
                raise AssertionError(f"{label}.{collection_name}[{index}].{field} must be an integer for collection sum rule")
            total += item_value
        if value.get(total_field) != total:
            raise AssertionError(f"{label}.{total_field}={value.get(total_field)!r} does not match sum({collection_name}.{field}); expected {total!r}")


def require_list_item_enums(value: dict[str, Any], list_item_enums: dict[str, list[str]], label: str) -> None:
    for list_field, allowed_values in list_item_enums.items():
        payload = value.get(list_field)
        if not isinstance(payload, list):
            raise AssertionError(f"{label}.{list_field} must be a list for item enum validation")
        allowed = set(allowed_values)
        unexpected = sorted(item for item in payload if item not in allowed)
        if unexpected:
            raise AssertionError(f"{label}.{list_field} has unexpected items {unexpected!r}; allowed={sorted(allowed)}")


def require_dict_key_enums(value: dict[str, Any], dict_key_enums: dict[str, list[str]], label: str) -> None:
    for dict_field, allowed_values in dict_key_enums.items():
        payload = value.get(dict_field)
        if not isinstance(payload, dict):
            raise AssertionError(f"{label}.{dict_field} must be a dict for key enum validation")
        allowed = set(allowed_values)
        unexpected = sorted(key for key in payload if key not in allowed)
        if unexpected:
            raise AssertionError(f"{label}.{dict_field} has unexpected keys {unexpected!r}; allowed={sorted(allowed)}")


def condition_matches(value: dict[str, Any], condition: Any, label: str) -> bool:
    if condition is None:
        return True
    if not isinstance(condition, dict):
        raise AssertionError(f"{label} condition must be an object")
    field = condition.get("field")
    if not isinstance(field, str):
        raise AssertionError(f"{label} condition must define a string field")
    if "equals" in condition:
        return value.get(field) == condition["equals"]
    if "not_equals" in condition:
        return value.get(field) != condition["not_equals"]
    raise AssertionError(f"{label} condition must define equals or not_equals")


def require_conditional_fields(value: dict[str, Any], conditional_fields: Any, label: str) -> None:
    if not conditional_fields:
        return
    if not isinstance(conditional_fields, list):
        raise AssertionError(f"{label}.conditional_fields must be a list")
    for index, rule in enumerate(conditional_fields):
        rule_label = f"{label}.conditional_fields[{index}]"
        if not isinstance(rule, dict):
            raise AssertionError(f"{rule_label} must be an object")
        if not condition_matches(value, rule.get("when"), rule_label):
            continue
        for key, expected_null in (("null", True), ("non_null", False)):
            fields = rule.get(key, [])
            if not isinstance(fields, list) or not all(isinstance(field, str) for field in fields):
                raise AssertionError(f"{rule_label}.{key} must be a list of field names")
            for field in fields:
                actual_is_null = value.get(field) is None
                if actual_is_null != expected_null:
                    state = "null" if expected_null else "non-null"
                    raise AssertionError(f"{label}.{field} must be {state} for {rule_label}")


def require_numeric_relations(value: dict[str, Any], numeric_relations: Any, label: str) -> None:
    if not numeric_relations:
        return
    if not isinstance(numeric_relations, list):
        raise AssertionError(f"{label}.numeric_relations must be a list")
    operators = {
        "eq": lambda left, right: left == right,
        "ne": lambda left, right: left != right,
        "lt": lambda left, right: left < right,
        "le": lambda left, right: left <= right,
        "gt": lambda left, right: left > right,
        "ge": lambda left, right: left >= right,
    }
    for index, rule in enumerate(numeric_relations):
        rule_label = f"{label}.numeric_relations[{index}]"
        if not isinstance(rule, dict):
            raise AssertionError(f"{rule_label} must be an object")
        if not condition_matches(value, rule.get("when"), rule_label):
            continue
        left_field = rule.get("left")
        right_field = rule.get("right")
        op_name = rule.get("op")
        offset = rule.get("offset", 0)
        if not isinstance(left_field, str) or not isinstance(right_field, str):
            raise AssertionError(f"{rule_label} must define string left and right fields")
        if op_name not in operators:
            raise AssertionError(f"{rule_label} has unsupported op {op_name!r}")
        if not isinstance(offset, int) or isinstance(offset, bool):
            raise AssertionError(f"{rule_label}.offset must be an integer")
        left = value.get(left_field)
        right = value.get(right_field)
        if not isinstance(left, int) or isinstance(left, bool):
            raise AssertionError(f"{label}.{left_field} must be an integer for {rule_label}")
        if not isinstance(right, int) or isinstance(right, bool):
            raise AssertionError(f"{label}.{right_field} must be an integer for {rule_label}")
        expected_right = right + offset
        if not operators[op_name](left, expected_right):
            suffix = f"{right_field}{offset:+d}" if offset else right_field
            raise AssertionError(f"{label}.{left_field}={left!r} violates {op_name} {suffix} ({expected_right!r})")


def require_difference_relations(value: dict[str, Any], difference_relations: Any, label: str) -> None:
    if not difference_relations:
        return
    if not isinstance(difference_relations, list):
        raise AssertionError(f"{label}.difference_relations must be a list")
    for index, rule in enumerate(difference_relations):
        rule_label = f"{label}.difference_relations[{index}]"
        if not isinstance(rule, dict):
            raise AssertionError(f"{rule_label} must be an object")
        if not condition_matches(value, rule.get("when"), rule_label):
            continue
        left_field = rule.get("left")
        minuend_field = rule.get("minuend")
        subtrahend_field = rule.get("subtrahend")
        if not all(isinstance(field, str) for field in (left_field, minuend_field, subtrahend_field)):
            raise AssertionError(f"{rule_label} must define string left, minuend, and subtrahend fields")
        left = value.get(left_field)
        minuend = value.get(minuend_field)
        subtrahend = value.get(subtrahend_field)
        for field_name, field_value in (
            (left_field, left),
            (minuend_field, minuend),
            (subtrahend_field, subtrahend),
        ):
            if not isinstance(field_value, int) or isinstance(field_value, bool):
                raise AssertionError(f"{label}.{field_name} must be an integer for {rule_label}")
        expected = minuend - subtrahend
        if left != expected:
            raise AssertionError(
                f"{label}.{left_field}={left!r} does not equal {minuend_field}-{subtrahend_field} ({expected!r})"
            )


def require_equality_flag_relations(value: dict[str, Any], equality_flag_relations: Any, label: str) -> None:
    if not equality_flag_relations:
        return
    if not isinstance(equality_flag_relations, list):
        raise AssertionError(f"{label}.equality_flag_relations must be a list")
    for index, rule in enumerate(equality_flag_relations):
        rule_label = f"{label}.equality_flag_relations[{index}]"
        if not isinstance(rule, dict):
            raise AssertionError(f"{rule_label} must be an object")
        if not condition_matches(value, rule.get("when"), rule_label):
            continue
        left_field = rule.get("left")
        right_field = rule.get("right")
        flag_field = rule.get("flag")
        if not isinstance(left_field, str) or not isinstance(right_field, str) or not isinstance(flag_field, str):
            raise AssertionError(f"{rule_label} must define string left, right, and flag fields")
        left = value.get(left_field)
        right = value.get(right_field)
        flag = value.get(flag_field)
        for field_name, field_value in ((left_field, left), (right_field, right)):
            if not isinstance(field_value, int) or isinstance(field_value, bool):
                raise AssertionError(f"{label}.{field_name} must be an integer for {rule_label}")
        if not isinstance(flag, bool):
            raise AssertionError(f"{label}.{flag_field} must be a boolean for {rule_label}")
        expected = left == right
        if flag != expected:
            raise AssertionError(f"{label}.{flag_field}={flag!r} does not match ({left_field} == {right_field})={expected!r}")


def require_boolean_formula_rules(value: dict[str, Any], boolean_formula_rules: dict[str, Any], label: str) -> None:
    for target_field, rule in boolean_formula_rules.items():
        if not isinstance(rule, dict):
            raise AssertionError(f"{label}.{target_field} boolean formula rule must be an object")
        all_fields = rule.get("all", [])
        zero_fields = rule.get("zero", [])
        if not isinstance(all_fields, list) or not all(isinstance(field, str) for field in all_fields):
            raise AssertionError(f"{label}.{target_field}.all must be a list of field names")
        if not isinstance(zero_fields, list) or not all(isinstance(field, str) for field in zero_fields):
            raise AssertionError(f"{label}.{target_field}.zero must be a list of field names")
        expected = True
        for field in all_fields:
            field_value = value.get(field)
            if not isinstance(field_value, bool):
                raise AssertionError(f"{label}.{field} must be a boolean for {target_field} formula")
            expected = expected and field_value
        for field in zero_fields:
            field_value = value.get(field)
            if isinstance(field_value, bool):
                raise AssertionError(f"{label}.{field} must be an integer or list for {target_field} formula")
            if isinstance(field_value, int):
                expected = expected and field_value == 0
                continue
            if isinstance(field_value, list):
                expected = expected and len(field_value) == 0
                continue
            raise AssertionError(f"{label}.{field} must be an integer or list for {target_field} formula")
        actual = value.get(target_field)
        if not isinstance(actual, bool):
            raise AssertionError(f"{label}.{target_field} must be a boolean for formula validation")
        if actual != expected:
            raise AssertionError(f"{label}.{target_field}={actual!r} does not match boolean formula; expected {expected!r}")


def require_nested_schema_fields(
    value: dict[str, Any],
    nested_schema_fields: dict[str, str],
    schemas_def: dict[str, Any],
    label: str,
) -> None:
    for field, expected_schema in nested_schema_fields.items():
        nested = value.get(field)
        if not isinstance(nested, dict):
            raise AssertionError(f"{label}.{field} must be an object for nested schema validation")
        if nested.get("schema") != expected_schema:
            raise AssertionError(f"{label}.{field}.schema={nested.get('schema')!r}, expected {expected_schema!r}")
        validate_value_against_manifest(nested, schemas_def)


def require_header_workflow_manifest_consistency(schemas_def: dict[str, Any]) -> None:
    required = json.loads(HEADER_INSPECT_WORKFLOWS.read_text())
    rows = required.get("required_workflows")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("header inspect required workflows must be non-empty")
    required_commands = {row.get("command") for row in rows if isinstance(row, dict)}
    required_hex_commands = {row.get("command") for row in rows if isinstance(row, dict) and row.get("workflow") == "hex"}
    header_schema = schemas_def.get("vort.header_inspect_smoke", {})
    command_coverage_commands = set(
        header_schema.get("collections", {}).get("command_coverage", {}).get("enums", {}).get("command", [])
    )
    if required_commands != command_coverage_commands:
        raise AssertionError(
            f"header workflow commands differ from command_coverage enum: required={sorted(required_commands)!r} manifest={sorted(command_coverage_commands)!r}"
        )
    case_commands = set(header_schema.get("item_enums", {}).get("command", []))
    if required_hex_commands != case_commands:
        raise AssertionError(
            f"header workflow hex commands differ from case command enum: required={sorted(required_hex_commands)!r} manifest={sorted(case_commands)!r}"
        )


def require_dashboard_strict_mode_manifest_consistency(schemas_def: dict[str, Any]) -> None:
    expected = json.loads(DASHBOARD_STRICT_MODES.read_text())
    rows = expected.get("expected_modes")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("dashboard strict expected modes must be non-empty")
    configured_modes = {row.get("mode") for row in rows if isinstance(row, dict)}
    strict_schema = schemas_def.get("vort.dashboard_strict_smoke", {})
    check_modes = set(strict_schema.get("item_enums", {}).get("mode", []))
    if configured_modes != check_modes:
        raise AssertionError(
            f"dashboard strict expected modes differ from check mode enum: configured={sorted(configured_modes)!r} manifest={sorted(check_modes)!r}"
        )
    mode_count_modes = set(
        strict_schema.get("collections", {}).get("mode_counts", {}).get("enums", {}).get("mode", [])
    )
    if configured_modes != mode_count_modes:
        raise AssertionError(
            f"dashboard strict expected modes differ from mode_counts enum: configured={sorted(configured_modes)!r} manifest={sorted(mode_count_modes)!r}"
        )
    for collection in ("expected_modes", "mode_requirements", "missing_modes"):
        collection_modes = set(
            strict_schema.get("collections", {}).get(collection, {}).get("enums", {}).get("mode", [])
        )
        if configured_modes != collection_modes:
            raise AssertionError(
                f"dashboard strict expected modes differ from {collection} enum: configured={sorted(configured_modes)!r} manifest={sorted(collection_modes)!r}"
            )


def require_dashboard_validation_reason_manifest_consistency(schemas_def: dict[str, Any]) -> None:
    dashboard_schema = schemas_def.get("vort.dashboard_index", {})
    configured_reasons = set(
        dashboard_schema.get("list_item_enums", {}).get("validation_unhealthy_reasons", [])
    )
    if not configured_reasons:
        raise AssertionError("dashboard validation unhealthy reason enum must be non-empty")
    expected = json.loads(DASHBOARD_STRICT_REASONS.read_text())
    rows = expected.get("expected_reasons")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("dashboard strict validation reason config must be non-empty")
    configured_checks = {row.get("check") for row in rows if isinstance(row, dict)}
    configured_fixtures = {row.get("fixture") for row in rows if isinstance(row, dict)}
    configured_reason_rows = {row.get("reason") for row in rows if isinstance(row, dict)}
    if configured_reasons != configured_reason_rows:
        raise AssertionError(
            f"dashboard strict validation reason config differs from dashboard index enum: configured={sorted(configured_reason_rows)!r} dashboard={sorted(configured_reasons)!r}"
        )
    if configured_reasons != configured_fixtures:
        raise AssertionError(
            f"dashboard strict validation reason fixtures differ from dashboard index enum: fixtures={sorted(configured_fixtures)!r} dashboard={sorted(configured_reasons)!r}"
        )
    strict_modes = json.loads(DASHBOARD_STRICT_MODES.read_text()).get("expected_modes", [])
    strict_validation_mode = next(
        (row for row in strict_modes if isinstance(row, dict) and row.get("mode") == "strict-validation-health"),
        None,
    )
    if not isinstance(strict_validation_mode, dict):
        raise AssertionError("dashboard strict expected modes must include strict-validation-health")
    reason_count = len(configured_reasons)
    for field in ("min_checks", "min_expected_failures", "min_matched"):
        value = strict_validation_mode.get(field)
        if not isinstance(value, int) or isinstance(value, bool) or value < reason_count:
            raise AssertionError(
                f"strict-validation-health {field}={value!r} must cover {reason_count} validation unhealthy reasons"
            )
    strict_schema = schemas_def.get("vort.dashboard_strict_smoke", {})
    covered_reasons = set(
        strict_schema.get("collections", {})
        .get("validation_unhealthy_reason_checks", {})
        .get("enums", {})
        .get("reason", [])
    )
    if configured_reasons != covered_reasons:
        raise AssertionError(
            f"dashboard strict validation reason coverage differs from dashboard index enum: configured={sorted(configured_reasons)!r} covered={sorted(covered_reasons)!r}"
        )
    covered_checks = set(
        strict_schema.get("collections", {})
        .get("validation_unhealthy_reason_checks", {})
        .get("enums", {})
        .get("check", [])
    )
    if configured_checks != covered_checks:
        raise AssertionError(
            f"dashboard strict validation reason checks differ from smoke enum: configured={sorted(configured_checks)!r} covered={sorted(covered_checks)!r}"
        )
    reason_config_schema = schemas_def.get("vort.dashboard_strict_validation_reasons", {})
    reason_config_reasons = set(reason_config_schema.get("item_enums", {}).get("reason", []))
    if configured_reasons != reason_config_reasons:
        raise AssertionError(
            f"dashboard strict validation reason config enum differs from dashboard index enum: config={sorted(reason_config_reasons)!r} dashboard={sorted(configured_reasons)!r}"
        )


def require_dashboard_producer_required_manifest_consistency() -> None:
    producers = json.loads(DASHBOARD_PRODUCERS.read_text())
    required = json.loads(DASHBOARD_PRODUCER_REQUIRED_ARTIFACTS.read_text())
    rows = required.get("required_artifacts")
    exact = producers.get("exact")
    metadata = producers.get("artifact_metadata")
    required_smoke_gates = producers.get("required_smoke_gates")
    if not isinstance(rows, list) or not rows:
        raise AssertionError("dashboard producer required artifacts config must be non-empty")
    if not isinstance(exact, dict) or not isinstance(metadata, dict) or not isinstance(required_smoke_gates, list):
        raise AssertionError("dashboard producer map has invalid exact/metadata/required_smoke_gates collections")
    configured_names = {row.get("name") for row in rows if isinstance(row, dict)}
    exact_names = set(exact)
    if configured_names != exact_names:
        raise AssertionError(
            f"dashboard producer required artifacts differ from exact producer map: configured={sorted(configured_names)!r} exact={sorted(exact_names)!r}"
        )
    required_smoke_gate_names = {name for name in required_smoke_gates if isinstance(name, str)}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise AssertionError(f"dashboard producer required_artifacts[{index}] must be an object")
        name = row.get("name")
        if not isinstance(name, str):
            raise AssertionError(f"dashboard producer required_artifacts[{index}].name must be a string")
        item_metadata = metadata.get(name)
        if not isinstance(item_metadata, dict):
            raise AssertionError(f"dashboard producer artifact {name!r} missing artifact_metadata")
        checks = {
            "producer_step": exact.get(name),
            "expected_format": item_metadata.get("expected_format"),
            "smoke_gate": item_metadata.get("smoke_gate"),
            "required_smoke_gate": name in required_smoke_gate_names,
        }
        for field, actual in checks.items():
            expected = row.get(field)
            if actual != expected:
                raise AssertionError(f"dashboard producer artifact {name!r} {field}={actual!r}, expected {expected!r}")


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
    require_field_pairs(value, schema_def.get("field_pairs", {}), schema)
    require_count_rules(value, schema_def.get("count_rules", {}), schema)
    require_dict_sum_rules(value, schema_def.get("dict_sum_rules", {}), schema)
    require_collection_sum_rules(value, schema_def.get("collection_sum_rules", {}), schema)
    require_dict_key_enums(value, schema_def.get("dict_key_enums", {}), schema)
    require_list_item_enums(value, schema_def.get("list_item_enums", {}), schema)
    require_conditional_fields(value, schema_def.get("conditional_fields", []), schema)
    require_numeric_relations(value, schema_def.get("numeric_relations", []), schema)
    require_difference_relations(value, schema_def.get("difference_relations", []), schema)
    require_equality_flag_relations(value, schema_def.get("equality_flag_relations", []), schema)
    require_boolean_formula_rules(value, schema_def.get("boolean_formula_rules", {}), schema)
    require_nested_schema_fields(value, schema_def.get("nested_schema_fields", {}), schemas_def, schema)

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
                bool(collection_def.get("allow_empty", False)),
            )


def validate_item_collection(
    value: dict[str, Any],
    collection_name: str,
    item_fields: dict[str, str],
    item_enums: dict[str, list[str]],
    item_field_pairs: dict[str, Any],
    item_list_field_pairs: dict[str, Any],
    schema: str,
    allow_empty: bool = False,
) -> None:
    items = value.get(collection_name)
    if not isinstance(items, list):
        raise AssertionError(f"{schema}.{collection_name} must be a list")
    if not items and not allow_empty:
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
    validate_value_against_manifest(json.loads(DASHBOARD_CONFIG_INDEX.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_CATEGORY_EXPECTED_ARTIFACTS.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_PRODUCERS.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_PRODUCER_REQUIRED_ARTIFACTS.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(HEADER_INSPECT_WORKFLOWS.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_STRICT_MODES.read_text()), schemas_def)
    validate_value_against_manifest(json.loads(DASHBOARD_STRICT_REASONS.read_text()), schemas_def)
    require_header_workflow_manifest_consistency(schemas_def)
    require_dashboard_strict_mode_manifest_consistency(schemas_def)
    require_dashboard_validation_reason_manifest_consistency(schemas_def)
    require_dashboard_producer_required_manifest_consistency()
    print(f"validation_json_docs=ok examples={len(parsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
