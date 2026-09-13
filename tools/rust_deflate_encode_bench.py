#!/usr/bin/env python3
"""Encode-throughput and size smoke for Vort vs Rust deflate baselines.

Rows include both zlib-wrapped and raw DEFLATE encoders so wrapper/checksum
costs can be separated from the core LZ77/Huffman encode work.
"""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap

from benchmark_provenance import capture_composite, provenance_csv_values
from benchmark_provenance_gate import PROVENANCE_COLUMNS, PROVENANCE_V2_COLUMNS
from rust_deflate_benchmark_common import (
    FDEFLATE,
    MINIZ_OXIDE,
    ROOT,
    build_runner,
    payloads,
    write_if_changed,
)

DRIVER = pathlib.Path(__file__).resolve()
RUNNER_PROJECT = ROOT / ".zig-cache" / "vort-rust-deflate-encode-runner"
RUNNER_PACKAGE = "vort-rust-deflate-encode-bench"
ARGS = sys.argv[1:]
CSV_PATH = None
if "--csv" in ARGS:
    index = ARGS.index("--csv")
    CSV_PATH = pathlib.Path(ARGS[index + 1])
    del ARGS[index : index + 2]
REPEAT = 1
if "--repeat" in ARGS:
    index = ARGS.index("--repeat")
    REPEAT = int(ARGS[index + 1])
    if REPEAT <= 0:
        raise SystemExit("--repeat must be positive")
    del ARGS[index : index + 2]
VORT_BENCH = pathlib.Path(ARGS[0]) if ARGS else None


def write_runner(workdir: pathlib.Path) -> pathlib.Path:
    write_if_changed(
        workdir / "Cargo.toml",
        textwrap.dedent(
            f"""
            [package]
            name = "vort-rust-deflate-encode-bench"
            version = "0.0.0"
            edition = "2021"

            [dependencies]
            fdeflate = {{ path = "{FDEFLATE}" }}
            miniz_oxide = {{ path = "{MINIZ_OXIDE}" }}
            """
        ).strip()
        + "\n"
    )
    write_if_changed(
        workdir / "src" / "main.rs",
        textwrap.dedent(
            """
            use std::{env, fs, process, time::Instant};

            fn encode(engine: &str, format: &str, input: &[u8]) -> Vec<u8> {
                match (engine, format) {
                    ("fdeflate", "zlib") => fdeflate::compress_to_vec(input),
                    ("fdeflate", "raw") => {
                        let mut compressor = fdeflate::Compressor::new(Vec::with_capacity(input.len() / 4), 1, false).expect("fdeflate raw compressor");
                        compressor.write_data(input).expect("fdeflate raw write");
                        compressor.finish().expect("fdeflate raw finish")
                    },
                    ("miniz_oxide", "zlib") => miniz_oxide::deflate::compress_to_vec_zlib(input, 6),
                    ("miniz_oxide", "raw") => miniz_oxide::deflate::compress_to_vec(input, 6),
                    _ => {
                        eprintln!("unknown engine/format: {engine} {format}");
                        process::exit(2);
                    }
                }
            }

            fn main() {
                let args: Vec<String> = env::args().collect();
                if args.len() != 5 {
                    eprintln!("usage: <fdeflate|miniz_oxide> <zlib|raw> <input> <iterations>");
                    process::exit(2);
                }
                let engine = &args[1];
                let format = &args[2];
                let input = fs::read(&args[3]).expect("read input");
                let iterations: usize = args[4].parse().expect("iterations");
                drop(encode(engine, format, &input));
                let start = Instant::now();
                let mut mix: u64 = 0;
                let mut last_size: usize = 0;
                for _ in 0..iterations {
                    let encoded = encode(engine, format, &input);
                    last_size = encoded.len();
                    mix = mix.wrapping_add(encoded.len() as u64);
                    if let Some(first) = encoded.first() {
                        mix = mix.wrapping_add(u64::from(*first));
                    }
                }
                let elapsed_ns = start.elapsed().as_nanos();
                println!("elapsed_ns={elapsed_ns} frame_bytes={last_size} mix={mix}");
            }
            """
        ).lstrip()
    )
    return workdir


def parse_fields(output: str) -> dict[str, int]:
    return {key: int(value) for key, value in (item.split("=", 1) for item in output.split())}


def run_rust(executable: pathlib.Path, engine: str, fmt: str, input_path: pathlib.Path, iterations: int) -> dict[str, int]:
    out = subprocess.run(
        [str(executable), engine, fmt, str(input_path), str(iterations)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    return parse_fields(out)


def run_vort(input_path: pathlib.Path, iterations: int, level: str) -> dict[str, int]:
    if VORT_BENCH is None:
        raise RuntimeError("missing Vort zlib encode benchmark executable")
    out = subprocess.run(
        [str(VORT_BENCH), str(input_path), str(iterations), level],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    return parse_fields(out)

def iterations_for(size: int) -> int:
    target = 16 * 1024 * 1024
    return max(32, min(5000, target // max(size, 1)))


def iterations_for_vort_mode(size: int, mode: str) -> int:
    iterations = iterations_for(size)
    if mode == "best":
        # Vort's current best preset uses the optimal parser and can be orders
        # of magnitude slower than the production default/fast presets on real
        # text. Keep the row in the CSV for strongest-size tracking without
        # making the smoke benchmark impractically long.
        return max(1, min(iterations, 8))
    return iterations


def throughput_mib_s(size: int, iterations: int, elapsed_ns: int) -> float:
    seconds = elapsed_ns / 1_000_000_000
    mib = (size * iterations) / (1024 * 1024)
    return 0.0 if seconds == 0 else mib / seconds


def median_fields(run_once):
    results = [run_once() for _ in range(REPEAT)]
    results.sort(key=lambda item: item["elapsed_ns"])
    return results[len(results) // 2]


def main() -> int:
    if shutil.which("cargo") is None:
        message = "rust deflate encode benchmark: cargo is missing"
        if CSV_PATH is not None:
            print(message, file=sys.stderr)
            return 1
        print(message + "; skipped")
        return 0
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        message = f"rust deflate encode benchmark: missing={','.join(missing)}"
        if CSV_PATH is not None:
            print(message, file=sys.stderr)
            return 1
        print(message + "; skipped")
        return 0
    if VORT_BENCH is None or not VORT_BENCH.is_file():
        print("rust deflate encode benchmark: Vort artifact is missing", file=sys.stderr)
        return 1

    benchmark_payloads = payloads(encode=True)
    project = write_runner(RUNNER_PROJECT)
    runner = build_runner(project, RUNNER_PACKAGE)
    provenance = capture_composite(
        vort_executable=VORT_BENCH,
        driver=DRIVER,
        runner_project=project,
        runner_executable=runner,
        fdeflate=FDEFLATE,
        miniz_oxide=MINIZ_OXIDE,
        argv=[sys.executable, *sys.argv],
    )
    output_rows = ["engine,format,case,input_bytes,input_sha256,frame_bytes,ratio,iterations,repeat,elapsed_ns,elapsed_s,throughput_mib_s,mix," + ",".join(PROVENANCE_COLUMNS + PROVENANCE_V2_COLUMNS)]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-encode-inputs-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        for name, payload in benchmark_payloads:
            plain = tmp / f"{name}.bin"
            plain.write_bytes(payload)
            iterations = iterations_for(len(payload))
            rows = []
            for engine, mode in [
                ("vort-fastest", "fastest"),
                ("vort-fast", "fast"),
                ("vort-default", "default"),
                ("vort-best", "best"),
                ("vort-dynamic-default", "dynamic-default"),
                ("vort-dynamic-literal", "dynamic-literal-default"),
                ("vort-fixed-fast", "fixed-fast"),
                ("vort-split-default", "split-default"),
                ("vort-adaptive-default", "adaptive-default"),
            ]:
                mode_iterations = iterations_for_vort_mode(len(payload), mode)
                rows.append((engine, "zlib", mode_iterations, median_fields(lambda mode=mode, mode_iterations=mode_iterations: run_vort(plain, mode_iterations, mode))))
            for engine, mode in [
                ("vort-raw-fastest", "raw-fastest"),
                ("vort-raw-fast", "raw-fast"),
                ("vort-raw-default", "raw-default"),
                ("vort-raw-best", "raw-best"),
                ("vort-raw-dynamic-default", "raw-dynamic-default"),
                ("vort-raw-fixed-fast", "raw-fixed-fast"),
                ("vort-raw-split-default", "raw-split-default"),
                ("vort-raw-adaptive-default", "raw-adaptive-default"),
            ]:
                mode_iterations = iterations_for_vort_mode(len(payload), mode.removeprefix("raw-"))
                rows.append((engine, "raw", mode_iterations, median_fields(lambda mode=mode, mode_iterations=mode_iterations: run_vort(plain, mode_iterations, mode))))
            rows.extend((engine, "zlib", iterations, median_fields(lambda engine=engine: run_rust(runner, engine, "zlib", plain, iterations))) for engine in ("fdeflate", "miniz_oxide"))
            rows.extend((f"{engine}-raw", "raw", iterations, median_fields(lambda engine=engine: run_rust(runner, engine, "raw", plain, iterations))) for engine in ("fdeflate", "miniz_oxide"))
            input_sha256 = hashlib.sha256(payload).hexdigest()
            for engine, fmt, row_iterations, fields in rows:
                frame_bytes = fields.get("frame_bytes", fields.get("zlib_bytes"))
                output_rows.append(
                    f"{engine},{fmt},{name},{len(payload)},{input_sha256},{frame_bytes},"
                    f"{frame_bytes / max(len(payload), 1):.4f},{row_iterations},{REPEAT},{fields['elapsed_ns']},"
                    f"{fields['elapsed_ns'] / 1_000_000_000:.6f},"
                    f"{throughput_mib_s(len(payload), row_iterations, fields['elapsed_ns']):.2f},{fields['mix']}"
                    f",{provenance_csv_values(provenance)}"
                )
    if CSV_PATH is not None:
        CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
        CSV_PATH.write_text("\n".join(output_rows) + "\n")
    else:
        print("\n".join(output_rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
