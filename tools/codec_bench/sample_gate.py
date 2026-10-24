#!/usr/bin/env python3
"""Check raw encoder samples against frozen inputs and the legacy CSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path


class EvidenceError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def integer(value: object, label: str, *, positive: bool = False) -> int:
    require(type(value) is int, f"{label}: expected integer")
    require(value > 0 if positive else value >= 0, f"{label}: invalid range")
    return value


def digest(value: object, label: str) -> str:
    require(isinstance(value, str) and len(value) == 64, f"{label}: invalid SHA-256")
    require(all(c in "0123456789abcdef" for c in value), f"{label}: invalid SHA-256")
    return value


def file_digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        while data := handle.read(1024 * 1024):
            sha.update(data)
    return sha.hexdigest()


def median_floor(values: list[int]) -> int:
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) // 2


def manifest_identities(manifest: dict) -> set[tuple[int, str]]:
    inputs = manifest.get("input_sets")
    require(isinstance(inputs, list) and bool(inputs), "manifest: missing inputs")
    identities = set()
    for item in inputs:
        size = integer(item.get("input_bytes"), "manifest.input_bytes", positive=True)
        sha = digest(item.get("input_sha256"), "manifest.input_sha256")
        path = Path(item["frozen_path"])
        require(path.stat().st_size == size and file_digest(path) == sha,
                f"manifest: frozen input changed: {path}")
        identities.add((size, sha))
    return identities


def settings_key(codec: str, row: dict) -> tuple[str, int | None]:
    settings = row.get("settings")
    require(isinstance(settings, dict), "row: missing settings")
    key = "planned_quality" if codec == "brotli" else "level"
    value = settings.get(key)
    if value is not None:
        require(type(value) is int, f"settings.{key}: expected integer")
        require(0 <= value <= 11 if codec == "brotli" else -131072 <= value <= 22,
                f"settings.{key}: unsupported value")
    return row["case"], value


def nullable_integer(value: object, label: str) -> None:
    if value is not None:
        integer(value, label)


def wire_header(value: object, label: str, input_bytes: int) -> None:
    require(isinstance(value, dict), f"{label}: missing wire header")
    require(set(value) >= {"window_size", "content_size", "content_checksum", "dictionary_id"},
            f"{label}: incomplete wire header")
    integer(value["window_size"], f"{label}.window_size", positive=True)
    nullable_integer(value["content_size"], f"{label}.content_size")
    require(value["content_size"] is None or value["content_size"] == input_bytes,
            f"{label}: declared content size differs from input")
    integer(value["dictionary_id"], f"{label}.dictionary_id")
    require(type(value["content_checksum"]) is bool, f"{label}: invalid checksum flag")


def validate_settings(codec: str, settings: dict, input_bytes: int) -> None:
    if codec == "brotli":
        required = {"planned_quality", "vort_api", "vort_level", "vort_mode",
                    "vort_command_state_max_input_kib", "vort_command_state_override_requested",
                    "vort_window_bits", "vort_large_window", "vort_metadata_bytes",
                    "vort_max_total_working_memory", "vort_memory_profile_enabled", "vort_hq_enabled",
                    "reference_quality", "reference_lgwin", "reference_mode"}
        require(set(settings) >= required, "Brotli settings: incomplete primary/reference policy")
        require(settings["vort_mode"] in {"generic", "text", "font"}, "Brotli settings: invalid mode")
        require(settings["vort_level"] == "fast" and bool(settings["vort_api"]),
                "Brotli settings: invalid primary API/level")
        integer(settings["reference_quality"], "settings.reference_quality")
        require(settings["reference_quality"] <= 11, "Brotli settings: invalid reference quality")
        integer(settings["vort_command_state_max_input_kib"], "settings.command_state")
        for field in ("vort_command_state_override_requested", "vort_window_bits", "vort_max_total_working_memory"):
            nullable_integer(settings[field], f"settings.{field}")
        for field in ("vort_large_window", "vort_memory_profile_enabled", "vort_hq_enabled"):
            require(type(settings[field]) is bool, f"settings.{field}: invalid flag")
        integer(settings["vort_metadata_bytes"], "settings.vort_metadata_bytes")
        integer(settings["reference_lgwin"], "settings.reference_lgwin", positive=True)
        integer(settings["reference_mode"], "settings.reference_mode")
        return
    required = {"level", "api", "requested_strategy", "requested_fast_acceleration",
                "requested_native_selection", "resolved_primary", "internal_candidate_settings",
                "wire_header", "reference"}
    require(set(settings) >= required, "Zstd settings: incomplete primary/reference policy")
    require(settings["api"] in {"level_policy", "native_frame"}, "Zstd settings: invalid API")
    require(settings["internal_candidate_settings"] in {"resolved_primary", "public_auto_level_policy"},
            "Zstd settings: missing candidate scope")
    require(settings["internal_candidate_settings"] ==
            ("resolved_primary" if settings["api"] == "native_frame" else "public_auto_level_policy"),
            "Zstd settings: candidate scope differs from API")
    strategies = {"auto", "fast", "double_fast", "greedy", "lazy", "optimal",
                  "lazy2", "btlazy2", "btopt", "btultra", "btultra2"}
    selections = {"auto", "raw_or_rle", "literal_only", "fast_compressed"}
    require(settings["requested_strategy"] is None or settings["requested_strategy"] in strategies,
            "Zstd settings: invalid requested strategy")
    require(settings["requested_native_selection"] is None or settings["requested_native_selection"] in selections,
            "Zstd settings: invalid requested selection")
    primary = settings["resolved_primary"]
    required_primary = {"content_checksum", "include_content_size", "window_log", "max_match_history_len",
                        "max_total_working_memory", "selection", "block_size_max", "dictionary_id",
                        "match_search_budget", "rep_beam_search", "strategy", "fast_acceleration",
                        "hq", "control_profile_enabled", "memory_profile_enabled"}
    require(isinstance(primary, dict) and set(primary) >= required_primary,
            "Zstd settings: incomplete resolved primary")
    for field in ("content_checksum", "include_content_size", "rep_beam_search",
                  "control_profile_enabled", "memory_profile_enabled"):
        require(type(primary[field]) is bool, f"resolved_primary.{field}: invalid flag")
    for field in ("block_size_max", "dictionary_id", "match_search_budget"):
        integer(primary[field], f"resolved_primary.{field}")
    for field in ("window_log", "max_match_history_len", "max_total_working_memory", "fast_acceleration"):
        nullable_integer(primary[field], f"resolved_primary.{field}")
    require(primary["strategy"] in strategies and primary["selection"] in selections,
            "Zstd settings: invalid resolved strategy/selection")
    require(primary["hq"] is None or isinstance(primary["hq"], dict), "Zstd settings: invalid HQ options")
    if primary["hq"] is not None:
        hq = primary["hq"]
        require(set(hq) >= {"search_depth", "nice_len", "min_match", "max_working_memory",
                            "parse_mode", "match_lengths", "max_price_evaluations"},
                "Zstd settings: incomplete effective HQ options")
        for field in ("search_depth", "nice_len", "min_match", "max_working_memory"):
            integer(hq[field], f"resolved_primary.hq.{field}")
        require(hq["parse_mode"] in {"bounded", "whole_block"} and hq["match_lengths"] in {"sampled", "complete"},
                "Zstd settings: invalid HQ search policy")
        nullable_integer(hq["max_price_evaluations"], "resolved_primary.hq.max_price_evaluations")
    nullable_integer(settings["requested_fast_acceleration"], "settings.requested_fast_acceleration")
    wire_header(settings["wire_header"], "settings.wire_header", input_bytes)
    reference = settings["reference"]
    require(isinstance(reference, dict) and set(reference) >= {"api", "level", "internal_parameters", "wire_header"},
            "Zstd settings: incomplete reference policy")
    require(reference["api"] == "ZSTD_compress" and reference["level"] == settings["level"],
            "Zstd settings: reference level/API differs")
    require(isinstance(reference["internal_parameters"], str) and bool(reference["internal_parameters"]),
            "Zstd settings: missing reference parameter scope")
    wire_header(reference["wire_header"], "settings.reference.wire_header", input_bytes)


def validate_csv(report: dict, csv_rows: list[dict[str, str]]) -> None:
    codec = report["codec"]
    key_name = "planned_quality" if codec == "brotli" else "level"
    by_key = {}
    for row in csv_rows:
        setting = int(row[key_name]) if row[key_name] else None
        key = (row["case"], setting)
        require(key not in by_key, f"CSV: duplicate row {key}")
        by_key[key] = row
    require(len(by_key) == len(report["rows"]), "CSV: sample row count differs")
    arch_bits = 32 if report["provenance"]["target_arch"] in {"x86", "arm", "wasm32"} else 64
    mask = (1 << arch_bits) - 1
    for row in report["rows"]:
        key = settings_key(codec, row)
        require(key in by_key, f"CSV: missing row {key}")
        actual = by_key.pop(key)
        expected_version = report.get("reference_version") if codec == "brotli" else report["references"][0].get("version")
        if codec == "brotli":
            require(type(expected_version) is int and int(actual["reference_version"], 16) == expected_version,
                    f"CSV: {key} reference version differs")
        else:
            require(actual["reference_version"] == expected_version, f"CSV: {key} reference version differs")
        for field in ("input_bytes", "iterations"):
            require(int(actual[field]) == row[field], f"CSV: {key} {field} differs")
        require(actual["input_sha256"] == row["input_sha256"], f"CSV: {key} input hash differs")
        if codec == "brotli":
            settings = row["settings"]
            require(int(actual["quality"]) == settings["reference_quality"], f"CSV: {key} reference quality differs")
            require(actual["planned_mode"] == settings["vort_mode"], f"CSV: {key} planned mode differs")
        for implementation in ("vort", "reference"):
            ns = row["summary"][f"{implementation}_min_ns"]
            size = row["wires"][f"{implementation}_bytes"]
            require(int(actual[f"{implementation}_ns"]) == ns, f"CSV: {key} time differs")
            require(int(actual[f"{implementation}_bytes"]) == size, f"CSV: {key} size differs")
            rate = row["input_bytes"] * row["iterations"] * 1e9 / (1048576 * ns)
            printed = actual[f"{implementation}_mib_s"]
            decimals = len(printed.partition(".")[2])
            require(math.isclose(float(printed), rate, rel_tol=1e-12,
                                 abs_tol=0.51 * 10 ** -decimals), f"CSV: {key} throughput differs")
        if codec == "zstd":
            require(int(actual["rounds"]) == len(row["rounds"]), f"CSV: {key} rounds differ")
            selected = [min(row["rounds"], key=lambda r: r[f"{impl}_ns"])[f"{impl}_mix"]
                        for impl in ("vort", "reference")]
            require(int(actual["checksum"]) == sum(selected) & mask, f"CSV: {key} checksum differs")
        provenance = report["provenance"]
        for field in ("executable_sha256", "optimize", "zig_version", "target_arch", "command"):
            require(actual[field] == str(provenance[field]), f"CSV: {key} provenance {field} differs")


def validate(report: dict, manifest: dict, *, csv_rows: list[dict[str, str]] | None = None,
             executable: Path | None = None, require_explicit_references: bool = False) -> dict:
    require(report.get("schema") == "vort.codec_encode_samples" and type(report.get("version")) is int and report.get("version") == 1,
            "report: unsupported schema/version")
    codec = report.get("codec")
    require(codec in {"brotli", "zstd"}, "report: unsupported codec")
    provenance = report.get("provenance")
    require(isinstance(provenance, dict), "report: missing provenance")
    executable_sha = digest(provenance.get("executable_sha256"), "provenance.executable_sha256")
    if executable is not None:
        require(file_digest(executable) == executable_sha, "executable: identity differs")
    require(provenance.get("optimize") == "ReleaseFast", "report: requires ReleaseFast")
    require(provenance.get("benchmark_threads") == 1, "report: requires one benchmark thread")
    require(bool(provenance.get("command")) and bool(provenance.get("cpu_model")),
            "report: incomplete runtime provenance")
    identities = manifest_identities(manifest)
    rows = report.get("rows")
    require(isinstance(rows, list) and bool(rows), "report: missing sample rows")
    arch = provenance.get("target_arch")
    require(arch in {"x86_64", "x86", "aarch64", "arm", "riscv64", "wasm32"},
            "report: unsupported architecture for checksum accounting")
    mask = (1 << (32 if arch in {"x86", "arm", "wasm32"} else 64)) - 1
    seen = set()
    total_rounds = 0
    for row in rows:
        require(isinstance(row.get("case"), str) and bool(row["case"]), "row: missing case")
        size = integer(row.get("input_bytes"), "row.input_bytes", positive=True)
        sha = digest(row.get("input_sha256"), "row.input_sha256")
        require((size, sha) in identities, f"row: input absent from frozen manifest: {row['case']}")
        iterations = integer(row.get("iterations"), "row.iterations", positive=True)
        key = settings_key(codec, row)
        validate_settings(codec, row["settings"], size)
        require(key not in seen, f"row: duplicate setting {key}")
        seen.add(key)
        rounds = row.get("rounds")
        require(isinstance(rounds, list) and bool(rounds), f"row: no raw rounds: {key}")
        if codec == "brotli":
            require(len(rounds) == 5, f"row: Brotli requires all five rounds: {key}")
        wires = row.get("wires")
        require(isinstance(wires, dict), f"row: missing wires: {key}")
        for implementation in ("vort", "reference"):
            integer(wires.get(f"{implementation}_bytes"), f"wires.{implementation}_bytes", positive=True)
            digest(wires.get(f"{implementation}_sha256"), f"wires.{implementation}_sha256")
        for index, raw in enumerate(rounds):
            require(type(raw.get("index")) is int and raw["index"] == index,
                    f"round: missing/out-of-order index: {key}")
            require(type(raw.get("vort_first")) is bool and raw["vort_first"] == (index % 2 == 0),
                    f"round: nonalternating order: {key}")
            for implementation in ("vort", "reference"):
                integer(raw.get(f"{implementation}_ns"), f"round.{implementation}_ns", positive=True)
                mix = integer(raw.get(f"{implementation}_mix"), f"round.{implementation}_mix")
                expected = wires[f"{implementation}_bytes"] * iterations & mask
                require(mix == expected, f"round: wire/iteration checksum differs: {key}")
        summary = row.get("summary")
        require(isinstance(summary, dict), f"row: missing summary: {key}")
        for implementation in ("vort", "reference"):
            times = [raw[f"{implementation}_ns"] for raw in rounds]
            integer(summary.get(f"{implementation}_min_ns"), f"summary.{implementation}_min_ns", positive=True)
            integer(summary.get(f"{implementation}_median_ns"), f"summary.{implementation}_median_ns", positive=True)
            require(summary.get(f"{implementation}_min_ns") == min(times),
                    f"summary: minimum differs: {key}")
            require(summary.get(f"{implementation}_median_ns") == median_floor(times),
                    f"summary: median differs: {key}")
        total_rounds += len(rounds)
    references = report.get("references")
    require(isinstance(references, list), "report: missing references")
    roles = {"brotli_encoder", "brotli_decoder", "brotli_common"} if codec == "brotli" else {"zstd"}
    require(len(references) == len(roles) and {r.get("role") for r in references} == roles,
            "references: missing/duplicate roles")
    for reference in references:
        require(reference.get("loaded_identity") is None and reference.get("dependencies_verified") is False,
                "references: loaded dependency identity is unverified")
        path = reference.get("canonical_file_path")
        sha = reference.get("file_sha256")
        if require_explicit_references:
            require(bool(reference.get("requested_path")) and bool(path), "references: explicit file required")
        if path is not None:
            digest(sha, "reference.file_sha256")
            require(file_digest(Path(path)) == sha, f"reference: identity differs: {path}")
        else:
            require(sha is None, "reference: hash present without an identified file")
    if csv_rows is not None:
        validate_csv(report, csv_rows)
    return {"codec": codec, "rows": len(rows), "rounds": total_rounds,
            "input_identity": "verified frozen length and SHA-256",
            "reference_scope": "requested files only; loaded dependency identities unverified"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples-json", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--require-explicit-references", action="store_true")
    args = parser.parse_args()
    csv_rows = None
    if args.csv:
        with args.csv.open(newline="") as handle:
            csv_rows = list(csv.DictReader(handle))
    result = validate(json.loads(args.samples_json.read_text()), json.loads(args.manifest.read_text()),
                      csv_rows=csv_rows, executable=args.executable,
                      require_explicit_references=args.require_explicit_references)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
