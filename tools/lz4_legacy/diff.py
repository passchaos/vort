#!/usr/bin/env python3
import argparse
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MAGIC = bytes((0x02, 0x21, 0x4C, 0x18))
MAX_BLOCK_SIZE = 8 * 1024 * 1024
MAX_COMPRESSED_SIZE = MAX_BLOCK_SIZE + MAX_BLOCK_SIZE // 255 + 16


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def scan_blocks(data: bytes) -> list[int]:
    if len(data) < len(MAGIC) or data[: len(MAGIC)] != MAGIC:
        raise AssertionError("invalid LZ4 legacy magic")
    position = len(MAGIC)
    sizes: list[int] = []
    while position < len(data):
        if len(data) - position < 4:
            raise AssertionError("truncated LZ4 legacy block header")
        compressed_size = struct.unpack_from("<I", data, position)[0]
        position += 4
        if compressed_size == 0 or compressed_size > MAX_COMPRESSED_SIZE:
            raise AssertionError("invalid LZ4 legacy block size")
        if len(data) - position < compressed_size:
            raise AssertionError("truncated LZ4 legacy block payload")
        sizes.append(compressed_size)
        position += compressed_size
    return sizes


def payloads() -> list[tuple[str, bytes]]:
    structured = bytes((index * 29 + index // 17) & 0xFF for index in range(300_000))
    return [
        ("empty", b""),
        ("tiny", b"abc"),
        ("repetitive", b"LZ4 legacy interoperability payload\n" * 8192),
        ("structured", structured),
    ]


def expect_failure(*args: object, error_name: str | None = None) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name is not None and error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name} diagnostic: {result.stderr.decode(errors='replace')}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lz4", type=Path)
    args = parser.parse_args()
    lz4_tool = args.lz4 or (Path(found) if (found := shutil.which("lz4")) else None)
    self_cases = 0
    external_encode_cases = 0
    external_decode_cases = 0
    malformed = 0

    with tempfile.TemporaryDirectory(prefix="vort-lz4-legacy-") as temp_text:
        temp = Path(temp_text)
        for name, payload in payloads():
            source = temp / f"{name}.bin"
            source.write_bytes(payload)
            encoded = temp / f"{name}.vort.lz4"
            repeated = temp / f"{name}.repeat.lz4"
            decoded = temp / f"{name}.vort.out"
            block_size = 32 * 1024

            run(args.cli, "encode-lz4-legacy-file", source, encoded, block_size)
            run(args.cli, "encode-lz4-legacy-file", source, repeated, block_size)
            if encoded.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic Vort legacy output for {name}")
            sizes = scan_blocks(encoded.read_bytes())
            expected_blocks = (len(payload) + block_size - 1) // block_size
            if len(sizes) != expected_blocks:
                raise AssertionError(f"legacy block count mismatch for {name}")
            listing = run(args.cli, "inspect-lz4-legacy-file", encoded, len(payload)).stdout
            if f"lz4_legacy_blocks={expected_blocks}".encode() not in listing:
                raise AssertionError(f"legacy metadata mismatch for {name}: {listing!r}")
            run(args.cli, "decode-lz4-legacy-file", encoded, decoded, len(payload))
            if decoded.read_bytes() != payload:
                raise AssertionError(f"Vort legacy round trip mismatch for {name}")
            self_cases += 1

            if lz4_tool is not None:
                external_decoded = run(lz4_tool, "-d", "-c", encoded).stdout
                if external_decoded != payload:
                    raise AssertionError(f"lz4 failed to decode Vort legacy output for {name}")
                external_decode_cases += 1

                reference = temp / f"{name}.reference.lz4"
                reference.write_bytes(run(lz4_tool, "-l", "-c", source).stdout)
                scan_blocks(reference.read_bytes())
                reference_decoded = temp / f"{name}.reference.out"
                run(
                    args.cli,
                    "decode-lz4-legacy-file",
                    reference,
                    reference_decoded,
                    len(payload),
                )
                if reference_decoded.read_bytes() != payload:
                    raise AssertionError(f"Vort failed to decode lz4 legacy output for {name}")
                external_encode_cases += 1

        valid = temp / "repetitive.vort.lz4"
        expect_failure(
            args.cli,
            "decode-lz4-legacy-file",
            valid,
            temp / "limited.out",
            1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        for name, data, error_name in (
            ("bad-magic", b"bad!", "InvalidMagic"),
            ("zero-block", MAGIC + bytes(4), "InvalidLz4LegacyStream"),
            ("truncated", valid.read_bytes()[:-1], "TruncatedFrame"),
        ):
            path = temp / f"{name}.lz4"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "inspect-lz4-legacy-file",
                path,
                1024 * 1024,
                error_name=error_name,
            )
            malformed += 1

        if lz4_tool is not None:
            large_payload = (b"0123456789abcdef" * ((MAX_BLOCK_SIZE + 4096) // 16 + 1))[
                : MAX_BLOCK_SIZE + 4096
            ]
            source = temp / "large.bin"
            source.write_bytes(large_payload)
            reference = temp / "large.reference.lz4"
            reference.write_bytes(run(lz4_tool, "-l", "-c", source).stdout)
            if len(scan_blocks(reference.read_bytes())) != 2:
                raise AssertionError("lz4 legacy 8 MiB block boundary was not observed")
            decoded = temp / "large.out"
            run(
                args.cli,
                "decode-lz4-legacy-file",
                reference,
                decoded,
                len(large_payload),
            )
            if decoded.read_bytes() != large_payload:
                raise AssertionError("Vort failed to decode multi-block lz4 legacy output")
            external_encode_cases += 1

    print(
        f"self_cases={self_cases} lz4={lz4_tool is not None} "
        f"external_encode={external_encode_cases} "
        f"external_decode={external_decode_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
