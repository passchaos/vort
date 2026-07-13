#!/usr/bin/env python3
"""Decode-throughput smoke for local Rust deflate baselines.

This is intentionally a small, reproducible smoke benchmark rather than a final
performance claim. It records fdeflate/miniz_oxide zlib decode throughput on the
same generated frames so Vort can track the Rust baselines the user requested.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ARGS = sys.argv[1:]
CSV_PATH = None
if "--csv" in ARGS:
    index = ARGS.index("--csv")
    CSV_PATH = pathlib.Path(ARGS[index + 1])
    del ARGS[index : index + 2]
VORT_BENCH = pathlib.Path(ARGS[0]) if ARGS else None
FDEFLATE = pathlib.Path.home() / "Work" / "fdeflate"
MINIZ_OXIDE = pathlib.Path.home() / "Work" / "miniz_oxide" / "miniz_oxide"


def write_runner(workdir: pathlib.Path) -> pathlib.Path:
    (workdir / "src").mkdir(parents=True)
    (workdir / "Cargo.toml").write_text(
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
    (workdir / "src" / "main.rs").write_text(
        textwrap.dedent(
            """
            use std::{env, fs, process, time::Instant};

            fn main() {
                let args: Vec<String> = env::args().collect();
                if args.len() != 4 {
                    eprintln!("usage: <fdeflate|miniz_oxide> <zlib-frame> <iterations>");
                    process::exit(2);
                }
                let engine = &args[1];
                let frame = fs::read(&args[2]).expect("read frame");
                let iterations: usize = args[3].parse().expect("iterations");
                let warmup = match engine.as_str() {
                    "fdeflate" => fdeflate::decompress_to_vec(&frame).expect("fdeflate decode"),
                    "miniz_oxide" => miniz_oxide::inflate::decompress_to_vec_zlib(&frame).expect("miniz_oxide decode"),
                    _ => {
                        eprintln!("unknown engine: {engine}");
                        process::exit(2);
                    }
                };
                drop(warmup);
                let start = Instant::now();
                let mut mix: u64 = 0;
                for _ in 0..iterations {
                    let decoded = match engine.as_str() {
                        "fdeflate" => fdeflate::decompress_to_vec(&frame).expect("fdeflate decode"),
                        "miniz_oxide" => miniz_oxide::inflate::decompress_to_vec_zlib(&frame).expect("miniz_oxide decode"),
                        _ => {
                            eprintln!("unknown engine: {engine}");
                            process::exit(2);
                        }
                    };
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


def run_bench(project: pathlib.Path, engine: str, frame: pathlib.Path, iterations: int) -> tuple[int, int]:
    out = subprocess.run(
        ["cargo", "run", "--release", "--quiet", "--", engine, str(frame), str(iterations)],
        cwd=project,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    fields = dict(item.split("=", 1) for item in out.split())
    return int(fields["elapsed_ns"]), int(fields["mix"])


def run_vort_bench(frame: pathlib.Path, iterations: int) -> tuple[int, int]:
    if VORT_BENCH is None:
        raise RuntimeError("missing Vort zlib decode benchmark executable")
    out = subprocess.run(
        [str(VORT_BENCH), str(frame), str(iterations)],
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


def main() -> int:
    if shutil.which("cargo") is None:
        print("rust deflate decode benchmark: skipped cargo=missing")
        return 0
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        print(f"rust deflate decode benchmark: skipped missing={','.join(missing)}")
        return 0

    payloads = [
        ("tiny", b"hello rust deflate baselines"),
        ("repetitive", b"abcabcabcabc" * 512),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 1024),
        ("binary", bytes((i * 131 + (i >> 3) * 17 + 29) & 0xFF for i in range(64 * 1024))),
    ]
    output_rows = ["engine,case,input_bytes,zlib_bytes,iterations,elapsed_s,throughput_mib_s,mix"]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-bench-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        project = write_runner(tmp / "runner")
        for name, payload in payloads:
            frame = tmp / f"{name}.zlib"
            frame.write_bytes(zlib.compress(payload, level=6))
            iterations = iterations_for(len(payload))
            rows = [("vort", run_vort_bench(frame, iterations))]
            rows.extend((engine, run_bench(project, engine, frame, iterations)) for engine in ("fdeflate", "miniz_oxide"))
            for engine, (elapsed_ns, mix) in rows:
                output_rows.append(
                    f"{engine},{name},{len(payload)},{frame.stat().st_size},{iterations},"
                    f"{elapsed_ns / 1_000_000_000:.6f},{throughput_mib_s(len(payload), iterations, elapsed_ns):.2f},{mix}"
                )
    for row in output_rows:
        print(row)
    if CSV_PATH is not None:
        CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
        CSV_PATH.write_text("\n".join(output_rows) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
