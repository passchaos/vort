#!/usr/bin/env python3
"""Verify Vort's compressed Brotli RLE slice with Node Brotli."""

from __future__ import annotations

import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: br_rle_node_diff.py <probe>")
    encoded = subprocess.check_output([sys.argv[1]])
    script = (
        "const z=require('zlib');let b=[];"
        "process.stdin.on('data',x=>b.push(x));"
        "process.stdin.on('end',()=>{const o=z.brotliDecompressSync(Buffer.concat(b));"
        "if(o.length!==4096||!o.every(x=>x===97))process.exit(2);});"
    )
    subprocess.run(["node", "-e", script], input=encoded, check=True)
    if len(encoded) >= 4096 // 16:
        raise SystemExit(f"RLE ratio regression: {len(encoded)} bytes")
    print(f"brotli rle node diff: encoded={len(encoded)} decoded=4096")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
