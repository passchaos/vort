#!/usr/bin/env python3
"""Black-box differential smoke against the system gzip CLI."""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "zig-out" / "bin" / "vort"
GZIP = shutil.which("gzip")


def run_cli(*args: str) -> str:
    result = subprocess.run([str(CLI), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
    return result.stdout.strip()


def parse_field(output: str, name: str) -> str:
    match = re.search(rf"(?:^| ){re.escape(name)}=([^ ]*)", output)
    if not match:
        raise AssertionError(f"missing {name!r} in {output!r}")
    return match.group(1)


def gzip_compress(data: bytes) -> bytes:
    if not GZIP:
        raise RuntimeError("gzip missing")
    with tempfile.TemporaryDirectory() as td:
        path = pathlib.Path(td) / "sample.bin"
        gz_path = pathlib.Path(str(path) + ".gz")
        path.write_bytes(data)
        subprocess.run([GZIP, "-n", "-1", str(path)], check=True)
        return gz_path.read_bytes()


def gzip_decompress(frame: bytes) -> bytes:
    if not GZIP:
        raise RuntimeError("gzip missing")
    result = subprocess.run([GZIP, "-dc"], input=frame, stdout=subprocess.PIPE, check=True)
    return result.stdout


def main() -> int:
    if not GZIP:
        print("gzip cli differential smoke: gzip=missing")
        return 0
    if not CLI.exists():
        raise SystemExit(f"missing built CLI at {CLI}; run `zig build` first")

    payloads = [b"", b"hello", b"hello vort", b"abcabcabcabc", b"the quick brown fox\n" * 8]
    for data in payloads:
        frame = gzip_compress(data)
        out = run_cli("decode-gzip-hex", frame.hex())
        assert int(parse_field(out, "decoded_bytes")) == len(data), out
        assert int(parse_field(out, "crc32")) == (zlib.crc32(data) & 0xFFFFFFFF), out

    # Vort fixed gzip known vector -> system gzip.
    vort_hello = bytes.fromhex("1f8b0800000000000403cb48cdc9c9070086a6103605000000")
    assert gzip_decompress(vort_hello) == b"hello"

    split_payloads = [
        b"",
        b"abcdefghijklmnopqrstuvwxyz",
        (b"abcabcabcabc" * 8) + b"----" + (b"the quick brown fox\n" * 4),
    ]
    for data in split_payloads:
        text = data.decode("ascii")
        frame = bytes.fromhex(run_cli("encode-gzip-best-split-hex", text, "17", "default"))
        assert gzip_decompress(frame) == data

    print(f"gzip cli differential smoke: payloads={len(payloads)} split_payloads={len(split_payloads)} gzip={GZIP} cli={CLI}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
