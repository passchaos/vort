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
        f"bzip2_diff=ok cases={len(cases)} compressed_bytes={compressed_total} "
        f"decoded_bytes={decoded_total} concatenated_bytes={len(first) + len(second)}"
    )


if __name__ == "__main__":
    main()
