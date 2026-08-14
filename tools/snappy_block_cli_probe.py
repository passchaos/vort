#!/usr/bin/env python3
import binascii
import struct
import os
import pathlib
import subprocess
import sys
import tempfile


PAYLOADS = [
    b"",
    b"hello",
    b"abcabcabcabc" * 16,
    bytes((i * 37 + 11) % 251 for i in range(1024)),
]

COMPRESSIBLE_PAYLOAD_INDEX = 2

KNOWN_BLOCKS = [
    ("hello-literal", "051068656c6c6f", b"hello"),
    ("copy1", "0c086162631503", b"abcabcabcabc"),
    ("copy2", "0500610e0100", b"aaaaa"),
    ("copy4", "05007a0f01000000", b"zzzzz"),
]


def crc32c_table():
    table = []
    for i in range(256):
        crc = i
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0x82F63B78
            else:
                crc >>= 1
        table.append(crc & 0xFFFFFFFF)
    return table


CRC32C_TABLE = crc32c_table()


def crc32c(data):
    crc = 0xFFFFFFFF
    for byte in data:
        crc = CRC32C_TABLE[(crc ^ byte) & 0xFF] ^ (crc >> 8)
    return (~crc) & 0xFFFFFFFF


def masked_crc32c(data):
    crc = crc32c(data)
    return (((crc >> 15) | ((crc << 17) & 0xFFFFFFFF)) + 0xA282EAD8) & 0xFFFFFFFF


def chunk(chunk_type, payload):
    return bytes([chunk_type]) + len(payload).to_bytes(3, "little") + payload


def snappy_identifier():
    return chunk(0xFF, b"sNaPpY")


def checked_chunk(chunk_type, plain, payload):
    return chunk(chunk_type, struct.pack("<I", masked_crc32c(plain)) + payload)


def snappy_varint(value):
    out = bytearray()
    while value >= 0x80:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def literal_block(data):
    out = bytearray(snappy_varint(len(data)))
    length_minus_one = len(data) - 1
    byte_count = 1
    tmp = length_minus_one
    while tmp >= 0x100:
        byte_count += 1
        tmp >>= 8
    out.append((59 + byte_count) << 2)
    tmp = length_minus_one
    for _ in range(byte_count):
        out.append(tmp & 0xFF)
        tmp >>= 8
    out.extend(data)
    return bytes(out)


def run(args, cwd, expect_ok=True):
    result = subprocess.run(
        args,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if expect_ok and result.returncode != 0:
        raise RuntimeError(
            f"command failed: {' '.join(args)}\nstdout={result.stdout.decode(errors='replace')}\nstderr={result.stderr.decode(errors='replace')}"
        )
    if not expect_ok and result.returncode == 0:
        raise RuntimeError(f"command unexpectedly succeeded: {' '.join(args)}")
    return result


def parse_hex(stdout):
    return bytes.fromhex(stdout.decode().strip())


def require_fields(text: str, fields: dict[str, int], context: str) -> None:
    for key, expected in fields.items():
        marker = f"{key}={expected}"
        if marker not in text:
            raise RuntimeError(f"bad {context} summary: missing {marker!r} in {text!r}")


def field_value(text: str, key: str) -> int:
    prefix = f"{key}="
    for token in text.split():
        if token.startswith(prefix):
            return int(token[len(prefix) :])
    raise RuntimeError(f"summary missing {key!r}: {text!r}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: snappy_block_cli_probe.py <vort-cli>")
    cli = pathlib.Path(sys.argv[1]).resolve()
    root = pathlib.Path(__file__).resolve().parents[1]

    checked = 0
    for index, payload in enumerate(PAYLOADS):
        payload_hex = binascii.hexlify(payload).decode()
        encoded = parse_hex(run([str(cli), "encode-snappy-block-hex", payload_hex], root).stdout)
        if index == COMPRESSIBLE_PAYLOAD_INDEX and len(encoded) >= len(payload):
            raise RuntimeError(f"compressible raw block did not shrink: encoded={len(encoded)} plain={len(payload)}")
        size = run([str(cli), "size-snappy-block-hex", encoded.hex(), str(len(payload))], root).stdout.decode()
        if f"decoded_bytes={len(payload)}" not in size:
            raise RuntimeError(f"bad size output: {size}")
        summary = run([str(cli), "summary-snappy-block-hex", encoded.hex()], root).stdout.decode()
        require_fields(summary, {"decoded_bytes": len(payload)}, "block hex")
        if index == COMPRESSIBLE_PAYLOAD_INDEX:
            if field_value(summary, "copies") <= 0:
                raise RuntimeError(f"compressible block summary has no copy tokens: {summary!r}")
        decoded = run([str(cli), "decode-snappy-block-hex", encoded.hex(), str(len(payload))], root).stdout
        if f"decoded_bytes={len(payload)}".encode() not in decoded:
            raise RuntimeError(f"bad decode output: {decoded!r}")
        if len(payload) > 0:
            run([str(cli), "decode-snappy-block-hex", encoded.hex(), str(len(payload) - 1)], root, expect_ok=False)
        checked += 1

    for name, block_hex, payload in KNOWN_BLOCKS:
        output = run([str(cli), "decode-snappy-block-hex", block_hex, str(len(payload))], root).stdout
        if f"decoded_bytes={len(payload)}".encode() not in output:
            raise RuntimeError(f"known block {name} decoded with unexpected output: {output!r}")
        summary = run([str(cli), "summary-snappy-block-hex", block_hex], root).stdout.decode()
        require_fields(summary, {"decoded_bytes": len(payload)}, f"known block {name}")
        checked += 1

    for index, payload in enumerate(PAYLOADS):
        payload_hex = binascii.hexlify(payload).decode()
        encoded = parse_hex(run([str(cli), "encode-snappy-frame-hex", payload_hex], root).stdout)
        if index == COMPRESSIBLE_PAYLOAD_INDEX and len(encoded) >= len(payload):
            raise RuntimeError(f"compressible frame did not shrink: encoded={len(encoded)} plain={len(payload)}")
        if index == COMPRESSIBLE_PAYLOAD_INDEX and encoded[10] != 0x00:
            raise RuntimeError(f"compressible frame did not use compressed chunk: type={encoded[10]}")
        size = run([str(cli), "size-snappy-frame-hex", encoded.hex(), str(len(payload))], root).stdout.decode()
        if f"decoded_bytes={len(payload)}" not in size:
            raise RuntimeError(f"bad frame size output: {size}")
        summary = run([str(cli), "summary-snappy-frame-hex", encoded.hex()], root).stdout.decode()
        require_fields(
            summary,
            {
                "decoded_bytes": len(payload),
                "stream_identifiers": 1,
                "skippable_chunks": 0,
            },
            "frame hex",
        )
        decoded = run([str(cli), "decode-snappy-frame-hex", encoded.hex(), str(len(payload))], root).stdout
        if f"decoded_bytes={len(payload)}".encode() not in decoded:
            raise RuntimeError(f"bad frame decode output: {decoded!r}")
        if len(payload) > 0:
            run([str(cli), "decode-snappy-frame-hex", encoded.hex(), str(len(payload) - 1)], root, expect_ok=False)
        checked += 1

    first_frame = parse_hex(run([str(cli), "encode-snappy-frame-hex", b"hello".hex()], root).stdout)
    second_frame = parse_hex(run([str(cli), "encode-snappy-frame-hex", b"world".hex()], root).stdout)
    concatenated = first_frame + second_frame
    size = run([str(cli), "size-snappy-frame-hex", concatenated.hex(), "10"], root).stdout.decode()
    if "decoded_bytes=10" not in size:
        raise RuntimeError(f"bad concatenated frame size output: {size}")
    summary = run([str(cli), "summary-snappy-frame-hex", concatenated.hex()], root).stdout.decode()
    require_fields(summary, {"decoded_bytes": 10, "stream_identifiers": 2}, "concatenated frame")
    decoded = run([str(cli), "decode-snappy-frame-hex", concatenated.hex(), "10"], root).stdout
    if b"decoded_bytes=10" not in decoded:
        raise RuntimeError(f"bad concatenated frame decode output: {decoded!r}")
    checked += 1

    known_payload = b"abcabcabcabc"
    compressed_frame = (
        snappy_identifier()
        + chunk(0x80, b"metadata")
        + checked_chunk(0x00, known_payload, bytes.fromhex("0c086162631503"))
    )
    output = run([str(cli), "decode-snappy-frame-hex", compressed_frame.hex(), str(len(known_payload))], root).stdout
    if f"decoded_bytes={len(known_payload)}".encode() not in output:
        raise RuntimeError(f"compressed frame decoded with unexpected output: {output!r}")
    summary = run([str(cli), "summary-snappy-frame-hex", compressed_frame.hex()], root).stdout.decode()
    require_fields(
        summary,
        {
            "decoded_bytes": len(known_payload),
            "compressed_chunks": 1,
            "skippable_chunks": 1,
            "skippable_payload_bytes": len(b"metadata"),
        },
        "compressed frame",
    )
    checked += 1

    corrupt = bytearray(compressed_frame)
    corrupt[-1] ^= 0x01
    run([str(cli), "size-snappy-frame-hex", bytes(corrupt).hex(), str(len(known_payload))], root, expect_ok=False)
    run([str(cli), "decode-snappy-frame-hex", bytes(corrupt).hex(), str(len(known_payload))], root, expect_ok=False)
    checked += 1

    for reserved_type in (0x02, 0x7F):
        reserved = snappy_identifier() + chunk(reserved_type, b"")
        run([str(cli), "size-snappy-frame-hex", reserved.hex(), "0"], root, expect_ok=False)
        run([str(cli), "decode-snappy-frame-hex", reserved.hex(), "0"], root, expect_ok=False)
        checked += 1

    skippable_before_identifier = chunk(0x80, b"") + snappy_identifier()
    run([str(cli), "size-snappy-frame-hex", skippable_before_identifier.hex(), "0"], root, expect_ok=False)
    run([str(cli), "decode-snappy-frame-hex", skippable_before_identifier.hex(), "0"], root, expect_ok=False)
    checked += 1

    for chunk_type in (0x00, 0x01):
        truncated_checked_payload = snappy_identifier() + chunk(chunk_type, b"\x00\x00\x00")
        run([str(cli), "size-snappy-frame-hex", truncated_checked_payload.hex(), "0"], root, expect_ok=False)
        run([str(cli), "decode-snappy-frame-hex", truncated_checked_payload.hex(), "0"], root, expect_ok=False)
        checked += 1

    with tempfile.TemporaryDirectory(prefix="vort-snappy-") as td:
        tmp = pathlib.Path(td)
        oversized_payload = b"x" * (64 * 1024 + 1)
        oversized_frame = snappy_identifier() + checked_chunk(0x00, oversized_payload, literal_block(oversized_payload))
        oversized_path = tmp / "oversized.sz"
        oversized_out = tmp / "oversized.out"
        oversized_path.write_bytes(oversized_frame)
        # This frame is intentionally too large for a single Snappy framed
        # compressed chunk.  Keep it on disk rather than passing a 128 KiB+
        # hex argument, which can exceed per-argument limits on some CI hosts.
        run([str(cli), "size-snappy-frame-file", str(oversized_path), str(len(oversized_payload))], root, expect_ok=False)
        run([str(cli), "decode-snappy-frame-file-to", str(oversized_path), str(oversized_out), str(len(oversized_payload))], root, expect_ok=False)
        checked += 1

        for i, payload in enumerate(PAYLOADS):
            src = tmp / f"case-{i}.bin"
            block = tmp / f"case-{i}.snappy-block"
            out = tmp / f"case-{i}.out"
            frame = tmp / f"case-{i}.sz"
            frame_out = tmp / f"case-{i}.frame.out"
            src.write_bytes(payload)
            run([str(cli), "encode-snappy-block-file", str(src), str(block)], root)
            run([str(cli), "size-snappy-block-file", str(block), str(len(payload))], root)
            summary = run([str(cli), "summary-snappy-block-file", str(block)], root).stdout.decode()
            require_fields(summary, {"decoded_bytes": len(payload)}, "block file")
            run([str(cli), "decode-snappy-block-file-to", str(block), str(out), str(len(payload))], root)
            if out.read_bytes() != payload:
                raise RuntimeError(f"file roundtrip mismatch for case {i}")
            if len(payload) > 0:
                run(
                    [str(cli), "decode-snappy-block-file-to", str(block), str(out), str(len(payload) - 1)],
                    root,
                    expect_ok=False,
                )
            checked += 1

            run([str(cli), "encode-snappy-frame-file", str(src), str(frame)], root)
            run([str(cli), "size-snappy-frame-file", str(frame), str(len(payload))], root)
            summary = run([str(cli), "summary-snappy-frame-file", str(frame)], root).stdout.decode()
            require_fields(summary, {"decoded_bytes": len(payload), "stream_identifiers": 1}, "frame file")
            run([str(cli), "decode-snappy-frame-file-to", str(frame), str(frame_out), str(len(payload))], root)
            if frame_out.read_bytes() != payload:
                raise RuntimeError(f"frame file roundtrip mismatch for case {i}")
            if len(payload) > 0:
                run(
                    [str(cli), "decode-snappy-frame-file-to", str(frame), str(frame_out), str(len(payload) - 1)],
                    root,
                    expect_ok=False,
                )
            checked += 1

    print(f"snappy_block_cli_probe=ok cases={checked}")


if __name__ == "__main__":
    os.environ.setdefault("LC_ALL", "C")
    main()
