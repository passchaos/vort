"""Small independent Zstd frame/block envelope reader; entropy stays opaque."""


def scan(wire):
    position, frames, skippables = 0, [], []
    def take(count):
        nonlocal position
        if count < 0 or position + count > len(wire): raise AssertionError("truncated Zstd envelope")
        result = wire[position:position + count]
        position += count
        return result
    while position < len(wire):
        start = position
        magic = int.from_bytes(take(4), "little")
        if 0x184d2a50 <= magic <= 0x184d2a5f:
            size = int.from_bytes(take(4), "little")
            take(size)
            skippables.append({"offset": start, "id": magic - 0x184d2a50, "payload_bytes": size})
            continue
        if magic != 0xfd2fb528: raise AssertionError("unexpected Zstd frame magic")
        descriptor = take(1)[0]
        if descriptor & 0x18: raise AssertionError("reserved Zstd frame descriptor")
        single, checksum = bool(descriptor & 0x20), bool(descriptor & 4)
        window = None
        if not single:
            wd = take(1)[0]
            base = 1 << (10 + (wd >> 3))
            window = base + (base >> 3) * (wd & 7)
        dictionary = int.from_bytes(take((0, 1, 2, 4)[descriptor & 3]), "little")
        width = (1 if single else 0, 2, 4, 8)[descriptor >> 6]
        content_size = int.from_bytes(take(width), "little") + (256 if width == 2 else 0) if width else None
        if single: window = content_size
        blocks = []
        while True:
            block_start = position
            packed = int.from_bytes(take(3), "little")
            final, kind, size = bool(packed & 1), (packed >> 1) & 3, packed >> 3
            if kind == 3 or size > 131072: raise AssertionError("invalid Zstd block envelope")
            payload_size = 1 if kind == 1 else size
            take(payload_size)
            blocks.append({"offset": block_start, "type": ("raw", "rle", "compressed")[kind], "payload_bytes": payload_size, "size_field": size, "last": final})
            if final: break
        trailer = int.from_bytes(take(4), "little") if checksum else None
        frames.append({"offset": start, "wire_bytes": position - start, "content_size": content_size, "window_size": window,
                       "dictionary_id": dictionary, "checksum": checksum, "checksum_trailer": trailer, "blocks": blocks})
    return {"frames": frames, "skippables": skippables, "wire_bytes": len(wire),
            "content_size_sum": sum(frame["content_size"] for frame in frames) if all(frame["content_size"] is not None for frame in frames) else None}
