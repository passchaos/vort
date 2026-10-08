#!/usr/bin/env python3
"""Differential tests for Vort's XZ/LZMA2 decoder."""

from __future__ import annotations

import argparse
import lzma
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()

    rng = random.Random(0x585A)
    cases: list[tuple[str, bytes, int, int]] = [
        ("empty", b"", lzma.CHECK_NONE, 0),
        ("text", b"Vort XZ differential.\n" * 2048, lzma.CHECK_CRC32, 6),
        ("runs", b"A" * 65536 + b"B" * 4096, lzma.CHECK_CRC64, 1),
        ("binary", bytes(range(256)) * 257, lzma.CHECK_CRC64, 9),
        ("random", bytes(rng.randrange(256) for _ in range(32768)), lzma.CHECK_SHA256, 3),
    ]
    check_names = {
        lzma.CHECK_NONE: "none",
        lzma.CHECK_CRC32: "crc32",
        lzma.CHECK_CRC64: "crc64",
        lzma.CHECK_SHA256: "sha256",
    }
    xz_tool = shutil.which("xz")

    with tempfile.TemporaryDirectory(prefix="vort-xz-diff-") as temp_text:
        temp = Path(temp_text)
        compressed_total = 0
        decoded_total = 0
        for name, payload, check, preset in cases:
            if not lzma.is_check_supported(check):
                continue
            compressed = lzma.compress(payload, format=lzma.FORMAT_XZ, check=check, preset=preset)
            compressed_total += len(compressed)
            decoded_total += len(payload)
            input_path = temp / f"{name}.xz"
            output_path = temp / f"{name}.out"
            input_path.write_bytes(compressed)

            run(args.cli, "decode-xz-file", str(input_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort XZ decode mismatch for {name}")
            size_output = run(args.cli, "size-xz-file", str(input_path), str(len(payload))).stdout
            if f"decoded_bytes={len(payload)}" not in size_output:
                raise AssertionError(f"Vort XZ size mismatch for {name}: {size_output}")
            inspect_output = run(args.cli, "inspect-xz-file", str(input_path)).stdout
            expected_blocks = 0 if len(payload) == 0 else 1
            if f"xz_check={check_names[check]}" not in inspect_output or f"blocks={expected_blocks}" not in inspect_output:
                raise AssertionError(f"Vort XZ inspection mismatch for {name}: {inspect_output}")

            source_path = temp / f"{name}.source"
            vort_path = temp / f"{name}.vort.xz"
            source_path.write_bytes(payload)
            block_size = 32768
            run(
                args.cli,
                "encode-xz-stored-file",
                str(source_path),
                str(vort_path),
                check_names[check],
                str(block_size),
            )
            vort_encoded = vort_path.read_bytes()
            if lzma.decompress(vort_encoded, format=lzma.FORMAT_XZ) != payload:
                raise AssertionError(f"Python could not decode Vort XZ output for {name}")
            if xz_tool is not None:
                subprocess.run([xz_tool, "--test", str(vort_path)], check=True)
            vort_inspect = run(args.cli, "inspect-xz-file", str(vort_path)).stdout
            expected_vort_blocks = 0 if len(payload) == 0 else (len(payload) + block_size - 1) // block_size
            if (
                f"xz_check={check_names[check]}" not in vort_inspect
                or f"blocks={expected_vort_blocks}" not in vort_inspect
            ):
                raise AssertionError(f"Vort encoded XZ metadata mismatch for {name}: {vort_inspect}")
            if name == "text":
                repeat_path = temp / "text-repeat.vort.xz"
                run(
                    args.cli,
                    "encode-xz-stored-file",
                    str(source_path),
                    str(repeat_path),
                    check_names[check],
                    str(block_size),
                )
                if repeat_path.read_bytes() != vort_encoded:
                    raise AssertionError("Vort XZ output is not deterministic")

        first = lzma.compress(b"first XZ member\n" * 97, check=lzma.CHECK_CRC32)
        second_payload = bytes(range(251)) * 313
        second = lzma.compress(second_payload, check=lzma.CHECK_CRC64)
        expected_concatenated = b"first XZ member\n" * 97 + second_payload
        concatenated = first + b"\x00" * 4 + second
        concat_path = temp / "concatenated.xz"
        concat_output = temp / "concatenated.out"
        concat_path.write_bytes(concatenated)
        strict = run(args.cli, "decode-xz-file", str(concat_path), str(concat_output), check=False)
        if strict.returncode == 0:
            raise AssertionError("single-stream XZ API accepted concatenated input")
        run(
            args.cli,
            "decode-xz-concat-file",
            str(concat_path),
            str(concat_output),
            str(len(expected_concatenated)),
        )
        if concat_output.read_bytes() != expected_concatenated:
            raise AssertionError("Vort concatenated XZ decode mismatch")

        limited = run(
            args.cli,
            "decode-xz-file",
            str(temp / "text.xz"),
            str(temp / "limited.out"),
            str(len(cases[1][1]) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError("XZ output limit was not enforced")

        corrupt = bytearray((temp / "binary.xz").read_bytes())
        corrupt[-13] ^= 1
        corrupt_path = temp / "corrupt.xz"
        corrupt_path.write_bytes(corrupt)
        corrupted = run(args.cli, "decode-xz-file", str(corrupt_path), str(temp / "corrupt.out"), check=False)
        if corrupted.returncode == 0:
            raise AssertionError("corrupt XZ stream was accepted")

        filtered = lzma.compress(
            b"BCJ filter rejection\n" * 64,
            format=lzma.FORMAT_XZ,
            check=lzma.CHECK_CRC64,
            filters=[
                {"id": lzma.FILTER_X86},
                {"id": lzma.FILTER_LZMA2, "preset": 1},
            ],
        )
        filtered_path = temp / "bcj-filter.xz"
        filtered_path.write_bytes(filtered)
        unsupported = run(
            args.cli,
            "decode-xz-file",
            str(filtered_path),
            str(temp / "bcj-filter.out"),
            check=False,
        )
        if unsupported.returncode == 0:
            raise AssertionError("unsupported XZ BCJ filter chain was accepted")

        multiblock_count = 0
        if xz_tool is not None:
            multiblock_payload = bytes(range(251)) * 1000
            generated = subprocess.run(
                [xz_tool, "--threads=1", "--check=crc64", "--block-size=65536", "--stdout"],
                input=multiblock_payload,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
            multiblock_path = temp / "multiblock.xz"
            multiblock_output = temp / "multiblock.out"
            multiblock_path.write_bytes(generated)
            run(args.cli, "decode-xz-file", str(multiblock_path), str(multiblock_output))
            if multiblock_output.read_bytes() != multiblock_payload:
                raise AssertionError("Vort multi-block XZ decode mismatch")
            inspect_output = run(args.cli, "inspect-xz-file", str(multiblock_path)).stdout
            block_field = next(field for field in inspect_output.split() if field.startswith("blocks="))
            multiblock_count = int(block_field.split("=", 1)[1])
            if multiblock_count < 2:
                raise AssertionError(f"system xz did not emit multiple blocks: {inspect_output}")

    print(
        f"xz_diff=ok directions=2 cases={len(cases)} compressed_bytes={compressed_total} "
        f"decoded_bytes={decoded_total} concatenated_bytes={len(expected_concatenated)} "
        f"multiblock_count={multiblock_count}"
    )


if __name__ == "__main__":
    main()
