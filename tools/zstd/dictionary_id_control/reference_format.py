"""Frame and entropy metadata inspection for dictionary-control fixtures."""
from __future__ import annotations

MAGIC = bytes.fromhex("28b52ffd")


def frame_header(wire: bytes, format: str = "standard") -> dict:
    """Inspect one header without relying on libzstd's dictionary-ID shortcut."""
    wire = bytes(wire)
    if format not in ("standard", "magicless"):
        raise ValueError(f"Unknown frame format {format!r}")
    offset = 4 if format == "standard" else 0
    if format == "standard" and not wire.startswith(MAGIC):
        raise ValueError("Missing standard Zstd magic")
    if len(wire) <= offset:
        raise ValueError("Truncated frame descriptor")
    descriptor = wire[offset]
    if descriptor & 0x18:
        raise ValueError("Reserved or unused frame descriptor bit")
    offset += 1
    single_segment = bool(descriptor & 0x20)
    window_size = None
    if not single_segment:
        if len(wire) <= offset:
            raise ValueError("Truncated window descriptor")
        window_descriptor = wire[offset]
        base = 1 << (10 + (window_descriptor >> 3))
        window_size = base + (base >> 3) * (window_descriptor & 7)
        offset += 1
    id_flag = descriptor & 3
    id_size = (0, 1, 2, 4)[id_flag]
    size_flag = descriptor >> 6
    size_size = (int(single_segment), 2, 4, 8)[size_flag]
    if len(wire) < offset + id_size + size_size:
        raise ValueError("Truncated dictionary ID or content size")
    dictionary_id = int.from_bytes(wire[offset:offset + id_size], "little")
    offset += id_size
    content_size = None
    if size_size:
        content_size = int.from_bytes(wire[offset:offset + size_size], "little")
        if size_size == 2:
            content_size += 256
        offset += size_size
    if single_segment:
        window_size = content_size
    return {"format": format, "descriptor": descriptor, "dictionary_id_flag": id_flag,
            "dictionary_id_size": id_size, "dictionary_id": dictionary_id,
            "single_segment": single_segment, "content_size": content_size,
            "checksum": bool(descriptor & 4), "window_size": window_size,
            "header_size": offset}


def entropy_modes(wire: bytes, format: str = "standard") -> list[dict]:
    """Read literal and sequence modes, proving first-block dictionary repeats.

    This is a small metadata reader for generated fixtures, not a decoder.
    Literal type 3 means the dictionary/previous block Huffman table is used;
    sequence mode 3 means the corresponding dictionary/previous FSE table.
    """
    offset = frame_header(wire, format)["header_size"]
    blocks = []
    while True:
        if offset + 3 > len(wire):
            raise ValueError("Truncated block header")
        header = int.from_bytes(wire[offset:offset + 3], "little")
        offset += 3
        last, kind, size = bool(header & 1), (header >> 1) & 3, header >> 3
        if kind == 3:
            raise ValueError("Reserved block type")
        stored = 1 if kind == 1 else size
        body = wire[offset:offset + stored]
        if len(body) != stored:
            raise ValueError("Truncated block body")
        block = {"block_index": len(blocks), "block_type": kind, "block_size": size,
                 "last": last}
        if kind == 2:
            if not body:
                raise ValueError("Empty compressed block")
            literal_type, size_format = body[0] & 3, (body[0] >> 2) & 3
            if literal_type < 2:
                header_size = 1 if size_format in (0, 2) else (2 if size_format == 1 else 3)
                value = int.from_bytes(body[:header_size], "little")
                regenerated = value >> (3 if header_size == 1 else 4)
                compressed = 1 if literal_type == 1 else regenerated
            else:
                header_size = 3 if size_format < 2 else size_format + 2
                value = int.from_bytes(body[:header_size], "little")
                bits = (10, 10, 14, 18)[size_format]
                regenerated = (value >> 4) & ((1 << bits) - 1)
                compressed = (value >> (4 + bits)) & ((1 << bits) - 1)
            sequence_offset = header_size + compressed
            if sequence_offset >= len(body):
                raise ValueError("Truncated sequence count")
            first = body[sequence_offset]
            sequence_offset += 1
            count = first
            if first >= 128:
                extra = 2 if first == 255 else 1
                if sequence_offset + extra > len(body):
                    raise ValueError("Truncated extended sequence count")
                count = (0x7f00 + int.from_bytes(body[sequence_offset:sequence_offset + 2], "little")
                         if first == 255 else ((first - 128) << 8) + body[sequence_offset])
                sequence_offset += extra
            block.update(literal_type=literal_type, literal_size=regenerated,
                         sequence_count=count)
            if count:
                if sequence_offset >= len(body):
                    raise ValueError("Truncated sequence modes")
                modes = body[sequence_offset]
                block["sequence_modes"] = {"literal_length": modes >> 6,
                                           "offset": (modes >> 4) & 3,
                                           "match_length": (modes >> 2) & 3}
        blocks.append(block)
        offset += stored
        if last:
            return blocks
