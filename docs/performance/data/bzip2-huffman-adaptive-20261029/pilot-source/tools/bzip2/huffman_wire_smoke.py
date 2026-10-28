#!/usr/bin/env python3
"""Independent synthetic-wire and system-libbz2 tests for entropy inspection."""

from __future__ import annotations

import bz2
import math
import random

from huffman_wire import BLOCK_MAGIC, END_MAGIC, WireError, inspect


def crc(data: bytes) -> int:
    value = 0xFFFFFFFF
    for byte in data:
        value ^= byte << 24
        for _ in range(8):
            value = ((value << 1) ^ (0x04C11DB7 if value & 0x80000000 else 0)) & 0xFFFFFFFF
    return value ^ 0xFFFFFFFF


def canonical(lengths: list[int]) -> dict[int, str]:
    result = {}
    code = 0
    for width in range(1, max(lengths) + 1):
        for symbol, length in enumerate(lengths):
            if length == width:
                result[symbol] = f"{code:0{width}b}"
                code += 1
        code <<= 1
    return result


class Bits:
    def __init__(self):
        self.parts = []
        self.position = 0

    def add(self, bits: str):
        self.parts.append(bits)
        self.position += len(bits)

    def write(self, value: int, width: int):
        self.add(f"{value:0{width}b}")

    def finish(self) -> bytes:
        text = "".join(self.parts)
        text += "0" * (-len(text) % 8)
        return bytes(int(text[index:index + 8], 2) for index in range(0, len(text), 8))


def synthetic(groups: int, lengths: list[int], selectors: list[int], *,
              symbols: list[int] | None = None, ranks: list[int] | None = None,
              used: bytes = b"ab", original: int = 0, payload: bytes = b"ab") -> tuple[bytes, dict]:
    symbols = [2, 2, 3] if symbols is None else symbols
    writer = Bits()
    for byte in b"BZh1":
        writer.write(byte, 8)
    writer.write(BLOCK_MAGIC, 48)
    writer.write(crc(payload), 32)
    writer.write(0, 1)
    writer.write(original, 24)
    bitmap_groups = {byte // 16 for byte in used}
    for group in range(16):
        writer.write(int(group in bitmap_groups), 1)
    for group in sorted(bitmap_groups):
        for low in range(16):
            writer.write(int(group * 16 + low in used), 1)
    entropy_start = writer.position
    writer.write(groups, 3)
    writer.write(len(selectors), 15)
    selector_start = writer.position
    mtf = list(range(groups))
    actual_ranks = []
    for index, selected in enumerate(selectors):
        rank = mtf.index(selected) if ranks is None else ranks[index]
        actual_ranks.append(rank)
        writer.add("1" * rank + "0")
        if rank < groups:
            mtf.insert(0, mtf.pop(rank))
    table_start = writer.position
    for _ in range(groups):
        current = lengths[0]
        writer.write(current, 5)
        for length in lengths:
            writer.add("10" * max(0, length - current) + "11" * max(0, current - length) + "0")
            current = length
    data_start = writer.position
    codes = canonical(lengths)
    writer.add("".join(codes[symbol] for symbol in symbols) if codes else "000000")
    data_end = writer.position
    writer.write(END_MAGIC, 48)
    writer.write(crc(payload), 32)
    return writer.finish(), {"entropy_start": entropy_start, "selector_start": selector_start,
                             "table_start": table_start, "data_start": data_start, "data_end": data_end,
                             "selector_ranks": actual_ranks}


def rejected(wire: bytes):
    try:
        inspect(wire)
    except WireError:
        return
    raise AssertionError("malformed wire accepted")


def accounting(report: dict):
    assert report["coded_bits"] + report["final_padding_bits"] == report["stream_bits"]
    assert report["final_padding_value"] == 0 and report["crc_verified"] is False
    assert 32 + sum(block["block_bits"] for block in report["blocks"]) + 80 == report["coded_bits"]
    for block in report["blocks"]:
        assert block["entropy_bits"] == 18 + block["selector_bits"] + block["table_bits"] + block["data_bits"]
        assert block["block_bits"] == block["header_bits"] + block["entropy_bits"]
        assert block["selector_bits"] == sum(rank + 1 for rank in block["selector_ranks"])
        assert block["selectors_used"] == math.ceil(block["symbol_count"] / 50)
        assert block["symbol_count"] == block["runa_symbols"] + block["runb_symbols"] + block["mtf_literal_symbols"] + 1
        assert block["transformed_bytes"] == block["run_expanded_bytes"] + block["mtf_literal_symbols"]


def rotation_symbols(payload: bytes) -> tuple[bytes, int, list[int]]:
    order = sorted(range(len(payload)), key=lambda start: payload[start:] + payload[:start])
    last = bytes(payload[(start - 1) % len(payload)] for start in order)
    used = bytes(sorted(set(last)))
    mtf = list(used)
    symbols = []
    run = 0
    for byte in last:
        index = mtf.index(byte)
        if index == 0:
            run += 1
            continue
        if run:
            value = run - 1
            while True:
                symbols.append(value % 2)
                if value < 2:
                    break
                value = (value - 2) // 2
            run = 0
        symbols.append(index + 1)
        mtf.insert(0, mtf.pop(index))
    if run:
        value = run - 1
        while True:
            symbols.append(value % 2)
            if value < 2:
                break
            value = (value - 2) // 2
    symbols.append(len(used) + 1)
    return used, order.index(0), symbols


def selector_switches() -> int:
    rng = random.Random(0x601)
    letters = bytearray(b"a")
    for _ in range(599):
        letters.append(ord("a") + ((letters[-1] - ord("a") + rng.randint(1, 2)) % 3))
    payload = bytes(letters)  # No initial RLE1 transformation is needed.
    used, original, symbols = rotation_symbols(payload)
    count = math.ceil(len(symbols) / 50)
    assert count >= 6
    selectors = [5, 5, 0, 5, 1, 5] + [0] * (count - 6)
    wire, layout = synthetic(6, [3] * (len(used) + 2), selectors,
                             used=used, symbols=symbols, original=original, payload=payload)
    assert bz2.decompress(wire) == payload
    report = inspect(wire)
    accounting(report)
    block = report["blocks"][0]
    assert block["selector_ranks"][:6] == [5, 0, 1, 1, 2, 1]
    assert block["selectors"] == selectors and block["symbol_count"] == len(symbols)
    assert block["selector_ranks"] == layout["selector_ranks"]
    assert block["transformed_bytes"] == len(payload) and block["run_expanded_bytes"] > 0
    # Decoders allow extra declared selectors, but they still consume wire bits.
    wire, _ = synthetic(2, [2] * 4, [0, 1])
    assert bz2.decompress(wire) == b"ab"
    block = inspect(wire)["blocks"][0]
    assert block["selector_count"] == 2 and block["unused_selectors"] == 1
    assert block["selector_bits"] == 3
    return 2


def payload_marker() -> int:
    # With alphaSize256 and fixed8 codes, these actual entropy symbols emit the
    # block marker's literal48-bit pattern inside a block's Huffman payload.
    symbols = list(BLOCK_MAGIC.to_bytes(6, "big")) + [255]
    used = bytes(range(254))
    wire, layout = synthetic(2, [8] * 256, [0], used=used, symbols=symbols)
    encoded_bits = "".join(f"{byte:08b}" for byte in wire)
    assert encoded_bits[layout["data_start"]:layout["data_start"] + 48] == f"{BLOCK_MAGIC:048b}"
    report = inspect(wire)  # CRC is deliberately outside this inspector's scope.
    accounting(report)
    assert report["block_count"] == 1 and report["blocks"][0]["symbol_count"] == 7
    assert report["blocks"][0]["data_bits"] == 56
    return 1


def tiny_wires() -> int:
    count = 0
    for groups in range(2, 7):
        for lengths in ([2, 2, 2, 2], [1, 2, 3, 3], [3, 3, 2, 1], [1, 2, 17, 17], [1, 2, 20, 20]):
            for selector in range(groups):
                wire, _ = synthetic(groups, lengths, [selector])
                assert bz2.decompress(wire) == b"ab"
                report = inspect(wire)
                accounting(report)
                block = report["blocks"][0]
                assert block["groups"] == groups and block["selectors"] == [selector]
                assert block["selector_bits"] == selector + 1 and block["symbol_count"] == 3
                assert block["table_bits"] == groups * (5 + 4 + 2 * sum(abs(a - b) for a, b in zip(lengths, lengths[1:])))
                assert block["data_bits"] == lengths[2] * 2 + lengths[3]
                assert block["transformed_bytes"] == 2 and block["original_pointer"] == 0
                count += 1
    return count


def longest_codes() -> int:
    lengths = list(range(1, 20)) + [20, 20]
    codes = canonical(lengths)
    assert codes[19] == f"{0xFFFFE:020b}" and codes[20] == f"{0xFFFFF:020b}"
    wire, _ = synthetic(2, lengths, [0], used=b"abcdefghijklmnopqrs",
                         symbols=[19, 2, 20], payload=b"as")
    assert bz2.decompress(wire) == b"as"
    report = inspect(wire)
    accounting(report)
    block = report["blocks"][0]
    assert block["alphabet_size"] == 21 and block["symbol_count"] == 3
    assert block["data_bits"] == 43 and block["table_bits"] == 128
    assert block["transformed_bytes"] == 2 and block["original_pointer"] == 0
    return 1


def negative_wires() -> int:
    checks = 0
    for lengths in ([0, 0, 0, 0], [1, 2, 21, 21], [1, 1, 1, 1]):
        rejected(synthetic(2, lengths, [0])[0])
        checks += 1
    rejected(synthetic(1, [2] * 4, [0])[0])
    rejected(synthetic(7, [2] * 4, [0])[0])
    rejected(synthetic(2, [2] * 4, [0], ranks=[2])[0])
    rejected(synthetic(2, [2] * 4, [])[0])
    rejected(synthetic(2, [2] * 4, [0], original=2)[0])
    rejected(synthetic(2, [2] * 4, [0], symbols=[1] * 17 + [3])[0])
    rejected(synthetic(2, [2] * 4, [0], symbols=[2] * 51 + [3])[0])
    checks += 7
    valid, _ = synthetic(2, [2] * 4, [0])
    for cut in range(len(valid)):
        rejected(valid[:cut])
        checks += 1
    assert inspect(valid)["final_padding_bits"] > 0
    rejected(valid[:-1] + bytes([valid[-1] | 1]))
    rejected(valid + b"\0")
    rejected(valid + bz2.compress(b""))
    checks += 3
    return checks


def system_wires() -> int:
    rng = random.Random(0xB21)
    cases = [(b"", 1), (b"abc", 9), (b"entropy wire inspection\n" * 128, 1),
             (rng.randbytes(2048), 9), (b"A" * 10000 + b"B" * 257, 1),
             (rng.randbytes(200123), 1)]
    for payload, level in cases:
        wire = bz2.compress(payload, compresslevel=level)
        report = inspect(wire)
        accounting(report)
        assert report["header_block_size"] == level * 100000
        assert bz2.decompress(wire) == payload
        if not payload:
            assert report["block_count"] == 0 and report["final_padding_bits"] == 0
        if len(payload) > 200000:
            assert report["block_count"] >= 2
            assert any(block["block_start_bit"] % 8 for block in report["blocks"][1:])
    return len(cases)


def main() -> int:
    tiny = tiny_wires()
    longest = longest_codes()
    switches = selector_switches()
    markers = payload_marker()
    negatives = negative_wires()
    system = system_wires()
    print(f"bzip2_huffman_wire_smoke=ok tiny={tiny} longest_codes={longest} selectors={switches} payload_marker={markers} invalid={negatives} system={system}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
