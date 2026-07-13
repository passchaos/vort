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
        "## Decode throughput",
        "",
        "| case | Vort MiB/s | best Rust MiB/s | Vort / best Rust | best Rust engine |",
        "| --- | ---: | ---: | ---: | --- |",
    ]
    for case, items in sorted(by_case(rows).items()):
        vort = next(row for row in items if row["engine"] == "vort")
        rust = max((row for row in items if row["engine"] != "vort"), key=lambda row: fnum(row, "throughput_mib_s"))
        vort_speed = fnum(vort, "throughput_mib_s")
        rust_speed = fnum(rust, "throughput_mib_s")
        ratio = 0.0 if rust_speed == 0 else vort_speed / rust_speed
        lines.append(f"| {case} | {vort_speed:.2f} | {rust_speed:.2f} | {ratio:.3f} | {rust['engine']} |")
    lines.append("")
    return lines


def encode_lines(rows: list[dict[str, str]]) -> list[str]:
    lines = [
        "## Encode speed and size",
        "",
        "| case | best Vort speed MiB/s | best Rust speed MiB/s | Vort speed / Rust | best Vort size | best Rust size | Vort size / Rust |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
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
        lines.append(
            f"| {case} | {best_vort_speed['engine']} {fnum(best_vort_speed, 'throughput_mib_s'):.2f} | "
            f"{best_rust_speed['engine']} {fnum(best_rust_speed, 'throughput_mib_s'):.2f} | {speed_ratio:.3f} | "
            f"{best_vort_size['engine']} {inum(best_vort_size, 'zlib_bytes')} | "
            f"{best_rust_size['engine']} {inum(best_rust_size, 'zlib_bytes')} | {size_ratio:.3f} |"
        )
    lines.append("")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--decode-csv", default="zig-out/vort-rust-deflate-decode-bench.csv")
    parser.add_argument("--encode-csv", default="zig-out/vort-rust-deflate-encode-bench.csv")
    parser.add_argument("--output", default="zig-out/vort-rust-deflate-benchmark-summary.md")
    args = parser.parse_args()

    decode_rows = read_rows(Path(args.decode_csv))
    encode_rows = read_rows(Path(args.encode_csv))
    lines = [
        "# Vort vs Rust deflate benchmark summary",
        "",
        "Derived from the fdeflate/miniz_oxide benchmark CSV artifacts. Ratios above 1.0 are better for throughput; ratios below 1.0 are better for compressed size.",
        "",
    ]
    lines.extend(decode_lines(decode_rows))
    lines.extend(encode_lines(encode_rows))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    print(f"rust_deflate_benchmark_summary={output} decode_rows={len(decode_rows)} encode_rows={len(encode_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
