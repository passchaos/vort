#!/usr/bin/env python3
"""Decode-throughput smoke for local Rust deflate baselines.

This is intentionally a small, reproducible smoke benchmark rather than a final
performance claim. It records fdeflate/miniz_oxide zlib and raw DEFLATE decode
throughput on the same generated frames so Vort can track the Rust baselines the
user requested while separating wrapper cost from the inflate core.
"""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import zlib

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
RUNNER_PROJECT = ROOT / ".zig-cache" / "vort-rust-deflate-decode-runner"
RUNNER_PACKAGE = "vort-rust-deflate-bench"
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


def write_runner(workdir):
    write_if_changed(
        workdir / "Cargo.toml",
        textwrap.dedent(
            f"""
            [package]
            name = "vort-rust-deflate-bench"
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

            fn decode(engine: &str, format: &str, frame: &[u8]) -> Vec<u8> {
                match (engine, format) {
                    ("fdeflate", "zlib") => fdeflate::decompress_to_vec(frame).expect("fdeflate decode"),
                    ("fdeflate", "raw") => {
                        // fdeflate's public inflater in this checkout is zlib-framed. The
                        // Python harness therefore omits a raw fdeflate row instead of
                        // pretending to benchmark a private/internal raw API.
                        eprintln!("fdeflate raw inflate unsupported by public API");
                        process::exit(2);
                    }
                    ("miniz_oxide", "zlib") => miniz_oxide::inflate::decompress_to_vec_zlib(frame).expect("miniz_oxide decode"),
                    ("miniz_oxide", "raw") => miniz_oxide::inflate::decompress_to_vec(frame).expect("miniz_oxide raw decode"),
                    _ => {
                        eprintln!("unknown engine/format: {engine} {format}");
                        process::exit(2);
                    }
                }
            }

            fn main() {
                let args: Vec<String> = env::args().collect();
                if args.len() != 5 {
                    eprintln!("usage: <fdeflate|miniz_oxide> <zlib|raw> <frame> <iterations>");
                    process::exit(2);
                }
                let engine = &args[1];
                let format = &args[2];
                let frame = fs::read(&args[3]).expect("read frame");
                let iterations: usize = args[4].parse().expect("iterations");
                drop(decode(engine, format, &frame));
                let start = Instant::now();
                let mut mix: u64 = 0;
                for _ in 0..iterations {
                    let decoded = decode(engine, format, &frame);
                    mix = mix.wrapping_add(decoded.len() as u64);
                    if let Some(first) = decoded.first() {
                        mix = mix.wrapping_add(u64::from(*first));
                    }
                }
                let elapsed_ns = start.elapsed().as_nanos();
                println!("elapsed_ns={elapsed_ns} mix={mix}");
            }
            """
        ).lstrip()
    )
    return workdir


def run_bench(executable, engine: str, fmt: str, frame, iterations: int) -> tuple[int, int]:
    out = subprocess.run(
        [str(executable), engine, fmt, str(frame), str(iterations)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    fields = dict(item.split("=", 1) for item in out.split())
    return int(fields["elapsed_ns"]), int(fields["mix"])


def run_vort_bench(frame, iterations: int, mode: str = "alloc") -> tuple[int, int]:
    if VORT_BENCH is None:
        raise RuntimeError("missing Vort zlib decode benchmark executable")
    out = subprocess.run(
        [str(VORT_BENCH), str(frame), str(iterations), mode],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    fields = dict(item.split("=", 1) for item in out.split())
    return int(fields["elapsed_ns"]), int(fields["mix"])


def iterations_for(size: int) -> int:
    target = 32 * 1024 * 1024
    return max(64, min(10_000, target // max(size, 1)))


def throughput_mib_s(size: int, iterations: int, elapsed_ns: int) -> float:
    seconds = elapsed_ns / 1_000_000_000
    mib = (size * iterations) / (1024 * 1024)
    return 0.0 if seconds == 0 else mib / seconds


def median_result(run_once):
    results = [run_once() for _ in range(REPEAT)]
    results.sort(key=lambda item: item[0])
    return results[len(results) // 2]


def raw_from_zlib(frame: bytes) -> bytes:
    if len(frame) < 6:
        raise AssertionError(f"zlib frame too short: {len(frame)}")
    cmf, flg = frame[0], frame[1]
    if (cmf & 0x0F) != 8 or ((cmf << 8) + flg) % 31 != 0:
        raise AssertionError(f"bad generated zlib header: {frame[:2].hex()}")
    if flg & 0x20:
        raise AssertionError("benchmark zlib frames must not require dictionaries")
    return frame[2:-4]


def main() -> int:
    if shutil.which("cargo") is None:
        message = "rust deflate decode benchmark: cargo is missing"
        if CSV_PATH is not None:
            print(message, file=sys.stderr)
            return 1
        print(message + "; skipped")
        return 0
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        message = f"rust deflate decode benchmark: missing={','.join(missing)}"
        if CSV_PATH is not None:
            print(message, file=sys.stderr)
            return 1
        print(message + "; skipped")
        return 0
    if VORT_BENCH is None or not VORT_BENCH.is_file():
        print("rust deflate decode benchmark: Vort artifact is missing", file=sys.stderr)
        return 1

    benchmark_payloads = payloads(encode=False)
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
        extra_environment={
            "python_zlib_compile_version": zlib.ZLIB_VERSION,
            "python_zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
            "rust_result_allocator": "rust-global-default",
            "vort_result_allocator": "std.heap.c_allocator",
        },
    )
    output_rows = ["engine,format,case,input_bytes,input_sha256,frame_bytes,iterations,repeat,elapsed_ns,elapsed_s,throughput_mib_s,mix," + ",".join(PROVENANCE_COLUMNS + PROVENANCE_V2_COLUMNS)]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-bench-inputs-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        for name, payload in benchmark_payloads:
            zlib_frame = tmp / f"{name}.zlib"
            zlib_frame.write_bytes(zlib.compress(payload, level=0 if name == "stored-binary" else 6))
            raw_frame = tmp / f"{name}.raw"
            raw_frame.write_bytes(raw_from_zlib(zlib_frame.read_bytes()))
            gzip_frame = tmp / f"{name}.gz"
            gzip_frame.write_bytes(zlib.compress(payload, level=0 if name == "stored-binary" else 6, wbits=31))
            iterations = iterations_for(len(payload))
            rows = [
                ("vort", "zlib", zlib_frame, median_result(lambda: run_vort_bench(zlib_frame, iterations))),
                ("vort-into", "zlib", zlib_frame, median_result(lambda: run_vort_bench(zlib_frame, iterations, "into"))),
                ("vort-exact", "zlib", zlib_frame, median_result(lambda: run_vort_bench(zlib_frame, iterations, "zlib-exact"))),
                ("vort-raw", "raw", raw_frame, median_result(lambda: run_vort_bench(raw_frame, iterations, "raw"))),
                ("vort-raw-into", "raw", raw_frame, median_result(lambda: run_vort_bench(raw_frame, iterations, "raw-into"))),
                ("vort-raw-exact", "raw", raw_frame, median_result(lambda: run_vort_bench(raw_frame, iterations, "raw-exact"))),
                ("vort-gzip", "gzip", gzip_frame, median_result(lambda: run_vort_bench(gzip_frame, iterations, "gzip"))),
                ("vort-gzip-exact", "gzip", gzip_frame, median_result(lambda: run_vort_bench(gzip_frame, iterations, "gzip-exact"))),
                ("vort-gzip-into", "gzip", gzip_frame, median_result(lambda: run_vort_bench(gzip_frame, iterations, "gzip-into"))),
            ]
            rows.extend((engine, "zlib", zlib_frame, median_result(lambda engine=engine: run_bench(runner, engine, "zlib", zlib_frame, iterations))) for engine in ("fdeflate", "miniz_oxide"))
            rows.append(("miniz_oxide-raw", "raw", raw_frame, median_result(lambda: run_bench(runner, "miniz_oxide", "raw", raw_frame, iterations))))
            input_sha256 = hashlib.sha256(payload).hexdigest()
            for engine, fmt, frame, (elapsed_ns, mix) in rows:
                output_rows.append(
                    f"{engine},{fmt},{name},{len(payload)},{input_sha256},{frame.stat().st_size},{iterations},{REPEAT},{elapsed_ns},"
                    f"{elapsed_ns / 1_000_000_000:.6f},{throughput_mib_s(len(payload), iterations, elapsed_ns):.2f},{mix}"
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
