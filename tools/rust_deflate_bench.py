#!/usr/bin/env python3
"""Decode-throughput smoke for local Rust deflate baselines.

This is intentionally a small, reproducible smoke benchmark rather than a final
performance claim. It records fdeflate/miniz_oxide zlib and raw DEFLATE decode
throughput on the same generated frames so Vort can track the Rust baselines the
user requested while separating wrapper cost from the inflate core.
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


def run_bench(project: pathlib.Path, engine: str, fmt: str, frame: pathlib.Path, iterations: int) -> tuple[int, int]:
    out = subprocess.run(
        ["cargo", "run", "--release", "--quiet", "--", engine, fmt, str(frame), str(iterations)],
        cwd=project,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    fields = dict(item.split("=", 1) for item in out.split())
    return int(fields["elapsed_ns"]), int(fields["mix"])


def run_vort_bench(frame: pathlib.Path, iterations: int, mode: str = "alloc") -> tuple[int, int]:
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
        print("rust deflate decode benchmark: skipped cargo=missing")
        return 0
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        print(f"rust deflate decode benchmark: skipped missing={','.join(missing)}")
        return 0

    payloads = [
        ("tiny", b"hello rust deflate baselines"),
        ("repetitive", b"abcabcabcabc" * 512),
        ("overlap-rle", b"a" * (32 * 1024)),
        ("distance-heavy", (b"0123456789abcdef" * 1024) + b"----" + (b"0123456789abcdef" * 1024)),
        ("dynamic-match", b"literal-heavy dynamic huffman decode stage\n" * 512),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 1024),
        ("binary", bytes((i * 131 + (i >> 3) * 17 + 29) & 0xFF for i in range(64 * 1024))),
        ("stored-binary", bytes((i * 131 + (i >> 3) * 17 + 29) & 0xFF for i in range(64 * 1024))),
        ("readme", (ROOT / "README.md").read_bytes()),
        ("roadmap", (ROOT / "docs" / "roadmap.md").read_bytes()),
    ]
    output_rows = ["engine,format,case,input_bytes,frame_bytes,iterations,elapsed_s,throughput_mib_s,mix"]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-bench-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        project = write_runner(tmp / "runner")
        for name, payload in payloads:
            zlib_frame = tmp / f"{name}.zlib"
            zlib_frame.write_bytes(zlib.compress(payload, level=0 if name == "stored-binary" else 6))
            raw_frame = tmp / f"{name}.raw"
            raw_frame.write_bytes(raw_from_zlib(zlib_frame.read_bytes()))
            gzip_frame = tmp / f"{name}.gz"
            gzip_frame.write_bytes(zlib.compress(payload, level=0 if name == "stored-binary" else 6, wbits=31))
            iterations = iterations_for(len(payload))
            rows = [
                ("vort", "zlib", zlib_frame, run_vort_bench(zlib_frame, iterations)),
                ("vort-into", "zlib", zlib_frame, run_vort_bench(zlib_frame, iterations, "into")),
                ("vort-raw", "raw", raw_frame, run_vort_bench(raw_frame, iterations, "raw")),
                ("vort-raw-into", "raw", raw_frame, run_vort_bench(raw_frame, iterations, "raw-into")),
                ("vort-gzip", "gzip", gzip_frame, run_vort_bench(gzip_frame, iterations, "gzip")),
                ("vort-gzip-into", "gzip", gzip_frame, run_vort_bench(gzip_frame, iterations, "gzip-into")),
            ]
            rows.extend((engine, "zlib", zlib_frame, run_bench(project, engine, "zlib", zlib_frame, iterations)) for engine in ("fdeflate", "miniz_oxide"))
            rows.append(("miniz_oxide-raw", "raw", raw_frame, run_bench(project, "miniz_oxide", "raw", raw_frame, iterations)))
            for engine, fmt, frame, (elapsed_ns, mix) in rows:
                output_rows.append(
                    f"{engine},{fmt},{name},{len(payload)},{frame.stat().st_size},{iterations},"
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
