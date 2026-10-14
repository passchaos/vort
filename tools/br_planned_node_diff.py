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
    quality_modes = ("generic", "text", "font")
    for quality in range(12):
        for planned_mode, (name, expected) in zip(quality_modes, cases):
            mode = f"q{quality}-{planned_mode}-{name}"
            encoded = subprocess.check_output([sys.argv[1], mode])
            actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
            if actual != expected:
                raise SystemExit(f"{mode}: node output mismatch")
            print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = (
        b"alpha beta gamma delta alpha beta gamma delta " * 64
        + b"qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
        + b"omega theta lambda omega theta lambda " * 64
    )
    encoded = subprocess.check_output([sys.argv[1], "chunked-multiblock"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("chunked-multiblock: node output mismatch")
    print(f"brotli planned chunked-multiblock node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b"abcdefghijklmnopqrstuvwxyz012345" * 2049
    encoded = subprocess.check_output([sys.argv[1], "chunked-large"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("chunked-large: node output mismatch")
    print(f"brotli planned chunked-large node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b"abcd0123" * ((1 << 24) // 8) + b"abcd0123abcd0123a"
    encoded = subprocess.check_output([sys.argv[1], "ratio-oversized"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-oversized: node output mismatch")
    if len(encoded) >= len(expected) // 100:
        raise SystemExit("ratio-oversized: expected compressed multi-block output")
    print(f"brotli planned ratio-oversized node diff: encoded={len(encoded)} decoded={len(actual)}")
    state = 0x12345678
    expected = bytearray(96 * 1024)
    for i in range(len(expected)):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        nibble = state >> 28
        expected[i] = nibble if i < len(expected) // 6 else 240 + nibble
    encoded = subprocess.check_output([sys.argv[1], "ratio-literal-split"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-literal-split: node output mismatch")
    print(f"brotli planned ratio-literal-split node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = open("src/br/dictionary.bin", "rb").read()
    encoded = subprocess.check_output([sys.argv[1], "ratio-command-split"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-command-split: node output mismatch")
    print(f"brotli planned ratio-command-split node diff: encoded={len(encoded)} decoded={len(actual)}")
    command_count = 6144
    region_commands = command_count // 3
    outer_insert_lens = (1, 2, 3, 4, 5, 6, 8, 10)
    middle_insert_lens = (34, 50, 66, 98, 130, 194, 322, 578)
    expected = bytearray(486912)
    position = 0
    for i in range(command_count):
        middle = region_commands <= i < 2 * region_commands
        insert_len = middle_insert_lens[i & 7] if middle else outer_insert_lens[i & 7]
        copy_len = 40 if middle else 2
        byte = 240 + (i & 15) if middle else i & 15
        expected[position : position + insert_len + copy_len] = bytes([byte]) * (insert_len + copy_len)
        position += insert_len + copy_len
    encoded = subprocess.check_output([sys.argv[1], "clustered-command-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("clustered-command-types: node output mismatch")
    print(f"brotli planned clustered-command-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    command_count = 8192
    boundaries = (901, 2305, 5179, 7001)
    region_types = (0, 1, 0, 2, 0)
    adaptive_insert_lens = (
        outer_insert_lens,
        middle_insert_lens,
        (18, 20, 22, 24, 26, 28, 30, 32),
    )
    adaptive_copy_lens = (2, 40, 6)
    adaptive_byte_bases = (0, 64, 128)
    expected = bytearray()
    region = 0
    for i in range(command_count):
        if region < len(boundaries) and i == boundaries[region]:
            region += 1
        tree = region_types[region]
        insert_len = adaptive_insert_lens[tree][i & 7]
        copy_len = adaptive_copy_lens[tree]
        byte = adaptive_byte_bases[tree] + (i & 15)
        expected.extend(bytes([byte]) * (insert_len + copy_len))
    encoded = subprocess.check_output([sys.argv[1], "adaptive-command-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("adaptive-command-types: node output mismatch")
    print(f"brotli planned adaptive-command-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    command_count = 8192
    first_split = command_count // 6
    second_split = command_count * 2 // 6
    third_split = command_count * 3 // 6
    expected = bytearray(1_242_295)
    position = 0
    for i in range(command_count):
        region = 0 if i < first_split else 1 if i < second_split else 2 if i < third_split else 3
        insert_len = outer_insert_lens[i & 7] if region & 1 == 0 else middle_insert_lens[i & 7]
        copy_len = 2 if region & 1 == 0 else 40
        byte = i & 15 if region & 1 == 0 else 240 + (i & 15)
        expected[position : position + insert_len + copy_len] = bytes([byte]) * (insert_len + copy_len)
        position += insert_len + copy_len
    encoded = subprocess.check_output([sys.argv[1], "alternating-command-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("alternating-command-types: node output mismatch")
    print(f"brotli planned alternating-command-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    command_count = 8192
    first_split = command_count // 6
    second_split = command_count * 2 // 6
    third_split = command_count * 3 // 6
    insert_lens = (
        outer_insert_lens,
        (34, 50, 66, 98, 130, 194, 322, 578),
        (18, 20, 22, 24, 26, 28, 30, 32),
    )
    copy_lens = (2, 40, 6)
    expected = bytearray(385911)
    position = 0
    for i in range(command_count):
        region = 0 if i < first_split else 1 if i < second_split else 2 if i < third_split else 3
        tree = 0 if region == 3 else region
        insert_len = insert_lens[tree][i & 7]
        copy_len = copy_lens[tree]
        byte = tree * 112 + (i & 15)
        expected[position : position + insert_len + copy_len] = bytes([byte]) * (insert_len + copy_len)
        position += insert_len + copy_len
    encoded = subprocess.check_output([sys.argv[1], "reuse-first-three-command-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("reuse-first-three-command-types: node output mismatch")
    print(f"brotli planned reuse-first-three-command-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    command_count = 8192
    first_split = command_count // 6
    second_split = command_count * 2 // 6
    third_split = command_count * 3 // 6
    insert_lens = (
        outer_insert_lens,
        middle_insert_lens,
        (18, 20, 22, 24, 26, 28, 30, 32),
        (2, 4, 6, 8, 10, 12, 14, 16),
    )
    copy_lens = (2, 40, 6, 258)
    expected = bytearray()
    for i in range(command_count):
        region = 0 if i < first_split else 1 if i < second_split else 2 if i < third_split else 3
        insert_len = insert_lens[region][i & 7]
        copy_len = copy_lens[region]
        byte = region * 64 + (i & 15)
        expected.extend(bytes([byte]) * (insert_len + copy_len))
    encoded = subprocess.check_output([sys.argv[1], "four-command-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("four-command-types: node output mismatch")
    print(f"brotli planned four-command-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    dynamic_literal_cases = (
        ("five-literal-types", (0, 1, 2, 3, 4, 4)),
        ("six-literal-types", (0, 1, 2, 3, 4, 5)),
        ("six-region-clustered-literal-types", (0, 1, 2, 0, 1, 2)),
    )
    literal_bases = (0, 48, 96, 144, 192, 224)
    for mode, region_types in dynamic_literal_cases:
        expected = bytearray(12288)
        for i in range(len(expected)):
            tree = region_types[i // 2048]
            expected[i] = literal_bases[tree] + (i & 15)
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    boundaries = (901, 2305, 5179, 7001)
    region_types = (0, 1, 0, 2, 0)
    literal_bases = (0, 96, 192)
    expected = bytearray(8192)
    region = 0
    for i in range(len(expected)):
        if region < len(boundaries) and i == boundaries[region]:
            region += 1
        expected[i] = literal_bases[region_types[region]] + (i & 31)
    encoded = subprocess.check_output([sys.argv[1], "adaptive-literal-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("adaptive-literal-types: node output mismatch")
    print(f"brotli planned adaptive-literal-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    encoded = subprocess.check_output([sys.argv[1], "adaptive-literal-context-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("adaptive-literal-context-types: node output mismatch")
    print(f"brotli planned adaptive-literal-context-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = bytes(range(256))
    encoded = subprocess.check_output([sys.argv[1], "maximum-adaptive-literal-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("maximum-adaptive-literal-types: node output mismatch")
    print(f"brotli planned maximum-adaptive-literal-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    encoded = subprocess.check_output([sys.argv[1], "maximum-joint-literal-contexts"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("maximum-joint-literal-contexts: node output mismatch")
    print(f"brotli planned maximum-joint-literal-contexts node diff: encoded={len(encoded)} decoded={len(actual)}")
    dynamic_command_insert_lens = (
        outer_insert_lens,
        middle_insert_lens,
        (18, 20, 22, 24, 26, 28, 30, 32),
        (2, 4, 6, 8, 10, 12, 14, 16),
        (3, 5, 7, 9, 11, 13, 15, 17),
        (6, 10, 14, 18, 22, 26, 30, 34),
    )
    dynamic_command_copy_lens = (2, 40, 6, 258, 12, 80)
    dynamic_command_byte_bases = (0, 64, 128, 192, 32, 224)
    dynamic_command_cases = (
        ("five-command-types", (0, 1, 2, 3, 4, 4)),
        ("six-command-types", (0, 1, 2, 3, 4, 5)),
        ("six-region-clustered-command-types", (0, 1, 2, 0, 1, 2)),
    )
    for mode, region_types in dynamic_command_cases:
        expected = bytearray()
        for i in range(12288):
            tree = region_types[i // 2048]
            insert_len = dynamic_command_insert_lens[tree][i & 7]
            copy_len = dynamic_command_copy_lens[tree]
            byte = dynamic_command_byte_bases[tree] + (i & 15)
            expected.extend(bytes([byte]) * (insert_len + copy_len))
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b"a" * (64 * 1024 + 8192 * 4)
    encoded = subprocess.check_output([sys.argv[1], "four-distance-types"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("four-distance-types: node output mismatch")
    print(f"brotli planned four-distance-types node diff: encoded={len(encoded)} decoded={len(actual)}")
    distance_cluster_cases = (
        ("adaptive-distance-types", 64 * 1024 + 8192 * 4),
        ("maximum-adaptive-distance-types", 64 * 1024 + 256 * 4),
        ("clustered-distance-types", 64 * 1024 + 12288 * 4),
        ("alternating-distance-types", 64 * 1024 + 8192 * 4),
        ("reuse-first-three-distance-types", 64 * 1024 + 8192 * 4),
    )
    for mode, decoded_len in distance_cluster_cases:
        expected = b"a" * decoded_len
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    expected = b"a" * (64 * 1024 + 4096 * 4)
    encoded = subprocess.check_output([sys.argv[1], "selected-distance-parameters"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("selected-distance-parameters: node output mismatch")
    print(f"brotli planned selected-distance-parameters node diff: encoded={len(encoded)} decoded={len(actual)}")
    dynamic_distance_cases = (
        "five-distance-types",
        "six-distance-types",
        "six-region-clustered-distance-types",
    )
    expected = b"a" * (64 * 1024 + 12288 * 4)
    for mode in dynamic_distance_cases:
        encoded = subprocess.check_output([sys.argv[1], mode])
        actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
        if actual != expected:
            raise SystemExit(f"{mode}: node output mismatch")
        print(f"brotli planned {mode} node diff: encoded={len(encoded)} decoded={len(actual)}")
    state = 0x12345678
    random_tail = bytearray(512)
    for i in range(len(random_tail)):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        random_tail[i] = state >> 24
    expected = b"a" * 512 + random_tail
    encoded = subprocess.check_output([sys.argv[1], "incremental-planned"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("incremental-planned: node output mismatch")
    print(f"brotli planned incremental-planned node diff: encoded={len(encoded)} decoded={len(actual)}")
    state = 0x9E3779B9
    first = bytearray(4096)
    for i in range(len(first)):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        first[i] = state >> 24
    expected = first + first
    encoded = subprocess.check_output([sys.argv[1], "incremental-planned-history"])
    actual = subprocess.run(["node", "-e", script], input=encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("incremental-planned-history: node output mismatch")
    if len(encoded) >= len(expected) // 2 + 64:
        raise SystemExit("incremental-planned-history: cross-block match was not retained")
    print(f"brotli planned incremental-planned-history node diff: encoded={len(encoded)} decoded={len(actual)}")
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
    expected = b"INFORMATION"
    ratio_encoded = subprocess.check_output([sys.argv[1], "ratio-dictionary-uppercase"])
    actual = subprocess.run(["node", "-e", script], input=ratio_encoded, check=True, capture_output=True).stdout
    if actual != expected:
        raise SystemExit("ratio-dictionary-uppercase: node output mismatch")
    if len(ratio_encoded) >= len(expected) + 4:
        raise SystemExit("ratio-dictionary-uppercase: expected dictionary compression")
    print(f"brotli planned ratio-dictionary-uppercase node diff: encoded={len(ratio_encoded)} decoded={len(actual)}")
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
    expected_index_bytes = 192_354
    if index_bytes != expected_index_bytes:
        raise SystemExit(
            f"dictionary index size mismatch: expected {expected_index_bytes}, got {index_bytes}"
        )
    print(f"brotli planned dictionary index: bytes={index_bytes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
