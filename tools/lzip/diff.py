#!/usr/bin/env python3
"""Bidirectional differential checks for Vort's lzip implementation."""

from __future__ import annotations

import argparse
import lzma
import random
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


def run(cli: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(cli), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def code_dictionary_size(size: int) -> int:
    if not 4096 <= size <= 512 * 1024 * 1024:
        raise ValueError("dictionary size outside lzip range")
    bits = (size - 1).bit_length()
    if bits == 12:
        return bits
    base = 1 << bits
    fraction = base // 16
    for numerator in range(7, 0, -1):
        if base - numerator * fraction >= size:
            return bits | (numerator << 5)
    return bits


def decode_dictionary_size(code: int) -> int:
    bits = code & 0x1F
    if not 12 <= bits <= 29:
        raise AssertionError(f"invalid lzip dictionary code: {code:#x}")
    base = 1 << bits
    return base if base == 4096 else base - (base // 16) * (code >> 5)


def make_member(payload: bytes, dictionary_size: int) -> bytes:
    header = b"LZIP\x01" + bytes((code_dictionary_size(dictionary_size),))
    compressed = lzma.compress(
        payload,
        format=lzma.FORMAT_RAW,
        filters=[
            {
                "id": lzma.FILTER_LZMA1,
                "dict_size": dictionary_size,
                "lc": 3,
                "lp": 0,
                "pb": 2,
            }
        ],
    )
    member_size = len(header) + len(compressed) + 20
    trailer = struct.pack("<IQQ", zlib.crc32(payload), len(payload), member_size)
    return header + compressed + trailer


def lzip_decode(tool: str, archive: Path) -> bytes:
    return subprocess.run(
        [tool, "-cd", str(archive)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def lzip_encode(tool: str, source: Path, dictionary_size: int) -> bytes:
    return subprocess.run(
        [tool, "-0", "-c", "-s", str(dictionary_size), str(source)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--incremental", required=True, type=Path)
    parser.add_argument("--lzip", type=Path)
    args = parser.parse_args()

    rng = random.Random(0x4C5A4950)
    cases: list[tuple[str, bytes, int]] = [
        ("empty", b"", 4096),
        ("tiny", b"hello lzip\n", 4096),
        ("text", b"Vort lzip differential.\n" * 2048, 64 * 1024),
        ("runs", b"A" * 65536 + b"B" * 8192, 1024 * 1024),
        ("binary", bytes(range(256)) * 257, 320 * 1024),
        ("random", bytes(rng.randrange(256) for _ in range(32768)), 1024 * 1024),
    ]
    lzip_tool = str(args.lzip) if args.lzip else shutil.which("lzip")

    with tempfile.TemporaryDirectory(prefix="vort-lzip-diff-") as temp_text:
        temp = Path(temp_text)
        compressed_total = 0
        decoded_total = 0
        external_cases = 0
        writer_cases = 0
        generated: dict[str, bytes] = {}
        vort_generated: dict[str, bytes] = {}
        incremental_cases = 0
        for name, payload, dictionary_size in cases:
            member = make_member(payload, dictionary_size)
            generated[name] = member
            compressed_total += len(member)
            decoded_total += len(payload)
            archive_path = temp / f"{name}.lz"
            output_path = temp / f"{name}.out"
            source_path = temp / f"{name}.source"
            archive_path.write_bytes(member)
            source_path.write_bytes(payload)

            if lzip_tool is not None and lzip_decode(lzip_tool, archive_path) != payload:
                raise AssertionError(f"lzip could not decode generated member {name}")
            run(args.cli, "decode-lzip-file", str(archive_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort lzip decode mismatch for {name}")
            for pattern in ("one", "micro"):
                run(args.incremental, str(archive_path), str(source_path), pattern)
            incremental_cases += 1
            size_output = run(args.cli, "size-lzip-file", str(archive_path), str(len(payload))).stdout
            if f"decoded_bytes={len(payload)}" not in size_output:
                raise AssertionError(f"Vort lzip size mismatch for {name}: {size_output}")
            inspect_output = run(args.cli, "inspect-lzip-file", str(archive_path)).stdout
            if "lzip_members=1" not in inspect_output or f"decoded_bytes={len(payload)}" not in inspect_output:
                raise AssertionError(f"Vort lzip inspection mismatch for {name}: {inspect_output}")

            vort_path = temp / f"{name}.vort.lz"
            run(
                args.cli,
                "encode-lzip-file",
                str(source_path),
                str(vort_path),
                str(dictionary_size),
            )
            vort_member = vort_path.read_bytes()
            vort_generated[name] = vort_member
            if vort_member[:5] != b"LZIP\x01":
                raise AssertionError(f"Vort emitted an invalid lzip header for {name}")
            encoded_dictionary_size = decode_dictionary_size(vort_member[5])
            crc32, data_size, member_size = struct.unpack("<IQQ", vort_member[-20:])
            if crc32 != zlib.crc32(payload):
                raise AssertionError(f"Vort emitted an invalid lzip CRC for {name}")
            if data_size != len(payload) or member_size != len(vort_member):
                raise AssertionError(f"Vort emitted invalid lzip trailer sizes for {name}")
            decoded_vort = lzma.decompress(
                vort_member[6:-20],
                format=lzma.FORMAT_RAW,
                filters=[
                    {
                        "id": lzma.FILTER_LZMA1,
                        "dict_size": encoded_dictionary_size,
                        "lc": 3,
                        "lp": 0,
                        "pb": 2,
                    }
                ],
            )
            if decoded_vort != payload:
                raise AssertionError(f"Python could not decode Vort lzip output for {name}")
            if lzip_tool is not None and lzip_decode(lzip_tool, vort_path) != payload:
                raise AssertionError(f"lzip could not decode Vort output for {name}")
            for pattern in ("one", "micro"):
                run(args.incremental, str(vort_path), str(source_path), pattern)
            incremental_cases += 1
            if name == "text":
                repeated_path = temp / "text-repeat.vort.lz"
                run(
                    args.cli,
                    "encode-lzip-file",
                    str(source_path),
                    str(repeated_path),
                    str(dictionary_size),
                )
                if repeated_path.read_bytes() != vort_member:
                    raise AssertionError("Vort lzip output is not deterministic")
            if name in ("text", "runs") and len(vort_member) >= len(payload):
                raise AssertionError(f"Vort lzip output did not reduce {name}")
            writer_cases += 1

            if lzip_tool is not None and name != "empty":
                reference_path = temp / f"{name}.reference.lz"
                reference_path.write_bytes(lzip_encode(lzip_tool, source_path, dictionary_size))
                run(args.cli, "decode-lzip-file", str(reference_path), str(output_path), str(len(payload)))
                if output_path.read_bytes() != payload:
                    raise AssertionError(f"Vort could not decode lzip output for {name}")
                for pattern in ("one", "micro"):
                    run(args.incremental, str(reference_path), str(source_path), pattern)
                incremental_cases += 1
                external_cases += 1

        concatenated = generated["tiny"] + generated["text"] + generated["random"]
        concat_path = temp / "concatenated.lz"
        concat_output = temp / "concatenated.out"
        concat_path.write_bytes(concatenated)
        expected_concat = cases[1][1] + cases[2][1] + cases[5][1]
        run(args.cli, "decode-lzip-file", str(concat_path), str(concat_output), str(len(expected_concat)))
        if concat_output.read_bytes() != expected_concat:
            raise AssertionError("Vort multimember lzip decode mismatch")
        concat_expected_path = temp / "concatenated.expected"
        concat_expected_path.write_bytes(expected_concat)
        for pattern in ("one", "micro"):
            run(args.incremental, str(concat_path), str(concat_expected_path), pattern)
        incremental_cases += 1
        concat_info = run(args.cli, "inspect-lzip-file", str(concat_path)).stdout
        if "lzip_members=3" not in concat_info:
            raise AssertionError(f"Vort multimember inspection mismatch: {concat_info}")
        if lzip_tool is not None and lzip_decode(lzip_tool, concat_path) != expected_concat:
            raise AssertionError("lzip could not decode generated multimember file")

        vort_concatenated = (
            vort_generated["tiny"]
            + vort_generated["text"]
            + vort_generated["random"]
        )
        vort_concat_path = temp / "vort-concatenated.lz"
        vort_concat_path.write_bytes(vort_concatenated)
        run(
            args.cli,
            "decode-lzip-file",
            str(vort_concat_path),
            str(concat_output),
            str(len(expected_concat)),
        )
        if concat_output.read_bytes() != expected_concat:
            raise AssertionError("Vort could not decode its concatenated lzip output")
        for pattern in ("one", "micro"):
            run(
                args.incremental,
                str(vort_concat_path),
                str(concat_expected_path),
                pattern,
            )
        incremental_cases += 1
        if lzip_tool is not None and lzip_decode(lzip_tool, vort_concat_path) != expected_concat:
            raise AssertionError("lzip could not decode Vort concatenated output")

        limited = run(
            args.cli,
            "decode-lzip-file",
            str(temp / "text.lz"),
            str(temp / "limited.out"),
            str(len(cases[2][1]) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError("lzip output limit was not enforced")

        dictionary_limited = run(
            args.cli,
            "decode-lzip-file",
            str(temp / "random.lz"),
            str(temp / "dictionary-limited.out"),
            str(len(cases[5][1])),
            str(64 * 1024),
            check=False,
        )
        if dictionary_limited.returncode == 0:
            raise AssertionError("lzip dictionary limit was not enforced")

        corrupt = bytearray(generated["binary"])
        corrupt[-20] ^= 1
        corrupt_path = temp / "corrupt.lz"
        corrupt_path.write_bytes(corrupt)
        corrupted = run(
            args.cli,
            "decode-lzip-file",
            str(corrupt_path),
            str(temp / "corrupt.out"),
            check=False,
        )
        if corrupted.returncode == 0:
            raise AssertionError("lzip CRC corruption was accepted")

        wrong_size = bytearray(generated["tiny"])
        wrong_size[-16] ^= 1
        wrong_size_path = temp / "wrong-size.lz"
        wrong_size_path.write_bytes(wrong_size)
        size_mismatch = run(
            args.cli,
            "decode-lzip-file",
            str(wrong_size_path),
            str(temp / "wrong-size.out"),
            check=False,
        )
        if size_mismatch.returncode == 0:
            raise AssertionError("lzip uncompressed-size corruption was accepted")

        trailing_path = temp / "trailing.lz"
        trailing_path.write_bytes(generated["tiny"] + b"trailing")
        trailing = run(
            args.cli,
            "decode-lzip-file",
            str(trailing_path),
            str(temp / "trailing.out"),
            check=False,
        )
        if trailing.returncode == 0:
            raise AssertionError("lzip trailing data was accepted")

    print(
        f"lzip_diff=ok cases={len(cases)} members={len(cases) + 3} compressed_bytes={compressed_total} "
        f"decoded_bytes={decoded_total} system_lzip={lzip_tool is not None} "
        f"lzip_encoded_cases={external_cases} vort_writer_cases={writer_cases} "
        f"incremental_cases={incremental_cases}"
    )


if __name__ == "__main__":
    main()
