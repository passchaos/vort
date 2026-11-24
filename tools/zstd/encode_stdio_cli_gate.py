#!/usr/bin/env python3
"""Black-box checks for streaming Zstd CLI stdin/stdout encoding."""

import argparse
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time


COMMAND = "encode-zstd-native-stream-file"
DECODE_COMMAND = "decode-zstd-native-file-to"
MAGIC = bytes.fromhex("28b52ffd")
TIMEOUT = 15
SENTINEL = b"\x00keep the existing output\xff\n"
PROFILES = ("--profile", "--memory-profile")


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def describe(result):
    return (f"exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def success(label, result, *, stdout=None, profiles=False):
    require(result.returncode == 0, f"{label}: {describe(result)}")
    if stdout is not None:
        require(result.stdout == stdout, f"{label}: wrong stdout; {describe(result)}")
    if profiles:
        for marker in (b"zstd_profile ", b"zstd_memory_profile "):
            require(any(line.startswith(marker) for line in result.stderr.splitlines()),
                    f"{label}: missing {marker!r} on stderr; {describe(result)}")
    else:
        require(result.stderr == b"", f"{label}: unexpected stderr; {describe(result)}")
    return result.stdout


def failure(label, result, error, allowed_prefix=b""):
    require(result.returncode > 0 and f"error: {error}".encode() in result.stderr.splitlines()
            and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and no non-payload stdout; {describe(result)}")


def frame_header(wire):
    """Return (content size or None, checksum flag, first block offset), or None if partial."""
    if len(wire) < 5:
        return None
    require(wire.startswith(MAGIC), f"not a Zstd frame; first bytes: {wire[:16]!r}")
    descriptor = wire[4]
    single_segment = bool(descriptor & 0x20)
    size_width = (int(single_segment), 2, 4, 8)[descriptor >> 6]
    size_offset = 5 + int(not single_segment) + (0, 1, 2, 4)[descriptor & 3]
    block_offset = size_offset + size_width
    if len(wire) < block_offset:
        return None
    size = None
    if size_width:
        size = int.from_bytes(wire[size_offset:block_offset], "little") + (256 if size_width == 2 else 0)
    return size, bool(descriptor & 4), block_offset


def run(args, cwd, data=b""):
    return subprocess.run(args, cwd=cwd, input=data, capture_output=True, timeout=TIMEOUT)


def verify_frame(label, decoder, cwd, wire, plain, content_size, *, checksum=True):
    header = frame_header(wire)
    require(header is not None and header[:2] == (content_size, checksum),
            f"{label}: expected FCS {content_size!r} and checksum flag {checksum}, got {header!r}")
    success(f"{label} round trip", run(decoder, cwd, wire), stdout=plain)


def check_modes(prefix, decoder, cwd):
    def encode(src, dst, *options, data=b""):
        return run([*prefix, COMMAND, src, dst, *options], cwd, data)

    plain = bytes(range(256)) + b"\x00\xff\r\n\x80vort zstd stdio\x00"
    pledge = f"--stream-size={len(plain)}"
    source = cwd / "input.raw"
    source.write_bytes(plain)
    out = cwd / "output.zst"

    def round_trip(label, result, data, size, *, checksum=True):
        wire = success(label, result)
        verify_frame(label, decoder, cwd, wire, data, size, checksum=checksum)
        return wire

    unknown = round_trip("stdin to stdout without pledge", encode("-", "-", data=plain), plain, None)
    known = round_trip("stdin to stdout with pledge", encode("-", "-", pledge, data=plain), plain, len(plain))
    named = round_trip("file to stdout", encode(source.name, "-"), plain, len(plain))
    omitted = ("auto", "false", "false")
    pledged_without_fcs = round_trip("pledge with explicit FCS and checksum omission",
                                    encode("-", "-", *omitted, pledge, data=plain), plain, None, checksum=False)
    round_trip("empty stdin without pledge", encode("-", "-", "--max-input-len=0"), b"", None)
    round_trip("empty stdin with zero pledge", encode("-", "-", "--stream-size=0"), b"", 0)

    out.write_bytes(SENTINEL)
    old_inode = out.stat().st_ino
    success("stdin to file is quiet", encode("-", out.name, data=plain), stdout=b"")
    require(out.read_bytes() == unknown, "stdin to file: different encoded payload than stdout")
    if os.name == "posix":
        require(out.stat().st_ino != old_inode, "stdin to file: destination was overwritten in place")

    success("profiles on stdin to stdout", encode("-", "-", *PROFILES, data=plain), stdout=unknown, profiles=True)
    success("profiles on file to stdout", encode(source.name, "-", *PROFILES), stdout=named, profiles=True)
    success("profiles on stdin to file", encode("-", out.name, *PROFILES, data=plain), stdout=b"", profiles=True)
    require(out.read_bytes() == unknown, "profiles on stdin to file: changed encoded payload")

    explicit_size = ("auto", "true", "true")
    failure("explicit FCS without a pledge", encode("-", "-", *explicit_size, data=plain), "MissingZstdStreamSize")
    failure("duplicate zero pledge", encode("-", "-", "--stream-size=0", "--stream-size=0"), "DuplicateZstdOption")
    failure("pledge on named input to stdout", encode(source.name, "-", pledge), "UnsupportedZstdStreamSize")

    def preserve_on_failure(label, args, error, data=b""):
        out.write_bytes(SENTINEL)
        old_inode = out.stat().st_ino
        failure(label, run([*prefix, *args], cwd, data), error)
        require(out.read_bytes() == SENTINEL, f"{label}: existing destination changed")
        if os.name == "posix":
            require(out.stat().st_ino == old_inode, f"{label}: existing destination was replaced")

    preserve_on_failure("pledge on named input to file", (COMMAND, source.name, out.name, pledge),
                        "UnsupportedZstdStreamSize")
    for options in (explicit_size, omitted):
        for difference in (-1, 1):
            label = f"content_size={options[2]}, pledge off by {difference:+}"
            wrong_pledge = f"--stream-size={len(plain) + difference}"
            preserve_on_failure(label, (COMMAND, "-", out.name, *options, wrong_pledge), "SizeMismatch", plain)
            if options == omitted:
                failure(f"{label} on stdout", encode("-", "-", *options, wrong_pledge, data=plain),
                        "SizeMismatch", pledged_without_fcs[:-1])
    for command, operands in (
        ("encode-zstd-native-hex", ()),  # A leading option must not be treated as literal text.
        ("encode-zstd-native-bytes-hex", ("00ff",)),
        ("encode-zstd-native-file-hex", (source.name,)),
    ):
        failure(f"pledge on {command}", run([*prefix, command, *operands, pledge], cwd), "UnsupportedZstdStreamSize")
    preserve_on_failure("pledge on one-shot file encoding", ("encode-zstd-native-file", source.name, out.name, pledge),
                        "UnsupportedZstdStreamSize")

    exact_input = f"--max-input-len={len(plain)}"
    exact_output = f"--max-output-len={len(unknown)}"
    success("exact stdin input/output caps", encode("-", "-", exact_input, exact_output, data=plain), stdout=unknown)
    wide_limit = (1 << 32) + 1
    success("streaming limits above 32-bit usize", encode("-", "-", f"--max-input-len={wide_limit}",
            f"--max-output-len={wide_limit}", data=plain), stdout=unknown)
    preserve_on_failure("short input for a 64-bit pledge", (COMMAND, "-", out.name, *omitted, f"--stream-size={wide_limit}"),
                        "SizeMismatch", plain)
    success("exact pledged input/output caps", encode("-", "-", *explicit_size, pledge, exact_input,
                                                     f"--max-output-len={len(known)}", data=plain), stdout=known)
    for flag, count in (("--max-input-len", len(plain)), ("--max-output-len", len(unknown))):
        low = f"{flag}={count - 1}"
        failure(f"insufficient {flag} on stdout", encode("-", "-", low, data=plain),
                "OutputLimitExceeded", unknown[:-1])
        preserve_on_failure(f"insufficient {flag} with named output", (COMMAND, "-", out.name, low),
                            "OutputLimitExceeded", plain)


def pipe_select_supported():
    if os.name == "nt":
        return False
    reader, writer = os.pipe()
    try:
        select.select([reader], [writer], [], 0)
        return True
    except (OSError, ValueError):
        return False
    finally:
        os.close(reader)
        os.close(writer)


def has_first_nonfinal_block(wire):
    header = frame_header(wire)
    if header is None:
        return False
    _, _, offset = header
    if len(wire) < offset + 3:
        return False
    value = int.from_bytes(wire[offset:offset + 3], "little")
    kind, size = (value >> 1) & 3, value >> 3
    require(not value & 1 and kind != 3 and size > 0, "expected a nonempty, non-final Zstd block before EOF")
    return len(wire) >= offset + 3 + (1 if kind == 1 else size)


def send_prefix(proc, head):
    reader, writer = proc.stdout.fileno(), proc.stdin.fileno()
    limit = min(select.PIPE_BUF, 4093)  # Bound each write after readiness; cross block boundaries.
    deadline = time.monotonic() + TIMEOUT
    seen = bytearray()
    sent = 0
    while sent < len(head) or not has_first_nonfinal_block(seen):
        delay = deadline - time.monotonic()
        require(delay > 0, "first compressed block not published before stdin EOF")
        reads, writes, _ = select.select([reader], [writer] if sent < len(head) else [], [], delay)
        if reads:
            chunk = os.read(reader, 65536)
            require(chunk, "stdout closed before publishing the first compressed block")
            seen.extend(chunk)
        if writes:
            sent += os.write(writer, head[sent:sent + limit])
    return bytes(seen)


def check_live_pipe(prefix, decoder, cwd):
    # One full 128 KiB block plus a partial block; the binary tail is withheld
    # until at least one full data block (not just the frame header) is visible.
    head = b"\xff" * (160 * 1024)
    tail = b"\x00\xff\r\n\x80zstd tail\x00"
    args = [*prefix, COMMAND, "-", "-", "raw_or_rle"]
    if pipe_select_supported():
        with subprocess.Popen(args, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              bufsize=0) as proc:
            try:
                seen = send_prefix(proc, head)
                stdout, stderr = proc.communicate(tail, timeout=TIMEOUT)
                result = subprocess.CompletedProcess(args, proc.returncode, seen + stdout, stderr)
            finally:
                if proc.poll() is None:
                    proc.kill()
    else:
        print("SKIP: select does not support pipes on this platform (checking the large round trip only)")
        result = run(args, cwd, head + tail)
    label = "fragmented input over 128 KiB"
    wire = success(label, result)
    verify_frame(label, decoder, cwd, wire, head + tail, None)


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
    # The WASI runner preopens the current directory as '.'.
    with tempfile.TemporaryDirectory(prefix="vort-zstd-encode-stdio-") as directory:
        cwd = Path(directory)
        check_modes(prefix, decoder, cwd)
        check_live_pipe(prefix, decoder, cwd)
    print(f"zstd_encode_stdio_cli mode={mode} decoder={reference} status=ok")


if __name__ == "__main__":
    main()
