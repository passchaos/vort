#!/usr/bin/env python3
"""Bidirectional checks for Vort's initial 7z implementation."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(program: Path, *args: str, check: bool = True, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
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


def create_reference(tool: str, tree: Path, archive: Path, options: list[str]) -> None:
    names = ["hello.txt", "second.txt", "empty.txt", "folder", "数据.txt"]
    subprocess.run(
        [tool, "a", "-bd", "-y", "-t7z", *options, str(archive), *names],
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
    seven_zip_tool = str(args.seven_zip) if args.seven_zip else shutil.which("7zz") or shutil.which("7z")

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
            subprocess.run(
                [seven_zip_tool, "t", "-bd", str(first)],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for name, payload in expected_vort.items():
                if seven_zip_extract(seven_zip_tool, first, name) != payload:
                    raise AssertionError(f"7-Zip could not extract Vort entry {name!r}")

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
            }
            for variant, options in variants.items():
                archive = temp / f"{variant}.7z"
                create_reference(seven_zip_tool, tree, archive, options)
                verify_with_vort(args.cli, archive, payloads)

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
        f"external_variants={7 if seven_zip_tool is not None else 0} "
        f"system_7zip={seven_zip_tool is not None}"
    )


if __name__ == "__main__":
    main()
