#!/usr/bin/env python3
"""Differential tests for Vort's dependency-free Bzip2 decoder."""

from __future__ import annotations

import argparse
import bz2
import random
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

    rng = random.Random(0xB21)
    cases = {
        "empty": (b"", 1),
        "tiny": (b"hello bzip2\n", 9),
        "text": (b"Vort dependency-free Bzip2 differential.\n" * 2048, 9),
        "runs": (b"A" * 70000 + b"B" * 8192 + b"A" * 1024, 1),
        "binary": (bytes(range(256)) * 257, 9),
        "random": (bytes(rng.randrange(256) for _ in range(32768)), 1),
        "multiblock": (bytes(range(251)) * 1000, 1),
    }

    with tempfile.TemporaryDirectory(prefix="vort-bzip2-diff-") as temp_text:
        temp = Path(temp_text)
        compressed_total = 0
        decoded_total = 0
        for name, (payload, level) in cases.items():
            compressed = bz2.compress(payload, compresslevel=level)
            if bz2.decompress(compressed) != payload:
                raise AssertionError(f"Python bz2 self-check failed for {name}")
            compressed_total += len(compressed)
            decoded_total += len(payload)
            input_path = temp / f"{name}.bz2"
            output_path = temp / f"{name}.out"
            input_path.write_bytes(compressed)

            run(args.cli, "decode-bzip2-file", str(input_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort decode mismatch for {name}")
            size_output = run(args.cli, "size-bzip2-file", str(input_path), str(len(payload))).stdout
            if f"decoded_bytes={len(payload)}" not in size_output:
                raise AssertionError(f"Vort size mismatch for {name}: {size_output}")

            source_path = temp / f"{name}.source"
            vort_path = temp / f"{name}.vort.bz2"
            source_path.write_bytes(payload)
            run(args.cli, "encode-bzip2-file", str(source_path), str(vort_path), str(level))
            vort_encoded = vort_path.read_bytes()
            if not vort_encoded.startswith(f"BZh{level}".encode()):
                raise AssertionError(f"Vort Bzip2 header mismatch for {name}")
            if bz2.decompress(vort_encoded) != payload:
                raise AssertionError(f"Python could not decode Vort output for {name}")

            if name == "text":
                repeat_path = temp / "text-repeat.vort.bz2"
                run(args.cli, "encode-bzip2-file", str(source_path), str(repeat_path), str(level))
                if repeat_path.read_bytes() != vort_encoded:
                    raise AssertionError("Vort Bzip2 output is not deterministic")

        randomized_payload = b"a\n" * 2500
        randomized = bytes.fromhex(
            "425a68313141592653597d0435b980077dc10000186000200050669a052534e42"
            "abb456c0d8856d02af5555da546c026d2ab6a889f1772453850907d0435b9"
        )
        if bz2.decompress(randomized) != randomized_payload:
            raise AssertionError("Python bz2 rejected bzip2 0.1 randomized fixture")
        randomized_path = temp / "randomized.bz2"
        randomized_output = temp / "randomized.out"
        randomized_path.write_bytes(randomized)
        run(
            args.cli,
            "decode-bzip2-file",
            str(randomized_path),
            str(randomized_output),
            str(len(randomized_payload)),
        )
        if randomized_output.read_bytes() != randomized_payload:
            raise AssertionError("Vort rejected legacy randomized Bzip2 block")
        randomized_size = run(
            args.cli,
            "size-bzip2-file",
            str(randomized_path),
            str(len(randomized_payload)),
        ).stdout
        if f"decoded_bytes={len(randomized_payload)}" not in randomized_size:
            raise AssertionError(f"Vort randomized Bzip2 size mismatch: {randomized_size}")

        first = b"first concatenated member\n" * 97
        second = bytes(range(251)) * 313
        concatenated = bz2.compress(first, compresslevel=1) + bz2.compress(second, compresslevel=9)
        concat_path = temp / "concatenated.bz2"
        concat_output = temp / "concatenated.out"
        concat_path.write_bytes(concatenated)
        strict = run(args.cli, "decode-bzip2-file", str(concat_path), str(concat_output), check=False)
        if strict.returncode == 0:
            raise AssertionError("single-stream Bzip2 API accepted concatenated input")
        run(
            args.cli,
            "decode-bzip2-concat-file",
            str(concat_path),
            str(concat_output),
            str(len(first) + len(second)),
        )
        if concat_output.read_bytes() != first + second:
            raise AssertionError("Vort concatenated Bzip2 decode mismatch")

        limited = run(
            args.cli,
            "decode-bzip2-file",
            str(temp / "text.bz2"),
            str(temp / "limited.out"),
            str(len(cases["text"][0]) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError("Bzip2 output limit was not enforced")

        corrupt = bytearray((temp / "multiblock.bz2").read_bytes())
        corrupt[-2] ^= 0x20
        corrupt_path = temp / "corrupt.bz2"
        corrupt_path.write_bytes(corrupt)
        corrupted = run(
            args.cli,
            "decode-bzip2-file",
            str(corrupt_path),
            str(temp / "corrupt.out"),
            check=False,
        )
        if corrupted.returncode == 0:
            raise AssertionError("corrupt Bzip2 stream was accepted")

    print(
        f"bzip2_diff=ok directions=2 cases={len(cases)} compressed_bytes={compressed_total} "
        f"decoded_bytes={decoded_total} randomized_cases=1 "
        f"concatenated_bytes={len(first) + len(second)}"
    )


if __name__ == "__main__":
    main()
