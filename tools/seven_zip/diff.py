#!/usr/bin/env python3
"""Bidirectional checks for Vort's common 7z implementation."""

from __future__ import annotations

import argparse
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


def seven_zip_extract(tool: str, archive: Path, name: str) -> bytes:
    return subprocess.run(
        [tool, "x", "-so", "-bd", str(archive), name],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def verify_with_seven_zip(tool: str, archive: Path, payloads: dict[str, bytes]) -> None:
    subprocess.run(
        [tool, "t", "-bd", str(archive)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    for name, payload in payloads.items():
        if seven_zip_extract(tool, archive, name) != payload:
            raise AssertionError(f"7-Zip could not extract Vort entry {name!r}")


def create_reference(tool: str, tree: Path, archive: Path, options: list[str]) -> None:
    names = ["hello.txt", "second.txt", "empty.txt", "folder", "数据.txt"]
    subprocess.run(
        [tool, "a", "-bd", "-y", "-t7z", *options, str(archive), *names],
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


def verify_with_vort(cli: Path, archive: Path, payloads: dict[str, bytes]) -> None:
    listing = run(cli, "list-7z-file", str(archive)).stdout
    for name in payloads:
        if f"name={name}" not in listing:
            raise AssertionError(f"7z listing omitted {name!r}: {listing}")
    for index, (name, payload) in enumerate(payloads.items()):
        output = archive.with_name(f"{archive.stem}-{index}.out")
        run(cli, "extract-7z-file", str(archive), name, str(output), str(len(payload)))
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort 7z extraction mismatch for {name!r}")


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
    external_variants = 0
    vort_writer_variants = 1

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

        if seven_zip_tool is not None:
            verify_with_seven_zip(seven_zip_tool, first, expected_vort)
            for compression in ("deflate", "bzip2", "lzma", "lzma2"):
                archive = temp / f"vort-{compression}-multi.7z"
                run(args.writer, str(archive), compression)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 3

            for compression in ("copy", "deflate", "bzip2", "lzma", "lzma2"):
                archive = temp / f"vort-{compression}-solid.7z"
                duplicate = temp / f"vort-{compression}-solid-repeat.7z"
                run(args.writer, str(archive), compression, "solid")
                run(args.writer, str(duplicate), compression, "solid")
                if archive.read_bytes() != duplicate.read_bytes():
                    raise AssertionError(f"Vort solid {compression} output is not deterministic")
                verify_with_vort(args.cli, archive, expected_vort)
                verify_with_seven_zip(seven_zip_tool, archive, expected_vort)
            vort_writer_variants += 5

            for header_compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
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
            vort_writer_variants += 6

            for compression in (
                "copy",
                "deflate",
                "bzip2",
                "lzma",
                "lzma2",
                "lzma2-stored",
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
            vort_writer_variants += 6

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

            variants = {
                "copy-plain": ["-mx=0", "-mhc=off", "-ms=off"],
                "deflate-plain": ["-m0=deflate", "-mx=5", "-mhc=off", "-ms=off"],
                "bzip2-plain": ["-m0=bzip2", "-mx=5", "-mhc=off", "-ms=off"],
                "lzma-plain": ["-m0=lzma", "-mx=5", "-mhc=off", "-ms=off"],
                "lzma2-plain": ["-m0=lzma2", "-mx=5", "-mhc=off", "-ms=off"],
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
            external_variants += len(variants)

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
                "bcj-lzma": (("bcj", "lzma"), x86_payload),
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
            for variant, (methods, payload) in filter_variants.items():
                archive = temp / f"{variant}.7z"
                options = [f"-m{index}={method}" for index, method in enumerate(methods)]
                options.extend(("-mx=5", "-mhc=off", "-ms=off"))
                create_reference_payload(seven_zip_tool, filter_tree, archive, payload, options)
                verify_with_vort(args.cli, archive, {"payload.bin": payload})
            external_variants += len(filter_variants)

            writer_variants = {
                "lzma2-multichunk": (
                    "lzma2",
                    "none",
                    b"multi-chunk literal LZMA2 payload\n" * 4096,
                ),
                "bcj-deflate": ("deflate", "x86", x86_payload),
                "bcj-lzma": ("lzma", "x86", x86_payload),
                "delta4-bzip2": ("bzip2", "delta:4", bytes(range(256)) * 16),
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
                verify_with_seven_zip(
                    seven_zip_tool,
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
        f"system_7zip={seven_zip_tool is not None}"
    )


if __name__ == "__main__":
    main()
