#!/usr/bin/env python3
"""Black-box checks for incremental gzip CLI stdin/stdout decoding."""

import argparse
from contextlib import nullcontext
import gzip
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time


COMMANDS = ("decode-gzip-file", "decode-gzip-concat-file")
TIMEOUT = 15
HEADER_SIZE = 10
FOOTER_SIZE = 8
SENTINEL = b"\x00keep the existing output\xff\r\n"

FIRST = b"\x00\xff\r\n\x80vort gzip first\x00" + bytes(range(256))
SECOND = b"\xff\x00vort gzip second member\r\n" * 4096
FIRST_WIRE = gzip.compress(FIRST, compresslevel=0, mtime=0)
EMPTY_WIRE = gzip.compress(b"", mtime=0)
SECOND_WIRE = gzip.compress(SECOND, mtime=0)
WIRE = FIRST_WIRE + EMPTY_WIRE + SECOND_WIRE
PLAIN = FIRST + SECOND


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def describe(result):
    return (f"argv={result.args!r}, exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def success(label, result, stdout=b""):
    require(result.returncode == 0 and result.stderr == b"" and result.stdout == stdout,
            f"{label}: expected silent stderr and {len(stdout)} exact stdout bytes; {describe(result)}")


def failure(label, result, error, allowed_prefix=b""):
    require(result.returncode > 0 and f"error: {error}".encode() in result.stderr.splitlines()
            and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and only a payload prefix on stdout; {describe(result)}")


def corrupt_footer(wire, offset):
    return wire[:offset] + bytes([wire[offset] ^ 1]) + wire[offset + 1:]


def check_modes(argv, cwd):
    def decode(src, dst, cap=None, *, wire=b"", allow_zero_padding=False):
        options = [] if cap is None else [str(cap)]
        if allow_zero_padding:
            options.append("--allow-zero-padding")
        return subprocess.run([*argv, src, dst, *options], cwd=cwd, input=wire,
                              capture_output=True, timeout=TIMEOUT)

    source = cwd / "input.gz"
    source.write_bytes(WIRE)
    out = cwd / "output"
    cap = len(PLAIN)

    success("stdin to stdout", decode("-", "-", wire=WIRE), PLAIN)
    success("stdin to stdout with exact cumulative cap", decode("-", "-", cap, wire=WIRE), PLAIN)
    success("file to stdout with exact cumulative cap", decode(source.name, "-", cap), PLAIN)
    success("streaming cap above 32-bit usize", decode("-", "-", (1 << 32) + cap, wire=WIRE), PLAIN)

    out.write_bytes(SENTINEL)
    # Hold the old inode open on POSIX so it cannot be reused by the new file.
    with (out.open("rb") if os.name == "posix" else nullcontext()) as old:
        success("stdin to file", decode("-", out.name, cap, wire=WIRE))
        require(out.read_bytes() == PLAIN, "stdin to file: wrong payload")
        if old is not None:
            require(out.stat().st_ino != os.fstat(old.fileno()).st_ino and old.read() == SENTINEL,
                    "stdin to file: existing destination was not replaced")

    out.write_bytes(SENTINEL)
    summary = f"compressed_bytes={len(WIRE)} decoded_bytes={cap} path={out.name}\n".encode()
    success("legacy file to file", decode(source.name, out.name, cap), summary)
    require(out.read_bytes() == PLAIN, "legacy file to file: wrong payload")

    success("empty member with zero cap", decode("-", "-", 0, wire=EMPTY_WIRE))
    success("empty member after cumulative cap is exhausted", decode("-", "-", cap, wire=WIRE + EMPTY_WIRE), PLAIN)

    def reject(label, wire, error, allowed_prefix=b"", cap=None, *, allow_zero_padding=False):
        options = {"wire": wire, "allow_zero_padding": allow_zero_padding}
        failure(label, decode("-", "-", cap, **options), error, allowed_prefix)
        out.write_bytes(SENTINEL)
        old_inode = out.stat().st_ino
        failure(f"{label} to file", decode("-", out.name, cap, **options), error)
        require(out.read_bytes() == SENTINEL, f"{label}: existing destination changed")
        if os.name == "posix":
            require(out.stat().st_ino == old_inode, f"{label}: existing destination was replaced")

    reject("empty stdin", b"", "TruncatedFrame")
    reject("truncated first header", FIRST_WIRE[:HEADER_SIZE - 1], "TruncatedFrame")
    reject("truncated first Deflate body", FIRST_WIRE[:-FOOTER_SIZE - 1], "TruncatedFrame", FIRST[:-1])
    reject("missing first footer", FIRST_WIRE[:-FOOTER_SIZE], "TruncatedFrame", FIRST)
    reject("truncated subsequent header", FIRST_WIRE + EMPTY_WIRE + SECOND_WIRE[:HEADER_SIZE - 1],
           "TruncatedFrame", FIRST)
    reject("truncated subsequent footer", WIRE[:-1], "TruncatedFrame", PLAIN)
    reject("bad first CRC32", corrupt_footer(FIRST_WIRE, -8), "ChecksumMismatch", FIRST)
    reject("bad first ISIZE", corrupt_footer(FIRST_WIRE, -4), "SizeMismatch", FIRST)
    reject("bad subsequent CRC32", corrupt_footer(WIRE, -8), "ChecksumMismatch", PLAIN)
    reject("bad subsequent ISIZE", corrupt_footer(WIRE, -4), "SizeMismatch", PLAIN)
    reject("bad CRC32 in empty member after cap is exhausted", WIRE + corrupt_footer(EMPTY_WIRE, -8),
           "ChecksumMismatch", PLAIN, cap)
    reject("short trailing nonmember bytes", WIRE + b"\x00" * (HEADER_SIZE - 1), "TruncatedFrame", PLAIN)
    reject("full trailing nonmember header", WIRE + b"\x00" * HEADER_SIZE, "BadGzipHeader", PLAIN)
    reject("insufficient cumulative cap", WIRE, "OutputLimitExceeded", PLAIN[:-1], cap - 1)
    reject("nonempty member after cap is exhausted", WIRE, "OutputLimitExceeded", FIRST, len(FIRST))
    failure("file to stdout with insufficient cumulative cap", decode(source.name, "-", cap - 1),
            "OutputLimitExceeded", PLAIN[:-1])

    # Padding exceeds the CLI read buffer and must be consumed without output.
    padding = b"\x00" * (32 * 1024 + 1)
    padded = WIRE + padding
    source.write_bytes(padded)
    success("padded file to stdout at exact cap", decode(source.name, "-", cap, allow_zero_padding=True), PLAIN)
    success("padded stdin to file", decode("-", out.name, wire=padded, allow_zero_padding=True))
    require(out.read_bytes() == PLAIN, "padded stdin to file: wrong payload")
    success("padded empty member at zero cap", decode("-", "-", 0, wire=EMPTY_WIRE + padding, allow_zero_padding=True))
    reject("junk after padding", padded + b"!", "TrailingData", PLAIN, cap, allow_zero_padding=True)
    reject("member after padding", FIRST_WIRE + b"\x00" + SECOND_WIRE, "TrailingData", FIRST,
           allow_zero_padding=True)
    reject("padding without a member", padding[:HEADER_SIZE], "BadGzipHeader", allow_zero_padding=True)

    out.unlink()
    failure("truncation to missing destination", decode("-", out.name, wire=WIRE[:-1]), "TruncatedFrame")
    require(not out.exists(), "truncation published a new destination")


def pipe_select_supported():
    if os.name != "posix":
        return False
    reader, writer = os.pipe()
    try:
        select.select([reader], [], [], 0)
        return True
    except (OSError, ValueError):
        return False
    finally:
        os.close(reader)
        os.close(writer)


def pipe_expect(proc, label, expected):
    fd = proc.stdout.fileno()
    deadline = time.monotonic() + TIMEOUT
    seen = bytearray()
    while len(seen) < len(expected):
        remaining = max(0, deadline - time.monotonic())
        require(select.select([fd], [], [], remaining)[0],
                f"{label}: timed out before the footer and stdin EOF ({len(seen)} bytes read)")
        # A buffered read can block even after select reports readiness.
        chunk = os.read(fd, len(expected) - len(seen))
        require(chunk, f"{label}: stdout closed after only {len(seen)} bytes")
        seen.extend(chunk)
    require(seen == expected, f"{label}: wrong pre-footer payload (first 32 bytes: {seen[:32]!r})")


def check_live_pipe(argv, cwd):
    with subprocess.Popen([*argv, "-", "-", str(len(PLAIN))], cwd=cwd, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0) as proc:
        try:
            # Force a short input read: no footer or EOF is available until
            # we receive the first member's payload.
            proc.stdin.write(FIRST_WIRE[:-FOOTER_SIZE])
            pipe_expect(proc, f"{argv[-1]}: first member", FIRST)

            # Finish that member and cross an empty member into the next one.
            # Its compressed prefix fits in the pipe; its payload does not.
            proc.stdin.write(FIRST_WIRE[-FOOTER_SIZE:] + EMPTY_WIRE + SECOND_WIRE[:-FOOTER_SIZE])
            early = 64 * 1024
            pipe_expect(proc, f"{argv[-1]}: subsequent member", SECOND[:early])
            stdout, stderr = proc.communicate(SECOND_WIRE[-FOOTER_SIZE:] + EMPTY_WIRE, timeout=TIMEOUT)
            success("fragmented concatenated pipe tail",
                    subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr), SECOND[early:])
        finally:
            if proc.poll() is None:
                proc.kill()


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

    if gzip_cli := shutil.which("gzip"):
        success("reference gzip -dc", subprocess.run([gzip_cli, "-dc"], input=WIRE,
                                                     capture_output=True, timeout=TIMEOUT), PLAIN)

    live = pipe_select_supported()
    if not live:
        print("SKIP: select does not support pipes on this platform")
    # The WASI runner preopens cwd as '.', so use relative file operands in both modes.
    with tempfile.TemporaryDirectory(prefix="vort-gzip-stdio-") as directory:
        cwd = Path(directory)
        for command in COMMANDS:
            argv = [*prefix, command]
            check_modes(argv, cwd)
            if live:
                check_live_pipe(argv, cwd)
    print(f"gzip_stdio_cli mode={mode} status=ok")


if __name__ == "__main__":
    main()
