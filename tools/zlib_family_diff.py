#!/usr/bin/env python3
"""Optional zlib-ng/zlib-rs differential harness.

This reports whether local competitor binaries are available and runs a small
round-trip check when they are. Missing binaries are reported as skipped instead
of silently passing as coverage.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "zig-out" / "bin" / "vort"

CANDIDATES = {
    "zlib-ng-minigzip": [
        pathlib.Path.home() / "Work" / "zlib-ng" / "build" / "minigzip",
        pathlib.Path.home() / "Work" / "zlib-ng" / "build" / "minigzip64",
        pathlib.Path.home() / "Work" / "zlib-ng" / "build" / "test" / "minigzip",
    ],
    "zlib-rs-compress-example": [
        pathlib.Path.home() / "Work" / "zlib-rs" / "target" / "release" / "examples" / "compress",
        pathlib.Path.home() / "Work" / "zlib-rs" / "target" / "debug" / "examples" / "compress",
    ],
}


def find_candidate(paths):
    for path in paths:
        if path.exists() and path.is_file():
            return path
    return None


def run_vort_decode(command: str, frame: bytes) -> int:
    out = subprocess.run([str(CLI), command, frame.hex()], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout
    marker = "decoded_bytes="
    return int(out.split(marker, 1)[1].split(" ", 1)[0])


def run_vort_decode_gzip(frame: bytes) -> int:
    return run_vort_decode("decode-gzip-hex", frame)


def run_vort_decode_zlib(frame: bytes) -> int:
    return run_vort_decode("decode-zlib-hex", frame)


def run_zlib_rs_corpus() -> tuple[int, int]:
    corpus_dir = pathlib.Path.home() / "Work" / "zlib-rs" / "test-libz-rs-sys" / "src" / "test-data" / "compression-corpus"
    if not corpus_dir.exists():
        return (0, 0)
    used = 0
    for gz in sorted(corpus_dir.glob("*.gz"))[:8]:
        frame = gz.read_bytes()
        expected = zlib.decompress(frame, wbits=31)
        assert run_vort_decode_gzip(frame) == len(expected)
        used += 1
    return (used, 0)


def check_vort_dynamic_outputs() -> int:
    payloads = [
        b"match-heavy:" + (b"abcabcabcabc" * 96) + (b"xyzxyzxyz" * 48),
        b"distance-heavy:" + (b"0123456789abcdef" * 512) + b"----" + (b"0123456789abcdef" * 64),
    ]
    for data in payloads:
        text = data.decode("ascii")
        raw_split = bytes.fromhex(subprocess.run([str(CLI), "encode-raw-best-split-hex", text, "257", "best"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
        assert zlib.decompress(raw_split, wbits=-15) == data
        zlib_frame = bytes.fromhex(subprocess.run([str(CLI), "encode-zlib-dynamic-hex", text, "default"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
        assert zlib.decompress(zlib_frame) == data
        zlib_split = bytes.fromhex(subprocess.run([str(CLI), "encode-zlib-best-split-hex", text, "257", "best"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
        assert zlib.decompress(zlib_split) == data
        gzip_frame = bytes.fromhex(subprocess.run([str(CLI), "encode-gzip-best-adaptive-hex", text, "best"], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE).stdout.strip())
        assert zlib.decompress(gzip_frame, wbits=31) == data
    return len(payloads)


def main() -> int:
    payload = b"zlib family differential payload" * 4
    print("zlib family differential harness:")
    used = 0
    for name, paths in CANDIDATES.items():
        exe = find_candidate(paths)
        if exe is None:
            print(f"- {name}: skipped (binary not built)")
            continue
        used += 1
        with tempfile.TemporaryDirectory() as td:
            src = pathlib.Path(td) / "payload.bin"
            src.write_bytes(payload)
            if name == "zlib-rs-compress-example":
                subprocess.run([str(exe), "1", "rs", str(src)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                frame = pathlib.Path(tempfile.gettempdir()) / "rs.txt"
                zdata = frame.read_bytes()
                assert zlib.decompress(zdata) == payload
                assert run_vort_decode_zlib(zdata) == len(payload)
            else:
                subprocess.run([str(exe), str(src)], check=True)
                gz = pathlib.Path(str(src) + ".gz").read_bytes()
                assert zlib.decompress(gz, wbits=31) == payload
                assert run_vort_decode_gzip(gz) == len(payload)
        print(f"- {name}: ok ({exe})")
    dynamic_used = check_vort_dynamic_outputs()
    print(f"- vort-dynamic-zlib-gzip-via-zlib: ok ({dynamic_used} payloads)")
    used += 1
    corpus_used, _ = run_zlib_rs_corpus()
    if corpus_used:
        print(f"- zlib-rs-gzip-corpus: ok ({corpus_used} files)")
        used += 1
    else:
        print("- zlib-rs-gzip-corpus: skipped (corpus missing)")
    print(f"zlib family differential summary: used={used} skipped={len(CANDIDATES)+2-used}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
