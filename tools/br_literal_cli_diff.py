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
