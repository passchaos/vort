#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MAGIC1 = 0x1099D02E
HEADER_SIZE = 32
SECTOR_SIZE = 0x8000


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
    first = bytes((index * 17 + index // 31) & 0xFF for index in range(SECTOR_SIZE))
    zero = bytes(SECTOR_SIZE)
    second = (b"WUX independent differential\n" * 1200)[:SECTOR_SIZE]
    third = random.Random(0x57555831).randbytes(SECTOR_SIZE)
    return first + zero + first + second + zero + third


def encode_reference(source: bytes, deduplicate: bool) -> bytes:
    sector_count = (len(source) + SECTOR_SIZE - 1) // SECTOR_SIZE
    metadata_size = HEADER_SIZE + sector_count * 4
    data_offset = (metadata_size + SECTOR_SIZE - 1) // SECTOR_SIZE * SECTOR_SIZE
    table: list[int] = []
    unique: list[bytes] = []
    index: dict[bytes, int] = {}
    for sector_index in range(sector_count):
        sector = source[sector_index * SECTOR_SIZE : (sector_index + 1) * SECTOR_SIZE]
        sector += bytes(SECTOR_SIZE - len(sector))
        mapping = index.get(sector) if deduplicate else None
        if mapping is None:
            mapping = len(unique)
            unique.append(sector)
            if deduplicate:
                index.setdefault(sector, mapping)
        table.append(mapping)
    output = bytearray(data_offset + len(unique) * SECTOR_SIZE)
    output[0:4] = b"WUX0"
    struct.pack_into("<I", output, 4, MAGIC1)
    struct.pack_into("<I", output, 8, SECTOR_SIZE)
    struct.pack_into("<Q", output, 16, len(source))
    for sector_index, mapping in enumerate(table):
        struct.pack_into("<I", output, HEADER_SIZE + sector_index * 4, mapping)
    for sector_index, sector in enumerate(unique):
        start = data_offset + sector_index * SECTOR_SIZE
        output[start : start + SECTOR_SIZE] = sector
    return bytes(output)


def decode_reference_range(image: bytes, offset: int, length: int) -> bytes:
    if image[:4] != b"WUX0" or struct.unpack_from("<I", image, 4)[0] != MAGIC1:
        raise AssertionError("bad WUX magic")
    sector_size = struct.unpack_from("<I", image, 8)[0]
    logical_size = struct.unpack_from("<Q", image, 16)[0]
    if offset + length > logical_size:
        raise AssertionError("range out of bounds")
    sector_count = (logical_size + sector_size - 1) // sector_size
    data_offset = (
        HEADER_SIZE + sector_count * 4 + sector_size - 1
    ) // sector_size * sector_size
    output = bytearray(length)
    written = 0
    while written < length:
        position = offset + written
        logical_sector = position // sector_size
        within = position % sector_size
        count = min(length - written, sector_size - within)
        physical_sector = struct.unpack_from(
            "<I", image, HEADER_SIZE + logical_sector * 4
        )[0]
        source = data_offset + physical_sector * sector_size + within
        output[written : written + count] = image[source : source + count]
        written += count
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wudcompress", type=Path)
    args = parser.parse_args()
    oracle = args.wudcompress or (
        Path(found) if (found := shutil.which("WudCompress")) else None
    )

    source_bytes = payload()
    writer_cases = 0
    reader_ranges = 0
    malformed = 0
    oracle_decode = 0
    oracle_encode = 0
    with tempfile.TemporaryDirectory(prefix="vort-wux-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.wud"
        source.write_bytes(source_bytes)
        for mode in ("deduplicate", "store-all"):
            image = temp / f"vort-{mode}.wux"
            run(args.cli, "encode-wux", source, image, SECTOR_SIZE, mode)
            expected = encode_reference(source_bytes, mode == "deduplicate")
            if image.read_bytes() != expected:
                raise AssertionError(f"WUX writer mismatch for {mode}")
            summary = run(args.cli, "inspect-wux", image).stdout
            if b"format=wux" not in summary or b"sector_bytes=32768" not in summary:
                raise AssertionError(f"WUX inspect mismatch for {mode}")
            writer_cases += 1
            if oracle is not None:
                result = run(oracle, image, "-noverify", check=False)
                if result.returncode != 0:
                    raise AssertionError(
                        "WudCompress decode failed: "
                        + result.stdout.decode(errors="replace")
                        + result.stderr.decode(errors="replace")
                    )
                unpacked = image.with_suffix(".wud")
                if unpacked.read_bytes() != source_bytes:
                    raise AssertionError(f"WudCompress decode mismatch for {mode}")
                oracle_decode += 1

        reference_bytes = encode_reference(source_bytes, True)
        reference = temp / "python-reference.wux"
        reference.write_bytes(reference_bytes)
        ranges = (
            (0, 4096),
            (SECTOR_SIZE - 37, 2 * SECTOR_SIZE + 91),
            (len(source_bytes) - 4096, 4096),
        )
        for index, (offset, length) in enumerate(ranges):
            output = temp / f"range-{index}.bin"
            run(args.cli, "decode-wux-range", reference, output, offset, length)
            expected = decode_reference_range(reference_bytes, offset, length)
            if output.read_bytes() != expected:
                raise AssertionError(f"WUX range mismatch at {offset}")
            reader_ranges += 1

        if oracle is not None:
            oracle_source = temp / "oracle-source.wud"
            oracle_source.write_bytes(source_bytes)
            result = run(oracle, oracle_source, "-noverify", check=False)
            if result.returncode != 0:
                raise AssertionError(
                    "WudCompress encode failed: "
                    + result.stdout.decode(errors="replace")
                    + result.stderr.decode(errors="replace")
                )
            oracle_image = oracle_source.with_suffix(".wux")
            decoded = temp / "oracle-decoded.wud"
            run(args.cli, "decode-wux", oracle_image, decoded, len(source_bytes))
            decoded_bytes = decoded.read_bytes()
            if decoded_bytes != source_bytes:
                first_difference = next(
                    (
                        index
                        for index, (actual, expected) in enumerate(
                            zip(decoded_bytes, source_bytes)
                        )
                        if actual != expected
                    ),
                    min(len(decoded_bytes), len(source_bytes)),
                )
                raise AssertionError(
                    "Vort decode mismatch for WudCompress output: "
                    f"actual={len(decoded_bytes)} expected={len(source_bytes)} "
                    f"first={first_difference}"
                )
            oracle_encode += 1

        short = temp / "short.wux"
        short.write_bytes(b"WUX0")
        expect_failure(args.cli, "inspect-wux", short, error_name="TruncatedFrame")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        corrupt[0] ^= 1
        bad_magic = temp / "bad-magic.wux"
        bad_magic.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-wux", bad_magic, error_name="InvalidMagic")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        struct.pack_into("<I", corrupt, 24, 1)
        bad_flags = temp / "bad-flags.wux"
        bad_flags.write_bytes(corrupt)
        expect_failure(
            args.cli, "inspect-wux", bad_flags, error_name="UnsupportedWuxFeature"
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-wux-range",
            reference,
            temp / "bad-range.bin",
            len(source_bytes) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"writer={writer_cases} reader_ranges={reader_ranges} malformed={malformed} "
        f"wudcompress={oracle is not None} oracle_decode={oracle_decode} "
        f"oracle_encode={oracle_encode}"
    )


if __name__ == "__main__":
    main()
