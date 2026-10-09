#!/usr/bin/env python3
"""Bidirectional differential tests for Vort's LZMA-Alone implementation."""

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
    xz_tool = shutil.which("xz")

    rng = random.Random(0x1A2B3C)
    cases = {
        "empty": (b"", 0),
        "tiny": (b"hello LZMA-Alone\n", 1),
        "text": (b"Vort LZMA differential.\n" * 2048, 6),
        "runs": (b"A" * 65536 + b"B" * 4096, 3),
        "binary": (bytes(range(256)) * 257, 9),
        "random": (bytes(rng.randrange(256) for _ in range(32768)), 6),
    }

    with tempfile.TemporaryDirectory(prefix="vort-lzma-diff-") as temp_text:
        temp = Path(temp_text)
        compressed_total = 0
        decoded_total = 0
        for name, (payload, preset) in cases.items():
            compressed = lzma.compress(payload, format=lzma.FORMAT_ALONE, preset=preset)
            compressed_total += len(compressed)
            decoded_total += len(payload)
            input_path = temp / f"{name}.lzma"
            output_path = temp / f"{name}.out"
            input_path.write_bytes(compressed)
            run(args.cli, "decode-lzma-file", str(input_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort LZMA decode mismatch for {name}")
            size_output = run(args.cli, "size-lzma-file", str(input_path), str(len(payload))).stdout
            if f"decoded_bytes={len(payload)}" not in size_output:
                raise AssertionError(f"Vort LZMA size mismatch for {name}: {size_output}")

            known_size = bytearray(compressed)
            known_size[5:13] = len(payload).to_bytes(8, "little")
            known_path = temp / f"{name}-known.lzma"
            known_output = temp / f"{name}-known.out"
            known_path.write_bytes(known_size)
            run(args.cli, "decode-lzma-file", str(known_path), str(known_output), str(len(payload)))
            if known_output.read_bytes() != payload:
                raise AssertionError(f"Vort known-size LZMA mismatch for {name}")

            source_path = temp / f"{name}.source"
            source_path.write_bytes(payload)
            for size_mode in ("end-marker", "known"):
                vort_path = temp / f"{name}.{size_mode}.vort.lzma"
                run(
                    args.cli,
                    "encode-lzma-file",
                    str(source_path),
                    str(vort_path),
                    size_mode,
                )
                vort_encoded = vort_path.read_bytes()
                if lzma.decompress(vort_encoded, format=lzma.FORMAT_ALONE) != payload:
                    raise AssertionError(
                        f"Python could not decode Vort {size_mode} LZMA output for {name}"
                    )
                if xz_tool is not None:
                    subprocess.run(
                        [xz_tool, "--format=lzma", "--test", str(vort_path)],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                if name == "text":
                    repeat_path = temp / f"text-repeat.{size_mode}.vort.lzma"
                    run(
                        args.cli,
                        "encode-lzma-file",
                        str(source_path),
                        str(repeat_path),
                        size_mode,
                    )
                    if repeat_path.read_bytes() != vort_encoded:
                        raise AssertionError(
                            f"Vort {size_mode} LZMA output is not deterministic"
                        )
            if name in ("text", "runs") and len(vort_encoded) >= len(payload):
                raise AssertionError(f"Vort LZMA output did not reduce {name}")

        text_payload = cases["text"][0]
        limited = run(
            args.cli,
            "decode-lzma-file",
            str(temp / "text.lzma"),
            str(temp / "limited.out"),
            str(len(text_payload) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError("LZMA output limit was not enforced")

        dictionary_limited = run(
            args.cli,
            "decode-lzma-file",
            str(temp / "text.lzma"),
            str(temp / "dict-limited.out"),
            str(len(text_payload)),
            "1048576",
            check=False,
        )
        if dictionary_limited.returncode == 0:
            raise AssertionError("LZMA dictionary limit was not enforced")

        corrupt = bytearray((temp / "binary.lzma").read_bytes())
        corrupt[-3] ^= 0x40
        corrupt_path = temp / "corrupt.lzma"
        corrupt_path.write_bytes(corrupt)
        corrupted = run(args.cli, "decode-lzma-file", str(corrupt_path), str(temp / "corrupt.out"), check=False)
        if corrupted.returncode == 0:
            raise AssertionError("corrupt LZMA stream was accepted")

    print(
        f"lzma_diff=ok cases={len(cases)} compressed_bytes={compressed_total} "
        f"decoded_bytes={decoded_total} writer_modes=2 system_xz={xz_tool is not None}"
    )


if __name__ == "__main__":
    main()
