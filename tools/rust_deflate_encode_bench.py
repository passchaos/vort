#!/usr/bin/env python3
"""Encode-throughput and size smoke for Vort vs Rust deflate baselines."""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap

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
    (workdir / "src" / "main.rs").write_text(
        textwrap.dedent(
            """
            use std::{env, fs, process, time::Instant};

            fn encode(engine: &str, input: &[u8]) -> Vec<u8> {
                match engine {
                    "fdeflate" => fdeflate::compress_to_vec(input),
                    "miniz_oxide" => miniz_oxide::deflate::compress_to_vec_zlib(input, 6),
                    _ => {
                        eprintln!("unknown engine: {engine}");
                        process::exit(2);
                    }
                }
            }

            fn main() {
                let args: Vec<String> = env::args().collect();
                if args.len() != 4 {
                    eprintln!("usage: <fdeflate|miniz_oxide> <input> <iterations>");
                    process::exit(2);
                }
                let engine = &args[1];
                let input = fs::read(&args[2]).expect("read input");
                let iterations: usize = args[3].parse().expect("iterations");
                drop(encode(engine, &input));
                let start = Instant::now();
                let mut mix: u64 = 0;
                let mut last_size: usize = 0;
                for _ in 0..iterations {
                    let encoded = encode(engine, &input);
                    last_size = encoded.len();
                    mix = mix.wrapping_add(encoded.len() as u64);
                    if let Some(first) = encoded.first() {
                        mix = mix.wrapping_add(u64::from(*first));
                    }
                }
                let elapsed_ns = start.elapsed().as_nanos();
                println!("elapsed_ns={elapsed_ns} zlib_bytes={last_size} mix={mix}");
            }
            """
        ).lstrip()
    )
    return workdir


def parse_fields(output: str) -> dict[str, int]:
    return {key: int(value) for key, value in (item.split("=", 1) for item in output.split())}


def run_rust(project: pathlib.Path, engine: str, input_path: pathlib.Path, iterations: int) -> dict[str, int]:
    out = subprocess.run(
        ["cargo", "run", "--release", "--quiet", "--", engine, str(input_path), str(iterations)],
        cwd=project,
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




def deterministic_noise(size: int) -> bytes:
    state = 0x1234ABCD
    out = bytearray(size)
    for i in range(size):
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFFFFFF
        out[i] = state & 0xFF
    return bytes(out)

def iterations_for(size: int) -> int:
    target = 16 * 1024 * 1024
    return max(32, min(5000, target // max(size, 1)))


def throughput_mib_s(size: int, iterations: int, elapsed_ns: int) -> float:
    seconds = elapsed_ns / 1_000_000_000
    mib = (size * iterations) / (1024 * 1024)
    return 0.0 if seconds == 0 else mib / seconds


def main() -> int:
    if shutil.which("cargo") is None:
        print("rust deflate encode benchmark: skipped cargo=missing")
        return 0
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        print(f"rust deflate encode benchmark: skipped missing={','.join(missing)}")
        return 0

    payloads = [
        ("tiny", b"hello rust deflate baselines"),
        ("repetitive", b"abcabcabcabc" * 512),
        ("overlap-rle", b"a" * (32 * 1024)),
        ("distance-heavy", (b"0123456789abcdef" * 1024) + b"----" + (b"0123456789abcdef" * 1024)),
        ("dynamic-literal", b"literal-heavy dynamic huffman decode stage\n" * 512),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 1024),
        ("binary", bytes((i * 131 + (i >> 3) * 17 + 29) & 0xFF for i in range(64 * 1024))),
        ("incompressible", deterministic_noise(64 * 1024)),
        ("readme", (ROOT / "README.md").read_bytes()),
        ("roadmap", (ROOT / "docs" / "roadmap.md").read_bytes()),
    ]
    output_rows = ["engine,case,input_bytes,zlib_bytes,ratio,iterations,elapsed_s,throughput_mib_s,mix"]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-encode-bench-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        project = write_runner(tmp / "runner")
        for name, payload in payloads:
            plain = tmp / f"{name}.bin"
            plain.write_bytes(payload)
            iterations = iterations_for(len(payload))
            rows = [
                ("vort-fastest", run_vort(plain, iterations, "fastest")),
                ("vort-fast", run_vort(plain, iterations, "fast")),
                ("vort-default", run_vort(plain, iterations, "default")),
                ("vort-dynamic-default", run_vort(plain, iterations, "dynamic-default")),
                ("vort-fixed-fast", run_vort(plain, iterations, "fixed-fast")),
            ]
            rows.extend((engine, run_rust(project, engine, plain, iterations)) for engine in ("fdeflate", "miniz_oxide"))
            for engine, fields in rows:
                output_rows.append(
                    f"{engine},{name},{len(payload)},{fields['zlib_bytes']},"
                    f"{fields['zlib_bytes'] / max(len(payload), 1):.4f},{iterations},"
                    f"{fields['elapsed_ns'] / 1_000_000_000:.6f},"
                    f"{throughput_mib_s(len(payload), iterations, fields['elapsed_ns']):.2f},{fields['mix']}"
                )
    for row in output_rows:
        print(row)
    if CSV_PATH is not None:
        CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
        CSV_PATH.write_text("\n".join(output_rows) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
