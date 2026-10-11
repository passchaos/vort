#!/usr/bin/env python3
import argparse
import base64
import bz2
import hashlib
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


WIA_CHUNK = 2 * 1024 * 1024
RVZ_CHUNK = 128 * 1024
PARTITION_LOGICAL_SIZE = 65 * 0x8000
FIXTURE_DIR = Path(__file__).resolve().parents[2] / "src" / "wia" / "testdata"

PARTITION_CASES = (
    (
        "wia-bzip2",
        "python-partition-bzip2.wia.bz2.b64",
        "wia",
        "bzip2",
        WIA_CHUNK,
        "1380f2ef05967e11ef608b249b7211f3952880101e9f1698c60d1b71ae3c7c27",
        "7ed1e69506a89dc1455c8b4dc50d79469fe1b921d6b73beb070549ea55f6bc54",
    ),
    (
        "rvz-smallchunks",
        "python-partition-smallchunks.rvz.bz2.b64",
        "rvz",
        "none",
        RVZ_CHUNK,
        "d6c151201f0ca55ad24ff454742848c8b6b0909b590f4f357f7f3d3e1f8010c6",
        "5366ef2365a409b77a272f5932ee488dba52e03f10cf39f92e13b50bd8e44ef7",
    ),
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


def load_partition_fixture(name: str, expected_digest: str) -> bytes:
    image = bz2.decompress(base64.b64decode((FIXTURE_DIR / name).read_bytes()))
    if hashlib.sha256(image).hexdigest() != expected_digest:
        raise AssertionError(f"partition fixture digest mismatch: {name}")
    return image


def discoverable_wii_iso(encrypted_iso: bytes) -> bytes:
    partition_offset = 0x50000
    data_relative = 0x20000
    data_offset = partition_offset + data_relative
    encrypted_group = encrypted_iso[0x8000:]
    if len(encrypted_group) != 2 * 1024 * 1024:
        raise AssertionError("unexpected synthetic partition size")
    output = bytearray(data_offset + len(encrypted_group))
    output[:0x80] = encrypted_iso[:0x80]
    struct.pack_into(">I", output, 0x18, 0x5D1C9EA3)
    output[0x60:0x62] = b"\0\0"
    struct.pack_into(">II", output, 0x40000, 1, 0x40020 // 4)
    struct.pack_into(">II", output, 0x40020, partition_offset // 4, 0)
    struct.pack_into(">I", output, partition_offset, 0x00010001)
    output[partition_offset + 0x1BF : partition_offset + 0x1CF] = bytes.fromhex(
        "5f5e6aa18746d1bbcec4c705fe96583e"
    )
    output[partition_offset + 0x1DC : partition_offset + 0x1E4] = bytes.fromhex(
        "0001000057494931"
    )
    output[partition_offset + 0x1F1] = 1
    struct.pack_into(
        ">II",
        output,
        partition_offset + 0x2B8,
        data_relative // 4,
        len(encrypted_group) // 4,
    )
    output[data_offset:] = encrypted_group
    return bytes(output)


def payload() -> bytes:
    rng = random.Random(0x574941)
    repetitive = (b"Dolphin WIA RVZ differential data\n" * 5000)[:RVZ_CHUNK]
    random_block = rng.randbytes(RVZ_CHUNK)
    zeros = bytes(RVZ_CHUNK)
    structured = bytes((index * 17 + index // 31) & 0xFF for index in range(RVZ_CHUNK))
    return repetitive + random_block + zeros + structured + b"partial WIA RVZ tail"


def rvz_junk_payload(size: int) -> bytes:
    seed = bytes((index * 7) & 0xFF for index in range(68))
    state = [
        int.from_bytes(seed[index * 4 : index * 4 + 4], "big")
        for index in range(17)
    ] + [0] * (521 - 17)
    for index in range(17, 521):
        state[index] = (
            ((state[index - 17] << 23) & 0xFFFFFFFF)
            ^ (state[index - 16] >> 9)
            ^ state[index - 1]
        )
    for index, word in enumerate(state):
        transformed = (word & 0xFF00FFFF) | ((word >> 2) & 0x00FF0000)
        state[index] = int.from_bytes(transformed.to_bytes(4, "little"), "big")

    def advance() -> None:
        for index in range(32):
            state[index] ^= state[index + 489]
        for index in range(32, 521):
            state[index] ^= state[index - 32]

    for _ in range(4):
        advance()
    output = bytearray()
    while len(output) < size:
        output.extend(b"".join(word.to_bytes(4, "little") for word in state))
        advance()
    return bytes(output[:size])


def dolphin_convert(
    executable: Path,
    source: Path,
    output: Path,
    output_format: str,
    compression: str | None = None,
    block_size: int | None = None,
    level: int = 6,
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
    if compression is not None:
        command.extend(("-c", compression))
        if compression != "none":
            command.extend(("-l", level))
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
    malformed = 0
    partition_cases = 0
    partition_encode = 0
    auto_partition_encode = 0
    with tempfile.TemporaryDirectory(prefix="vort-wia-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.iso"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        cases = (
            ("wia", "none", WIA_CHUNK, 0),
            ("wia", "purge", WIA_CHUNK, 0),
            ("wia", "bzip2", WIA_CHUNK, 6),
            ("wia", "lzma", WIA_CHUNK, 6),
            ("wia", "lzma2", WIA_CHUNK, 6),
            ("rvz", "none", RVZ_CHUNK, 0),
            ("rvz", "bzip2", RVZ_CHUNK, 6),
            ("rvz", "lzma", RVZ_CHUNK, 6),
            ("rvz", "lzma2", RVZ_CHUNK, 6),
            ("rvz", "zstd", RVZ_CHUNK, 5),
        )
        for container, compression, chunk_size, level in cases:
            image = temp / f"vort-{container}-{compression}.{container}"
            output = temp / f"vort-{container}-{compression}.iso"
            ranged = temp / f"vort-{container}-{compression}.range"
            run(
                args.cli,
                f"encode-{container}",
                source,
                image,
                compression,
                chunk_size,
                level,
            )
            summary = run(args.cli, f"inspect-{container}", image).stdout
            if (
                f"format={container}".encode() not in summary
                or f"compression={compression}".encode() not in summary
            ):
                raise AssertionError(f"Vort inspect mismatch for {container}/{compression}")
            run(args.cli, f"decode-{container}", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort round trip mismatch for {container}/{compression}")
            range_offset = RVZ_CHUNK - 37
            range_length = 2 * RVZ_CHUNK + 91
            run(
                args.cli,
                f"decode-{container}-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort range mismatch for {container}/{compression}")
            images[f"{container}-{compression}"] = image
            self_cases += 1

            if dolphin_tool is not None:
                external = temp / f"vort-{container}-{compression}.dolphin.iso"
                dolphin_convert(dolphin_tool, image, external, "iso")
                if external.read_bytes() != plain:
                    raise AssertionError(
                        f"DolphinTool decode mismatch for {container}/{compression}"
                    )
                external_encode += 1

        valid = images["rvz-zstd"]
        expect_failure(
            args.cli,
            "decode-rvz",
            valid,
            temp / "limited.iso",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-rvz-range",
            valid,
            temp / "bad-range.iso",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1
        short = temp / "short.rvz"
        short.write_bytes(valid.read_bytes()[:72])
        expect_failure(args.cli, "inspect-rvz", short, error_name="SizeMismatch")
        malformed += 1
        bad_header_bytes = bytearray(valid.read_bytes())
        bad_header_bytes[52] ^= 1
        bad_header = temp / "bad-header.rvz"
        bad_header.write_bytes(bad_header_bytes)
        expect_failure(args.cli, "inspect-rvz", bad_header, error_name="ChecksumMismatch")
        malformed += 1

        for (
            label,
            fixture_name,
            container,
            compression,
            chunk_size,
            image_digest,
            output_digest,
        ) in PARTITION_CASES:
            image = temp / f"partition-{label}.{container}"
            output = temp / f"partition-{label}.vort.iso"
            ranged = temp / f"partition-{label}.range"
            image.write_bytes(load_partition_fixture(fixture_name, image_digest))
            summary = run(args.cli, f"inspect-{container}", image).stdout
            if (
                f"format={container}".encode() not in summary
                or f"compression={compression}".encode() not in summary
                or f"chunk_bytes={chunk_size}".encode() not in summary
                or b"partitions=1" not in summary
            ):
                raise AssertionError(f"partition inspect mismatch for {label}")
            run(
                args.cli,
                f"decode-{container}",
                image,
                output,
                PARTITION_LOGICAL_SIZE,
            )
            decoded = output.read_bytes()
            if hashlib.sha256(decoded).hexdigest() != output_digest:
                raise AssertionError(f"partition decode mismatch for {label}")

            # Sector 12 in the RVZ fixture carries an exception in subchunk 3.
            range_offset = 13 * 0x8000 - 37
            range_length = 2 * 0x8000 + 91
            run(
                args.cli,
                f"decode-{container}-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != decoded[range_offset : range_offset + range_length]:
                raise AssertionError(f"partition range mismatch for {label}")
            partition_cases += 1

            if dolphin_tool is not None:
                external = temp / f"partition-{label}.dolphin.iso"
                dolphin_convert(dolphin_tool, image, external, "iso")
                if external.read_bytes() != decoded:
                    raise AssertionError(
                        f"DolphinTool partition decode mismatch for {label}"
                    )
                external_decode += 1

            if label == "rvz-smallchunks":
                key_hex = "000102030405060708090a0b0c0d0e0f"
                for (
                    writer_container,
                    writer_compression,
                    writer_chunk_size,
                    writer_level,
                ) in cases:
                    written = temp / (
                        f"partition-vort-{writer_container}-"
                        f"{writer_compression}.{writer_container}"
                    )
                    roundtrip = temp / (
                        f"partition-vort-{writer_container}-"
                        f"{writer_compression}.iso"
                    )
                    run(
                        args.cli,
                        f"encode-{writer_container}-partition",
                        output,
                        written,
                        writer_compression,
                        0x8000,
                        2 * 1024 * 1024,
                        key_hex,
                        writer_chunk_size,
                        writer_level,
                    )
                    run(
                        args.cli,
                        f"decode-{writer_container}",
                        written,
                        roundtrip,
                        PARTITION_LOGICAL_SIZE,
                    )
                    if roundtrip.read_bytes() != decoded:
                        raise AssertionError(
                            "partition writer round trip mismatch for "
                            f"{writer_container}/{writer_compression}"
                        )
                    partition_encode += 1

                    if dolphin_tool is not None:
                        external = temp / (
                            f"partition-vort-{writer_container}-"
                            f"{writer_compression}.dolphin.iso"
                        )
                        dolphin_convert(dolphin_tool, written, external, "iso")
                        if external.read_bytes() != decoded:
                            raise AssertionError(
                                "DolphinTool partition writer mismatch for "
                                f"{writer_container}/{writer_compression}"
                            )
                        external_encode += 1

                discovered_source = temp / "discoverable-wii.iso"
                discovered_plain = discoverable_wii_iso(decoded)
                discovered_source.write_bytes(discovered_plain)
                common_key = "102132435465768798a9bacbdcedfe0f"
                for (
                    writer_container,
                    writer_compression,
                    writer_chunk_size,
                    writer_level,
                ) in (
                    ("wia", "bzip2", WIA_CHUNK, 6),
                    ("rvz", "zstd", RVZ_CHUNK, 5),
                ):
                    written = temp / f"auto-{writer_container}.{writer_container}"
                    roundtrip = temp / f"auto-{writer_container}.vort.iso"
                    run(
                        args.cli,
                        f"encode-{writer_container}-disc",
                        discovered_source,
                        written,
                        writer_compression,
                        1,
                        common_key,
                        writer_chunk_size,
                        writer_level,
                    )
                    run(
                        args.cli,
                        f"decode-{writer_container}",
                        written,
                        roundtrip,
                        len(discovered_plain),
                    )
                    if roundtrip.read_bytes() != discovered_plain:
                        raise AssertionError(
                            f"automatic partition mismatch for {writer_container}"
                        )
                    auto_partition_encode += 1
                    if dolphin_tool is not None:
                        external = temp / f"auto-{writer_container}.dolphin.iso"
                        dolphin_convert(dolphin_tool, written, external, "iso")
                        if external.read_bytes() != discovered_plain:
                            raise AssertionError(
                                "DolphinTool automatic partition mismatch for "
                                f"{writer_container}"
                            )
                        external_encode += 1

        if dolphin_tool is not None:
            dolphin_plain = bytes(
                (index * 29 + index // 31) & 0xFF
                for index in range(65536 + 137)
            )
            dolphin_source = temp / "dolphin-source.iso"
            dolphin_source.write_bytes(dolphin_plain)
            for container, codecs, chunk_size in (
                ("wia", ("none", "bzip2", "lzma", "lzma2"), WIA_CHUNK),
                ("rvz", ("zstd",), RVZ_CHUNK),
            ):
                for compression in codecs:
                    image = temp / f"dolphin-{container}-{compression}.{container}"
                    output = temp / f"dolphin-{container}-{compression}.vort.iso"
                    dolphin_convert(
                        dolphin_tool,
                        dolphin_source,
                        image,
                        container,
                        compression,
                        chunk_size,
                        5 if compression == "zstd" else 6,
                    )
                    run(
                        args.cli,
                        f"decode-{container}",
                        image,
                        output,
                        len(dolphin_plain),
                    )
                    if output.read_bytes() != dolphin_plain:
                        raise AssertionError(
                            f"Vort decode mismatch for DolphinTool {container}/{compression}"
                        )
                    external_decode += 1

            packed_plain = rvz_junk_payload(2 * RVZ_CHUNK)
            packed_source = temp / "dolphin-packed-source.iso"
            packed_image = temp / "dolphin-packed.rvz"
            packed_output = temp / "dolphin-packed.vort.iso"
            packed_source.write_bytes(packed_plain)
            dolphin_convert(
                dolphin_tool,
                packed_source,
                packed_image,
                "rvz",
                "zstd",
                RVZ_CHUNK,
                5,
            )
            packed_summary = run(args.cli, "inspect-rvz", packed_image).stdout
            if b"packed=1" not in packed_summary:
                raise AssertionError("DolphinTool did not emit RVZ packing fixture")
            run(
                args.cli,
                "decode-rvz",
                packed_image,
                packed_output,
                len(packed_plain),
            )
            if packed_output.read_bytes() != packed_plain:
                raise AssertionError("Vort decode mismatch for DolphinTool packed RVZ")
            external_decode += 1

    print(
        f"self={self_cases} dolphin_tool={dolphin_tool is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed} partitions={partition_cases} "
        f"partition_encode={partition_encode} "
        f"auto_partition_encode={auto_partition_encode} "
        f"rvz_packing_decode=True rvz_packing_write=False"
    )


if __name__ == "__main__":
    main()
