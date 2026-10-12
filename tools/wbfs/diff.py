#!/usr/bin/env python3
import argparse
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


HD_SECTOR = 512
WBFS_SECTOR = 2 * 1024 * 1024
LOGICAL_SIZE = 143_432 * 2 * 0x8000
BLOCKS_PER_DISC = (LOGICAL_SIZE + WBFS_SECTOR - 1) // WBFS_SECTOR
DISC_INFO_SIZE = (0x100 + BLOCKS_PER_DISC * 2 + HD_SECTOR - 1) // HD_SECTOR * HD_SECTOR


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
    data = bytearray(3 * WBFS_SECTOR + 137)
    for index in range(WBFS_SECTOR):
        data[index] = (index * 17 + index // 31) & 0xFF
    repetitive = b"WBFS independent differential\n"
    for index in range(2 * WBFS_SECTOR, 3 * WBFS_SECTOR):
        data[index] = repetitive[(index - 2 * WBFS_SECTOR) % len(repetitive)]
    for index in range(3 * WBFS_SECTOR, len(data)):
        data[index] = (index * 29 + 7) & 0xFF
    struct.pack_into(">I", data, 0x18, 0x5D1C9EA3)
    data[0x60:0x62] = b"\0\0"
    data[0x40000:0x40020] = bytes(0x20)
    return bytes(data)


def encode_reference(source: bytes, sparse: bool) -> bytes:
    input_clusters = (len(source) + WBFS_SECTOR - 1) // WBFS_SECTOR
    mappings = [0] * BLOCKS_PER_DISC
    stored: list[bytes] = []
    for index in range(input_clusters):
        chunk = source[index * WBFS_SECTOR : (index + 1) * WBFS_SECTOR]
        if index != 0 and sparse and not any(chunk):
            continue
        stored.append(chunk)
        mappings[index] = len(stored)
    output = bytearray((len(stored) + 1) * WBFS_SECTOR)
    output[0:4] = b"WBFS"
    struct.pack_into(">I", output, 4, len(output) // HD_SECTOR)
    output[8] = 9
    output[9] = 21
    output[12] = 1
    output[HD_SECTOR : HD_SECTOR + 0x100] = source[:0x100]
    for index, mapping in enumerate(mappings):
        struct.pack_into(">H", output, HD_SECTOR + 0x100 + index * 2, mapping)
    for index, chunk in enumerate(stored, 1):
        start = index * WBFS_SECTOR
        output[start : start + len(chunk)] = chunk
    return bytes(output)


def decode_reference_range(image: bytes, offset: int, length: int) -> bytes:
    if image[:4] != b"WBFS":
        raise AssertionError("bad WBFS magic")
    if len(image) != struct.unpack_from(">I", image, 4)[0] * (1 << image[8]):
        raise AssertionError("WBFS size mismatch")
    sector_size = 1 << image[9]
    blocks = (LOGICAL_SIZE + sector_size - 1) // sector_size
    table_offset = (1 << image[8]) + 0x100
    output = bytearray(length)
    written = 0
    while written < length:
        position = offset + written
        cluster = position // sector_size
        within = position % sector_size
        count = min(length - written, sector_size - within)
        mapping = struct.unpack_from(">H", image, table_offset + cluster * 2)[0]
        if mapping:
            physical = mapping * sector_size + within
            output[written : written + count] = image[physical : physical + count]
        written += count
    return bytes(output)


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

    source_bytes = payload()
    writer_cases = 0
    reader_cases = 0
    malformed = 0
    dolphin_cases = 0
    with tempfile.TemporaryDirectory(prefix="vort-wbfs-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.iso"
        source.write_bytes(source_bytes)
        for mode in ("sparse", "full"):
            image = temp / f"vort-{mode}.wbfs"
            run(args.cli, "encode-wbfs", source, image, WBFS_SECTOR, mode)
            expected = encode_reference(source_bytes, mode == "sparse")
            if image.read_bytes() != expected:
                raise AssertionError(f"WBFS writer mismatch for {mode}")
            summary = run(args.cli, "inspect-wbfs", image).stdout
            if b"format=wbfs" not in summary or b"wbfs_sector_bytes=2097152" not in summary:
                raise AssertionError(f"WBFS inspect mismatch for {mode}")
            writer_cases += 1
            if dolphin_tool is not None:
                header = json.loads(
                    run(dolphin_tool, "header", "-i", image, "-j").stdout
                )
                if header.get("block_size") != WBFS_SECTOR:
                    raise AssertionError(f"DolphinTool WBFS header mismatch for {mode}")
                dolphin_cases += 1

        reference = temp / "python-reference.wbfs"
        reference_bytes = encode_reference(source_bytes, True)
        reference.write_bytes(reference_bytes)
        ranges = (
            (0, 0x1000),
            (WBFS_SECTOR - 37, 2 * WBFS_SECTOR + 91),
            (len(source_bytes) - 100, 8192),
            (LOGICAL_SIZE - 4096, 4096),
        )
        for index, (offset, length) in enumerate(ranges):
            output = temp / f"range-{index}.bin"
            run(args.cli, "decode-wbfs-range", reference, output, offset, length)
            expected = decode_reference_range(reference_bytes, offset, length)
            if output.read_bytes() != expected:
                raise AssertionError(f"WBFS range mismatch at {offset}")
            reader_cases += 1

        short = temp / "short.wbfs"
        short.write_bytes(b"WBFS")
        expect_failure(args.cli, "inspect-wbfs", short, error_name="TruncatedFrame")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        corrupt[0] ^= 1
        bad_magic = temp / "bad-magic.wbfs"
        bad_magic.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-wbfs", bad_magic, error_name="InvalidMagic")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        struct.pack_into(">I", corrupt, 4, len(corrupt) // HD_SECTOR - 1)
        bad_size = temp / "bad-size.wbfs"
        bad_size.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-wbfs", bad_size, error_name="SizeMismatch")
        malformed += 1
        expect_failure(
            args.cli,
            "decode-wbfs-range",
            reference,
            temp / "bad-range.bin",
            LOGICAL_SIZE - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"writer={writer_cases} reader_ranges={reader_cases} malformed={malformed} "
        f"dolphin_tool={dolphin_tool is not None} dolphin={dolphin_cases}"
    )


if __name__ == "__main__":
    main()
