#!/usr/bin/env python3
"""Black-box smoke for Vort's minimal dependency-free Brotli literal blocks."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


def bits_to_bytes(bits: list[int]) -> bytes:
    out = bytearray((len(bits) + 7) // 8)
    for i, bit in enumerate(bits):
        if bit:
            out[i // 8] |= 1 << (i % 8)
    return bytes(out)


def write_bits(bits: list[int], value: int, count: int) -> None:
    for i in range(count):
        bits.append((value >> i) & 1)


def write_block_type_count(bits: list[int], value: int) -> None:
    if value == 1:
        write_bits(bits, 0, 1)
        return
    write_bits(bits, 1, 1)
    if value == 2:
        write_bits(bits, 0, 3)
        return
    selector = 1
    while selector < 8:
        low = (1 << selector) + 1
        high = low + ((1 << selector) - 1)
        if low <= value <= high:
            write_bits(bits, selector, 3)
            write_bits(bits, value - low, selector)
            return
        selector += 1
    raise ValueError(value)


def write_simple_single_symbol_prefix(bits: list[int], alphabet_size: int, symbol: int) -> None:
    alphabet_bits = (alphabet_size - 1).bit_length()
    write_bits(bits, 1, 2)
    write_bits(bits, 0, 2)
    write_bits(bits, symbol, alphabet_bits)


def write_zero_context_map_rle(bits: list[int], context_map_size: int, ntrees: int, rlemax: int) -> None:
    if ntrees < 2 or rlemax <= 0 or context_map_size < (1 << rlemax):
        raise ValueError((context_map_size, ntrees, rlemax))
    if context_map_size >= (1 << (rlemax + 1)):
        raise ValueError((context_map_size, ntrees, rlemax))
    write_bits(bits, 1, 1)  # use RLE for zeros
    write_bits(bits, rlemax - 1, 4)
    write_simple_single_symbol_prefix(bits, ntrees + rlemax, rlemax)
    write_bits(bits, context_map_size - (1 << rlemax), rlemax)
    write_bits(bits, 0, 1)  # IMTF = false


def write_distance_context_map_copy3(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    write_bits(bits, 0, 1)
    write_bits(bits, 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_literal_context_map_for_a(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for context in range(64):
        write_bits(bits, 1 if context == (ord("a") & 0x3F) else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_literal_context_map_for_a_imtf(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    target = ord("a") & 0x3F
    for context in range(64):
        write_bits(bits, 1 if context in (target, target + 1) else 0, 1)
    write_bits(bits, 1, 1)  # IMTF = true


def write_utf8_literal_context_map_for_a(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for context in range(64):
        write_bits(bits, 1 if context == 56 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_utf8_literal_context_map_for_context63(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for context in range(64):
        write_bits(bits, 1 if context == 63 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_utf8_literal_context_map_for_fifth_tree(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 3)
    write_bits(bits, 4, 3)
    for context in range(64):
        write_bits(bits, 1 if context == 56 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_signed_literal_context_map_for_one_after_zero(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for context in range(64):
        write_bits(bits, 1 if context == 8 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_literal_context_map_for_ab(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, 0, 2)
    write_bits(bits, 1, 2)
    write_bits(bits, 2, 2)
    context_a = ord("a") & 0x3F
    context_b = ord("b") & 0x3F
    for context in range(64):
        tree_index = 1 if context == context_a else 2 if context == context_b else 0
        write_three_symbol_context_map_code(bits, tree_index)
    write_bits(bits, 0, 1)  # IMTF = false


def write_three_symbol_context_map_code(bits: list[int], symbol: int) -> None:
    if symbol == 0:
        write_bits(bits, 0, 1)
    elif symbol == 1:
        write_bits(bits, 1, 2)
    elif symbol == 2:
        write_bits(bits, 3, 2)
    else:
        raise ValueError(symbol)


def write_literal_block_switch_context_map(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for index in range(128):
        write_bits(bits, 1 if index >= 64 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_literal_block_switch_three_types_context_map(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, 0, 2)
    write_bits(bits, 1, 2)
    write_bits(bits, 2, 2)
    for index in range(192):
        write_three_symbol_context_map_code(bits, index // 64)
    write_bits(bits, 0, 1)  # IMTF = false


def write_distance_block_switch_context_map(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 0, 1)
    write_bits(bits, 1, 1)
    for index in range(8):
        write_bits(bits, 1 if index == 4 else 0, 1)
    write_bits(bits, 0, 1)  # IMTF = false


def write_distance_block_switch_three_types_context_map(bits: list[int]) -> None:
    write_bits(bits, 0, 1)  # RLEMAX = 0
    write_bits(bits, 1, 2)  # simple context-map prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, 0, 2)
    write_bits(bits, 1, 2)
    write_bits(bits, 2, 2)
    for index in range(12):
        tree_index = 1 if index == 4 else 2 if index == 8 else 0
        write_three_symbol_context_map_code(bits, tree_index)
    write_bits(bits, 0, 1)  # IMTF = false


def write_literal_hello_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 3, 2)  # NSYM = 4
    for symbol in b"helo":
        write_bits(bits, symbol, 8)
    write_bits(bits, 0, 1)  # tree-select

    write_simple_single_symbol_prefix(bits, 704, 40)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_hello_trivial_context_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 2)
    write_zero_context_map_rle(bits, 64, 2, 6)
    write_block_type_count(bits, 2)
    write_zero_context_map_rle(bits, 4, 2, 2)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 3, 2)  # NSYM = 4
    for symbol in b"helo":
        write_bits(bits, symbol, 8)
    write_bits(bits, 0, 1)  # tree-select
    write_simple_single_symbol_prefix(bits, 256, 0)

    write_simple_single_symbol_prefix(bits, 704, 40)

    write_simple_single_symbol_prefix(bits, 64, 0)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_copy_a_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 1, 4)  # NDIRECT = 1
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 704, 138)
    write_simple_single_symbol_prefix(bits, 65, 16)


def write_last_distance_a_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 1, 4)  # NDIRECT = 1
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 136, 10)
    write_bits(bits, 0, 10)
    write_simple_single_symbol_prefix(bits, 65, 16)


def write_short_distance_a_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 1, 4)  # NDIRECT = 1
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 136, 10)
    write_bits(bits, 128, 10)

    write_bits(bits, 1, 2)  # simple distance prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 16, 7)
    write_bits(bits, 5, 7)


def write_regular_distance_ab_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 1, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)

    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 0, 2)  # NSYM = 1
    write_bits(bits, 145, 10)

    write_simple_single_symbol_prefix(bits, 112, 17)


def write_distance_context_ab_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 2, 4)  # NDIRECT = 2
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 2)
    write_distance_context_map_copy3(bits)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)

    write_simple_single_symbol_prefix(bits, 704, 145)
    write_simple_single_symbol_prefix(bits, 66, 16)
    write_simple_single_symbol_prefix(bits, 66, 17)


def write_literal_context_aba_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode = LSB6
    write_block_type_count(bits, 2)
    write_literal_context_map_for_a(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_context_imtf_aba_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode = LSB6
    write_block_type_count(bits, 2)
    write_literal_context_map_for_a_imtf(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_context_utf8_aba_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 2, 2)  # literal context mode = UTF8
    write_block_type_count(bits, 2)
    write_utf8_literal_context_map_for_a(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_utf8_context_after_distance_three_copy_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 3, 4)  # NDIRECT = 3
    write_bits(bits, 2, 2)  # literal context mode = UTF8
    write_block_type_count(bits, 2)
    write_utf8_literal_context_map_for_context63(bits)
    write_block_type_count(bits, 1)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)
    write_simple_single_symbol_prefix(bits, 256, ord("c"))

    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 152, 10)
    write_bits(bits, 8, 10)

    write_simple_single_symbol_prefix(bits, 67, 18)


def write_literal_context_five_trees_aba_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 2, 2)  # literal context mode = UTF8
    write_block_type_count(bits, 5)
    write_utf8_literal_context_map_for_fifth_tree(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, 0)
    write_simple_single_symbol_prefix(bits, 256, 0)
    write_simple_single_symbol_prefix(bits, 256, 0)
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_context_signed_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 3, 2)  # literal context mode = Signed
    write_block_type_count(bits, 2)
    write_signed_literal_context_map_for_one_after_zero(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, 1)
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_context_three_trees_abc_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode = LSB6
    write_block_type_count(bits, 3)
    write_literal_context_map_for_ab(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 256, ord("c"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_command_switch_aaab_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 2)
    write_simple_single_symbol_prefix(bits, 4, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first command block count = 1
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 1, 4)  # NDIRECT = 1
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)

    write_simple_single_symbol_prefix(bits, 704, 136)
    write_simple_single_symbol_prefix(bits, 704, 8)
    write_simple_single_symbol_prefix(bits, 65, 16)


def write_command_switch_three_types_aaabbbc_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 3)
    write_simple_single_symbol_prefix(bits, 5, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first command block count = 1
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 1, 4)  # NDIRECT = 1
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)
    write_bits(bits, ord("c"), 8)

    write_simple_single_symbol_prefix(bits, 704, 136)
    write_simple_single_symbol_prefix(bits, 704, 136)
    write_simple_single_symbol_prefix(bits, 704, 8)
    write_simple_single_symbol_prefix(bits, 65, 16)


def write_literal_block_switch_ab_header(bits: list[int]) -> None:
    write_block_type_count(bits, 2)
    write_simple_single_symbol_prefix(bits, 4, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first literal block count = 1
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode, block type 0
    write_bits(bits, 0, 2)  # literal context mode, block type 1
    write_block_type_count(bits, 2)
    write_literal_block_switch_context_map(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 704, 16)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_literal_block_switch_three_types_abc_header(bits: list[int]) -> None:
    write_block_type_count(bits, 3)
    write_simple_single_symbol_prefix(bits, 5, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first literal block count = 1
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 0, 4)  # NDIRECT
    write_bits(bits, 0, 2)  # literal context mode, block type 0
    write_bits(bits, 0, 2)  # literal context mode, block type 1
    write_bits(bits, 0, 2)  # literal context mode, block type 2
    write_block_type_count(bits, 3)
    write_literal_block_switch_three_types_context_map(bits)
    write_block_type_count(bits, 1)

    write_simple_single_symbol_prefix(bits, 256, ord("a"))
    write_simple_single_symbol_prefix(bits, 256, ord("b"))
    write_simple_single_symbol_prefix(bits, 256, ord("c"))
    write_simple_single_symbol_prefix(bits, 704, 24)
    write_simple_single_symbol_prefix(bits, 64, 0)


def write_distance_block_switch_abcabab_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 2)
    write_simple_single_symbol_prefix(bits, 4, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first distance block count = 1
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 3, 4)  # NDIRECT = 3
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 2)
    write_distance_block_switch_context_map(bits)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)
    write_bits(bits, ord("c"), 8)

    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 152, 10)
    write_bits(bits, 128, 10)

    write_simple_single_symbol_prefix(bits, 67, 18)
    write_simple_single_symbol_prefix(bits, 67, 17)


def write_distance_block_switch_three_types_abcababbb_header(bits: list[int]) -> None:
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 3)
    write_simple_single_symbol_prefix(bits, 5, 1)
    write_simple_single_symbol_prefix(bits, 26, 0)
    write_bits(bits, 0, 2)  # first distance block count = 1
    write_bits(bits, 0, 2)  # NPOSTFIX
    write_bits(bits, 3, 4)  # NDIRECT = 3
    write_bits(bits, 0, 2)  # literal context mode
    write_block_type_count(bits, 1)
    write_block_type_count(bits, 3)
    write_distance_block_switch_three_types_context_map(bits)

    write_bits(bits, 1, 2)  # simple literal prefix
    write_bits(bits, 2, 2)  # NSYM = 3
    write_bits(bits, ord("a"), 8)
    write_bits(bits, ord("b"), 8)
    write_bits(bits, ord("c"), 8)

    write_bits(bits, 1, 2)  # simple insert-copy prefix
    write_bits(bits, 1, 2)  # NSYM = 2
    write_bits(bits, 152, 10)
    write_bits(bits, 128, 10)

    write_simple_single_symbol_prefix(bits, 67, 18)
    write_simple_single_symbol_prefix(bits, 67, 17)
    write_simple_single_symbol_prefix(bits, 67, 16)


def literal_only_hello_frame(final: bool) -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1 if final else 0, 1)
    if final:
        write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    if not final:
        write_bits(bits, 0, 1)  # ISUNCOMPRESSED = false
    write_literal_hello_header(bits)
    # Literal tree is canonical by sorted symbol order:
    # e=00, h=01, l=10, o=11, stored LSB-first.
    write_bits(bits, 2, 2)  # h
    write_bits(bits, 0, 2)  # e
    write_bits(bits, 1, 2)  # l
    write_bits(bits, 1, 2)  # l
    write_bits(bits, 3, 2)  # o
    if not final:
        # Final empty meta-block.
        write_bits(bits, 1, 1)
        write_bits(bits, 1, 1)
    return bits_to_bytes(bits)


def trivial_context_hello_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_literal_hello_trivial_context_header(bits)
    write_bits(bits, 2, 2)  # h
    write_bits(bits, 0, 2)  # e
    write_bits(bits, 1, 2)  # l
    write_bits(bits, 1, 2)  # l
    write_bits(bits, 3, 2)  # o
    return bits_to_bytes(bits)


def direct_copy_a_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_copy_a_header(bits)
    return bits_to_bytes(bits)


def last_distance_a_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_last_distance_a_header(bits)
    write_bits(bits, 1, 1)  # command 136
    write_bits(bits, 0, 1)  # command 0
    return bits_to_bytes(bits)


def short_distance_a_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_short_distance_a_header(bits)
    write_bits(bits, 1, 1)  # command 136
    write_bits(bits, 1, 1)  # distance 16
    write_bits(bits, 0, 1)  # command 128
    write_bits(bits, 0, 1)  # distance 5
    return bits_to_bytes(bits)


def cross_block_short_distance_a_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16

    write_bits(bits, 0, 1)  # ISLAST = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_bits(bits, 0, 1)  # ISUNCOMPRESSED = false
    write_short_distance_a_header(bits)
    write_bits(bits, 1, 1)  # command 136
    write_bits(bits, 1, 1)  # distance 16

    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 1, 16)  # MLEN - 1
    write_short_distance_a_header(bits)
    write_bits(bits, 0, 1)  # command 128
    write_bits(bits, 0, 1)  # distance 5
    return bits_to_bytes(bits)


def regular_distance_ab_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_regular_distance_ab_header(bits)
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 1, 1)  # b
    write_bits(bits, 0, 1)  # dextra
    return bits_to_bytes(bits)


def distance_context_ab_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 4, 16)  # MLEN - 1
    write_distance_context_ab_header(bits)
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 1, 1)  # b
    return bits_to_bytes(bits)


def literal_context_aba_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_aba_header(bits)
    return bits_to_bytes(bits)


def literal_context_imtf_aba_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_imtf_aba_header(bits)
    return bits_to_bytes(bits)


def literal_context_utf8_aba_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_utf8_aba_header(bits)
    return bits_to_bytes(bits)


def utf8_context_after_distance_three_copy_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 5, 16)  # MLEN - 1
    write_utf8_context_after_distance_three_copy_header(bits)
    write_bits(bits, 1, 1)  # command 152
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 1, 1)  # b
    write_bits(bits, 0, 1)  # command 8
    return bits_to_bytes(bits)


def literal_context_five_trees_aba_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_five_trees_aba_header(bits)
    return bits_to_bytes(bits)


def literal_context_signed_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_signed_header(bits)
    return bits_to_bytes(bits)


def literal_context_three_trees_abc_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_context_three_trees_abc_header(bits)
    return bits_to_bytes(bits)


def command_switch_aaab_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 3, 16)  # MLEN - 1
    write_command_switch_aaab_header(bits)
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 0, 2)  # next command block count = 1
    write_bits(bits, 1, 1)  # b
    return bits_to_bytes(bits)


def command_switch_three_types_aaabbbc_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 6, 16)  # MLEN - 1
    write_command_switch_three_types_aaabbbc_header(bits)
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 0, 2)  # next command block count = 1
    write_bits(bits, 1, 2)  # b
    write_bits(bits, 0, 2)  # next command block count = 1
    write_bits(bits, 3, 2)  # c
    return bits_to_bytes(bits)


def literal_block_switch_ab_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 1, 16)  # MLEN - 1
    write_literal_block_switch_ab_header(bits)
    return bits_to_bytes(bits)


def literal_block_switch_three_types_abc_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 2, 16)  # MLEN - 1
    write_literal_block_switch_three_types_abc_header(bits)
    write_bits(bits, 0, 2)  # next literal block count = 1
    write_bits(bits, 0, 2)  # next literal block count = 1
    return bits_to_bytes(bits)


def distance_block_switch_abcabab_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 6, 16)  # MLEN - 1
    write_distance_block_switch_abcabab_header(bits)
    write_bits(bits, 1, 1)  # command 152
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 1, 2)  # b
    write_bits(bits, 3, 2)  # c
    write_bits(bits, 0, 1)  # command 128
    write_bits(bits, 0, 2)  # next distance block count = 1
    return bits_to_bytes(bits)


def distance_block_switch_three_types_abcababbb_frame() -> bytes:
    bits: list[int] = []
    write_bits(bits, 0, 1)  # WBITS = 16
    write_bits(bits, 1, 1)  # ISLAST
    write_bits(bits, 0, 1)  # ISLASTEMPTY = false
    write_bits(bits, 0, 2)  # MNIBBLES = 4
    write_bits(bits, 8, 16)  # MLEN - 1
    write_distance_block_switch_three_types_abcababbb_header(bits)
    write_bits(bits, 1, 1)  # command 152
    write_bits(bits, 0, 1)  # a
    write_bits(bits, 1, 2)  # b
    write_bits(bits, 3, 2)  # c
    write_bits(bits, 0, 1)  # command 128
    write_bits(bits, 0, 2)  # next distance block count = 1
    write_bits(bits, 0, 1)  # command 128
    write_bits(bits, 0, 2)  # next distance block count = 1
    return bits_to_bytes(bits)


def run(cmd: list[str], cwd: Path, expect_ok: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if expect_ok and result.returncode != 0:
        raise RuntimeError(
            f"command failed: {' '.join(cmd)}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    if not expect_ok and result.returncode == 0:
        raise RuntimeError(f"command unexpectedly succeeded: {' '.join(cmd)}")
    return result


def node_decode(br_path: Path) -> bytes:
    script = (
        "const fs=require('fs');"
        "const z=require('zlib');"
        "process.stdout.write(z.brotliDecompressSync(fs.readFileSync(process.argv[1])));"
    )
    result = subprocess.run(["node", "-e", script, str(br_path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return result.stdout


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: br_literal_cli_diff.py <vort-cli>")
    cli = Path(sys.argv[1]).resolve()
    root = Path(__file__).resolve().parents[1]
    cases = {
        "final": (literal_only_hello_frame(True), b"hello"),
        "nonfinal": (literal_only_hello_frame(False), b"hello"),
        "trivial-context": (trivial_context_hello_frame(), b"hello"),
        "copy": (direct_copy_a_frame(), b"aaaaa"),
        "last-distance": (last_distance_a_frame(), b"aaaaa"),
        "short-distance": (short_distance_a_frame(), b"aaaaa"),
        "cross-block-short-distance": (cross_block_short_distance_a_frame(), b"aaaaa"),
        "regular-distance": (regular_distance_ab_frame(), b"ababa"),
        "distance-context": (distance_context_ab_frame(), b"ababa"),
        "literal-context": (literal_context_aba_frame(), b"aba"),
        "literal-context-imtf": (literal_context_imtf_aba_frame(), b"aba"),
        "literal-context-utf8": (literal_context_utf8_aba_frame(), b"aba"),
        "utf8-context-after-distance-three-copy": (utf8_context_after_distance_three_copy_frame(), b"abcabc"),
        "literal-context-five-trees": (literal_context_five_trees_aba_frame(), b"aba"),
        "literal-context-signed": (literal_context_signed_frame(), bytes([1, ord("b"), 1])),
        "literal-context-three-trees": (literal_context_three_trees_abc_frame(), b"abc"),
        "command-switch": (command_switch_aaab_frame(), b"aaab"),
        "command-switch-three-types": (command_switch_three_types_aaabbbc_frame(), b"aaabbbc"),
        "literal-block-switch": (literal_block_switch_ab_frame(), b"ab"),
        "literal-block-switch-three-types": (literal_block_switch_three_types_abc_frame(), b"abc"),
        "distance-block-switch": (distance_block_switch_abcabab_frame(), b"abcabab"),
        "distance-block-switch-three-types": (distance_block_switch_three_types_abcababbb_frame(), b"abcababbb"),
    }

    with tempfile.TemporaryDirectory(prefix="vort-br-literal-") as td:
        tmp = Path(td)
        checked = 0
        for name, (frame, expected) in cases.items():
            path = tmp / f"{name}.br"
            out = tmp / f"{name}.out"
            path.write_bytes(frame)
            run([str(cli), "size-br-file", str(path), str(len(expected))], root)
            run([str(cli), "decode-br-file-to", str(path), str(out), str(len(expected))], root)
            if out.read_bytes() != expected:
                raise AssertionError(f"vort decode mismatch for {name}")
            if node_decode(path) != expected:
                raise AssertionError(f"node decode mismatch for {name}")
            run([str(cli), "decode-br-file-to", str(path), str(out), str(len(expected) - 1)], root, expect_ok=False)
            checked += 1

    print(f"br_literal_cli_diff=ok cases={checked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
