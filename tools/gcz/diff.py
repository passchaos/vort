#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


BLOCK_SIZE = 128 * 1024
MAGIC = 0xB10BC001
RAW_FLAG = 1 << 63
OFFSET_MASK = RAW_FLAG - 1


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def expect_failure(*args: object, error_name: str) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name}: {result.stderr.decode(errors='replace')}"
        )


def payload() -> bytes:
    rng = random.Random(0x47435A)
    repetitive = (b"Dolphin GCZ differential block\n" * 5000)[:BLOCK_SIZE]
    random_block = rng.randbytes(BLOCK_SIZE)
    zeros = bytes(BLOCK_SIZE)
    structured = bytes((index * 19 + index // 23) & 0xFF for index in range(BLOCK_SIZE))
    return repetitive + random_block + zeros + structured + repetitive + b"partial GCZ tail"


def reference_decode(image: bytes) -> bytes:
    if len(image) < 32:
        raise AssertionError("reference GCZ header is truncated")
    magic, _, stored_size, logical_size, block_size, block_count = struct.unpack_from(
        "<IIQQII", image
    )
    if magic != MAGIC or block_size == 0 or block_count == 0:
        raise AssertionError("reference GCZ header is invalid")
    if block_count != (logical_size + block_size - 1) // block_size:
        raise AssertionError("reference GCZ block count mismatch")
    data_offset = 32 + block_count * 12
    if data_offset + stored_size > len(image):
        raise AssertionError("reference GCZ data is truncated")
    pointers = struct.unpack_from(f"<{block_count}Q", image, 32)
    hashes = struct.unpack_from(f"<{block_count}I", image, 32 + block_count * 8)
    decoded = bytearray()
    for index, pointer in enumerate(pointers):
        start = pointer & OFFSET_MASK
        end = (
            pointers[index + 1] & OFFSET_MASK
            if index + 1 < block_count
            else stored_size
        )
        if end < start or end > stored_size:
            raise AssertionError("reference GCZ pointer mismatch")
        block = image[data_offset + start : data_offset + end]
        if zlib.adler32(block) & 0xFFFFFFFF != hashes[index]:
            raise AssertionError("reference GCZ hash mismatch")
        if pointer & RAW_FLAG:
            if len(block) != block_size:
                raise AssertionError("reference GCZ raw size mismatch")
            decoded.extend(block)
        else:
            plain = zlib.decompress(block)
            if len(plain) != block_size:
                raise AssertionError("reference GCZ decoded size mismatch")
            decoded.extend(plain)
    return bytes(decoded[:logical_size])


def reference_encode(plain: bytes, block_size: int) -> bytes:
    block_count = (len(plain) + block_size - 1) // block_size
    pointers: list[int] = []
    hashes: list[int] = []
    stored_blocks: list[bytes] = []
    position = 0
    for index in range(block_count):
        block = plain[index * block_size : (index + 1) * block_size]
        block += bytes(block_size - len(block))
        compressed = zlib.compress(block, 9)
        raw = len(compressed) > block_size - 10
        stored = block if raw else compressed
        pointers.append(position | (RAW_FLAG if raw else 0))
        hashes.append(zlib.adler32(stored) & 0xFFFFFFFF)
        stored_blocks.append(stored)
        position += len(stored)
    header = struct.pack(
        "<IIQQII",
        MAGIC,
        0,
        position,
        len(plain),
        block_size,
        block_count,
    )
    pointer_table = struct.pack(f"<{block_count}Q", *pointers)
    hash_table = struct.pack(f"<{block_count}I", *hashes)
    return header + pointer_table + hash_table + b"".join(stored_blocks)


def dolphin_convert(
    executable: Path,
    source: Path,
    output: Path,
    output_format: str,
    block_size: int | None = None,
) -> None:
    command: list[object] = [
        executable,
        "convert",
        "-i",
        source,
        "-o",
        output,
        "-f",
        output_format,
    ]
    if block_size is not None:
        command.extend(("-b", block_size))
    run(*command)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--dolphin-tool", type=Path)
    args = parser.parse_args()
    dolphin_tool = args.dolphin_tool or (
        Path(found)
        if (found := shutil.which("dolphin-tool") or shutil.which("DolphinTool"))
        else None
    )

    plain = payload()
    self_cases = 0
    external_encode = 0
    external_decode = 0
    reference_encode_cases = 0
    reference_decode_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-gcz-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.iso"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for compression in ("raw", "zlib", "auto"):
            image = temp / f"vort-{compression}.gcz"
            output = temp / f"vort-{compression}.iso"
            ranged = temp / f"vort-{compression}.range"
            run(
                args.cli,
                "encode-gcz",
                source,
                image,
                compression,
                BLOCK_SIZE,
                9,
                0,
            )
            summary = run(args.cli, "inspect-gcz", image).stdout
            if b"blocks=6" not in summary or f"block_bytes={BLOCK_SIZE}".encode() not in summary:
                raise AssertionError(f"Vort GCZ inspect mismatch for {compression}")
            run(args.cli, "decode-gcz", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort GCZ round trip mismatch for {compression}")
            range_offset = BLOCK_SIZE - 37
            range_length = 2 * BLOCK_SIZE + 91
            run(
                args.cli,
                "decode-gcz-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort GCZ range mismatch for {compression}")
            images[compression] = image
            self_cases += 1
            if reference_decode(image.read_bytes()) != plain:
                raise AssertionError(f"Python reference decode mismatch for {compression}")
            reference_encode_cases += 1

            if dolphin_tool is not None:
                external = temp / f"vort-{compression}.dolphin.iso"
                dolphin_convert(dolphin_tool, image, external, "iso")
                if external.read_bytes() != plain:
                    raise AssertionError(f"DolphinTool GCZ decode mismatch for {compression}")
                external_encode += 1

        valid = images["auto"]
        expect_failure(
            args.cli,
            "decode-gcz",
            valid,
            temp / "limited.iso",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-gcz-range",
            valid,
            temp / "bad-range.iso",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        short = temp / "short.gcz"
        short.write_bytes(valid.read_bytes()[:32])
        expect_failure(args.cli, "inspect-gcz", short, error_name="TruncatedFrame")
        malformed += 1
        bad_pointer_bytes = bytearray(valid.read_bytes())
        struct.pack_into("<Q", bad_pointer_bytes, 32, 1)
        bad_pointer = temp / "bad-pointer.gcz"
        bad_pointer.write_bytes(bad_pointer_bytes)
        expect_failure(args.cli, "inspect-gcz", bad_pointer, error_name="InvalidGcz")
        malformed += 1
        bad_hash_bytes = bytearray(valid.read_bytes())
        block_count = (len(plain) + BLOCK_SIZE - 1) // BLOCK_SIZE
        hashes_offset = 32 + block_count * 8
        bad_hash_bytes[hashes_offset] ^= 1
        bad_hash = temp / "bad-hash.gcz"
        bad_hash.write_bytes(bad_hash_bytes)
        expect_failure(
            args.cli,
            "decode-gcz-range",
            bad_hash,
            temp / "bad-hash.range",
            0,
            1,
            error_name="ChecksumMismatch",
        )
        malformed += 1

        reference_image = temp / "reference.gcz"
        reference_output = temp / "reference.vort.iso"
        reference_image.write_bytes(reference_encode(plain, BLOCK_SIZE))
        run(args.cli, "decode-gcz", reference_image, reference_output, len(plain))
        if reference_output.read_bytes() != plain:
            raise AssertionError("Vort decode mismatch for Python reference GCZ")
        reference_decode_cases += 1

        if dolphin_tool is not None:
            image = temp / "dolphin.gcz"
            output = temp / "dolphin.vort.iso"
            dolphin_convert(dolphin_tool, source, image, "gcz", BLOCK_SIZE)
            run(args.cli, "decode-gcz", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode mismatch for DolphinTool GCZ")
            external_decode += 1

    print(
        f"self={self_cases} dolphin_tool={dolphin_tool is not None} "
        f"reference_encode={reference_encode_cases} "
        f"reference_decode={reference_decode_cases} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
