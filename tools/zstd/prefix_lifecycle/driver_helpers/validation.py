"""Strict checks of actual Vort lifecycle receipts and independent C decoding."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


class ValidationError(AssertionError):
    """A lifecycle receipt, physical artifact, or reference check did not match."""


STATELESS_APIS = frozenset({
    "one_shot_encode", "one_shot_level_encode", "one_shot_decode",
})
SUPPORTED_APIS = STATELESS_APIS | frozenset({
    "native_encode", "level_encode", "native_decode",
    "incremental_encode", "incremental_parallel_encode", "incremental_decode",
})
SUPPORTED_OPERATIONS = frozenset({
    "observe", "set_prefix", "set_dictionary", "clear_dictionary",
    "reset_session", "reset_parameters", "reset_all", "encode", "decode",
    "step", "finish", "next_stream", "provide_dictionary",
})
HARNESS_ERRORS = frozenset({
    "UnsupportedStage", "UnsupportedEntry", "UnsupportedDirective",
    "InvalidProbeConfig", "PrefixProbeInvariant", "ProbeDidNotConverge",
    "MissingDictionary",
})


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def _count(value, label: str) -> int:
    _require(type(value) is int and value >= 0, f"{label}: expected a nonnegative integer")
    return value


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_artifact(path, label: str) -> tuple[bytes, dict]:
    _require(isinstance(path, str) and bool(path), f"{label}: missing physical artifact path")
    source = Path(path)
    _require(source.is_absolute(), f"{label}: artifact path must be absolute: {path}")
    try:
        data = source.read_bytes()
    except (OSError, ValueError) as error:
        raise ValidationError(f"{label}: cannot read {path}: {error}") from error
    return data, {"path": str(source.resolve()), "size": len(data), "sha256": _digest(data)}


def _snapshot(event: dict, field: str, label: str):
    _require(field in event and isinstance(event[field], str), f"{label}: {field} must be a JSON string")
    try:
        parsed = json.loads(event[field])
    except (ValueError, TypeError) as error:
        raise ValidationError(f"{label}: invalid {field}: {error}") from error
    _require(parsed is None or isinstance(parsed, dict), f"{label}: {field} must encode an object or null")
    return parsed


def _validate_prefix_snapshot(snapshot, expectation: dict, stateless: bool, label: str) -> dict:
    if stateless:
        _require(snapshot is None, f"{label}: stateless API must report a null prefix snapshot")
        _require("phase" not in expectation, f"{label}: stateless API has no prefix phase")
        return {"stateless": True, "prefix_snapshot_null": True}

    _require(isinstance(snapshot, dict), f"{label}: stateful API must report a prefix snapshot")
    required = {"phase", "pending", "active", "dictionary_id", "content_type", "used_for", "setter_eligible"}
    _require(required <= snapshot.keys(), f"{label}: prefix snapshot is missing {sorted(required - snapshot.keys())}")
    if "usage" in snapshot:
        _require(snapshot["usage"] in ("persistent", "prefix"), f"{label}: unknown prefix usage {snapshot['usage']!r}")
    phase = snapshot["phase"]
    _require(phase in ("none", "pending", "active"), f"{label}: unknown prefix phase {phase!r}")
    for field in ("pending", "active", "setter_eligible"):
        _require(type(snapshot[field]) is bool, f"{label}: prefix {field} must be boolean")
    _require(snapshot["pending"] is (phase == "pending"), f"{label}: pending disagrees with phase {phase}")
    _require(snapshot["active"] is (phase == "active"), f"{label}: active disagrees with phase {phase}")
    _require(snapshot["used_for"] in ("none", "call", "frame", "skippable"), f"{label}: unknown prefix purpose")
    if phase == "none":
        _require(snapshot["dictionary_id"] is None and snapshot["content_type"] is None,
                 f"{label}: cleared prefix retains dictionary metadata")
    else:
        dictionary_id = _count(snapshot["dictionary_id"], f"{label}: prefix dictionary_id")
        _require(dictionary_id <= 0xffffffff, f"{label}: prefix dictionary_id exceeds u32")
        _require(snapshot["content_type"] in ("raw", "full"), f"{label}: live prefix has no valid content type")
        _require(snapshot["used_for"] == "none" if phase == "pending" else snapshot["used_for"] != "none",
                 f"{label}: prefix purpose disagrees with phase {phase}")
    if "phase" in expectation:
        expected_phase = expectation["phase"]
        _require(expected_phase in ("none", "pending", "active"), f"{label}: invalid expected phase {expected_phase!r}")
        _require(phase == expected_phase, f"{label}: expected phase {expected_phase}, found {phase}")
    return {"stateless": False, "phase_consistent": True, "phase": phase,
            "expected_phase": expectation.get("phase")}


def _reference_call(label: str, function, *arguments, **keywords):
    try:
        return function(*arguments, **keywords)
    except Exception as error:
        raise ValidationError(f"{label}: independent reference failed: {error}") from error


def _equal_payload(actual: bytes, expected: bytes, label: str) -> dict:
    _require(isinstance(actual, bytes), f"{label}: reference did not return decoded bytes")
    actual_hash, expected_hash = _digest(actual), _digest(expected)
    _require(len(actual) == len(expected) and actual_hash == expected_hash and actual == expected,
             f"{label}: decoded payload differs: size {len(actual)}/{len(expected)}, SHA-256 {actual_hash}/{expected_hash}")
    return {"equals_payload": True, "size": len(actual), "sha256": actual_hash}


def _without_dictionary_id(wire: bytes, format: str, label: str) -> bytes:
    descriptor_offset = 4 if format == "standard" else 0
    _require(len(wire) > descriptor_offset, f"{label}: missing frame descriptor for normalization")
    descriptor = wire[descriptor_offset]
    dictionary_width = (0, 1, 2, 4)[descriptor & 3]
    dictionary_offset = descriptor_offset + 1 + (0 if descriptor & 0x20 else 1)
    _require(len(wire) >= dictionary_offset + dictionary_width,
             f"{label}: truncated dictionary ID field for normalization")
    return (wire[:descriptor_offset] + bytes([descriptor & 0xfc])
            + wire[descriptor_offset + 1:dictionary_offset]
            + wire[dictionary_offset + dictionary_width:])


def _validate_entropy_control(control, wire: bytes, prefix: bytes, payload: bytes,
                              format: str, library, label: str) -> dict:
    _require(isinstance(control, dict), f"{label}: missing FULL entropy dependency control")
    _require(control.get("entropy_dependency") is True, f"{label}: entropy control does not declare dependency")
    if "mode_inspection_used" in control:
        _require(control["mode_inspection_used"] is False, f"{label}: entropy control relies on inferred repeat modes")
    normalization = control.get("normalization")
    _require(isinstance(normalization, dict), f"{label}: missing entropy wire normalization receipt")
    normalized_wire = _without_dictionary_id(wire, format, label)
    normalized_hash = _digest(normalized_wire)
    _require(type(normalization.get("descriptor_dictionary_id_flag")) is int
             and normalization["descriptor_dictionary_id_flag"] == 0,
             f"{label}: entropy control retains Dictionary_ID descriptor bits")
    _require(normalization.get("normalized_wire_sha256") == normalized_hash,
             f"{label}: normalized wire SHA-256 differs from independent normalization")
    descriptor_offset = 4 if format == "standard" else 0
    _require(normalization.get("original_wire_size") == len(wire)
             and normalization.get("original_wire_sha256") == _digest(wire)
             and normalization.get("normalized_wire_size") == len(normalized_wire)
             and normalization.get("removed_dictionary_id_size") == (0, 1, 2, 4)[wire[descriptor_offset] & 3],
             f"{label}: entropy normalization receipt does not match the original frame")
    normalized_header = _reference_call(label, library.inspect_header, normalized_wire, format=format)
    _require(isinstance(normalized_header, dict) and normalized_header.get("complete") is True
             and normalized_header.get("error") is None and normalized_header.get("frame_type") == "data"
             and normalized_header.get("dictionary_id") == 0,
             f"{label}: normalized entropy control does not have a complete data header with ID zero")
    recorded_header = control.get("normalized_header")
    _require(isinstance(recorded_header, dict), f"{label}: missing normalized header receipt")
    for field in ("complete", "error", "frame_type", "dictionary_id", "content_size", "checksum", "header_size"):
        _require(field in recorded_header and recorded_header[field] == normalized_header.get(field),
                 f"{label}: normalized header receipt differs for {field}")
    positive = control.get("normalized_full_prefix")
    _require(isinstance(positive, dict), f"{label}: missing normalized FULL positive control")
    positive_result = positive.get("result")
    _require(isinstance(positive_result, dict) and positive_result.get("error") is None
             and positive_result.get("ret") == 0 and not positive_result.get("incomplete"),
             f"{label}: normalized FULL positive control did not complete decoding")
    _require(positive.get("accepted") is True and positive.get("equals_payload") is True
             and positive.get("output_size") == len(payload) and positive.get("output_sha256") == _digest(payload),
             f"{label}: normalized FULL positive control differs from payload")
    positive_reference = positive.get("ref_prefix")
    _require(isinstance(positive_reference, dict) and positive_reference.get("ret") == 0
             and positive_reference.get("error") is None and positive_reference.get("prefix_sha256") == _digest(prefix)
             and positive_reference.get("prefix_size") == len(prefix) and positive.get("error_stage") == "decode",
             f"{label}: normalized positive control did not successfully bind the actual FULL prefix")

    history_offset = _reference_call(label, library.dictionary_header_size, prefix)
    _count(history_offset, f"{label}: FULL history offset")
    _require(12 <= history_offset < len(prefix), f"{label}: FULL dictionary has no valid history and repcode section")
    history_hash = _digest(prefix[history_offset:])
    full_repcodes = [int.from_bytes(prefix[offset:offset + 4], "little")
                     for offset in range(history_offset - 12, history_offset, 4)]
    raw = control.get("raw_same_history")
    _require(isinstance(raw, dict), f"{label}: missing RAW same-history negative control")
    _require(control.get("history_sha256") == raw.get("history_sha256") == history_hash,
             f"{label}: entropy controls do not use the actual identical FULL history")
    _require(control.get("history_size") == raw.get("history_size") == len(prefix) - history_offset,
             f"{label}: entropy controls report a different history length")
    for field in ("full_initial_repcodes", "raw_initial_repcodes"):
        values = control.get(field)
        _require(isinstance(values, list) and len(values) == 3 and all(type(value) is int for value in values),
                 f"{label}: {field} must contain three actual integer repcodes")
    _require(control.get("full_initial_repcodes") == full_repcodes == [1, 4, 8]
             and control.get("raw_initial_repcodes") == full_repcodes and control.get("repcodes_equal") is True,
             f"{label}: entropy controls do not preserve identical initial repcodes")
    rep_basis = control.get("raw_repcodes_basis")
    _require(isinstance(rep_basis, dict) and rep_basis.get("kind") == "Zstandard frame-format initial repeated offsets"
             and rep_basis.get("values") == full_repcodes and rep_basis.get("private_context_state_queried") is False,
             f"{label}: RAW repcode defaults lack an explicit normative basis")
    for source_field, hash_field, declaration_field in (
            ("source_path", "source_sha256", "source_declaration"),
            ("reset_source_path", "reset_source_sha256", "reset_declaration")):
        if source_field in rep_basis:
            source, source_artifact = _read_artifact(rep_basis[source_field], f"{label}: RAW repcode source")
            declaration = rep_basis.get(declaration_field)
            _require(rep_basis.get(hash_field) == source_artifact["sha256"]
                     and isinstance(declaration, str) and bool(declaration) and declaration.encode() in source,
                     f"{label}: RAW repcode source receipt differs from its source file")
    _require(type(raw.get("prefix_content_type")) is int and raw["prefix_content_type"] == 1,
             f"{label}: same-history negative control did not use RAW prefix content")
    raw_reference = raw.get("ref_prefix")
    _require(isinstance(raw_reference, dict) and raw_reference.get("ret") == 0 and raw_reference.get("error") is None
             and raw_reference.get("prefix_sha256") == history_hash
             and raw_reference.get("prefix_size") == len(prefix) - history_offset,
             f"{label}: RAW same-history prefix binding did not succeed")
    raw_result = raw.get("result")
    _require(isinstance(raw_result, dict) and raw.get("accepted") is False and raw.get("error_stage") == "decode"
             and not raw_result.get("incomplete"), f"{label}: RAW entropy control is not an actual decoding rejection")
    raw_return = _count(raw_result.get("ret"), f"{label}: RAW decode return code")
    actual_error = _reference_call(label, library.result, raw_return)
    _require(isinstance(actual_error, dict) and actual_error.get("error") == raw_result.get("error")
             and raw_result.get("error") in ("Data corruption detected", "Restored data doesn't match checksum"),
             f"{label}: RAW entropy control rejected for a reason other than data corruption or checksum")
    return {"normalized_wire_sha256": normalized_hash, "history_sha256": history_hash,
            "initial_repcodes": full_repcodes, "raw_decode_error": raw_result["error"],
            "dictionary_id_neutralized": True, "same_history_and_repcodes": True}


def _validate_encoded(wire: bytes, encoded: dict, config: dict, library, label: str) -> dict:
    _require(isinstance(encoded, dict), f"{label}: encoded expectation must be an object")
    mode, kind = encoded.get("mode"), encoded.get("kind")
    _require(mode in ("prefix", "plain", "persistent"), f"{label}: unknown encoded mode {mode!r}")
    _require(kind in ("raw", "full"), f"{label}: unknown dictionary kind {kind!r}")
    payload, payload_artifact = _read_artifact(encoded.get("payload_path"), f"{label}: payload")
    prefix, prefix_artifact = None, None
    if encoded.get("prefix_path") is not None:
        prefix, prefix_artifact = _read_artifact(encoded["prefix_path"], f"{label}: prefix")
    _require(mode == "plain" or prefix is not None, f"{label}: {mode} mode requires prefix bytes")
    format = config.get("format", "standard")
    _require(format in ("standard", "magicless"), f"{label}: unknown frame format {format!r}")
    header = _reference_call(label, library.inspect_header, wire, format=format)
    _require(isinstance(header, dict) and header.get("complete") is True and header.get("error") is None,
             f"{label}: frame header is incomplete or invalid: {header!r}")
    _require(header.get("frame_type") == "data", f"{label}: encoded payload is not a data frame")
    known_size, checksum = config.get("known_size", True), config.get("checksum", True)
    include_id = config.get("include_dictionary_id", True)
    _require(type(known_size) is bool and type(checksum) is bool and type(include_id) is bool,
             f"{label}: frame options must be boolean")
    expected_size = len(payload) if known_size else None
    _require(header.get("content_size") == expected_size,
             f"{label}: content size {header.get('content_size')!r}, expected {expected_size!r}")
    _require(header.get("checksum") is checksum, f"{label}: checksum flag disagrees with config")
    expected_id = 0
    if mode != "plain" and kind == "full" and include_id:
        expected_id = _reference_call(label, library.dictionary_id, prefix)
        _count(expected_id, f"{label}: reference dictionary_id")
    _require(header.get("dictionary_id") == expected_id,
             f"{label}: dictionary ID {header.get('dictionary_id')!r}, expected {expected_id}")

    if mode == "prefix":
        observations = _reference_call(label, library.validate_prefix_wire, wire, prefix, payload,
                                       kind="full" if kind == "full" else "default", format=format)
        _require(isinstance(observations, dict), f"{label}: missing prefix dependency observations")
        for field in ("history_dependency", "entropy_dependency", "prefix_dependency"):
            _require(type(observations.get(field)) is bool, f"{label}: {field} must be an actual boolean")
        history_dependency = observations["history_dependency"]
        entropy_dependency = observations["entropy_dependency"]
        prefix_dependency = observations["prefix_dependency"]
        _require(prefix_dependency is (history_dependency or entropy_dependency),
                 f"{label}: prefix dependency differs from the observed history and entropy dependencies")
        entropy_validation = None
        if kind == "full":
            control = observations.get("wrong_history_control", {})
            _require(isinstance(control, dict) and control.get("full_dictionary_header_unchanged") is True,
                     f"{label}: FULL wrong-history control did not preserve dictionary metadata")
            if entropy_dependency:
                entropy_validation = _validate_entropy_control(observations.get("entropy_control"), wire, prefix,
                                                               payload, format, library, label)
            _require(prefix_dependency is True,
                     f"{label}: FULL prefix frame demonstrates neither history nor entropy dependency: {observations!r}")
        else:
            _require(history_dependency is True and entropy_dependency is False,
                     f"{label}: RAW prefix frame does not demonstrate history dependency: {observations!r}")
        decoded = observations.get("correct_prefix", {})
        _require(isinstance(decoded, dict) and decoded.get("accepted") is True and decoded.get("equals_payload") is True,
                 f"{label}: correct prefix did not decode the payload")
        _require(decoded.get("output_size") == len(payload) and decoded.get("output_sha256") == _digest(payload),
                 f"{label}: correct-prefix decoded size or SHA-256 differs")
        validation = {"history_dependency": history_dependency, "entropy_dependency": entropy_dependency,
                      "prefix_dependency": prefix_dependency, "reference_observations": observations}
        if entropy_validation is not None:
            validation["entropy_control_validation"] = entropy_validation
    else:
        arguments = {"format": format}
        if mode == "persistent":
            arguments["dictionary"] = prefix
        decoded = _reference_call(label, library.decode, wire, **arguments)
        validation = {"decoded": _equal_payload(decoded, payload, label),
                      "reference_dictionary_mode": "none" if mode == "plain" else "persistent"}
    return {"mode": mode, "kind": kind, "payload": payload_artifact, "prefix": prefix_artifact,
            "header": header, **validation}


def validate_case(case: dict, report: dict, library, reference_receipt: dict) -> dict:
    """Validate one scripted case without equating C and Vort step chunking.

    Raw probe events retain the exact JSON snapshot strings. Parsed public
    snapshots and independent reference receipts remain separate observations.
    Only explicitly declared logical input counts are compared.
    """
    _require(isinstance(case, dict) and isinstance(report, dict), "case and report must be objects")
    name = case.get("name", "unnamed")
    config = case.get("config")
    _require(isinstance(config, dict), f"{name}: missing config")
    _require(isinstance(config.get("api"), str) and config["api"] in SUPPORTED_APIS,
             f"{name}: unknown probe API {config.get('api')!r}")
    stages, expectations, events = config.get("stages"), case.get("expectations"), report.get("events")
    _require(isinstance(stages, list) and isinstance(expectations, list) and isinstance(events, list),
             f"{name}: stages, expectations and events must be lists")
    _require(len(stages) == len(expectations) == len(events),
             f"{name}: stage/expectation/event counts differ: {len(stages)}/{len(expectations)}/{len(events)}")
    _require(report.get("completed") is True, f"{name}: probe did not complete")
    _require(report.get("borrowed_assets_preserved") is True, f"{name}: borrowed assets were modified")
    _require(isinstance(reference_receipt, dict), f"{name}: reference receipt must be an object")
    reference_pointer = {"receipt_path": reference_receipt.get("receipt_path"),
                         "recipe_names": case.get("reference_recipe_names", [])}
    api_stateless = config.get("api") in STATELESS_APIS
    result_stages, output_hashes = [], {}
    for index, (stage, expectation, event) in enumerate(zip(stages, expectations, events)):
        label = f"{name} stage {index}"
        _require(all(isinstance(value, dict) for value in (stage, expectation, event)), f"{label}: stage receipts must be objects")
        _require(type(event.get("stage")) is int and event["stage"] == index, f"{label}: event stage index differs")
        _require(event.get("operation") == stage.get("operation") and isinstance(stage.get("operation"), str),
                 f"{label}: event operation differs from script")
        _require(stage["operation"] in SUPPORTED_OPERATIONS, f"{label}: unknown probe operation {stage['operation']!r}")
        _require("error" in expectation, f"{label}: exact error expectation is required")
        expected_error, actual_error = expectation["error"], event.get("error_name")
        _require(expected_error is None or isinstance(expected_error, str) and bool(expected_error),
                 f"{label}: expected error must be null or an exact error name")
        _require("error_name" in event and actual_error == expected_error,
                 f"{label}: expected error {expected_error!r}, found {actual_error!r}")
        _require(actual_error not in HARNESS_ERRORS and not (isinstance(actual_error, str) and actual_error.startswith("Unsupported")),
                 f"{label}: unsupported or failed probe operation: {actual_error}")
        _require(event.get("status") in ("error", "completed", "need_input", "need_output", "done"),
                 f"{label}: unknown actual status {event.get('status')!r}")
        _require(event["status"] == "error" if actual_error is not None else event["status"] != "error",
                 f"{label}: status disagrees with error_name")
        input_read = _count(event.get("input_read"), f"{label}: input_read")
        output_written = _count(event.get("output_written"), f"{label}: output_written")
        if "input_read" in expectation:
            expected_read = _count(expectation["input_read"], f"{label}: expected input_read")
            _require(input_read == expected_read, f"{label}: input_read {input_read}, expected {expected_read}")
        output, output_artifact = _read_artifact(event.get("output_path"), f"{label}: output")
        _require(event.get("output_path") == stage.get("output_path"), f"{label}: output path differs from script")
        _require(output_artifact["size"] == output_written, f"{label}: physical output size differs from receipt")
        _require(output_artifact["sha256"] == event.get("output_sha256"), f"{label}: physical output SHA-256 differs from receipt")
        if "zero_output" in expectation:
            _require(type(expectation["zero_output"]) is bool, f"{label}: zero_output must be boolean")
            _require((output_written == 0) is expectation["zero_output"], f"{label}: zero_output expectation differs")
        prefix_snapshot = _snapshot(event, "prefix_snapshot_json", label)
        stream_snapshot = _snapshot(event, "stream_snapshot_json", label)
        if "stateless" in expectation:
            _require(type(expectation["stateless"]) is bool and expectation["stateless"] is api_stateless,
                     f"{label}: stateless expectation disagrees with API")
        validation = {"exact_error": True, "error_name": actual_error, "physical_output_verified": True,
                      "input_read": input_read, "input_read_compared": "input_read" in expectation,
                      **_validate_prefix_snapshot(prefix_snapshot, expectation, api_stateless, label)}
        if api_stateless:
            _require(stream_snapshot is None, f"{label}: stateless API must report a null stream snapshot")
        if "encoded" in expectation:
            _require(actual_error is None, f"{label}: failed stage cannot provide a successful encoded frame")
            validation["encoded"] = _validate_encoded(output, expectation["encoded"], config, library, label)
        if "decoded_payload_path" in expectation:
            payload, payload_artifact = _read_artifact(expectation["decoded_payload_path"], f"{label}: decoded payload")
            validation["decoded"] = {"payload": payload_artifact, **_equal_payload(output, payload, label)}
        result_stages.append({"stage": index, "operation": event["operation"], "raw": dict(event),
                              "prefix_snapshot": prefix_snapshot, "stream_snapshot": stream_snapshot,
                              "artifact": output_artifact, "validation": validation})
        output_hashes[str(index)] = output_artifact["sha256"]
    return {"name": name, "passed": True, "stages": result_stages, "output_hashes": output_hashes,
            "reference_receipt": reference_pointer, "adapters": case.get("adapters", [])}
