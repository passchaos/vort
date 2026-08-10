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
        or "native-summary-error" in name
        or "lz4-native-stream-summary" in name
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


def format_markdown_counts(counts: dict) -> str:
    """Render small count maps in a stable order for dashboard table cells."""
    parts: list[str] = []
    for key, value in sorted((str(key), value) for key, value in counts.items()):
        count = int(value) if isinstance(value, int) and not isinstance(value, bool) else 0
        parts.append(f"`{key}`={count}")
    return "<br>".join(parts) if parts else "`none`"


def format_markdown_list(values: list) -> str:
    parts = [f"`{value}`" for value in (str(value) for value in values)]
    return ", ".join(parts) if parts else "`none`"


def format_markdown_offset_range(value: object) -> str:
    if not isinstance(value, dict):
        return "`missing`"
    minimum = value.get("min")
    maximum = value.get("max")
    if not isinstance(minimum, int) or isinstance(minimum, bool) or not isinstance(maximum, int) or isinstance(maximum, bool):
        return "`invalid`"
    return f"`{minimum}..{maximum}`"


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
        lz4_error_counts = data.get("lz4_error_counts") if isinstance(data.get("lz4_error_counts"), dict) else {}
        zstd_error_counts = data.get("zstd_error_counts") if isinstance(data.get("zstd_error_counts"), dict) else {}
        lz4_phase_counts = data.get("lz4_phase_counts") if isinstance(data.get("lz4_phase_counts"), dict) else {}
        zstd_phase_counts = data.get("zstd_phase_counts") if isinstance(data.get("zstd_phase_counts"), dict) else {}
        offset_min = int(data.get("offset_min") or 0)
        offset_max = int(data.get("offset_max") or 0)
        lz4_offset_min = int(data.get("lz4_offset_min") or 0)
        lz4_offset_max = int(data.get("lz4_offset_max") or 0)
        zstd_offset_min = int(data.get("zstd_offset_min") or 0)
        zstd_offset_max = int(data.get("zstd_offset_max") or 0)
        phase_offset_ranges = data.get("phase_offset_ranges") if isinstance(data.get("phase_offset_ranges"), dict) else {}
        required_codec_phases = data.get("required_codec_phases") if isinstance(data.get("required_codec_phases"), dict) else {}
        lz4_required_phases = required_codec_phases.get("lz4") if isinstance(required_codec_phases.get("lz4"), list) else []
        zstd_required_phases = required_codec_phases.get("zstd") if isinstance(required_codec_phases.get("zstd"), list) else []
        lz4_missing_phases = sorted(str(phase) for phase in lz4_required_phases if int(lz4_phase_counts.get(str(phase)) or 0) == 0)
        zstd_missing_phases = sorted(str(phase) for phase in zstd_required_phases if int(zstd_phase_counts.get(str(phase)) or 0) == 0)
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
        if schema == "vort.fuzz_corpus_report" and artifact.name == "vort-deflate-wrapper-fuzz-corpus.json":
            report = data
        elif schema == "vort.fuzz_corpus_coverage_smoke" and artifact.name == "vort-fuzz-corpus-coverage-smoke.json":
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


def native_fuzz_corpus_health(artifacts: list[Path]) -> dict:
    report = None
    coverage = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.fuzz_corpus_report" and artifact.name == "vort-native-fuzz-corpus.json":
            report = data
        elif data.get("schema") == "vort.fuzz_corpus_coverage_smoke" and artifact.name == "vort-native-fuzz-corpus-coverage-smoke.json":
            coverage = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    report_present = isinstance(report, dict)
    coverage_present = isinstance(coverage, dict)
    cases = int_field(report, "cases")
    matched_rows = int_field(report, "matched_rows")
    unmatched_rows = cases - matched_rows
    exact_error_expectations = int_field(report, "exact_error_expectations")
    mode_count_rows = int_field(report, "mode_count_rows")
    error_count_rows = int_field(report, "error_count_rows")
    coverage_mode_requirements = int_field(coverage, "mode_requirement_count")
    coverage_error_requirements = int_field(coverage, "error_requirement_count")
    healthy = (
        report_present
        and coverage_present
        and bool(report.get("ok"))
        and bool(coverage.get("ok"))
        and str(report.get("mode") or "") == "native"
        and cases > 0
        and matched_rows == cases
        and unmatched_rows == 0
        and exact_error_expectations > 0
        and mode_count_rows > 0
        and error_count_rows > 0
        and coverage_mode_requirements > 0
        and coverage_error_requirements > 0
    )
    return {
        "present": report_present,
        "coverage_present": coverage_present,
        "healthy": healthy,
        "cases": cases,
        "accepted": int_field(report, "accepted"),
        "rejected": int_field(report, "rejected"),
        "matched_rows": matched_rows,
        "unmatched_rows": unmatched_rows,
        "exact_error_expectations": exact_error_expectations,
        "mode_count_rows": mode_count_rows,
        "error_count_rows": error_count_rows,
        "coverage_mode_requirements": coverage_mode_requirements,
        "coverage_error_requirements": coverage_error_requirements,
    }


def br_static_dictionary_health(artifacts: list[Path]) -> dict:
    # Multiple exploratory Brotli static-dictionary probes intentionally share
    # the same schemas as the canonical smoke artifacts. Keep this aggregate
    # health gate pinned to the stable CI artifact names so stale wide-probe
    # outputs in zig-out cannot make the dashboard look healthier or less
    # healthy than the retained validation set.
    candidate = None
    upstream = None
    node = None
    audit = None
    negative = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.br_static_dictionary_candidate_report" and artifact.name == "vort-br-static-dictionary-candidates.json":
            candidate = data
        elif schema == "vort.br_static_dictionary_candidate_upstream_smoke" and artifact.name == "vort-br-static-dictionary-candidate-upstream-smoke.json":
            upstream = data
        elif schema == "vort.br_static_dictionary_node_probe" and artifact.name == "vort-br-static-dictionary-node-probe.json":
            node = data
        elif schema == "vort.br_static_dictionary_source_audit" and artifact.name == "vort-br-static-dictionary-source-audit.json":
            audit = data
        elif schema == "vort.br_static_dictionary_source_audit_negative_smoke" and artifact.name == "vort-br-static-dictionary-source-audit-negative-smoke.json":
            negative = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    negative_cases = negative.get("cases") if isinstance(negative, dict) else []
    negative_cases = negative_cases if isinstance(negative_cases, list) else []
    negative_matched = sum(1 for row in negative_cases if isinstance(row, dict) and row.get("matched") is True)
    candidate_present = isinstance(candidate, dict)
    upstream_present = isinstance(upstream, dict)
    node_present = isinstance(node, dict)
    audit_present = isinstance(audit, dict)
    negative_present = isinstance(negative, dict)
    candidate_count = int_field(candidate, "candidate_count")
    raw_word_count = int_field(candidate, "raw_word_count")
    upstream_candidate_count = int_field(upstream, "candidate_count")
    upstream_raw_word_count = int_field(upstream, "raw_word_count")
    node_probed_count = int_field(node, "probed_count")
    node_decode_successes = int_field(node, "node_decode_successes")
    audit_entry_count = int_field(audit, "entry_count")
    audit_anchor_count = int_field(audit, "anchor_count")
    audit_generated_zig_bytes = int_field(audit, "generated_zig_bytes")
    negative_case_count = int_field(negative, "case_count")
    healthy = (
        candidate_present
        and upstream_present
        and node_present
        and audit_present
        and negative_present
        and candidate_count > 0
        and raw_word_count > 0
        and bool(upstream.get("ok"))
        and upstream_candidate_count > 0
        and upstream_raw_word_count > 0
        and bool(node.get("ok"))
        and node_probed_count > 0
        and node_decode_successes == node_probed_count
        and bool(audit.get("ok"))
        and bool(audit.get("generated_table_matches_source"))
        and audit_entry_count > 0
        and audit_anchor_count > 0
        and audit_generated_zig_bytes > 0
        and bool(negative.get("ok"))
        and negative_case_count > 0
        and negative_matched == negative_case_count
    )
    return {
        "present": candidate_present,
        "upstream_present": upstream_present,
        "node_present": node_present,
        "audit_present": audit_present,
        "negative_present": negative_present,
        "healthy": healthy,
        "candidate_count": candidate_count,
        "raw_word_count": raw_word_count,
        "upstream_candidate_count": upstream_candidate_count,
        "upstream_raw_word_count": upstream_raw_word_count,
        "node_probed_count": node_probed_count,
        "node_decode_successes": node_decode_successes,
        "node_size_winner_count": int_field(node, "size_winner_count"),
        "audit_entry_count": audit_entry_count,
        "audit_anchor_count": audit_anchor_count,
        "audit_generated_zig_bytes": audit_generated_zig_bytes,
        "negative_case_count": negative_case_count,
        "negative_matched": negative_matched,
    }


def png_scratch_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.png_scratch_report":
            continue
        cases = data.get("cases")
        cases = cases if isinstance(cases, list) else []
        def int_case(row: dict, field: str) -> int:
            value = row.get(field)
            return value if isinstance(value, int) and not isinstance(value, bool) else 0
        case_count = int(data.get("case_count") or 0)
        adam7_cases = sum(1 for row in cases if isinstance(row, dict) and row.get("interlace") == "adam7")
        stored_achieved = sum(1 for row in cases if isinstance(row, dict) and row.get("stored_streaming_status") == "achieved")
        fixed_achieved = sum(1 for row in cases if isinstance(row, dict) and row.get("fixed_dynamic_streaming_status") == "achieved")
        total_zlib_scratch = sum(int_case(row, "zlib_scratch_bytes") for row in cases if isinstance(row, dict))
        total_streaming_savings = sum(int_case(row, "streaming_scratch_savings_bytes") for row in cases if isinstance(row, dict))
        max_working_scratch = max((int_case(row, "working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        max_streaming_working_scratch = max((int_case(row, "streaming_working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        max_fixed_dynamic_streaming_working_scratch = max((int_case(row, "fixed_dynamic_streaming_working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        min_streaming_ratio = min((int_case(row, "streaming_scratch_ratio_x10000") for row in cases if isinstance(row, dict)), default=0)
        healthy = (
            case_count > 0
            and adam7_cases > 0
            and stored_achieved == case_count
            and fixed_achieved == case_count
            and total_streaming_savings == total_zlib_scratch
            and max_working_scratch > max_streaming_working_scratch
            and max_fixed_dynamic_streaming_working_scratch >= 32768
        )
        return {
            "present": True,
            "healthy": healthy,
            "case_count": case_count,
            "adam7_cases": adam7_cases,
            "stored_achieved": stored_achieved,
            "fixed_achieved": fixed_achieved,
            "total_zlib_scratch": total_zlib_scratch,
            "total_streaming_savings": total_streaming_savings,
            "max_working_scratch": max_working_scratch,
            "max_streaming_working_scratch": max_streaming_working_scratch,
            "max_fixed_dynamic_streaming_working_scratch": max_fixed_dynamic_streaming_working_scratch,
            "min_streaming_ratio": min_streaming_ratio,
        }
    return {
        "present": False,
        "healthy": False,
        "case_count": 0,
        "adam7_cases": 0,
        "stored_achieved": 0,
        "fixed_achieved": 0,
        "total_zlib_scratch": 0,
        "total_streaming_savings": 0,
        "max_working_scratch": 0,
        "max_streaming_working_scratch": 0,
        "max_fixed_dynamic_streaming_working_scratch": 0,
        "min_streaming_ratio": 0,
    }


def zlib_relaxed_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.zlib_relaxed_report":
            continue
        def int_field(field: str) -> int:
            value = data.get(field)
            return value if isinstance(value, int) and not isinstance(value, bool) else 0
        zlib_total = int_field("strict_rejections") + int_field("relaxed_successes") + int_field("dictionary_successes") + int_field("zlib_concatenated_successes") + int_field("zlib_decoder_successes") + int_field("limited_rejections")
        gzip_total = int_field("gzip_strict_rejections") + int_field("gzip_relaxed_successes") + int_field("gzip_concatenated_successes") + int_field("gzip_decoder_successes") + int_field("gzip_limited_rejections")
        healthy = (
            int_field("strict_rejections") >= 2
            and int_field("relaxed_successes") >= 5
            and int_field("dictionary_successes") >= 2
            and int_field("zlib_concatenated_successes") >= 3
            and int_field("zlib_decoder_successes") >= 8
            and int_field("limited_rejections") >= 1
            and int_field("gzip_strict_rejections") >= 3
            and int_field("gzip_relaxed_successes") >= 9
            and int_field("gzip_concatenated_successes") >= 4
            and int_field("gzip_decoder_successes") >= 4
            and int_field("gzip_limited_rejections") >= 1
        )
        return {
            "present": True,
            "healthy": healthy,
            "strict_rejections": int_field("strict_rejections"),
            "relaxed_successes": int_field("relaxed_successes"),
            "dictionary_successes": int_field("dictionary_successes"),
            "zlib_concatenated_successes": int_field("zlib_concatenated_successes"),
            "zlib_decoder_successes": int_field("zlib_decoder_successes"),
            "limited_rejections": int_field("limited_rejections"),
            "gzip_strict_rejections": int_field("gzip_strict_rejections"),
            "gzip_relaxed_successes": int_field("gzip_relaxed_successes"),
            "gzip_concatenated_successes": int_field("gzip_concatenated_successes"),
            "gzip_decoder_successes": int_field("gzip_decoder_successes"),
            "gzip_limited_rejections": int_field("gzip_limited_rejections"),
            "zlib_total": zlib_total,
            "gzip_total": gzip_total,
        }
    return {
        "present": False,
        "healthy": False,
        "strict_rejections": 0,
        "relaxed_successes": 0,
        "dictionary_successes": 0,
        "zlib_concatenated_successes": 0,
        "zlib_decoder_successes": 0,
        "limited_rejections": 0,
        "gzip_strict_rejections": 0,
        "gzip_relaxed_successes": 0,
        "gzip_concatenated_successes": 0,
        "gzip_decoder_successes": 0,
        "gzip_limited_rejections": 0,
        "zlib_total": 0,
        "gzip_total": 0,
    }


def zstd_compare_health(artifacts: list[Path]) -> dict:
    compare = None
    standard = None
    sweep = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.zstd_compare_gate":
            if artifact.name == "vort-zstd-compare-gate.json":
                compare = data
            elif artifact.name == "vort-zstd-compare-standard-gate.json":
                standard = data
        elif data.get("schema") == "vort.zstd_compare_block_sweep_gate" and artifact.name == "vort-zstd-compare-block-sweep-gate.json":
            sweep = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def float_field(data: dict | None, field: str) -> float:
        if not isinstance(data, dict):
            return 0.0
        value = data.get(field)
        return float(value) if isinstance(value, (int, float)) and not isinstance(value, bool) else 0.0

    compare_present = isinstance(compare, dict)
    standard_present = isinstance(standard, dict)
    sweep_present = isinstance(sweep, dict)
    healthy = (
        compare_present
        and standard_present
        and sweep_present
        and bool(compare.get("ok"))
        and bool(standard.get("ok"))
        and bool(sweep.get("ok"))
        and int_field(compare, "data_rows") > 0
        and int_field(standard, "data_rows") > 0
        and int_field(sweep, "data_rows") > 0
    )
    return {
        "present": compare_present,
        "standard_present": standard_present,
        "block_sweep_present": sweep_present,
        "healthy": healthy,
        "compare_rows": int_field(compare, "data_rows"),
        "standard_rows": int_field(standard, "data_rows"),
        "block_sweep_rows": int_field(sweep, "data_rows"),
        "native_ratio": float_field(compare, "total_native_ratio"),
        "native_stream_ratio": float_field(compare, "total_native_stream_ratio"),
        "standard_native_ratio": float_field(standard, "total_native_ratio"),
        "standard_native_stream_ratio": float_field(standard, "total_native_stream_ratio"),
        "decode_vs_zstd": float_field(compare, "total_vort_decode_vs_zstd"),
        "standard_decode_vs_zstd": float_field(standard, "total_vort_decode_vs_zstd"),
        "best_block_len": int_field(sweep, "best_block_len"),
        "best_range_decode_mib_s": float_field(sweep, "best_range_decode_mib_s"),
        "best_range_decode_full_input_mib_s": float_field(sweep, "best_range_decode_full_input_mib_s"),
    }


def native_allocation_health(artifacts: list[Path]) -> dict:
    report = None
    smoke = None
    negative = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.native_allocation_report":
            report = data
        elif schema == "vort.native_allocation_smoke":
            smoke = data
        elif schema == "vort.native_allocation_negative_smoke":
            negative = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    cases = smoke.get("cases") if isinstance(smoke, dict) else []
    cases = cases if isinstance(cases, list) else []
    budget_cases = smoke.get("budget_cases") if isinstance(smoke, dict) else []
    budget_cases = budget_cases if isinstance(budget_cases, list) else []
    negative_cases = negative.get("cases") if isinstance(negative, dict) else []
    negative_cases = negative_cases if isinstance(negative_cases, list) else []
    zero_matched = sum(1 for row in cases if isinstance(row, dict) and row.get("matched") is True)
    budget_matched = sum(1 for row in budget_cases if isinstance(row, dict) and row.get("matched") is True)
    negative_matched = sum(1 for row in negative_cases if isinstance(row, dict) and row.get("matched") is True)
    report_present = isinstance(report, dict)
    smoke_present = isinstance(smoke, dict)
    negative_present = isinstance(negative, dict)
    required_zero_cases = int_field(smoke, "required_zero_allocation_cases")
    required_budget_cases = int_field(smoke, "required_budget_cases")
    negative_case_count = int_field(negative, "case_count")
    healthy = (
        report_present
        and smoke_present
        and negative_present
        and bool(smoke.get("ok"))
        and bool(negative.get("ok"))
        and int_field(report, "case_count") > 0
        and required_zero_cases > 0
        and zero_matched == required_zero_cases
        and required_budget_cases > 0
        and budget_matched == required_budget_cases
        and negative_case_count > 0
        and negative_matched == negative_case_count
    )
    return {
        "present": report_present,
        "smoke_present": smoke_present,
        "negative_present": negative_present,
        "healthy": healthy,
        "report_case_count": int_field(report, "case_count"),
        "required_zero_allocation_cases": required_zero_cases,
        "zero_allocation_matched": zero_matched,
        "required_budget_cases": required_budget_cases,
        "budget_matched": budget_matched,
        "negative_case_count": negative_case_count,
        "negative_matched": negative_matched,
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
    def int_field(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

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
        probe_details = [
            {
                "label": str(probe.get("label") or ""),
                "ok": probe.get("ok") is True,
                "cases": int_field(probe, "cases"),
                "returncode": int_field(probe, "returncode"),
                "timed_out": probe.get("timed_out") is True,
            }
            for probe in probes
            if isinstance(probe, dict)
        ]
        capabilities = data.get("capabilities")
        if not isinstance(capabilities, list):
            capabilities = []
        ok_capabilities = sum(1 for row in capabilities if isinstance(row, dict) and row.get("ok") is True)
        capability_cases = {
            str(row.get("capability")): int(row.get("cases") or 0)
            for row in capabilities
            if isinstance(row, dict)
        }
        capability_details = [
            {
                "capability": str(row.get("capability") or ""),
                "present": row.get("present") is True,
                "ok": row.get("ok") is True,
                "ok_probe_count": int_field(row, "ok_probe_count"),
                "probe_count": int_field(row, "probe_count"),
                "cases": int_field(row, "cases"),
            }
            for row in capabilities
            if isinstance(row, dict)
        ]
        coverage = data.get("coverage")
        if not isinstance(coverage, list):
            coverage = []
        coverage_details = [
            {
                "codec": str(row.get("codec") or ""),
                "surface": str(row.get("surface") or ""),
                "present": row.get("present") is True,
                "ok": row.get("ok") is True,
                "ok_probe_count": int_field(row, "ok_probe_count"),
                "probe_count": int_field(row, "probe_count"),
                "cases": int_field(row, "cases"),
            }
            for row in coverage
            if isinstance(row, dict)
        ]
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
            "coverage_details": coverage_details,
            "capability_details": capability_details,
            "probe_details": probe_details,
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
        "coverage_details": [],
        "capability_details": [],
        "probe_details": [],
    }


def native_stream_summary_health(artifacts: list[Path], schema: str, *, require_block_checksum: bool = False) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != schema:
            continue
        frame_count = int(data.get("frame_count") or 0)
        skippable_frame_count = int(data.get("skippable_frame_count") or 0)
        checksum_frame_count = int(data.get("checksum_frame_count") or 0)
        block_checksum_frame_count = int(data.get("block_checksum_frame_count") or 0)
        dictionary_id_frame_count = int(data.get("dictionary_id_frame_count") or 0)
        content_size_frame_count = int(data.get("content_size_frame_count") or 0)
        declared_content_bytes = int(data.get("declared_content_bytes") or 0)
        block_count = int(data.get("block_count") or 0)
        raw_block_count = int(data.get("raw_block_count") or 0)
        rle_block_count = int(data.get("rle_block_count") or 0)
        compressed_block_count = int(data.get("compressed_block_count") or 0)
        compressed_bytes = int(data.get("compressed_bytes") or 0)
        payload_bytes = int(data.get("payload_bytes") or 0)
        skippable_payload_bytes = int(data.get("skippable_payload_bytes") or 0)
        # Dashboard summaries intentionally require retained fixtures to cover
        # ordinary data frames plus optional frame-level metadata. LZ4 opts into
        # block-checksum coverage because that flag has no Zstd analogue.
        healthy = (
            frame_count >= 2
            and skippable_frame_count >= 1
            and checksum_frame_count >= 1
            and (not require_block_checksum or block_checksum_frame_count >= 1)
            and dictionary_id_frame_count >= 1
            and content_size_frame_count >= 1
            and declared_content_bytes > 0
            and block_count >= 2
            and raw_block_count >= 1
            and compressed_bytes > 0
            and payload_bytes > 0
            and skippable_payload_bytes > 0
        )
        return {
            "present": True,
            "healthy": healthy,
            "frame_count": frame_count,
            "skippable_frame_count": skippable_frame_count,
            "checksum_frame_count": checksum_frame_count,
            "block_checksum_frame_count": block_checksum_frame_count,
            "dictionary_id_frame_count": dictionary_id_frame_count,
            "content_size_frame_count": content_size_frame_count,
            "declared_content_bytes": declared_content_bytes,
            "block_count": block_count,
            "raw_block_count": raw_block_count,
            "rle_block_count": rle_block_count,
            "compressed_block_count": compressed_block_count,
            "compressed_bytes": compressed_bytes,
            "payload_bytes": payload_bytes,
            "skippable_payload_bytes": skippable_payload_bytes,
        }
    return {
        "present": False,
        "healthy": False,
        "frame_count": 0,
        "skippable_frame_count": 0,
        "checksum_frame_count": 0,
        "block_checksum_frame_count": 0,
        "dictionary_id_frame_count": 0,
        "content_size_frame_count": 0,
        "declared_content_bytes": 0,
        "block_count": 0,
        "raw_block_count": 0,
        "rle_block_count": 0,
        "compressed_block_count": 0,
        "compressed_bytes": 0,
        "payload_bytes": 0,
        "skippable_payload_bytes": 0,
    }


def zstd_native_summary_health(artifacts: list[Path]) -> dict:
    return native_stream_summary_health(artifacts, "vort.zstd_native_stream_summary")


def lz4_native_summary_health(artifacts: list[Path]) -> dict:
    return native_stream_summary_health(artifacts, "vort.lz4_native_stream_summary", require_block_checksum=True)



def native_summary_error_dashboard_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_summary_error_dashboard":
            continue
        case_count = int(data.get("case_count") or 0)
        lz4_case_count = int(data.get("lz4_case_count") or 0)
        zstd_case_count = int(data.get("zstd_case_count") or 0)
        error_counts = data.get("error_counts") if isinstance(data.get("error_counts"), dict) else {}
        phase_counts = data.get("phase_counts") if isinstance(data.get("phase_counts"), dict) else {}
        checksum_mismatch_count = int(error_counts.get("ChecksumMismatch") or 0)
        corrupt_frame_count = int(error_counts.get("CorruptFrame") or 0)
        truncated_frame_count = int(error_counts.get("TruncatedFrame") or 0)
        magic_phase_count = int(phase_counts.get("magic") or 0)
        skippable_payload_phase_count = int(phase_counts.get("skippable_payload") or 0)
        frame_body_phase_count = int(phase_counts.get("frame_body") or 0)
        frame_checksum_phase_count = int(phase_counts.get("frame_checksum") or 0)
        frame_phase_count = int(phase_counts.get("frame") or 0)
        lz4_error_counts = data.get("lz4_error_counts") if isinstance(data.get("lz4_error_counts"), dict) else {}
        zstd_error_counts = data.get("zstd_error_counts") if isinstance(data.get("zstd_error_counts"), dict) else {}
        lz4_phase_counts = data.get("lz4_phase_counts") if isinstance(data.get("lz4_phase_counts"), dict) else {}
        zstd_phase_counts = data.get("zstd_phase_counts") if isinstance(data.get("zstd_phase_counts"), dict) else {}
        offset_min = int(data.get("offset_min") or 0)
        offset_max = int(data.get("offset_max") or 0)
        lz4_offset_min = int(data.get("lz4_offset_min") or 0)
        lz4_offset_max = int(data.get("lz4_offset_max") or 0)
        zstd_offset_min = int(data.get("zstd_offset_min") or 0)
        zstd_offset_max = int(data.get("zstd_offset_max") or 0)
        phase_offset_ranges = data.get("phase_offset_ranges") if isinstance(data.get("phase_offset_ranges"), dict) else {}
        required_codec_phases = data.get("required_codec_phases") if isinstance(data.get("required_codec_phases"), dict) else {}
        lz4_required_phases = required_codec_phases.get("lz4") if isinstance(required_codec_phases.get("lz4"), list) else []
        zstd_required_phases = required_codec_phases.get("zstd") if isinstance(required_codec_phases.get("zstd"), list) else []
        lz4_missing_phases = sorted(str(phase) for phase in lz4_required_phases if int(lz4_phase_counts.get(str(phase)) or 0) == 0)
        zstd_missing_phases = sorted(str(phase) for phase in zstd_required_phases if int(zstd_phase_counts.get(str(phase)) or 0) == 0)
        return {
            "present": True,
            "healthy": data.get("ok") is True
            and case_count >= 14
            and lz4_case_count >= 7
            and zstd_case_count >= 7
            and checksum_mismatch_count >= 1
            and corrupt_frame_count >= 4
            and truncated_frame_count >= 8
            and magic_phase_count >= 2
            and skippable_payload_phase_count >= 2
            and frame_body_phase_count >= 2
            and frame_checksum_phase_count >= 2
            and frame_phase_count >= 2
            and len(lz4_missing_phases) == 0
            and len(zstd_missing_phases) == 0,
            "case_count": case_count,
            "lz4_case_count": lz4_case_count,
            "zstd_case_count": zstd_case_count,
            "checksum_mismatch_count": checksum_mismatch_count,
            "corrupt_frame_count": corrupt_frame_count,
            "truncated_frame_count": truncated_frame_count,
            "magic_phase_count": magic_phase_count,
            "skippable_payload_phase_count": skippable_payload_phase_count,
            "frame_body_phase_count": frame_body_phase_count,
            "frame_checksum_phase_count": frame_checksum_phase_count,
            "frame_phase_count": frame_phase_count,
            "error_counts": error_counts,
            "phase_counts": phase_counts,
            "lz4_error_counts": lz4_error_counts,
            "zstd_error_counts": zstd_error_counts,
            "lz4_phase_counts": lz4_phase_counts,
            "zstd_phase_counts": zstd_phase_counts,
            "offset_min": offset_min,
            "offset_max": offset_max,
            "lz4_offset_min": lz4_offset_min,
            "lz4_offset_max": lz4_offset_max,
            "zstd_offset_min": zstd_offset_min,
            "zstd_offset_max": zstd_offset_max,
            "phase_offset_ranges": phase_offset_ranges,
            "required_codec_phases": required_codec_phases,
            "lz4_missing_phases": lz4_missing_phases,
            "zstd_missing_phases": zstd_missing_phases,
        }
    return {
        "present": False,
        "healthy": False,
        "case_count": 0,
        "lz4_case_count": 0,
        "zstd_case_count": 0,
        "checksum_mismatch_count": 0,
        "corrupt_frame_count": 0,
        "truncated_frame_count": 0,
        "magic_phase_count": 0,
        "skippable_payload_phase_count": 0,
        "frame_body_phase_count": 0,
        "frame_checksum_phase_count": 0,
        "frame_phase_count": 0,
        "error_counts": {},
        "phase_counts": {},
        "lz4_error_counts": {},
        "zstd_error_counts": {},
        "lz4_phase_counts": {},
        "zstd_phase_counts": {},
        "offset_min": 0,
        "offset_max": 0,
        "lz4_offset_min": 0,
        "lz4_offset_max": 0,
        "zstd_offset_min": 0,
        "zstd_offset_max": 0,
        "phase_offset_ranges": {},
        "required_codec_phases": {},
        "lz4_missing_phases": [],
        "zstd_missing_phases": [],
    }


def native_summary_error_negative_health(artifacts: list[Path]) -> dict:
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_summary_error_negative_smoke":
            continue
        case_count = int(data.get("case_count") or 0)
        return {
            "present": True,
            "healthy": data.get("ok") is True and case_count >= 3,
            "case_count": case_count,
        }
    return {"present": False, "healthy": False, "case_count": 0}

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


def dashboard_configuration_health(artifacts: list[Path]) -> dict:
    """Summarize meta-dashboard smoke artifacts.

    These artifacts validate the dashboard's own configuration surfaces rather
    than compression behavior. Keeping them together gives reviewers one place
    to check that config indexing, required producer metadata, and negative
    guardrails are all still being retained by the validation run.
    """
    config_smoke = None
    config_negative = None
    category_negative = None
    producers_required = None
    producers_negative = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.dashboard_config_index_smoke" and artifact.name == "vort-dashboard-config-index-smoke.json":
            config_smoke = data
        elif schema == "vort.dashboard_config_index_negative_smoke" and artifact.name == "vort-dashboard-config-index-negative-smoke.json":
            config_negative = data
        elif schema == "vort.dashboard_category_negative_smoke" and artifact.name == "vort-dashboard-category-negative-smoke.json":
            category_negative = data
        elif schema == "vort.dashboard_producers_required_smoke" and artifact.name == "vort-dashboard-producers-required-smoke.json":
            producers_required = data
        elif schema == "vort.dashboard_producers_negative_smoke" and artifact.name == "vort-dashboard-producers-negative-smoke.json":
            producers_negative = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def matched_items(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        items = data.get(field)
        if not isinstance(items, list):
            return 0
        return sum(1 for item in items if isinstance(item, dict) and item.get("matched") is True)

    config_count = int_field(config_smoke, "config_count")
    config_matched = matched_items(config_smoke, "configs")
    config_negative_count = int_field(config_negative, "case_count")
    config_negative_matched = matched_items(config_negative, "cases")
    category_negative_count = int_field(category_negative, "case_count")
    category_negative_matched = matched_items(category_negative, "cases")
    producers_required_count = int_field(producers_required, "artifact_count")
    producers_required_matched = matched_items(producers_required, "cases")
    producers_required_smoke_gate_count = int_field(producers_required, "required_smoke_gate_count")
    producers_negative_count = int_field(producers_negative, "case_count")
    producers_negative_matched = matched_items(producers_negative, "cases")
    healthy = (
        isinstance(config_smoke, dict)
        and bool(config_smoke.get("ok"))
        and config_count > 0
        and config_matched == config_count
        and isinstance(config_negative, dict)
        and bool(config_negative.get("ok"))
        and config_negative_count > 0
        and config_negative_matched == config_negative_count
        and isinstance(category_negative, dict)
        and bool(category_negative.get("ok"))
        and category_negative_count > 0
        and category_negative_matched == category_negative_count
        and isinstance(producers_required, dict)
        and bool(producers_required.get("ok"))
        and producers_required_count > 0
        and producers_required_matched == producers_required_count
        and producers_required_smoke_gate_count > 0
        and isinstance(producers_negative, dict)
        and bool(producers_negative.get("ok"))
        and producers_negative_count > 0
        and producers_negative_matched == producers_negative_count
    )
    return {
        "config_index_present": isinstance(config_smoke, dict),
        "config_index_ok": bool(config_smoke.get("ok")) if isinstance(config_smoke, dict) else False,
        "config_index_config_count": config_count,
        "config_index_matched": config_matched,
        "config_index_unmatched": config_count - config_matched,
        "config_index_negative_present": isinstance(config_negative, dict),
        "config_index_negative_ok": bool(config_negative.get("ok")) if isinstance(config_negative, dict) else False,
        "config_index_negative_case_count": config_negative_count,
        "config_index_negative_matched": config_negative_matched,
        "config_index_negative_unmatched": config_negative_count - config_negative_matched,
        "category_negative_present": isinstance(category_negative, dict),
        "category_negative_ok": bool(category_negative.get("ok")) if isinstance(category_negative, dict) else False,
        "category_negative_case_count": category_negative_count,
        "category_negative_matched": category_negative_matched,
        "category_negative_unmatched": category_negative_count - category_negative_matched,
        "producers_required_present": isinstance(producers_required, dict),
        "producers_required_ok": bool(producers_required.get("ok")) if isinstance(producers_required, dict) else False,
        "producers_required_artifact_count": producers_required_count,
        "producers_required_matched": producers_required_matched,
        "producers_required_unmatched": producers_required_count - producers_required_matched,
        "producers_required_smoke_gate_count": producers_required_smoke_gate_count,
        "producers_negative_present": isinstance(producers_negative, dict),
        "producers_negative_ok": bool(producers_negative.get("ok")) if isinstance(producers_negative, dict) else False,
        "producers_negative_case_count": producers_negative_count,
        "producers_negative_matched": producers_negative_matched,
        "producers_negative_unmatched": producers_negative_count - producers_negative_matched,
        "healthy": healthy,
    }


def validation_json_health(artifacts: list[Path]) -> dict:
    smoke = None
    docs_negative = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.validation_json_smoke" and artifact.name == "vort-validation-json-smoke.json":
            smoke = data
        elif data.get("schema") == "vort.validation_json_docs_negative_smoke" and artifact.name == "vort-validation-json-docs-negative-smoke.json":
            docs_negative = data

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    checked_schemas = smoke.get("checked_schemas") if isinstance(smoke, dict) else []
    checked_schema_count = len(checked_schemas) if isinstance(checked_schemas, list) else 0
    docs_case_count = int_field(docs_negative, "case_count")
    docs_cases = docs_negative.get("cases") if isinstance(docs_negative, dict) else []
    docs_matched = sum(1 for item in docs_cases if isinstance(item, dict) and item.get("matched") is True) if isinstance(docs_cases, list) else 0
    healthy = (
        isinstance(smoke, dict)
        and bool(smoke.get("ok"))
        and checked_schema_count > 0
        and bool(smoke.get("cli_success_ok"))
        and int_field(smoke, "report_rows") > 0
        and int_field(smoke, "corrupt_rows") > 0
        and isinstance(docs_negative, dict)
        and bool(docs_negative.get("ok"))
        and docs_case_count > 0
        and docs_matched == docs_case_count
    )
    return {
        "present": isinstance(smoke, dict),
        "ok": bool(smoke.get("ok")) if isinstance(smoke, dict) else False,
        "checked_schema_count": checked_schema_count,
        "cli_success_ok": bool(smoke.get("cli_success_ok")) if isinstance(smoke, dict) else False,
        "cli_failure_ok": bool(smoke.get("cli_failure_ok")) if isinstance(smoke, dict) else False,
        "cli_failure_hint": str(smoke.get("cli_failure_hint") or "") if isinstance(smoke, dict) else "",
        "report_rows": int_field(smoke, "report_rows"),
        "corrupt_rows": int_field(smoke, "corrupt_rows"),
        "docs_negative_present": isinstance(docs_negative, dict),
        "docs_negative_ok": bool(docs_negative.get("ok")) if isinstance(docs_negative, dict) else False,
        "docs_negative_case_count": docs_case_count,
        "docs_negative_matched": docs_matched,
        "docs_negative_unmatched": docs_case_count - docs_matched,
        "healthy": healthy,
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
    dashboard_configuration = dashboard_configuration_health(artifacts)
    validation_json = validation_json_health(artifacts)
    sidecar_corrupt_health_summary = sidecar_corrupt_health(artifacts)
    huffman_health = huffman_length_health(artifacts)
    fuzz_health = fuzz_corpus_health(artifacts)
    decode_stage_health_summary = decode_stage_health(artifacts)
    native_fuzz = native_fuzz_corpus_health(artifacts)
    br_static_dictionary = br_static_dictionary_health(artifacts)
    png_scratch = png_scratch_health(artifacts)
    zlib_relaxed = zlib_relaxed_health(artifacts)
    zstd_compare = zstd_compare_health(artifacts)
    native_allocation = native_allocation_health(artifacts)
    python_zlib_health = python_zlib_diff_health(artifacts)
    native_codec_health = native_codec_probes_health(artifacts)
    native_summary_error_health = native_summary_error_dashboard_health(artifacts)
    native_summary_error_negative = native_summary_error_negative_health(artifacts)
    lz4_native_summary = lz4_native_summary_health(artifacts)
    zstd_native_summary = zstd_native_summary_health(artifacts)
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
    dashboard_configuration_healthy = dashboard_configuration["healthy"]
    validation_json_healthy = validation_json["healthy"]
    sidecar_corrupt_healthy = sidecar_corrupt_health_summary["healthy"]
    huffman_healthy = huffman_health["healthy"]
    fuzz_healthy = fuzz_health["healthy"]
    decode_stage_healthy = decode_stage_health_summary["healthy"]
    python_zlib_healthy = python_zlib_health["healthy"]
    native_summary_error_healthy = native_summary_error_health["healthy"]
    native_summary_error_negative_healthy = native_summary_error_negative["healthy"]
    lz4_native_summary_healthy = lz4_native_summary["healthy"]
    zstd_native_summary_healthy = zstd_native_summary["healthy"]
    native_tier_discovery_healthy = native_tier_discovery_health["healthy"]
    validation_healthy = (
        producer_healthy
        and smoke_gate_healthy
        and header_healthy
        and strict_healthy
        and dashboard_configuration_healthy
        and validation_json_healthy
        and sidecar_corrupt_healthy
        and huffman_healthy
        and fuzz_healthy
        and decode_stage_healthy
        and python_zlib_healthy
        and native_codec_health["healthy"]
        and zstd_compare["healthy"]
        and br_static_dictionary["healthy"]
        and native_summary_error_healthy
        and native_summary_error_negative_healthy
        and lz4_native_summary_healthy
        and zstd_native_summary_healthy
        and native_tier_discovery_healthy
    )
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
    dashboard_configuration_present = (
        dashboard_configuration["config_index_present"]
        and dashboard_configuration["config_index_negative_present"]
        and dashboard_configuration["category_negative_present"]
        and dashboard_configuration["producers_required_present"]
        and dashboard_configuration["producers_negative_present"]
    )
    if not dashboard_configuration_present:
        validation_unhealthy_reasons.append("missing_dashboard_configuration_artifact")
    elif not dashboard_configuration_healthy:
        validation_unhealthy_reasons.append("dashboard_configuration_failed")
    if not validation_json["present"]:
        validation_unhealthy_reasons.append("missing_validation_json_smoke_artifact")
    elif not (
        validation_json["ok"]
        and validation_json["cli_success_ok"]
        and validation_json["checked_schema_count"] > 0
        and validation_json["report_rows"] > 0
        and validation_json["corrupt_rows"] > 0
    ):
        validation_unhealthy_reasons.append("validation_json_failed")
    if not validation_json["docs_negative_present"]:
        validation_unhealthy_reasons.append("missing_validation_json_docs_negative_artifact")
    elif not (
        validation_json["docs_negative_ok"]
        and validation_json["docs_negative_case_count"] > 0
        and validation_json["docs_negative_matched"] == validation_json["docs_negative_case_count"]
    ):
        validation_unhealthy_reasons.append("validation_json_docs_negative_failed")
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
    if not native_codec_health["present"]:
        validation_unhealthy_reasons.append("missing_native_codec_probes_artifact")
    elif not native_codec_health["healthy"]:
        validation_unhealthy_reasons.append("native_codec_probes_failed")
    if not (zstd_compare["present"] and zstd_compare["standard_present"] and zstd_compare["block_sweep_present"]):
        validation_unhealthy_reasons.append("missing_zstd_compare_artifact")
    elif not zstd_compare["healthy"]:
        validation_unhealthy_reasons.append("zstd_compare_failed")
    br_static_dictionary_present = (
        br_static_dictionary["present"]
        and br_static_dictionary["upstream_present"]
        and br_static_dictionary["node_present"]
        and br_static_dictionary["audit_present"]
        and br_static_dictionary["negative_present"]
    )
    if not br_static_dictionary_present:
        validation_unhealthy_reasons.append("missing_br_static_dictionary_artifact")
    elif not br_static_dictionary["healthy"]:
        validation_unhealthy_reasons.append("br_static_dictionary_failed")
    if not native_summary_error_health["present"]:
        validation_unhealthy_reasons.append("missing_native_summary_error_dashboard_artifact")
    elif not native_summary_error_healthy:
        validation_unhealthy_reasons.append("native_summary_error_dashboard_undercovered")
    if not native_summary_error_negative["present"]:
        validation_unhealthy_reasons.append("missing_native_summary_error_negative_artifact")
    elif not native_summary_error_negative_healthy:
        validation_unhealthy_reasons.append("native_summary_error_negative_failed")
    if not lz4_native_summary["present"]:
        validation_unhealthy_reasons.append("missing_lz4_native_summary_artifact")
    elif not lz4_native_summary_healthy:
        validation_unhealthy_reasons.append("lz4_native_summary_undercovered")
    if not zstd_native_summary["present"]:
        validation_unhealthy_reasons.append("missing_zstd_native_summary_artifact")
    elif not zstd_native_summary_healthy:
        validation_unhealthy_reasons.append("zstd_native_summary_undercovered")
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
        f"- native summary errors: cases total/lz4/zstd/checksum/corrupt/truncated/magic/skippable/body/checksum-phase/frame {native_summary_error_health['case_count']}/{native_summary_error_health['lz4_case_count']}/{native_summary_error_health['zstd_case_count']}/{native_summary_error_health['checksum_mismatch_count']}/{native_summary_error_health['corrupt_frame_count']}/{native_summary_error_health['truncated_frame_count']}/{native_summary_error_health['magic_phase_count']}/{native_summary_error_health['skippable_payload_phase_count']}/{native_summary_error_health['frame_body_phase_count']}/{native_summary_error_health['frame_checksum_phase_count']}/{native_summary_error_health['frame_phase_count']}, healthy `{native_summary_error_healthy}`",
        f"- native summary error negative smoke: cases {native_summary_error_negative['case_count']}, healthy `{native_summary_error_negative_healthy}`",
        f"- lz4 native summary: frames/skippable/checksum/block-checksum/dictionary/content-size/blocks raw/compressed {lz4_native_summary['frame_count']}/{lz4_native_summary['skippable_frame_count']}/{lz4_native_summary['checksum_frame_count']}/{lz4_native_summary['block_checksum_frame_count']}/{lz4_native_summary['dictionary_id_frame_count']}/{lz4_native_summary['content_size_frame_count']}/{lz4_native_summary['block_count']} {lz4_native_summary['raw_block_count']}/{lz4_native_summary['compressed_block_count']}, declared/payload/skippable bytes {lz4_native_summary['declared_content_bytes']}/{lz4_native_summary['payload_bytes']}/{lz4_native_summary['skippable_payload_bytes']}, healthy `{lz4_native_summary_healthy}`",
        f"- zstd native summary: frames/skippable/checksum/dictionary/content-size/blocks raw/rle/compressed {zstd_native_summary['frame_count']}/{zstd_native_summary['skippable_frame_count']}/{zstd_native_summary['checksum_frame_count']}/{zstd_native_summary['dictionary_id_frame_count']}/{zstd_native_summary['content_size_frame_count']}/{zstd_native_summary['block_count']} {zstd_native_summary['raw_block_count']}/{zstd_native_summary['rle_block_count']}/{zstd_native_summary['compressed_block_count']}, declared/payload/skippable bytes {zstd_native_summary['declared_content_bytes']}/{zstd_native_summary['payload_bytes']}/{zstd_native_summary['skippable_payload_bytes']}, healthy `{zstd_native_summary_healthy}`",
        f"- native tier range bench: {native_tier_health['ok_count']}/{native_tier_health['summary_count']} summaries ok across {native_tier_health['rows']} rows ({native_tier_health['enforced_count']} throughput-enforced), sources built-in/project/standard/custom/legacy {native_tier_health['built_in_summary_count']}/{native_tier_health['project_files_summary_count']}/{native_tier_health['standard_corpus_summary_count']}/{native_tier_health['custom_summary_count']}/{native_tier_health['legacy_summary_count']} missing {','.join(native_tier_health['missing_sources']) or 'none'}, min range MiB/s seek_fast/balanced/ratio {native_tier_health['seek_fast_min_range_mib_s']:.2f}/{native_tier_health['balanced_min_range_mib_s']:.2f}/{native_tier_health['ratio_min_range_mib_s']:.2f}, healthy `{native_tier_health['healthy']}`",
        f"- native tier corpus discovery: source mode `{native_tier_discovery_health['source_mode']}`, sources {native_tier_discovery_health['source_count']}/{native_tier_discovery_health['candidate_count']}, selected cases {native_tier_discovery_health['selected_case_count']}, missing reason `{native_tier_discovery_health['missing_reason'] or 'none'}`, healthy `{native_tier_discovery_health['healthy']}`",
        "",
    ]
    category_rows = []
    for category in sorted(grouped):
        category_records = [record for record in records if record["category"] == category]
        category_rows.append(
            {
                "category": category,
                "artifacts": len(category_records),
                "json": sum(1 for record in category_records if record["format"] == "json"),
                "markdown": sum(1 for record in category_records if record["format"] == "md"),
                "csv": sum(1 for record in category_records if record["format"] == "csv"),
                "producer_steps": sum(1 for record in category_records if record["producer_step"]),
                "smoke_gates": sum(1 for record in category_records if record["smoke_gate"]),
            }
        )
    lines.extend(
        [
            "## Dashboard artifact inventory",
            "",
            "| category | artifacts | json | markdown | csv | producer steps | smoke gates |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for row in category_rows:
        lines.append(
            f"| `{row['category']}` | {row['artifacts']} | {row['json']} | {row['markdown']} | {row['csv']} | {row['producer_steps']} | {row['smoke_gates']} |"
        )
    lines.append("")
    validation_reason_status = "none" if not validation_unhealthy_reasons else ", ".join(f"`{reason}`" for reason in validation_unhealthy_reasons)
    lines.extend(
        [
            "## Validation unhealthy reasons",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| active reasons | {len(validation_unhealthy_reasons)} | {validation_reason_status} |",
            f"| aggregate health | {1 if validation_healthy else 0} | validation healthy `{validation_healthy}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Producer and smoke-gate coverage",
            "",
            "| category | covered | missing | detail |",
            "| --- | ---: | ---: | --- |",
            f"| producer steps | {producer_step_covered}/{len(records)} | {len(producer_step_missing)} | allowed missing {len(producer_step_allowed_missing)} |",
            f"| smoke gates | {smoke_gate_covered}/{len(records)} | {len(smoke_gate_missing)} | required missing {len(smoke_gate_required_missing)} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Dashboard strict mode coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| strict checks | {strict_health['check_count']} | expected failures/matched {strict_health['expected_failure_count']}/{strict_health['matched_count']} |",
            f"| modes | {strict_health['mode_count']} | expected/missing {strict_health['expected_mode_count']}/{strict_health['missing_mode_count']} |",
            f"| requirement deltas | {strict_health['missing_checks'] + strict_health['missing_expected_failures'] + strict_health['missing_matched']} | checks/expected/matched {strict_health['missing_checks']}/{strict_health['missing_expected_failures']}/{strict_health['missing_matched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Dashboard configuration coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| config index | {dashboard_configuration['config_index_config_count']} | matched {dashboard_configuration['config_index_matched']}, negative {dashboard_configuration['config_index_negative_matched']}/{dashboard_configuration['config_index_negative_case_count']} |",
            f"| category guardrails | {dashboard_configuration['category_negative_case_count']} | matched {dashboard_configuration['category_negative_matched']}, present `{dashboard_configuration['category_negative_present']}` |",
            f"| required producers | {dashboard_configuration['producers_required_artifact_count']} | matched {dashboard_configuration['producers_required_matched']}, required smoke gates {dashboard_configuration['producers_required_smoke_gate_count']} |",
            f"| producer guardrails | {dashboard_configuration['producers_negative_case_count']} | matched {dashboard_configuration['producers_negative_matched']}, healthy `{dashboard_configuration['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Validation JSON schema coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| checked schemas | {validation_json['checked_schema_count']} | smoke present `{validation_json['present']}`, ok `{validation_json['ok']}` |",
            f"| CLI validation | {1 if validation_json['cli_success_ok'] else 0} | failure-ok `{validation_json['cli_failure_ok']}`, hint `{validation_json['cli_failure_hint'] or 'none'}` |",
            f"| report rows | {validation_json['report_rows']} | corrupt rows {validation_json['corrupt_rows']} |",
            f"| docs negative cases | {validation_json['docs_negative_matched']}/{validation_json['docs_negative_case_count']} | present `{validation_json['docs_negative_present']}`, healthy `{validation_json['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Header inspect coverage",
            "",
            "| category | total | raw | zlib | gzip |",
            "| --- | ---: | ---: | ---: | ---: |",
            f"| positive cases | {header_health['case_count']} | {header_health['raw_cases']} | {header_health['zlib_cases']} | {header_health['gzip_cases']} |",
            f"| negative cases | {header_health['negative_cases']} | {header_health['raw_negative_cases']} | {header_health['zlib_negative_cases']} | {header_health['gzip_negative_cases']} |",
            "",
            "| workflow/feature | count | detail |",
            "| --- | ---: | --- |",
            f"| commands | {header_health['command_count']} | successes/failures {header_health['command_successes']}/{header_health['command_failures']} |",
            f"| workflows | {header_health['workflow_count']} | successes {header_health['workflow_successes']}, required/missing {header_health['required_workflow_count']}/{header_health['missing_workflow_count']} |",
            f"| dictionary cases | {header_health['dictionary_cases']} | optional/FHCRC {header_health['optional_header_cases']}/{header_health['fhcrc_cases']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native fuzz corpus coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| native cases | {native_fuzz['cases']} | accepted/rejected {native_fuzz['accepted']}/{native_fuzz['rejected']} |",
            f"| matched rows | {native_fuzz['matched_rows']} | unmatched {native_fuzz['unmatched_rows']} |",
            f"| exact error expectations | {native_fuzz['exact_error_expectations']} | mode/error rows {native_fuzz['mode_count_rows']}/{native_fuzz['error_count_rows']} |",
            f"| coverage requirements | {native_fuzz['coverage_mode_requirements'] + native_fuzz['coverage_error_requirements']} | modes/errors {native_fuzz['coverage_mode_requirements']}/{native_fuzz['coverage_error_requirements']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Static dictionary coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| candidates | {br_static_dictionary['candidate_count']} | raw words {br_static_dictionary['raw_word_count']} |",
            f"| upstream smoke | {br_static_dictionary['upstream_candidate_count']} | raw words {br_static_dictionary['upstream_raw_word_count']}, present `{br_static_dictionary['upstream_present']}` |",
            f"| node probe | {br_static_dictionary['node_decode_successes']}/{br_static_dictionary['node_probed_count']} | size winners {br_static_dictionary['node_size_winner_count']} |",
            f"| source audit | {br_static_dictionary['audit_entry_count']} | anchors {br_static_dictionary['audit_anchor_count']}, generated bytes {br_static_dictionary['audit_generated_zig_bytes']} |",
            f"| negative smoke | {br_static_dictionary['negative_matched']}/{br_static_dictionary['negative_case_count']} | healthy `{br_static_dictionary['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## PNG scratch coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| cases | {png_scratch['case_count']} | Adam7 {png_scratch['adam7_cases']}, healthy `{png_scratch['healthy']}` |",
            f"| streaming achieved | {png_scratch['stored_achieved']}/{png_scratch['case_count']} | fixed/dynamic {png_scratch['fixed_achieved']}/{png_scratch['case_count']} |",
            f"| zlib scratch savings | {png_scratch['total_streaming_savings']} | zlib scratch {png_scratch['total_zlib_scratch']} |",
            f"| max working scratch | {png_scratch['max_working_scratch']} | streaming/fixed-dynamic {png_scratch['max_streaming_working_scratch']}/{png_scratch['max_fixed_dynamic_streaming_working_scratch']} |",
            f"| min streaming ratio x10000 | {png_scratch['min_streaming_ratio']} | lower is better |",
            "",
        ]
    )
    lines.extend(
        [
            "## Zlib relaxed compatibility coverage",
            "",
            "| wrapper | strict rejections | relaxed successes | concatenated successes | decoder successes | limited rejections | extra |",
            "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
            f"| zlib | {zlib_relaxed['strict_rejections']} | {zlib_relaxed['relaxed_successes']} | {zlib_relaxed['zlib_concatenated_successes']} | {zlib_relaxed['zlib_decoder_successes']} | {zlib_relaxed['limited_rejections']} | dictionary {zlib_relaxed['dictionary_successes']} |",
            f"| gzip | {zlib_relaxed['gzip_strict_rejections']} | {zlib_relaxed['gzip_relaxed_successes']} | {zlib_relaxed['gzip_concatenated_successes']} | {zlib_relaxed['gzip_decoder_successes']} | {zlib_relaxed['gzip_limited_rejections']} | total {zlib_relaxed['gzip_total']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Zstd compare gate coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| compare rows | {zstd_compare['compare_rows']} | native/native-stream ratios {zstd_compare['native_ratio']:.3f}/{zstd_compare['native_stream_ratio']:.3f}, decode-vs-zstd {zstd_compare['decode_vs_zstd']:.3f} |",
            f"| standard rows | {zstd_compare['standard_rows']} | native/native-stream ratios {zstd_compare['standard_native_ratio']:.3f}/{zstd_compare['standard_native_stream_ratio']:.3f}, decode-vs-zstd {zstd_compare['standard_decode_vs_zstd']:.3f} |",
            f"| block sweep rows | {zstd_compare['block_sweep_rows']} | best block {zstd_compare['best_block_len']} bytes, range/full MiB/s {zstd_compare['best_range_decode_mib_s']:.2f}/{zstd_compare['best_range_decode_full_input_mib_s']:.2f} |",
            f"| gate health | {1 if zstd_compare['healthy'] else 0} | compare/standard/sweep present {zstd_compare['present']}/{zstd_compare['standard_present']}/{zstd_compare['block_sweep_present']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native allocation coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| report cases | {native_allocation['report_case_count']} | present `{native_allocation['present']}` |",
            f"| zero-allocation cases | {native_allocation['zero_allocation_matched']}/{native_allocation['required_zero_allocation_cases']} | smoke present `{native_allocation['smoke_present']}` |",
            f"| budget cases | {native_allocation['budget_matched']}/{native_allocation['required_budget_cases']} | healthy `{native_allocation['healthy']}` |",
            f"| negative smoke cases | {native_allocation['negative_matched']}/{native_allocation['negative_case_count']} | present `{native_allocation['negative_present']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Sidecar corrupt smoke coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| corrupt rows | {sidecar_corrupt_health_summary['rows']} | healthy `{sidecar_corrupt_healthy}` |",
            f"| metadata checks | {sidecar_corrupt_health_summary['metadata_ok_rows']} | failed {sidecar_corrupt_health_summary['metadata_failed_rows']} |",
            f"| full decode rejection | {sidecar_corrupt_health_summary['full_rejected_rows']} | not rejected {sidecar_corrupt_health_summary['full_not_rejected_rows']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Huffman length oracle coverage",
            "",
            "| implementation | optimal rows | non-optimal rows | worst gap bits |",
            "| --- | ---: | ---: | ---: |",
            f"| production | {huffman_health['optimal_rows']}/{huffman_health['row_count']} | {huffman_health['non_optimal_rows']} | {huffman_health['worst_gap_bits']} |",
            f"| package-merge | {huffman_health['package_merge_optimal_rows']}/{huffman_health['row_count']} | {huffman_health['package_merge_non_optimal_rows']} | {huffman_health['package_merge_worst_gap_bits']} |",
            "",
            "| validation | count | detail |",
            "| --- | ---: | --- |",
            f"| malformed rows | {huffman_health['malformed_rows']} | healthy `{huffman_healthy}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Python zlib differential coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| payloads | {python_zlib_health['payloads']} | large-file/match-heavy/dynamic {python_zlib_health['large_file_payloads']}/{python_zlib_health['match_heavy_payloads']}/{python_zlib_health['dynamic_payloads']} |",
            f"| file hex encodes | {python_zlib_health['file_hex_encode_cases']} | dictionary cases {python_zlib_health['dictionary_cases']} |",
            f"| dictionary encodes | {python_zlib_health['zlib_dict_encode_cases'] + python_zlib_health['raw_dict_encode_cases']} | zlib/raw {python_zlib_health['zlib_dict_encode_cases']}/{python_zlib_health['raw_dict_encode_cases']} |",
            f"| malformed cases | {python_zlib_health['malformed_wrapper_cases'] + python_zlib_health['malformed_deflate_cases']} | wrapper/deflate {python_zlib_health['malformed_wrapper_cases']}/{python_zlib_health['malformed_deflate_cases']} |",
            f"| CLI outcomes | {python_zlib_health['cli_successes'] + python_zlib_health['expected_failures']} | successes/expected-failures {python_zlib_health['cli_successes']}/{python_zlib_health['expected_failures']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Decode-stage smoke coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| timing rows | {decode_stage_health_summary['rows']} | ok `{decode_stage_health_summary['ok']}` |",
            f"| error rows | {decode_stage_health_summary['error_rows']} | matched/unmatched {decode_stage_health_summary['matched_error_rows']}/{decode_stage_health_summary['unmatched_error_rows']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Fuzz corpus coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| corpus cases | {fuzz_health['cases']} | matched/unmatched {fuzz_health['matched_rows']}/{fuzz_health['unmatched_rows']} |",
            f"| exact error expectations | {fuzz_health['exact_error_expectations']} | mode/error rows {fuzz_health['mode_count_rows']}/{fuzz_health['error_count_rows']} |",
            f"| coverage requirements | {fuzz_health['coverage_mode_requirements'] + fuzz_health['coverage_error_requirements']} | modes/errors {fuzz_health['coverage_mode_requirements']}/{fuzz_health['coverage_error_requirements']} |",
            "",
        ]
    )
    if native_codec_health["coverage_details"]:
        lines.extend(
            [
                "## Native codec probe coverage",
                "",
                "| codec | surface | present | ok | probes | cases |",
                "| --- | --- | --- | --- | ---: | ---: |",
            ]
        )
        for row in native_codec_health["coverage_details"]:
            lines.append(
                f"| `{row['codec']}` | `{row['surface']}` | `{row['present']}` | `{row['ok']}` | {row['ok_probe_count']}/{row['probe_count']} | {row['cases']} |"
            )
        lines.append("")
    if native_codec_health["capability_details"]:
        lines.extend(
            [
                "## Native codec probe capabilities",
                "",
                "| capability | present | ok | probes | cases |",
                "| --- | --- | --- | ---: | ---: |",
            ]
        )
        for row in native_codec_health["capability_details"]:
            lines.append(
                f"| `{row['capability']}` | `{row['present']}` | `{row['ok']}` | {row['ok_probe_count']}/{row['probe_count']} | {row['cases']} |"
            )
        lines.append("")
    if native_codec_health["probe_details"]:
        lines.extend(
            [
                "## Native codec probe executables",
                "",
                "| probe | ok | cases | returncode | timed out |",
                "| --- | --- | ---: | ---: | --- |",
            ]
        )
        for row in native_codec_health["probe_details"]:
            lines.append(
                f"| `{row['label']}` | `{row['ok']}` | {row['cases']} | {row['returncode']} | `{row['timed_out']}` |"
            )
        lines.append("")
    required_native_summary_error_phases = native_summary_error_health["required_codec_phases"]
    if not isinstance(required_native_summary_error_phases, dict):
        required_native_summary_error_phases = {}
    lines.extend(
        [
            "## Native stream summary coverage",
            "",
            "| codec | frames | skippable | checksum | block checksum | dictionary | content size | blocks raw/rle/compressed | payload/skippable bytes |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
            f"| `lz4` | {lz4_native_summary['frame_count']} | {lz4_native_summary['skippable_frame_count']} | {lz4_native_summary['checksum_frame_count']} | {lz4_native_summary['block_checksum_frame_count']} | {lz4_native_summary['dictionary_id_frame_count']} | {lz4_native_summary['content_size_frame_count']} | {lz4_native_summary['raw_block_count']}/{lz4_native_summary['rle_block_count']}/{lz4_native_summary['compressed_block_count']} | {lz4_native_summary['payload_bytes']}/{lz4_native_summary['skippable_payload_bytes']} |",
            f"| `zstd` | {zstd_native_summary['frame_count']} | {zstd_native_summary['skippable_frame_count']} | {zstd_native_summary['checksum_frame_count']} | 0 | {zstd_native_summary['dictionary_id_frame_count']} | {zstd_native_summary['content_size_frame_count']} | {zstd_native_summary['raw_block_count']}/{zstd_native_summary['rle_block_count']}/{zstd_native_summary['compressed_block_count']} | {zstd_native_summary['payload_bytes']}/{zstd_native_summary['skippable_payload_bytes']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native summary error codec coverage",
            "",
            "| codec | cases | errors | phases | required phases | missing phases |",
            "| --- | ---: | --- | --- | --- | --- |",
        ]
    )
    for codec in ("lz4", "zstd"):
        required_phases = required_native_summary_error_phases.get(codec)
        if not isinstance(required_phases, list):
            required_phases = []
        case_count = native_summary_error_health[f"{codec}_case_count"]
        error_counts = native_summary_error_health[f"{codec}_error_counts"]
        phase_counts = native_summary_error_health[f"{codec}_phase_counts"]
        missing_phases = native_summary_error_health[f"{codec}_missing_phases"]
        # Keep the per-codec matrix in the Markdown output as well as JSON so
        # dashboard reviewers can spot asymmetric malformed-stream coverage
        # without opening the retained artifact by hand.
        lines.append(
            f"| `{codec}` | {case_count} | {format_markdown_counts(error_counts)} | {format_markdown_counts(phase_counts)} | {format_markdown_list(required_phases)} | {format_markdown_list(missing_phases)} |"
        )
    lines.append("")
    phase_offset_ranges = native_summary_error_health["phase_offset_ranges"]
    if not isinstance(phase_offset_ranges, dict):
        phase_offset_ranges = {}
    phase_counts = native_summary_error_health["phase_counts"]
    if not isinstance(phase_counts, dict):
        phase_counts = {}
    lines.extend(
        [
            "## Native summary error phase offsets",
            "",
            "| phase | cases | offset range |",
            "| --- | ---: | --- |",
        ]
    )
    for phase in sorted(set(str(phase) for phase in phase_counts) | set(str(phase) for phase in phase_offset_ranges)):
        count_value = phase_counts.get(phase)
        count = int(count_value) if isinstance(count_value, int) and not isinstance(count_value, bool) else 0
        lines.append(f"| `{phase}` | {count} | {format_markdown_offset_range(phase_offset_ranges.get(phase))} |")
    if not phase_counts and not phase_offset_ranges:
        lines.append("| `none` | 0 | `missing` |")
    lines.append("")
    selected_labels = ", ".join(
        f"`{case.get('label', '')}`"
        for case in native_tier_discovery_health["selected_cases"]
        if isinstance(case, dict)
    ) or "`none`"
    source_list = ", ".join(f"`{source}`" for source in native_tier_discovery_health["sources"]) or "`none`"
    lines.extend(
        [
            "## Native tier corpus discovery",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| sources | {native_tier_discovery_health['source_count']}/{native_tier_discovery_health['candidate_count']} | mode `{native_tier_discovery_health['source_mode']}`, full `{native_tier_discovery_health['full']}`, limit `{native_tier_discovery_health['limit']}` |",
            f"| selected cases | {native_tier_discovery_health['selected_case_count']} | {selected_labels} |",
            f"| corpus paths | {len(native_tier_discovery_health['sources'])} | {source_list} |",
            f"| output csv | {1 if native_tier_discovery_health['csv'] else 0} | `{native_tier_discovery_health['csv'] or 'none'}` |",
            f"| missing reason | {1 if native_tier_discovery_health['missing_reason'] else 0} | `{native_tier_discovery_health['missing_reason'] or 'none'}` |",
            "",
        ]
    )
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
                "dashboard_configuration_healthy": dashboard_configuration["healthy"],
                "dashboard_config_index_present": dashboard_configuration["config_index_present"],
                "dashboard_config_index_ok": dashboard_configuration["config_index_ok"],
                "dashboard_config_index_config_count": dashboard_configuration["config_index_config_count"],
                "dashboard_config_index_matched": dashboard_configuration["config_index_matched"],
                "dashboard_config_index_unmatched": dashboard_configuration["config_index_unmatched"],
                "dashboard_config_index_negative_present": dashboard_configuration["config_index_negative_present"],
                "dashboard_config_index_negative_ok": dashboard_configuration["config_index_negative_ok"],
                "dashboard_config_index_negative_case_count": dashboard_configuration["config_index_negative_case_count"],
                "dashboard_config_index_negative_matched": dashboard_configuration["config_index_negative_matched"],
                "dashboard_config_index_negative_unmatched": dashboard_configuration["config_index_negative_unmatched"],
                "dashboard_category_negative_present": dashboard_configuration["category_negative_present"],
                "dashboard_category_negative_ok": dashboard_configuration["category_negative_ok"],
                "dashboard_category_negative_case_count": dashboard_configuration["category_negative_case_count"],
                "dashboard_category_negative_matched": dashboard_configuration["category_negative_matched"],
                "dashboard_category_negative_unmatched": dashboard_configuration["category_negative_unmatched"],
                "dashboard_producers_required_present": dashboard_configuration["producers_required_present"],
                "dashboard_producers_required_ok": dashboard_configuration["producers_required_ok"],
                "dashboard_producers_required_artifact_count": dashboard_configuration["producers_required_artifact_count"],
                "dashboard_producers_required_matched": dashboard_configuration["producers_required_matched"],
                "dashboard_producers_required_unmatched": dashboard_configuration["producers_required_unmatched"],
                "dashboard_producers_required_smoke_gate_count": dashboard_configuration["producers_required_smoke_gate_count"],
                "dashboard_producers_negative_present": dashboard_configuration["producers_negative_present"],
                "dashboard_producers_negative_ok": dashboard_configuration["producers_negative_ok"],
                "dashboard_producers_negative_case_count": dashboard_configuration["producers_negative_case_count"],
                "dashboard_producers_negative_matched": dashboard_configuration["producers_negative_matched"],
                "dashboard_producers_negative_unmatched": dashboard_configuration["producers_negative_unmatched"],
                "validation_json_present": validation_json["present"],
                "validation_json_ok": validation_json["ok"],
                "validation_json_healthy": validation_json["healthy"],
                "validation_json_checked_schema_count": validation_json["checked_schema_count"],
                "validation_json_cli_success_ok": validation_json["cli_success_ok"],
                "validation_json_cli_failure_ok": validation_json["cli_failure_ok"],
                "validation_json_cli_failure_hint": validation_json["cli_failure_hint"],
                "validation_json_report_rows": validation_json["report_rows"],
                "validation_json_corrupt_rows": validation_json["corrupt_rows"],
                "validation_json_docs_negative_present": validation_json["docs_negative_present"],
                "validation_json_docs_negative_ok": validation_json["docs_negative_ok"],
                "validation_json_docs_negative_case_count": validation_json["docs_negative_case_count"],
                "validation_json_docs_negative_matched": validation_json["docs_negative_matched"],
                "validation_json_docs_negative_unmatched": validation_json["docs_negative_unmatched"],
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
                "native_fuzz_corpus_present": native_fuzz["present"],
                "native_fuzz_corpus_coverage_present": native_fuzz["coverage_present"],
                "native_fuzz_corpus_healthy": native_fuzz["healthy"],
                "native_fuzz_corpus_cases": native_fuzz["cases"],
                "native_fuzz_corpus_accepted": native_fuzz["accepted"],
                "native_fuzz_corpus_rejected": native_fuzz["rejected"],
                "native_fuzz_corpus_matched_rows": native_fuzz["matched_rows"],
                "native_fuzz_corpus_unmatched_rows": native_fuzz["unmatched_rows"],
                "native_fuzz_corpus_exact_error_expectations": native_fuzz["exact_error_expectations"],
                "native_fuzz_corpus_mode_count_rows": native_fuzz["mode_count_rows"],
                "native_fuzz_corpus_error_count_rows": native_fuzz["error_count_rows"],
                "native_fuzz_corpus_coverage_mode_requirements": native_fuzz["coverage_mode_requirements"],
                "native_fuzz_corpus_coverage_error_requirements": native_fuzz["coverage_error_requirements"],
                "br_static_dictionary_present": br_static_dictionary["present"],
                "br_static_dictionary_upstream_present": br_static_dictionary["upstream_present"],
                "br_static_dictionary_node_present": br_static_dictionary["node_present"],
                "br_static_dictionary_audit_present": br_static_dictionary["audit_present"],
                "br_static_dictionary_negative_present": br_static_dictionary["negative_present"],
                "br_static_dictionary_healthy": br_static_dictionary["healthy"],
                "br_static_dictionary_candidate_count": br_static_dictionary["candidate_count"],
                "br_static_dictionary_raw_word_count": br_static_dictionary["raw_word_count"],
                "br_static_dictionary_upstream_candidate_count": br_static_dictionary["upstream_candidate_count"],
                "br_static_dictionary_upstream_raw_word_count": br_static_dictionary["upstream_raw_word_count"],
                "br_static_dictionary_node_probed_count": br_static_dictionary["node_probed_count"],
                "br_static_dictionary_node_decode_successes": br_static_dictionary["node_decode_successes"],
                "br_static_dictionary_node_size_winner_count": br_static_dictionary["node_size_winner_count"],
                "br_static_dictionary_audit_entry_count": br_static_dictionary["audit_entry_count"],
                "br_static_dictionary_audit_anchor_count": br_static_dictionary["audit_anchor_count"],
                "br_static_dictionary_audit_generated_zig_bytes": br_static_dictionary["audit_generated_zig_bytes"],
                "br_static_dictionary_negative_case_count": br_static_dictionary["negative_case_count"],
                "br_static_dictionary_negative_matched": br_static_dictionary["negative_matched"],
                "png_scratch_present": png_scratch["present"],
                "png_scratch_healthy": png_scratch["healthy"],
                "png_scratch_case_count": png_scratch["case_count"],
                "png_scratch_adam7_cases": png_scratch["adam7_cases"],
                "png_scratch_stored_achieved": png_scratch["stored_achieved"],
                "png_scratch_fixed_achieved": png_scratch["fixed_achieved"],
                "png_scratch_total_zlib_scratch": png_scratch["total_zlib_scratch"],
                "png_scratch_total_streaming_savings": png_scratch["total_streaming_savings"],
                "png_scratch_max_working_scratch": png_scratch["max_working_scratch"],
                "png_scratch_max_streaming_working_scratch": png_scratch["max_streaming_working_scratch"],
                "png_scratch_max_fixed_dynamic_streaming_working_scratch": png_scratch["max_fixed_dynamic_streaming_working_scratch"],
                "png_scratch_min_streaming_ratio": png_scratch["min_streaming_ratio"],
                "zlib_relaxed_present": zlib_relaxed["present"],
                "zlib_relaxed_healthy": zlib_relaxed["healthy"],
                "zlib_relaxed_strict_rejections": zlib_relaxed["strict_rejections"],
                "zlib_relaxed_successes": zlib_relaxed["relaxed_successes"],
                "zlib_relaxed_dictionary_successes": zlib_relaxed["dictionary_successes"],
                "zlib_relaxed_concatenated_successes": zlib_relaxed["zlib_concatenated_successes"],
                "zlib_relaxed_decoder_successes": zlib_relaxed["zlib_decoder_successes"],
                "zlib_relaxed_limited_rejections": zlib_relaxed["limited_rejections"],
                "gzip_relaxed_strict_rejections": zlib_relaxed["gzip_strict_rejections"],
                "gzip_relaxed_successes": zlib_relaxed["gzip_relaxed_successes"],
                "gzip_relaxed_concatenated_successes": zlib_relaxed["gzip_concatenated_successes"],
                "gzip_relaxed_decoder_successes": zlib_relaxed["gzip_decoder_successes"],
                "gzip_relaxed_limited_rejections": zlib_relaxed["gzip_limited_rejections"],
                "zstd_compare_present": zstd_compare["present"],
                "zstd_compare_standard_present": zstd_compare["standard_present"],
                "zstd_compare_block_sweep_present": zstd_compare["block_sweep_present"],
                "zstd_compare_healthy": zstd_compare["healthy"],
                "zstd_compare_rows": zstd_compare["compare_rows"],
                "zstd_compare_standard_rows": zstd_compare["standard_rows"],
                "zstd_compare_block_sweep_rows": zstd_compare["block_sweep_rows"],
                "zstd_compare_native_ratio": zstd_compare["native_ratio"],
                "zstd_compare_native_stream_ratio": zstd_compare["native_stream_ratio"],
                "zstd_compare_standard_native_ratio": zstd_compare["standard_native_ratio"],
                "zstd_compare_standard_native_stream_ratio": zstd_compare["standard_native_stream_ratio"],
                "zstd_compare_decode_vs_zstd": zstd_compare["decode_vs_zstd"],
                "zstd_compare_standard_decode_vs_zstd": zstd_compare["standard_decode_vs_zstd"],
                "zstd_compare_best_block_len": zstd_compare["best_block_len"],
                "zstd_compare_best_range_decode_mib_s": zstd_compare["best_range_decode_mib_s"],
                "zstd_compare_best_range_decode_full_input_mib_s": zstd_compare["best_range_decode_full_input_mib_s"],
                "native_allocation_present": native_allocation["present"],
                "native_allocation_smoke_present": native_allocation["smoke_present"],
                "native_allocation_negative_present": native_allocation["negative_present"],
                "native_allocation_healthy": native_allocation["healthy"],
                "native_allocation_report_case_count": native_allocation["report_case_count"],
                "native_allocation_required_zero_allocation_cases": native_allocation["required_zero_allocation_cases"],
                "native_allocation_zero_allocation_matched": native_allocation["zero_allocation_matched"],
                "native_allocation_required_budget_cases": native_allocation["required_budget_cases"],
                "native_allocation_budget_matched": native_allocation["budget_matched"],
                "native_allocation_negative_case_count": native_allocation["negative_case_count"],
                "native_allocation_negative_matched": native_allocation["negative_matched"],
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
                "native_summary_error_present": native_summary_error_health["present"],
                "native_summary_error_healthy": native_summary_error_healthy,
                "native_summary_error_case_count": native_summary_error_health["case_count"],
                "native_summary_error_lz4_case_count": native_summary_error_health["lz4_case_count"],
                "native_summary_error_zstd_case_count": native_summary_error_health["zstd_case_count"],
                "native_summary_error_checksum_mismatch_count": native_summary_error_health["checksum_mismatch_count"],
                "native_summary_error_corrupt_frame_count": native_summary_error_health["corrupt_frame_count"],
                "native_summary_error_truncated_frame_count": native_summary_error_health["truncated_frame_count"],
                "native_summary_error_magic_phase_count": native_summary_error_health["magic_phase_count"],
                "native_summary_error_skippable_payload_phase_count": native_summary_error_health["skippable_payload_phase_count"],
                "native_summary_error_frame_body_phase_count": native_summary_error_health["frame_body_phase_count"],
                "native_summary_error_frame_checksum_phase_count": native_summary_error_health["frame_checksum_phase_count"],
                "native_summary_error_frame_phase_count": native_summary_error_health["frame_phase_count"],
                "native_summary_error_error_counts": native_summary_error_health["error_counts"],
                "native_summary_error_phase_counts": native_summary_error_health["phase_counts"],
                "native_summary_error_lz4_error_counts": native_summary_error_health["lz4_error_counts"],
                "native_summary_error_zstd_error_counts": native_summary_error_health["zstd_error_counts"],
                "native_summary_error_lz4_phase_counts": native_summary_error_health["lz4_phase_counts"],
                "native_summary_error_zstd_phase_counts": native_summary_error_health["zstd_phase_counts"],
                "native_summary_error_offset_min": native_summary_error_health["offset_min"],
                "native_summary_error_offset_max": native_summary_error_health["offset_max"],
                "native_summary_error_lz4_offset_min": native_summary_error_health["lz4_offset_min"],
                "native_summary_error_lz4_offset_max": native_summary_error_health["lz4_offset_max"],
                "native_summary_error_zstd_offset_min": native_summary_error_health["zstd_offset_min"],
                "native_summary_error_zstd_offset_max": native_summary_error_health["zstd_offset_max"],
                "native_summary_error_phase_offset_ranges": native_summary_error_health["phase_offset_ranges"],
                "native_summary_error_required_codec_phases": native_summary_error_health["required_codec_phases"],
                "native_summary_error_lz4_missing_phases": native_summary_error_health["lz4_missing_phases"],
                "native_summary_error_zstd_missing_phases": native_summary_error_health["zstd_missing_phases"],
                "native_summary_error_negative_present": native_summary_error_negative["present"],
                "native_summary_error_negative_healthy": native_summary_error_negative_healthy,
                "native_summary_error_negative_case_count": native_summary_error_negative["case_count"],
                "lz4_native_summary_present": lz4_native_summary["present"],
                "lz4_native_summary_healthy": lz4_native_summary_healthy,
                "lz4_native_summary_frame_count": lz4_native_summary["frame_count"],
                "lz4_native_summary_skippable_frame_count": lz4_native_summary["skippable_frame_count"],
                "lz4_native_summary_checksum_frame_count": lz4_native_summary["checksum_frame_count"],
                "lz4_native_summary_block_checksum_frame_count": lz4_native_summary["block_checksum_frame_count"],
                "lz4_native_summary_dictionary_id_frame_count": lz4_native_summary["dictionary_id_frame_count"],
                "lz4_native_summary_content_size_frame_count": lz4_native_summary["content_size_frame_count"],
                "lz4_native_summary_declared_content_bytes": lz4_native_summary["declared_content_bytes"],
                "lz4_native_summary_block_count": lz4_native_summary["block_count"],
                "lz4_native_summary_raw_block_count": lz4_native_summary["raw_block_count"],
                "lz4_native_summary_compressed_block_count": lz4_native_summary["compressed_block_count"],
                "lz4_native_summary_compressed_bytes": lz4_native_summary["compressed_bytes"],
                "lz4_native_summary_payload_bytes": lz4_native_summary["payload_bytes"],
                "lz4_native_summary_skippable_payload_bytes": lz4_native_summary["skippable_payload_bytes"],
                "zstd_native_summary_present": zstd_native_summary["present"],
                "zstd_native_summary_healthy": zstd_native_summary_healthy,
                "zstd_native_summary_frame_count": zstd_native_summary["frame_count"],
                "zstd_native_summary_skippable_frame_count": zstd_native_summary["skippable_frame_count"],
                "zstd_native_summary_checksum_frame_count": zstd_native_summary["checksum_frame_count"],
                "zstd_native_summary_dictionary_id_frame_count": zstd_native_summary["dictionary_id_frame_count"],
                "zstd_native_summary_content_size_frame_count": zstd_native_summary["content_size_frame_count"],
                "zstd_native_summary_declared_content_bytes": zstd_native_summary["declared_content_bytes"],
                "zstd_native_summary_block_count": zstd_native_summary["block_count"],
                "zstd_native_summary_raw_block_count": zstd_native_summary["raw_block_count"],
                "zstd_native_summary_rle_block_count": zstd_native_summary["rle_block_count"],
                "zstd_native_summary_compressed_block_count": zstd_native_summary["compressed_block_count"],
                "zstd_native_summary_compressed_bytes": zstd_native_summary["compressed_bytes"],
                "zstd_native_summary_payload_bytes": zstd_native_summary["payload_bytes"],
                "zstd_native_summary_skippable_payload_bytes": zstd_native_summary["skippable_payload_bytes"],
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
