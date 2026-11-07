"""Independent frame/block/sequence metadata for real C-produced fixtures."""
MAGIC = bytes.fromhex("28b52ffd")


def frame_header(wire, format="standard"):
    offset = 4 if format == "standard" else 0
    if format == "standard" and not wire.startswith(MAGIC):
        raise ValueError("Missing frame magic")
    descriptor = wire[offset]
    if descriptor & 0x18:
        raise ValueError("Reserved frame descriptor bits")
    offset += 1
    single = bool(descriptor & 0x20)
    window = None
    if not single:
        wd = wire[offset]
        base = 1 << (10 + (wd >> 3))
        window = base + (base >> 3) * (wd & 7)
        offset += 1
    dictionary_size = (0, 1, 2, 4)[descriptor & 3]
    dictionary_id = int.from_bytes(wire[offset:offset + dictionary_size], "little")
    offset += dictionary_size
    size_size = (int(single), 2, 4, 8)[descriptor >> 6]
    size = int.from_bytes(wire[offset:offset + size_size], "little") if size_size else None
    if size_size == 2:
        size += 256
    offset += size_size
    return {"header_size": offset, "content_size": size, "checksum": bool(descriptor & 4),
            "dictionary_id": dictionary_id, "single_segment": single,
            "window_size": size if single else window, "format": format}


def blocks(wire, format="standard"):
    header = frame_header(wire, format)
    offset, result = header["header_size"], []
    while True:
        block_start = offset
        value = int.from_bytes(wire[offset:offset + 3], "little")
        offset += 3
        last, kind, size = bool(value & 1), (value >> 1) & 3, value >> 3
        if kind == 3:
            raise ValueError("Reserved block type")
        stored = 1 if kind == 1 else size
        body = wire[offset:offset + stored]
        if len(body) != stored:
            raise ValueError("Truncated block body")
        record = {"offset": block_start, "block_type": kind, "stored_size": stored,
                  "block_size": size, "last": last, "sequence_count": 0}
        if kind == 2:
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
            seq = header_size + compressed
            first = body[seq]
            seq += 1
            count = first
            if first >= 128:
                count = 0x7f00 + int.from_bytes(body[seq:seq + 2], "little") if first == 255 else ((first - 128) << 8) + body[seq]
                seq += 2 if first == 255 else 1
            record.update(literal_type=literal_type, literal_size=regenerated, sequence_count=count)
            if count:
                modes = body[seq]
                record["sequence_modes"] = {"literal_length": modes >> 6, "offset": (modes >> 4) & 3,
                                            "match_length": (modes >> 2) & 3}
        result.append(record)
        offset += stored
        if last:
            break
    return header, result, offset + (4 if header["checksum"] else 0)


def inspect_stream(wire, format="standard"):
    offset, frames = 0, []
    while offset < len(wire):
        if format == "standard" and len(wire) - offset >= 8 and int.from_bytes(wire[offset:offset + 4], "little") & 0xfffffff0 == 0x184d2a50:
            size = int.from_bytes(wire[offset + 4:offset + 8], "little")
            frames.append({"offset": offset, "skippable": True, "size": 8 + size})
            offset += 8 + size
            continue
        header, records, size = blocks(wire[offset:], format)
        frames.append({"offset": offset, "size": size, "skippable": False,
                       "header": header, "blocks": records,
                       "sequence_count": sum(block["sequence_count"] for block in records)})
        offset += size
    if offset != len(wire):
        raise ValueError("Frame sizes do not span input")
    return frames
