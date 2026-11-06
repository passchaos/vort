"""Independent bounded Python/libz validation of generated encoder wire."""
import hashlib
import zlib

CHUNK = 65536
REPEAT = b"R" * CHUNK
ZERO = bytes(CHUNK)


def require(ok, detail):
    if not ok:
        raise AssertionError(detail)


def check_output(output, offset, count, pattern):
    expected = REPEAT[:len(output)] if pattern == "repeat" else ZERO[:len(output)]
    if pattern == "dirty" and offset <= count - 1 < offset + len(output):
        dirty = count - 1 - offset
        require(output[dirty] == 1, "oracle final dirty byte")
        require(output[:dirty] == expected[:dirty] and output[dirty + 1:] == expected[dirty + 1:], "oracle zero prefix/suffix")
    else:
        require(output == expected, "oracle output content")


def inflate_stream(source, family, pattern, count, on_progress=None):
    wbits = -15 if family.startswith("raw_") else 31 if family.startswith("gzip_") else 15
    decoder = zlib.decompressobj(wbits)
    receipt = dict(input_read=0, output_written=0, source_bytes=0, calls=0,
                   crc32=0, adler32=1, completed=False, all_output_bytes_checked=True)
    wire_hash = hashlib.sha256()
    first, last = b"", b""
    next_progress = 256 * 1024 * 1024
    while piece := source.read(CHUNK):
        require(not decoder.eof, "oracle wire after EOF")
        receipt["source_bytes"] += len(piece)
        wire_hash.update(piece)
        first += piece[:max(0, 10 - len(first))]
        last = (last + piece)[-8:]
        pending = piece
        while True:
            before = len(pending)
            output = decoder.decompress(pending, CHUNK)
            consumed = before - len(decoder.unconsumed_tail) - len(decoder.unused_data)
            require(consumed >= 0, "oracle input receipt")
            receipt["input_read"] += consumed
            check_output(output, receipt["output_written"], count, pattern)
            receipt["output_written"] += len(output)
            receipt["calls"] += 1
            receipt["crc32"] = zlib.crc32(output, receipt["crc32"])
            receipt["adler32"] = zlib.adler32(output, receipt["adler32"])
            require(receipt["output_written"] <= count, "oracle excess decoded bytes")
            if on_progress and receipt["output_written"] >= next_progress:
                on_progress(dict(receipt))
                next_progress = receipt["output_written"] + 256 * 1024 * 1024
            pending = decoder.unconsumed_tail
            if decoder.eof:
                require(not pending and not decoder.unused_data, "oracle trailing bytes")
                break
            if not pending and len(output) < CHUNK:
                break
            require(consumed or output, "oracle no progress")
    require(decoder.eof, "oracle truncated wire")
    require(receipt["input_read"] == receipt["source_bytes"], "oracle complete input receipt")
    require(receipt["output_written"] == count, "oracle complete output receipt")
    receipt["crc32"] &= 0xFFFFFFFF
    receipt["adler32"] &= 0xFFFFFFFF
    if wbits == 31:
        require(first[:3] == b"\x1f\x8b\x08" and not first[3] & 0xE0, "gzip header")
        require(int.from_bytes(last[:4], "little") == receipt["crc32"], "gzip CRC footer")
        require(int.from_bytes(last[4:], "little") == count & 0xFFFFFFFF, "gzip ISIZE footer")
    elif wbits == 15:
        require(len(first) >= 2 and first[0] & 15 == 8 and int.from_bytes(first[:2], "big") % 31 == 0, "zlib header")
        require(int.from_bytes(last[-4:], "big") == receipt["adler32"], "zlib Adler footer")
    receipt.update(completed=True, wire_sha256=wire_hash.hexdigest(), wbits=wbits,
                   footer_checked=wbits != -15, wire_prefix_hex=first.hex(), wire_suffix_hex=last.hex())
    return receipt
