#!/usr/bin/env python3
"""Black-box checks for verified Zstd seekable file ranges on native and WASI."""

import argparse
import errno
import os
from pathlib import Path
import struct
import tempfile

from encode_stdio_cli_gate import (
    MAGIC,
    SENTINEL,
    describe,
    failure,
    frame_header,
    require,
    run,
    success,
)
from seekable_cli_gate import COMMAND as ENCODE_COMMAND
from seekable_cli_gate import FOOTER_MAGIC, TABLE_MAGIC, assert_destination


COMMAND = "decode-zstd-seekable-range-file"
FRAME_SIZE = 4096
FOUR_GIB = 1 << 32


def make_archive(prefix, cwd):
    first = bytes(range(256)) * (FRAME_SIZE // 256)
    tail = b"\x00\xff\r\n\x80seekable range\x00"
    plain = first + first[::-1] + tail
    source = cwd / "input.raw"
    source.write_bytes(plain)
    wire = success(
        "encode three checksummed frames",
        run([
            *prefix, ENCODE_COMMAND, source.name, "-", f"--frame-size={FRAME_SIZE}",
            "--seek-checksum=true", "--frame-checksum=true",
        ], cwd),
    )

    # Locate the checksum fields independently of the range reader.
    count, descriptor, magic = struct.unpack_from("<IBI", wire, len(wire) - 9)
    require((count, descriptor, magic) == (3, 0x80, FOOTER_MAGIC), "wrong seekable footer")
    table_bytes = count * 12 + 9
    table_offset = len(wire) - table_bytes - 8
    require(struct.unpack_from("<II", wire, table_offset) == (TABLE_MAGIC, table_bytes),
            "wrong seekable table header")
    windows = []
    checksum_offsets = []
    start = 0
    for i, size in enumerate((FRAME_SIZE, FRAME_SIZE, len(tail))):
        entry = table_offset + 8 + i * 12
        compressed, decoded = struct.unpack_from("<II", wire, entry)
        end = start + compressed
        require(decoded == size and start < end <= table_offset, f"wrong extent for entry {i}")
        frame = wire[start:end]
        header = frame_header(frame)
        require(header is not None and header[:2] == (size, True) and header[2] + 7 <= len(frame),
                f"wrong checksummed frame header for entry {i}")
        if frame[4] & 0x20:  # Single-segment windows equal the frame content size.
            windows.append(size)
        else:
            base = 1 << (10 + (frame[5] >> 3))
            windows.append(base + (base >> 3) * (frame[5] & 7))
        checksum_offsets.append((end - 4, entry + 8))
        start = end
    require(start == table_offset, "indexed frames do not end at the table")
    return plain, wire, windows, checksum_offsets[1]


def check_ranges(decode, cwd, archive, plain, wire, windows):
    out = cwd / "output.raw"
    offset = FRAME_SIZE - 5
    length = FRAME_SIZE + 8  # Partial first and third frames, with the whole second frame.
    expected = plain[offset:offset + length]
    caps = ("--max-frames=3", f"--max-window-size={max(windows)}",
            f"--max-frame-decoded-size={FRAME_SIZE}")
    success("cross-frame binary stdout with exact caps",
            decode(archive.name, "-", offset, length, *caps), stdout=expected)

    label = "cross-frame range atomically replaces a named file"
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    success(label, decode(archive.name, out.name, offset, length))
    assert_destination(label, out, inode, expected, replaced=True)

    success("zero length at EOF", decode(archive.name, "-", len(plain), 0), stdout=b"")
    tail_size = len(plain) - 2 * FRAME_SIZE
    success("limits ignore the unselected full-size frames",
            decode(archive.name, "-", len(plain) - 2, 2,
                   f"--max-frame-decoded-size={tail_size}", f"--max-window-size={windows[-1]}"),
            stdout=plain[-2:])
    for offset, length in (
        (len(plain), 1), (len(plain) + 1, 0), (len(plain) - 2, 3),
        (FOUR_GIB + 1, 1), (1, FOUR_GIB + 1), ((1 << 64) - 1, 2),
    ):
        failure(f"out-of-bounds range {offset}+{length}",
                decode(archive.name, "-", offset, length), "RangeOutOfBounds")

    failure("stdin is not a seekable input", decode("-", "-", 0, 1, data=wire),
            "UnsupportedZstdSeekableInput")
    result = decode(".", "-", 0, 1)
    require(result.returncode > 0 and result.stdout == b"",
            f"accepted a directory as seekable input: {describe(result)}")

    for label, offset, option in (
        ("full index entry count", 0, "--max-frames=2"),
        ("selected frame window", windows.index(max(windows)) * FRAME_SIZE,
         f"--max-window-size={max(windows) - 1}"),
        ("full selected frame decoded size", 0, f"--max-frame-decoded-size={FRAME_SIZE - 1}"),
    ):
        failure(label, decode(archive.name, "-", offset, 1, option), "OutputLimitExceeded")


def check_corruption(decode, cwd, plain, wire, checksum_offsets):
    out = cwd / "output.raw"
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    for kind, checksum in zip(("frame", "seek-table"), checksum_offsets):
        archive = cwd / f"corrupt-{kind}.zst"
        corrupt = bytearray(wire)
        corrupt[checksum] ^= 1  # Change only this checksum of the second frame.
        archive.write_bytes(corrupt)

        success(f"range before unselected bad {kind} checksum",
                decode(archive.name, "-", FRAME_SIZE - 5, 5),
                stdout=plain[FRAME_SIZE - 5:FRAME_SIZE])
        success(f"range after unselected bad {kind} checksum",
                decode(archive.name, "-", 2 * FRAME_SIZE, 3),
                stdout=plain[2 * FRAME_SIZE:2 * FRAME_SIZE + 3])
        success(f"zero range does not verify bad {kind} checksum",
                decode(archive.name, "-", len(plain), 0), stdout=b"")
        failure(f"selected bad {kind} checksum outside the requested bytes",
                decode(archive.name, "-", FRAME_SIZE, 2), "ChecksumMismatch")

        offset = FRAME_SIZE - 7
        verified = plain[offset:FRAME_SIZE]
        label = f"bad {kind} checksum publishes only the preceding verified intersection"
        result = decode(archive.name, "-", offset, 12)
        failure(label, result, "ChecksumMismatch", verified)
        require(result.stdout == verified, f"{label}: missing verified output; {describe(result)}")

        label = f"late {kind} checksum failure leaves named output untouched"
        failure(label, decode(archive.name, out.name, offset, 12), "ChecksumMismatch")
        assert_destination(label, out, inode, SENTINEL, replaced=False)
        new = cwd / "unpublished.raw"
        failure(f"late {kind} checksum failure does not create named output",
                decode(archive.name, new.name, offset, 12), "ChecksumMismatch")
        require(not new.exists(), f"late {kind} checksum failure published a new destination")


def write_sparse_archive(path, plain):
    if os.name != "posix":
        return False
    extent = (FOUR_GIB // 2) + 16
    # Two valid skippable frames consume no decoded bytes. The selected raw
    # frame and terminal seek table both start beyond the 32-bit boundary.
    skipped = struct.pack("<II", 0x184D2A50, extent - 8)
    raw_last_block = ((len(plain) << 3) | 1).to_bytes(3, "little")
    frame = MAGIC + bytes((0x20, len(plain))) + raw_last_block + plain
    entries = struct.pack("<IIIIII", extent, 0, extent, 0, len(frame), len(plain))
    footer = struct.pack("<IBI", 3, 0, FOOTER_MAGIC)
    table = struct.pack("<II", TABLE_MAGIC, len(entries) + len(footer)) + entries + footer
    try:
        with path.open("wb") as out:
            out.write(skipped)
            # Verify hole support with a small gap before extending to 4 GiB.
            out.seek(1 << 20)
            out.write(b"\x00")
            out.flush()
            if os.fstat(out.fileno()).st_blocks * 512 >= 1 << 20:
                return False
            out.seek(extent)
            out.write(skipped)
            out.seek(2 * extent)
            out.write(frame + table)
    except OSError as err:
        if err.errno in (errno.EFBIG, errno.EINVAL, errno.EOVERFLOW):
            return False
        raise
    info = path.stat()
    require(info.st_size == 2 * extent + len(frame) + len(table), "wrong sparse archive length")
    require(info.st_blocks * 512 < 1 << 20, "sparse archive allocated too much storage")
    return True


def check_sparse(decode, cwd):
    plain = b"\x00\xffrange beyond 4 GiB\x00"
    path = cwd / "wide-sparse.zst"
    if not write_sparse_archive(path, plain):
        print("SKIP: host filesystem does not support the sparse >4 GiB seekable fixture")
        return "skipped"
    success("range from a sparse frame beyond 4 GiB",
            decode(path.name, "-", 1, len(plain) - 2, "--max-frames=3"), stdout=plain[1:-1])
    return "ok"


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

    # The WASI runner preopens its working directory as '.'.
    with tempfile.TemporaryDirectory(prefix="vort-zstd-seekable-range-cli-") as directory:
        cwd = Path(directory)

        def decode(src, dst, offset, length, *options, data=b""):
            return run([*prefix, COMMAND, src, dst, str(offset), str(length), *options], cwd, data)

        plain, wire, windows, checksum_offsets = make_archive(prefix, cwd)
        archive = cwd / "input.zst"
        archive.write_bytes(wire)
        check_ranges(decode, cwd, archive, plain, wire, windows)
        check_corruption(decode, cwd, plain, wire, checksum_offsets)
        sparse = check_sparse(decode, cwd)
    print(f"zstd_seekable_range_cli mode={mode} sparse={sparse} status=ok")


if __name__ == "__main__":
    main()
