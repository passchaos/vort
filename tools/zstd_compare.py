#!/usr/bin/env python3
import argparse
import csv
import pathlib
import shutil
import subprocess
import tempfile
import time
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")
CSV_FIELDS = [
    "path",
    "input_bytes",
    "zstd_bytes",
    "vort_raw_fixed_bytes",
    "vort_over_zstd",
    "zstd_decode_ms",
    "vort_raw_fixed_decode_ms",
    "zstd_decode_mib_s",
    "vort_raw_fixed_decode_mib_s",
    "vort_decode_vs_zstd",
    "decode_repeats",
    "zstd_version",
    "vort_commit",
    "zig_version",
    "cpu_model",
    "optimize",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("items", nargs="*", help="optional vort CLI artifact followed by paths")
    parser.add_argument("--csv", type=pathlib.Path)
    parser.add_argument("--markdown", type=pathlib.Path)
    parser.add_argument("--optimize", default="unknown")
    parser.add_argument("--decode-repeats", type=positive_int_arg, default=3)
    return parser.parse_args()


def positive_int_arg(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError(f"expected a positive integer, got {value!r}")
    return parsed


def zstd_version() -> str:
    if not ZSTD:
        return "missing"
    proc = subprocess.run([ZSTD, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return proc.stdout.strip()


def command_output(args: list[str]) -> str:
    proc = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def timed_subprocess(args: list[str], **kwargs: Any) -> tuple[subprocess.CompletedProcess[Any], float]:
    start = time.perf_counter()
    proc = subprocess.run(args, **kwargs)
    return proc, time.perf_counter() - start


def median(values: list[float]) -> float:
    ordered = sorted(values)
    midpoint = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[midpoint]
    return (ordered[midpoint - 1] + ordered[midpoint]) / 2.0


def measure_zstd_decode(zstd_path: pathlib.Path, expected: bytes, repeats: int) -> float:
    timings: list[float] = []
    for _ in range(repeats):
        proc, elapsed = timed_subprocess(
            [ZSTD, "-q", "-dc", str(zstd_path)],
            check=True,
            stdout=subprocess.PIPE,
        )
        if proc.stdout != expected:
            raise AssertionError(f"zstd decode mismatch for {zstd_path}")
        timings.append(elapsed)
    return median(timings)


def measure_vort_raw_decode(cli: pathlib.Path, raw_path: pathlib.Path, decoded_path: pathlib.Path, expected: bytes, repeats: int) -> float:
    timings: list[float] = []
    for _ in range(repeats):
        _, elapsed = timed_subprocess(
            [str(cli), "decode-raw-file", str(raw_path), str(decoded_path), str(len(expected))],
            cwd=ROOT,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if decoded_path.read_bytes() != expected:
            raise AssertionError(f"Vort raw fixed decode mismatch for {raw_path}")
        timings.append(elapsed)
    return median(timings)


def mib_per_second(byte_count: int, elapsed_seconds: float) -> float:
    if elapsed_seconds <= 0.0:
        return 0.0
    return (byte_count / (1024.0 * 1024.0)) / elapsed_seconds


def cpu_model() -> str:
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text(errors="ignore").splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    return "unknown"


def metadata(optimize: str, decode_repeats: int) -> dict[str, str]:
    return {
        "zstd_version": zstd_version(),
        "vort_commit": command_output(["git", "rev-parse", "--short", "HEAD"]),
        "zig_version": command_output(["zig", "version"]),
        "cpu_model": cpu_model(),
        "optimize": optimize,
        "decode_repeats": str(decode_repeats),
    }


def write_outputs(args: argparse.Namespace, rows: list[dict[str, Any]], meta: dict[str, str]) -> None:
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)

    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        lines = [
            "# Vort vs zstd size and decode smoke",
            "",
            f"- zstd: `{meta['zstd_version']}`",
            f"- Vort commit: `{meta['vort_commit']}`",
            f"- Zig version: `{meta['zig_version']}`",
            f"- CPU: `{meta['cpu_model']}`",
            f"- Optimize: `{meta['optimize']}`",
            f"- Decode repeats: `{meta['decode_repeats']}` median per input and codec",
            "- zstd command: `zstd -q -f -1 -o <tmp> <path>`",
            "- zstd decode command: `zstd -q -dc <tmp.zst>`",
            "- Vort command: `vort encode-raw-fixed-hex <utf8 text>`",
            "- Vort decode command: `vort decode-raw-file <tmp.raw> <tmp.out> <input_bytes>`",
            "",
            "Decode timings include process startup and temporary-file/stdout plumbing; they are a retained smoke signal, not a standalone throughput claim.",
            "",
            "| path | input bytes | zstd bytes | Vort raw fixed bytes | Vort / zstd | zstd decode MiB/s | Vort raw fixed decode MiB/s | Vort decode / zstd |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
        for row in rows:
            ratio = row["vort_over_zstd"]
            ratio_text = "n/a" if not isinstance(ratio, float) or ratio < 0 else f"{ratio:.4f}"
            zstd_decode = row["zstd_decode_mib_s"]
            vort_decode = row["vort_raw_fixed_decode_mib_s"]
            decode_ratio = row["vort_decode_vs_zstd"]
            lines.append(
                f"| {('**TOTAL**' if row['path'] == 'TOTAL' else '`' + row['path'] + '`')} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_raw_fixed_bytes']} | {ratio_text} | {zstd_decode:.2f} | {vort_decode:.2f} | {decode_ratio:.4f} |"
            )
        args.markdown.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    if not ZSTD:
        print("zstd compare: zstd=missing")
        write_outputs(args, [], metadata(args.optimize, args.decode_repeats))
        return 0

    cli = pathlib.Path(args.items[0]) if args.items and pathlib.Path(args.items[0]).exists() else None
    path_args = args.items[1:] if cli else args.items
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"] if not path_args else [pathlib.Path(p) for p in path_args]

    rows: list[dict[str, Any]] = []
    meta = metadata(args.optimize, args.decode_repeats)
    print("path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,zstd_decode_ms,vort_raw_fixed_decode_ms")
    for path in paths:
        data = path.read_bytes()
        with tempfile.TemporaryDirectory() as td:
            temp_dir = pathlib.Path(td)
            zstd_path = temp_dir / "sample.zst"
            subprocess.run([ZSTD, "-q", "-f", "-1", "-o", str(zstd_path), str(path)], check=True)
            zstd_size = zstd_path.stat().st_size
            zstd_decode_s = measure_zstd_decode(zstd_path, data, args.decode_repeats)

            vort_decode_s = -1.0
            vort_decode_mib_s = -1.0
            vort_decode_vs_zstd = -1.0
            zstd_decode_mib_s = mib_per_second(len(data), zstd_decode_s)

            if cli:
                # CLI command accepts text payloads; decode as UTF-8 for documentation/source corpora.
                hex_out = subprocess.run(
                    [str(cli), "encode-raw-fixed-hex", data.decode("utf-8")],
                    cwd=ROOT,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                ).stdout.strip()
                vort_data = bytes.fromhex(hex_out)
                raw_path = temp_dir / "sample.raw"
                decoded_path = temp_dir / "sample.vort.out"
                raw_path.write_bytes(vort_data)
                vort_decode_s = measure_vort_raw_decode(cli, raw_path, decoded_path, data, args.decode_repeats)
                vort_size = len(vort_data)
                vort_decode_mib_s = mib_per_second(len(data), vort_decode_s)
                vort_decode_vs_zstd = vort_decode_mib_s / zstd_decode_mib_s if zstd_decode_mib_s > 0.0 else -1.0
            else:
                vort_size = -1
        ratio = (vort_size / zstd_size) if zstd_size and vort_size >= 0 else -1.0
        rows.append(
            {
                "path": str(path),
                "input_bytes": len(data),
                "zstd_bytes": zstd_size,
                "vort_raw_fixed_bytes": vort_size,
                "vort_over_zstd": ratio,
                "zstd_decode_ms": zstd_decode_s * 1000.0,
                "vort_raw_fixed_decode_ms": vort_decode_s * 1000.0,
                "zstd_decode_mib_s": zstd_decode_mib_s,
                "vort_raw_fixed_decode_mib_s": vort_decode_mib_s,
                "vort_decode_vs_zstd": vort_decode_vs_zstd,
                "decode_repeats": args.decode_repeats,
                **meta,
            }
        )
        print(f"{path},{len(data)},{zstd_size},{vort_size},{zstd_decode_s * 1000.0:.3f},{vort_decode_s * 1000.0:.3f}")

    if rows:
        total_input = sum(int(row["input_bytes"]) for row in rows)
        total_zstd = sum(int(row["zstd_bytes"]) for row in rows)
        total_vort = sum(int(row["vort_raw_fixed_bytes"]) for row in rows if int(row["vort_raw_fixed_bytes"]) >= 0)
        total_ratio = (total_vort / total_zstd) if total_zstd and total_vort >= 0 else -1.0
        total_zstd_decode_ms = sum(float(row["zstd_decode_ms"]) for row in rows)
        total_vort_decode_ms = sum(float(row["vort_raw_fixed_decode_ms"]) for row in rows)
        total_zstd_decode_mib_s = mib_per_second(total_input, total_zstd_decode_ms / 1000.0)
        total_vort_decode_mib_s = mib_per_second(total_input, total_vort_decode_ms / 1000.0)
        rows.append(
            {
                "path": "TOTAL",
                "input_bytes": total_input,
                "zstd_bytes": total_zstd,
                "vort_raw_fixed_bytes": total_vort,
                "vort_over_zstd": total_ratio,
                "zstd_decode_ms": total_zstd_decode_ms,
                "vort_raw_fixed_decode_ms": total_vort_decode_ms,
                "zstd_decode_mib_s": total_zstd_decode_mib_s,
                "vort_raw_fixed_decode_mib_s": total_vort_decode_mib_s,
                "vort_decode_vs_zstd": total_vort_decode_mib_s / total_zstd_decode_mib_s if total_zstd_decode_mib_s > 0.0 else -1.0,
                "decode_repeats": args.decode_repeats,
                **meta,
            }
        )

    write_outputs(args, rows, meta)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
