#!/usr/bin/env python3
"""Sweep native Vort block lengths for the zstd comparison smoke."""

from __future__ import annotations

import argparse
import csv
import pathlib
import subprocess
import sys
import tempfile
from typing import Any

sys.dont_write_bytecode = True

import zstd_compare

CSV_FIELDS = [
    "path",
    "block_len",
    "input_bytes",
    "zstd_bytes",
    "vort_native_best_bytes",
    "vort_native_stream_bytes",
    "vort_native_embedded_bytes",
    "vort_native_best_over_zstd",
    "vort_native_stream_over_zstd",
    "vort_native_embedded_over_zstd",
    "vort_stream_over_native_best",
    "vort_stream_over_native_best_bytes",
    "vort_stream_over_native_best_pct",
    "vort_embedded_over_native_stream",
    "vort_embedded_over_native_stream_bytes",
    "vort_embedded_over_native_stream_pct",
    "source_mode",
    "size_mode",
    "case_limit",
    "zstd_version",
    "vort_commit",
    "zig_version",
    "cpu_model",
    "optimize",
]


def parse_block_lens(value: str) -> list[int]:
    result: list[int] = []
    seen: set[int] = set()
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        parsed = int(item)
        if parsed <= 0:
            raise argparse.ArgumentTypeError(f"block lengths must be positive, got {item!r}")
        if parsed not in seen:
            result.append(parsed)
            seen.add(parsed)
    if not result:
        raise argparse.ArgumentTypeError("at least one block length is required")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("items", nargs="*", help="optional vort CLI artifact followed by paths")
    parser.add_argument("--csv", type=pathlib.Path)
    parser.add_argument("--markdown", type=pathlib.Path)
    parser.add_argument("--optimize", default="unknown")
    parser.add_argument("--block-lens", type=parse_block_lens, default=parse_block_lens("4096,8192,16384,32768,65536"))
    parser.add_argument("--standard-suite", action="store_true")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--limit", type=zstd_compare.positive_int_arg)
    return parser.parse_args()


def ratio(numerator: int, denominator: int) -> float:
    return numerator / denominator if denominator > 0 else -1.0


def overhead_ratio(current: int, baseline: int) -> float:
    return current / baseline if baseline > 0 else -1.0


def overhead_pct(current: int, baseline: int) -> float:
    return ((current / baseline) - 1.0) * 100.0 if baseline > 0 else -1.0


def metadata(args: argparse.Namespace, cli_items: int) -> dict[str, str]:
    return {
        "zstd_version": zstd_compare.zstd_version(),
        "vort_commit": zstd_compare.command_output(["git", "rev-parse", "--short", "HEAD"]),
        "zig_version": zstd_compare.command_output(["zig", "version"]),
        "cpu_model": zstd_compare.cpu_model(),
        "optimize": args.optimize,
        "source_mode": zstd_compare.source_mode_for(args, cli_items),
        "size_mode": zstd_compare.size_mode_for(args),
        "case_limit": str(args.limit if args.limit is not None else "none"),
    }


def encode_size(cli: pathlib.Path, command: str, input_path: pathlib.Path, output_path: pathlib.Path, block_len: int | None = None) -> int:
    argv = [str(cli), command, str(input_path), str(output_path)]
    if block_len is not None:
        argv.append(str(block_len))
    subprocess.run(
        argv,
        cwd=zstd_compare.ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return output_path.stat().st_size


def format_ratio(value: Any) -> str:
    return "n/a" if not isinstance(value, float) or value < 0 else f"{value:.4f}"


def format_pct(value: Any) -> str:
    return "n/a" if not isinstance(value, float) or value < 0 else f"{value:.2f}%"


def add_total_rows(rows: list[dict[str, Any]], block_lens: list[int], meta: dict[str, str]) -> None:
    data_rows = list(rows)
    for block_len in block_lens:
        block_rows = [row for row in data_rows if int(row["block_len"]) == block_len]
        if not block_rows:
            continue
        total_input = sum(int(row["input_bytes"]) for row in block_rows)
        total_zstd = sum(int(row["zstd_bytes"]) for row in block_rows)
        total_best = sum(int(row["vort_native_best_bytes"]) for row in block_rows)
        total_stream = sum(int(row["vort_native_stream_bytes"]) for row in block_rows)
        total_embedded = sum(int(row["vort_native_embedded_bytes"]) for row in block_rows)
        stream_over_best_bytes = total_stream - total_best
        embedded_over_stream_bytes = total_embedded - total_stream
        rows.append(
            {
                "path": "TOTAL",
                "block_len": block_len,
                "input_bytes": total_input,
                "zstd_bytes": total_zstd,
                "vort_native_best_bytes": total_best,
                "vort_native_stream_bytes": total_stream,
                "vort_native_embedded_bytes": total_embedded,
                "vort_native_best_over_zstd": ratio(total_best, total_zstd),
                "vort_native_stream_over_zstd": ratio(total_stream, total_zstd),
                "vort_native_embedded_over_zstd": ratio(total_embedded, total_zstd),
                "vort_stream_over_native_best": overhead_ratio(total_stream, total_best),
                "vort_stream_over_native_best_bytes": stream_over_best_bytes,
                "vort_stream_over_native_best_pct": overhead_pct(total_stream, total_best),
                "vort_embedded_over_native_stream": overhead_ratio(total_embedded, total_stream),
                "vort_embedded_over_native_stream_bytes": embedded_over_stream_bytes,
                "vort_embedded_over_native_stream_pct": overhead_pct(total_embedded, total_stream),
                **meta,
            }
        )


def write_outputs(args: argparse.Namespace, rows: list[dict[str, Any]], meta: dict[str, str], block_lens: list[int]) -> None:
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)

    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        total_rows = [row for row in rows if row["path"] == "TOTAL"]
        best_total = min(total_rows, key=lambda row: int(row["vort_native_stream_bytes"])) if total_rows else None
        lines = [
            "# Vort native block length sweep vs zstd",
            "",
            f"- source mode: `{meta['source_mode']}`",
            f"- size mode: `{meta['size_mode']}`",
            f"- case limit: `{meta['case_limit']}`",
            f"- zstd: `{meta['zstd_version']}`",
            f"- Vort commit: `{meta['vort_commit']}`",
            f"- Zig version: `{meta['zig_version']}`",
            f"- CPU: `{meta['cpu_model']}`",
            f"- Optimize: `{meta['optimize']}`",
            f"- Swept native block lengths: `{','.join(str(n) for n in block_lens)}`",
            "",
            "The sweep isolates native block-fragmentation cost by comparing a single-frame native best payload with blocked native streams that omit the embedded index. The embedded rows keep the index-frame cost visible for each block length.",
            "",
        ]
        if best_total is not None:
            lines.extend(
                [
                    f"Best total native stream bytes in this smoke: block length `{best_total['block_len']}` with `{best_total['vort_native_stream_bytes']}` bytes (`{format_ratio(best_total['vort_native_stream_over_zstd'])}x` zstd).",
                    "",
                ]
            )
        lines.extend(
            [
                "## TOTAL by block length",
                "",
                "| block length | input bytes | zstd bytes | native best bytes | native stream bytes | native embedded bytes | stream / zstd | embedded / zstd | stream / native best | stream overhead bytes | stream overhead pct | embedded / stream | embedded-index bytes |",
                "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
            ]
        )
        for row in total_rows:
            lines.append(
                f"| {row['block_len']} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_stream_bytes']} | {row['vort_native_embedded_bytes']} | {format_ratio(row['vort_native_stream_over_zstd'])} | {format_ratio(row['vort_native_embedded_over_zstd'])} | {format_ratio(row['vort_stream_over_native_best'])} | {row['vort_stream_over_native_best_bytes']} | {format_pct(row['vort_stream_over_native_best_pct'])} | {format_ratio(row['vort_embedded_over_native_stream'])} | {row['vort_embedded_over_native_stream_bytes']} |"
            )
        lines.extend(
            [
                "",
                "## Per-input rows",
                "",
                "| path | block length | input bytes | zstd bytes | native best bytes | native stream bytes | native embedded bytes | stream / native best | embedded / stream |",
                "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
            ]
        )
        for row in rows:
            if row["path"] == "TOTAL":
                continue
            lines.append(
                f"| `{row['path']}` | {row['block_len']} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_stream_bytes']} | {row['vort_native_embedded_bytes']} | {format_ratio(row['vort_stream_over_native_best'])} | {format_ratio(row['vort_embedded_over_native_stream'])} |"
            )
        args.markdown.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    cli_items = zstd_compare.cli_arg_count(args.items)
    cli = pathlib.Path(args.items[0]) if cli_items else None
    if cli is None:
        raise SystemExit("zstd block sweep requires a vort CLI artifact")
    if not zstd_compare.ZSTD:
        print("zstd block sweep: zstd=missing")
        return 0

    path_args = args.items[cli_items:]
    cases = zstd_compare.load_cases(args, path_args)
    meta = metadata(args, cli_items)
    rows: list[dict[str, Any]] = []
    print("path,block_len,input_bytes,zstd_bytes,vort_native_best_bytes,vort_native_stream_bytes,vort_native_embedded_bytes")
    for label, data in cases:
        with tempfile.TemporaryDirectory() as td:
            temp_dir = pathlib.Path(td)
            input_path = temp_dir / "sample.input"
            input_path.write_bytes(data)
            zstd_path = temp_dir / "sample.zst"
            subprocess.run([zstd_compare.ZSTD, "-q", "-f", "-1", "-o", str(zstd_path), str(input_path)], check=True)
            zstd_size = zstd_path.stat().st_size
            native_best_path = temp_dir / "sample.vort-best"
            native_best_size = encode_size(cli, "encode-vort-best-file", input_path, native_best_path)
            for block_len in args.block_lens:
                native_stream_path = temp_dir / f"sample-{block_len}.vort-stream"
                native_stream_size = encode_size(cli, "encode-vort-blocked-best-file", input_path, native_stream_path, block_len)
                native_embedded_path = temp_dir / f"sample-{block_len}.vort"
                native_embedded_size = encode_size(cli, "encode-vort-embedded-best-file", input_path, native_embedded_path, block_len)
                stream_over_best_bytes = native_stream_size - native_best_size
                embedded_over_stream_bytes = native_embedded_size - native_stream_size
                rows.append(
                    {
                        "path": label,
                        "block_len": block_len,
                        "input_bytes": len(data),
                        "zstd_bytes": zstd_size,
                        "vort_native_best_bytes": native_best_size,
                        "vort_native_stream_bytes": native_stream_size,
                        "vort_native_embedded_bytes": native_embedded_size,
                        "vort_native_best_over_zstd": ratio(native_best_size, zstd_size),
                        "vort_native_stream_over_zstd": ratio(native_stream_size, zstd_size),
                        "vort_native_embedded_over_zstd": ratio(native_embedded_size, zstd_size),
                        "vort_stream_over_native_best": overhead_ratio(native_stream_size, native_best_size),
                        "vort_stream_over_native_best_bytes": stream_over_best_bytes,
                        "vort_stream_over_native_best_pct": overhead_pct(native_stream_size, native_best_size),
                        "vort_embedded_over_native_stream": overhead_ratio(native_embedded_size, native_stream_size),
                        "vort_embedded_over_native_stream_bytes": embedded_over_stream_bytes,
                        "vort_embedded_over_native_stream_pct": overhead_pct(native_embedded_size, native_stream_size),
                        **meta,
                    }
                )
                print(f"{label},{block_len},{len(data)},{zstd_size},{native_best_size},{native_stream_size},{native_embedded_size}")

    add_total_rows(rows, args.block_lens, meta)
    write_outputs(args, rows, meta, args.block_lens)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
