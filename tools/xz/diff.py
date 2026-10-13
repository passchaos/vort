#!/usr/bin/env python3
"""Differential tests for Vort's XZ/LZMA2 implementation."""

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
    parser.add_argument("--modern-seven-zip", type=Path)
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
    modern_seven_zip_tool = (
        str(args.modern_seven_zip) if args.modern_seven_zip else None
    )

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
            source_path.write_bytes(payload)
            block_size = 131072 if name == "runs" else 32768
            writer_sizes: dict[str, int] = {}
            for writer_mode, command in (
                ("stored", "encode-xz-stored-file"),
                ("compressed", "encode-xz-file"),
            ):
                vort_path = temp / f"{name}.{writer_mode}.vort.xz"
                run(
                    args.cli,
                    command,
                    str(source_path),
                    str(vort_path),
                    check_names[check],
                    str(block_size),
                )
                vort_encoded = vort_path.read_bytes()
                writer_sizes[writer_mode] = len(vort_encoded)
                if lzma.decompress(vort_encoded, format=lzma.FORMAT_XZ) != payload:
                    raise AssertionError(
                        f"Python could not decode Vort {writer_mode} XZ output for {name}"
                    )
                if xz_tool is not None:
                    subprocess.run([xz_tool, "--test", str(vort_path)], check=True)
                vort_inspect = run(args.cli, "inspect-xz-file", str(vort_path)).stdout
                expected_vort_blocks = (
                    0 if len(payload) == 0 else (len(payload) + block_size - 1) // block_size
                )
                if (
                    f"xz_check={check_names[check]}" not in vort_inspect
                    or f"blocks={expected_vort_blocks}" not in vort_inspect
                ):
                    raise AssertionError(
                        f"Vort {writer_mode} XZ metadata mismatch for {name}: {vort_inspect}"
                    )
                if name == "text":
                    repeat_path = temp / f"text-repeat.{writer_mode}.vort.xz"
                    run(
                        args.cli,
                        command,
                        str(source_path),
                        str(repeat_path),
                        check_names[check],
                        str(block_size),
                    )
                    if repeat_path.read_bytes() != vort_encoded:
                        raise AssertionError(f"Vort {writer_mode} XZ output is not deterministic")
            if name in ("text", "runs") and writer_sizes["compressed"] >= writer_sizes["stored"]:
                raise AssertionError(f"Vort compressed XZ did not reduce {name}")

        dictionary_payload = bytearray(2 * 65536 + 8192)
        dictionary_state = 0x13198A2E
        for index in range(2 * 65536):
            dictionary_state ^= (dictionary_state << 13) & 0xFFFFFFFF
            dictionary_state ^= dictionary_state >> 17
            dictionary_state ^= (dictionary_state << 5) & 0xFFFFFFFF
            dictionary_state &= 0xFFFFFFFF
            dictionary_payload[index] = dictionary_state & 0xFF
        dictionary_payload[2 * 65536 :] = dictionary_payload[0:8192]
        dictionary_source = temp / "dictionary.source"
        dictionary_source.write_bytes(dictionary_payload)
        dictionary_default = temp / "dictionary-default.xz"
        dictionary_large = temp / "dictionary-128k.xz"
        run(
            args.cli,
            "encode-xz-file",
            str(dictionary_source),
            str(dictionary_default),
            "crc64",
            "1048576",
        )
        run(
            args.cli,
            "encode-xz-file",
            str(dictionary_source),
            str(dictionary_large),
            "crc64",
            "1048576",
            "none",
            "131072",
        )
        default_bytes = dictionary_default.read_bytes()
        large_bytes = dictionary_large.read_bytes()
        dictionary_saved = len(default_bytes) - len(large_bytes)
        if dictionary_saved < 7000:
            raise AssertionError(
                f"larger XZ dictionary saved only {dictionary_saved} bytes"
            )
        if lzma.decompress(large_bytes, format=lzma.FORMAT_XZ) != dictionary_payload:
            raise AssertionError("Python could not decode Vort 128 KiB dictionary output")
        if "max_dictionary=131072" not in run(
            args.cli, "inspect-xz-file", str(dictionary_large)
        ).stdout:
            raise AssertionError("Vort XZ dictionary property was not preserved")
        if xz_tool is not None:
            subprocess.run([xz_tool, "--test", str(dictionary_large)], check=True)

        very_wide_gap = 17 * 65536
        very_wide_payload = bytearray(very_wide_gap + 8192)
        very_wide_state = 0x243F6A88
        for index in range(very_wide_gap):
            very_wide_state ^= (very_wide_state << 13) & 0xFFFFFFFF
            very_wide_state ^= very_wide_state >> 17
            very_wide_state ^= (very_wide_state << 5) & 0xFFFFFFFF
            very_wide_state &= 0xFFFFFFFF
            very_wide_payload[index] = very_wide_state & 0xFF
        very_wide_payload[very_wide_gap:] = very_wide_payload[:8192]
        very_wide_source = temp / "dictionary-2m.source"
        very_wide_source.write_bytes(very_wide_payload)
        dictionary_1m = temp / "dictionary-1m.xz"
        dictionary_2m = temp / "dictionary-2m.xz"
        run(
            args.cli,
            "encode-xz-file",
            str(very_wide_source),
            str(dictionary_1m),
            "crc64",
            "2097152",
            "none",
            "1048576",
        )
        run(
            args.cli,
            "encode-xz-file",
            str(very_wide_source),
            str(dictionary_2m),
            "crc64",
            "2097152",
            "none",
            "2097152",
        )
        dictionary_1m_bytes = dictionary_1m.read_bytes()
        dictionary_2m_bytes = dictionary_2m.read_bytes()
        dictionary_2m_saved = len(dictionary_1m_bytes) - len(dictionary_2m_bytes)
        if dictionary_2m_saved < 7000:
            raise AssertionError(
                f"2 MiB XZ dictionary saved only {dictionary_2m_saved} bytes"
            )
        if lzma.decompress(dictionary_2m_bytes, format=lzma.FORMAT_XZ) != very_wide_payload:
            raise AssertionError("Python could not decode Vort 2 MiB dictionary output")
        if "max_dictionary=2097152" not in run(
            args.cli, "inspect-xz-file", str(dictionary_2m)
        ).stdout:
            raise AssertionError("Vort 2 MiB XZ dictionary property was not preserved")
        if xz_tool is not None:
            subprocess.run([xz_tool, "--test", str(dictionary_2m)], check=True)

        lazy_source = temp / "text.source"
        lazy_archive = temp / "text.lazy.vort.xz"
        run(
            args.cli,
            "encode-xz-file",
            str(lazy_source),
            str(lazy_archive),
            "crc32",
            "1048576",
            "none",
            "32768",
            "lazy",
        )
        lazy_bytes = lazy_archive.read_bytes()
        if lzma.decompress(lazy_bytes, format=lzma.FORMAT_XZ) != lazy_source.read_bytes():
            raise AssertionError("Python could not decode Vort lazy XZ output")
        if xz_tool is not None:
            subprocess.run([xz_tool, "--test", str(lazy_archive)], check=True)

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

        x86_payload = (b"\x90\xe8\x10\x00\x00\x00\x90\xe9\xf0\xff\xff\xff" * 4096) + b"tail"
        filter_cases = [
            (
                "delta",
                bytes(range(251)) * 401,
                [
                    {"id": lzma.FILTER_DELTA, "dist": 7},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["delta_blocks=1"],
                "delta:7",
            ),
            (
                "x86",
                x86_payload,
                [
                    {"id": lzma.FILTER_X86, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "x86_blocks=1"],
                "x86:4096",
            ),
            (
                "x86-delta",
                x86_payload,
                [
                    {"id": lzma.FILTER_X86},
                    {"id": lzma.FILTER_DELTA, "dist": 4},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["delta_blocks=1", "bcj_blocks=1", "x86_blocks=1"],
                "x86,delta:4",
            ),
            (
                "powerpc",
                b"\x48\x00\x00\x01\x4b\xff\xff\xfd" * 4096,
                [
                    {"id": lzma.FILTER_POWERPC, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "powerpc_blocks=1"],
                "powerpc:4096",
            ),
            (
                "ia64",
                b"\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" * 2048,
                [
                    {"id": lzma.FILTER_IA64, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "ia64_blocks=1"],
                "ia64:4096",
            ),
            (
                "arm",
                b"\x04\x00\x00\xeb\xfc\xff\xff\xeb" * 4096,
                [
                    {"id": lzma.FILTER_ARM, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "arm_blocks=1"],
                "arm:4096",
            ),
            (
                "arm-thumb",
                b"\x00\xf0\x00\xf8\xff\xf7\xff\xff" * 4096,
                [
                    {"id": lzma.FILTER_ARMTHUMB, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "arm_thumb_blocks=1"],
                "armthumb:4096",
            ),
            (
                "sparc",
                b"\x40\x00\x00\x00\x7f\xff\xff\xff" * 4096,
                [
                    {"id": lzma.FILTER_SPARC, "start_offset": 4096},
                    {"id": lzma.FILTER_LZMA2, "preset": 1},
                ],
                ["bcj_blocks=1", "sparc_blocks=1"],
                "sparc:4096",
            ),
        ]
        for name, payload, filter_chain, expected_counters, writer_filter in filter_cases:
            filtered = lzma.compress(
                payload,
                format=lzma.FORMAT_XZ,
                check=lzma.CHECK_CRC64,
                filters=filter_chain,
            )
            filtered_path = temp / f"{name}-filter.xz"
            filtered_output = temp / f"{name}-filter.out"
            filtered_path.write_bytes(filtered)
            run(args.cli, "decode-xz-file", str(filtered_path), str(filtered_output))
            if filtered_output.read_bytes() != payload:
                raise AssertionError(f"Vort {name} filter decode mismatch")
            inspect_output = run(args.cli, "inspect-xz-file", str(filtered_path)).stdout
            for expected_counter in expected_counters:
                if expected_counter not in inspect_output:
                    raise AssertionError(f"Vort {name} filter metadata mismatch: {inspect_output}")

            source_path = temp / f"{name}-filter.source"
            source_path.write_bytes(payload)
            for writer_mode, command in (
                ("stored", "encode-xz-stored-file"),
                ("compressed", "encode-xz-file"),
            ):
                vort_filtered_path = temp / f"{name}-filter.{writer_mode}.vort.xz"
                run(
                    args.cli,
                    command,
                    str(source_path),
                    str(vort_filtered_path),
                    "crc64",
                    "1048576",
                    writer_filter,
                )
                if lzma.decompress(vort_filtered_path.read_bytes()) != payload:
                    raise AssertionError(
                        f"Python could not decode Vort {name} {writer_mode} filter output"
                    )

        modern_filter_cases = {
            "arm64": (
                b"\x00\x00\x00\x94\x00\x00\x00\x90" * 4096,
                "arm64:4096",
                "arm64_blocks=1",
            ),
            "riscv": (
                b"\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00"
                * 2048,
                "riscv:4096",
                "riscv_blocks=1",
            ),
        }
        for name, (payload, writer_filter, expected_counter) in modern_filter_cases.items():
            source_path = temp / f"{name}-modern.source"
            source_path.write_bytes(payload)
            for writer_mode, command in (
                ("stored", "encode-xz-stored-file"),
                ("compressed", "encode-xz-file"),
            ):
                archive = temp / f"{name}-modern.{writer_mode}.xz"
                output = temp / f"{name}-modern.{writer_mode}.out"
                run(
                    args.cli,
                    command,
                    str(source_path),
                    str(archive),
                    "crc64",
                    "1048576",
                    writer_filter,
                )
                run(args.cli, "decode-xz-file", str(archive), str(output))
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort {name} XZ self-decode mismatch")
                inspect_output = run(args.cli, "inspect-xz-file", str(archive)).stdout
                if expected_counter not in inspect_output:
                    raise AssertionError(
                        f"Vort {name} XZ metadata mismatch: {inspect_output}"
                    )
                if modern_seven_zip_tool is not None:
                    subprocess.run(
                        [modern_seven_zip_tool, "t", "-bd", str(archive)],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                    extracted = subprocess.run(
                        [modern_seven_zip_tool, "x", "-so", "-bd", str(archive)],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    ).stdout
                    if extracted != payload:
                        raise AssertionError(
                            f"7-Zip could not decode Vort {name} XZ output"
                        )

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
        f"filter_cases={len(filter_cases)} writer_modes=2 multiblock_count={multiblock_count}"
        f" dictionary_cases=2 dictionary_default={len(default_bytes)}"
        f" dictionary_large={len(large_bytes)} dictionary_saved={dictionary_saved}"
        f" dictionary_1m={len(dictionary_1m_bytes)}"
        f" dictionary_2m={len(dictionary_2m_bytes)} dictionary_2m_saved={dictionary_2m_saved}"
        f" parser_cases=1 lazy_bytes={len(lazy_bytes)}"
        f" modern_filter_cases={len(modern_filter_cases)}"
        f" modern_7zip={modern_seven_zip_tool is not None}"
    )


if __name__ == "__main__":
    main()
