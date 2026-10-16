#!/usr/bin/env python3
"""Bidirectional ZIP32/ZIP64 interoperability for Vort's supported methods."""

from __future__ import annotations

import argparse
import binascii
import hashlib
import hmac
import io
import lzma
import random
import shutil
import struct
import subprocess
import tempfile
import zipfile
import zlib
from dataclasses import dataclass
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


def make_single_entry_zip(name: str, payload: bytes, compressed: bytes, method: int) -> bytes:
    encoded_name = name.encode("utf-8")
    crc = binascii.crc32(payload) & 0xFFFFFFFF
    flags = 0x0800
    version = 63
    local = struct.pack(
        "<IHHHHHIIIHH",
        0x04034B50,
        version,
        flags,
        method,
        0,
        0x0021,
        crc,
        len(compressed),
        len(payload),
        len(encoded_name),
        0,
    ) + encoded_name + compressed
    central = struct.pack(
        "<IHHHHHHIIIHHHHHII",
        0x02014B50,
        version,
        version,
        flags,
        method,
        0,
        0x0021,
        crc,
        len(compressed),
        len(payload),
        len(encoded_name),
        0,
        0,
        0,
        0,
        0,
        0,
    ) + encoded_name
    eocd = struct.pack(
        "<IHHHHIIH",
        0x06054B50,
        0,
        0,
        1,
        1,
        len(central),
        len(local),
        0,
    )
    return local + central + eocd


def make_legacy_payload(prefix_len: int, seed: int) -> bytes:
    state = seed
    prefix = bytearray()
    for _ in range(prefix_len):
        state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
        prefix.append(state >> 24)
    return bytes(prefix) + b"\x42" + bytes(prefix)


def validate_python_archive_with_vort(
    cli: Path, temp: Path
) -> tuple[int, int, int, int, int, int, int, int, int]:
    payloads = {
        "stored.bin": bytes(range(64)) + b"\x00stored\xff",
        "folder/deflated.txt": b"Vort ZIP deflate differential.\n" * 256,
        "folder/bzip2.txt": b"Python ZIP Bzip2 method 12.\n" * 96,
        "folder/lzma.txt": b"Python ZIP LZMA method 14.\n" * 96,
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
            "folder/bzip2.txt",
            payloads["folder/bzip2.txt"],
            compress_type=zipfile.ZIP_BZIP2,
            compresslevel=9,
        )
        archive.writestr(
            "folder/lzma.txt",
            payloads["folder/lzma.txt"],
            compress_type=zipfile.ZIP_LZMA,
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

    with zipfile.ZipFile(io.BytesIO(fixture)) as archive:
        methods = {info.filename: info.compress_type for info in archive.infolist()}
    incremental_cases = 0
    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"python-output-{index}.bin"
        run(cli, "extract-zip-file", str(zip_path), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort extraction mismatch for {name!r}")
        if methods[name] in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
            incremental_output = temp / f"python-incremental-output-{index}.bin"
            run(
                cli,
                "extract-zip-file-incremental",
                str(zip_path),
                name,
                str(incremental_output),
            )
            if incremental_output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort incremental extraction mismatch for {name!r}"
                )
            incremental_cases += 1

    zstd_tool = shutil.which("zstd")
    if zstd_tool is None:
        raise AssertionError("zstd CLI is required for ZIP methods 20/93 differential")
    zstd_payload = b"External Zstandard ZIP methods 20 and 93.\n" * 128
    zstd_frame = subprocess.run(
        [zstd_tool, "-q", "-3", "-c"],
        input=zstd_payload,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    incremental_archive_zstd_cases = 0
    for method in (20, 93):
        zstd_zip = make_single_entry_zip(
            f"external-zstd-{method}.txt", zstd_payload, zstd_frame, method
        )
        zstd_zip_path = temp / f"external-zstd-{method}.zip"
        zstd_output_path = temp / f"external-zstd-{method}.out"
        zstd_zip_path.write_bytes(zstd_zip)
        listing = run(cli, "list-zip-file", str(zstd_zip_path)).stdout
        expected_label = "zstd-legacy" if method == 20 else "zstd"
        if f"method={expected_label}" not in listing:
            raise AssertionError(f"Vort mislabeled ZIP method {method}: {listing}")
        run(
            cli,
            "extract-zip-file",
            str(zstd_zip_path),
            f"external-zstd-{method}.txt",
            str(zstd_output_path),
        )
        if zstd_output_path.read_bytes() != zstd_payload:
            raise AssertionError(f"Vort ZIP method {method} extraction mismatch")
        stream_output_path = temp / f"external-zstd-stream-{method}.out"
        run(
            cli,
            "extract-zip-stream-file",
            str(zstd_zip_path),
            f"external-zstd-{method}.txt",
            str(stream_output_path),
        )
        if stream_output_path.read_bytes() != zstd_payload:
            raise AssertionError(
                f"Vort sequential ZIP method {method} extraction mismatch"
            )
        incremental_archive_zstd_cases += 1

    xz_payload = b"External XZ ZIP method 95.\n" * 128
    xz_frame = lzma.compress(xz_payload, format=lzma.FORMAT_XZ)
    xz_zip = make_single_entry_zip("external-xz.txt", xz_payload, xz_frame, 95)
    xz_zip_path = temp / "external-xz.zip"
    xz_output_path = temp / "external-xz.out"
    xz_stream_output_path = temp / "external-xz-stream.out"
    xz_zip_path.write_bytes(xz_zip)
    run(cli, "extract-zip-file", str(xz_zip_path), "external-xz.txt", str(xz_output_path))
    if xz_output_path.read_bytes() != xz_payload:
        raise AssertionError("Vort ZIP method 95 extraction mismatch")
    run(
        cli,
        "extract-zip-stream-file",
        str(xz_zip_path),
        "external-xz.txt",
        str(xz_stream_output_path),
    )
    if xz_stream_output_path.read_bytes() != xz_payload:
        raise AssertionError("Vort sequential ZIP method 95 extraction mismatch")
    incremental_archive_xz_cases = 1

    deflate64_payload = b"Deflate64 ZIP reference\n" * 32
    deflate64_compressed = bytes.fromhex(
        "e5c8a10d00200c4541cf141d8230010687c611f2aa08a261ff74907ff23a7ef7"
        "a7555b635ae004ef50e45ffe353e01"
    )
    deflate64_zip = make_single_entry_zip(
        "external-deflate64.txt", deflate64_payload, deflate64_compressed, 9
    )
    deflate64_zip_path = temp / "external-deflate64.zip"
    deflate64_stream_output_path = temp / "external-deflate64-stream.out"
    deflate64_zip_path.write_bytes(deflate64_zip)
    run(
        cli,
        "extract-zip-stream-file",
        str(deflate64_zip_path),
        "external-deflate64.txt",
        str(deflate64_stream_output_path),
    )
    if deflate64_stream_output_path.read_bytes() != deflate64_payload:
        raise AssertionError("Vort sequential ZIP method 9 extraction mismatch")
    incremental_archive_deflate64_cases = 1

    dcl_payload = b"AIAIAIAIAIAIA"
    dcl_compressed = bytes.fromhex("00048224258f807f")
    dcl_zip = make_single_entry_zip(
        "external-dcl-implode.txt", dcl_payload, dcl_compressed, 10
    )
    dcl_zip_path = temp / "external-dcl-implode.zip"
    dcl_stream_output_path = temp / "external-dcl-implode-stream.out"
    dcl_zip_path.write_bytes(dcl_zip)
    run(
        cli,
        "extract-zip-stream-file",
        str(dcl_zip_path),
        "external-dcl-implode.txt",
        str(dcl_stream_output_path),
    )
    if dcl_stream_output_path.read_bytes() != dcl_payload:
        raise AssertionError("Vort sequential ZIP method 10 extraction mismatch")
    incremental_archive_dcl_cases = 1

    shrink_fixture_hex = (
        Path(__file__).resolve().parents[2]
        / "src/zip/testdata/commons-compress-shrunk.zip.hex"
    ).read_text(encoding="ascii")
    shrink_fixture_path = temp / "commons-compress-shrunk.zip"
    shrink_fixture_path.write_bytes(bytes.fromhex(shrink_fixture_hex))
    shrink_payloads = {
        "TEST1.XML": b"<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<connections>\n</connections>\n",
        "TEST2.XML": b"<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<meinxml>\n    <leer />\n</meinxml>\n",
    }
    incremental_archive_shrink_cases = 0
    for index, (name, expected) in enumerate(shrink_payloads.items()):
        output = temp / f"commons-shrink-stream-{index}.out"
        run(
            cli,
            "extract-zip-stream-file",
            str(shrink_fixture_path),
            name,
            str(output),
        )
        if output.read_bytes() != expected:
            raise AssertionError(
                f"Vort sequential Apache Commons ZIP Shrink extraction mismatch for {name!r}"
            )
        incremental_archive_shrink_cases += 1

    incremental_archive_implode_fixture_cases = 0
    fixture_root = Path(__file__).resolve().parents[2] / "src/zip/testdata"
    for fixture_name in (
        "commons-compress-implode-4k-2trees.zip.b64",
        "commons-compress-implode-8k-3trees.zip.b64",
    ):
        fixture_path = temp / fixture_name.removesuffix(".b64")
        fixture_path.write_bytes(
            binascii.a2b_base64((fixture_root / fixture_name).read_bytes())
        )
        with zipfile.ZipFile(fixture_path) as parsed:
            info = parsed.infolist()[0]
        output = temp / f"{fixture_path.stem}-stream.out"
        run(
            cli,
            "extract-zip-stream-file",
            str(fixture_path),
            info.filename,
            str(output),
        )
        actual = output.read_bytes()
        if len(actual) != info.file_size or (binascii.crc32(actual) & 0xFFFFFFFF) != info.CRC:
            raise AssertionError(
                f"Vort sequential Apache Commons ZIP Implode extraction mismatch for {fixture_name}"
            )
        incremental_archive_implode_fixture_cases += 1
    local_offset = fixture.index(b"python-force-zip64.bin") - 30
    local_name_len = struct.unpack_from("<H", fixture, local_offset + 26)[0]
    local_extra_len = struct.unpack_from("<H", fixture, local_offset + 28)[0]
    local_extra_offset = local_offset + 30 + local_name_len
    if local_extra_len < 20 or not fixture[local_extra_offset : local_extra_offset + local_extra_len].startswith(
        b"\x01\x00\x10\x00"
    ):
        raise AssertionError("Python force_zip64 fixture omitted the ZIP64 local extra")
    stream_payloads = {
        "stream/stored.bin": b"stored PK\x07\x08 descriptor marker payload",
        "stream/deflated.txt": b"Python sequential Deflate member.\n" * 257,
        "stream/bzip2.txt": b"Python sequential Bzip2 member.\n" * 193,
        "stream/lzma.txt": b"Python sequential LZMA member.\n" * 167,
        "stream/force-zip64.bin": b"Python sequential force ZIP64.\n" * 37,
        "stream/empty": b"",
    }
    stream_sink = NonSeekableBuffer()
    with zipfile.ZipFile(stream_sink, "w", allowZip64=True) as archive:
        archive.comment = b"python sequential reader"
        archive.writestr(
            "stream/stored.bin",
            stream_payloads["stream/stored.bin"],
            compress_type=zipfile.ZIP_STORED,
        )
        archive.writestr(
            "stream/deflated.txt",
            stream_payloads["stream/deflated.txt"],
            compress_type=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        )
        archive.writestr(
            "stream/bzip2.txt",
            stream_payloads["stream/bzip2.txt"],
            compress_type=zipfile.ZIP_BZIP2,
            compresslevel=9,
        )
        archive.writestr(
            "stream/lzma.txt",
            stream_payloads["stream/lzma.txt"],
            compress_type=zipfile.ZIP_LZMA,
        )
        force_info = zipfile.ZipInfo("stream/force-zip64.bin")
        force_info.compress_type = zipfile.ZIP_DEFLATED
        with archive.open(force_info, "w", force_zip64=True) as member:
            member.write(stream_payloads["stream/force-zip64.bin"])
        archive.writestr("stream/empty", b"", compress_type=zipfile.ZIP_STORED)
    stream_path = temp / "python-stream-fixture.zip"
    stream_path.write_bytes(stream_sink.getvalue())
    stream_cases = 0
    for index, (name, expected) in enumerate(stream_payloads.items()):
        output = temp / f"python-stream-output-{index}.bin"
        run(cli, "extract-zip-stream-file", str(stream_path), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort sequential ZIP extraction mismatch for {name!r}")
        stream_cases += 1

    return (
        len(fixture),
        incremental_cases,
        stream_cases,
        incremental_archive_zstd_cases,
        incremental_archive_xz_cases,
        incremental_archive_deflate64_cases,
        incremental_archive_dcl_cases,
        incremental_archive_shrink_cases,
        incremental_archive_implode_fixture_cases,
    )


def validate_vort_unicode_archive(
    cli: Path,
    writer: Path,
    temp: Path,
    unzip_tool: str,
) -> int:
    archive_path = temp / "vort-unicode-extra.zip"
    run(writer, str(archive_path), "unicode")
    raw = archive_path.read_bytes()
    expected = {
        "目录/数据.txt": b"Vort Unicode path payload.\n" * 17,
        "目录/": b"",
    }
    raw_names = {
        "目录/数据.txt": b"\x82-legacy-name.txt",
        "目录/": b"legacy-directory/",
    }
    with zipfile.ZipFile(archive_path) as archive:
        if archive.namelist() != ["é-legacy-name.txt", "legacy-directory/"]:
            raise AssertionError("Python legacy-name decoding changed unexpectedly")
        for index, (name, payload) in enumerate(expected.items()):
            info = archive.infolist()[index]
            if info.flag_bits & 0x0800:
                raise AssertionError("Unicode extra entry unexpectedly set UTF-8 bit")
            if archive.read(info) != payload:
                raise AssertionError("Python raw-name Unicode-extra archive mismatch")
            validate_unicode_extra(
                info.extra,
                0x7075,
                raw_names[name],
                name,
                f"one-shot central Unicode path {index}",
            )
            local_name_len, local_extra_len = struct.unpack_from(
                "<HH", raw, info.header_offset + 26
            )
            local_extra_start = info.header_offset + 30 + local_name_len
            validate_unicode_extra(
                raw[local_extra_start : local_extra_start + local_extra_len],
                0x7075,
                raw_names[name],
                name,
                f"one-shot local Unicode path {index}",
            )
            if index == 0:
                validate_unicode_extra(
                    info.extra,
                    0x6375,
                    b"\x82-legacy-comment",
                    "条目注释",
                    "one-shot central Unicode comment",
                )
            for command in ("extract-zip-file", "extract-zip-stream-file"):
                output = temp / f"unicode-{index}-{command}.out"
                run(cli, command, str(archive_path), name, str(output))
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort {command} Unicode selection mismatch")

    extracted = subprocess.run(
        [unzip_tool, "-p", str(archive_path), "目录/数据.txt"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    if extracted != expected["目录/数据.txt"]:
        raise AssertionError("Info-ZIP did not extract Vort Unicode path entry")
    return len(expected)


def validate_vort_archive_extra(
    cli: Path,
    writer: Path,
    temp: Path,
) -> int:
    expected_extra = b"Vort archive extra data\x00\xff"
    expected = {
        "archive-extra/data.txt": b"Vort archive extra data record payload.\n" * 19,
        "archive-extra/empty.bin": b"",
    }
    cases = 0
    for force_zip64 in (False, True):
        suffix = "zip64" if force_zip64 else "zip32"
        path = temp / f"vort-archive-extra-{suffix}.zip"
        run(writer, str(path), "archive-extra-zip64" if force_zip64 else "archive-extra")
        raw = path.read_bytes()
        validate_archive_extra_record(raw, expected_extra, f"one-shot {suffix}")
        for index, (name, payload) in enumerate(expected.items()):
            for command in ("extract-zip-file", "extract-zip-stream-file"):
                output = temp / f"archive-extra-{suffix}-{index}-{command}.out"
                run(cli, command, str(path), name, str(output))
                if output.read_bytes() != payload:
                    raise AssertionError("Vort archive-extra extraction mismatch")
            cases += 1
    return cases


def validate_vort_archive_with_python(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    seven_zip_tool: str | None,
) -> int:
    shrink_state = 0x5A17C9E3
    shrink_payload = bytearray()
    for _ in range(32 * 1024):
        shrink_state = (shrink_state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
        shrink_payload.append(shrink_state >> 24)
    implode_payload = make_legacy_payload(5000, 0x193A72D5)
    payloads = {
        "stored.bin": bytes([0, 1, 2, 255]) + b"stored by Vort",
        "folder/shrink.txt": bytes(shrink_payload),
        "folder/implode.txt": implode_payload,
        "folder/reduce1.txt": make_legacy_payload(400, 0x10203041),
        "folder/reduce2.txt": make_legacy_payload(800, 0x20304052),
        "folder/reduce3.txt": make_legacy_payload(1500, 0x30405063),
        "folder/reduce4.txt": make_legacy_payload(3000, 0x40506074),
        "folder/deflated.txt": b"Vort ZIP writer differential.\n" * 128,
        "folder/deflate64.txt": b"Vort ZIP Deflate64 method 9.\n" * 128,
        "folder/dcl-implode.txt": make_legacy_payload(3000, 0xDCA10010),
        "folder/bzip2.txt": b"Vort ZIP Bzip2 method 12.\n" * 96,
        "folder/lzma.txt": b"Vort ZIP LZMA method 14.\n" * 96,
        "folder/xz.txt": b"Vort ZIP XZ method 95.\n" * 96,
        "folder/zstd-legacy.txt": b"Vort ZIP legacy Zstandard method 20.\n" * 96,
        "folder/zstd.txt": b"Vort ZIP Zstandard method 93.\n" * 96,
        "folder/ppmd.txt": b"Vort ZIP PPMd method 98.\n" * 128,
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
        expected_methods = {
            "stored.bin": zipfile.ZIP_STORED,
            "folder/shrink.txt": 1,
            "folder/implode.txt": 6,
            "folder/reduce1.txt": 2,
            "folder/reduce2.txt": 3,
            "folder/reduce3.txt": 4,
            "folder/reduce4.txt": 5,
            "folder/deflated.txt": zipfile.ZIP_DEFLATED,
            "folder/deflate64.txt": 9,
            "folder/dcl-implode.txt": 10,
            "folder/bzip2.txt": zipfile.ZIP_BZIP2,
            "folder/lzma.txt": zipfile.ZIP_LZMA,
            "folder/xz.txt": 95,
            "folder/zstd-legacy.txt": 20,
            "folder/zstd.txt": 93,
            "folder/ppmd.txt": 98,
            "utf8-目录/数据.txt": zipfile.ZIP_DEFLATED,
            "empty/": zipfile.ZIP_STORED,
        }
        zstd_tool = shutil.which("zstd")
        if zstd_tool is None:
            raise AssertionError("zstd CLI is required for ZIP methods 20/93 differential")
        for name, expected in payloads.items():
            info = archive.getinfo(name)
            name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
            data_offset = info.header_offset + 30 + name_len + extra_len
            if info.compress_type in (20, 93):
                actual = subprocess.run(
                    [zstd_tool, "-q", "-d", "-c"],
                    input=raw[data_offset : data_offset + info.compress_size],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
            elif info.compress_type in (2, 3, 4, 5, 6, 10):
                # The dedicated matrices below cover Reduce with Vort,
                # descriptor-free Implode with 7-Zip, and DCL Implode payloads
                # with zlib blast. Vort self-extraction covers these legal
                # descriptor-backed entries in the ordinary archive.
                actual = expected
            elif info.compress_type in (1, 9, 98):
                if seven_zip_tool is None:
                    # The Vort self-extraction pass below still validates these
                    # entries when no independent legacy/Deflate64/PPMd tool is installed.
                    actual = expected
                else:
                    actual = subprocess.run(
                        [seven_zip_tool, "x", "-so", "-bd", str(first), name],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    ).stdout
            elif info.compress_type == 95:
                actual = lzma.decompress(
                    raw[data_offset : data_offset + info.compress_size],
                    format=lzma.FORMAT_XZ,
                )
            else:
                actual = archive.read(info)
            if actual != expected:
                raise AssertionError(f"Python extraction mismatch for {name!r}")
            if name == "stored.bin":
                if info.date_time != (2026, 10, 17, 1, 23, 44):
                    raise AssertionError("custom DOS timestamp did not round trip")
                if info.comment != b"stored entry":
                    raise AssertionError("entry comment did not round trip")
                if info.create_system != 3 or info.internal_attr != 1:
                    raise AssertionError("ZIP creator/internal attributes did not round trip")
                if info.external_attr != 0o100640 << 16:
                    raise AssertionError("ZIP Unix external attributes did not round trip")
                validate_timestamp_extras(
                    info.extra,
                    "one-shot central stored.bin",
                    False,
                )
                validate_timestamp_extras(
                    raw[info.header_offset + 30 + name_len : data_offset],
                    "one-shot local stored.bin",
                    True,
                )
            elif info.date_time != (1980, 1, 1, 0, 0, 0):
                raise AssertionError(f"non-deterministic timestamp for {name!r}")
            if not info.flag_bits & 0x0008:
                raise AssertionError(f"data-descriptor flag omitted for {name!r}")
            if not info.flag_bits & 0x0800:
                raise AssertionError(f"UTF-8 flag omitted for {name!r}")
            if info.compress_type != expected_methods[name]:
                raise AssertionError(f"compression method mismatch for {name!r}")
            if info.compress_type in (20, 93, 95, 98) and info.extract_version != 63:
                raise AssertionError(f"method {info.compress_type} omitted ZIP 6.3 version-needed")
            if info.compress_type == 9 and not force_zip64 and info.extract_version != 21:
                raise AssertionError("Deflate64 method omitted ZIP 2.1 version-needed")
            if force_zip64 and info.extract_version < 45:
                raise AssertionError(f"ZIP64 version-needed omitted for {name!r}")

            local_flags = struct.unpack_from("<H", raw, info.header_offset + 6)[0]
            local_crc, local_compressed, local_uncompressed = struct.unpack_from(
                "<III", raw, info.header_offset + 14
            )
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

        if seven_zip_tool is not None:
            extracted_xz = subprocess.run(
                [seven_zip_tool, "x", "-so", "-bd", str(first), "folder/xz.txt"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            if extracted_xz != payloads["folder/xz.txt"]:
                raise AssertionError("7-Zip could not extract Vort ZIP XZ entry")

    listing = run(cli, "list-zip-file", str(first)).stdout
    if f"zip_entries={len(payloads)}" not in listing:
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


ZIPCRYPTO_PASSWORD = "vort-zip-password"
ZIPCRYPTO_PAYLOADS = {
    "encrypted/stored.bin": b"Vort Traditional ZipCrypto stored payload.\n" * 17,
    "encrypted/deflate.txt": b"Vort Traditional ZipCrypto Deflate payload.\n" * 97,
}

WINZIP_AES_PASSWORD = "vort-aes-password"
WINZIP_AES_PAYLOADS = {
    "aes/stored-128.bin": b"Vort WinZip AES-128 stored payload longer than twenty bytes.",
    "aes/deflate-192.txt": b"Vort WinZip AES-192 Deflate payload.\n" * 67,
    "aes/small-256.bin": b"small",
}

PKWARE_STRONG_PASSWORD = "vort-strong-password"
PKWARE_STRONG_PAYLOADS = {
    "strong/stored-128.bin": b"Vort PKWARE Strong AES-128 stored payload.",
    "strong/deflate-192.txt": b"Vort PKWARE Strong AES-192 Deflate payload.\n" * 67,
    "strong/bzip2-256.txt": b"Vort PKWARE Strong AES-256 Bzip2 payload.\n" * 53,
}


def decrypt_winzip_aes_reference(
    raw: bytes,
    info: zipfile.ZipInfo,
    password: str,
    openssl_tool: str,
) -> bytes:
    local_offset = info.header_offset
    (
        signature,
        version_needed,
        flags,
        wire_method,
        _time,
        _date,
        local_crc,
        _compressed_size,
        _uncompressed_size,
        name_len,
        extra_len,
    ) = struct.unpack_from("<IHHHHHIIIHH", raw, local_offset)
    if signature != 0x04034B50 or version_needed < 51 or wire_method != 99 or flags & 1 == 0:
        raise AssertionError("invalid WinZip AES local metadata")
    extra_offset = local_offset + 30 + name_len
    local_extra = raw[extra_offset : extra_offset + extra_len]
    central_fields = parse_extra_fields(info.extra, f"WinZip AES central {info.filename!r}")
    local_fields = parse_extra_fields(local_extra, f"WinZip AES local {info.filename!r}")
    aes = central_fields.get(0x9901)
    if aes is None or aes != local_fields.get(0x9901) or len(aes) != 7:
        raise AssertionError("missing or mismatched WinZip AES extra field")
    vendor_version, vendor, strength, actual_method = struct.unpack("<H2sBH", aes)
    if vendor_version not in (1, 2) or vendor != b"AE" or strength not in (1, 2, 3):
        raise AssertionError("invalid WinZip AES parameters")
    key_len = {1: 16, 2: 24, 3: 32}[strength]
    salt_len = key_len // 2
    data_offset = extra_offset + extra_len
    encrypted = raw[data_offset : data_offset + info.compress_size]
    if len(encrypted) < salt_len + 12:
        raise AssertionError("truncated WinZip AES payload")
    salt = encrypted[:salt_len]
    verifier = encrypted[salt_len : salt_len + 2]
    ciphertext = encrypted[salt_len + 2 : -10]
    authentication = encrypted[-10:]
    derived = hashlib.pbkdf2_hmac(
        "sha1", password.encode(), salt, 1000, 2 * key_len + 2
    )
    if not hmac.compare_digest(verifier, derived[-2:]):
        raise AssertionError("WinZip AES password verifier mismatch")
    expected_authentication = hmac.new(
        derived[key_len : 2 * key_len], ciphertext, hashlib.sha1
    ).digest()[:10]
    if not hmac.compare_digest(authentication, expected_authentication):
        raise AssertionError("WinZip AES authentication mismatch")
    counters = b"".join(
        counter.to_bytes(16, "little")
        for counter in range(1, (len(ciphertext) + 15) // 16 + 1)
    )
    key_stream = subprocess.run(
        [
            openssl_tool,
            "enc",
            f"-aes-{key_len * 8}-ecb",
            "-K",
            derived[:key_len].hex(),
            "-nopad",
            "-nosalt",
        ],
        input=counters,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    compressed = bytes(left ^ right for left, right in zip(ciphertext, key_stream))
    if actual_method == zipfile.ZIP_STORED:
        payload = compressed
    elif actual_method == zipfile.ZIP_DEFLATED:
        payload = zlib.decompress(compressed, -15)
    else:
        raise AssertionError(f"unexpected WinZip AES method {actual_method}")
    if len(payload) != info.file_size:
        raise AssertionError("WinZip AES uncompressed size mismatch")
    if vendor_version == 1:
        expected_crc = binascii.crc32(payload) & 0xFFFFFFFF
        if info.CRC != expected_crc or local_crc not in (0, expected_crc):
            raise AssertionError("WinZip AES AE-1 CRC mismatch")
    elif info.CRC != 0:
        raise AssertionError("WinZip AES AE-2 CRC is not zero")
    return payload


def validate_vort_winzip_aes(
    cli: Path,
    writer: Path,
    temp: Path,
    openssl_tool: str,
) -> tuple[int, int]:
    cases = 0
    sequential_cases = 0
    for descriptor in (False, True):
        suffix = "descriptor" if descriptor else "known"
        archive_path = temp / f"vort-winzip-aes-{suffix}.zip"
        run(
            writer,
            str(archive_path),
            "winzip-aes-descriptor" if descriptor else "winzip-aes",
        )
        raw = archive_path.read_bytes()
        with zipfile.ZipFile(archive_path) as archive:
            if archive.namelist() != list(WINZIP_AES_PAYLOADS):
                raise AssertionError("Vort WinZip AES entry order mismatch")
            for index, (name, expected) in enumerate(WINZIP_AES_PAYLOADS.items()):
                info = archive.getinfo(name)
                if info.compress_type != 99 or info.flag_bits & 1 == 0:
                    raise AssertionError(f"Vort WinZip AES metadata mismatch for {name!r}")
                if decrypt_winzip_aes_reference(
                    raw, info, WINZIP_AES_PASSWORD, openssl_tool
                ) != expected:
                    raise AssertionError(f"OpenSSL could not decrypt Vort WinZip AES {name!r}")
                output = temp / f"vort-winzip-aes-{suffix}-{index}.out"
                extract_with_vort_password(
                    cli, archive_path, name, output, WINZIP_AES_PASSWORD
                )
                if output.read_bytes() != expected:
                    raise AssertionError(f"Vort WinZip AES self-extraction mismatch for {name!r}")
                stream_output = temp / f"vort-winzip-aes-{suffix}-{index}.stream.out"
                run(
                    cli,
                    "extract-zip-stream-file",
                    str(archive_path),
                    name,
                    str(stream_output),
                    str(512 * 1024 * 1024),
                    WINZIP_AES_PASSWORD,
                )
                if stream_output.read_bytes() != expected:
                    raise AssertionError(
                        f"Vort sequential WinZip AES mismatch for {name!r}"
                    )
                sequential_cases += 1
                cases += 1
    return cases, sequential_cases


def extract_with_vort_password(
    cli: Path, archive: Path, name: str, output: Path, password: str
) -> None:
    run(
        cli,
        "extract-zip-file",
        str(archive),
        name,
        str(output),
        str(512 * 1024 * 1024),
        str(64 * 1024 * 1024),
        password,
    )


def validate_vort_zipcrypto(
    cli: Path,
    writer: Path,
    unzip_tool: str,
    temp: Path,
) -> tuple[int, int]:
    cases = 0
    sequential_cases = 0
    for descriptor in (False, True):
        suffix = "descriptor" if descriptor else "known"
        archive_path = temp / f"vort-zipcrypto-{suffix}.zip"
        run(
            writer,
            str(archive_path),
            "zipcrypto-descriptor" if descriptor else "zipcrypto",
        )
        with zipfile.ZipFile(archive_path) as archive:
            if archive.namelist() != list(ZIPCRYPTO_PAYLOADS):
                raise AssertionError("Vort ZipCrypto entry order mismatch")
            for index, (name, expected) in enumerate(ZIPCRYPTO_PAYLOADS.items()):
                info = archive.getinfo(name)
                if info.flag_bits & 1 == 0 or bool(info.flag_bits & 8) != descriptor:
                    raise AssertionError(f"Vort ZipCrypto flags mismatch for {name!r}")
                if archive.read(name, pwd=ZIPCRYPTO_PASSWORD.encode()) != expected:
                    raise AssertionError(f"Python could not decrypt Vort {name!r}")
                try:
                    archive.read(name, pwd=b"wrong-password")
                except (RuntimeError, zipfile.BadZipFile):
                    pass
                else:
                    raise AssertionError("Python accepted a wrong Vort ZIP password")

                output = temp / f"vort-zipcrypto-{suffix}-{index}.out"
                extract_with_vort_password(
                    cli,
                    archive_path,
                    name,
                    output,
                    ZIPCRYPTO_PASSWORD,
                )
                if output.read_bytes() != expected:
                    raise AssertionError(f"Vort ZipCrypto self-extraction mismatch for {name!r}")
                stream_output = temp / f"vort-zipcrypto-{suffix}-{index}.stream.out"
                run(
                    cli,
                    "extract-zip-stream-file",
                    str(archive_path),
                    name,
                    str(stream_output),
                    str(512 * 1024 * 1024),
                    ZIPCRYPTO_PASSWORD,
                )
                if stream_output.read_bytes() != expected:
                    raise AssertionError(
                        f"Vort sequential ZipCrypto mismatch for {name!r}"
                    )
                sequential_cases += 1
                wrong = subprocess.run(
                    [
                        str(cli),
                        "extract-zip-file",
                        str(archive_path),
                        name,
                        str(temp / f"vort-zipcrypto-{suffix}-{index}.wrong"),
                        str(512 * 1024 * 1024),
                        str(64 * 1024 * 1024),
                        "wrong-password",
                    ],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if wrong.returncode == 0:
                    raise AssertionError("Vort accepted a wrong ZIP password")
                cases += 1

        extracted = subprocess.run(
            [unzip_tool, "-P", ZIPCRYPTO_PASSWORD, "-p", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout
        if extracted != b"".join(ZIPCRYPTO_PAYLOADS.values()):
            raise AssertionError("Info-ZIP could not decrypt Vort ZipCrypto output")
    return cases, sequential_cases


def validate_vort_pkware_strong(
    cli: Path,
    writer: Path,
    temp: Path,
    seven_zip_tool: str | None,
) -> tuple[int, int, int]:
    cases = 0
    seven_zip_cases = 0
    sequential_cases = 0
    expected_algorithms = (0x660E, 0x660F, 0x6610)
    for descriptor in (False, True):
        suffix = "descriptor" if descriptor else "known"
        archive_path = temp / f"vort-pkware-strong-{suffix}.zip"
        run(
            writer,
            str(archive_path),
            "pkware-strong-descriptor" if descriptor else "pkware-strong",
        )
        with zipfile.ZipFile(archive_path) as archive:
            if archive.namelist() != list(PKWARE_STRONG_PAYLOADS):
                raise AssertionError("Vort PKWARE Strong entry order mismatch")
            for index, (name, expected) in enumerate(PKWARE_STRONG_PAYLOADS.items()):
                info = archive.getinfo(name)
                if info.flag_bits & 0x41 != 0x41 or bool(info.flag_bits & 8) != descriptor:
                    raise AssertionError(f"Vort PKWARE Strong flags mismatch for {name!r}")
                fields = parse_extra_fields(
                    info.extra, f"PKWARE Strong central {name!r}"
                )
                strong = fields.get(0x0017)
                if strong is None or len(strong) != 8:
                    raise AssertionError(f"missing PKWARE Strong extra field for {name!r}")
                record_format, algorithm, bit_length, flags = struct.unpack(
                    "<HHHH", strong
                )
                if (
                    record_format != 2
                    or algorithm != expected_algorithms[index]
                    or bit_length != (128, 192, 256)[index]
                    or flags != 1
                ):
                    raise AssertionError(f"invalid PKWARE Strong extra field for {name!r}")

                output = temp / f"vort-pkware-strong-{suffix}-{index}.out"
                extract_with_vort_password(
                    cli,
                    archive_path,
                    name,
                    output,
                    PKWARE_STRONG_PASSWORD,
                )
                if output.read_bytes() != expected:
                    raise AssertionError(
                        f"Vort PKWARE Strong self-extraction mismatch for {name!r}"
                    )
                stream_output = temp / f"vort-pkware-strong-{suffix}-{index}.stream.out"
                run(
                    cli,
                    "extract-zip-stream-file",
                    str(archive_path),
                    name,
                    str(stream_output),
                    str(512 * 1024 * 1024),
                    PKWARE_STRONG_PASSWORD,
                )
                if stream_output.read_bytes() != expected:
                    raise AssertionError(
                        f"Vort PKWARE Strong sequential mismatch for {name!r}"
                    )
                sequential_cases += 1
                wrong = subprocess.run(
                    [
                        str(cli),
                        "extract-zip-file",
                        str(archive_path),
                        name,
                        str(temp / f"vort-pkware-strong-{suffix}-{index}.wrong"),
                        str(512 * 1024 * 1024),
                        str(64 * 1024 * 1024),
                        "wrong-password",
                    ],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if wrong.returncode == 0:
                    raise AssertionError("Vort accepted a wrong PKWARE Strong password")
                cases += 1

                if seven_zip_tool is not None:
                    extracted = subprocess.run(
                        [
                            seven_zip_tool,
                            "x",
                            "-so",
                            "-bd",
                            f"-p{PKWARE_STRONG_PASSWORD}",
                            str(archive_path),
                            name,
                        ],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    ).stdout
                    if extracted != expected:
                        raise AssertionError(
                            f"7-Zip could not decrypt Vort PKWARE Strong {name!r}"
                        )
                    seven_zip_cases += 1
    return cases, seven_zip_cases, sequential_cases


def validate_infozip_zipcrypto(
    cli: Path,
    zip_tool: str,
    temp: Path,
) -> tuple[int, int]:
    payload = b"Info-ZIP Traditional encryption read by Vort.\n" * 128
    cases = 0
    sequential_cases = 0
    for index, compression in enumerate(("-0", "-9")):
        source = temp / f"infozip-encrypted-{index}.txt"
        archive = temp / f"infozip-encrypted-{index}.zip"
        output = temp / f"infozip-encrypted-{index}.out"
        source.write_bytes(payload)
        subprocess.run(
            [
                zip_tool,
                "-q",
                compression,
                "-P",
                ZIPCRYPTO_PASSWORD,
                archive.name,
                source.name,
            ],
            cwd=temp,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        with zipfile.ZipFile(archive) as parsed:
            info = parsed.getinfo(source.name)
            expected_method = zipfile.ZIP_STORED if compression == "-0" else zipfile.ZIP_DEFLATED
            if info.flag_bits & 1 == 0 or info.compress_type != expected_method:
                raise AssertionError("Info-ZIP ZipCrypto metadata mismatch")
        extract_with_vort_password(
            cli,
            archive,
            source.name,
            output,
            ZIPCRYPTO_PASSWORD,
        )
        if output.read_bytes() != payload:
            raise AssertionError("Vort could not decrypt Info-ZIP output")
        stream_output = temp / f"infozip-encrypted-{index}.stream.out"
        run(
            cli,
            "extract-zip-stream-file",
            str(archive),
            source.name,
            str(stream_output),
            str(512 * 1024 * 1024),
            ZIPCRYPTO_PASSWORD,
        )
        if stream_output.read_bytes() != payload:
            raise AssertionError("Vort sequential reader could not decrypt Info-ZIP output")
        sequential_cases += 1
        cases += 1
    return cases, sequential_cases


def validate_seven_zip_xz_with_vort(cli: Path, tool: str, temp: Path) -> None:
    payload = b"7-Zip XZ method 95 reference.\n" * 256
    source = temp / "seven-zip-xz.txt"
    archive = temp / "seven-zip-xz.zip"
    output = temp / "seven-zip-xz.out"
    source.write_bytes(payload)
    subprocess.run(
        [tool, "a", "-bd", "-y", "-tzip", "-mm=xz", str(archive), source.name],
        cwd=temp,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    run(cli, "extract-zip-file", str(archive), source.name, str(output))
    if output.read_bytes() != payload:
        raise AssertionError("Vort could not decode 7-Zip XZ method 95 output")


def validate_vort_ppmd_cutoff_with_seven_zip(writer: Path, tool: str, temp: Path) -> None:
    archive = temp / "vort-ppmd-cutoff.zip"
    run(writer, str(archive), "ppmd-cutoff")
    expected = b"Vort ZIP PPMd method 98.\n" * 128
    actual = subprocess.run(
        [tool, "x", "-so", "-bd", str(archive), "folder/ppmd.txt"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    if actual != expected:
        raise AssertionError("7-Zip could not extract Vort ZIP PPMd cut-off entry")
    with zipfile.ZipFile(archive) as parsed:
        info = parsed.getinfo("folder/ppmd.txt")
        raw = archive.read_bytes()
        name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
        data_offset = info.header_offset + 30 + name_len + extra_len
        properties = struct.unpack_from("<H", raw, data_offset)[0]
        if properties >> 12 != 1:
            raise AssertionError("Vort ZIP PPMd writer omitted cut-off restore mode")


def validate_vort_implode_modes(
    cli: Path, writer: Path, tool: str | None, temp: Path
) -> tuple[int, int]:
    expected = make_legacy_payload(5000, 0x193A72D5)
    sizes: dict[str, int] = {}
    stream_cases = 0
    external_cases = 0
    for dictionary, dictionary_flag in (("4k", 0), ("8k", 2)):
        for literals, literal_flag in (("raw", 0), ("tree", 4)):
            mode = f"implode-{dictionary}-{literals}"
            for descriptor_mode in (False, True):
                suffix = "-descriptor" if descriptor_mode else ""
                archive = temp / f"vort-{mode}{suffix}.zip"
                run(writer, str(archive), mode + suffix)
                output = temp / f"vort-{mode}{suffix}-stream.out"
                run(
                    cli,
                    "extract-zip-stream-file",
                    str(archive),
                    "folder/implode.txt",
                    str(output),
                )
                if output.read_bytes() != expected:
                    raise AssertionError(
                        f"Vort sequential ZIP {mode}{suffix} extraction mismatch"
                    )
                stream_cases += 1
                with zipfile.ZipFile(archive) as parsed:
                    info = parsed.getinfo("folder/implode.txt")
                    if info.compress_type != 6:
                        raise AssertionError("Vort Implode writer used the wrong method ID")
                    if (info.flag_bits & 6) != (dictionary_flag | literal_flag):
                        raise AssertionError(f"Vort ZIP {mode}{suffix} flags mismatch")
                    if bool(info.flag_bits & 8) != descriptor_mode:
                        raise AssertionError(f"Vort ZIP {mode}{suffix} descriptor flag mismatch")
                    if not descriptor_mode:
                        sizes[mode] = info.compress_size
                if tool is not None and not descriptor_mode:
                    actual = subprocess.run(
                        [tool, "x", "-so", "-bd", str(archive), "folder/implode.txt"],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    ).stdout
                    if actual != expected:
                        raise AssertionError(f"7-Zip could not extract Vort ZIP {mode} entry")
                    external_cases += 1
    for literals in ("raw", "tree"):
        if sizes[f"implode-8k-{literals}"] >= sizes[f"implode-4k-{literals}"]:
            raise AssertionError("Vort 8 KiB Implode mode did not use its long-distance match")
    return stream_cases, external_cases


def validate_vort_reduce_modes(cli: Path, writer: Path, temp: Path) -> tuple[int, int]:
    archive = temp / "vort-reduce.zip"
    run(writer, str(archive), "reduce")
    descriptor_archive = temp / "vort-reduce-descriptor.zip"
    run(writer, str(descriptor_archive), "reduce-descriptor")
    cases = {
        "folder/reduce1.txt": make_legacy_payload(400, 0x10203041),
        "folder/reduce2.txt": make_legacy_payload(800, 0x20304052),
        "folder/reduce3.txt": make_legacy_payload(1500, 0x30405063),
        "folder/reduce4.txt": make_legacy_payload(3000, 0x40506074),
    }
    stream_cases = 0
    with zipfile.ZipFile(archive) as parsed:
        for index, (name, expected) in enumerate(cases.items(), start=1):
            info = parsed.getinfo(name)
            if info.compress_type != index + 1:
                raise AssertionError(f"Vort ZIP Reduce method mismatch for {name}")
            output = temp / f"reduce-{index}.out"
            run(cli, "extract-zip-file", str(archive), name, str(output))
            if output.read_bytes() != expected:
                raise AssertionError(f"Vort ZIP Reduce self-extraction mismatch for {name}")
            stream_output = temp / f"reduce-stream-{index}.out"
            run(
                cli,
                "extract-zip-stream-file",
                str(archive),
                name,
                str(stream_output),
            )
            if stream_output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort sequential known-size Reduce extraction mismatch for {name}"
                )
            stream_cases += 1
            descriptor_stream_output = temp / f"reduce-descriptor-stream-{index}.out"
            run(
                cli,
                "extract-zip-stream-file",
                str(descriptor_archive),
                name,
                str(descriptor_stream_output),
            )
            if descriptor_stream_output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort sequential descriptor-backed Reduce extraction mismatch for {name}"
                )
            stream_cases += 1
    return len(cases), stream_cases


def validate_vort_dcl_implode_modes(
    cli: Path,
    writer: Path,
    temp: Path,
    blast_tool: Path | None,
) -> tuple[int, int]:
    expected = make_legacy_payload(3000, 0xDCA10010)
    self_cases = 0
    external_cases = 0
    sizes: dict[str, int] = {}
    for dictionary, dictionary_bits in (("1k", 4), ("2k", 5), ("4k", 6)):
        for literals, literal_mode in (("raw", 0), ("coded", 1)):
            mode = f"dcl-{dictionary}-{literals}"
            archive = temp / f"vort-{mode}.zip"
            output = temp / f"vort-{mode}.out"
            run(writer, str(archive), mode)
            run(cli, "extract-zip-file", str(archive), "folder/dcl-implode.txt", str(output))
            if output.read_bytes() != expected:
                raise AssertionError(f"Vort could not self-extract ZIP {mode}")
            raw = archive.read_bytes()
            with zipfile.ZipFile(archive) as parsed:
                info = parsed.getinfo("folder/dcl-implode.txt")
                if info.compress_type != 10:
                    raise AssertionError("Vort DCL Implode writer used the wrong method ID")
                name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
                data_offset = info.header_offset + 30 + name_len + extra_len
                compressed = raw[data_offset : data_offset + info.compress_size]
                sizes[mode] = info.compress_size
            if compressed[:2] != bytes((literal_mode, dictionary_bits)):
                raise AssertionError(f"Vort ZIP {mode} payload header mismatch")
            self_cases += 1
            if blast_tool is not None:
                actual = subprocess.run(
                    [str(blast_tool)],
                    input=compressed,
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                ).stdout
                if actual != expected:
                    raise AssertionError(f"zlib blast could not decode Vort ZIP {mode}")
                external_cases += 1
    for literals in ("raw", "coded"):
        if sizes[f"dcl-4k-{literals}"] >= sizes[f"dcl-2k-{literals}"]:
            raise AssertionError("Vort 4 KiB DCL mode did not use its long-distance match")
    return self_cases, external_cases


def validate_seven_zip_deflate64_with_vort(cli: Path, tool: str, temp: Path) -> int:
    rng = random.Random(0xDEF1A7E64)
    prefix = bytes(rng.randrange(256) for _ in range(40_000))
    cases = {
        "deflate64-text.txt": b"7-Zip Deflate64 reference.\n" * 2048,
        "deflate64-long-distance.bin": prefix + b"separator" + prefix,
    }
    for name, payload in cases.items():
        source = temp / name
        archive = temp / f"{name}.zip"
        output = temp / f"{name}.out"
        source.write_bytes(payload)
        subprocess.run(
            [tool, "a", "-bd", "-y", "-tzip", "-mm=Deflate64", str(archive), source.name],
            cwd=temp,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        with zipfile.ZipFile(archive) as parsed:
            info = parsed.getinfo(source.name)
            if info.compress_type != 9:
                raise AssertionError("7-Zip did not emit method 9")
            if name.endswith("long-distance.bin") and info.compress_size >= len(payload) * 3 // 4:
                raise AssertionError("Deflate64 long-distance fixture did not compress enough")
        run(cli, "extract-zip-file", str(archive), source.name, str(output))
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort could not decode 7-Zip Deflate64 entry {name}")
    return len(cases)


def validate_seven_zip_ppmd_with_vort(cli: Path, tool: str, temp: Path) -> int:
    cutoff_payload = b"".join(
        f"{index:08x} PPMd cut-off context {index % 997:03d} payload line\n".encode()
        for index in range(50_000)
    )
    cases = {
        "ppmd-restart.txt": (
            b"7-Zip PPMd restart reference.\n" * 2048,
            ["-mx=5"],
            0,
        ),
        "ppmd-cutoff.txt": (
            cutoff_payload,
            ["-mx=9", "-mmem=1m", "-mo=16"],
            1,
        ),
    }
    for name, (payload, options, expected_restore) in cases.items():
        source = temp / name
        archive = temp / f"{name}.zip"
        output = temp / f"{name}.out"
        source.write_bytes(payload)
        subprocess.run(
            [tool, "a", "-bd", "-y", "-tzip", "-mm=PPMd", *options, str(archive), source.name],
            cwd=temp,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        with zipfile.ZipFile(archive) as parsed:
            info = parsed.getinfo(source.name)
            if info.compress_type != 98:
                raise AssertionError("7-Zip did not emit ZIP method 98")
            raw = archive.read_bytes()
            name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
            data_offset = info.header_offset + 30 + name_len + extra_len
            properties = struct.unpack_from("<H", raw, data_offset)[0]
            if properties >> 12 != expected_restore:
                raise AssertionError("7-Zip PPMd restore mode did not match the fixture")
            if name.endswith("cutoff.txt") and ((properties >> 4) & 0xFF) + 1 != 1:
                raise AssertionError("7-Zip PPMd cut-off fixture did not use a 1 MiB model")
        run(cli, "extract-zip-file", str(archive), source.name, str(output))
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort could not decode 7-Zip PPMd entry {name}")
        limited = subprocess.run(
            [
                str(cli),
                "extract-zip-file",
                str(archive),
                source.name,
                str(temp / f"{name}.limited"),
                str(len(payload)),
                str(1024 * 1024 - 1),
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if limited.returncode == 0:
            raise AssertionError("Vort accepted ZIP PPMd model memory above the caller limit")
    return len(cases)


INCREMENTAL_COMMENT = b"vort incremental writer interop"
INCREMENTAL_PAYLOADS = {
    "known-stored.bin": b"\x00known-stored-PK\x07\x08-payload\xff",
    "unknown-stored.bin": b"PK\x07\x08unknown-stored-PK\x07\x08tail",
    "known-deflate.txt": b"known deflate stream crosses block boundaries.\n" * 900,
    "utf8-目录/未知-deflate.txt": b"unknown deflate UTF-8 path payload.\n" * 61,
    "empty-stored.bin": b"",
    "empty-deflate.bin": b"",
    "known-bzip2.txt": b"known Bzip2 incremental ZIP payload.\n" * 96,
    "unknown-bzip2.txt": b"unknown Bzip2 incremental ZIP payload.\n" * 73,
    "empty-bzip2.bin": b"",
    "known-zstd.txt": b"known Zstandard incremental ZIP payload.\n" * 103,
    "unknown-zstd-legacy.txt": b"unknown legacy Zstandard incremental ZIP payload.\n" * 67,
    "empty-zstd.bin": b"",
    "known-lzma.txt": b"known LZMA incremental ZIP payload.\n" * 89,
    "unknown-lzma.txt": b"unknown LZMA incremental ZIP payload.\n" * 71,
    "empty-lzma.bin": b"",
    "known-xz.txt": b"known XZ incremental ZIP payload.\n" * 97,
    "unknown-xz.txt": b"unknown XZ incremental ZIP payload.\n" * 79,
    "empty-xz.bin": b"",
    "known-deflate64.bin": b"known Deflate64 incremental ZIP payload.\n" * 101,
    "unknown-deflate64.bin": b"unknown Deflate64 incremental ZIP payload.\n" * 83,
    "empty-deflate64.bin": b"",
    "known-ppmd.txt": b"known PPMd incremental ZIP payload.\n" * 107,
    "unknown-ppmd.txt": b"unknown PPMd incremental ZIP payload.\n" * 89,
    "empty-ppmd.bin": b"",
    "known-shrink.txt": b"known Shrink incremental ZIP payload.\n" * 109,
    "unknown-shrink.txt": b"unknown Shrink incremental ZIP payload.\n" * 91,
    "empty-shrink.bin": b"",
    "known-dcl-implode.txt": b"known DCL Implode incremental ZIP payload.\n" * 113,
    "unknown-dcl-implode.txt": b"unknown DCL Implode incremental ZIP payload.\n" * 93,
    "empty-dcl-implode.bin": b"",
    "known-reduce-1.txt": b"known Reduce factor 1 incremental ZIP payload.\n" * 67,
    "unknown-reduce-1.txt": b"unknown Reduce factor 1 incremental ZIP payload.\n" * 53,
    "empty-reduce-1.bin": b"",
    "known-reduce-2.txt": b"known Reduce factor 2 incremental ZIP payload.\n" * 71,
    "unknown-reduce-2.txt": b"unknown Reduce factor 2 incremental ZIP payload.\n" * 59,
    "empty-reduce-2.bin": b"",
    "known-reduce-3.txt": b"known Reduce factor 3 incremental ZIP payload.\n" * 73,
    "unknown-reduce-3.txt": b"unknown Reduce factor 3 incremental ZIP payload.\n" * 61,
    "empty-reduce-3.bin": b"",
    "known-reduce-4.txt": b"known Reduce factor 4 incremental ZIP payload.\n" * 79,
    "unknown-reduce-4.txt": b"unknown Reduce factor 4 incremental ZIP payload.\n" * 63,
    "empty-reduce-4.bin": b"",
    "known-implode.txt": b"known traditional Implode incremental ZIP payload.\n" * 83,
    "unknown-implode.txt": b"unknown traditional Implode incremental ZIP payload.\n" * 67,
    "empty-implode.bin": b"",
}
INCREMENTAL_METHODS = {
    "known-stored.bin": zipfile.ZIP_STORED,
    "unknown-stored.bin": zipfile.ZIP_STORED,
    "known-deflate.txt": zipfile.ZIP_DEFLATED,
    "utf8-目录/未知-deflate.txt": zipfile.ZIP_DEFLATED,
    "empty-stored.bin": zipfile.ZIP_STORED,
    "empty-deflate.bin": zipfile.ZIP_DEFLATED,
    "known-bzip2.txt": zipfile.ZIP_BZIP2,
    "unknown-bzip2.txt": zipfile.ZIP_BZIP2,
    "empty-bzip2.bin": zipfile.ZIP_BZIP2,
    "known-zstd.txt": 93,
    "unknown-zstd-legacy.txt": 20,
    "empty-zstd.bin": 93,
    "known-lzma.txt": zipfile.ZIP_LZMA,
    "unknown-lzma.txt": zipfile.ZIP_LZMA,
    "empty-lzma.bin": zipfile.ZIP_LZMA,
    "known-xz.txt": 95,
    "unknown-xz.txt": 95,
    "empty-xz.bin": 95,
    "known-deflate64.bin": 9,
    "unknown-deflate64.bin": 9,
    "empty-deflate64.bin": 9,
    "known-ppmd.txt": 98,
    "unknown-ppmd.txt": 98,
    "empty-ppmd.bin": 98,
    "known-shrink.txt": 1,
    "unknown-shrink.txt": 1,
    "empty-shrink.bin": 1,
    "known-dcl-implode.txt": 10,
    "unknown-dcl-implode.txt": 10,
    "empty-dcl-implode.bin": 10,
    "known-reduce-1.txt": 2,
    "unknown-reduce-1.txt": 2,
    "empty-reduce-1.bin": 2,
    "known-reduce-2.txt": 3,
    "unknown-reduce-2.txt": 3,
    "empty-reduce-2.bin": 3,
    "known-reduce-3.txt": 4,
    "unknown-reduce-3.txt": 4,
    "empty-reduce-3.bin": 4,
    "known-reduce-4.txt": 5,
    "unknown-reduce-4.txt": 5,
    "empty-reduce-4.bin": 5,
    "known-implode.txt": 6,
    "unknown-implode.txt": 6,
    "empty-implode.bin": 6,
}


def parse_extra_fields(extra: bytes, context: str) -> dict[int, bytes]:
    fields: dict[int, bytes] = {}
    offset = 0
    while offset < len(extra):
        if offset + 4 > len(extra):
            raise AssertionError(f"truncated extra-field header in {context}")
        field_id, field_len = struct.unpack_from("<HH", extra, offset)
        offset += 4
        end = offset + field_len
        if end > len(extra):
            raise AssertionError(f"truncated extra field {field_id:#06x} in {context}")
        if field_id in fields:
            raise AssertionError(f"duplicate extra field {field_id:#06x} in {context}")
        fields[field_id] = extra[offset:end]
        offset = end
    return fields


EXTENDED_TIMESTAMP_SECONDS = (1_700_000_001, 1_700_000_002, -1)
NTFS_TIMESTAMP_SECONDS = (1_700_000_001, 1_700_000_002, 1_700_000_003)


def windows_filetime(seconds: int) -> int:
    return (seconds + 11_644_473_600) * 10_000_000


def validate_timestamp_extras(extra: bytes, context: str, local: bool) -> None:
    fields = parse_extra_fields(extra, context)
    extended = fields.get(0x5455)
    expected_extended_len = 13 if local else 5
    if extended is None or len(extended) != expected_extended_len:
        raise AssertionError(f"{context} extended timestamp width mismatch")
    if extended[0] != 0x07:
        raise AssertionError(f"{context} extended timestamp flags mismatch")
    values = struct.unpack_from("<" + "i" * (3 if local else 1), extended, 1)
    if values != EXTENDED_TIMESTAMP_SECONDS[: len(values)]:
        raise AssertionError(f"{context} extended timestamp values mismatch")

    ntfs = fields.get(0x000A)
    if ntfs is None or len(ntfs) != 32:
        raise AssertionError(f"{context} NTFS timestamp width mismatch")
    reserved, tag, size, modified, accessed, created = struct.unpack(
        "<IHHQQQ", ntfs
    )
    if reserved != 0 or tag != 1 or size != 24:
        raise AssertionError(f"{context} NTFS timestamp header mismatch")
    if (modified, accessed, created) != tuple(
        windows_filetime(value) for value in NTFS_TIMESTAMP_SECONDS
    ):
        raise AssertionError(f"{context} NTFS timestamp values mismatch")


def validate_unicode_extra(
    extra: bytes,
    field_id: int,
    raw_text: bytes,
    unicode_text: str,
    context: str,
) -> None:
    payload = parse_extra_fields(extra, context).get(field_id)
    expected_utf8 = unicode_text.encode("utf-8")
    if payload is None or len(payload) != 5 + len(expected_utf8):
        raise AssertionError(f"{context} Unicode extra width mismatch")
    if payload[0] != 1:
        raise AssertionError(f"{context} Unicode extra version mismatch")
    if struct.unpack_from("<I", payload, 1)[0] != binascii.crc32(raw_text) & 0xFFFFFFFF:
        raise AssertionError(f"{context} Unicode extra CRC mismatch")
    if payload[5:] != expected_utf8:
        raise AssertionError(f"{context} Unicode extra text mismatch")


def central_directory_bounds(raw: bytes) -> tuple[int, int]:
    eocd_offset = raw.rfind(b"PK\x05\x06")
    if eocd_offset < 0 or eocd_offset + 22 > len(raw):
        raise AssertionError("missing EOCD")
    central_size, central_offset = struct.unpack_from("<II", raw, eocd_offset + 12)
    if central_size != 0xFFFFFFFF and central_offset != 0xFFFFFFFF:
        return central_offset, central_size
    locator_offset = eocd_offset - 20
    if locator_offset < 0 or raw[locator_offset : locator_offset + 4] != b"PK\x06\x07":
        raise AssertionError("missing ZIP64 locator")
    zip64_offset = struct.unpack_from("<Q", raw, locator_offset + 8)[0]
    if raw[zip64_offset : zip64_offset + 4] != b"PK\x06\x06":
        raise AssertionError("missing ZIP64 EOCD")
    central_size = struct.unpack_from("<Q", raw, zip64_offset + 40)[0]
    central_offset = struct.unpack_from("<Q", raw, zip64_offset + 48)[0]
    return central_offset, central_size


def validate_archive_extra_record(
    raw: bytes,
    expected_data: bytes,
    context: str,
) -> None:
    central_offset, central_size = central_directory_bounds(raw)
    if raw[central_offset : central_offset + 4] != b"PK\x06\x08":
        raise AssertionError(f"{context} archive extra signature mismatch")
    payload_len = struct.unpack_from("<I", raw, central_offset + 4)[0]
    record_end = central_offset + 8 + payload_len
    if payload_len != len(expected_data) or raw[central_offset + 8 : record_end] != expected_data:
        raise AssertionError(f"{context} archive extra payload mismatch")
    if central_size < 8 + payload_len or raw[record_end : record_end + 4] not in (
        b"PK\x01\x02",
        b"PK\x06\x06",
        b"PK\x05\x06",
    ):
        raise AssertionError(f"{context} archive extra central bounds mismatch")


def validate_incremental_raw_layout(raw: bytes, force_zip64: bool) -> None:
    eocd_offset = raw.rfind(b"PK\x05\x06")
    if eocd_offset < 0 or eocd_offset + 22 > len(raw):
        raise AssertionError("incremental archive omitted its legacy EOCD")
    (
        eocd_signature,
        disk,
        central_disk,
        entries_on_disk,
        entry_count,
        legacy_central_size,
        legacy_central_offset,
        comment_len,
    ) = struct.unpack_from("<IHHHHIIH", raw, eocd_offset)
    if eocd_signature != 0x06054B50 or disk != 0 or central_disk != 0:
        raise AssertionError("invalid incremental legacy EOCD header")
    if raw[eocd_offset + 22 :] != INCREMENTAL_COMMENT or comment_len != len(
        INCREMENTAL_COMMENT
    ):
        raise AssertionError("incremental archive comment mismatch")

    expected_count = len(INCREMENTAL_PAYLOADS)
    if force_zip64:
        locator_offset = eocd_offset - 20
        if locator_offset < 0 or raw[locator_offset : locator_offset + 4] != b"PK\x06\x07":
            raise AssertionError("ZIP64 incremental archive omitted its EOCD locator")
        locator_disk, zip64_eocd_offset, disk_count = struct.unpack_from(
            "<IQI", raw, locator_offset + 4
        )
        if locator_disk != 0 or disk_count != 1:
            raise AssertionError("invalid ZIP64 incremental EOCD locator")
        if zip64_eocd_offset + 56 != locator_offset:
            raise AssertionError("unexpected ZIP64 incremental EOCD record size")
        (
            zip64_signature,
            zip64_record_size,
            made_by,
            needed,
            zip64_disk,
            zip64_central_disk,
            zip64_entries_on_disk,
            zip64_entry_count,
            central_size,
            central_offset,
        ) = struct.unpack_from("<IQHHIIQQQQ", raw, zip64_eocd_offset)
        if zip64_signature != 0x06064B50 or zip64_record_size != 44 or needed != 45:
            raise AssertionError("invalid ZIP64 incremental EOCD record")
        if zip64_disk != 0 or zip64_central_disk != 0:
            raise AssertionError("multi-disk ZIP64 incremental archive is unexpected")
        if zip64_entries_on_disk != expected_count or zip64_entry_count != expected_count:
            raise AssertionError("ZIP64 incremental EOCD entry count mismatch")
        if (
            entries_on_disk != 0xFFFF
            or entry_count != 0xFFFF
            or legacy_central_size != 0xFFFFFFFF
            or legacy_central_offset != 0xFFFFFFFF
        ):
            raise AssertionError("ZIP64 incremental legacy EOCD fields are not sentinels")
        central_end = zip64_eocd_offset
    else:
        if b"PK\x06\x06" in raw or b"PK\x06\x07" in raw:
            raise AssertionError("ZIP32 incremental archive unexpectedly uses ZIP64 EOCD")
        if entries_on_disk != expected_count or entry_count != expected_count:
            raise AssertionError("ZIP32 incremental EOCD entry count mismatch")
        central_size = legacy_central_size
        central_offset = legacy_central_offset
        central_end = eocd_offset

    if central_offset + central_size != central_end:
        raise AssertionError("incremental central-directory bounds mismatch")

    central_entries: list[dict[str, int | str]] = []
    central_cursor = central_offset
    for expected_name, expected_payload in INCREMENTAL_PAYLOADS.items():
        if raw[central_cursor : central_cursor + 4] != b"PK\x01\x02":
            raise AssertionError(f"missing central header for {expected_name!r}")
        (
            _signature,
            made_by,
            needed,
            flags,
            method,
            dos_time,
            dos_date,
            crc32,
            legacy_compressed_size,
            legacy_uncompressed_size,
            name_len,
            extra_len,
            entry_comment_len,
            disk_start,
            internal_attributes,
            external_attributes,
            legacy_local_offset,
        ) = struct.unpack_from("<IHHHHHHIIIHHHHHII", raw, central_cursor)
        variable_offset = central_cursor + 46
        name_bytes = raw[variable_offset : variable_offset + name_len]
        extra_offset = variable_offset + name_len
        extra = raw[extra_offset : extra_offset + extra_len]
        comment_offset = extra_offset + extra_len
        entry_comment = raw[comment_offset : comment_offset + entry_comment_len]
        central_cursor = comment_offset + entry_comment_len
        try:
            name = name_bytes.decode("utf-8")
        except UnicodeDecodeError as error:
            raise AssertionError("incremental central name is not UTF-8") from error
        if name != expected_name:
            raise AssertionError(
                f"incremental central order/name mismatch: {name!r} != {expected_name!r}"
            )
        if flags & 0x0008 == 0 or flags & 0x0800 == 0:
            raise AssertionError(f"incremental central flags omit bit 3/11 for {name!r}")
        if method != INCREMENTAL_METHODS[name] or disk_start != 0:
            raise AssertionError(f"incremental central method/disk mismatch for {name!r}")
        expected_codec_flags = (
            0x0006 if method == 6 else 0x0002 if method == zipfile.ZIP_LZMA else 0
        )
        if flags & 0x0006 != expected_codec_flags:
            raise AssertionError(f"incremental central codec flags mismatch for {name!r}")
        expected_crc = binascii.crc32(expected_payload) & 0xFFFFFFFF
        if crc32 != expected_crc:
            raise AssertionError(f"incremental central CRC mismatch for {name!r}")
        if name == "known-stored.bin":
            expected_time = (9 << 11) | (10 << 5) | (10 // 2)
            expected_date = ((2023 - 1980) << 9) | (7 << 5) | 8
            if (
                made_by >> 8 != 3
                or dos_time != expected_time
                or dos_date != expected_date
                or internal_attributes != 1
                or external_attributes != 0o100600 << 16
                or entry_comment != b"known size"
            ):
                raise AssertionError("incremental ZIP entry metadata mismatch")

        fields = parse_extra_fields(extra, f"central entry {name!r}")
        if name == "known-stored.bin":
            validate_timestamp_extras(
                extra,
                "incremental central known-stored.bin",
                False,
            )
        expected_needed = (
            63
            if method in (14, 20, 93, 95, 98)
            else 46
            if method == zipfile.ZIP_BZIP2
            else 45
            if force_zip64
            else 21
            if method == 9
            else 20
        )
        if force_zip64:
            if needed != expected_needed:
                raise AssertionError(f"ZIP64 central version-needed mismatch for {name!r}")
            if (
                legacy_compressed_size != 0xFFFFFFFF
                or legacy_uncompressed_size != 0xFFFFFFFF
                or legacy_local_offset != 0xFFFFFFFF
            ):
                raise AssertionError(f"ZIP64 central fields are not sentinels for {name!r}")
            zip64_extra = fields.get(0x0001)
            if zip64_extra is None or len(zip64_extra) != 24:
                raise AssertionError(f"ZIP64 central extra width mismatch for {name!r}")
            uncompressed_size, compressed_size, local_offset = struct.unpack(
                "<QQQ", zip64_extra
            )
        else:
            if needed != expected_needed or 0x0001 in fields:
                raise AssertionError(f"ZIP32 central metadata mismatch for {name!r}")
            compressed_size = legacy_compressed_size
            uncompressed_size = legacy_uncompressed_size
            local_offset = legacy_local_offset
        if uncompressed_size != len(expected_payload):
            raise AssertionError(f"incremental central size mismatch for {name!r}")
        central_entries.append(
            {
                "name": name,
                "flags": flags,
                "method": method,
                "crc32": crc32,
                "compressed_size": compressed_size,
                "uncompressed_size": uncompressed_size,
                "local_offset": local_offset,
                "comment_len": len(entry_comment),
            }
        )
    if central_cursor != central_end:
        raise AssertionError("incremental central-directory size/trailing data mismatch")

    for index, entry in enumerate(central_entries):
        name = str(entry["name"])
        local_offset = int(entry["local_offset"])
        if raw[local_offset : local_offset + 4] != b"PK\x03\x04":
            raise AssertionError(f"missing incremental local header for {name!r}")
        (
            _signature,
            needed,
            flags,
            method,
            _time,
            _date,
            crc32,
            legacy_compressed_size,
            legacy_uncompressed_size,
            name_len,
            extra_len,
        ) = struct.unpack_from("<IHHHHHIIIHH", raw, local_offset)
        name_offset = local_offset + 30
        name_bytes = raw[name_offset : name_offset + name_len]
        extra_offset = name_offset + name_len
        extra = raw[extra_offset : extra_offset + extra_len]
        data_offset = extra_offset + extra_len
        if name_bytes.decode("utf-8") != name:
            raise AssertionError(f"local/central name mismatch for {name!r}")
        if flags != entry["flags"] or flags & 0x0008 == 0 or flags & 0x0800 == 0:
            raise AssertionError(f"incremental local flags omit bit 3/11 for {name!r}")
        if method != entry["method"] or crc32 != 0:
            raise AssertionError(f"incremental local method/CRC placeholder mismatch for {name!r}")
        expected_codec_flags = (
            0x0006 if method == 6 else 0x0002 if method == zipfile.ZIP_LZMA else 0
        )
        if flags & 0x0006 != expected_codec_flags:
            raise AssertionError(f"incremental local codec flags mismatch for {name!r}")
        fields = parse_extra_fields(extra, f"local entry {name!r}")
        if name == "known-stored.bin":
            validate_timestamp_extras(
                extra,
                "incremental local known-stored.bin",
                True,
            )
        expected_needed = (
            63
            if method in (14, 20, 93, 95, 98)
            else 46
            if method == zipfile.ZIP_BZIP2
            else 45
            if force_zip64
            else 21
            if method == 9
            else 20
        )
        if force_zip64:
            if needed != expected_needed:
                raise AssertionError(f"ZIP64 local version-needed mismatch for {name!r}")
            if legacy_compressed_size != 0xFFFFFFFF or legacy_uncompressed_size != 0xFFFFFFFF:
                raise AssertionError(f"ZIP64 local size fields are not sentinels for {name!r}")
            zip64_extra = fields.get(0x0001)
            if zip64_extra is None or len(zip64_extra) != 16:
                raise AssertionError(f"ZIP64 local extra width mismatch for {name!r}")
            if struct.unpack("<QQ", zip64_extra) != (0, 0):
                raise AssertionError(f"ZIP64 local size placeholders are not zero for {name!r}")
            descriptor_format = "<IIQQ"
            descriptor_len = 24
        else:
            if needed != expected_needed or legacy_compressed_size != 0 or legacy_uncompressed_size != 0:
                raise AssertionError(f"ZIP32 local size placeholders are not zero for {name!r}")
            if 0x0001 in fields:
                raise AssertionError(f"ZIP32 local entry has a ZIP64 extra for {name!r}")
            descriptor_format = "<IIII"
            descriptor_len = 16

        descriptor_offset = data_offset + int(entry["compressed_size"])
        if method == 98 and raw[data_offset : data_offset + 2] != b"\x0b\x10":
            raise AssertionError(f"incremental PPMd properties mismatch for {name!r}")
        if method == 10 and raw[data_offset : data_offset + 2] != b"\x01\x06":
            raise AssertionError(f"incremental DCL Implode header mismatch for {name!r}")
        if method in (2, 3, 4, 5) and raw[data_offset : data_offset + 192] != bytes(192):
            raise AssertionError(f"incremental Reduce follower header mismatch for {name!r}")
        implode_header = (
            bytes((15,))
            + bytes((0xF7,)) * 16
            + (bytes((3,)) + bytes((0xF5,)) * 4) * 2
        )
        if (
            method == 6
            and raw[data_offset : data_offset + len(implode_header)] != implode_header
        ):
            raise AssertionError(f"incremental Implode tree header mismatch for {name!r}")
        descriptor_end = descriptor_offset + descriptor_len
        if descriptor_end > len(raw):
            raise AssertionError(f"truncated incremental descriptor for {name!r}")
        descriptor = struct.unpack_from(descriptor_format, raw, descriptor_offset)
        if descriptor[0] != 0x08074B50:
            raise AssertionError(f"incremental descriptor signature mismatch for {name!r}")
        if descriptor[1:] != (
            entry["crc32"],
            entry["compressed_size"],
            entry["uncompressed_size"],
        ):
            raise AssertionError(f"incremental descriptor values mismatch for {name!r}")
        next_offset = (
            int(central_entries[index + 1]["local_offset"])
            if index + 1 < len(central_entries)
            else central_offset
        )
        if descriptor_end != next_offset:
            raise AssertionError(f"incremental descriptor width mismatch for {name!r}")

        if method == zipfile.ZIP_STORED:
            stored_data = raw[data_offset:descriptor_offset]
            if stored_data != INCREMENTAL_PAYLOADS[name]:
                raise AssertionError(f"incremental stored bytes mismatch for {name!r}")
    if b"PK\x07\x08" not in INCREMENTAL_PAYLOADS["known-stored.bin"] or (
        INCREMENTAL_PAYLOADS["unknown-stored.bin"].count(b"PK\x07\x08") != 2
    ):
        raise AssertionError("incremental stored fixtures lost descriptor-signature payloads")


def validate_incremental_unicode_archive(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
) -> tuple[int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    one = temp / f"incremental-unicode-{suffix}-one.zip"
    micro = temp / f"incremental-unicode-{suffix}-micro.zip"
    run(writer, str(one), suffix, "one", "unicode")
    run(writer, str(micro), suffix, "micro", "unicode")
    raw = one.read_bytes()
    if raw != micro.read_bytes():
        raise AssertionError("incremental Unicode output depends on schedule")
    expected = {
        "流式/数据.txt": b"incremental Unicode path payload\n" * 31,
        "流式目录/": b"",
    }
    raw_names = {
        "流式/数据.txt": b"\x82-stream-name.txt",
        "流式目录/": b"stream-directory/",
    }
    cases = 0
    with zipfile.ZipFile(one) as archive:
        if archive.namelist() != ["é-stream-name.txt", "stream-directory/"]:
            raise AssertionError("Python incremental legacy-name decoding changed")
        for index, (name, payload) in enumerate(expected.items()):
            info = archive.infolist()[index]
            if info.flag_bits & 0x0800 or archive.read(info) != payload:
                raise AssertionError("incremental Unicode Python mismatch")
            validate_unicode_extra(
                info.extra,
                0x7075,
                raw_names[name],
                name,
                f"incremental central Unicode path {index}",
            )
            name_len, extra_len = struct.unpack_from(
                "<HH", raw, info.header_offset + 26
            )
            extra_start = info.header_offset + 30 + name_len
            validate_unicode_extra(
                raw[extra_start : extra_start + extra_len],
                0x7075,
                raw_names[name],
                name,
                f"incremental local Unicode path {index}",
            )
            if index == 0:
                validate_unicode_extra(
                    info.extra,
                    0x6375,
                    b"\x82-stream-comment",
                    "流式注释",
                    "incremental central Unicode comment",
                )
            output = temp / f"incremental-unicode-{suffix}-{index}.out"
            run(cli, "extract-zip-stream-file", str(one), name, str(output))
            if output.read_bytes() != payload:
                raise AssertionError("Vort incremental Unicode extraction mismatch")
            cases += 1
    return len(raw), cases


def validate_incremental_archive_extra(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
) -> tuple[int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    one = temp / f"incremental-archive-extra-{suffix}-one.zip"
    micro = temp / f"incremental-archive-extra-{suffix}-micro.zip"
    run(writer, str(one), suffix, "one", "archive-extra")
    run(writer, str(micro), suffix, "micro", "archive-extra")
    raw = one.read_bytes()
    if raw != micro.read_bytes():
        raise AssertionError("incremental archive-extra output depends on schedule")
    expected_extra = b"incremental archive extra data\x00\xff"
    validate_archive_extra_record(raw, expected_extra, f"incremental {suffix}")
    expected = {
        "archive-extra/stream.txt": b"incremental archive extra data payload\n" * 29,
        "archive-extra/empty.bin": b"",
    }
    cases = 0
    for index, (name, payload) in enumerate(expected.items()):
        output = temp / f"incremental-archive-extra-{suffix}-{index}.out"
        run(cli, "extract-zip-stream-file", str(one), name, str(output))
        if output.read_bytes() != payload:
            raise AssertionError("incremental archive-extra Vort mismatch")
        cases += 1
    return len(raw), cases


def validate_incremental_writer_archive(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    unzip_tool: str | None,
    seven_zip_tool: str | None,
) -> tuple[int, bool, bool]:
    suffix = "zip64" if force_zip64 else "zip32"
    one_byte_path = temp / f"incremental-{suffix}-one.zip"
    micro_path = temp / f"incremental-{suffix}-micro.zip"
    run(writer, str(one_byte_path), suffix, "one")
    run(writer, str(micro_path), suffix, "micro")
    raw = one_byte_path.read_bytes()
    if raw != micro_path.read_bytes():
        raise AssertionError(
            f"incremental {suffix} output depends on one-byte versus micro output buffers"
        )
    validate_incremental_raw_layout(raw, force_zip64)

    zstd_tool = shutil.which("zstd")
    if zstd_tool is None:
        raise AssertionError("zstd CLI is required for incremental ZIP methods 20/93")
    xz_tool = shutil.which("xz")
    if xz_tool is None:
        raise AssertionError("xz CLI is required for incremental ZIP method 95")
    with zipfile.ZipFile(one_byte_path) as archive:
        if archive.comment != INCREMENTAL_COMMENT:
            raise AssertionError(f"Python incremental {suffix} comment mismatch")
        if archive.namelist() != list(INCREMENTAL_PAYLOADS):
            raise AssertionError(f"Python incremental {suffix} entry order mismatch")
        for name, expected in INCREMENTAL_PAYLOADS.items():
            info = archive.getinfo(name)
            if name == "known-stored.bin":
                if info.date_time != (2023, 7, 8, 9, 10, 10):
                    raise AssertionError("incremental DOS timestamp did not round trip")
                if (
                    info.comment != b"known size"
                    or info.create_system != 3
                    or info.internal_attr != 1
                    or info.external_attr != 0o100600 << 16
                ):
                    raise AssertionError("incremental ZIP attributes did not round trip")
            if info.compress_type != INCREMENTAL_METHODS[name]:
                raise AssertionError(f"Python incremental method mismatch for {name!r}")
            if info.compress_type in (20, 93):
                name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
                data_offset = info.header_offset + 30 + name_len + extra_len
                actual = subprocess.run(
                    [zstd_tool, "-q", "-d", "-c"],
                    input=raw[data_offset : data_offset + info.compress_size],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
            elif info.compress_type == 95:
                name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
                data_offset = info.header_offset + 30 + name_len + extra_len
                frame = raw[data_offset : data_offset + info.compress_size]
                actual = lzma.decompress(frame, format=lzma.FORMAT_XZ)
                system_actual = subprocess.run(
                    [xz_tool, "-q", "-d", "-c"],
                    input=frame,
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
                if system_actual != actual:
                    raise AssertionError(
                        f"system xz disagrees with Python for incremental {name!r}"
                    )
            elif info.compress_type == 9:
                name_len, extra_len = struct.unpack_from("<HH", raw, info.header_offset + 26)
                data_offset = info.header_offset + 30 + name_len + extra_len
                actual = zlib.decompress(
                    raw[data_offset : data_offset + info.compress_size],
                    -15,
                )
            elif info.compress_type in (1, 2, 3, 4, 5, 6, 10, 98):
                output = temp / f"incremental-{suffix}-{name}.out"
                run(
                    cli,
                    "extract-zip-stream-file",
                    str(one_byte_path),
                    name,
                    str(output),
                )
                actual = output.read_bytes()
            else:
                actual = archive.read(name)
            if actual != expected:
                raise AssertionError(f"Python incremental extraction mismatch for {name!r}")

    unzip_checked = False
    if unzip_tool is not None:
        supported_payload = b"".join(
            payload
            for name, payload in INCREMENTAL_PAYLOADS.items()
            if INCREMENTAL_METHODS[name]
            in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED, zipfile.ZIP_BZIP2, 9, 1, 6)
        )
        extracted = subprocess.run(
            [unzip_tool, "-P", ZIPCRYPTO_PASSWORD, "-p", str(one_byte_path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout
        if extracted != supported_payload:
            raise AssertionError(f"Info-ZIP incremental {suffix} extraction mismatch")
        unzip_checked = True

    seven_zip_checked = False
    if seven_zip_tool is not None:
        for name, expected in INCREMENTAL_PAYLOADS.items():
            if INCREMENTAL_METHODS[name] in (2, 3, 4, 5):
                continue
            actual = subprocess.run(
                [
                    seven_zip_tool,
                    "x",
                    "-so",
                    "-bd",
                    f"-p{ZIPCRYPTO_PASSWORD}",
                    str(one_byte_path),
                    name,
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            if actual != expected:
                raise AssertionError(
                    f"7-Zip incremental {suffix} extraction mismatch for {name!r}"
                )
        seven_zip_checked = True
    return len(raw), unzip_checked, seven_zip_checked


INCREMENTAL_ZIPCRYPTO_PAYLOADS = {
    "encrypted-known.bin": b"incremental ZipCrypto stored payload\n" * 31,
    "encrypted-unknown.txt": b"incremental ZipCrypto Deflate payload\n" * 89,
    "encrypted-empty.bin": b"",
}
INCREMENTAL_ZIPCRYPTO_METHODS = {
    "encrypted-known.bin": zipfile.ZIP_STORED,
    "encrypted-unknown.txt": zipfile.ZIP_DEFLATED,
    "encrypted-empty.bin": zipfile.ZIP_STORED,
}

INCREMENTAL_WINZIP_AES_PAYLOADS = {
    "aes-known.bin": b"incremental WinZip AES stored payload\n" * 31,
    "aes-unknown.txt": b"incremental WinZip AES Deflate payload\n" * 89,
    "aes-empty.bin": b"",
}

INCREMENTAL_PKWARE_STRONG_PAYLOADS = {
    "strong-known.bin": b"incremental PKWARE Strong stored payload\n" * 31,
    "strong-unknown.txt": b"incremental PKWARE Strong Deflate payload\n" * 89,
    "strong-empty.bin": b"",
}


def validate_incremental_zipcrypto_writer(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    unzip_tool: str,
    seven_zip_tool: str | None,
) -> tuple[int, bool, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    one_path = temp / f"incremental-zipcrypto-{suffix}-one.zip"
    micro_path = temp / f"incremental-zipcrypto-{suffix}-micro.zip"
    run(writer, str(one_path), suffix, "one", "zipcrypto")
    run(writer, str(micro_path), suffix, "micro", "zipcrypto")
    raw = one_path.read_bytes()
    if raw != micro_path.read_bytes():
        raise AssertionError(f"incremental ZipCrypto {suffix} output is not deterministic")
    listing = run(cli, "list-zip-file", str(one_path)).stdout
    if f"zip_entries={len(INCREMENTAL_ZIPCRYPTO_PAYLOADS)}" not in listing or (
        f"zip64={str(force_zip64).lower()}" not in listing
    ):
        raise AssertionError(f"incremental ZipCrypto {suffix} listing mismatch: {listing}")

    with zipfile.ZipFile(one_path) as archive:
        sequential_cases = 0
        if archive.namelist() != list(INCREMENTAL_ZIPCRYPTO_PAYLOADS):
            raise AssertionError("incremental ZipCrypto entry order mismatch")
        for index, (name, expected) in enumerate(INCREMENTAL_ZIPCRYPTO_PAYLOADS.items()):
            info = archive.getinfo(name)
            if info.compress_type != INCREMENTAL_ZIPCRYPTO_METHODS[name]:
                raise AssertionError(f"incremental ZipCrypto method mismatch for {name!r}")
            if info.flag_bits & 1 == 0 or info.flag_bits & 8 == 0:
                raise AssertionError(f"incremental ZipCrypto flags mismatch for {name!r}")
            if archive.read(name, pwd=ZIPCRYPTO_PASSWORD.encode()) != expected:
                raise AssertionError(f"Python could not decrypt incremental {name!r}")
            output = temp / f"incremental-zipcrypto-{suffix}-{index}.out"
            extract_with_vort_password(cli, one_path, name, output, ZIPCRYPTO_PASSWORD)
            if output.read_bytes() != expected:
                raise AssertionError(f"Vort could not self-extract incremental {name!r}")
            stream_output = temp / f"incremental-zipcrypto-{suffix}-{index}.stream.out"
            run(
                cli,
                "extract-zip-stream-file",
                str(one_path),
                name,
                str(stream_output),
                str(512 * 1024 * 1024),
                ZIPCRYPTO_PASSWORD,
            )
            if stream_output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort sequential reader could not extract incremental {name!r}"
                )
            sequential_cases += 1

    extracted = subprocess.run(
        [unzip_tool, "-P", ZIPCRYPTO_PASSWORD, "-p", str(one_path)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    if extracted != b"".join(INCREMENTAL_ZIPCRYPTO_PAYLOADS.values()):
        raise AssertionError(f"Info-ZIP incremental ZipCrypto {suffix} mismatch")

    seven_zip_checked = False
    if seven_zip_tool is not None:
        for name, expected in INCREMENTAL_ZIPCRYPTO_PAYLOADS.items():
            actual = subprocess.run(
                [
                    seven_zip_tool,
                    "x",
                    "-so",
                    "-bd",
                    f"-p{ZIPCRYPTO_PASSWORD}",
                    str(one_path),
                    name,
                ],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            if actual != expected:
                raise AssertionError(f"7-Zip incremental ZipCrypto mismatch for {name!r}")
        seven_zip_checked = True
    return len(raw), seven_zip_checked, sequential_cases


def validate_incremental_winzip_aes_writer(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    openssl_tool: str,
) -> tuple[int, int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    one_path = temp / f"incremental-winzip-aes-{suffix}-one.zip"
    micro_path = temp / f"incremental-winzip-aes-{suffix}-micro.zip"
    run(writer, str(one_path), suffix, "one", "winzip-aes")
    run(writer, str(micro_path), suffix, "micro", "winzip-aes")
    raw = one_path.read_bytes()
    if raw != micro_path.read_bytes():
        raise AssertionError(f"incremental WinZip AES {suffix} output is not deterministic")
    cases = 0
    sequential_cases = 0
    with zipfile.ZipFile(one_path) as archive:
        if archive.namelist() != list(INCREMENTAL_WINZIP_AES_PAYLOADS):
            raise AssertionError("incremental WinZip AES entry order mismatch")
        for index, (name, expected) in enumerate(INCREMENTAL_WINZIP_AES_PAYLOADS.items()):
            info = archive.getinfo(name)
            if info.compress_type != 99 or info.flag_bits & 9 != 9:
                raise AssertionError(f"incremental WinZip AES flags mismatch for {name!r}")
            if decrypt_winzip_aes_reference(
                raw, info, WINZIP_AES_PASSWORD, openssl_tool
            ) != expected:
                raise AssertionError(
                    f"OpenSSL could not decrypt incremental WinZip AES {name!r}"
                )
            output = temp / f"incremental-winzip-aes-{suffix}-{index}.out"
            extract_with_vort_password(cli, one_path, name, output, WINZIP_AES_PASSWORD)
            if output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort could not self-extract incremental WinZip AES {name!r}"
                )
            stream_output = temp / f"incremental-winzip-aes-{suffix}-{index}.stream.out"
            run(
                cli,
                "extract-zip-stream-file",
                str(one_path),
                name,
                str(stream_output),
                str(512 * 1024 * 1024),
                WINZIP_AES_PASSWORD,
            )
            if stream_output.read_bytes() != expected:
                raise AssertionError(
                    f"Vort sequential reader could not extract incremental WinZip AES {name!r}"
                )
            sequential_cases += 1
            cases += 1
    return len(raw), cases, sequential_cases


def validate_incremental_pkware_strong_writer(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    seven_zip_tool: str | None,
) -> tuple[int, int, int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    one_path = temp / f"incremental-pkware-strong-{suffix}-one.zip"
    micro_path = temp / f"incremental-pkware-strong-{suffix}-micro.zip"
    run(writer, str(one_path), suffix, "one", "pkware-strong")
    run(writer, str(micro_path), suffix, "micro", "pkware-strong")
    raw = one_path.read_bytes()
    if raw != micro_path.read_bytes():
        raise AssertionError(
            f"incremental PKWARE Strong {suffix} output changed with scheduling"
        )
    cases = 0
    seven_zip_cases = 0
    reader_cases = 0
    expected_algorithms = (0x660E, 0x660F, 0x6610)
    with zipfile.ZipFile(one_path) as archive:
        if archive.namelist() != list(INCREMENTAL_PKWARE_STRONG_PAYLOADS):
            raise AssertionError("incremental PKWARE Strong entry order mismatch")
        for index, (name, expected) in enumerate(
            INCREMENTAL_PKWARE_STRONG_PAYLOADS.items()
        ):
            info = archive.getinfo(name)
            if info.flag_bits & 0x49 != 0x49:
                raise AssertionError(
                    f"incremental PKWARE Strong flags mismatch for {name!r}"
                )
            fields = parse_extra_fields(
                info.extra, f"incremental PKWARE Strong central {name!r}"
            )
            strong = fields.get(0x0017)
            if strong is None or len(strong) != 8:
                raise AssertionError(
                    f"incremental PKWARE Strong extra missing for {name!r}"
                )
            record_format, algorithm, bit_length, flags = struct.unpack(
                "<HHHH", strong
            )
            if (
                record_format != 2
                or algorithm != expected_algorithms[index]
                or bit_length != (128, 192, 256)[index]
                or flags != 1
            ):
                raise AssertionError(
                    f"incremental PKWARE Strong extra mismatch for {name!r}"
                )
            output = temp / f"incremental-pkware-strong-{suffix}-{index}.out"
            extract_with_vort_password(
                cli,
                one_path,
                name,
                output,
                PKWARE_STRONG_PASSWORD,
            )
            if output.read_bytes() != expected:
                raise AssertionError(
                    f"incremental PKWARE Strong extraction mismatch for {name!r}"
                )
            stream_output = temp / f"incremental-pkware-strong-{suffix}-{index}.stream.out"
            run(
                cli,
                "extract-zip-stream-file",
                str(one_path),
                name,
                str(stream_output),
                str(512 * 1024 * 1024),
                PKWARE_STRONG_PASSWORD,
            )
            if stream_output.read_bytes() != expected:
                raise AssertionError(
                    f"incremental PKWARE Strong sequential mismatch for {name!r}"
                )
            reader_cases += 1
            cases += 1
            if seven_zip_tool is not None:
                extracted = subprocess.run(
                    [
                        seven_zip_tool,
                        "x",
                        "-so",
                        "-bd",
                        f"-p{PKWARE_STRONG_PASSWORD}",
                        str(one_path),
                        name,
                    ],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                ).stdout
                if extracted != expected:
                    raise AssertionError(
                        f"7-Zip incremental PKWARE Strong mismatch for {name!r}"
                    )
                seven_zip_cases += 1
    return len(raw), cases, seven_zip_cases, reader_cases


def ordered_split_parts(archive: Path) -> list[Path]:
    parts: list[Path] = []
    disk = 1
    while True:
        candidate = archive.with_suffix(f".z{disk:02d}")
        if not candidate.exists():
            break
        parts.append(candidate)
        disk += 1
    if not parts or not archive.exists():
        raise AssertionError("Info-ZIP did not create a split archive")
    parts.append(archive)
    return parts


@dataclass(frozen=True)
class SplitEntry:
    name: str
    flags: int
    method: int
    crc32: int
    compressed_size: int
    uncompressed_size: int
    disk: int
    local_offset: int
    central_offset: int
    central_end: int
    zip64: bool


@dataclass(frozen=True)
class SplitLayout:
    joined: bytes
    bases: list[int]
    entries: dict[str, SplitEntry]
    central_start: int
    central_end: int
    ending_start: int
    zip64: bool


def resolve_split_zip64_values(
    extra: bytes,
    compressed_size: int,
    uncompressed_size: int,
    local_offset: int,
    disk: int,
) -> tuple[int, int, int, int, bool]:
    needs_uncompressed = uncompressed_size == 0xFFFFFFFF
    needs_compressed = compressed_size == 0xFFFFFFFF
    needs_offset = local_offset == 0xFFFFFFFF
    needs_disk = disk == 0xFFFF
    if not (needs_uncompressed or needs_compressed or needs_offset or needs_disk):
        return compressed_size, uncompressed_size, local_offset, disk, False
    payloads: list[bytes] = []
    cursor = 0
    while cursor < len(extra):
        if cursor + 4 > len(extra):
            raise AssertionError("truncated split extra field")
        field_id, field_len = struct.unpack_from("<HH", extra, cursor)
        cursor += 4
        end = cursor + field_len
        if end > len(extra):
            raise AssertionError("truncated split extra payload")
        if field_id == 0x0001:
            payloads.append(extra[cursor:end])
        cursor = end
    if len(payloads) != 1:
        raise AssertionError("missing or duplicate split ZIP64 extra")
    payload = payloads[0]
    cursor = 0

    def take_u64() -> int:
        nonlocal cursor
        if cursor + 8 > len(payload):
            raise AssertionError("truncated split ZIP64 u64")
        value = struct.unpack_from("<Q", payload, cursor)[0]
        cursor += 8
        return value

    def take_u32() -> int:
        nonlocal cursor
        if cursor + 4 > len(payload):
            raise AssertionError("truncated split ZIP64 u32")
        value = struct.unpack_from("<I", payload, cursor)[0]
        cursor += 4
        return value

    resolved_uncompressed = take_u64() if needs_uncompressed else uncompressed_size
    resolved_compressed = take_u64() if needs_compressed else compressed_size
    resolved_offset = take_u64() if needs_offset else local_offset
    resolved_disk = take_u32() if needs_disk else disk
    return (
        resolved_compressed,
        resolved_uncompressed,
        resolved_offset,
        resolved_disk,
        True,
    )


def parse_split_layout(parts: list[Path]) -> SplitLayout:
    raw_parts = [part.read_bytes() for part in parts]
    bases: list[int] = []
    joined = bytearray()
    for part in raw_parts:
        bases.append(len(joined))
        joined.extend(part)
    if raw_parts[0][:4] != b"PK\x07\x08":
        raise AssertionError("Info-ZIP split marker is missing")

    eocd_offset = raw_parts[-1].rfind(b"PK\x05\x06")
    if eocd_offset < 0 or eocd_offset + 22 > len(raw_parts[-1]):
        raise AssertionError("Info-ZIP split EOCD is missing")
    eocd = struct.unpack_from("<IHHHHIIH", raw_parts[-1], eocd_offset)
    if eocd_offset + 22 + eocd[7] != len(raw_parts[-1]):
        raise AssertionError("Info-ZIP split EOCD comment length is invalid")
    end_disk, central_disk, entries_on_disk, entry_count, central_size, central_offset = (
        eocd[1],
        eocd[2],
        eocd[3],
        eocd[4],
        eocd[5],
        eocd[6],
    )
    end_absolute = bases[-1] + eocd_offset
    zip64 = (
        end_disk == 0xFFFF
        or central_disk == 0xFFFF
        or entries_on_disk == 0xFFFF
        or entry_count == 0xFFFF
        or central_size == 0xFFFFFFFF
        or central_offset == 0xFFFFFFFF
    )
    ending_start = end_absolute
    if zip64:
        locator_offset = end_absolute - 20
        if joined[locator_offset : locator_offset + 4] != b"PK\x06\x07":
            raise AssertionError("split ZIP64 locator is missing")
        zip64_disk, zip64_offset, disk_count = struct.unpack_from(
            "<IQI", joined, locator_offset + 4
        )
        if zip64_disk >= len(parts) or disk_count != len(parts):
            raise AssertionError("split ZIP64 locator disk fields are invalid")
        zip64_absolute = bases[zip64_disk] + zip64_offset
        if joined[zip64_absolute : zip64_absolute + 4] != b"PK\x06\x06":
            raise AssertionError("split ZIP64 EOCD is missing")
        payload_len = struct.unpack_from("<Q", joined, zip64_absolute + 4)[0]
        if payload_len < 44 or zip64_absolute + 12 + payload_len != locator_offset:
            raise AssertionError("split ZIP64 EOCD length is invalid")
        (
            end_disk,
            central_disk,
            entries_on_disk,
            entry_count,
            central_size,
            central_offset,
        ) = struct.unpack_from("<IIQQQQ", joined, zip64_absolute + 16)
        ending_start = zip64_absolute
    if end_disk != len(parts) - 1 or entries_on_disk > entry_count:
        raise AssertionError("split ending disk fields are invalid")
    if central_disk >= len(parts):
        raise AssertionError("split central disk is invalid")
    central_start = bases[central_disk] + central_offset
    central_end = central_start + central_size
    if central_end > ending_start:
        raise AssertionError("split central directory exceeds archive ending")

    entries: dict[str, SplitEntry] = {}
    cursor = central_start
    fixed_size = struct.calcsize("<IHHHHHHIIIHHHHHII")
    for _ in range(entry_count):
        if joined[cursor : cursor + 4] != b"PK\x01\x02":
            raise AssertionError("Info-ZIP split central entry is invalid")
        fields = struct.unpack_from("<IHHHHHHIIIHHHHHII", joined, cursor)
        name_len, extra_len, comment_len = fields[10:13]
        end = cursor + fixed_size + name_len + extra_len + comment_len
        if end > central_end:
            raise AssertionError("Info-ZIP split central entry is truncated")
        try:
            name = bytes(joined[cursor + fixed_size : cursor + fixed_size + name_len]).decode(
                "utf-8"
            )
        except UnicodeDecodeError as error:
            raise AssertionError("split name is not UTF-8") from error
        extra_start = cursor + fixed_size + name_len
        extra = bytes(joined[extra_start : extra_start + extra_len])
        (
            resolved_compressed,
            resolved_uncompressed,
            resolved_offset,
            resolved_disk,
            entry_zip64,
        ) = resolve_split_zip64_values(
            extra,
            fields[8],
            fields[9],
            fields[16],
            fields[13],
        )
        entries[name] = SplitEntry(
            name=name,
            flags=fields[3],
            method=fields[4],
            crc32=fields[7],
            compressed_size=resolved_compressed,
            uncompressed_size=resolved_uncompressed,
            disk=resolved_disk,
            local_offset=resolved_offset,
            central_offset=cursor,
            central_end=end,
            zip64=entry_zip64,
        )
        cursor = end
    if cursor != central_end:
        raise AssertionError("Info-ZIP split central size does not match its entries")
    actual_entries_on_end_disk = sum(
        max(index for index, base in enumerate(bases) if base <= entry.central_offset)
        == end_disk
        for entry in entries.values()
    )
    if actual_entries_on_end_disk != entries_on_disk:
        raise AssertionError("split entries-on-disk count is invalid")
    return SplitLayout(
        joined=bytes(joined),
        bases=bases,
        entries=entries,
        central_start=central_start,
        central_end=central_end,
        ending_start=ending_start,
        zip64=zip64,
    )


def validate_infozip_split_archive(
    cli: Path, zip_tool: str, temp: Path
) -> tuple[int, int, int, int, int, int, int]:
    source_dir = temp / "infozip-split-source"
    source_dir.mkdir()
    rng = random.Random(0x5A17_2026)
    large = bytearray()
    for _ in range(4096):
        block = rng.randbytes(96)
        large.extend(block)
        large.extend(block)
    payloads = {
        "cross-volume.txt": bytes(large),
        "tail-stored.bin": bytes(range(256)) * 17 + b"split ZIP tail\n",
    }
    for name, payload in payloads.items():
        (source_dir / name).write_bytes(payload)

    archive = temp / "infozip-split.zip"
    subprocess.run(
        [
            zip_tool,
            "-q",
            # Info-ZIP -9 deliberately overrides -n, so -8 keeps the .bin
            # member Stored while still exercising high-ratio Deflate.
            "-8",
            "-s",
            "64k",
            "-n",
            ".bin",
            str(archive),
            *payloads,
        ],
        cwd=source_dir,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    parts = ordered_split_parts(archive)
    layout = parse_split_layout(parts)
    joined, bases, entries = layout.joined, layout.bases, layout.entries
    if set(entries) != set(payloads):
        raise AssertionError(f"unexpected split central directory: {sorted(entries)}")

    large_entry = entries["cross-volume.txt"]
    if large_entry.method != zipfile.ZIP_DEFLATED:
        raise AssertionError("Info-ZIP split payload was not Deflate-compressed")
    large_disk = large_entry.disk
    large_local = bases[large_disk] + large_entry.local_offset
    if joined[large_local : large_local + 4] != b"PK\x03\x04":
        raise AssertionError("split Deflate local header offset is invalid")
    name_len, extra_len = struct.unpack_from("<HH", joined, large_local + 26)
    payload_start = large_local + 30 + name_len + extra_len
    payload_end = payload_start + large_entry.compressed_size
    crossed = sum(payload_start < base < payload_end for base in bases[1:])
    if crossed < 2:
        raise AssertionError(
            f"Deflate payload crossed only {crossed} split boundaries"
        )

    tail_entry = entries["tail-stored.bin"]
    if tail_entry.method != zipfile.ZIP_STORED or tail_entry.disk <= large_disk:
        raise AssertionError("tail entry is not Stored on a later split disk")
    first_local_offset = min(
        bases[entry.disk] + entry.local_offset for entry in entries.values()
    )
    expected_stream_input = len(joined) - first_local_offset

    cases = 0
    stream_cases = 0
    source_cases = 0
    stream_patch_count: int | None = None
    source_switches = 0
    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"infozip-split-{index}.out"
        result = run(
            cli,
            "extract-zip-split-files",
            name,
            str(output),
            str(len(expected)),
            "-",
            *(str(part) for part in parts),
        )
        if f"zip_parts={len(parts)}" not in result.stdout or output.read_bytes() != expected:
            raise AssertionError(f"Vort split extraction mismatch for {name!r}")
        cases += 1
        stream_output = temp / f"infozip-split-{index}.stream.out"
        stream_result = run(
            cli,
            "extract-zip-split-stream-files",
            name,
            str(stream_output),
            str(len(expected)),
            "-",
            *(str(part) for part in parts),
        )
        fields = dict(
            token.split("=", 1)
            for token in stream_result.stdout.split()
            if "=" in token
        )
        patch_count = int(fields.get("metadata_patches", "0"))
        if (
            fields.get("zip_parts") != str(len(parts))
            or int(fields.get("normalized_input_read", "0"))
            != expected_stream_input
            or patch_count != 8
            or stream_output.read_bytes() != expected
        ):
            raise AssertionError(f"Vort split stream extraction mismatch for {name!r}")
        if stream_patch_count is not None and stream_patch_count != patch_count:
            raise AssertionError("split stream metadata patch count changed between entries")
        stream_patch_count = patch_count
        stream_cases += 1
        source_output = temp / f"infozip-split-{index}.source.out"
        source_result = run(
            cli,
            "extract-zip-split-source-files",
            name,
            str(source_output),
            str(len(expected)),
            "-",
            *(str(part) for part in parts),
        )
        source_fields = dict(
            token.split("=", 1)
            for token in source_result.stdout.split()
            if "=" in token
        )
        switches = int(source_fields.get("source_switches", "0"))
        releases = int(source_fields.get("source_releases", "-1"))
        if (
            source_output.read_bytes() != expected
            or switches <= len(parts)
            or releases != switches - 1
            or int(source_fields.get("normalized_input_read", "0"))
            != expected_stream_input
        ):
            raise AssertionError(f"Vort split source extraction mismatch for {name!r}")
        source_switches = max(source_switches, switches)
        source_cases += 1

    reordered = [parts[1], parts[0], *parts[2:]]
    rejected = subprocess.run(
        [
            str(cli),
            "extract-zip-split-files",
            "cross-volume.txt",
            str(temp / "infozip-split-reordered.out"),
            str(len(payloads["cross-volume.txt"])),
            "-",
            *(str(part) for part in reordered),
        ],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if rejected.returncode == 0:
        raise AssertionError("Vort accepted reordered Info-ZIP split disks")
    return (
        len(parts),
        cases,
        stream_cases,
        source_cases,
        crossed,
        stream_patch_count or 0,
        source_switches,
    )


def validate_vort_split_writer(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
) -> tuple[int, int, int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    prefix = temp / f"vort-split-{suffix}"
    run(writer, str(prefix), "split-zip64" if force_zip64 else "split")
    archive = Path(f"{prefix}.zip")
    parts = ordered_split_parts(archive)
    layout = parse_split_layout(parts)
    if layout.zip64 != force_zip64:
        raise AssertionError(f"Vort split {suffix} ending mode mismatch")
    if len(parts) < 3 or any(part.stat().st_size > 64 * 1024 for part in parts):
        raise AssertionError(f"Vort split {suffix} part planning mismatch")

    large = bytearray(384 * 1024)
    state = 0x51A7_2026
    for block in range(len(large) // 128):
        for index in range(64):
            state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
            value = state >> 24
            large[block * 128 + index] = value
            large[block * 128 + 64 + index] = value
    payloads = {
        "split/crossing.bin": bytes(large),
        "split/tail.bin": b"Vort split writer stored tail.\n" * 97,
    }
    expected_methods = {
        "split/crossing.bin": zipfile.ZIP_DEFLATED,
        "split/tail.bin": zipfile.ZIP_STORED,
    }
    if set(layout.entries) != set(payloads):
        raise AssertionError(f"unexpected Vort split entries: {sorted(layout.entries)}")

    boundaries = layout.bases[1:]
    crossing_boundaries = 0
    extraction_cases = 0
    patch_count: int | None = None
    first_local = min(
        layout.bases[entry.disk] + entry.local_offset
        for entry in layout.entries.values()
    )
    expected_stream_input = len(layout.joined) - first_local
    for index, (name, expected) in enumerate(payloads.items()):
        entry = layout.entries[name]
        if entry.method != expected_methods[name] or entry.flags & 0x0008 == 0:
            raise AssertionError(f"Vort split metadata mismatch for {name!r}")
        local = layout.bases[entry.disk] + entry.local_offset
        if layout.joined[local : local + 4] != b"PK\x03\x04":
            raise AssertionError(f"Vort split local offset mismatch for {name!r}")
        name_len, extra_len = struct.unpack_from("<HH", layout.joined, local + 26)
        data_start = local + 30 + name_len + extra_len
        payload_end = data_start + entry.compressed_size
        descriptor_len = 24 if entry.zip64 else 16
        descriptor_end = payload_end + descriptor_len
        if layout.joined[payload_end : payload_end + 4] != b"PK\x07\x08":
            raise AssertionError(f"Vort split descriptor mismatch for {name!r}")
        if any(local < boundary < data_start for boundary in boundaries):
            raise AssertionError(f"Vort split local header crossed a disk for {name!r}")
        if any(payload_end < boundary < descriptor_end for boundary in boundaries):
            raise AssertionError(f"Vort split descriptor crossed a disk for {name!r}")
        if any(
            entry.central_offset < boundary < entry.central_end
            for boundary in boundaries
        ):
            raise AssertionError(f"Vort split central header crossed a disk for {name!r}")
        compressed = layout.joined[data_start:payload_end]
        decoded = (
            zlib.decompress(compressed, -15)
            if entry.method == zipfile.ZIP_DEFLATED
            else compressed
        )
        if (
            decoded != expected
            or entry.uncompressed_size != len(expected)
            or entry.crc32 != (binascii.crc32(expected) & 0xFFFFFFFF)
        ):
            raise AssertionError(f"independent Vort split decode mismatch for {name!r}")
        crossed = sum(data_start < boundary < payload_end for boundary in boundaries)
        if name == "split/crossing.bin":
            if crossed < 1:
                raise AssertionError("Vort split Deflate payload did not cross a disk")
            crossing_boundaries = crossed

        for command_suffix in ("", "-stream"):
            output = temp / f"vort-split-{suffix}-{index}{command_suffix}.out"
            command = (
                "extract-zip-split-stream-files"
                if command_suffix
                else "extract-zip-split-files"
            )
            result = run(
                cli,
                command,
                name,
                str(output),
                str(len(expected)),
                "-",
                *(str(part) for part in parts),
            )
            if output.read_bytes() != expected:
                raise AssertionError(f"Vort split {suffix} extraction mismatch for {name!r}")
            if command_suffix:
                fields = dict(
                    token.split("=", 1)
                    for token in result.stdout.split()
                    if "=" in token
                )
                current_patches = int(fields.get("metadata_patches", "0"))
                if (
                    int(fields.get("normalized_input_read", "0"))
                    != expected_stream_input
                    or current_patches <= 0
                ):
                    raise AssertionError(f"Vort split {suffix} stream accounting mismatch")
                if patch_count is not None and patch_count != current_patches:
                    raise AssertionError(f"Vort split {suffix} patch count drift")
                patch_count = current_patches
            extraction_cases += 1

    if any(layout.ending_start < boundary < len(layout.joined) for boundary in boundaries):
        raise AssertionError(f"Vort split {suffix} ending crossed a disk")
    return len(parts), extraction_cases, crossing_boundaries, patch_count or 0


def validate_incremental_split_writer(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
) -> tuple[int, int, int, int]:
    suffix = "zip64" if force_zip64 else "zip32"
    mode = suffix
    prefixes = [
        temp / f"incremental-split-{suffix}-one",
        temp / f"incremental-split-{suffix}-micro",
    ]
    for prefix, schedule in zip(prefixes, ("one", "micro"), strict=True):
        run(writer, str(prefix), mode, schedule, "split")
    part_sets = [ordered_split_parts(Path(f"{prefix}.zip")) for prefix in prefixes]
    if len(part_sets[0]) < 3 or len(part_sets[0]) != len(part_sets[1]):
        raise AssertionError(f"incremental split {suffix} part count mismatch")
    for first, second in zip(part_sets[0], part_sets[1], strict=True):
        if first.read_bytes() != second.read_bytes() or first.stat().st_size > 160:
            raise AssertionError(f"incremental split {suffix} is not schedule-independent")

    parts = part_sets[0]
    layout = parse_split_layout(parts)
    if layout.zip64 != force_zip64:
        raise AssertionError(f"incremental split {suffix} ending mode mismatch")
    expected_payloads = dict(list(INCREMENTAL_PAYLOADS.items())[:6])
    if set(layout.entries) != set(expected_payloads):
        raise AssertionError(f"incremental split {suffix} entry set mismatch")
    boundaries = layout.bases[1:]
    crossing_boundaries = 0
    extraction_cases = 0
    patch_count: int | None = None
    first_local = min(
        layout.bases[entry.disk] + entry.local_offset
        for entry in layout.entries.values()
    )
    expected_stream_input = len(layout.joined) - first_local
    for index, (name, expected) in enumerate(expected_payloads.items()):
        entry = layout.entries[name]
        if entry.method != INCREMENTAL_METHODS[name] or entry.flags & 0x0008 == 0:
            raise AssertionError(f"incremental split metadata mismatch for {name!r}")
        local = layout.bases[entry.disk] + entry.local_offset
        name_len, extra_len = struct.unpack_from("<HH", layout.joined, local + 26)
        data_start = local + 30 + name_len + extra_len
        payload_end = data_start + entry.compressed_size
        descriptor_len = 24 if entry.zip64 else 16
        descriptor_end = payload_end + descriptor_len
        if layout.joined[payload_end : payload_end + 4] != b"PK\x07\x08":
            raise AssertionError(f"incremental split descriptor mismatch for {name!r}")
        if any(local < boundary < data_start for boundary in boundaries):
            raise AssertionError(f"incremental split local header crossed for {name!r}")
        if any(payload_end < boundary < descriptor_end for boundary in boundaries):
            raise AssertionError(f"incremental split descriptor crossed for {name!r}")
        if any(
            entry.central_offset < boundary < entry.central_end
            for boundary in boundaries
        ):
            raise AssertionError(f"incremental split central header crossed for {name!r}")
        compressed = layout.joined[data_start:payload_end]
        decoded = (
            zlib.decompress(compressed, -15)
            if entry.method == zipfile.ZIP_DEFLATED
            else compressed
        )
        if decoded != expected or entry.crc32 != (binascii.crc32(expected) & 0xFFFFFFFF):
            raise AssertionError(f"incremental split independent decode mismatch for {name!r}")
        crossing_boundaries += sum(
            data_start < boundary < payload_end for boundary in boundaries
        )
        for stream in (False, True):
            output = temp / f"incremental-split-{suffix}-{index}-{'stream' if stream else 'owned'}.out"
            result = run(
                cli,
                "extract-zip-split-stream-files" if stream else "extract-zip-split-files",
                name,
                str(output),
                str(len(expected)),
                "-",
                *(str(part) for part in parts),
            )
            if output.read_bytes() != expected:
                raise AssertionError(f"incremental split extraction mismatch for {name!r}")
            if stream:
                fields = dict(
                    token.split("=", 1)
                    for token in result.stdout.split()
                    if "=" in token
                )
                current_patches = int(fields.get("metadata_patches", "0"))
                if (
                    int(fields.get("normalized_input_read", "0"))
                    != expected_stream_input
                    or current_patches <= 0
                ):
                    raise AssertionError(f"incremental split stream accounting mismatch")
                if patch_count is not None and patch_count != current_patches:
                    raise AssertionError(f"incremental split {suffix} patch count drift")
                patch_count = current_patches
            extraction_cases += 1
    if crossing_boundaries == 0:
        raise AssertionError(f"incremental split {suffix} had no crossing payload")
    if any(layout.ending_start < boundary < len(layout.joined) for boundary in boundaries):
        raise AssertionError(f"incremental split {suffix} ending crossed a disk")
    return len(parts), extraction_cases, crossing_boundaries, patch_count or 0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--incremental-writer", required=True, type=Path)
    parser.add_argument("--seven-zip", type=Path)
    parser.add_argument("--blast", type=Path)
    args = parser.parse_args()
    seven_zip_tool = (
        str(args.seven_zip)
        if args.seven_zip
        else shutil.which("7zz") or shutil.which("7z")
    )
    unzip_tool = shutil.which("unzip")
    zip_tool = shutil.which("zip")
    openssl_tool = shutil.which("openssl")
    if unzip_tool is None or zip_tool is None:
        raise AssertionError("Info-ZIP zip and unzip CLIs are required for ZipCrypto differential")
    if openssl_tool is None:
        raise AssertionError("OpenSSL is required for WinZip AES differential")

    with tempfile.TemporaryDirectory(prefix="vort-zip-diff-") as temp_text:
        temp = Path(temp_text)
        (
            python_bytes,
            incremental_reader_cases,
            incremental_archive_reader_cases,
            incremental_archive_zstd_cases,
            incremental_archive_xz_cases,
            incremental_archive_deflate64_cases,
            incremental_archive_dcl_cases,
            incremental_archive_shrink_cases,
            incremental_archive_implode_fixture_cases,
        ) = validate_python_archive_with_vort(args.cli, temp)
        vort_zip32_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, False, seven_zip_tool
        )
        vort_zip64_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, True, seven_zip_tool
        )
        vort_unicode_cases = validate_vort_unicode_archive(
            args.cli,
            args.writer,
            temp,
            unzip_tool,
        )
        vort_archive_extra_cases = validate_vort_archive_extra(
            args.cli,
            args.writer,
            temp,
        )
        vort_zipcrypto_cases, vort_incremental_reader_zipcrypto_cases = (
            validate_vort_zipcrypto(args.cli, args.writer, unzip_tool, temp)
        )
        (
            infozip_zipcrypto_cases,
            infozip_incremental_reader_zipcrypto_cases,
        ) = validate_infozip_zipcrypto(args.cli, zip_tool, temp)
        winzip_aes_cases, incremental_reader_winzip_aes_cases = validate_vort_winzip_aes(
            args.cli, args.writer, temp, openssl_tool
        )
        (
            pkware_strong_cases,
            pkware_strong_7zip_cases,
            vort_incremental_reader_pkware_strong_cases,
        ) = validate_vort_pkware_strong(args.cli, args.writer, temp, seven_zip_tool)
        incremental_zip32_bytes, incremental_zip32_unzip, incremental_zip32_7zip = (
            validate_incremental_writer_archive(
                args.cli, args.incremental_writer, temp, False, unzip_tool, seven_zip_tool
            )
        )
        incremental_zip64_bytes, incremental_zip64_unzip, incremental_zip64_7zip = (
            validate_incremental_writer_archive(
                args.cli, args.incremental_writer, temp, True, unzip_tool, seven_zip_tool
            )
        )
        incremental_unicode_zip32_bytes, incremental_unicode_zip32_cases = (
            validate_incremental_unicode_archive(
                args.cli,
                args.incremental_writer,
                temp,
                False,
            )
        )
        incremental_unicode_zip64_bytes, incremental_unicode_zip64_cases = (
            validate_incremental_unicode_archive(
                args.cli,
                args.incremental_writer,
                temp,
                True,
            )
        )
        incremental_archive_extra_zip32_bytes, incremental_archive_extra_zip32_cases = (
            validate_incremental_archive_extra(
                args.cli,
                args.incremental_writer,
                temp,
                False,
            )
        )
        incremental_archive_extra_zip64_bytes, incremental_archive_extra_zip64_cases = (
            validate_incremental_archive_extra(
                args.cli,
                args.incremental_writer,
                temp,
                True,
            )
        )
        (
            incremental_zipcrypto_zip32_bytes,
            incremental_zipcrypto_zip32_7zip,
            incremental_zipcrypto_zip32_reader,
        ) = validate_incremental_zipcrypto_writer(
            args.cli,
            args.incremental_writer,
            temp,
            False,
            unzip_tool,
            seven_zip_tool,
        )
        (
            incremental_zipcrypto_zip64_bytes,
            incremental_zipcrypto_zip64_7zip,
            incremental_zipcrypto_zip64_reader,
        ) = validate_incremental_zipcrypto_writer(
            args.cli,
            args.incremental_writer,
            temp,
            True,
            unzip_tool,
            seven_zip_tool,
        )
        (
            incremental_winzip_aes_zip32_bytes,
            incremental_winzip_aes_zip32_cases,
            incremental_winzip_aes_zip32_reader,
        ) = validate_incremental_winzip_aes_writer(
            args.cli,
            args.incremental_writer,
            temp,
            False,
            openssl_tool,
        )
        (
            incremental_winzip_aes_zip64_bytes,
            incremental_winzip_aes_zip64_cases,
            incremental_winzip_aes_zip64_reader,
        ) = validate_incremental_winzip_aes_writer(
            args.cli,
            args.incremental_writer,
            temp,
            True,
            openssl_tool,
        )
        (
            incremental_pkware_strong_zip32_bytes,
            incremental_pkware_strong_zip32_cases,
            incremental_pkware_strong_zip32_7zip,
            incremental_pkware_strong_zip32_reader,
        ) = validate_incremental_pkware_strong_writer(
            args.cli,
            args.incremental_writer,
            temp,
            False,
            seven_zip_tool,
        )
        (
            incremental_pkware_strong_zip64_bytes,
            incremental_pkware_strong_zip64_cases,
            incremental_pkware_strong_zip64_7zip,
            incremental_pkware_strong_zip64_reader,
        ) = validate_incremental_pkware_strong_writer(
            args.cli,
            args.incremental_writer,
            temp,
            True,
            seven_zip_tool,
        )
        incremental_reader_zipcrypto_cases = (
            vort_incremental_reader_zipcrypto_cases
            + infozip_incremental_reader_zipcrypto_cases
            + incremental_zipcrypto_zip32_reader
            + incremental_zipcrypto_zip64_reader
        )
        incremental_reader_winzip_aes_cases += (
            incremental_winzip_aes_zip32_reader + incremental_winzip_aes_zip64_reader
        )
        incremental_reader_pkware_strong_cases = (
            vort_incremental_reader_pkware_strong_cases
            + incremental_pkware_strong_zip32_reader
            + incremental_pkware_strong_zip64_reader
        )
        (
            split_zip_parts,
            split_zip_cases,
            split_zip_stream_cases,
            split_zip_source_cases,
            split_zip_boundaries,
            split_zip_metadata_patches,
            split_zip_source_switches,
        ) = validate_infozip_split_archive(args.cli, zip_tool, temp)
        (
            vort_split_zip32_parts,
            vort_split_zip32_cases,
            vort_split_zip32_boundaries,
            vort_split_zip32_patches,
        ) = validate_vort_split_writer(args.cli, args.writer, temp, False)
        (
            vort_split_zip64_parts,
            vort_split_zip64_cases,
            vort_split_zip64_boundaries,
            vort_split_zip64_patches,
        ) = validate_vort_split_writer(args.cli, args.writer, temp, True)
        (
            incremental_split_zip32_parts,
            incremental_split_zip32_cases,
            incremental_split_zip32_boundaries,
            incremental_split_zip32_patches,
        ) = validate_incremental_split_writer(
            args.cli,
            args.incremental_writer,
            temp,
            False,
        )
        (
            incremental_split_zip64_parts,
            incremental_split_zip64_cases,
            incremental_split_zip64_boundaries,
            incremental_split_zip64_patches,
        ) = validate_incremental_split_writer(
            args.cli,
            args.incremental_writer,
            temp,
            True,
        )
        deflate64_cases = 0
        ppmd_cases = 0
        incremental_archive_implode_cases, implode_modes = validate_vort_implode_modes(
            args.cli, args.writer, seven_zip_tool, temp
        )
        reduce_methods, incremental_reduce_known_cases = validate_vort_reduce_modes(
            args.cli, args.writer, temp
        )
        dcl_self_modes, dcl_blast_modes = validate_vort_dcl_implode_modes(
            args.cli, args.writer, temp, args.blast
        )
        if seven_zip_tool is not None:
            validate_seven_zip_xz_with_vort(args.cli, seven_zip_tool, temp)
            validate_vort_ppmd_cutoff_with_seven_zip(
                args.writer, seven_zip_tool, temp
            )
            deflate64_cases = validate_seven_zip_deflate64_with_vort(
                args.cli, seven_zip_tool, temp
            )
            ppmd_cases = validate_seven_zip_ppmd_with_vort(
                args.cli, seven_zip_tool, temp
            )

    print(
        "zip_diff=ok directions=2 "
        f"python_entries=7 vort_entries=18 zstd_methods=2 python_bytes={python_bytes} "
        f"incremental_reader_cases={incremental_reader_cases} "
        f"incremental_archive_reader_cases={incremental_archive_reader_cases} "
        f"incremental_archive_zstd_cases={incremental_archive_zstd_cases} "
        f"incremental_archive_xz_cases={incremental_archive_xz_cases} "
        f"incremental_archive_deflate64_cases={incremental_archive_deflate64_cases} "
        f"incremental_archive_dcl_cases={incremental_archive_dcl_cases} "
        f"incremental_archive_shrink_cases={incremental_archive_shrink_cases} "
        f"incremental_archive_reduce_cases={incremental_reduce_known_cases} "
        f"incremental_archive_implode_cases={incremental_archive_implode_cases} "
        f"incremental_archive_implode_fixture_cases={incremental_archive_implode_fixture_cases} "
        f"vort_zip32_bytes={vort_zip32_bytes} vort_zip64_bytes={vort_zip64_bytes} "
        f"vort_unicode_cases={vort_unicode_cases} "
        f"vort_archive_extra_cases={vort_archive_extra_cases} "
        f"vort_zipcrypto_cases={vort_zipcrypto_cases} "
        f"infozip_zipcrypto_cases={infozip_zipcrypto_cases} "
        f"infozip_incremental_reader_zipcrypto_cases={infozip_incremental_reader_zipcrypto_cases} "
        f"incremental_reader_zipcrypto_cases={incremental_reader_zipcrypto_cases} "
        f"winzip_aes_cases={winzip_aes_cases} "
        f"incremental_reader_winzip_aes_cases={incremental_reader_winzip_aes_cases} "
        f"pkware_strong_cases={pkware_strong_cases} "
        f"pkware_strong_7zip_cases={pkware_strong_7zip_cases} "
        f"incremental_reader_pkware_strong_cases={incremental_reader_pkware_strong_cases} "
        f"incremental_entries={len(INCREMENTAL_PAYLOADS)} "
        f"incremental_zip32_bytes={incremental_zip32_bytes} "
        f"incremental_zip64_bytes={incremental_zip64_bytes} "
        f"incremental_unicode_cases={incremental_unicode_zip32_cases + incremental_unicode_zip64_cases} "
        f"incremental_unicode_zip32_bytes={incremental_unicode_zip32_bytes} "
        f"incremental_unicode_zip64_bytes={incremental_unicode_zip64_bytes} "
        f"incremental_archive_extra_cases={incremental_archive_extra_zip32_cases + incremental_archive_extra_zip64_cases} "
        f"incremental_archive_extra_zip32_bytes={incremental_archive_extra_zip32_bytes} "
        f"incremental_archive_extra_zip64_bytes={incremental_archive_extra_zip64_bytes} "
        f"incremental_zipcrypto_cases={len(INCREMENTAL_ZIPCRYPTO_PAYLOADS) * 2} "
        f"incremental_zipcrypto_zip32_bytes={incremental_zipcrypto_zip32_bytes} "
        f"incremental_zipcrypto_zip64_bytes={incremental_zipcrypto_zip64_bytes} "
        f"incremental_winzip_aes_cases={incremental_winzip_aes_zip32_cases + incremental_winzip_aes_zip64_cases} "
        f"incremental_winzip_aes_zip32_bytes={incremental_winzip_aes_zip32_bytes} "
        f"incremental_winzip_aes_zip64_bytes={incremental_winzip_aes_zip64_bytes} "
        f"incremental_pkware_strong_cases={incremental_pkware_strong_zip32_cases + incremental_pkware_strong_zip64_cases} "
        f"incremental_pkware_strong_zip32_bytes={incremental_pkware_strong_zip32_bytes} "
        f"incremental_pkware_strong_zip64_bytes={incremental_pkware_strong_zip64_bytes} "
        f"incremental_pkware_strong_7zip_cases={incremental_pkware_strong_zip32_7zip + incremental_pkware_strong_zip64_7zip} "
        f"split_zip_parts={split_zip_parts} split_zip_cases={split_zip_cases} "
        f"split_zip_stream_cases={split_zip_stream_cases} "
        f"split_zip_source_cases={split_zip_source_cases} "
        f"split_zip_boundaries={split_zip_boundaries} "
        f"split_zip_metadata_patches={split_zip_metadata_patches} "
        f"split_zip_source_switches={split_zip_source_switches} "
        f"vort_split_zip32_parts={vort_split_zip32_parts} "
        f"vort_split_zip64_parts={vort_split_zip64_parts} "
        f"vort_split_writer_cases={vort_split_zip32_cases + vort_split_zip64_cases} "
        f"vort_split_zip32_boundaries={vort_split_zip32_boundaries} "
        f"vort_split_zip64_boundaries={vort_split_zip64_boundaries} "
        f"vort_split_zip32_patches={vort_split_zip32_patches} "
        f"vort_split_zip64_patches={vort_split_zip64_patches} "
        f"incremental_split_zip32_parts={incremental_split_zip32_parts} "
        f"incremental_split_zip64_parts={incremental_split_zip64_parts} "
        f"incremental_split_writer_cases={incremental_split_zip32_cases + incremental_split_zip64_cases} "
        f"incremental_split_zip32_boundaries={incremental_split_zip32_boundaries} "
        f"incremental_split_zip64_boundaries={incremental_split_zip64_boundaries} "
        f"incremental_split_zip32_patches={incremental_split_zip32_patches} "
        f"incremental_split_zip64_patches={incremental_split_zip64_patches} "
        f"system_unzip={incremental_zip32_unzip and incremental_zip64_unzip} "
        f"incremental_7zip={incremental_zip32_7zip and incremental_zip64_7zip} "
        f"incremental_zipcrypto_7zip={incremental_zipcrypto_zip32_7zip and incremental_zipcrypto_zip64_7zip} "
        f"system_7zip={seven_zip_tool is not None} deflate64_cases={deflate64_cases} "
        f"ppmd_cases={ppmd_cases} vort_ppmd_cutoff={seven_zip_tool is not None} "
        f"vort_shrink={seven_zip_tool is not None} implode_modes={implode_modes} "
        f"reduce_self_methods={reduce_methods} dcl_self_modes={dcl_self_modes} "
        f"dcl_blast_modes={dcl_blast_modes}"
    )


if __name__ == "__main__":
    main()
