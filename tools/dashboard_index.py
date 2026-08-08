#!/usr/bin/env python3
"""Write a small Markdown index for zig-out dashboard artifacts."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
from pathlib import Path


def category_for(path: Path) -> str:
    name = path.name
    if (
        "validation" in name
        or "sidecar-corrupt" in name
        or "header-inspect" in name
        or "dashboard-strict" in name
        or "dashboard-producers" in name
        or "dashboard-category" in name
        or "dashboard-config" in name
        or "huffman-length" in name
        or "br-static-dictionary" in name
        or "dynamic-plan" in name
        or "native-allocation" in name
        or "deflate-decode-stage" in name
        or "python-zlib-diff" in name
        or "zstd-native-stream-summary" in name
        or ("zstd-compare" in name and "gate" in name)
        or "fuzz" in name
    ):
        return "validation"
    if "bench" in name or "benchmark" in name or "zstd-compare" in name:
        return "benchmark"
    if "standard" in name or "corpus" in name or "dictionary" in name or "level-report" in name:
        return "corpus and ratio"
    if "parallel" in name or "thread-pool" in name:
        return "native parallel"
    return "other"


def load_producer_map(path: Path) -> dict:
    data = read_json(path)
    if data.get("schema") != "vort.dashboard_producers":
        return {}
    return data


def producer_step_for(path: Path, producer_map: dict) -> str:
    name = path.name
    exact = producer_map.get("exact")
    if isinstance(exact, dict) and name in exact:
        return str(exact[name])

    contains = producer_map.get("contains")
    if isinstance(contains, list):
        for item in contains:
            if not isinstance(item, dict):
                continue
            match = item.get("match")
            producer = item.get("producer_step")
            if isinstance(match, str) and isinstance(producer, str) and match in name:
                return producer

    fallback_exact = {
        "vort-sidecar-corrupt-smoke.md": "zig build run-sidecar-corrupt-dashboard",
        "vort-sidecar-corrupt-smoke.json": "zig build run-sidecar-corrupt-dashboard",
        "vort-validation-json-smoke.json": "zig build run-validation-json-dashboard",
        "vort-dashboard-index.md": "zig build run-dashboard-index",
        "vort-dashboard-index.json": "zig build run-dashboard-index",
        "vort-dictionary-corpus-dashboard.md": "zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard",
        "vort-file-corpus-standard-dashboard.md": "zig build -Doptimize=ReleaseFast run-file-corpus-standard-dashboard",
        "vort-file-corpus-standard-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-file-corpus-standard-full-dashboard",
        "vort-native-parallel-dashboard.md": "zig build -Doptimize=ReleaseFast run-native-parallel-dashboard",
        "vort-native-thread-pool-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-native-thread-pool-full-dashboard",
        "vort-standard-corpus-dashboard.md": "zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard",
        "vort-standard-corpus-full-dashboard.md": "zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard",
    }
    if name in fallback_exact:
        return fallback_exact[name]
    if "native-parallel" in name:
        return "zig build -Doptimize=ReleaseFast bench-native-parallel"
    if "path-dashboard" in name:
        return "zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- <paths>"
    if "tar-dashboard" in name:
        return "zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths <tar>"
    return ""


def is_allowed_missing(path: Path, producer_map: dict) -> bool:
    allow = producer_map.get("allow_missing")
    if not isinstance(allow, dict):
        return False
    name = path.name
    exact = allow.get("exact")
    if isinstance(exact, list) and name in exact:
        return True
    contains = allow.get("contains")
    if isinstance(contains, list):
        return any(isinstance(match, str) and match in name for match in contains)
    return False


def artifact_config_for(path: Path, producer_map: dict) -> dict:
    metadata = producer_map.get("artifact_metadata")
    if not isinstance(metadata, dict):
        return {}
    value = metadata.get(path.name)
    return value if isinstance(value, dict) else {}


def required_smoke_gates(producer_map: dict) -> list[str]:
    required = producer_map.get("required_smoke_gates")
    if not isinstance(required, list):
        return []
    return [name for name in required if isinstance(name, str)]


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


def json_summary(path: Path) -> str:
    data = read_json(path)
    if not data:
        return ""
    schema = data.get("schema")
    rows = data.get("rows")
    ok = data.get("ok")
    parts: list[str] = []
    if schema:
        parts.append(f"schema `{schema}`")
    if rows is not None:
        parts.append(f"rows `{rows}`")
    if ok is not None:
        parts.append(f"ok `{ok}`")
    return ", ".join(parts)


def csv_row_count(path: Path) -> int | None:
    try:
        with path.open(newline="") as f:
            return sum(1 for _ in csv.DictReader(f))
    except Exception:
        return None


def sidecar_corrupt_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.sidecar_corrupt_smoke_report":
            continue
        rows = int(data.get("rows") or 0)
        metadata_ok_rows = int(data.get("metadata_ok_rows") or 0)
        full_rejected_rows = int(data.get("full_rejected_rows") or 0)
        metadata_failed_rows = rows - metadata_ok_rows
        full_not_rejected_rows = rows - full_rejected_rows
        return {
            "present": True,
            "rows": rows,
            "metadata_ok_rows": metadata_ok_rows,
            "full_rejected_rows": full_rejected_rows,
            "metadata_failed_rows": metadata_failed_rows,
            "full_not_rejected_rows": full_not_rejected_rows,
            "healthy": rows > 0 and metadata_failed_rows == 0 and full_not_rejected_rows == 0,
        }
    return {
        "present": False,
        "rows": 0,
        "metadata_ok_rows": 0,
        "full_rejected_rows": 0,
        "metadata_failed_rows": 0,
        "full_not_rejected_rows": 0,
        "healthy": False,
    }


def huffman_length_health(artifacts: list[Path]) -> dict:
    def parse_int(value: str | None) -> int | None:
        try:
            return int(value or "0")
        except ValueError:
            return None

    for artifact in artifacts:
        if artifact.name != "vort-huffman-length-report.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        row_count = len(rows)
        optimal_rows = sum(1 for row in rows if row.get("optimal") == "true")
        package_merge_optimal_rows = sum(1 for row in rows if row.get("package_merge_optimal") == "true")
        gap_values = [parse_int(row.get("gap_bits")) for row in rows]
        package_merge_gap_values = [parse_int(row.get("package_merge_gap_bits")) for row in rows]
        malformed_rows = sum(1 for left, right in zip(gap_values, package_merge_gap_values) if left is None or right is None)
        worst_gap_bits = max((value for value in gap_values if value is not None), default=0)
        package_merge_worst_gap_bits = max((value for value in package_merge_gap_values if value is not None), default=0)
        non_optimal_rows = row_count - optimal_rows
        package_merge_non_optimal_rows = row_count - package_merge_optimal_rows
        return {
            "present": True,
            "row_count": row_count,
            "optimal_rows": optimal_rows,
            "non_optimal_rows": non_optimal_rows,
            "malformed_rows": malformed_rows,
            "worst_gap_bits": worst_gap_bits,
            "package_merge_optimal_rows": package_merge_optimal_rows,
            "package_merge_non_optimal_rows": package_merge_non_optimal_rows,
            "package_merge_worst_gap_bits": package_merge_worst_gap_bits,
            "healthy": row_count > 0
            and malformed_rows == 0
            and non_optimal_rows == 0
            and worst_gap_bits == 0
            and package_merge_non_optimal_rows == 0
            and package_merge_worst_gap_bits == 0,
        }
    return {
        "present": False,
        "row_count": 0,
        "optimal_rows": 0,
        "non_optimal_rows": 0,
        "malformed_rows": 0,
        "worst_gap_bits": 0,
        "package_merge_optimal_rows": 0,
        "package_merge_non_optimal_rows": 0,
        "package_merge_worst_gap_bits": 0,
        "healthy": False,
    }


def fuzz_corpus_health(artifacts: list[Path]) -> dict:
    report = None
    coverage = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.fuzz_corpus_report":
            report = data
        elif schema == "vort.fuzz_corpus_coverage_smoke":
            coverage = data

    def as_int(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    report_present = isinstance(report, dict)
    coverage_present = isinstance(coverage, dict)
    cases = as_int(report, "cases")
    matched_rows = as_int(report, "matched_rows")
    exact_error_expectations = as_int(report, "exact_error_expectations")
    mode_count_rows = as_int(report, "mode_count_rows")
    error_count_rows = as_int(report, "error_count_rows")
    coverage_mode_requirements = as_int(coverage, "mode_requirement_count")
    coverage_error_requirements = as_int(coverage, "error_requirement_count")
    unmatched_rows = cases - matched_rows
    report_healthy = (
        report_present
        and bool(report.get("ok"))
        and cases > 0
        and unmatched_rows == 0
        and exact_error_expectations > 0
        and mode_count_rows > 0
        and error_count_rows > 0
    )
    coverage_healthy = (
        coverage_present
        and bool(coverage.get("ok"))
        and coverage_mode_requirements > 0
        and coverage_error_requirements > 0
    )
    return {
        "present": report_present,
        "ok": bool(report.get("ok")) if report_present else False,
        "coverage_present": coverage_present,
        "coverage_ok": bool(coverage.get("ok")) if coverage_present else False,
        "cases": cases,
        "matched_rows": matched_rows,
        "unmatched_rows": unmatched_rows,
        "exact_error_expectations": exact_error_expectations,
        "mode_count_rows": mode_count_rows,
        "error_count_rows": error_count_rows,
        "coverage_mode_requirements": coverage_mode_requirements,
        "coverage_error_requirements": coverage_error_requirements,
        "report_healthy": report_healthy,
        "coverage_healthy": coverage_healthy,
        "healthy": report_healthy and coverage_healthy,
    }


def decode_stage_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.deflate_decode_stage_report":
            continue
        rows = int(data.get("rows") or 0)
        error_rows = int(data.get("error_rows") or 0)
        matched_error_rows = int(data.get("matched_error_rows") or 0)
        unmatched_error_rows = int(data.get("unmatched_error_rows") or 0)
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "rows": rows,
            "error_rows": error_rows,
            "matched_error_rows": matched_error_rows,
            "unmatched_error_rows": unmatched_error_rows,
            "healthy": bool(data.get("ok")) and rows > 0 and error_rows > 0 and matched_error_rows == error_rows and unmatched_error_rows == 0,
        }
    return {
        "present": False,
        "ok": False,
        "rows": 0,
        "error_rows": 0,
        "matched_error_rows": 0,
        "unmatched_error_rows": 0,
        "healthy": False,
    }


def native_tier_range_health(artifacts: list[Path]) -> dict:
    expected_sources = ("built_in", "project_files", "standard_corpus")
    source_order = (*expected_sources, "custom", "legacy")
    tiers = ("seek_fast", "balanced", "ratio")
    summaries = []
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.native_tier_range_bench_gate":
            summaries.append(data)
    present = len(summaries) > 0
    ok_count = sum(1 for data in summaries if bool(data.get("ok")))
    row_count = sum(int(data.get("rows") or 0) for data in summaries)
    fixture_count = sum(int(data.get("fixture_count") or 0) for data in summaries)
    enforced_count = sum(1 for data in summaries if bool(data.get("enforce_throughput")))
    source_counts = {source: 0 for source in expected_sources}
    source_counts["custom"] = 0
    source_rows = {source: 0 for source in source_counts}
    legacy_count = 0
    legacy_rows = 0
    source_details = {
        source: {
            "source": source,
            "summary_count": 0,
            "ok_count": 0,
            "rows": 0,
            "fixture_count": 0,
            "enforced_count": 0,
            "missing": source in expected_sources,
            "min_range_mib_s_by_tier": {tier: float("inf") for tier in tiers},
            "range_mib_s_floor_by_tier": {tier: 0.0 for tier in tiers},
        }
        for source in source_order
    }
    for data in summaries:
        source = data.get("source")
        rows = int(data.get("rows") or 0)
        source_key = str(source) if source in source_counts else "legacy"
        if source in source_counts:
            source_counts[source] += 1
            source_rows[source] += rows
        else:
            legacy_count += 1
            legacy_rows += rows
        detail = source_details[source_key]
        detail["summary_count"] += 1
        detail["ok_count"] += 1 if bool(data.get("ok")) else 0
        detail["rows"] += rows
        detail["fixture_count"] += int(data.get("fixture_count") or 0)
        detail["enforced_count"] += 1 if bool(data.get("enforce_throughput")) else 0
        min_by_tier = data.get("min_range_mib_s_by_tier")
        floor_by_tier = data.get("range_mib_s_floor_by_tier")
        for tier in tiers:
            if isinstance(min_by_tier, dict):
                value = min_by_tier.get(tier)
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    detail["min_range_mib_s_by_tier"][tier] = min(detail["min_range_mib_s_by_tier"][tier], float(value))
            if isinstance(floor_by_tier, dict):
                value = floor_by_tier.get(tier)
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    # If a source appears multiple times, display the strictest
                    # effective floor so the Markdown table remains conservative.
                    detail["range_mib_s_floor_by_tier"][tier] = max(detail["range_mib_s_floor_by_tier"][tier], float(value))
    missing_sources = [source for source in expected_sources if source_counts[source] == 0]
    for source, detail in source_details.items():
        detail["missing"] = source in expected_sources and detail["summary_count"] == 0
        for tier in tiers:
            if detail["min_range_mib_s_by_tier"][tier] == float("inf"):
                detail["min_range_mib_s_by_tier"][tier] = 0.0

    def tier_min(field: str, tier: str) -> float:
        values = []
        for data in summaries:
            by_tier = data.get(field)
            if isinstance(by_tier, dict):
                value = by_tier.get(tier)
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    values.append(float(value))
        return min(values) if values else 0.0

    healthy = present and ok_count == len(summaries) and row_count > 0 and fixture_count > 0 and not missing_sources and legacy_count == 0
    return {
        "present": present,
        "healthy": healthy,
        "summary_count": len(summaries),
        "ok_count": ok_count,
        "rows": row_count,
        "fixture_count": fixture_count,
        "enforced_count": enforced_count,
        "built_in_summary_count": source_counts["built_in"],
        "project_files_summary_count": source_counts["project_files"],
        "standard_corpus_summary_count": source_counts["standard_corpus"],
        "custom_summary_count": source_counts["custom"],
        "legacy_summary_count": legacy_count,
        "built_in_rows": source_rows["built_in"],
        "project_files_rows": source_rows["project_files"],
        "standard_corpus_rows": source_rows["standard_corpus"],
        "custom_rows": source_rows["custom"],
        "legacy_rows": legacy_rows,
        "missing_sources": missing_sources,
        "source_details": [source_details[source] for source in source_order],
        "seek_fast_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "seek_fast"),
        "balanced_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "balanced"),
        "ratio_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "ratio"),
        "seek_fast_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "seek_fast"),
        "balanced_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "balanced"),
        "ratio_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "ratio"),
    }


def native_tier_corpus_discovery_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_tier_range_corpus_discovery":
            continue
        def int_field(name: str) -> int:
            value = data.get(name)
            return value if isinstance(value, int) and not isinstance(value, bool) else 0

        selected_cases = data.get("selected_cases")
        selected_cases = selected_cases if isinstance(selected_cases, list) else []
        sources = data.get("sources")
        sources = sources if isinstance(sources, list) else []
        missing_reason = data.get("missing_reason")
        limit = data.get("limit")
        limit = limit if isinstance(limit, int) and not isinstance(limit, bool) else None
        candidate_count = int_field("candidate_count")
        source_count = int_field("source_count")
        selected_case_count = int_field("selected_case_count")
        csv_path = str(data.get("csv") or "")
        missing_reason_text = str(missing_reason) if isinstance(missing_reason, str) else ""
        healthy = (
            bool(data.get("ok"))
            and str(data.get("source_mode") or "") in {"discovered", "paths"}
            and candidate_count >= source_count
            and source_count > 0
            and source_count == len(sources)
            and selected_case_count > 0
            and selected_case_count == len(selected_cases)
            and bool(csv_path)
            and isinstance(missing_reason, str)
            and missing_reason_text == ""
        )
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "source_mode": str(data.get("source_mode") or ""),
            "full": bool(data.get("full")),
            "limit": limit,
            "candidate_count": candidate_count,
            "source_count": source_count,
            "selected_case_count": selected_case_count,
            "sources": [str(source) for source in sources],
            "selected_cases": selected_cases,
            "csv": csv_path,
            "missing_reason": missing_reason_text,
            "healthy": healthy,
        }
    return {
        "present": False,
        "ok": False,
        "source_mode": "",
        "full": False,
        "limit": None,
        "candidate_count": 0,
        "source_count": 0,
        "selected_case_count": 0,
        "sources": [],
        "selected_cases": [],
        "csv": "",
        "missing_reason": "missing_discovery_artifact",
        "healthy": False,
    }


def python_zlib_diff_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.python_zlib_diff_smoke":
            continue
        payloads = int(data.get("payloads") or 0)
        large_file_payloads = int(data.get("large_file_payloads") or 0)
        file_hex_encode_cases = int(data.get("file_hex_encode_cases") or 0)
        match_heavy_payloads = int(data.get("match_heavy_payloads") or 0)
        dynamic_payloads = int(data.get("dynamic_payloads") or 0)
        dictionary_cases = int(data.get("dictionary_cases") or 0)
        zlib_dict_encode_cases = int(data.get("zlib_dict_encode_cases") or 0)
        raw_dict_encode_cases = int(data.get("raw_dict_encode_cases") or 0)
        malformed_wrapper_cases = int(data.get("malformed_wrapper_cases") or 0)
        malformed_deflate_cases = int(data.get("malformed_deflate_cases") or 0)
        cli_successes = int(data.get("cli_successes") or 0)
        expected_failures = int(data.get("expected_failures") or 0)
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "payloads": payloads,
            "large_file_payloads": large_file_payloads,
            "file_hex_encode_cases": file_hex_encode_cases,
            "match_heavy_payloads": match_heavy_payloads,
            "dynamic_payloads": dynamic_payloads,
            "dictionary_cases": dictionary_cases,
            "zlib_dict_encode_cases": zlib_dict_encode_cases,
            "raw_dict_encode_cases": raw_dict_encode_cases,
            "malformed_wrapper_cases": malformed_wrapper_cases,
            "malformed_deflate_cases": malformed_deflate_cases,
            "cli_successes": cli_successes,
            "expected_failures": expected_failures,
            "healthy": bool(data.get("ok"))
            and payloads > 0
            and large_file_payloads > 0
            and file_hex_encode_cases > 0
            and match_heavy_payloads > 0
            and dynamic_payloads > 0
            and dictionary_cases > 0
            and zlib_dict_encode_cases > 0
            and raw_dict_encode_cases > 0
            and malformed_wrapper_cases > 0
            and malformed_deflate_cases > 0
            and cli_successes > 0
            and expected_failures > 0,
        }
    return {
        "present": False,
        "ok": False,
        "payloads": 0,
        "large_file_payloads": 0,
        "file_hex_encode_cases": 0,
        "match_heavy_payloads": 0,
        "dynamic_payloads": 0,
        "dictionary_cases": 0,
        "zlib_dict_encode_cases": 0,
        "raw_dict_encode_cases": 0,
        "malformed_wrapper_cases": 0,
        "malformed_deflate_cases": 0,
        "cli_successes": 0,
        "expected_failures": 0,
        "healthy": False,
    }


def native_codec_probes_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_codec_probes":
            continue
        probes = data.get("probes")
        if not isinstance(probes, list):
            probes = []
        ok_probes = sum(1 for probe in probes if isinstance(probe, dict) and probe.get("ok") is True)
        timed_out_probes = sum(1 for probe in probes if isinstance(probe, dict) and probe.get("timed_out") is True)
        probe_cases = {
            str(probe.get("label")): int(probe.get("cases") or 0)
            for probe in probes
            if isinstance(probe, dict)
        }
        capabilities = data.get("capabilities")
        if not isinstance(capabilities, list):
            capabilities = []
        ok_capabilities = sum(1 for row in capabilities if isinstance(row, dict) and row.get("ok") is True)
        capability_cases = {
            str(row.get("capability")): int(row.get("cases") or 0)
            for row in capabilities
            if isinstance(row, dict)
        }
        total_cases = int(data.get("total_cases") or 0)
        capability_count = int(data.get("capability_count") or len(capabilities))
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "healthy": bool(data.get("ok"))
            and ok_probes == int(data.get("probe_count") or 0)
            and ok_probes == 4
            and timed_out_probes == 0
            and capability_count > 0
            and ok_capabilities == capability_count
            and total_cases > 0
            and capability_cases.get("lib-generated", 0) > 0
            and capability_cases.get("incremental", 0) > 0
            and capability_cases.get("chunked", 0) > 0
            and capability_cases.get("reusable-chunked", 0) > 0
            and capability_cases.get("fse-repeat", 0) > 0
            and probe_cases.get("zstd-native-frame-probe", 0) >= 213
            and probe_cases.get("zstd-native-dictionary-probe", 0) >= 25,
            "probe_count": int(data.get("probe_count") or 0),
            "ok_probe_count": ok_probes,
            "timed_out_probes": timed_out_probes,
            "capability_count": capability_count,
            "ok_capability_count": ok_capabilities,
            "lib_generated_cases": capability_cases.get("lib-generated", 0),
            "incremental_cases": capability_cases.get("incremental", 0),
            "chunked_cases": capability_cases.get("chunked", 0),
            "reusable_chunked_cases": capability_cases.get("reusable-chunked", 0),
            "fse_repeat_cases": capability_cases.get("fse-repeat", 0),
            "dictionary_cases": capability_cases.get("dictionary", 0),
            "malformed_cases": capability_cases.get("malformed", 0),
            "total_cases": total_cases,
            "zstd_frame_cases": probe_cases.get("zstd-native-frame-probe", 0),
            "zstd_dictionary_cases": probe_cases.get("zstd-native-dictionary-probe", 0),
        }
    return {
        "present": False,
        "ok": False,
        "healthy": False,
        "probe_count": 0,
        "ok_probe_count": 0,
        "timed_out_probes": 0,
        "capability_count": 0,
        "ok_capability_count": 0,
        "lib_generated_cases": 0,
        "incremental_cases": 0,
        "chunked_cases": 0,
        "reusable_chunked_cases": 0,
        "fse_repeat_cases": 0,
        "dictionary_cases": 0,
        "malformed_cases": 0,
        "total_cases": 0,
        "zstd_frame_cases": 0,
        "zstd_dictionary_cases": 0,
    }


def artifact_metadata(path: Path) -> str:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    return f"{stat.st_size} bytes, updated `{mtime}`"


def dashboard_strict_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.dashboard_strict_smoke":
            missing_modes = data.get("missing_modes")
            if not isinstance(missing_modes, list):
                missing_modes = []
            mode_counts = data.get("mode_counts")
            if not isinstance(mode_counts, list):
                mode_counts = []
            mode_requirements = data.get("mode_requirements")
            if not isinstance(mode_requirements, list):
                mode_requirements = []
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "check_count": int(data.get("check_count") or 0),
                "mode_count": int(data.get("mode_count") or 0),
                "expected_failure_count": sum(int(row.get("expected_failures") or 0) for row in mode_counts if isinstance(row, dict)),
                "matched_count": sum(int(row.get("matched") or 0) for row in mode_counts if isinstance(row, dict)),
                "expected_mode_count": int(data.get("expected_mode_count") or 0),
                "missing_mode_count": int(data.get("missing_mode_count") or 0),
                "missing_checks": sum(int(row.get("missing_checks") or 0) for row in mode_requirements if isinstance(row, dict)),
                "missing_expected_failures": sum(int(row.get("missing_expected_failures") or 0) for row in mode_requirements if isinstance(row, dict)),
                "missing_matched": sum(int(row.get("missing_matched") or 0) for row in mode_requirements if isinstance(row, dict)),
                "missing_modes": missing_modes,
            }
    return {
        "present": False,
        "ok": False,
        "check_count": 0,
        "mode_count": 0,
        "expected_failure_count": 0,
        "matched_count": 0,
        "expected_mode_count": 0,
        "missing_mode_count": 0,
        "missing_checks": 0,
        "missing_expected_failures": 0,
        "missing_matched": 0,
        "missing_modes": [],
    }


def header_inspect_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.header_inspect_smoke":
            missing_workflows = data.get("missing_workflows")
            if not isinstance(missing_workflows, list):
                missing_workflows = []
            def as_int(field: str) -> int:
                value = data.get(field)
                return value if isinstance(value, int) and not isinstance(value, bool) else 0
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "case_count": as_int("case_count"),
                "raw_cases": as_int("raw_cases"),
                "zlib_cases": as_int("zlib_cases"),
                "gzip_cases": as_int("gzip_cases"),
                "negative_cases": as_int("negative_cases"),
                "raw_negative_cases": as_int("raw_negative_cases"),
                "zlib_negative_cases": as_int("zlib_negative_cases"),
                "gzip_negative_cases": as_int("gzip_negative_cases"),
                "command_count": as_int("command_count"),
                "command_successes": as_int("command_successes"),
                "command_failures": as_int("command_failures"),
                "workflow_count": as_int("workflow_count"),
                "workflow_successes": as_int("workflow_successes"),
                "dictionary_cases": as_int("dictionary_cases"),
                "optional_header_cases": as_int("optional_header_cases"),
                "fhcrc_cases": as_int("fhcrc_cases"),
                "required_workflow_count": as_int("required_workflow_count"),
                "missing_workflow_count": as_int("missing_workflow_count"),
                "missing_workflows": missing_workflows,
            }
    return {
        "present": False,
        "ok": False,
        "case_count": 0,
        "raw_cases": 0,
        "zlib_cases": 0,
        "gzip_cases": 0,
        "negative_cases": 0,
        "raw_negative_cases": 0,
        "zlib_negative_cases": 0,
        "gzip_negative_cases": 0,
        "command_count": 0,
        "command_successes": 0,
        "command_failures": 0,
        "workflow_count": 0,
        "workflow_successes": 0,
        "dictionary_cases": 0,
        "optional_header_cases": 0,
        "fhcrc_cases": 0,
        "required_workflow_count": 0,
        "missing_workflow_count": 0,
        "missing_workflows": [],
    }


def artifact_record(path: Path, output_dir: Path, producer_map: dict) -> dict:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = read_json(path) if path.suffix == ".json" else {}
    rows = data.get("rows")
    if rows is None and path.suffix == ".csv":
        rows = csv_row_count(path)
    producer_step = producer_step_for(path, producer_map)
    artifact_config = artifact_config_for(path, producer_map)
    expected_format = artifact_config.get("expected_format", "")
    if expected_format and expected_format != path.suffix.lstrip("."):
        raise ValueError(f"{path.name} expected format {expected_format!r} but found {path.suffix!r}")
    return {
        "name": path.name,
        "path": path.relative_to(output_dir).as_posix(),
        "category": category_for(path),
        "format": path.suffix.lstrip("."),
        "expected_format": expected_format,
        "producer_step": producer_step,
        "producer_missing_allowed": producer_step == "" and is_allowed_missing(path, producer_map),
        "smoke_gate": artifact_config.get("smoke_gate", ""),
        "size_bytes": stat.st_size,
        "mtime_utc": mtime,
        "schema": data.get("schema"),
        "schema_version": data.get("schema_version"),
        "rows": rows,
        "ok": data.get("ok"),
        "required_workflow_count": data.get("required_workflow_count") if data.get("schema") == "vort.header_inspect_smoke" else None,
        "missing_workflow_count": data.get("missing_workflow_count") if data.get("schema") == "vort.header_inspect_smoke" else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="zig-out", help="dashboard artifact directory")
    parser.add_argument("--output", default="zig-out/vort-dashboard-index.md", help="Markdown index path")
    parser.add_argument("--manifest", default="zig-out/vort-dashboard-index.json", help="JSON artifact manifest path")
    parser.add_argument("--producer-map", default="tools/dashboard_producers.json", help="JSON producer-step mapping path")
    parser.add_argument("--strict-producers", action="store_true", help="fail if any artifact lacks a producer_step")
    parser.add_argument("--strict-smoke-gates", action="store_true", help="fail if required artifacts lack a smoke_gate")
    parser.add_argument("--strict-header-inspect", action="store_true", help="fail if header inspect artifact is missing, failed, or has missing workflows")
    parser.add_argument("--strict-validation-health", action="store_true", help="fail if the aggregate validation_healthy flag is false")
    args = parser.parse_args()

    root = Path(args.dir)
    output = Path(args.output)
    manifest = Path(args.manifest)
    producer_map = load_producer_map(Path(args.producer_map))
    artifacts = sorted(
        path
        for path in root.glob("vort-*")
        if path.suffix in {".csv", ".md", ".json"} and path.resolve() not in {output.resolve(), manifest.resolve()}
    )
    grouped: dict[str, list[Path]] = {}
    for artifact in artifacts:
        grouped.setdefault(category_for(artifact), []).append(artifact)

    records = [artifact_record(path, output.parent, producer_map) for path in artifacts]
    producer_step_missing = [record["name"] for record in records if not record["producer_step"] and not record["producer_missing_allowed"]]
    producer_step_allowed_missing = [record["name"] for record in records if not record["producer_step"] and record["producer_missing_allowed"]]
    producer_step_covered = len(records) - len(producer_step_missing)
    smoke_gate_missing = [record["name"] for record in records if not record["smoke_gate"]]
    smoke_gate_covered = len(records) - len(smoke_gate_missing)
    records_by_name = {record["name"]: record for record in records}
    smoke_gate_required_missing = [
        name
        for name in required_smoke_gates(producer_map)
        if name not in records_by_name or not records_by_name[name]["smoke_gate"]
    ]
    header_health = header_inspect_health(artifacts)
    strict_health = dashboard_strict_health(artifacts)
    sidecar_corrupt_health_summary = sidecar_corrupt_health(artifacts)
    huffman_health = huffman_length_health(artifacts)
    fuzz_health = fuzz_corpus_health(artifacts)
    decode_stage_health_summary = decode_stage_health(artifacts)
    python_zlib_health = python_zlib_diff_health(artifacts)
    native_codec_health = native_codec_probes_health(artifacts)
    native_tier_health = native_tier_range_health(artifacts)
    native_tier_discovery_health = native_tier_corpus_discovery_health(artifacts)
    producer_healthy = len(producer_step_missing) == 0
    smoke_gate_healthy = len(smoke_gate_required_missing) == 0
    header_healthy = (
        header_health["present"]
        and header_health["ok"]
        and header_health["missing_workflow_count"] == 0
        and header_health["case_count"] > 0
        and header_health["raw_cases"] > 0
        and header_health["zlib_cases"] > 0
        and header_health["gzip_cases"] > 0
        and header_health["negative_cases"] > 0
        and header_health["raw_negative_cases"] > 0
        and header_health["zlib_negative_cases"] > 0
        and header_health["gzip_negative_cases"] > 0
        and header_health["command_count"] > 0
        and header_health["command_successes"] > 0
        and header_health["command_failures"] > 0
        and header_health["workflow_count"] > 0
        and header_health["workflow_successes"] > 0
        and header_health["dictionary_cases"] > 0
        and header_health["optional_header_cases"] > 0
        and header_health["fhcrc_cases"] > 0
    )
    strict_healthy = strict_health["present"] and strict_health["ok"] and strict_health["missing_mode_count"] == 0
    sidecar_corrupt_healthy = sidecar_corrupt_health_summary["healthy"]
    huffman_healthy = huffman_health["healthy"]
    fuzz_healthy = fuzz_health["healthy"]
    decode_stage_healthy = decode_stage_health_summary["healthy"]
    python_zlib_healthy = python_zlib_health["healthy"]
    native_tier_discovery_healthy = native_tier_discovery_health["healthy"]
    validation_healthy = producer_healthy and smoke_gate_healthy and header_healthy and strict_healthy and sidecar_corrupt_healthy and huffman_healthy and fuzz_healthy and decode_stage_healthy and python_zlib_healthy and native_tier_discovery_healthy
    validation_unhealthy_reasons = []
    if not producer_healthy:
        validation_unhealthy_reasons.append("missing_producer_steps")
    if not smoke_gate_healthy:
        validation_unhealthy_reasons.append("missing_required_smoke_gates")
    if not header_health["present"]:
        validation_unhealthy_reasons.append("missing_header_inspect_artifact")
    elif not header_health["ok"]:
        validation_unhealthy_reasons.append("header_inspect_failed")
    elif header_health["missing_workflow_count"]:
        validation_unhealthy_reasons.append("missing_header_workflows")
    elif not header_healthy:
        validation_unhealthy_reasons.append("header_inspect_undercovered")
    if not strict_health["present"]:
        validation_unhealthy_reasons.append("missing_dashboard_strict_artifact")
    elif not strict_health["ok"]:
        validation_unhealthy_reasons.append("dashboard_strict_failed")
    elif strict_health["missing_mode_count"]:
        validation_unhealthy_reasons.append("missing_dashboard_strict_modes")
    if not sidecar_corrupt_health_summary["present"]:
        validation_unhealthy_reasons.append("missing_sidecar_corrupt_artifact")
    elif not sidecar_corrupt_healthy:
        validation_unhealthy_reasons.append("sidecar_corrupt_failed")
    if not huffman_health["present"]:
        validation_unhealthy_reasons.append("missing_huffman_length_artifact")
    elif not huffman_healthy:
        validation_unhealthy_reasons.append("huffman_length_failed")
    if not fuzz_health["present"]:
        validation_unhealthy_reasons.append("missing_fuzz_corpus_artifact")
    elif not fuzz_health["report_healthy"]:
        validation_unhealthy_reasons.append("fuzz_corpus_failed")
    if not fuzz_health["coverage_present"]:
        validation_unhealthy_reasons.append("missing_fuzz_coverage_artifact")
    elif not fuzz_health["coverage_healthy"]:
        validation_unhealthy_reasons.append("fuzz_coverage_failed")
    if not decode_stage_health_summary["present"]:
        validation_unhealthy_reasons.append("missing_decode_stage_artifact")
    elif not decode_stage_healthy:
        validation_unhealthy_reasons.append("decode_stage_failed")
    if not python_zlib_health["present"]:
        validation_unhealthy_reasons.append("missing_python_zlib_diff_artifact")
    elif not python_zlib_healthy:
        validation_unhealthy_reasons.append("python_zlib_diff_failed")
    if not native_tier_discovery_health["present"]:
        validation_unhealthy_reasons.append("missing_native_tier_corpus_discovery_artifact")
    elif not native_tier_discovery_healthy:
        validation_unhealthy_reasons.append("native_tier_corpus_discovery_failed")

    lines = [
        "# Vort dashboard index",
        "",
        "Generated from `zig-out` artifacts. Paths are relative to this index file.",
        f"",
        f"- artifacts: {len(artifacts)}",
        f"- producer steps: {producer_step_covered}/{len(records)}",
        f"- allowed missing producer steps: {len(producer_step_allowed_missing)}",
        f"- smoke gates: {smoke_gate_covered}/{len(records)}",
        f"- required smoke gates missing: {len(smoke_gate_required_missing)}",
        f"- validation healthy: `{validation_healthy}`",
        f"- validation unhealthy reasons: {len(validation_unhealthy_reasons)}",
        f"- header inspect workflows: {header_health['required_workflow_count']} required, {header_health['missing_workflow_count']} missing, healthy `{header_healthy}`",
        f"- header inspect coverage: cases raw/zlib/gzip {header_health['raw_cases']}/{header_health['zlib_cases']}/{header_health['gzip_cases']}, negatives raw/zlib/gzip {header_health['raw_negative_cases']}/{header_health['zlib_negative_cases']}/{header_health['gzip_negative_cases']}, commands {header_health['command_successes']}/{header_health['command_failures']}, workflows {header_health['workflow_successes']}, dictionary/optional/FHCRC {header_health['dictionary_cases']}/{header_health['optional_header_cases']}/{header_health['fhcrc_cases']}",
        f"- dashboard strict smoke: {strict_health['check_count']} checks, {strict_health['expected_failure_count']} expected failures, {strict_health['matched_count']} matched across {strict_health['mode_count']} modes ({strict_health['missing_mode_count']} missing modes, checks/expected/matched deltas {strict_health['missing_checks']}/{strict_health['missing_expected_failures']}/{strict_health['missing_matched']}), healthy `{strict_healthy}`",
        f"- sidecar corrupt smoke: {sidecar_corrupt_health_summary['metadata_ok_rows']}/{sidecar_corrupt_health_summary['rows']} metadata-ok rows, {sidecar_corrupt_health_summary['full_rejected_rows']}/{sidecar_corrupt_health_summary['rows']} full-rejected rows, healthy `{sidecar_corrupt_healthy}`",
        f"- huffman length oracle: {huffman_health['optimal_rows']}/{huffman_health['row_count']} production optimal rows, {huffman_health['package_merge_optimal_rows']}/{huffman_health['row_count']} package-merge optimal rows, gaps {huffman_health['worst_gap_bits']}/{huffman_health['package_merge_worst_gap_bits']}, malformed rows {huffman_health['malformed_rows']}, healthy `{huffman_healthy}`",
        f"- fuzz corpus coverage: {fuzz_health['matched_rows']}/{fuzz_health['cases']} rows matched, exact-error rows {fuzz_health['exact_error_expectations']}, coverage requirements {fuzz_health['coverage_mode_requirements']}/{fuzz_health['coverage_error_requirements']}, healthy `{fuzz_healthy}`",
        f"- decode-stage smoke: {decode_stage_health_summary['matched_error_rows']}/{decode_stage_health_summary['error_rows']} error rows matched across {decode_stage_health_summary['rows']} timing rows, healthy `{decode_stage_healthy}`",
        f"- Python zlib differential: payloads {python_zlib_health['payloads']} (large-file {python_zlib_health['large_file_payloads']}, file-hex encodes {python_zlib_health['file_hex_encode_cases']}), dynamic {python_zlib_health['dynamic_payloads']}, dictionary encode raw/zlib {python_zlib_health['raw_dict_encode_cases']}/{python_zlib_health['zlib_dict_encode_cases']}, CLI successes/failures {python_zlib_health['cli_successes']}/{python_zlib_health['expected_failures']}, healthy `{python_zlib_healthy}`",
        f"- native codec probes: {native_codec_health['ok_probe_count']}/{native_codec_health['probe_count']} probes ok, capabilities {native_codec_health['ok_capability_count']}/{native_codec_health['capability_count']} ok, cases total/lib/incremental/chunked/reusable-chunked/fse-repeat {native_codec_health['total_cases']}/{native_codec_health['lib_generated_cases']}/{native_codec_health['incremental_cases']}/{native_codec_health['chunked_cases']}/{native_codec_health['reusable_chunked_cases']}/{native_codec_health['fse_repeat_cases']}, healthy `{native_codec_health['healthy']}`",
        f"- native tier range bench: {native_tier_health['ok_count']}/{native_tier_health['summary_count']} summaries ok across {native_tier_health['rows']} rows ({native_tier_health['enforced_count']} throughput-enforced), sources built-in/project/standard/custom/legacy {native_tier_health['built_in_summary_count']}/{native_tier_health['project_files_summary_count']}/{native_tier_health['standard_corpus_summary_count']}/{native_tier_health['custom_summary_count']}/{native_tier_health['legacy_summary_count']} missing {','.join(native_tier_health['missing_sources']) or 'none'}, min range MiB/s seek_fast/balanced/ratio {native_tier_health['seek_fast_min_range_mib_s']:.2f}/{native_tier_health['balanced_min_range_mib_s']:.2f}/{native_tier_health['ratio_min_range_mib_s']:.2f}, healthy `{native_tier_health['healthy']}`",
        f"- native tier corpus discovery: source mode `{native_tier_discovery_health['source_mode']}`, sources {native_tier_discovery_health['source_count']}/{native_tier_discovery_health['candidate_count']}, selected cases {native_tier_discovery_health['selected_case_count']}, missing reason `{native_tier_discovery_health['missing_reason'] or 'none'}`, healthy `{native_tier_discovery_health['healthy']}`",
        "",
    ]
    if native_tier_health["source_details"]:
        lines.extend(
            [
                "## Native tier range source health",
                "",
                "| source | summaries | ok | rows | fixtures | enforced | missing | min range MiB/s seek_fast/balanced/ratio | floor MiB/s seek_fast/balanced/ratio |",
                "| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |",
            ]
        )
        for detail in native_tier_health["source_details"]:
            min_by_tier = detail["min_range_mib_s_by_tier"]
            floor_by_tier = detail["range_mib_s_floor_by_tier"]
            min_text = f"{min_by_tier['seek_fast']:.2f}/{min_by_tier['balanced']:.2f}/{min_by_tier['ratio']:.2f}"
            floor_text = f"{floor_by_tier['seek_fast']:.2f}/{floor_by_tier['balanced']:.2f}/{floor_by_tier['ratio']:.2f}"
            lines.append(
                f"| `{detail['source']}` | {detail['summary_count']} | {detail['ok_count']} | {detail['rows']} | {detail['fixture_count']} | {detail['enforced_count']} | `{detail['missing']}` | {min_text} | {floor_text} |"
            )
        lines.append("")
    if strict_health["missing_modes"]:
        lines.extend(["## Missing dashboard strict modes", "", "| mode | min checks | min expected failures | min matched |", "| --- | ---: | ---: | ---: |"])
        for row in strict_health["missing_modes"]:
            lines.append(f"| `{row.get('mode', '')}` | {row.get('min_checks', '')} | {row.get('min_expected_failures', '')} | {row.get('min_matched', '')} |")
        lines.append("")
    if header_health["missing_workflows"]:
        lines.extend(["## Missing header inspect workflows", "", "| command | workflow | format |", "| --- | --- | --- |"])
        for row in header_health["missing_workflows"]:
            lines.append(f"| `{row.get('command', '')}` | {row.get('workflow', '')} | {row.get('format', '')} |")
        lines.append("")
    for category in sorted(grouped):
        lines.extend([f"## {category}", ""])
        for artifact in grouped[category]:
            rel = artifact.relative_to(output.parent)
            if artifact.suffix == ".json":
                note = json_summary(artifact)
            elif artifact.suffix == ".csv":
                rows = csv_row_count(artifact)
                note = f"rows `{rows}`" if rows is not None else ""
            else:
                note = ""
            metadata = artifact_metadata(artifact)
            suffix = f" — {metadata}"
            producer_step = producer_step_for(artifact, producer_map)
            if producer_step:
                suffix += f", `{producer_step}`"
            if note:
                suffix += f", {note}"
            lines.append(f"- [{artifact.name}]({rel.as_posix()}){suffix}")
        lines.append("")
    if not artifacts:
        lines.append("_No dashboard artifacts found._")
        lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps(
            {
                "schema": "vort.dashboard_index",
                "schema_version": 1,
                "artifact_count": len(records),
                "producer_step_covered": producer_step_covered,
                "producer_step_allowed_missing": producer_step_allowed_missing,
                "producer_step_missing": producer_step_missing,
                "producer_healthy": producer_healthy,
                "smoke_gate_covered": smoke_gate_covered,
                "smoke_gate_missing": smoke_gate_missing,
                "smoke_gate_required_missing": smoke_gate_required_missing,
                "smoke_gate_healthy": smoke_gate_healthy,
                "validation_healthy": validation_healthy,
                "validation_unhealthy_reasons": validation_unhealthy_reasons,
                "header_inspect_present": header_health["present"],
                "header_inspect_ok": header_health["ok"],
                "header_inspect_healthy": header_healthy,
                "header_inspect_case_count": header_health["case_count"],
                "header_inspect_raw_cases": header_health["raw_cases"],
                "header_inspect_zlib_cases": header_health["zlib_cases"],
                "header_inspect_gzip_cases": header_health["gzip_cases"],
                "header_inspect_negative_cases": header_health["negative_cases"],
                "header_inspect_raw_negative_cases": header_health["raw_negative_cases"],
                "header_inspect_zlib_negative_cases": header_health["zlib_negative_cases"],
                "header_inspect_gzip_negative_cases": header_health["gzip_negative_cases"],
                "header_inspect_command_count": header_health["command_count"],
                "header_inspect_command_successes": header_health["command_successes"],
                "header_inspect_command_failures": header_health["command_failures"],
                "header_inspect_workflow_count": header_health["workflow_count"],
                "header_inspect_workflow_successes": header_health["workflow_successes"],
                "header_inspect_dictionary_cases": header_health["dictionary_cases"],
                "header_inspect_optional_header_cases": header_health["optional_header_cases"],
                "header_inspect_fhcrc_cases": header_health["fhcrc_cases"],
                "header_inspect_required_workflow_count": header_health["required_workflow_count"],
                "header_inspect_missing_workflow_count": header_health["missing_workflow_count"],
                "header_inspect_missing_workflows": header_health["missing_workflows"],
                "dashboard_strict_present": strict_health["present"],
                "dashboard_strict_ok": strict_health["ok"],
                "dashboard_strict_healthy": strict_healthy,
                "dashboard_strict_check_count": strict_health["check_count"],
                "dashboard_strict_mode_count": strict_health["mode_count"],
                "dashboard_strict_expected_failure_count": strict_health["expected_failure_count"],
                "dashboard_strict_matched_count": strict_health["matched_count"],
                "dashboard_strict_expected_mode_count": strict_health["expected_mode_count"],
                "dashboard_strict_missing_mode_count": strict_health["missing_mode_count"],
                "dashboard_strict_missing_checks": strict_health["missing_checks"],
                "dashboard_strict_missing_expected_failures": strict_health["missing_expected_failures"],
                "dashboard_strict_missing_matched": strict_health["missing_matched"],
                "dashboard_strict_missing_modes": strict_health["missing_modes"],
                "sidecar_corrupt_present": sidecar_corrupt_health_summary["present"],
                "sidecar_corrupt_healthy": sidecar_corrupt_healthy,
                "sidecar_corrupt_rows": sidecar_corrupt_health_summary["rows"],
                "sidecar_corrupt_metadata_ok_rows": sidecar_corrupt_health_summary["metadata_ok_rows"],
                "sidecar_corrupt_full_rejected_rows": sidecar_corrupt_health_summary["full_rejected_rows"],
                "sidecar_corrupt_metadata_failed_rows": sidecar_corrupt_health_summary["metadata_failed_rows"],
                "sidecar_corrupt_full_not_rejected_rows": sidecar_corrupt_health_summary["full_not_rejected_rows"],
                "huffman_length_present": huffman_health["present"],
                "huffman_length_healthy": huffman_healthy,
                "huffman_length_row_count": huffman_health["row_count"],
                "huffman_length_optimal_rows": huffman_health["optimal_rows"],
                "huffman_length_non_optimal_rows": huffman_health["non_optimal_rows"],
                "huffman_length_malformed_rows": huffman_health["malformed_rows"],
                "huffman_length_worst_gap_bits": huffman_health["worst_gap_bits"],
                "huffman_length_package_merge_optimal_rows": huffman_health["package_merge_optimal_rows"],
                "huffman_length_package_merge_non_optimal_rows": huffman_health["package_merge_non_optimal_rows"],
                "huffman_length_package_merge_worst_gap_bits": huffman_health["package_merge_worst_gap_bits"],
                "fuzz_corpus_present": fuzz_health["present"],
                "fuzz_corpus_ok": fuzz_health["ok"],
                "fuzz_corpus_coverage_present": fuzz_health["coverage_present"],
                "fuzz_corpus_coverage_ok": fuzz_health["coverage_ok"],
                "fuzz_corpus_healthy": fuzz_healthy,
                "fuzz_corpus_cases": fuzz_health["cases"],
                "fuzz_corpus_matched_rows": fuzz_health["matched_rows"],
                "fuzz_corpus_unmatched_rows": fuzz_health["unmatched_rows"],
                "fuzz_corpus_exact_error_expectations": fuzz_health["exact_error_expectations"],
                "fuzz_corpus_mode_count_rows": fuzz_health["mode_count_rows"],
                "fuzz_corpus_error_count_rows": fuzz_health["error_count_rows"],
                "fuzz_corpus_coverage_mode_requirements": fuzz_health["coverage_mode_requirements"],
                "fuzz_corpus_coverage_error_requirements": fuzz_health["coverage_error_requirements"],
                "decode_stage_present": decode_stage_health_summary["present"],
                "decode_stage_ok": decode_stage_health_summary["ok"],
                "decode_stage_healthy": decode_stage_healthy,
                "decode_stage_rows": decode_stage_health_summary["rows"],
                "decode_stage_error_rows": decode_stage_health_summary["error_rows"],
                "decode_stage_matched_error_rows": decode_stage_health_summary["matched_error_rows"],
                "decode_stage_unmatched_error_rows": decode_stage_health_summary["unmatched_error_rows"],
                "python_zlib_diff_present": python_zlib_health["present"],
                "python_zlib_diff_ok": python_zlib_health["ok"],
                "python_zlib_diff_healthy": python_zlib_healthy,
                "python_zlib_diff_payloads": python_zlib_health["payloads"],
                "python_zlib_diff_large_file_payloads": python_zlib_health["large_file_payloads"],
                "python_zlib_diff_file_hex_encode_cases": python_zlib_health["file_hex_encode_cases"],
                "python_zlib_diff_match_heavy_payloads": python_zlib_health["match_heavy_payloads"],
                "python_zlib_diff_dynamic_payloads": python_zlib_health["dynamic_payloads"],
                "python_zlib_diff_dictionary_cases": python_zlib_health["dictionary_cases"],
                "python_zlib_diff_zlib_dict_encode_cases": python_zlib_health["zlib_dict_encode_cases"],
                "python_zlib_diff_raw_dict_encode_cases": python_zlib_health["raw_dict_encode_cases"],
                "python_zlib_diff_malformed_wrapper_cases": python_zlib_health["malformed_wrapper_cases"],
                "python_zlib_diff_malformed_deflate_cases": python_zlib_health["malformed_deflate_cases"],
                "python_zlib_diff_cli_successes": python_zlib_health["cli_successes"],
                "python_zlib_diff_expected_failures": python_zlib_health["expected_failures"],
                "native_codec_probes_present": native_codec_health["present"],
                "native_codec_probes_ok": native_codec_health["ok"],
                "native_codec_probes_healthy": native_codec_health["healthy"],
                "native_codec_probes_probe_count": native_codec_health["probe_count"],
                "native_codec_probes_ok_probe_count": native_codec_health["ok_probe_count"],
                "native_codec_probes_timed_out_probes": native_codec_health["timed_out_probes"],
                "native_codec_probes_capability_count": native_codec_health["capability_count"],
                "native_codec_probes_ok_capability_count": native_codec_health["ok_capability_count"],
                "native_codec_probes_lib_generated_cases": native_codec_health["lib_generated_cases"],
                "native_codec_probes_incremental_cases": native_codec_health["incremental_cases"],
                "native_codec_probes_chunked_cases": native_codec_health["chunked_cases"],
                "native_codec_probes_reusable_chunked_cases": native_codec_health["reusable_chunked_cases"],
                "native_codec_probes_fse_repeat_cases": native_codec_health["fse_repeat_cases"],
                "native_codec_probes_dictionary_cases": native_codec_health["dictionary_cases"],
                "native_codec_probes_malformed_cases": native_codec_health["malformed_cases"],
                "native_codec_probes_total_cases": native_codec_health["total_cases"],
                "native_codec_probes_zstd_frame_cases": native_codec_health["zstd_frame_cases"],
                "native_codec_probes_zstd_dictionary_cases": native_codec_health["zstd_dictionary_cases"],
                "native_tier_range_present": native_tier_health["present"],
                "native_tier_range_healthy": native_tier_health["healthy"],
                "native_tier_range_summary_count": native_tier_health["summary_count"],
                "native_tier_range_ok_count": native_tier_health["ok_count"],
                "native_tier_range_rows": native_tier_health["rows"],
                "native_tier_range_fixture_count": native_tier_health["fixture_count"],
                "native_tier_range_enforced_count": native_tier_health["enforced_count"],
                "native_tier_range_built_in_summary_count": native_tier_health["built_in_summary_count"],
                "native_tier_range_project_files_summary_count": native_tier_health["project_files_summary_count"],
                "native_tier_range_standard_corpus_summary_count": native_tier_health["standard_corpus_summary_count"],
                "native_tier_range_custom_summary_count": native_tier_health["custom_summary_count"],
                "native_tier_range_legacy_summary_count": native_tier_health["legacy_summary_count"],
                "native_tier_range_built_in_rows": native_tier_health["built_in_rows"],
                "native_tier_range_project_files_rows": native_tier_health["project_files_rows"],
                "native_tier_range_standard_corpus_rows": native_tier_health["standard_corpus_rows"],
                "native_tier_range_custom_rows": native_tier_health["custom_rows"],
                "native_tier_range_legacy_rows": native_tier_health["legacy_rows"],
                "native_tier_range_missing_sources": native_tier_health["missing_sources"],
                "native_tier_range_source_details": native_tier_health["source_details"],
                "native_tier_corpus_discovery_present": native_tier_discovery_health["present"],
                "native_tier_corpus_discovery_ok": native_tier_discovery_health["ok"],
                "native_tier_corpus_discovery_healthy": native_tier_discovery_health["healthy"],
                "native_tier_corpus_discovery_source_mode": native_tier_discovery_health["source_mode"],
                "native_tier_corpus_discovery_full": native_tier_discovery_health["full"],
                "native_tier_corpus_discovery_limit": native_tier_discovery_health["limit"],
                "native_tier_corpus_discovery_candidate_count": native_tier_discovery_health["candidate_count"],
                "native_tier_corpus_discovery_source_count": native_tier_discovery_health["source_count"],
                "native_tier_corpus_discovery_sources": native_tier_discovery_health["sources"],
                "native_tier_corpus_discovery_selected_case_count": native_tier_discovery_health["selected_case_count"],
                "native_tier_corpus_discovery_selected_cases": native_tier_discovery_health["selected_cases"],
                "native_tier_corpus_discovery_csv": native_tier_discovery_health["csv"],
                "native_tier_corpus_discovery_missing_reason": native_tier_discovery_health["missing_reason"],
                "native_tier_range_seek_fast_min_range_mib_s": native_tier_health["seek_fast_min_range_mib_s"],
                "native_tier_range_balanced_min_range_mib_s": native_tier_health["balanced_min_range_mib_s"],
                "native_tier_range_ratio_min_range_mib_s": native_tier_health["ratio_min_range_mib_s"],
                "native_tier_range_seek_fast_min_full_input_mib_s": native_tier_health["seek_fast_min_full_input_mib_s"],
                "native_tier_range_balanced_min_full_input_mib_s": native_tier_health["balanced_min_full_input_mib_s"],
                "native_tier_range_ratio_min_full_input_mib_s": native_tier_health["ratio_min_full_input_mib_s"],
                "artifacts": records,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    if args.strict_producers and producer_step_missing:
        missing = ",".join(producer_step_missing)
        raise SystemExit(f"dashboard_index_missing_producers={missing}")
    if args.strict_smoke_gates and smoke_gate_required_missing:
        missing = ",".join(smoke_gate_required_missing)
        raise SystemExit(f"dashboard_index_missing_smoke_gates={missing}")
    if args.strict_header_inspect:
        if not header_health["present"]:
            raise SystemExit("dashboard_index_missing_header_inspect=1")
        if not header_health["ok"]:
            raise SystemExit("dashboard_index_header_inspect_failed=1")
        if header_health["missing_workflow_count"]:
            missing = ",".join(f"{row.get('command')}:{row.get('workflow')}" for row in header_health["missing_workflows"])
            raise SystemExit(f"dashboard_index_header_inspect_missing_workflows={header_health['missing_workflow_count']}:{missing}")
    if args.strict_validation_health and not validation_healthy:
        reasons = ",".join(validation_unhealthy_reasons)
        raise SystemExit(f"dashboard_index_validation_unhealthy={reasons}")
    print(f"dashboard_index={output} manifest={manifest} artifacts={len(artifacts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
