#!/usr/bin/env python3
"""Bidirectional ZIP32/ZIP64 interoperability for Vort's supported methods."""

from __future__ import annotations

import argparse
import binascii
import io
import lzma
import random
import shutil
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


def validate_python_archive_with_vort(cli: Path, temp: Path) -> tuple[int, int, int]:
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

    xz_payload = b"External XZ ZIP method 95.\n" * 128
    xz_frame = lzma.compress(xz_payload, format=lzma.FORMAT_XZ)
    xz_zip = make_single_entry_zip("external-xz.txt", xz_payload, xz_frame, 95)
    xz_zip_path = temp / "external-xz.zip"
    xz_output_path = temp / "external-xz.out"
    xz_zip_path.write_bytes(xz_zip)
    run(cli, "extract-zip-file", str(xz_zip_path), "external-xz.txt", str(xz_output_path))
    if xz_output_path.read_bytes() != xz_payload:
        raise AssertionError("Vort ZIP method 95 extraction mismatch")
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

    return len(fixture), incremental_cases, stream_cases


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
            if info.date_time != (1980, 1, 1, 0, 0, 0):
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


def validate_vort_implode_modes_with_seven_zip(writer: Path, tool: str, temp: Path) -> int:
    expected = make_legacy_payload(5000, 0x193A72D5)
    sizes: dict[str, int] = {}
    for dictionary, dictionary_flag in (("4k", 0), ("8k", 2)):
        for literals, literal_flag in (("raw", 0), ("tree", 4)):
            mode = f"implode-{dictionary}-{literals}"
            archive = temp / f"vort-{mode}.zip"
            run(writer, str(archive), mode)
            actual = subprocess.run(
                [tool, "x", "-so", "-bd", str(archive), "folder/implode.txt"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            if actual != expected:
                raise AssertionError(f"7-Zip could not extract Vort ZIP {mode} entry")
            with zipfile.ZipFile(archive) as parsed:
                info = parsed.getinfo("folder/implode.txt")
                if info.compress_type != 6:
                    raise AssertionError("Vort Implode writer used the wrong method ID")
                if (info.flag_bits & 6) != (dictionary_flag | literal_flag):
                    raise AssertionError(f"Vort ZIP {mode} flags mismatch")
                sizes[mode] = info.compress_size
    for literals in ("raw", "tree"):
        if sizes[f"implode-8k-{literals}"] >= sizes[f"implode-4k-{literals}"]:
            raise AssertionError("Vort 8 KiB Implode mode did not use its long-distance match")
    return len(sizes)


def validate_vort_reduce_modes(cli: Path, writer: Path, temp: Path) -> int:
    archive = temp / "vort-reduce.zip"
    run(writer, str(archive), "reduce")
    cases = {
        "folder/reduce1.txt": make_legacy_payload(400, 0x10203041),
        "folder/reduce2.txt": make_legacy_payload(800, 0x20304052),
        "folder/reduce3.txt": make_legacy_payload(1500, 0x30405063),
        "folder/reduce4.txt": make_legacy_payload(3000, 0x40506074),
    }
    with zipfile.ZipFile(archive) as parsed:
        for index, (name, expected) in enumerate(cases.items(), start=1):
            info = parsed.getinfo(name)
            if info.compress_type != index + 1:
                raise AssertionError(f"Vort ZIP Reduce method mismatch for {name}")
            output = temp / f"reduce-{index}.out"
            run(cli, "extract-zip-file", str(archive), name, str(output))
            if output.read_bytes() != expected:
                raise AssertionError(f"Vort ZIP Reduce self-extraction mismatch for {name}")
    return len(cases)


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
}
INCREMENTAL_METHODS = {
    "known-stored.bin": zipfile.ZIP_STORED,
    "unknown-stored.bin": zipfile.ZIP_STORED,
    "known-deflate.txt": zipfile.ZIP_DEFLATED,
    "utf8-目录/未知-deflate.txt": zipfile.ZIP_DEFLATED,
    "empty-stored.bin": zipfile.ZIP_STORED,
    "empty-deflate.bin": zipfile.ZIP_DEFLATED,
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
            _made_by,
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
            _made_by,
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
            entry_comment_len,
            disk_start,
            _internal_attributes,
            _external_attributes,
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
        expected_crc = binascii.crc32(expected_payload) & 0xFFFFFFFF
        if crc32 != expected_crc:
            raise AssertionError(f"incremental central CRC mismatch for {name!r}")

        fields = parse_extra_fields(extra, f"central entry {name!r}")
        if force_zip64:
            if needed != 45:
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
            if needed != 20 or 0x0001 in fields:
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
        fields = parse_extra_fields(extra, f"local entry {name!r}")
        if force_zip64:
            if needed != 45:
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
            if needed != 20 or legacy_compressed_size != 0 or legacy_uncompressed_size != 0:
                raise AssertionError(f"ZIP32 local size placeholders are not zero for {name!r}")
            if 0x0001 in fields:
                raise AssertionError(f"ZIP32 local entry has a ZIP64 extra for {name!r}")
            descriptor_format = "<IIII"
            descriptor_len = 16

        descriptor_offset = data_offset + int(entry["compressed_size"])
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


def validate_extracted_tree(root: Path) -> None:
    for name, expected in INCREMENTAL_PAYLOADS.items():
        extracted = root / name
        if not extracted.is_file() or extracted.read_bytes() != expected:
            raise AssertionError(f"external incremental extraction mismatch for {name!r}")


def validate_incremental_writer_archive(
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

    with zipfile.ZipFile(one_byte_path) as archive:
        if archive.comment != INCREMENTAL_COMMENT:
            raise AssertionError(f"Python incremental {suffix} comment mismatch")
        if archive.namelist() != list(INCREMENTAL_PAYLOADS):
            raise AssertionError(f"Python incremental {suffix} entry order mismatch")
        if archive.testzip() is not None:
            raise AssertionError(f"Python reported a corrupt incremental {suffix} entry")
        for name, expected in INCREMENTAL_PAYLOADS.items():
            info = archive.getinfo(name)
            if info.compress_type != INCREMENTAL_METHODS[name]:
                raise AssertionError(f"Python incremental method mismatch for {name!r}")
            if archive.read(name) != expected:
                raise AssertionError(f"Python incremental extraction mismatch for {name!r}")

    unzip_checked = False
    if unzip_tool is not None:
        extracted = subprocess.run(
            [unzip_tool, "-p", str(one_byte_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout
        if extracted != b"".join(INCREMENTAL_PAYLOADS.values()):
            raise AssertionError(f"Info-ZIP incremental {suffix} extraction mismatch")
        unzip_checked = True

    seven_zip_checked = False
    if seven_zip_tool is not None:
        seven_zip_root = temp / f"incremental-{suffix}-7zip"
        seven_zip_root.mkdir()
        subprocess.run(
            [seven_zip_tool, "x", "-y", f"-o{seven_zip_root}", str(one_byte_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        validate_extracted_tree(seven_zip_root)
        seven_zip_checked = True
    return len(raw), unzip_checked, seven_zip_checked


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

    with tempfile.TemporaryDirectory(prefix="vort-zip-diff-") as temp_text:
        temp = Path(temp_text)
        (
            python_bytes,
            incremental_reader_cases,
            incremental_archive_reader_cases,
        ) = validate_python_archive_with_vort(args.cli, temp)
        vort_zip32_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, False, seven_zip_tool
        )
        vort_zip64_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, True, seven_zip_tool
        )
        incremental_zip32_bytes, incremental_zip32_unzip, incremental_zip32_7zip = (
            validate_incremental_writer_archive(
                args.incremental_writer, temp, False, unzip_tool, seven_zip_tool
            )
        )
        incremental_zip64_bytes, incremental_zip64_unzip, incremental_zip64_7zip = (
            validate_incremental_writer_archive(
                args.incremental_writer, temp, True, unzip_tool, seven_zip_tool
            )
        )
        deflate64_cases = 0
        ppmd_cases = 0
        implode_modes = 0
        reduce_methods = validate_vort_reduce_modes(args.cli, args.writer, temp)
        dcl_self_modes, dcl_blast_modes = validate_vort_dcl_implode_modes(
            args.cli, args.writer, temp, args.blast
        )
        if seven_zip_tool is not None:
            validate_seven_zip_xz_with_vort(args.cli, seven_zip_tool, temp)
            validate_vort_ppmd_cutoff_with_seven_zip(
                args.writer, seven_zip_tool, temp
            )
            implode_modes = validate_vort_implode_modes_with_seven_zip(
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
        f"vort_zip32_bytes={vort_zip32_bytes} vort_zip64_bytes={vort_zip64_bytes} "
        f"incremental_entries={len(INCREMENTAL_PAYLOADS)} "
        f"incremental_zip32_bytes={incremental_zip32_bytes} "
        f"incremental_zip64_bytes={incremental_zip64_bytes} "
        f"system_unzip={incremental_zip32_unzip and incremental_zip64_unzip} "
        f"incremental_7zip={incremental_zip32_7zip and incremental_zip64_7zip} "
        f"system_7zip={seven_zip_tool is not None} deflate64_cases={deflate64_cases} "
        f"ppmd_cases={ppmd_cases} vort_ppmd_cutoff={seven_zip_tool is not None} "
        f"vort_shrink={seven_zip_tool is not None} implode_modes={implode_modes} "
        f"reduce_self_methods={reduce_methods} dcl_self_modes={dcl_self_modes} "
        f"dcl_blast_modes={dcl_blast_modes}"
    )


if __name__ == "__main__":
    main()
