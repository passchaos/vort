#!/usr/bin/env python3
"""Black-box checks for streaming Brotli CLI stdin/stdout decoding."""

import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

from large_window_decode_cli import PLAIN as LARGE_PLAIN, WIRE as LARGE_WIRE


COMMAND = "decode-br-file-to"
TIMEOUT = 15
SENTINEL = b"\x00keep the existing output\xff\n"

# Node v26.10.0 (upstream Brotli 1.2.0), quality 5, lgwin 16. Encode FIRST
# with createBrotliCompress, FLUSH to obtain HEAD, then end(LAST) for TAIL.
# Checked in so native tests do not require Node or a Brotli executable.
FIRST = b"\x00\xff\r\n\x80vort Brotli first\x00" * 64
LAST = b"\xfe\x00vort Brotli last\r\n\x81" * 8192
HEAD = bytes.fromhex("f05b0080b88db983c677edde0b0221a2ddd8af5ac8b1a22ae3dd6ed5c3684d25f5582803")
TAIL = bytes.fromhex("faff0f008cd4484d73bb5468082c00ff14249acfb240c294715c7a1f90c5ff2700233552d3dc2e0002200e0b40f71200")
WIRE = HEAD + TAIL
PLAIN = FIRST + LAST
EMPTY_WIRE = b"\x06"  # brotliCompressSync(b"", same quality and lgwin)
TRAILING = b"\x00"


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def describe(result):
    return (f"exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def success(label, result, stdout=b""):
    require(result.returncode == 0 and result.stderr == b"" and result.stdout == stdout,
            f"{label}: expected silent stderr and {len(stdout)} exact stdout bytes; {describe(result)}")


def failure(label, result, error, allowed_prefix=b""):
    require(result.returncode > 0 and f"error: {error}".encode() in result.stderr
            and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and no non-payload stdout; {describe(result)}")


def check_modes(prefix, cwd):
    def decode(src, dst, *options, wire=b""):
        return subprocess.run([*prefix, COMMAND, src, dst, *options], cwd=cwd, input=wire,
                              capture_output=True, timeout=TIMEOUT)

    source = cwd / "input.br"
    source.write_bytes(WIRE)
    out = cwd / "output"
    cap = str(len(PLAIN))
    low_cap = str(len(PLAIN) - 1)

    success("stdin to stdout with exact cap", decode("-", "-", cap, wire=WIRE), PLAIN)
    success("file to stdout with exact cap", decode(source.name, "-", cap), PLAIN)
    out.write_bytes(SENTINEL)
    old_inode = out.stat().st_ino
    success("stdin to file", decode("-", out.name, cap, wire=WIRE))
    require(out.read_bytes() == PLAIN, "stdin to file: wrong payload")
    if os.name == "posix":
        require(out.stat().st_ino != old_inode, "stdin to file: destination was overwritten in place")

    summary = f"br_compressed_bytes={len(WIRE)} decoded_bytes={len(PLAIN)} path={out.name}\n".encode()
    out.write_bytes(SENTINEL)
    success("legacy file to file", decode(source.name, out.name, cap), summary)
    require(out.read_bytes() == PLAIN, "legacy file to file: wrong payload")

    success("encoded empty Brotli stream with zero cap", decode("-", "-", "0", wire=EMPTY_WIRE))

    def reject(label, bad_wire, error, allowed_prefix=b"", *options):
        failure(label, decode("-", "-", *options, wire=bad_wire), error, allowed_prefix)
        out.write_bytes(SENTINEL)
        failure(f"{label} to file", decode("-", out.name, *options, wire=bad_wire), error)
        require(out.read_bytes() == SENTINEL, f"{label}: existing destination changed")

    reject("empty stdin", b"", "TruncatedFrame")
    reject("truncated header", WIRE[:1], "TruncatedFrame")
    reject("truncated stream", WIRE[:-1], "TruncatedFrame", PLAIN)
    reject("trailing byte", WIRE + TRAILING, "TrailingData", PLAIN)
    reject("insufficient output cap", WIRE, "OutputLimitExceeded", PLAIN[:-1], low_cap)
    failure("file to stdout with insufficient cap", decode(source.name, "-", low_cap),
            "OutputLimitExceeded", PLAIN[:-1])
    out.unlink()
    failure("truncation to a missing file", decode("-", out.name, wire=WIRE[:-1]), "TruncatedFrame")
    require(not out.exists(), "truncation published a new destination")

    reject("default window rejects upstream Large Window", LARGE_WIRE, "CorruptFrame")
    large_cap = str(len(LARGE_PLAIN))
    success("Large Window opt-in to stdout", decode("-", "-", large_cap, "--large-window", wire=LARGE_WIRE),
            LARGE_PLAIN)
    success("Large Window opt-in to file", decode("-", out.name, "--large-window", large_cap, wire=LARGE_WIRE))
    require(out.read_bytes() == LARGE_PLAIN, "Large Window opt-in to file: wrong payload")


def pipe_select_supported():
    if os.name == "nt":
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


@contextmanager
def pipe_decode(prefix, cwd):
    with subprocess.Popen([*prefix, COMMAND, "-", "-"], cwd=cwd, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0) as proc:
        try:
            yield proc
        finally:
            if proc.poll() is None:
                proc.kill()


def pipe_expect(proc, label, expected):
    fd = proc.stdout.fileno()
    deadline = time.monotonic() + TIMEOUT
    seen = bytearray()
    while len(seen) < len(expected):
        remaining = max(0, deadline - time.monotonic())
        require(select.select([fd], [], [], remaining)[0], f"{label}: timed out before stdin EOF")
        # A buffered read could still wait for more data after select returns.
        chunk = os.read(fd, len(expected) - len(seen))
        require(chunk, f"{label}: stdout closed after only {len(seen)} bytes")
        seen.extend(chunk)
    require(seen == expected, f"{label}: wrong payload (first 32 bytes: {seen[:32]!r})")


def pipe_finish(proc, tail):
    stdout, stderr = proc.communicate(tail, timeout=TIMEOUT)
    return subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr)


def check_live_pipes(prefix, cwd):
    if not pipe_select_supported():
        print("SKIP: select does not support pipes on this platform")
        return

    with pipe_decode(prefix, cwd) as proc:
        # Only a byte of the Brotli header is present for the first read.
        proc.stdin.write(HEAD[:1])
        require(not select.select([proc.stdout.fileno()], [], [], 0.02)[0], "output before any payload was sent")
        proc.stdin.write(HEAD[1:])
        # The upstream encoder's flushed prefix is decodable without the
        # final meta-block or EOF; the CLI must not wait for either.
        pipe_expect(proc, "flushed prefix", FIRST)
        success("fragmented pipe tail", pipe_finish(proc, TAIL), LAST)

    with pipe_decode(prefix, cwd) as proc:
        proc.stdin.write(WIRE)
        # The final byte is needed to emit all of PLAIN. Add the trailing
        # byte only after that progress, so it cannot share the input read
        # containing the end of the valid stream.
        pipe_expect(proc, "complete stream with stdin still open", PLAIN)
        failure("trailing byte in a later pipe read", pipe_finish(proc, TRAILING), "TrailingData")


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
    # The WASI runner preopens its working directory as '.', so all file
    # operands are relative to this scratch directory in both modes.
    with tempfile.TemporaryDirectory(prefix="vort-br-stdio-") as directory:
        cwd = Path(directory)
        check_modes(prefix, cwd)
        check_live_pipes(prefix, cwd)
    print(f"br_stdio_cli mode={mode} status=ok")


if __name__ == "__main__":
    main()
