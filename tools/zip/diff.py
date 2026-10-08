#!/usr/bin/env python3
"""Bidirectional ZIP32/ZIP64 stored/deflate compatibility with Python zipfile."""

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
        "python-force-zip64.bin": b"Python force_zip64 member\n" * 31,
        "empty/": b"",
    }
    sink = NonSeekableBuffer()
    with zipfile.ZipFile(sink, "w", allowZip64=True) as archive:
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
        zip64_info = zipfile.ZipInfo("python-force-zip64.bin")
        zip64_info.compress_type = zipfile.ZIP_DEFLATED
        with archive.open(zip64_info, "w", force_zip64=True) as member:
            member.write(payloads["python-force-zip64.bin"])
        directory = zipfile.ZipInfo("empty/")
        directory.external_attr = 0o40775 << 16
        archive.writestr(directory, b"", compress_type=zipfile.ZIP_STORED)
    fixture = sink.getvalue()
    zip_path = temp / "python-fixture.zip"
    zip_path.write_bytes(fixture)

    listing = run(cli, "list-zip-file", str(zip_path)).stdout
    if f"zip_entries={len(payloads)}" not in listing:
        raise AssertionError(f"unexpected ZIP listing header: {listing}")
    if "zip64=false" not in listing:
        raise AssertionError(f"Python fixture unexpectedly used a ZIP64 EOCD: {listing}")
    for name in payloads:
        if f"name={name}" not in listing:
            raise AssertionError(f"ZIP listing omitted {name!r}: {listing}")

    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"python-output-{index}.bin"
        run(cli, "extract-zip-file", str(zip_path), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort extraction mismatch for {name!r}")
    local_offset = fixture.index(b"python-force-zip64.bin") - 30
    local_name_len = struct.unpack_from("<H", fixture, local_offset + 26)[0]
    local_extra_len = struct.unpack_from("<H", fixture, local_offset + 28)[0]
    local_extra_offset = local_offset + 30 + local_name_len
    if local_extra_len < 20 or not fixture[local_extra_offset : local_extra_offset + local_extra_len].startswith(
        b"\x01\x00\x10\x00"
    ):
        raise AssertionError("Python force_zip64 fixture omitted the ZIP64 local extra")
    return len(fixture)


def validate_vort_archive_with_python(
    cli: Path, writer: Path, temp: Path, force_zip64: bool
) -> int:
    payloads = {
        "stored.bin": bytes([0, 1, 2, 255]) + b"stored by Vort",
        "folder/deflated.txt": b"Vort ZIP writer differential.\n" * 128,
        "utf8-目录/数据.txt": "ZIP UTF-8 文件名\n".encode() * 17,
        "empty/": b"",
    }
    suffix = "zip64" if force_zip64 else "zip32"
    first = temp / f"vort-{suffix}-first.zip"
    second = temp / f"vort-{suffix}-second.zip"
    writer_args = (str(first), "zip64") if force_zip64 else (str(first),)
    second_args = (str(second), "zip64") if force_zip64 else (str(second),)
    run(writer, *writer_args)
    run(writer, *second_args)
    raw = first.read_bytes()
    if raw != second.read_bytes():
        raise AssertionError("Vort ZIP writer output is not deterministic")
    if not raw.startswith(b"MZ-VORT-ZIP-PREFIX\n"):
        raise AssertionError("Vort ZIP append prefix was not preserved")
    has_zip64_end = b"PK\x06\x06" in raw and b"PK\x06\x07" in raw
    if has_zip64_end != force_zip64:
        raise AssertionError(f"unexpected ZIP64 end-record state for {suffix}")

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
            if force_zip64 and info.extract_version < 45:
                raise AssertionError(f"ZIP64 version-needed omitted for {name!r}")

            local_flags = struct.unpack_from("<H", raw, info.header_offset + 6)[0]
            local_crc, local_compressed, local_uncompressed = struct.unpack_from(
                "<III", raw, info.header_offset + 14
            )
            name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
            data_offset = info.header_offset + 30 + name_len + extra_len
            descriptor_offset = data_offset + info.compress_size
            expected_local_sizes = (0xFFFFFFFF, 0xFFFFFFFF) if force_zip64 else (0, 0)
            if local_flags & 0x0008 == 0 or local_crc != 0 or (local_compressed, local_uncompressed) != expected_local_sizes:
                raise AssertionError(f"invalid local descriptor fields for {name!r}")
            if raw[descriptor_offset : descriptor_offset + 4] != b"PK\x07\x08":
                raise AssertionError(f"descriptor signature omitted for {name!r}")
            if force_zip64:
                descriptor_crc, descriptor_compressed, descriptor_uncompressed = struct.unpack_from(
                    "<IQQ", raw, descriptor_offset + 4
                )
            else:
                descriptor_crc, descriptor_compressed, descriptor_uncompressed = struct.unpack_from(
                    "<III", raw, descriptor_offset + 4
                )
            if (descriptor_crc, descriptor_compressed, descriptor_uncompressed) != (
                info.CRC,
                info.compress_size,
                info.file_size,
            ):
                raise AssertionError(f"descriptor values mismatch for {name!r}")

    listing = run(cli, "list-zip-file", str(first)).stdout
    if "zip_entries=4" not in listing:
        raise AssertionError(f"Vort could not list its generated archive: {listing}")
    expected_zip64 = str(force_zip64).lower()
    if f"zip64={expected_zip64}" not in listing:
        raise AssertionError(f"Vort ZIP64 metadata mismatch: {listing}")
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
        vort_zip32_bytes = validate_vort_archive_with_python(args.cli, args.writer, temp, False)
        vort_zip64_bytes = validate_vort_archive_with_python(args.cli, args.writer, temp, True)

    print(
        "zip_diff=ok directions=2 "
        f"python_entries=5 vort_entries=4 python_bytes={python_bytes} "
        f"vort_zip32_bytes={vort_zip32_bytes} vort_zip64_bytes={vort_zip64_bytes}"
    )


if __name__ == "__main__":
    main()
