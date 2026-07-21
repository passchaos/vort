#!/usr/bin/env python3
import argparse
import csv
import os
import pathlib
import shutil
import subprocess
import tempfile
import tarfile
import time
import zlib
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")
SMOKE_LIMIT = 128 * 1024
SILESIA = pathlib.Path(os.environ.get("VORT_SILESIA_PATH", pathlib.Path.home() / "Work" / "zlib-rs" / "silesia-small.tar"))
CORPORA_DIR = pathlib.Path(os.environ.get("VORT_CORPORA_DIR", pathlib.Path.home() / "Work" / "corpora"))
STANDARD_CORPUS_CANDIDATES = [
    SILESIA,
    CORPORA_DIR / "calgary.tar",
    CORPORA_DIR / "canterbury.tar",
    CORPORA_DIR / "large-canterbury.tar",
    CORPORA_DIR / "enwik8",
]
CSV_FIELDS = [
    "path",
    "input_bytes",
    "zstd_bytes",
    "vort_raw_fixed_bytes",
    "vort_native_best_bytes",
    "vort_native_embedded_bytes",
    "vort_over_zstd",
    "vort_native_best_over_zstd",
    "vort_native_over_zstd",
    "zstd_decode_ms",
    "vort_raw_fixed_decode_ms",
    "vort_native_best_decode_ms",
    "vort_native_decode_ms",
    "zstd_decode_mib_s",
    "vort_raw_fixed_decode_mib_s",
    "vort_native_best_decode_mib_s",
    "vort_native_decode_mib_s",
    "vort_decode_vs_zstd",
    "vort_native_best_decode_vs_zstd",
    "vort_native_decode_vs_zstd",
    "decode_repeats",
    "native_block_len",
    "source_mode",
    "size_mode",
    "case_limit",
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
    parser.add_argument("--native-block-len", type=positive_int_arg, default=8192)
    parser.add_argument("--standard-suite", action="store_true")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--limit", type=positive_int_arg)
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
    subprocess.run(
        [str(cli), "decode-raw-file", str(raw_path), str(decoded_path), str(len(expected))],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if decoded_path.read_bytes() != expected:
        raise AssertionError(f"Vort raw fixed decode mismatch for {raw_path}")
    proc = subprocess.run(
        [str(cli), "bench-decode-raw-file", str(raw_path), str(len(expected)), str(repeats)],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return elapsed_seconds_from_bench(proc.stdout, "raw", repeats, len(expected), expected_accumulated_crc32(expected, repeats))


def measure_vort_best_decode(cli: pathlib.Path, frame_path: pathlib.Path, expected: bytes, repeats: int) -> float:
    proc = subprocess.run(
        [str(cli), "bench-decode-vort-best-file", str(frame_path), str(len(expected)), str(repeats)],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return elapsed_seconds_from_bench(proc.stdout, "vort_best", repeats, len(expected), expected_accumulated_crc32(expected, repeats))


def measure_vort_native_decode(cli: pathlib.Path, stream_path: pathlib.Path, decoded_path: pathlib.Path, expected: bytes, repeats: int) -> float:
    subprocess.run(
        [str(cli), "decode-vort-embedded-range-file", str(stream_path), str(decoded_path), "0", str(len(expected))],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if decoded_path.read_bytes() != expected:
        raise AssertionError(f"Vort native embedded decode mismatch for {stream_path}")
    proc = subprocess.run(
        [str(cli), "bench-decode-vort-embedded-range-file", str(stream_path), str(len(expected)), str(repeats)],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return elapsed_seconds_from_bench(proc.stdout, "vort_embedded", repeats, len(expected), expected_accumulated_crc32(expected, repeats))


def parse_key_values(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for part in text.strip().split():
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        result[key] = value
    return result


def expected_accumulated_crc32(payload: bytes, iterations: int) -> int:
    return ((zlib.crc32(payload) & 0xFFFF_FFFF) * iterations) & 0xFFFF_FFFF


def elapsed_seconds_from_bench(text: str, expected_mode: str, expected_iterations: int, expected_decoded_bytes: int, expected_checksum: int) -> float:
    fields = parse_key_values(text)
    if fields.get("mode") != expected_mode:
        raise AssertionError(f"unexpected bench mode in output: {text!r}")
    if int(fields.get("iterations", "0")) != expected_iterations:
        raise AssertionError(f"unexpected bench iterations in output: {text!r}")
    if int(fields.get("decoded_bytes", "0")) != expected_decoded_bytes:
        raise AssertionError(f"unexpected bench decoded byte count in output: {text!r}")
    if int(fields.get("checksum", "0")) != expected_checksum:
        raise AssertionError(f"unexpected bench checksum in output: {text!r}")
    elapsed_ns = int(fields.get("elapsed_ns", "0"))
    if elapsed_ns <= 0:
        raise AssertionError(f"missing positive elapsed_ns in output: {text!r}")
    return elapsed_ns / expected_iterations / 1_000_000_000.0


def mib_per_second(byte_count: int, elapsed_seconds: float) -> float:
    if elapsed_seconds <= 0.0:
        return 0.0
    return (byte_count / (1024.0 * 1024.0)) / elapsed_seconds


def discover_standard_corpora() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for path in STANDARD_CORPUS_CANDIDATES:
        if path.exists() and path not in seen:
            found.append(path)
            seen.add(path)
    return found


def bounded_case(label: str, data: bytes, full: bool) -> tuple[str, bytes]:
    if full:
        return label, data
    return f"{label}-128k", data[:SMOKE_LIMIT]


def append_case(cases: list[tuple[str, bytes]], label: str, data: bytes, full: bool, limit: int | None) -> bool:
    cases.append(bounded_case(label, data, full))
    return limit is not None and len(cases) >= limit


def load_path_cases(paths: list[pathlib.Path], full: bool, limit: int | None = None) -> list[tuple[str, bytes]]:
    cases: list[tuple[str, bytes]] = []
    for path in paths:
        if path.is_dir():
            for child in sorted(p for p in path.rglob("*") if p.is_file()):
                label = str(child.relative_to(path.parent))
                if append_case(cases, label, child.read_bytes(), full, limit):
                    return cases
        elif tarfile.is_tarfile(path):
            with tarfile.open(path, "r:*") as tar:
                for member in tar.getmembers():
                    if not member.isfile():
                        continue
                    extracted = tar.extractfile(member)
                    if extracted is None:
                        continue
                    label = f"{path.name}:{member.name}"
                    if append_case(cases, label, extracted.read(), full, limit):
                        return cases
        else:
            if append_case(cases, path.name, path.read_bytes(), full, limit):
                return cases
    return cases


def default_cases(limit: int | None = None) -> list[tuple[str, bytes]]:
    paths = [ROOT / "README.md", ROOT / "docs" / "roadmap.md"]
    return [(str(path), path.read_bytes()) for path in paths[:limit]]


def load_cases(args: argparse.Namespace, path_args: list[str]) -> list[tuple[str, bytes]]:
    if args.standard_suite:
        discovered = discover_standard_corpora()
        if discovered:
            return load_path_cases(discovered, args.full, args.limit)
        # Keep the smoke portable in checkouts that do not have the optional
        # corpora installed; the Markdown output still makes the source choice
        # visible through the row labels.
        return default_cases(args.limit)
    if path_args:
        return load_path_cases([pathlib.Path(path) for path in path_args], True, args.limit)
    return default_cases(args.limit)


def source_mode_for(args: argparse.Namespace, cli_items: int) -> str:
    has_path_items = len(args.items) > cli_items
    if args.standard_suite:
        return "standard-suite"
    return "paths" if has_path_items else "default-samples"


def size_mode_for(args: argparse.Namespace) -> str:
    if args.standard_suite and not args.full:
        return "bounded-128KiB"
    return "full"


def cli_arg_count(items: list[str]) -> int:
    if not items:
        return 0
    candidate = pathlib.Path(items[0])
    return 1 if candidate.is_file() and os.access(candidate, os.X_OK) else 0


def cpu_model() -> str:
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text(errors="ignore").splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    return "unknown"


def metadata(args: argparse.Namespace, cli_items: int) -> dict[str, str]:
    return {
        "zstd_version": zstd_version(),
        "vort_commit": command_output(["git", "rev-parse", "--short", "HEAD"]),
        "zig_version": command_output(["zig", "version"]),
        "cpu_model": cpu_model(),
        "optimize": args.optimize,
        "decode_repeats": str(args.decode_repeats),
        "native_block_len": str(args.native_block_len),
        "source_mode": source_mode_for(args, cli_items),
        "size_mode": size_mode_for(args),
        "case_limit": str(args.limit if args.limit is not None else "none"),
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
            f"- source mode: `{meta['source_mode']}`",
            f"- size mode: `{meta['size_mode']}`",
            f"- case limit: `{meta['case_limit']}`",
            f"- zstd: `{meta['zstd_version']}`",
            f"- Vort commit: `{meta['vort_commit']}`",
            f"- Zig version: `{meta['zig_version']}`",
            f"- CPU: `{meta['cpu_model']}`",
            f"- Optimize: `{meta['optimize']}`",
            f"- Decode repeats: `{meta['decode_repeats']}`; zstd uses median process decode, Vort uses an internal loop divided by this count",
            f"- Native block length: `{meta['native_block_len']}`",
            "- zstd command: `zstd -q -f -1 -o <tmp> <path>`",
            "- zstd decode command: `zstd -q -dc <tmp.zst>`",
            "- Vort raw command: `vort encode-raw-fixed-file <path> <tmp.raw>`",
            "- Vort raw decode command: `vort decode-raw-file <tmp.raw> <tmp.out> <input_bytes>` and `vort bench-decode-raw-file <tmp.raw> <input_bytes> <repeat>`",
            "- Vort native best command: `vort encode-vort-best-file <path> <tmp.vort-best>`",
            "- Vort native best decode command: `vort bench-decode-vort-best-file <tmp.vort-best> <input_bytes> <repeat>`",
            "- Vort native embedded command: `vort encode-vort-embedded-best-file <path> <tmp.vort> <block_len>`",
            "- Vort native embedded decode command: `vort decode-vort-embedded-range-file <tmp.vort> <tmp.out> 0 <input_bytes>`",
            "",
            "Decode timings are a retained smoke signal, not a standalone throughput claim: zstd rows include process/stdout plumbing, while Vort raw/native rows use CLI-internal decode loops divided by the repeat count after a one-shot output check.",
            "",
            "| path | input bytes | zstd bytes | Vort raw fixed bytes | Vort native best bytes | Vort native embedded bytes | Vort raw / zstd | Vort native best / zstd | Vort native embedded / zstd | zstd decode MiB/s | Vort raw fixed decode MiB/s | Vort native best decode MiB/s | Vort native embedded decode MiB/s | Vort raw decode / zstd | Vort native best decode / zstd | Vort native embedded decode / zstd |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
        ]
        for row in rows:
            raw_ratio = row["vort_over_zstd"]
            native_best_ratio = row["vort_native_best_over_zstd"]
            native_ratio = row["vort_native_over_zstd"]
            raw_ratio_text = "n/a" if not isinstance(raw_ratio, float) or raw_ratio < 0 else f"{raw_ratio:.4f}"
            native_best_ratio_text = "n/a" if not isinstance(native_best_ratio, float) or native_best_ratio < 0 else f"{native_best_ratio:.4f}"
            native_ratio_text = "n/a" if not isinstance(native_ratio, float) or native_ratio < 0 else f"{native_ratio:.4f}"
            zstd_decode = row["zstd_decode_mib_s"]
            raw_decode = row["vort_raw_fixed_decode_mib_s"]
            native_best_decode = row["vort_native_best_decode_mib_s"]
            native_decode = row["vort_native_decode_mib_s"]
            raw_decode_ratio = row["vort_decode_vs_zstd"]
            native_best_decode_ratio = row["vort_native_best_decode_vs_zstd"]
            native_decode_ratio = row["vort_native_decode_vs_zstd"]
            lines.append(
                f"| {('**TOTAL**' if row['path'] == 'TOTAL' else '`' + row['path'] + '`')} | {row['input_bytes']} | {row['zstd_bytes']} | {row['vort_raw_fixed_bytes']} | {row['vort_native_best_bytes']} | {row['vort_native_embedded_bytes']} | {raw_ratio_text} | {native_best_ratio_text} | {native_ratio_text} | {zstd_decode:.2f} | {raw_decode:.2f} | {native_best_decode:.2f} | {native_decode:.2f} | {raw_decode_ratio:.4f} | {native_best_decode_ratio:.4f} | {native_decode_ratio:.4f} |"
            )
        args.markdown.write_text("\n".join(lines) + "\n")


def main() -> int:
    args = parse_args()
    cli_items = cli_arg_count(args.items)
    if not ZSTD:
        print("zstd compare: zstd=missing")
        write_outputs(args, [], metadata(args, cli_items))
        return 0

    cli = pathlib.Path(args.items[0]) if cli_items else None
    path_args = args.items[cli_items:]
    cases = load_cases(args, path_args)

    rows: list[dict[str, Any]] = []
    meta = metadata(args, cli_items)
    print("path,input_bytes,zstd_bytes,vort_raw_fixed_bytes,vort_native_best_bytes,vort_native_embedded_bytes,zstd_decode_ms,vort_raw_fixed_decode_ms,vort_native_best_decode_ms,vort_native_decode_ms")
    for label, data in cases:
        with tempfile.TemporaryDirectory() as td:
            temp_dir = pathlib.Path(td)
            input_path = temp_dir / "sample.input"
            input_path.write_bytes(data)
            zstd_path = temp_dir / "sample.zst"
            subprocess.run([ZSTD, "-q", "-f", "-1", "-o", str(zstd_path), str(input_path)], check=True)
            zstd_size = zstd_path.stat().st_size
            zstd_decode_s = measure_zstd_decode(zstd_path, data, args.decode_repeats)

            vort_decode_s = -1.0
            vort_decode_mib_s = -1.0
            vort_decode_vs_zstd = -1.0
            native_best_size = -1
            native_best_decode_s = -1.0
            native_best_decode_mib_s = -1.0
            native_best_decode_vs_zstd = -1.0
            native_size = -1
            native_decode_s = -1.0
            native_decode_mib_s = -1.0
            native_decode_vs_zstd = -1.0
            zstd_decode_mib_s = mib_per_second(len(data), zstd_decode_s)

            if cli:
                raw_path = temp_dir / "sample.raw"
                subprocess.run(
                    [str(cli), "encode-raw-fixed-file", str(input_path), str(raw_path)],
                    cwd=ROOT,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                decoded_path = temp_dir / "sample.vort.out"
                vort_decode_s = measure_vort_raw_decode(cli, raw_path, decoded_path, data, args.decode_repeats)
                vort_size = raw_path.stat().st_size
                vort_decode_mib_s = mib_per_second(len(data), vort_decode_s)
                vort_decode_vs_zstd = vort_decode_mib_s / zstd_decode_mib_s if zstd_decode_mib_s > 0.0 else -1.0

                native_best_path = temp_dir / "sample.vort-best"
                subprocess.run(
                    [str(cli), "encode-vort-best-file", str(input_path), str(native_best_path)],
                    cwd=ROOT,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                native_best_size = native_best_path.stat().st_size
                native_best_decode_s = measure_vort_best_decode(cli, native_best_path, data, args.decode_repeats)
                native_best_decode_mib_s = mib_per_second(len(data), native_best_decode_s)
                native_best_decode_vs_zstd = native_best_decode_mib_s / zstd_decode_mib_s if zstd_decode_mib_s > 0.0 else -1.0

                native_path = temp_dir / "sample.vort"
                native_decoded_path = temp_dir / "sample.native.out"
                subprocess.run(
                    [str(cli), "encode-vort-embedded-best-file", str(input_path), str(native_path), str(args.native_block_len)],
                    cwd=ROOT,
                    check=True,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                native_size = native_path.stat().st_size
                native_decode_s = measure_vort_native_decode(cli, native_path, native_decoded_path, data, args.decode_repeats)
                native_decode_mib_s = mib_per_second(len(data), native_decode_s)
                native_decode_vs_zstd = native_decode_mib_s / zstd_decode_mib_s if zstd_decode_mib_s > 0.0 else -1.0
            else:
                vort_size = -1
                native_best_size = -1
        ratio = (vort_size / zstd_size) if zstd_size and vort_size >= 0 else -1.0
        native_best_ratio = (native_best_size / zstd_size) if zstd_size and native_best_size >= 0 else -1.0
        native_ratio = (native_size / zstd_size) if zstd_size and native_size >= 0 else -1.0
        rows.append(
            {
                "path": label,
                "input_bytes": len(data),
                "zstd_bytes": zstd_size,
                "vort_raw_fixed_bytes": vort_size,
                "vort_native_best_bytes": native_best_size,
                "vort_native_embedded_bytes": native_size,
                "vort_over_zstd": ratio,
                "vort_native_best_over_zstd": native_best_ratio,
                "vort_native_over_zstd": native_ratio,
                "zstd_decode_ms": zstd_decode_s * 1000.0,
                "vort_raw_fixed_decode_ms": vort_decode_s * 1000.0,
                "vort_native_best_decode_ms": native_best_decode_s * 1000.0,
                "vort_native_decode_ms": native_decode_s * 1000.0,
                "zstd_decode_mib_s": zstd_decode_mib_s,
                "vort_raw_fixed_decode_mib_s": vort_decode_mib_s,
                "vort_native_best_decode_mib_s": native_best_decode_mib_s,
                "vort_native_decode_mib_s": native_decode_mib_s,
                "vort_decode_vs_zstd": vort_decode_vs_zstd,
                "vort_native_best_decode_vs_zstd": native_best_decode_vs_zstd,
                "vort_native_decode_vs_zstd": native_decode_vs_zstd,
                "decode_repeats": args.decode_repeats,
                "native_block_len": args.native_block_len,
                **meta,
            }
        )
        print(f"{label},{len(data)},{zstd_size},{vort_size},{native_best_size},{native_size},{zstd_decode_s * 1000.0:.3f},{vort_decode_s * 1000.0:.3f},{native_best_decode_s * 1000.0:.3f},{native_decode_s * 1000.0:.3f}")

    if rows:
        total_input = sum(int(row["input_bytes"]) for row in rows)
        total_zstd = sum(int(row["zstd_bytes"]) for row in rows)
        total_vort = sum(int(row["vort_raw_fixed_bytes"]) for row in rows if int(row["vort_raw_fixed_bytes"]) >= 0)
        total_native_best = sum(int(row["vort_native_best_bytes"]) for row in rows if int(row["vort_native_best_bytes"]) >= 0)
        total_native = sum(int(row["vort_native_embedded_bytes"]) for row in rows if int(row["vort_native_embedded_bytes"]) >= 0)
        total_ratio = (total_vort / total_zstd) if total_zstd and total_vort >= 0 else -1.0
        total_native_best_ratio = (total_native_best / total_zstd) if total_zstd and total_native_best >= 0 else -1.0
        total_native_ratio = (total_native / total_zstd) if total_zstd and total_native >= 0 else -1.0
        total_zstd_decode_ms = sum(float(row["zstd_decode_ms"]) for row in rows)
        total_vort_decode_ms = sum(float(row["vort_raw_fixed_decode_ms"]) for row in rows)
        total_native_best_decode_ms = sum(float(row["vort_native_best_decode_ms"]) for row in rows)
        total_native_decode_ms = sum(float(row["vort_native_decode_ms"]) for row in rows)
        total_zstd_decode_mib_s = mib_per_second(total_input, total_zstd_decode_ms / 1000.0)
        total_vort_decode_mib_s = mib_per_second(total_input, total_vort_decode_ms / 1000.0)
        total_native_best_decode_mib_s = mib_per_second(total_input, total_native_best_decode_ms / 1000.0)
        total_native_decode_mib_s = mib_per_second(total_input, total_native_decode_ms / 1000.0)
        rows.append(
            {
                "path": "TOTAL",
                "input_bytes": total_input,
                "zstd_bytes": total_zstd,
                "vort_raw_fixed_bytes": total_vort,
                "vort_native_best_bytes": total_native_best,
                "vort_native_embedded_bytes": total_native,
                "vort_over_zstd": total_ratio,
                "vort_native_best_over_zstd": total_native_best_ratio,
                "vort_native_over_zstd": total_native_ratio,
                "zstd_decode_ms": total_zstd_decode_ms,
                "vort_raw_fixed_decode_ms": total_vort_decode_ms,
                "vort_native_best_decode_ms": total_native_best_decode_ms,
                "vort_native_decode_ms": total_native_decode_ms,
                "zstd_decode_mib_s": total_zstd_decode_mib_s,
                "vort_raw_fixed_decode_mib_s": total_vort_decode_mib_s,
                "vort_native_best_decode_mib_s": total_native_best_decode_mib_s,
                "vort_native_decode_mib_s": total_native_decode_mib_s,
                "vort_decode_vs_zstd": total_vort_decode_mib_s / total_zstd_decode_mib_s if total_zstd_decode_mib_s > 0.0 else -1.0,
                "vort_native_best_decode_vs_zstd": total_native_best_decode_mib_s / total_zstd_decode_mib_s if total_zstd_decode_mib_s > 0.0 else -1.0,
                "vort_native_decode_vs_zstd": total_native_decode_mib_s / total_zstd_decode_mib_s if total_zstd_decode_mib_s > 0.0 else -1.0,
                "decode_repeats": args.decode_repeats,
                "native_block_len": args.native_block_len,
                **meta,
            }
        )

    write_outputs(args, rows, meta)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
