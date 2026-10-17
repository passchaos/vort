#!/usr/bin/env python3
"""Bidirectional checks for Vort's common 7z implementation."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(
    program: Path, *args: str, check: bool = True, cwd: Path | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def seven_zip_extract(
    tool: str, archive: Path, name: str, password: str | None = None
) -> bytes:
    password_args = [f"-p{password}"] if password is not None else []
    return subprocess.run(
        [tool, "x", "-so", "-bd", *password_args, str(archive), name],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def verify_with_seven_zip(
    tool: str,
    archive: Path,
    payloads: dict[str, bytes],
    password: str | None = None,
) -> None:
    password_args = [f"-p{password}"] if password is not None else []
    subprocess.run(
        [tool, "t", "-bd", *password_args, str(archive)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    for name, payload in payloads.items():
        if seven_zip_extract(tool, archive, name, password) != payload:
            raise AssertionError(f"7-Zip could not extract Vort entry {name!r}")


def create_reference(tool: str, tree: Path, archive: Path, options: list[str]) -> None:
    names = ["hello.txt", "second.txt", "empty.txt", "folder", "数据.txt"]
    subprocess.run(
        [
            tool,
            "a",
            "-bd",
            "-y",
            "-t7z",
            "-mtm=on",
            "-mta=on",
            *options,
            str(archive),
            *names,
        ],
        check=True,
        cwd=tree,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def create_reference_payload(
    tool: str, tree: Path, archive: Path, payload: bytes, options: list[str]
) -> None:
    (tree / "payload.bin").write_bytes(payload)
    subprocess.run(
        [tool, "a", "-bd", "-y", "-t7z", *options, str(archive), "payload.bin"],
        check=True,
        cwd=tree,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def verify_with_vort(
    cli: Path,
    archive: Path,
    payloads: dict[str, bytes],
    password: str | None = None,
) -> None:
    list_args = (str(archive), password) if password is not None else (str(archive),)
    listing = run(cli, "list-7z-file", *list_args).stdout
    for name in payloads:
        if f"name={name}" not in listing:
            raise AssertionError(f"7z listing omitted {name!r}: {listing}")
    for index, (name, payload) in enumerate(payloads.items()):
        output = archive.with_name(f"{archive.stem}-{index}.out")
        extract_args = [
            "extract-7z-file",
            str(archive),
            name,
            str(output),
            str(len(payload)),
        ]
        if password is not None:
            extract_args.extend(("536870912", "536870912", password))
        run(cli, *extract_args)
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort 7z extraction mismatch for {name!r}")


def verify_with_vort_source(
    cli: Path,
    archive: Path,
    payloads: dict[str, bytes],
    password: str | None = None,
) -> None:
    list_args = (str(archive), password) if password is not None else (str(archive),)
    listing = run(cli, "list-7z-source-file", *list_args).stdout
    if "seven_zip_source_reads=" not in listing:
        raise AssertionError("7z source listing omitted positional-read diagnostics")
    for name in payloads:
        if f"name={name}" not in listing:
            raise AssertionError(f"7z source listing omitted {name!r}: {listing}")
    for index, (name, payload) in enumerate(payloads.items()):
        output = archive.with_name(f"{archive.stem}-source-{index}.out")
        extract_args = [
            "extract-7z-source-file",
            str(archive),
            name,
            str(output),
            str(len(payload)),
        ]
        if password is not None:
            extract_args.extend(("536870912", "536870912", password))
        result = run(cli, *extract_args).stdout
        if "seven_zip_source_reads=" not in result:
            raise AssertionError("7z source extraction omitted read diagnostics")
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort source extraction mismatch for {name!r}")


def verify_with_vort_source_stream(
    cli: Path,
    archive: Path,
    payloads: dict[str, bytes],
    password: str | None = None,
) -> None:
    for index, (name, payload) in enumerate(payloads.items()):
        output = archive.with_name(f"{archive.stem}-source-stream-{index}.out")
        extract_args = [
            "extract-7z-source-stream-file",
            str(archive),
            name,
            str(output),
            str(len(payload)),
        ]
        if password is not None:
            extract_args.extend(("536870912", "536870912", password))
        result = run(cli, *extract_args).stdout
        if "seven_zip_source_stream_reads=" not in result:
            raise AssertionError("7z source stream extraction omitted diagnostics")
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort source stream mismatch for {name!r}")


def verify_vort_metadata(
    cli: Path,
    archive: Path,
    name: str,
    expected: dict[str, int],
    defined: tuple[str, ...] = (),
) -> None:
    listing = run(cli, "list-7z-file", str(archive)).stdout
    line = next((item for item in listing.splitlines() if f"name={name}" in item), None)
    if line is None:
        raise AssertionError(f"7z listing omitted metadata entry {name!r}: {listing}")
    for field, value in expected.items():
        marker = f"{field}_defined=true {field}={value}"
        if marker not in line:
            raise AssertionError(f"7z metadata mismatch for {name!r}: {marker}: {line}")
    for field in defined:
        if f"{field}_defined=true" not in line:
            raise AssertionError(f"7z metadata omitted {field} for {name!r}: {line}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--seven-zip", type=Path)
    parser.add_argument("--modern-seven-zip", type=Path)
    args = parser.parse_args()
    seven_zip_tool = (
        str(args.seven_zip)
        if args.seven_zip
        else shutil.which("7zz") or shutil.which("7z")
    )
    modern_seven_zip_tool = (
        str(args.modern_seven_zip) if args.modern_seven_zip else None
    )
    modern_branch_filters = False
    if modern_seven_zip_tool is not None:
        methods_output = subprocess.run(
            [modern_seven_zip_tool, "i"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout
        modern_branch_filters = "ARM64" in methods_output and "RISCV" in methods_output
    external_variants = 0
    vort_writer_variants = 1
    source_variants = 1
    stream_variants = 1

    with tempfile.TemporaryDirectory(prefix="vort-seven-zip-diff-") as temp_text:
        temp = Path(temp_text)
        first = temp / "vort-first.7z"
        second = temp / "vort-second.7z"
        run(args.writer, str(first))
        run(args.writer, str(second))
        if first.read_bytes() != second.read_bytes():
            raise AssertionError("Vort 7z stored output is not deterministic")
        expected_vort = {
            "plain.txt": b"Vort 7z payload\n",
            "empty.txt": b"",
            "utf8-目录/数据.txt": "Vort 7z UTF-8\n".encode(),
        }
        verify_with_vort(args.cli, first, expected_vort)
        verify_with_vort_source(args.cli, first, expected_vort)
        verify_with_vort_source_stream(args.cli, first, expected_vort)
        filetime_epoch = 116_444_736_000_000_000
        verify_vort_metadata(
            args.cli,
            first,
            "plain.txt",
            {
                "creation": filetime_epoch + 10_000_000,
                "access": filetime_epoch + 20_000_000,
                "modification": filetime_epoch + 30_000_000,
                "attributes": 0x81A4_0020,
            },
        )

        if seven_zip_tool is not None:
            verify_with_seven_zip(seven_zip_tool, first, expected_vort)
            for compression in ("deflate", "bzip2", "lzma", "lzma2", "ppmd7"):
                archive = temp / f"vort-{compression}-multi.7z"
                run(args.writer, str(archive), compression)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 5

            for compression in ("copy", "deflate", "bzip2", "lzma", "lzma2", "ppmd7"):
                archive = temp / f"vort-{compression}-solid.7z"
                duplicate = temp / f"vort-{compression}-solid-repeat.7z"
                run(args.writer, str(archive), compression, "solid")
                run(args.writer, str(duplicate), compression, "solid")
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(f"Vort solid {compression} output is not deterministic")
                verify_with_vort(args.cli, archive, expected_vort)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 6

            for header_compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
                "ppmd7",
            ):
                archive = temp / f"vort-header-{header_compression}.7z"
                duplicate = temp / f"vort-header-{header_compression}-repeat.7z"
                run(args.writer, str(archive), "lzma2", "solid", header_compression)
                run(args.writer, str(duplicate), "lzma2", "solid", header_compression)
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(
                        f"Vort encoded-header {header_compression} output is not deterministic"
                    )
                verify_with_vort(args.cli, archive, expected_vort)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 7

            encryption_password = "vort-password-密码"
            for compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
                "ppmd7",
            ):
                archive = temp / f"vort-aes-{compression}.7z"
                duplicate = temp / f"vort-aes-{compression}-repeat.7z"
                writer_args = (
                    compression,
                    "solid",
                    "copy",
                    "classic",
                    "0",
                    "inline-names",
                    "inline-metadata",
                    "encrypted",
                    "encrypted-header",
                )
                run(args.writer, str(archive), *writer_args)
                run(args.writer, str(duplicate), *writer_args)
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(
                        f"Vort AES {compression} output is not deterministic"
                    )
                verify_with_vort(
                    args.cli,
                    archive,
                    expected_vort,
                    encryption_password,
                )
                verify_with_seven_zip(
                    seven_zip_tool,
                    archive,
                    expected_vort,
                    encryption_password,
                )
            vort_writer_variants += 7

            standard_kdf_archive = temp / "vort-aes-standard-kdf.7z"
            run(
                args.writer,
                str(standard_kdf_archive),
                "lzma2",
                "solid",
                "copy",
                "classic",
                "0",
                "inline-names",
                "inline-metadata",
                "encrypted-standard",
                "encrypted-header",
            )
            verify_with_vort(
                args.cli,
                standard_kdf_archive,
                expected_vort,
                encryption_password,
            )
            verify_with_seven_zip(
                seven_zip_tool,
                standard_kdf_archive,
                expected_vort,
                encryption_password,
            )
            vort_writer_variants += 1

            combined_encrypted = temp / "vort-aes-external-metadata.7z"
            run(
                args.writer,
                str(combined_encrypted),
                "lzma2",
                "solid",
                "copy",
                "classic",
                "0",
                "external-lzma2",
                "external-metadata-copy",
                "encrypted",
                "encrypted-header",
            )
            verify_with_vort(
                args.cli,
                combined_encrypted,
                expected_vort,
                encryption_password,
            )
            verify_with_seven_zip(
                seven_zip_tool,
                combined_encrypted,
                expected_vort,
                encryption_password,
            )
            verify_with_vort_source(
                args.cli,
                combined_encrypted,
                expected_vort,
                encryption_password,
            )
            source_variants += 1
            verify_with_vort_source_stream(
                args.cli,
                combined_encrypted,
                expected_vort,
                encryption_password,
            )
            stream_variants += 1
            vort_writer_variants += 1

            for name_compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
                "ppmd7",
            ):
                archive = temp / f"vort-external-names-{name_compression}.7z"
                duplicate = temp / f"vort-external-names-{name_compression}-repeat.7z"
                writer_args = (
                    "lzma2",
                    "solid",
                    "lzma2",
                    "classic",
                    "0",
                    f"external-{name_compression}",
                )
                run(args.writer, str(archive), *writer_args)
                run(args.writer, str(duplicate), *writer_args)
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(
                        f"Vort external-name {name_compression} output is not deterministic"
                    )
                verify_with_vort(args.cli, archive, expected_vort)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 7

            for metadata_compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
                "ppmd7",
            ):
                archive = temp / f"vort-external-metadata-{metadata_compression}.7z"
                duplicate = temp / (
                    f"vort-external-metadata-{metadata_compression}-repeat.7z"
                )
                writer_args = (
                    "lzma2",
                    "solid",
                    "lzma2",
                    "classic",
                    "0",
                    "external-lzma2",
                    f"external-metadata-{metadata_compression}",
                )
                run(args.writer, str(archive), *writer_args)
                run(args.writer, str(duplicate), *writer_args)
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(
                        "Vort external-metadata "
                        f"{metadata_compression} output is not deterministic"
                    )
                verify_with_vort(args.cli, archive, expected_vort)
                verify_vort_metadata(
                    args.cli,
                    archive,
                    "plain.txt",
                    {
                        "creation": filetime_epoch + 10_000_000,
                        "access": filetime_epoch + 20_000_000,
                        "modification": filetime_epoch + 30_000_000,
                        "attributes": 0x81A4_0020,
                    },
                )
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 7

            for compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
                "ppmd7",
            ):
                archive = temp / f"vort-bcj2-{compression}.7z"
                duplicate = temp / f"vort-bcj2-{compression}-repeat.7z"
                run(
                    args.writer,
                    str(archive),
                    compression,
                    "solid",
                    "plain",
                    "bcj2",
                    "4096",
                )
                run(
                    args.writer,
                    str(duplicate),
                    compression,
                    "solid",
                    "plain",
                    "bcj2",
                    "4096",
                )
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(f"Vort BCJ2 {compression} output is not deterministic")
                verify_with_vort(args.cli, archive, expected_vort)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 7

            tree = temp / "tree"
            tree.mkdir()
            (tree / "folder").mkdir()
            payloads = {
                "hello.txt": b"hello seven zip\n" * 128,
                "second.txt": b"second file\n" * 257,
                "empty.txt": b"",
                "数据.txt": "Unicode payload 数据\n".encode() * 64,
            }
            for name, payload in payloads.items():
                (tree / name).write_bytes(payload)
            modified_seconds = 1_577_934_245
            access_seconds = 1_612_325_106
            for path in (*((tree / name) for name in payloads), tree / "folder"):
                os.utime(path, (access_seconds, modified_seconds))

            variants = {
                "copy-plain": ["-mx=0", "-mhc=off", "-ms=off"],
                "deflate-plain": ["-m0=deflate", "-mx=5", "-mhc=off", "-ms=off"],
                "bzip2-plain": ["-m0=bzip2", "-mx=5", "-mhc=off", "-ms=off"],
                "lzma-plain": ["-m0=lzma", "-mx=5", "-mhc=off", "-ms=off"],
                "lzma2-plain": ["-m0=lzma2", "-mx=5", "-mhc=off", "-ms=off"],
                "ppmd-order2-plain": [
                    "-m0=PPMd:o=2:mem=64k",
                    "-mhc=off",
                    "-ms=off",
                ],
                "ppmd-order6-solid": [
                    "-m0=PPMd:o=6:mem=256k",
                    "-mhc=on",
                    "-ms=on",
                ],
                "ppmd-order16-plain": [
                    "-m0=PPMd:o=16:mem=1m",
                    "-mhc=off",
                    "-ms=off",
                ],
                "lzma-solid-encoded": ["-m0=lzma", "-mx=5", "-mhc=on", "-ms=on"],
                "lzma2-solid-encoded": ["-m0=lzma2", "-mx=5", "-mhc=on", "-ms=on"],
                "lzma2-bcj2-solid": [
                    "-m0=bcj2",
                    "-m1=lzma2",
                    "-mx=5",
                    "-mhc=off",
                    "-ms=on",
                ],
            }
            for variant, options in variants.items():
                archive = temp / f"{variant}.7z"
                create_reference(seven_zip_tool, tree, archive, options)
                verify_with_vort(args.cli, archive, payloads)
                if variant == "lzma2-solid-encoded":
                    verify_with_vort_source(args.cli, archive, payloads)
                    source_variants += 1
                if variant in (
                    "copy-plain",
                    "deflate-plain",
                    "bzip2-plain",
                    "lzma-plain",
                    "lzma2-plain",
                    "lzma-solid-encoded",
                    "lzma2-solid-encoded",
                ):
                    verify_with_vort_source_stream(args.cli, archive, payloads)
                    stream_variants += 1
                if variant == "copy-plain":
                    verify_vort_metadata(
                        args.cli,
                        archive,
                        "hello.txt",
                        {
                            "modification": filetime_epoch
                            + modified_seconds * 10_000_000,
                        },
                        ("access", "attributes"),
                    )
            external_variants += len(variants)

            ppmd_tree = temp / "ppmd-tree"
            ppmd_tree.mkdir()
            ppmd_stress_payload = (
                (b"PPMd context restart and allocator pressure\n" * 4096)
                + (bytes(range(256)) * 1024)
                + (b"suffix-model-0123456789-abcdefghijklmnopqrstuvwxyz\n" * 4096)
            )
            ppmd_stress_archive = temp / "ppmd-order16-small-memory.7z"
            create_reference_payload(
                seven_zip_tool,
                ppmd_tree,
                ppmd_stress_archive,
                ppmd_stress_payload,
                ["-m0=PPMd:o=16:mem=64k", "-mhc=off", "-ms=off"],
            )
            verify_with_vort(
                args.cli,
                ppmd_stress_archive,
                {"payload.bin": ppmd_stress_payload},
            )
            external_variants += 1

            filter_tree = temp / "filter-tree"
            filter_tree.mkdir()
            x86_payload = (
                b"\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" * 256
            )
            bcj2_input = filter_tree / "bcj2-writer.bin"
            bcj2_input.write_bytes(x86_payload)
            bcj2_archive = temp / "vort-bcj2-markers.7z"
            run(
                args.cli,
                "create-7z-file",
                str(bcj2_archive),
                "bcj2-writer.bin",
                str(bcj2_input),
                "lzma2",
                "none",
                "non-solid",
                "plain",
                "bcj2",
                "4096",
            )
            verify_with_vort(
                args.cli,
                bcj2_archive,
                {"bcj2-writer.bin": x86_payload},
            )
            verify_with_seven_zip(
                seven_zip_tool,
                bcj2_archive,
                {"bcj2-writer.bin": x86_payload},
            )
            vort_writer_variants += 1
            filter_variants = {
                "bcj-lzma2": (("bcj", "lzma2"), x86_payload),
                "delta4-lzma2": (
                    ("delta:4", "lzma2"),
                    bytes(range(256)) * 16,
                ),
                "delta4-ppmd": (
                    ("delta:4", "PPMd:o=6:mem=64k"),
                    bytes(range(256)) * 16,
                ),
                "bcj-lzma": (("bcj", "lzma"), x86_payload),
                "bcj-ppmd": (("bcj", "PPMd:o=6:mem=64k"), x86_payload),
                "bcj2-lzma2": (("bcj2", "lzma2"), x86_payload),
                "bcj2-lzma": (("bcj2", "lzma"), x86_payload),
                "bcj-delta4-lzma2": (
                    ("bcj", "delta:4", "lzma2"),
                    x86_payload,
                ),
                "ppc-lzma2": (
                    ("ppc", "lzma2"),
                    b"\x48\x00\x00\x01\x4b\xff\xff\xfd" * 256,
                ),
                "ia64-lzma2": (
                    ("ia64", "lzma2"),
                    b"\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" * 256,
                ),
                "arm-lzma2": (
                    ("arm", "lzma2"),
                    b"\x04\x00\x00\xeb\xfc\xff\xff\xeb" * 256,
                ),
                "arm-thumb-lzma2": (
                    ("armt", "lzma2"),
                    b"\x00\xf0\x00\xf8\xff\xf7\xff\xff" * 256,
                ),
                "sparc-lzma2": (
                    ("sparc", "lzma2"),
                    b"\x40\x00\x00\x00\x7f\xff\xff\xff" * 256,
                ),
            }
            if modern_branch_filters:
                filter_variants.update(
                    {
                        "arm64-lzma2": (
                            ("arm64", "lzma2"),
                            b"\x00\x00\x00\x94\x00\x00\x00\x90" * 256,
                        ),
                        "riscv-lzma2": (
                            ("riscv", "lzma2"),
                            b"\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00"
                            * 128,
                        ),
                    }
                )
            for variant, (methods, payload) in filter_variants.items():
                archive = temp / f"{variant}.7z"
                options = [f"-m{index}={method}" for index, method in enumerate(methods)]
                options.extend(("-mx=5", "-mhc=off", "-ms=off"))
                reference_tool = (
                    modern_seven_zip_tool
                    if variant in ("arm64-lzma2", "riscv-lzma2")
                    else seven_zip_tool
                )
                create_reference_payload(reference_tool, filter_tree, archive, payload, options)
                verify_with_vort(args.cli, archive, {"payload.bin": payload})
            external_variants += len(filter_variants)

            encrypted_payload = b"7-Zip AES reference payload\n" * 37
            encrypted_references = {
                "aes-data": [
                    "-m0=lzma2",
                    "-mx=5",
                    "-mhc=off",
                    "-mhe=off",
                    "-pseven-zip-password",
                ],
                "aes-header": [
                    "-m0=lzma2",
                    "-mx=5",
                    "-mhc=on",
                    "-mhe=on",
                    "-pseven-zip-password",
                ],
                "aes-ppmd": [
                    "-m0=PPMd:o=6:mem=64k",
                    "-mhc=off",
                    "-mhe=off",
                    "-pseven-zip-password",
                ],
            }
            for variant, options in encrypted_references.items():
                archive = temp / f"{variant}.7z"
                create_reference_payload(
                    seven_zip_tool,
                    filter_tree,
                    archive,
                    encrypted_payload,
                    options,
                )
                verify_with_vort(
                    args.cli,
                    archive,
                    {"payload.bin": encrypted_payload},
                    "seven-zip-password",
                )
                if variant == "aes-header":
                    verify_with_vort_source(
                        args.cli,
                        archive,
                        {"payload.bin": encrypted_payload},
                        "seven-zip-password",
                    )
                    source_variants += 1
                if variant in ("aes-data", "aes-header"):
                    verify_with_vort_source_stream(
                        args.cli,
                        archive,
                        {"payload.bin": encrypted_payload},
                        "seven-zip-password",
                    )
                    stream_variants += 1
            external_variants += len(encrypted_references)

            encrypted_bcj2_archive = temp / "aes-bcj2.7z"
            create_reference_payload(
                seven_zip_tool,
                filter_tree,
                encrypted_bcj2_archive,
                x86_payload,
                [
                    "-m0=bcj2",
                    "-m1=lzma2",
                    "-mx=5",
                    "-mhc=off",
                    "-mhe=off",
                    "-pseven-zip-password",
                ],
            )
            verify_with_vort(
                args.cli,
                encrypted_bcj2_archive,
                {"payload.bin": x86_payload},
                "seven-zip-password",
            )
            verify_with_vort_source(
                args.cli,
                encrypted_bcj2_archive,
                {"payload.bin": x86_payload},
                "seven-zip-password",
            )
            external_variants += 1
            source_variants += 1

            wrong_password = run(
                args.cli,
                "list-7z-file",
                str(temp / "aes-header.7z"),
                "wrong-password",
                check=False,
            )
            if wrong_password.returncode == 0:
                raise AssertionError("7z encrypted header accepted a wrong password")

            encrypted_filter_input = filter_tree / "payload.bin"
            encrypted_filter_input.write_bytes(x86_payload)
            encrypted_filter_archive = temp / "vort-aes-x86.7z"
            run(
                args.cli,
                "create-7z-file",
                str(encrypted_filter_archive),
                "payload.bin",
                str(encrypted_filter_input),
                "lzma2",
                "x86",
                "non-solid",
                "plain",
                "classic",
                "0",
                "inline-names",
                "inline-metadata",
                "-",
                "-",
                "-",
                "-",
                encryption_password,
                "42424242424242424242424242424242",
                "2424242424242424",
                "63",
                "plain-header",
            )
            verify_with_vort(
                args.cli,
                encrypted_filter_archive,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            verify_with_seven_zip(
                seven_zip_tool,
                encrypted_filter_archive,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            verify_with_vort_source_stream(
                args.cli,
                encrypted_filter_archive,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            vort_writer_variants += 1
            stream_variants += 1

            encrypted_bcj2_output = temp / "vort-aes-bcj2.7z"
            run(
                args.cli,
                "create-7z-file",
                str(encrypted_bcj2_output),
                "payload.bin",
                str(encrypted_filter_input),
                "lzma2",
                "none",
                "non-solid",
                "plain",
                "bcj2",
                "0",
                "inline-names",
                "inline-metadata",
                "-",
                "-",
                "-",
                "-",
                encryption_password,
                "42424242424242424242424242424242",
                "2424242424242424",
                "63",
                "plain-header",
            )
            verify_with_vort(
                args.cli,
                encrypted_bcj2_output,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            verify_with_seven_zip(
                seven_zip_tool,
                encrypted_bcj2_output,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            verify_with_vort_source(
                args.cli,
                encrypted_bcj2_output,
                {"payload.bin": x86_payload},
                encryption_password,
            )
            vort_writer_variants += 1
            source_variants += 1

            writer_variants = {
                "lzma2-multichunk": (
                    "lzma2",
                    "none",
                    b"multi-chunk literal LZMA2 payload\n" * 4096,
                ),
                "ppmd7-large": (
                    "ppmd7",
                    "none",
                    b"PPMd7 large writer payload\n" * 8192,
                ),
                "bcj-deflate": ("deflate", "x86", x86_payload),
                "bcj-lzma": ("lzma", "x86", x86_payload),
                "bcj-ppmd7": ("ppmd7", "x86", x86_payload),
                "delta4-bzip2": ("bzip2", "delta:4", bytes(range(256)) * 16),
                "delta4-ppmd7": ("ppmd7", "delta:4", bytes(range(256)) * 16),
                "bcj-lzma2": ("lzma2", "x86", x86_payload),
                "delta4-lzma2-stored": (
                    "lzma2-stored",
                    "delta:4",
                    bytes(range(256)) * 16,
                ),
                "bcj-delta4-lzma2": (
                    "lzma2",
                    "x86,delta:4",
                    x86_payload,
                ),
                "ppc-lzma2": (
                    "lzma2",
                    "powerpc",
                    b"\x48\x00\x00\x01\x4b\xff\xff\xfd" * 256,
                ),
                "ia64-lzma2": (
                    "lzma2",
                    "ia64",
                    b"\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" * 256,
                ),
                "arm-lzma2": (
                    "lzma2",
                    "arm",
                    b"\x04\x00\x00\xeb\xfc\xff\xff\xeb" * 256,
                ),
                "arm-thumb-lzma2": (
                    "lzma2",
                    "arm-thumb",
                    b"\x00\xf0\x00\xf8\xff\xf7\xff\xff" * 256,
                ),
                "sparc-lzma2": (
                    "lzma2",
                    "sparc",
                    b"\x40\x00\x00\x00\x7f\xff\xff\xff" * 256,
                ),
            }
            if modern_branch_filters:
                writer_variants.update(
                    {
                        "arm64-lzma2": (
                            "lzma2",
                            "arm64",
                            b"\x00\x00\x00\x94\x00\x00\x00\x90" * 256,
                        ),
                        "riscv-lzma2": (
                            "lzma2",
                            "riscv",
                            b"\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00"
                            * 128,
                        ),
                    }
                )
            for variant, (compression, filter_spec, payload) in writer_variants.items():
                input_path = filter_tree / "payload.bin"
                input_path.write_bytes(payload)
                archive = temp / f"vort-{variant}.7z"
                run(
                    args.cli,
                    "create-7z-file",
                    str(archive),
                    "payload.bin",
                    str(input_path),
                    compression,
                    filter_spec,
                )
                verification_tool = (
                    modern_seven_zip_tool
                    if variant in ("arm64-lzma2", "riscv-lzma2")
                    else seven_zip_tool
                )
                verify_with_seven_zip(
                    verification_tool,
                    archive,
                    {"payload.bin": payload},
                )
            vort_writer_variants += len(writer_variants)

            corrupt = bytearray((temp / "copy-plain.7z").read_bytes())
            corrupt[8] ^= 1
            corrupt_path = temp / "corrupt-start-header.7z"
            corrupt_path.write_bytes(corrupt)
            rejected = run(args.cli, "list-7z-file", str(corrupt_path), check=False)
            if rejected.returncode == 0:
                raise AssertionError("7z start-header CRC corruption was accepted")

            limited = run(
                args.cli,
                "extract-7z-file",
                str(temp / "lzma2-solid-encoded.7z"),
                "hello.txt",
                str(temp / "limited.out"),
                str(len(payloads["hello.txt"]) - 1),
                check=False,
            )
            if limited.returncode == 0:
                raise AssertionError("7z output limit was not enforced")

    print(
        f"seven_zip_diff=ok writer_entries={len(expected_vort) + 1} "
        f"external_variants={external_variants} "
        f"vort_writer_variants={vort_writer_variants} "
        f"source_variants={source_variants} "
        f"stream_variants={stream_variants} "
        f"system_7zip={seven_zip_tool is not None} "
        f"modern_7zip={modern_seven_zip_tool is not None} "
        f"modern_branch_filters={modern_branch_filters}"
    )


if __name__ == "__main__":
    main()
