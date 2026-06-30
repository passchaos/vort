#!/usr/bin/env python3
"""Checksum differential smoke tests against Python zlib and local tools.

The Zig unit tests already compare Vort with Zig std. This harness exercises the
built Vort CLI as a black-box process and checks zlib-family checksum semantics:

* Adler-32 and IEEE CRC-32 against Python's zlib module;
* zlib wrapper trailer Adler-32 bytes produced by Python zlib;
* gzip trailer IEEE CRC-32 bytes produced by the system gzip CLI when available.
"""
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


def parse_field(output: str, name: str) -> int:
    match = re.search(rf"(?:^| ){re.escape(name)}=([^ ]*)", output)
    if not match:
        raise AssertionError(f"missing {name!r} in {output!r}")
    return int(match.group(1))


def assert_cli_checksum(label: str, data: bytes, output: str) -> None:
    assert parse_field(output, "input_bytes") == len(data), (label, output)
    assert parse_field(output, "adler32") == (zlib.adler32(data) & 0xFFFFFFFF), (label, output)
    assert parse_field(output, "crc32") == (zlib.crc32(data) & 0xFFFFFFFF), (label, output)


def main() -> int:
    if not CLI.exists():
        raise SystemExit(f"missing built CLI at {CLI}; run `zig build` first")

    payloads = [
        b"",
        b"a",
        b"abc",
        b"123456789",
        b"The quick brown fox jumps over the lazy dog",
        bytes((i * 131 + 17) & 0xFF for i in range(4099)),
    ]

    file_cases = 0
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td)
        text_cases = 0
        for index, data in enumerate(payloads):
            if data.isascii():
                text = data.decode("ascii")
                assert_cli_checksum(f"text-{index}", data, run_cli("checksum", text))
                text_cases += 1

            path = tmp / f"payload-{index}.bin"
            path.write_bytes(data)
            assert_cli_checksum(f"file-{index}", data, run_cli("checksum-file", str(path)))
            file_cases += 1

            zlib_frame = zlib.compress(data, level=1)
            assert int.from_bytes(zlib_frame[-4:], "big") == (zlib.adler32(data) & 0xFFFFFFFF)

            if GZIP:
                gzip_frame = subprocess.run([GZIP, "-n", "-1", "-c", str(path)], check=True, stdout=subprocess.PIPE).stdout
                assert int.from_bytes(gzip_frame[-8:-4], "little") == (zlib.crc32(data) & 0xFFFFFFFF)

    gzip_status = GZIP if GZIP else "missing"
    print(f"checksum zlib-family diff smoke: payloads={len(payloads)} text_cases={text_cases} file_cases={file_cases} gzip={gzip_status} cli={CLI}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
