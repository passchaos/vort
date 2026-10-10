#!/usr/bin/env python3
import argparse
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MAGIC = bytes((0x89, ord("L"), ord("Z"), ord("O"), 0, 13, 10, 0x1A, 10))
F_EXTRA = 0x40
F_FILTER = 0x800
F_ADLER_D = 0x1
F_ADLER_C = 0x2
F_CRC_D = 0x100
F_CRC_C = 0x200


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def read_u32(data: bytes, position: int) -> tuple[int, int]:
    return struct.unpack(">I", data[position : position + 4])[0], position + 4


def scan_offsets(data: bytes) -> list[int]:
    position = 0
    offsets: list[int] = []
    while position < len(data):
        if data[position : position + 9] != MAGIC:
            raise AssertionError("invalid LZOP magic")
        position += 9
        version = struct.unpack(">H", data[position : position + 2])[0]
        position += 4
        if version >= 0x940:
            position += 2
        position += 1
        if version >= 0x940:
            position += 1
        flags, position = read_u32(data, position)
        if flags & F_FILTER:
            position += 4
        position += 8
        if version >= 0x940:
            position += 4
        name_len = data[position]
        position += 1 + name_len + 4
        if flags & F_EXTRA:
            extra_len, position = read_u32(data, position)
            position += extra_len + 4
        while True:
            block_offset = position
            uncompressed, position = read_u32(data, position)
            if uncompressed == 0:
                break
            compressed, position = read_u32(data, position)
            offsets.append(block_offset)
            checksums = int(bool(flags & F_ADLER_D)) + int(bool(flags & F_CRC_D))
            if compressed < uncompressed:
                checksums += int(bool(flags & F_ADLER_C)) + int(bool(flags & F_CRC_C))
            position += checksums * 4 + compressed
    return offsets


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lzop", type=Path)
    args = parser.parse_args()
    lzop_tool = args.lzop or (Path(found) if (found := shutil.which("lzop")) else None)
    payload = bytes((index * 31 + index // 23) & 0xFF for index in range(200_000))
    self_cases = 0
    external_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-hadoop-lzo-index-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)
        archive = temp / "payload.lzo"
        run(args.cli, "encode-lzop-file", source, archive, 32768, "crc32", "compressed-checksum")
        first_index = temp / "payload.lzo.index"
        second_index = temp / "payload-repeat.lzo.index"
        run(args.cli, "create-hadoop-lzo-index", archive, first_index)
        run(args.cli, "create-hadoop-lzo-index", archive, second_index)
        if first_index.read_bytes() != second_index.read_bytes():
            raise AssertionError("Vort Hadoop LZO index is not deterministic")
        offsets = scan_offsets(archive.read_bytes())
        expected_index = b"".join(struct.pack(">Q", offset) for offset in offsets)
        if first_index.read_bytes() != expected_index:
            raise AssertionError("Vort Hadoop LZO offsets differ from reference scanner")
        listing = run(args.cli, "inspect-hadoop-lzo-index", archive, first_index).stdout
        if f"lzo_blocks={len(offsets)}" not in listing:
            raise AssertionError(f"Vort Hadoop LZO metadata mismatch: {listing}")
        decoded = temp / "range.out"
        run(
            args.cli,
            "extract-hadoop-lzo-blocks",
            archive,
            first_index,
            decoded,
            1,
            2,
            65536,
        )
        if decoded.read_bytes() != payload[32768:98304]:
            raise AssertionError("Vort Hadoop LZO indexed range mismatch")
        self_cases += 1

        duplicate = bytearray(first_index.read_bytes())
        if len(duplicate) >= 16:
            duplicate[8:16] = duplicate[0:8]
            duplicate_path = temp / "duplicate.index"
            duplicate_path.write_bytes(duplicate)
            failed = run(
                args.cli,
                "inspect-hadoop-lzo-index",
                archive,
                duplicate_path,
                check=False,
            )
            if failed.returncode == 0 or "InvalidHadoopLzoIndex" not in failed.stderr:
                raise AssertionError("Vort accepted duplicate Hadoop LZO offsets")
            malformed += 1
        truncated_path = temp / "truncated.index"
        truncated_path.write_bytes(first_index.read_bytes()[:-1])
        if run(
            args.cli,
            "inspect-hadoop-lzo-index",
            archive,
            truncated_path,
            check=False,
        ).returncode == 0:
            raise AssertionError("Vort accepted truncated Hadoop LZO index")
        malformed += 1

        if lzop_tool is not None:
            reference = temp / "reference.lzo"
            with reference.open("wb") as output:
                subprocess.run(
                    [str(lzop_tool), "-3", "-c", str(source)],
                    check=True,
                    stdout=output,
                    stderr=subprocess.PIPE,
                )
            reference_index = temp / "reference.lzo.index"
            run(args.cli, "create-hadoop-lzo-index", reference, reference_index)
            expected = b"".join(
                struct.pack(">Q", offset) for offset in scan_offsets(reference.read_bytes())
            )
            if reference_index.read_bytes() != expected:
                raise AssertionError("Vort rejected lzop block offsets")
            external_cases += 1

    print(
        f"self_cases={self_cases} lzop={lzop_tool is not None} "
        f"external_cases={external_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
