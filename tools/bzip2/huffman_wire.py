"""Strict single-stream Bzip2 entropy inspection, without BWT or CRC decoding."""

from __future__ import annotations


BLOCK_MAGIC = 0x314159265359
END_MAGIC = 0x177245385090


class WireError(ValueError):
    """Malformed or truncated Bzip2 entropy wire."""


class _Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.position = 32

    def fail(self, message: str):
        raise WireError(f"bit {self.position}: {message}")

    def read(self, width: int) -> int:
        end = self.position + width
        if end > len(self.data) * 8:
            self.fail("truncated field or Huffman code")
        first = self.position // 8
        if width == 1:
            result = (self.data[first] >> (7 - self.position % 8)) & 1
        else:
            last = (end + 7) // 8
            result = (int.from_bytes(self.data[first:last], "big") >> (last * 8 - end)) & ((1 << width) - 1)
        self.position = end
        return result


def _table(reader: _Reader, lengths: list[int]) -> tuple[list[dict[int, int]], int]:
    counts = [0] * 21
    for length in lengths:
        counts[length] += 1
    by_width = [{} for _ in range(21)]
    code = 0
    for width in range(1, 21):
        code = (code + counts[width - 1]) << 1
        if code + counts[width] > 1 << width:
            reader.fail("oversubscribed Huffman lengths")
        for symbol, length in enumerate(lengths):
            if length == width:
                by_width[width][code] = symbol
                code += 1
        # The next recurrence uses the first code at this width.
        code -= counts[width]
    return by_width, max(lengths)


def _symbol(reader: _Reader, table: tuple[list[dict[int, int]], int]) -> int:
    by_width, maximum = table
    code = 0
    for width in range(1, maximum + 1):
        code = (code << 1) | reader.read(1)
        symbol = by_width[width].get(code)
        if symbol is not None:
            return symbol
    reader.fail("invalid Huffman code")


def _block(reader: _Reader, start: int, block_limit: int) -> dict:
    crc = reader.read(32)
    randomized = bool(reader.read(1))
    original = reader.read(24)
    bitmap_start = reader.position
    bitmap = reader.read(16)
    used = []
    for group in range(16):
        if bitmap & (1 << (15 - group)):
            low = reader.read(16)
            used.extend(group * 16 + bit for bit in range(16) if low & (1 << (15 - bit)))
    if not used:
        reader.fail("empty block alphabet")
    bitmap_bits = reader.position - bitmap_start
    entropy_start = reader.position
    groups = reader.read(3)
    selector_count = reader.read(15)
    if not 2 <= groups <= 6:
        reader.fail("Huffman group count outside 2..6")
    if not 1 <= selector_count <= 2 + block_limit // 50:
        reader.fail("invalid selector count")
    selector_start = reader.position
    selector_ranks, selectors = [], []
    mtf = list(range(groups))
    for _ in range(selector_count):
        rank = 0
        while reader.read(1):
            rank += 1
            if rank >= groups:
                reader.fail("selector MTF rank exceeds group count")
        selector_ranks.append(rank)
        selected = mtf.pop(rank)
        mtf.insert(0, selected)
        selectors.append(selected)
    selector_bits = reader.position - selector_start
    table_start = reader.position
    alphabet_size = len(used) + 2
    lengths, tables = [], []
    for _ in range(groups):
        current = reader.read(5)
        table_lengths = []
        for _ in range(alphabet_size):
            if not 1 <= current <= 20:
                reader.fail("Huffman length outside 1..20")
            while reader.read(1):
                current += -1 if reader.read(1) else 1
                if not 1 <= current <= 20:
                    reader.fail("Huffman length delta outside 1..20")
            table_lengths.append(current)
        lengths.append(table_lengths)
        tables.append(_table(reader, table_lengths))
    table_bits = reader.position - table_start
    data_start = reader.position
    histogram = [0] * alphabet_size
    data_bits_by_group = [0] * groups
    selector_index = symbol_count = transformed = 0
    remaining = selected = 0
    run = 0
    weight = 1
    run_sequences = run_bytes = 0
    while True:
        if remaining == 0:
            if selector_index == selector_count:
                reader.fail("selectors exhausted before EOB")
            selected = selectors[selector_index]
            selector_index += 1
            remaining = 50
        remaining -= 1
        before = reader.position
        symbol = _symbol(reader, tables[selected])
        data_bits_by_group[selected] += reader.position - before
        histogram[symbol] += 1
        symbol_count += 1
        if symbol_count > block_limit + 1:
            reader.fail("too many encoded MTF symbols")
        if symbol in (0, 1):
            if run == 0:
                run_sequences += 1
            run += weight * (symbol + 1)
            weight *= 2
            if transformed + run > block_limit:
                reader.fail("RUNA/RUNB expansion exceeds block size")
            continue
        if run:
            transformed += run
            run_bytes += run
            run = 0
            weight = 1
        if symbol == alphabet_size - 1:
            break
        transformed += 1
        if transformed > block_limit:
            reader.fail("transformed block exceeds block size")
    if transformed == 0 or original >= transformed:
        reader.fail("original pointer outside transformed block")
    data_bits = reader.position - data_start
    return {
        "block_start_bit": start, "block_end_bit": reader.position,
        "block_bits": reader.position - start, "physical_bits": reader.position - start,
        "header_bits": entropy_start - start,
        "bitmap_bits": bitmap_bits, "entropy_start_bit": entropy_start,
        "groups": groups, "selector_count": selector_count,
        "selectors_used": selector_index, "unused_selectors": selector_count - selector_index,
        "selectors": selectors, "selector_ranks": selector_ranks,
        "symbol_count": symbol_count, "selector_bits": selector_bits,
        "table_bits": table_bits, "data_bits": data_bits,
        "entropy_bits": 18 + selector_bits + table_bits + data_bits,
        "data_bits_by_group": data_bits_by_group,
        "alphabet_size": alphabet_size, "in_use_bytes": used,
        "runa_symbols": histogram[0],
        "runb_symbols": histogram[1], "run_sequences": run_sequences,
        "run_expanded_bytes": run_bytes, "mtf_literal_symbols": symbol_count - histogram[0] - histogram[1] - 1,
        "transformed_bytes": transformed, "original_pointer": original,
        "randomized": randomized, "block_crc32": crc,
    }


def inspect(encoded: bytes) -> dict:
    """Inspect one BZh stream; CRC fields are reported but never verified.

    `header_block_size` is in bytes. Selector/table/data bit counts cover the
    physical fields actually present, including any unused declared selectors.
    The next marker is read only after Huffman decoding reaches EOB.
    """
    if len(encoded) < 4 or encoded[:3] != b"BZh" or encoded[3] not in b"123456789":
        raise WireError("invalid BZh1..9 header")
    size_100k = encoded[3] - ord("0")
    limit = size_100k * 100_000
    reader = _Reader(encoded)
    blocks = []
    while True:
        start = reader.position
        marker = reader.read(48)
        if marker == END_MAGIC:
            combined_crc = reader.read(32)
            break
        if marker != BLOCK_MAGIC:
            reader.fail("invalid block or stream-end marker")
        blocks.append(_block(reader, start, limit))
    coded_bits = reader.position
    padding = len(encoded) * 8 - coded_bits
    if padding >= 8:
        reader.fail("trailing bytes after one Bzip2 stream")
    if padding and reader.read(padding) != 0:
        reader.fail("nonzero final padding")
    return {
        "header_block_size": limit, "header_block_size_100k": size_100k,
        "block_count": len(blocks), "blocks": blocks,
        "header_bits": 32, "footer_start_bit": start, "footer_bits": 80,
        "combined_crc32": combined_crc, "crc_verified": False,
        "coded_bits": coded_bits, "final_padding_bits": padding,
        "final_padding_value": 0, "stream_bytes": len(encoded), "stream_bits": len(encoded) * 8,
        "physical_bits": len(encoded) * 8,
    }
