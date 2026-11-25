#!/usr/bin/env python3
"""Black-box checks for bounded Zstd seekable CLI encoding on files and pipes."""

import argparse
import os
from pathlib import Path
import random
import select
import shutil
import struct
import subprocess
import tempfile
import time

from encode_stdio_cli_gate import (
    DECODE_COMMAND,
    SENTINEL,
    TIMEOUT,
    describe,
    failure,
    frame_header,
    pipe_select_supported,
    require,
    run,
    success,
)


COMMAND = "encode-zstd-seekable-file"
TABLE_MAGIC = 0x184D2A5E
FOOTER_MAGIC = 0x8F92EAB1
FRAME_SIZE = 4096


def verify_frame(label, decoder, cwd, frame, plain, checksum):
    header = frame_header(frame)
    require(header is not None and header[:2] == (len(plain), checksum),
            f"{label}: wrong frame content size or checksum flag: {header!r}")
    _, _, offset = header
    # Walk block headers independently of the seek table: each entry must
    # cover exactly one data frame, not a fragment or several concatenated frames.
    while True:
        require(offset + 3 <= len(frame), f"{label}: missing block header")
        block = int.from_bytes(frame[offset:offset + 3], "little")
        kind, size = (block >> 1) & 3, block >> 3
        require(kind != 3, f"{label}: reserved block type")
        offset += 3 + (1 if kind == 1 else size)
        if block & 1:
            break
    require(offset + (4 if checksum else 0) == len(frame),
            f"{label}: seek entry ends outside the frame boundary")
    success(f"{label} decode", run(decoder, cwd, frame), stdout=plain)


def verify_archive(label, decoder, cwd, wire, plain, frame_size, *,
                   seek_checksum, frame_checksum, expected_hashes=None):
    require(len(wire) >= 17, f"{label}: missing seek table")
    count, descriptor, magic = struct.unpack_from("<IBI", wire, len(wire) - 9)
    require(magic == FOOTER_MAGIC, f"{label}: incorrect seek footer magic")
    require(descriptor == (0x80 if seek_checksum else 0), f"{label}: wrong seek descriptor")
    expected_count = max(1, (len(plain) + frame_size - 1) // frame_size)
    require(count == expected_count, f"{label}: expected {expected_count} frames, got {count}")
    entry_size = 12 if seek_checksum else 8
    table_bytes = count * entry_size + 9
    table_offset = len(wire) - table_bytes - 8
    require(table_offset >= 0, f"{label}: truncated seek table")
    require(struct.unpack_from("<II", wire, table_offset) == (TABLE_MAGIC, table_bytes),
            f"{label}: wrong skippable table header")

    frames = []
    offset = 0
    for i in range(count):
        frame_label = f"{label} frame {i}"
        entry_offset = table_offset + 8 + i * entry_size
        compressed, decompressed = struct.unpack_from("<II", wire, entry_offset)
        chunk = plain[i * frame_size:(i + 1) * frame_size]
        require(decompressed == len(chunk), f"{frame_label}: wrong seek entry plaintext size")
        require(0 < compressed <= table_offset - offset, f"{frame_label}: invalid compressed size")
        frame = wire[offset:offset + compressed]
        verify_frame(frame_label, decoder, cwd, frame, chunk, frame_checksum)
        digest = None
        if seek_checksum:
            digest = wire[entry_offset + 8:entry_offset + 12]
            # Both checksums store the low 32 bits of XXH64. The standard
            # frame trailer was verified by the decoder, independently of the table.
            expected = frame[-4:] if frame_checksum else expected_hashes[i]
            require(digest == expected, f"{frame_label}: wrong seek checksum")
        frames.append((frame, digest))
        offset += compressed
    require(offset == table_offset, f"{label}: seek entries do not cover the data prefix")
    return frames


def assert_destination(label, out, inode, payload, *, replaced):
    require(out.read_bytes() == payload, f"{label}: wrong destination content")
    if os.name == "posix":
        require((out.stat().st_ino != inode) == replaced,
                f"{label}: destination replacement must occur on success only")


def check_rejections(encode, source, out, plain, options, first_frame):
    cap = "--max-frames=3"
    failure("missing stdin frame cap", encode("-", "-", *options, data=plain),
            "MissingZstdSeekableMaxFrames")
    failure("unknown option", encode("-", "-", *options, cap, "--unknown=true", data=plain),
            "UnknownZstdOption")
    for option in (*options, cap):
        label = f"duplicate {option.split('=')[0]}"
        failure(label, encode("-", "-", *options, cap, option, data=plain), "DuplicateZstdOption")

    for invalid in ("--frame-size=0", "--max-frames=0", "--max-frames=134217729",
                    "--seek-checksum=yes", "--frame-checksum=1", "--max-total-memory=-1"):
        # Named input rules out a missing stdin cap as the cause of failure.
        result = encode(source.name, "-", invalid)
        require(result.returncode > 0 and result.stdout == b"",
                f"accepted invalid option {invalid}: {describe(result)}")

    low = "--max-frames=1"
    failure("stdin frame cap overflow to stdout",
            encode("-", "-", *options, low, data=plain), "OutputLimitExceeded", first_frame)
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    for src, data in ((source.name, b""), ("-", plain)):
        label = f"frame cap overflow from {src!r} to a named destination"
        failure(label, encode(src, out.name, *options, low, data=data), "OutputLimitExceeded")
        assert_destination(label, out, inode, SENTINEL, replaced=False)

    label = "insufficient total memory"
    result = encode(source.name, out.name, f"--frame-size={FRAME_SIZE}", "--max-total-memory=1")
    require(result.returncode > 0 and result.stdout == b"", f"{label}: {describe(result)}")
    assert_destination(label, out, inode, SENTINEL, replaced=False)

    out.unlink()
    failure("overflow must not publish a new destination",
            encode("-", out.name, *options, low, data=plain), "OutputLimitExceeded")
    require(not out.exists(), "frame cap overflow published a new destination")


def check_modes(prefix, decoder, cwd):
    def encode(src, dst, *options, data=b""):
        return run([*prefix, COMMAND, src, dst, *options], cwd, data)

    first = bytes(range(256)) * (FRAME_SIZE // 256)
    second = first[::-1]
    plain = first + second + b"\x00\xff\r\n\x80vort short tail\x00"
    source = cwd / "input.raw"
    source.write_bytes(plain)
    out = cwd / "output.zst"
    sizing = f"--frame-size={FRAME_SIZE}"
    memory = f"--max-total-memory={64 << 20}"
    options = (sizing, memory, "--seek-checksum=true", "--frame-checksum=true")

    label = "named input infers the frame count for binary stdout"
    wire = success(label, encode(source.name, "-", *options))
    frames = verify_archive(label, decoder, cwd, wire, plain, FRAME_SIZE,
                            seek_checksum=True, frame_checksum=True)

    cap = "--max-frames=3"
    label = "named input to atomic destination with exact frame cap"
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    success(label, encode(source.name, out.name, *options, cap))
    assert_destination(label, out, inode, wire, replaced=True)

    label = "stdin to named destination is quiet and atomic"
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    success(label, encode("-", out.name, *options, cap, data=plain), stdout=b"")
    assert_destination(label, out, inode, wire, replaced=True)

    label = "seek checksums without frame checksums"
    unchecked = success(label, encode("-", "-", sizing, memory, "--seek-checksum=true",
                                      "--frame-checksum=false", cap, data=plain))
    verify_archive(label, decoder, cwd, unchecked, plain, FRAME_SIZE,
                   seek_checksum=True, frame_checksum=False, expected_hashes=[digest for _, digest in frames])

    label = "exact frame multiple at the stdin cap"
    exact = first + second
    exact_wire = success(label, encode("-", "-", sizing, "--max-frames=2",
                                      "--seek-checksum=false", "--frame-checksum=true", data=exact))
    verify_archive(label, decoder, cwd, exact_wire, exact, FRAME_SIZE,
                   seek_checksum=False, frame_checksum=True)

    label = "empty stdin still produces one frame"
    no_checksums = (sizing, "--seek-checksum=false", "--frame-checksum=false")
    empty = success(label, encode("-", "-", *no_checksums, "--max-frames=1"))
    verify_archive(label, decoder, cwd, empty, b"", FRAME_SIZE,
                   seek_checksum=False, frame_checksum=False)
    (cwd / "empty.raw").write_bytes(b"")
    success("empty named input infers one frame", encode("empty.raw", "-", *no_checksums), stdout=empty)

    check_rejections(encode, source, out, plain, options, frames[0][0])


def read_before_eof(proc, head):
    reader, writer = proc.stdout.fileno(), proc.stdin.fileno()
    limit = min(select.PIPE_BUF, 4093)
    deadline = time.monotonic() + TIMEOUT
    seen = bytearray()
    sent = 0
    while True:
        if sent == len(head):
            header = frame_header(seen)
            if header is not None and len(seen) > header[2] + 3:
                return bytes(seen)  # At least one block payload byte, not only a frame header.
        delay = deadline - time.monotonic()
        require(delay > 0, "first seekable frame payload not published before stdin EOF")
        reads, writes, _ = select.select([reader], [writer] if sent < len(head) else [], [], delay)
        if reads:
            chunk = os.read(reader, 65536)
            require(chunk, "stdout closed before publishing the first seekable frame")
            seen.extend(chunk)
        if writes:
            sent += os.write(writer, head[sent:sent + limit])


def check_live_pipe(prefix, decoder, cwd):
    # Keep the pipe open after sending a full, incompressible frame that is
    # larger than I/O buffering. The short final frame is withheld until data arrives.
    head = random.Random(0x5EECA8E).randbytes(256 * 1024)
    tail = b"\x00\xff\r\n\x80pipe tail\x00"
    args = [*prefix, COMMAND, "-", "-", f"--frame-size={len(head)}", "--max-frames=2",
            "--seek-checksum=true", "--frame-checksum=true"]
    if pipe_select_supported():
        with subprocess.Popen(args, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, bufsize=0) as proc:
            try:
                seen = read_before_eof(proc, head)
                stdout, stderr = proc.communicate(tail, timeout=TIMEOUT)
                result = subprocess.CompletedProcess(args, proc.returncode, seen + stdout, stderr)
            finally:
                if proc.poll() is None:
                    proc.kill()
    else:
        print("SKIP: select does not support pipes on this platform (checking round trip only)")
        result = run(args, cwd, head + tail)
    label = "fragmented stdin/stdout pipe"
    verify_archive(label, decoder, cwd, success(label, result), head + tail, len(head),
                   seek_checksum=True, frame_checksum=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=Path, help="built Vort CLI executable or WASI probe")
    parser.add_argument("--wasi-runner", type=Path, help="Node WASI runner for the probe")
    args = parser.parse_args()
    prefix = [str(args.cli.resolve())]
    mode = "native"
    if args.wasi_runner is not None:
        mode = "wasi"
        prefix[:0] = ["node", "--no-warnings", str(args.wasi_runner.resolve())]
    if zstd := shutil.which("zstd"):
        decoder = [str(Path(zstd).resolve()), "-q", "-d", "-c"]
        reference = "zstd"
    else:
        decoder = [*prefix, DECODE_COMMAND, "-", "-"]
        reference = "vort"
    # The WASI runner preopens its working directory as '.'.
    with tempfile.TemporaryDirectory(prefix="vort-zstd-seekable-cli-") as directory:
        cwd = Path(directory)
        check_modes(prefix, decoder, cwd)
        check_live_pipe(prefix, decoder, cwd)
    print(f"zstd_seekable_cli mode={mode} decoder={reference} status=ok")


if __name__ == "__main__":
    main()
