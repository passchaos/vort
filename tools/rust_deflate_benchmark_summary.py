#!/usr/bin/env python3
"""Summarize Vort vs fdeflate/miniz_oxide benchmark CSV artifacts."""

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def by_case(rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["case"]].append(row)
    return grouped


def fnum(row: dict[str, str], key: str) -> float:
    return float(row[key])


def inum(row: dict[str, str], key: str) -> int:
    return int(row[key])


def size_bytes(row: dict[str, str]) -> int:
    return int(row.get("frame_bytes", row.get("zlib_bytes", "0")))


def parse_histogram(value: str) -> list[int]:
    if not value:
        return []
    return [int(part) for part in value.split(";")]


def top_histogram_deltas(row: dict[str, str], key: str, best_key: str, symbol_base: int, limit: int = 3) -> str:
    values = parse_histogram(row.get(key, ""))
    best_values = parse_histogram(row.get(best_key, ""))
    if not values or not best_values or len(values) != len(best_values):
        return ""
    deltas = sorted(
        (
            (best_values[i] - values[i], symbol_base + i)
            for i in range(len(values))
            if best_values[i] != values[i]
        ),
        key=lambda item: abs(item[0]),
        reverse=True,
    )
    return ", ".join(f"{symbol}:{delta:+d}" for delta, symbol in deltas[:limit])


def row_format(row: dict[str, str]) -> str:
    return row.get("format", "zlib")


def geomean(values: list[float]) -> float:
    positive = [value for value in values if value > 0.0]
    if not positive:
        return 0.0
    return math.exp(sum(math.log(value) for value in positive) / len(positive))


RatioSample = tuple[str, float]


def append_overview_row(lines: list[str], metric: str, samples: list[RatioSample], note: str, lower_is_better: bool = False) -> None:
    if not samples:
        return
    values = [value for _, value in samples]
    worst_case, worst_ratio = (max if lower_is_better else min)(samples, key=lambda item: item[1])
    lines.append(f"| {metric} | {len(samples)} | {geomean(values):.3f} | {worst_case} {worst_ratio:.3f} | {note} |")


def benchmark_overview_lines(decode_rows: list[dict[str, str]], encode_rows: list[dict[str, str]]) -> list[str]:
    zlib_decode_alloc: list[RatioSample] = []
    zlib_decode_exact: list[RatioSample] = []
    zlib_decode_into: list[RatioSample] = []
    raw_decode_alloc: list[RatioSample] = []
    raw_decode_exact: list[RatioSample] = []
    raw_decode_into: list[RatioSample] = []
    for case, items in sorted(by_case(decode_rows).items()):
        zlib_items = [row for row in items if row_format(row) == "zlib"]
        vort_alloc = next((row for row in zlib_items if row["engine"] == "vort"), None)
        vort_exact = next((row for row in zlib_items if row["engine"] == "vort-exact"), None)
        vort_into = next((row for row in zlib_items if row["engine"] == "vort-into"), None)
        rust_rows = [row for row in zlib_items if not row["engine"].startswith("vort")]
        if vort_alloc is not None and vort_into is not None and rust_rows:
            rust = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
            rust_speed = fnum(rust, "throughput_mib_s")
            if rust_speed > 0:
                zlib_decode_alloc.append((case, fnum(vort_alloc, "throughput_mib_s") / rust_speed))
                if vort_exact is not None:
                    zlib_decode_exact.append((case, fnum(vort_exact, "throughput_mib_s") / rust_speed))
                zlib_decode_into.append((case, fnum(vort_into, "throughput_mib_s") / rust_speed))

        raw_items = [row for row in items if row_format(row) == "raw"]
        vort_raw = next((row for row in raw_items if row["engine"] == "vort-raw"), None)
        vort_raw_exact = next((row for row in raw_items if row["engine"] == "vort-raw-exact"), None)
        vort_raw_into = next((row for row in raw_items if row["engine"] == "vort-raw-into"), None)
        miniz_raw = next((row for row in raw_items if row["engine"] == "miniz_oxide-raw"), None)
        if vort_raw is not None and vort_raw_into is not None and miniz_raw is not None:
            rust_speed = fnum(miniz_raw, "throughput_mib_s")
            if rust_speed > 0:
                raw_decode_alloc.append((case, fnum(vort_raw, "throughput_mib_s") / rust_speed))
                if vort_raw_exact is not None:
                    raw_decode_exact.append((case, fnum(vort_raw_exact, "throughput_mib_s") / rust_speed))
                raw_decode_into.append((case, fnum(vort_raw_into, "throughput_mib_s") / rust_speed))

    zlib_encode_speed: list[RatioSample] = []
    zlib_default_size: list[RatioSample] = []
    zlib_best_size: list[RatioSample] = []
    raw_encode_speed: list[RatioSample] = []
    raw_default_size: list[RatioSample] = []
    raw_best_size: list[RatioSample] = []
    for case, items in sorted(by_case(encode_rows).items()):
        zlib_items = [row for row in items if row_format(row) == "zlib"]
        vort_rows = [row for row in zlib_items if row["engine"].startswith("vort")]
        rust_rows = [row for row in zlib_items if not row["engine"].startswith("vort")]
        if vort_rows and rust_rows:
            best_vort_speed = max(vort_rows, key=lambda row: fnum(row, "throughput_mib_s"))
            best_rust_speed = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
            rust_speed = fnum(best_rust_speed, "throughput_mib_s")
            if rust_speed > 0:
                zlib_encode_speed.append((case, fnum(best_vort_speed, "throughput_mib_s") / rust_speed))
            best_rust_size = min(rust_rows, key=size_bytes)
            rust_size = max(size_bytes(best_rust_size), 1)
            vort_default = next((row for row in vort_rows if row["engine"] == "vort-default"), None)
            if vort_default is not None:
                zlib_default_size.append((case, size_bytes(vort_default) / rust_size))
            best_vort_size = min(vort_rows, key=size_bytes)
            zlib_best_size.append((case, size_bytes(best_vort_size) / rust_size))

        raw_items = [row for row in items if row_format(row) == "raw"]
        vort_rows = [row for row in raw_items if row["engine"].startswith("vort")]
        rust_rows = [row for row in raw_items if not row["engine"].startswith("vort")]
        if vort_rows and rust_rows:
            best_vort_speed = max(vort_rows, key=lambda row: fnum(row, "throughput_mib_s"))
            best_rust_speed = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
            rust_speed = fnum(best_rust_speed, "throughput_mib_s")
            if rust_speed > 0:
                raw_encode_speed.append((case, fnum(best_vort_speed, "throughput_mib_s") / rust_speed))
            best_rust_size = min(rust_rows, key=size_bytes)
            rust_size = max(size_bytes(best_rust_size), 1)
            vort_default = next((row for row in vort_rows if row["engine"] == "vort-raw-default"), None)
            if vort_default is not None:
                raw_default_size.append((case, size_bytes(vort_default) / rust_size))
            best_vort_size = min(vort_rows, key=size_bytes)
            raw_best_size.append((case, size_bytes(best_vort_size) / rust_size))

    lines = [
        "## Benchmark gap overview",
        "",
        "Geomean ratios summarize the detailed per-case tables below. Throughput ratios above 1.0 are faster than the Rust baseline; size ratios below 1.0 are smaller.",
        "",
        "| metric | cases | geomean ratio | weakest case | note |",
        "| --- | ---: | ---: | --- | --- |",
    ]
    append_overview_row(lines, "zlib decode alloc / best Rust", zlib_decode_alloc, "Vort growable allocator-returning zlib decode vs best fdeflate/miniz_oxide zlib row")
    append_overview_row(lines, "zlib decode exact / best Rust", zlib_decode_exact, "Vort exact-size allocator-returning zlib decode vs best fdeflate/miniz_oxide zlib row")
    append_overview_row(lines, "zlib decode into / best Rust", zlib_decode_into, "Vort caller-buffer zlib decode vs best fdeflate/miniz_oxide zlib row")
    append_overview_row(lines, "raw decode alloc / miniz_oxide", raw_decode_alloc, "Vort growable allocator-returning raw decode vs miniz_oxide raw inflate")
    append_overview_row(lines, "raw decode exact / miniz_oxide", raw_decode_exact, "Vort exact-size allocator-returning raw decode vs miniz_oxide raw inflate")
    append_overview_row(lines, "raw decode into / miniz_oxide", raw_decode_into, "Vort caller-buffer raw decode vs miniz_oxide raw inflate")
    append_overview_row(lines, "zlib encode best-speed / best Rust", zlib_encode_speed, "Fastest Vort zlib row per case vs fastest fdeflate/miniz_oxide zlib row")
    append_overview_row(lines, "zlib encode default size / best Rust", zlib_default_size, "Vort production default zlib size vs smallest Rust zlib size", lower_is_better=True)
    append_overview_row(lines, "zlib encode best size / best Rust", zlib_best_size, "Smallest Vort zlib row vs smallest Rust zlib row", lower_is_better=True)
    append_overview_row(lines, "raw encode best-speed / best Rust", raw_encode_speed, "Fastest Vort raw row per case vs fastest fdeflate/miniz_oxide raw row")
    append_overview_row(lines, "raw encode default size / best Rust", raw_default_size, "Vort raw default size vs smallest Rust raw size", lower_is_better=True)
    append_overview_row(lines, "raw encode best size / best Rust", raw_best_size, "Smallest Vort raw row vs smallest Rust raw row", lower_is_better=True)
    lines.append("")
    return lines


def decode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode throughput (zlib)",
        "",
        "| case | Vort alloc MiB/s | Vort exact MiB/s | Vort into MiB/s | best Rust MiB/s | alloc / Rust | exact / Rust | into / Rust | best Rust engine |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for case, items in sorted(by_case(rows).items()):
        zlib_items = [row for row in items if row_format(row) == "zlib"]
        vort_alloc = next(row for row in zlib_items if row["engine"] == "vort")
        vort_exact = next((row for row in zlib_items if row["engine"] == "vort-exact"), None)
        vort_into = next(row for row in zlib_items if row["engine"] == "vort-into")
        rust_rows = [row for row in zlib_items if not row["engine"].startswith("vort")]
        rust = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        alloc_speed = fnum(vort_alloc, "throughput_mib_s")
        exact_speed = fnum(vort_exact, "throughput_mib_s") if vort_exact is not None else 0.0
        into_speed = fnum(vort_into, "throughput_mib_s")
        rust_speed = fnum(rust, "throughput_mib_s")
        alloc_ratio = 0.0 if rust_speed == 0 else alloc_speed / rust_speed
        exact_ratio = 0.0 if rust_speed == 0 else exact_speed / rust_speed
        into_ratio = 0.0 if rust_speed == 0 else into_speed / rust_speed
        lines.append(f"| {case} | {alloc_speed:.2f} | {exact_speed:.2f} | {into_speed:.2f} | {rust_speed:.2f} | {alloc_ratio:.3f} | {exact_ratio:.3f} | {into_ratio:.3f} | {rust['engine']} |")
    lines.append("")
    return lines


def raw_decode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode throughput (raw deflate)",
        "",
        "| case | Vort raw alloc MiB/s | Vort raw exact MiB/s | Vort raw into MiB/s | miniz_oxide raw MiB/s | alloc / miniz raw | exact / miniz raw | into / miniz raw |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        raw_items = [row for row in items if row_format(row) == "raw"]
        vort_raw = next((row for row in raw_items if row["engine"] == "vort-raw"), None)
        vort_raw_exact = next((row for row in raw_items if row["engine"] == "vort-raw-exact"), None)
        vort_raw_into = next((row for row in raw_items if row["engine"] == "vort-raw-into"), None)
        miniz_raw = next((row for row in raw_items if row["engine"] == "miniz_oxide-raw"), None)
        if vort_raw is None or vort_raw_into is None or miniz_raw is None:
            continue
        alloc_speed = fnum(vort_raw, "throughput_mib_s")
        exact_speed = fnum(vort_raw_exact, "throughput_mib_s") if vort_raw_exact is not None else 0.0
        into_speed = fnum(vort_raw_into, "throughput_mib_s")
        rust_speed = fnum(miniz_raw, "throughput_mib_s")
        alloc_ratio = 0.0 if rust_speed == 0 else alloc_speed / rust_speed
        exact_ratio = 0.0 if rust_speed == 0 else exact_speed / rust_speed
        into_ratio = 0.0 if rust_speed == 0 else into_speed / rust_speed
        lines.append(f"| {case} | {alloc_speed:.2f} | {exact_speed:.2f} | {into_speed:.2f} | {rust_speed:.2f} | {alloc_ratio:.3f} | {exact_ratio:.3f} | {into_ratio:.3f} |")
    lines.append("")
    return lines


def gzip_decode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Vort gzip decode throughput",
        "",
        "| case | gzip alloc MiB/s | gzip exact MiB/s | gzip into MiB/s | exact / alloc | into / alloc |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        gzip = next((row for row in items if row["engine"] == "vort-gzip"), None)
        gzip_exact = next((row for row in items if row["engine"] == "vort-gzip-exact"), None)
        gzip_into = next((row for row in items if row["engine"] == "vort-gzip-into"), None)
        if gzip is None or gzip_into is None:
            continue
        alloc_speed = fnum(gzip, "throughput_mib_s")
        exact_speed = fnum(gzip_exact, "throughput_mib_s") if gzip_exact is not None else 0.0
        into_speed = fnum(gzip_into, "throughput_mib_s")
        exact_ratio = 0.0 if alloc_speed == 0 else exact_speed / alloc_speed
        into_ratio = 0.0 if alloc_speed == 0 else into_speed / alloc_speed
        lines.append(f"| {case} | {alloc_speed:.2f} | {exact_speed:.2f} | {into_speed:.2f} | {exact_ratio:.3f} | {into_ratio:.3f} |")
    lines.append("")
    return lines


def decode_allocation_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode allocation overhead",
        "",
        "| case | raw alloc/into time | zlib alloc/into time | gzip alloc/into time |",
        "| --- | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        raw_alloc = next((row for row in items if row["engine"] == "vort-raw"), None)
        raw_into = next((row for row in items if row["engine"] == "vort-raw-into"), None)
        zlib_alloc = next((row for row in items if row["engine"] == "vort"), None)
        zlib_into = next((row for row in items if row["engine"] == "vort-into"), None)
        gzip_alloc = next((row for row in items if row["engine"] == "vort-gzip"), None)
        gzip_into = next((row for row in items if row["engine"] == "vort-gzip-into"), None)
        if zlib_alloc is None or zlib_into is None or gzip_alloc is None or gzip_into is None:
            continue
        raw_ratio = "" if raw_alloc is None or raw_into is None else f"{fnum(raw_alloc, 'elapsed_s') / fnum(raw_into, 'elapsed_s'):.3f}"
        zlib_ratio = fnum(zlib_alloc, "elapsed_s") / fnum(zlib_into, "elapsed_s")
        gzip_ratio = fnum(gzip_alloc, "elapsed_s") / fnum(gzip_into, "elapsed_s")
        lines.append(f"| {case} | {raw_ratio} | {zlib_ratio:.3f} | {gzip_ratio:.3f} |")
    lines.append("")
    return lines


def encode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Encode speed and size",
        "",
        "| case | best Vort speed MiB/s | best Rust speed MiB/s | Vort speed / Rust | Vort default / dynamic speed | literal/default speed | literal/default size | split/default speed | adaptive/default speed | split/default size | adaptive/default size | Vort default size / Rust | Vort best preset size / Rust | best Vort size | best Rust size | Vort size / Rust | notes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for case, items in sorted(by_case(rows).items()):
        zlib_items = [row for row in items if row_format(row) == "zlib"]
        vort_rows = [row for row in zlib_items if row["engine"].startswith("vort")]
        rust_rows = [row for row in zlib_items if not row["engine"].startswith("vort")]
        best_vort_speed = max(vort_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_rust_speed = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_vort_size = min(vort_rows, key=size_bytes)
        best_rust_size = min(rust_rows, key=size_bytes)
        speed_ratio = fnum(best_vort_speed, "throughput_mib_s") / fnum(best_rust_speed, "throughput_mib_s")
        size_ratio = size_bytes(best_vort_size) / max(size_bytes(best_rust_size), 1)
        vort_default = next((row for row in vort_rows if row["engine"] == "vort-default"), None)
        vort_best = next((row for row in vort_rows if row["engine"] == "vort-best"), None)
        vort_dynamic = next((row for row in vort_rows if row["engine"] == "vort-dynamic-default"), None)
        vort_dynamic_literal = next((row for row in vort_rows if row["engine"] == "vort-dynamic-literal"), None)
        vort_split = next((row for row in vort_rows if row["engine"] == "vort-split-default"), None)
        vort_adaptive = next((row for row in vort_rows if row["engine"] == "vort-adaptive-default"), None)
        dynamic_overhead = ""
        if vort_default is not None and vort_dynamic is not None and fnum(vort_dynamic, "throughput_mib_s") != 0:
            dynamic_overhead = f"{fnum(vort_default, 'throughput_mib_s') / fnum(vort_dynamic, 'throughput_mib_s'):.3f}"
        literal_speed = literal_size = split_speed = split_size = adaptive_speed = adaptive_size = ""
        default_size_ratio = best_preset_size_ratio = ""
        rust_size = max(size_bytes(best_rust_size), 1)
        if vort_default is not None:
            default_speed = fnum(vort_default, "throughput_mib_s")
            default_size = max(size_bytes(vort_default), 1)
            default_size_ratio = f"{size_bytes(vort_default) / rust_size:.3f}"
            if vort_dynamic_literal is not None:
                literal_speed = "" if default_speed == 0 else f"{fnum(vort_dynamic_literal, 'throughput_mib_s') / default_speed:.3f}"
                literal_size = f"{size_bytes(vort_dynamic_literal) / default_size:.3f}"
            if vort_split is not None:
                split_speed = "" if default_speed == 0 else f"{fnum(vort_split, 'throughput_mib_s') / default_speed:.3f}"
                split_size = f"{size_bytes(vort_split) / default_size:.3f}"
            if vort_adaptive is not None:
                adaptive_speed = "" if default_speed == 0 else f"{fnum(vort_adaptive, 'throughput_mib_s') / default_speed:.3f}"
                adaptive_size = f"{size_bytes(vort_adaptive) / default_size:.3f}"
        if vort_best is not None:
            best_preset_size_ratio = f"{size_bytes(vort_best) / rust_size:.3f}"
        notes = []
        if literal_size and float(literal_size) > 2.0:
            notes.append("literal-only size high")
        if split_size and float(split_size) > 1.25:
            notes.append("split size high")
        if adaptive_size and float(adaptive_size) > 1.05:
            notes.append("adaptive size high")
        lines.append(
            f"| {case} | {best_vort_speed['engine']} {fnum(best_vort_speed, 'throughput_mib_s'):.2f} | "
            f"{best_rust_speed['engine']} {fnum(best_rust_speed, 'throughput_mib_s'):.2f} | {speed_ratio:.3f} | "
            f"{dynamic_overhead} | "
            f"{literal_speed} | {literal_size} | "
            f"{split_speed} | {adaptive_speed} | {split_size} | {adaptive_size} | "
            f"{default_size_ratio} | {best_preset_size_ratio} | "
            f"{best_vort_size['engine']} {size_bytes(best_vort_size)} | "
            f"{best_rust_size['engine']} {size_bytes(best_rust_size)} | {size_ratio:.3f} | "
            f"{'; '.join(notes)} |"
        )
    lines.append("")
    return lines


def raw_encode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Raw deflate encode speed and size",
        "",
        "| case | best Vort raw speed MiB/s | best Rust raw speed MiB/s | Vort raw speed / Rust raw | Vort raw default size / Rust raw | best Vort raw size | best Rust raw size | Vort raw size / Rust raw |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        raw_items = [row for row in items if row_format(row) == "raw"]
        vort_rows = [row for row in raw_items if row["engine"].startswith("vort")]
        rust_rows = [row for row in raw_items if not row["engine"].startswith("vort")]
        if not vort_rows or not rust_rows:
            continue
        best_vort_speed = max(vort_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_rust_speed = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_vort_size = min(vort_rows, key=size_bytes)
        best_rust_size = min(rust_rows, key=size_bytes)
        vort_default = next((row for row in vort_rows if row["engine"] == "vort-raw-default"), None)
        rust_size = max(size_bytes(best_rust_size), 1)
        default_size_ratio = "" if vort_default is None else f"{size_bytes(vort_default) / rust_size:.3f}"
        speed_ratio = fnum(best_vort_speed, "throughput_mib_s") / fnum(best_rust_speed, "throughput_mib_s")
        size_ratio = size_bytes(best_vort_size) / rust_size
        lines.append(
            f"| {case} | {best_vort_speed['engine']} {fnum(best_vort_speed, 'throughput_mib_s'):.2f} | "
            f"{best_rust_speed['engine']} {fnum(best_rust_speed, 'throughput_mib_s'):.2f} | {speed_ratio:.3f} | "
            f"{default_size_ratio} | {best_vort_size['engine']} {size_bytes(best_vort_size)} | "
            f"{best_rust_size['engine']} {size_bytes(best_rust_size)} | {size_ratio:.3f} |"
        )
    lines.append("")
    return lines


def dynamic_plan_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Dynamic plan diagnostics",
        "",
        "| path | tokens | matches | matched bytes | avg match len | avg distance | short matches | len symbol Δ | dist symbol Δ | len extra hist | dist extra hist | fixed/dynamic size | best size/default | best tokens/default | best avg len/default | best avg dist/default | best header/default | best literal/default | best match-symbol/default | best len-extra/default | best dist-extra/default | best extra/default | best len extra hist | best dist extra hist | best short matches | best/dynamic time | stats/dynamic time | code-length ops |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        best_size_ratio = fnum(row, "best_preset_default_size_ratio") if "best_preset_default_size_ratio" in row else 0.0
        best_token_ratio = fnum(row, "best_preset_default_token_ratio") if "best_preset_default_token_ratio" in row else 0.0
        avg_len = fnum(row, "avg_match_len_x100") / 100.0 if "avg_match_len_x100" in row else 0.0
        avg_distance = fnum(row, "avg_match_distance") if "avg_match_distance" in row else 0.0
        short_matches = row.get("short_match_tokens", "")
        length_symbol_delta = top_histogram_deltas(row, "length_symbol_hist", "best_preset_length_symbol_hist", 257)
        distance_symbol_delta = top_histogram_deltas(row, "distance_symbol_hist", "best_preset_distance_symbol_hist", 0)
        length_extra_hist = row.get("length_extra_hist", "")
        distance_extra_hist = row.get("distance_extra_hist", "")
        best_avg_len_ratio = fnum(row, "best_preset_default_avg_len_ratio") if "best_preset_default_avg_len_ratio" in row else 0.0
        best_avg_distance_ratio = fnum(row, "best_preset_default_avg_distance_ratio") if "best_preset_default_avg_distance_ratio" in row else 0.0
        best_header_ratio = fnum(row, "best_preset_default_header_ratio") if "best_preset_default_header_ratio" in row else 0.0
        best_literal_ratio = fnum(row, "best_preset_default_literal_ratio") if "best_preset_default_literal_ratio" in row else 0.0
        best_match_symbol_ratio = fnum(row, "best_preset_default_match_symbol_ratio") if "best_preset_default_match_symbol_ratio" in row else 0.0
        best_length_extra_ratio = fnum(row, "best_preset_default_length_extra_ratio") if "best_preset_default_length_extra_ratio" in row else 0.0
        best_distance_extra_ratio = fnum(row, "best_preset_default_distance_extra_ratio") if "best_preset_default_distance_extra_ratio" in row else 0.0
        best_extra_ratio = fnum(row, "best_preset_default_extra_ratio") if "best_preset_default_extra_ratio" in row else 0.0
        best_length_extra_hist = row.get("best_preset_length_extra_hist", "")
        best_distance_extra_hist = row.get("best_preset_distance_extra_hist", "")
        best_short_matches = row.get("best_preset_short_match_tokens", "")
        lines.append(
            f"| {row['path']} | {row['token_count']} | {row['match_tokens']} | {row['matched_bytes']} | "
            f"{avg_len:.2f} | {avg_distance:.0f} | {short_matches} | {length_symbol_delta} | {distance_symbol_delta} | "
            f"{length_extra_hist} | {distance_extra_hist} | "
            f"{fnum(row, 'fixed_dynamic_size_ratio'):.3f} | {best_size_ratio:.3f} | {best_token_ratio:.3f} | "
            f"{best_avg_len_ratio:.3f} | {best_avg_distance_ratio:.3f} | "
            f"{best_header_ratio:.3f} | {best_literal_ratio:.3f} | {best_match_symbol_ratio:.3f} | "
            f"{best_length_extra_ratio:.3f} | {best_distance_extra_ratio:.3f} | {best_extra_ratio:.3f} | "
            f"{best_length_extra_hist} | {best_distance_extra_hist} | {best_short_matches} | "
            f"{fnum(row, 'best_dynamic_time_ratio'):.3f} | "
            f"{fnum(row, 'stats_dynamic_time_ratio'):.3f} | {row['code_length_ops']} |"
        )
    lines.append("")
    return lines


def dictionary_deflate_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Dictionary deflate savings",
        "",
        "| case | input bytes | dict bytes | raw plain | raw dict | raw Δ | raw dict/plain | zlib plain | zlib dict | zlib Δ | zlib dict/plain |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['case']} | {row['input_bytes']} | {row['dict_bytes']} | "
            f"{row['raw_plain_bytes']} | {row['raw_dict_bytes']} | {row['raw_dict_delta']} | "
            f"{fnum(row, 'raw_dict_ratio'):.3f} | {row['zlib_plain_bytes']} | {row['zlib_dict_bytes']} | "
            f"{row['zlib_dict_delta']} | {fnum(row, 'zlib_dict_ratio'):.3f} |"
        )
    lines.append("")
    return lines


def decode_stage_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode stage diagnostics",
        "",
        "| case | raw alloc MiB/s | raw into MiB/s | zlib alloc MiB/s | zlib into MiB/s | gzip alloc MiB/s | gzip into MiB/s | zlib/raw time | zlib/raw into time | gzip/raw time | gzip/raw into time | raw alloc/into time | zlib alloc/into time | gzip alloc/into time | iterations | raw bytes | zlib bytes | gzip bytes |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['case']} | {fnum(row, 'raw_mib_s'):.2f} | {fnum(row, 'raw_into_mib_s'):.2f} | "
            f"{fnum(row, 'zlib_mib_s'):.2f} | {fnum(row, 'zlib_into_mib_s'):.2f} | "
            f"{fnum(row, 'gzip_mib_s'):.2f} | {fnum(row, 'gzip_into_mib_s'):.2f} | "
            f"{fnum(row, 'zlib_wrapper_time_ratio'):.3f} | {fnum(row, 'zlib_wrapper_into_time_ratio'):.3f} | "
            f"{fnum(row, 'gzip_wrapper_time_ratio'):.3f} | {fnum(row, 'gzip_wrapper_into_time_ratio'):.3f} | "
            f"{fnum(row, 'raw_alloc_into_time_ratio'):.3f} | {fnum(row, 'zlib_alloc_into_time_ratio'):.3f} | "
            f"{fnum(row, 'gzip_alloc_into_time_ratio'):.3f} | {row['iterations']} | "
            f"{row['raw_bytes']} | {row['zlib_bytes']} | {row['gzip_bytes']} |"
        )
    lines.append("")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--decode-csv", default="zig-out/vort-rust-deflate-decode-bench.csv")
    parser.add_argument("--encode-csv", default="zig-out/vort-rust-deflate-encode-bench.csv")
    parser.add_argument("--dynamic-plan-csv", default="zig-out/vort-dynamic-plan-report.csv")
    parser.add_argument("--dictionary-deflate-csv", default="zig-out/vort-dictionary-deflate-report.csv")
    parser.add_argument("--decode-stage-csv", default="zig-out/vort-deflate-decode-stage-report.csv")
    parser.add_argument("--output", default="zig-out/vort-rust-deflate-benchmark-summary.md")
    args = parser.parse_args()

    decode_rows = read_rows(Path(args.decode_csv))
    encode_rows = read_rows(Path(args.encode_csv))
    dynamic_plan_path = Path(args.dynamic_plan_csv)
    dynamic_plan_rows = read_rows(dynamic_plan_path) if dynamic_plan_path.exists() else []
    dictionary_deflate_path = Path(args.dictionary_deflate_csv)
    dictionary_deflate_rows = read_rows(dictionary_deflate_path) if dictionary_deflate_path.exists() else []
    decode_stage_path = Path(args.decode_stage_csv)
    decode_stage_rows = read_rows(decode_stage_path) if decode_stage_path.exists() else []
    lines = [
        "# Vort vs Rust deflate benchmark summary",
        "",
        "Derived from the fdeflate/miniz_oxide benchmark CSV artifacts. Ratios above 1.0 are better for throughput; ratios below 1.0 are better for compressed size.",
        "",
    ]
    lines.extend(benchmark_overview_lines(decode_rows, encode_rows))
    lines.extend(decode_lines(decode_rows))
    lines.extend(raw_decode_lines(decode_rows))
    lines.extend(gzip_decode_lines(decode_rows))
    lines.extend(decode_allocation_lines(decode_rows))
    lines.extend(encode_lines(encode_rows))
    lines.extend(raw_encode_lines(encode_rows))
    if dynamic_plan_rows:
        lines.extend(dynamic_plan_lines(dynamic_plan_rows))
    if decode_stage_rows:
        lines.extend(decode_stage_lines(decode_stage_rows))
    if dictionary_deflate_rows:
        lines.extend(dictionary_deflate_lines(dictionary_deflate_rows))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    print(
        f"rust_deflate_benchmark_summary={output} "
        f"decode_rows={len(decode_rows)} encode_rows={len(encode_rows)} "
        f"dynamic_plan_rows={len(dynamic_plan_rows)} decode_stage_rows={len(decode_stage_rows)} "
        f"dictionary_deflate_rows={len(dictionary_deflate_rows)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
