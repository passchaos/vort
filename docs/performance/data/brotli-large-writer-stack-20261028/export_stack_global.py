"""Expose the existing mutable stack global for diagnosis; do not alter its value."""
from pathlib import Path
import sys

def read_uleb(data, position):
    value = shift = 0
    while True:
        byte = data[position]
        position += 1
        value |= (byte & 127) << shift
        if not byte & 128:
            return value, position
        shift += 7

def uleb(value):
    result = bytearray()
    while True:
        byte = value & 127
        value >>= 7
        result.append(byte | (128 if value else 0))
        if not value:
            return bytes(result)

binary = Path(sys.argv[1]).read_bytes()
assert binary[:8] == bytes.fromhex("0061736d01000000")
result = bytearray(binary[:8])
position = 8
while position < len(binary):
    section_id = binary[position]
    size, start = read_uleb(binary, position + 1)
    payload = binary[start:start + size]
    position = start + size
    if section_id == 6:
        count, global_start = read_uleb(payload, 0)
        assert count == 1 and payload[global_start:global_start + 3] == bytes.fromhex("7f0141"), "expected sole mutable i32 stack global"
    if section_id == 7:
        count, body_start = read_uleb(payload, 0)
        name = b"reviewStackPointer"
        payload = uleb(count + 1) + payload[body_start:] + uleb(len(name)) + name + bytes([3, 0])
    result.extend(bytes([section_id]) + uleb(len(payload)) + payload)
Path(sys.argv[2]).write_bytes(result)
