#!/usr/bin/env python3
"""Verify deterministic incremental Deflate64 fixtures with Info-ZIP unzip.

This script never compiles the probe. Pass --probe to generate fixtures using an
already-built executable, or omit it to review an existing fixture directory.
Python's zipfile is used for metadata only: it does not decode ZIP method 9.
"""

from __future__ import annotations

import argparse
import binascii
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import platform
import struct
import subprocess
import zipfile


SCHEMAS = ("vort.deflate64.stream-fixtures.v1", "vort.deflate64.stream-fixtures.v2", "vort.deflate64.stream-fixtures.v3")
STREAM_V1_CASES = ("empty", "tiny", "pattern", "binary", "runs", "long_length", "long_distance")
FIXED_CASES = STREAM_V1_CASES + ("multi_block",)
LENGTH_BASE = (3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
               35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227)
LENGTH_EXTRA = (0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5)
DISTANCE_BASE = (1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                 8193, 12289, 16385, 24577, 32769, 49153)
DISTANCE_EXTRA = (0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                  7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14)


def require(condition: bool, context: object) -> None:
    if not condition:
        raise AssertionError(context)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def deterministic_bytes(length: int, seed: int) -> bytes:
    result = bytearray()
    state = seed
    for _ in range(length):
        state = (state * 1_664_525 + 1_013_904_223) & 0xFFFFFFFF
        result.append(state >> 24)
    return bytes(result)


def expected_input(name: str) -> bytes:
    if name == "empty":
        return b""
    if name == "tiny":
        return b"Deflate64\x00tiny\xff\n"
    if name == "pattern":
        return b"Deflate64 streaming ZIP method 9 backpressure.\n" * 257
    if name == "binary":
        return deterministic_bytes(16_387, 0xD6402026)
    if name == "runs":
        return b"R" * 70_003
    if name == "long_length":
        return b"Q" * 65_539
    if name == "long_distance":
        history = deterministic_bytes(65_536, 0x65362026)
        return history + history
    if name == "multi_block":
        period = b"Deflate64 multi-block history continuity.\n"
        return (period * ((300_000 + len(period) - 1) // len(period)))[:300_000]
    raise AssertionError(f"unknown deterministic case {name!r}")


class Bits:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def read(self, width: int) -> int:
        require(self.offset + width <= len(self.data) * 8, "truncated Deflate64 bits")
        value = 0
        for bit in range(width):
            value |= ((self.data[self.offset >> 3] >> (self.offset & 7)) & 1) << bit
            self.offset += 1
        return value

    def align(self) -> None:
        self.offset = (self.offset + 7) & ~7


class Huffman:
    def __init__(self, lengths: list[int], *, allow_empty: bool = False, require_complete: bool = False) -> None:
        counts = [0] * 16
        for length in lengths:
            require(0 <= length <= 15, "invalid Huffman code length")
            if length:
                counts[length] += 1
        remaining = 1
        for width in range(1, 16):
            remaining = remaining * 2 - counts[width]
            require(remaining >= 0, "oversubscribed Huffman tree")
        active = sum(counts)
        require(active != 0 or allow_empty, "empty Huffman tree")
        if active and remaining:
            require(not require_complete and active == 1 and counts[1] == 1, "incomplete Huffman tree")
        self.lengths = lengths
        self.active = active
        next_codes = [0] * 16
        code = 0
        for width in range(1, 16):
            code = (code + counts[width - 1]) << 1
            next_codes[width] = code
        self.table: dict[tuple[int, int], int] = {}
        for symbol, width in enumerate(lengths):
            if not width:
                continue
            canonical = next_codes[width]
            next_codes[width] += 1
            reversed_code = int(f"{canonical:0{width}b}"[::-1], 2)
            self.table[width, reversed_code] = symbol
        self.maximum = max(lengths, default=0)

    def symbol(self, bits: Bits) -> int:
        code = 0
        for width in range(1, self.maximum + 1):
            code |= bits.read(1) << (width - 1)
            if (width, code) in self.table:
                return self.table[width, code]
        raise AssertionError("invalid Huffman symbol")


def dynamic_trees(bits: Bits) -> tuple[Huffman, Huffman, dict[str, object]]:
    start = bits.offset
    literal_count, distance_count, code_count = bits.read(5) + 257, bits.read(5) + 1, bits.read(4) + 4
    require(literal_count <= 286 and distance_count <= 32, "invalid dynamic alphabet")
    order = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15)
    code_lengths = [0] * 19
    for index in range(code_count):
        code_lengths[order[index]] = bits.read(3)
    codes = Huffman(code_lengths, require_complete=True)
    lengths: list[int] = []
    total = literal_count + distance_count
    encoded_lengths = {"literal_lengths": 0, "repeat16": 0, "repeat17": 0, "repeat18": 0}
    rle_code_bits = rle_extra_bits = 0
    while len(lengths) < total:
        symbol = codes.symbol(bits)
        rle_code_bits += codes.lengths[symbol]
        if symbol <= 15:
            lengths.append(symbol)
            encoded_lengths["literal_lengths"] += 1
        elif symbol == 16:
            require(bool(lengths), "repeat without prior length")
            lengths.extend([lengths[-1]] * (bits.read(2) + 3))
            rle_extra_bits += 2
            encoded_lengths["repeat16"] += 1
        elif symbol == 17:
            lengths.extend([0] * (bits.read(3) + 3))
            rle_extra_bits += 3
            encoded_lengths["repeat17"] += 1
        elif symbol == 18:
            lengths.extend([0] * (bits.read(7) + 11))
            rle_extra_bits += 7
            encoded_lengths["repeat18"] += 1
        else:
            raise AssertionError("invalid code-length symbol")
        require(len(lengths) <= total, "code-length repeat exceeds alphabet")
    require(lengths[256] != 0, "missing end-of-block code")
    literal_lengths, distance_lengths = lengths[:literal_count], lengths[literal_count:]
    literals = Huffman(literal_lengths)
    distances = Huffman(distance_lengths, allow_empty=True)
    counted_bits = 14 + code_count * 3 + rle_code_bits + rle_extra_bits
    require(bits.offset - start == counted_bits, "dynamic header bit count differs")
    header = {"hlit": literal_count - 257, "hdist": distance_count - 1, "hclen": code_count - 4,
              "literal_alphabet_entries": literal_count, "distance_alphabet_entries": distance_count,
              "code_length_alphabet_entries": code_count, "literal_active_codes": literals.active,
              "distance_active_codes": distances.active, "code_length_active_codes": codes.active,
              "literal_max_bits": literals.maximum, "distance_max_bits": distances.maximum,
              "code_length_max_bits": codes.maximum, "code_length_rle": encoded_lengths,
              "dimension_bits": 14, "code_length_alphabet_bits": code_count * 3,
              "rle_code_bits": rle_code_bits, "rle_extra_bits": rle_extra_bits,
              "tree_header_bits": counted_bits}
    return literals, distances, header


def inspect_raw(data: bytes, expected: bytes) -> dict[str, object]:
    """Independent bounded raw decoder; also proves extended tokens are present."""
    bits = Bits(data)
    output = bytearray()
    blocks: list[str] = []
    block_details: list[dict[str, object]] = []
    literal_tokens = match_tokens = maximum_length = maximum_distance = 0
    length_285_tokens = length_65538_tokens = distance_31_tokens = distance_65536_tokens = 0
    maximum_length_285_extra = maximum_distance_31_extra = 0
    while True:
        block_start, output_start = bits.offset, len(output)
        final, kind = bits.read(1), bits.read(2)
        header: dict[str, object] | None = None
        literal_code_bits = length_code_bits = length_extra_bits = distance_code_bits = distance_extra_bits = end_code_bits = 0
        if kind == 0:
            blocks.append("stored")
            alignment = (-(block_start + 3)) & 7
            require(bits.read(alignment) == 0, "nonzero emitted stored-block alignment padding")
            length, complement = bits.read(16), bits.read(16)
            require(length ^ complement == 0xFFFF, "stored LEN/NLEN mismatch")
            require(len(output) + length <= len(expected), "stored output exceeds deterministic input")
            for _ in range(length):
                output.append(bits.read(8))
            header_bits, payload_bits = 3 + alignment + 32, length * 8
        else:
            require(kind != 3, "reserved block type")
            if kind == 1:
                blocks.append("fixed")
                literals = Huffman([8] * 144 + [9] * 112 + [7] * 24 + [8] * 8)
                distances = Huffman([5] * 32)
            else:
                blocks.append("dynamic")
                literals, distances, header = dynamic_trees(bits)
            header_bits = bits.offset - block_start
            while True:
                symbol = literals.symbol(bits)
                if symbol < 256:
                    require(len(output) < len(expected), "literal output exceeds deterministic input")
                    output.append(symbol)
                    literal_tokens += 1
                    literal_code_bits += literals.lengths[symbol]
                    continue
                if symbol == 256:
                    end_code_bits += literals.lengths[symbol]
                    break
                require(257 <= symbol <= 285, "reserved literal/length symbol")
                length_code_bits += literals.lengths[symbol]
                if symbol == 285:
                    extra = bits.read(16)
                    length = 3 + extra
                    length_extra_bits += 16
                    length_285_tokens += 1
                    maximum_length_285_extra = max(maximum_length_285_extra, extra)
                    length_65538_tokens += int(extra == 65535)
                else:
                    index = symbol - 257
                    length = LENGTH_BASE[index] + bits.read(LENGTH_EXTRA[index])
                    length_extra_bits += LENGTH_EXTRA[index]
                distance_symbol = distances.symbol(bits)
                require(distance_symbol < 32, "invalid distance symbol")
                distance_extra = bits.read(DISTANCE_EXTRA[distance_symbol])
                distance = DISTANCE_BASE[distance_symbol] + distance_extra
                distance_code_bits += distances.lengths[distance_symbol]
                distance_extra_bits += DISTANCE_EXTRA[distance_symbol]
                if distance_symbol == 31:
                    distance_31_tokens += 1
                    maximum_distance_31_extra = max(maximum_distance_31_extra, distance_extra)
                    distance_65536_tokens += int(distance_extra == 16383)
                require(0 < distance <= min(65_536, len(output)), "match has no valid history")
                require(len(output) + length <= len(expected), "match output exceeds deterministic input")
                for _ in range(length):
                    output.append(output[-distance])
                match_tokens += 1
                maximum_length, maximum_distance = max(maximum_length, length), max(maximum_distance, distance)
            payload_bits = literal_code_bits + length_code_bits + length_extra_bits + distance_code_bits + distance_extra_bits + end_code_bits
        require(bits.offset - block_start == header_bits + payload_bits, "block bit accounting differs")
        block_details.append({"kind": blocks[-1], "final": bool(final), "start_bit": block_start,
                              "end_bit": bits.offset, "encoded_bits": bits.offset - block_start,
                              "header_bits": header_bits, "payload_bits": payload_bits,
                              "literal_code_bits": literal_code_bits, "length_code_bits": length_code_bits,
                              "length_extra_bits": length_extra_bits, "distance_code_bits": distance_code_bits,
                              "distance_extra_bits": distance_extra_bits, "end_code_bits": end_code_bits,
                              "decoded_start": output_start, "decoded_bytes": len(output) - output_start,
                              "dynamic_header": header})
        if final:
            break
        require(len(blocks) <= len(data) * 8, "too many blocks")
    require(bytes(output) == expected, "independent raw decoded bytes differ")
    require(len(data) * 8 - bits.offset < 8, "trailing bytes after final block")
    end_bit = bits.offset
    padding = len(data) * 8 - bits.offset
    require(bits.read(padding) == 0, "nonzero final-byte padding")
    require(sum(block["encoded_bits"] for block in block_details) == end_bit and end_bit + padding == len(data) * 8,
            "whole stream bit count differs")
    return {"blocks": blocks, "literal_tokens": literal_tokens, "match_tokens": match_tokens,
            "maximum_length": maximum_length, "maximum_distance": maximum_distance,
            "length_285_tokens": length_285_tokens, "length_65538_tokens": length_65538_tokens,
            "maximum_length_285_extra": maximum_length_285_extra,
            "distance_31_tokens": distance_31_tokens, "distance_65536_tokens": distance_65536_tokens,
            "maximum_distance_31_extra": maximum_distance_31_extra,
            "end_bit": end_bit, "padding_bits": padding, "serialized_bits": len(data) * 8,
            "block_details": block_details, "dynamic_block_count": blocks.count("dynamic"),
            "dynamic_encoded_bits": sum(block["encoded_bits"] for block in block_details if block["kind"] == "dynamic"),
            "dynamic_tree_header_bits": sum(block["dynamic_header"]["tree_header_bits"] for block in block_details
                                            if block["dynamic_header"] is not None),
            "decoded_bytes": len(output), "decoded_sha256": sha256(output)}


def check_dynamic_parser_golden() -> None:
    """Hand-pack an RFC 1951 header without target encoder or parser tables.

    Literal codes are 0=0, A=10, B=110, EOB=111; distance codes are 0/1.
    CL codes are 1=0, 2=10, 3=110, 18=111. Distinct lengths at the RFC
    positions of 1, 2 and 3 detect exchanges with 14, 13 and 12 respectively.
    This parser self-check is separate from actual target-encoder fixtures.
    """
    fields = [(1, 1), (2, 2), (0, 5), (1, 5), (14, 4)]
    # Explicit RFC wire positions 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1.
    fields.extend((value, 3) for value in (0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 2, 0, 1))
    # Lengths: 1, 64 zeroes, 2, 3, 138+51 zeroes, 3, 1, 1.
    # Huffman fields below reverse the stated canonical codes for LSB packing.
    fields.extend(((0, 1), (7, 3), (53, 7), (1, 2), (3, 3), (7, 3), (127, 7),
                   (7, 3), (40, 7), (3, 3), (0, 1), (0, 1)))
    fields.extend(((0, 1), (1, 2), (3, 3), (7, 3)))  # Literal0, A, B, EOB.
    packed_bits = [(value >> bit) & 1 for value, width in fields for bit in range(width)]
    wire = bytes(sum(value << shift for shift, value in enumerate(packed_bits[index:index + 8]))
                 for index in range(0, len(packed_bits), 8))
    require(wire.hex() == "05c181010000008310afb5ff8f1ada01" and len(packed_bits) == 121,
            "RFC dynamic golden wire changed")
    bits = Bits(wire)
    require((bits.read(1), bits.read(2)) == (1, 2), "RFC dynamic golden block type")
    literals, distances, header = dynamic_trees(bits)
    require(literals.lengths == [1] + [0] * 64 + [2, 3] + [0] * 189 + [3] and
            distances.lengths == [1, 1], "RFC dynamic golden expanded lengths")
    require(bits.offset == 112 and header["tree_header_bits"] == 109 and
            header["rle_code_bits"] == 20 and header["rle_extra_bits"] == 21,
            "RFC dynamic golden header bit count")
    raw = inspect_raw(wire, b"\x00AB")
    require(raw["end_bit"] == 121 and raw["padding_bits"] == 7 and
            raw["block_details"][0]["header_bits"] == 112 and
            raw["block_details"][0]["payload_bits"] == 9, "RFC dynamic golden payload bit count")
    for lengths, error in (([1, 1, 1], "oversubscribed Huffman tree"),
                           ([2, 2], "incomplete Huffman tree"), ([], "empty Huffman tree")):
        try:
            Huffman(lengths)
        except AssertionError as actual:
            require(str(actual) == error, "strict Huffman self-check error differs")
        else:
            raise AssertionError(f"strict Huffman self-check accepted {error}")


def wrap_raw(payload: bytes, compressed: bytes, name: str) -> bytes:
    """A standalone ZIP32 container for target-encoder raw reference decoding."""
    encoded_name = name.encode("ascii")
    crc = binascii.crc32(payload) & 0xFFFFFFFF
    local = struct.pack("<IHHHHHIIIHH", 0x04034B50, 21, 0, 9, 0, 0x21,
                        crc, len(compressed), len(payload), len(encoded_name), 0) + encoded_name + compressed
    central = struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 21, 21, 0, 9, 0, 0x21,
                          crc, len(compressed), len(payload), len(encoded_name), 0, 0, 0, 0, 0, 0) + encoded_name
    return local + central + struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 1, 1, len(central), len(local), 0)


def checked_artifact(directory: Path, row: dict[str, object]) -> tuple[Path, bytes]:
    name = row["file"]
    require(isinstance(name, str) and Path(name).name == name, "artifact must be a local filename")
    path = directory / name
    data = path.read_bytes()
    require(len(data) == row["bytes"] and sha256(data) == row["sha256"], (name, "artifact identity"))
    return path, data


def inspect_zip(data: bytes, expected: bytes, required_names: tuple[str, ...]) -> list[dict[str, object]]:
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(tuple(archive.namelist()) == required_names, "unexpected ZIP member order")
        records = []
        for info in archive.infolist():
            require(info.compress_type == 9 and info.extract_version >= 21, (info.filename, "method 9 metadata"))
            require(info.file_size == len(expected) and info.CRC == binascii.crc32(expected) & 0xFFFFFFFF,
                    (info.filename, "plaintext size/CRC metadata"))
            require(not info.flag_bits & 1 and not info.extra, (info.filename, "unexpected encryption/extra"))
            header = struct.unpack_from("<IHHHHHIIIHH", data, info.header_offset)
            signature, version, flags, method, _, _, local_crc, local_compressed, local_size, name_len, extra_len = header
            require(signature == 0x04034B50 and version >= 21 and flags == info.flag_bits and method == 9,
                    (info.filename, "local/central headers"))
            payload_offset = info.header_offset + 30 + name_len + extra_len
            require(data[info.header_offset + 30:info.header_offset + 30 + name_len] == info.filename.encode("ascii"),
                    "local filename differs")
            compressed = data[payload_offset:payload_offset + info.compress_size]
            require(len(compressed) == info.compress_size, "truncated ZIP payload")
            descriptor = None
            if flags & 8:
                offset = payload_offset + info.compress_size
                first = struct.unpack_from("<I", data, offset)[0]
                if first == 0x08074B50:
                    offset += 4
                values = struct.unpack_from("<III", data, offset)
                require(values == (info.CRC, info.compress_size, info.file_size), "ZIP descriptor metadata")
                descriptor = {"signed": first == 0x08074B50, "crc32": values[0], "compressed_bytes": values[1]}
                require(local_crc in (0, info.CRC) and local_compressed in (0, info.compress_size) and
                        local_size in (0, info.file_size), "incompatible local descriptor placeholders")
            else:
                require((local_crc, local_compressed, local_size) == (info.CRC, info.compress_size, info.file_size),
                        "local metadata differs from central directory")
            records.append({"name": info.filename, "method": 9, "flags": flags, "crc32": info.CRC,
                            "uncompressed_bytes": info.file_size, "compressed_bytes": info.compress_size,
                            "descriptor": descriptor, "raw": inspect_raw(compressed, expected)})
        return records


def check_raw_policy(raw: dict[str, object], case: str, compression: str, context: str) -> None:
    blocks = raw["blocks"]
    if compression == "dynamic":
        require(blocks and all(kind == "dynamic" for kind in blocks), (context, "forced dynamic block type"))
    elif compression == "fixed":
        require(blocks and all(kind == "fixed" for kind in blocks), (context, "forced fixed block type"))
    else:
        require(compression == "adaptive", (context, "unknown compression policy"))
    if case == "long_length":
        require(raw["maximum_length"] == 65_538 and raw["length_65538_tokens"] > 0 and
                raw["maximum_length_285_extra"] == 65535, (context, "missing code285/extra65535 token"))
        if compression == "dynamic":
            require(any(block["dynamic_header"]["literal_alphabet_entries"] == 286 for block in raw["block_details"]),
                    (context, "dynamic alphabet excludes code285"))
    elif case == "long_distance":
        require(raw["maximum_distance"] == 65_536 and raw["distance_65536_tokens"] > 0 and
                raw["maximum_distance_31_extra"] == 16383, (context, "missing distance31/extra16383 token"))
        if compression == "dynamic":
            require(any(block["dynamic_header"]["distance_alphabet_entries"] == 32 for block in raw["block_details"]),
                    (context, "dynamic alphabet excludes distance31"))
    elif case == "multi_block":
        require(sum(kind in ("fixed", "dynamic") for kind in blocks) >= 3 and raw["match_tokens"] > 0,
                (context, "missing actual multi-block compressed output"))


def main() -> None:
    check_dynamic_parser_golden()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True, help="fixture directory; generation writes only here")
    parser.add_argument("--probe", type=Path, help="already-built Zig fixture probe (no compilation)")
    parser.add_argument("--unzip", type=Path, default=Path("/usr/bin/unzip"))
    parser.add_argument("--report", type=Path, help="default: DIRECTORY/differential.json")
    args = parser.parse_args()
    directory, unzip = args.directory.resolve(), args.unzip.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    commands = []

    def run(*arguments: object) -> bytes:
        command = [str(value) for value in arguments]
        result = subprocess.run(command, capture_output=True, check=False, timeout=120)
        commands.append({"command": command, "exit_code": result.returncode,
                         "stdout_bytes": len(result.stdout), "stdout_sha256": sha256(result.stdout),
                         "stderr": result.stderr.decode(errors="replace")})
        require(result.returncode == 0, (command, result.returncode, result.stderr.decode(errors="replace")))
        return result.stdout

    version = run(unzip, "-v").decode(errors="replace")
    require("USE_DEFLATE64" in version, "unzip must advertise USE_DEFLATE64")
    generator = None
    if args.probe:
        probe = args.probe.resolve()
        generator = {"path": str(probe), "sha256": sha256(probe.read_bytes())}
        run(probe, directory)
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    require(manifest.get("schema") in SCHEMAS, "unexpected fixture schema")
    dynamic_matrix = manifest["schema"].endswith(".v3")
    one_shot_matrix = dynamic_matrix or manifest["schema"].endswith(".v2")
    expected_cases = FIXED_CASES if one_shot_matrix else STREAM_V1_CASES
    require(tuple(case["name"] for case in manifest["cases"]) == expected_cases, "deterministic corpus case list")
    results = []
    for case in manifest["cases"]:
        expected = expected_input(case["name"])
        require(isinstance(case["input_file"], str) and Path(case["input_file"]).name == case["input_file"],
                "input artifact must be a local filename")
        plaintext = directory / case["input_file"]
        require(plaintext.read_bytes() == expected and len(expected) == case["input_bytes"] and
                sha256(expected) == case["input_sha256"] and
                binascii.crc32(expected) & 0xFFFFFFFF == case["crc32"], (case["name"], "deterministic input"))
        expected_artifacts = {(kind, "fixed", pattern) for kind in ("incremental_raw", "incremental_zip") for pattern in ("one", "mixed")}
        if one_shot_matrix:
            expected_artifacts |= {("one_shot_raw", "adaptive", None), ("one_shot_zip", "adaptive", None)}
        if dynamic_matrix:
            expected_artifacts |= {(kind, compression, "mixed") for kind in ("incremental_raw", "incremental_zip")
                                   for compression in ("dynamic", "adaptive")}
        def artifact_compression(row: dict) -> str:
            return row["compression"] if dynamic_matrix else "fixed" if row["kind"].startswith("incremental_") else "adaptive"
        require(len(case["artifacts"]) == len(expected_artifacts) and
                {(row["kind"], artifact_compression(row), row["pattern"]) for row in case["artifacts"]} == expected_artifacts,
                (case["name"], "artifact pattern matrix"))
        wires: dict[tuple[str, str], bytes] = {}
        for artifact in case["artifacts"]:
            path, data = checked_artifact(directory, artifact)
            incremental = artifact["kind"].startswith("incremental_")
            compression = artifact_compression(artifact)
            wire_key = artifact["kind"], compression
            raw_bound = len(expected) + 5 * (max(1, (len(expected) + 65_534) // 65_535))
            if incremental:
                progress = artifact["progress"]
                expected_reads = len(expected) * (2 if artifact["kind"] == "incremental_zip" else 1)
                require(progress["input_read"] == expected_reads and progress["output_written"] == len(data) and
                        progress["caller_guards_verified"] is True and progress["steps"] > 0,
                        (path.name, "caller progress accounting"))
                if artifact["pattern"] == "mixed":
                    require(progress["zero_input_offers"] > 0 and progress["zero_output_offers"] > 0,
                            (path.name, "missing zero-sized backpressure offers"))
                if wire_key in wires:
                    require(wires[wire_key] == data, (case["name"], "chunk schedule changed deterministic wire"))
                else:
                    wires[wire_key] = data
            else:
                require(artifact["progress"] is None and artifact["pattern"] is None and
                        artifact["raw_payload_bound"] == raw_bound, (path.name, "one-shot report/bound"))
            if artifact["kind"] in ("incremental_raw", "one_shot_raw"):
                if not incremental:
                    require(len(data) <= raw_bound, (path.name, "one-shot encodedBound exceeded"))
                raw = inspect_raw(data, expected)
                check_raw_policy(raw, case["name"], compression, path.name)
                wrapped = directory / (path.stem + "-reference.zip")
                wrapped.write_bytes(wrap_raw(expected, data, "raw.bin"))
                require(run(unzip, "-p", wrapped, "raw.bin") == expected, (path.name, "unzip raw container output"))
                records = inspect_zip(wrapped.read_bytes(), expected, ("raw.bin",))
            elif artifact["kind"] in ("incremental_zip", "one_shot_zip"):
                names = ("known.bin", "unknown.bin") if incremental else ("oneshot.bin",)
                records = inspect_zip(data, expected, names)
                run(unzip, "-t", path)
                for member in names:
                    require(run(unzip, "-p", path, member) == expected, (path.name, member, "unzip full output"))
                for record in records:
                    if incremental:
                        require(record["flags"] & 8, "streaming method9 entry must retain descriptor")
                    else:
                        require(not record["flags"] & 8 and record["compressed_bytes"] <= raw_bound,
                                (path.name, "one-shot payload bound/local metadata"))
                    check_raw_policy(record["raw"], case["name"], compression, f"{path.name}/{record['name']}")
            else:
                raise AssertionError(f"unknown fixture artifact kind {artifact['kind']!r}")
            results.append({"case": case["name"], "artifact": path.name, "kind": artifact["kind"],
                            "compression": compression,
                            "wire_sha256": sha256(data), "wire_bytes": len(data), "members": records,
                            "one_shot_raw_payload_bound": None if incremental else raw_bound,
                            "independent_unzip_full_contents_verified": True})
    dynamic_blocks = sum(member["raw"]["dynamic_block_count"] for row in results for member in row["members"])
    dynamic_bits = sum(member["raw"]["dynamic_encoded_bits"] for row in results for member in row["members"])
    report = {"schema": "vort.deflate64.stream-differential.v3", "created_utc": datetime.now(timezone.utc).isoformat(),
              "python": platform.python_version(), "probe": generator,
              "manifest_sha256": sha256(manifest_path.read_bytes()),
              "reference": {"path": str(unzip), "executable_sha256": sha256(unzip.read_bytes()), "version": version},
              "validation": "deterministic full plaintext, independent fixed/dynamic raw token/header/exact-bit decode, ZIP9 CRC/descriptors, unzip -t and -p",
              "dynamic_blocks_verified": dynamic_blocks, "dynamic_encoded_bits_verified": dynamic_bits,
              "block_count_scope": "all independently decoded raw/reference ZIP and library ZIP member records; repeated fixtures counted separately",
              "size_scope": "actual serialized sizes and exact parsed bits only; no throughput or timing measurement",
              "results": results, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), "artifacts_verified": len(results), "reference": str(unzip)}))


if __name__ == "__main__":
    main()
