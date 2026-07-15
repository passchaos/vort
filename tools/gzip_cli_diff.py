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


def expect_cli_failure(*args: str, error_name: str) -> None:
    result = subprocess.run([str(CLI), *args], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode == 0:
        raise AssertionError(f"expected {args!r} to fail with {error_name}, got stdout={result.stdout!r}")
    if error_name not in result.stderr:
        raise AssertionError(f"expected {error_name} in stderr for {args!r}, got stderr={result.stderr!r}")


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

    expect_cli_failure("decode-gzip-hex", "", error_name="TruncatedFrame")
    expect_cli_failure("decode-gzip-hex", "1f8b0800000000000403", error_name="TruncatedFrame")

    payloads = [b"", b"hello", b"hello vort", b"abcabcabcabc", b"the quick brown fox\n" * 8]
    for data in payloads:
        frame = gzip_compress(data)
        out = run_cli("decode-gzip-hex", frame.hex())
        assert int(parse_field(out, "decoded_bytes")) == len(data), out
        assert int(parse_field(out, "crc32")) == (zlib.crc32(data) & 0xFFFFFFFF), out
        with tempfile.TemporaryDirectory(prefix="vort-gzip-file-", dir=ROOT / ".zig-cache") as tmpdir:
            tmp = pathlib.Path(tmpdir)
            compressed_path = tmp / "sample.gz"
            decoded_path = tmp / "sample.out"
            limited_path = tmp / "sample-limited.out"
            compressed_path.write_bytes(frame)
            out = run_cli("decode-gzip-file", str(compressed_path), str(decoded_path))
            assert int(parse_field(out, "decoded_bytes")) == len(data), out
            assert decoded_path.read_bytes() == data, out
            out = run_cli("decode-gzip-file", str(compressed_path), str(limited_path), str(len(data)))
            assert int(parse_field(out, "decoded_bytes")) == len(data), out
            assert limited_path.read_bytes() == data, out
            if data:
                expect_cli_failure("decode-gzip-file", str(compressed_path), str(tmp / "too-small.out"), str(len(data) - 1), error_name="OutputLimitExceeded")

    concatenated = gzip_compress(b"hello ") + gzip_compress(b"world")
    concatenated_plain = b"hello world"
    with tempfile.TemporaryDirectory(prefix="vort-gzip-cat-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        compressed_path = tmp / "cat.gz"
        decoded_path = tmp / "cat.out"
        limited_path = tmp / "cat-limited.out"
        compressed_path.write_bytes(concatenated)
        out = run_cli("decode-gzip-file", str(compressed_path), str(decoded_path))
        assert int(parse_field(out, "decoded_bytes")) == len(concatenated_plain), out
        assert decoded_path.read_bytes() == concatenated_plain, out
        out = run_cli("decode-gzip-file", str(compressed_path), str(limited_path), str(len(concatenated_plain)))
        assert int(parse_field(out, "decoded_bytes")) == len(concatenated_plain), out
        assert limited_path.read_bytes() == concatenated_plain, out
        expect_cli_failure("decode-gzip-file", str(compressed_path), str(tmp / "cat-too-small.out"), str(len(concatenated_plain) - 1), error_name="OutputLimitExceeded")
        empty_path = tmp / "empty.gz"
        empty_path.write_bytes(b"")
        expect_cli_failure("decode-gzip-file", str(empty_path), str(tmp / "empty.out"), error_name="TruncatedFrame")
        header_only_path = tmp / "header-only.gz"
        header_only_path.write_bytes(bytes.fromhex("1f8b0800000000000403"))
        expect_cli_failure("decode-gzip-file", str(header_only_path), str(tmp / "header-only.out"), error_name="TruncatedFrame")

    # Vort fixed gzip known vector -> system gzip.
    vort_hello = bytes.fromhex("1f8b0800000000000403cb48cdc9c9070086a6103605000000")
    assert gzip_decompress(vort_hello) == b"hello"

    split_payloads = [
        b"",
        b"abcdefghijklmnopqrstuvwxyz",
        (b"abcabcabcabc" * 8) + b"----" + (b"the quick brown fox\n" * 4),
        (b"abcabcabcabc" * 64) + b"----" + (b"abcabcabcabc" * 16),
        (b"0123456789abcdef" * 128) + b"tail" + (b"0123456789abcdef" * 16),
    ]
    for data in split_payloads:
        text = data.decode("ascii")
        frame = bytes.fromhex(run_cli("encode-gzip-best-split-hex", text, "17", "default"))
        assert gzip_decompress(frame) == data

    dynamic_payloads = [
        b"match-heavy:" + (b"abcabcabcabc" * 96) + (b"xyzxyzxyz" * 48),
        b"distance-heavy:" + (b"0123456789abcdef" * 512) + b"----" + (b"0123456789abcdef" * 64),
        (b"lorem ipsum dolor sit amet\n" * 32) + (b"A" * 511) + (b"lorem ipsum dolor sit amet\n" * 32),
    ]
    for data in dynamic_payloads:
        text = data.decode("ascii")
        frame = bytes.fromhex(run_cli("encode-gzip-dynamic-hex", text, "default"))
        assert gzip_decompress(frame) == data
        adaptive = bytes.fromhex(run_cli("encode-gzip-best-adaptive-hex", text, "best"))
        assert gzip_decompress(adaptive) == data

    print(f"gzip cli differential smoke: payloads={len(payloads)} split_payloads={len(split_payloads)} dynamic_payloads={len(dynamic_payloads)} gzip={GZIP} cli={CLI}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
