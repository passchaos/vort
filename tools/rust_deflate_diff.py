#!/usr/bin/env python3
"""Differential smoke against local Rust deflate baselines.

The user-provided long-term target includes surpassing `fdeflate` and
`miniz_oxide`. This harness turns the local source checkouts under `~/Work`
into executable evidence: Rust-generated zlib/raw deflate streams must decode
through Vort, Vort-generated zlib frames must decode through both Rust
implementations, and the raw deflate payload inside Vort zlib frames must
decode through Rust implementations that expose raw inflate APIs.
"""
import pathlib
import subprocess
import sys
import tempfile
import textwrap

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "zig-out" / "bin" / "vort"
FDEFLATE = pathlib.Path.home() / "Work" / "fdeflate"
MINIZ_OXIDE = pathlib.Path.home() / "Work" / "miniz_oxide" / "miniz_oxide"


def run_cli(*args: str) -> str:
    return subprocess.run([str(CLI), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def write_runner(workdir: pathlib.Path) -> pathlib.Path:
    (workdir / "src").mkdir(parents=True)
    (workdir / "Cargo.toml").write_text(
        textwrap.dedent(
            f"""
            [package]
            name = "vort-rust-deflate-diff"
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
            use std::{env, fs, process};

            fn main() {
                let args: Vec<String> = env::args().collect();
                if args.len() != 5 {
                    eprintln!("usage: <fdeflate|miniz_oxide> <compress-zlib|decompress-zlib|compress-raw|decompress-raw> <input> <output>");
                    process::exit(2);
                }
                let engine = &args[1];
                let op = &args[2];
                let input = fs::read(&args[3]).expect("read input");
                let output = match (engine.as_str(), op.as_str()) {
                    ("fdeflate", "compress-zlib") => fdeflate::compress_to_vec(&input),
                    ("fdeflate", "decompress-zlib") => fdeflate::decompress_to_vec(&input).expect("fdeflate decode"),
                    ("fdeflate", "compress-raw") => {
                        // fdeflate's public convenience helpers are zlib-wrapped, but the
                        // streaming compressor can intentionally omit the zlib header/footer.
                        let mut compressor = fdeflate::Compressor::new(Vec::with_capacity(input.len() / 4), 1, false).expect("fdeflate raw compressor");
                        compressor.write_data(&input).expect("fdeflate raw write");
                        compressor.finish().expect("fdeflate raw finish")
                    },
                    ("miniz_oxide", "compress-zlib") => miniz_oxide::deflate::compress_to_vec_zlib(&input, 6),
                    ("miniz_oxide", "decompress-zlib") => miniz_oxide::inflate::decompress_to_vec_zlib(&input).expect("miniz_oxide decode"),
                    ("miniz_oxide", "compress-raw") => miniz_oxide::deflate::compress_to_vec(&input, 6),
                    ("miniz_oxide", "decompress-raw") => miniz_oxide::inflate::decompress_to_vec(&input).expect("miniz_oxide raw decode"),
                    _ => {
                        eprintln!("unknown engine/op: {engine} {op}");
                        process::exit(2);
                    }
                };
                fs::write(&args[4], output).expect("write output");
            }
            """
        ).lstrip()
    )
    return workdir


def cargo_run(project: pathlib.Path, engine: str, op: str, input_path: pathlib.Path, output_path: pathlib.Path) -> None:
    subprocess.run(
        ["cargo", "run", "--quiet", "--", engine, op, str(input_path), str(output_path)],
        cwd=project,
        check=True,
    )


def write_raw_from_vort_zlib(zlib_path: pathlib.Path, raw_path: pathlib.Path) -> None:
    frame = zlib_path.read_bytes()
    if len(frame) < 6:
        raise AssertionError(f"Vort zlib frame too short: {len(frame)} bytes")
    cmf, flg = frame[0], frame[1]
    if (cmf & 0x0F) != 8 or ((cmf << 8) + flg) % 31 != 0:
        raise AssertionError(f"Vort zlib header is not RFC1950 deflate: {frame[:2].hex()}")
    if flg & 0x20:
        raise AssertionError("Vort non-dictionary zlib encode unexpectedly set FDICT")
    raw_path.write_bytes(frame[2:-4])


def main() -> int:
    if not CLI.exists():
        raise SystemExit(f"missing built CLI at {CLI}; run `zig build` first")
    missing = [str(path) for path in (FDEFLATE, MINIZ_OXIDE) if not path.exists()]
    if missing:
        print(f"rust deflate differential smoke: skipped missing={','.join(missing)}")
        return 0

    payloads = [
        b"",
        b"hello rust deflate baselines",
        b"abcabcabcabc" * 16,
        (b"the quick brown fox jumps over the lazy dog\n" * 32) + (b"A" * 257),
        bytes(range(256)) * 2,
    ]
    with tempfile.TemporaryDirectory(prefix="vort-rust-deflate-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        project = write_runner(tmp / "runner")
        engines = ("fdeflate", "miniz_oxide")
        used = 0
        for i, payload in enumerate(payloads):
            plain = tmp / f"plain-{i}.bin"
            plain.write_bytes(payload)
            vort_zlib = tmp / f"vort-{i}.zlib"
            vort_raw = tmp / f"vort-{i}.raw"
            run_cli("encode-zlib-best-file", str(plain), str(vort_zlib), "default")
            write_raw_from_vort_zlib(vort_zlib, vort_raw)
            for engine in engines:
                rust_zlib = tmp / f"{engine}-{i}.zlib"
                rust_raw = tmp / f"{engine}-{i}.raw"
                rust_plain = tmp / f"{engine}-{i}.plain"
                rust_raw_plain = tmp / f"{engine}-{i}.raw.plain"
                vort_decoded = tmp / f"vort-from-{engine}-{i}.plain"
                vort_raw_decoded = tmp / f"vort-from-{engine}-{i}.raw.plain"

                cargo_run(project, engine, "compress-zlib", plain, rust_zlib)
                run_cli("decode-zlib-file", str(rust_zlib), str(vort_decoded), str(len(payload)))
                assert vort_decoded.read_bytes() == payload, (engine, i, "rust->vort")

                cargo_run(project, engine, "decompress-zlib", vort_zlib, rust_plain)
                assert rust_plain.read_bytes() == payload, (engine, i, "vort->rust")
                used += 2

                cargo_run(project, engine, "compress-raw", plain, rust_raw)
                run_cli("decode-raw-file", str(rust_raw), str(vort_raw_decoded), str(len(payload)))
                assert vort_raw_decoded.read_bytes() == payload, (engine, i, "rust raw->vort")
                used += 1

                # fdeflate's public decompressor is zlib-framed; miniz_oxide exposes
                # a raw inflate helper, so it verifies Vort's wrapper-independent
                # deflate payload in the opposite direction.
                if engine == "miniz_oxide":
                    cargo_run(project, engine, "decompress-raw", vort_raw, rust_raw_plain)
                    assert rust_raw_plain.read_bytes() == payload, (engine, i, "vort raw->rust")
                    used += 1

    print(f"rust deflate differential smoke: engines=2 payloads={len(payloads)} checks={used}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
