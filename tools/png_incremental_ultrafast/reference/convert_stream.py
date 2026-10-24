#!/usr/bin/env python3
"""RFC1951 parse/conversion of real fdeflate bytes, without native output."""
from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
import zlib

WORK = Path(__file__).resolve().parent
OWNER = Path("/nav_env/Temp/vort-png-incremental-ultrafast-reference")
LENGTH_BASE = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]
LENGTH_EXTRA = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]
DISTANCE_BASE = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577]
DISTANCE_EXTRA = [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13]
CODE_LENGTH_ORDER = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Bits:
    def __init__(self, data: bytes):
        self.data = data
        self.position = 0

    def take(self, count: int) -> int:
        if self.position + count > len(self.data) * 8:
            raise ValueError("truncated RFC1951 bitstream")
        result = 0
        for i in range(count):
            result |= ((self.data[self.position // 8] >> (self.position % 8)) & 1) << i
            self.position += 1
        return result


class Huffman:
    def __init__(self, lengths: list[int]):
        if any(n < 0 or n > 15 for n in lengths):
            raise ValueError("invalid Huffman code length")
        self.max_length = max(lengths)
        if self.max_length == 0:
            raise ValueError("empty Huffman tree")
        counts = [lengths.count(n) for n in range(16)]
        counts[0] = 0
        next_code = [0] * 16
        code = 0
        for width in range(1, 16):
            code = (code + counts[width - 1]) << 1
            if code + counts[width] > 1 << width:
                raise ValueError("oversubscribed Huffman tree")
            next_code[width] = code
        self.table = {}
        for symbol, width in enumerate(lengths):
            if not width:
                continue
            canonical = next_code[width]
            next_code[width] += 1
            reversed_code = sum(((canonical >> i) & 1) << (width - 1 - i) for i in range(width))
            self.table[(width, reversed_code)] = symbol

    def decode(self, reader: Bits) -> int:
        code = 0
        for width in range(1, self.max_length + 1):
            code |= reader.take(1) << (width - 1)
            if (width, code) in self.table:
                return self.table[(width, code)]
        raise ValueError("invalid Huffman symbol")


def dynamic_trees(reader: Bits) -> tuple[Huffman, Huffman, dict]:
    hlit = reader.take(5) + 257
    hdist = reader.take(5) + 1
    hclen = reader.take(4) + 4
    if hlit > 286:
        raise ValueError("reserved literal alphabet size")
    code_lengths = [0] * 19
    for symbol in CODE_LENGTH_ORDER[:hclen]:
        code_lengths[symbol] = reader.take(3)
    code_tree = Huffman(code_lengths)
    expanded = []
    while len(expanded) < hlit + hdist:
        symbol = code_tree.decode(reader)
        if symbol <= 15:
            expanded.append(symbol)
        elif symbol == 16:
            if not expanded:
                raise ValueError("repeat-without-previous length")
            expanded += [expanded[-1]] * (reader.take(2) + 3)
        elif symbol == 17:
            expanded += [0] * (reader.take(3) + 3)
        elif symbol == 18:
            expanded += [0] * (reader.take(7) + 11)
        else:
            raise ValueError("reserved code-length symbol")
        if len(expanded) > hlit + hdist:
            raise ValueError("code-length repeat overflow")
    literal_lengths = expanded[:hlit]
    distance_lengths = expanded[hlit:]
    if literal_lengths[256] == 0:
        raise ValueError("missing EOB code")
    metadata = {"hlit": hlit, "hdist": hdist, "hclen": hclen,
                "dynamic_header_deflate_bit_end": reader.position,
                "literal_lengths": literal_lengths, "distance_lengths": distance_lengths}
    return Huffman(literal_lengths), Huffman(distance_lengths), metadata


def parse_old(old: bytes, source: bytes) -> dict:
    if len(old) < 7 or old[0] & 15 != 8 or old[0] >> 4 > 7 or int.from_bytes(old[:2], "big") % 31 or old[1] & 32:
        raise ValueError("invalid or dictionary zlib header")
    reader = Bits(old[2:-4])
    final = reader.take(1)
    kind = reader.take(2)
    if final != 1 or kind != 2:
        raise ValueError("old reference must be exactly one final dynamic block")
    literal, distance, metadata = dynamic_trees(reader)
    decoded = bytearray()
    symbols = 0
    matches = 0
    maximum_distance = 0
    while True:
        before = reader.position
        symbol = literal.decode(reader)
        symbols += 1
        if symbol < 256:
            decoded.append(symbol)
        elif symbol == 256:
            eob_start = before
            break
        elif 257 <= symbol <= 285:
            index = symbol - 257
            length = LENGTH_BASE[index] + reader.take(LENGTH_EXTRA[index])
            dsym = distance.decode(reader)
            if dsym > 29:
                raise ValueError("reserved distance symbol")
            offset = DISTANCE_BASE[dsym] + reader.take(DISTANCE_EXTRA[dsym])
            if offset > len(decoded):
                raise ValueError("distance before output start")
            for _ in range(length):
                decoded.append(decoded[-offset])
            matches += 1
            maximum_distance = max(maximum_distance, offset)
        else:
            raise ValueError("reserved literal/length symbol")
        if len(decoded) > len(source):
            raise ValueError("decoded output exceeds original")
    if bytes(decoded) != source:
        raise ValueError("independent RFC1951 parser payload mismatch")
    eob_end = reader.position
    if len(reader.data) != (eob_end + 7) // 8:
        raise ValueError("unexpected bytes after old final EOB")
    while reader.position < len(reader.data) * 8:
        if reader.take(1):
            raise ValueError("nonzero old padding")
    if int.from_bytes(old[-4:], "big") != zlib.adler32(source) & 0xffffffff:
        raise ValueError("old Adler32 mismatch")
    return {**metadata, "deflate_eob_bit_start": eob_start, "deflate_eob_bit_end": eob_end,
            "zlib_eob_bit_end": 16 + eob_end, "symbol_count_including_eob": symbols,
            "length_distance_pairs": matches, "maximum_distance": maximum_distance}


def append_bits(output: bytearray, position: int, value: int, width: int) -> int:
    for bit in range(width):
        if position // 8 == len(output):
            output.append(0)
        output[position // 8] |= ((value >> bit) & 1) << (position % 8)
        position += 1
    return position


def convert(old: bytes, source: bytes) -> tuple[bytes, dict]:
    parsed = parse_old(old, source)
    end = parsed["zlib_eob_bit_end"]
    output = bytearray(old[:(end + 7) // 8])
    output[2] &= 0xfe  # only original first BFINAL changes
    if end % 8:
        output[-1] &= (1 << (end % 8)) - 1
    # RFC1951 stored final block: BFINAL=1,BTYPE=00; numeric three-bit value1.
    position = append_bits(output, end, 1, 3)
    padding = (-position) % 8
    position = append_bits(output, position, 0, padding)
    assert position == len(output) * 8
    len_offset = len(output)
    output.extend(b"\x00\x00\xff\xff")
    output.extend(old[-4:])
    # Independent bit-prefix check prevents changing any old content code.
    for bit in range(end):
        expected = 0 if bit == 16 else ((old[bit // 8] >> (bit % 8)) & 1)
        if ((output[bit // 8] >> (bit % 8)) & 1) != expected:
            raise ValueError("derived stream changed an original content bit")
    decoder = zlib.decompressobj(zlib.MAX_WBITS)
    inflated = decoder.decompress(bytes(output), len(source) + 1) + decoder.flush()
    if inflated != source or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail:
        raise ValueError("derived stream system zlib inflate failed")
    return bytes(output), {**parsed, "final_stored_header_zlib_bit_start": end,
                           "final_stored_padding_bits": padding, "final_stored_len_byte_offset": len_offset}


def main() -> None:
    if WORK != OWNER:
        raise RuntimeError("conversion outputs must stay in owned Temp directory")
    old_file = WORK / "fixtures.jsonl"
    old_payload = old_file.read_bytes()
    old_rows = [json.loads(line) for line in old_payload.splitlines()]
    output = bytearray()
    residues = set()
    headers = set()
    for row in old_rows:
        source = bytes.fromhex(row["source_hex"])
        old = bytes.fromhex(row["expected_hex"])
        derived, parsed = convert(old, source)
        residues.add(parsed["zlib_eob_bit_end"] % 8)
        headers.add((parsed["hlit"], parsed["hdist"], parsed["hclen"], parsed["dynamic_header_deflate_bit_end"]))
        final = {**row, "old_expected_hex": old.hex(), "old_expected_sha256": sha(old),
                 "derived_expected_hex": derived.hex(), "derived_expected_sha256": sha(derived),
                 "stream_expected_hex": derived.hex(), "stream_expected_sha256": sha(derived),
                 "stream_expected_len": len(derived), "parsed_rfc1951": parsed,
                 "stream_system_zlib_inflate": "pass"}
        output.extend((json.dumps(final, sort_keys=True, separators=(",", ":")) + "\n").encode())
    (WORK / "stream-fixtures.jsonl").write_bytes(output)
    manifest = {"schema": "vort.png_incremental_ultrafast_stream_reference.v1", "pass": True,
                "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "rows": len(old_rows), "old_fixture_sha256": sha(old_payload),
                "stream_fixture_sha256": sha(output), "converter_sha256": sha(Path(__file__).read_bytes()),
                "old_manifest_sha256": sha((WORK / "manifest.json").read_bytes()),
                "contract": "RFC1951 dynamic-tree and length/distance parse of actual single-full-write fdeflate. Preserve every bit through EOB except first BFINAL cleared. Append final stored block numeric header1 width3 (LSB bits1,0,0), zero byte alignment, LEN=0000/NLEN=ffff, unchanged original Adler32. No Zig/native results used.",
                "RFC_sections": ["1951 section3.1.1", "1951 section3.2.4", "1951 section3.2.5", "1951 section3.2.7", "1950 section2.2"],
                "full_original_prefix_checked_except_bfinal": True,
                "rfc_parser_original_payload_exact": True,
                "derived_system_zlib_inflate_rows": len(old_rows),
                "zlib_compile_version": zlib.ZLIB_VERSION, "zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
                "EOB_bit_residues_mod8": sorted(residues), "dynamic_header_shapes": sorted(headers)}
    (WORK / "stream-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"pass": True, "rows": len(old_rows), "old_fixture_sha256": manifest["old_fixture_sha256"],
                      "stream_fixture_sha256": manifest["stream_fixture_sha256"], "EOB_bit_residues_mod8": sorted(residues)}))


if __name__ == "__main__":
    main()
