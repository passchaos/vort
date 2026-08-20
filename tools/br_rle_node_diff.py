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
        *(
            (f"alternating-{n}", (b"xy" * ((n + 1) // 2))[:n])
            for n in (*range(6, 24), 71, 327, 1095, 1096, 1097, 2119, 2120, 65535, 65536, 1048576, 16777216)
        ),
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
