#!/usr/bin/env python3
"""Construct fixed dictionary matches from RFC 1951 and verify with zlib."""
import json
import zlib
from pathlib import Path


def fixed_match(distance_symbol, extra_value=0, extra_count=0):
    bits = []
    def put(value, count):
        bits.extend((value >> index) & 1 for index in range(count))
    def reverse(value, count):
        return int(f"{value:0{count}b}"[::-1], 2)
    def symbol(value):
        if value < 144:
            code, width = 0x30 + value, 8
        elif value < 256:
            code, width = 0x190 + value - 144, 9
        elif value < 280:
            code, width = value - 256, 7
        else:
            code, width = 0xc0 + value - 280, 8
        put(reverse(code, width), width)
    put(1, 1)  # final block
    put(1, 2)  # fixed Huffman block
    symbol(264)  # match length ten
    put(reverse(distance_symbol, 5), 5)
    put(extra_value, extra_count)
    symbol(256)
    return bytes(sum(bit << offset for offset, bit in enumerate(bits[start:start+8]))
                 for start in range(0, len(bits), 8))


def verify(raw, dictionary, output):
    decoder = zlib.decompressobj(wbits=-15, zdict=dictionary)
    assert decoder.decompress(raw) == output and decoder.eof
    wrapped = (b"\x78\x20" + zlib.adler32(dictionary).to_bytes(4, "big") + raw
               + zlib.adler32(output).to_bytes(4, "big"))
    decoder = zlib.decompressobj(zdict=dictionary)
    assert decoder.decompress(wrapped) == output and decoder.eof
    return {"raw_hex": raw.hex(), "zlib_hex": wrapped.hex(),
            "dictionary_hex": dictionary.hex(), "output_hex": output.hex()}


result = {"wire_source": "independent RFC 1951 fixed match bit writer",
          "python_zlib_runtime_version": zlib.ZLIB_RUNTIME_VERSION,
          "tail_match": verify(fixed_match(6, 1, 2), b"ABCDEFGHIJ", b"ABCDEFGHIJ"),
          "repeat_match": verify(fixed_match(0), b"A", b"A" * 10),
          "empty": verify(bytes.fromhex("0300"), b"", b"")}
try:
    zlib.decompress(fixed_match(6, 1, 2), wbits=-15)
except zlib.error as error:
    result["no_dictionary_error"] = str(error)
else:
    raise AssertionError("tail fixture must require a dictionary")
print(json.dumps(result, indent=2))
