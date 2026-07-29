#!/usr/bin/env python3
"""Bounded differential probe for Vort's native-subset Zstandard decoder.

This is intentionally a smoke/probe rather than a full corpus runner: it keeps
payload sizes small enough for the existing `decode-zstd-native-hex` CLI surface
while covering multiple data shapes and zstd levels that have historically
exposed parser, FSE-table, repeat-offset, and Huffman-literal bugs.
"""

from __future__ import annotations

import argparse
import pathlib
import random
import re
import shutil
import subprocess
import sys
import zlib


ROOT = pathlib.Path(__file__).resolve().parents[1]
ZSTD = shutil.which("zstd")


def zstd_compress(payload: bytes, level: int) -> bytes:
    if not ZSTD:
        raise RuntimeError("zstd missing")
    return subprocess.run(
        [ZSTD, f"-{level}", "-cq"],
        input=payload,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout


def parse_crc(output: str) -> tuple[int, int]:
    decoded = re.search(r"(?:^| )decoded_bytes=([0-9]+)", output)
    crc = re.search(r"(?:^| )crc32=([0-9]+)", output)
    if not decoded or not crc:
        raise AssertionError(f"missing decode fields in {output!r}")
    return int(decoded.group(1)), int(crc.group(1))


def parse_decoded_size(output: str) -> int:
    decoded = re.search(r"(?:^| )decoded_bytes=([0-9]+)", output)
    if not decoded:
        raise AssertionError(f"missing decoded size in {output!r}")
    return int(decoded.group(1))


def native_size(cli: pathlib.Path, frame: bytes, expected_len: int) -> None:
    result = subprocess.run(
        [str(cli), "size-zstd-native-hex", frame.hex(), str(expected_len)],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", "replace").strip()
        raise AssertionError(stderr or f"native size rc={result.returncode}")
    decoded_len = parse_decoded_size(result.stdout.decode("utf-8", "replace"))
    if decoded_len != expected_len:
        raise AssertionError(f"decoded_len={decoded_len} expected_len={expected_len}")


def native_decode(cli: pathlib.Path, frame: bytes, expected: bytes) -> None:
    result = subprocess.run(
        [str(cli), "decode-zstd-native-hex", frame.hex(), str(len(expected))],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", "replace").strip()
        raise AssertionError(stderr or f"native decode rc={result.returncode}")
    decoded_len, crc = parse_crc(result.stdout.decode("utf-8", "replace"))
    expected_crc = zlib.crc32(expected) & 0xFFFFFFFF
    if decoded_len != len(expected) or crc != expected_crc:
        raise AssertionError(
            f"decoded_len={decoded_len} expected_len={len(expected)} "
            f"crc={crc} expected_crc={expected_crc}"
        )


def native_encode(cli: pathlib.Path, payload: bytes, mode: str = "auto") -> bytes:
    result = subprocess.run(
        [str(cli), "encode-zstd-native-bytes-hex", payload.hex(), mode, "true", "true"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", "replace").strip()
        raise AssertionError(stderr or f"native encode rc={result.returncode}")
    return bytes.fromhex(result.stdout.decode("ascii").strip())


def verify_native_encode(cli: pathlib.Path, payload: bytes, mode: str) -> None:
    native_frame = native_encode(cli, payload, mode)
    zstd_decoded = subprocess.run(
        [ZSTD, "-dcq"],
        input=native_frame,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout
    if zstd_decoded != payload:
        raise AssertionError(
            f"system zstd decoded {len(zstd_decoded)} bytes, expected {len(payload)}"
        )
    native_size(cli, native_frame, len(payload))
    native_decode(cli, native_frame, payload)


def generated_payloads() -> list[tuple[str, bytes]]:
    rng = random.Random(0x51D)
    printable = bytes(range(32, 127))
    englishish = (
        b"eeeeeeeeeeeeeeeeee tttttttttaaaaaaaaooooooiiiiinnnssrrddllccuumm"
        b"wfgypbvkjxqz.,0123456789"
    )
    json_unit = b'{"key":"value","number":123,"array":[1,2,3],"text":"abcdefg"}\n'
    two_symbol_state = 1
    two_symbol_huffman = bytearray()
    for _ in range(192):
        two_symbol_huffman.append(ord("B") if (two_symbol_state & 1) else ord("A"))
        feedback = (
            (two_symbol_state >> 0)
            ^ (two_symbol_state >> 2)
            ^ (two_symbol_state >> 3)
            ^ (two_symbol_state >> 4)
        ) & 1
        two_symbol_state = (two_symbol_state >> 1) | (feedback << 7)
    four_symbol_state = 1
    four_symbol_huffman = bytearray()
    for _ in range(192):
        four_symbol_state = (four_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        four_symbol_huffman.append(b"ABCD"[(four_symbol_state >> 30) & 3])
    eight_symbol_state = 0x1234_5678
    eight_symbol_huffman = bytearray()
    for _ in range(256):
        eight_symbol_state = (eight_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        eight_symbol_huffman.append(b"ABCDEFGH"[(eight_symbol_state >> 29) & 7])

    cases: list[tuple[str, bytes]] = [
        ("empty", b""),
        ("tiny", b"hello"),
        ("json100", json_unit * 100),
        ("alphabet200", printable * 200),
        ("two-symbol-huffman", bytes(two_symbol_huffman)),
        ("four-symbol-huffman", bytes(four_symbol_huffman)),
        ("eight-symbol-huffman", bytes(eight_symbol_huffman)),
        (
            "structured-lines",
            b"".join(
                b'{"k":"%04d","n":%d,"txt":"abcdefghijklmnopqrstuvwxyz0123456789"}\n' % (i, i)
                for i in range(80)
            ),
        ),
    ]
    for n in (257, 1024, 4096, 16_384):
        cases.append((f"dna{n}", bytes(rng.choice(b"ACGTN") for _ in range(n))))
        cases.append((f"print{n}", bytes(rng.choice(printable) for _ in range(n))))
        cases.append((f"english{n}", bytes(rng.choice(englishish) for _ in range(n))))
    # Deterministic larger shapes that previously found native decoder bugs but
    # still fit safely under the CLI hex argument limits.
    cases.append(("dna-direct-offset", bytes(b"ACGTN"[(i * 17 + i // 7 + i // 31) % 5] for i in range(4200))))
    cases.append(("print-mixed-tables", bytes(((i * 37 + i // 11 + i // 101) % 95) + 32 for i in range(24_000))))
    return cases


def discover_dir_payloads(dirs: list[pathlib.Path], max_files: int) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for directory in dirs:
        for path in sorted(p for p in directory.rglob("*") if p.is_file()):
            files.append(path)
            if max_files > 0 and len(files) >= max_files:
                return files
    return files


def payloads(paths: list[pathlib.Path], dirs: list[pathlib.Path], max_files: int, limit: int) -> list[tuple[str, bytes]]:
    cases = generated_payloads()
    for path in [*paths, *discover_dir_payloads(dirs, max_files)]:
        data = path.read_bytes()
        if limit > 0:
            data = data[:limit]
        cases.append((f"file:{path}", data))
    return cases


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", nargs="?", type=pathlib.Path, default=ROOT / "zig-out" / "bin" / "vort")
    parser.add_argument(
        "--path",
        action="append",
        type=pathlib.Path,
        default=[],
        help="Add a file payload to the generated probe set. May be repeated.",
    )
    parser.add_argument(
        "--dir",
        action="append",
        type=pathlib.Path,
        default=[],
        help="Add files discovered recursively under a directory. May be repeated.",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=8,
        help="Maximum files discovered across all --dir inputs; 0 means no limit.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=24_000,
        help="Maximum bytes read from each --path payload; 0 means no truncation.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cli = args.cli
    if not ZSTD:
        print("zstd_native_probe: zstd=missing")
        return 0
    if not cli.exists():
        raise SystemExit(f"missing built CLI at {cli}; run `zig build` first")

    levels = (1, 3, 6, 9, 12, 19)
    native_modes = ("auto", "raw_or_rle", "literal_only")
    checked = 0
    for name, payload in payloads(args.path, args.dir, args.max_files, args.limit):
        for mode in native_modes:
            try:
                verify_native_encode(cli, payload, mode)
            except (AssertionError, subprocess.CalledProcessError) as exc:
                print(
                    f"zstd_native_probe_fail case={name} mode=native-encode:{mode} "
                    f"input_bytes={len(payload)} error={exc}"
                )
                return 1
            checked += 1

        for level in levels:
            frame = zstd_compress(payload, level)
            try:
                native_size(cli, frame, len(payload))
                native_decode(cli, frame, payload)
            except AssertionError as exc:
                print(
                    f"zstd_native_probe_fail case={name} level={level} "
                    f"input_bytes={len(payload)} frame_bytes={len(frame)} error={exc}"
                )
                print(frame.hex()[:800])
                return 1
            checked += 1

    print(f"zstd_native_probe_ok cases={checked} zstd={pathlib.Path(ZSTD).name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
