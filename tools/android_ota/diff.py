#!/usr/bin/env python3
import argparse
import bz2
import hashlib
import lzma
import random
import re
import shutil
import struct
import subprocess
import tarfile
import tempfile
import zlib
from pathlib import Path


MAGIC = b"CrAU"
BLOCK_SIZE = 4096
HEADER_SIZE = 24
REPLACE = 0
REPLACE_BZ = 1
SOURCE_COPY = 4
SOURCE_BSDIFF = 5
ZERO = 6
REPLACE_XZ = 8
PUFFDIFF = 9

PUFFDIFF_FIXTURE = bytes.fromhex(
    "5055463100000051080112270a04081010320a040850100a0a04086010121204"
    "08101058120408781028120508a8011038181f1a240a0210320a04084810500a"
    "05089801101212021058120408701058120508c8011038182142534449464634"
    "30380000000000000034000000000000002100000000000000425a6839314159"
    "26535965298c9b00000360407a0e08004000200021229a3d4f50400c3bc79bb2"
    "210ee915987a7c5dc914e1424194a6326c425a6839314159265359f1205f0d00"
    "00024115420820004000000240002000223d23108603965411165f1772453850"
    "90f1205f0d425a683931415926535907d4cb6e00000001000100200021184682"
    "ee48a70a1200fa996dc0"
)


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


def varint(value: int) -> bytes:
    output = bytearray()
    while value >= 0x80:
        output.append((value & 0x7F) | 0x80)
        value >>= 7
    output.append(value)
    return bytes(output)


def vfield(number: int, value: int) -> bytes:
    return varint(number << 3) + varint(value)


def bfield(number: int, value: bytes) -> bytes:
    return varint((number << 3) | 2) + varint(len(value)) + value


def parse_varint(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    shift = 0
    for _ in range(10):
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, offset
        shift += 7
    raise AssertionError("invalid varint")


def fields(data: bytes) -> list[tuple[int, int, int | bytes]]:
    output: list[tuple[int, int, int | bytes]] = []
    offset = 0
    while offset < len(data):
        tag, offset = parse_varint(data, offset)
        number, wire = tag >> 3, tag & 7
        if wire == 0:
            value, offset = parse_varint(data, offset)
        elif wire == 2:
            length, offset = parse_varint(data, offset)
            value = data[offset : offset + length]
            if len(value) != length:
                raise AssertionError("truncated protobuf field")
            offset += length
        elif wire == 1:
            value = data[offset : offset + 8]
            offset += 8
        elif wire == 5:
            value = data[offset : offset + 4]
            offset += 4
        else:
            raise AssertionError(f"unsupported wire type {wire}")
        output.append((number, wire, value))
    return output


def one(message: bytes, number: int, default: int | bytes | None = None) -> int | bytes | None:
    values = [value for field, _, value in fields(message) if field == number]
    if len(values) > 1:
        raise AssertionError(f"duplicate field {number}")
    return values[0] if values else default


def many(message: bytes, number: int) -> list[int | bytes]:
    return [value for field, _, value in fields(message) if field == number]


def extent(start: int, count: int) -> bytes:
    return vfield(1, start) + vfield(2, count)


def operation(
    kind: int,
    start_block: int,
    block_count: int,
    data_offset: int = 0,
    blob: bytes = b"",
) -> bytes:
    message = bytearray(vfield(1, kind))
    if blob:
        message += vfield(2, data_offset)
        message += vfield(3, len(blob))
    message += bfield(6, extent(start_block, block_count))
    if blob:
        message += bfield(8, hashlib.sha256(blob).digest())
    return bytes(message)


def partition_info(data: bytes) -> bytes:
    return vfield(1, len(data)) + bfield(2, hashlib.sha256(data).digest())


def build_payload(
    partition_data: bytes,
    operations: list[tuple[int, int, int, bytes]],
    name: bytes = b"system",
) -> bytes:
    data_offset = 0
    partition = bytearray(bfield(1, name))
    partition += bfield(7, partition_info(partition_data))
    blobs = bytearray()
    for kind, start, count, blob in operations:
        partition += bfield(8, operation(kind, start, count, data_offset, blob))
        blobs += blob
        data_offset += len(blob)
    manifest = vfield(3, BLOCK_SIZE) + vfield(12, 0) + bfield(13, bytes(partition))
    return MAGIC + struct.pack(">QQI", 2, len(manifest), 0) + manifest + blobs


def reference_mixed_payload(data: bytes) -> bytes:
    blocks = [data[index * BLOCK_SIZE : (index + 1) * BLOCK_SIZE] for index in range(4)]
    return build_payload(
        data,
        [
            (REPLACE, 0, 1, blocks[0]),
            (REPLACE_BZ, 1, 1, bz2.compress(blocks[1], compresslevel=9)),
            (
                REPLACE_XZ,
                2,
                1,
                lzma.compress(
                    blocks[2],
                    format=lzma.FORMAT_XZ,
                    check=lzma.CHECK_CRC32,
                    preset=6,
                ),
            ),
            (ZERO, 3, 1, b""),
        ],
    )


def source_copy_payload(source: bytes) -> tuple[bytes, bytes]:
    if len(source) != 2 * BLOCK_SIZE:
        raise AssertionError("source copy fixture must be two blocks")
    target = source[BLOCK_SIZE:] + source[:BLOCK_SIZE]
    operation_message = bytearray(vfield(1, SOURCE_COPY))
    operation_message += bfield(4, extent(1, 1))
    operation_message += bfield(4, extent(0, 1))
    operation_message += bfield(6, extent(0, 2))
    operation_message += bfield(9, hashlib.sha256(target).digest())
    partition = bytearray(bfield(1, b"vendor"))
    partition += bfield(6, partition_info(source))
    partition += bfield(7, partition_info(target))
    partition += bfield(8, bytes(operation_message))
    manifest = vfield(3, BLOCK_SIZE) + vfield(12, 2) + bfield(13, bytes(partition))
    return MAGIC + struct.pack(">QQI", 2, len(manifest), 0) + manifest, target


def signed_magnitude(value: int) -> bytes:
    magnitude = abs(value)
    if magnitude > (1 << 63) - 1:
        raise AssertionError("signed-magnitude value is too large")
    if value < 0:
        magnitude |= 1 << 63
    return struct.pack("<Q", magnitude)


def source_bsdiff_payload(source: bytes) -> tuple[bytes, bytes, bytes]:
    if len(source) != 2 * BLOCK_SIZE:
        raise AssertionError("SOURCE_BSDIFF fixture must be two blocks")
    target_first = bytearray(source[:BLOCK_SIZE])
    for index in range(0, BLOCK_SIZE, 31):
        target_first[index] ^= (index * 17 + 3) & 0xFF
    target_second = (b"independent BSDIFF40 extra stream\n" * 160)[:BLOCK_SIZE]
    target_second += bytes(BLOCK_SIZE - len(target_second))
    target = bytes(target_first) + target_second
    diff = bytes(
        (new - old) & 0xFF
        for old, new in zip(source[:BLOCK_SIZE], target_first)
    )
    control = (
        signed_magnitude(BLOCK_SIZE)
        + signed_magnitude(BLOCK_SIZE)
        + signed_magnitude(0)
    )
    control_compressed = bz2.compress(control, compresslevel=9)
    diff_compressed = bz2.compress(diff, compresslevel=9)
    extra_compressed = bz2.compress(target_second, compresslevel=9)
    patch = (
        b"BSDIFF40"
        + signed_magnitude(len(control_compressed))
        + signed_magnitude(len(diff_compressed))
        + signed_magnitude(len(target))
        + control_compressed
        + diff_compressed
        + extra_compressed
    )

    operation_message = bytearray(vfield(1, SOURCE_BSDIFF))
    operation_message += vfield(2, 0)
    operation_message += vfield(3, len(patch))
    operation_message += bfield(4, extent(0, 2))
    operation_message += bfield(6, extent(0, 2))
    operation_message += bfield(8, hashlib.sha256(patch).digest())
    operation_message += bfield(9, hashlib.sha256(source).digest())
    partition = bytearray(bfield(1, b"product"))
    partition += bfield(6, partition_info(source))
    partition += bfield(7, partition_info(target))
    partition += bfield(8, bytes(operation_message))
    manifest = vfield(3, BLOCK_SIZE) + vfield(12, 4) + bfield(13, bytes(partition))
    payload = MAGIC + struct.pack(">QQI", 2, len(manifest), 0) + manifest + patch
    return payload, target, patch


def puffdiff_payload() -> tuple[bytes, bytes, bytes]:
    source_prefix = bytes.fromhex(
        "1122636462666105003303006304004455"
    )
    expected_prefix = bytes.fromhex(
        "636462666105003366010500faff0102030405630400"
    )
    source = source_prefix + bytes(BLOCK_SIZE - len(source_prefix))
    target = expected_prefix + bytes(BLOCK_SIZE - len(expected_prefix))
    operation_message = bytearray(vfield(1, PUFFDIFF))
    operation_message += vfield(2, 0)
    operation_message += vfield(3, len(PUFFDIFF_FIXTURE))
    operation_message += bfield(4, extent(0, 1))
    operation_message += bfield(6, extent(0, 1))
    operation_message += vfield(7, 22)
    operation_message += bfield(8, hashlib.sha256(PUFFDIFF_FIXTURE).digest())
    operation_message += bfield(9, hashlib.sha256(source).digest())
    partition = bytearray(bfield(1, b"puffin"))
    partition += bfield(6, partition_info(source))
    partition += bfield(7, partition_info(target))
    partition += bfield(8, bytes(operation_message))
    manifest = vfield(3, BLOCK_SIZE) + vfield(12, 5) + bfield(13, bytes(partition))
    payload = MAGIC + struct.pack(">QQI", 2, len(manifest), 0) + manifest + PUFFDIFF_FIXTURE
    return payload, source, target


def decode_reference(payload: bytes) -> dict[str, bytes]:
    if payload[:4] != MAGIC:
        raise AssertionError("bad magic")
    major, manifest_size, metadata_signature_size = struct.unpack_from(">QQI", payload, 4)
    if major != 2:
        raise AssertionError("bad major")
    manifest = payload[HEADER_SIZE : HEADER_SIZE + manifest_size]
    data_base = HEADER_SIZE + manifest_size + metadata_signature_size
    block_size = int(one(manifest, 3, 4096))
    output: dict[str, bytes] = {}
    for partition_value in many(manifest, 13):
        partition = bytes(partition_value)
        name = bytes(one(partition, 1)).decode()
        info = bytes(one(partition, 7))
        size = int(one(info, 1, 0))
        expected_hash = bytes(one(info, 2, b""))
        image = bytearray(size)
        covered = bytearray(size)
        for operation_value in many(partition, 8):
            op = bytes(operation_value)
            kind = int(one(op, 1))
            blob_offset = int(one(op, 2, 0))
            blob_length = int(one(op, 3, 0))
            blob = payload[data_base + blob_offset : data_base + blob_offset + blob_length]
            blob_hash = bytes(one(op, 8, b""))
            if blob_hash and hashlib.sha256(blob).digest() != blob_hash:
                raise AssertionError("blob hash mismatch")
            if kind == REPLACE:
                decoded = blob
            elif kind == REPLACE_BZ:
                decoded = bz2.decompress(blob)
            elif kind == REPLACE_XZ:
                decoded = lzma.decompress(blob, format=lzma.FORMAT_XZ)
            elif kind == ZERO:
                decoded = None
            else:
                raise AssertionError(f"unsupported reference operation {kind}")
            operation_offset = 0
            for extent_value in many(op, 6):
                extent_message = bytes(extent_value)
                start = int(one(extent_message, 1, 0)) * block_size
                length = int(one(extent_message, 2, 0)) * block_size
                end = min(start + length, size)
                if any(covered[start:end]):
                    raise AssertionError("overlapping destination")
                covered[start:end] = b"\1" * (end - start)
                if decoded is None:
                    image[start:end] = bytes(end - start)
                else:
                    image[start:end] = decoded[operation_offset : operation_offset + end - start]
                operation_offset += length
            if decoded is not None and operation_offset != len(decoded):
                raise AssertionError("operation size mismatch")
        if not all(covered):
            raise AssertionError("incomplete partition")
        if expected_hash and hashlib.sha256(image).digest() != expected_hash:
            raise AssertionError("partition hash mismatch")
        output[name] = bytes(image)
    return output


def writer_payload() -> bytes:
    structured = bytes((index * 17 + index // 31) & 0xFF for index in range(BLOCK_SIZE))
    repetitive = (b"Android OTA independent differential\n" * 128)[:BLOCK_SIZE]
    repetitive += bytes(BLOCK_SIZE - len(repetitive))
    zeros = bytes(2 * BLOCK_SIZE)
    random_bytes = random.Random(0x43524155).randbytes(2 * BLOCK_SIZE)
    return structured + repetitive + zeros + random_bytes


def mixed_payload_data() -> bytes:
    first = bytes((index * 29 + 3) & 0xFF for index in range(BLOCK_SIZE))
    second = (b"bzip2 reference operation " * 200)[:BLOCK_SIZE]
    second += bytes(BLOCK_SIZE - len(second))
    third = (b"xz reference operation " * 240)[:BLOCK_SIZE]
    third += bytes(BLOCK_SIZE - len(third))
    return first + second + third + bytes(BLOCK_SIZE)


def fuzz_mutations(cli: Path, temp: Path, valid: bytes) -> int:
    samples = [valid[:length] for length in range(min(len(valid), 32))]
    rng = random.Random(0x43524155)
    for _ in range(48):
        mutated = bytearray(valid)
        for _ in range(1 + rng.randrange(4)):
            offset = rng.randrange(len(mutated))
            mutated[offset] ^= 1 << rng.randrange(8)
        samples.append(bytes(mutated))
    for index, sample in enumerate(samples):
        path = temp / f"fuzz-{index}.bin"
        path.write_bytes(sample)
        result = run(cli, "inspect-android-ota", path, check=False)
        if result.returncode < 0:
            raise AssertionError(f"mutation {index} terminated by signal {-result.returncode}")
    return len(samples)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--payload-dumper", type=Path)
    parser.add_argument("--aosp-update-engine", type=Path)
    parser.add_argument("--bspatch", type=Path)
    parser.add_argument("--puffin", type=Path)
    parser.add_argument("--puff-codec-oracle", type=Path)
    args = parser.parse_args()
    oracle = args.payload_dumper or (
        Path(found) if (found := shutil.which("payload_dumper")) else None
    )
    bspatch = args.bspatch or (
        Path(found) if (found := shutil.which("bspatch")) else None
    )
    puffin = args.puffin or (
        Path(found) if (found := shutil.which("puffin")) else None
    )
    puff_codec_oracle = args.puff_codec_oracle

    source_bytes = writer_payload()
    writer_cases = 0
    oracle_decode = 0
    reader_cases = 0
    ranges = 0
    malformed = 0
    aosp_full = 0
    aosp_delta = 0
    bspatch_cases = 0
    puffin_cases = 0
    puff_codec_cases = 0
    with tempfile.TemporaryDirectory(prefix="vort-android-ota-") as temp_text:
        temp = Path(temp_text)
        source = temp / "system.img"
        source.write_bytes(source_bytes)
        raw_payload: bytes | None = None
        for compression in ("raw", "bzip2", "xz", "auto"):
            payload_path = temp / f"vort-{compression}.bin"
            run(
                args.cli,
                "encode-android-ota",
                source,
                payload_path,
                "system",
                compression,
                BLOCK_SIZE,
                2 * BLOCK_SIZE,
            )
            payload = payload_path.read_bytes()
            decoded = decode_reference(payload)
            if decoded != {"system": source_bytes}:
                raise AssertionError(f"reference decode mismatch for {compression}")
            if compression == "raw":
                raw_payload = payload
                expected = build_payload(
                    source_bytes,
                    [
                        (REPLACE, 0, 2, source_bytes[: 2 * BLOCK_SIZE]),
                        (ZERO, 2, 2, b""),
                        (REPLACE, 4, 2, source_bytes[4 * BLOCK_SIZE :]),
                    ],
                )
                if payload != expected:
                    raise AssertionError("raw writer protobuf mismatch")
            summary = run(args.cli, "inspect-android-ota", payload_path).stdout
            if b"format=android-ota" not in summary or b"name=system" not in summary:
                raise AssertionError(f"inspect mismatch for {compression}")
            writer_cases += 1
            if oracle is not None:
                output_dir = temp / f"oracle-{compression}"
                run(
                    oracle,
                    payload_path,
                    "-o",
                    output_dir,
                    "-i",
                    "system",
                    "-P",
                    "-q",
                )
                if (output_dir / "system.img").read_bytes() != source_bytes:
                    raise AssertionError(f"payload_dumper mismatch for {compression}")
                oracle_decode += 1

        reference_data = mixed_payload_data()
        reference_payload = reference_mixed_payload(reference_data)
        reference = temp / "python-reference.bin"
        reference.write_bytes(reference_payload)
        decoded = temp / "reference-decoded.img"
        run(
            args.cli,
            "extract-android-ota",
            reference,
            "system",
            decoded,
            len(reference_data),
        )
        if decoded.read_bytes() != reference_data:
            raise AssertionError("Vort decode mismatch for Python payload")
        reader_cases += 1
        for index, (offset, length) in enumerate(
            (
                (0, 137),
                (BLOCK_SIZE - 37, 2 * BLOCK_SIZE + 91),
                (len(reference_data) - 4096, 4096),
            )
        ):
            output = temp / f"range-{index}.bin"
            run(
                args.cli,
                "extract-android-ota-range",
                reference,
                "system",
                output,
                offset,
                length,
            )
            if output.read_bytes() != reference_data[offset : offset + length]:
                raise AssertionError(f"range mismatch at {offset}")
            ranges += 1

        source_copy_bytes = (
            random.Random(0x534F5552).randbytes(BLOCK_SIZE)
            + (b"SOURCE_COPY old partition " * 200)[:BLOCK_SIZE]
        )
        source_copy_bytes += bytes(2 * BLOCK_SIZE - len(source_copy_bytes))
        source_copy, source_copy_expected = source_copy_payload(source_copy_bytes)
        source_copy_path = temp / "source-copy.bin"
        source_copy_path.write_bytes(source_copy)
        old_image = temp / "vendor-old.img"
        old_image.write_bytes(source_copy_bytes)
        source_copy_output = temp / "vendor-new.img"
        run(
            args.cli,
            "extract-android-ota",
            source_copy_path,
            "vendor",
            source_copy_output,
            len(source_copy_expected),
            old_image,
        )
        if source_copy_output.read_bytes() != source_copy_expected:
            raise AssertionError("SOURCE_COPY decode mismatch")
        reader_cases += 1
        source_copy_range = temp / "source-copy-range.img"
        run(
            args.cli,
            "extract-android-ota-range",
            source_copy_path,
            "vendor",
            source_copy_range,
            BLOCK_SIZE - 31,
            97,
            old_image,
        )
        if source_copy_range.read_bytes() != source_copy_expected[BLOCK_SIZE - 31 : BLOCK_SIZE + 66]:
            raise AssertionError("SOURCE_COPY range mismatch")
        ranges += 1

        source_bsdiff_bytes = random.Random(0x42534449).randbytes(2 * BLOCK_SIZE)
        source_bsdiff, source_bsdiff_expected, source_patch = source_bsdiff_payload(
            source_bsdiff_bytes
        )
        source_bsdiff_path = temp / "source-bsdiff.bin"
        source_bsdiff_path.write_bytes(source_bsdiff)
        bsdiff_old = temp / "product-old.img"
        bsdiff_old.write_bytes(source_bsdiff_bytes)
        bsdiff_output = temp / "product-new.img"
        run(
            args.cli,
            "extract-android-ota",
            source_bsdiff_path,
            "product",
            bsdiff_output,
            len(source_bsdiff_expected),
            bsdiff_old,
        )
        if bsdiff_output.read_bytes() != source_bsdiff_expected:
            raise AssertionError("SOURCE_BSDIFF decode mismatch")
        reader_cases += 1
        bsdiff_range = temp / "source-bsdiff-range.img"
        run(
            args.cli,
            "extract-android-ota-range",
            source_bsdiff_path,
            "product",
            bsdiff_range,
            BLOCK_SIZE - 47,
            131,
            bsdiff_old,
        )
        if bsdiff_range.read_bytes() != source_bsdiff_expected[BLOCK_SIZE - 47 : BLOCK_SIZE + 84]:
            raise AssertionError("SOURCE_BSDIFF range mismatch")
        ranges += 1
        if bspatch is not None:
            patch_path = temp / "independent.bsdiff"
            patch_path.write_bytes(source_patch)
            bspatch_output = temp / "bspatch-product.img"
            run(bspatch, bsdiff_old, bspatch_output, patch_path)
            if bspatch_output.read_bytes() != source_bsdiff_expected:
                raise AssertionError("bspatch oracle mismatch")
            bspatch_cases += 1

        puff_payload, puff_source, puff_expected = puffdiff_payload()
        puff_payload_path = temp / "puffdiff-payload.bin"
        puff_payload_path.write_bytes(puff_payload)
        puff_source_path = temp / "puffin-old.img"
        puff_source_path.write_bytes(puff_source)
        puff_output = temp / "puffin-new.img"
        run(
            args.cli,
            "extract-android-ota",
            puff_payload_path,
            "puffin",
            puff_output,
            len(puff_expected),
            puff_source_path,
        )
        if puff_output.read_bytes() != puff_expected:
            raise AssertionError("PUFFDIFF OTA decode mismatch")
        reader_cases += 1
        puff_range = temp / "puffin-range.img"
        run(
            args.cli,
            "extract-android-ota-range",
            puff_payload_path,
            "puffin",
            puff_range,
            3,
            257,
            puff_source_path,
        )
        if puff_range.read_bytes() != puff_expected[3:260]:
            raise AssertionError("PUFFDIFF range mismatch")
        ranges += 1
        if puffin is not None:
            raw_source = temp / "puffin-raw-source.bin"
            raw_source.write_bytes(puff_source[:17])
            patch_path = temp / "pinned.puffdiff"
            patch_path.write_bytes(PUFFDIFF_FIXTURE)
            raw_output = temp / "puffin-raw-output.bin"
            run(
                puffin,
                "--operation=puffpatch",
                f"--src_file={raw_source}",
                f"--dst_file={raw_output}",
                f"--patch_file={patch_path}",
            )
            if raw_output.read_bytes() != puff_expected[:22]:
                raise AssertionError("AOSP puffpatch mismatch")
            puffin_cases += 1

        if puff_codec_oracle is not None:
            codec_payload = (
                b"Puffin dynamic codec oracle payload with repeated text and bytes.\n"
                * 64
            ) + random.Random(0x50554646).randbytes(70_000)
            codec_cases: list[tuple[str, bytes]] = []
            for name, level, strategy in (
                ("stored", 0, zlib.Z_DEFAULT_STRATEGY),
                ("fixed", 6, zlib.Z_FIXED),
                ("dynamic", 9, zlib.Z_DEFAULT_STRATEGY),
            ):
                compressor = zlib.compressobj(
                    level=level,
                    method=zlib.DEFLATED,
                    wbits=-15,
                    memLevel=8,
                    strategy=strategy,
                )
                codec_cases.append(
                    (name, compressor.compress(codec_payload) + compressor.flush())
                )
            for name, deflate_bytes in codec_cases:
                codec_input = temp / f"codec-{name}.deflate"
                codec_input.write_bytes(deflate_bytes)
                oracle_puff = temp / f"codec-{name}.oracle.puff"
                oracle_restored = temp / f"codec-{name}.oracle.deflate"
                run(
                    puff_codec_oracle,
                    codec_input,
                    oracle_puff,
                    oracle_restored,
                )
                if oracle_restored.read_bytes() != deflate_bytes:
                    raise AssertionError(f"AOSP Puffin {name} huff mismatch")
                vort_puff = temp / f"codec-{name}.vort.puff"
                summary = run(
                    args.cli,
                    "puff-android-deflate",
                    codec_input,
                    vort_puff,
                    0,
                    len(deflate_bytes) * 8,
                ).stdout.decode()
                match = re.search(r"consumed_bits=(\d+)", summary)
                if match is None:
                    raise AssertionError("missing Puffin consumed bit count")
                consumed_bits = int(match.group(1))
                if vort_puff.read_bytes() != oracle_puff.read_bytes():
                    raise AssertionError(f"AOSP Puffin {name} puff mismatch")
                vort_restored = temp / f"codec-{name}.vort.deflate"
                run(
                    args.cli,
                    "huff-android-deflate",
                    vort_puff,
                    vort_restored,
                    0,
                    consumed_bits,
                )
                if vort_restored.read_bytes() != deflate_bytes:
                    raise AssertionError(f"Vort Puffin {name} huff mismatch")
                puff_codec_cases += 1

        short = temp / "short.bin"
        short.write_bytes(MAGIC)
        expect_failure(args.cli, "inspect-android-ota", short, error_name="TruncatedFrame")
        malformed += 1
        corrupt = bytearray(reference_payload)
        corrupt[0] ^= 1
        bad_magic = temp / "bad-magic.bin"
        bad_magic.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-android-ota", bad_magic, error_name="InvalidMagic")
        malformed += 1
        corrupt = bytearray(reference_payload)
        struct.pack_into(">Q", corrupt, 4, 3)
        bad_version = temp / "bad-version.bin"
        bad_version.write_bytes(corrupt)
        expect_failure(
            args.cli, "inspect-android-ota", bad_version, error_name="UnsupportedVersion"
        )
        malformed += 1
        corrupt = bytearray(reference_payload)
        corrupt[-1] ^= 1
        bad_hash = temp / "bad-hash.bin"
        bad_hash.write_bytes(corrupt)
        expect_failure(
            args.cli, "inspect-android-ota", bad_hash, error_name="ChecksumMismatch"
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-android-ota-range",
            reference,
            "system",
            temp / "bad-range.img",
            len(reference_data) - 1,
            2,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        corrupt_source = temp / "vendor-corrupt.img"
        corrupt_source.write_bytes(bytes([source_copy_bytes[0] ^ 1]) + source_copy_bytes[1:])
        expect_failure(
            args.cli,
            "extract-android-ota",
            source_copy_path,
            "vendor",
            temp / "bad-source.img",
            len(source_copy_expected),
            corrupt_source,
            error_name="ChecksumMismatch",
        )
        malformed += 1
        if raw_payload is None:
            raise AssertionError("missing raw payload")
        fuzz_cases = fuzz_mutations(args.cli, temp, raw_payload)

        if args.aosp_update_engine is not None:
            sample_dir = args.aosp_update_engine / "sample_images"
            payload_archive = sample_dir / "sample_payloads.tar.xz"
            image_archive = sample_dir / "sample_images.tar.bz2"
            if not payload_archive.is_file() or not image_archive.is_file():
                raise AssertionError("AOSP sample payload/image archives are missing")
            aosp_payloads = temp / "aosp-payloads"
            aosp_images = temp / "aosp-images"
            aosp_payloads.mkdir()
            aosp_images.mkdir()
            with tarfile.open(payload_archive) as archive:
                archive.extractall(aosp_payloads)
            with tarfile.open(image_archive) as archive:
                archive.extractall(aosp_images)
            full_payload = aosp_payloads / "full_payload.bin"
            delta_payload = aosp_payloads / "delta_payload.bin"
            for partition, expected_name in (
                ("kernel", "disk_ext2_4k.img"),
                ("root", "disk_sqfs_default.img"),
            ):
                expected = (aosp_images / expected_name).read_bytes()
                output = temp / f"aosp-full-{partition}.img"
                run(
                    args.cli,
                    "extract-android-ota",
                    full_payload,
                    partition,
                    output,
                    len(expected),
                )
                if output.read_bytes() != expected:
                    raise AssertionError(f"AOSP full {partition} mismatch")
                aosp_full += 1
            expected_root = (aosp_images / "disk_sqfs_default.img").read_bytes()
            output_root = temp / "aosp-delta-root.img"
            run(
                args.cli,
                "extract-android-ota",
                delta_payload,
                "root",
                output_root,
                len(expected_root),
                aosp_images / "disk_sqfs_empty.img",
            )
            if output_root.read_bytes() != expected_root:
                raise AssertionError("AOSP delta root mismatch")
            aosp_delta += 1
            expected_kernel = (aosp_images / "disk_ext2_4k.img").read_bytes()
            output_kernel = temp / "aosp-delta-kernel.img"
            run(
                args.cli,
                "extract-android-ota",
                delta_payload,
                "kernel",
                output_kernel,
                len(expected_kernel),
                aosp_images / "disk_ext2_4k_empty.img",
            )
            if output_kernel.read_bytes() != expected_kernel:
                raise AssertionError("AOSP BROTLI_BSDIFF kernel mismatch")
            aosp_delta += 1
            kernel_range = temp / "aosp-delta-kernel-range.img"
            run(
                args.cli,
                "extract-android-ota-range",
                delta_payload,
                "kernel",
                kernel_range,
                3897,
                8192,
                aosp_images / "disk_ext2_4k_empty.img",
            )
            if kernel_range.read_bytes() != expected_kernel[3897 : 3897 + 8192]:
                raise AssertionError("AOSP BROTLI_BSDIFF range mismatch")
            ranges += 1

    print(
        f"writer={writer_cases} reader={reader_cases} ranges={ranges} "
        f"malformed={malformed} fuzz={fuzz_cases} "
        f"payload_dumper={oracle is not None} oracle_decode={oracle_decode} "
        f"bspatch={bspatch is not None} bspatch_cases={bspatch_cases} "
        f"puffin={puffin is not None} puffin_cases={puffin_cases} "
        f"puff_codec={puff_codec_oracle is not None} "
        f"puff_codec_cases={puff_codec_cases} "
        f"aosp={args.aosp_update_engine is not None} aosp_full={aosp_full} "
        f"aosp_delta={aosp_delta}"
    )


if __name__ == "__main__":
    main()
