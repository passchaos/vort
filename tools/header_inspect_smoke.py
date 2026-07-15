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
    dictionary = b"hello "
    dict_payload = b"hello hello hello"
    dict_compressor = zlib.compressobj(level=6, wbits=zlib.MAX_WBITS, zdict=dictionary)
    zlib_dict_frame = dict_compressor.compress(dict_payload) + dict_compressor.flush()
    # This member carries FEXTRA, FNAME, FCOMMENT, and FHCRC over a raw fixed
    # deflate "hello" payload. Keeping the bytes literal makes the smoke stable
    # across Python gzip header policy changes while still exercising Vort's
    # optional-header parser and FHCRC validator through the CLI.
    gzip_optional_frame = bytes.fromhex(
        "1f8b081e0000000000030400616263646e616d6500636f6d6d656e7400"
        "e248cb48cdc9c9070086a6103605000000"
    )

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
    zlib_dict_hex = run(cli, "inspect-zlib-header-hex", zlib_dict_frame.hex())
    require_fields(
        zlib_dict_hex,
        {
            "zlib_header compressed_bytes": str(len(zlib_dict_frame)),
            "data_offset": "6",
            "method": "8",
            "window_bits": "15",
            "fdict": "true",
            "dictid": str(zlib.adler32(dictionary) & 0xFFFFFFFF),
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
    gzip_optional_hex = run(cli, "inspect-gzip-header-hex", gzip_optional_frame.hex())
    require_fields(
        gzip_optional_hex,
        {
            "gzip_header compressed_bytes": str(len(gzip_optional_frame)),
            "data_offset": "31",
            "flags": "0x1e",
            "extra_present": "true",
            "extra_len": "4",
            "extra_hex": "61626364",
            "filename": '"name"',
            "comment": '"comment"',
            "header_crc": "18658",
        },
    )

    with tempfile.TemporaryDirectory(prefix="vort-header-inspect-") as tmp:
        tmp_path = Path(tmp)
        zlib_path = tmp_path / "sample.zlib"
        zlib_dict_path = tmp_path / "sample-dict.zlib"
        gzip_path = tmp_path / "sample.gz"
        gzip_optional_path = tmp_path / "sample-options.gz"
        zlib_path.write_bytes(zlib_frame)
        zlib_dict_path.write_bytes(zlib_dict_frame)
        gzip_path.write_bytes(gzip_frame)
        gzip_optional_path.write_bytes(gzip_optional_frame)

        zlib_file = run(cli, "inspect-zlib-header-file", str(zlib_path))
        zlib_dict_file = run(cli, "inspect-zlib-header-file", str(zlib_dict_path))
        gzip_file = run(cli, "inspect-gzip-header-file", str(gzip_path))
        gzip_optional_file = run(cli, "inspect-gzip-header-file", str(gzip_optional_path))
        if zlib_file != zlib_hex:
            raise AssertionError(f"zlib file/hex inspection mismatch: {zlib_file!r} != {zlib_hex!r}")
        if zlib_dict_file != zlib_dict_hex:
            raise AssertionError(f"zlib dict file/hex inspection mismatch: {zlib_dict_file!r} != {zlib_dict_hex!r}")
        if gzip_file != gzip_hex:
            raise AssertionError(f"gzip file/hex inspection mismatch: {gzip_file!r} != {gzip_hex!r}")
        if gzip_optional_file != gzip_optional_hex:
            raise AssertionError(f"gzip optional file/hex inspection mismatch: {gzip_optional_file!r} != {gzip_optional_hex!r}")

    print("header inspect smoke: zlib=ok zlib_dict=ok gzip=ok gzip_optional=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
