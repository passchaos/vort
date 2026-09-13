#!/usr/bin/env python3
"""Shared corpus and persistent-runner helpers for Rust Deflate benchmarks."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FDEFLATE = Path.home() / "Work" / "fdeflate"
MINIZ_OXIDE = Path.home() / "Work" / "miniz_oxide" / "miniz_oxide"


def deterministic_noise(size: int) -> bytes:
    state = 0x1234ABCD
    output = bytearray(size)
    for index in range(size):
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFFFFFF
        output[index] = state & 0xFF
    return bytes(output)


def payloads(*, encode: bool) -> list[tuple[str, bytes]]:
    common = [
        ("tiny", b"hello rust deflate baselines"),
        ("repetitive", b"abcabcabcabc" * 512),
        ("overlap-rle", b"a" * (32 * 1024)),
        ("distance-heavy", (b"0123456789abcdef" * 1024) + b"----" + (b"0123456789abcdef" * 1024)),
        ("dynamic-match", b"literal-heavy dynamic huffman decode stage\n" * 512),
        ("text", b"the quick brown fox jumps over the lazy dog\n" * 1024),
        ("binary", bytes((index * 131 + (index >> 3) * 17 + 29) & 0xFF for index in range(64 * 1024))),
    ]
    common.append(
        ("incompressible", deterministic_noise(64 * 1024))
        if encode
        else ("stored-binary", common[-1][1])
    )
    common.extend([
        ("readme", (ROOT / "README.md").read_bytes()),
        ("roadmap", (ROOT / "docs" / "roadmap.md").read_bytes()),
    ])
    return common


def write_if_changed(path: Path, content: str) -> None:
    if path.is_file() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build_runner(project: Path, package: str) -> Path:
    environment = os.environ.copy()
    environment["RUSTFLAGS"] = "-C target-cpu=native"
    subprocess.run(
        ["cargo", "build", "--release", "--quiet"],
        cwd=project,
        env=environment,
        check=True,
    )
    suffix = ".exe" if os.name == "nt" else ""
    executable = project / "target" / "release" / f"{package}{suffix}"
    if not executable.is_file():
        raise AssertionError(f"Cargo runner missing: {executable}")
    return executable
