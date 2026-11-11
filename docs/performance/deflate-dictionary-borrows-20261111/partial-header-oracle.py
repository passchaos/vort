import json
import zlib

bits = []
def put(value, count):
    bits.extend((value >> index) & 1 for index in range(count))
def reverse(value, count):
    return int(f"{value:0{count}b}"[::-1], 2)
put(2, 3)
for _ in range(5):
    put(reverse(0x190, 9), 9)
put(0, 7)
assert len(bits) == 55
put(3, 3)
put(reverse(0x30 + ord("A"), 8), 8)
put(0, 7)
wire = bytes(sum(bit << offset for offset, bit in enumerate(bits[start:start+8]))
             for start in range(0, len(bits), 8))
assert wire.hex() == "9a3061c2840980390200"
assert zlib.decompress(wire, -15) == b"\x90" * 5 + b"A"
assert zlib.decompress(bytes.fromhex("730400"), -15) == b"A"
assert zlib.decompress(bytes.fromhex("010300fcff616263"), -15) == b"abc"
print(json.dumps({"zlib_runtime": zlib.ZLIB_RUNTIME_VERSION,
                  "partial_header_hex": wire.hex(), "first_block_bits": 55,
                  "stop_bytes": 7, "buffered_next_header_bits": 1,
                  "partial_header_output_hex": (b"\x90" * 5 + b"A").hex(),
                  "literal_hex": "730400", "stored_hex": "010300fcff616263"}, indent=2))
