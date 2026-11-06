"""Independent RFC 1950/1951 receipts for bounded codec-control payloads.

The DEFLATE reader reconstructs every literal and copy without using zlib.
Reference checks call the Python runtime's system zlib. Receipts
contain JSON values; reconstructed bytes are compared inside the helpers.
"""

import hashlib
import zlib


_LENGTH_BASE = (
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
)
_LENGTH_EXTRA = (0,) * 8 + (1,) * 4 + (2,) * 4 + (3,) * 4 + (4,) * 4 + (5,) * 4 + (0,)
_DISTANCE_BASE = (
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193,
    12289, 16385, 24577,
)
_DISTANCE_EXTRA = (0,) * 4 + tuple(value for value in range(1, 14) for _ in range(2))
_CODE_LENGTH_ORDER = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15)


def require(condition: bool, context: str) -> None:
    """Keep validation active when Python is run with optimization enabled."""
    if not condition:
        raise AssertionError(context)


def adler32(data: bytes) -> int:
    """Compute RFC 1950's checksum independently of the system zlib."""
    low, high = 1, 0
    for start in range(0, len(data), 5552):
        for value in data[start:start + 5552]:
            low += value
            high += low
        low %= 65521
        high %= 65521
    return (high << 16) | low


class _Bits:
    def __init__(self, wire: bytes):
        self.wire = wire
        self.position = 0

    def read(self, count: int) -> int:
        require(0 <= count <= 16, "invalid DEFLATE bit-read width")
        require(self.position + count <= len(self.wire) * 8,
                f"truncated DEFLATE at bit {self.position}")
        value = 0
        for shift in range(count):
            value |= ((self.wire[self.position >> 3] >> (self.position & 7)) & 1) << shift
            self.position += 1
        return value

    def align(self) -> None:
        self.position = (self.position + 7) & ~7

    def bytes(self, count: int) -> bytes:
        require(self.position & 7 == 0, "unaligned stored DEFLATE block")
        start = self.position >> 3
        require(start + count <= len(self.wire),
                f"truncated stored DEFLATE block at byte {start}")
        self.position += count * 8
        return self.wire[start:start + count]


def _reverse(code: int, width: int) -> int:
    result = 0
    for _ in range(width):
        result = (result << 1) | (code & 1)
        code >>= 1
    return result


class _Huffman:
    def __init__(self, lengths, name: str, *, allow_empty=False, allow_single=True):
        require(all(0 <= width <= 15 for width in lengths), f"invalid {name} code length")
        self.name = name
        self.max_width = max(lengths, default=0)
        self.codes = {}
        if not self.max_width:
            require(allow_empty, f"empty {name} Huffman tree")
            return
        counts = [0] * 16
        for width in lengths:
            if width:
                counts[width] += 1
        available = 1
        for width in range(1, 16):
            available = available * 2 - counts[width]
            require(available >= 0, f"oversubscribed {name} Huffman tree")
        require(available == 0 or (allow_single and self.max_width == 1 and counts[1] == 1),
                f"incomplete {name} Huffman tree")
        next_code = [0] * 16
        code = 0
        for width in range(1, 16):
            code = (code + counts[width - 1]) << 1
            next_code[width] = code
        for symbol, width in enumerate(lengths):
            if width:
                self.codes[width, _reverse(next_code[width], width)] = symbol
                next_code[width] += 1

    def decode(self, bits: _Bits) -> int:
        require(self.max_width != 0, f"copy requires a nonempty {self.name} Huffman tree")
        code = 0
        for width in range(1, self.max_width + 1):
            code |= bits.read(1) << (width - 1)
            symbol = self.codes.get((width, code))
            if symbol is not None:
                return symbol
        raise AssertionError(f"invalid {self.name} Huffman code at bit {bits.position}")


def _fixed_trees():
    literals = [8] * 144 + [9] * 112 + [7] * 24 + [8] * 8
    return _Huffman(literals, "literal/length"), _Huffman([5] * 32, "distance")


def _dynamic_trees(bits: _Bits):
    literal_count = bits.read(5) + 257
    distance_count = bits.read(5) + 1
    code_count = bits.read(4) + 4
    require(literal_count <= 286, "reserved dynamic DEFLATE literal/length count")
    code_lengths = [0] * 19
    for index in range(code_count):
        code_lengths[_CODE_LENGTH_ORDER[index]] = bits.read(3)
    code_tree = _Huffman(code_lengths, "code-length", allow_single=False)
    lengths = []
    total = literal_count + distance_count
    while len(lengths) < total:
        symbol = code_tree.decode(bits)
        if symbol < 16:
            lengths.append(symbol)
            continue
        if symbol == 16:
            require(bool(lengths), "DEFLATE repeat code 16 has no previous length")
            value, count = lengths[-1], bits.read(2) + 3
        elif symbol == 17:
            value, count = 0, bits.read(3) + 3
        else:
            value, count = 0, bits.read(7) + 11
        require(len(lengths) + count <= total, "DEFLATE code-length repeat exceeds tree extent")
        lengths.extend([value] * count)
    require(lengths[256] != 0, "DEFLATE literal/length tree has no end-of-block code")
    return (_Huffman(lengths[:literal_count], "literal/length"),
            _Huffman(lengths[literal_count:], "distance", allow_empty=True))


def inspect_deflate(wire: bytes, expected: bytes, window_bits: int = 15,
                    dictionary: bytes | None = None) -> dict:
    """Decode one raw RFC 1951 stream and return a JSON-safe receipt.

    Output is bounded by len(expected), including during overlapping copies.
    Only the last 2**window_bits bytes of dictionary enter DEFLATE history.
    The final block must occupy exactly wire, allowing its final byte's padding.
    All bit/byte positions in this receipt are relative to the raw stream.
    """
    require(8 <= window_bits <= 15, "DEFLATE window_bits must be between 8 and 15")
    window = 1 << window_bits
    history = dictionary[-window:] if dictionary is not None else b""
    bits = _Bits(wire)
    output = bytearray()
    blocks = []
    literal_total, copy_total, copy_bytes, max_distance = 0, 0, 0, 0
    while True:
        start_bit = bits.position
        start_output = len(output)
        final, kind = bool(bits.read(1)), bits.read(2)
        require(kind != 3, f"reserved DEFLATE block type at bit {start_bit}")
        literals, copies, block_copy_bytes, block_max_distance = 0, 0, 0, 0
        if kind == 0:
            bits.align()
            length, inverse_length = bits.read(16), bits.read(16)
            require(length ^ inverse_length == 0xffff, "stored DEFLATE LEN/NLEN mismatch")
            require(len(output) + length <= len(expected), "stored DEFLATE exceeds expected output bound")
            output.extend(bits.bytes(length))
            literals = length
        else:
            literal_tree, distance_tree = _fixed_trees() if kind == 1 else _dynamic_trees(bits)
            while True:
                symbol = literal_tree.decode(bits)
                if symbol < 256:
                    require(len(output) < len(expected), "DEFLATE literal exceeds expected output bound")
                    output.append(symbol)
                    literals += 1
                elif symbol == 256:
                    break
                else:
                    require(symbol <= 285, "reserved DEFLATE length symbol")
                    length_index = symbol - 257
                    length = _LENGTH_BASE[length_index] + bits.read(_LENGTH_EXTRA[length_index])
                    distance_symbol = distance_tree.decode(bits)
                    require(distance_symbol < 30, "reserved DEFLATE distance symbol")
                    distance = _DISTANCE_BASE[distance_symbol] + bits.read(_DISTANCE_EXTRA[distance_symbol])
                    require(distance <= window, f"DEFLATE distance {distance} exceeds window {window}")
                    require(distance <= len(history) + len(output), "DEFLATE copy precedes available history")
                    require(len(output) + length <= len(expected), "DEFLATE copy exceeds expected output bound")
                    for _ in range(length):
                        source = len(history) + len(output) - distance
                        output.append(history[source] if source < len(history) else output[source - len(history)])
                    copies += 1
                    block_copy_bytes += length
                    block_max_distance = max(block_max_distance, distance)
        literal_total += literals
        copy_total += copies
        copy_bytes += block_copy_bytes
        max_distance = max(max_distance, block_max_distance)
        blocks.append({
            "type": ("stored", "fixed", "dynamic")[kind], "final": final,
            "start_bit": start_bit, "end_bit": bits.position,
            "start_output": start_output, "end_output": len(output),
            "literals": literals, "copies": copies, "copy_bytes": block_copy_bytes,
            "max_distance": block_max_distance,
        })
        if final:
            break
    end_byte = (bits.position + 7) // 8
    require(end_byte == len(wire), f"DEFLATE trailing bytes: consumed {end_byte}, supplied {len(wire)}")
    require(output == expected, "independent DEFLATE reconstruction differs from expected payload")
    padding_bits = end_byte * 8 - bits.position
    padding_value = wire[-1] >> (8 - padding_bits) if padding_bits else 0
    return {
        "decoded_bytes": len(output), "output_sha256": hashlib.sha256(output).hexdigest(),
        "literals": literal_total, "copies": copy_total, "copy_bytes": copy_bytes,
        "max_distance": max_distance, "window_bytes": window,
        "dictionary_history_bytes": len(history), "end_bit": bits.position,
        "end_byte": end_byte, "padding_bits": padding_bits, "padding_value": padding_value,
        "blocks": blocks,
    }


def inspect_zlib(wire: bytes, expected: bytes, window_bits: int,
                 dictionary: bytes | None = None,
                 has_dictionary_expected: bool | None = None) -> dict:
    """Validate a complete RFC 1950 stream with an independent raw decoder.

    By default dictionary=None expects no FDICT, while dictionary=b'' expects
    FDICT with DICTID=1. Pass has_dictionary_expected explicitly when the
    producer intentionally treats an empty configured dictionary as absent.
    A dictionary supplied for a stream without FDICT does not seed its history.
    """
    require(8 <= window_bits <= 15, "zlib window_bits must be between 8 and 15")
    require(len(wire) >= 7, "truncated zlib header/body/footer")
    cmf, flg = wire[0], wire[1]
    require(cmf & 15 == 8, "zlib CM must specify DEFLATE")
    require(cmf >> 4 <= 7, "reserved zlib CINFO window size")
    require(((cmf << 8) | flg) % 31 == 0, "invalid zlib FCHECK")
    advertised_bits = (cmf >> 4) + 8
    require(advertised_bits == window_bits,
            f"zlib CINFO advertises {advertised_bits} bits, expected {window_bits}")
    has_dictionary = bool(flg & 0x20)
    if has_dictionary_expected is None:
        has_dictionary_expected = dictionary is not None
    require(has_dictionary == has_dictionary_expected, "zlib FDICT differs from expected dictionary presence")
    body_offset, dictionary_id = 2, None
    active_dictionary = None
    if has_dictionary:
        require(len(wire) >= 11, "truncated zlib DICTID/body/footer")
        require(dictionary is not None, "zlib FDICT requires a supplied dictionary")
        dictionary_id = int.from_bytes(wire[2:6], "big")
        require(dictionary_id == adler32(dictionary), "zlib DICTID differs from full dictionary Adler-32")
        body_offset, active_dictionary = 6, dictionary
    body = wire[body_offset:-4]
    raw_receipt = inspect_deflate(body, expected, window_bits, active_dictionary)
    footer = int.from_bytes(wire[-4:], "big")
    expected_adler = adler32(expected)
    require(footer == expected_adler, "zlib Adler-32 footer differs from expected payload")
    decoder = (zlib.decompressobj(wbits=window_bits, zdict=active_dictionary)
               if active_dictionary is not None else zlib.decompressobj(wbits=window_bits))
    # One excess byte exposes a decoder that would exceed the bounded plaintext.
    decoded = decoder.decompress(wire, len(expected) + 1)
    require(decoded == expected, "system zlib reconstruction differs from expected payload")
    require(decoder.eof, "system zlib did not reach EOF")
    require(not decoder.unused_data, "system zlib left unused input")
    require(not decoder.unconsumed_tail, "system zlib left unconsumed input")
    require(decoder.flush() == b"", "system zlib retained output after EOF")
    return {
        "wire_bytes": len(wire), "decoded_bytes": len(expected),
        "cmf": cmf, "flg": flg, "fcheck": flg & 31, "flevel": flg >> 6,
        "window_bits": advertised_bits, "window_bytes": 1 << advertised_bits,
        "fdict": has_dictionary, "dictionary_id": dictionary_id,
        "dictionary_bytes": len(dictionary) if dictionary is not None else None,
        "deflate_offset": body_offset, "deflate_bytes": len(body),
        "deflate_end_bit": body_offset * 8 + raw_receipt["end_bit"],
        "deflate_end_byte": body_offset + raw_receipt["end_byte"],
        "footer_offset": len(wire) - 4, "adler32": footer,
        "deflate": raw_receipt,
        "system_zlib": {"eof": decoder.eof, "unused_bytes": len(decoder.unused_data),
                        "unconsumed_bytes": len(decoder.unconsumed_tail)},
    }


def fixed_window9_distance_fixture(distance: int) -> tuple[bytes, bytes]:
    """Handwrite literals then one length-3 copy at distance 512 or 513.

    Return (zlib_wire, expected_plaintext). The prefix has exactly distance
    bytes, so the copy begins at that output offset. Fixed Huffman codes come
    directly from RFC 1951; this fixture does not invoke any compressor.
    """
    require(distance in (512, 513), "boundary fixture distance must be 512 or 513")
    packed_bits = []

    def number(value, width):
        packed_bits.extend((value >> shift) & 1 for shift in range(width))

    def code(value, width):
        packed_bits.extend((value >> shift) & 1 for shift in reversed(range(width)))

    prefix = bytes((index * 73 + 19) & 255 for index in range(distance))
    number(3, 3)  # BFINAL=1 and BTYPE=01 (fixed).
    for value in prefix:
        if value <= 143:
            code(0x30 + value, 8)
        else:
            code(0x190 + value - 144, 9)
    code(1, 7)  # Fixed length symbol 257 encodes length 3.
    code(17 if distance == 512 else 18, 5)
    number(127 if distance == 512 else 0, 7 if distance == 512 else 8)
    code(0, 7)  # Fixed end-of-block symbol 256.
    raw = bytearray((len(packed_bits) + 7) // 8)
    for position, bit in enumerate(packed_bits):
        raw[position // 8] |= bit << (position & 7)
    cmf = 0x18  # DEFLATE with CINFO=1: a 512-byte window.
    flg = (31 - ((cmf << 8) % 31)) % 31
    expected = prefix + prefix[:3]
    wire = bytes((cmf, flg)) + raw + adler32(expected).to_bytes(4, "big")
    return wire, expected


def window_distance_selfcheck() -> dict:
    """Prove the window-9 boundary with bounded, separate output buffers.

    Some libz builds accept distance 513 when the whole literal prefix remains
    in the current output buffer. Pause exactly after that prefix, then provide
    a new 17-byte output buffer: libz must use its retained 512-byte window.
    Distance 512 must complete; distance 513 must report Z_DATA_ERROR (-3).
    The independent parser enforces the advertised limit in either situation.
    """
    cases = []
    for distance in (512, 513):
        wire, expected = fixed_window9_distance_fixture(distance)
        unrestricted = inspect_deflate(wire[2:-4], expected, 15)
        require(unrestricted["literals"] == distance and unrestricted["copies"] == 1
                and unrestricted["copy_bytes"] == 3 and unrestricted["max_distance"] == distance,
                "handwritten fixed fixture differs from its literal/copy specification")
        try:
            strict = inspect_deflate(wire[2:-4], expected, 9)
        except AssertionError as error:
            require(distance == 513 and str(error) == "DEFLATE distance 513 exceeds window 512",
                    f"unexpected strict parser rejection: {error}")
            raw_parser = {"accepted": False, "error": str(error)}
        else:
            require(distance == 512 and strict["max_distance"] == 512,
                    "independent parser accepted an over-window copy")
            raw_parser = {"accepted": True, "max_distance": strict["max_distance"]}

        oneshot_decoder = zlib.decompressobj(wbits=9)
        try:
            decoded = oneshot_decoder.decompress(wire, len(expected) + 1)
        except zlib.error as error:
            require(distance == 513 and str(error).startswith("Error -3 "),
                    f"unexpected oneshot libz rejection: {error}")
            oneshot = {"accepted": False, "status": "data_error", "error": str(error)}
        else:
            require(decoded == expected and oneshot_decoder.eof
                    and not oneshot_decoder.unused_data and not oneshot_decoder.unconsumed_tail,
                    "oneshot libz reference did not consume the exact boundary fixture")
            oneshot = {"accepted": True, "status": "stream_end", "decoded_bytes": len(decoded)}

        decoder = zlib.decompressobj(wbits=9)
        prefix = decoder.decompress(wire, distance)
        require(prefix == expected[:distance] and len(prefix) == distance,
                "microstep libz did not stop at the exact pre-copy output offset")
        remaining = decoder.unconsumed_tail
        require(not decoder.eof and bool(remaining) and not decoder.unused_data,
                "microstep libz must pause with unconsumed match/trailer input")
        microstep = {"prefix_output_bytes": len(prefix), "prefix_eof": decoder.eof,
                     "remaining_input_bytes": len(remaining), "tail_buffer_bytes": 17}
        try:
            tail = decoder.decompress(remaining, 17)
        except zlib.error as error:
            require(distance == 513 and str(error).startswith("Error -3 "),
                    f"unexpected microstep libz rejection: {error}")
            microstep.update({"accepted": False, "status": "data_error", "zlib_status": -3,
                              "error": str(error)})
        else:
            require(distance == 512 and prefix + tail == expected and decoder.eof
                    and not decoder.unused_data and not decoder.unconsumed_tail,
                    "microstep libz must complete only the legal distance-512 fixture")
            microstep.update({"accepted": True, "status": "stream_end", "zlib_status": 1,
                              "tail_output_bytes": len(tail), "eof": decoder.eof})
        cases.append({"distance": distance, "wire_bytes": len(wire),
                      "decoded_bytes": len(expected), "raw_parser": raw_parser,
                      "oneshot_libz": oneshot, "microstep_libz": microstep})
    return {
        "window_bits": 9, "system_zlib_version": zlib.ZLIB_RUNTIME_VERSION,
        "fixture": "handwritten RFC 1951 fixed literals and one length-3 copy",
        "oneshot_libz_may_accept": cases[1]["oneshot_libz"]["accepted"],
        "raw_parser_strict": True,
        "microstep_accept_distance": 512, "microstep_reject_distance": 513,
        "cases": cases,
    }
