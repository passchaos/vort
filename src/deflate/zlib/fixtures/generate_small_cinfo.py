"""Build an independent fixed-Huffman zlib compatibility fixture."""
import hashlib
from pathlib import Path
import zlib


def generate():
    bits = []

    def emit(value, count):
        bits.extend((value >> i) & 1 for i in range(count))

    def symbol(value):
        if value < 144:
            code, width = 0x30 + value, 8
        elif value < 256:
            code, width = 0x190 + value - 144, 9
        elif value < 280:
            code, width = value - 256, 7
        else:
            code, width = 0xC0 + value - 280, 8
        emit(int(f"{code:0{width}b}"[::-1], 2), width)

    emit(3, 3)  # BFINAL=1, BTYPE=fixed Huffman.
    prefix = bytes(range(256)) + b"\xa5"
    for value in prefix:
        symbol(value)
    symbol(284)
    emit(30, 5)  # Length 227 + 30 = 257.
    emit(1, 5)  # Reversed five-bit distance symbol 16.
    emit(0, 7)  # Distance 257 + 0 = 257.
    symbol(256)
    body = bytes(
        sum(bits[i + j] << j for j in range(min(8, len(bits) - i)))
        for i in range(0, len(bits), 8)
    )
    payload = prefix * 2
    wire = b"\x08\x1d" + body + zlib.adler32(payload).to_bytes(4, "big")
    assert zlib.decompress(wire) == payload
    return wire


if __name__ == "__main__":
    wire = generate()
    Path(__file__).with_name("small-cinfo-distance-257.zlib").write_bytes(wire)
    print(zlib.ZLIB_RUNTIME_VERSION, len(wire), hashlib.sha256(wire).hexdigest())
