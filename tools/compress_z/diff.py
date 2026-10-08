#!/usr/bin/env python3
"""Differential checks for Vort's Unix compress (.Z) implementation."""

from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(cli: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(cli), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def external_decode(tool: str, archive: Path) -> bytes:
    return subprocess.run(
        [tool, "-c", str(archive)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def external_encode(tool: str, source: Path, max_bits: int) -> bytes:
    command = [tool, "-c", "-b", str(max_bits)]
    command.append(str(source))
    return subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--compress", type=Path)
    parser.add_argument("--uncompress", type=Path)
    args = parser.parse_args()

    rng = random.Random(0x1F9D)
    random_wide = bytes(rng.randrange(256) for _ in range(96 * 1024))
    cases: list[tuple[str, bytes, int, bool]] = [
        ("empty", b"", 16, True),
        ("tiny", b"hello Unix compress\n", 16, True),
        ("text", b"Vort dependency-free .Z differential.\n" * 2048, 16, True),
        ("binary", bytes(range(256)) * 257, 12, False),
        ("random-growth", bytes(rng.randrange(256) for _ in range(32768)), 10, False),
        ("random-clear", bytes(rng.randrange(256) for _ in range(32768)), 9, True),
        ("random-wide", random_wide, 16, True),
    ]
    uncompress_tool = str(args.uncompress) if args.uncompress else shutil.which("uncompress")
    compress_tool = str(args.compress) if args.compress else shutil.which("compress")

    with tempfile.TemporaryDirectory(prefix="vort-compress-z-diff-") as temp_text:
        temp = Path(temp_text)
        encoded_total = 0
        decoded_total = 0
        external_encoded = 0
        for name, payload, max_bits, block_mode in cases:
            source_path = temp / f"{name}.source"
            archive_path = temp / f"{name}.vort.Z"
            output_path = temp / f"{name}.out"
            source_path.write_bytes(payload)
            run(
                args.cli,
                "encode-compress-z-file",
                str(source_path),
                str(archive_path),
                str(max_bits),
                "block" if block_mode else "nonblock",
            )
            encoded = archive_path.read_bytes()
            expected_flags = max_bits | (0x80 if block_mode else 0)
            if encoded[:3] != bytes((0x1F, 0x9D, expected_flags)):
                raise AssertionError(f"Vort .Z header mismatch for {name}")
            encoded_total += len(encoded)
            decoded_total += len(payload)

            if uncompress_tool is not None and external_decode(uncompress_tool, archive_path) != payload:
                raise AssertionError(f"system uncompress could not decode Vort output for {name}")

            run(args.cli, "decode-compress-z-file", str(archive_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort .Z round-trip mismatch for {name}")
            size_output = run(
                args.cli,
                "size-compress-z-file",
                str(archive_path),
                str(len(payload)),
            ).stdout
            if f"decoded_bytes={len(payload)}" not in size_output:
                raise AssertionError(f"Vort .Z size mismatch for {name}: {size_output}")

            repeat_path = temp / f"{name}.repeat.Z"
            run(
                args.cli,
                "encode-compress-z-file",
                str(source_path),
                str(repeat_path),
                str(max_bits),
                "block" if block_mode else "nonblock",
            )
            if repeat_path.read_bytes() != encoded:
                raise AssertionError(f"Vort .Z output is not deterministic for {name}")

            if compress_tool is not None and block_mode:
                reference = external_encode(compress_tool, source_path, max_bits)
                reference_path = temp / f"{name}.reference.Z"
                reference_path.write_bytes(reference)
                run(
                    args.cli,
                    "decode-compress-z-file",
                    str(reference_path),
                    str(output_path),
                    str(len(payload)),
                )
                if output_path.read_bytes() != payload:
                    raise AssertionError(f"Vort could not decode ncompress output for {name}")
                external_encoded += 1

        limited = run(
            args.cli,
            "decode-compress-z-file",
            str(temp / "text.vort.Z"),
            str(temp / "limited.out"),
            str(len(cases[2][1]) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError(".Z output limit was not enforced")

        invalid_path = temp / "invalid.Z"
        invalid_path.write_bytes(bytes((0x1F, 0x9D, 0xB0)))
        invalid = run(
            args.cli,
            "decode-compress-z-file",
            str(invalid_path),
            str(temp / "invalid.out"),
            check=False,
        )
        if invalid.returncode == 0:
            raise AssertionError("reserved .Z header flags were accepted")

    print(
        f"compress_z_diff=ok cases={len(cases)} encoded_bytes={encoded_total} "
        f"decoded_bytes={decoded_total} system_uncompress={uncompress_tool is not None} "
        f"ncompress_cases={external_encoded}"
    )


if __name__ == "__main__":
    main()
