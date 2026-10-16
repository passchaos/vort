#!/usr/bin/env python3
"""CPIO header-format and compression-wrapper interoperability harness."""

from __future__ import annotations

import argparse
import os
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(
    program: Path | str,
    *args: str,
    check: bool = True,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def make_payload() -> bytes:
    rng = random.Random(0xC910_0707)
    prefix = bytes(rng.randrange(256) for _ in range(4096))
    return prefix + b"CPIO interoperability payload\n" * 256 + prefix


def reference_create(
    cpio: Path,
    work: Path,
    output: Path,
    format_name: str,
    names: tuple[str, ...],
) -> None:
    with output.open("wb") as archive_file:
        subprocess.run(
            [str(cpio), "-o", "-H", format_name, "--quiet"],
            check=True,
            cwd=work,
            input=("\n".join(names) + "\n").encode(),
            stdout=archive_file,
            stderr=subprocess.PIPE,
        )


def reference_extract(cpio: Path, archive: Path, output_dir: Path) -> bytes:
    output_dir.mkdir()
    run(cpio, "-id", "--quiet", "-F", str(archive), cwd=output_dir)
    return (output_dir / "payload.bin").read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", type=Path)
    parser.add_argument("--incremental-reader", type=Path)
    parser.add_argument("--cpio", type=Path)
    args = parser.parse_args()
    cpio_tool = args.cpio or (Path(found) if (found := shutil.which("cpio")) else None)
    payload = make_payload()
    formats = {
        "newc": "newc",
        "crc": "crc",
        "odc": "odc",
        "bin": "binary_little",
        "bin-be": "binary_big",
    }
    reference_formats = ("newc", "crc", "odc", "bin")
    compressions = (
        "none",
        "gzip",
        "bzip2",
        "brotli",
        "compress-z",
        "lzma",
        "xz",
        "lz4",
        "lzip",
        "lzf",
        "zstd",
        "lzop",
    )
    writer_external = 0
    reference_writer = 0
    wrapper_cases = 0
    incremental_writer_cases = 0
    incremental_reader_cases = 0

    with tempfile.TemporaryDirectory(prefix="vort-cpio-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)

        for format_name, expected_tag in formats.items():
            first = temp / f"vort-{format_name}-first.cpio"
            second = temp / f"vort-{format_name}-second.cpio"
            output = temp / f"vort-{format_name}.out"
            run(args.cli, "create-cpio-file", str(first), "payload.bin", str(source), format_name)
            run(args.cli, "create-cpio-file", str(second), "payload.bin", str(source), format_name)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort CPIO {format_name} output is not deterministic")
            listing = run(args.cli, "list-cpio-file", str(first)).stdout
            if f"format={expected_tag}" not in listing or "name=payload.bin" not in listing:
                raise AssertionError(f"Vort CPIO listing mismatch for {format_name}: {listing}")
            run(args.cli, "extract-cpio-file", str(first), "payload.bin", str(output), str(len(payload)))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort CPIO {format_name} self-extraction mismatch")
            if args.incremental_reader is not None:
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_reader,
                        str(first),
                        "payload.bin",
                        str(source),
                        pattern,
                    )
                    incremental_reader_cases += 1
            if cpio_tool is not None:
                listed = run(cpio_tool, "-it", "--quiet", "-F", str(first)).stdout.splitlines()
                if listed != ["payload.bin"]:
                    raise AssertionError(f"GNU cpio rejected Vort {format_name}: {listed}")
                if reference_extract(
                    cpio_tool,
                    first,
                    temp / f"gnu-vort-{format_name}",
                ) != payload:
                    raise AssertionError(f"GNU cpio extraction mismatch for Vort {format_name}")
                writer_external += 1

        for compression in compressions:
            archive = temp / f"wrapper-{compression}.cpio"
            output = temp / f"wrapper-{compression}.out"
            run(
                args.cli,
                "create-cpio-file",
                str(archive),
                "payload.bin",
                str(source),
                "newc",
                compression,
            )
            listing = run(args.cli, "list-cpio-file", str(archive)).stdout
            expected = "zstandard" if compression == "zstd" else (
                "compress_z" if compression == "compress-z" else compression
            )
            if f"compression={expected}" not in listing:
                raise AssertionError(f"Vort mislabeled CPIO wrapper {compression}: {listing}")
            run(args.cli, "extract-cpio-file", str(archive), "payload.bin", str(output), str(len(payload)))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort CPIO wrapper mismatch for {compression}")
            wrapper_cases += 1

        if args.writer is not None:
            expected_names = ["plain.txt", "folder", "folder/data.bin", "link"]
            for format_name in formats:
                archive = temp / f"probe-{format_name}.cpio"
                run(args.writer, str(archive), format_name)
                incremental_one = temp / f"probe-{format_name}-incremental-one.cpio"
                incremental_micro = temp / f"probe-{format_name}-incremental-micro.cpio"
                run(args.writer, str(incremental_one), format_name, "incremental-one")
                run(args.writer, str(incremental_micro), format_name, "incremental-micro")
                expected_wire = archive.read_bytes()
                if incremental_one.read_bytes() != expected_wire:
                    raise AssertionError(
                        f"one-byte incremental CPIO wire mismatch for {format_name}"
                    )
                if incremental_micro.read_bytes() != expected_wire:
                    raise AssertionError(
                        f"micro incremental CPIO wire mismatch for {format_name}"
                    )
                incremental_writer_cases += 2
                listing = run(args.cli, "list-cpio-file", str(archive)).stdout
                if "kind=directory" not in listing or "kind=symlink" not in listing:
                    raise AssertionError(f"Vort writer probe metadata mismatch for {format_name}: {listing}")
                if cpio_tool is not None:
                    listed = run(cpio_tool, "-it", "--quiet", "-F", str(archive)).stdout.splitlines()
                    if listed != expected_names:
                        raise AssertionError(f"GNU cpio rejected Vort metadata archive {format_name}: {listed}")

        if cpio_tool is not None:
            reference = temp / "reference"
            reference.mkdir()
            (reference / "payload.bin").write_bytes(payload)
            (reference / "folder").mkdir()
            os.symlink("payload.bin", reference / "link")
            (reference / "hard-a").write_bytes(payload)
            os.link(reference / "hard-a", reference / "hard-b")
            names = ("payload.bin", "folder", "link", "hard-a", "hard-b")
            for format_name in reference_formats:
                archive = temp / f"reference-{format_name}.cpio"
                reference_create(cpio_tool, reference, archive, format_name, names)
                listing = run(args.cli, "list-cpio-file", str(archive)).stdout
                if "name=payload.bin" not in listing or "kind=directory" not in listing or "kind=symlink" not in listing:
                    raise AssertionError(f"Vort misparsed GNU {format_name}: {listing}")
                output = temp / f"reference-{format_name}.out"
                run(args.cli, "extract-cpio-file", str(archive), "payload.bin", str(output), str(len(payload)))
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed GNU cpio {format_name}")
                link_output = temp / f"reference-{format_name}.link"
                run(args.cli, "extract-cpio-file", str(archive), "link", str(link_output), "1024")
                if link_output.read_bytes() != b"payload.bin":
                    raise AssertionError(f"Vort failed GNU cpio {format_name} symlink target")
                hard_output = temp / f"reference-{format_name}.hard"
                run(args.cli, "extract-cpio-file", str(archive), "hard-a", str(hard_output), str(len(payload)))
                if hard_output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed GNU cpio {format_name} hard-link resolution")
                if args.incremental_reader is not None:
                    for pattern in ("one", "micro"):
                        run(
                            args.incremental_reader,
                            str(archive),
                            "payload.bin",
                            str(reference / "payload.bin"),
                            pattern,
                        )
                        incremental_reader_cases += 1
                reference_writer += 1

        crc_archive = temp / "vort-crc-first.cpio"
        corrupt = bytearray(crc_archive.read_bytes())
        payload_offset = corrupt.find(payload)
        if payload_offset < 0:
            raise AssertionError("could not locate CRC payload")
        corrupt[payload_offset] ^= 1
        corrupt_path = temp / "corrupt-crc.cpio"
        corrupt_path.write_bytes(corrupt)
        failed = run(
            args.cli,
            "extract-cpio-file",
            str(corrupt_path),
            "payload.bin",
            str(temp / "corrupt.out"),
            check=False,
        )
        if failed.returncode == 0:
            raise AssertionError("Vort accepted a CPIO CRC archive with corrupt data")

        truncated = temp / "truncated.cpio"
        truncated.write_bytes((temp / "vort-newc-first.cpio").read_bytes()[:100])
        if run(args.cli, "list-cpio-file", str(truncated), check=False).returncode == 0:
            raise AssertionError("Vort accepted a truncated CPIO header")

        trailing = bytearray((temp / "vort-newc-first.cpio").read_bytes())
        trailing[-1] = 1
        trailing_path = temp / "trailing.cpio"
        trailing_path.write_bytes(trailing)
        if run(args.cli, "list-cpio-file", str(trailing_path), check=False).returncode == 0:
            raise AssertionError("Vort accepted nonzero bytes after the CPIO trailer")

    print(
        f"formats={len(formats)} self_writer_cases={len(formats)} "
        f"cpio={cpio_tool is not None} writer_external={writer_external} "
        f"reference_writer={reference_writer} wrapper_cases={wrapper_cases} "
        f"incremental_writer_cases={incremental_writer_cases} "
        f"incremental_reader_cases={incremental_reader_cases} "
        "corrupt_crc=True truncated=True trailing=True"
    )


if __name__ == "__main__":
    main()
