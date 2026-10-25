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


SCHEMA = "vort.deflate64.stream-fixtures.v1"
FIXED_CASES = ("empty", "tiny", "pattern", "binary", "runs", "long_length", "long_distance")
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
    def __init__(self, lengths: list[int]) -> None:
        counts = [0] * 16
        for length in lengths:
            require(0 <= length <= 15, "invalid Huffman code length")
            if length:
                counts[length] += 1
        remaining = 1
        for width in range(1, 16):
            remaining = remaining * 2 - counts[width]
            require(remaining >= 0, "oversubscribed Huffman tree")
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


def dynamic_trees(bits: Bits) -> tuple[Huffman, Huffman]:
    literal_count, distance_count, code_count = bits.read(5) + 257, bits.read(5) + 1, bits.read(4) + 4
    require(literal_count <= 286 and distance_count <= 32, "invalid dynamic alphabet")
    order = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 3, 12, 2, 13, 1, 14, 15)
    code_lengths = [0] * 19
    for index in range(code_count):
        code_lengths[order[index]] = bits.read(3)
    codes = Huffman(code_lengths)
    lengths: list[int] = []
    total = literal_count + distance_count
    while len(lengths) < total:
        symbol = codes.symbol(bits)
        if symbol <= 15:
            lengths.append(symbol)
        elif symbol == 16:
            require(bool(lengths), "repeat without prior length")
            lengths.extend([lengths[-1]] * (bits.read(2) + 3))
        elif symbol == 17:
            lengths.extend([0] * (bits.read(3) + 3))
        elif symbol == 18:
            lengths.extend([0] * (bits.read(7) + 11))
        else:
            raise AssertionError("invalid code-length symbol")
        require(len(lengths) <= total, "code-length repeat exceeds alphabet")
    require(lengths[256] != 0, "missing end-of-block code")
    return Huffman(lengths[:literal_count]), Huffman(lengths[literal_count:])


def inspect_raw(data: bytes, expected: bytes) -> dict[str, object]:
    """Independent bounded raw decoder; also proves extended tokens are present."""
    bits = Bits(data)
    output = bytearray()
    blocks: list[str] = []
    literal_tokens = match_tokens = maximum_length = maximum_distance = 0
    while True:
        final, kind = bits.read(1), bits.read(2)
        if kind == 0:
            blocks.append("stored")
            bits.align()
            length, complement = bits.read(16), bits.read(16)
            require(length ^ complement == 0xFFFF, "stored LEN/NLEN mismatch")
            require(len(output) + length <= len(expected), "stored output exceeds deterministic input")
            for _ in range(length):
                output.append(bits.read(8))
        else:
            require(kind != 3, "reserved block type")
            if kind == 1:
                blocks.append("fixed")
                literals = Huffman([8] * 144 + [9] * 112 + [7] * 24 + [8] * 8)
                distances = Huffman([5] * 32)
            else:
                blocks.append("dynamic")
                literals, distances = dynamic_trees(bits)
            while True:
                symbol = literals.symbol(bits)
                if symbol < 256:
                    require(len(output) < len(expected), "literal output exceeds deterministic input")
                    output.append(symbol)
                    literal_tokens += 1
                    continue
                if symbol == 256:
                    break
                require(257 <= symbol <= 285, "reserved literal/length symbol")
                if symbol == 285:
                    length = 3 + bits.read(16)
                else:
                    index = symbol - 257
                    length = LENGTH_BASE[index] + bits.read(LENGTH_EXTRA[index])
                distance_symbol = distances.symbol(bits)
                require(distance_symbol < 32, "invalid distance symbol")
                distance = DISTANCE_BASE[distance_symbol] + bits.read(DISTANCE_EXTRA[distance_symbol])
                require(0 < distance <= min(65_536, len(output)), "match has no valid history")
                require(len(output) + length <= len(expected), "match output exceeds deterministic input")
                for _ in range(length):
                    output.append(output[-distance])
                match_tokens += 1
                maximum_length, maximum_distance = max(maximum_length, length), max(maximum_distance, distance)
        if final:
            break
        require(len(blocks) <= len(data) * 8, "too many blocks")
    require(bytes(output) == expected, "independent raw decoded bytes differ")
    require(len(data) * 8 - bits.offset < 8, "trailing bytes after final block")
    padding = len(data) * 8 - bits.offset
    require(bits.read(padding) == 0, "nonzero final-byte padding")
    return {"blocks": blocks, "literal_tokens": literal_tokens, "match_tokens": match_tokens,
            "maximum_length": maximum_length, "maximum_distance": maximum_distance,
            "decoded_bytes": len(output), "decoded_sha256": sha256(output)}


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


def main() -> None:
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
    require(manifest.get("schema") == SCHEMA, "unexpected fixture schema")
    require(tuple(case["name"] for case in manifest["cases"]) == FIXED_CASES, "deterministic corpus case list")
    results = []
    for case in manifest["cases"]:
        expected = expected_input(case["name"])
        require(isinstance(case["input_file"], str) and Path(case["input_file"]).name == case["input_file"],
                "input artifact must be a local filename")
        plaintext = directory / case["input_file"]
        require(plaintext.read_bytes() == expected and len(expected) == case["input_bytes"] and
                sha256(expected) == case["input_sha256"] and
                binascii.crc32(expected) & 0xFFFFFFFF == case["crc32"], (case["name"], "deterministic input"))
        require(len(case["artifacts"]) == 4 and
                {(row["kind"], row["pattern"]) for row in case["artifacts"]} ==
                {(kind, pattern) for kind in ("incremental_raw", "incremental_zip") for pattern in ("one", "mixed")},
                (case["name"], "artifact pattern matrix"))
        wires: dict[str, bytes] = {}
        for artifact in case["artifacts"]:
            path, data = checked_artifact(directory, artifact)
            progress = artifact["progress"]
            expected_reads = len(expected) * (2 if artifact["kind"] == "incremental_zip" else 1)
            require(progress["input_read"] == expected_reads and progress["output_written"] == len(data) and
                    progress["caller_guards_verified"] is True and progress["steps"] > 0,
                    (path.name, "caller progress accounting"))
            if artifact["pattern"] == "mixed":
                require(progress["zero_input_offers"] > 0 and progress["zero_output_offers"] > 0,
                        (path.name, "missing zero-sized backpressure offers"))
            if artifact["kind"] in wires:
                require(wires[artifact["kind"]] == data, (case["name"], "chunk schedule changed deterministic wire"))
            else:
                wires[artifact["kind"]] = data
            if artifact["kind"] == "incremental_raw":
                raw = inspect_raw(data, expected)
                if case["name"] in ("long_length", "long_distance"):
                    target = 65_538 if case["name"] == "long_length" else 65_536
                    field = "maximum_length" if case["name"] == "long_length" else "maximum_distance"
                    require(raw[field] == target, (case["name"], "missing encoded extended token"))
                wrapped = directory / (path.stem + "-reference.zip")
                wrapped.write_bytes(wrap_raw(expected, data, "raw.bin"))
                require(run(unzip, "-p", wrapped, "raw.bin") == expected, (path.name, "unzip raw container output"))
                records = inspect_zip(wrapped.read_bytes(), expected, ("raw.bin",))
            elif artifact["kind"] == "incremental_zip":
                records = inspect_zip(data, expected, ("known.bin", "unknown.bin"))
                run(unzip, "-t", path)
                for member in ("known.bin", "unknown.bin"):
                    require(run(unzip, "-p", path, member) == expected, (path.name, member, "unzip full output"))
                for record in records:
                    require(record["flags"] & 8, "streaming method9 entry must retain descriptor")
                    if case["name"] in ("long_length", "long_distance"):
                        field = "maximum_length" if case["name"] == "long_length" else "maximum_distance"
                        target = 65_538 if case["name"] == "long_length" else 65_536
                        require(record["raw"][field] == target, (path.name, record["name"], "missing extended token"))
            else:
                raise AssertionError(f"unknown fixture artifact kind {artifact['kind']!r}")
            results.append({"case": case["name"], "artifact": path.name, "kind": artifact["kind"],
                            "wire_sha256": sha256(data), "wire_bytes": len(data), "members": records,
                            "independent_unzip_full_contents_verified": True})
    report = {"schema": "vort.deflate64.stream-differential.v1", "created_utc": datetime.now(timezone.utc).isoformat(),
              "python": platform.python_version(), "probe": generator,
              "manifest_sha256": sha256(manifest_path.read_bytes()),
              "reference": {"path": str(unzip), "executable_sha256": sha256(unzip.read_bytes()), "version": version},
              "validation": "deterministic full plaintext, independent raw token decode, ZIP9 headers/CRC/descriptors, unzip -t and -p",
              "results": results, "commands": commands}
    report_path = args.report or directory / "differential.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(report_path), "artifacts_verified": len(results), "reference": str(unzip)}))


if __name__ == "__main__":
    main()
