#!/usr/bin/env python3
"""Small LZ4 frame fixtures shared by native-summary smoke tests."""

from __future__ import annotations

import struct

MASK32 = 0xFFFF_FFFF
XXH32_PRIME1 = 0x9E37_79B1
XXH32_PRIME2 = 0x85EB_CA77
XXH32_PRIME3 = 0xC2B2_AE3D
XXH32_PRIME4 = 0x27D4_EB2F
XXH32_PRIME5 = 0x1656_67B1


def _rotl32(value: int, shift: int) -> int:
    return ((value << shift) | (value >> (32 - shift))) & MASK32


def _round32(acc: int, lane: int) -> int:
    acc = (acc + lane * XXH32_PRIME2) & MASK32
    acc = _rotl32(acc, 13)
    return (acc * XXH32_PRIME1) & MASK32


def xxh32(data: bytes, seed: int = 0) -> int:
    """Return XXH32(data, seed) using the canonical little-endian algorithm."""

    offset = 0
    length = len(data)
    seed &= MASK32
    if length >= 16:
        v1 = (seed + XXH32_PRIME1 + XXH32_PRIME2) & MASK32
        v2 = (seed + XXH32_PRIME2) & MASK32
        v3 = seed
        v4 = (seed - XXH32_PRIME1) & MASK32
        limit = length - 16
        while offset <= limit:
            v1 = _round32(v1, struct.unpack_from("<I", data, offset)[0])
            offset += 4
            v2 = _round32(v2, struct.unpack_from("<I", data, offset)[0])
            offset += 4
            v3 = _round32(v3, struct.unpack_from("<I", data, offset)[0])
            offset += 4
            v4 = _round32(v4, struct.unpack_from("<I", data, offset)[0])
            offset += 4
        digest = (_rotl32(v1, 1) + _rotl32(v2, 7) + _rotl32(v3, 12) + _rotl32(v4, 18)) & MASK32
    else:
        digest = (seed + XXH32_PRIME5) & MASK32

    digest = (digest + length) & MASK32
    while offset + 4 <= length:
        digest = (digest + struct.unpack_from("<I", data, offset)[0] * XXH32_PRIME3) & MASK32
        digest = (_rotl32(digest, 17) * XXH32_PRIME4) & MASK32
        offset += 4
    while offset < length:
        digest = (digest + data[offset] * XXH32_PRIME5) & MASK32
        digest = (_rotl32(digest, 11) * XXH32_PRIME1) & MASK32
        offset += 1

    digest ^= digest >> 15
    digest = (digest * XXH32_PRIME2) & MASK32
    digest ^= digest >> 13
    digest = (digest * XXH32_PRIME3) & MASK32
    digest ^= digest >> 16
    return digest & MASK32


def frame_descriptor_checksum(descriptor: bytes) -> int:
    """Return the LZ4 frame descriptor checksum byte."""

    return (xxh32(descriptor, 0) >> 8) & 0xFF


def skippable_frame(skippable_id: int, payload: bytes) -> bytes:
    if not 0 <= skippable_id <= 15:
        raise ValueError(skippable_id)
    return struct.pack("<II", 0x184D2A50 + skippable_id, len(payload)) + payload


def dictionary_id_raw_frame(dictionary_id: int, payload: bytes) -> bytes:
    """Build a valid LZ4 raw-block frame carrying a Dictionary_ID.

    The frame is intentionally self-contained for summary probes: the block is
    stored raw, so summary parsing can validate Dictionary_ID/header accounting
    without needing to decode with a preset dictionary.
    """

    if not 0 < dictionary_id <= MASK32:
        raise ValueError(dictionary_id)
    if len(payload) > 64 * 1024:
        raise ValueError("fixture keeps the 64 KiB block-size descriptor")
    descriptor = b"\x69\x40" + struct.pack("<Q", len(payload)) + struct.pack("<I", dictionary_id)
    return (
        struct.pack("<I", 0x184D2204)
        + descriptor
        + bytes([frame_descriptor_checksum(descriptor)])
        + struct.pack("<I", 0x8000_0000 | len(payload))
        + payload
        + b"\x00\x00\x00\x00"
    )
