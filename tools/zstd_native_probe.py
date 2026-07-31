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
import tempfile
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
    if len(frame) > 24_000:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-native-probe-", dir=ROOT / ".zig-cache") as tmpdir:
            path = pathlib.Path(tmpdir) / "frame.zst"
            path.write_bytes(frame)
            result = subprocess.run(
                [str(cli), "size-zstd-native-file", str(path), str(expected_len)],
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
            return

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
    if len(frame) > 24_000:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-native-probe-", dir=ROOT / ".zig-cache") as tmpdir:
            path = pathlib.Path(tmpdir) / "frame.zst"
            path.write_bytes(frame)
            result = subprocess.run(
                [str(cli), "decode-zstd-native-file", str(path), str(len(expected))],
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
            return

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


def native_error(cli: pathlib.Path, frame: bytes, expected_error: str) -> None:
    """Assert that both size preflight and decode reject a malformed frame.

    The native library exposes size and decode as separate public APIs, and both
    must reject reserved/header-invalid frames before any output-limit decision
    can mask the parser error.
    """
    for command in ("size-zstd-native-hex", "decode-zstd-native-hex"):
        result = subprocess.run(
            [str(cli), command, frame.hex(), "0"],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode == 0 or expected_error not in result.stderr:
            raise AssertionError(
                f"{command} expected {expected_error}, got "
                f"rc={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}"
            )


def native_encode(cli: pathlib.Path, payload: bytes, mode: str = "auto") -> bytes:
    if len(payload) > 24_000:
        with tempfile.TemporaryDirectory(prefix="vort-zstd-native-probe-", dir=ROOT / ".zig-cache") as tmpdir:
            path = pathlib.Path(tmpdir) / "payload.bin"
            path.write_bytes(payload)
            result = subprocess.run(
                [str(cli), "encode-zstd-native-file-hex", str(path), mode, "true", "true"],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if result.returncode != 0:
                stderr = result.stderr.decode("utf-8", "replace").strip()
                raise AssertionError(stderr or f"native encode rc={result.returncode}")
            return bytes.fromhex(result.stdout.decode("ascii").strip())

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


def handcrafted_frames() -> list[tuple[str, bytes, bytes]]:
    """Small valid frames that exercise parser edge cases not emitted by writers."""
    raw = b"abc"
    block_header = ((len(raw) << 3) | 1).to_bytes(3, "little")
    descriptor_unused_bit = bytes.fromhex("28b52ffd") + b"\x10\x00" + block_header + raw
    skippable_only = (0x184D2A50).to_bytes(4, "little") + (3).to_bytes(4, "little") + b"abc"
    return [
        ("descriptor-unused-bit", descriptor_unused_bit, raw),
        ("skippable-only", skippable_only, b""),
    ]


def handcrafted_invalid_frames() -> list[tuple[str, bytes, str]]:
    """Small malformed frames with reference-visible failures."""
    raw = b"abc"
    block_header = ((len(raw) << 3) | 1).to_bytes(3, "little")
    # Frame Header Descriptor bit 3 is reserved by the Zstandard spec. Unlike
    # the adjacent unused bit 4, reference zstd rejects otherwise valid frames
    # with this bit set, so the native parser should report a hard corruption
    # error instead of accepting the stream or classifying it as a feature gap.
    descriptor_reserved_bit = bytes.fromhex("28b52ffd") + b"\x08\x00" + block_header + raw
    return [
        ("descriptor-reserved-bit", descriptor_reserved_bit, "CorruptFrame"),
    ]


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
    six_symbol_state = 0x0BAD_F00D
    six_symbol_huffman = bytearray()
    for _ in range(256):
        six_symbol_state = (six_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        six_symbol_huffman.append(b"ABCDEF"[(six_symbol_state >> 29) % 6])
    eight_symbol_state = 0x1234_5678
    eight_symbol_huffman = bytearray()
    for _ in range(256):
        eight_symbol_state = (eight_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        eight_symbol_huffman.append(b"ABCDEFGH"[(eight_symbol_state >> 29) & 7])
    sixteen_symbol_state = 0x8765_4321
    sixteen_symbol_huffman = bytearray()
    for _ in range(256):
        sixteen_symbol_state = (sixteen_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        sixteen_symbol_huffman.append(b"ABCDEFGHIJKLMNOP"[(sixteen_symbol_state >> 28) & 15])
    thirty_two_symbol_alphabet = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"
    thirty_two_symbol_state = 0xFEED_BEEF
    thirty_two_symbol_huffman = bytearray()
    for _ in range(384):
        thirty_two_symbol_state = (thirty_two_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        thirty_two_symbol_huffman.append(thirty_two_symbol_alphabet[(thirty_two_symbol_state >> 27) & 31])
    sixty_four_symbol_state = 0x3141_5926
    sixty_four_symbol_huffman = bytearray()
    for _ in range(512):
        sixty_four_symbol_state = (sixty_four_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        sixty_four_symbol_huffman.append(32 + ((sixty_four_symbol_state >> 26) & 63))
    printable_huffman_state = 0x2718_2818
    printable_huffman = bytearray()
    for _ in range(768):
        printable_huffman_state = (printable_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        printable_huffman.append(32 + ((printable_huffman_state >> 24) % 95))
    four_stream_huffman_state = 0x1618_0339
    four_stream_huffman = bytearray()
    for _ in range(4096):
        four_stream_huffman_state = (four_stream_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        four_stream_huffman.append(32 + ((four_stream_huffman_state >> 24) % 95))
    non_divisible_four_stream_huffman_state = 0x1618_0339
    non_divisible_four_stream_huffman = bytearray()
    for _ in range(5190):
        non_divisible_four_stream_huffman_state = (non_divisible_four_stream_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        non_divisible_four_stream_huffman.append(32 + ((non_divisible_four_stream_huffman_state >> 24) % 95))
    large_four_stream_huffman_state = 0x577D_F00D
    large_four_stream_huffman = bytearray()
    for _ in range(64 * 1024):
        large_four_stream_huffman_state = (large_four_stream_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        large_four_stream_huffman.append(32 + ((large_four_stream_huffman_state >> 24) % 95))
    treeless_writer_huffman_state = 0x577D_F00D
    treeless_writer_huffman = bytearray()
    for _ in range((1 << 17) + 4096):
        treeless_writer_huffman_state = (treeless_writer_huffman_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        treeless_writer_huffman.append(32 + ((treeless_writer_huffman_state >> 24) % 95))

    older_candidate_state = 0x6A09_E667
    older_candidate_prefix = bytearray()
    for _ in range(8 * 1024):
        older_candidate_state = (older_candidate_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        older_candidate_prefix.append(older_candidate_state >> 24)
    older_candidate_payload = bytes(older_candidate_prefix + older_candidate_prefix[:64] + older_candidate_prefix + b"tail-data")
    one_twenty_eight_symbol_state = 0x1357_9BDF
    one_twenty_eight_symbol_huffman = bytearray()
    for _ in range(896):
        one_twenty_eight_symbol_state = (one_twenty_eight_symbol_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        one_twenty_eight_symbol_huffman.append(1 + ((one_twenty_eight_symbol_state >> 24) & 127))
    max_direct_state = 0x1290_0F5E
    max_direct_huffman_bytes = bytearray(range(129))
    for _ in range(129 * 64 - 129):
        max_direct_state = (max_direct_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        max_direct_huffman_bytes.append((max_direct_state >> 16) % 129)
    max_direct_huffman = bytes(max_direct_huffman_bytes)
    high_byte_state = 0xFEED_BEEF
    high_byte_binary = bytearray()
    for _ in range(1024):
        high_byte_state = (high_byte_state * 1_664_525 + 1_013_904_223) & 0xFFFF_FFFF
        high_byte_binary.append(129 + ((high_byte_state >> 16) % 127))

    cases: list[tuple[str, bytes]] = [
        ("empty", b""),
        ("tiny", b"hello"),
        ("json100", json_unit * 100),
        ("alphabet200", printable * 200),
        ("long-period-pattern", b"abcdefghijklmnop" * 24),
        ("two-symbol-huffman", bytes(two_symbol_huffman)),
        ("four-symbol-huffman", bytes(four_symbol_huffman)),
        ("six-symbol-huffman", bytes(six_symbol_huffman)),
        ("eight-symbol-huffman", bytes(eight_symbol_huffman)),
        ("sixteen-symbol-huffman", bytes(sixteen_symbol_huffman)),
        ("thirty-two-symbol-huffman", bytes(thirty_two_symbol_huffman)),
        ("sixty-four-symbol-huffman", bytes(sixty_four_symbol_huffman)),
        ("printable-huffman", bytes(printable_huffman)),
        ("four-stream-huffman", bytes(four_stream_huffman)),
        ("non-divisible-four-stream-huffman", bytes(non_divisible_four_stream_huffman)),
        ("large-four-stream-huffman", bytes(large_four_stream_huffman)),
        ("treeless-writer-huffman", bytes(treeless_writer_huffman)),
        ("older-duplicate-candidate", older_candidate_payload),
        ("one-twenty-eight-symbol-huffman", bytes(one_twenty_eight_symbol_huffman)),
        ("max-direct-symbol-huffman", max_direct_huffman),
        ("high-byte-binary-fallback", bytes(high_byte_binary)),
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
    for name, frame, expected in handcrafted_frames():
        zstd_decoded = subprocess.run(
            [ZSTD, "-dcq"],
            input=frame,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        ).stdout
        if zstd_decoded != expected:
            print(
                f"zstd_native_probe_fail case={name} mode=handcrafted-zstd "
                f"decoded_bytes={len(zstd_decoded)} expected_bytes={len(expected)}"
            )
            return 1
        try:
            native_size(cli, frame, len(expected))
            native_decode(cli, frame, expected)
        except AssertionError as exc:
            print(
                f"zstd_native_probe_fail case={name} mode=handcrafted-native "
                f"input_bytes={len(expected)} frame_bytes={len(frame)} error={exc}"
            )
            print(frame.hex()[:800])
            return 1
        checked += 1

    for name, frame, expected_error in handcrafted_invalid_frames():
        zstd_failed = subprocess.run(
            [ZSTD, "-dcq"],
            input=frame,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if zstd_failed.returncode == 0:
            print(
                f"zstd_native_probe_fail case={name} mode=handcrafted-zstd-invalid "
                f"decoded_bytes={len(zstd_failed.stdout)}"
            )
            return 1
        try:
            native_error(cli, frame, expected_error)
        except AssertionError as exc:
            print(
                f"zstd_native_probe_fail case={name} mode=handcrafted-native-invalid "
                f"frame_bytes={len(frame)} error={exc}"
            )
            print(frame.hex()[:800])
            return 1
        checked += 1

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
