#!/usr/bin/env python3
"""Decode planner-backed Brotli real-shape corpora with Node."""

from __future__ import annotations

import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: br_planned_node_diff.py <probe>")
    cases = (
        ("json", b'{"kind":"event","active":true,"values":[1,2,3,5,8,13]}\n' * 48),
        ("source", b"pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" * 40),
        ("log", b"2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" * 40),
    )
    script = (
        "const z=require('zlib');let b=[];"
        "process.stdin.on('data',x=>b.push(x));"
        "process.stdin.on('end',()=>process.stdout.write(z.brotliDecompressSync(Buffer.concat(b))));"
    )
    for name, expected in cases:
        for mode in (name, f"lazy-{name}"):
            encoded = subprocess.check_output([sys.argv[1], mode])
            actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
            if actual != expected:
                raise SystemExit(f"{mode}: node output mismatch")
            print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b" information follows the information"
    encoded = subprocess.check_output([sys.argv[1], "dictionary-words"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("dictionary-words: node output mismatch")
    if len(encoded) >= len(expected):
        raise SystemExit("dictionary-words: expected a smaller encoded stream")
    print(f"brotli planned dictionary-words node diff: encoded={len(encoded)} decoded={len(actual)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
