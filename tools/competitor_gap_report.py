#!/usr/bin/env python3
"""Aggregate existing benchmark CSVs into one competitor-gap report.

The source benchmarks deliberately measure different APIs and wire formats.
This tool normalizes their ratios, but groups results by codec, operation, and
profile so unrelated measurements are never folded into one headline score.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import platform
import subprocess
import sys
from collections import defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FILES = {
    "deflate_encode": (
        "vort-rust-deflate-encode-bench-repeat3.csv",
        "vort-rust-deflate-encode-bench.csv",
    ),
    "deflate_decode": (
        "vort-rust-deflate-decode-bench-repeat3.csv",
        "vort-rust-deflate-decode-bench.csv",
    ),
    "deflate_incremental": ("vort-deflate-incremental-encode.csv",),
    "zstd_encode": ("vort-zstd-encode-bench.csv",),
    "zstd_decode": ("vort-zstd-reference-bench.csv",),
    "lz4": ("vort-lz4-reference-bench.csv",),
    "snappy": ("vort-snappy-reference-bench.csv",),
    "brotli_encode": ("vort-br-planned-encode-bench.csv",),
    "brotli_decode": ("vort-br-reference-bench.csv",),
    "standard_corpus": (
        "vort-standard-multi-corpus-dashboard.csv",
        "vort-standard-corpus-dashboard.csv",
        "vort-standard-corpus.csv",
    ),
}
OPTIONAL_FILES = {"deflate_incremental", "standard_corpus"}
PROVENANCE_COLUMNS = (
    "provenance_version",
    "optimize",
    "zig_version",
    "target_arch",
    "target_os",
    "target_abi",
    "target_cpu",
    "cpu_model",
    "cpu_affinity",
    "affinity_cpu_count",
    "benchmark_threads",
    "codec_thread_policy",
    "executable_sha256",
    "command",
)


class ReportError(RuntimeError):
    pass


@dataclass(frozen=True)
class Metric:
    codec: str
    operation: str
    profile: str
    case: str
    metric: str
    unit: str
    better: str
    vort_value: float
    reference_value: float
    vort_over_reference: float
    reference: str
    reference_version: str
    input_bytes: int
    vort_bytes: int | None
    reference_bytes: int | None
    source: str
    input_sha256: str | None = None


def read_csv(path: Path, required: set[str], source: str) -> list[dict[str, str]]:
    try:
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle, strict=True)
            fieldnames = reader.fieldnames or []
            fields = set(fieldnames)
            if len(fieldnames) != len(fields):
                raise ReportError(f"{source}: duplicate CSV columns: {path}")
            missing = sorted(required - fields)
            if missing:
                raise ReportError(f"{source}: missing columns {missing}: {path}")
            rows = list(reader)
    except (OSError, UnicodeError, csv.Error) as error:
        raise ReportError(f"{source}: cannot read {path}: {error}") from error
    if not rows:
        raise ReportError(f"{source}: CSV has no data rows: {path}")
    return rows


def number(row: dict[str, str], key: str, source: str) -> float:
    try:
        value = float(row[key])
    except (KeyError, TypeError, ValueError) as error:
        raise ReportError(f"{source}: invalid {key!r} in row {row!r}") from error
    if not math.isfinite(value) or value <= 0.0:
        raise ReportError(f"{source}: non-positive or non-finite {key!r} in row {row!r}")
    return value


def integer(row: dict[str, str], key: str, source: str) -> int:
    value = number(row, key, source)
    if not value.is_integer():
        raise ReportError(f"{source}: non-integer {key!r} in row {row!r}")
    return int(value)


def nonnegative_integer(row: dict[str, str], key: str, source: str) -> int:
    try:
        value = int(row[key])
    except (KeyError, TypeError, ValueError) as error:
        raise ReportError(f"{source}: invalid {key!r} in row {row!r}") from error
    if value < 0:
        raise ReportError(f"{source}: negative {key!r} in row {row!r}")
    return value


def optional_nonnegative(row: dict[str, str], key: str, source: str) -> float:
    try:
        value = float(row.get(key, "0"))
    except (TypeError, ValueError) as error:
        raise ReportError(f"{source}: invalid {key!r} in row {row!r}") from error
    if not math.isfinite(value) or value < 0.0:
        raise ReportError(f"{source}: negative or non-finite {key!r} in row {row!r}")
    return value


def version_text(value: str) -> str:
    try:
        packed = int(value)
    except ValueError:
        return value or "unreported"
    if packed >= 1_000_000:
        return f"{packed // 1_000_000}.{(packed // 1_000) % 1_000}.{packed % 1_000}"
    if packed >= 10_000:
        return f"{packed // 10_000}.{(packed // 100) % 100}.{packed % 100}"
    return value or "unreported"


def speed_metric(
    codec: str,
    profile: str,
    case: str,
    vort_speed: float,
    reference_speed: float,
    reference: str,
    version: str,
    input_bytes: int,
    source: str,
    operation: str = "decode",
    vort_bytes: int | None = None,
    reference_bytes: int | None = None,
    input_sha256: str | None = None,
) -> Metric:
    if vort_speed <= 0.0 or reference_speed <= 0.0:
        raise ReportError(f"{source}: throughput must be positive for {case}")
    return Metric(
        codec, operation, profile, case, "throughput", "MiB/s", "higher",
        vort_speed, reference_speed, vort_speed / reference_speed, reference,
        version or "unreported", input_bytes, vort_bytes, reference_bytes, source, input_sha256,
    )


def size_metric(
    codec: str,
    profile: str,
    case: str,
    vort_bytes: int,
    reference_bytes: int,
    reference: str,
    version: str,
    input_bytes: int,
    source: str,
    input_sha256: str | None = None,
) -> Metric:
    if input_bytes <= 0 or vort_bytes <= 0 or reference_bytes <= 0:
        raise ReportError(f"{source}: sizes must be positive for {case}")
    return Metric(
        codec, "encode", profile, case, "compressed_size", "compressed/input",
        "lower", vort_bytes / input_bytes, reference_bytes / input_bytes,
        vort_bytes / reference_bytes, reference, version or "unreported",
        input_bytes, vort_bytes, reference_bytes, source, input_sha256,
    )


def grouped_unique(rows: list[dict[str, str]], keys: tuple[str, ...], source: str) -> dict[tuple[str, ...], list[dict[str, str]]]:
    grouped: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    seen: set[tuple[str, ...]] = set()
    for row in rows:
        identity = tuple(row[key] for key in keys)
        if identity in seen:
            raise ReportError(f"{source}: duplicate row {identity}")
        seen.add(identity)
        grouped[identity[:-1]].append(row)
    return grouped


def common_input_bytes(rows: list[dict[str, str]], source: str, context: object) -> int:
    values = {integer(row, "input_bytes", source) for row in rows}
    if len(values) != 1:
        raise ReportError(f"{source}: inconsistent input_bytes for {context!r}: {sorted(values)}")
    return next(iter(values))


def deflate_encode_metrics(rows: list[dict[str, str]], source: str) -> list[Metric]:
    required = {"engine", "format", "case", "input_bytes", "frame_bytes", "throughput_mib_s"}
    if any(required - set(row) for row in rows):
        raise ReportError(f"{source}: invalid Deflate encode schema")
    groups = grouped_unique(rows, ("format", "case", "engine"), source)
    metrics: list[Metric] = []
    for (wire_format, case), items in sorted(groups.items()):
        if wire_format not in {"raw", "zlib"}:
            continue
        input_bytes = common_input_bytes(items, source, (wire_format, case))
        vort = [row for row in items if row["engine"].startswith("vort")]
        refs = [row for row in items if not row["engine"].startswith("vort")]
        if not vort or not refs:
            continue
        selections = (
            ("best-speed", max(vort, key=lambda row: number(row, "throughput_mib_s", source)), max(refs, key=lambda row: number(row, "throughput_mib_s", source))),
            ("best-size", min(vort, key=lambda row: (integer(row, "frame_bytes", source), -number(row, "throughput_mib_s", source))), min(refs, key=lambda row: (integer(row, "frame_bytes", source), -number(row, "throughput_mib_s", source)))),
        )
        for profile, vort_row, ref_row in selections:
            vort_bytes = integer(vort_row, "frame_bytes", source)
            ref_bytes = integer(ref_row, "frame_bytes", source)
            label = f"{wire_format}-{profile}"
            reference = ref_row["engine"]
            metrics.append(speed_metric(
                "deflate", label, case, number(vort_row, "throughput_mib_s", source),
                number(ref_row, "throughput_mib_s", source), reference, "unreported",
                input_bytes, source, "encode", vort_bytes, ref_bytes,
            ))
            metrics.append(size_metric(
                "deflate", label, case, vort_bytes, ref_bytes, reference,
                "unreported", input_bytes, source,
            ))
    return metrics


def deflate_decode_metrics(rows: list[dict[str, str]], source: str) -> list[Metric]:
    required = {"engine", "format", "case", "input_bytes", "throughput_mib_s"}
    if any(required - set(row) for row in rows):
        raise ReportError(f"{source}: invalid Deflate decode schema")
    groups = grouped_unique(rows, ("format", "case", "engine"), source)
    metrics: list[Metric] = []
    modes = {
        "zlib": (("alloc", "vort"), ("exact", "vort-exact"), ("into", "vort-into")),
        "raw": (("alloc", "vort-raw"), ("exact", "vort-raw-exact"), ("into", "vort-raw-into")),
    }
    for (wire_format, case), items in sorted(groups.items()):
        if wire_format not in modes:
            continue
        input_bytes = common_input_bytes(items, source, (wire_format, case))
        by_engine = {row["engine"]: row for row in items}
        refs = [row for row in items if not row["engine"].startswith("vort")]
        if not refs:
            continue
        ref = max(refs, key=lambda row: number(row, "throughput_mib_s", source))
        for api, engine in modes[wire_format]:
            row = by_engine.get(engine)
            if row is None:
                continue
            metrics.append(speed_metric(
                "deflate", f"{wire_format}-{api}", case,
                number(row, "throughput_mib_s", source), number(ref, "throughput_mib_s", source),
                ref["engine"], "unreported", input_bytes, source,
            ))
    return metrics


def deflate_incremental_metrics(rows: list[dict[str, str]], source: str) -> list[Metric]:
    required = {"case", "mode", "input_bytes", "output_bytes", "throughput_mib_s"}
    if any(required - set(row) for row in rows):
        raise ReportError(f"{source}: invalid incremental Deflate schema")
    groups = grouped_unique(rows, ("case", "mode"), source)
    metrics: list[Metric] = []
    for (case,), items in sorted(groups.items()):
        input_bytes = common_input_bytes(items, source, case)
        by_mode = {row["mode"]: row for row in items}
        vort = by_mode.get("persistent-lazy")
        refs = [row for row in items if row["mode"].startswith("zlib-")]
        if vort is None or not refs:
            continue
        ref = refs[0]
        reference = ref["mode"]
        vort_bytes = integer(vort, "output_bytes", source)
        ref_bytes = integer(ref, "output_bytes", source)
        metrics.append(speed_metric(
            "deflate", "incremental-level6", case,
            number(vort, "throughput_mib_s", source), number(ref, "throughput_mib_s", source),
            reference, "unreported", input_bytes, source, "encode", vort_bytes, ref_bytes,
        ))
        metrics.append(size_metric(
            "deflate", "incremental-level6", case, vort_bytes, ref_bytes,
            reference, "unreported", input_bytes, source,
        ))
    return metrics


def paired_metrics(
    rows: list[dict[str, str]],
    source: str,
    codec: str,
    operation: str,
    profile: Callable[[dict[str, str]], str],
    reference: str,
    version_column: str | None = "reference_version",
    vort_speed_column: str = "vort_mib_s",
    reference_speed_column: str = "reference_mib_s",
    vort_bytes_column: str | None = None,
    reference_bytes_column: str | None = None,
) -> list[Metric]:
    metrics: list[Metric] = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        case = row["case"]
        profile_name = profile(row)
        identity = (profile_name, case)
        if identity in seen:
            raise ReportError(f"{source}: duplicate row {identity}")
        seen.add(identity)
        input_bytes = integer(row, "input_bytes", source)
        version = version_text(row.get(version_column, "unreported")) if version_column else "unreported"
        vort_bytes = integer(row, vort_bytes_column, source) if vort_bytes_column else None
        ref_bytes = integer(row, reference_bytes_column, source) if reference_bytes_column else None
        input_sha256 = row.get("input_sha256")
        if input_sha256 is not None and (len(input_sha256) != 64 or any(character not in "0123456789abcdef" for character in input_sha256)):
            raise ReportError(f"{source}: invalid input_sha256 for {case}")
        metrics.append(speed_metric(
            codec, profile_name, case, number(row, vort_speed_column, source),
            number(row, reference_speed_column, source), reference, version,
            input_bytes, source, operation, vort_bytes, ref_bytes, input_sha256,
        ))
        if operation == "encode" and vort_bytes is not None and ref_bytes is not None:
            metrics.append(size_metric(
                codec, profile_name, case, vort_bytes, ref_bytes, reference, version,
                input_bytes, source, input_sha256,
            ))
    return metrics


def brotli_encode_metrics(rows: list[dict[str, str]], source: str) -> list[Metric]:
    required = {
        "case", "quality", "input_bytes", "reference_version",
        "vort_bytes", "lazy_bytes", "ratio_bytes", "reference_bytes",
        "vort_mib_s", "lazy_mib_s", "ratio_mib_s", "reference_mib_s",
    }
    if any(required - set(row) for row in rows):
        raise ReportError(f"{source}: invalid Brotli encode schema")
    metrics: list[Metric] = []
    seen: set[tuple[str, str]] = set()
    modes = (("fast", "vort_bytes", "vort_mib_s"), ("balanced", "lazy_bytes", "lazy_mib_s"), ("ratio", "ratio_bytes", "ratio_mib_s"))
    for row in rows:
        case = row["case"]
        quality = integer(row, "quality", source)
        input_bytes = integer(row, "input_bytes", source)
        ref_bytes = integer(row, "reference_bytes", source)
        ref_speed = number(row, "reference_mib_s", source)
        version = version_text(row["reference_version"])
        for mode, bytes_column, speed_column in modes:
            profile = f"q{quality}-{mode}"
            identity = (profile, case)
            if identity in seen:
                raise ReportError(f"{source}: duplicate row {identity}")
            seen.add(identity)
            vort_bytes = integer(row, bytes_column, source)
            metrics.append(speed_metric(
                "brotli", profile, case, number(row, speed_column, source),
                ref_speed, "libbrotli", version, input_bytes, source, "encode",
                vort_bytes, ref_bytes,
            ))
            metrics.append(size_metric(
                "brotli", profile, case, vort_bytes, ref_bytes, "libbrotli",
                version, input_bytes, source,
            ))
    return metrics


def standard_corpus_metrics(rows: list[dict[str, str]], source: str) -> list[Metric]:
    required = {
        "corpus", "input_bytes",
        "vort_zlib_fastest_bytes", "vort_ms", "vort_decode_ms",
        "vort_zlib_default_bytes", "vort_default_ms", "vort_default_decode_ms",
        "vort_zlib_best_bytes", "vort_best_ms", "vort_best_decode_ms",
        "gzip_bytes", "gzip_ms", "gzip_decode_ms",
        "zlib_ng_gzip_bytes", "zlib_ng_ms", "zlib_ng_decode_ms",
        "zlib_rs_zlib_bytes", "zlib_rs_ms", "zlib_rs_decode_ms",
        "zstd_bytes", "zstd_ms", "zstd_decode_ms",
    }
    if any(required - set(row) for row in rows):
        raise ReportError(f"{source}: invalid standard-corpus schema")
    metrics: list[Metric] = []
    seen: set[str] = set()
    for row in rows:
        case = row["corpus"]
        if case in seen:
            raise ReportError(f"{source}: duplicate corpus row {case!r}")
        seen.add(case)
        input_bytes = integer(row, "input_bytes", source)
        references = (
            ("gzip", "gzip", "gzip_bytes", "gzip_ms", "gzip_decode_ms"),
            ("zlib-ng", "gzip", "zlib_ng_gzip_bytes", "zlib_ng_ms", "zlib_ng_decode_ms"),
            ("zlib-rs", "zlib", "zlib_rs_zlib_bytes", "zlib_rs_ms", "zlib_rs_decode_ms"),
            ("zstd", "zstd", "zstd_bytes", "zstd_ms", "zstd_decode_ms"),
        )
        for profile, bytes_column, encode_column, decode_column in (
            ("fastest", "vort_zlib_fastest_bytes", "vort_ms", "vort_decode_ms"),
            ("default", "vort_zlib_default_bytes", "vort_default_ms", "vort_default_decode_ms"),
            ("best", "vort_zlib_best_bytes", "vort_best_ms", "vort_best_decode_ms"),
        ):
            vort_bytes = integer(row, bytes_column, source)
            vort_encode = 1000.0 * input_bytes / (1024.0 * 1024.0 * number(row, encode_column, source))
            vort_decode = 1000.0 * input_bytes / (1024.0 * 1024.0 * number(row, decode_column, source))
            for reference, wire_format, reference_bytes_column, reference_encode_column, reference_decode_column in references:
                comparison_profile = f"zlib-{profile}-vs-{reference}-{wire_format}"
                reference_encode_ms = optional_nonnegative(row, reference_encode_column, source)
                reference_decode_ms = optional_nonnegative(row, reference_decode_column, source)
                reference_bytes = nonnegative_integer(row, reference_bytes_column, source)
                if reference_encode_ms > 0.0:
                    reference_encode = 1000.0 * input_bytes / (
                        1024.0 * 1024.0 * reference_encode_ms
                    )
                    metrics.append(speed_metric(
                        "deflate-family", comparison_profile, case, vort_encode, reference_encode,
                        reference, "unreported", input_bytes, source, "encode",
                        vort_bytes, reference_bytes or None,
                    ))
                if reference_decode_ms > 0.0:
                    reference_decode = 1000.0 * input_bytes / (
                        1024.0 * 1024.0 * reference_decode_ms
                    )
                    metrics.append(speed_metric(
                        "deflate-family", comparison_profile, case, vort_decode, reference_decode,
                        reference, "unreported", input_bytes, source, "decode",
                    ))
                if reference_bytes > 0:
                    metrics.append(size_metric(
                        "deflate-family", comparison_profile, case, vort_bytes,
                        reference_bytes, reference, "unreported", input_bytes, source,
                    ))
    return metrics


def geomean(values: list[float]) -> float:
    if not values or any(value <= 0.0 or not math.isfinite(value) for value in values):
        raise ReportError("geometric mean requires finite positive values")
    return math.exp(sum(math.log(value) for value in values) / len(values))


def ratio_status(metric: str, ratio: float) -> str:
    if metric == "throughput":
        if ratio >= 1.0:
            return "ahead"
        if ratio >= 0.9:
            return "near"
        return "behind"
    if ratio <= 1.0:
        return "ahead"
    if ratio <= 1.05:
        return "near"
    return "behind"


def metric_status(metric: Metric) -> str:
    return ratio_status(metric.metric, metric.vort_over_reference)


def priority_eligible(codec: str, operation: str, profile: str) -> bool:
    # These Deflate profiles choose a potentially different implementation for
    # every case. They describe Pareto-envelope endpoints rather than a stable
    # production configuration, so keep them visible but out of action ranking.
    return not (
        codec == "deflate"
        and operation == "encode"
        and profile in {
            "raw-best-size",
            "raw-best-speed",
            "zlib-best-size",
            "zlib-best-speed",
        }
    )


def summarize(metrics: list[Metric]) -> list[dict[str, object]]:
    groups: dict[tuple[str, str, str], list[Metric]] = defaultdict(list)
    for metric in metrics:
        groups[(metric.codec, metric.operation, metric.profile)].append(metric)
    summaries: list[dict[str, object]] = []
    for (codec, operation, profile), items in sorted(groups.items()):
        speed_items = [item for item in items if item.metric == "throughput"]
        size_items = [item for item in items if item.metric == "compressed_size"]
        speed_geomean = geomean([item.vort_over_reference for item in speed_items]) if speed_items else None
        size_geomean = geomean([item.vort_over_reference for item in size_items]) if size_items else None
        weakest_speed = min(speed_items, key=lambda item: item.vort_over_reference) if speed_items else None
        weakest_size = max(size_items, key=lambda item: item.vort_over_reference) if size_items else None
        references = sorted({item.reference for item in items})
        versions = sorted({item.reference_version for item in items})
        summaries.append({
            "codec": codec,
            "operation": operation,
            "profile": profile,
            "reference": "/".join(references),
            "reference_version": "/".join(versions),
            "case_count": len({item.case for item in items}),
            "priority_eligible": priority_eligible(codec, operation, profile),
            "speed_geomean_x": speed_geomean,
            "speed_status": None if speed_geomean is None else ratio_status("throughput", speed_geomean),
            "weakest_speed_case": None if weakest_speed is None else weakest_speed.case,
            "weakest_speed_x": None if weakest_speed is None else weakest_speed.vort_over_reference,
            "size_geomean_x": size_geomean,
            "size_status": None if size_geomean is None else ratio_status("compressed_size", size_geomean),
            "weakest_size_case": None if weakest_size is None else weakest_size.case,
            "weakest_size_x": None if weakest_size is None else weakest_size.vort_over_reference,
        })
    return summaries


def resolve_path(output_dir: Path, override: str | None, candidates: tuple[str, ...]) -> Path | None:
    if override is not None:
        return Path(override)
    return next((output_dir / name for name in candidates if (output_dir / name).is_file()), None)


def input_evidence(path: Path) -> dict[str, object]:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
        stat = path.stat()
    except OSError as error:
        raise ReportError(f"cannot fingerprint {path}: {error}") from error
    return {
        "sha256": digest.hexdigest(),
        "size_bytes": stat.st_size,
        "modified_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
    }


def benchmark_provenance(rows: list[dict[str, str]], source: str) -> dict[str, str] | None:
    fields = set(rows[0])
    present = fields.intersection(PROVENANCE_COLUMNS)
    if not present:
        return None
    missing = set(PROVENANCE_COLUMNS) - fields
    if missing:
        raise ReportError(f"{source}: incomplete benchmark provenance columns: {sorted(missing)}")
    values = {tuple(row[column] for column in PROVENANCE_COLUMNS) for row in rows}
    if len(values) != 1:
        raise ReportError(f"{source}: inconsistent benchmark provenance across rows")
    value = next(iter(values))
    if any(not item for item in value):
        raise ReportError(f"{source}: empty benchmark provenance value")
    provenance = dict(zip(PROVENANCE_COLUMNS, value, strict=True))
    if provenance["provenance_version"] != "1":
        raise ReportError(f"{source}: unsupported benchmark provenance version")
    if provenance["optimize"] != "ReleaseFast":
        raise ReportError(f"{source}: benchmark provenance is not ReleaseFast")
    try:
        affinity_cpu_count = int(provenance["affinity_cpu_count"])
    except ValueError as error:
        raise ReportError(f"{source}: invalid affinity_cpu_count") from error
    if affinity_cpu_count < 0:
        raise ReportError(f"{source}: invalid affinity_cpu_count")
    if provenance["cpu_affinity"] == "unavailable":
        if affinity_cpu_count != 0:
            raise ReportError(f"{source}: invalid affinity_cpu_count")
    elif affinity_count(provenance["cpu_affinity"], source) != affinity_cpu_count:
        raise ReportError(f"{source}: affinity_cpu_count does not match cpu_affinity")
    try:
        benchmark_threads = int(provenance["benchmark_threads"])
    except ValueError as error:
        raise ReportError(f"{source}: invalid benchmark_threads") from error
    if benchmark_threads <= 0:
        raise ReportError(f"{source}: invalid benchmark_threads")
    executable_sha256 = provenance["executable_sha256"]
    if len(executable_sha256) != 64 or any(character not in "0123456789abcdef" for character in executable_sha256):
        raise ReportError(f"{source}: invalid executable_sha256")
    if any(character in provenance["command"] for character in ",\r\n"):
        raise ReportError(f"{source}: command is not CSV-safe")
    if "input_sha256" not in fields:
        raise ReportError(f"{source}: benchmark provenance requires input_sha256")
    for row in rows:
        input_sha256 = row["input_sha256"]
        if len(input_sha256) != 64 or any(character not in "0123456789abcdef" for character in input_sha256):
            raise ReportError(f"{source}: invalid input_sha256")
    return provenance


def affinity_count(value: str, source: str) -> int:
    count = 0
    previous_end = -1
    try:
        for item in value.split(";"):
            parts = item.split("-")
            if len(parts) == 1:
                start = end = int(parts[0])
            elif len(parts) == 2:
                start, end = map(int, parts)
            else:
                raise ValueError
            if start < 0 or end < start or start <= previous_end:
                raise ValueError
            count += end - start + 1
            previous_end = end
    except ValueError as error:
        raise ReportError(f"{source}: invalid cpu_affinity") from error
    return count


def load_metrics(args: argparse.Namespace) -> tuple[list[Metric], list[dict[str, object]]]:
    paths = {
        name: resolve_path(args.input_dir, getattr(args, name), candidates)
        for name, candidates in DEFAULT_FILES.items()
    }
    metrics: list[Metric] = []
    inputs: list[dict[str, object]] = []

    def consume(name: str, loader: Callable[[list[dict[str, str]], str], list[Metric]], required: set[str]) -> None:
        path = paths[name]
        if path is None or not path.is_file():
            inputs.append({
                "name": name,
                "path": None if path is None else str(path),
                "status": "missing",
                "rows": 0,
                "metrics": 0,
                "sha256": None,
                "size_bytes": None,
                "modified_utc": None,
            })
            return
        rows = read_csv(path, required, name)
        provenance = benchmark_provenance(rows, name)
        loaded = loader(rows, name)
        metrics.extend(loaded)
        inputs.append({
            "name": name,
            "path": str(path),
            "status": "loaded" if loaded else "no-comparable-rows",
            "rows": len(rows),
            "metrics": len(loaded),
            "benchmark_provenance": provenance,
        } | input_evidence(path))

    consume(
        "deflate_encode", deflate_encode_metrics,
        {"engine", "format", "case", "input_bytes", "frame_bytes", "throughput_mib_s"},
    )
    consume(
        "deflate_decode", deflate_decode_metrics,
        {"engine", "format", "case", "input_bytes", "throughput_mib_s"},
    )
    consume(
        "deflate_incremental", deflate_incremental_metrics,
        {"case", "mode", "input_bytes", "output_bytes", "throughput_mib_s"},
    )
    consume(
        "zstd_encode",
        lambda rows, source: paired_metrics(
            rows, source, "zstd", "encode", lambda row: f"level-{integer(row, 'level', source)}",
            "libzstd", vort_bytes_column="vort_bytes", reference_bytes_column="reference_bytes",
        ),
        {"case", "level", "input_bytes", "reference_version", "vort_bytes", "reference_bytes", "vort_mib_s", "reference_mib_s"},
    )
    consume(
        "zstd_decode",
        lambda rows, source: paired_metrics(rows, source, "zstd", "decode", lambda row: "caller-buffer", "libzstd"),
        {"case", "input_bytes", "reference_version", "vort_mib_s", "reference_mib_s"},
    )
    consume(
        "lz4",
        lambda rows, source: paired_metrics(
            rows, source, "lz4", "decode", lambda row: "block", "liblz4",
            vort_bytes_column="vort_encoded_bytes", reference_bytes_column="encoded_bytes",
        ),
        {"case", "input_bytes", "reference_version", "encoded_bytes", "vort_encoded_bytes", "vort_mib_s", "reference_mib_s"},
    )
    # LZ4's benchmark times decode but also emits both encoder sizes. Add size
    # as a separate encode metric while keeping its speed row labelled decode.
    if paths["lz4"] is not None and paths["lz4"].is_file():
        rows = read_csv(paths["lz4"], {"case", "input_bytes", "reference_version", "encoded_bytes", "vort_encoded_bytes"}, "lz4")
        size_count = 0
        for row in rows:
            metrics.append(size_metric(
                "lz4", "block", row["case"], integer(row, "vort_encoded_bytes", "lz4"),
                integer(row, "encoded_bytes", "lz4"), "liblz4", version_text(row["reference_version"]),
                integer(row, "input_bytes", "lz4"), "lz4",
            ))
            size_count += 1
        next(item for item in inputs if item["name"] == "lz4")["metrics"] += size_count
    consume(
        "snappy",
        lambda rows, source: paired_metrics(rows, source, "snappy", "decode", lambda row: "block", "libsnappy", version_column=None),
        {"case", "input_bytes", "encoded_bytes", "vort_mib_s", "reference_mib_s"},
    )
    consume(
        "brotli_encode", brotli_encode_metrics,
        {"case", "quality", "input_bytes", "reference_version", "vort_bytes", "lazy_bytes", "ratio_bytes", "reference_bytes", "vort_mib_s", "lazy_mib_s", "ratio_mib_s", "reference_mib_s"},
    )
    consume(
        "brotli_decode",
        lambda rows, source: paired_metrics(rows, source, "brotli", "decode", lambda row: "caller-buffer", "libbrotli"),
        {"case", "input_bytes", "reference_version", "vort_mib_s", "reference_mib_s"},
    )
    consume(
        "standard_corpus", standard_corpus_metrics,
        {"corpus", "input_bytes", "vort_zlib_fastest_bytes", "vort_ms", "vort_decode_ms", "gzip_bytes", "gzip_ms", "gzip_decode_ms"},
    )
    return metrics, inputs


def git_metadata() -> dict[str, object]:
    def git(*arguments: str) -> str:
        try:
            return subprocess.run(
                ["git", *arguments], cwd=ROOT, check=True, text=True,
                capture_output=True,
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            return "unknown"

    dirty = git("status", "--short")
    return {
        "commit": git("rev-parse", "--short=12", "HEAD"),
        "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "dirty": dirty not in {"", "unknown"},
    }


def environment_metadata() -> dict[str, str]:
    return {
        "platform": platform.platform(),
        "machine": platform.machine() or "unknown",
        "processor": platform.processor() or "unreported",
        "python": platform.python_version(),
    }


def fmt_ratio(value: object, suffix: str = "x") -> str:
    return "—" if value is None else f"{float(value):.3f}{suffix}"


def fmt_weakest(case: object, ratio: object) -> str:
    if case is None or ratio is None:
        return "—"
    return f"{case} {float(ratio):.3f}x"


def group_status(summary: dict[str, object]) -> str:
    speed = summary["speed_geomean_x"]
    size = summary["size_geomean_x"]
    speed_ahead = speed is None or float(speed) >= 1.0
    size_ahead = size is None or float(size) <= 1.0
    speed_floor_ahead = summary["weakest_speed_x"] is None or float(summary["weakest_speed_x"]) >= 1.0
    size_ceiling_ahead = summary["weakest_size_x"] is None or float(summary["weakest_size_x"]) <= 1.0
    if speed_ahead and size_ahead and speed_floor_ahead and size_ceiling_ahead:
        return "ahead"
    speed_near = speed is None or float(speed) >= 0.9
    size_near = size is None or float(size) <= 1.05
    speed_floor_near = summary["weakest_speed_x"] is None or float(summary["weakest_speed_x"]) >= 0.9
    size_ceiling_near = summary["weakest_size_x"] is None or float(summary["weakest_size_x"]) <= 1.05
    if speed_near and size_near and speed_floor_near and size_ceiling_near:
        return "near"
    if (speed is not None and float(speed) >= 1.0) or (size is not None and float(size) <= 1.0):
        return "mixed"
    return "behind"


def priority_score(summary: dict[str, object]) -> float:
    speed = summary["speed_geomean_x"]
    size = summary["size_geomean_x"]
    weakest_speed = summary["weakest_speed_x"]
    weakest_size = summary["weakest_size_x"]
    speed_gap = 1.0 if speed is None else 1.0 / float(speed)
    size_gap = 1.0 if size is None else float(size)
    weakest_speed_gap = 1.0 if weakest_speed is None else 1.0 / float(weakest_speed)
    weakest_size_gap = 1.0 if weakest_size is None else float(weakest_size)
    return max(speed_gap, size_gap, weakest_speed_gap, weakest_size_gap)


def report_payload(metrics: list[Metric], inputs: list[dict[str, object]]) -> dict[str, object]:
    summaries = summarize(metrics)
    for summary in summaries:
        summary["status"] = group_status(summary)
        summary["priority_score"] = priority_score(summary)
    ranked_metrics = [
        metric for metric in metrics
        if priority_eligible(metric.codec, metric.operation, metric.profile)
    ]
    throughput = [metric for metric in ranked_metrics if metric.metric == "throughput"]
    sizes = [metric for metric in ranked_metrics if metric.metric == "compressed_size"]
    weakest_speed = min(throughput, key=lambda metric: metric.vort_over_reference) if throughput else None
    weakest_size = max(sizes, key=lambda metric: metric.vort_over_reference) if sizes else None
    git = git_metadata()
    real_corpus = any(metric.source == "standard_corpus" for metric in metrics)
    loaded_inputs = [item for item in inputs if item["status"] == "loaded"]
    provenance_inputs = [item for item in loaded_inputs if item.get("benchmark_provenance") is not None]
    return {
        "schema": "vort.competitor_gap_report",
        "schema_version": 2,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "git": git,
        "report_environment": environment_metadata(),
        "inputs": inputs,
        "coverage": {
            "loaded_sources": sum(item["status"] == "loaded" for item in inputs),
            "missing_sources": sum(item["status"] != "loaded" for item in inputs),
            "empty_sources": sum(item["status"] == "no-comparable-rows" for item in inputs),
            "metric_count": len(metrics),
            "group_count": len(summaries),
            "real_corpus": real_corpus,
            "memory_comparison": False,
            "benchmark_environment_recorded": bool(loaded_inputs) and len(provenance_inputs) == len(loaded_inputs),
            "benchmark_environment_source_count": len(provenance_inputs),
            "benchmark_environment_total_sources": len(loaded_inputs),
        },
        "summaries": summaries,
        "weakest": {
            "throughput": None if weakest_speed is None else asdict(weakest_speed),
            "compressed_size": None if weakest_size is None else asdict(weakest_size),
        },
        "metrics": [asdict(metric) | {"status": metric_status(metric)} for metric in sorted(metrics, key=lambda item: (item.codec, item.operation, item.profile, item.case, item.metric))],
    }


def markdown(payload: dict[str, object]) -> str:
    lines = [
        "# Vort competitor gap report",
        "",
        f"- Generated (UTC): `{payload['generated_utc']}`",
        f"- Git: `{payload['git']['commit']}` on `{payload['git']['branch']}`; dirty=`{str(payload['git']['dirty']).lower()}`",
        f"- Report environment: `{payload['report_environment']['platform']}`; machine=`{payload['report_environment']['machine']}`; Python=`{payload['report_environment']['python']}`",
        f"- Evidence: `{payload['coverage']['loaded_sources']}` sources, `{payload['coverage']['metric_count']}` normalized metrics, `{payload['coverage']['group_count']}` comparable groups",
        f"- Scope: locked benchmark artifacts; real-corpus=`{str(payload['coverage']['real_corpus']).lower()}`; cross-library peak-memory=`{str(payload['coverage']['memory_comparison']).lower()}`",
        f"- Benchmark provenance: `{payload['coverage']['benchmark_environment_source_count']}/{payload['coverage']['benchmark_environment_total_sources']}` loaded sources record build target and runtime CPU affinity; complete=`{str(payload['coverage']['benchmark_environment_recorded']).lower()}`",
        "- Interpretation: throughput ratios above 1.0 are faster; compressed-size ratios below 1.0 are smaller",
        "- Status requires both the geometric mean and weakest case to meet the threshold; mixed means the aggregate and at least one dimension/case disagree",
        "- Gap priority is the largest aggregate or weakest-case shortfall within one codec/operation/profile group; no cross-format total score is computed",
        "- Deflate `best-speed`/`best-size` rows are per-case Pareto envelopes, not one stable configuration; they are excluded from action ranking and weakest-case callouts",
        "",
        "## Summary",
        "",
        "| codec | operation | profile | reference | cases | speed geomean | weakest speed | size geomean | weakest size | status |",
        "| --- | --- | --- | --- | ---: | ---: | --- | ---: | --- | --- |",
    ]
    for row in payload["summaries"]:
        reference = f"{row['reference']} {row['reference_version']}"
        lines.append(
            f"| {row['codec']} | {row['operation']} | {row['profile']} | {reference} | {row['case_count']} | "
            f"{fmt_ratio(row['speed_geomean_x'])} | {fmt_weakest(row['weakest_speed_case'], row['weakest_speed_x'])} | "
            f"{fmt_ratio(row['size_geomean_x'])} | {fmt_weakest(row['weakest_size_case'], row['weakest_size_x'])} | {row['status']} |"
        )

    ranked = sorted(
        (row for row in payload["summaries"] if row["priority_eligible"]),
        key=lambda row: float(row["priority_score"]),
        reverse=True,
    )
    lines.extend([
        "",
        "## Highest-priority gaps",
        "",
        "| rank | codec | operation | profile | gap factor | status |",
        "| ---: | --- | --- | --- | ---: | --- |",
    ])
    for index, row in enumerate(ranked[:10], 1):
        lines.append(
            f"| {index} | {row['codec']} | {row['operation']} | {row['profile']} | {float(row['priority_score']):.3f}x | {row['status']} |"
        )

    lines.extend([
        "",
        "## Current weakest cases",
        "",
    ])
    weakest = payload["weakest"]
    speed = weakest["throughput"]
    size = weakest["compressed_size"]
    if speed is not None:
        lines.append(
            f"- Throughput: `{speed['codec']}/{speed['profile']}/{speed['case']}` at `{speed['vort_over_reference']:.3f}x` versus `{speed['reference']} {speed['reference_version']}`."
        )
    if size is not None:
        lines.append(
            f"- Compressed size: `{size['codec']}/{size['profile']}/{size['case']}` at `{size['vort_over_reference']:.3f}x` reference bytes."
        )

    lines.extend([
        "",
        "## Evidence coverage",
        "",
        "| input | status | rows | metrics | benchmark provenance | modified UTC | SHA-256 | path |",
        "| --- | --- | ---: | ---: | --- | --- | --- | --- |",
    ])
    for item in payload["inputs"]:
        sha256 = "—" if item["sha256"] is None else str(item["sha256"])[:12]
        provenance = item.get("benchmark_provenance")
        provenance_text = "—" if provenance is None else (
            f"{provenance['optimize']}; zig {provenance['zig_version']}; "
            f"{provenance['target_arch']}-{provenance['target_os']}-{provenance['target_abi']}; "
            f"target CPU {provenance['target_cpu']}; host CPU {provenance['cpu_model']}; "
            f"affinity {provenance['cpu_affinity']} ({provenance['affinity_cpu_count']} CPUs); "
            f"benchmark threads {provenance['benchmark_threads']}; codec threads {provenance['codec_thread_policy']}; "
            f"exe {provenance['executable_sha256'][:12]}; "
            f"command `{provenance['command']}`"
        )
        lines.append(
            f"| {item['name']} | {item['status']} | {item['rows']} | {item['metrics']} | {provenance_text} | "
            f"{item['modified_utc'] or '—'} | `{sha256}` | `{item['path'] or '—'}` |"
        )
    if payload["coverage"]["missing_sources"]:
        lines.extend([
            "",
            "Missing inputs are excluded from aggregates. Core inputs are required by `--strict`; optional incremental/real-corpus inputs remain visibly missing until their producers are run.",
        ])
    if payload["coverage"]["empty_sources"]:
        lines.extend([
            "",
            "Inputs with no comparable rows are excluded from aggregates. Strict mode rejects this condition for core inputs.",
        ])

    lines.extend([
        "",
        "## Normalized rows",
        "",
        "| codec | operation | profile | case | input SHA-256 | metric | Vort | reference | Vort/reference | status | source |",
        "| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | --- | --- |",
    ])
    for metric in payload["metrics"]:
        input_hash = "—" if metric["input_sha256"] is None else f"`{metric['input_sha256'][:12]}`"
        lines.append(
            f"| {metric['codec']} | {metric['operation']} | {metric['profile']} | {metric['case']} | "
            f"{input_hash} | {metric['metric']} | "
            f"{metric['vort_value']:.4f} | {metric['reference_value']:.4f} | {metric['vort_over_reference']:.3f}x | "
            f"{metric['status']} | {metric['source']} |"
        )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path("zig-out"))
    for name in DEFAULT_FILES:
        parser.add_argument(f"--{name.replace('_', '-')}", dest=name)
    parser.add_argument("--markdown", type=Path, default=Path("zig-out/vort-competitor-gap-report.md"))
    parser.add_argument("--json", type=Path, default=Path("zig-out/vort-competitor-gap-report.json"))
    parser.add_argument("--strict", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        metrics, inputs = load_metrics(args)
        missing = [item["name"] for item in inputs if item["status"] == "missing"]
        empty = [item["name"] for item in inputs if item["status"] == "no-comparable-rows"]
        missing_required = [name for name in missing if name not in OPTIONAL_FILES]
        empty_required = [name for name in empty if name not in OPTIONAL_FILES]
        explicit_missing = [
            name for name in missing if getattr(args, name) is not None
        ]
        explicit_empty = [
            name for name in empty if getattr(args, name) is not None
        ]
        if explicit_missing:
            raise ReportError(
                f"explicit benchmark inputs do not exist: {', '.join(sorted(explicit_missing))}"
            )
        if explicit_empty:
            raise ReportError(
                f"explicit benchmark inputs have no comparable rows: {', '.join(sorted(explicit_empty))}"
            )
        if args.strict and missing_required:
            required = sorted(set(missing_required))
            raise ReportError(f"missing required benchmark inputs: {', '.join(required)}")
        if args.strict and empty_required:
            raise ReportError(
                f"required benchmark inputs have no comparable rows: {', '.join(sorted(empty_required))}"
            )
        if not metrics:
            raise ReportError("no comparable benchmark metrics were found")
        payload = report_payload(metrics, inputs)
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(markdown(payload), encoding="utf-8")
        args.json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except (ReportError, OSError) as error:
        print(f"competitor gap report failed: {error}", file=sys.stderr)
        return 1
    print(
        f"competitor_gap_report=ok metrics={len(metrics)} groups={len(payload['summaries'])} "
        f"missing={payload['coverage']['missing_sources']} markdown={args.markdown} json={args.json}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
