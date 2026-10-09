#!/usr/bin/env python3
"""Bidirectional checks for Vort's LZO1X and LZOP implementation."""

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


def lzop_decode(tool: str, archive: Path, *, multipart: bool = False) -> bytes:
    result = subprocess.run(
        [tool, "-dc", str(archive)],
        check=not multipart,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if multipart and result.returncode not in (0, 2):
        raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
    return result.stdout


def lzop_encode(
    tool: str,
    source: Path,
    level: int,
    *,
    crc32: bool = False,
    compressed_checksum: bool = False,
    filter_distance: int | None = None,
) -> bytes:
    command = [tool, f"-{level}", "-c"]
    if crc32:
        command.append("--crc32")
    if compressed_checksum:
        command.extend(("-C", "-C"))
    if filter_distance is not None:
        command.append(f"--filter={filter_distance}")
    command.append(str(source))
    return subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def lzop_encode_multipart(tool: str, sources: list[Path]) -> bytes:
    return subprocess.run(
        [tool, "-3", "-c", *(str(source) for source in sources)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lzop", type=Path)
    args = parser.parse_args()

    rng = random.Random(0x4C5A4F50)
    long_prefix = bytes(rng.randrange(256) for _ in range(20_000))
    cases: list[tuple[str, bytes, int]] = [
        ("empty", b"", 1),
        ("tiny", b"hello lzop\n", 3),
        ("text", b"Vort LZO1X differential.\n" * 4096, 3),
        ("runs", b"A" * 131072 + b"B" * 16384, 1),
        ("binary", bytes(range(256)) * 513, 9),
        ("random", bytes(rng.randrange(256) for _ in range(32768)), 3),
        ("long-distance", long_prefix + b"separator" + long_prefix, 9),
    ]
    lzop_tool = str(args.lzop) if args.lzop else shutil.which("lzop")

    with tempfile.TemporaryDirectory(prefix="vort-lzop-diff-") as temp_text:
        temp = Path(temp_text)
        encoded_total = 0
        decoded_total = 0
        compressed_blocks = 0
        vort_compressed_cases = 0
        generated: dict[str, bytes] = {}
        for index, (name, payload, level) in enumerate(cases):
            source_path = temp / f"{name}.source"
            vort_stored_path = temp / f"{name}.vort-stored.lzo"
            vort_path = temp / f"{name}.vort.lzo"
            output_path = temp / f"{name}.out"
            source_path.write_bytes(payload)
            checksum = "adler32" if index % 2 == 0 else "crc32"
            run(
                args.cli,
                "encode-lzop-stored-file",
                str(source_path),
                str(vort_stored_path),
                "32768",
                checksum,
            )
            vort_stored = vort_stored_path.read_bytes()
            run(args.cli, "decode-lzop-file", str(vort_stored_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort stored LZOP round-trip mismatch for {name}")
            if lzop_tool is not None and lzop_decode(lzop_tool, vort_stored_path) != payload:
                raise AssertionError(f"lzop could not decode Vort stored output for {name}")

            encode_args = [
                "encode-lzop-file",
                str(source_path),
                str(vort_path),
                "32768",
                checksum,
            ]
            if name in {"text", "runs", "long-distance"}:
                encode_args.append("compressed-checksum")
            run(args.cli, *encode_args)
            vort_encoded = vort_path.read_bytes()
            encoded_total += len(vort_encoded)
            decoded_total += len(payload)
            run(args.cli, "decode-lzop-file", str(vort_path), str(output_path), str(len(payload)))
            if output_path.read_bytes() != payload:
                raise AssertionError(f"Vort compressed LZOP round-trip mismatch for {name}")
            if lzop_tool is not None and lzop_decode(lzop_tool, vort_path) != payload:
                raise AssertionError(f"lzop could not decode Vort compressed output for {name}")

            inspect_vort = run(args.cli, "inspect-lzop-file", str(vort_path)).stdout
            if "compressed_blocks=0" not in inspect_vort:
                vort_compressed_cases += 1
            if name in {"text", "runs", "binary", "long-distance"} and "compressed_blocks=0" in inspect_vort:
                raise AssertionError(f"Vort did not compress the expected LZOP case {name}")

            repeat_path = temp / f"{name}.repeat.lzo"
            repeat_args = encode_args.copy()
            repeat_args[2] = str(repeat_path)
            run(args.cli, *repeat_args)
            if repeat_path.read_bytes() != vort_encoded:
                raise AssertionError(f"Vort LZOP output is not deterministic for {name}")

            stored_repeat_path = temp / f"{name}.stored-repeat.lzo"
            run(
                args.cli,
                "encode-lzop-stored-file",
                str(source_path),
                str(stored_repeat_path),
                "32768",
                checksum,
            )
            if stored_repeat_path.read_bytes() != vort_stored:
                raise AssertionError(f"Vort stored LZOP output is not deterministic for {name}")

            if lzop_tool is not None:
                reference_path = temp / f"{name}.reference.lzo"
                reference = lzop_encode(
                    lzop_tool,
                    source_path,
                    level,
                    crc32=index % 2 == 1,
                    compressed_checksum=name in {"text", "runs"},
                )
                reference_path.write_bytes(reference)
                generated[name] = reference
                run(args.cli, "decode-lzop-file", str(reference_path), str(output_path), str(len(payload)))
                if output_path.read_bytes() != payload:
                    raise AssertionError(f"Vort could not decode lzop output for {name}")
                inspect_output = run(args.cli, "inspect-lzop-file", str(reference_path)).stdout
                if "compressed_blocks=0" not in inspect_output:
                    compressed_blocks += 1

        if lzop_tool is not None:
            filtered_source = temp / "filtered.source"
            filtered_path = temp / "filtered.lzo"
            filtered_output = temp / "filtered.out"
            filtered_payload = bytes(range(251)) * 1024
            filtered_source.write_bytes(filtered_payload)
            filtered_path.write_bytes(lzop_encode(lzop_tool, filtered_source, 3, filter_distance=4))
            run(args.cli, "decode-lzop-file", str(filtered_path), str(filtered_output), str(len(filtered_payload)))
            if filtered_output.read_bytes() != filtered_payload:
                raise AssertionError("Vort could not decode filtered LZOP output")

            concatenated = generated["tiny"] + generated["text"] + generated["random"]
            concat_path = temp / "concatenated.lzo"
            concat_output = temp / "concatenated.out"
            concat_path.write_bytes(concatenated)
            expected = cases[1][1] + cases[2][1] + cases[5][1]
            run(args.cli, "decode-lzop-file", str(concat_path), str(concat_output), str(len(expected)))
            if concat_output.read_bytes() != expected:
                raise AssertionError("Vort concatenated LZOP decode mismatch")
            inspect_output = run(args.cli, "inspect-lzop-file", str(concat_path)).stdout
            if "lzop_streams=3" not in inspect_output:
                raise AssertionError(f"Vort LZOP stream count mismatch: {inspect_output}")

            multipart_path = temp / "multipart.lzo"
            multipart_output = temp / "multipart.out"
            multipart_sources = [temp / "tiny.source", temp / "text.source"]
            multipart_expected = cases[1][1] + cases[2][1]
            multipart_path.write_bytes(lzop_encode_multipart(lzop_tool, multipart_sources))
            run(args.cli, "decode-lzop-file", str(multipart_path), str(multipart_output))
            if multipart_output.read_bytes() != multipart_expected:
                raise AssertionError("Vort lzop multipart decode mismatch")
            if lzop_decode(lzop_tool, multipart_path, multipart=True) != multipart_expected:
                raise AssertionError("lzop multipart self-check failed")

        limited = run(
            args.cli,
            "decode-lzop-file",
            str(temp / "text.vort.lzo"),
            str(temp / "limited.out"),
            str(len(cases[2][1]) - 1),
            check=False,
        )
        if limited.returncode == 0:
            raise AssertionError("LZOP output limit was not enforced")

        block_limited = run(
            args.cli,
            "decode-lzop-file",
            str(temp / "text.vort.lzo"),
            str(temp / "block-limited.out"),
            str(len(cases[2][1])),
            "1024",
            check=False,
        )
        if block_limited.returncode == 0:
            raise AssertionError("LZOP block-size limit was not enforced")

        corrupt = bytearray((temp / "binary.vort.lzo").read_bytes())
        corrupt[-5] ^= 1
        corrupt_path = temp / "corrupt.lzo"
        corrupt_path.write_bytes(corrupt)
        corrupted = run(
            args.cli,
            "decode-lzop-file",
            str(corrupt_path),
            str(temp / "corrupt.out"),
            check=False,
        )
        if corrupted.returncode == 0:
            raise AssertionError("LZOP data corruption was accepted")

    print(
        f"lzop_diff=ok cases={len(cases)} encoded_bytes={encoded_total} "
        f"decoded_bytes={decoded_total} system_lzop={lzop_tool is not None} "
        f"reference_compressed_cases={compressed_blocks} "
        f"vort_compressed_cases={vort_compressed_cases}"
    )


if __name__ == "__main__":
    main()
