#!/usr/bin/env python3
import argparse
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


MAGIC_END = b"bvx$"
MAGIC_RAW = b"bvx-"
MAGIC_V1 = b"bvx1"
MAGIC_V2 = b"bvx2"
MAGIC_LZVN = b"bvxn"
V1_HEADER_SIZE = 772
V2_FIXED_SIZE = 32


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def scan(data: bytes) -> list[tuple[str, int, int, int]]:
    position = 0
    blocks: list[tuple[str, int, int, int]] = []
    while True:
        if len(data) - position < 4:
            raise AssertionError("truncated LZFSE magic")
        magic = data[position : position + 4]
        if magic == MAGIC_END:
            position += 4
            if position != len(data):
                raise AssertionError("trailing LZFSE data")
            return blocks
        start = position
        if magic == MAGIC_RAW:
            if len(data) - position < 8:
                raise AssertionError("truncated raw header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            position += 8 + raw_size
            kind = "raw"
        elif magic == MAGIC_LZVN:
            if len(data) - position < 12:
                raise AssertionError("truncated LZVN header")
            raw_size, payload_size = struct.unpack_from("<II", data, position + 4)
            position += 12 + payload_size
            kind = "lzvn"
        elif magic == MAGIC_V1:
            if len(data) - position < V1_HEADER_SIZE:
                raise AssertionError("truncated V1 header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            literal_size, lmd_size = struct.unpack_from("<II", data, position + 20)
            position += V1_HEADER_SIZE + literal_size + lmd_size
            kind = "v1"
        elif magic == MAGIC_V2:
            if len(data) - position < V2_FIXED_SIZE:
                raise AssertionError("truncated V2 header")
            raw_size = struct.unpack_from("<I", data, position + 4)[0]
            packed0, packed1, packed2 = struct.unpack_from("<QQQ", data, position + 8)
            header_size = packed2 & 0xFFFF_FFFF
            literal_size = (packed0 >> 20) & 0xF_FFFF
            lmd_size = (packed1 >> 40) & 0xF_FFFF
            if header_size < V2_FIXED_SIZE:
                raise AssertionError("invalid V2 header size")
            position += header_size + literal_size + lmd_size
            kind = "v2"
        else:
            raise AssertionError(f"invalid LZFSE magic {magic!r}")
        if position > len(data):
            raise AssertionError(f"truncated {kind} payload")
        blocks.append((kind, start, position, raw_size))


def decode_frequencies(encoded: bytes) -> list[int]:
    bit_value = int.from_bytes(encoded, "little")
    bit_offset = 0
    bit_counts = [2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14] * 2
    values = [
        0,
        2,
        1,
        4,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        5,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        6,
        0,
        3,
        1,
        0,
        0,
        2,
        1,
        7,
        0,
        3,
        1,
        0,
    ]
    frequencies: list[int] = []
    for _ in range(360):
        bits = (bit_value >> bit_offset) & 0x3FFF
        bit_count = bit_counts[bits & 31]
        if bit_count == 8:
            frequency = 8 + ((bits >> 4) & 15)
        elif bit_count == 14:
            frequency = 24 + ((bits >> 4) & 1023)
        else:
            frequency = values[bits & 31]
        frequencies.append(frequency)
        bit_offset += bit_count
    if (bit_offset + 7) // 8 != len(encoded):
        raise AssertionError("V2 frequency byte count mismatch")
    return frequencies


def v2_block_to_v1(data: bytes, start: int, end: int) -> bytes:
    raw_size = struct.unpack_from("<I", data, start + 4)[0]
    packed0, packed1, packed2 = struct.unpack_from("<QQQ", data, start + 8)
    header_size = packed2 & 0xFFFF_FFFF
    literal_count = packed0 & 0xF_FFFF
    literal_size = (packed0 >> 20) & 0xF_FFFF
    match_count = (packed0 >> 40) & 0xF_FFFF
    literal_bits = ((packed0 >> 60) & 7) - 7
    literal_states = [(packed1 >> shift) & 1023 for shift in (0, 10, 20, 30)]
    lmd_size = (packed1 >> 40) & 0xF_FFFF
    lmd_bits = ((packed1 >> 60) & 7) - 7
    l_state = (packed2 >> 32) & 1023
    m_state = (packed2 >> 42) & 1023
    d_state = (packed2 >> 52) & 1023
    frequencies = decode_frequencies(data[start + V2_FIXED_SIZE : start + header_size])
    header = bytearray(V1_HEADER_SIZE)
    struct.pack_into(
        "<7Ii4Hi3H",
        header,
        0,
        0x31787662,
        raw_size,
        literal_size + lmd_size,
        literal_count,
        match_count,
        literal_size,
        lmd_size,
        literal_bits,
        *literal_states,
        lmd_bits,
        l_state,
        m_state,
        d_state,
    )
    for index, frequency in enumerate(frequencies):
        struct.pack_into("<H", header, 50 + index * 2, frequency)
    return bytes(header) + data[start + header_size : end]


def convert_v2_to_v1(data: bytes) -> tuple[bytes, int]:
    converted = bytearray()
    converted_count = 0
    for kind, start, end, _ in scan(data):
        if kind == "v2":
            converted.extend(v2_block_to_v1(data, start, end))
            converted_count += 1
        else:
            converted.extend(data[start:end])
    converted.extend(MAGIC_END)
    return bytes(converted), converted_count


def expect_failure(*args: object, error_name: str | None = None) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name is not None and error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name} diagnostic: {result.stderr.decode(errors='replace')}"
        )


def payloads() -> list[tuple[str, bytes]]:
    state = 0x1234_5678
    random_data = bytearray()
    for _ in range(50_000):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        random_data.append(state & 0xFF)
    structured = bytearray()
    for index in range(12_000):
        structured.extend(f'{{"id":{index},"kind":"lzfse","bucket":{index % 31}}}\n'.encode())
    return [
        ("empty", b""),
        ("tiny", b"abc"),
        ("lzvn", b"Apple LZVN payload abcabcabc\n" * 128),
        ("structured", bytes(structured)),
        ("random", bytes(random_data)),
        ("zeros", bytes(100_000)),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lzfse", type=Path)
    args = parser.parse_args()
    reference = args.lzfse or (Path(found) if (found := shutil.which("lzfse")) else None)
    self_cases = 0
    external_encode = 0
    external_decode = 0
    v1_cases = 0
    malformed = 0
    kind_counts = {"raw": 0, "lzvn": 0, "v1": 0, "v2": 0}

    with tempfile.TemporaryDirectory(prefix="vort-lzfse-") as temp_text:
        temp = Path(temp_text)
        valid_for_malformed: Path | None = None
        v2_for_malformed: Path | None = None
        for name, payload in payloads():
            source = temp / f"{name}.bin"
            source.write_bytes(payload)
            encoded = temp / f"{name}.vort.lzfse"
            repeated = temp / f"{name}.repeat.lzfse"
            decoded = temp / f"{name}.vort.out"
            run(args.cli, "encode-lzfse-file", source, encoded, 32768, "lzvn")
            run(args.cli, "encode-lzfse-file", source, repeated, 32768, "lzvn")
            if encoded.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic Vort LZFSE output for {name}")
            blocks = scan(encoded.read_bytes())
            listing = run(args.cli, "inspect-lzfse-file", encoded, len(payload)).stdout
            if f"decoded_bytes={len(payload)}".encode() not in listing:
                raise AssertionError(f"Vort LZFSE metadata mismatch for {name}: {listing!r}")
            run(args.cli, "decode-lzfse-file", encoded, decoded, len(payload))
            if decoded.read_bytes() != payload:
                raise AssertionError(f"Vort LZFSE round trip mismatch for {name}")
            self_cases += 1
            if payload and valid_for_malformed is None:
                valid_for_malformed = encoded

            if reference is not None and payload:
                reference_decoded = temp / f"{name}.reference.out"
                run(reference, "-decode", "-i", encoded, "-o", reference_decoded)
                if reference_decoded.read_bytes() != payload:
                    raise AssertionError(f"Apple decoder rejected Vort output for {name}")
                external_decode += 1

                reference_encoded = temp / f"{name}.reference.lzfse"
                run(reference, "-encode", "-i", source, "-o", reference_encoded)
                reference_blocks = scan(reference_encoded.read_bytes())
                for kind, _, _, _ in reference_blocks:
                    kind_counts[kind] += 1
                reference_output = temp / f"{name}.reference-vort.out"
                run(
                    args.cli,
                    "decode-lzfse-file",
                    reference_encoded,
                    reference_output,
                    len(payload),
                )
                if reference_output.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected Apple output for {name}")
                external_encode += 1

                converted, converted_count = convert_v2_to_v1(reference_encoded.read_bytes())
                if converted_count:
                    converted_path = temp / f"{name}.v1.lzfse"
                    converted_path.write_bytes(converted)
                    converted_output = temp / f"{name}.v1.out"
                    run(
                        args.cli,
                        "decode-lzfse-file",
                        converted_path,
                        converted_output,
                        len(payload),
                    )
                    if converted_output.read_bytes() != payload:
                        raise AssertionError(f"Vort rejected V1 conversion for {name}")
                    apple_v1_output = temp / f"{name}.v1-apple.out"
                    run(reference, "-decode", "-i", converted_path, "-o", apple_v1_output)
                    if apple_v1_output.read_bytes() != payload:
                        raise AssertionError(f"Apple rejected V1 conversion for {name}")
                    v1_cases += converted_count
                    if v2_for_malformed is None:
                        v2_for_malformed = reference_encoded

        assert valid_for_malformed is not None
        expect_failure(
            args.cli,
            "decode-lzfse-file",
            valid_for_malformed,
            temp / "limited.out",
            1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        malformed_cases = [
            ("bad-magic", b"nope", "InvalidMagic"),
            ("missing-end", valid_for_malformed.read_bytes()[:-4], "TruncatedFrame"),
            ("trailing", valid_for_malformed.read_bytes() + b"x", "TrailingData"),
            (
                "bad-lzvn-distance",
                MAGIC_LZVN
                + struct.pack("<II", 1, 9)
                + bytes((0xF1, 0x06, 0, 0, 0, 0, 0, 0, 0))
                + MAGIC_END,
                "InvalidLzvnStream",
            ),
        ]
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.lzfse"
            path.write_bytes(data)
            expect_failure(
                args.cli,
                "decode-lzfse-file",
                path,
                temp / f"{name}.out",
                1024 * 1024,
                error_name=error_name,
            )
            malformed += 1
        if v2_for_malformed is not None:
            corrupt = bytearray(v2_for_malformed.read_bytes())
            corrupt[32] ^= 0xFF
            path = temp / "corrupt-v2.lzfse"
            path.write_bytes(corrupt)
            expect_failure(
                args.cli,
                "decode-lzfse-file",
                path,
                temp / "corrupt-v2.out",
                512 * 1024 * 1024,
            )
            malformed += 1

    print(
        f"self_cases={self_cases} lzfse={reference is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"v1_cases={v1_cases} malformed={malformed} "
        f"kinds=raw:{kind_counts['raw']},lzvn:{kind_counts['lzvn']},"
        f"v1:{kind_counts['v1']},v2:{kind_counts['v2']}"
    )


if __name__ == "__main__":
    main()
