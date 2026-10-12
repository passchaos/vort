#!/usr/bin/env python3
import argparse
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MAGIC = b"WII\x01DISC"
HEADER_SIZE = 56
DATA_BLOCK = 256 * 1024


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
    block = DATA_BLOCK
    data = bytearray(3 * block + 137)
    for index in range(block):
        data[index] = (index * 17 + index // 31) & 0xFF
    repetitive = b"WDF independent differential\n"
    for index in range(2 * block, 3 * block):
        data[index] = repetitive[(index - 2 * block) % len(repetitive)]
    for index in range(3 * block, len(data)):
        data[index] = (index * 29 + 3) & 0xFF
    struct.pack_into(">I", data, 0x18, 0x5D1C9EA3)
    data[0:6] = b"RZDE01"
    data[0x60:0x62] = b"\0\0"
    return bytes(data)


def chunks_for(source: bytes, sparse: bool, min_hole: int = 28) -> list[tuple[int, int]]:
    padded = (len(source) + 3) // 4 * 4
    if not sparse:
        return [(0, padded)] if padded else [(len(source), 0)]
    chunks: list[tuple[int, int]] = []
    chunk_start = 0
    position = 0
    min_hole = max(4, (min_hole + 3) // 4 * 4)

    def zero_word(offset: int) -> bool:
        return not any(source[offset : min(len(source), offset + 4)])

    while position < padded:
        if not zero_word(position):
            position += 4
            continue
        zero_start = position
        while position < padded and zero_word(position):
            position += 4
        if position - zero_start >= min_hole:
            if zero_start > chunk_start:
                chunks.append((chunk_start, zero_start - chunk_start))
            chunk_start = position
    if chunk_start < padded:
        chunks.append((chunk_start, padded - chunk_start))
    return chunks or [(len(source), 0)]


def encode_reference(source: bytes, version: int, sparse: bool) -> bytes:
    chunks = chunks_for(source, sparse)
    chunk_size = 28 if version == 1 else 24
    data_size = sum(size for _, size in chunks)
    table_offset = HEADER_SIZE + data_size
    output = bytearray(table_offset + len(MAGIC) + len(chunks) * chunk_size)
    output[:8] = MAGIC
    struct.pack_into(">IIIIQQIIQ", output, 8, version, HEADER_SIZE, 4, version,
                     len(source), data_size, 0, len(chunks), table_offset)
    data_offset = HEADER_SIZE
    for file_pos, size in chunks:
        actual = source[file_pos : min(len(source), file_pos + size)]
        output[data_offset : data_offset + len(actual)] = actual
        data_offset += size
    output[table_offset : table_offset + 8] = MAGIC
    for index, (file_pos, size) in enumerate(chunks):
        entry = table_offset + 8 + index * chunk_size
        physical = HEADER_SIZE + sum(chunk_size_ for _, chunk_size_ in chunks[:index])
        if version == 1:
            struct.pack_into(">IQQQ", output, entry, 0, file_pos, physical, size)
        else:
            struct.pack_into(">QQQ", output, entry, file_pos, physical, size)
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wdf", type=Path)
    parser.add_argument("--wit", type=Path)
    args = parser.parse_args()
    wdf_tool = args.wdf or (
        Path(found) if (found := shutil.which("wdf")) else None
    )
    wit_tool = args.wit or (
        Path(found) if (found := shutil.which("wit")) else None
    )

    source_bytes = payload()
    writer_cases = 0
    oracle_decode = 0
    oracle_encode = 0
    reader_ranges = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-wdf-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.iso"
        source.write_bytes(source_bytes)
        for version in (1, 2):
            for mode in ("sparse", "full"):
                image = temp / f"vort-v{version}-{mode}.wdf"
                run(args.cli, "encode-wdf", source, image, f"wdf{version}", mode, 28)
                expected = encode_reference(source_bytes, version, mode == "sparse")
                if image.read_bytes() != expected:
                    raise AssertionError(f"WDF{version} writer mismatch for {mode}")
                summary = run(args.cli, "inspect-wdf", image).stdout
                if f"version={version}".encode() not in summary:
                    raise AssertionError(f"WDF{version} inspect mismatch")
                writer_cases += 1
                if wdf_tool is not None:
                    unpacked = run(wdf_tool, "+CAT", image).stdout
                    if (
                        unpacked[: len(source_bytes)] != source_bytes
                        or len(unpacked) - len(source_bytes) > 3
                        or any(unpacked[len(source_bytes) :])
                    ):
                        raise AssertionError(
                            f"wdf oracle decode mismatch for WDF{version}: "
                            f"actual={len(unpacked)} expected={len(source_bytes)} "
                        )
                    oracle_decode += 1

        reference_bytes = encode_reference(source_bytes, 2, True)
        reference = temp / "python-reference.wdf"
        reference.write_bytes(reference_bytes)
        ranges = (
            (0, 4096),
            (DATA_BLOCK - 37, 2 * DATA_BLOCK + 91),
            (len(source_bytes) - 100, 100),
        )
        for index, (offset, length) in enumerate(ranges):
            output = temp / f"range-{index}.bin"
            run(args.cli, "decode-wdf-range", reference, output, offset, length)
            if output.read_bytes() != source_bytes[offset : offset + length]:
                raise AssertionError(f"WDF range mismatch at {offset}")
            reader_ranges += 1

        if wit_tool is not None:
            for version in (1, 2):
                output = temp / f"wit-v{version}.wdf"
                result = run(
                    wit_tool,
                    "COPY",
                    "--raw",
                    f"--wdf{version}",
                    "--dest",
                    output,
                    "--overwrite",
                    source,
                    check=False,
                )
                if result.returncode != 0:
                    raise AssertionError(
                        "wit WDF writer failed: "
                        + result.stderr.decode(errors="replace")
                    )
                decoded = temp / f"wit-v{version}.decoded"
                run(args.cli, "decode-wdf", output, decoded, len(source_bytes))
                if decoded.read_bytes() != source_bytes:
                    raise AssertionError(f"Vort decode mismatch for wit WDF{version}")
                oracle_encode += 1

        short = temp / "short.wdf"
        short.write_bytes(MAGIC)
        expect_failure(args.cli, "inspect-wdf", short, error_name="TruncatedFrame")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        corrupt[0] ^= 1
        bad_magic = temp / "bad-magic.wdf"
        bad_magic.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-wdf", bad_magic, error_name="InvalidMagic")
        malformed += 1
        corrupt = bytearray(reference_bytes)
        struct.pack_into(">I", corrupt, 8, 3)
        bad_version = temp / "bad-version.wdf"
        bad_version.write_bytes(corrupt)
        expect_failure(args.cli, "inspect-wdf", bad_version, error_name="UnsupportedVersion")
        malformed += 1
        expect_failure(
            args.cli,
            "decode-wdf-range",
            reference,
            temp / "bad-range.bin",
            len(source_bytes) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

    print(
        f"writer={writer_cases} reader_ranges={reader_ranges} malformed={malformed} "
        f"wdf_tool={wdf_tool is not None} oracle_decode={oracle_decode} "
        f"wit_tool={wit_tool is not None} oracle_encode={oracle_encode}"
    )


if __name__ == "__main__":
    main()
