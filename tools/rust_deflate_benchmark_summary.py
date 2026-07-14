#!/usr/bin/env python3
"""Summarize Vort vs fdeflate/miniz_oxide benchmark CSV artifacts."""

import argparse
import csv
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


def decode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode throughput (zlib)",
        "",
        "| case | Vort alloc MiB/s | Vort into MiB/s | best Rust MiB/s | alloc / Rust | into / Rust | best Rust engine |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for case, items in sorted(by_case(rows).items()):
        vort_alloc = next(row for row in items if row["engine"] == "vort")
        vort_into = next(row for row in items if row["engine"] == "vort-into")
        rust_rows = [row for row in items if not row["engine"].startswith("vort")]
        rust = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        alloc_speed = fnum(vort_alloc, "throughput_mib_s")
        into_speed = fnum(vort_into, "throughput_mib_s")
        rust_speed = fnum(rust, "throughput_mib_s")
        alloc_ratio = 0.0 if rust_speed == 0 else alloc_speed / rust_speed
        into_ratio = 0.0 if rust_speed == 0 else into_speed / rust_speed
        lines.append(f"| {case} | {alloc_speed:.2f} | {into_speed:.2f} | {rust_speed:.2f} | {alloc_ratio:.3f} | {into_ratio:.3f} | {rust['engine']} |")
    lines.append("")
    return lines


def gzip_decode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Vort gzip decode throughput",
        "",
        "| case | gzip alloc MiB/s | gzip into MiB/s | into / alloc |",
        "| --- | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        gzip = next((row for row in items if row["engine"] == "vort-gzip"), None)
        gzip_into = next((row for row in items if row["engine"] == "vort-gzip-into"), None)
        if gzip is None or gzip_into is None:
            continue
        alloc_speed = fnum(gzip, "throughput_mib_s")
        into_speed = fnum(gzip_into, "throughput_mib_s")
        ratio = 0.0 if alloc_speed == 0 else into_speed / alloc_speed
        lines.append(f"| {case} | {alloc_speed:.2f} | {into_speed:.2f} | {ratio:.3f} |")
    lines.append("")
    return lines


def decode_allocation_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Decode allocation overhead",
        "",
        "| case | zlib alloc/into time | gzip alloc/into time |",
        "| --- | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        zlib_alloc = next((row for row in items if row["engine"] == "vort"), None)
        zlib_into = next((row for row in items if row["engine"] == "vort-into"), None)
        gzip_alloc = next((row for row in items if row["engine"] == "vort-gzip"), None)
        gzip_into = next((row for row in items if row["engine"] == "vort-gzip-into"), None)
        if zlib_alloc is None or zlib_into is None or gzip_alloc is None or gzip_into is None:
            continue
        zlib_ratio = fnum(zlib_alloc, "elapsed_s") / fnum(zlib_into, "elapsed_s")
        gzip_ratio = fnum(gzip_alloc, "elapsed_s") / fnum(gzip_into, "elapsed_s")
        lines.append(f"| {case} | {zlib_ratio:.3f} | {gzip_ratio:.3f} |")
    lines.append("")
    return lines


def encode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Encode speed and size",
        "",
        "| case | best Vort speed MiB/s | best Rust speed MiB/s | Vort speed / Rust | Vort default / dynamic speed | split/default speed | adaptive/default speed | split/default size | adaptive/default size | Vort default size / Rust | Vort best preset size / Rust | best Vort size | best Rust size | Vort size / Rust |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for case, items in sorted(by_case(rows).items()):
        vort_rows = [row for row in items if row["engine"].startswith("vort")]
        rust_rows = [row for row in items if not row["engine"].startswith("vort")]
        best_vort_speed = max(vort_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_rust_speed = max(rust_rows, key=lambda row: fnum(row, "throughput_mib_s"))
        best_vort_size = min(vort_rows, key=lambda row: inum(row, "zlib_bytes"))
        best_rust_size = min(rust_rows, key=lambda row: inum(row, "zlib_bytes"))
        speed_ratio = fnum(best_vort_speed, "throughput_mib_s") / fnum(best_rust_speed, "throughput_mib_s")
        size_ratio = inum(best_vort_size, "zlib_bytes") / max(inum(best_rust_size, "zlib_bytes"), 1)
        vort_default = next((row for row in vort_rows if row["engine"] == "vort-default"), None)
        vort_best = next((row for row in vort_rows if row["engine"] == "vort-best"), None)
        vort_dynamic = next((row for row in vort_rows if row["engine"] == "vort-dynamic-default"), None)
        vort_split = next((row for row in vort_rows if row["engine"] == "vort-split-default"), None)
        vort_adaptive = next((row for row in vort_rows if row["engine"] == "vort-adaptive-default"), None)
        dynamic_overhead = ""
        if vort_default is not None and vort_dynamic is not None and fnum(vort_dynamic, "throughput_mib_s") != 0:
            dynamic_overhead = f"{fnum(vort_default, 'throughput_mib_s') / fnum(vort_dynamic, 'throughput_mib_s'):.3f}"
        split_speed = split_size = adaptive_speed = adaptive_size = ""
        default_size_ratio = best_preset_size_ratio = ""
        rust_size = max(inum(best_rust_size, "zlib_bytes"), 1)
        if vort_default is not None:
            default_speed = fnum(vort_default, "throughput_mib_s")
            default_size = max(inum(vort_default, "zlib_bytes"), 1)
            default_size_ratio = f"{inum(vort_default, 'zlib_bytes') / rust_size:.3f}"
            if vort_split is not None:
                split_speed = "" if default_speed == 0 else f"{fnum(vort_split, 'throughput_mib_s') / default_speed:.3f}"
                split_size = f"{inum(vort_split, 'zlib_bytes') / default_size:.3f}"
            if vort_adaptive is not None:
                adaptive_speed = "" if default_speed == 0 else f"{fnum(vort_adaptive, 'throughput_mib_s') / default_speed:.3f}"
                adaptive_size = f"{inum(vort_adaptive, 'zlib_bytes') / default_size:.3f}"
        if vort_best is not None:
            best_preset_size_ratio = f"{inum(vort_best, 'zlib_bytes') / rust_size:.3f}"
        lines.append(
            f"| {case} | {best_vort_speed['engine']} {fnum(best_vort_speed, 'throughput_mib_s'):.2f} | "
            f"{best_rust_speed['engine']} {fnum(best_rust_speed, 'throughput_mib_s'):.2f} | {speed_ratio:.3f} | "
            f"{dynamic_overhead} | "
            f"{split_speed} | {adaptive_speed} | {split_size} | {adaptive_size} | "
            f"{default_size_ratio} | {best_preset_size_ratio} | "
            f"{best_vort_size['engine']} {inum(best_vort_size, 'zlib_bytes')} | "
            f"{best_rust_size['engine']} {inum(best_rust_size, 'zlib_bytes')} | {size_ratio:.3f} |"
        )
    lines.append("")
    return lines


def dynamic_plan_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Dynamic plan diagnostics",
        "",
        "| path | tokens | matches | matched bytes | fixed/dynamic size | best preset size/default | best preset tokens/default | best/dynamic time | stats/dynamic time | code-length ops |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        best_size_ratio = fnum(row, "best_preset_default_size_ratio") if "best_preset_default_size_ratio" in row else 0.0
        best_token_ratio = fnum(row, "best_preset_default_token_ratio") if "best_preset_default_token_ratio" in row else 0.0
        lines.append(
            f"| {row['path']} | {row['token_count']} | {row['match_tokens']} | {row['matched_bytes']} | "
            f"{fnum(row, 'fixed_dynamic_size_ratio'):.3f} | {best_size_ratio:.3f} | {best_token_ratio:.3f} | "
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
    lines.extend(decode_lines(decode_rows))
    lines.extend(gzip_decode_lines(decode_rows))
    lines.extend(decode_allocation_lines(decode_rows))
    lines.extend(encode_lines(encode_rows))
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
