#!/usr/bin/env python3
"""Black-box checks for incremental gzip CLI stdin/stdout encoding."""

import argparse
from contextlib import nullcontext
import gzip
import os
from pathlib import Path
import select
import shutil
import struct
import subprocess
import tempfile
import time
import zlib


COMMAND = "encode-gzip-best-file"
TIMEOUT = 15
BLOCK = 32 * 1024
SENTINEL = b"\x00keep the existing output\xff\r\n"
PLAIN = bytes(range(256)) * 263 + b"\x00\xff\r\n\x80vort gzip stdio\x00"


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def run(argv, cwd, data=b""):
    return subprocess.run(argv, cwd=cwd, input=data, capture_output=True, timeout=TIMEOUT)


def describe(result):
    return (f"argv={result.args!r}, exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def success(label, result, stdout=None):
    require(result.returncode == 0 and result.stderr == b"", f"{label}: {describe(result)}")
    if stdout is not None:
        require(result.stdout == stdout, f"{label}: wrong stdout; {describe(result)}")
    return result.stdout


def failure(label, result, error, allowed_prefix=b""):
    require(result.returncode > 0 and f"error: {error}".encode() in result.stderr.splitlines()
            and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and only a payload prefix on stdout; {describe(result)}")


def verify_member(label, cwd, gzip_cli, wire, plain):
    require(len(wire) >= 18 and wire.startswith(b"\x1f\x8b\x08"), f"{label}: missing gzip header/footer")
    crc, size = struct.unpack("<II", wire[-8:])
    require(crc == zlib.crc32(plain) and size == len(plain) % (1 << 32), f"{label}: wrong CRC32/ISIZE")
    require(gzip.decompress(wire) == plain, f"{label}: Python gzip decoded a different payload")
    if gzip_cli is not None:
        success(f"{label}: reference gzip -dc", run([gzip_cli, "-dc"], cwd, wire), plain)


def summary(plain, wire, output):
    return f"input_bytes={len(plain)} output_bytes={len(wire)} path={output}\n".encode()


def check_modes(argv, cwd, gzip_cli):
    def encode(src, dst, *options, data=b""):
        return run([*argv, src, dst, *options], cwd, data)

    source = cwd / "input.raw"
    source.write_bytes(PLAIN)
    out = cwd / "output.gz"
    wire = success("stdin to stdout", encode("-", "-", data=PLAIN))
    verify_member("default streaming", cwd, gzip_cli, wire, PLAIN)
    success("file to stdout", encode(source.name, "-"), wire)

    out.write_bytes(SENTINEL)
    # Hold the old inode open so it cannot be reused by the new file.
    with (out.open("rb") if os.name == "posix" else nullcontext()) as old:
        success("stdin to file is quiet", encode("-", out.name, data=PLAIN), b"")
        require(out.read_bytes() == wire, "stdin to file: different encoded payload than stdout")
        if old is not None:
            require(out.stat().st_ino != os.fstat(old.fileno()).st_ino and old.read() == SENTINEL,
                    "stdin to file: existing destination was not replaced")

    result = encode(source.name, out.name)
    legacy_wire = out.read_bytes()
    success("legacy file to file", result, summary(PLAIN, legacy_wire, out.name))
    verify_member("legacy file to file", cwd, gzip_cli, legacy_wire, PLAIN)

    rsync = "--rsyncable"
    rsync_wire = success("rsyncable stdin to stdout", encode("-", "-", rsync, "fast", data=PLAIN))
    verify_member("rsyncable streaming", cwd, gzip_cli, rsync_wire, PLAIN)
    success("rsyncable file to stdout", encode(source.name, "-", "fast", rsync), rsync_wire)
    success("rsyncable stdin to file", encode("-", out.name, "fast", rsync, data=PLAIN), b"")
    require(out.read_bytes() == rsync_wire, "rsyncable stdin to file: different wire than stdout")

    exact_input = f"--max-input-len={len(PLAIN)}"
    exact_output = ("--max-output-len", str(len(wire)))
    exact_rsync_output = ("--max-output-len", str(len(rsync_wire)))
    success("exact stdin caps", encode("-", "-", exact_input, *exact_output, data=PLAIN), wire)
    success("exact named-input caps", encode(source.name, "-", *exact_output, exact_input), wire)
    success("exact rsyncable named-file caps and summary",
            encode(source.name, out.name, exact_input, "fast", *exact_rsync_output, rsync),
            summary(PLAIN, rsync_wire, out.name))
    require(out.read_bytes() == rsync_wire, "rsyncable named paths and pipes produced different wire")

    wide = str((1 << 32) + 1)
    success("caps above 32-bit usize", encode("-", "-", "--max-input-len", wide,
            f"--max-output-len={wide}", data=PLAIN), wire)
    empty = success("empty input with zero input cap", encode("-", "-", "--max-input-len=0"))
    verify_member("empty input", cwd, gzip_cli, empty, b"")
    success("empty input exact output cap", encode("-", "-", f"--max-output-len={len(empty)}"), empty)
    failure("zero output cap rejects empty gzip member", encode("-", "-", "--max-output-len=0"),
            "OutputLimitExceeded")

    same = cwd / "same.raw"
    same.write_bytes(PLAIN)
    failure("rsyncable same-path insufficient output cap",
            encode(same.name, same.name, rsync, "fast", "--max-output-len=0"), "OutputLimitExceeded")
    require(same.read_bytes() == PLAIN, "rsyncable same-path failure changed the input")
    success("rsyncable same-path replacement", encode(same.name, same.name, rsync, "fast"),
            summary(PLAIN, rsync_wire, same.name))
    require(same.read_bytes() == rsync_wire, "rsyncable same-path replacement produced different wire")

    def preserve(label, src, options, error, data=b""):
        out.write_bytes(SENTINEL)
        old_inode = out.stat().st_ino
        failure(label, encode(src, out.name, *options, data=data), error)
        require(out.read_bytes() == SENTINEL, f"{label}: existing destination changed")
        if os.name == "posix":
            require(out.stat().st_ino == old_inode, f"{label}: existing destination was replaced")

    low_input = ("--max-input-len", str(len(PLAIN) - 1))
    low_output = (f"--max-output-len={len(wire) - 1}",)
    low_rsync_output = (f"--max-output-len={len(rsync_wire) - 1}",)
    failure("stdin input cap", encode("-", "-", *low_input, data=PLAIN), "OutputLimitExceeded", wire[:-1])
    failure("stdin output cap", encode("-", "-", *low_output, data=PLAIN), "OutputLimitExceeded", wire[:-1])
    failure("named input cap preflight", encode(source.name, "-", *low_input), "OutputLimitExceeded")
    for label, cap in (("input", low_input), ("output", low_output)):
        preserve(f"stdin {label} cap with named destination", "-", cap, "OutputLimitExceeded", PLAIN)
        preserve(f"legacy file path rejects {label} cap", source.name, cap, "UnsupportedGzipStreamLimit")
    for label, cap in (("input", low_input), ("output", low_rsync_output)):
        preserve(f"rsyncable file paths honor {label} cap", source.name, (rsync, "fast", *cap),
                 "OutputLimitExceeded")

    for flag in ("--max-input-len", "--max-output-len"):
        failure(f"duplicate {flag}", encode("-", "-", f"{flag}=0", flag, "0"), "DuplicateGzipOption")
        failure(f"missing {flag} value", encode("-", "-", flag), "MissingGzipOptionValue")
        failure(f"overflowing {flag}", encode("-", "-", f"{flag}={1 << 64}"), "Overflow")
    out.unlink()
    failure("output cap with absent destination", encode("-", out.name, *low_output, data=PLAIN),
            "OutputLimitExceeded")
    require(not out.exists(), "output cap failure published a new file")
    require(not (cwd / "-").exists(), "dash was treated as a named output")


def pipe_select_supported():
    if os.name != "posix":
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


def send_prefix(proc, head):
    reader, writer = proc.stdout.fileno(), proc.stdin.fileno()
    chunk_size = min(select.PIPE_BUF, 4093)
    deadline = time.monotonic() + TIMEOUT
    decoder = zlib.decompressobj(31)
    wire, plain = bytearray(), bytearray()
    sent = 0
    while sent < len(head) or len(plain) < BLOCK:
        remaining = deadline - time.monotonic()
        require(remaining > 0, f"no complete {BLOCK}-byte prefix before stdin EOF ({len(plain)} bytes decoded)")
        reads, writes, _ = select.select([reader], [writer] if sent < len(head) else [], [], remaining)
        if reads:
            chunk = os.read(reader, 65536)
            require(chunk, "stdout closed before publishing a complete data block")
            wire.extend(chunk)
            plain.extend(decoder.decompress(chunk))
        if writes:
            sent += os.write(writer, head[sent:sent + chunk_size])
    require(not decoder.eof and head.startswith(plain), "wrong prefix or complete gzip member before stdin EOF")
    return bytes(wire)


def check_live_pipe(argv, cwd, gzip_cli):
    # Withhold the tail and EOF until the first complete block can independently
    # be decoded. The second block covers any pending sub-byte DEFLATE output.
    tail = b"\x00\xff\r\n\x80gzip tail\x00"
    for options in ((), ("--rsyncable",)):
        label = f"fragmented pipe {options or 'default'}"
        args = [*argv, "-", "-", *options]
        with subprocess.Popen(args, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, bufsize=0) as proc:
            try:
                prefix = send_prefix(proc, PLAIN)
                stdout, stderr = proc.communicate(tail, timeout=TIMEOUT)
                wire = success(label, subprocess.CompletedProcess(args, proc.returncode, prefix + stdout, stderr))
            finally:
                if proc.poll() is None:
                    proc.kill()
        verify_member(label, cwd, gzip_cli, wire, PLAIN + tail)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=Path, help="built Vort CLI executable or WASI probe")
    parser.add_argument("--wasi-runner", type=Path, help="Node WASI runner for the probe")
    args = parser.parse_args()
    argv = [str(args.cli.resolve()), COMMAND]
    mode = "native"
    if args.wasi_runner is not None:
        mode = "wasi"
        argv[:0] = ["node", "--no-warnings", str(args.wasi_runner.resolve())]
    gzip_cli = shutil.which("gzip")
    if gzip_cli is not None:
        gzip_cli = str(Path(gzip_cli).resolve())

    # The WASI runner preopens cwd as '.', so use relative file operands.
    with tempfile.TemporaryDirectory(prefix="vort-gzip-encode-stdio-") as directory:
        cwd = Path(directory)
        check_modes(argv, cwd, gzip_cli)
        if pipe_select_supported():
            check_live_pipe(argv, cwd, gzip_cli)
        else:
            print("SKIP: select does not support pipes on this platform")
    print(f"gzip_encode_stdio_cli mode={mode} decoder={'python+gzip' if gzip_cli else 'python'} status=ok")


if __name__ == "__main__":
    main()
