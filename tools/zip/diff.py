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


def validate_python_archive_with_vort(cli: Path, temp: Path) -> int:
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

    for index, (name, expected) in enumerate(payloads.items()):
        output = temp / f"python-output-{index}.bin"
        run(cli, "extract-zip-file", str(zip_path), name, str(output))
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort extraction mismatch for {name!r}")

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
    return len(fixture)


def validate_vort_archive_with_python(
    cli: Path,
    writer: Path,
    temp: Path,
    force_zip64: bool,
    seven_zip_tool: str | None,
) -> int:
    payloads = {
        "stored.bin": bytes([0, 1, 2, 255]) + b"stored by Vort",
        "folder/deflated.txt": b"Vort ZIP writer differential.\n" * 128,
        "folder/deflate64.txt": b"Vort ZIP Deflate64 method 9.\n" * 128,
        "folder/bzip2.txt": b"Vort ZIP Bzip2 method 12.\n" * 96,
        "folder/lzma.txt": b"Vort ZIP LZMA method 14.\n" * 96,
        "folder/xz.txt": b"Vort ZIP XZ method 95.\n" * 96,
        "folder/zstd-legacy.txt": b"Vort ZIP legacy Zstandard method 20.\n" * 96,
        "folder/zstd.txt": b"Vort ZIP Zstandard method 93.\n" * 96,
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
            "folder/deflated.txt": zipfile.ZIP_DEFLATED,
            "folder/deflate64.txt": 9,
            "folder/bzip2.txt": zipfile.ZIP_BZIP2,
            "folder/lzma.txt": zipfile.ZIP_LZMA,
            "folder/xz.txt": 95,
            "folder/zstd-legacy.txt": 20,
            "folder/zstd.txt": 93,
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
            elif info.compress_type == 9:
                if seven_zip_tool is None:
                    # The Vort self-extraction pass below still validates the
                    # entry when no independent Deflate64 tool is installed.
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
            if info.compress_type in (20, 93, 95) and info.extract_version != 63:
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--seven-zip", type=Path)
    args = parser.parse_args()
    seven_zip_tool = (
        str(args.seven_zip)
        if args.seven_zip
        else shutil.which("7zz") or shutil.which("7z")
    )

    with tempfile.TemporaryDirectory(prefix="vort-zip-diff-") as temp_text:
        temp = Path(temp_text)
        python_bytes = validate_python_archive_with_vort(args.cli, temp)
        vort_zip32_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, False, seven_zip_tool
        )
        vort_zip64_bytes = validate_vort_archive_with_python(
            args.cli, args.writer, temp, True, seven_zip_tool
        )
        deflate64_cases = 0
        if seven_zip_tool is not None:
            validate_seven_zip_xz_with_vort(args.cli, seven_zip_tool, temp)
            deflate64_cases = validate_seven_zip_deflate64_with_vort(
                args.cli, seven_zip_tool, temp
            )

    print(
        "zip_diff=ok directions=2 "
        f"python_entries=7 vort_entries=10 zstd_methods=2 python_bytes={python_bytes} "
        f"vort_zip32_bytes={vort_zip32_bytes} vort_zip64_bytes={vort_zip64_bytes} "
        f"system_7zip={seven_zip_tool is not None} deflate64_cases={deflate64_cases}"
    )


if __name__ == "__main__":
    main()
