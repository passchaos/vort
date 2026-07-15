#!/usr/bin/env python3
"""Smoke-test Vort zlib/gzip header inspection CLI commands."""

import gzip
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


def run(cli: str, *args: str) -> str:
    return subprocess.check_output([cli, *args], text=True).strip()


def require_fields(output: str, fields: dict[str, str]) -> None:
    for key, value in fields.items():
        needle = f"{key}={value}"
        if needle not in output:
            raise AssertionError(f"missing {needle!r} in {output!r}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <vort-cli>", file=sys.stderr)
        return 2

    cli = argv[1]
    payload = b"hello"
    zlib_frame = zlib.compress(payload, level=6)
    gzip_frame = gzip.compress(payload, compresslevel=6, mtime=0)

    zlib_hex = run(cli, "inspect-zlib-header-hex", zlib_frame.hex())
    require_fields(
        zlib_hex,
        {
            "zlib_header compressed_bytes": str(len(zlib_frame)),
            "data_offset": "2",
            "method": "8",
            "window_bits": "15",
            "window_size": "32768",
            "fdict": "false",
            "dictid": "null",
        },
    )

    gzip_hex = run(cli, "inspect-gzip-header-hex", gzip_frame.hex())
    require_fields(
        gzip_hex,
        {
            "gzip_header compressed_bytes": str(len(gzip_frame)),
            "data_offset": "10",
            "flags": "0x00",
            "text": "false",
            "mtime": "0",
            "extra_present": "false",
            "filename": "null",
            "comment": "null",
            "header_crc": "null",
        },
    )

    with tempfile.TemporaryDirectory(prefix="vort-header-inspect-") as tmp:
        tmp_path = Path(tmp)
        zlib_path = tmp_path / "sample.zlib"
        gzip_path = tmp_path / "sample.gz"
        zlib_path.write_bytes(zlib_frame)
        gzip_path.write_bytes(gzip_frame)

        zlib_file = run(cli, "inspect-zlib-header-file", str(zlib_path))
        gzip_file = run(cli, "inspect-gzip-header-file", str(gzip_path))
        if zlib_file != zlib_hex:
            raise AssertionError(f"zlib file/hex inspection mismatch: {zlib_file!r} != {zlib_hex!r}")
        if gzip_file != gzip_hex:
            raise AssertionError(f"gzip file/hex inspection mismatch: {gzip_file!r} != {gzip_hex!r}")

    print("header inspect smoke: zlib=ok gzip=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
