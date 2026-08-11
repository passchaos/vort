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
    if "bench" in name or "benchmark" in name or "zstd-compare" in name or "snappy-report" in name:
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
    markdown = next((artifact for artifact in artifacts if artifact.name == "vort-sidecar-corrupt-smoke.md"), None)

    def int_field(data: dict, field: str) -> int:
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def item_bool(row: dict, field: str) -> bool | None:
        value = row.get(field)
        return value if isinstance(value, bool) else None

    def item_int(row: dict, field: str) -> int | None:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else None

    def item_str(row: dict, field: str) -> str:
        value = row.get(field)
        return value if isinstance(value, str) else ""

    def parse_markdown_bool(value: str) -> bool | None:
        if value == "true":
            return True
        if value == "false":
            return False
        return None

    def parse_markdown_rows(path: Path | None) -> list[dict[str, bool | int | str | None]]:
        if path is None:
            return []
        parsed: list[dict[str, bool | int | str | None]] = []
        try:
            text = path.read_text(errors="replace")
        except Exception:
            return parsed
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) != 6 or cells[0] in {"case", "---"} or set(cells[0]) == {"-"}:
                continue
            try:
                stream_bytes = int(cells[4])
                sidecar_bytes = int(cells[5])
            except ValueError:
                stream_bytes = None
                sidecar_bytes = None
            parsed.append(
                {
                    "case": cells[0],
                    "metadata_ok": parse_markdown_bool(cells[1]),
                    "full_rejected": parse_markdown_bool(cells[2]),
                    "full_error": cells[3],
                    "stream_bytes": stream_bytes,
                    "sidecar_bytes": sidecar_bytes,
                }
            )
        return parsed

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.sidecar_corrupt_smoke_report":
            continue
        rows = int_field(data, "rows")
        metadata_ok_rows = int_field(data, "metadata_ok_rows")
        full_rejected_rows = int_field(data, "full_rejected_rows")
        metadata_failed_rows = rows - metadata_ok_rows
        full_not_rejected_rows = rows - full_rejected_rows

        items = data.get("items")
        items = items if isinstance(items, list) else []
        item_rows = len(items)
        item_metadata_ok_rows = sum(1 for row in items if isinstance(row, dict) and row.get("metadata_ok") is True)
        item_full_rejected_rows = sum(1 for row in items if isinstance(row, dict) and row.get("full_rejected") is True)
        item_malformed_rows = 0
        item_duplicate_rows = 0
        expected_by_case: dict[str, dict[str, bool | int | str]] = {}
        for row in items:
            if not isinstance(row, dict):
                item_malformed_rows += 1
                continue
            case = item_str(row, "case")
            expected = {
                "case": case,
                "metadata_ok": item_bool(row, "metadata_ok"),
                "full_rejected": item_bool(row, "full_rejected"),
                "full_error": item_str(row, "full_error"),
                "stream_bytes": item_int(row, "stream_bytes"),
                "sidecar_bytes": item_int(row, "sidecar_bytes"),
            }
            if not case or any(value is None for value in expected.values()):
                item_malformed_rows += 1
                continue
            if case in expected_by_case:
                item_duplicate_rows += 1
                continue
            expected_by_case[case] = expected
        item_count_mismatch = (
            abs(rows - item_rows)
            + abs(metadata_ok_rows - item_metadata_ok_rows)
            + abs(full_rejected_rows - item_full_rejected_rows)
            + item_malformed_rows
            + item_duplicate_rows
        )

        markdown_present = markdown is not None
        markdown_rows_data = parse_markdown_rows(markdown if markdown_present else None)
        markdown_rows = len(markdown_rows_data)
        markdown_matched_cases: set[str] = set()
        for row in markdown_rows_data:
            case = str(row.get("case") or "")
            expected = expected_by_case.get(case)
            if expected is None or case in markdown_matched_cases:
                continue
            if all(row.get(field) == expected[field] for field in ("case", "metadata_ok", "full_rejected", "full_error", "stream_bytes", "sidecar_bytes")):
                markdown_matched_cases.add(case)
        markdown_matched = len(markdown_matched_cases)
        markdown_unmatched = max(markdown_rows, len(expected_by_case)) - markdown_matched
        healthy = (
            rows > 0
            and metadata_failed_rows == 0
            and full_not_rejected_rows == 0
            and item_rows == rows
            and item_count_mismatch == 0
            and markdown_present
            and markdown_rows == item_rows
            and markdown_matched == item_rows
            and markdown_unmatched == 0
        )
        return {
            "present": True,
            "rows": rows,
            "metadata_ok_rows": metadata_ok_rows,
            "full_rejected_rows": full_rejected_rows,
            "metadata_failed_rows": metadata_failed_rows,
            "full_not_rejected_rows": full_not_rejected_rows,
            "item_rows": item_rows,
            "item_count_mismatch": item_count_mismatch,
            "markdown_present": markdown_present,
            "markdown_rows": markdown_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
            "healthy": healthy,
        }
    return {
        "present": False,
        "rows": 0,
        "metadata_ok_rows": 0,
        "full_rejected_rows": 0,
        "metadata_failed_rows": 0,
        "full_not_rejected_rows": 0,
        "item_rows": 0,
        "item_count_mismatch": 0,
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
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
        markdown_present = False
        markdown_summary_rows = 0
        markdown_matched = 0
        markdown_case_rows = 0
        markdown_case_matched = 0
        markdown_expected = {
            "rows": row_count,
            "optimal rows": optimal_rows,
            "non-optimal rows": non_optimal_rows,
            "worst gap bits": worst_gap_bits,
            "package-merge optimal rows": package_merge_optimal_rows,
            "package-merge non-optimal rows": package_merge_non_optimal_rows,
            "package-merge worst gap bits": package_merge_worst_gap_bits,
        }
        for md_artifact in artifacts:
            if md_artifact.name != "vort-huffman-length-report.md":
                continue
            markdown_present = True
            text = md_artifact.read_text(errors="replace")
            markdown_lines = {line.strip() for line in text.splitlines()}
            for label, expected in markdown_expected.items():
                markdown_summary_rows += 1
                if f"- {label}: {expected}" in markdown_lines:
                    markdown_matched += 1
            markdown_case_rows = row_count
            for row in rows:
                expected_row = (
                    f"| {row.get('case')} | {row.get('symbol_count')} | {row.get('max_bits')} | "
                    f"{row.get('optimal_cost')} | {row.get('actual_cost')} | {row.get('gap_bits')} | "
                    f"{row.get('package_merge_cost')} | {row.get('package_merge_gap_bits')} | "
                    f"{row.get('kraft_cost')}/{row.get('kraft_limit')} | {row.get('optimal')} | "
                    f"{row.get('package_merge_optimal')} | {row.get('lengths')} | "
                    f"{row.get('optimal_lengths')} | {row.get('package_merge_lengths')} |"
                )
                if expected_row in markdown_lines:
                    markdown_case_matched += 1
            break
        markdown_unmatched = markdown_summary_rows - markdown_matched
        markdown_case_unmatched = markdown_case_rows - markdown_case_matched
        markdown_healthy = (
            markdown_present
            and markdown_summary_rows == len(markdown_expected)
            and markdown_unmatched == 0
            and markdown_case_rows == row_count
            and markdown_case_unmatched == 0
        )
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
            "markdown_present": markdown_present,
            "markdown_summary_rows": markdown_summary_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
            "markdown_case_rows": markdown_case_rows,
            "markdown_case_matched": markdown_case_matched,
            "markdown_case_unmatched": markdown_case_unmatched,
            "healthy": row_count > 0
            and malformed_rows == 0
            and non_optimal_rows == 0
            and worst_gap_bits == 0
            and package_merge_non_optimal_rows == 0
            and package_merge_worst_gap_bits == 0
            and markdown_healthy,
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
        "markdown_present": False,
        "markdown_summary_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
        "markdown_case_rows": 0,
        "markdown_case_matched": 0,
        "markdown_case_unmatched": 0,
        "healthy": False,
    }


def level_report_health(artifacts: list[Path]) -> dict:
    expected_cases = {"text", "structured", "repeated"}
    expected_levels = {"fastest", "fast", "default", "best"}
    expected_strategies = {"default", "filtered", "huffman_only", "rle"}
    expected_pairs = {
        (case, level, strategy)
        for case in expected_cases
        for level in expected_levels
        for strategy in expected_strategies
    }
    expected_rows = len(expected_pairs)

    def parse_int(value: str | None) -> int | None:
        try:
            return int(value or "0")
        except ValueError:
            return None

    def scaled_ratio(numerator: int, denominator: int, scale: int) -> int:
        return (numerator * scale) // denominator if denominator > 0 else 0

    def row_key(row: dict[str, str]) -> tuple[int, int, int]:
        raw = parse_int(row.get("raw_best_bytes")) or 0
        adaptive = parse_int(row.get("adaptive_bytes")) or 0
        tokens = parse_int(row.get("tokens")) or 0
        return raw, adaptive, tokens

    def adaptive_key(row: dict[str, str]) -> tuple[int, int, int]:
        raw = parse_int(row.get("raw_best_bytes")) or 0
        adaptive = parse_int(row.get("adaptive_bytes")) or 0
        tokens = parse_int(row.get("tokens")) or 0
        return adaptive, raw, tokens

    def percent(value: int) -> str:
        return f"{value // 100}.{value % 100:02d}%"

    for artifact in artifacts:
        if artifact.name != "vort-level-report.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[tuple[str, str, str]] = set()
        duplicate_pairs: set[tuple[str, str, str]] = set()
        unknown_pairs: set[tuple[str, str, str]] = set()
        rows_by_case: dict[str, list[dict[str, str]]] = {case: [] for case in expected_cases}
        positive_rows = 0
        shape_rows = 0
        token_accounting_rows = 0
        ratio_rows = 0
        roundtrip_rows = 0
        for row in rows:
            case = str(row.get("case") or "")
            level = str(row.get("level") or "")
            strategy = str(row.get("strategy") or "")
            triple = (case, level, strategy)
            if triple in expected_pairs:
                if triple in seen:
                    duplicate_pairs.add(triple)
                seen.add(triple)
                rows_by_case.setdefault(case, []).append(row)
                shape_rows += 1
            elif case or level or strategy:
                unknown_pairs.add(triple)

            input_bytes = parse_int(row.get("input_bytes"))
            tokens = parse_int(row.get("tokens"))
            literal_tokens = parse_int(row.get("literal_tokens"))
            match_tokens = parse_int(row.get("match_tokens"))
            matched_bytes = parse_int(row.get("matched_bytes"))
            match_coverage = parse_int(row.get("match_coverage_x10000"))
            fixed_bits = parse_int(row.get("fixed_bits"))
            fixed_bits_per_byte = parse_int(row.get("fixed_bits_per_byte_x100"))
            raw_best_bytes = parse_int(row.get("raw_best_bytes"))
            raw_best_ratio = parse_int(row.get("raw_best_ratio_x10000"))
            adaptive_bytes = parse_int(row.get("adaptive_bytes"))
            adaptive_ratio = parse_int(row.get("adaptive_ratio_x10000"))
            roundtrip_crc32 = parse_int(row.get("roundtrip_crc32"))
            numeric_values = (
                input_bytes,
                tokens,
                literal_tokens,
                match_tokens,
                matched_bytes,
                match_coverage,
                fixed_bits,
                fixed_bits_per_byte,
                raw_best_bytes,
                raw_best_ratio,
                adaptive_bytes,
                adaptive_ratio,
                roundtrip_crc32,
            )
            if any(value is None for value in numeric_values):
                continue
            assert input_bytes is not None
            assert tokens is not None
            assert literal_tokens is not None
            assert match_tokens is not None
            assert matched_bytes is not None
            assert match_coverage is not None
            assert fixed_bits is not None
            assert fixed_bits_per_byte is not None
            assert raw_best_bytes is not None
            assert raw_best_ratio is not None
            assert adaptive_bytes is not None
            assert adaptive_ratio is not None
            assert roundtrip_crc32 is not None

            if input_bytes > 0 and tokens > 0 and raw_best_bytes > 0 and adaptive_bytes > 0:
                positive_rows += 1
            if (
                tokens == literal_tokens + match_tokens
                and matched_bytes <= input_bytes
                and match_coverage <= 10_000
            ):
                token_accounting_rows += 1
            if (
                raw_best_ratio == scaled_ratio(raw_best_bytes, input_bytes, 10_000)
                and adaptive_ratio == scaled_ratio(adaptive_bytes, input_bytes, 10_000)
                and fixed_bits_per_byte == scaled_ratio(fixed_bits, input_bytes, 100)
                and match_coverage == scaled_ratio(matched_bytes, input_bytes, 10_000)
            ):
                ratio_rows += 1
            if roundtrip_crc32 > 0:
                roundtrip_rows += 1

        row_count = len(rows)
        missing_pairs = sorted("/".join(pair) for pair in expected_pairs - seen)
        duplicate_pair_names = sorted("/".join(pair) for pair in duplicate_pairs)
        unknown_pair_names = sorted("/".join(pair) for pair in unknown_pairs)
        markdown_present = False
        markdown_summary_rows = 0
        markdown_matched = 0
        markdown_detail_rows = 0
        markdown_detail_matched = 0
        for md_artifact in artifacts:
            if md_artifact.name != "vort-level-report.md":
                continue
            markdown_present = True
            markdown_lines = {line.rstrip() for line in md_artifact.read_text(errors="replace").splitlines()}
            expected_lines = [f"Rows: {len(rows)}"]
            for case in sorted(expected_cases):
                case_rows = rows_by_case.get(case, [])
                if not case_rows:
                    continue
                best_raw = min(case_rows, key=row_key)
                best_adaptive = min(case_rows, key=adaptive_key)
                expected_lines.append(
                    "|{case} | {raw_bytes} | {raw_level}/{raw_strategy}/{raw_parser} | "
                    "{adaptive_bytes} | {adaptive_level}/{adaptive_strategy}/{adaptive_parser} | "
                    "{coverage} | {tokens} |".format(
                        case=case,
                        raw_bytes=best_raw.get("raw_best_bytes", ""),
                        raw_level=best_raw.get("level", ""),
                        raw_strategy=best_raw.get("strategy", ""),
                        raw_parser=best_raw.get("parser", ""),
                        adaptive_bytes=best_adaptive.get("adaptive_bytes", ""),
                        adaptive_level=best_adaptive.get("level", ""),
                        adaptive_strategy=best_adaptive.get("strategy", ""),
                        adaptive_parser=best_adaptive.get("parser", ""),
                        coverage=percent(parse_int(best_adaptive.get("match_coverage_x10000")) or 0),
                        tokens=best_adaptive.get("tokens", ""),
                    )
                )
            for line in expected_lines:
                markdown_summary_rows += 1
                if line in markdown_lines:
                    markdown_matched += 1
            markdown_detail_rows = row_count
            for row in rows:
                expected_row = (
                    "|{case} | {level} | {strategy} | {parser} | {raw_bytes} | {raw_ratio} | "
                    "{adaptive_bytes} | {adaptive_ratio} | {coverage} | {avg_match_len} | "
                    "{fixed_bits_per_byte} | {tokens} | {stored_fast_path} |"
                ).format(
                    case=row.get("case", ""),
                    level=row.get("level", ""),
                    strategy=row.get("strategy", ""),
                    parser=row.get("parser", ""),
                    raw_bytes=row.get("raw_best_bytes", ""),
                    raw_ratio=percent(parse_int(row.get("raw_best_ratio_x10000")) or 0),
                    adaptive_bytes=row.get("adaptive_bytes", ""),
                    adaptive_ratio=percent(parse_int(row.get("adaptive_ratio_x10000")) or 0),
                    coverage=percent(parse_int(row.get("match_coverage_x10000")) or 0),
                    avg_match_len=percent(parse_int(row.get("avg_match_len_x100")) or 0).removesuffix("%"),
                    fixed_bits_per_byte=percent(parse_int(row.get("fixed_bits_per_byte_x100")) or 0).removesuffix("%"),
                    tokens=row.get("tokens", ""),
                    stored_fast_path=row.get("stored_fast_path", ""),
                )
                if expected_row in markdown_lines:
                    markdown_detail_matched += 1
            break
        markdown_unmatched = markdown_summary_rows - markdown_matched
        markdown_detail_unmatched = markdown_detail_rows - markdown_detail_matched
        healthy = (
            row_count == expected_rows
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and token_accounting_rows == row_count
            and ratio_rows == row_count
            and roundtrip_rows == row_count
            and markdown_present
            and markdown_summary_rows == 1 + len(expected_cases)
            and markdown_unmatched == 0
            and markdown_detail_rows == row_count
            and markdown_detail_unmatched == 0
        )
        return {
            "present": True,
            "healthy": healthy,
            "rows": row_count,
            "expected_rows": expected_rows,
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "token_accounting_rows": token_accounting_rows,
            "ratio_rows": ratio_rows,
            "roundtrip_rows": roundtrip_rows,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
            "markdown_present": markdown_present,
            "markdown_summary_rows": markdown_summary_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
            "markdown_detail_rows": markdown_detail_rows,
            "markdown_detail_matched": markdown_detail_matched,
            "markdown_detail_unmatched": markdown_detail_unmatched,
        }
    return {
        "present": False,
        "healthy": False,
        "rows": 0,
        "expected_rows": expected_rows,
        "positive_rows": 0,
        "shape_rows": 0,
        "token_accounting_rows": 0,
        "ratio_rows": 0,
        "roundtrip_rows": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
        "markdown_present": False,
        "markdown_summary_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
        "markdown_detail_rows": 0,
        "markdown_detail_matched": 0,
        "markdown_detail_unmatched": 0,
    }


def dynamic_plan_health(artifacts: list[Path]) -> dict:
    expected_sources = {
        "project_files": {
            "artifact": "vort-dynamic-plan-report.csv",
            "paths": {"README.md", "docs/roadmap.md"},
        },
        "builtins": {
            "artifact": "vort-dynamic-plan-builtins-report.csv",
            "paths": {"tiny", "repetitive", "overlap-rle", "distance-heavy", "dynamic-match", "text", "binary"},
        },
    }
    histogram_fields = {
        "length_symbol_hist": 29,
        "distance_symbol_hist": 30,
        "length_extra_hist": 6,
        "distance_extra_hist": 14,
        "best_preset_length_symbol_hist": 29,
        "best_preset_distance_symbol_hist": 30,
        "best_preset_length_extra_hist": 6,
        "best_preset_distance_extra_hist": 14,
    }

    def parse_int(row: dict[str, str], field: str) -> int | None:
        try:
            return int(row.get(field) or "0")
        except ValueError:
            return None

    def parse_float(row: dict[str, str], field: str) -> float | None:
        try:
            return float(row.get(field) or "0")
        except ValueError:
            return None

    def ratio_close(row: dict[str, str], field: str, numerator: int, denominator: int) -> bool:
        reported = parse_float(row, field)
        if reported is None:
            return False
        expected = (numerator / denominator) if denominator else 0.0
        return abs(reported - expected) <= 0.0001

    def histogram_ok(row: dict[str, str], field: str, expected_len: int) -> bool:
        parts = str(row.get(field) or "").split(";")
        if len(parts) != expected_len:
            return False
        try:
            return all(int(part) >= 0 for part in parts)
        except ValueError:
            return False

    total_rows = 0
    expected_rows = sum(len(config["paths"]) for config in expected_sources.values())
    present_sources: set[str] = set()
    seen_paths: set[tuple[str, str]] = set()
    positive_rows = 0
    token_accounting_rows = 0
    histogram_rows = 0
    ratio_rows = 0
    slack_rows = 0
    wrapper_rows = 0
    malformed_rows = 0

    for source, config in expected_sources.items():
        artifact_name = config["artifact"]
        artifact = next((path for path in artifacts if path.name == artifact_name), None)
        if artifact is None:
            continue
        present_sources.add(source)
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        total_rows += len(rows)
        for row in rows:
            path_name = str(row.get("path") or "")
            if path_name in config["paths"]:
                seen_paths.add((source, path_name))

            int_fields = {
                field: parse_int(row, field)
                for field in (
                    "input_bytes",
                    "token_count",
                    "literal_tokens",
                    "match_tokens",
                    "matched_bytes",
                    "short_match_tokens",
                    "far_match_tokens",
                    "stored_bytes",
                    "fixed_bytes",
                    "dynamic_bytes",
                    "dynamic_header_bits",
                    "dynamic_literal_bits",
                    "dynamic_length_bits",
                    "dynamic_distance_bits",
                    "dynamic_length_extra_bits",
                    "dynamic_distance_extra_bits",
                    "dynamic_extra_bits",
                    "hlit",
                    "hdist",
                    "hclen",
                    "code_length_ops",
                    "stats_ns",
                    "dynamic_encode_ns",
                    "best_encode_ns",
                    "dynamic_zlib_bytes",
                    "best_zlib_bytes",
                    "best_preset_token_count",
                    "best_preset_literal_tokens",
                    "best_preset_match_tokens",
                    "best_preset_matched_bytes",
                    "best_preset_zlib_bytes",
                    "best_preset_header_bits",
                    "best_preset_literal_bits",
                    "best_preset_length_bits",
                    "best_preset_distance_bits",
                    "best_preset_length_extra_bits",
                    "best_preset_distance_extra_bits",
                    "best_preset_extra_bits",
                    "dynamic_bits_mod8",
                    "dynamic_bits_to_save_byte",
                    "best_preset_bits_mod8",
                    "best_preset_bits_to_save_byte",
                )
            }
            if any(value is None for value in int_fields.values()):
                malformed_rows += 1
                continue
            values = {key: int(value) for key, value in int_fields.items() if value is not None}
            if (
                values["input_bytes"] > 0
                and values["token_count"] > 0
                and values["stored_bytes"] > 0
                and values["fixed_bytes"] > 0
                and values["dynamic_bytes"] > 0
                and values["dynamic_zlib_bytes"] > 0
                and values["best_zlib_bytes"] > 0
                and values["stats_ns"] > 0
                and values["dynamic_encode_ns"] > 0
                and values["best_encode_ns"] > 0
                and 257 <= values["hlit"] <= 286
                and 1 <= values["hdist"] <= 30
                and 4 <= values["hclen"] <= 19
            ):
                positive_rows += 1
            if (
                values["token_count"] == values["literal_tokens"] + values["match_tokens"]
                and values["best_preset_token_count"] == values["best_preset_literal_tokens"] + values["best_preset_match_tokens"]
                and values["matched_bytes"] <= values["input_bytes"]
                and values["best_preset_matched_bytes"] <= values["input_bytes"]
                and values["short_match_tokens"] + values["far_match_tokens"] <= values["match_tokens"]
            ):
                token_accounting_rows += 1
            if all(histogram_ok(row, field, expected_len) for field, expected_len in histogram_fields.items()):
                histogram_rows += 1
            if (
                ratio_close(row, "fixed_dynamic_size_ratio", values["fixed_bytes"], values["dynamic_bytes"])
                and ratio_close(row, "best_dynamic_time_ratio", values["best_encode_ns"], values["dynamic_encode_ns"])
                and ratio_close(row, "stats_dynamic_time_ratio", values["stats_ns"], values["dynamic_encode_ns"])
                and ratio_close(row, "best_preset_default_size_ratio", values["best_preset_zlib_bytes"], values["best_zlib_bytes"])
                and ratio_close(row, "best_preset_default_token_ratio", values["best_preset_token_count"], values["token_count"])
            ):
                ratio_rows += 1
            if (
                0 <= values["dynamic_bits_mod8"] < 8
                and values["dynamic_bits_to_save_byte"] == values["dynamic_bits_mod8"]
                and 0 <= values["best_preset_bits_mod8"] < 8
                and values["best_preset_bits_to_save_byte"] == values["best_preset_bits_mod8"]
            ):
                slack_rows += 1
            if (
                values["dynamic_zlib_bytes"] == values["dynamic_bytes"] + 6
                and values["best_zlib_bytes"] > 0
                and values["best_preset_zlib_bytes"] > 0
            ):
                wrapper_rows += 1

    expected_path_pairs = {
        (source, path)
        for source, config in expected_sources.items()
        for path in config["paths"]
    }
    missing_sources = sorted(source for source in expected_sources if source not in present_sources)
    missing_paths = sorted(f"{source}:{path}" for source, path in expected_path_pairs - seen_paths)
    healthy = (
        len(present_sources) == len(expected_sources)
        and total_rows == expected_rows
        and not missing_sources
        and not missing_paths
        and malformed_rows == 0
        and positive_rows == total_rows
        and token_accounting_rows == total_rows
        and histogram_rows == total_rows
        and ratio_rows == total_rows
        and slack_rows == total_rows
        and wrapper_rows == total_rows
    )
    return {
        "present": len(present_sources) == len(expected_sources),
        "healthy": healthy,
        "source_count": len(present_sources),
        "expected_source_count": len(expected_sources),
        "rows": total_rows,
        "expected_rows": expected_rows,
        "positive_rows": positive_rows,
        "token_accounting_rows": token_accounting_rows,
        "histogram_rows": histogram_rows,
        "ratio_rows": ratio_rows,
        "slack_rows": slack_rows,
        "wrapper_rows": wrapper_rows,
        "malformed_rows": malformed_rows,
        "missing_sources": missing_sources,
        "missing_paths": missing_paths,
    }


def fuzz_corpus_health(artifacts: list[Path]) -> dict:
    report = None
    coverage = None
    markdown = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.fuzz_corpus_report" and artifact.name == "vort-deflate-wrapper-fuzz-corpus.json":
            report = data
        elif schema == "vort.fuzz_corpus_coverage_smoke" and artifact.name == "vort-fuzz-corpus-coverage-smoke.json":
            coverage = data
        elif artifact.name == "vort-deflate-wrapper-fuzz-corpus.md":
            markdown = artifact

    def as_int(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def row_int(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def markdown_cell(value: object) -> str:
        return str(value or "")

    def markdown_checks(report_data: dict | None) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        if not isinstance(report_data, dict):
            return (True, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        expected = [
            f"- mode: `{report_data.get('mode')}`",
            f"- cases: {as_int(report_data, 'cases')}",
            f"- accepted: {as_int(report_data, 'accepted')}",
            f"- rejected: {as_int(report_data, 'rejected')}",
            f"- exact error expectations: {as_int(report_data, 'exact_error_expectations')}",
            f"- matched rows: {as_int(report_data, 'matched_rows')}",
            "## Mode summary",
            "## Error summary",
            "## Samples",
        ]
        for row in mode_counts:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {mode} | {cases} | {accepted} | {rejected} | {exact} | {matched} |".format(
                    mode=markdown_cell(row.get("mode")),
                    cases=row_int(row, "cases"),
                    accepted=row_int(row, "accepted"),
                    rejected=row_int(row, "rejected"),
                    exact=row_int(row, "exact_error_expectations"),
                    matched=row_int(row, "matched_rows"),
                )
            )
        for row in error_counts:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {mode} | `{error}` | {count} |".format(
                    mode=markdown_cell(row.get("mode")),
                    error=markdown_cell(row.get("error")),
                    count=row_int(row, "count"),
                )
            )
        for row in items:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {index} | {mode} | {input_bytes} | {expected} | `{expected_error}` | {outcome} | `{actual_error}` | {matched} |".format(
                    index=row_int(row, "index"),
                    mode=markdown_cell(row.get("mode")),
                    input_bytes=row_int(row, "input_bytes"),
                    expected=markdown_cell(row.get("expected")),
                    expected_error=markdown_cell(row.get("expected_error")),
                    outcome=markdown_cell(row.get("outcome")),
                    actual_error=markdown_cell(row.get("actual_error")),
                    matched="true" if row.get("matched") is True else "false",
                )
            )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

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
    items = report.get("items") if isinstance(report, dict) else []
    items = items if isinstance(items, list) else []
    mode_counts = report.get("mode_counts") if isinstance(report, dict) else []
    mode_counts = mode_counts if isinstance(mode_counts, list) else []
    error_counts = report.get("error_counts") if isinstance(report, dict) else []
    error_counts = error_counts if isinstance(error_counts, list) else []
    report_rows = len(items)
    accepted_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("outcome") == "accepted")
    rejected_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("outcome") == "rejected")
    matched_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("matched") is True)
    exact_from_items = sum(1 for row in items if isinstance(row, dict) and str(row.get("expected_error") or "") != "")
    report_count_mismatch = (
        abs(cases - report_rows)
        + abs(as_int(report, "accepted") - accepted_from_items)
        + abs(as_int(report, "rejected") - rejected_from_items)
        + abs(matched_rows - matched_from_items)
        + abs(exact_error_expectations - exact_from_items)
        + abs(mode_count_rows - len(mode_counts))
        + abs(error_count_rows - len(error_counts))
    )
    mode_requirements = coverage.get("mode_requirements") if isinstance(coverage, dict) else []
    mode_requirements = mode_requirements if isinstance(mode_requirements, list) else []
    error_requirements = coverage.get("error_requirements") if isinstance(coverage, dict) else []
    error_requirements = error_requirements if isinstance(error_requirements, list) else []
    coverage_mode_matched = sum(1 for row in mode_requirements if isinstance(row, dict) and row.get("matched") is True)
    coverage_error_matched = sum(1 for row in error_requirements if isinstance(row, dict) and row.get("matched") is True)
    coverage_unmatched = (
        abs(coverage_mode_requirements - len(mode_requirements))
        + abs(coverage_error_requirements - len(error_requirements))
        + (len(mode_requirements) - coverage_mode_matched)
        + (len(error_requirements) - coverage_error_matched)
    )
    markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(report if report_present else None)
    report_healthy = (
        report_present
        and bool(report.get("ok"))
        and str(report.get("mode") or "") == "mixed"
        and cases > 0
        and report_count_mismatch == 0
        and matched_rows == cases
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
        and coverage_unmatched == 0
    )
    markdown_healthy = markdown_present and markdown_rows > 0 and markdown_unmatched == 0
    return {
        "present": report_present,
        "ok": bool(report.get("ok")) if report_present else False,
        "coverage_present": coverage_present,
        "coverage_ok": bool(coverage.get("ok")) if coverage_present else False,
        "markdown_present": markdown_present,
        "cases": cases,
        "accepted": as_int(report, "accepted"),
        "rejected": as_int(report, "rejected"),
        "report_rows": report_rows,
        "report_count_mismatch": report_count_mismatch,
        "matched_rows": matched_rows,
        "unmatched_rows": unmatched_rows,
        "exact_error_expectations": exact_error_expectations,
        "mode_count_rows": mode_count_rows,
        "error_count_rows": error_count_rows,
        "coverage_mode_requirements": coverage_mode_requirements,
        "coverage_error_requirements": coverage_error_requirements,
        "coverage_mode_matched": coverage_mode_matched,
        "coverage_error_matched": coverage_error_matched,
        "coverage_unmatched": coverage_unmatched,
        "markdown_rows": markdown_rows,
        "markdown_matched": markdown_matched,
        "markdown_unmatched": markdown_unmatched,
        "report_healthy": report_healthy,
        "coverage_healthy": coverage_healthy,
        "markdown_healthy": markdown_healthy,
        "healthy": report_healthy and coverage_healthy and markdown_healthy,
    }


def decode_stage_health(artifacts: list[Path]) -> dict:
    expected_cases = {"tiny", "repetitive", "overlap-rle", "distance-heavy", "text", "dynamic-literal-only", "dynamic-match", "binary", "stored-binary", "structured"}
    report = None
    markdown = None
    csv_rows: list[dict[str, str]] = []
    csv_present = False
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.deflate_decode_stage_report":
            report = data
        elif artifact.name == "vort-deflate-decode-stage-report.md":
            markdown = artifact
        elif artifact.name == "vort-deflate-decode-stage-report.csv":
            csv_present = True
            try:
                with artifact.open(newline="") as f:
                    csv_rows = list(csv.DictReader(f))
            except Exception:
                csv_rows = []

    def int_value(row: dict[str, str], key: str) -> int:
        return int(row.get(key) or "0")

    def float_value(row: dict[str, str], key: str) -> float:
        return float(row.get(key) or "0")

    def report_int(data: dict, key: str) -> int:
        value = data.get(key)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def item_int(row: dict, key: str) -> int:
        value = row.get(key)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def markdown_checks(data: dict | None) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        if not isinstance(data, dict):
            return (True, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        items = data.get("items") if isinstance(data.get("items"), list) else []
        error_items = data.get("error_items") if isinstance(data.get("error_items"), list) else []
        expected = [
            "# Deflate decode stage report",
            "| case | input bytes | raw bytes | block | header bits/bytes |",
            "## Error path smoke",
            "| case | wrapper | input bytes | expected error | actual error | matched |",
        ]
        for row in items:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {case} | {input_bytes} | {raw_bytes} | {block} | {header_bits}/{header_bytes} | {hlit}/{hdist}/{hclen} | {lit_nonzero}/{lit_zero}/{lit_max} | {dist_nonzero}/{dist_zero}/{dist_max} | {iterations} | {repeat} |".format(
                    case=str(row.get("case") or ""),
                    input_bytes=item_int(row, "input_bytes"),
                    raw_bytes=item_int(row, "raw_bytes"),
                    block=str(row.get("raw_block_type") or ""),
                    header_bits=item_int(row, "raw_header_bits"),
                    header_bytes=item_int(row, "raw_header_bytes"),
                    hlit=item_int(row, "dynamic_hlit"),
                    hdist=item_int(row, "dynamic_hdist"),
                    hclen=item_int(row, "dynamic_hclen"),
                    lit_nonzero=item_int(row, "dynamic_literal_nonzero"),
                    lit_zero=item_int(row, "dynamic_literal_zero"),
                    lit_max=item_int(row, "dynamic_literal_max_bits"),
                    dist_nonzero=item_int(row, "dynamic_distance_nonzero"),
                    dist_zero=item_int(row, "dynamic_distance_zero"),
                    dist_max=item_int(row, "dynamic_distance_max_bits"),
                    iterations=item_int(row, "iterations"),
                    repeat=item_int(row, "repeat"),
                )
            )
        for row in error_items:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {case} | {wrapper} | {input_bytes} | `{expected_error}` | `{actual_error}` | `{matched}` |".format(
                    case=str(row.get("case") or ""),
                    wrapper=str(row.get("wrapper") or ""),
                    input_bytes=item_int(row, "input_bytes"),
                    expected_error=str(row.get("expected_error") or ""),
                    actual_error=str(row.get("actual_error") or ""),
                    matched="true" if row.get("matched") is True else "false",
                )
            )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    csv_seen: set[str] = set()
    csv_duplicate_cases: set[str] = set()
    csv_unknown_cases: set[str] = set()
    csv_positive_rows = 0
    csv_header_rows = 0
    csv_dynamic_rows = 0
    csv_stored_rows = 0
    csv_fixed_rows = 0
    csv_positive_float_fields = [
        "raw_mib_s",
        "raw_exact_mib_s",
        "raw_into_mib_s",
        "zlib_mib_s",
        "zlib_exact_mib_s",
        "zlib_into_mib_s",
        "gzip_mib_s",
        "gzip_exact_mib_s",
        "gzip_into_mib_s",
        "adler32_mib_s",
        "crc32_mib_s",
    ]
    for row in csv_rows:
        case = str(row.get("case") or "")
        if case in expected_cases:
            if case in csv_seen:
                csv_duplicate_cases.add(case)
            csv_seen.add(case)
        elif case:
            csv_unknown_cases.add(case)
        try:
            input_bytes = int_value(row, "input_bytes")
            zlib_bytes = int_value(row, "zlib_bytes")
            gzip_bytes = int_value(row, "gzip_bytes")
            raw_bytes = int_value(row, "raw_bytes")
            raw_header_bits = int_value(row, "raw_header_bits")
            raw_header_bytes = int_value(row, "raw_header_bytes")
            iterations = int_value(row, "iterations")
            repeat = int_value(row, "repeat")
            mix = int_value(row, "mix")
            floats_positive = all(float_value(row, field) > 0.0 for field in csv_positive_float_fields)
        except ValueError:
            continue
        if all(value > 0 for value in (input_bytes, zlib_bytes, gzip_bytes, raw_bytes, raw_header_bits, raw_header_bytes, iterations, repeat, mix)) and floats_positive:
            csv_positive_rows += 1
        block_type = str(row.get("raw_block_type") or "")
        if block_type in {"fixed", "dynamic", "stored"}:
            if block_type == "dynamic":
                try:
                    if all(int_value(row, field) > 0 for field in ("dynamic_hlit", "dynamic_hdist", "dynamic_hclen", "dynamic_literal_nonzero", "dynamic_literal_max_bits")):
                        csv_header_rows += 1
                        csv_dynamic_rows += 1
                except ValueError:
                    pass
            else:
                if all((row.get(field) or "0") == "0" for field in ("dynamic_hlit", "dynamic_hdist", "dynamic_hclen", "dynamic_literal_nonzero", "dynamic_literal_max_bits")):
                    csv_header_rows += 1
                    if block_type == "fixed":
                        csv_fixed_rows += 1
                    if block_type == "stored":
                        csv_stored_rows += 1
    csv_missing_cases = sorted(expected_cases - csv_seen)
    csv_duplicate_case_names = sorted(csv_duplicate_cases)
    csv_unknown_case_names = sorted(csv_unknown_cases)
    csv_healthy = (
        csv_present
        and len(csv_rows) == len(expected_cases)
        and not csv_missing_cases
        and not csv_duplicate_case_names
        and not csv_unknown_case_names
        and csv_positive_rows == len(csv_rows)
        and csv_header_rows == len(csv_rows)
        and csv_dynamic_rows > 0
        and csv_fixed_rows > 0
        and csv_stored_rows > 0
    )

    if isinstance(report, dict):
        rows = report_int(report, "rows")
        error_rows = report_int(report, "error_rows")
        matched_error_rows = report_int(report, "matched_error_rows")
        unmatched_error_rows = report_int(report, "unmatched_error_rows")
        items = report.get("items") if isinstance(report.get("items"), list) else []
        error_items = report.get("error_items") if isinstance(report.get("error_items"), list) else []
        matched_from_items = sum(1 for row in error_items if isinstance(row, dict) and row.get("matched") is True)
        unmatched_from_items = sum(1 for row in error_items if isinstance(row, dict) and row.get("matched") is False)
        report_rows = len(items)
        error_item_rows = len(error_items)
        report_count_mismatch = (
            abs(rows - report_rows)
            + abs(error_rows - error_item_rows)
            + abs(matched_error_rows - matched_from_items)
            + abs(unmatched_error_rows - unmatched_from_items)
        )
        markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(report)
        report_healthy = bool(report.get("ok")) and rows > 0 and error_rows > 0 and report_count_mismatch == 0 and matched_error_rows == error_rows and unmatched_error_rows == 0
        markdown_healthy = markdown_present and markdown_rows > 0 and markdown_unmatched == 0
        return {
            "present": True,
            "ok": bool(report.get("ok")),
            "rows": rows,
            "error_rows": error_rows,
            "report_rows": report_rows,
            "error_item_rows": error_item_rows,
            "report_count_mismatch": report_count_mismatch,
            "matched_error_rows": matched_error_rows,
            "unmatched_error_rows": unmatched_error_rows,
            "csv_present": csv_present,
            "csv_rows": len(csv_rows),
            "csv_positive_rows": csv_positive_rows,
            "csv_header_rows": csv_header_rows,
            "csv_dynamic_rows": csv_dynamic_rows,
            "csv_fixed_rows": csv_fixed_rows,
            "csv_stored_rows": csv_stored_rows,
            "csv_missing_cases": csv_missing_cases,
            "csv_duplicate_cases": csv_duplicate_case_names,
            "csv_unknown_cases": csv_unknown_case_names,
            "markdown_present": markdown_present,
            "markdown_rows": markdown_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
            "healthy": report_healthy and csv_healthy and markdown_healthy,
        }
    return {
        "present": False,
        "ok": False,
        "rows": 0,
        "error_rows": 0,
        "report_rows": 0,
        "error_item_rows": 0,
        "report_count_mismatch": 0,
        "matched_error_rows": 0,
        "unmatched_error_rows": 0,
        "csv_present": csv_present,
        "csv_rows": len(csv_rows),
        "csv_positive_rows": csv_positive_rows,
        "csv_header_rows": csv_header_rows,
        "csv_dynamic_rows": csv_dynamic_rows,
        "csv_fixed_rows": csv_fixed_rows,
        "csv_stored_rows": csv_stored_rows,
        "csv_missing_cases": csv_missing_cases,
        "csv_duplicate_cases": csv_duplicate_case_names,
        "csv_unknown_cases": csv_unknown_case_names,
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
        "healthy": False,
    }


def native_tier_range_health(artifacts: list[Path]) -> dict:
    expected_sources = ("built_in", "project_files", "standard_corpus")
    source_order = (*expected_sources, "custom", "legacy")
    tiers = ("seek_fast", "balanced", "ratio")
    tier_block_len = {"seek_fast": 8 * 1024, "balanced": 32 * 1024, "ratio": 64 * 1024}
    csv_artifacts = {
        "built_in": "vort-native-tier-range-bench.csv",
        "project_files": "vort-native-tier-range-files-bench.csv",
        "standard_corpus": "vort-native-tier-range-corpus-bench.csv",
    }
    summaries = []
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.native_tier_range_bench_gate":
            summaries.append(data)

    def summary_fixture_names_for_source(source: str) -> list[str]:
        names: set[str] = set()
        for data in summaries:
            if data.get("source") != source:
                continue
            fixtures = data.get("fixtures")
            if isinstance(fixtures, list):
                names.update(str(item) for item in fixtures if str(item))
        return sorted(names)

    def csv_health(source: str, artifact_name: str) -> dict:
        for artifact in artifacts:
            if artifact.name != artifact_name:
                continue
            try:
                with artifact.open(newline="") as f:
                    rows = list(csv.DictReader(f))
            except Exception:
                rows = []
            positive_rows = 0
            shape_rows = 0
            throughput_rows = 0
            fixtures = {str(row.get("fixture") or "") for row in rows}
            fixture_names = sorted(fixtures - {""})
            expected_fixture_names = summary_fixture_names_for_source(source) or fixture_names
            expected_pairs = {(fixture, tier) for fixture in expected_fixture_names for tier in tiers}
            seen: set[tuple[str, str]] = set()
            duplicate_pairs: set[tuple[str, str]] = set()
            unknown_pairs: set[tuple[str, str]] = set()
            seen_tiers: set[str] = set()
            total_stream_bytes_by_tier = {tier: 0 for tier in tiers}
            total_index_entries_by_tier = {tier: 0 for tier in tiers}
            min_range_mib_s_by_tier = {tier: float("inf") for tier in tiers}
            min_full_input_mib_s_by_tier = {tier: float("inf") for tier in tiers}
            for row in rows:
                fixture = str(row.get("fixture") or "")
                tier = str(row.get("tier") or "")
                pair = (fixture, tier)
                if pair in expected_pairs:
                    if pair in seen:
                        duplicate_pairs.add(pair)
                    seen.add((fixture, tier))
                    seen_tiers.add(tier)
                elif fixture or tier:
                    unknown_pairs.add(pair)
                try:
                    block_len = int(row.get("block_len") or "0")
                    input_bytes = int(row.get("input_bytes") or "0")
                    stream_bytes = int(row.get("stream_bytes") or "0")
                    index_entries = int(row.get("index_entries") or "0")
                    range_offset = int(row.get("range_offset") or "-1")
                    range_len = int(row.get("range_len") or "0")
                    iterations = int(row.get("iterations") or "0")
                    repeat = int(row.get("repeat") or "0")
                    elapsed_ns = int(row.get("elapsed_ns") or "0")
                    checksum = int(row.get("checksum") or "0")
                    range_mib_s = float(row.get("range_mib_s") or "0")
                    full_input_mib_s = float(row.get("full_input_mib_s") or "0")
                except ValueError:
                    continue
                if tier in tiers:
                    total_stream_bytes_by_tier[tier] += stream_bytes
                    total_index_entries_by_tier[tier] += index_entries
                    if range_mib_s > 0.0:
                        min_range_mib_s_by_tier[tier] = min(min_range_mib_s_by_tier[tier], range_mib_s)
                    if full_input_mib_s > 0.0:
                        min_full_input_mib_s_by_tier[tier] = min(min_full_input_mib_s_by_tier[tier], full_input_mib_s)
                if all(value > 0 for value in (block_len, input_bytes, stream_bytes, index_entries, range_len, iterations, repeat, elapsed_ns, checksum)) and range_offset >= 0 and range_mib_s > 0.0 and full_input_mib_s > 0.0:
                    positive_rows += 1
                if tier in tier_block_len and block_len == tier_block_len[tier] and index_entries >= (input_bytes + block_len - 1) // block_len and range_offset + range_len <= input_bytes:
                    shape_rows += 1
                expected_range = ((range_len * iterations) / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
                expected_full = ((input_bytes * iterations) / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
                if abs(range_mib_s - expected_range) <= 0.0001 and abs(full_input_mib_s - expected_full) <= 0.0001:
                    throughput_rows += 1
            missing_pairs = sorted(f"{fixture}:{tier}" for fixture, tier in expected_pairs - seen)
            duplicate_pair_names = sorted(f"{fixture}:{tier}" for fixture, tier in duplicate_pairs)
            unknown_pair_names = sorted(f"{fixture}:{tier}" for fixture, tier in unknown_pairs)
            healthy = (
                bool(rows)
                and len(seen) == len(expected_pairs)
                and not missing_pairs
                and not duplicate_pair_names
                and not unknown_pair_names
                and positive_rows == len(rows)
                and shape_rows == len(rows)
                and throughput_rows == len(rows)
            )
            for by_tier in (min_range_mib_s_by_tier, min_full_input_mib_s_by_tier):
                for tier in tiers:
                    if by_tier[tier] == float("inf"):
                        by_tier[tier] = 0.0
            return {
                "present": True,
                "healthy": healthy,
                "rows": len(rows),
                "fixtures": len(fixture_names),
                "fixture_names": fixture_names,
                "tier_count": len(seen_tiers),
                "tiers": sorted(seen_tiers),
                "positive_rows": positive_rows,
                "shape_rows": shape_rows,
                "throughput_rows": throughput_rows,
                "missing_pairs": missing_pairs,
                "duplicate_pairs": duplicate_pair_names,
                "unknown_pairs": unknown_pair_names,
                "total_stream_bytes_by_tier": total_stream_bytes_by_tier,
                "total_index_entries_by_tier": total_index_entries_by_tier,
                "min_range_mib_s_by_tier": min_range_mib_s_by_tier,
                "min_full_input_mib_s_by_tier": min_full_input_mib_s_by_tier,
            }
        return {
            "present": False,
            "healthy": False,
            "rows": 0,
            "fixtures": 0,
            "fixture_names": [],
            "tier_count": 0,
            "tiers": [],
            "positive_rows": 0,
            "shape_rows": 0,
            "throughput_rows": 0,
            "missing_pairs": [],
            "duplicate_pairs": [],
            "unknown_pairs": [],
            "total_stream_bytes_by_tier": {tier: 0 for tier in tiers},
            "total_index_entries_by_tier": {tier: 0 for tier in tiers},
            "min_range_mib_s_by_tier": {tier: 0.0 for tier in tiers},
            "min_full_input_mib_s_by_tier": {tier: 0.0 for tier in tiers},
        }

    csv_summaries = {source: csv_health(source, artifact_name) for source, artifact_name in csv_artifacts.items()}
    csv_present_count = sum(1 for item in csv_summaries.values() if item["present"])
    csv_healthy_count = sum(1 for item in csv_summaries.values() if item["healthy"])
    csv_rows = sum(int(item["rows"]) for item in csv_summaries.values())
    csv_positive_rows = sum(int(item["positive_rows"]) for item in csv_summaries.values())
    csv_shape_rows = sum(int(item["shape_rows"]) for item in csv_summaries.values())
    csv_throughput_rows = sum(int(item["throughput_rows"]) for item in csv_summaries.values())
    csv_missing_sources = [source for source, item in csv_summaries.items() if not item["present"]]
    csv_missing_pairs = [f"{source}:{pair}" for source, item in csv_summaries.items() for pair in item["missing_pairs"]]
    csv_duplicate_pairs = [f"{source}:{pair}" for source, item in csv_summaries.items() for pair in item["duplicate_pairs"]]
    csv_unknown_pairs = [f"{source}:{pair}" for source, item in csv_summaries.items() for pair in item["unknown_pairs"]]
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
    summary_csv_row_mismatch = 0
    summary_csv_fixture_mismatch = 0
    summary_csv_tier_mismatch = 0
    summary_csv_path_mismatch = 0
    summary_csv_stream_bytes_mismatch = 0
    summary_csv_index_entries_mismatch = 0
    summary_csv_min_range_mismatch = 0
    summary_csv_min_full_mismatch = 0
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

    def int_by_tier(data: dict, field: str, tier: str) -> int:
        value = data.get(field)
        if not isinstance(value, dict):
            return 0
        item = value.get(tier)
        return item if isinstance(item, int) and not isinstance(item, bool) else 0

    def float_by_tier(data: dict, field: str, tier: str) -> float:
        value = data.get(field)
        if not isinstance(value, dict):
            return 0.0
        item = value.get(tier)
        return float(item) if isinstance(item, (int, float)) and not isinstance(item, bool) else 0.0

    def close_float(left: float, right: float, tolerance: float = 0.0001) -> bool:
        return abs(left - right) <= tolerance

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
        if source in csv_summaries:
            # The JSON gate summary is the compact CI signal, but the CSV is
            # the row-level evidence humans inspect. Keep the two tied together
            # so a stale summary cannot make native tier coverage look healthy
            # after a benchmark matrix or throughput calculation changes.
            csv_summary = csv_summaries[source]
            if rows != int(csv_summary["rows"]):
                summary_csv_row_mismatch += 1
            summary_fixtures = data.get("fixtures") if isinstance(data.get("fixtures"), list) else []
            summary_fixture_names = sorted(str(item) for item in summary_fixtures)
            if int(data.get("fixture_count") or 0) != int(csv_summary["fixtures"]) or summary_fixture_names != csv_summary["fixture_names"]:
                summary_csv_fixture_mismatch += 1
            summary_tiers = data.get("tiers") if isinstance(data.get("tiers"), list) else []
            summary_tier_names = sorted(str(item) for item in summary_tiers)
            if int(data.get("tier_count") or 0) != int(csv_summary["tier_count"]) or summary_tier_names != csv_summary["tiers"]:
                summary_csv_tier_mismatch += 1
            if Path(str(data.get("csv") or "")).name != csv_artifacts[source]:
                summary_csv_path_mismatch += 1
            for tier in tiers:
                if int_by_tier(data, "total_stream_bytes_by_tier", tier) != csv_summary["total_stream_bytes_by_tier"][tier]:
                    summary_csv_stream_bytes_mismatch += 1
                if int_by_tier(data, "total_index_entries_by_tier", tier) != csv_summary["total_index_entries_by_tier"][tier]:
                    summary_csv_index_entries_mismatch += 1
                if not close_float(float_by_tier(data, "min_range_mib_s_by_tier", tier), csv_summary["min_range_mib_s_by_tier"][tier]):
                    summary_csv_min_range_mismatch += 1
                if not close_float(float_by_tier(data, "min_full_input_mib_s_by_tier", tier), csv_summary["min_full_input_mib_s_by_tier"][tier]):
                    summary_csv_min_full_mismatch += 1
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
    source_count_mismatch = sum(abs(source_counts[source] - 1) for source in expected_sources) + source_counts["custom"] + legacy_count
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

    csv_healthy = (
        csv_present_count == len(csv_artifacts)
        and csv_healthy_count == len(csv_artifacts)
        and csv_rows > 0
        and not csv_missing_sources
        and not csv_missing_pairs
        and not csv_duplicate_pairs
        and not csv_unknown_pairs
    )
    summary_csv_mismatch_total = (
        summary_csv_row_mismatch
        + summary_csv_fixture_mismatch
        + summary_csv_tier_mismatch
        + summary_csv_path_mismatch
        + summary_csv_stream_bytes_mismatch
        + summary_csv_index_entries_mismatch
        + summary_csv_min_range_mismatch
        + summary_csv_min_full_mismatch
    )
    healthy = (
        present
        and ok_count == len(summaries)
        and row_count > 0
        and fixture_count > 0
        and not missing_sources
        and legacy_count == 0
        and source_count_mismatch == 0
        and summary_csv_mismatch_total == 0
        and csv_healthy
    )
    return {
        "present": present,
        "healthy": healthy,
        "summary_count": len(summaries),
        "ok_count": ok_count,
        "rows": row_count,
        "fixture_count": fixture_count,
        "enforced_count": enforced_count,
        "csv_present_count": csv_present_count,
        "csv_healthy_count": csv_healthy_count,
        "csv_rows": csv_rows,
        "csv_positive_rows": csv_positive_rows,
        "csv_shape_rows": csv_shape_rows,
        "csv_throughput_rows": csv_throughput_rows,
        "csv_missing_sources": csv_missing_sources,
        "csv_missing_pairs": csv_missing_pairs,
        "csv_duplicate_pairs": csv_duplicate_pairs,
        "csv_unknown_pairs": csv_unknown_pairs,
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
        "source_count_mismatch": source_count_mismatch,
        "summary_csv_row_mismatch": summary_csv_row_mismatch,
        "summary_csv_fixture_mismatch": summary_csv_fixture_mismatch,
        "summary_csv_tier_mismatch": summary_csv_tier_mismatch,
        "summary_csv_path_mismatch": summary_csv_path_mismatch,
        "summary_csv_stream_bytes_mismatch": summary_csv_stream_bytes_mismatch,
        "summary_csv_index_entries_mismatch": summary_csv_index_entries_mismatch,
        "summary_csv_min_range_mismatch": summary_csv_min_range_mismatch,
        "summary_csv_min_full_mismatch": summary_csv_min_full_mismatch,
        "summary_csv_mismatch_total": summary_csv_mismatch_total,
        "source_details": [source_details[source] for source in source_order],
        "seek_fast_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "seek_fast"),
        "balanced_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "balanced"),
        "ratio_min_range_mib_s": tier_min("min_range_mib_s_by_tier", "ratio"),
        "seek_fast_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "seek_fast"),
        "balanced_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "balanced"),
        "ratio_min_full_input_mib_s": tier_min("min_full_input_mib_s_by_tier", "ratio"),
    }


def native_tier_corpus_discovery_health(artifacts: list[Path]) -> dict:
    expected_csv_artifact = "vort-native-tier-range-corpus-bench.csv"
    discovery = None
    corpus_summary = None
    corpus_csv = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_tier_range_corpus_discovery":
            if data.get("schema") == "vort.native_tier_range_bench_gate" and data.get("source") == "standard_corpus":
                corpus_summary = data
            if artifact.name == expected_csv_artifact:
                corpus_csv = artifact
            continue
        discovery = data
    if discovery is not None:
        def int_field(name: str) -> int:
            value = discovery.get(name)
            return value if isinstance(value, int) and not isinstance(value, bool) else 0

        def csv_fixture_bytes(path: Path | None) -> dict[str, int] | None:
            if path is None:
                return None
            try:
                with path.open(newline="") as f:
                    rows = list(csv.DictReader(f))
            except Exception:
                return {}
            by_fixture: dict[str, int] = {}
            for row in rows:
                fixture = str(row.get("fixture") or "")
                if not fixture:
                    continue
                try:
                    input_bytes = int(row.get("input_bytes") or "0")
                except ValueError:
                    input_bytes = 0
                if fixture not in by_fixture:
                    by_fixture[fixture] = input_bytes
                elif by_fixture[fixture] != input_bytes:
                    by_fixture[fixture] = -1
            return by_fixture

        selected_cases = discovery.get("selected_cases")
        selected_cases = selected_cases if isinstance(selected_cases, list) else []
        sources = discovery.get("sources")
        sources = sources if isinstance(sources, list) else []
        missing_reason = discovery.get("missing_reason")
        limit = discovery.get("limit")
        limit = limit if isinstance(limit, int) and not isinstance(limit, bool) else None
        candidate_count = int_field("candidate_count")
        source_count = int_field("source_count")
        selected_case_count = int_field("selected_case_count")
        csv_path = str(discovery.get("csv") or "")
        missing_reason_text = str(missing_reason) if isinstance(missing_reason, str) else ""
        selected_labels: list[str] = []
        selected_bytes: dict[str, int] = {}
        selected_case_mismatch = 0
        for case in selected_cases:
            if not isinstance(case, dict):
                selected_case_mismatch += 1
                continue
            label = str(case.get("label") or "")
            byte_value = case.get("bytes")
            if not label or not isinstance(byte_value, int) or isinstance(byte_value, bool) or byte_value <= 0:
                selected_case_mismatch += 1
                continue
            if label in selected_bytes:
                selected_case_mismatch += 1
            selected_labels.append(label)
            selected_bytes[label] = byte_value
        selected_label_set = sorted(set(selected_labels))
        csv_path_mismatch = 1 if csv_path and Path(csv_path).name != expected_csv_artifact else 0
        summary_fixture_mismatch = 0
        if isinstance(corpus_summary, dict):
            summary_fixtures = corpus_summary.get("fixtures") if isinstance(corpus_summary.get("fixtures"), list) else []
            summary_fixture_names = sorted(str(item) for item in summary_fixtures)
            if int(corpus_summary.get("fixture_count") or 0) != selected_case_count or summary_fixture_names != selected_label_set:
                summary_fixture_mismatch = 1
        csv_fixture_mismatch = 0
        csv_byte_mismatch = 0
        csv_bytes = csv_fixture_bytes(corpus_csv)
        if csv_bytes is not None:
            csv_fixture_names = sorted(csv_bytes)
            if selected_case_count != len(csv_fixture_names) or selected_label_set != csv_fixture_names:
                csv_fixture_mismatch = 1
            for label, byte_value in selected_bytes.items():
                if csv_bytes.get(label) != byte_value:
                    csv_byte_mismatch += 1
            csv_byte_mismatch += sum(1 for value in csv_bytes.values() if value <= 0)
        mismatch_total = selected_case_mismatch + csv_path_mismatch + summary_fixture_mismatch + csv_fixture_mismatch + csv_byte_mismatch
        healthy = (
            bool(discovery.get("ok"))
            and str(discovery.get("source_mode") or "") in {"discovered", "paths"}
            and candidate_count >= source_count
            and source_count > 0
            and source_count == len(sources)
            and selected_case_count > 0
            and selected_case_count == len(selected_cases)
            and bool(csv_path)
            and isinstance(missing_reason, str)
            and missing_reason_text == ""
            and mismatch_total == 0
        )
        return {
            "present": True,
            "ok": bool(discovery.get("ok")),
            "source_mode": str(discovery.get("source_mode") or ""),
            "full": bool(discovery.get("full")),
            "limit": limit,
            "candidate_count": candidate_count,
            "source_count": source_count,
            "selected_case_count": selected_case_count,
            "sources": [str(source) for source in sources],
            "selected_cases": selected_cases,
            "csv": csv_path,
            "missing_reason": missing_reason_text,
            "selected_case_mismatch": selected_case_mismatch,
            "csv_path_mismatch": csv_path_mismatch,
            "summary_fixture_mismatch": summary_fixture_mismatch,
            "csv_fixture_mismatch": csv_fixture_mismatch,
            "csv_byte_mismatch": csv_byte_mismatch,
            "mismatch_total": mismatch_total,
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
        "selected_case_mismatch": 0,
        "csv_path_mismatch": 0,
        "summary_fixture_mismatch": 0,
        "csv_fixture_mismatch": 0,
        "csv_byte_mismatch": 0,
        "mismatch_total": 0,
        "healthy": False,
    }


def native_fuzz_corpus_health(artifacts: list[Path]) -> dict:
    report = None
    coverage = None
    markdown = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.fuzz_corpus_report" and artifact.name == "vort-native-fuzz-corpus.json":
            report = data
        elif data.get("schema") == "vort.fuzz_corpus_coverage_smoke" and artifact.name == "vort-native-fuzz-corpus-coverage-smoke.json":
            coverage = data
        elif artifact.name == "vort-native-fuzz-corpus.md":
            markdown = artifact

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def row_int(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def expected_label(value: object) -> str:
        return str(value or "any")

    def markdown_cell(value: object) -> str:
        return str(value or "")

    def markdown_checks(report_data: dict | None) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        if not isinstance(report_data, dict):
            return (True, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        expected = [
            f"- mode: `{report_data.get('mode')}`",
            f"- cases: {int_field(report_data, 'cases')}",
            f"- accepted: {int_field(report_data, 'accepted')}",
            f"- rejected: {int_field(report_data, 'rejected')}",
            f"- exact error expectations: {int_field(report_data, 'exact_error_expectations')}",
            f"- matched rows: {int_field(report_data, 'matched_rows')}",
            "## Mode summary",
            "## Error summary",
            "## Samples",
        ]
        for row in mode_counts:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {mode} | {cases} | {accepted} | {rejected} | {exact} | {matched} |".format(
                    mode=markdown_cell(row.get("mode")),
                    cases=row_int(row, "cases"),
                    accepted=row_int(row, "accepted"),
                    rejected=row_int(row, "rejected"),
                    exact=row_int(row, "exact_error_expectations"),
                    matched=row_int(row, "matched_rows"),
                )
            )
        for row in error_counts:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {mode} | `{error}` | {count} |".format(
                    mode=markdown_cell(row.get("mode")),
                    error=markdown_cell(row.get("error")),
                    count=row_int(row, "count"),
                )
            )
        for row in items:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {index} | {mode} | {input_bytes} | {expected} | `{expected_error}` | {outcome} | `{actual_error}` | {matched} |".format(
                    index=row_int(row, "index"),
                    mode=markdown_cell(row.get("mode")),
                    input_bytes=row_int(row, "input_bytes"),
                    expected=expected_label(row.get("expected")),
                    expected_error=markdown_cell(row.get("expected_error")),
                    outcome=markdown_cell(row.get("outcome")),
                    actual_error=markdown_cell(row.get("actual_error")),
                    matched="true" if row.get("matched") is True else "false",
                )
            )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

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
    items = report.get("items") if isinstance(report, dict) else []
    items = items if isinstance(items, list) else []
    mode_counts = report.get("mode_counts") if isinstance(report, dict) else []
    mode_counts = mode_counts if isinstance(mode_counts, list) else []
    error_counts = report.get("error_counts") if isinstance(report, dict) else []
    error_counts = error_counts if isinstance(error_counts, list) else []
    report_rows = len(items)
    accepted_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("outcome") == "accepted")
    rejected_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("outcome") == "rejected")
    matched_from_items = sum(1 for row in items if isinstance(row, dict) and row.get("matched") is True)
    exact_from_items = sum(1 for row in items if isinstance(row, dict) and str(row.get("expected_error") or "") != "")
    report_count_mismatch = (
        abs(cases - report_rows)
        + abs(int_field(report, "accepted") - accepted_from_items)
        + abs(int_field(report, "rejected") - rejected_from_items)
        + abs(matched_rows - matched_from_items)
        + abs(exact_error_expectations - exact_from_items)
        + abs(mode_count_rows - len(mode_counts))
        + abs(error_count_rows - len(error_counts))
    )
    mode_requirements = coverage.get("mode_requirements") if isinstance(coverage, dict) else []
    mode_requirements = mode_requirements if isinstance(mode_requirements, list) else []
    error_requirements = coverage.get("error_requirements") if isinstance(coverage, dict) else []
    error_requirements = error_requirements if isinstance(error_requirements, list) else []
    coverage_mode_matched = sum(1 for row in mode_requirements if isinstance(row, dict) and row.get("matched") is True)
    coverage_error_matched = sum(1 for row in error_requirements if isinstance(row, dict) and row.get("matched") is True)
    coverage_unmatched = (
        abs(coverage_mode_requirements - len(mode_requirements))
        + abs(coverage_error_requirements - len(error_requirements))
        + (len(mode_requirements) - coverage_mode_matched)
        + (len(error_requirements) - coverage_error_matched)
    )
    markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(report if report_present else None)
    report_healthy = (
        report_present
        and bool(report.get("ok"))
        and str(report.get("mode") or "") == "native"
        and cases > 0
        and report_count_mismatch == 0
        and matched_rows == cases
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
        and coverage_unmatched == 0
    )
    markdown_healthy = markdown_present and markdown_rows > 0 and markdown_unmatched == 0
    healthy = report_healthy and coverage_healthy and markdown_healthy
    return {
        "present": report_present,
        "coverage_present": coverage_present,
        "markdown_present": markdown_present,
        "report_healthy": report_healthy,
        "coverage_healthy": coverage_healthy,
        "markdown_healthy": markdown_healthy,
        "healthy": healthy,
        "cases": cases,
        "accepted": int_field(report, "accepted"),
        "rejected": int_field(report, "rejected"),
        "report_rows": report_rows,
        "report_count_mismatch": report_count_mismatch,
        "matched_rows": matched_rows,
        "unmatched_rows": unmatched_rows,
        "exact_error_expectations": exact_error_expectations,
        "mode_count_rows": mode_count_rows,
        "error_count_rows": error_count_rows,
        "coverage_mode_requirements": coverage_mode_requirements,
        "coverage_error_requirements": coverage_error_requirements,
        "coverage_mode_matched": coverage_mode_matched,
        "coverage_error_matched": coverage_error_matched,
        "coverage_unmatched": coverage_unmatched,
        "markdown_rows": markdown_rows,
        "markdown_matched": markdown_matched,
        "markdown_unmatched": markdown_unmatched,
    }


def br_static_dictionary_health(artifacts: list[Path]) -> dict:
    # Multiple exploratory Brotli static-dictionary probes intentionally share
    # the same schemas as the canonical smoke artifacts. Keep this aggregate
    # health gate pinned to the stable CI artifact names so stale wide-probe
    # outputs in zig-out cannot make the dashboard look healthier or less
    # healthy than the retained validation set.
    candidate = None
    candidate_markdown = None
    upstream = None
    upstream_report = None
    upstream_markdown = None
    node = None
    node_markdown = None
    audit = None
    negative = None
    report = None
    report_csv = None
    report_markdown = None
    report_negative = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.br_static_dictionary_candidate_report" and artifact.name == "vort-br-static-dictionary-candidates.json":
            candidate = data
        elif artifact.name == "vort-br-static-dictionary-candidates.md":
            candidate_markdown = artifact
        elif schema == "vort.br_static_dictionary_candidate_upstream_smoke" and artifact.name == "vort-br-static-dictionary-candidate-upstream-smoke.json":
            upstream = data
        elif schema == "vort.br_static_dictionary_candidate_report" and artifact.name == "vort-br-static-dictionary-candidates-upstream.json":
            upstream_report = data
        elif artifact.name == "vort-br-static-dictionary-candidates-upstream.md":
            upstream_markdown = artifact
        elif schema == "vort.br_static_dictionary_node_probe" and artifact.name == "vort-br-static-dictionary-node-probe.json":
            node = data
        elif artifact.name == "vort-br-static-dictionary-node-probe.md":
            node_markdown = artifact
        elif schema == "vort.br_static_dictionary_source_audit" and artifact.name == "vort-br-static-dictionary-source-audit.json":
            audit = data
        elif schema == "vort.br_static_dictionary_source_audit_negative_smoke" and artifact.name == "vort-br-static-dictionary-source-audit-negative-smoke.json":
            negative = data
        elif schema == "vort.br_static_dictionary_report" and artifact.name == "vort-br-static-dictionary-report.json":
            report = data
        elif schema == "vort.br_static_dictionary_report_negative_smoke" and artifact.name == "vort-br-static-dictionary-report-negative-smoke.json":
            report_negative = data
        elif artifact.name == "vort-br-static-dictionary-report.csv":
            report_csv = artifact
        elif artifact.name == "vort-br-static-dictionary-report.md":
            report_markdown = artifact

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def entry_key(row: dict) -> tuple[int, int, int, str] | None:
        transform = row.get("transform")
        copy_len = row.get("copy_len")
        word_index = row.get("word_index")
        word = row.get("word")
        word_bytes = row.get("word_bytes")
        if (
            not isinstance(transform, int)
            or isinstance(transform, bool)
            or not isinstance(copy_len, int)
            or isinstance(copy_len, bool)
            or not isinstance(word_index, int)
            or isinstance(word_index, bool)
            or not isinstance(word, str)
            or not isinstance(word_bytes, int)
            or isinstance(word_bytes, bool)
            or word_bytes != len(word.encode())
        ):
            return None
        return (transform, copy_len, word_index, word)

    report_entries = report.get("entries") if isinstance(report, dict) else []
    report_entries = report_entries if isinstance(report_entries, list) else []
    report_entry_keys = {key for row in report_entries if isinstance(row, dict) for key in [entry_key(row)] if key is not None}
    report_json_entries = len(report_entries)
    report_entry_count = int_field(report, "entry_count")
    report_transform_count = int_field(report, "transform_count")
    report_length_count = int_field(report, "length_count")
    report_category_counts = report.get("category_counts") if isinstance(report, dict) else {}
    report_category_counts = report_category_counts if isinstance(report_category_counts, dict) else {}

    def dict_int(data: dict, field: str) -> int:
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def markdown_escape(value: object) -> str:
        # The report writer wraps words in backticks, so escape the only
        # characters that can make a generated cell ambiguous before comparing
        # JSON-derived snippets against the retained Markdown companion.
        return str(value).replace("`", "\\`").replace("\n", " ")

    def report_markdown_code_escape(value: str) -> str:
        # Mirror tools/br_static_dictionary_report.zig's writeMarkdownCode().
        # The Brotli word table includes punctuation and CRLF-containing words;
        # using the exact byte-oriented spelling here makes the dashboard health
        # sensitive to drift in every retained Markdown entry row, not just to
        # the six summary bullets.
        parts: list[str] = []
        for char in value:
            byte = ord(char)
            if char in ("`", "\\", "|"):
                parts.append("\\" + char)
            elif char == "\n":
                parts.append("\\n")
            elif char == "\r":
                parts.append("\\r")
            elif char == "\t":
                parts.append("\\t")
            elif byte <= 0x08 or byte in (0x0B, 0x0C) or 0x0E <= byte <= 0x1F or byte == 0x7F:
                parts.append(f"\\x{byte:02x}")
            else:
                parts.append(char)
        return "".join(parts)

    def candidate_markdown_health(data: dict | None, markdown_path: Path | None) -> dict[str, int | bool]:
        if not isinstance(data, dict):
            return {"present": False, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 0, "sample_rows": 0, "sample_matched": 0, "sample_unmatched": 0}
        if markdown_path is None:
            return {"present": False, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 1, "sample_rows": 0, "sample_matched": 0, "sample_unmatched": 0}
        try:
            markdown = markdown_path.read_text(errors="replace")
        except Exception:
            return {"present": True, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 1, "sample_rows": 0, "sample_matched": 0, "sample_unmatched": 0}
        markdown_lines = {line.rstrip() for line in markdown.splitlines()}
        summary_expected = [
            f"- Source mode: {data.get('source_mode')}",
            f"- Source limit: {int_field(data, 'source_limit')}",
            f"- Source entries: {int_field(data, 'source_entry_count')}",
            f"- Anchor raw words: {int_field(data, 'anchor_raw_word_count')}",
            f"- Upstream raw words: {int_field(data, 'upstream_raw_word_count')}",
            f"- Unique raw words: {int_field(data, 'raw_word_count')}",
            f"- Supported transforms considered: {int_field(data, 'transform_count')}",
            f"- Candidate entries: {int_field(data, 'candidate_count')}",
        ]
        for row in data.get("kind_rows", []) if isinstance(data.get("kind_rows"), list) else []:
            if isinstance(row, dict):
                summary_expected.append(f"| `{row.get('transform_kind')}` | {dict_int(row, 'candidate_count')} |")
        for row in data.get("length_rows", []) if isinstance(data.get("length_rows"), list) else []:
            if isinstance(row, dict):
                summary_expected.append(f"| {dict_int(row, 'copy_len')} | {dict_int(row, 'candidate_count')} |")
        summary_matched = sum(1 for line in summary_expected if line in markdown_lines)
        candidates = data.get("candidates") if isinstance(data.get("candidates"), list) else []
        sample_expected: list[str] = []
        for row in candidates[:80]:
            if isinstance(row, dict):
                transform = dict_int(row, "transform")
                copy_len = dict_int(row, "copy_len")
                word_index = dict_int(row, "word_index")
                sample_expected.append(
                    f"| {transform} | {copy_len} | {word_index} | `{markdown_escape(row.get('transform_kind', ''))}` | `{markdown_escape(row.get('raw_word', ''))}` | `{markdown_escape(row.get('transformed_word', ''))}` |"
                )
        sample_matched = sum(1 for line in sample_expected if line in markdown_lines)
        return {
            "present": True,
            "summary_rows": len(summary_expected),
            "summary_matched": summary_matched,
            "summary_unmatched": len(summary_expected) - summary_matched,
            "sample_rows": len(sample_expected),
            "sample_matched": sample_matched,
            "sample_unmatched": len(sample_expected) - sample_matched,
        }

    def node_markdown_health(data: dict | None, markdown_path: Path | None) -> dict[str, int | bool]:
        if not isinstance(data, dict):
            return {"present": False, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 0, "row_count": 0, "row_matched": 0, "row_unmatched": 0}
        if markdown_path is None:
            return {"present": False, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 1, "row_count": 0, "row_matched": 0, "row_unmatched": 0}
        try:
            markdown = markdown_path.read_text(errors="replace")
        except Exception:
            return {"present": True, "summary_rows": 0, "summary_matched": 0, "summary_unmatched": 1, "row_count": 0, "row_matched": 0, "row_unmatched": 0}
        markdown_lines = {line.rstrip() for line in markdown.splitlines()}
        summary_expected = [
            f"- Candidate entries: {int_field(data, 'candidate_count')}",
            f"- Candidate source mode: {data.get('candidate_source_mode')}",
            f"- Candidate source limit: {int_field(data, 'candidate_source_limit')}",
            f"- Candidate raw words: {int_field(data, 'candidate_raw_word_count')}",
            f"- Probe start index: {int_field(data, 'start_index')}",
            f"- Probe limit: {int_field(data, 'limit')}",
            f"- Probed entries: {int_field(data, 'probed_count')}",
            f"- Node decode successes: {int_field(data, 'node_decode_successes')}",
            f"- Vort decode successes: {int_field(data, 'vort_decode_successes')}",
            f"- Vort decode failures: {int_field(data, 'vort_decode_failures')}",
            f"- Size winners: {int_field(data, 'size_winner_count')}",
        ]
        for row in data.get("kind_rows", []) if isinstance(data.get("kind_rows"), list) else []:
            if isinstance(row, dict):
                summary_expected.append(
                    f"| `{row.get('transform_kind')}` | {dict_int(row, 'probed_count')} | {dict_int(row, 'node_decode_successes')} | {dict_int(row, 'vort_decode_successes')} | {dict_int(row, 'vort_decode_failures')} |"
                )
        for row in data.get("size_rows", []) if isinstance(data.get("size_rows"), list) else []:
            if isinstance(row, dict):
                summary_expected.append(f"| `{row.get('size_class')}` | {dict_int(row, 'probed_count')} |")
        summary_matched = sum(1 for line in summary_expected if line in markdown_lines)
        rows = data.get("rows") if isinstance(data.get("rows"), list) else []
        row_expected: list[str] = []
        for row in rows:
            if isinstance(row, dict):
                error = markdown_escape(row.get("error", ""))
                row_expected.append(
                    f"| {dict_int(row, 'index')} | {dict_int(row, 'transform')} | {dict_int(row, 'copy_len')} | {dict_int(row, 'word_index')} | `{markdown_escape(row.get('candidate_word', ''))}` | {dict_int(row, 'payload_bytes')} | {dict_int(row, 'br_bytes')} | `{markdown_escape(row.get('size_class', ''))}` | `{markdown_escape(row.get('classification', ''))}` | `{error}` |"
                )
        row_matched = sum(1 for line in row_expected if line in markdown_lines)
        return {
            "present": True,
            "summary_rows": len(summary_expected),
            "summary_matched": summary_matched,
            "summary_unmatched": len(summary_expected) - summary_matched,
            "row_count": len(row_expected),
            "row_matched": row_matched,
            "row_unmatched": len(row_expected) - row_matched,
        }

    report_identity_count = sum(1 for transform, _, _, word in report_entry_keys if transform == 0 and " " not in word)
    report_transform_entry_count = sum(1 for transform, _, _, word in report_entry_keys if transform != 0 and " " not in word)
    report_phrase_count = sum(1 for _, _, _, word in report_entry_keys if " " in word)
    report_category_total = sum(
        value for value in report_category_counts.values()
        if isinstance(value, int) and not isinstance(value, bool)
    )
    report_category_mismatch_rows = sum(
        1
        for key, actual in (
            ("identity", report_identity_count),
            ("transform", report_transform_entry_count),
            ("phrase", report_phrase_count),
        )
        if report_category_counts.get(key) != actual
    )
    report_actual_transform_count = len({transform for transform, _, _, _ in report_entry_keys})
    report_actual_length_count = len({copy_len for _, copy_len, _, _ in report_entry_keys})
    report_matrix_rows_data = report.get("matrix_rows") if isinstance(report, dict) else []
    report_matrix_rows_data = report_matrix_rows_data if isinstance(report_matrix_rows_data, list) else []
    report_matrix_total = 0
    report_matrix_mismatch_rows = 0
    for row in report_matrix_rows_data:
        if not isinstance(row, dict):
            report_matrix_mismatch_rows += 1
            continue
        identity = row.get("identity")
        transform_entries = row.get("transform_entries")
        phrase = row.get("phrase")
        total = row.get("total")
        if all(isinstance(value, int) and not isinstance(value, bool) for value in (identity, transform_entries, phrase, total)):
            assert isinstance(identity, int)
            assert isinstance(transform_entries, int)
            assert isinstance(phrase, int)
            assert isinstance(total, int)
            report_matrix_total += total
            if identity + transform_entries + phrase != total:
                report_matrix_mismatch_rows += 1
        else:
            report_matrix_mismatch_rows += 1

    report_csv_rows = 0
    report_csv_matched = 0
    if isinstance(report_csv, Path):
        try:
            with report_csv.open(newline="") as f:
                csv_rows = list(csv.DictReader(f))
        except Exception:
            csv_rows = []
        report_csv_rows = len(csv_rows)
        csv_keys: set[tuple[int, int, int, str]] = set()
        for row in csv_rows:
            try:
                csv_keys.add((int(row.get("transform") or "0"), int(row.get("copy_len") or "0"), int(row.get("word_index") or "0"), str(row.get("word") or "")))
            except ValueError:
                continue
        report_csv_matched = len(report_entry_keys & csv_keys)
    report_csv_unmatched = max(report_csv_rows, report_entry_count) - report_csv_matched

    report_markdown_summary_rows = 0
    report_markdown_matched = 0
    report_markdown_matrix_rows = 0
    report_markdown_matrix_matched = 0
    report_markdown_entry_rows = 0
    report_markdown_entry_matched = 0
    if isinstance(report_markdown, Path):
        markdown = report_markdown.read_text(errors="replace")
        markdown_lines = {line.rstrip() for line in markdown.splitlines()}
        markdown_expected = {
            "Entries": report_entry_count,
            "Distinct transforms": report_transform_count,
            "Distinct lengths": report_length_count,
            "Identity entries": dict_int(report_category_counts, "identity"),
            "Transform entries": dict_int(report_category_counts, "transform"),
            "Phrase entries": dict_int(report_category_counts, "phrase"),
        }
        for label, expected in markdown_expected.items():
            report_markdown_summary_rows += 1
            if f"- {label}: {expected}" in markdown:
                report_markdown_matched += 1
        matrix_expected: list[str] = []
        for row in report_matrix_rows_data:
            if isinstance(row, dict):
                matrix_expected.append(
                    f"| {dict_int(row, 'transform')} | {dict_int(row, 'identity')} | {dict_int(row, 'transform_entries')} | {dict_int(row, 'phrase')} | {dict_int(row, 'total')} |"
                )
        report_markdown_matrix_rows = len(matrix_expected)
        report_markdown_matrix_matched = sum(1 for line in matrix_expected if line in markdown_lines)
        entry_expected: list[str] = []
        for row in report_entries:
            if isinstance(row, dict):
                key = entry_key(row)
                if key is None:
                    continue
                transform, copy_len, word_index, word = key
                entry_expected.append(
                    f"| {transform} | {copy_len} | {word_index} | {dict_int(row, 'word_bytes')} | `{report_markdown_code_escape(word)}` |"
                )
        report_markdown_entry_rows = len(entry_expected)
        report_markdown_entry_matched = sum(1 for line in entry_expected if line in markdown_lines)
    report_markdown_unmatched = report_markdown_summary_rows - report_markdown_matched
    report_markdown_matrix_unmatched = report_markdown_matrix_rows - report_markdown_matrix_matched
    report_markdown_entry_unmatched = report_markdown_entry_rows - report_markdown_entry_matched

    def negative_smoke_case_stats(data: dict | None) -> dict[str, int]:
        cases = data.get("cases") if isinstance(data, dict) else []
        cases = cases if isinstance(cases, list) else []
        case_count = int_field(data, "case_count")
        matched = sum(1 for row in cases if isinstance(row, dict) and row.get("matched") is True)
        rows = len(cases)
        return {
            "case_count": case_count,
            "rows": rows,
            "matched": matched,
            # Count drift and unmatched rows are tracked separately so a
            # dashboard cannot pass when an extra matched row hides behind a
            # lower declared case_count, or when an extra unmatched row hides
            # behind a matched count equal to case_count.
            "count_mismatch": abs(case_count - rows),
            "unmatched": max(case_count, rows) - matched,
        }

    report_negative_stats = negative_smoke_case_stats(report_negative)
    report_negative_case_count = report_negative_stats["case_count"]
    report_negative_rows = report_negative_stats["rows"]
    report_negative_matched = report_negative_stats["matched"]
    report_negative_count_mismatch = report_negative_stats["count_mismatch"]
    report_negative_unmatched = report_negative_stats["unmatched"]

    negative_stats = negative_smoke_case_stats(negative)
    negative_case_count = negative_stats["case_count"]
    negative_rows = negative_stats["rows"]
    negative_matched = negative_stats["matched"]
    negative_count_mismatch = negative_stats["count_mismatch"]
    negative_unmatched = negative_stats["unmatched"]
    candidate_present = isinstance(candidate, dict)
    candidate_markdown = candidate_markdown_health(candidate, candidate_markdown)
    upstream_report_present = isinstance(upstream_report, dict)
    upstream_markdown = candidate_markdown_health(upstream_report, upstream_markdown)
    node_markdown = node_markdown_health(node, node_markdown)
    upstream_present = isinstance(upstream, dict)
    node_present = isinstance(node, dict)
    audit_present = isinstance(audit, dict)
    negative_present = isinstance(negative, dict)
    report_present = isinstance(report, dict)
    report_csv_present = isinstance(report_csv, Path)
    report_markdown_present = isinstance(report_markdown, Path)
    report_negative_present = isinstance(report_negative, dict)
    candidate_count = int_field(candidate, "candidate_count")
    raw_word_count = int_field(candidate, "raw_word_count")
    upstream_candidate_count = int_field(upstream, "candidate_count")
    upstream_raw_word_count = int_field(upstream, "raw_word_count")
    upstream_report_candidate_count = int_field(upstream_report, "candidate_count")
    upstream_report_raw_word_count = int_field(upstream_report, "raw_word_count")
    upstream_report_upstream_raw_word_count = int_field(upstream_report, "upstream_raw_word_count")
    node_probed_count = int_field(node, "probed_count")
    node_decode_successes = int_field(node, "node_decode_successes")
    audit_entry_count = int_field(audit, "entry_count")
    audit_anchor_count = int_field(audit, "anchor_count")
    audit_generated_zig_bytes = int_field(audit, "generated_zig_bytes")
    core_healthy = (
        candidate_present
        and bool(candidate_markdown["present"])
        and upstream_present
        and upstream_report_present
        and bool(upstream_markdown["present"])
        and node_present
        and bool(node_markdown["present"])
        and audit_present
        and negative_present
        and candidate_count > 0
        and raw_word_count > 0
        and candidate_markdown["summary_rows"] > 0
        and candidate_markdown["summary_unmatched"] == 0
        and candidate_markdown["sample_rows"] > 0
        and candidate_markdown["sample_unmatched"] == 0
        and bool(upstream.get("ok"))
        and upstream_candidate_count > 0
        and upstream_raw_word_count > 0
        and upstream_report_candidate_count == upstream_candidate_count
        and upstream_report_raw_word_count == upstream_raw_word_count
        and upstream_report_upstream_raw_word_count == int_field(upstream, "upstream_raw_word_count")
        and upstream_report.get("source_mode") == upstream.get("source_mode") == "upstream"
        and int_field(upstream_report, "source_limit") == int_field(upstream, "source_limit")
        and upstream_markdown["summary_rows"] > 0
        and upstream_markdown["summary_unmatched"] == 0
        and upstream_markdown["sample_rows"] > 0
        and upstream_markdown["sample_unmatched"] == 0
        and bool(node.get("ok"))
        and node_probed_count > 0
        and node_decode_successes == node_probed_count
        and node_markdown["summary_rows"] > 0
        and node_markdown["summary_unmatched"] == 0
        and node_markdown["row_count"] == node_probed_count
        and node_markdown["row_unmatched"] == 0
        and bool(audit.get("ok"))
        and bool(audit.get("generated_table_matches_source"))
        and audit_entry_count > 0
        and audit_anchor_count > 0
        and audit_generated_zig_bytes > 0
        and bool(negative.get("ok"))
        and negative_case_count > 0
        and negative_count_mismatch == 0
        and negative_matched == negative_case_count
        and negative_unmatched == 0
    )
    report_healthy = (
        report_present
        and report_csv_present
        and report_markdown_present
        and report_negative_present
        and report_entry_count > 0
        and report_json_entries == report_entry_count
        and len(report_entry_keys) == report_entry_count
        and report_transform_count > 0
        and report_transform_count == report_actual_transform_count
        and report_length_count > 0
        and report_length_count == report_actual_length_count
        and report_category_total == report_entry_count
        and report_category_mismatch_rows == 0
        and report_matrix_total == report_entry_count
        and report_matrix_mismatch_rows == 0
        and report_csv_rows == report_entry_count
        and report_csv_unmatched == 0
        and report_markdown_summary_rows == 6
        and report_markdown_unmatched == 0
        and report_markdown_matrix_rows == len(report_matrix_rows_data)
        and report_markdown_matrix_rows > 0
        and report_markdown_matrix_unmatched == 0
        and report_markdown_entry_rows == report_entry_count
        and report_markdown_entry_unmatched == 0
        and bool(report_negative.get("ok"))
        and report_negative_case_count > 0
        and report_negative_rows == report_negative_case_count
        and report_negative_matched == report_negative_case_count
        and report_negative_count_mismatch == 0
        and report_negative_unmatched == 0
    )
    healthy = core_healthy and report_healthy
    return {
        "present": candidate_present,
        "candidate_markdown_present": bool(candidate_markdown["present"]),
        "candidate_markdown_summary_rows": int(candidate_markdown["summary_rows"]),
        "candidate_markdown_matched": int(candidate_markdown["summary_matched"]),
        "candidate_markdown_unmatched": int(candidate_markdown["summary_unmatched"]),
        "candidate_markdown_sample_rows": int(candidate_markdown["sample_rows"]),
        "candidate_markdown_sample_matched": int(candidate_markdown["sample_matched"]),
        "candidate_markdown_sample_unmatched": int(candidate_markdown["sample_unmatched"]),
        "upstream_present": upstream_present,
        "upstream_report_present": upstream_report_present,
        "upstream_report_candidate_count": upstream_report_candidate_count,
        "upstream_report_raw_word_count": upstream_report_raw_word_count,
        "upstream_report_upstream_raw_word_count": upstream_report_upstream_raw_word_count,
        "upstream_markdown_present": bool(upstream_markdown["present"]),
        "upstream_markdown_summary_rows": int(upstream_markdown["summary_rows"]),
        "upstream_markdown_matched": int(upstream_markdown["summary_matched"]),
        "upstream_markdown_unmatched": int(upstream_markdown["summary_unmatched"]),
        "upstream_markdown_sample_rows": int(upstream_markdown["sample_rows"]),
        "upstream_markdown_sample_matched": int(upstream_markdown["sample_matched"]),
        "upstream_markdown_sample_unmatched": int(upstream_markdown["sample_unmatched"]),
        "node_present": node_present,
        "node_markdown_present": bool(node_markdown["present"]),
        "node_markdown_summary_rows": int(node_markdown["summary_rows"]),
        "node_markdown_matched": int(node_markdown["summary_matched"]),
        "node_markdown_unmatched": int(node_markdown["summary_unmatched"]),
        "node_markdown_rows": int(node_markdown["row_count"]),
        "node_markdown_matched_rows": int(node_markdown["row_matched"]),
        "node_markdown_unmatched_rows": int(node_markdown["row_unmatched"]),
        "audit_present": audit_present,
        "negative_present": negative_present,
        "report_present": report_present,
        "report_csv_present": report_csv_present,
        "report_markdown_present": report_markdown_present,
        "report_negative_present": report_negative_present,
        "core_healthy": core_healthy,
        "report_healthy": report_healthy,
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
        "negative_rows": negative_rows,
        "negative_matched": negative_matched,
        "negative_count_mismatch": negative_count_mismatch,
        "negative_unmatched": negative_unmatched,
        "report_entry_count": report_entry_count,
        "report_json_entries": report_json_entries,
        "report_transform_count": report_transform_count,
        "report_length_count": report_length_count,
        "report_identity_count": report_identity_count,
        "report_transform_entry_count": report_transform_entry_count,
        "report_phrase_count": report_phrase_count,
        "report_category_total": report_category_total,
        "report_category_mismatch_rows": report_category_mismatch_rows,
        "report_matrix_rows": len(report_matrix_rows_data),
        "report_matrix_total": report_matrix_total,
        "report_matrix_mismatch_rows": report_matrix_mismatch_rows,
        "report_csv_rows": report_csv_rows,
        "report_csv_matched": report_csv_matched,
        "report_csv_unmatched": report_csv_unmatched,
        "report_markdown_summary_rows": report_markdown_summary_rows,
        "report_markdown_matched": report_markdown_matched,
        "report_markdown_unmatched": report_markdown_unmatched,
        "report_markdown_matrix_rows": report_markdown_matrix_rows,
        "report_markdown_matrix_matched": report_markdown_matrix_matched,
        "report_markdown_matrix_unmatched": report_markdown_matrix_unmatched,
        "report_markdown_entry_rows": report_markdown_entry_rows,
        "report_markdown_entry_matched": report_markdown_entry_matched,
        "report_markdown_entry_unmatched": report_markdown_entry_unmatched,
        "report_negative_case_count": report_negative_case_count,
        "report_negative_rows": report_negative_rows,
        "report_negative_matched": report_negative_matched,
        "report_negative_count_mismatch": report_negative_count_mismatch,
        "report_negative_unmatched": report_negative_unmatched,
    }


def png_scratch_health(artifacts: list[Path]) -> dict:
    markdown = next((artifact for artifact in artifacts if artifact.name == "vort-png-scratch-report.md"), None)

    def int_case(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def str_case(row: dict, field: str) -> str:
        value = row.get(field)
        return str(value) if isinstance(value, str) else ""

    def row_consistent(row: dict) -> bool:
        working = int_case(row, "working_scratch_bytes")
        streaming_working = int_case(row, "streaming_working_scratch_bytes")
        fixed_streaming_working = int_case(row, "fixed_dynamic_streaming_working_scratch_bytes")
        image_output = int_case(row, "image_output_bytes")
        zlib_scratch = int_case(row, "zlib_scratch_bytes")
        filtered = int_case(row, "filtered_row_scratch_bytes")
        previous = int_case(row, "previous_row_scratch_bytes")
        history = int_case(row, "fixed_dynamic_history_scratch_bytes")
        ratio = int_case(row, "streaming_scratch_ratio_x10000")
        expected_ratio = streaming_working * 10000 // working if working > 0 else 0
        return (
            working == zlib_scratch + filtered + previous
            and streaming_working == filtered + previous
            and fixed_streaming_working == history + filtered + previous
            and int_case(row, "streaming_scratch_savings_bytes") == zlib_scratch
            and int_case(row, "total_caller_owned_bytes") == working + image_output
            and int_case(row, "streaming_total_caller_owned_bytes") == streaming_working + image_output
            and int_case(row, "fixed_dynamic_streaming_total_caller_owned_bytes") == fixed_streaming_working + image_output
            and ratio == expected_ratio
        )

    def markdown_checks(cases: list[object]) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        expected: list[str] = []
        for row in cases:
            if not isinstance(row, dict):
                continue
            expected.append(
                "| {case} | {interlace} | {width}x{height} | {bit_depth} | {color_type} | {stored} | {fixed} | {zlib} | {filtered} | {previous} | {history} | {output} | {working} | {streaming_working} | {fixed_streaming_working} | {savings} | {ratio} | {total} | {streaming_total} | {fixed_total} |".format(
                    case=str_case(row, "case"),
                    interlace=str_case(row, "interlace"),
                    width=int_case(row, "width"),
                    height=int_case(row, "height"),
                    bit_depth=int_case(row, "bit_depth"),
                    color_type=str_case(row, "color_type"),
                    stored=str_case(row, "stored_streaming_status"),
                    fixed=str_case(row, "fixed_dynamic_streaming_status"),
                    zlib=int_case(row, "zlib_scratch_bytes"),
                    filtered=int_case(row, "filtered_row_scratch_bytes"),
                    previous=int_case(row, "previous_row_scratch_bytes"),
                    history=int_case(row, "fixed_dynamic_history_scratch_bytes"),
                    output=int_case(row, "image_output_bytes"),
                    working=int_case(row, "working_scratch_bytes"),
                    streaming_working=int_case(row, "streaming_working_scratch_bytes"),
                    fixed_streaming_working=int_case(row, "fixed_dynamic_streaming_working_scratch_bytes"),
                    savings=int_case(row, "streaming_scratch_savings_bytes"),
                    ratio=int_case(row, "streaming_scratch_ratio_x10000"),
                    total=int_case(row, "total_caller_owned_bytes"),
                    streaming_total=int_case(row, "streaming_total_caller_owned_bytes"),
                    fixed_total=int_case(row, "fixed_dynamic_streaming_total_caller_owned_bytes"),
                )
            )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.png_scratch_report":
            continue
        cases = data.get("cases")
        cases = cases if isinstance(cases, list) else []
        case_count = int(data.get("case_count") or 0)
        report_rows = len(cases)
        report_count_mismatch = abs(case_count - report_rows)
        row_consistent_count = sum(1 for row in cases if isinstance(row, dict) and row_consistent(row))
        row_inconsistent_count = report_rows - row_consistent_count
        adam7_cases = sum(1 for row in cases if isinstance(row, dict) and row.get("interlace") == "adam7")
        stored_achieved = sum(1 for row in cases if isinstance(row, dict) and row.get("stored_streaming_status") == "achieved")
        fixed_achieved = sum(1 for row in cases if isinstance(row, dict) and row.get("fixed_dynamic_streaming_status") == "achieved")
        total_zlib_scratch = sum(int_case(row, "zlib_scratch_bytes") for row in cases if isinstance(row, dict))
        total_streaming_savings = sum(int_case(row, "streaming_scratch_savings_bytes") for row in cases if isinstance(row, dict))
        max_working_scratch = max((int_case(row, "working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        max_streaming_working_scratch = max((int_case(row, "streaming_working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        max_fixed_dynamic_streaming_working_scratch = max((int_case(row, "fixed_dynamic_streaming_working_scratch_bytes") for row in cases if isinstance(row, dict)), default=0)
        min_streaming_ratio = min((int_case(row, "streaming_scratch_ratio_x10000") for row in cases if isinstance(row, dict)), default=0)
        markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(cases)
        healthy = (
            case_count > 0
            and report_count_mismatch == 0
            and row_inconsistent_count == 0
            and adam7_cases > 0
            and stored_achieved == case_count
            and fixed_achieved == case_count
            and total_streaming_savings == total_zlib_scratch
            and max_working_scratch > max_streaming_working_scratch
            and max_fixed_dynamic_streaming_working_scratch >= 32768
            and markdown_present
            and markdown_rows == case_count
            and markdown_unmatched == 0
        )
        return {
            "present": True,
            "markdown_present": markdown_present,
            "healthy": healthy,
            "case_count": case_count,
            "report_rows": report_rows,
            "report_count_mismatch": report_count_mismatch,
            "row_consistent_count": row_consistent_count,
            "row_inconsistent_count": row_inconsistent_count,
            "adam7_cases": adam7_cases,
            "stored_achieved": stored_achieved,
            "fixed_achieved": fixed_achieved,
            "total_zlib_scratch": total_zlib_scratch,
            "total_streaming_savings": total_streaming_savings,
            "max_working_scratch": max_working_scratch,
            "max_streaming_working_scratch": max_streaming_working_scratch,
            "max_fixed_dynamic_streaming_working_scratch": max_fixed_dynamic_streaming_working_scratch,
            "min_streaming_ratio": min_streaming_ratio,
            "markdown_rows": markdown_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
        }
    return {
        "present": False,
        "markdown_present": False,
        "healthy": False,
        "case_count": 0,
        "report_rows": 0,
        "report_count_mismatch": 0,
        "row_consistent_count": 0,
        "row_inconsistent_count": 0,
        "adam7_cases": 0,
        "stored_achieved": 0,
        "fixed_achieved": 0,
        "total_zlib_scratch": 0,
        "total_streaming_savings": 0,
        "max_working_scratch": 0,
        "max_streaming_working_scratch": 0,
        "max_fixed_dynamic_streaming_working_scratch": 0,
        "min_streaming_ratio": 0,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
    }


def zlib_relaxed_health(artifacts: list[Path]) -> dict:
    report = None
    gate = None
    markdown = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.zlib_relaxed_report":
            report = data
        elif data.get("schema") == "vort.zlib_relaxed_report_gate":
            gate = data
        elif artifact.name == "vort-zlib-relaxed-report.md":
            markdown = artifact

    metric_rows = (
        ("strict_rejections", "zlib strict rejections"),
        ("relaxed_successes", "zlib relaxed successes"),
        ("dictionary_successes", "zlib dictionary successes"),
        ("zlib_concatenated_successes", "zlib concatenated successes"),
        ("zlib_decoder_successes", "zlib decoder successes"),
        ("limited_rejections", "zlib limited rejections"),
        ("gzip_strict_rejections", "gzip strict rejections"),
        ("gzip_relaxed_successes", "gzip relaxed successes"),
        ("gzip_concatenated_successes", "gzip concatenated successes"),
        ("gzip_decoder_successes", "gzip decoder successes"),
        ("gzip_limited_rejections", "gzip limited rejections"),
    )
    metric_fields = {field for field, _ in metric_rows}
    exact_gate_rules = {
        "strict_rejections": 2,
        "dictionary_successes": 2,
        "limited_rejections": 1,
        "gzip_strict_rejections": 3,
        "gzip_decoder_successes": 4,
        "gzip_limited_rejections": 1,
    }
    floor_gate_rules = {
        "relaxed_successes": 5,
        "zlib_concatenated_successes": 3,
        "zlib_decoder_successes": 8,
        "gzip_relaxed_successes": 9,
        "gzip_concatenated_successes": 4,
    }

    def int_field(field: str) -> int:
        if not isinstance(report, dict):
            return 0
        value = report.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def markdown_checks() -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        expected = [f"| {label} | {int_field(field)} |" for field, label in metric_rows]
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    gate_checks = gate.get("checks") if isinstance(gate, dict) else {}
    gate_checks = gate_checks if isinstance(gate_checks, dict) else {}
    gate_check_count = len(gate_checks)
    gate_expected_checks = len(metric_rows)
    gate_passed_count = sum(1 for value in gate_checks.values() if value is True)
    gate_failed_checks = sorted(str(name) for name, value in gate_checks.items() if value is not True)
    gate_present = isinstance(gate, dict)
    gate_ok = bool(gate.get("ok")) if isinstance(gate, dict) else False
    gate_keys = {str(name) for name in gate_checks}
    recomputed_gate_checks = {
        field: int_field(field) == expected
        for field, expected in exact_gate_rules.items()
    }
    recomputed_gate_checks.update({
        field: int_field(field) >= floor
        for field, floor in floor_gate_rules.items()
    })
    gate_missing_checks = len(metric_fields - gate_keys)
    gate_extra_checks = len(gate_keys - metric_fields)
    gate_recomputed_passed_count = sum(1 for value in recomputed_gate_checks.values() if value is True)
    gate_recomputed_failed_count = gate_expected_checks - gate_recomputed_passed_count
    gate_check_rule_mismatch = sum(
        1
        for field, expected in recomputed_gate_checks.items()
        if gate_checks.get(field) is not expected
    ) + gate_extra_checks
    gate_exact_mismatch_count = sum(
        1 for field, expected in exact_gate_rules.items()
        if int_field(field) != expected
    )
    gate_floor_shortfall_count = sum(
        1 for field, floor in floor_gate_rules.items()
        if int_field(field) < floor
    )
    gate_report_matched = sum(
        1
        for field in metric_fields
        if gate_checks.get(field) is True and recomputed_gate_checks.get(field) is True
    )
    gate_report_unmatched = gate_extra_checks + (gate_expected_checks - gate_report_matched)
    markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks()
    zlib_total = int_field("strict_rejections") + int_field("relaxed_successes") + int_field("dictionary_successes") + int_field("zlib_concatenated_successes") + int_field("zlib_decoder_successes") + int_field("limited_rejections")
    gzip_total = int_field("gzip_strict_rejections") + int_field("gzip_relaxed_successes") + int_field("gzip_concatenated_successes") + int_field("gzip_decoder_successes") + int_field("gzip_limited_rejections")
    report_present = isinstance(report, dict)
    report_healthy = gate_exact_mismatch_count == 0 and gate_floor_shortfall_count == 0
    markdown_healthy = markdown_present and markdown_rows == gate_expected_checks and markdown_unmatched == 0
    gate_healthy = (
        gate_present
        and gate_ok
        and gate_check_count == gate_expected_checks
        and gate_missing_checks == 0
        and gate_extra_checks == 0
        and gate_recomputed_failed_count == 0
        and gate_check_rule_mismatch == 0
        and gate_report_unmatched == 0
        and gate_passed_count == gate_check_count
    )
    healthy = report_present and report_healthy and gate_healthy and markdown_healthy
    return {
        "present": report_present,
        "markdown_present": markdown_present,
        "healthy": healthy,
        "gate_present": gate_present,
        "gate_ok": gate_ok,
        "gate_check_count": gate_check_count,
        "gate_expected_checks": gate_expected_checks,
        "gate_passed_count": gate_passed_count,
        "gate_failed_checks": gate_failed_checks,
        "gate_report_matched": gate_report_matched,
        "gate_report_unmatched": gate_report_unmatched,
        "gate_missing_checks": gate_missing_checks,
        "gate_extra_checks": gate_extra_checks,
        "gate_recomputed_passed_count": gate_recomputed_passed_count,
        "gate_recomputed_failed_count": gate_recomputed_failed_count,
        "gate_check_rule_mismatch": gate_check_rule_mismatch,
        "gate_exact_mismatch_count": gate_exact_mismatch_count,
        "gate_floor_shortfall_count": gate_floor_shortfall_count,
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
        "markdown_rows": markdown_rows,
        "markdown_matched": markdown_matched,
        "markdown_unmatched": markdown_unmatched,
    }

def snappy_report_health(artifacts: list[Path]) -> dict:
    expected_modes = {"raw_block", "framed", "raw_block_reusable", "framed_reusable"}
    expected_cases = {"tiny", "text", "structured", "repetitive", "incompressible"}
    expected_pairs = {(mode, case) for mode in expected_modes for case in expected_cases}
    for artifact in artifacts:
        if artifact.name != "vort-snappy-report.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_timing_rows = 0
        ratio_rows = 0
        throughput_rows = 0
        repetitive_shrunk_rows = 0
        framed_overhead_matched_cases = 0
        reusable_size_matched_cases = 0
        reusable_checksum_matched_cases = 0
        rows_by_pair: dict[tuple[str, str], dict[str, str]] = {}
        for row in rows:
            mode = str(row.get("mode") or "")
            case = str(row.get("case") or "")
            pair = (mode, case)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_pair[pair] = row
            else:
                unknown_pairs.add(pair)
            try:
                input_bytes = int(row.get("input_bytes") or "0")
                encoded_bytes = int(row.get("encoded_bytes") or "0")
                ratio = float(row.get("ratio") or "0")
                iterations = int(row.get("iterations") or "0")
                encode_ns = int(row.get("encode_ns") or "0")
                decode_ns = int(row.get("decode_ns") or "0")
                encode_mib_s = float(row.get("encode_mib_s") or "0")
                decode_mib_s = float(row.get("decode_mib_s") or "0")
            except ValueError:
                continue
            if input_bytes > 0 and encoded_bytes > 0 and ratio > 0.0 and encode_mib_s > 0.0 and decode_mib_s > 0.0:
                positive_timing_rows += 1
            if input_bytes > 0 and abs(ratio - (encoded_bytes / input_bytes)) <= 0.000001:
                ratio_rows += 1
            expected_encode_mib_s = ((input_bytes * iterations) / (1024.0 * 1024.0)) / (encode_ns / 1_000_000_000.0) if encode_ns > 0 else 0.0
            expected_decode_mib_s = ((input_bytes * iterations) / (1024.0 * 1024.0)) / (decode_ns / 1_000_000_000.0) if decode_ns > 0 else 0.0
            if abs(encode_mib_s - expected_encode_mib_s) <= 0.0001 and abs(decode_mib_s - expected_decode_mib_s) <= 0.0001:
                throughput_rows += 1
            if case == "repetitive" and pair in expected_pairs and ratio < 0.35:
                repetitive_shrunk_rows += 1

        for case in expected_cases:
            raw = rows_by_pair.get(("raw_block", case))
            framed = rows_by_pair.get(("framed", case))
            raw_reusable = rows_by_pair.get(("raw_block_reusable", case))
            framed_reusable = rows_by_pair.get(("framed_reusable", case))
            if not (raw and framed and raw_reusable and framed_reusable):
                continue
            try:
                raw_size = int(raw.get("encoded_bytes") or "0")
                framed_size = int(framed.get("encoded_bytes") or "0")
                raw_reusable_size = int(raw_reusable.get("encoded_bytes") or "0")
                framed_reusable_size = int(framed_reusable.get("encoded_bytes") or "0")
                raw_checksum = int(raw.get("checksum") or "0")
                framed_checksum = int(framed.get("checksum") or "0")
                raw_reusable_checksum = int(raw_reusable.get("checksum") or "0")
                framed_reusable_checksum = int(framed_reusable.get("checksum") or "0")
            except ValueError:
                continue
            framed_overhead = framed_size - raw_size
            framed_reusable_overhead = framed_reusable_size - raw_reusable_size
            if framed_overhead > 0 and framed_overhead == framed_reusable_overhead:
                framed_overhead_matched_cases += 1
            if raw_size == raw_reusable_size and framed_size == framed_reusable_size and framed_size >= raw_size:
                reusable_size_matched_cases += 1
            if raw_checksum == raw_reusable_checksum and framed_checksum == framed_reusable_checksum and raw_checksum > 0 and framed_checksum > 0:
                reusable_checksum_matched_cases += 1

        missing_pairs = sorted(f"{mode}:{case}" for mode, case in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{mode}:{case}" for mode, case in duplicate_pairs)
        unknown_pair_names = sorted(f"{mode}:{case}" for mode, case in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_timing_rows == row_count
            and ratio_rows == row_count
            and throughput_rows == row_count
            and repetitive_shrunk_rows == len(expected_modes)
            and framed_overhead_matched_cases == len(expected_cases)
            and reusable_size_matched_cases == len(expected_cases)
            and reusable_checksum_matched_cases == len(expected_cases)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_timing_rows": positive_timing_rows,
            "ratio_rows": ratio_rows,
            "throughput_rows": throughput_rows,
            "repetitive_shrunk_rows": repetitive_shrunk_rows,
            "framed_overhead_matched_cases": framed_overhead_matched_cases,
            "reusable_size_matched_cases": reusable_size_matched_cases,
            "reusable_checksum_matched_cases": reusable_checksum_matched_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_timing_rows": 0,
        "ratio_rows": 0,
        "throughput_rows": 0,
        "repetitive_shrunk_rows": 0,
        "framed_overhead_matched_cases": 0,
        "reusable_size_matched_cases": 0,
        "reusable_checksum_matched_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def checksum_bench_health(artifacts: list[Path]) -> dict:
    expected_algorithms = {
        "adler32",
        "crc32-scalar",
        "crc32-slice4",
        "crc32-slice8",
        "crc32-slice16",
        "crc32-slice32",
        "crc32-slice32-seg64",
        "crc32-slice32-seg256",
        "crc32-slice32-seg1024",
        "crc32-slice32-seg4096",
        "crc32-slice32-span-threshold256",
        "crc32-slice32-span-threshold1024",
        "crc32-slice32-span-threshold2048",
        "crc32-slice32-span-threshold4096",
        "crc32-slice32-selective4096",
        "crc32-best",
        "crc32c-scalar",
        "crc32c-slice8",
        "crc32c-slice16",
        "crc32c-slice32",
        "crc32c-best",
    }
    expected_bytes = 1 << 20
    expected_iterations = 128
    for artifact in artifacts:
        if artifact.name != "vort-checksum-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[str] = set()
        duplicate_algorithms: set[str] = set()
        unknown_algorithms: set[str] = set()
        positive_rows = 0
        workload_rows = 0
        throughput_rows = 0
        crc32_mixes: set[str] = set()
        crc32c_mixes: set[str] = set()
        for row in rows:
            algorithm = str(row.get("algorithm") or "")
            if algorithm in expected_algorithms:
                if algorithm in seen:
                    duplicate_algorithms.add(algorithm)
                seen.add(algorithm)
            else:
                unknown_algorithms.add(algorithm)
            try:
                bytes_value = int(row.get("bytes") or "0")
                iterations = int(row.get("iterations") or "0")
                elapsed_s = float(row.get("elapsed_s") or "0")
                throughput = float(row.get("throughput_mib_s") or "0")
                mix = int(row.get("mix") or "0")
            except ValueError:
                continue
            if elapsed_s > 0.0 and throughput > 0.0 and mix > 0:
                positive_rows += 1
            if bytes_value == expected_bytes and iterations == expected_iterations:
                workload_rows += 1
            expected_throughput = ((bytes_value * iterations) / (1024.0 * 1024.0)) / elapsed_s if elapsed_s > 0.0 else 0.0
            if abs(throughput - expected_throughput) <= 0.05:
                throughput_rows += 1
            if algorithm.startswith("crc32-"):
                crc32_mixes.add(str(mix))
            elif algorithm.startswith("crc32c-"):
                crc32c_mixes.add(str(mix))

        missing_algorithms = sorted(expected_algorithms - seen)
        duplicate_algorithm_names = sorted(duplicate_algorithms)
        unknown_algorithm_names = sorted(unknown_algorithms)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_algorithms)
            and not missing_algorithms
            and not duplicate_algorithm_names
            and not unknown_algorithm_names
            and positive_rows == row_count
            and workload_rows == row_count
            and throughput_rows == row_count
            and len(crc32_mixes) == 1
            and len(crc32c_mixes) == 1
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_algorithms),
            "positive_rows": positive_rows,
            "workload_rows": workload_rows,
            "throughput_rows": throughput_rows,
            "crc32_mix_groups": len(crc32_mixes),
            "crc32c_mix_groups": len(crc32c_mixes),
            "missing_algorithms": missing_algorithms,
            "duplicate_algorithms": duplicate_algorithm_names,
            "unknown_algorithms": unknown_algorithm_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_algorithms),
        "positive_rows": 0,
        "workload_rows": 0,
        "throughput_rows": 0,
        "crc32_mix_groups": 0,
        "crc32c_mix_groups": 0,
        "missing_algorithms": [],
        "duplicate_algorithms": [],
        "unknown_algorithms": [],
    }


def chunk_cursor_bench_health(artifacts: list[Path]) -> dict:
    expected_cases = {
        "read-1b-empty": {"operation": "read-byte", "payload_bytes": 8 * 1024, "chunk_bytes": 1, "include_empty_chunks": "true"},
        "copy-1b-empty": {"operation": "copy-to", "payload_bytes": 8 * 1024, "chunk_bytes": 1, "include_empty_chunks": "true"},
        "copy-7b-empty": {"operation": "copy-to", "payload_bytes": 32 * 1024, "chunk_bytes": 7, "include_empty_chunks": "true"},
        "copy-256b": {"operation": "copy-to", "payload_bytes": 64 * 1024, "chunk_bytes": 256, "include_empty_chunks": "false"},
    }
    expected_kernels = {"current", "skip_empty_advance"}
    expected_pairs = {(case, kernel) for case in expected_cases for kernel in expected_kernels}

    def expected_chunk_count(payload_bytes: int, chunk_bytes: int, include_empty: bool) -> int:
        non_empty = (payload_bytes + chunk_bytes - 1) // chunk_bytes
        return non_empty * 2 + 1 if include_empty else non_empty

    for artifact in artifacts:
        if artifact.name != "vort-chunk-cursor-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        shape_rows = 0
        throughput_rows = 0
        rows_by_pair: dict[tuple[str, str], dict[str, str]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            kernel = str(row.get("kernel") or "")
            pair = (case, kernel)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_pair[pair] = row
            else:
                unknown_pairs.add(pair)
            expected = expected_cases.get(case)
            try:
                payload_bytes = int(row.get("payload_bytes") or "0")
                chunk_bytes = int(row.get("chunk_bytes") or "0")
                chunk_count = int(row.get("chunk_count") or "0")
                iterations = int(row.get("iterations") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                bytes_per_s = float(row.get("bytes_per_s") or "0")
                mib_per_s = float(row.get("mib_per_s") or "0")
            except ValueError:
                continue
            if iterations > 0 and elapsed_ns > 0 and checksum > 0 and bytes_per_s > 0.0 and mib_per_s > 0.0:
                positive_rows += 1
            expected_bytes_per_s = (payload_bytes * iterations) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            expected_mib_per_s = expected_bytes_per_s / (1024.0 * 1024.0)
            if abs(bytes_per_s - expected_bytes_per_s) <= 0.01 and abs(mib_per_s - expected_mib_per_s) <= 0.01:
                throughput_rows += 1
            if expected is not None:
                expected_chunks = expected_chunk_count(expected["payload_bytes"], expected["chunk_bytes"], expected["include_empty_chunks"] == "true")
                if (
                    row.get("operation") == expected["operation"]
                    and row.get("include_empty_chunks") == expected["include_empty_chunks"]
                    and payload_bytes == expected["payload_bytes"]
                    and chunk_bytes == expected["chunk_bytes"]
                    and chunk_count == expected_chunks
                ):
                    shape_rows += 1

        checksum_matched_cases = 0
        for case in expected_cases:
            current = rows_by_pair.get((case, "current"))
            optimized = rows_by_pair.get((case, "skip_empty_advance"))
            if not (current and optimized):
                continue
            try:
                current_checksum = int(current.get("checksum") or "0")
                optimized_checksum = int(optimized.get("checksum") or "0")
            except ValueError:
                continue
            if current_checksum == optimized_checksum and current_checksum > 0:
                checksum_matched_cases += 1

        missing_pairs = sorted(f"{case}:{kernel}" for case, kernel in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{kernel}" for case, kernel in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{kernel}" for case, kernel in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_cases == len(expected_cases)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_cases": checksum_matched_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }

    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "shape_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def deflate_match_copy_bench_health(artifacts: list[Path]) -> dict:
    expected_cases = {
        "rle-long": "rle",
        "small-distance-long": "small_distance",
        "nonoverlap-len3": "non_overlapping",
        "nonoverlap-len6": "non_overlapping",
        "nonoverlap-len32": "non_overlapping",
        "overlap-text-like": "overlapping",
        "overlap-distance-heavy": "overlapping",
    }
    expected_kernels = {"current", "nonoverlap_first", "small_unrolled"}
    expected_pairs = {(case, kernel) for case in expected_cases for kernel in expected_kernels}
    for artifact in artifacts:
        if artifact.name != "vort-deflate-match-copy-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        expected_class_rows = 0
        output_bytes_rows = 0
        throughput_rows = 0
        rows_by_case: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            kernel = str(row.get("kernel") or "")
            class_name = str(row.get("class") or "")
            pair = (case, kernel)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_case.setdefault(case, []).append(row)
            else:
                unknown_pairs.add(pair)
            if expected_cases.get(case) == class_name:
                expected_class_rows += 1
            try:
                length = int(row.get("length") or "0")
                distance = int(row.get("distance") or "0")
                ops_per_iter = int(row.get("ops_per_iter") or "0")
                iterations = int(row.get("iterations") or "0")
                output_bytes = int(row.get("output_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                output_mib_s = float(row.get("output_mib_per_s") or "0")
            except ValueError:
                continue
            if all(value > 0 for value in (length, distance, ops_per_iter, iterations, output_bytes, elapsed_ns, checksum)) and output_mib_s > 0.0:
                positive_rows += 1
            if output_bytes == length * ops_per_iter * iterations:
                output_bytes_rows += 1
            expected_mib_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(output_mib_s - expected_mib_s) <= 0.05:
                throughput_rows += 1

        checksum_matched_cases = 0
        for case in expected_cases:
            case_rows = rows_by_case.get(case, [])
            checksums = set()
            for row in case_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            if len(case_rows) == len(expected_kernels) and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_cases += 1

        missing_pairs = sorted(f"{case}:{kernel}" for case, kernel in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{kernel}" for case, kernel in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{kernel}" for case, kernel in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and expected_class_rows == row_count
            and output_bytes_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_cases == len(expected_cases)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "expected_class_rows": expected_class_rows,
            "output_bytes_rows": output_bytes_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_cases": checksum_matched_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "expected_class_rows": 0,
        "output_bytes_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def deflate_huffman_build_bench_health(artifacts: list[Path]) -> dict:
    expected = {
        "literal-mixed": {"table", "fast9", "fast11", "fast12"},
        "literal-long-tail": {"table", "fast9", "fast11", "fast12"},
        "distance-mixed": {"table", "fast5", "fast8"},
        "code-length": {"table", "fast5", "fast7"},
    }
    lookup_bits = {"table": 0, "fast5": 5, "fast7": 7, "fast8": 8, "fast9": 9, "fast11": 11, "fast12": 12}
    expected_pairs = {(case, build) for case, builds in expected.items() for build in builds}
    for artifact in artifacts:
        if artifact.name != "vort-deflate-huffman-build-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []

        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        lookup_rows = 0
        throughput_rows = 0
        rows_by_case: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            build = str(row.get("build") or "")
            pair = (case, build)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_case.setdefault(case, []).append(row)
            else:
                unknown_pairs.add(pair)
            try:
                row_lookup_bits = int(row.get("lookup_bits") or "-1")
                symbols = int(row.get("symbols") or "0")
                iterations = int(row.get("iterations") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                builds_per_s = float(row.get("builds_per_s") or "0")
            except ValueError:
                continue
            if row_lookup_bits == lookup_bits.get(build, -2):
                lookup_rows += 1
            if symbols > 0 and iterations > 0 and elapsed_ns > 0 and checksum > 0 and builds_per_s > 0.0:
                positive_rows += 1
            expected_builds_per_s = iterations / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(builds_per_s - expected_builds_per_s) <= 0.05:
                throughput_rows += 1

        checksum_variant_cases = 0
        for case, builds in expected.items():
            case_rows = rows_by_case.get(case, [])
            checksums = set()
            for row in case_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            # The table-builder variants intentionally produce different table
            # layouts for the same symbol set. Requiring unique non-zero
            # checksums per variant catches stale or duplicated benchmark rows.
            if len(case_rows) == len(builds) and len(checksums) == len(builds) and all(checksum > 0 for checksum in checksums):
                checksum_variant_cases += 1

        missing_pairs = sorted(f"{case}:{build}" for case, build in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{build}" for case, build in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{build}" for case, build in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and lookup_rows == row_count
            and throughput_rows == row_count
            and checksum_variant_cases == len(expected)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "lookup_rows": lookup_rows,
            "throughput_rows": throughput_rows,
            "checksum_variant_cases": checksum_variant_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "lookup_rows": 0,
        "throughput_rows": 0,
        "checksum_variant_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def deflate_huffman_lookup_bench_health(artifacts: list[Path]) -> dict:
    expected = {
        "fixed-literal": {"table", "fixed_fast", "fast9"},
        "fixed-distance": {"table", "fixed_fast", "fast5", "fast8"},
        "code-length": {"table", "fast5", "fast7"},
        "dynamic-mixed": {"table", "fast9", "fast11", "fast12"},
        "dynamic-long-tail": {"table", "fast9", "fast11", "fast12"},
        "dynamic-distance": {"table", "fast5", "fast8"},
    }
    lookup_bits = {"table": 0, "fixed_fast": 9, "fast5": 5, "fast7": 7, "fast8": 8, "fast9": 9, "fast11": 11, "fast12": 12}
    expected_pairs = {(case, decoder) for case, decoders in expected.items() for decoder in decoders}
    for artifact in artifacts:
        if artifact.name != "vort-deflate-huffman-lookup-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        lookup_rows = 0
        throughput_rows = 0
        rows_by_case: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            decoder = str(row.get("decoder") or "")
            pair = (case, decoder)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_case.setdefault(case, []).append(row)
            else:
                unknown_pairs.add(pair)
            try:
                row_lookup_bits = int(row.get("lookup_bits") or "-1")
                symbols_per_iter = int(row.get("symbols_per_iter") or "0")
                iterations = int(row.get("iterations") or "0")
                input_bytes = int(row.get("input_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                symbols_per_s = float(row.get("symbols_per_s") or "0")
                mib_per_s = float(row.get("mib_per_s") or "0")
            except ValueError:
                continue
            if row_lookup_bits == lookup_bits.get(decoder, -2):
                lookup_rows += 1
            if all(value > 0 for value in (symbols_per_iter, iterations, input_bytes, elapsed_ns, checksum)) and symbols_per_s > 0.0 and mib_per_s > 0.0:
                positive_rows += 1
            expected_symbols_per_s = (symbols_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            expected_mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(symbols_per_s - expected_symbols_per_s) <= 0.05 and abs(mib_per_s - expected_mib_per_s) <= 0.01:
                throughput_rows += 1

        checksum_matched_cases = 0
        for case, decoders in expected.items():
            case_rows = rows_by_case.get(case, [])
            checksums = set()
            for row in case_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            if len(case_rows) == len(decoders) and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_cases += 1
        missing_pairs = sorted(f"{case}:{decoder}" for case, decoder in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{decoder}" for case, decoder in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{decoder}" for case, decoder in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and lookup_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_cases == len(expected)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "lookup_rows": lookup_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_cases": checksum_matched_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "lookup_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def deflate_chunked_huffman_bench_health(artifacts: list[Path]) -> dict:
    expected_cases = {
        "fixed-literal": {"decoder": "fixed_fast", "lookup_bits": 9},
        "dynamic-mixed": {"decoder": "fast11", "lookup_bits": 11},
        "dynamic-long-tail": {"decoder": "fast12", "lookup_bits": 12},
    }
    expected_readers = {
        "buffered": 0,
        "chunked_4096": 4096,
        "coalesced_4096": 4096,
        "joined_4096": 4096,
        "windowed1024_4096": 4096,
        "windowed4096_4096": 4096,
        "span_4096": 4096,
        "chunked_64": 64,
        "coalesced_64": 64,
        "joined_64": 64,
        "windowed1024_64": 64,
        "windowed4096_64": 64,
        "span_64": 64,
        "chunked_1": 1,
        "coalesced_1": 1,
        "joined_1": 1,
        "windowed1024_1": 1,
        "windowed4096_1": 1,
        "span_1": 1,
    }
    expected_pairs = {(case, reader) for case in expected_cases for reader in expected_readers}
    symbols_per_iter_expected = 128 * 1024
    for artifact in artifacts:
        if artifact.name != "vort-deflate-chunked-huffman-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        shape_rows = 0
        buffered_zero_chunk_rows = 0
        chunk_count_rows = 0
        throughput_rows = 0
        rows_by_case: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            reader = str(row.get("reader") or "")
            pair = (case, reader)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                rows_by_case.setdefault(case, []).append(row)
            else:
                unknown_pairs.add(pair)
            expected_case = expected_cases.get(case)
            expected_chunk_bytes = expected_readers.get(reader)
            try:
                lookup_bits = int(row.get("lookup_bits") or "-1")
                chunk_bytes = int(row.get("chunk_bytes") or "-1")
                chunk_count = int(row.get("chunk_count") or "-1")
                symbols_per_iter = int(row.get("symbols_per_iter") or "0")
                iterations = int(row.get("iterations") or "0")
                input_bytes = int(row.get("input_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                symbols_per_s = float(row.get("symbols_per_s") or "0")
                mib_per_s = float(row.get("mib_per_s") or "0")
            except ValueError:
                continue
            if iterations > 0 and input_bytes > 0 and elapsed_ns > 0 and checksum > 0 and symbols_per_s > 0.0 and mib_per_s > 0.0:
                positive_rows += 1
            if reader == "buffered" and chunk_count == 0:
                buffered_zero_chunk_rows += 1
            if iterations > 0 and input_bytes % iterations == 0:
                input_bytes_per_iteration = input_bytes // iterations
                expected_chunk_count = 0 if reader == "buffered" else (input_bytes_per_iteration + max(1, chunk_bytes) - 1) // max(1, chunk_bytes)
                if chunk_count == expected_chunk_count:
                    chunk_count_rows += 1
            expected_symbols_per_s = (symbols_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            expected_mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(symbols_per_s - expected_symbols_per_s) <= 0.05 and abs(mib_per_s - expected_mib_per_s) <= 0.01:
                throughput_rows += 1
            if (
                expected_case is not None
                and expected_chunk_bytes is not None
                and row.get("decoder") == expected_case["decoder"]
                and lookup_bits == expected_case["lookup_bits"]
                and chunk_bytes == expected_chunk_bytes
                and symbols_per_iter == symbols_per_iter_expected
                and (reader == "buffered" or chunk_count > 0)
            ):
                shape_rows += 1
        checksum_matched_cases = 0
        for case in expected_cases:
            case_rows = rows_by_case.get(case, [])
            checksums = set()
            for row in case_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            if len(case_rows) == len(expected_readers) and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_cases += 1
        missing_pairs = sorted(f"{case}:{reader}" for case, reader in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{reader}" for case, reader in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{reader}" for case, reader in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and buffered_zero_chunk_rows == len(expected_cases)
            and chunk_count_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_cases == len(expected_cases)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "buffered_zero_chunk_rows": buffered_zero_chunk_rows,
            "chunk_count_rows": chunk_count_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_cases": checksum_matched_cases,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "shape_rows": 0,
        "buffered_zero_chunk_rows": 0,
        "chunk_count_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_cases": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def deflate_extra_bits_bench_health(artifacts: list[Path]) -> dict:
    expected_cases = {
        "extra-1": {"bits": 1, "kernels": {"single"}},
        "extra-3": {"bits": 3, "kernels": {"single"}},
        "extra-5": {"bits": 5, "kernels": {"single"}},
        "extra-9": {"bits": 9, "kernels": {"single"}},
        "extra-13": {"bits": 13, "kernels": {"single"}},
        "mixed-readme-length": {"bits": 0, "kernels": {"current", "staged"}},
        "mixed-roadmap-length": {"bits": 0, "kernels": {"current", "staged"}},
        "mixed-readme-distance": {"bits": 0, "kernels": {"mixed-extra"}},
        "mixed-roadmap-distance": {"bits": 0, "kernels": {"mixed-extra"}},
        "distance-readme-symbol-extra": {"bits": 0, "kernels": {"current", "fused18"}},
        "distance-roadmap-symbol-extra": {"bits": 0, "kernels": {"current", "fused18"}},
    }
    expected_readers = {"buffered", "chunked_4096", "span_4096", "chunked_64", "span_64", "chunked_1", "span_1"}
    expected_pairs = {
        (case, reader, kernel)
        for case, case_info in expected_cases.items()
        for reader in expected_readers
        for kernel in case_info["kernels"]
    }
    paired_kernels = {
        "mixed-readme-length": ("current", "staged"),
        "mixed-roadmap-length": ("current", "staged"),
        "distance-readme-symbol-extra": ("current", "fused18"),
        "distance-roadmap-symbol-extra": ("current", "fused18"),
    }
    for artifact in artifacts:
        if artifact.name != "vort-deflate-extra-bits-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str, str]] = set()
        duplicate_pairs: set[tuple[str, str, str]] = set()
        unknown_pairs: set[tuple[str, str, str]] = set()
        by_key: dict[tuple[str, str, str], dict[str, str]] = {}
        positive_rows = 0
        shape_rows = 0
        throughput_rows = 0
        paired_checksum_rows = 0
        rows_by_case: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            case = str(row.get("case") or "")
            reader = str(row.get("reader") or "")
            kernel = str(row.get("kernel") or "")
            key = (case, reader, kernel)
            if key in expected_pairs:
                if key in seen:
                    duplicate_pairs.add(key)
                seen.add(key)
                by_key[key] = row
                rows_by_case.setdefault(case, []).append(row)
            else:
                unknown_pairs.add(key)
            try:
                bits = int(row.get("bits") or "-1")
                reads_per_iter = int(row.get("reads_per_iter") or "0")
                iterations = int(row.get("iterations") or "0")
                repeat = int(row.get("repeat") or "0")
                input_bytes = int(row.get("input_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                reads_per_s = float(row.get("reads_per_s") or "0")
                mib_per_s = float(row.get("mib_per_s") or "0")
            except ValueError:
                continue
            if all(value > 0 for value in (reads_per_iter, iterations, repeat, input_bytes, elapsed_ns, checksum)) and reads_per_s > 0.0 and mib_per_s > 0.0:
                positive_rows += 1
            expected_reads_per_s = (reads_per_iter * iterations) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            expected_mib_per_s = (input_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(reads_per_s - expected_reads_per_s) <= 0.05 and abs(mib_per_s - expected_mib_per_s) <= 0.01:
                throughput_rows += 1
            case_info = expected_cases.get(case)
            if case_info is not None and reader in expected_readers and kernel in case_info["kernels"] and bits == case_info["bits"]:
                shape_rows += 1
        checksum_matched_cases = 0
        for case, case_info in expected_cases.items():
            case_rows = rows_by_case.get(case, [])
            checksums = set()
            for row in case_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            expected_case_rows = len(expected_readers) * len(case_info["kernels"])
            if len(case_rows) == expected_case_rows and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_cases += 1
        for case, kernels in paired_kernels.items():
            lhs, rhs = kernels
            for reader in expected_readers:
                lhs_row = by_key.get((case, reader, lhs))
                rhs_row = by_key.get((case, reader, rhs))
                if lhs_row is not None and rhs_row is not None and lhs_row.get("checksum") == rhs_row.get("checksum"):
                    paired_checksum_rows += 1
        missing_pairs = sorted(f"{case}:{reader}:{kernel}" for case, reader, kernel in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{case}:{reader}:{kernel}" for case, reader, kernel in duplicate_pairs)
        unknown_pair_names = sorted(f"{case}:{reader}:{kernel}" for case, reader, kernel in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_cases == len(expected_cases)
            and paired_checksum_rows == len(paired_kernels) * len(expected_readers)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_cases": checksum_matched_cases,
            "paired_checksum_rows": paired_checksum_rows,
            "expected_paired_checksum_rows": len(paired_kernels) * len(expected_readers),
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "shape_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_cases": 0,
        "paired_checksum_rows": 0,
        "expected_paired_checksum_rows": len(paired_kernels) * len(expected_readers),
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def dictionary_decode_bench_health(artifacts: list[Path]) -> dict:
    expected_rows = {
        ("history-replay-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("history-replay-raw-dynamic-exact_alloc", "raw", "dynamic", "exact_alloc"),
        ("history-replay-raw-dynamic-into", "raw", "dynamic", "into"),
        ("history-replay-raw-best-alloc", "raw", "best", "alloc"),
        ("history-replay-zlib-fixed-alloc", "zlib", "fixed", "alloc"),
        ("history-replay-zlib-fixed-exact_alloc", "zlib", "fixed", "exact_alloc"),
        ("history-replay-zlib-fixed-into", "zlib", "fixed", "into"),
        ("history-replay-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("history-replay-zlib-dynamic-exact_alloc", "zlib", "dynamic", "exact_alloc"),
        ("history-replay-zlib-dynamic-into", "zlib", "dynamic", "into"),
        ("json-prefix-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("json-prefix-raw-dynamic-into", "raw", "dynamic", "into"),
        ("json-prefix-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("json-prefix-zlib-dynamic-into", "zlib", "dynamic", "into"),
        ("log-prefix-raw-dynamic-alloc", "raw", "dynamic", "alloc"),
        ("log-prefix-raw-dynamic-into", "raw", "dynamic", "into"),
        ("log-prefix-zlib-dynamic-alloc", "zlib", "dynamic", "alloc"),
        ("log-prefix-zlib-dynamic-into", "zlib", "dynamic", "into"),
    }
    for artifact in artifacts:
        if artifact.name != "vort-dictionary-decode-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str, str, str]] = set()
        duplicate_pairs: set[tuple[str, str, str, str]] = set()
        unknown_pairs: set[tuple[str, str, str, str]] = set()
        positive_rows = 0
        shape_rows = 0
        output_size_rows = 0
        throughput_rows = 0
        rows_by_payload: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            key = (
                str(row.get("case") or ""),
                str(row.get("format") or ""),
                str(row.get("encoder") or ""),
                str(row.get("mode") or ""),
            )
            if key in expected_rows:
                if key in seen:
                    duplicate_pairs.add(key)
                seen.add(key)
                shape_rows += 1
                case = key[0]
                for marker in ("-raw-", "-zlib-"):
                    if marker in case:
                        rows_by_payload.setdefault(case.split(marker, 1)[0], []).append(row)
                        break
            else:
                unknown_pairs.add(key)
            try:
                input_bytes = int(row.get("input_bytes") or "0")
                dict_bytes = int(row.get("dict_bytes") or "0")
                compressed_bytes = int(row.get("compressed_bytes") or "0")
                iterations = int(row.get("iterations") or "0")
                repeat = int(row.get("repeat") or "0")
                output_bytes = int(row.get("output_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                decode_mib_s = float(row.get("decode_mib_s") or "0")
            except ValueError:
                continue
            if all(value > 0 for value in (input_bytes, dict_bytes, compressed_bytes, iterations, repeat, output_bytes, elapsed_ns, checksum)) and decode_mib_s > 0.0:
                positive_rows += 1
            if input_bytes > 0 and iterations > 0 and output_bytes == input_bytes * iterations:
                output_size_rows += 1
            expected_decode_mib_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(decode_mib_s - expected_decode_mib_s) <= 0.01:
                throughput_rows += 1
        expected_payload_counts = {"history-replay": 10, "json-prefix": 4, "log-prefix": 4}
        checksum_matched_payloads = 0
        for payload, expected_count in expected_payload_counts.items():
            payload_rows = rows_by_payload.get(payload, [])
            checksums = set()
            for row in payload_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            if len(payload_rows) == expected_count and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_payloads += 1
        missing_pairs = sorted(":".join(key) for key in expected_rows - seen)
        duplicate_pair_names = sorted(":".join(key) for key in duplicate_pairs)
        unknown_pair_names = sorted(":".join(key) for key in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_rows)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and output_size_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_payloads == len(expected_payload_counts)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_rows),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "output_size_rows": output_size_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_payloads": checksum_matched_payloads,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_rows),
        "positive_rows": 0,
        "shape_rows": 0,
        "output_size_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_payloads": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def png_scanline_bench_health(artifacts: list[Path]) -> dict:
    expected_stages = {"none", "sub", "up", "average", "paeth"}
    expected_bpp = {"1", "2", "3", "4", "6", "8"}
    expected_pairs = {(stage, bpp) for stage in expected_stages for bpp in expected_bpp}
    for artifact in artifacts:
        if artifact.name != "vort-png-scanline-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str]] = set()
        duplicate_pairs: set[tuple[str, str]] = set()
        unknown_pairs: set[tuple[str, str]] = set()
        positive_rows = 0
        shape_rows = 0
        io_match_rows = 0
        throughput_rows = 0
        rows_by_bpp: dict[str, list[dict[str, str]]] = {}
        for row in rows:
            stage = str(row.get("stage") or "")
            bpp = str(row.get("bpp") or "")
            pair = (stage, bpp)
            if pair in expected_pairs:
                if pair in seen:
                    duplicate_pairs.add(pair)
                seen.add(pair)
                shape_rows += 1
                rows_by_bpp.setdefault(bpp, []).append(row)
            else:
                unknown_pairs.add(pair)
            try:
                iterations = int(row.get("iterations") or "0")
                repeat = int(row.get("repeat") or "0")
                input_bytes = int(row.get("input_bytes") or "0")
                output_bytes = int(row.get("output_bytes") or "0")
                elapsed_ns = int(row.get("elapsed_ns") or "0")
                checksum = int(row.get("checksum") or "0")
                output_mib_per_s = float(row.get("output_mib_per_s") or "0")
            except ValueError:
                continue
            if all(value > 0 for value in (iterations, repeat, input_bytes, output_bytes, elapsed_ns, checksum)) and output_mib_per_s > 0.0:
                positive_rows += 1
            if input_bytes > 0 and input_bytes == output_bytes:
                io_match_rows += 1
            expected_output_mib_per_s = (output_bytes / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0) if elapsed_ns > 0 else 0.0
            if abs(output_mib_per_s - expected_output_mib_per_s) <= 0.01:
                throughput_rows += 1
        checksum_matched_bpps = 0
        for bpp in expected_bpp:
            bpp_rows = rows_by_bpp.get(bpp, [])
            checksums = set()
            for row in bpp_rows:
                try:
                    checksums.add(int(row.get("checksum") or "0"))
                except ValueError:
                    checksums.add(0)
            if len(bpp_rows) == len(expected_stages) and len(checksums) == 1 and next(iter(checksums), 0) > 0:
                checksum_matched_bpps += 1
        missing_pairs = sorted(f"{stage}:{bpp}" for stage, bpp in expected_pairs - seen)
        duplicate_pair_names = sorted(f"{stage}:{bpp}" for stage, bpp in duplicate_pairs)
        unknown_pair_names = sorted(f"{stage}:{bpp}" for stage, bpp in unknown_pairs)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_pairs)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and shape_rows == row_count
            and io_match_rows == row_count
            and throughput_rows == row_count
            and checksum_matched_bpps == len(expected_bpp)
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_pairs),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "io_match_rows": io_match_rows,
            "throughput_rows": throughput_rows,
            "checksum_matched_bpps": checksum_matched_bpps,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_pairs),
        "positive_rows": 0,
        "shape_rows": 0,
        "io_match_rows": 0,
        "throughput_rows": 0,
        "checksum_matched_bpps": 0,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def chunked_zlib_bench_health(artifacts: list[Path]) -> dict:
    markdown = next((artifact for artifact in artifacts if artifact.name == "vort-chunked-zlib-bench-report.md"), None)
    expected_cases = {
        "png-rgb8-dynamic-64b": {
            "encoder": "best",
            "input_bytes": (96 * 3 + 1) * 64,
            "chunk_bytes": 64,
            "include_empty_chunks": "false",
            "direct_strategy": "stack-join",
        },
        "png-rgb8-dynamic-1b-empty": {
            "encoder": "best",
            "input_bytes": (48 * 3 + 1) * 48,
            "chunk_bytes": 1,
            "include_empty_chunks": "true",
            "direct_strategy": "stack-join",
        },
        "png-rgb8-literal-large-4k": {
            "encoder": "dynamic_literal",
            "input_bytes": (512 * 3 + 1) * 256,
            "chunk_bytes": 4096,
            "include_empty_chunks": "false",
            "direct_strategy": "span-reader",
        },
        "png-rgb8-match-large-4k": {
            "encoder": "best",
            "input_bytes": (512 * 3 + 1) * 256,
            "chunk_bytes": 4096,
            "include_empty_chunks": "false",
            "direct_strategy": "span-reader",
        },
        "png-rgba8-stored-256b": {
            "encoder": "stored",
            "input_bytes": (128 * 4 + 1) * 96,
            "chunk_bytes": 256,
            "include_empty_chunks": "false",
            "direct_strategy": "stored-direct",
        },
        "png-indexed-stored-1b-empty": {
            "encoder": "stored",
            "input_bytes": (96 + 1) * 64,
            "chunk_bytes": 1,
            "include_empty_chunks": "true",
            "direct_strategy": "stack-join",
        },
        "png-indexed-stored-7b-empty": {
            "encoder": "stored",
            "input_bytes": (257 + 1) * 48,
            "chunk_bytes": 7,
            "include_empty_chunks": "true",
            "direct_strategy": "stack-join",
        },
        "png-literal-16b": {
            "encoder": "dynamic_literal",
            "input_bytes": (80 * 3 + 1) * 80,
            "chunk_bytes": 16,
            "include_empty_chunks": "false",
            "direct_strategy": "stack-join",
        },
    }

    def expected_chunk_count(zlib_bytes: int, chunk_bytes: int, include_empty: bool) -> int:
        non_empty = max(1, (zlib_bytes + chunk_bytes - 1) // chunk_bytes)
        return non_empty * 2 + 1 if include_empty else non_empty

    def ratio_ok(row: dict[str, str], numerator: str, denominator: str, ratio_key: str) -> bool:
        try:
            reported = float(row.get(ratio_key) or "0")
            computed = float(row.get(numerator) or "0") / float(row.get(denominator) or "0")
        except (ValueError, ZeroDivisionError):
            return False
        return abs(reported - computed) <= 0.005

    def markdown_cells(line: str) -> list[str]:
        return [cell.strip() for cell in line.strip().strip("|").split("|")]

    def markdown_row_matches(row: dict[str, str], cells: list[str]) -> bool:
        if len(cells) != 18:
            return False
        try:
            int_fields = (
                ("input_bytes", 2),
                ("zlib_bytes", 3),
                ("chunk_bytes", 4),
                ("chunk_count", 5),
                ("iterations", 7),
                ("repeat", 8),
            )
            float_fields = (
                ("contiguous_mib_s", 9, 0.005),
                ("chunk_join_mib_s", 10, 0.005),
                ("chunk_direct_mib_s", 11, 0.005),
                ("chunk_exact_mib_s", 12, 0.005),
                ("direct_over_contiguous", 14, 0.001),
                ("direct_over_join", 15, 0.001),
                ("join_over_contiguous", 16, 0.001),
                ("exact_over_direct", 17, 0.001),
            )
            return (
                cells[0] == row.get("case")
                and cells[1] == row.get("encoder")
                and all(int(cells[index]) == int(row.get(field) or "0") for field, index in int_fields)
                and cells[6] == row.get("include_empty_chunks")
                and cells[13] == row.get("direct_strategy")
                and all(abs(float(cells[index]) - float(row.get(field) or "0")) <= tolerance for field, index, tolerance in float_fields)
            )
        except ValueError:
            return False

    def markdown_health(rows: list[dict[str, str]]) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        try:
            markdown_rows_by_case = {
                cells[0]: cells
                for line in markdown.read_text(errors="replace").splitlines()
                if line.startswith("| ")
                for cells in [markdown_cells(line)]
                if cells and cells[0] not in {"case", "---"}
            }
        except Exception:
            return (True, len(rows), 0, len(rows) or 1)
        matched = 0
        for row in rows:
            cells = markdown_rows_by_case.get(str(row.get("case") or ""))
            if cells is not None and markdown_row_matches(row, cells):
                matched += 1
        return (True, len(rows), matched, len(rows) - matched)

    for artifact in artifacts:
        if artifact.name != "vort-chunked-zlib-bench-report-repeat3.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[str] = set()
        duplicate_cases: set[str] = set()
        unknown_cases: set[str] = set()
        positive_rows = 0
        shape_rows = 0
        chunk_count_rows = 0
        ratio_rows = 0
        for row in rows:
            case = str(row.get("case") or "")
            expected = expected_cases.get(case)
            if expected is not None:
                if case in seen:
                    duplicate_cases.add(case)
                seen.add(case)
            elif case:
                unknown_cases.add(case)
            try:
                input_bytes = int(row.get("input_bytes") or "0")
                zlib_bytes = int(row.get("zlib_bytes") or "0")
                chunk_bytes = int(row.get("chunk_bytes") or "0")
                chunk_count = int(row.get("chunk_count") or "0")
                iterations = int(row.get("iterations") or "0")
                repeat = int(row.get("repeat") or "0")
                mix = int(row.get("mix") or "0")
                contiguous_mib_s = float(row.get("contiguous_mib_s") or "0")
                chunk_join_mib_s = float(row.get("chunk_join_mib_s") or "0")
                chunk_direct_mib_s = float(row.get("chunk_direct_mib_s") or "0")
                chunk_exact_mib_s = float(row.get("chunk_exact_mib_s") or "0")
                direct_over_contiguous = float(row.get("direct_over_contiguous") or "0")
                direct_over_join = float(row.get("direct_over_join") or "0")
                join_over_contiguous = float(row.get("join_over_contiguous") or "0")
                exact_over_direct = float(row.get("exact_over_direct") or "0")
            except ValueError:
                continue
            if (
                expected is not None
                and row.get("encoder") == expected["encoder"]
                and input_bytes == expected["input_bytes"]
                and chunk_bytes == expected["chunk_bytes"]
                and row.get("include_empty_chunks") == expected["include_empty_chunks"]
                and row.get("direct_strategy") == expected["direct_strategy"]
            ):
                shape_rows += 1
            if all(value > 0 for value in (zlib_bytes, chunk_count, iterations, repeat, mix)) and all(
                value > 0.0
                for value in (
                    contiguous_mib_s,
                    chunk_join_mib_s,
                    chunk_direct_mib_s,
                    chunk_exact_mib_s,
                    direct_over_contiguous,
                    direct_over_join,
                    join_over_contiguous,
                    exact_over_direct,
                )
            ):
                positive_rows += 1
            if chunk_bytes > 0 and zlib_bytes >= 6 and chunk_count == expected_chunk_count(zlib_bytes, chunk_bytes, row.get("include_empty_chunks") == "true"):
                chunk_count_rows += 1
            if (
                ratio_ok(row, "chunk_direct_mib_s", "contiguous_mib_s", "direct_over_contiguous")
                and ratio_ok(row, "chunk_direct_mib_s", "chunk_join_mib_s", "direct_over_join")
                and ratio_ok(row, "chunk_join_mib_s", "contiguous_mib_s", "join_over_contiguous")
                and ratio_ok(row, "chunk_exact_mib_s", "chunk_direct_mib_s", "exact_over_direct")
            ):
                ratio_rows += 1
        missing_cases = sorted(set(expected_cases) - seen)
        duplicate_case_names = sorted(duplicate_cases)
        unknown_case_names = sorted(unknown_cases)
        row_count = len(rows)
        markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_health(rows)
        healthy = (
            row_count == len(expected_cases)
            and not missing_cases
            and not duplicate_case_names
            and not unknown_case_names
            and positive_rows == row_count
            and shape_rows == row_count
            and chunk_count_rows == row_count
            and ratio_rows == row_count
            and markdown_present
            and markdown_rows == row_count
            and markdown_unmatched == 0
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_cases),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "chunk_count_rows": chunk_count_rows,
            "ratio_rows": ratio_rows,
            "missing_cases": missing_cases,
            "duplicate_cases": duplicate_case_names,
            "unknown_cases": unknown_case_names,
            "markdown_present": markdown_present,
            "markdown_rows": markdown_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_cases),
        "positive_rows": 0,
        "shape_rows": 0,
        "chunk_count_rows": 0,
        "ratio_rows": 0,
        "missing_cases": [],
        "duplicate_cases": [],
        "unknown_cases": [],
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
    }


def png_streaming_zlib_bench_health(artifacts: list[Path]) -> dict:
    expected_cases = {
        "png-stream-rle-dynamic": {
            "encoder": "dynamic",
            "pattern": "zero",
            "width": 2048,
            "height": 64,
            "row_bytes": 2048,
            "image_bytes": 131072,
            "chunk_bytes": 64,
        },
        "png-stream-up-filter-dynamic": {
            "encoder": "dynamic",
            "pattern": "vertical_delta",
            "width": 2048,
            "height": 64,
            "row_bytes": 2048,
            "image_bytes": 131072,
            "chunk_bytes": 64,
        },
        "png-stream-sub-filter-dynamic": {
            "encoder": "dynamic",
            "pattern": "horizontal_delta",
            "width": 2048,
            "height": 64,
            "row_bytes": 2048,
            "image_bytes": 131072,
            "chunk_bytes": 64,
        },
        "png-stream-average-filter-dynamic": {
            "encoder": "dynamic",
            "pattern": "average_delta",
            "width": 2048,
            "height": 64,
            "row_bytes": 2048,
            "image_bytes": 131072,
            "chunk_bytes": 64,
        },
        "png-stream-paeth-filter-dynamic": {
            "encoder": "dynamic",
            "pattern": "paeth_delta",
            "width": 2048,
            "height": 64,
            "row_bytes": 2048,
            "image_bytes": 131072,
            "chunk_bytes": 64,
        },
        "png-stream-paeth-rgba8-dynamic": {
            "encoder": "dynamic",
            "pattern": "paeth_delta",
            "width": 1024,
            "height": 64,
            "row_bytes": 4096,
            "image_bytes": 262144,
            "chunk_bytes": 64,
        },
        "png-stream-small-distance-dynamic": {
            "encoder": "dynamic",
            "pattern": "abcd",
            "width": 1024,
            "height": 64,
            "row_bytes": 4096,
            "image_bytes": 262144,
            "chunk_bytes": 64,
        },
        "png-stream-row-repeat-dynamic": {
            "encoder": "dynamic",
            "pattern": "repeated_row",
            "width": 1024,
            "height": 96,
            "row_bytes": 3072,
            "image_bytes": 294912,
            "chunk_bytes": 32,
        },
        "png-stream-row-repeat-fixed": {
            "encoder": "fixed",
            "pattern": "repeated_row",
            "width": 1024,
            "height": 64,
            "row_bytes": 3072,
            "image_bytes": 196608,
            "chunk_bytes": 32,
        },
        "png-stream-wide-rle-dynamic": {
            "encoder": "dynamic",
            "pattern": "zero",
            "width": 65536,
            "height": 16,
            "row_bytes": 65536,
            "image_bytes": 1048576,
            "chunk_bytes": 64,
        },
    }

    def ratio_ok(row: dict[str, str]) -> bool:
        try:
            reported = float(row.get("chunked_over_contiguous") or "0")
            computed = float(row.get("chunked_mib_s") or "0") / float(row.get("contiguous_mib_s") or "0")
        except (ValueError, ZeroDivisionError):
            return False
        return abs(reported - computed) <= 0.005

    for artifact in artifacts:
        if artifact.name != "vort-png-streaming-zlib-bench-report-repeat3.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[str] = set()
        duplicate_cases: set[str] = set()
        unknown_cases: set[str] = set()
        positive_rows = 0
        shape_rows = 0
        image_size_rows = 0
        chunk_count_rows = 0
        ratio_rows = 0
        for row in rows:
            case = str(row.get("case") or "")
            expected = expected_cases.get(case)
            if expected is not None:
                if case in seen:
                    duplicate_cases.add(case)
                seen.add(case)
            elif case:
                unknown_cases.add(case)
            try:
                width = int(row.get("width") or "0")
                height = int(row.get("height") or "0")
                row_bytes = int(row.get("row_bytes") or "0")
                image_bytes = int(row.get("image_bytes") or "0")
                zlib_bytes = int(row.get("zlib_bytes") or "0")
                chunk_bytes = int(row.get("chunk_bytes") or "0")
                chunk_count = int(row.get("chunk_count") or "0")
                iterations = int(row.get("iterations") or "0")
                repeat = int(row.get("repeat") or "0")
                mix = int(row.get("mix") or "0")
                contiguous_mib_s = float(row.get("contiguous_mib_s") or "0")
                chunked_mib_s = float(row.get("chunked_mib_s") or "0")
                chunked_over_contiguous = float(row.get("chunked_over_contiguous") or "0")
            except ValueError:
                continue
            if (
                expected is not None
                and row.get("encoder") == expected["encoder"]
                and row.get("pattern") == expected["pattern"]
                and width == expected["width"]
                and height == expected["height"]
                and row_bytes == expected["row_bytes"]
                and image_bytes == expected["image_bytes"]
                and chunk_bytes == expected["chunk_bytes"]
            ):
                shape_rows += 1
            if row_bytes > 0 and height > 0 and row_bytes * height == image_bytes:
                image_size_rows += 1
            if all(value > 0 for value in (zlib_bytes, chunk_count, iterations, repeat, mix)) and all(
                value > 0.0 for value in (contiguous_mib_s, chunked_mib_s, chunked_over_contiguous)
            ):
                positive_rows += 1
            if zlib_bytes > 0 and chunk_bytes > 0 and chunk_count == (zlib_bytes + chunk_bytes - 1) // chunk_bytes:
                chunk_count_rows += 1
            if ratio_ok(row):
                ratio_rows += 1
        missing_cases = sorted(set(expected_cases) - seen)
        duplicate_case_names = sorted(duplicate_cases)
        unknown_case_names = sorted(unknown_cases)
        row_count = len(rows)
        healthy = (
            row_count == len(expected_cases)
            and not missing_cases
            and not duplicate_case_names
            and not unknown_case_names
            and positive_rows == row_count
            and shape_rows == row_count
            and image_size_rows == row_count
            and chunk_count_rows == row_count
            and ratio_rows == row_count
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_cases),
            "positive_rows": positive_rows,
            "shape_rows": shape_rows,
            "image_size_rows": image_size_rows,
            "chunk_count_rows": chunk_count_rows,
            "ratio_rows": ratio_rows,
            "missing_cases": missing_cases,
            "duplicate_cases": duplicate_case_names,
            "unknown_cases": unknown_case_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_cases),
        "positive_rows": 0,
        "shape_rows": 0,
        "image_size_rows": 0,
        "chunk_count_rows": 0,
        "ratio_rows": 0,
        "missing_cases": [],
        "duplicate_cases": [],
        "unknown_cases": [],
    }


def deflate_dynamic_decode_profile_health(artifacts: list[Path]) -> dict:
    required_cases = {"README.md", "docs/roadmap.md", "chunked-window-match"}
    class_names = {"rle", "small_distance", "non_overlapping", "overlapping"}

    def parse_int(row: dict[str, str], key: str) -> int:
        return int(row.get(key) or "0")

    def parse_float(row: dict[str, str], key: str) -> float:
        return float(row.get(key) or "0")

    def parse_hist(row: dict[str, str], key: str, expected_len: int) -> list[int]:
        parts = str(row.get(key) or "").split(";")
        if len(parts) != expected_len:
            raise ValueError(key)
        return [int(part) for part in parts]

    def basic_positive(row: dict[str, str]) -> bool:
        positive_int_fields = ("input_bytes", "raw_bytes", "payload_ns", "output_bytes", "literal_symbols", "literal_fast_hits", "literal_lookup_covered", "literal_lookup_size", "distance_lookup_covered", "distance_lookup_size", "mix")
        return all(parse_int(row, field) > 0 for field in positive_int_fields)

    def histogram_ok(row: dict[str, str]) -> bool:
        length_hist = parse_hist(row, "length_symbol_histogram", 29)
        distance_hist = parse_hist(row, "distance_symbol_histogram", 30)
        length_width_reads = parse_hist(row, "length_extra_width_reads", 14)
        distance_width_reads = parse_hist(row, "distance_extra_width_reads", 14)
        length_width_bits = parse_hist(row, "length_extra_width_bits", 14)
        distance_width_bits = parse_hist(row, "distance_extra_width_bits", 14)
        return (
            sum(length_hist) == parse_int(row, "length_symbols")
            and sum(distance_hist) == parse_int(row, "distance_symbols")
            and sum(length_width_reads) == parse_int(row, "length_symbols")
            and sum(distance_width_reads) == parse_int(row, "distance_symbols")
            and sum(length_width_bits) == parse_int(row, "length_extra_bits")
            and sum(distance_width_bits) == parse_int(row, "distance_extra_bits")
            and parse_int(row, "distance_code_plus_extra_bits") == parse_int(row, "distance_code_bits") + parse_int(row, "distance_extra_bits")
        )

    def lookup_ok(row: dict[str, str]) -> bool:
        literal_lookup_bits = parse_int(row, "literal_lookup_bits")
        literal_covered = parse_int(row, "literal_lookup_covered")
        literal_size = parse_int(row, "literal_lookup_size")
        distance_covered = parse_int(row, "distance_lookup_covered")
        distance_size = parse_int(row, "distance_lookup_size")
        literal_ratio = parse_float(row, "literal_lookup_coverage_ratio")
        distance_ratio = parse_float(row, "distance_lookup_coverage_ratio")
        return (
            literal_size == (1 << literal_lookup_bits)
            and distance_size == 256
            and 0 < literal_covered <= literal_size
            and 0 < distance_covered <= distance_size
            and 0.0 < literal_ratio <= 1.0
            and 0.0 < distance_ratio <= 1.0
        )

    def match_class_ok(row: dict[str, str]) -> bool:
        class_counts = [
            parse_int(row, "match_rle_count"),
            parse_int(row, "match_small_distance_count"),
            parse_int(row, "match_non_overlapping_count"),
            parse_int(row, "match_overlapping_count"),
        ]
        class_bytes = [
            parse_int(row, "match_rle_bytes"),
            parse_int(row, "match_small_distance_bytes"),
            parse_int(row, "match_non_overlapping_bytes"),
            parse_int(row, "match_overlapping_bytes"),
        ]
        dominant = str(row.get("dominant_match_class") or "")
        if dominant not in class_names:
            return False
        dominant_index = ["rle", "small_distance", "non_overlapping", "overlapping"].index(dominant)
        if class_bytes[dominant_index] != max(class_bytes):
            return False
        ratio_fields = (
            "dominant_match_byte_ratio",
            "match_rle_byte_ratio",
            "match_small_distance_byte_ratio",
            "match_non_overlapping_byte_ratio",
            "match_overlapping_byte_ratio",
        )
        return (
            sum(class_counts) == parse_int(row, "distance_symbols")
            and sum(class_bytes) == parse_int(row, "match_bytes")
            and all(0.0 <= parse_float(row, field) <= 1.0 for field in ratio_fields)
        )

    def ratio_accounting_ok(row: dict[str, str]) -> bool:
        def ratio_close(field: str, numerator: int, denominator: int) -> bool:
            expected = (float(numerator) / float(denominator)) if denominator else 0.0
            return abs(parse_float(row, field) - expected) <= 0.000001

        class_order = ("rle", "small_distance", "non_overlapping", "overlapping")
        class_counts = [parse_int(row, f"match_{name}_count") for name in class_order]
        class_bytes = [parse_int(row, f"match_{name}_bytes") for name in class_order]
        match_bytes = parse_int(row, "match_bytes")
        distance_symbols = parse_int(row, "distance_symbols")
        literal_reads = parse_int(row, "literal_fast_hits") + parse_int(row, "literal_fast_misses")
        distance_reads = parse_int(row, "distance_fast_hits") + parse_int(row, "distance_fast_misses")
        length_class_extra_bits = parse_hist(row, "match_class_length_extra_bits", 4)
        distance_class_extra_bits = parse_hist(row, "match_class_distance_extra_bits", 4)
        distance_class_code_bits = parse_hist(row, "match_class_distance_code_bits", 4)
        distance_code_plus_fields = (
            "match_rle_distance_code_plus_extra_bits_per_match",
            "match_small_distance_code_plus_extra_bits_per_match",
            "match_non_overlapping_distance_code_plus_extra_bits_per_match",
            "match_overlapping_distance_code_plus_extra_bits_per_match",
        )

        checks = [
            ratio_close("literal_lookup_coverage_ratio", parse_int(row, "literal_lookup_covered"), parse_int(row, "literal_lookup_size")),
            ratio_close("distance_lookup_coverage_ratio", parse_int(row, "distance_lookup_covered"), parse_int(row, "distance_lookup_size")),
            ratio_close("literal_fast_miss_ratio", parse_int(row, "literal_fast_misses"), literal_reads),
            ratio_close("distance_fast_miss_ratio", parse_int(row, "distance_fast_misses"), distance_reads),
            ratio_close("extra_bits_per_match", parse_int(row, "length_extra_bits") + parse_int(row, "distance_extra_bits"), distance_symbols),
            ratio_close("distance_code_plus_extra_bits_per_match", parse_int(row, "distance_code_plus_extra_bits"), distance_symbols),
            ratio_close("dominant_match_byte_ratio", max(class_bytes), match_bytes),
        ]
        for index, class_name in enumerate(class_order):
            extra_bits = length_class_extra_bits[index] + distance_class_extra_bits[index]
            checks.extend(
                [
                    ratio_close(f"match_{class_name}_byte_ratio", class_bytes[index], match_bytes),
                    ratio_close(f"match_{class_name}_extra_bits_per_match", extra_bits, class_counts[index]),
                    ratio_close(f"match_{class_name}_extra_bits_per_byte", extra_bits, class_bytes[index]),
                    ratio_close(distance_code_plus_fields[index], distance_class_code_bits[index] + distance_class_extra_bits[index], class_counts[index]),
                ]
            )
        return all(checks)

    for artifact in artifacts:
        if artifact.name != "vort-deflate-dynamic-decode-profile.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        by_case: dict[str, dict[str, str]] = {}
        duplicate_cases: set[str] = set()
        for row in rows:
            case = str(row.get("case") or "")
            if not case:
                continue
            if case in by_case:
                duplicate_cases.add(case)
            else:
                by_case[case] = row
        missing_cases = sorted(required_cases - set(by_case))
        duplicate_case_names = sorted(duplicate_cases)
        required_rows = [by_case[case] for case in sorted(required_cases) if case in by_case]
        positive_rows = 0
        histogram_rows = 0
        lookup_rows = 0
        match_class_rows = 0
        ratio_rows = 0
        for row in required_rows:
            try:
                if basic_positive(row):
                    positive_rows += 1
                if histogram_ok(row):
                    histogram_rows += 1
                if lookup_ok(row):
                    lookup_rows += 1
                if match_class_ok(row):
                    match_class_rows += 1
                if ratio_accounting_ok(row):
                    ratio_rows += 1
            except (ValueError, OverflowError):
                continue
        chunked = by_case.get("chunked-window-match")
        chunked_window_rows = 0
        if chunked is not None:
            try:
                if (
                    parse_int(chunked, "input_bytes") == (512 * 3 + 1) * 256
                    and parse_int(chunked, "raw_bytes") > 64 * 1024
                    and parse_int(chunked, "match_bytes") > parse_int(chunked, "literal_symbols")
                    and chunked.get("dominant_match_class") == "non_overlapping"
                ):
                    chunked_window_rows = 1
            except ValueError:
                chunked_window_rows = 0
        required_count = len(required_cases)
        healthy = (
            len(rows) >= required_count
            and not missing_cases
            and not duplicate_case_names
            and positive_rows == required_count
            and histogram_rows == required_count
            and lookup_rows == required_count
            and match_class_rows == required_count
            and ratio_rows == required_count
            and chunked_window_rows == 1
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": len(rows),
            "required_rows": required_count,
            "positive_rows": positive_rows,
            "histogram_rows": histogram_rows,
            "lookup_rows": lookup_rows,
            "match_class_rows": match_class_rows,
            "ratio_rows": ratio_rows,
            "chunked_window_rows": chunked_window_rows,
            "missing_cases": missing_cases,
            "duplicate_cases": duplicate_case_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "required_rows": len(required_cases),
        "positive_rows": 0,
        "histogram_rows": 0,
        "lookup_rows": 0,
        "match_class_rows": 0,
        "ratio_rows": 0,
        "chunked_window_rows": 0,
        "missing_cases": [],
        "duplicate_cases": [],
    }


def native_library_bench_health(artifacts: list[Path]) -> dict:
    expected_codecs = {"lz4", "zstd"}
    expected_cases = {"text", "structured", "repetitive"}
    base_modes = {"one_shot", "incremental", "incremental_direct", "incremental_fallback"}
    decode_modes = {"lib_decode", "native_lib_decode"}
    expected_extra_rows = {
        ("lz4", "chain_depth_0", "chain_depth"),
        ("lz4", "chain_depth_default", "chain_depth"),
        ("zstd", "match_budget_0", "mixed_budget"),
        ("zstd", "match_budget_full", "mixed_budget"),
        ("zstd", "high_byte_binary", "high_byte_binary"),
        ("lz4", "lib_generated", "lib_generated"),
        ("zstd", "lib_generated", "lib_generated"),
        ("lz4", "lib_generated_no_size", "lib_generated_no_size"),
        ("zstd", "lib_generated_no_size", "lib_generated_no_size"),
        ("lz4", "lib_generated_checksum", "lib_generated_checksum"),
        ("zstd", "lib_generated_checksum", "lib_generated_checksum"),
        ("lz4", "lib_generated_no_size_checksum", "lib_generated_no_size_checksum"),
        ("zstd", "lib_generated_no_size_checksum", "lib_generated_no_size_checksum"),
        ("lz4", "lib_generated_independent", "lib_generated_independent"),
        ("lz4", "lib_generated_independent_no_size_checksum", "lib_generated_independent_no_size_checksum"),
        ("zstd", "sequence_huffman_literals_plain", "sequence_huffman_literals"),
        ("zstd", "sequence_huffman_literals", "sequence_huffman_literals"),
        ("lz4", "dictionary_plain", "dictionary"),
        ("lz4", "dictionary", "dictionary"),
        ("zstd", "dictionary_plain", "dictionary"),
        ("zstd", "dictionary", "dictionary"),
        ("lz4", "trained_dictionary_plain", "trained_dictionary"),
        ("lz4", "trained_dictionary", "trained_dictionary"),
        ("zstd", "trained_dictionary_plain", "trained_dictionary"),
        ("zstd", "trained_dictionary", "trained_dictionary"),
        ("lz4", "dictionary_set_plain", "dictionary_set"),
        ("lz4", "dictionary_set", "dictionary_set"),
        ("zstd", "dictionary_set_plain", "dictionary_set"),
        ("zstd", "dictionary_set", "dictionary_set"),
        ("lz4", "dictionary_set_chunked_plain", "dictionary_set_chunked"),
        ("lz4", "dictionary_set_chunked", "dictionary_set_chunked"),
        ("zstd", "dictionary_set_chunked_plain", "dictionary_set_chunked"),
        ("zstd", "dictionary_set_chunked", "dictionary_set_chunked"),
        ("lz4", "dictionary_set_chunked_append_plain", "dictionary_set_chunked_append"),
        ("lz4", "dictionary_set_chunked_append", "dictionary_set_chunked_append"),
        ("zstd", "dictionary_set_chunked_append_plain", "dictionary_set_chunked_append"),
        ("zstd", "dictionary_set_chunked_append", "dictionary_set_chunked_append"),
        ("lz4", "dictionary_set_chunked_append_exact_plain", "dictionary_set_chunked_append_exact"),
        ("lz4", "dictionary_set_chunked_append_exact", "dictionary_set_chunked_append_exact"),
        ("zstd", "dictionary_set_chunked_append_exact_plain", "dictionary_set_chunked_append_exact"),
        ("zstd", "dictionary_set_chunked_append_exact", "dictionary_set_chunked_append_exact"),
        ("lz4", "dictionary_set_reusable_plain", "dictionary_set_reusable"),
        ("lz4", "dictionary_set_reusable", "dictionary_set_reusable"),
        ("zstd", "dictionary_set_reusable_plain", "dictionary_set_reusable"),
        ("zstd", "dictionary_set_reusable", "dictionary_set_reusable"),
        ("lz4", "dictionary_set_reusable_append_exact_plain", "dictionary_set_reusable_append_exact"),
        ("lz4", "dictionary_set_reusable_append_exact", "dictionary_set_reusable_append_exact"),
        ("zstd", "dictionary_set_reusable_append_exact_plain", "dictionary_set_reusable_append_exact"),
        ("zstd", "dictionary_set_reusable_append_exact", "dictionary_set_reusable_append_exact"),
        ("lz4", "dictionary_set_direct_plain", "dictionary_set_direct"),
        ("lz4", "dictionary_set_direct", "dictionary_set_direct"),
        ("zstd", "dictionary_set_direct_plain", "dictionary_set_direct"),
        ("zstd", "dictionary_set_direct", "dictionary_set_direct"),
        ("lz4", "dictionary_set_fallback_plain", "dictionary_set_fallback"),
        ("lz4", "dictionary_set_fallback", "dictionary_set_fallback"),
        ("zstd", "dictionary_set_fallback_plain", "dictionary_set_fallback"),
        ("zstd", "dictionary_set_fallback", "dictionary_set_fallback"),
    }
    expected_rows = {
        (codec, mode, case)
        for codec in expected_codecs
        for mode in base_modes
        for case in expected_cases
    } | {
        (codec, mode, case)
        for codec in expected_codecs
        for mode in decode_modes
        for case in expected_cases
    } | expected_extra_rows

    def row_int(row: dict[str, str], key: str) -> int:
        return int(row.get(key) or "0")

    def row_float(row: dict[str, str], key: str) -> float:
        return float(row.get(key) or "0")

    def throughput_ok(row: dict[str, str], key: str, ns_key: str) -> bool:
        input_bytes = row_int(row, "input_bytes")
        iterations = row_int(row, "iterations")
        elapsed_ns = row_int(row, ns_key)
        reported = row_float(row, key)
        expected = (input_bytes * iterations / (1024.0 * 1024.0)) / (elapsed_ns / 1_000_000_000.0)
        return abs(reported - expected) <= max(0.02, expected * 0.0005)

    def encoded_less(rows_by_id: dict[tuple[str, str, str], dict[str, str]], lhs: tuple[str, str, str], rhs: tuple[str, str, str]) -> bool:
        left = rows_by_id.get(lhs)
        right = rows_by_id.get(rhs)
        if left is None or right is None:
            return False
        return row_int(left, "encoded_bytes") < row_int(right, "encoded_bytes")

    improvement_pairs = [
        (("lz4", "chain_depth_default", "chain_depth"), ("lz4", "chain_depth_0", "chain_depth")),
        (("zstd", "match_budget_full", "mixed_budget"), ("zstd", "match_budget_0", "mixed_budget")),
        (("zstd", "sequence_huffman_literals", "sequence_huffman_literals"), ("zstd", "sequence_huffman_literals_plain", "sequence_huffman_literals")),
    ]
    for codec in ("lz4", "zstd"):
        for dictionary_case in ("dictionary", "trained_dictionary", "dictionary_set", "dictionary_set_chunked", "dictionary_set_chunked_append", "dictionary_set_chunked_append_exact", "dictionary_set_reusable", "dictionary_set_reusable_append_exact", "dictionary_set_direct", "dictionary_set_fallback"):
            improvement_pairs.append(((codec, dictionary_case, dictionary_case), (codec, f"{dictionary_case}_plain", dictionary_case)))

    compression_rows = [
        ("zstd", "high_byte_binary", "high_byte_binary"),
        *[(codec, case, case) for codec in ("lz4", "zstd") for case in ("lib_generated", "lib_generated_no_size", "lib_generated_checksum", "lib_generated_no_size_checksum")],
        ("lz4", "lib_generated_independent", "lib_generated_independent"),
        ("lz4", "lib_generated_independent_no_size_checksum", "lib_generated_independent_no_size_checksum"),
        *[(codec, mode, case) for codec in expected_codecs for mode in decode_modes for case in expected_cases],
    ]
    expected_improvement_checks = len(improvement_pairs) + len(compression_rows)

    for artifact in artifacts:
        if artifact.name != "vort-native-library-bench.csv":
            continue
        try:
            with artifact.open(newline="") as f:
                rows = list(csv.DictReader(f))
        except Exception:
            rows = []
        seen: set[tuple[str, str, str]] = set()
        duplicate_pairs: set[tuple[str, str, str]] = set()
        unknown_pairs: set[tuple[str, str, str]] = set()
        rows_by_id: dict[tuple[str, str, str], dict[str, str]] = {}
        positive_rows = 0
        throughput_rows = 0
        iteration_rows = 0
        first_iterations: int | None = None
        for row in rows:
            identity = (str(row.get("codec") or ""), str(row.get("mode") or ""), str(row.get("case") or ""))
            if identity in expected_rows:
                if identity in seen:
                    duplicate_pairs.add(identity)
                else:
                    rows_by_id[identity] = row
                seen.add(identity)
            else:
                unknown_pairs.add(identity)
            try:
                input_bytes = row_int(row, "input_bytes")
                encoded_bytes = row_int(row, "encoded_bytes")
                iterations = row_int(row, "iterations")
                encode_ns = row_int(row, "encode_ns")
                decode_ns = row_int(row, "decode_ns")
                checksum = row_int(row, "checksum")
                encode_mib_s = row_float(row, "encode_mib_s")
                decode_mib_s = row_float(row, "decode_mib_s")
            except ValueError:
                continue
            if all(value > 0 for value in (input_bytes, encoded_bytes, iterations, encode_ns, decode_ns, checksum)) and encode_mib_s > 0.0 and decode_mib_s > 0.0 and encoded_bytes > 8:
                positive_rows += 1
            if throughput_ok(row, "encode_mib_s", "encode_ns") and throughput_ok(row, "decode_mib_s", "decode_ns"):
                throughput_rows += 1
            if first_iterations is None:
                first_iterations = iterations
            if iterations == first_iterations:
                iteration_rows += 1
        missing_pairs = sorted(":".join(identity) for identity in expected_rows - seen)
        duplicate_pair_names = sorted(":".join(identity) for identity in duplicate_pairs)
        unknown_pair_names = sorted(":".join(identity) for identity in unknown_pairs)
        shape_rows = len(seen)
        improvement_checks = 0
        for lhs, rhs in improvement_pairs:
            if encoded_less(rows_by_id, lhs, rhs):
                improvement_checks += 1
        for identity in compression_rows:
            row = rows_by_id.get(identity)
            if row is not None and row_int(row, "encoded_bytes") < row_int(row, "input_bytes"):
                improvement_checks += 1
        row_count = len(rows)
        healthy = (
            row_count == len(expected_rows)
            and shape_rows == len(expected_rows)
            and not missing_pairs
            and not duplicate_pair_names
            and not unknown_pair_names
            and positive_rows == row_count
            and throughput_rows == row_count
            and iteration_rows == row_count
            and improvement_checks == expected_improvement_checks
        )
        return {
            "present": True,
            "healthy": healthy,
            "row_count": row_count,
            "expected_rows": len(expected_rows),
            "positive_rows": positive_rows,
            "throughput_rows": throughput_rows,
            "iteration_rows": iteration_rows,
            "improvement_checks": improvement_checks,
            "expected_improvement_checks": expected_improvement_checks,
            "missing_pairs": missing_pairs,
            "duplicate_pairs": duplicate_pair_names,
            "unknown_pairs": unknown_pair_names,
        }
    return {
        "present": False,
        "healthy": False,
        "row_count": 0,
        "expected_rows": len(expected_rows),
        "positive_rows": 0,
        "throughput_rows": 0,
        "iteration_rows": 0,
        "improvement_checks": 0,
        "expected_improvement_checks": expected_improvement_checks,
        "missing_pairs": [],
        "duplicate_pairs": [],
        "unknown_pairs": [],
    }


def zstd_compare_health(artifacts: list[Path]) -> dict:
    compare = None
    standard = None
    sweep = None
    csv_artifacts: dict[str, Path] = {}
    markdown_artifacts: dict[str, Path] = {}
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.zstd_compare_gate":
            if artifact.name == "vort-zstd-compare-gate.json":
                compare = data
            elif artifact.name == "vort-zstd-compare-standard-gate.json":
                standard = data
        elif data.get("schema") == "vort.zstd_compare_block_sweep_gate" and artifact.name == "vort-zstd-compare-block-sweep-gate.json":
            sweep = data
        elif artifact.name == "vort-zstd-compare.csv":
            csv_artifacts["compare"] = artifact
        elif artifact.name == "vort-zstd-compare-standard.csv":
            csv_artifacts["standard"] = artifact
        elif artifact.name == "vort-zstd-compare-block-sweep.csv":
            csv_artifacts["sweep"] = artifact
        elif artifact.name == "vort-zstd-compare.md":
            markdown_artifacts["compare"] = artifact
        elif artifact.name == "vort-zstd-compare-standard.md":
            markdown_artifacts["standard"] = artifact
        elif artifact.name == "vort-zstd-compare-block-sweep.md":
            markdown_artifacts["sweep"] = artifact

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

    def close(actual: float, expected: float, tolerance: float = 0.0001) -> bool:
        return abs(actual - expected) <= tolerance

    def csv_rows_for(kind: str) -> list[dict[str, str]]:
        artifact = csv_artifacts.get(kind)
        if artifact is None:
            return []
        try:
            with artifact.open(newline="") as f:
                return list(csv.DictReader(f))
        except Exception:
            return []

    def compare_csv_mismatches(rows: list[dict[str, str]], gate: dict | None) -> int:
        if not isinstance(gate, dict):
            return 1
        mismatches = 0
        data_rows = [row for row in rows if row.get("path") != "TOTAL"]
        total_rows = [row for row in rows if row.get("path") == "TOTAL"]
        if len(rows) != int_field(gate, "rows"):
            mismatches += 1
        if len(data_rows) != int_field(gate, "data_rows"):
            mismatches += 1
        if len(total_rows) != 1:
            return mismatches + 1
        total = total_rows[0]
        float_pairs = (
            ("total_native_ratio", "vort_native_over_zstd"),
            ("total_native_stream_ratio", "vort_native_stream_over_zstd"),
            ("total_native_best_ratio", "vort_native_best_over_zstd"),
            ("total_vort_decode_vs_zstd", "vort_decode_vs_zstd"),
            ("total_stream_over_native_best", "vort_stream_over_native_best"),
            ("total_embedded_over_native_stream", "vort_embedded_over_native_stream"),
            ("total_embedded_over_native_best", "vort_embedded_over_native_best"),
        )
        for gate_field, csv_field in float_pairs:
            if gate_field in gate:
                try:
                    if not close(float(total.get(csv_field) or "0"), float_field(gate, gate_field)):
                        mismatches += 1
                except ValueError:
                    mismatches += 1
        int_pairs = (
            ("native_block_len", "native_block_len"),
            ("decode_repeats", "decode_repeats"),
            ("total_stream_over_native_best_bytes", "vort_stream_over_native_best_bytes"),
            ("total_embedded_over_native_stream_bytes", "vort_embedded_over_native_stream_bytes"),
            ("total_embedded_over_native_best_bytes", "vort_embedded_over_native_best_bytes"),
        )
        for gate_field, csv_field in int_pairs:
            if gate_field in gate:
                try:
                    if int(total.get(csv_field) or "0") != int_field(gate, gate_field):
                        mismatches += 1
                except ValueError:
                    mismatches += 1
        for field in ("source_mode", "size_mode", "case_limit", "optimize"):
            if str(total.get(field) or "") != str(gate.get(field) or ""):
                mismatches += 1
        return mismatches

    def sweep_csv_mismatches(rows: list[dict[str, str]], gate: dict | None) -> int:
        if not isinstance(gate, dict):
            return 1
        mismatches = 0
        data_rows = [row for row in rows if row.get("path") != "TOTAL"]
        total_rows = [row for row in rows if row.get("path") == "TOTAL"]
        if len(rows) != int_field(gate, "rows"):
            mismatches += 1
        if len(data_rows) != int_field(gate, "data_rows"):
            mismatches += 1
        if len(total_rows) != int_field(gate, "total_rows"):
            mismatches += 1
        paths = {row.get("path", "") for row in data_rows}
        block_lens: set[int] = set()
        for row in rows:
            try:
                block_lens.add(int(row.get("block_len") or "0"))
            except ValueError:
                mismatches += 1
        if len(paths) != int_field(gate, "path_count"):
            mismatches += 1
        if len(block_lens) != int_field(gate, "block_len_count"):
            mismatches += 1
        expected_lens = gate.get("block_lens")
        if isinstance(expected_lens, list) and sorted(block_lens) != sorted(int(value) for value in expected_lens):
            mismatches += 1
        best_total = None
        for row in total_rows:
            try:
                if best_total is None or int(row.get("vort_native_stream_bytes") or "0") < int(best_total.get("vort_native_stream_bytes") or "0"):
                    best_total = row
            except ValueError:
                mismatches += 1
        if best_total is None:
            return mismatches + 1
        try:
            if int(best_total.get("block_len") or "0") != int_field(gate, "best_block_len"):
                mismatches += 1
            if int(best_total.get("vort_native_stream_bytes") or "0") != int_field(gate, "best_native_stream_bytes"):
                mismatches += 1
            if int(best_total.get("vort_stream_over_native_best_bytes") or "0") != int_field(gate, "best_stream_over_native_best_bytes"):
                mismatches += 1
            if int(best_total.get("vort_embedded_over_native_stream_bytes") or "0") != int_field(gate, "best_embedded_over_native_stream_bytes"):
                mismatches += 1
            if not close(float(best_total.get("vort_native_stream_over_zstd") or "0"), float_field(gate, "best_native_stream_ratio")):
                mismatches += 1
            if not close(float(best_total.get("vort_range_decode_mib_s") or "0"), float_field(gate, "best_range_decode_mib_s")):
                mismatches += 1
            if not close(float(best_total.get("vort_range_decode_full_input_mib_s") or "0"), float_field(gate, "best_range_decode_full_input_mib_s")):
                mismatches += 1
        except ValueError:
            mismatches += 1
        for field in ("source_mode", "size_mode", "case_limit", "optimize"):
            if str(best_total.get(field) or "") != str(gate.get(field) or ""):
                mismatches += 1
        return mismatches

    def markdown_checks(kind: str, gate: dict | None, rows: list[dict[str, str]]) -> tuple[int, int]:
        if not isinstance(gate, dict):
            return (1, 0)
        artifact = markdown_artifacts.get(kind)
        if artifact is None:
            return (1, 0)
        text = artifact.read_text(errors="replace")
        expected = [
            f"- source mode: `{gate.get('source_mode')}`",
            f"- size mode: `{gate.get('size_mode')}`",
            f"- case limit: `{gate.get('case_limit')}`",
        ]
        if kind in {"compare", "standard"}:
            expected.extend([
                f"- Native block length: `{int_field(gate, 'native_block_len')}`",
                f"- Decode repeats: `{int_field(gate, 'decode_repeats')}`",
                "Vort native stream bytes",
                "Vort native embedded bytes",
            ])
            total_rows = [row for row in rows if row.get("path") == "TOTAL"]
            if total_rows:
                total = total_rows[0]
                expected.append(f"| **TOTAL** | {total.get('input_bytes')} | {total.get('zstd_bytes')} |")
        else:
            block_lens = gate.get("block_lens")
            if isinstance(block_lens, list):
                expected.append(f"- Swept native block lengths: `{','.join(str(item) for item in block_lens)}`")
            expected.extend([
                f"block length `{int_field(gate, 'best_block_len')}`",
                "## TOTAL by block length",
                "## Per-input rows",
                "embedded-index bytes",
                "stream overhead bytes",
                "range decode MiB/s",
            ])
        matched = sum(1 for needle in expected if needle in text)
        return (len(expected), matched)

    def markdown_cells(line: str) -> list[str]:
        return [cell.strip() for cell in line.strip().strip("|").split("|")]

    def plain_cell(cell: str) -> str:
        value = cell.strip()
        if value.startswith("`") and value.endswith("`") and len(value) >= 2:
            value = value[1:-1]
        if value.startswith("**") and value.endswith("**") and len(value) >= 4:
            value = value[2:-2]
        return value

    def formatted_ratio(row: dict[str, str], field: str) -> str:
        try:
            value = float(row.get(field) or "0")
        except ValueError:
            return "n/a"
        return "n/a" if value < 0 else f"{value:.4f}"

    def formatted_float(row: dict[str, str], field: str, decimals: int = 2, suffix: str = "") -> str:
        try:
            value = float(row.get(field) or "0")
        except ValueError:
            return "n/a"
        return f"{value:.{decimals}f}{suffix}"

    def formatted_int(row: dict[str, str], field: str) -> str:
        try:
            return str(int(row.get(field) or "0"))
        except ValueError:
            return ""

    def compare_markdown_row_matches(row: dict[str, str], cells: list[str]) -> bool:
        if len(cells) != 24 or plain_cell(cells[0]) != str(row.get("path") or ""):
            return False
        expected = [
            formatted_int(row, "input_bytes"),
            formatted_int(row, "zstd_bytes"),
            formatted_int(row, "vort_raw_fixed_bytes"),
            formatted_int(row, "vort_native_best_bytes"),
            formatted_int(row, "vort_native_stream_bytes"),
            formatted_int(row, "vort_native_embedded_bytes"),
            formatted_int(row, "vort_stream_over_native_best_bytes"),
            formatted_int(row, "vort_embedded_over_native_stream_bytes"),
            formatted_int(row, "vort_embedded_over_native_best_bytes"),
            formatted_ratio(row, "vort_stream_over_native_best"),
            formatted_ratio(row, "vort_embedded_over_native_stream"),
            formatted_ratio(row, "vort_embedded_over_native_best"),
            formatted_ratio(row, "vort_over_zstd"),
            formatted_ratio(row, "vort_native_best_over_zstd"),
            formatted_ratio(row, "vort_native_stream_over_zstd"),
            formatted_ratio(row, "vort_native_over_zstd"),
            formatted_float(row, "zstd_decode_mib_s"),
            formatted_float(row, "vort_raw_fixed_decode_mib_s"),
            formatted_float(row, "vort_native_best_decode_mib_s"),
            formatted_float(row, "vort_native_decode_mib_s"),
            formatted_ratio(row, "vort_decode_vs_zstd"),
            formatted_ratio(row, "vort_native_best_decode_vs_zstd"),
            formatted_ratio(row, "vort_native_decode_vs_zstd"),
        ]
        return cells[1:] == expected

    def sweep_markdown_row_matches(row: dict[str, str], cells: list[str]) -> bool:
        if str(row.get("path") or "") == "TOTAL":
            if len(cells) != 15 or plain_cell(cells[0]) != str(row.get("seekability_tier") or ""):
                return False
            expected = [
                formatted_int(row, "block_len"),
                formatted_int(row, "input_bytes"),
                formatted_int(row, "zstd_bytes"),
                formatted_int(row, "vort_native_best_bytes"),
                formatted_int(row, "vort_native_stream_bytes"),
                formatted_int(row, "vort_native_embedded_bytes"),
                formatted_ratio(row, "vort_native_stream_over_zstd"),
                formatted_ratio(row, "vort_native_embedded_over_zstd"),
                formatted_ratio(row, "vort_stream_over_native_best"),
                formatted_int(row, "vort_stream_over_native_best_bytes"),
                formatted_float(row, "vort_stream_over_native_best_pct", suffix="%"),
                formatted_ratio(row, "vort_embedded_over_native_stream"),
                formatted_int(row, "vort_embedded_over_native_stream_bytes"),
                formatted_float(row, "vort_range_decode_mib_s"),
            ]
            return cells[1:] == expected
        if len(cells) != 12 or plain_cell(cells[0]) != str(row.get("path") or "") or plain_cell(cells[1]) != str(row.get("seekability_tier") or ""):
            return False
        expected = [
            formatted_int(row, "block_len"),
            formatted_int(row, "input_bytes"),
            formatted_int(row, "zstd_bytes"),
            formatted_int(row, "vort_native_best_bytes"),
            formatted_int(row, "vort_native_stream_bytes"),
            formatted_int(row, "vort_native_embedded_bytes"),
            formatted_ratio(row, "vort_stream_over_native_best"),
            formatted_ratio(row, "vort_embedded_over_native_stream"),
            formatted_int(row, "range_offset"),
            formatted_float(row, "vort_range_decode_mib_s"),
        ]
        return cells[2:] == expected

    def markdown_detail_checks(kind: str, rows: list[dict[str, str]]) -> tuple[int, int]:
        artifact = markdown_artifacts.get(kind)
        if artifact is None:
            return (len(rows), 0)
        try:
            table_rows = [
                markdown_cells(line)
                for line in artifact.read_text(errors="replace").splitlines()
                if line.startswith("| ")
            ]
        except Exception:
            return (len(rows), 0)
        table_rows = [
            cells
            for cells in table_rows
            if cells and plain_cell(cells[0]) not in {"path", "tier", "---"}
        ]
        matched = 0
        used: set[int] = set()
        for row in rows:
            matcher = sweep_markdown_row_matches if kind == "sweep" else compare_markdown_row_matches
            for index, cells in enumerate(table_rows):
                if index in used:
                    continue
                if matcher(row, cells):
                    used.add(index)
                    matched += 1
                    break
        return (len(rows), matched)

    compare_present = isinstance(compare, dict)
    standard_present = isinstance(standard, dict)
    sweep_present = isinstance(sweep, dict)
    compare_rows = csv_rows_for("compare")
    standard_rows = csv_rows_for("standard")
    sweep_rows = csv_rows_for("sweep")
    csv_present_count = sum(1 for kind in ("compare", "standard", "sweep") if kind in csv_artifacts)
    csv_expected_present_count = 3
    csv_row_count = len(compare_rows) + len(standard_rows) + len(sweep_rows)
    csv_expected_rows = int_field(compare, "rows") + int_field(standard, "rows") + int_field(sweep, "rows")
    csv_unmatched_rows = (
        csv_expected_present_count
        - csv_present_count
        + compare_csv_mismatches(compare_rows, compare)
        + compare_csv_mismatches(standard_rows, standard)
        + sweep_csv_mismatches(sweep_rows, sweep)
    )
    csv_matched_rows = csv_row_count if csv_unmatched_rows == 0 else 0
    markdown_present_count = sum(1 for kind in ("compare", "standard", "sweep") if kind in markdown_artifacts)
    markdown_expected_present_count = 3
    compare_md_rows, compare_md_matched = markdown_checks("compare", compare, compare_rows)
    standard_md_rows, standard_md_matched = markdown_checks("standard", standard, standard_rows)
    sweep_md_rows, sweep_md_matched = markdown_checks("sweep", sweep, sweep_rows)
    markdown_summary_rows = compare_md_rows + standard_md_rows + sweep_md_rows
    markdown_matched = compare_md_matched + standard_md_matched + sweep_md_matched
    markdown_unmatched = markdown_summary_rows - markdown_matched + (markdown_expected_present_count - markdown_present_count)
    compare_md_detail_rows, compare_md_detail_matched = markdown_detail_checks("compare", compare_rows)
    standard_md_detail_rows, standard_md_detail_matched = markdown_detail_checks("standard", standard_rows)
    sweep_md_detail_rows, sweep_md_detail_matched = markdown_detail_checks("sweep", sweep_rows)
    markdown_detail_rows = compare_md_detail_rows + standard_md_detail_rows + sweep_md_detail_rows
    markdown_detail_matched = compare_md_detail_matched + standard_md_detail_matched + sweep_md_detail_matched
    markdown_detail_unmatched = markdown_detail_rows - markdown_detail_matched
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
        and csv_present_count == csv_expected_present_count
        and csv_row_count == csv_expected_rows
        and csv_unmatched_rows == 0
        and markdown_present_count == markdown_expected_present_count
        and markdown_summary_rows > 0
        and markdown_unmatched == 0
        and markdown_detail_rows == csv_row_count
        and markdown_detail_unmatched == 0
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
        "csv_present_count": csv_present_count,
        "csv_expected_present_count": csv_expected_present_count,
        "csv_rows": csv_row_count,
        "csv_expected_rows": csv_expected_rows,
        "csv_matched_rows": csv_matched_rows,
        "csv_unmatched_rows": csv_unmatched_rows,
        "markdown_present_count": markdown_present_count,
        "markdown_expected_present_count": markdown_expected_present_count,
        "markdown_summary_rows": markdown_summary_rows,
        "markdown_matched": markdown_matched,
        "markdown_unmatched": markdown_unmatched,
        "markdown_detail_rows": markdown_detail_rows,
        "markdown_detail_matched": markdown_detail_matched,
        "markdown_detail_unmatched": markdown_detail_unmatched,
    }


def native_allocation_health(artifacts: list[Path]) -> dict:
    report = None
    smoke = None
    negative = None
    markdown = None
    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        schema = data.get("schema")
        if schema == "vort.native_allocation_report":
            report = data
        elif schema == "vort.native_allocation_smoke":
            smoke = data
        elif schema == "vort.native_allocation_negative_smoke":
            negative = data
        elif artifact.name == "vort-native-allocation-report.md":
            markdown = artifact

    def int_field(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def row_int(row: dict, field: str) -> int | None:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else None

    def report_row_balanced(row: dict) -> bool:
        allocations = row_int(row, "allocations")
        deallocations = row_int(row, "deallocations")
        allocated_bytes = row_int(row, "allocated_bytes")
        freed_bytes = row_int(row, "freed_bytes")
        return (
            allocations is not None
            and deallocations is not None
            and allocated_bytes is not None
            and freed_bytes is not None
            and allocations == deallocations
            and allocated_bytes == freed_bytes
        )

    def parse_markdown_rows(path: Path | None) -> list[dict[str, int | str]]:
        if path is None:
            return []
        rows: list[dict[str, int | str]] = []
        try:
            text = path.read_text(errors="replace")
        except Exception:
            return rows
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) != 7 or cells[0] in {"case", "---"} or set(cells[0]) == {"-"}:
                continue
            try:
                rows.append({
                    "case": cells[0],
                    "input_bytes": int(cells[1]),
                    "output_bytes": int(cells[2]),
                    "allocations": int(cells[3]),
                    "deallocations": int(cells[4]),
                    "allocated_bytes": int(cells[5]),
                    "freed_bytes": int(cells[6]),
                })
            except ValueError:
                continue
        return rows

    def row_metrics_match(left: dict, right: dict, fields: tuple[str, ...]) -> bool:
        return all(row_int(left, field) == row_int(right, field) for field in fields)

    def smoke_rows_match_report(rows: list[dict], *, require_zero: bool, require_budget: bool) -> tuple[int, int]:
        matched_cases: set[str] = set()
        unmatched = 0
        for row in rows:
            if not isinstance(row, dict):
                unmatched += 1
                continue
            case = str(row.get("case") or "")
            report_row = report_by_case.get(case)
            if not isinstance(report_row, dict):
                unmatched += 1
                continue
            metrics_match = row_metrics_match(
                row,
                report_row,
                ("allocations", "deallocations", "allocated_bytes", "freed_bytes"),
            )
            if row.get("present") is not True or row.get("matched") is not True or not metrics_match:
                unmatched += 1
                continue
            if case in matched_cases:
                unmatched += 1
                continue
            if require_zero and any(row_int(report_row, field) != 0 for field in ("allocations", "deallocations", "allocated_bytes", "freed_bytes")):
                unmatched += 1
                continue
            if require_budget:
                max_fields = (
                    ("allocations", "max_allocations"),
                    ("deallocations", "max_deallocations"),
                    ("allocated_bytes", "max_allocated_bytes"),
                    ("freed_bytes", "max_freed_bytes"),
                )
                within_budget = row.get("balanced") is True and report_row_balanced(report_row)
                for report_field, max_field in max_fields:
                    value = row_int(report_row, report_field)
                    max_value = row_int(row, max_field)
                    within_budget = within_budget and value is not None and max_value is not None and value <= max_value
                if not within_budget:
                    unmatched += 1
                    continue
            matched_cases.add(case)
        return len(matched_cases), unmatched

    report_cases = report.get("cases") if isinstance(report, dict) else []
    report_cases = report_cases if isinstance(report_cases, list) else []
    report_rows = len(report_cases)
    report_count_mismatch = abs(int_field(report, "case_count") - report_rows)
    report_by_case: dict[str, dict] = {}
    report_duplicate_cases = 0
    report_balanced_rows = 0
    for row in report_cases:
        if not isinstance(row, dict):
            continue
        case = str(row.get("case") or "")
        if case in report_by_case:
            report_duplicate_cases += 1
        else:
            report_by_case[case] = row
        if report_row_balanced(row):
            report_balanced_rows += 1
    report_unbalanced_rows = report_rows - report_balanced_rows
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
    zero_report_matched, zero_report_unmatched = smoke_rows_match_report(cases, require_zero=True, require_budget=False)
    zero_report_unmatched += abs(required_zero_cases - len(cases))
    budget_report_matched, budget_report_unmatched = smoke_rows_match_report(budget_cases, require_zero=False, require_budget=True)
    budget_report_unmatched += abs(required_budget_cases - len(budget_cases))
    zero_case_names = {str(row.get("case") or "") for row in cases if isinstance(row, dict)}
    budget_case_names = {str(row.get("case") or "") for row in budget_cases if isinstance(row, dict)}
    report_case_names = set(report_by_case)
    smoke_classified_cases = len((zero_case_names | budget_case_names) & report_case_names)
    smoke_classification_overlap = len(zero_case_names & budget_case_names)
    smoke_classification_missing = len(report_case_names - (zero_case_names | budget_case_names))
    smoke_classification_extra = len((zero_case_names | budget_case_names) - report_case_names)
    negative_unmatched = max(negative_case_count, len(negative_cases)) - negative_matched
    markdown_present = isinstance(markdown, Path)
    markdown_rows_data = parse_markdown_rows(markdown if markdown_present else None)
    markdown_rows = len(markdown_rows_data)
    markdown_matched_cases: set[str] = set()
    markdown_malformed_rows = 0
    for row in markdown_rows_data:
        case = str(row.get("case") or "")
        report_row = report_by_case.get(case)
        if not isinstance(report_row, dict):
            markdown_malformed_rows += 1
            continue
        if case in markdown_matched_cases:
            markdown_malformed_rows += 1
            continue
        if row_metrics_match(
            row,
            report_row,
            ("input_bytes", "output_bytes", "allocations", "deallocations", "allocated_bytes", "freed_bytes"),
        ):
            markdown_matched_cases.add(case)
        else:
            markdown_malformed_rows += 1
    markdown_matched = len(markdown_matched_cases)
    markdown_unmatched = max(markdown_rows, report_rows) - markdown_matched + markdown_malformed_rows
    healthy = (
        report_present
        and smoke_present
        and negative_present
        and markdown_present
        and bool(smoke.get("ok"))
        and bool(negative.get("ok"))
        and int_field(report, "case_count") > 0
        and report_count_mismatch == 0
        and report_duplicate_cases == 0
        and report_unbalanced_rows == 0
        and required_zero_cases > 0
        and zero_matched == required_zero_cases
        and zero_report_matched == required_zero_cases
        and zero_report_unmatched == 0
        and required_budget_cases > 0
        and budget_matched == required_budget_cases
        and budget_report_matched == required_budget_cases
        and budget_report_unmatched == 0
        and smoke_classified_cases == report_rows
        and smoke_classification_overlap == 0
        and smoke_classification_missing == 0
        and smoke_classification_extra == 0
        and negative_case_count > 0
        and negative_matched == negative_case_count
        and negative_unmatched == 0
        and markdown_rows == report_rows
        and markdown_matched == report_rows
        and markdown_unmatched == 0
    )
    return {
        "present": report_present,
        "smoke_present": smoke_present,
        "negative_present": negative_present,
        "markdown_present": markdown_present,
        "healthy": healthy,
        "report_case_count": int_field(report, "case_count"),
        "report_rows": report_rows,
        "report_count_mismatch": report_count_mismatch,
        "report_balanced_rows": report_balanced_rows,
        "report_duplicate_cases": report_duplicate_cases,
        "report_unbalanced_rows": report_unbalanced_rows,
        "required_zero_allocation_cases": required_zero_cases,
        "zero_allocation_matched": zero_matched,
        "zero_report_matched": zero_report_matched,
        "zero_report_unmatched": zero_report_unmatched,
        "required_budget_cases": required_budget_cases,
        "budget_matched": budget_matched,
        "budget_report_matched": budget_report_matched,
        "budget_report_unmatched": budget_report_unmatched,
        "smoke_classified_cases": smoke_classified_cases,
        "smoke_classification_overlap": smoke_classification_overlap,
        "smoke_classification_missing": smoke_classification_missing,
        "smoke_classification_extra": smoke_classification_extra,
        "negative_case_count": negative_case_count,
        "negative_matched": negative_matched,
        "negative_unmatched": negative_unmatched,
        "markdown_rows": markdown_rows,
        "markdown_matched": markdown_matched,
        "markdown_unmatched": markdown_unmatched,
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
        dictionary_encode_cases = zlib_dict_encode_cases + raw_dict_encode_cases
        malformed_cases = malformed_wrapper_cases + malformed_deflate_cases
        cli_total_outcomes = cli_successes + expected_failures
        inline_payloads = max(0, payloads - large_file_payloads)
        large_file_payload_overflow = max(0, large_file_payloads - payloads)
        file_hex_expected_cases = large_file_payloads * 3
        file_hex_case_mismatch = abs(file_hex_encode_cases - file_hex_expected_cases)
        cli_success_floor = payloads + file_hex_encode_cases + dictionary_encode_cases
        expected_failure_floor = malformed_cases
        cli_outcome_floor = cli_success_floor + expected_failure_floor
        cli_success_shortfall = max(0, cli_success_floor - cli_successes)
        expected_failure_shortfall = max(0, expected_failure_floor - expected_failures)
        cli_outcome_shortfall = max(0, cli_outcome_floor - cli_total_outcomes)
        # The Python differential harness is intentionally black-box, but its
        # command matrix is deterministic. Keep an exact dashboard recomputation
        # here so future edits cannot silently drop a success/failure branch
        # while still staying above the broad historical floor. The constants
        # mirror tools/python_zlib_diff.py's command groups: inline payloads
        # exercise many hex/round-trip encoder paths, large payloads route
        # through file commands, and the fixed miscellaneous counts cover
        # dictionary concatenation, file-limit, malformed/trailing, and known
        # deterministic wrapper checks outside the per-case loops.
        payload_cli_success_expected = inline_payloads * 19 + large_file_payloads * 12
        dictionary_decode_success_expected = dictionary_cases * 4
        dictionary_encode_success_expected = dictionary_encode_cases * 2
        dynamic_encode_success_expected = dynamic_payloads * 2
        fixed_misc_cli_success_expected = 30
        cli_success_expected = (
            payload_cli_success_expected
            + dictionary_decode_success_expected
            + dictionary_encode_success_expected
            + dynamic_encode_success_expected
            + fixed_misc_cli_success_expected
        )
        fixed_misc_expected_failure_expected = 31
        expected_failure_expected = malformed_cases + dictionary_encode_cases + fixed_misc_expected_failure_expected
        cli_total_expected = cli_success_expected + expected_failure_expected
        cli_success_exact_mismatch = abs(cli_successes - cli_success_expected)
        expected_failure_exact_mismatch = abs(expected_failures - expected_failure_expected)
        cli_outcome_exact_mismatch = abs(cli_total_outcomes - cli_total_expected)
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "payloads": payloads,
            "large_file_payloads": large_file_payloads,
            "inline_payloads": inline_payloads,
            "large_file_payload_overflow": large_file_payload_overflow,
            "file_hex_encode_cases": file_hex_encode_cases,
            "match_heavy_payloads": match_heavy_payloads,
            "dynamic_payloads": dynamic_payloads,
            "dictionary_cases": dictionary_cases,
            "zlib_dict_encode_cases": zlib_dict_encode_cases,
            "raw_dict_encode_cases": raw_dict_encode_cases,
            "dictionary_encode_cases": dictionary_encode_cases,
            "malformed_wrapper_cases": malformed_wrapper_cases,
            "malformed_deflate_cases": malformed_deflate_cases,
            "malformed_cases": malformed_cases,
            "cli_successes": cli_successes,
            "expected_failures": expected_failures,
            "cli_total_outcomes": cli_total_outcomes,
            "file_hex_expected_cases": file_hex_expected_cases,
            "file_hex_case_mismatch": file_hex_case_mismatch,
            "cli_success_floor": cli_success_floor,
            "cli_success_shortfall": cli_success_shortfall,
            "expected_failure_floor": expected_failure_floor,
            "expected_failure_shortfall": expected_failure_shortfall,
            "cli_outcome_floor": cli_outcome_floor,
            "cli_outcome_shortfall": cli_outcome_shortfall,
            "payload_cli_success_expected": payload_cli_success_expected,
            "cli_success_expected": cli_success_expected,
            "expected_failure_expected": expected_failure_expected,
            "cli_total_expected": cli_total_expected,
            "cli_success_exact_mismatch": cli_success_exact_mismatch,
            "expected_failure_exact_mismatch": expected_failure_exact_mismatch,
            "cli_outcome_exact_mismatch": cli_outcome_exact_mismatch,
            "healthy": bool(data.get("ok"))
            and payloads > 0
            and large_file_payloads > 0
            and inline_payloads > 0
            and large_file_payload_overflow == 0
            and file_hex_encode_cases > 0
            and match_heavy_payloads > 0
            and dynamic_payloads > 0
            and dictionary_cases > 0
            and zlib_dict_encode_cases >= dictionary_cases
            and raw_dict_encode_cases >= dictionary_cases
            and dictionary_encode_cases > 0
            and malformed_wrapper_cases > 0
            and malformed_deflate_cases > 0
            and malformed_cases > 0
            and cli_successes > 0
            and expected_failures > 0
            and cli_total_outcomes > 0
            and file_hex_case_mismatch == 0
            and cli_success_shortfall == 0
            and expected_failure_shortfall == 0
            and cli_outcome_shortfall == 0
            and payload_cli_success_expected > 0
            and cli_success_exact_mismatch == 0
            and expected_failure_exact_mismatch == 0
            and cli_outcome_exact_mismatch == 0,
        }
    return {
        "present": False,
        "ok": False,
        "payloads": 0,
        "large_file_payloads": 0,
        "inline_payloads": 0,
        "large_file_payload_overflow": 0,
        "file_hex_encode_cases": 0,
        "match_heavy_payloads": 0,
        "dynamic_payloads": 0,
        "dictionary_cases": 0,
        "zlib_dict_encode_cases": 0,
        "raw_dict_encode_cases": 0,
        "dictionary_encode_cases": 0,
        "malformed_wrapper_cases": 0,
        "malformed_deflate_cases": 0,
        "malformed_cases": 0,
        "cli_successes": 0,
        "expected_failures": 0,
        "cli_total_outcomes": 0,
        "file_hex_expected_cases": 0,
        "file_hex_case_mismatch": 0,
        "cli_success_floor": 0,
        "cli_success_shortfall": 0,
        "expected_failure_floor": 0,
        "expected_failure_shortfall": 0,
        "cli_outcome_floor": 0,
        "cli_outcome_shortfall": 0,
        "payload_cli_success_expected": 0,
        "cli_success_expected": 0,
        "expected_failure_expected": 0,
        "cli_total_expected": 0,
        "cli_success_exact_mismatch": 0,
        "expected_failure_exact_mismatch": 0,
        "cli_outcome_exact_mismatch": 0,
        "healthy": False,
    }


def native_codec_probes_health(artifacts: list[Path]) -> dict:
    required_probe_labels = {
        "lz4-native-probe",
        "lz4-native-dictionary-probe",
        "zstd-native-frame-probe",
        "zstd-native-dictionary-probe",
    }
    required_coverage_pairs = {
        ("lz4", "frame"),
        ("lz4", "dictionary"),
        ("zstd", "frame"),
        ("zstd", "dictionary"),
    }
    required_capabilities = {
        "lib-generated",
        "native-generated",
        "incremental",
        "chunked",
        "reusable-chunked",
        "fse-repeat",
        "dictionary",
        "dictionary-training",
        "dictionary-set",
        "skippable",
        "malformed",
        "checksum",
        "bounded-limits",
        "huffman",
        "sequence-tables",
        "block",
    }

    def int_field(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    markdown_artifact = next((artifact for artifact in artifacts if artifact.name == "vort-native-codec-probes.md"), None)

    def bool_text(value: object) -> str:
        return "true" if value is True else "false"

    def markdown_checks(data: dict, coverage: list[dict], capabilities: list[dict], probes: list[dict]) -> tuple[bool, int, int, int]:
        if markdown_artifact is None:
            return (False, 0, 0, 1)
        try:
            text = markdown_artifact.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        expected = [
            f"- ok: `{bool_text(data.get('ok'))}`",
            f"- total cases: `{int_field(data, 'total_cases')}`",
            "## Coverage",
            "## Capabilities",
            "## Probes",
        ]
        for row in coverage:
            expected.append(
                "| {codec} | {surface} | `{present}` | `{ok}` | {ok_probe_count}/{probe_count} | {cases} |".format(
                    codec=row.get("codec", ""),
                    surface=row.get("surface", ""),
                    present=bool_text(row.get("present")),
                    ok=bool_text(row.get("ok")),
                    ok_probe_count=int_field(row, "ok_probe_count"),
                    probe_count=int_field(row, "probe_count"),
                    cases=int_field(row, "cases"),
                )
            )
        for row in capabilities:
            expected.append(
                "| {capability} | `{present}` | `{ok}` | {ok_probe_count}/{probe_count} | {cases} |".format(
                    capability=row.get("capability", ""),
                    present=bool_text(row.get("present")),
                    ok=bool_text(row.get("ok")),
                    ok_probe_count=int_field(row, "ok_probe_count"),
                    probe_count=int_field(row, "probe_count"),
                    cases=int_field(row, "cases"),
                )
            )
        for probe in probes:
            timeout = probe.get("timeout_seconds")
            if isinstance(timeout, (int, float)) and not isinstance(timeout, bool):
                timeout_text = f"{timeout:g}"
            else:
                timeout_text = ""
            expected.append(
                "| {label} | `{ok}` | {cases} | {returncode} | `{timed_out}` | {timeout_seconds} |".format(
                    label=probe.get("label", ""),
                    ok=bool_text(probe.get("ok")),
                    cases=int_field(probe, "cases"),
                    returncode=int_field(probe, "returncode"),
                    timed_out=bool_text(probe.get("timed_out")),
                    timeout_seconds=timeout_text,
                )
            )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_codec_probes":
            continue
        probes = data.get("probes")
        if not isinstance(probes, list):
            probes = []
        probe_count = int_field(data, "probe_count")
        probe_rows = len(probes)
        ok_probes = sum(1 for probe in probes if isinstance(probe, dict) and probe.get("ok") is True)
        timed_out_probes = sum(1 for probe in probes if isinstance(probe, dict) and probe.get("timed_out") is True)
        probe_labels = [
            str(probe.get("label") or "")
            for probe in probes
            if isinstance(probe, dict)
        ]
        probe_label_set = {label for label in probe_labels if label}
        missing_required_probes = len(required_probe_labels - probe_label_set)
        duplicate_probe_rows = len(probe_labels) - len(probe_label_set)
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
                "timeout_seconds": probe.get("timeout_seconds"),
            }
            for probe in probes
            if isinstance(probe, dict)
        ]
        capabilities = data.get("capabilities")
        if not isinstance(capabilities, list):
            capabilities = []
        capability_count = int_field(data, "capability_count")
        capability_rows = len(capabilities)
        ok_capabilities = sum(1 for row in capabilities if isinstance(row, dict) and row.get("ok") is True)
        capability_names = [
            str(row.get("capability") or "")
            for row in capabilities
            if isinstance(row, dict)
        ]
        capability_name_set = {name for name in capability_names if name}
        missing_required_capabilities = len(required_capabilities - capability_name_set)
        duplicate_capability_rows = len(capability_names) - len(capability_name_set)
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
        coverage_count = int_field(data, "coverage_count")
        coverage_rows = len(coverage)
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
        coverage_pairs = [
            (row["codec"], row["surface"])
            for row in coverage_details
        ]
        coverage_pair_set = {pair for pair in coverage_pairs if pair[0] and pair[1]}
        missing_required_coverage = len(required_coverage_pairs - coverage_pair_set)
        duplicate_coverage_rows = len(coverage_pairs) - len(coverage_pair_set)
        total_cases = int_field(data, "total_cases")
        coverage_ok_rows = sum(1 for row in coverage_details if row["present"] and row["ok"])
        coverage_case_sum = sum(row["cases"] for row in coverage_details)
        probe_case_sum = sum(row["cases"] for row in probe_details)
        probe_count_mismatch = abs(probe_count - probe_rows)
        probe_case_sum_mismatch = abs(total_cases - probe_case_sum)
        capability_count_mismatch = abs(capability_count - capability_rows)
        capability_row_unhealthy = max(capability_count, capability_rows) - ok_capabilities
        coverage_count_mismatch = abs(coverage_count - coverage_rows)
        markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(data, coverage_details, capability_details, probe_details)
        return {
            "present": True,
            "ok": bool(data.get("ok")),
            "healthy": bool(data.get("ok"))
            and ok_probes == probe_count
            and ok_probes == 4
            and probe_count_mismatch == 0
            and probe_case_sum_mismatch == 0
            and missing_required_probes == 0
            and duplicate_probe_rows == 0
            and timed_out_probes == 0
            and coverage_rows == 4
            and coverage_count_mismatch == 0
            and coverage_ok_rows == coverage_rows
            and coverage_case_sum == total_cases
            and missing_required_coverage == 0
            and duplicate_coverage_rows == 0
            and capability_count > 0
            and capability_count_mismatch == 0
            and ok_capabilities == capability_count
            and capability_row_unhealthy == 0
            and missing_required_capabilities == 0
            and duplicate_capability_rows == 0
            and total_cases > 0
            and capability_cases.get("lib-generated", 0) > 0
            and capability_cases.get("incremental", 0) > 0
            and capability_cases.get("chunked", 0) > 0
            and capability_cases.get("reusable-chunked", 0) > 0
            and capability_cases.get("fse-repeat", 0) > 0
            and probe_cases.get("zstd-native-frame-probe", 0) >= 213
            and probe_cases.get("zstd-native-dictionary-probe", 0) >= 25
            and markdown_present
            and markdown_rows > 0
            and markdown_unmatched == 0,
            "probe_count": probe_count,
            "probe_rows": probe_rows,
            "ok_probe_count": ok_probes,
            "timed_out_probes": timed_out_probes,
            "probe_case_sum": probe_case_sum,
            "probe_count_mismatch": probe_count_mismatch,
            "probe_case_sum_mismatch": probe_case_sum_mismatch,
            "missing_required_probes": missing_required_probes,
            "duplicate_probe_rows": duplicate_probe_rows,
            "coverage_count": coverage_count,
            "coverage_rows": coverage_rows,
            "coverage_ok_rows": coverage_ok_rows,
            "coverage_case_sum": coverage_case_sum,
            "coverage_count_mismatch": coverage_count_mismatch,
            "missing_required_coverage": missing_required_coverage,
            "duplicate_coverage_rows": duplicate_coverage_rows,
            "capability_count": capability_count,
            "capability_rows": capability_rows,
            "ok_capability_count": ok_capabilities,
            "capability_count_mismatch": capability_count_mismatch,
            "capability_row_unhealthy": capability_row_unhealthy,
            "missing_required_capabilities": missing_required_capabilities,
            "duplicate_capability_rows": duplicate_capability_rows,
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
            "markdown_present": markdown_present,
            "markdown_rows": markdown_rows,
            "markdown_matched": markdown_matched,
            "markdown_unmatched": markdown_unmatched,
        }
    return {
        "present": False,
        "ok": False,
        "healthy": False,
        "probe_count": 0,
        "probe_rows": 0,
        "ok_probe_count": 0,
        "timed_out_probes": 0,
        "probe_case_sum": 0,
        "probe_count_mismatch": 0,
        "probe_case_sum_mismatch": 0,
        "missing_required_probes": 0,
        "duplicate_probe_rows": 0,
        "coverage_count": 0,
        "coverage_rows": 0,
        "coverage_ok_rows": 0,
        "coverage_case_sum": 0,
        "coverage_count_mismatch": 0,
        "missing_required_coverage": 0,
        "duplicate_coverage_rows": 0,
        "capability_count": 0,
        "capability_rows": 0,
        "ok_capability_count": 0,
        "capability_count_mismatch": 0,
        "capability_row_unhealthy": 0,
        "missing_required_capabilities": 0,
        "duplicate_capability_rows": 0,
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
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
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
        block_count_mismatch = abs(block_count - (raw_block_count + rle_block_count + compressed_block_count))
        declared_payload_slack_bytes = declared_content_bytes - payload_bytes
        metadata_frame_overflow = max(0, dictionary_id_frame_count - frame_count) + max(0, content_size_frame_count - frame_count)
        checksum_frame_overflow = max(0, checksum_frame_count - frame_count)
        block_checksum_frame_overflow = max(0, block_checksum_frame_count - frame_count)
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
            and block_count_mismatch == 0
            and declared_payload_slack_bytes == 0
            and metadata_frame_overflow == 0
            and checksum_frame_overflow == 0
            and (not require_block_checksum or block_checksum_frame_overflow == 0)
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
            "block_count_mismatch": block_count_mismatch,
            "declared_payload_slack_bytes": declared_payload_slack_bytes,
            "metadata_frame_overflow": metadata_frame_overflow,
            "checksum_frame_overflow": checksum_frame_overflow,
            "block_checksum_frame_overflow": block_checksum_frame_overflow,
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
        "block_count_mismatch": 0,
        "declared_payload_slack_bytes": 0,
        "metadata_frame_overflow": 0,
        "checksum_frame_overflow": 0,
        "block_checksum_frame_overflow": 0,
    }


def zstd_native_summary_health(artifacts: list[Path]) -> dict:
    return native_stream_summary_health(artifacts, "vort.zstd_native_stream_summary")


def lz4_native_summary_health(artifacts: list[Path]) -> dict:
    return native_stream_summary_health(artifacts, "vort.lz4_native_stream_summary", require_block_checksum=True)



def native_summary_error_dashboard_health(artifacts: list[Path]) -> dict:
    def count_cases(cases: list[dict], field: str, *, codec: str | None = None) -> dict[str, int]:
        counts: dict[str, int] = {}
        for case in cases:
            if codec is not None and str(case.get("codec") or "") != codec:
                continue
            key = str(case.get(field) or "")
            if not key:
                continue
            counts[key] = counts.get(key, 0) + 1
        return counts

    def dict_count_mismatch(reported: dict, computed: dict[str, int]) -> int:
        mismatch = 0
        keys = set(str(key) for key in reported) | set(computed)
        for key in keys:
            try:
                reported_value = int(reported.get(key) or 0)
            except (TypeError, ValueError):
                reported_value = -1
            mismatch += abs(reported_value - int(computed.get(key, 0)))
        return mismatch

    def int_offsets(cases: list[dict], *, codec: str | None = None, phase: str | None = None) -> list[int]:
        offsets: list[int] = []
        for case in cases:
            if codec is not None and str(case.get("codec") or "") != codec:
                continue
            if phase is not None and str(case.get("phase") or "") != phase:
                continue
            value = case.get("offset")
            if isinstance(value, int) and not isinstance(value, bool):
                offsets.append(value)
        return offsets

    def range_tuple(offsets: list[int]) -> tuple[int, int]:
        return (min(offsets), max(offsets)) if offsets else (0, 0)

    def range_mismatch(reported_min: int, reported_max: int, offsets: list[int]) -> int:
        expected_min, expected_max = range_tuple(offsets)
        return 0 if reported_min == expected_min and reported_max == expected_max else 1

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") != "vort.native_summary_error_dashboard":
            continue
        cases_raw = data.get("cases") if isinstance(data.get("cases"), list) else []
        cases = [case for case in cases_raw if isinstance(case, dict)]
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
        computed_error_counts = count_cases(cases, "error")
        computed_phase_counts = count_cases(cases, "phase")
        computed_lz4_error_counts = count_cases(cases, "error", codec="lz4")
        computed_zstd_error_counts = count_cases(cases, "error", codec="zstd")
        computed_lz4_phase_counts = count_cases(cases, "phase", codec="lz4")
        computed_zstd_phase_counts = count_cases(cases, "phase", codec="zstd")
        case_count_mismatch = abs(case_count - len(cases))
        codec_case_count_mismatch = abs(lz4_case_count - sum(1 for case in cases if str(case.get("codec") or "") == "lz4")) + abs(zstd_case_count - sum(1 for case in cases if str(case.get("codec") or "") == "zstd"))
        error_count_mismatch = dict_count_mismatch(error_counts, computed_error_counts)
        phase_count_mismatch = dict_count_mismatch(phase_counts, computed_phase_counts)
        codec_error_count_mismatch = dict_count_mismatch(lz4_error_counts, computed_lz4_error_counts) + dict_count_mismatch(zstd_error_counts, computed_zstd_error_counts)
        codec_phase_count_mismatch = dict_count_mismatch(lz4_phase_counts, computed_lz4_phase_counts) + dict_count_mismatch(zstd_phase_counts, computed_zstd_phase_counts)
        offset_range_mismatch = (
            range_mismatch(offset_min, offset_max, int_offsets(cases))
            + range_mismatch(lz4_offset_min, lz4_offset_max, int_offsets(cases, codec="lz4"))
            + range_mismatch(zstd_offset_min, zstd_offset_max, int_offsets(cases, codec="zstd"))
        )
        for phase in set(phase_offset_ranges) | set(computed_phase_counts):
            reported_range = phase_offset_ranges.get(phase) if isinstance(phase_offset_ranges.get(phase), dict) else {}
            try:
                reported_min = int(reported_range.get("min") or 0)
                reported_max = int(reported_range.get("max") or 0)
            except (TypeError, ValueError):
                reported_min = -1
                reported_max = -1
            offset_range_mismatch += range_mismatch(reported_min, reported_max, int_offsets(cases, phase=str(phase)))
        return {
            "present": True,
            "healthy": data.get("ok") is True
            and case_count >= 14
            and case_count_mismatch == 0
            and lz4_case_count >= 7
            and zstd_case_count >= 7
            and codec_case_count_mismatch == 0
            and checksum_mismatch_count >= 1
            and corrupt_frame_count >= 4
            and truncated_frame_count >= 8
            and error_count_mismatch == 0
            and magic_phase_count >= 2
            and skippable_payload_phase_count >= 2
            and frame_body_phase_count >= 2
            and frame_checksum_phase_count >= 2
            and frame_phase_count >= 2
            and phase_count_mismatch == 0
            and codec_error_count_mismatch == 0
            and codec_phase_count_mismatch == 0
            and offset_range_mismatch == 0
            and len(lz4_missing_phases) == 0
            and len(zstd_missing_phases) == 0,
            "case_count": case_count,
            "case_rows": len(cases),
            "case_count_mismatch": case_count_mismatch,
            "lz4_case_count": lz4_case_count,
            "zstd_case_count": zstd_case_count,
            "codec_case_count_mismatch": codec_case_count_mismatch,
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
            "error_count_mismatch": error_count_mismatch,
            "phase_count_mismatch": phase_count_mismatch,
            "codec_error_count_mismatch": codec_error_count_mismatch,
            "codec_phase_count_mismatch": codec_phase_count_mismatch,
            "offset_range_mismatch": offset_range_mismatch,
            "phase_offset_ranges": phase_offset_ranges,
            "required_codec_phases": required_codec_phases,
            "lz4_missing_phases": lz4_missing_phases,
            "zstd_missing_phases": zstd_missing_phases,
        }
    return {
        "present": False,
        "healthy": False,
        "case_count": 0,
        "case_rows": 0,
        "case_count_mismatch": 0,
        "lz4_case_count": 0,
        "zstd_case_count": 0,
        "codec_case_count_mismatch": 0,
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
        "error_count_mismatch": 0,
        "phase_count_mismatch": 0,
        "codec_error_count_mismatch": 0,
        "codec_phase_count_mismatch": 0,
        "offset_range_mismatch": 0,
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
        cases = data.get("cases") if isinstance(data.get("cases"), list) else []
        row_count = len(cases)
        matched = sum(1 for row in cases if isinstance(row, dict) and row.get("matched") is True)
        expected_failures = sum(1 for row in cases if isinstance(row, dict) and row.get("expected_failure") is True)
        count_mismatch = abs(case_count - row_count)
        return {
            "present": True,
            "healthy": data.get("ok") is True and case_count >= 3 and count_mismatch == 0 and matched == case_count and expected_failures == case_count,
            "case_count": case_count,
            "rows": row_count,
            "count_mismatch": count_mismatch,
            "matched": matched,
            "expected_failures": expected_failures,
        }
    return {"present": False, "healthy": False, "case_count": 0, "rows": 0, "count_mismatch": 0, "matched": 0, "expected_failures": 0}

def artifact_metadata(path: Path) -> str:
    stat = path.stat()
    mtime = dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    return f"{stat.st_size} bytes, updated `{mtime}`"


def dashboard_strict_health(artifacts: list[Path]) -> dict:
    markdown = next((artifact for artifact in artifacts if artifact.name == "vort-dashboard-strict-smoke.md"), None)

    def as_int(data: dict, field: str) -> int:
        value = data.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def row_int(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    def markdown_checks(data: dict) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)
        mode_counts = data.get("mode_counts") if isinstance(data.get("mode_counts"), list) else []
        mode_requirements = data.get("mode_requirements") if isinstance(data.get("mode_requirements"), list) else []
        missing_modes = data.get("missing_modes") if isinstance(data.get("missing_modes"), list) else []
        validation_reason_checks = data.get("validation_unhealthy_reason_checks") if isinstance(data.get("validation_unhealthy_reason_checks"), list) else []
        checks = data.get("checks") if isinstance(data.get("checks"), list) else []
        expected = [
            f"- ok: `{bool(data.get('ok'))}`",
            f"- checks: {as_int(data, 'check_count')}",
            "## Mode summary",
            "### Expected mode matrix",
            f"- expected modes: {as_int(data, 'expected_mode_count')}",
            f"- missing modes: {as_int(data, 'missing_mode_count')}",
            "### Validation unhealthy reason coverage",
            f"- covered reasons: {as_int(data, 'validation_unhealthy_reason_count')}",
            "## Checks",
        ]
        for row in mode_counts:
            if isinstance(row, dict):
                expected.append(
                    f"| `{row.get('mode')}` | {row_int(row, 'checks')} | {row_int(row, 'expected_failures')} | {row_int(row, 'matched')} |"
                )
        for row in mode_requirements:
            if isinstance(row, dict):
                expected.append(
                    f"| `{row.get('mode')}` | {row_int(row, 'checks')} | {row_int(row, 'min_checks')} | {row_int(row, 'missing_checks')} | {row_int(row, 'expected_failures')} | {row_int(row, 'min_expected_failures')} | {row_int(row, 'missing_expected_failures')} | {row_int(row, 'matched')} | {row_int(row, 'min_matched')} | {row_int(row, 'missing_matched')} |"
                )
        for row in missing_modes:
            if isinstance(row, dict):
                expected.append(
                    f"| `{row.get('mode')}` | {row_int(row, 'min_checks')} | {row_int(row, 'min_expected_failures')} | {row_int(row, 'min_matched')} |"
                )
        for row in validation_reason_checks:
            if isinstance(row, dict):
                expected.append(f"| `{row.get('reason')}` | `{row.get('check')}` | `{row.get('matched')}` |")
        for row in checks:
            if isinstance(row, dict):
                expected.append(
                    f"| `{row.get('name')}` | `{row.get('mode')}` | `{row.get('expected_failure')}` | {row_int(row, 'returncode')} | `{row.get('expected_output')}` | {row_int(row, 'actual_output_bytes')} | `{row.get('actual_output')}` | `{row.get('actual_output_truncated')}` | `{row.get('matched')}` |"
                )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.dashboard_strict_smoke":
            missing_modes = data.get("missing_modes")
            if not isinstance(missing_modes, list):
                missing_modes = []
            mode_counts = data.get("mode_counts")
            if not isinstance(mode_counts, list):
                mode_counts = []
            expected_modes = data.get("expected_modes")
            if not isinstance(expected_modes, list):
                expected_modes = []
            mode_requirements = data.get("mode_requirements")
            if not isinstance(mode_requirements, list):
                mode_requirements = []
            checks = data.get("checks")
            if not isinstance(checks, list):
                checks = []
            validation_reason_checks = data.get("validation_unhealthy_reason_checks")
            if not isinstance(validation_reason_checks, list):
                validation_reason_checks = []
            check_rows = len(checks)
            mode_count_rows = len(mode_counts)
            expected_mode_rows = len(expected_modes)
            mode_requirement_rows = len(mode_requirements)
            validation_reason_rows = len(validation_reason_checks)
            expected_failure_count = sum(row_int(row, "expected_failures") for row in mode_counts if isinstance(row, dict))
            matched_count = sum(row_int(row, "matched") for row in mode_counts if isinstance(row, dict))
            missing_checks = sum(row_int(row, "missing_checks") for row in mode_requirements if isinstance(row, dict))
            missing_expected_failures = sum(row_int(row, "missing_expected_failures") for row in mode_requirements if isinstance(row, dict))
            missing_matched = sum(row_int(row, "missing_matched") for row in mode_requirements if isinstance(row, dict))
            report_count_mismatch = (
                abs(as_int(data, "check_count") - check_rows)
                + abs(as_int(data, "check_count") - sum(row_int(row, "checks") for row in mode_counts if isinstance(row, dict)))
                + abs(as_int(data, "mode_count") - mode_count_rows)
                + abs(as_int(data, "expected_mode_count") - expected_mode_rows)
                + abs(as_int(data, "expected_mode_count") - mode_requirement_rows)
                + abs(as_int(data, "missing_mode_count") - len(missing_modes))
                + abs(as_int(data, "validation_unhealthy_reason_count") - validation_reason_rows)
                + (check_rows - sum(1 for row in checks if isinstance(row, dict) and row.get("matched") is True))
            )
            markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(data)
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "check_count": as_int(data, "check_count"),
                "check_rows": check_rows,
                "mode_count": as_int(data, "mode_count"),
                "mode_count_rows": mode_count_rows,
                "expected_failure_count": expected_failure_count,
                "matched_count": matched_count,
                "expected_mode_count": as_int(data, "expected_mode_count"),
                "expected_mode_rows": expected_mode_rows,
                "mode_requirement_rows": mode_requirement_rows,
                "validation_reason_rows": validation_reason_rows,
                "report_count_mismatch": report_count_mismatch,
                "missing_mode_count": as_int(data, "missing_mode_count"),
                "missing_checks": missing_checks,
                "missing_expected_failures": missing_expected_failures,
                "missing_matched": missing_matched,
                "missing_modes": missing_modes,
                "markdown_present": markdown_present,
                "markdown_rows": markdown_rows,
                "markdown_matched": markdown_matched,
                "markdown_unmatched": markdown_unmatched,
            }
    return {
        "present": False,
        "ok": False,
        "check_count": 0,
        "check_rows": 0,
        "mode_count": 0,
        "mode_count_rows": 0,
        "expected_failure_count": 0,
        "matched_count": 0,
        "expected_mode_count": 0,
        "expected_mode_rows": 0,
        "mode_requirement_rows": 0,
        "validation_reason_rows": 0,
        "report_count_mismatch": 0,
        "missing_mode_count": 0,
        "missing_checks": 0,
        "missing_expected_failures": 0,
        "missing_matched": 0,
        "missing_modes": [],
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
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

    def item_rows(data: dict | None, field: str) -> int:
        if not isinstance(data, dict):
            return 0
        items = data.get(field)
        return len(items) if isinstance(items, list) else 0

    config_count = int_field(config_smoke, "config_count")
    config_rows = item_rows(config_smoke, "configs")
    config_matched = matched_items(config_smoke, "configs")
    config_count_mismatch = abs(config_count - config_rows)
    config_row_unmatched = max(0, config_rows - config_matched)
    config_negative_count = int_field(config_negative, "case_count")
    config_negative_rows = item_rows(config_negative, "cases")
    config_negative_matched = matched_items(config_negative, "cases")
    config_negative_count_mismatch = abs(config_negative_count - config_negative_rows)
    config_negative_row_unmatched = max(0, config_negative_rows - config_negative_matched)
    category_negative_count = int_field(category_negative, "case_count")
    category_negative_rows = item_rows(category_negative, "cases")
    category_negative_matched = matched_items(category_negative, "cases")
    category_negative_count_mismatch = abs(category_negative_count - category_negative_rows)
    category_negative_row_unmatched = max(0, category_negative_rows - category_negative_matched)
    producers_required_count = int_field(producers_required, "artifact_count")
    producers_required_rows = item_rows(producers_required, "cases")
    producers_required_matched = matched_items(producers_required, "cases")
    producers_required_count_mismatch = abs(producers_required_count - producers_required_rows)
    producers_required_row_unmatched = max(0, producers_required_rows - producers_required_matched)
    producers_required_smoke_gate_count = int_field(producers_required, "required_smoke_gate_count")
    producers_negative_count = int_field(producers_negative, "case_count")
    producers_negative_rows = item_rows(producers_negative, "cases")
    producers_negative_matched = matched_items(producers_negative, "cases")
    producers_negative_count_mismatch = abs(producers_negative_count - producers_negative_rows)
    producers_negative_row_unmatched = max(0, producers_negative_rows - producers_negative_matched)
    healthy = (
        isinstance(config_smoke, dict)
        and bool(config_smoke.get("ok"))
        and config_count > 0
        and config_matched == config_count
        and config_count_mismatch == 0
        and config_row_unmatched == 0
        and isinstance(config_negative, dict)
        and bool(config_negative.get("ok"))
        and config_negative_count > 0
        and config_negative_matched == config_negative_count
        and config_negative_count_mismatch == 0
        and config_negative_row_unmatched == 0
        and isinstance(category_negative, dict)
        and bool(category_negative.get("ok"))
        and category_negative_count > 0
        and category_negative_matched == category_negative_count
        and category_negative_count_mismatch == 0
        and category_negative_row_unmatched == 0
        and isinstance(producers_required, dict)
        and bool(producers_required.get("ok"))
        and producers_required_count > 0
        and producers_required_matched == producers_required_count
        and producers_required_count_mismatch == 0
        and producers_required_row_unmatched == 0
        and producers_required_smoke_gate_count > 0
        and isinstance(producers_negative, dict)
        and bool(producers_negative.get("ok"))
        and producers_negative_count > 0
        and producers_negative_matched == producers_negative_count
        and producers_negative_count_mismatch == 0
        and producers_negative_row_unmatched == 0
    )
    return {
        "config_index_present": isinstance(config_smoke, dict),
        "config_index_ok": bool(config_smoke.get("ok")) if isinstance(config_smoke, dict) else False,
        "config_index_config_count": config_count,
        "config_index_config_rows": config_rows,
        "config_index_matched": config_matched,
        "config_index_unmatched": config_count - config_matched,
        "config_index_count_mismatch": config_count_mismatch,
        "config_index_row_unmatched": config_row_unmatched,
        "config_index_negative_present": isinstance(config_negative, dict),
        "config_index_negative_ok": bool(config_negative.get("ok")) if isinstance(config_negative, dict) else False,
        "config_index_negative_case_count": config_negative_count,
        "config_index_negative_rows": config_negative_rows,
        "config_index_negative_matched": config_negative_matched,
        "config_index_negative_unmatched": config_negative_count - config_negative_matched,
        "config_index_negative_count_mismatch": config_negative_count_mismatch,
        "config_index_negative_row_unmatched": config_negative_row_unmatched,
        "category_negative_present": isinstance(category_negative, dict),
        "category_negative_ok": bool(category_negative.get("ok")) if isinstance(category_negative, dict) else False,
        "category_negative_case_count": category_negative_count,
        "category_negative_rows": category_negative_rows,
        "category_negative_matched": category_negative_matched,
        "category_negative_unmatched": category_negative_count - category_negative_matched,
        "category_negative_count_mismatch": category_negative_count_mismatch,
        "category_negative_row_unmatched": category_negative_row_unmatched,
        "producers_required_present": isinstance(producers_required, dict),
        "producers_required_ok": bool(producers_required.get("ok")) if isinstance(producers_required, dict) else False,
        "producers_required_artifact_count": producers_required_count,
        "producers_required_rows": producers_required_rows,
        "producers_required_matched": producers_required_matched,
        "producers_required_unmatched": producers_required_count - producers_required_matched,
        "producers_required_count_mismatch": producers_required_count_mismatch,
        "producers_required_row_unmatched": producers_required_row_unmatched,
        "producers_required_smoke_gate_count": producers_required_smoke_gate_count,
        "producers_negative_present": isinstance(producers_negative, dict),
        "producers_negative_ok": bool(producers_negative.get("ok")) if isinstance(producers_negative, dict) else False,
        "producers_negative_case_count": producers_negative_count,
        "producers_negative_rows": producers_negative_rows,
        "producers_negative_matched": producers_negative_matched,
        "producers_negative_unmatched": producers_negative_count - producers_negative_matched,
        "producers_negative_count_mismatch": producers_negative_count_mismatch,
        "producers_negative_row_unmatched": producers_negative_row_unmatched,
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
    checked_schemas = checked_schemas if isinstance(checked_schemas, list) else []
    checked_schema_count = len(checked_schemas)
    checked_schema_unique_count = len({item for item in checked_schemas if isinstance(item, str)})
    checked_schema_duplicate_count = checked_schema_count - checked_schema_unique_count
    docs_case_count = int_field(docs_negative, "case_count")
    docs_cases = docs_negative.get("cases") if isinstance(docs_negative, dict) else []
    docs_cases = docs_cases if isinstance(docs_cases, list) else []
    docs_case_rows = len(docs_cases)
    docs_matched = sum(1 for item in docs_cases if isinstance(item, dict) and item.get("matched") is True)
    docs_count_mismatch = abs(docs_case_count - docs_case_rows)
    docs_row_unmatched = max(0, docs_case_rows - docs_matched)
    cli_failure_ok = bool(smoke.get("cli_failure_ok")) if isinstance(smoke, dict) else False
    cli_failure_hint = str(smoke.get("cli_failure_hint") or "") if isinstance(smoke, dict) else ""
    healthy = (
        isinstance(smoke, dict)
        and bool(smoke.get("ok"))
        and checked_schema_count > 0
        and checked_schema_duplicate_count == 0
        and bool(smoke.get("cli_success_ok"))
        and not cli_failure_ok
        and bool(cli_failure_hint)
        and int_field(smoke, "report_rows") > 0
        and int_field(smoke, "corrupt_rows") > 0
        and isinstance(docs_negative, dict)
        and bool(docs_negative.get("ok"))
        and docs_case_count > 0
        and docs_matched == docs_case_count
        and docs_count_mismatch == 0
        and docs_row_unmatched == 0
    )
    return {
        "present": isinstance(smoke, dict),
        "ok": bool(smoke.get("ok")) if isinstance(smoke, dict) else False,
        "checked_schema_count": checked_schema_count,
        "checked_schema_unique_count": checked_schema_unique_count,
        "checked_schema_duplicate_count": checked_schema_duplicate_count,
        "cli_success_ok": bool(smoke.get("cli_success_ok")) if isinstance(smoke, dict) else False,
        "cli_failure_ok": cli_failure_ok,
        "cli_failure_hint": cli_failure_hint,
        "report_rows": int_field(smoke, "report_rows"),
        "corrupt_rows": int_field(smoke, "corrupt_rows"),
        "docs_negative_present": isinstance(docs_negative, dict),
        "docs_negative_ok": bool(docs_negative.get("ok")) if isinstance(docs_negative, dict) else False,
        "docs_negative_case_count": docs_case_count,
        "docs_negative_rows": docs_case_rows,
        "docs_negative_matched": docs_matched,
        "docs_negative_unmatched": docs_case_count - docs_matched,
        "docs_negative_count_mismatch": docs_count_mismatch,
        "docs_negative_row_unmatched": docs_row_unmatched,
        "healthy": healthy,
    }


def header_inspect_health(artifacts: list[Path]) -> dict:
    markdown = next((artifact for artifact in artifacts if artifact.name == "vort-header-inspect-smoke.md"), None)

    def markdown_cell(value: object) -> str:
        return str(value).replace("|", "\\|")

    def markdown_sample(value: object, limit: int = 32) -> str:
        text = str(value)
        if len(text) <= limit:
            return markdown_cell(text)
        head = max(8, limit - 12)
        tail = 8
        return markdown_cell(f"{text[:head]}…{text[-tail:]} ({len(text)} hex)")

    def markdown_checks(data: dict) -> tuple[bool, int, int, int]:
        if markdown is None:
            return (False, 0, 0, 1)
        try:
            text = markdown.read_text(errors="replace")
        except Exception:
            return (True, 0, 0, 1)

        cases = data.get("cases") if isinstance(data.get("cases"), list) else []
        negative_items = data.get("negative_items") if isinstance(data.get("negative_items"), list) else []
        command_coverage = data.get("command_coverage") if isinstance(data.get("command_coverage"), list) else []
        workflow_coverage = data.get("workflow_coverage") if isinstance(data.get("workflow_coverage"), list) else []
        missing_workflows = data.get("missing_workflows") if isinstance(data.get("missing_workflows"), list) else []
        negative_error_counts = data.get("negative_error_counts") if isinstance(data.get("negative_error_counts"), dict) else {}
        expected = [
            f"- ok: `{bool(data.get('ok'))}`",
            f"- cases: {as_int('case_count')} (raw={as_int('raw_cases')}, zlib={as_int('zlib_cases')}, gzip={as_int('gzip_cases')})",
            f"- dictionary cases: {as_int('dictionary_cases')}",
            f"- optional gzip header cases: {as_int('optional_header_cases')}",
            f"- FHCRC cases: {as_int('fhcrc_cases')}",
            f"- malformed negative cases: {as_int('negative_cases')}",
            "## Format summary",
            "## Command coverage",
            "## Workflow coverage",
            "### Required workflow coverage",
            f"- required rows: {as_int('required_workflow_count')}",
            f"- missing rows: {as_int('missing_workflow_count')}",
            "## Successful inspections",
            "## Expected failures",
            "### Error summary",
        ]
        for format_name in ("raw", "zlib", "gzip"):
            format_cases = [case for case in cases if isinstance(case, dict) and case.get("format") == format_name]
            expected.append(
                "| {format} | {cases} | {bytes} | {dictionary} | {optional} | {fhcrc} |".format(
                    format=markdown_cell(format_name),
                    cases=len(format_cases),
                    bytes=sum(as_row_int(case, "bytes") for case in format_cases),
                    dictionary=sum(1 for case in format_cases if case.get("has_dictionary") is True),
                    optional=sum(1 for case in format_cases if case.get("has_optional_fields") is True),
                    fhcrc=sum(1 for case in format_cases if case.get("header_crc") is True),
                )
            )
            expected.append(f"| {markdown_cell(format_name)} | {sum(1 for item in negative_items if isinstance(item, dict) and item.get('format') == format_name)} |")
        for row in command_coverage:
            if isinstance(row, dict):
                expected.append(f"| `{markdown_cell(row.get('command', ''))}` | {markdown_cell(row.get('format', ''))} | {as_row_int(row, 'successes')} | {as_row_int(row, 'failures')} |")
        for row in workflow_coverage:
            if isinstance(row, dict):
                expected.append(f"| `{markdown_cell(row.get('command', ''))}` | {markdown_cell(row.get('workflow', ''))} | {markdown_cell(row.get('format', ''))} | {as_row_int(row, 'successes')} |")
        for row in missing_workflows:
            if isinstance(row, dict):
                expected.append(f"| `{markdown_cell(row.get('command', ''))}` | {markdown_cell(row.get('workflow', ''))} | {markdown_cell(row.get('format', ''))} |")
        for row in cases:
            if isinstance(row, dict):
                expected.append(
                    f"| {markdown_cell(row.get('name', ''))} | `{markdown_cell(row.get('schema_name', ''))}` | {as_row_int(row, 'bytes')} | {markdown_cell(row.get('detail', ''))} | `{markdown_cell(row.get('command', ''))}` | `{markdown_sample(row.get('sample', ''))}` |"
                )
        for error_name, count in sorted((str(key), value) for key, value in negative_error_counts.items()):
            if isinstance(count, int) and not isinstance(count, bool):
                expected.append(f"| `{markdown_cell(error_name)}` | {count} |")
        for row in negative_items:
            if isinstance(row, dict):
                expected.append(
                    f"| {markdown_cell(row.get('name', ''))} | `{markdown_cell(row.get('command', ''))}` | `{markdown_sample(row.get('sample', ''))}` | `{markdown_cell(row.get('expected_error', ''))}` |"
                )
        matched = sum(1 for needle in expected if needle in text)
        return (True, len(expected), matched, len(expected) - matched)

    def as_row_int(row: dict, field: str) -> int:
        value = row.get(field)
        return value if isinstance(value, int) and not isinstance(value, bool) else 0

    for artifact in artifacts:
        data = read_json(artifact) if artifact.suffix == ".json" else {}
        if data.get("schema") == "vort.header_inspect_smoke":
            missing_workflows = data.get("missing_workflows")
            if not isinstance(missing_workflows, list):
                missing_workflows = []
            def as_int(field: str) -> int:
                value = data.get(field)
                return value if isinstance(value, int) and not isinstance(value, bool) else 0
            cases = data.get("cases") if isinstance(data.get("cases"), list) else []
            negative_items = data.get("negative_items") if isinstance(data.get("negative_items"), list) else []
            command_coverage = data.get("command_coverage") if isinstance(data.get("command_coverage"), list) else []
            workflow_coverage = data.get("workflow_coverage") if isinstance(data.get("workflow_coverage"), list) else []
            required_workflows = data.get("required_workflows") if isinstance(data.get("required_workflows"), list) else []
            help_workflows = data.get("help_workflows") if isinstance(data.get("help_workflows"), list) else []
            negative_error_counts = data.get("negative_error_counts") if isinstance(data.get("negative_error_counts"), dict) else {}
            report_rows = len(cases)
            negative_item_rows = len(negative_items)
            command_coverage_rows = len(command_coverage)
            workflow_coverage_rows = len(workflow_coverage)
            required_workflow_rows = len(required_workflows)
            help_workflow_rows = len(help_workflows)
            report_count_mismatch = (
                abs(as_int("case_count") - report_rows)
                + abs(as_int("raw_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("format") == "raw"))
                + abs(as_int("zlib_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("format") == "zlib"))
                + abs(as_int("gzip_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("format") == "gzip"))
                + abs(as_int("negative_cases") - negative_item_rows)
                + abs(as_int("raw_negative_cases") - sum(1 for row in negative_items if isinstance(row, dict) and row.get("format") == "raw"))
                + abs(as_int("zlib_negative_cases") - sum(1 for row in negative_items if isinstance(row, dict) and row.get("format") == "zlib"))
                + abs(as_int("gzip_negative_cases") - sum(1 for row in negative_items if isinstance(row, dict) and row.get("format") == "gzip"))
                + abs(as_int("command_count") - command_coverage_rows)
                + abs(as_int("command_successes") - sum(as_row_int(row, "successes") for row in command_coverage if isinstance(row, dict)))
                + abs(as_int("command_failures") - sum(as_row_int(row, "failures") for row in command_coverage if isinstance(row, dict)))
                + abs(as_int("workflow_count") - workflow_coverage_rows)
                + abs(as_int("workflow_successes") - sum(as_row_int(row, "successes") for row in workflow_coverage if isinstance(row, dict)))
                + abs(as_int("dictionary_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("has_dictionary") is True))
                + abs(as_int("optional_header_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("has_optional_fields") is True))
                + abs(as_int("fhcrc_cases") - sum(1 for row in cases if isinstance(row, dict) and row.get("header_crc") is True))
                + abs(as_int("required_workflow_count") - required_workflow_rows)
                + abs(as_int("missing_workflow_count") - len(missing_workflows))
                + abs(as_int("help_workflow_count") - help_workflow_rows)
                + abs(as_int("negative_cases") - sum(value for value in negative_error_counts.values() if isinstance(value, int) and not isinstance(value, bool)))
            )
            markdown_present, markdown_rows, markdown_matched, markdown_unmatched = markdown_checks(data)
            return {
                "present": True,
                "ok": bool(data.get("ok")),
                "report_rows": report_rows,
                "negative_item_rows": negative_item_rows,
                "command_coverage_rows": command_coverage_rows,
                "workflow_coverage_rows": workflow_coverage_rows,
                "required_workflow_rows": required_workflow_rows,
                "help_workflow_rows": help_workflow_rows,
                "report_count_mismatch": report_count_mismatch,
                "markdown_present": markdown_present,
                "markdown_rows": markdown_rows,
                "markdown_matched": markdown_matched,
                "markdown_unmatched": markdown_unmatched,
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
        "report_rows": 0,
        "negative_item_rows": 0,
        "command_coverage_rows": 0,
        "workflow_coverage_rows": 0,
        "required_workflow_rows": 0,
        "help_workflow_rows": 0,
        "report_count_mismatch": 0,
        "markdown_present": False,
        "markdown_rows": 0,
        "markdown_matched": 0,
        "markdown_unmatched": 0,
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
    level_report = level_report_health(artifacts)
    dynamic_plan = dynamic_plan_health(artifacts)
    fuzz_health = fuzz_corpus_health(artifacts)
    decode_stage_health_summary = decode_stage_health(artifacts)
    native_fuzz = native_fuzz_corpus_health(artifacts)
    br_static_dictionary = br_static_dictionary_health(artifacts)
    png_scratch = png_scratch_health(artifacts)
    zlib_relaxed = zlib_relaxed_health(artifacts)
    snappy_report = snappy_report_health(artifacts)
    checksum_bench = checksum_bench_health(artifacts)
    chunk_cursor_bench = chunk_cursor_bench_health(artifacts)
    deflate_match_copy_bench = deflate_match_copy_bench_health(artifacts)
    deflate_huffman_build_bench = deflate_huffman_build_bench_health(artifacts)
    deflate_huffman_lookup_bench = deflate_huffman_lookup_bench_health(artifacts)
    deflate_chunked_huffman_bench = deflate_chunked_huffman_bench_health(artifacts)
    deflate_extra_bits_bench = deflate_extra_bits_bench_health(artifacts)
    dictionary_decode_bench = dictionary_decode_bench_health(artifacts)
    png_scanline_bench = png_scanline_bench_health(artifacts)
    chunked_zlib_bench = chunked_zlib_bench_health(artifacts)
    png_streaming_zlib_bench = png_streaming_zlib_bench_health(artifacts)
    deflate_dynamic_decode_profile = deflate_dynamic_decode_profile_health(artifacts)
    native_library_bench = native_library_bench_health(artifacts)
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
        and header_health["markdown_present"]
        and header_health["missing_workflow_count"] == 0
        and header_health["report_count_mismatch"] == 0
        and header_health["case_count"] > 0
        and header_health["report_rows"] == header_health["case_count"]
        and header_health["raw_cases"] > 0
        and header_health["zlib_cases"] > 0
        and header_health["gzip_cases"] > 0
        and header_health["negative_cases"] > 0
        and header_health["negative_item_rows"] == header_health["negative_cases"]
        and header_health["raw_negative_cases"] > 0
        and header_health["zlib_negative_cases"] > 0
        and header_health["gzip_negative_cases"] > 0
        and header_health["command_count"] > 0
        and header_health["command_coverage_rows"] == header_health["command_count"]
        and header_health["command_successes"] > 0
        and header_health["command_failures"] > 0
        and header_health["workflow_count"] > 0
        and header_health["workflow_coverage_rows"] == header_health["workflow_count"]
        and header_health["workflow_successes"] > 0
        and header_health["dictionary_cases"] > 0
        and header_health["optional_header_cases"] > 0
        and header_health["fhcrc_cases"] > 0
        and header_health["required_workflow_rows"] == header_health["required_workflow_count"]
        and header_health["help_workflow_rows"] == header_health["required_workflow_count"]
        and header_health["markdown_rows"] > 0
        and header_health["markdown_unmatched"] == 0
    )
    strict_healthy = (
        strict_health["present"]
        and strict_health["ok"]
        and strict_health["markdown_present"]
        and strict_health["missing_mode_count"] == 0
        and strict_health["report_count_mismatch"] == 0
        and strict_health["check_rows"] == strict_health["check_count"]
        and strict_health["mode_count_rows"] == strict_health["mode_count"]
        and strict_health["expected_mode_rows"] == strict_health["expected_mode_count"]
        and strict_health["mode_requirement_rows"] == strict_health["expected_mode_count"]
        and strict_health["markdown_rows"] > 0
        and strict_health["markdown_unmatched"] == 0
    )
    dashboard_configuration_healthy = dashboard_configuration["healthy"]
    validation_json_healthy = validation_json["healthy"]
    sidecar_corrupt_healthy = sidecar_corrupt_health_summary["healthy"]
    huffman_healthy = huffman_health["healthy"]
    level_report_healthy = level_report["healthy"]
    dynamic_plan_healthy = dynamic_plan["healthy"]
    fuzz_healthy = fuzz_health["healthy"]
    decode_stage_healthy = decode_stage_health_summary["healthy"]
    python_zlib_healthy = python_zlib_health["healthy"]
    native_fuzz_healthy = native_fuzz["healthy"]
    png_scratch_healthy = png_scratch["healthy"]
    zlib_relaxed_healthy = zlib_relaxed["healthy"]
    snappy_report_healthy = snappy_report["healthy"]
    checksum_bench_healthy = checksum_bench["healthy"]
    chunk_cursor_bench_healthy = chunk_cursor_bench["healthy"]
    deflate_match_copy_bench_healthy = deflate_match_copy_bench["healthy"]
    deflate_huffman_build_bench_healthy = deflate_huffman_build_bench["healthy"]
    deflate_huffman_lookup_bench_healthy = deflate_huffman_lookup_bench["healthy"]
    deflate_chunked_huffman_bench_healthy = deflate_chunked_huffman_bench["healthy"]
    deflate_extra_bits_bench_healthy = deflate_extra_bits_bench["healthy"]
    dictionary_decode_bench_healthy = dictionary_decode_bench["healthy"]
    png_scanline_bench_healthy = png_scanline_bench["healthy"]
    chunked_zlib_bench_healthy = chunked_zlib_bench["healthy"]
    png_streaming_zlib_bench_healthy = png_streaming_zlib_bench["healthy"]
    deflate_dynamic_decode_profile_healthy = deflate_dynamic_decode_profile["healthy"]
    native_library_bench_healthy = native_library_bench["healthy"]
    native_allocation_healthy = native_allocation["healthy"]
    native_summary_error_healthy = native_summary_error_health["healthy"]
    native_summary_error_negative_healthy = native_summary_error_negative["healthy"]
    lz4_native_summary_healthy = lz4_native_summary["healthy"]
    zstd_native_summary_healthy = zstd_native_summary["healthy"]
    native_tier_healthy = native_tier_health["healthy"]
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
        and level_report_healthy
        and dynamic_plan_healthy
        and fuzz_healthy
        and decode_stage_healthy
        and native_fuzz_healthy
        and png_scratch_healthy
        and zlib_relaxed_healthy
        and native_allocation_healthy
        and python_zlib_healthy
        and native_codec_health["healthy"]
        and zstd_compare["healthy"]
        and snappy_report_healthy
        and checksum_bench_healthy
        and chunk_cursor_bench_healthy
        and deflate_match_copy_bench_healthy
        and deflate_huffman_build_bench_healthy
        and deflate_huffman_lookup_bench_healthy
        and deflate_chunked_huffman_bench_healthy
        and deflate_extra_bits_bench_healthy
        and dictionary_decode_bench_healthy
        and png_scanline_bench_healthy
        and chunked_zlib_bench_healthy
        and png_streaming_zlib_bench_healthy
        and deflate_dynamic_decode_profile_healthy
        and native_library_bench_healthy
        and br_static_dictionary["healthy"]
        and native_summary_error_healthy
        and native_summary_error_negative_healthy
        and lz4_native_summary_healthy
        and zstd_native_summary_healthy
        and native_tier_healthy
        and native_tier_discovery_healthy
    )
    validation_unhealthy_reasons = []
    if not producer_healthy:
        validation_unhealthy_reasons.append("missing_producer_steps")
    if not smoke_gate_healthy:
        validation_unhealthy_reasons.append("missing_required_smoke_gates")
    if not (header_health["present"] and header_health["markdown_present"]):
        validation_unhealthy_reasons.append("missing_header_inspect_artifact")
    elif not header_health["ok"]:
        validation_unhealthy_reasons.append("header_inspect_failed")
    elif header_health["missing_workflow_count"]:
        validation_unhealthy_reasons.append("missing_header_workflows")
    elif not header_healthy:
        validation_unhealthy_reasons.append("header_inspect_undercovered")
    if not (strict_health["present"] and strict_health["markdown_present"]):
        validation_unhealthy_reasons.append("missing_dashboard_strict_artifact")
    elif not strict_health["ok"]:
        validation_unhealthy_reasons.append("dashboard_strict_failed")
    elif strict_health["missing_mode_count"]:
        validation_unhealthy_reasons.append("missing_dashboard_strict_modes")
    elif not strict_healthy:
        validation_unhealthy_reasons.append("dashboard_strict_failed")
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
    if not (sidecar_corrupt_health_summary["present"] and sidecar_corrupt_health_summary["markdown_present"]):
        validation_unhealthy_reasons.append("missing_sidecar_corrupt_artifact")
    elif not sidecar_corrupt_healthy:
        validation_unhealthy_reasons.append("sidecar_corrupt_failed")
    if not (huffman_health["present"] and huffman_health["markdown_present"]):
        validation_unhealthy_reasons.append("missing_huffman_length_artifact")
    elif not huffman_healthy:
        validation_unhealthy_reasons.append("huffman_length_failed")
    if not level_report["present"]:
        validation_unhealthy_reasons.append("missing_level_report_artifact")
    elif not level_report_healthy:
        validation_unhealthy_reasons.append("level_report_failed")
    if not dynamic_plan["present"]:
        validation_unhealthy_reasons.append("missing_dynamic_plan_artifact")
    elif not dynamic_plan_healthy:
        validation_unhealthy_reasons.append("dynamic_plan_failed")
    if not (fuzz_health["present"] and fuzz_health["markdown_present"]):
        validation_unhealthy_reasons.append("missing_fuzz_corpus_artifact")
    elif not (fuzz_health["report_healthy"] and fuzz_health["markdown_healthy"]):
        validation_unhealthy_reasons.append("fuzz_corpus_failed")
    if not fuzz_health["coverage_present"]:
        validation_unhealthy_reasons.append("missing_fuzz_coverage_artifact")
    elif not fuzz_health["coverage_healthy"]:
        validation_unhealthy_reasons.append("fuzz_coverage_failed")
    if not (native_fuzz["present"] and native_fuzz["markdown_present"]):
        validation_unhealthy_reasons.append("missing_native_fuzz_corpus_artifact")
    elif not (native_fuzz["report_healthy"] and native_fuzz["markdown_healthy"]):
        validation_unhealthy_reasons.append("native_fuzz_corpus_failed")
    if not native_fuzz["coverage_present"]:
        validation_unhealthy_reasons.append("missing_native_fuzz_coverage_artifact")
    elif not native_fuzz["coverage_healthy"]:
        validation_unhealthy_reasons.append("native_fuzz_coverage_failed")
    if not (png_scratch["present"] and png_scratch["markdown_present"]):
        validation_unhealthy_reasons.append("missing_png_scratch_artifact")
    elif not png_scratch_healthy:
        validation_unhealthy_reasons.append("png_scratch_failed")
    if not (zlib_relaxed["present"] and zlib_relaxed["gate_present"] and zlib_relaxed["markdown_present"]):
        validation_unhealthy_reasons.append("missing_zlib_relaxed_artifact")
    elif not zlib_relaxed_healthy:
        validation_unhealthy_reasons.append("zlib_relaxed_failed")
    if not snappy_report["present"]:
        validation_unhealthy_reasons.append("missing_snappy_report_artifact")
    elif not snappy_report_healthy:
        validation_unhealthy_reasons.append("snappy_report_failed")
    if not checksum_bench["present"]:
        validation_unhealthy_reasons.append("missing_checksum_bench_artifact")
    elif not checksum_bench_healthy:
        validation_unhealthy_reasons.append("checksum_bench_failed")
    if not chunk_cursor_bench["present"]:
        validation_unhealthy_reasons.append("missing_chunk_cursor_bench_artifact")
    elif not chunk_cursor_bench_healthy:
        validation_unhealthy_reasons.append("chunk_cursor_bench_failed")
    if not deflate_match_copy_bench["present"]:
        validation_unhealthy_reasons.append("missing_deflate_match_copy_bench_artifact")
    elif not deflate_match_copy_bench_healthy:
        validation_unhealthy_reasons.append("deflate_match_copy_bench_failed")
    if not deflate_huffman_build_bench["present"]:
        validation_unhealthy_reasons.append("missing_deflate_huffman_build_bench_artifact")
    elif not deflate_huffman_build_bench_healthy:
        validation_unhealthy_reasons.append("deflate_huffman_build_bench_failed")
    if not deflate_huffman_lookup_bench["present"]:
        validation_unhealthy_reasons.append("missing_deflate_huffman_lookup_bench_artifact")
    elif not deflate_huffman_lookup_bench_healthy:
        validation_unhealthy_reasons.append("deflate_huffman_lookup_bench_failed")
    if not deflate_chunked_huffman_bench["present"]:
        validation_unhealthy_reasons.append("missing_deflate_chunked_huffman_bench_artifact")
    elif not deflate_chunked_huffman_bench_healthy:
        validation_unhealthy_reasons.append("deflate_chunked_huffman_bench_failed")
    if not deflate_extra_bits_bench["present"]:
        validation_unhealthy_reasons.append("missing_deflate_extra_bits_bench_artifact")
    elif not deflate_extra_bits_bench_healthy:
        validation_unhealthy_reasons.append("deflate_extra_bits_bench_failed")
    if not dictionary_decode_bench["present"]:
        validation_unhealthy_reasons.append("missing_dictionary_decode_bench_artifact")
    elif not dictionary_decode_bench_healthy:
        validation_unhealthy_reasons.append("dictionary_decode_bench_failed")
    if not png_scanline_bench["present"]:
        validation_unhealthy_reasons.append("missing_png_scanline_bench_artifact")
    elif not png_scanline_bench_healthy:
        validation_unhealthy_reasons.append("png_scanline_bench_failed")
    if not (chunked_zlib_bench["present"] and chunked_zlib_bench["markdown_present"]):
        validation_unhealthy_reasons.append("missing_chunked_zlib_bench_artifact")
    elif not chunked_zlib_bench_healthy:
        validation_unhealthy_reasons.append("chunked_zlib_bench_failed")
    if not png_streaming_zlib_bench["present"]:
        validation_unhealthy_reasons.append("missing_png_streaming_zlib_bench_artifact")
    elif not png_streaming_zlib_bench_healthy:
        validation_unhealthy_reasons.append("png_streaming_zlib_bench_failed")
    if not deflate_dynamic_decode_profile["present"]:
        validation_unhealthy_reasons.append("missing_deflate_dynamic_decode_profile_artifact")
    elif not deflate_dynamic_decode_profile_healthy:
        validation_unhealthy_reasons.append("deflate_dynamic_decode_profile_failed")
    if not native_library_bench["present"]:
        validation_unhealthy_reasons.append("missing_native_library_bench_artifact")
    elif not native_library_bench_healthy:
        validation_unhealthy_reasons.append("native_library_bench_failed")
    native_allocation_present = (
        native_allocation["present"]
        and native_allocation["smoke_present"]
        and native_allocation["negative_present"]
        and native_allocation["markdown_present"]
    )
    if not native_allocation_present:
        validation_unhealthy_reasons.append("missing_native_allocation_artifact")
    elif not native_allocation_healthy:
        validation_unhealthy_reasons.append("native_allocation_failed")
    if not (decode_stage_health_summary["present"] and decode_stage_health_summary["markdown_present"]):
        validation_unhealthy_reasons.append("missing_decode_stage_artifact")
    elif not decode_stage_healthy:
        validation_unhealthy_reasons.append("decode_stage_failed")
    if not python_zlib_health["present"]:
        validation_unhealthy_reasons.append("missing_python_zlib_diff_artifact")
    elif not python_zlib_healthy:
        validation_unhealthy_reasons.append("python_zlib_diff_failed")
    if not native_codec_health["present"]:
        validation_unhealthy_reasons.append("missing_native_codec_probes_artifact")
    elif not native_codec_health["markdown_present"]:
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
        and br_static_dictionary["upstream_report_present"]
        and br_static_dictionary["upstream_markdown_present"]
        and br_static_dictionary["node_present"]
        and br_static_dictionary["audit_present"]
        and br_static_dictionary["negative_present"]
        and br_static_dictionary["candidate_markdown_present"]
        and br_static_dictionary["report_present"]
        and br_static_dictionary["report_csv_present"]
        and br_static_dictionary["report_markdown_present"]
        and br_static_dictionary["report_negative_present"]
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
    if not native_tier_health["present"]:
        validation_unhealthy_reasons.append("missing_native_tier_range_artifact")
    elif not native_tier_healthy:
        validation_unhealthy_reasons.append("native_tier_range_failed")
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
        f"- sidecar corrupt smoke: {sidecar_corrupt_health_summary['metadata_ok_rows']}/{sidecar_corrupt_health_summary['rows']} metadata-ok rows, {sidecar_corrupt_health_summary['full_rejected_rows']}/{sidecar_corrupt_health_summary['rows']} full-rejected rows, Markdown {sidecar_corrupt_health_summary['markdown_matched']}/{sidecar_corrupt_health_summary['markdown_rows']}, healthy `{sidecar_corrupt_healthy}`",
        f"- huffman length oracle: {huffman_health['optimal_rows']}/{huffman_health['row_count']} production optimal rows, {huffman_health['package_merge_optimal_rows']}/{huffman_health['row_count']} package-merge optimal rows, gaps {huffman_health['worst_gap_bits']}/{huffman_health['package_merge_worst_gap_bits']}, malformed rows {huffman_health['malformed_rows']}, healthy `{huffman_healthy}`",
        f"- level report: {level_report['rows']}/{level_report['expected_rows']} rows, shape {level_report['shape_rows']}, token/ratio/roundtrip {level_report['token_accounting_rows']}/{level_report['ratio_rows']}/{level_report['roundtrip_rows']}, Markdown {level_report['markdown_matched']}/{level_report['markdown_summary_rows']}, healthy `{level_report_healthy}`",
        f"- dynamic plan: {dynamic_plan['rows']}/{dynamic_plan['expected_rows']} rows across {dynamic_plan['source_count']}/{dynamic_plan['expected_source_count']} sources, token/histogram/ratio/slack/wrapper {dynamic_plan['token_accounting_rows']}/{dynamic_plan['histogram_rows']}/{dynamic_plan['ratio_rows']}/{dynamic_plan['slack_rows']}/{dynamic_plan['wrapper_rows']}, healthy `{dynamic_plan_healthy}`",
        f"- fuzz corpus coverage: {fuzz_health['matched_rows']}/{fuzz_health['cases']} rows matched, Markdown {fuzz_health['markdown_matched']}/{fuzz_health['markdown_rows']}, exact-error rows {fuzz_health['exact_error_expectations']}, coverage requirements {fuzz_health['coverage_mode_requirements']}/{fuzz_health['coverage_error_requirements']}, healthy `{fuzz_healthy}`",
        f"- native fuzz corpus: {native_fuzz['matched_rows']}/{native_fuzz['cases']} rows matched, Markdown {native_fuzz['markdown_matched']}/{native_fuzz['markdown_rows']}, coverage matched modes/errors {native_fuzz['coverage_mode_matched']}/{native_fuzz['coverage_error_matched']}, healthy `{native_fuzz['healthy']}`",
        f"- decode-stage smoke: {decode_stage_health_summary['matched_error_rows']}/{decode_stage_health_summary['error_rows']} error rows matched across {decode_stage_health_summary['rows']} timing rows, healthy `{decode_stage_healthy}`",
        f"- Python zlib differential: payloads {python_zlib_health['payloads']} (large-file {python_zlib_health['large_file_payloads']}, file-hex encodes {python_zlib_health['file_hex_encode_cases']}), dynamic {python_zlib_health['dynamic_payloads']}, dictionary encode raw/zlib {python_zlib_health['raw_dict_encode_cases']}/{python_zlib_health['zlib_dict_encode_cases']}, CLI successes/failures {python_zlib_health['cli_successes']}/{python_zlib_health['expected_failures']}, healthy `{python_zlib_healthy}`",
        f"- native codec probes: {native_codec_health['ok_probe_count']}/{native_codec_health['probe_count']} probes ok, rows/mismatch/case-sum {native_codec_health['probe_rows']}/{native_codec_health['probe_count_mismatch']}/{native_codec_health['probe_case_sum']}, capabilities {native_codec_health['ok_capability_count']}/{native_codec_health['capability_count']} ok, capability rows/mismatch/missing/duplicate {native_codec_health['capability_rows']}/{native_codec_health['capability_count_mismatch']}/{native_codec_health['missing_required_capabilities']}/{native_codec_health['duplicate_capability_rows']}, coverage rows/mismatch/missing/duplicate {native_codec_health['coverage_rows']}/{native_codec_health['coverage_count_mismatch']}/{native_codec_health['missing_required_coverage']}/{native_codec_health['duplicate_coverage_rows']}, cases total/lib/incremental/chunked/reusable-chunked/fse-repeat {native_codec_health['total_cases']}/{native_codec_health['lib_generated_cases']}/{native_codec_health['incremental_cases']}/{native_codec_health['chunked_cases']}/{native_codec_health['reusable_chunked_cases']}/{native_codec_health['fse_repeat_cases']}, healthy `{native_codec_health['healthy']}`",
        f"- native codec probe Markdown: {native_codec_health['markdown_matched']}/{native_codec_health['markdown_rows']} checks matched, unmatched {native_codec_health['markdown_unmatched']}",
        f"- native summary errors: cases total/lz4/zstd/checksum/corrupt/truncated/magic/skippable/body/checksum-phase/frame {native_summary_error_health['case_count']}/{native_summary_error_health['lz4_case_count']}/{native_summary_error_health['zstd_case_count']}/{native_summary_error_health['checksum_mismatch_count']}/{native_summary_error_health['corrupt_frame_count']}/{native_summary_error_health['truncated_frame_count']}/{native_summary_error_health['magic_phase_count']}/{native_summary_error_health['skippable_payload_phase_count']}/{native_summary_error_health['frame_body_phase_count']}/{native_summary_error_health['frame_checksum_phase_count']}/{native_summary_error_health['frame_phase_count']}, drift case/codec/error/phase/codec-error/codec-phase/offset {native_summary_error_health['case_count_mismatch']}/{native_summary_error_health['codec_case_count_mismatch']}/{native_summary_error_health['error_count_mismatch']}/{native_summary_error_health['phase_count_mismatch']}/{native_summary_error_health['codec_error_count_mismatch']}/{native_summary_error_health['codec_phase_count_mismatch']}/{native_summary_error_health['offset_range_mismatch']}, healthy `{native_summary_error_healthy}`",
        f"- native summary error negative smoke: cases {native_summary_error_negative['case_count']}, rows/matched/expected {native_summary_error_negative['rows']}/{native_summary_error_negative['matched']}/{native_summary_error_negative['expected_failures']}, mismatch {native_summary_error_negative['count_mismatch']}, healthy `{native_summary_error_negative_healthy}`",
        f"- lz4 native summary: frames/skippable/checksum/block-checksum/dictionary/content-size/blocks raw/compressed {lz4_native_summary['frame_count']}/{lz4_native_summary['skippable_frame_count']}/{lz4_native_summary['checksum_frame_count']}/{lz4_native_summary['block_checksum_frame_count']}/{lz4_native_summary['dictionary_id_frame_count']}/{lz4_native_summary['content_size_frame_count']}/{lz4_native_summary['block_count']} {lz4_native_summary['raw_block_count']}/{lz4_native_summary['compressed_block_count']}, declared/payload/skippable bytes {lz4_native_summary['declared_content_bytes']}/{lz4_native_summary['payload_bytes']}/{lz4_native_summary['skippable_payload_bytes']}, slack/mismatch {lz4_native_summary['declared_payload_slack_bytes']}/{lz4_native_summary['block_count_mismatch']}, healthy `{lz4_native_summary_healthy}`",
        f"- zstd native summary: frames/skippable/checksum/dictionary/content-size/blocks raw/rle/compressed {zstd_native_summary['frame_count']}/{zstd_native_summary['skippable_frame_count']}/{zstd_native_summary['checksum_frame_count']}/{zstd_native_summary['dictionary_id_frame_count']}/{zstd_native_summary['content_size_frame_count']}/{zstd_native_summary['block_count']} {zstd_native_summary['raw_block_count']}/{zstd_native_summary['rle_block_count']}/{zstd_native_summary['compressed_block_count']}, declared/payload/skippable bytes {zstd_native_summary['declared_content_bytes']}/{zstd_native_summary['payload_bytes']}/{zstd_native_summary['skippable_payload_bytes']}, slack/mismatch {zstd_native_summary['declared_payload_slack_bytes']}/{zstd_native_summary['block_count_mismatch']}, healthy `{zstd_native_summary_healthy}`",
        f"- Snappy report: {snappy_report['row_count']}/{snappy_report['expected_rows']} rows, positive/ratio/throughput {snappy_report['positive_timing_rows']}/{snappy_report['ratio_rows']}/{snappy_report['throughput_rows']}, repetitive shrunk {snappy_report['repetitive_shrunk_rows']}, framed overhead/reusable size/checksum matches {snappy_report['framed_overhead_matched_cases']}/{snappy_report['reusable_size_matched_cases']}/{snappy_report['reusable_checksum_matched_cases']}, missing/duplicate/unknown pairs {len(snappy_report['missing_pairs'])}/{len(snappy_report['duplicate_pairs'])}/{len(snappy_report['unknown_pairs'])}, healthy `{snappy_report_healthy}`",
        f"- checksum bench: {checksum_bench['row_count']}/{checksum_bench['expected_rows']} rows, workload {checksum_bench['workload_rows']}, positive/throughput {checksum_bench['positive_rows']}/{checksum_bench['throughput_rows']}, mix groups crc32/crc32c {checksum_bench['crc32_mix_groups']}/{checksum_bench['crc32c_mix_groups']}, missing/duplicate/unknown algorithms {len(checksum_bench['missing_algorithms'])}/{len(checksum_bench['duplicate_algorithms'])}/{len(checksum_bench['unknown_algorithms'])}, healthy `{checksum_bench_healthy}`",
        f"- chunk cursor bench: {chunk_cursor_bench['row_count']}/{chunk_cursor_bench['expected_rows']} rows, shape {chunk_cursor_bench['shape_rows']}, positive/throughput {chunk_cursor_bench['positive_rows']}/{chunk_cursor_bench['throughput_rows']}, checksum matches {chunk_cursor_bench['checksum_matched_cases']}, missing/duplicate/unknown pairs {len(chunk_cursor_bench['missing_pairs'])}/{len(chunk_cursor_bench['duplicate_pairs'])}/{len(chunk_cursor_bench['unknown_pairs'])}, healthy `{chunk_cursor_bench_healthy}`",
        f"- deflate match-copy bench: {deflate_match_copy_bench['row_count']}/{deflate_match_copy_bench['expected_rows']} rows, classes {deflate_match_copy_bench['expected_class_rows']}, positive/output/throughput {deflate_match_copy_bench['positive_rows']}/{deflate_match_copy_bench['output_bytes_rows']}/{deflate_match_copy_bench['throughput_rows']}, checksum matches {deflate_match_copy_bench['checksum_matched_cases']}, missing/duplicate/unknown pairs {len(deflate_match_copy_bench['missing_pairs'])}/{len(deflate_match_copy_bench['duplicate_pairs'])}/{len(deflate_match_copy_bench['unknown_pairs'])}, healthy `{deflate_match_copy_bench_healthy}`",
        f"- deflate Huffman build bench: {deflate_huffman_build_bench['row_count']}/{deflate_huffman_build_bench['expected_rows']} rows, lookup {deflate_huffman_build_bench['lookup_rows']}, positive/throughput {deflate_huffman_build_bench['positive_rows']}/{deflate_huffman_build_bench['throughput_rows']}, checksum variant cases {deflate_huffman_build_bench['checksum_variant_cases']}, missing/duplicate/unknown pairs {len(deflate_huffman_build_bench['missing_pairs'])}/{len(deflate_huffman_build_bench['duplicate_pairs'])}/{len(deflate_huffman_build_bench['unknown_pairs'])}, healthy `{deflate_huffman_build_bench_healthy}`",
        f"- deflate Huffman lookup bench: {deflate_huffman_lookup_bench['row_count']}/{deflate_huffman_lookup_bench['expected_rows']} rows, lookup {deflate_huffman_lookup_bench['lookup_rows']}, positive/throughput {deflate_huffman_lookup_bench['positive_rows']}/{deflate_huffman_lookup_bench['throughput_rows']}, checksum matches {deflate_huffman_lookup_bench['checksum_matched_cases']}, missing/duplicate/unknown pairs {len(deflate_huffman_lookup_bench['missing_pairs'])}/{len(deflate_huffman_lookup_bench['duplicate_pairs'])}/{len(deflate_huffman_lookup_bench['unknown_pairs'])}, healthy `{deflate_huffman_lookup_bench_healthy}`",
        f"- deflate chunked Huffman bench: {deflate_chunked_huffman_bench['row_count']}/{deflate_chunked_huffman_bench['expected_rows']} rows, shape/chunks {deflate_chunked_huffman_bench['shape_rows']}/{deflate_chunked_huffman_bench['chunk_count_rows']}, positive/throughput {deflate_chunked_huffman_bench['positive_rows']}/{deflate_chunked_huffman_bench['throughput_rows']}, checksum matches {deflate_chunked_huffman_bench['checksum_matched_cases']}, missing/duplicate/unknown pairs {len(deflate_chunked_huffman_bench['missing_pairs'])}/{len(deflate_chunked_huffman_bench['duplicate_pairs'])}/{len(deflate_chunked_huffman_bench['unknown_pairs'])}, healthy `{deflate_chunked_huffman_bench_healthy}`",
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
            f"| strict checks | {strict_health['check_count']} | rows {strict_health['check_rows']}, expected failures/matched {strict_health['expected_failure_count']}/{strict_health['matched_count']} |",
            f"| modes | {strict_health['mode_count']} | rows {strict_health['mode_count_rows']}, expected/missing {strict_health['expected_mode_count']}/{strict_health['missing_mode_count']} |",
            f"| requirement deltas | {strict_health['missing_checks'] + strict_health['missing_expected_failures'] + strict_health['missing_matched']} | checks/expected/matched {strict_health['missing_checks']}/{strict_health['missing_expected_failures']}/{strict_health['missing_matched']}, count mismatch {strict_health['report_count_mismatch']} |",
            f"| Markdown rows | {strict_health['markdown_matched']}/{strict_health['markdown_rows']} | present `{strict_health['markdown_present']}`, unmatched {strict_health['markdown_unmatched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Dashboard configuration coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| config index | {dashboard_configuration['config_index_config_count']} | rows {dashboard_configuration['config_index_config_rows']}, matched {dashboard_configuration['config_index_matched']}, mismatch {dashboard_configuration['config_index_count_mismatch']}, row-unmatched {dashboard_configuration['config_index_row_unmatched']} |",
            f"| config negative | {dashboard_configuration['config_index_negative_case_count']} | rows {dashboard_configuration['config_index_negative_rows']}, matched {dashboard_configuration['config_index_negative_matched']}, mismatch {dashboard_configuration['config_index_negative_count_mismatch']}, row-unmatched {dashboard_configuration['config_index_negative_row_unmatched']} |",
            f"| category guardrails | {dashboard_configuration['category_negative_case_count']} | rows {dashboard_configuration['category_negative_rows']}, matched {dashboard_configuration['category_negative_matched']}, mismatch {dashboard_configuration['category_negative_count_mismatch']}, row-unmatched {dashboard_configuration['category_negative_row_unmatched']} |",
            f"| required producers | {dashboard_configuration['producers_required_artifact_count']} | rows {dashboard_configuration['producers_required_rows']}, matched {dashboard_configuration['producers_required_matched']}, mismatch {dashboard_configuration['producers_required_count_mismatch']}, row-unmatched {dashboard_configuration['producers_required_row_unmatched']}, required smoke gates {dashboard_configuration['producers_required_smoke_gate_count']} |",
            f"| producer guardrails | {dashboard_configuration['producers_negative_case_count']} | rows {dashboard_configuration['producers_negative_rows']}, matched {dashboard_configuration['producers_negative_matched']}, mismatch {dashboard_configuration['producers_negative_count_mismatch']}, row-unmatched {dashboard_configuration['producers_negative_row_unmatched']}, healthy `{dashboard_configuration['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Validation JSON schema coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| checked schemas | {validation_json['checked_schema_count']} | unique {validation_json['checked_schema_unique_count']}, duplicates {validation_json['checked_schema_duplicate_count']}, smoke present `{validation_json['present']}`, ok `{validation_json['ok']}` |",
            f"| CLI validation | {1 if validation_json['cli_success_ok'] else 0} | failure-ok `{validation_json['cli_failure_ok']}`, hint `{validation_json['cli_failure_hint'] or 'none'}` |",
            f"| report rows | {validation_json['report_rows']} | corrupt rows {validation_json['corrupt_rows']} |",
            f"| docs negative cases | {validation_json['docs_negative_matched']}/{validation_json['docs_negative_case_count']} | rows {validation_json['docs_negative_rows']}, mismatch {validation_json['docs_negative_count_mismatch']}, row-unmatched {validation_json['docs_negative_row_unmatched']}, present `{validation_json['docs_negative_present']}`, healthy `{validation_json['healthy']}` |",
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
            f"| JSON row checks | {header_health['report_rows']}/{header_health['case_count']} | negatives {header_health['negative_item_rows']}/{header_health['negative_cases']}, count mismatch {header_health['report_count_mismatch']} |",
            f"| Markdown rows | {header_health['markdown_matched']}/{header_health['markdown_rows']} | present `{header_health['markdown_present']}`, unmatched {header_health['markdown_unmatched']} |",
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
            f"| report rows | {native_fuzz['report_rows']}/{native_fuzz['cases']} | matched {native_fuzz['matched_rows']}, count mismatch {native_fuzz['report_count_mismatch']}, unmatched {native_fuzz['unmatched_rows']} |",
            f"| exact error expectations | {native_fuzz['exact_error_expectations']} | mode/error rows {native_fuzz['mode_count_rows']}/{native_fuzz['error_count_rows']} |",
            f"| coverage requirements | {native_fuzz['coverage_mode_requirements'] + native_fuzz['coverage_error_requirements']} | matched modes/errors {native_fuzz['coverage_mode_matched']}/{native_fuzz['coverage_error_matched']}, unmatched {native_fuzz['coverage_unmatched']} |",
            f"| Markdown rows | {native_fuzz['markdown_matched']}/{native_fuzz['markdown_rows']} | present `{native_fuzz['markdown_present']}`, unmatched {native_fuzz['markdown_unmatched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Static dictionary coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| candidates | {br_static_dictionary['candidate_count']} | raw words {br_static_dictionary['raw_word_count']}, Markdown {br_static_dictionary['candidate_markdown_matched']}/{br_static_dictionary['candidate_markdown_summary_rows']} |",
            f"| candidate sample rows | {br_static_dictionary['candidate_markdown_sample_matched']}/{br_static_dictionary['candidate_markdown_sample_rows']} | unmatched {br_static_dictionary['candidate_markdown_sample_unmatched']}, present `{br_static_dictionary['candidate_markdown_present']}` |",
            f"| upstream smoke | {br_static_dictionary['upstream_candidate_count']} | raw words {br_static_dictionary['upstream_raw_word_count']}, present `{br_static_dictionary['upstream_present']}` |",
            f"| upstream report | {br_static_dictionary['upstream_report_candidate_count']} | raw words {br_static_dictionary['upstream_report_raw_word_count']}, upstream words {br_static_dictionary['upstream_report_upstream_raw_word_count']}, present `{br_static_dictionary['upstream_report_present']}` |",
            f"| upstream Markdown | {br_static_dictionary['upstream_markdown_matched']}/{br_static_dictionary['upstream_markdown_summary_rows']} | sample {br_static_dictionary['upstream_markdown_sample_matched']}/{br_static_dictionary['upstream_markdown_sample_rows']}, unmatched {br_static_dictionary['upstream_markdown_unmatched'] + br_static_dictionary['upstream_markdown_sample_unmatched']}, present `{br_static_dictionary['upstream_markdown_present']}` |",
            f"| node probe | {br_static_dictionary['node_decode_successes']}/{br_static_dictionary['node_probed_count']} | size winners {br_static_dictionary['node_size_winner_count']}, Markdown {br_static_dictionary['node_markdown_matched']}/{br_static_dictionary['node_markdown_summary_rows']} |",
            f"| node rows | {br_static_dictionary['node_markdown_matched_rows']}/{br_static_dictionary['node_markdown_rows']} | unmatched {br_static_dictionary['node_markdown_unmatched_rows']}, present `{br_static_dictionary['node_markdown_present']}` |",
            f"| source audit | {br_static_dictionary['audit_entry_count']} | anchors {br_static_dictionary['audit_anchor_count']}, generated bytes {br_static_dictionary['audit_generated_zig_bytes']} |",
            f"| negative smoke | {br_static_dictionary['negative_matched']}/{br_static_dictionary['negative_case_count']} | rows {br_static_dictionary['negative_rows']}, mismatch {br_static_dictionary['negative_count_mismatch']}, unmatched {br_static_dictionary['negative_unmatched']}, healthy `{br_static_dictionary['healthy']}` |",
            f"| report entries | {br_static_dictionary['report_entry_count']} | csv {br_static_dictionary['report_csv_matched']}/{br_static_dictionary['report_csv_rows']}, Markdown {br_static_dictionary['report_markdown_matched']}/{br_static_dictionary['report_markdown_summary_rows']} |",
            f"| report matrix rows | {br_static_dictionary['report_markdown_matrix_matched']}/{br_static_dictionary['report_markdown_matrix_rows']} | unmatched {br_static_dictionary['report_markdown_matrix_unmatched']}, present `{br_static_dictionary['report_markdown_present']}` |",
            f"| report entry rows | {br_static_dictionary['report_markdown_entry_matched']}/{br_static_dictionary['report_markdown_entry_rows']} | unmatched {br_static_dictionary['report_markdown_entry_unmatched']}, present `{br_static_dictionary['report_markdown_present']}` |",
            f"| report negative smoke | {br_static_dictionary['report_negative_matched']}/{br_static_dictionary['report_negative_case_count']} | rows {br_static_dictionary['report_negative_rows']}, mismatch {br_static_dictionary['report_negative_count_mismatch']}, unmatched {br_static_dictionary['report_negative_unmatched']}, report healthy `{br_static_dictionary['report_healthy']}` |",
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
            f"| report rows | {png_scratch['report_rows']}/{png_scratch['case_count']} | consistent {png_scratch['row_consistent_count']}, count mismatch {png_scratch['report_count_mismatch']}, inconsistent {png_scratch['row_inconsistent_count']} |",
            f"| streaming achieved | {png_scratch['stored_achieved']}/{png_scratch['case_count']} | fixed/dynamic {png_scratch['fixed_achieved']}/{png_scratch['case_count']} |",
            f"| zlib scratch savings | {png_scratch['total_streaming_savings']} | zlib scratch {png_scratch['total_zlib_scratch']} |",
            f"| max working scratch | {png_scratch['max_working_scratch']} | streaming/fixed-dynamic {png_scratch['max_streaming_working_scratch']}/{png_scratch['max_fixed_dynamic_streaming_working_scratch']} |",
            f"| min streaming ratio x10000 | {png_scratch['min_streaming_ratio']} | lower is better |",
            f"| Markdown rows | {png_scratch['markdown_matched']}/{png_scratch['markdown_rows']} | present `{png_scratch['markdown_present']}`, unmatched {png_scratch['markdown_unmatched']} |",
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
            f"| gate | {zlib_relaxed['gate_check_count']} | {zlib_relaxed['gate_passed_count']} | 0 | 0 | {len(zlib_relaxed['gate_failed_checks'])} | ok `{zlib_relaxed['gate_ok']}` |",
            f"| gate/report drift | {zlib_relaxed['gate_report_matched']} | {zlib_relaxed['gate_expected_checks']} | 0 | 0 | {zlib_relaxed['gate_report_unmatched']} | expected checks |",
            f"| gate recompute | {zlib_relaxed['gate_recomputed_passed_count']} | {zlib_relaxed['gate_expected_checks']} | {zlib_relaxed['gate_missing_checks']} | {zlib_relaxed['gate_extra_checks']} | {zlib_relaxed['gate_recomputed_failed_count']} | rule/exact/floor {zlib_relaxed['gate_check_rule_mismatch']}/{zlib_relaxed['gate_exact_mismatch_count']}/{zlib_relaxed['gate_floor_shortfall_count']} |",
            f"| Markdown rows | {zlib_relaxed['markdown_matched']} | {zlib_relaxed['markdown_rows']} | 0 | 0 | {zlib_relaxed['markdown_unmatched']} | present `{zlib_relaxed['markdown_present']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Snappy report coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {snappy_report['row_count']} | expected {snappy_report['expected_rows']}, present `{snappy_report['present']}` |",
            f"| positive timing rows | {snappy_report['positive_timing_rows']} | ratio/throughput {snappy_report['ratio_rows']}/{snappy_report['throughput_rows']} |",
            f"| repetitive shrunk | {snappy_report['repetitive_shrunk_rows']} | expected modes 4 |",
            f"| framed overhead matches | {snappy_report['framed_overhead_matched_cases']} | expected cases 5 |",
            f"| reusable size/checksum matches | {snappy_report['reusable_size_matched_cases']}/{snappy_report['reusable_checksum_matched_cases']} | missing/duplicate/unknown pairs {len(snappy_report['missing_pairs'])}/{len(snappy_report['duplicate_pairs'])}/{len(snappy_report['unknown_pairs'])}, healthy `{snappy_report['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Checksum benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {checksum_bench['row_count']} | expected {checksum_bench['expected_rows']}, present `{checksum_bench['present']}` |",
            f"| workload rows | {checksum_bench['workload_rows']} | positive/throughput rows {checksum_bench['positive_rows']}/{checksum_bench['throughput_rows']} |",
            f"| digest mix groups | {checksum_bench['crc32_mix_groups'] + checksum_bench['crc32c_mix_groups']} | crc32/crc32c {checksum_bench['crc32_mix_groups']}/{checksum_bench['crc32c_mix_groups']}, missing/duplicate/unknown algorithms {len(checksum_bench['missing_algorithms'])}/{len(checksum_bench['duplicate_algorithms'])}/{len(checksum_bench['unknown_algorithms'])}, healthy `{checksum_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Chunk cursor benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {chunk_cursor_bench['row_count']} | expected {chunk_cursor_bench['expected_rows']}, present `{chunk_cursor_bench['present']}` |",
            f"| shape rows | {chunk_cursor_bench['shape_rows']} | positive/throughput rows {chunk_cursor_bench['positive_rows']}/{chunk_cursor_bench['throughput_rows']} |",
            f"| checksum matches | {chunk_cursor_bench['checksum_matched_cases']} | expected cases 4 |",
            f"| pair drift | {len(chunk_cursor_bench['missing_pairs'])} | duplicate/unknown {len(chunk_cursor_bench['duplicate_pairs'])}/{len(chunk_cursor_bench['unknown_pairs'])}, healthy `{chunk_cursor_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate match-copy benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_match_copy_bench['row_count']} | expected {deflate_match_copy_bench['expected_rows']}, present `{deflate_match_copy_bench['present']}` |",
            f"| class rows | {deflate_match_copy_bench['expected_class_rows']} | positive/output/throughput rows {deflate_match_copy_bench['positive_rows']}/{deflate_match_copy_bench['output_bytes_rows']}/{deflate_match_copy_bench['throughput_rows']} |",
            f"| checksum matches | {deflate_match_copy_bench['checksum_matched_cases']} | expected cases 7 |",
            f"| pair drift | {len(deflate_match_copy_bench['missing_pairs'])} | duplicate/unknown {len(deflate_match_copy_bench['duplicate_pairs'])}/{len(deflate_match_copy_bench['unknown_pairs'])}, healthy `{deflate_match_copy_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate Huffman build benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_huffman_build_bench['row_count']} | expected {deflate_huffman_build_bench['expected_rows']}, present `{deflate_huffman_build_bench['present']}` |",
            f"| lookup rows | {deflate_huffman_build_bench['lookup_rows']} | positive/throughput rows {deflate_huffman_build_bench['positive_rows']}/{deflate_huffman_build_bench['throughput_rows']} |",
            f"| checksum variant cases | {deflate_huffman_build_bench['checksum_variant_cases']} | expected cases 4 |",
            f"| pair drift | {len(deflate_huffman_build_bench['missing_pairs'])} | duplicate/unknown {len(deflate_huffman_build_bench['duplicate_pairs'])}/{len(deflate_huffman_build_bench['unknown_pairs'])}, healthy `{deflate_huffman_build_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate Huffman lookup benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_huffman_lookup_bench['row_count']} | expected {deflate_huffman_lookup_bench['expected_rows']}, present `{deflate_huffman_lookup_bench['present']}` |",
            f"| lookup rows | {deflate_huffman_lookup_bench['lookup_rows']} | positive/throughput rows {deflate_huffman_lookup_bench['positive_rows']}/{deflate_huffman_lookup_bench['throughput_rows']} |",
            f"| checksum matches | {deflate_huffman_lookup_bench['checksum_matched_cases']} | expected cases 6 |",
            f"| pair drift | {len(deflate_huffman_lookup_bench['missing_pairs'])} | duplicate/unknown {len(deflate_huffman_lookup_bench['duplicate_pairs'])}/{len(deflate_huffman_lookup_bench['unknown_pairs'])}, healthy `{deflate_huffman_lookup_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate chunked Huffman benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_chunked_huffman_bench['row_count']} | expected {deflate_chunked_huffman_bench['expected_rows']}, present `{deflate_chunked_huffman_bench['present']}` |",
            f"| shape rows | {deflate_chunked_huffman_bench['shape_rows']} | positive/throughput rows {deflate_chunked_huffman_bench['positive_rows']}/{deflate_chunked_huffman_bench['throughput_rows']} |",
            f"| chunk counts | {deflate_chunked_huffman_bench['chunk_count_rows']} | buffered rows {deflate_chunked_huffman_bench['buffered_zero_chunk_rows']} |",
            f"| checksum matches | {deflate_chunked_huffman_bench['checksum_matched_cases']} | expected cases 3 |",
            f"| pair drift | {len(deflate_chunked_huffman_bench['missing_pairs'])} | duplicate/unknown {len(deflate_chunked_huffman_bench['duplicate_pairs'])}/{len(deflate_chunked_huffman_bench['unknown_pairs'])}, healthy `{deflate_chunked_huffman_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate extra-bit benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_extra_bits_bench['row_count']} | expected {deflate_extra_bits_bench['expected_rows']}, present `{deflate_extra_bits_bench['present']}` |",
            f"| shape rows | {deflate_extra_bits_bench['shape_rows']} | positive/throughput rows {deflate_extra_bits_bench['positive_rows']}/{deflate_extra_bits_bench['throughput_rows']} |",
            f"| checksum matches | {deflate_extra_bits_bench['checksum_matched_cases']} | paired checksums {deflate_extra_bits_bench['paired_checksum_rows']}/{deflate_extra_bits_bench['expected_paired_checksum_rows']} |",
            f"| pair drift | {len(deflate_extra_bits_bench['missing_pairs'])} | duplicate/unknown {len(deflate_extra_bits_bench['duplicate_pairs'])}/{len(deflate_extra_bits_bench['unknown_pairs'])}, healthy `{deflate_extra_bits_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Dictionary decode benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {dictionary_decode_bench['row_count']} | expected {dictionary_decode_bench['expected_rows']}, present `{dictionary_decode_bench['present']}` |",
            f"| shape rows | {dictionary_decode_bench['shape_rows']} | positive/throughput rows {dictionary_decode_bench['positive_rows']}/{dictionary_decode_bench['throughput_rows']} |",
            f"| output-size rows | {dictionary_decode_bench['output_size_rows']} | checksum payloads {dictionary_decode_bench['checksum_matched_payloads']} |",
            f"| pair drift | {len(dictionary_decode_bench['missing_pairs'])} | duplicate/unknown {len(dictionary_decode_bench['duplicate_pairs'])}/{len(dictionary_decode_bench['unknown_pairs'])}, healthy `{dictionary_decode_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## PNG scanline benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {png_scanline_bench['row_count']} | expected {png_scanline_bench['expected_rows']}, present `{png_scanline_bench['present']}` |",
            f"| shape rows | {png_scanline_bench['shape_rows']} | positive/throughput rows {png_scanline_bench['positive_rows']}/{png_scanline_bench['throughput_rows']} |",
            f"| input/output rows | {png_scanline_bench['io_match_rows']} | checksum bpp groups {png_scanline_bench['checksum_matched_bpps']} |",
            f"| pair drift | {len(png_scanline_bench['missing_pairs'])} | duplicate/unknown {len(png_scanline_bench['duplicate_pairs'])}/{len(png_scanline_bench['unknown_pairs'])}, healthy `{png_scanline_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Chunked zlib benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {chunked_zlib_bench['row_count']} | expected {chunked_zlib_bench['expected_rows']}, present `{chunked_zlib_bench['present']}` |",
            f"| shape rows | {chunked_zlib_bench['shape_rows']} | positive rows {chunked_zlib_bench['positive_rows']} |",
            f"| ratio rows | {chunked_zlib_bench['ratio_rows']} | chunk-count rows {chunked_zlib_bench['chunk_count_rows']}, missing/duplicate/unknown cases {len(chunked_zlib_bench['missing_cases'])}/{len(chunked_zlib_bench['duplicate_cases'])}/{len(chunked_zlib_bench['unknown_cases'])}, healthy `{chunked_zlib_bench['healthy']}` |",
            f"| Markdown rows | {chunked_zlib_bench['markdown_matched']}/{chunked_zlib_bench['markdown_rows']} | present `{chunked_zlib_bench['markdown_present']}`, unmatched {chunked_zlib_bench['markdown_unmatched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## PNG streaming zlib benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {png_streaming_zlib_bench['row_count']} | expected {png_streaming_zlib_bench['expected_rows']}, present `{png_streaming_zlib_bench['present']}` |",
            f"| shape rows | {png_streaming_zlib_bench['shape_rows']} | positive rows {png_streaming_zlib_bench['positive_rows']} |",
            f"| ratio rows | {png_streaming_zlib_bench['ratio_rows']} | image-size rows {png_streaming_zlib_bench['image_size_rows']} |",
            f"| chunk counts | {png_streaming_zlib_bench['chunk_count_rows']} | missing/duplicate/unknown cases {len(png_streaming_zlib_bench['missing_cases'])}/{len(png_streaming_zlib_bench['duplicate_cases'])}/{len(png_streaming_zlib_bench['unknown_cases'])}, healthy `{png_streaming_zlib_bench['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Deflate dynamic decode profile coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {deflate_dynamic_decode_profile['row_count']} | required {deflate_dynamic_decode_profile['required_rows']}, present `{deflate_dynamic_decode_profile['present']}` |",
            f"| required row checks | {deflate_dynamic_decode_profile['positive_rows']} | histograms/lookups {deflate_dynamic_decode_profile['histogram_rows']}/{deflate_dynamic_decode_profile['lookup_rows']} |",
            f"| match class rows | {deflate_dynamic_decode_profile['match_class_rows']} | ratio rows {deflate_dynamic_decode_profile['ratio_rows']} |",
            f"| chunked-window rows | {deflate_dynamic_decode_profile['chunked_window_rows']} | missing required/duplicate cases {len(deflate_dynamic_decode_profile['missing_cases'])}/{len(deflate_dynamic_decode_profile['duplicate_cases'])}, healthy `{deflate_dynamic_decode_profile['healthy']}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native library benchmark coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {native_library_bench['row_count']} | expected {native_library_bench['expected_rows']}, present `{native_library_bench['present']}` |",
            f"| positive rows | {native_library_bench['positive_rows']} | throughput/iteration {native_library_bench['throughput_rows']}/{native_library_bench['iteration_rows']} |",
            f"| improvement checks | {native_library_bench['improvement_checks']}/{native_library_bench['expected_improvement_checks']} | pair drift {len(native_library_bench['missing_pairs'])}, duplicate/unknown {len(native_library_bench['duplicate_pairs'])}/{len(native_library_bench['unknown_pairs'])}, healthy `{native_library_bench['healthy']}` |",
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
            f"| CSV drift checks | {zstd_compare['csv_matched_rows']}/{zstd_compare['csv_rows']} | artifacts {zstd_compare['csv_present_count']}/{zstd_compare['csv_expected_present_count']}, unmatched {zstd_compare['csv_unmatched_rows']} |",
            f"| Markdown drift checks | {zstd_compare['markdown_matched']}/{zstd_compare['markdown_summary_rows']} | artifacts {zstd_compare['markdown_present_count']}/{zstd_compare['markdown_expected_present_count']}, unmatched {zstd_compare['markdown_unmatched']} |",
            f"| Markdown detail rows | {zstd_compare['markdown_detail_matched']}/{zstd_compare['markdown_detail_rows']} | unmatched {zstd_compare['markdown_detail_unmatched']} |",
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
            f"| report rows | {native_allocation['report_rows']}/{native_allocation['report_case_count']} | balanced {native_allocation['report_balanced_rows']}, count mismatch {native_allocation['report_count_mismatch']}, duplicate {native_allocation['report_duplicate_cases']}, unbalanced {native_allocation['report_unbalanced_rows']} |",
            f"| zero-allocation cases | {native_allocation['zero_allocation_matched']}/{native_allocation['required_zero_allocation_cases']} | smoke present `{native_allocation['smoke_present']}` |",
            f"| zero/report drift | {native_allocation['zero_report_matched']}/{native_allocation['required_zero_allocation_cases']} | unmatched {native_allocation['zero_report_unmatched']} |",
            f"| budget cases | {native_allocation['budget_matched']}/{native_allocation['required_budget_cases']} | healthy `{native_allocation['healthy']}` |",
            f"| budget/report drift | {native_allocation['budget_report_matched']}/{native_allocation['required_budget_cases']} | unmatched {native_allocation['budget_report_unmatched']} |",
            f"| smoke classification | {native_allocation['smoke_classified_cases']}/{native_allocation['report_rows']} | overlap {native_allocation['smoke_classification_overlap']}, missing {native_allocation['smoke_classification_missing']}, extra {native_allocation['smoke_classification_extra']} |",
            f"| negative smoke cases | {native_allocation['negative_matched']}/{native_allocation['negative_case_count']} | present `{native_allocation['negative_present']}`, unmatched {native_allocation['negative_unmatched']} |",
            f"| Markdown rows | {native_allocation['markdown_matched']}/{native_allocation['markdown_rows']} | present `{native_allocation['markdown_present']}`, unmatched {native_allocation['markdown_unmatched']} |",
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
            f"| JSON item rows | {sidecar_corrupt_health_summary['item_rows']} | count mismatch {sidecar_corrupt_health_summary['item_count_mismatch']} |",
            f"| Markdown rows | {sidecar_corrupt_health_summary['markdown_matched']}/{sidecar_corrupt_health_summary['markdown_rows']} | present `{sidecar_corrupt_health_summary['markdown_present']}`, unmatched {sidecar_corrupt_health_summary['markdown_unmatched']} |",
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
            f"| Markdown summary | {huffman_health['markdown_matched']}/{huffman_health['markdown_summary_rows']} | present `{huffman_health['markdown_present']}` |",
            f"| Markdown case rows | {huffman_health['markdown_case_matched']}/{huffman_health['markdown_case_rows']} | unmatched {huffman_health['markdown_case_unmatched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Compression level report coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {level_report['rows']} | expected {level_report['expected_rows']}, present `{level_report['present']}` |",
            f"| row checks | {level_report['shape_rows']} | positive/token/ratio/roundtrip {level_report['positive_rows']}/{level_report['token_accounting_rows']}/{level_report['ratio_rows']}/{level_report['roundtrip_rows']} |",
            f"| pair drift | {len(level_report['missing_pairs'])} | duplicate/unknown {len(level_report['duplicate_pairs'])}/{len(level_report['unknown_pairs'])} |",
            f"| Markdown summary | {level_report['markdown_matched']}/{level_report['markdown_summary_rows']} | present `{level_report['markdown_present']}`, healthy `{level_report_healthy}` |",
            f"| Markdown detail rows | {level_report['markdown_detail_matched']}/{level_report['markdown_detail_rows']} | unmatched {level_report['markdown_detail_unmatched']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Dynamic plan report coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| rows | {dynamic_plan['rows']} | expected {dynamic_plan['expected_rows']}, sources {dynamic_plan['source_count']}/{dynamic_plan['expected_source_count']} |",
            f"| row checks | {dynamic_plan['positive_rows']} | token/histogram/ratio {dynamic_plan['token_accounting_rows']}/{dynamic_plan['histogram_rows']}/{dynamic_plan['ratio_rows']} |",
            f"| bit/zlib checks | {dynamic_plan['slack_rows']}/{dynamic_plan['wrapper_rows']} | malformed {dynamic_plan['malformed_rows']}, missing paths {len(dynamic_plan['missing_paths'])}, healthy `{dynamic_plan_healthy}` |",
            "",
        ]
    )
    lines.extend(
        [
            "## Python zlib differential coverage",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| payloads | {python_zlib_health['payloads']} | inline/large-file/match-heavy/dynamic {python_zlib_health['inline_payloads']}/{python_zlib_health['large_file_payloads']}/{python_zlib_health['match_heavy_payloads']}/{python_zlib_health['dynamic_payloads']}, large overflow {python_zlib_health['large_file_payload_overflow']} |",
            f"| file hex encodes | {python_zlib_health['file_hex_encode_cases']} | expected {python_zlib_health['file_hex_expected_cases']}, mismatch {python_zlib_health['file_hex_case_mismatch']} |",
            f"| dictionary encodes | {python_zlib_health['dictionary_encode_cases']} | zlib/raw {python_zlib_health['zlib_dict_encode_cases']}/{python_zlib_health['raw_dict_encode_cases']}, dictionary cases {python_zlib_health['dictionary_cases']} |",
            f"| malformed cases | {python_zlib_health['malformed_cases']} | wrapper/deflate {python_zlib_health['malformed_wrapper_cases']}/{python_zlib_health['malformed_deflate_cases']}, expected floor {python_zlib_health['expected_failure_floor']} |",
            f"| CLI outcomes | {python_zlib_health['cli_total_outcomes']} | successes/expected-failures {python_zlib_health['cli_successes']}/{python_zlib_health['expected_failures']}, shortfalls {python_zlib_health['cli_success_shortfall']}/{python_zlib_health['expected_failure_shortfall']}/{python_zlib_health['cli_outcome_shortfall']}, exact expected {python_zlib_health['cli_success_expected']}/{python_zlib_health['expected_failure_expected']}/{python_zlib_health['cli_total_expected']}, exact mismatch {python_zlib_health['cli_success_exact_mismatch']}/{python_zlib_health['expected_failure_exact_mismatch']}/{python_zlib_health['cli_outcome_exact_mismatch']} |",
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
            f"| report rows | {decode_stage_health_summary['report_rows']}/{decode_stage_health_summary['rows']} | error items {decode_stage_health_summary['error_item_rows']}/{decode_stage_health_summary['error_rows']}, count mismatch {decode_stage_health_summary['report_count_mismatch']} |",
            f"| csv rows | {decode_stage_health_summary['csv_rows']} | positive/header {decode_stage_health_summary['csv_positive_rows']}/{decode_stage_health_summary['csv_header_rows']} |",
            f"| csv block types | {decode_stage_health_summary['csv_dynamic_rows']} | fixed/stored {decode_stage_health_summary['csv_fixed_rows']}/{decode_stage_health_summary['csv_stored_rows']}, missing/duplicate/unknown cases {len(decode_stage_health_summary['csv_missing_cases'])}/{len(decode_stage_health_summary['csv_duplicate_cases'])}/{len(decode_stage_health_summary['csv_unknown_cases'])} |",
            f"| Markdown rows | {decode_stage_health_summary['markdown_matched']}/{decode_stage_health_summary['markdown_rows']} | present `{decode_stage_health_summary['markdown_present']}`, unmatched {decode_stage_health_summary['markdown_unmatched']} |",
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
            f"| report rows | {fuzz_health['report_rows']}/{fuzz_health['cases']} | accepted/rejected {fuzz_health['accepted']}/{fuzz_health['rejected']}, count mismatch {fuzz_health['report_count_mismatch']} |",
            f"| exact error expectations | {fuzz_health['exact_error_expectations']} | mode/error rows {fuzz_health['mode_count_rows']}/{fuzz_health['error_count_rows']} |",
            f"| coverage requirements | {fuzz_health['coverage_mode_requirements'] + fuzz_health['coverage_error_requirements']} | matched modes/errors {fuzz_health['coverage_mode_matched']}/{fuzz_health['coverage_error_matched']}, unmatched {fuzz_health['coverage_unmatched']} |",
            f"| Markdown rows | {fuzz_health['markdown_matched']}/{fuzz_health['markdown_rows']} | present `{fuzz_health['markdown_present']}`, unmatched {fuzz_health['markdown_unmatched']} |",
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
            "| codec | frames | skippable | checksum | block checksum | dictionary | content size | blocks raw/rle/compressed | payload/skippable bytes | declared slack | mismatches | overflow |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: |",
            f"| `lz4` | {lz4_native_summary['frame_count']} | {lz4_native_summary['skippable_frame_count']} | {lz4_native_summary['checksum_frame_count']} | {lz4_native_summary['block_checksum_frame_count']} | {lz4_native_summary['dictionary_id_frame_count']} | {lz4_native_summary['content_size_frame_count']} | {lz4_native_summary['raw_block_count']}/{lz4_native_summary['rle_block_count']}/{lz4_native_summary['compressed_block_count']} | {lz4_native_summary['payload_bytes']}/{lz4_native_summary['skippable_payload_bytes']} | {lz4_native_summary['declared_payload_slack_bytes']} | {lz4_native_summary['block_count_mismatch']} | {lz4_native_summary['metadata_frame_overflow'] + lz4_native_summary['checksum_frame_overflow'] + lz4_native_summary['block_checksum_frame_overflow']} |",
            f"| `zstd` | {zstd_native_summary['frame_count']} | {zstd_native_summary['skippable_frame_count']} | {zstd_native_summary['checksum_frame_count']} | 0 | {zstd_native_summary['dictionary_id_frame_count']} | {zstd_native_summary['content_size_frame_count']} | {zstd_native_summary['raw_block_count']}/{zstd_native_summary['rle_block_count']}/{zstd_native_summary['compressed_block_count']} | {zstd_native_summary['payload_bytes']}/{zstd_native_summary['skippable_payload_bytes']} | {zstd_native_summary['declared_payload_slack_bytes']} | {zstd_native_summary['block_count_mismatch']} | {zstd_native_summary['metadata_frame_overflow'] + zstd_native_summary['checksum_frame_overflow'] + zstd_native_summary['block_checksum_frame_overflow']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native codec probe Markdown drift",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| Markdown checks | {native_codec_health['markdown_matched']}/{native_codec_health['markdown_rows']} | present `{native_codec_health['markdown_present']}`, unmatched {native_codec_health['markdown_unmatched']} |",
            f"| coverage rows | {native_codec_health['coverage_ok_rows']}/{native_codec_health['coverage_rows']} | case sum {native_codec_health['coverage_case_sum']}/{native_codec_health['total_cases']} |",
            "",
        ]
    )
    lines.extend(
        [
            "## Native summary error aggregate drift",
            "",
            "| category | count | detail |",
            "| --- | ---: | --- |",
            f"| case rows | {native_summary_error_health['case_rows']} | declared {native_summary_error_health['case_count']}, mismatch {native_summary_error_health['case_count_mismatch']} |",
            f"| codec case drift | {native_summary_error_health['codec_case_count_mismatch']} | lz4/zstd {native_summary_error_health['lz4_case_count']}/{native_summary_error_health['zstd_case_count']} |",
            f"| count drift | {native_summary_error_health['error_count_mismatch'] + native_summary_error_health['phase_count_mismatch']} | errors {native_summary_error_health['error_count_mismatch']}, phases {native_summary_error_health['phase_count_mismatch']} |",
            f"| codec count drift | {native_summary_error_health['codec_error_count_mismatch'] + native_summary_error_health['codec_phase_count_mismatch']} | errors {native_summary_error_health['codec_error_count_mismatch']}, phases {native_summary_error_health['codec_phase_count_mismatch']} |",
            f"| offset drift | {native_summary_error_health['offset_range_mismatch']} | healthy `{native_summary_error_health['healthy']}` |",
            "",
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
            f"| discovery mismatches | {native_tier_discovery_health['mismatch_total']} | selected/csv path/summary fixtures/csv fixtures/csv bytes {native_tier_discovery_health['selected_case_mismatch']}/{native_tier_discovery_health['csv_path_mismatch']}/{native_tier_discovery_health['summary_fixture_mismatch']}/{native_tier_discovery_health['csv_fixture_mismatch']}/{native_tier_discovery_health['csv_byte_mismatch']} |",
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
        lines.extend(
            [
                "## Native tier range CSV coverage",
                "",
                "| category | count | detail |",
                "| --- | ---: | --- |",
                f"| csv artifacts | {native_tier_health['csv_present_count']} | healthy {native_tier_health['csv_healthy_count']}, missing sources {len(native_tier_health['csv_missing_sources'])} |",
                f"| csv rows | {native_tier_health['csv_rows']} | positive/shape {native_tier_health['csv_positive_rows']}/{native_tier_health['csv_shape_rows']} |",
                f"| throughput rows | {native_tier_health['csv_throughput_rows']} | pair drift {len(native_tier_health['csv_missing_pairs'])}, duplicate/unknown {len(native_tier_health['csv_duplicate_pairs'])}/{len(native_tier_health['csv_unknown_pairs'])} |",
                f"| summary/CSV mismatches | {native_tier_health['summary_csv_mismatch_total']} | source count {native_tier_health['source_count_mismatch']}, rows/fixtures/tiers/path {native_tier_health['summary_csv_row_mismatch']}/{native_tier_health['summary_csv_fixture_mismatch']}/{native_tier_health['summary_csv_tier_mismatch']}/{native_tier_health['summary_csv_path_mismatch']}, stream/index/min range/min full {native_tier_health['summary_csv_stream_bytes_mismatch']}/{native_tier_health['summary_csv_index_entries_mismatch']}/{native_tier_health['summary_csv_min_range_mismatch']}/{native_tier_health['summary_csv_min_full_mismatch']} |",
                "",
            ]
        )
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
                "header_inspect_markdown_present": header_health["markdown_present"],
                "header_inspect_report_rows": header_health["report_rows"],
                "header_inspect_negative_item_rows": header_health["negative_item_rows"],
                "header_inspect_command_coverage_rows": header_health["command_coverage_rows"],
                "header_inspect_workflow_coverage_rows": header_health["workflow_coverage_rows"],
                "header_inspect_required_workflow_rows": header_health["required_workflow_rows"],
                "header_inspect_help_workflow_rows": header_health["help_workflow_rows"],
                "header_inspect_report_count_mismatch": header_health["report_count_mismatch"],
                "header_inspect_markdown_rows": header_health["markdown_rows"],
                "header_inspect_markdown_matched": header_health["markdown_matched"],
                "header_inspect_markdown_unmatched": header_health["markdown_unmatched"],
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
                "dashboard_strict_check_rows": strict_health["check_rows"],
                "dashboard_strict_mode_count": strict_health["mode_count"],
                "dashboard_strict_mode_count_rows": strict_health["mode_count_rows"],
                "dashboard_strict_expected_failure_count": strict_health["expected_failure_count"],
                "dashboard_strict_matched_count": strict_health["matched_count"],
                "dashboard_strict_expected_mode_count": strict_health["expected_mode_count"],
                "dashboard_strict_expected_mode_rows": strict_health["expected_mode_rows"],
                "dashboard_strict_mode_requirement_rows": strict_health["mode_requirement_rows"],
                "dashboard_strict_validation_reason_rows": strict_health["validation_reason_rows"],
                "dashboard_strict_report_count_mismatch": strict_health["report_count_mismatch"],
                "dashboard_strict_missing_mode_count": strict_health["missing_mode_count"],
                "dashboard_strict_missing_checks": strict_health["missing_checks"],
                "dashboard_strict_missing_expected_failures": strict_health["missing_expected_failures"],
                "dashboard_strict_missing_matched": strict_health["missing_matched"],
                "dashboard_strict_missing_modes": strict_health["missing_modes"],
                "dashboard_strict_markdown_present": strict_health["markdown_present"],
                "dashboard_strict_markdown_rows": strict_health["markdown_rows"],
                "dashboard_strict_markdown_matched": strict_health["markdown_matched"],
                "dashboard_strict_markdown_unmatched": strict_health["markdown_unmatched"],
                "dashboard_configuration_healthy": dashboard_configuration["healthy"],
                "dashboard_config_index_present": dashboard_configuration["config_index_present"],
                "dashboard_config_index_ok": dashboard_configuration["config_index_ok"],
                "dashboard_config_index_config_count": dashboard_configuration["config_index_config_count"],
                "dashboard_config_index_config_rows": dashboard_configuration["config_index_config_rows"],
                "dashboard_config_index_matched": dashboard_configuration["config_index_matched"],
                "dashboard_config_index_unmatched": dashboard_configuration["config_index_unmatched"],
                "dashboard_config_index_count_mismatch": dashboard_configuration["config_index_count_mismatch"],
                "dashboard_config_index_row_unmatched": dashboard_configuration["config_index_row_unmatched"],
                "dashboard_config_index_negative_present": dashboard_configuration["config_index_negative_present"],
                "dashboard_config_index_negative_ok": dashboard_configuration["config_index_negative_ok"],
                "dashboard_config_index_negative_case_count": dashboard_configuration["config_index_negative_case_count"],
                "dashboard_config_index_negative_rows": dashboard_configuration["config_index_negative_rows"],
                "dashboard_config_index_negative_matched": dashboard_configuration["config_index_negative_matched"],
                "dashboard_config_index_negative_unmatched": dashboard_configuration["config_index_negative_unmatched"],
                "dashboard_config_index_negative_count_mismatch": dashboard_configuration["config_index_negative_count_mismatch"],
                "dashboard_config_index_negative_row_unmatched": dashboard_configuration["config_index_negative_row_unmatched"],
                "dashboard_category_negative_present": dashboard_configuration["category_negative_present"],
                "dashboard_category_negative_ok": dashboard_configuration["category_negative_ok"],
                "dashboard_category_negative_case_count": dashboard_configuration["category_negative_case_count"],
                "dashboard_category_negative_rows": dashboard_configuration["category_negative_rows"],
                "dashboard_category_negative_matched": dashboard_configuration["category_negative_matched"],
                "dashboard_category_negative_unmatched": dashboard_configuration["category_negative_unmatched"],
                "dashboard_category_negative_count_mismatch": dashboard_configuration["category_negative_count_mismatch"],
                "dashboard_category_negative_row_unmatched": dashboard_configuration["category_negative_row_unmatched"],
                "dashboard_producers_required_present": dashboard_configuration["producers_required_present"],
                "dashboard_producers_required_ok": dashboard_configuration["producers_required_ok"],
                "dashboard_producers_required_artifact_count": dashboard_configuration["producers_required_artifact_count"],
                "dashboard_producers_required_rows": dashboard_configuration["producers_required_rows"],
                "dashboard_producers_required_matched": dashboard_configuration["producers_required_matched"],
                "dashboard_producers_required_unmatched": dashboard_configuration["producers_required_unmatched"],
                "dashboard_producers_required_count_mismatch": dashboard_configuration["producers_required_count_mismatch"],
                "dashboard_producers_required_row_unmatched": dashboard_configuration["producers_required_row_unmatched"],
                "dashboard_producers_required_smoke_gate_count": dashboard_configuration["producers_required_smoke_gate_count"],
                "dashboard_producers_negative_present": dashboard_configuration["producers_negative_present"],
                "dashboard_producers_negative_ok": dashboard_configuration["producers_negative_ok"],
                "dashboard_producers_negative_case_count": dashboard_configuration["producers_negative_case_count"],
                "dashboard_producers_negative_rows": dashboard_configuration["producers_negative_rows"],
                "dashboard_producers_negative_matched": dashboard_configuration["producers_negative_matched"],
                "dashboard_producers_negative_unmatched": dashboard_configuration["producers_negative_unmatched"],
                "dashboard_producers_negative_count_mismatch": dashboard_configuration["producers_negative_count_mismatch"],
                "dashboard_producers_negative_row_unmatched": dashboard_configuration["producers_negative_row_unmatched"],
                "validation_json_present": validation_json["present"],
                "validation_json_ok": validation_json["ok"],
                "validation_json_healthy": validation_json["healthy"],
                "validation_json_checked_schema_count": validation_json["checked_schema_count"],
                "validation_json_checked_schema_unique_count": validation_json["checked_schema_unique_count"],
                "validation_json_checked_schema_duplicate_count": validation_json["checked_schema_duplicate_count"],
                "validation_json_cli_success_ok": validation_json["cli_success_ok"],
                "validation_json_cli_failure_ok": validation_json["cli_failure_ok"],
                "validation_json_cli_failure_hint": validation_json["cli_failure_hint"],
                "validation_json_report_rows": validation_json["report_rows"],
                "validation_json_corrupt_rows": validation_json["corrupt_rows"],
                "validation_json_docs_negative_present": validation_json["docs_negative_present"],
                "validation_json_docs_negative_ok": validation_json["docs_negative_ok"],
                "validation_json_docs_negative_case_count": validation_json["docs_negative_case_count"],
                "validation_json_docs_negative_rows": validation_json["docs_negative_rows"],
                "validation_json_docs_negative_matched": validation_json["docs_negative_matched"],
                "validation_json_docs_negative_unmatched": validation_json["docs_negative_unmatched"],
                "validation_json_docs_negative_count_mismatch": validation_json["docs_negative_count_mismatch"],
                "validation_json_docs_negative_row_unmatched": validation_json["docs_negative_row_unmatched"],
                "sidecar_corrupt_present": sidecar_corrupt_health_summary["present"],
                "sidecar_corrupt_healthy": sidecar_corrupt_healthy,
                "sidecar_corrupt_rows": sidecar_corrupt_health_summary["rows"],
                "sidecar_corrupt_metadata_ok_rows": sidecar_corrupt_health_summary["metadata_ok_rows"],
                "sidecar_corrupt_full_rejected_rows": sidecar_corrupt_health_summary["full_rejected_rows"],
                "sidecar_corrupt_metadata_failed_rows": sidecar_corrupt_health_summary["metadata_failed_rows"],
                "sidecar_corrupt_full_not_rejected_rows": sidecar_corrupt_health_summary["full_not_rejected_rows"],
                "sidecar_corrupt_item_rows": sidecar_corrupt_health_summary["item_rows"],
                "sidecar_corrupt_item_count_mismatch": sidecar_corrupt_health_summary["item_count_mismatch"],
                "sidecar_corrupt_markdown_present": sidecar_corrupt_health_summary["markdown_present"],
                "sidecar_corrupt_markdown_rows": sidecar_corrupt_health_summary["markdown_rows"],
                "sidecar_corrupt_markdown_matched": sidecar_corrupt_health_summary["markdown_matched"],
                "sidecar_corrupt_markdown_unmatched": sidecar_corrupt_health_summary["markdown_unmatched"],
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
                "huffman_length_markdown_present": huffman_health["markdown_present"],
                "huffman_length_markdown_summary_rows": huffman_health["markdown_summary_rows"],
                "huffman_length_markdown_matched": huffman_health["markdown_matched"],
                "huffman_length_markdown_unmatched": huffman_health["markdown_unmatched"],
                "huffman_length_markdown_case_rows": huffman_health["markdown_case_rows"],
                "huffman_length_markdown_case_matched": huffman_health["markdown_case_matched"],
                "huffman_length_markdown_case_unmatched": huffman_health["markdown_case_unmatched"],
                "level_report_present": level_report["present"],
                "level_report_healthy": level_report_healthy,
                "level_report_rows": level_report["rows"],
                "level_report_expected_rows": level_report["expected_rows"],
                "level_report_positive_rows": level_report["positive_rows"],
                "level_report_shape_rows": level_report["shape_rows"],
                "level_report_token_accounting_rows": level_report["token_accounting_rows"],
                "level_report_ratio_rows": level_report["ratio_rows"],
                "level_report_roundtrip_rows": level_report["roundtrip_rows"],
                "level_report_missing_pairs": level_report["missing_pairs"],
                "level_report_duplicate_pairs": level_report["duplicate_pairs"],
                "level_report_unknown_pairs": level_report["unknown_pairs"],
                "level_report_markdown_present": level_report["markdown_present"],
                "level_report_markdown_summary_rows": level_report["markdown_summary_rows"],
                "level_report_markdown_matched": level_report["markdown_matched"],
                "level_report_markdown_unmatched": level_report["markdown_unmatched"],
                "level_report_markdown_detail_rows": level_report["markdown_detail_rows"],
                "level_report_markdown_detail_matched": level_report["markdown_detail_matched"],
                "level_report_markdown_detail_unmatched": level_report["markdown_detail_unmatched"],
                "dynamic_plan_present": dynamic_plan["present"],
                "dynamic_plan_healthy": dynamic_plan_healthy,
                "dynamic_plan_source_count": dynamic_plan["source_count"],
                "dynamic_plan_expected_source_count": dynamic_plan["expected_source_count"],
                "dynamic_plan_rows": dynamic_plan["rows"],
                "dynamic_plan_expected_rows": dynamic_plan["expected_rows"],
                "dynamic_plan_positive_rows": dynamic_plan["positive_rows"],
                "dynamic_plan_token_accounting_rows": dynamic_plan["token_accounting_rows"],
                "dynamic_plan_histogram_rows": dynamic_plan["histogram_rows"],
                "dynamic_plan_ratio_rows": dynamic_plan["ratio_rows"],
                "dynamic_plan_slack_rows": dynamic_plan["slack_rows"],
                "dynamic_plan_wrapper_rows": dynamic_plan["wrapper_rows"],
                "dynamic_plan_malformed_rows": dynamic_plan["malformed_rows"],
                "dynamic_plan_missing_sources": dynamic_plan["missing_sources"],
                "dynamic_plan_missing_paths": dynamic_plan["missing_paths"],
                "fuzz_corpus_present": fuzz_health["present"],
                "fuzz_corpus_ok": fuzz_health["ok"],
                "fuzz_corpus_coverage_present": fuzz_health["coverage_present"],
                "fuzz_corpus_coverage_ok": fuzz_health["coverage_ok"],
                "fuzz_corpus_markdown_present": fuzz_health["markdown_present"],
                "fuzz_corpus_healthy": fuzz_healthy,
                "fuzz_corpus_cases": fuzz_health["cases"],
                "fuzz_corpus_accepted": fuzz_health["accepted"],
                "fuzz_corpus_rejected": fuzz_health["rejected"],
                "fuzz_corpus_report_rows": fuzz_health["report_rows"],
                "fuzz_corpus_report_count_mismatch": fuzz_health["report_count_mismatch"],
                "fuzz_corpus_matched_rows": fuzz_health["matched_rows"],
                "fuzz_corpus_unmatched_rows": fuzz_health["unmatched_rows"],
                "fuzz_corpus_exact_error_expectations": fuzz_health["exact_error_expectations"],
                "fuzz_corpus_mode_count_rows": fuzz_health["mode_count_rows"],
                "fuzz_corpus_error_count_rows": fuzz_health["error_count_rows"],
                "fuzz_corpus_coverage_mode_requirements": fuzz_health["coverage_mode_requirements"],
                "fuzz_corpus_coverage_error_requirements": fuzz_health["coverage_error_requirements"],
                "fuzz_corpus_coverage_mode_matched": fuzz_health["coverage_mode_matched"],
                "fuzz_corpus_coverage_error_matched": fuzz_health["coverage_error_matched"],
                "fuzz_corpus_coverage_unmatched": fuzz_health["coverage_unmatched"],
                "fuzz_corpus_markdown_rows": fuzz_health["markdown_rows"],
                "fuzz_corpus_markdown_matched": fuzz_health["markdown_matched"],
                "fuzz_corpus_markdown_unmatched": fuzz_health["markdown_unmatched"],
                "decode_stage_present": decode_stage_health_summary["present"],
                "decode_stage_ok": decode_stage_health_summary["ok"],
                "decode_stage_healthy": decode_stage_healthy,
                "decode_stage_rows": decode_stage_health_summary["rows"],
                "decode_stage_error_rows": decode_stage_health_summary["error_rows"],
                "decode_stage_report_rows": decode_stage_health_summary["report_rows"],
                "decode_stage_error_item_rows": decode_stage_health_summary["error_item_rows"],
                "decode_stage_report_count_mismatch": decode_stage_health_summary["report_count_mismatch"],
                "decode_stage_matched_error_rows": decode_stage_health_summary["matched_error_rows"],
                "decode_stage_unmatched_error_rows": decode_stage_health_summary["unmatched_error_rows"],
                "decode_stage_csv_present": decode_stage_health_summary["csv_present"],
                "decode_stage_csv_rows": decode_stage_health_summary["csv_rows"],
                "decode_stage_csv_positive_rows": decode_stage_health_summary["csv_positive_rows"],
                "decode_stage_csv_header_rows": decode_stage_health_summary["csv_header_rows"],
                "decode_stage_csv_dynamic_rows": decode_stage_health_summary["csv_dynamic_rows"],
                "decode_stage_csv_fixed_rows": decode_stage_health_summary["csv_fixed_rows"],
                "decode_stage_csv_stored_rows": decode_stage_health_summary["csv_stored_rows"],
                "decode_stage_csv_missing_cases": decode_stage_health_summary["csv_missing_cases"],
                "decode_stage_csv_duplicate_cases": decode_stage_health_summary["csv_duplicate_cases"],
                "decode_stage_csv_unknown_cases": decode_stage_health_summary["csv_unknown_cases"],
                "decode_stage_markdown_present": decode_stage_health_summary["markdown_present"],
                "decode_stage_markdown_rows": decode_stage_health_summary["markdown_rows"],
                "decode_stage_markdown_matched": decode_stage_health_summary["markdown_matched"],
                "decode_stage_markdown_unmatched": decode_stage_health_summary["markdown_unmatched"],
                "native_fuzz_corpus_present": native_fuzz["present"],
                "native_fuzz_corpus_coverage_present": native_fuzz["coverage_present"],
                "native_fuzz_corpus_markdown_present": native_fuzz["markdown_present"],
                "native_fuzz_corpus_healthy": native_fuzz["healthy"],
                "native_fuzz_corpus_cases": native_fuzz["cases"],
                "native_fuzz_corpus_accepted": native_fuzz["accepted"],
                "native_fuzz_corpus_rejected": native_fuzz["rejected"],
                "native_fuzz_corpus_report_rows": native_fuzz["report_rows"],
                "native_fuzz_corpus_report_count_mismatch": native_fuzz["report_count_mismatch"],
                "native_fuzz_corpus_matched_rows": native_fuzz["matched_rows"],
                "native_fuzz_corpus_unmatched_rows": native_fuzz["unmatched_rows"],
                "native_fuzz_corpus_exact_error_expectations": native_fuzz["exact_error_expectations"],
                "native_fuzz_corpus_mode_count_rows": native_fuzz["mode_count_rows"],
                "native_fuzz_corpus_error_count_rows": native_fuzz["error_count_rows"],
                "native_fuzz_corpus_coverage_mode_requirements": native_fuzz["coverage_mode_requirements"],
                "native_fuzz_corpus_coverage_error_requirements": native_fuzz["coverage_error_requirements"],
                "native_fuzz_corpus_coverage_mode_matched": native_fuzz["coverage_mode_matched"],
                "native_fuzz_corpus_coverage_error_matched": native_fuzz["coverage_error_matched"],
                "native_fuzz_corpus_coverage_unmatched": native_fuzz["coverage_unmatched"],
                "native_fuzz_corpus_markdown_rows": native_fuzz["markdown_rows"],
                "native_fuzz_corpus_markdown_matched": native_fuzz["markdown_matched"],
                "native_fuzz_corpus_markdown_unmatched": native_fuzz["markdown_unmatched"],
                "br_static_dictionary_present": br_static_dictionary["present"],
                "br_static_dictionary_candidate_markdown_present": br_static_dictionary["candidate_markdown_present"],
                "br_static_dictionary_candidate_markdown_summary_rows": br_static_dictionary["candidate_markdown_summary_rows"],
                "br_static_dictionary_candidate_markdown_matched": br_static_dictionary["candidate_markdown_matched"],
                "br_static_dictionary_candidate_markdown_unmatched": br_static_dictionary["candidate_markdown_unmatched"],
                "br_static_dictionary_candidate_markdown_sample_rows": br_static_dictionary["candidate_markdown_sample_rows"],
                "br_static_dictionary_candidate_markdown_sample_matched": br_static_dictionary["candidate_markdown_sample_matched"],
                "br_static_dictionary_candidate_markdown_sample_unmatched": br_static_dictionary["candidate_markdown_sample_unmatched"],
                "br_static_dictionary_upstream_present": br_static_dictionary["upstream_present"],
                "br_static_dictionary_upstream_report_present": br_static_dictionary["upstream_report_present"],
                "br_static_dictionary_upstream_report_candidate_count": br_static_dictionary["upstream_report_candidate_count"],
                "br_static_dictionary_upstream_report_raw_word_count": br_static_dictionary["upstream_report_raw_word_count"],
                "br_static_dictionary_upstream_report_upstream_raw_word_count": br_static_dictionary["upstream_report_upstream_raw_word_count"],
                "br_static_dictionary_upstream_markdown_present": br_static_dictionary["upstream_markdown_present"],
                "br_static_dictionary_upstream_markdown_summary_rows": br_static_dictionary["upstream_markdown_summary_rows"],
                "br_static_dictionary_upstream_markdown_matched": br_static_dictionary["upstream_markdown_matched"],
                "br_static_dictionary_upstream_markdown_unmatched": br_static_dictionary["upstream_markdown_unmatched"],
                "br_static_dictionary_upstream_markdown_sample_rows": br_static_dictionary["upstream_markdown_sample_rows"],
                "br_static_dictionary_upstream_markdown_sample_matched": br_static_dictionary["upstream_markdown_sample_matched"],
                "br_static_dictionary_upstream_markdown_sample_unmatched": br_static_dictionary["upstream_markdown_sample_unmatched"],
                "br_static_dictionary_node_present": br_static_dictionary["node_present"],
                "br_static_dictionary_node_markdown_present": br_static_dictionary["node_markdown_present"],
                "br_static_dictionary_node_markdown_summary_rows": br_static_dictionary["node_markdown_summary_rows"],
                "br_static_dictionary_node_markdown_matched": br_static_dictionary["node_markdown_matched"],
                "br_static_dictionary_node_markdown_unmatched": br_static_dictionary["node_markdown_unmatched"],
                "br_static_dictionary_node_markdown_rows": br_static_dictionary["node_markdown_rows"],
                "br_static_dictionary_node_markdown_matched_rows": br_static_dictionary["node_markdown_matched_rows"],
                "br_static_dictionary_node_markdown_unmatched_rows": br_static_dictionary["node_markdown_unmatched_rows"],
                "br_static_dictionary_audit_present": br_static_dictionary["audit_present"],
                "br_static_dictionary_negative_present": br_static_dictionary["negative_present"],
                "br_static_dictionary_report_present": br_static_dictionary["report_present"],
                "br_static_dictionary_report_csv_present": br_static_dictionary["report_csv_present"],
                "br_static_dictionary_report_markdown_present": br_static_dictionary["report_markdown_present"],
                "br_static_dictionary_report_negative_present": br_static_dictionary["report_negative_present"],
                "br_static_dictionary_core_healthy": br_static_dictionary["core_healthy"],
                "br_static_dictionary_report_healthy": br_static_dictionary["report_healthy"],
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
                "br_static_dictionary_negative_rows": br_static_dictionary["negative_rows"],
                "br_static_dictionary_negative_matched": br_static_dictionary["negative_matched"],
                "br_static_dictionary_negative_count_mismatch": br_static_dictionary["negative_count_mismatch"],
                "br_static_dictionary_negative_unmatched": br_static_dictionary["negative_unmatched"],
                "br_static_dictionary_report_entry_count": br_static_dictionary["report_entry_count"],
                "br_static_dictionary_report_json_entries": br_static_dictionary["report_json_entries"],
                "br_static_dictionary_report_transform_count": br_static_dictionary["report_transform_count"],
                "br_static_dictionary_report_length_count": br_static_dictionary["report_length_count"],
                "br_static_dictionary_report_identity_count": br_static_dictionary["report_identity_count"],
                "br_static_dictionary_report_transform_entry_count": br_static_dictionary["report_transform_entry_count"],
                "br_static_dictionary_report_phrase_count": br_static_dictionary["report_phrase_count"],
                "br_static_dictionary_report_category_total": br_static_dictionary["report_category_total"],
                "br_static_dictionary_report_category_mismatch_rows": br_static_dictionary["report_category_mismatch_rows"],
                "br_static_dictionary_report_matrix_rows": br_static_dictionary["report_matrix_rows"],
                "br_static_dictionary_report_matrix_total": br_static_dictionary["report_matrix_total"],
                "br_static_dictionary_report_matrix_mismatch_rows": br_static_dictionary["report_matrix_mismatch_rows"],
                "br_static_dictionary_report_csv_rows": br_static_dictionary["report_csv_rows"],
                "br_static_dictionary_report_csv_matched": br_static_dictionary["report_csv_matched"],
                "br_static_dictionary_report_csv_unmatched": br_static_dictionary["report_csv_unmatched"],
                "br_static_dictionary_report_markdown_summary_rows": br_static_dictionary["report_markdown_summary_rows"],
                "br_static_dictionary_report_markdown_matched": br_static_dictionary["report_markdown_matched"],
                "br_static_dictionary_report_markdown_unmatched": br_static_dictionary["report_markdown_unmatched"],
                "br_static_dictionary_report_markdown_matrix_rows": br_static_dictionary["report_markdown_matrix_rows"],
                "br_static_dictionary_report_markdown_matrix_matched": br_static_dictionary["report_markdown_matrix_matched"],
                "br_static_dictionary_report_markdown_matrix_unmatched": br_static_dictionary["report_markdown_matrix_unmatched"],
                "br_static_dictionary_report_markdown_entry_rows": br_static_dictionary["report_markdown_entry_rows"],
                "br_static_dictionary_report_markdown_entry_matched": br_static_dictionary["report_markdown_entry_matched"],
                "br_static_dictionary_report_markdown_entry_unmatched": br_static_dictionary["report_markdown_entry_unmatched"],
                "br_static_dictionary_report_negative_case_count": br_static_dictionary["report_negative_case_count"],
                "br_static_dictionary_report_negative_rows": br_static_dictionary["report_negative_rows"],
                "br_static_dictionary_report_negative_matched": br_static_dictionary["report_negative_matched"],
                "br_static_dictionary_report_negative_count_mismatch": br_static_dictionary["report_negative_count_mismatch"],
                "br_static_dictionary_report_negative_unmatched": br_static_dictionary["report_negative_unmatched"],
                "png_scratch_present": png_scratch["present"],
                "png_scratch_markdown_present": png_scratch["markdown_present"],
                "png_scratch_healthy": png_scratch["healthy"],
                "png_scratch_case_count": png_scratch["case_count"],
                "png_scratch_report_rows": png_scratch["report_rows"],
                "png_scratch_report_count_mismatch": png_scratch["report_count_mismatch"],
                "png_scratch_row_consistent_count": png_scratch["row_consistent_count"],
                "png_scratch_row_inconsistent_count": png_scratch["row_inconsistent_count"],
                "png_scratch_adam7_cases": png_scratch["adam7_cases"],
                "png_scratch_stored_achieved": png_scratch["stored_achieved"],
                "png_scratch_fixed_achieved": png_scratch["fixed_achieved"],
                "png_scratch_total_zlib_scratch": png_scratch["total_zlib_scratch"],
                "png_scratch_total_streaming_savings": png_scratch["total_streaming_savings"],
                "png_scratch_max_working_scratch": png_scratch["max_working_scratch"],
                "png_scratch_max_streaming_working_scratch": png_scratch["max_streaming_working_scratch"],
                "png_scratch_max_fixed_dynamic_streaming_working_scratch": png_scratch["max_fixed_dynamic_streaming_working_scratch"],
                "png_scratch_min_streaming_ratio": png_scratch["min_streaming_ratio"],
                "png_scratch_markdown_rows": png_scratch["markdown_rows"],
                "png_scratch_markdown_matched": png_scratch["markdown_matched"],
                "png_scratch_markdown_unmatched": png_scratch["markdown_unmatched"],
                "zlib_relaxed_present": zlib_relaxed["present"],
                "zlib_relaxed_markdown_present": zlib_relaxed["markdown_present"],
                "zlib_relaxed_healthy": zlib_relaxed["healthy"],
                "zlib_relaxed_gate_present": zlib_relaxed["gate_present"],
                "zlib_relaxed_gate_ok": zlib_relaxed["gate_ok"],
                "zlib_relaxed_gate_check_count": zlib_relaxed["gate_check_count"],
                "zlib_relaxed_gate_expected_checks": zlib_relaxed["gate_expected_checks"],
                "zlib_relaxed_gate_passed_count": zlib_relaxed["gate_passed_count"],
                "zlib_relaxed_gate_failed_checks": zlib_relaxed["gate_failed_checks"],
                "zlib_relaxed_gate_report_matched": zlib_relaxed["gate_report_matched"],
                "zlib_relaxed_gate_report_unmatched": zlib_relaxed["gate_report_unmatched"],
                "zlib_relaxed_gate_missing_checks": zlib_relaxed["gate_missing_checks"],
                "zlib_relaxed_gate_extra_checks": zlib_relaxed["gate_extra_checks"],
                "zlib_relaxed_gate_recomputed_passed_count": zlib_relaxed["gate_recomputed_passed_count"],
                "zlib_relaxed_gate_recomputed_failed_count": zlib_relaxed["gate_recomputed_failed_count"],
                "zlib_relaxed_gate_check_rule_mismatch": zlib_relaxed["gate_check_rule_mismatch"],
                "zlib_relaxed_gate_exact_mismatch_count": zlib_relaxed["gate_exact_mismatch_count"],
                "zlib_relaxed_gate_floor_shortfall_count": zlib_relaxed["gate_floor_shortfall_count"],
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
                "zlib_relaxed_markdown_rows": zlib_relaxed["markdown_rows"],
                "zlib_relaxed_markdown_matched": zlib_relaxed["markdown_matched"],
                "zlib_relaxed_markdown_unmatched": zlib_relaxed["markdown_unmatched"],
                "snappy_report_present": snappy_report["present"],
                "snappy_report_healthy": snappy_report["healthy"],
                "snappy_report_rows": snappy_report["row_count"],
                "snappy_report_expected_rows": snappy_report["expected_rows"],
                "snappy_report_positive_timing_rows": snappy_report["positive_timing_rows"],
                "snappy_report_ratio_rows": snappy_report["ratio_rows"],
                "snappy_report_throughput_rows": snappy_report["throughput_rows"],
                "snappy_report_repetitive_shrunk_rows": snappy_report["repetitive_shrunk_rows"],
                "snappy_report_framed_overhead_matched_cases": snappy_report["framed_overhead_matched_cases"],
                "snappy_report_reusable_size_matched_cases": snappy_report["reusable_size_matched_cases"],
                "snappy_report_reusable_checksum_matched_cases": snappy_report["reusable_checksum_matched_cases"],
                "snappy_report_missing_pairs": snappy_report["missing_pairs"],
                "snappy_report_duplicate_pairs": snappy_report["duplicate_pairs"],
                "snappy_report_unknown_pairs": snappy_report["unknown_pairs"],
                "checksum_bench_present": checksum_bench["present"],
                "checksum_bench_healthy": checksum_bench["healthy"],
                "checksum_bench_rows": checksum_bench["row_count"],
                "checksum_bench_expected_rows": checksum_bench["expected_rows"],
                "checksum_bench_positive_rows": checksum_bench["positive_rows"],
                "checksum_bench_workload_rows": checksum_bench["workload_rows"],
                "checksum_bench_throughput_rows": checksum_bench["throughput_rows"],
                "checksum_bench_crc32_mix_groups": checksum_bench["crc32_mix_groups"],
                "checksum_bench_crc32c_mix_groups": checksum_bench["crc32c_mix_groups"],
                "checksum_bench_missing_algorithms": checksum_bench["missing_algorithms"],
                "checksum_bench_duplicate_algorithms": checksum_bench["duplicate_algorithms"],
                "checksum_bench_unknown_algorithms": checksum_bench["unknown_algorithms"],
                "chunk_cursor_bench_present": chunk_cursor_bench["present"],
                "chunk_cursor_bench_healthy": chunk_cursor_bench["healthy"],
                "chunk_cursor_bench_rows": chunk_cursor_bench["row_count"],
                "chunk_cursor_bench_expected_rows": chunk_cursor_bench["expected_rows"],
                "chunk_cursor_bench_positive_rows": chunk_cursor_bench["positive_rows"],
                "chunk_cursor_bench_shape_rows": chunk_cursor_bench["shape_rows"],
                "chunk_cursor_bench_throughput_rows": chunk_cursor_bench["throughput_rows"],
                "chunk_cursor_bench_checksum_matched_cases": chunk_cursor_bench["checksum_matched_cases"],
                "chunk_cursor_bench_missing_pairs": chunk_cursor_bench["missing_pairs"],
                "chunk_cursor_bench_duplicate_pairs": chunk_cursor_bench["duplicate_pairs"],
                "chunk_cursor_bench_unknown_pairs": chunk_cursor_bench["unknown_pairs"],
                "deflate_match_copy_bench_present": deflate_match_copy_bench["present"],
                "deflate_match_copy_bench_healthy": deflate_match_copy_bench["healthy"],
                "deflate_match_copy_bench_rows": deflate_match_copy_bench["row_count"],
                "deflate_match_copy_bench_expected_rows": deflate_match_copy_bench["expected_rows"],
                "deflate_match_copy_bench_positive_rows": deflate_match_copy_bench["positive_rows"],
                "deflate_match_copy_bench_expected_class_rows": deflate_match_copy_bench["expected_class_rows"],
                "deflate_match_copy_bench_output_bytes_rows": deflate_match_copy_bench["output_bytes_rows"],
                "deflate_match_copy_bench_throughput_rows": deflate_match_copy_bench["throughput_rows"],
                "deflate_match_copy_bench_checksum_matched_cases": deflate_match_copy_bench["checksum_matched_cases"],
                "deflate_match_copy_bench_missing_pairs": deflate_match_copy_bench["missing_pairs"],
                "deflate_match_copy_bench_duplicate_pairs": deflate_match_copy_bench["duplicate_pairs"],
                "deflate_match_copy_bench_unknown_pairs": deflate_match_copy_bench["unknown_pairs"],
                "deflate_huffman_build_bench_present": deflate_huffman_build_bench["present"],
                "deflate_huffman_build_bench_healthy": deflate_huffman_build_bench["healthy"],
                "deflate_huffman_build_bench_rows": deflate_huffman_build_bench["row_count"],
                "deflate_huffman_build_bench_expected_rows": deflate_huffman_build_bench["expected_rows"],
                "deflate_huffman_build_bench_positive_rows": deflate_huffman_build_bench["positive_rows"],
                "deflate_huffman_build_bench_lookup_rows": deflate_huffman_build_bench["lookup_rows"],
                "deflate_huffman_build_bench_throughput_rows": deflate_huffman_build_bench["throughput_rows"],
                "deflate_huffman_build_bench_checksum_variant_cases": deflate_huffman_build_bench["checksum_variant_cases"],
                "deflate_huffman_build_bench_missing_pairs": deflate_huffman_build_bench["missing_pairs"],
                "deflate_huffman_build_bench_duplicate_pairs": deflate_huffman_build_bench["duplicate_pairs"],
                "deflate_huffman_build_bench_unknown_pairs": deflate_huffman_build_bench["unknown_pairs"],
                "deflate_huffman_lookup_bench_present": deflate_huffman_lookup_bench["present"],
                "deflate_huffman_lookup_bench_healthy": deflate_huffman_lookup_bench["healthy"],
                "deflate_huffman_lookup_bench_rows": deflate_huffman_lookup_bench["row_count"],
                "deflate_huffman_lookup_bench_expected_rows": deflate_huffman_lookup_bench["expected_rows"],
                "deflate_huffman_lookup_bench_positive_rows": deflate_huffman_lookup_bench["positive_rows"],
                "deflate_huffman_lookup_bench_lookup_rows": deflate_huffman_lookup_bench["lookup_rows"],
                "deflate_huffman_lookup_bench_throughput_rows": deflate_huffman_lookup_bench["throughput_rows"],
                "deflate_huffman_lookup_bench_checksum_matched_cases": deflate_huffman_lookup_bench["checksum_matched_cases"],
                "deflate_huffman_lookup_bench_missing_pairs": deflate_huffman_lookup_bench["missing_pairs"],
                "deflate_huffman_lookup_bench_duplicate_pairs": deflate_huffman_lookup_bench["duplicate_pairs"],
                "deflate_huffman_lookup_bench_unknown_pairs": deflate_huffman_lookup_bench["unknown_pairs"],
                "deflate_chunked_huffman_bench_present": deflate_chunked_huffman_bench["present"],
                "deflate_chunked_huffman_bench_healthy": deflate_chunked_huffman_bench["healthy"],
                "deflate_chunked_huffman_bench_rows": deflate_chunked_huffman_bench["row_count"],
                "deflate_chunked_huffman_bench_expected_rows": deflate_chunked_huffman_bench["expected_rows"],
                "deflate_chunked_huffman_bench_positive_rows": deflate_chunked_huffman_bench["positive_rows"],
                "deflate_chunked_huffman_bench_shape_rows": deflate_chunked_huffman_bench["shape_rows"],
                "deflate_chunked_huffman_bench_buffered_zero_chunk_rows": deflate_chunked_huffman_bench["buffered_zero_chunk_rows"],
                "deflate_chunked_huffman_bench_chunk_count_rows": deflate_chunked_huffman_bench["chunk_count_rows"],
                "deflate_chunked_huffman_bench_throughput_rows": deflate_chunked_huffman_bench["throughput_rows"],
                "deflate_chunked_huffman_bench_checksum_matched_cases": deflate_chunked_huffman_bench["checksum_matched_cases"],
                "deflate_chunked_huffman_bench_missing_pairs": deflate_chunked_huffman_bench["missing_pairs"],
                "deflate_chunked_huffman_bench_duplicate_pairs": deflate_chunked_huffman_bench["duplicate_pairs"],
                "deflate_chunked_huffman_bench_unknown_pairs": deflate_chunked_huffman_bench["unknown_pairs"],
                "deflate_extra_bits_bench_present": deflate_extra_bits_bench["present"],
                "deflate_extra_bits_bench_healthy": deflate_extra_bits_bench["healthy"],
                "deflate_extra_bits_bench_rows": deflate_extra_bits_bench["row_count"],
                "deflate_extra_bits_bench_expected_rows": deflate_extra_bits_bench["expected_rows"],
                "deflate_extra_bits_bench_positive_rows": deflate_extra_bits_bench["positive_rows"],
                "deflate_extra_bits_bench_shape_rows": deflate_extra_bits_bench["shape_rows"],
                "deflate_extra_bits_bench_throughput_rows": deflate_extra_bits_bench["throughput_rows"],
                "deflate_extra_bits_bench_checksum_matched_cases": deflate_extra_bits_bench["checksum_matched_cases"],
                "deflate_extra_bits_bench_paired_checksum_rows": deflate_extra_bits_bench["paired_checksum_rows"],
                "deflate_extra_bits_bench_expected_paired_checksum_rows": deflate_extra_bits_bench["expected_paired_checksum_rows"],
                "deflate_extra_bits_bench_missing_pairs": deflate_extra_bits_bench["missing_pairs"],
                "deflate_extra_bits_bench_duplicate_pairs": deflate_extra_bits_bench["duplicate_pairs"],
                "deflate_extra_bits_bench_unknown_pairs": deflate_extra_bits_bench["unknown_pairs"],
                "dictionary_decode_bench_present": dictionary_decode_bench["present"],
                "dictionary_decode_bench_healthy": dictionary_decode_bench["healthy"],
                "dictionary_decode_bench_rows": dictionary_decode_bench["row_count"],
                "dictionary_decode_bench_expected_rows": dictionary_decode_bench["expected_rows"],
                "dictionary_decode_bench_positive_rows": dictionary_decode_bench["positive_rows"],
                "dictionary_decode_bench_shape_rows": dictionary_decode_bench["shape_rows"],
                "dictionary_decode_bench_output_size_rows": dictionary_decode_bench["output_size_rows"],
                "dictionary_decode_bench_throughput_rows": dictionary_decode_bench["throughput_rows"],
                "dictionary_decode_bench_checksum_matched_payloads": dictionary_decode_bench["checksum_matched_payloads"],
                "dictionary_decode_bench_missing_pairs": dictionary_decode_bench["missing_pairs"],
                "dictionary_decode_bench_duplicate_pairs": dictionary_decode_bench["duplicate_pairs"],
                "dictionary_decode_bench_unknown_pairs": dictionary_decode_bench["unknown_pairs"],
                "png_scanline_bench_present": png_scanline_bench["present"],
                "png_scanline_bench_healthy": png_scanline_bench["healthy"],
                "png_scanline_bench_rows": png_scanline_bench["row_count"],
                "png_scanline_bench_expected_rows": png_scanline_bench["expected_rows"],
                "png_scanline_bench_positive_rows": png_scanline_bench["positive_rows"],
                "png_scanline_bench_shape_rows": png_scanline_bench["shape_rows"],
                "png_scanline_bench_io_match_rows": png_scanline_bench["io_match_rows"],
                "png_scanline_bench_throughput_rows": png_scanline_bench["throughput_rows"],
                "png_scanline_bench_checksum_matched_bpps": png_scanline_bench["checksum_matched_bpps"],
                "png_scanline_bench_missing_pairs": png_scanline_bench["missing_pairs"],
                "png_scanline_bench_duplicate_pairs": png_scanline_bench["duplicate_pairs"],
                "png_scanline_bench_unknown_pairs": png_scanline_bench["unknown_pairs"],
                "chunked_zlib_bench_present": chunked_zlib_bench["present"],
                "chunked_zlib_bench_healthy": chunked_zlib_bench["healthy"],
                "chunked_zlib_bench_rows": chunked_zlib_bench["row_count"],
                "chunked_zlib_bench_expected_rows": chunked_zlib_bench["expected_rows"],
                "chunked_zlib_bench_positive_rows": chunked_zlib_bench["positive_rows"],
                "chunked_zlib_bench_shape_rows": chunked_zlib_bench["shape_rows"],
                "chunked_zlib_bench_chunk_count_rows": chunked_zlib_bench["chunk_count_rows"],
                "chunked_zlib_bench_ratio_rows": chunked_zlib_bench["ratio_rows"],
                "chunked_zlib_bench_missing_cases": chunked_zlib_bench["missing_cases"],
                "chunked_zlib_bench_duplicate_cases": chunked_zlib_bench["duplicate_cases"],
                "chunked_zlib_bench_unknown_cases": chunked_zlib_bench["unknown_cases"],
                "chunked_zlib_bench_markdown_present": chunked_zlib_bench["markdown_present"],
                "chunked_zlib_bench_markdown_rows": chunked_zlib_bench["markdown_rows"],
                "chunked_zlib_bench_markdown_matched": chunked_zlib_bench["markdown_matched"],
                "chunked_zlib_bench_markdown_unmatched": chunked_zlib_bench["markdown_unmatched"],
                "png_streaming_zlib_bench_present": png_streaming_zlib_bench["present"],
                "png_streaming_zlib_bench_healthy": png_streaming_zlib_bench["healthy"],
                "png_streaming_zlib_bench_rows": png_streaming_zlib_bench["row_count"],
                "png_streaming_zlib_bench_expected_rows": png_streaming_zlib_bench["expected_rows"],
                "png_streaming_zlib_bench_positive_rows": png_streaming_zlib_bench["positive_rows"],
                "png_streaming_zlib_bench_shape_rows": png_streaming_zlib_bench["shape_rows"],
                "png_streaming_zlib_bench_image_size_rows": png_streaming_zlib_bench["image_size_rows"],
                "png_streaming_zlib_bench_chunk_count_rows": png_streaming_zlib_bench["chunk_count_rows"],
                "png_streaming_zlib_bench_ratio_rows": png_streaming_zlib_bench["ratio_rows"],
                "png_streaming_zlib_bench_missing_cases": png_streaming_zlib_bench["missing_cases"],
                "png_streaming_zlib_bench_duplicate_cases": png_streaming_zlib_bench["duplicate_cases"],
                "png_streaming_zlib_bench_unknown_cases": png_streaming_zlib_bench["unknown_cases"],
                "deflate_dynamic_decode_profile_present": deflate_dynamic_decode_profile["present"],
                "deflate_dynamic_decode_profile_healthy": deflate_dynamic_decode_profile["healthy"],
                "deflate_dynamic_decode_profile_rows": deflate_dynamic_decode_profile["row_count"],
                "deflate_dynamic_decode_profile_required_rows": deflate_dynamic_decode_profile["required_rows"],
                "deflate_dynamic_decode_profile_positive_rows": deflate_dynamic_decode_profile["positive_rows"],
                "deflate_dynamic_decode_profile_histogram_rows": deflate_dynamic_decode_profile["histogram_rows"],
                "deflate_dynamic_decode_profile_lookup_rows": deflate_dynamic_decode_profile["lookup_rows"],
                "deflate_dynamic_decode_profile_match_class_rows": deflate_dynamic_decode_profile["match_class_rows"],
                "deflate_dynamic_decode_profile_ratio_rows": deflate_dynamic_decode_profile["ratio_rows"],
                "deflate_dynamic_decode_profile_chunked_window_rows": deflate_dynamic_decode_profile["chunked_window_rows"],
                "deflate_dynamic_decode_profile_missing_cases": deflate_dynamic_decode_profile["missing_cases"],
                "deflate_dynamic_decode_profile_duplicate_cases": deflate_dynamic_decode_profile["duplicate_cases"],
                "native_library_bench_present": native_library_bench["present"],
                "native_library_bench_healthy": native_library_bench["healthy"],
                "native_library_bench_rows": native_library_bench["row_count"],
                "native_library_bench_expected_rows": native_library_bench["expected_rows"],
                "native_library_bench_positive_rows": native_library_bench["positive_rows"],
                "native_library_bench_throughput_rows": native_library_bench["throughput_rows"],
                "native_library_bench_iteration_rows": native_library_bench["iteration_rows"],
                "native_library_bench_improvement_checks": native_library_bench["improvement_checks"],
                "native_library_bench_expected_improvement_checks": native_library_bench["expected_improvement_checks"],
                "native_library_bench_missing_pairs": native_library_bench["missing_pairs"],
                "native_library_bench_duplicate_pairs": native_library_bench["duplicate_pairs"],
                "native_library_bench_unknown_pairs": native_library_bench["unknown_pairs"],
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
                "zstd_compare_csv_present_count": zstd_compare["csv_present_count"],
                "zstd_compare_csv_expected_present_count": zstd_compare["csv_expected_present_count"],
                "zstd_compare_csv_rows": zstd_compare["csv_rows"],
                "zstd_compare_csv_expected_rows": zstd_compare["csv_expected_rows"],
                "zstd_compare_csv_matched_rows": zstd_compare["csv_matched_rows"],
                "zstd_compare_csv_unmatched_rows": zstd_compare["csv_unmatched_rows"],
                "zstd_compare_markdown_present_count": zstd_compare["markdown_present_count"],
                "zstd_compare_markdown_expected_present_count": zstd_compare["markdown_expected_present_count"],
                "zstd_compare_markdown_summary_rows": zstd_compare["markdown_summary_rows"],
                "zstd_compare_markdown_matched": zstd_compare["markdown_matched"],
                "zstd_compare_markdown_unmatched": zstd_compare["markdown_unmatched"],
                "zstd_compare_markdown_detail_rows": zstd_compare["markdown_detail_rows"],
                "zstd_compare_markdown_detail_matched": zstd_compare["markdown_detail_matched"],
                "zstd_compare_markdown_detail_unmatched": zstd_compare["markdown_detail_unmatched"],
                "native_allocation_present": native_allocation["present"],
                "native_allocation_smoke_present": native_allocation["smoke_present"],
                "native_allocation_negative_present": native_allocation["negative_present"],
                "native_allocation_markdown_present": native_allocation["markdown_present"],
                "native_allocation_healthy": native_allocation["healthy"],
                "native_allocation_report_case_count": native_allocation["report_case_count"],
                "native_allocation_report_rows": native_allocation["report_rows"],
                "native_allocation_report_count_mismatch": native_allocation["report_count_mismatch"],
                "native_allocation_report_balanced_rows": native_allocation["report_balanced_rows"],
                "native_allocation_report_duplicate_cases": native_allocation["report_duplicate_cases"],
                "native_allocation_report_unbalanced_rows": native_allocation["report_unbalanced_rows"],
                "native_allocation_required_zero_allocation_cases": native_allocation["required_zero_allocation_cases"],
                "native_allocation_zero_allocation_matched": native_allocation["zero_allocation_matched"],
                "native_allocation_zero_report_matched": native_allocation["zero_report_matched"],
                "native_allocation_zero_report_unmatched": native_allocation["zero_report_unmatched"],
                "native_allocation_required_budget_cases": native_allocation["required_budget_cases"],
                "native_allocation_budget_matched": native_allocation["budget_matched"],
                "native_allocation_budget_report_matched": native_allocation["budget_report_matched"],
                "native_allocation_budget_report_unmatched": native_allocation["budget_report_unmatched"],
                "native_allocation_smoke_classified_cases": native_allocation["smoke_classified_cases"],
                "native_allocation_smoke_classification_overlap": native_allocation["smoke_classification_overlap"],
                "native_allocation_smoke_classification_missing": native_allocation["smoke_classification_missing"],
                "native_allocation_smoke_classification_extra": native_allocation["smoke_classification_extra"],
                "native_allocation_negative_case_count": native_allocation["negative_case_count"],
                "native_allocation_negative_matched": native_allocation["negative_matched"],
                "native_allocation_negative_unmatched": native_allocation["negative_unmatched"],
                "native_allocation_markdown_rows": native_allocation["markdown_rows"],
                "native_allocation_markdown_matched": native_allocation["markdown_matched"],
                "native_allocation_markdown_unmatched": native_allocation["markdown_unmatched"],
                "python_zlib_diff_present": python_zlib_health["present"],
                "python_zlib_diff_ok": python_zlib_health["ok"],
                "python_zlib_diff_healthy": python_zlib_healthy,
                "python_zlib_diff_payloads": python_zlib_health["payloads"],
                "python_zlib_diff_large_file_payloads": python_zlib_health["large_file_payloads"],
                "python_zlib_diff_inline_payloads": python_zlib_health["inline_payloads"],
                "python_zlib_diff_large_file_payload_overflow": python_zlib_health["large_file_payload_overflow"],
                "python_zlib_diff_file_hex_encode_cases": python_zlib_health["file_hex_encode_cases"],
                "python_zlib_diff_match_heavy_payloads": python_zlib_health["match_heavy_payloads"],
                "python_zlib_diff_dynamic_payloads": python_zlib_health["dynamic_payloads"],
                "python_zlib_diff_dictionary_cases": python_zlib_health["dictionary_cases"],
                "python_zlib_diff_zlib_dict_encode_cases": python_zlib_health["zlib_dict_encode_cases"],
                "python_zlib_diff_raw_dict_encode_cases": python_zlib_health["raw_dict_encode_cases"],
                "python_zlib_diff_dictionary_encode_cases": python_zlib_health["dictionary_encode_cases"],
                "python_zlib_diff_malformed_wrapper_cases": python_zlib_health["malformed_wrapper_cases"],
                "python_zlib_diff_malformed_deflate_cases": python_zlib_health["malformed_deflate_cases"],
                "python_zlib_diff_malformed_cases": python_zlib_health["malformed_cases"],
                "python_zlib_diff_cli_successes": python_zlib_health["cli_successes"],
                "python_zlib_diff_expected_failures": python_zlib_health["expected_failures"],
                "python_zlib_diff_cli_total_outcomes": python_zlib_health["cli_total_outcomes"],
                "python_zlib_diff_file_hex_expected_cases": python_zlib_health["file_hex_expected_cases"],
                "python_zlib_diff_file_hex_case_mismatch": python_zlib_health["file_hex_case_mismatch"],
                "python_zlib_diff_cli_success_floor": python_zlib_health["cli_success_floor"],
                "python_zlib_diff_cli_success_shortfall": python_zlib_health["cli_success_shortfall"],
                "python_zlib_diff_expected_failure_floor": python_zlib_health["expected_failure_floor"],
                "python_zlib_diff_expected_failure_shortfall": python_zlib_health["expected_failure_shortfall"],
                "python_zlib_diff_cli_outcome_floor": python_zlib_health["cli_outcome_floor"],
                "python_zlib_diff_cli_outcome_shortfall": python_zlib_health["cli_outcome_shortfall"],
                "python_zlib_diff_payload_cli_success_expected": python_zlib_health["payload_cli_success_expected"],
                "python_zlib_diff_cli_success_expected": python_zlib_health["cli_success_expected"],
                "python_zlib_diff_expected_failure_expected": python_zlib_health["expected_failure_expected"],
                "python_zlib_diff_cli_total_expected": python_zlib_health["cli_total_expected"],
                "python_zlib_diff_cli_success_exact_mismatch": python_zlib_health["cli_success_exact_mismatch"],
                "python_zlib_diff_expected_failure_exact_mismatch": python_zlib_health["expected_failure_exact_mismatch"],
                "python_zlib_diff_cli_outcome_exact_mismatch": python_zlib_health["cli_outcome_exact_mismatch"],
                "native_codec_probes_present": native_codec_health["present"],
                "native_codec_probes_ok": native_codec_health["ok"],
                "native_codec_probes_markdown_present": native_codec_health["markdown_present"],
                "native_codec_probes_healthy": native_codec_health["healthy"],
                "native_codec_probes_probe_count": native_codec_health["probe_count"],
                "native_codec_probes_probe_rows": native_codec_health["probe_rows"],
                "native_codec_probes_ok_probe_count": native_codec_health["ok_probe_count"],
                "native_codec_probes_timed_out_probes": native_codec_health["timed_out_probes"],
                "native_codec_probes_probe_case_sum": native_codec_health["probe_case_sum"],
                "native_codec_probes_probe_count_mismatch": native_codec_health["probe_count_mismatch"],
                "native_codec_probes_probe_case_sum_mismatch": native_codec_health["probe_case_sum_mismatch"],
                "native_codec_probes_missing_required_probes": native_codec_health["missing_required_probes"],
                "native_codec_probes_duplicate_probe_rows": native_codec_health["duplicate_probe_rows"],
                "native_codec_probes_coverage_count": native_codec_health["coverage_count"],
                "native_codec_probes_coverage_rows": native_codec_health["coverage_rows"],
                "native_codec_probes_coverage_ok_rows": native_codec_health["coverage_ok_rows"],
                "native_codec_probes_coverage_case_sum": native_codec_health["coverage_case_sum"],
                "native_codec_probes_coverage_count_mismatch": native_codec_health["coverage_count_mismatch"],
                "native_codec_probes_missing_required_coverage": native_codec_health["missing_required_coverage"],
                "native_codec_probes_duplicate_coverage_rows": native_codec_health["duplicate_coverage_rows"],
                "native_codec_probes_capability_count": native_codec_health["capability_count"],
                "native_codec_probes_capability_rows": native_codec_health["capability_rows"],
                "native_codec_probes_ok_capability_count": native_codec_health["ok_capability_count"],
                "native_codec_probes_capability_count_mismatch": native_codec_health["capability_count_mismatch"],
                "native_codec_probes_capability_row_unhealthy": native_codec_health["capability_row_unhealthy"],
                "native_codec_probes_missing_required_capabilities": native_codec_health["missing_required_capabilities"],
                "native_codec_probes_duplicate_capability_rows": native_codec_health["duplicate_capability_rows"],
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
                "native_codec_probes_markdown_rows": native_codec_health["markdown_rows"],
                "native_codec_probes_markdown_matched": native_codec_health["markdown_matched"],
                "native_codec_probes_markdown_unmatched": native_codec_health["markdown_unmatched"],
                "native_summary_error_present": native_summary_error_health["present"],
                "native_summary_error_healthy": native_summary_error_healthy,
                "native_summary_error_case_count": native_summary_error_health["case_count"],
                "native_summary_error_case_rows": native_summary_error_health["case_rows"],
                "native_summary_error_case_count_mismatch": native_summary_error_health["case_count_mismatch"],
                "native_summary_error_lz4_case_count": native_summary_error_health["lz4_case_count"],
                "native_summary_error_zstd_case_count": native_summary_error_health["zstd_case_count"],
                "native_summary_error_codec_case_count_mismatch": native_summary_error_health["codec_case_count_mismatch"],
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
                "native_summary_error_error_count_mismatch": native_summary_error_health["error_count_mismatch"],
                "native_summary_error_phase_count_mismatch": native_summary_error_health["phase_count_mismatch"],
                "native_summary_error_codec_error_count_mismatch": native_summary_error_health["codec_error_count_mismatch"],
                "native_summary_error_codec_phase_count_mismatch": native_summary_error_health["codec_phase_count_mismatch"],
                "native_summary_error_offset_range_mismatch": native_summary_error_health["offset_range_mismatch"],
                "native_summary_error_phase_offset_ranges": native_summary_error_health["phase_offset_ranges"],
                "native_summary_error_required_codec_phases": native_summary_error_health["required_codec_phases"],
                "native_summary_error_lz4_missing_phases": native_summary_error_health["lz4_missing_phases"],
                "native_summary_error_zstd_missing_phases": native_summary_error_health["zstd_missing_phases"],
                "native_summary_error_negative_present": native_summary_error_negative["present"],
                "native_summary_error_negative_healthy": native_summary_error_negative_healthy,
                "native_summary_error_negative_case_count": native_summary_error_negative["case_count"],
                "native_summary_error_negative_rows": native_summary_error_negative["rows"],
                "native_summary_error_negative_count_mismatch": native_summary_error_negative["count_mismatch"],
                "native_summary_error_negative_matched": native_summary_error_negative["matched"],
                "native_summary_error_negative_expected_failures": native_summary_error_negative["expected_failures"],
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
                "lz4_native_summary_block_count_mismatch": lz4_native_summary["block_count_mismatch"],
                "lz4_native_summary_declared_payload_slack_bytes": lz4_native_summary["declared_payload_slack_bytes"],
                "lz4_native_summary_metadata_frame_overflow": lz4_native_summary["metadata_frame_overflow"],
                "lz4_native_summary_checksum_frame_overflow": lz4_native_summary["checksum_frame_overflow"],
                "lz4_native_summary_block_checksum_frame_overflow": lz4_native_summary["block_checksum_frame_overflow"],
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
                "zstd_native_summary_block_count_mismatch": zstd_native_summary["block_count_mismatch"],
                "zstd_native_summary_declared_payload_slack_bytes": zstd_native_summary["declared_payload_slack_bytes"],
                "zstd_native_summary_metadata_frame_overflow": zstd_native_summary["metadata_frame_overflow"],
                "zstd_native_summary_checksum_frame_overflow": zstd_native_summary["checksum_frame_overflow"],
                "zstd_native_summary_block_checksum_frame_overflow": zstd_native_summary["block_checksum_frame_overflow"],
                "native_tier_range_present": native_tier_health["present"],
                "native_tier_range_healthy": native_tier_health["healthy"],
                "native_tier_range_summary_count": native_tier_health["summary_count"],
                "native_tier_range_ok_count": native_tier_health["ok_count"],
                "native_tier_range_rows": native_tier_health["rows"],
                "native_tier_range_fixture_count": native_tier_health["fixture_count"],
                "native_tier_range_enforced_count": native_tier_health["enforced_count"],
                "native_tier_range_csv_present_count": native_tier_health["csv_present_count"],
                "native_tier_range_csv_healthy_count": native_tier_health["csv_healthy_count"],
                "native_tier_range_csv_rows": native_tier_health["csv_rows"],
                "native_tier_range_csv_positive_rows": native_tier_health["csv_positive_rows"],
                "native_tier_range_csv_shape_rows": native_tier_health["csv_shape_rows"],
                "native_tier_range_csv_throughput_rows": native_tier_health["csv_throughput_rows"],
                "native_tier_range_csv_missing_sources": native_tier_health["csv_missing_sources"],
                "native_tier_range_csv_missing_pairs": native_tier_health["csv_missing_pairs"],
                "native_tier_range_csv_duplicate_pairs": native_tier_health["csv_duplicate_pairs"],
                "native_tier_range_csv_unknown_pairs": native_tier_health["csv_unknown_pairs"],
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
                "native_tier_range_source_count_mismatch": native_tier_health["source_count_mismatch"],
                "native_tier_range_summary_csv_row_mismatch": native_tier_health["summary_csv_row_mismatch"],
                "native_tier_range_summary_csv_fixture_mismatch": native_tier_health["summary_csv_fixture_mismatch"],
                "native_tier_range_summary_csv_tier_mismatch": native_tier_health["summary_csv_tier_mismatch"],
                "native_tier_range_summary_csv_path_mismatch": native_tier_health["summary_csv_path_mismatch"],
                "native_tier_range_summary_csv_stream_bytes_mismatch": native_tier_health["summary_csv_stream_bytes_mismatch"],
                "native_tier_range_summary_csv_index_entries_mismatch": native_tier_health["summary_csv_index_entries_mismatch"],
                "native_tier_range_summary_csv_min_range_mismatch": native_tier_health["summary_csv_min_range_mismatch"],
                "native_tier_range_summary_csv_min_full_mismatch": native_tier_health["summary_csv_min_full_mismatch"],
                "native_tier_range_summary_csv_mismatch_total": native_tier_health["summary_csv_mismatch_total"],
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
                "native_tier_corpus_discovery_selected_case_mismatch": native_tier_discovery_health["selected_case_mismatch"],
                "native_tier_corpus_discovery_csv_path_mismatch": native_tier_discovery_health["csv_path_mismatch"],
                "native_tier_corpus_discovery_summary_fixture_mismatch": native_tier_discovery_health["summary_fixture_mismatch"],
                "native_tier_corpus_discovery_csv_fixture_mismatch": native_tier_discovery_health["csv_fixture_mismatch"],
                "native_tier_corpus_discovery_csv_byte_mismatch": native_tier_discovery_health["csv_byte_mismatch"],
                "native_tier_corpus_discovery_mismatch_total": native_tier_discovery_health["mismatch_total"],
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
