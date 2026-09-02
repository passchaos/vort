#!/usr/bin/env python3
"""Verify Vort's compressed Brotli RLE slice with Node Brotli."""

from __future__ import annotations

import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: br_rle_node_diff.py <probe>")
    cases = (
        ("rle", b"a" * 4096),
        ("ababa", b"ababa"),
        ("binary-ababa", bytes((0, 255, 0, 255, 0))),
        ("multi-compressed-distance", b"aaaaa"),
        ("multi-compressed-context", b"ab"),
        *(
            (f"alternating-{n}", (b"xy" * ((n + 1) // 2))[:n])
            for n in (*range(6, 24), 71, 327, 1095, 1096, 1097, 2119, 2120, 65535, 65536, 1048576, 16777216)
        ),
        *((f"repeated-prefix-{n}", b"abcd" * n) for n in (2, 3, 7, 31)),
        *((f"repeated-prefix2-{n}", b"xy" * n) for n in (2, 3, 7, 31)),
        *((f"repeated-prefix3-{n}", b"xyz" * n) for n in (2, 3, 7, 31)),
        *((f"binary-prefix3-{n}", bytes((0, 0x80, 0xFF)) * n) for n in (2, 7, 31)),
        ("planned-mixed", b"abcabcXabcabcXabcabcX"),
        ("planned-distance42", (b"abcd" * 10) + b"aa" + (b"abcd" * 10)),
        ("planned-complex", b"abcdefabcdefXabcdefabcdefXabcdefabcdefX"),
        ("planned-complex16", b"abcdefghijklmnop" * 8),
        ("planned-byte-alphabet", bytes(range(256)) * 3),
    )
    script = (
        "const z=require('zlib');let b=[];"
        "process.stdin.on('data',x=>b.push(x));"
        "process.stdin.on('end',()=>{const o=z.brotliDecompressSync(Buffer.concat(b));"
        "process.stdout.write(o);});"
    )
    for mode, expected in cases:
        encoded = subprocess.check_output([sys.argv[1], mode])
        completed = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True)
        if completed.stdout != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        if mode == "rle" and len(encoded) >= 4096 // 16:
            raise SystemExit(f"RLE ratio regression: {len(encoded)} bytes")
        print(f"brotli {mode} node diff: encoded={len(encoded)} decoded={len(expected)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
