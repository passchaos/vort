#!/usr/bin/env python3
import argparse
import struct
import subprocess
import tempfile
from pathlib import Path

import lz4.block


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def encode_reference(data: bytes, block_size: int = 256 * 1024, chunk_size: int = 64 * 1024) -> bytes:
    output = bytearray()
    for block_start in range(0, len(data), block_size):
        block = data[block_start : block_start + block_size]
        output += struct.pack(">I", len(block))
        for chunk_start in range(0, len(block), chunk_size):
            chunk = block[chunk_start : chunk_start + chunk_size]
            compressed = lz4.block.compress(chunk, store_size=False)
            output += struct.pack(">I", len(compressed))
            output += compressed
    return bytes(output)


def decode_reference(data: bytes, chunk_size: int = 64 * 1024) -> bytes:
    position = 0
    output = bytearray()
    while position < len(data):
        expected = struct.unpack(">I", data[position : position + 4])[0]
        position += 4
        written = 0
        while written < expected:
            compressed_len = struct.unpack(">I", data[position : position + 4])[0]
            position += 4
            compressed = data[position : position + compressed_len]
            position += compressed_len
            wanted = min(chunk_size, expected - written)
            plain = lz4.block.decompress(compressed, uncompressed_size=wanted)
            if len(plain) != wanted:
                raise AssertionError("reference Hadoop LZ4 chunk size mismatch")
            output += plain
            written += len(plain)
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    payload = bytes((index * 41 + index // 19) & 0xFF for index in range(700_000))
    self_cases = 0
    reference_cases = 0
    incremental_encode_cases = 0
    incremental_decode_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-hadoop-lz4-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)
        first = temp / "vort-first.lz4"
        second = temp / "vort-second.lz4"
        for output in (first, second):
            run(args.cli, "encode-hadoop-lz4-file", source, output)
        if first.read_bytes() != second.read_bytes():
            raise AssertionError("Vort Hadoop LZ4 output is not deterministic")
        incremental = temp / "vort-incremental.lz4"
        run(args.cli, "encode-hadoop-lz4-incremental-file", source, incremental)
        if incremental.read_bytes() != first.read_bytes():
            raise AssertionError("Vort Hadoop LZ4 incremental encode is not one-shot exact")
        if decode_reference(incremental.read_bytes()) != payload:
            raise AssertionError("python-lz4 rejected Vort incremental Hadoop LZ4 output")
        incremental_encode_cases += 1
        if decode_reference(first.read_bytes()) != payload:
            raise AssertionError("python-lz4 rejected Vort Hadoop LZ4 output")
        decoded = temp / "vort.out"
        run(args.cli, "decode-hadoop-lz4-file", first, decoded, len(payload))
        if decoded.read_bytes() != payload:
            raise AssertionError("Vort Hadoop LZ4 self decode mismatch")
        incremental_decoded = temp / "vort-incremental.out"
        run(
            args.cli,
            "decode-hadoop-lz4-incremental-file",
            first,
            incremental_decoded,
            len(payload),
            17,
            31,
        )
        if incremental_decoded.read_bytes() != payload:
            raise AssertionError("Vort Hadoop LZ4 incremental self decode mismatch")
        incremental_decode_cases += 1
        listing = run(args.cli, "inspect-hadoop-lz4-file", first).stdout
        if "decoded_bytes=700000" not in listing or "hadoop_lz4_blocks=" not in listing:
            raise AssertionError(f"Vort Hadoop LZ4 metadata mismatch: {listing}")
        self_cases += 1

        reference = temp / "python.lz4"
        reference.write_bytes(encode_reference(payload))
        reference_output = temp / "python.out"
        run(args.cli, "decode-hadoop-lz4-file", reference, reference_output, len(payload))
        if reference_output.read_bytes() != payload:
            raise AssertionError("Vort rejected python-lz4 Hadoop framing")
        reference_incremental_output = temp / "python-incremental.out"
        run(
            args.cli,
            "decode-hadoop-lz4-incremental-file",
            reference,
            reference_incremental_output,
            len(payload),
            17,
            31,
        )
        if reference_incremental_output.read_bytes() != payload:
            raise AssertionError("Vort incremental decoder rejected python-lz4 Hadoop framing")
        incremental_decode_cases += 1
        reference_cases += 1

        limited = run(
            args.cli,
            "decode-hadoop-lz4-file",
            first,
            temp / "limited.out",
            len(payload) - 1,
            check=False,
        )
        if limited.returncode == 0 or "OutputLimitExceeded" not in limited.stderr:
            raise AssertionError("Vort ignored Hadoop LZ4 output limit")
        malformed += 1

        corrupt = bytearray(first.read_bytes())
        corrupt[0:4] = (1).to_bytes(4, "big")
        corrupt_path = temp / "bad-length.lz4"
        corrupt_path.write_bytes(corrupt)
        if run(args.cli, "inspect-hadoop-lz4-file", corrupt_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted mismatched Hadoop LZ4 block length")
        malformed += 1

    print(
        f"self_cases={self_cases} reference_cases={reference_cases} "
        f"incremental_encode_cases={incremental_encode_cases} "
        f"incremental_decode_cases={incremental_decode_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
