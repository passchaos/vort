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
        for mode in (name, f"lazy-{name}", f"ratio-{name}"):
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
    expected = b"Information about compression performance and dictionary support."
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-dictionary-short"])
    dictionary_encoded = subprocess.check_output([sys.argv[1], "dictionary-dictionary-short"])
    if ratio_encoded != dictionary_encoded:
        raise SystemExit("ratio-dictionary-short: expected ratio mode to select dictionary stream")
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-dictionary-short: node output mismatch")
    print(f"brotli planned ratio-dictionary-short node diff: encoded={len(ratio_encoded)} decoded={len(actual)}")
    expected = b"abcdefghabcdefgh information follows abcdefghabcdefgh"
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-dictionary-mixed"])
    dictionary_encoded = subprocess.check_output([sys.argv[1], "dictionary-dictionary-mixed"])
    if len(ratio_encoded) >= len(dictionary_encoded):
        raise SystemExit("ratio-dictionary-mixed: expected mixed ratio stream to beat dictionary-only stream")
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-dictionary-mixed: node output mismatch")
    print(f"brotli planned ratio-dictionary-mixed node diff: encoded={len(ratio_encoded)} dictionary={len(dictionary_encoded)} decoded={len(actual)}")
    expected = b"information"
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-dictionary-word"])
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-dictionary-word: node output mismatch")
    print(f"brotli planned ratio-dictionary-word node diff: encoded={len(ratio_encoded)} decoded={len(actual)}")
    expected = b"qzxwvbnm"
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-dictionary-unmatched"])
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-dictionary-unmatched: node output mismatch")
    print(f"brotli planned ratio-dictionary-unmatched node diff: encoded={len(ratio_encoded)} decoded={len(actual)}")
    expected = b"qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-ratio-incompressible"])
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-incompressible: node output mismatch")
    if len(ratio_encoded) > len(expected) + 4:
        raise SystemExit("ratio-incompressible: output exceeds stored framing ceiling")
    print(f"brotli planned ratio-incompressible node diff: encoded={len(ratio_encoded)} decoded={len(actual)}")
    expected = b"qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    for mode in ("stable-fast-incompressible", "stable-balanced-incompressible"):
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        if len(encoded) > len(expected) + 4:
            raise SystemExit(f"{mode}: output exceeds stored framing ceiling")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b"abcd"
    for mode in ("stable-fast-tiny", "stable-balanced-tiny", "ratio-tiny"):
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    index_bytes = int(subprocess.check_output([sys.argv[1], "dictionary-index-bytes"]))
    if index_bytes > 150_000:
        raise SystemExit(f"dictionary index exceeds memory budget: {index_bytes}")
    print(f"brotli planned dictionary index: bytes={index_bytes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
