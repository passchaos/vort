#!/usr/bin/env python3
"""Bidirectional ZIP32 stored/deflate compatibility test with Python zipfile."""

from __future__ import annotations

import argparse
import io
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path


class NonSeekableBuffer(io.BytesIO):
    def seekable(self) -> bool:
        return False

    def seek(self, *args: object, **kwargs: object) -> int:
        raise io.UnsupportedOperation("non-seekable ZIP fixture")


def run(program: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def validate_python_archive_with_vort(cli: Path, temp: Path) -> int:
    payloads = {
        "stored.bin": bytes(range(64)) + b"\x00stored\xff",
        "folder/deflated.txt": b"Vort ZIP deflate differential.\n" * 256,
        "utf8-目录/数据.txt": "ZIP UTF-8 文件名\n".encode() * 17,
        "empty/": b"",
    }
    sink = NonSeekableBuffer()
    with zipfile.ZipFile(sink, "w", allowZip64=False) as archive:
        archive.comment = b"vort zip differential"
        archive.writestr("stored.bin", payloads["stored.bin"], compress_type=zipfile.ZIP_STORED)
        archive.writestr(
            "folder/deflated.txt",
            payloads["folder/deflated.txt"],
            compress_type=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        )
        archive.writestr(
            "utf8-目录/数据.txt",
            payloads["utf8-目录/数据.txt"],
            compress_type=zipfile.ZIP_DEFLATED,
            compresslevel=1,
        )
        directory = zipfile.ZipInfo("empty/")
        directory.external_attr = 0o40775 << 16
        archive.writestr(directory, b"", compress_type=zipfile.ZIP_STORED)
    fixture = sink.getvalue()
    zip_path = temp / "python-fixture.zip"
    zip_path.write_bytes(fixture)

    listing = run(cli, "list-zip-file", str(zip_path)).stdout
    if "zip_entries=4" not in listing:
        raise AssertionError(f"unexpected ZIP listing header: {listing}")
    for name in payloads:
        if f"name={name}" not in listing:
            raise AssertionError(f"ZIP listing omitted {name!r}: {listing}")

    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"python-output-{index}.bin"
        run(cli, "extract-zip-file", str(zip_path), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort extraction mismatch for {name!r}")
    return len(fixture)


def validate_vort_archive_with_python(cli: Path, writer: Path, temp: Path) -> int:
    payloads = {
        "stored.bin": bytes([0, 1, 2, 255]) + b"stored by Vort",
        "folder/deflated.txt": b"Vort ZIP writer differential.\n" * 128,
        "utf8-目录/数据.txt": "ZIP UTF-8 文件名\n".encode() * 17,
        "empty/": b"",
    }
    first = temp / "vort-first.zip"
    second = temp / "vort-second.zip"
    run(writer, str(first))
    run(writer, str(second))
    raw = first.read_bytes()
    if raw != second.read_bytes():
        raise AssertionError("Vort ZIP writer output is not deterministic")
    if not raw.startswith(b"MZ-VORT-ZIP-PREFIX\n"):
        raise AssertionError("Vort ZIP append prefix was not preserved")

    with zipfile.ZipFile(first) as archive:
        if archive.comment != b"vort zip writer differential":
            raise AssertionError("Vort archive comment mismatch")
        if archive.namelist() != list(payloads):
            raise AssertionError(f"unexpected Vort entry order: {archive.namelist()!r}")
        if archive.testzip() is not None:
            raise AssertionError("Python reported a corrupt Vort entry")
        for index, (name, expected) in enumerate(payloads.items()):
            info = archive.getinfo(name)
            if archive.read(info) != expected:
                raise AssertionError(f"Python extraction mismatch for {name!r}")
            if info.date_time != (1980, 1, 1, 0, 0, 0):
                raise AssertionError(f"non-deterministic timestamp for {name!r}")
            if not info.flag_bits & 0x0008:
                raise AssertionError(f"data-descriptor flag omitted for {name!r}")
            if not info.flag_bits & 0x0800:
                raise AssertionError(f"UTF-8 flag omitted for {name!r}")
            expected_method = zipfile.ZIP_STORED if index in (0, 3) else zipfile.ZIP_DEFLATED
            if info.compress_type != expected_method:
                raise AssertionError(f"compression method mismatch for {name!r}")

            local_flags = struct.unpack_from("<H", raw, info.header_offset + 6)[0]
            local_crc, local_compressed, local_uncompressed = struct.unpack_from(
                "<III", raw, info.header_offset + 14
            )
            name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
            data_offset = info.header_offset + 30 + name_len + extra_len
            descriptor_offset = data_offset + info.compress_size
            if local_flags & 0x0008 == 0 or (local_crc, local_compressed, local_uncompressed) != (0, 0, 0):
                raise AssertionError(f"invalid local descriptor fields for {name!r}")
            if raw[descriptor_offset : descriptor_offset + 4] != b"PK\x07\x08":
                raise AssertionError(f"descriptor signature omitted for {name!r}")

    listing = run(cli, "list-zip-file", str(first)).stdout
    if "zip_entries=4" not in listing:
        raise AssertionError(f"Vort could not list its generated archive: {listing}")
    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"vort-output-{index}.bin"
        run(cli, "extract-zip-file", str(first), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort self-extraction mismatch for {name!r}")
    return len(raw)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="vort-zip-diff-") as temp_text:
        temp = Path(temp_text)
        python_bytes = validate_python_archive_with_vort(args.cli, temp)
        vort_bytes = validate_vort_archive_with_python(args.cli, args.writer, temp)

    print(f"zip_diff=ok directions=2 entries=4 python_bytes={python_bytes} vort_bytes={vort_bytes}")


if __name__ == "__main__":
    main()
