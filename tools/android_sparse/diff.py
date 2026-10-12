#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


MAGIC = 0xED26FF3A
HEADER_SIZE = 28
CHUNK_HEADER_SIZE = 12
BLOCK_SIZE = 4096
RAW = 0xCAC1
FILL = 0xCAC2
DONT_CARE = 0xCAC3
CRC32 = 0xCAC4


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
    first = bytes((index * 17 + index // 31) & 0xFF for index in range(BLOCK_SIZE))
    zero = bytes(BLOCK_SIZE)
    pattern = struct.pack("<I", 0x11223344) * (BLOCK_SIZE // 4)
    random_block = random.Random(0x53494D47).randbytes(BLOCK_SIZE)
    last = (b"Android sparse independent differential\n" * 128)[:BLOCK_SIZE]
    last += bytes(BLOCK_SIZE - len(last))
    return first + zero + pattern + pattern + random_block + zero + last


def fill_value(block: bytes) -> int | None:
    value = block[:4]
    return struct.unpack("<I", value)[0] if value * (len(block) // 4) == block else None


def encode_reference(
    source: bytes,
    sparse_zero: bool,
    use_fill: bool,
    emit_crc: bool,
    image_checksum: bool,
) -> bytes:
    if len(source) % BLOCK_SIZE:
        raise AssertionError("reference input must be block aligned")
    plans: list[tuple[int, int, int, int]] = []
    block_count = len(source) // BLOCK_SIZE
    index = 0
    while index < block_count:
        block = source[index * BLOCK_SIZE : (index + 1) * BLOCK_SIZE]
        value = fill_value(block)
        if value == 0 and sparse_zero:
            kind = DONT_CARE
        elif value is not None and use_fill:
            kind = FILL
        else:
            kind = RAW
        end = index + 1
        while end < block_count:
            next_block = source[end * BLOCK_SIZE : (end + 1) * BLOCK_SIZE]
            next_value = fill_value(next_block)
            if next_value == 0 and sparse_zero:
                next_kind = DONT_CARE
            elif next_value is not None and use_fill:
                next_kind = FILL
            else:
                next_kind = RAW
            if next_kind != kind or (kind == FILL and next_value != value):
                break
            end += 1
        plans.append((kind, index, end - index, value or 0))
        index = end

    crc = zlib.crc32(source)
    output = bytearray(
        struct.pack(
            "<IHHHHIIII",
            MAGIC,
            1,
            0,
            HEADER_SIZE,
            CHUNK_HEADER_SIZE,
            BLOCK_SIZE,
            block_count,
            len(plans) + int(emit_crc),
            crc if image_checksum else 0,
        )
    )
    for kind, first_block, count, value in plans:
        if kind == RAW:
            payload_bytes = source[
                first_block * BLOCK_SIZE : (first_block + count) * BLOCK_SIZE
            ]
        elif kind == FILL:
            payload_bytes = struct.pack("<I", value)
        else:
            payload_bytes = b""
        output += struct.pack(
            "<HHII", kind, 0, count, CHUNK_HEADER_SIZE + len(payload_bytes)
        )
        output += payload_bytes
    if emit_crc:
        output += struct.pack("<HHIII", CRC32, 0, 0, CHUNK_HEADER_SIZE + 4, crc)
    return bytes(output)


def decode_reference(image: bytes) -> bytes:
    if len(image) < HEADER_SIZE:
        raise AssertionError("truncated sparse image")
    (
        magic,
        major,
        _minor,
        file_header_size,
        chunk_header_size,
        block_size,
        total_blocks,
        total_chunks,
        image_checksum,
    ) = struct.unpack_from("<IHHHHIIII", image)
    if magic != MAGIC or major != 1:
        raise AssertionError("invalid sparse header")
    offset = file_header_size
    output = bytearray()
    for _ in range(total_chunks):
        kind, reserved, blocks, total_size = struct.unpack_from("<HHII", image, offset)
        if reserved or total_size < chunk_header_size:
            raise AssertionError("invalid sparse chunk")
        payload_offset = offset + chunk_header_size
        payload_size = total_size - chunk_header_size
        payload_bytes = image[payload_offset : payload_offset + payload_size]
        if len(payload_bytes) != payload_size:
            raise AssertionError("truncated sparse chunk")
        if kind == RAW:
            if payload_size != blocks * block_size:
                raise AssertionError("invalid raw chunk")
            output += payload_bytes
        elif kind == FILL:
            if payload_size != 4:
                raise AssertionError("invalid fill chunk")
            output += payload_bytes * (blocks * block_size // 4)
        elif kind == DONT_CARE:
            if payload_size:
                raise AssertionError("invalid don't-care chunk")
            output += bytes(blocks * block_size)
        elif kind == CRC32:
            if blocks or payload_size != 4:
                raise AssertionError("invalid CRC32 chunk")
            if struct.unpack("<I", payload_bytes)[0] != zlib.crc32(output):
                raise AssertionError("CRC32 mismatch")
        else:
            raise AssertionError("unknown sparse chunk")
        offset += total_size
    if len(output) != total_blocks * block_size or offset != len(image):
        raise AssertionError("sparse size mismatch")
    if image_checksum and image_checksum != zlib.crc32(output):
        raise AssertionError("image checksum mismatch")
    return bytes(output)


def fuzz_mutations(cli: Path, temp: Path, valid: bytes) -> int:
    samples: list[bytes] = [valid[:length] for length in range(min(len(valid), 40))]
    rng = random.Random(0xA11D501D)
    for _ in range(48):
        mutated = bytearray(valid)
        for _ in range(1 + rng.randrange(4)):
            offset = rng.randrange(len(mutated))
            mutated[offset] ^= 1 << rng.randrange(8)
        samples.append(bytes(mutated))
    for index, sample in enumerate(samples):
        path = temp / f"fuzz-{index}.simg"
        path.write_bytes(sample)
        result = run(cli, "inspect-android-sparse", path, check=False)
        if result.returncode < 0:
            raise AssertionError(f"mutation {index} terminated by signal {-result.returncode}")
    return len(samples)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--simg2img", type=Path)
    parser.add_argument("--img2simg", type=Path)
    args = parser.parse_args()
    simg2img = args.simg2img or (
        Path(found) if (found := shutil.which("simg2img")) else None
    )
    img2simg = args.img2simg or (
        Path(found) if (found := shutil.which("img2simg")) else None
    )

    source_bytes = payload()
    modes = (
        ("sparse-fill", True, True, False, False),
        ("sparse-fill-crcs", True, True, True, True),
        ("stored-raw", False, False, True, False),
        ("sparse-raw-fill", True, False, False, True),
    )
    writer_cases = 0
    reader_ranges = 0
    malformed = 0
    oracle_decode = 0
    oracle_encode = 0
    with tempfile.TemporaryDirectory(prefix="vort-android-sparse-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.img"
        source.write_bytes(source_bytes)
        for name, sparse_zero, use_fill, emit_crc, image_checksum in modes:
            image = temp / f"vort-{name}.simg"
            run(
                args.cli,
                "encode-android-sparse",
                source,
                image,
                BLOCK_SIZE,
                "sparse" if sparse_zero else "store-zero",
                "fill" if use_fill else "raw-fill",
                "crc" if emit_crc else "no-crc",
                "checksum" if image_checksum else "no-checksum",
            )
            expected = encode_reference(
                source_bytes, sparse_zero, use_fill, emit_crc, image_checksum
            )
            actual = image.read_bytes()
            if actual != expected:
                raise AssertionError(f"writer mismatch for {name}")
            if decode_reference(actual) != source_bytes:
                raise AssertionError(f"reference decode mismatch for {name}")
            summary = run(args.cli, "inspect-android-sparse", image).stdout
            if b"format=android-sparse" not in summary or b"block_bytes=4096" not in summary:
                raise AssertionError(f"inspect mismatch for {name}")
            writer_cases += 1
            if simg2img is not None:
                decoded = temp / f"aosp-decoded-{name}.img"
                run(simg2img, image, decoded)
                if decoded.read_bytes() != source_bytes:
                    raise AssertionError(f"simg2img decode mismatch for {name}")
                oracle_decode += 1

        reference_bytes = encode_reference(source_bytes, True, True, True, True)
        reference = temp / "python-reference.simg"
        reference.write_bytes(reference_bytes)
        ranges = (
            (0, 137),
            (BLOCK_SIZE - 37, 3 * BLOCK_SIZE + 91),
            (len(source_bytes) - 4096, 4096),
        )
        for index, (offset, length) in enumerate(ranges):
            output = temp / f"range-{index}.bin"
            run(
                args.cli,
                "decode-android-sparse-range",
                reference,
                output,
                offset,
                length,
            )
            if output.read_bytes() != source_bytes[offset : offset + length]:
                raise AssertionError(f"range mismatch at {offset}")
            reader_ranges += 1

        if img2simg is not None:
            aosp_image = temp / "aosp.simg"
            run(img2simg, source, aosp_image, BLOCK_SIZE)
            decoded = temp / "vort-decoded-aosp.img"
            run(
                args.cli,
                "decode-android-sparse",
                aosp_image,
                decoded,
                len(source_bytes),
            )
            if decoded.read_bytes() != source_bytes:
                raise AssertionError("Vort decode mismatch for img2simg output")
            oracle_encode += 1

        short = temp / "short.simg"
        short.write_bytes(struct.pack("<I", MAGIC))
        expect_failure(
            args.cli, "inspect-android-sparse", short, error_name="TruncatedFrame"
        )
        malformed += 1
        corrupt = bytearray(reference_bytes)
        corrupt[0] ^= 1
        bad_magic = temp / "bad-magic.simg"
        bad_magic.write_bytes(corrupt)
        expect_failure(
            args.cli, "inspect-android-sparse", bad_magic, error_name="InvalidMagic"
        )
        malformed += 1
        corrupt = bytearray(reference_bytes)
        struct.pack_into("<H", corrupt, 4, 2)
        bad_version = temp / "bad-version.simg"
        bad_version.write_bytes(corrupt)
        expect_failure(
            args.cli,
            "inspect-android-sparse",
            bad_version,
            error_name="UnsupportedVersion",
        )
        malformed += 1
        corrupt = bytearray(reference_bytes)
        corrupt[HEADER_SIZE + CHUNK_HEADER_SIZE] ^= 1
        bad_crc = temp / "bad-crc.simg"
        bad_crc.write_bytes(corrupt)
        expect_failure(
            args.cli,
            "inspect-android-sparse",
            bad_crc,
            error_name="ChecksumMismatch",
        )
        malformed += 1
        trailing = temp / "trailing.simg"
        trailing.write_bytes(reference_bytes + b"x")
        expect_failure(
            args.cli,
            "inspect-android-sparse",
            trailing,
            error_name="TrailingData",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-android-sparse-range",
            reference,
            temp / "bad-range.bin",
            len(source_bytes) - 1,
            2,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        fuzz_cases = fuzz_mutations(args.cli, temp, reference_bytes)

    print(
        f"writer={writer_cases} reader_ranges={reader_ranges} malformed={malformed} "
        f"fuzz={fuzz_cases} simg2img={simg2img is not None} "
        f"oracle_decode={oracle_decode} img2simg={img2simg is not None} "
        f"oracle_encode={oracle_encode}"
    )


if __name__ == "__main__":
    main()
