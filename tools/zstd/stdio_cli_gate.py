#!/usr/bin/env python3
"""Black-box checks for incremental Zstd CLI stdin/stdout decoding."""

import argparse
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time


COMMAND = "decode-zstd-native-file-to"
MAGIC = bytes.fromhex("28b52ffd")
TIMEOUT = 15
SENTINEL = b"\x00keep the existing output\xff\n"


def block_header(size, *, kind=0, last=True):
    return ((size << 3) | (kind << 1) | last).to_bytes(3, "little")


def raw_block(data, *, last=True):
    return block_header(len(data), last=last) + data


def small_frame(data):
    return MAGIC + b"\x20" + bytes([len(data)]) + raw_block(data)


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
    require(result.returncode > 0 and error.encode() in result.stderr and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and no non-payload stdout; {describe(result)}")


def check_modes(prefix, cwd):
    def decode(src, dst, *options, wire=b""):
        return subprocess.run([*prefix, COMMAND, src, dst, *options], cwd=cwd, input=wire,
                              capture_output=True, timeout=TIMEOUT)

    first = b"\x00\xff\r\n\x80first"
    second = bytes(range(256)) * 3
    skipped = b"\x5d\x2a\x4d\x18" + len(MAGIC).to_bytes(4, "little") + MAGIC
    # No declared content size in the second frame, with a 1152-byte window.
    wire = small_frame(first) + skipped + MAGIC + b"\x00\x01" + raw_block(second)
    plain = first + second
    cap = str(len(plain))
    window = "--max-window-size=1152"
    (cwd / "input.zst").write_bytes(wire)
    out = cwd / "output"

    success("stdin to stdout", decode("-", "-", cap, window, wire=wire), plain)
    success("file to stdout", decode("input.zst", "-", cap, window), plain)
    out.write_bytes(SENTINEL)
    old_inode = out.stat().st_ino
    success("stdin to file", decode("-", out.name, cap, window, wire=wire))
    require(out.read_bytes() == plain, "stdin to file: wrong payload")
    if os.name == "posix":
        require(out.stat().st_ino != old_inode, "stdin to file: destination was overwritten in place")

    summary = f"zstd_native_compressed_bytes={len(wire)} decoded_bytes={len(plain)}".encode()
    success("legacy file to file", decode("input.zst", out.name, cap, window),
            summary + f" path={out.name}\n".encode())
    require(out.read_bytes() == plain, "legacy file to file: wrong payload")
    (cwd / "-").write_bytes(wire)
    success("legacy size command treats dash as a path",
            subprocess.run([*prefix, "size-zstd-native-file", "-"], cwd=cwd, input=b"",
                           capture_output=True, timeout=TIMEOUT), summary + b"\n")

    success("encoded empty frame", decode("-", "-", "0", "--max-window-size=0", wire=small_frame(b"")))
    failure("empty stdin", decode("-", "-"), "TruncatedFrame")
    failure("truncated magic", decode("-", "-", wire=MAGIC[:2]), "TruncatedFrame")

    def reject(label, bad_wire, error, prefix, *options):
        failure(label, decode("-", "-", *options, wire=bad_wire), error, prefix)
        out.write_bytes(SENTINEL)
        failure(f"{label} to file", decode("-", out.name, *options, wire=bad_wire), error)
        require(out.read_bytes() == SENTINEL, f"{label}: existing destination changed")

    reject("truncated second frame", wire[:-1], "TruncatedFrame", plain)
    reject("output cap", wire, "OutputLimitExceeded", plain[:-1], str(len(plain) - 1), window)
    reject("window cap", wire, "OutputLimitExceeded", first, "--max-window-size=1151")
    out.unlink()
    failure("truncation to a missing file", decode("-", out.name, wire=wire[:-1]), "TruncatedFrame")
    require(not out.exists(), "truncation published a new destination")

    # Unknown content size; the advertised window need not be allocated for a tiny raw block.
    small_block = raw_block(first)
    wide_header = MAGIC + b"\x00\x90"  # 256 MiB
    success("128 MiB default window", decode("-", "-", wire=MAGIC + b"\x00\x88" + small_block), first)
    failure("default window rejects header before payload", decode("-", "-", wire=wide_header),
            "OutputLimitExceeded")
    success("override default window", decode("-", "-", f"--max-window-size={1 << 28}",
                                              wire=wide_header + small_block), first)

    # Two maximum-sized RLE blocks expand far beyond the size of the pipe.
    count = 128 * 1024
    rle = (MAGIC + b"\x00\x38" + block_header(count, kind=1, last=False) + b"\xff"
           + block_header(count, kind=1) + b"\x00")
    success("large RLE drain", decode("-", "-", str(2 * count), wire=rle),
            b"\xff" * count + b"\x00" * count)

    if zstd := shutil.which("zstd"):
        data = (b"vort zstd stdio\x00\xff\r\n" + bytes(range(256))) * 128
        frame = subprocess.run([zstd, "-q", "-3", "--check", "-c"], input=data, capture_output=True,
                               check=True, timeout=TIMEOUT).stdout
        require(frame.startswith(MAGIC) and frame[4] & 4 and len(frame) < len(data),
                "external zstd did not produce a checksummed compressed fixture")
        success("external checksummed frame", decode("-", "-", wire=frame), data)
        bad = frame[:-1] + bytes([frame[-1] ^ 1])
        reject("bad checksum", bad, "ChecksumMismatch", data)
    else:
        print("SKIP: external zstd unavailable")


def pipe_select_supported():
    reader, writer = os.pipe()
    try:
        select.select([reader], [], [], 0)
        return True
    except (OSError, ValueError):
        return False
    finally:
        os.close(reader)
        os.close(writer)


def check_early_output(prefix, cwd):
    if not pipe_select_supported():
        print("SKIP: select does not support pipes on this platform")
        return

    first, last = b"first\x00\xff\r\n", b"last\xfe\x00"
    head = MAGIC + b"\x20" + bytes([len(first) + len(last)]) + raw_block(first, last=False)
    with subprocess.Popen([*prefix, COMMAND, "-", "-"], cwd=cwd, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0) as proc:
        try:
            fd = proc.stdout.fileno()
            # Split both the magic and the block header. No payload is available yet.
            for fragment in (head[:2], head[2:7]):
                proc.stdin.write(fragment)
                require(not select.select([fd], [], [], 0.02)[0], "output before any payload was sent")
            proc.stdin.write(head[7:])

            # No final block and no EOF yet. A buffered read could block even
            # after select reports readiness, so only do raw short reads here.
            deadline = time.monotonic() + TIMEOUT
            seen = bytearray()
            while len(seen) < len(first):
                remaining = max(0, deadline - time.monotonic())
                require(select.select([fd], [], [], remaining)[0], "first block not published before stdin EOF")
                chunk = os.read(fd, len(first) - len(seen))
                require(chunk, "stdout closed before publishing the first block")
                seen.extend(chunk)
            require(seen == first, f"wrong pre-EOF payload: {seen!r}")
            stdout, stderr = proc.communicate(raw_block(last), timeout=TIMEOUT)
            success("fragmented pipe tail", subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr),
                    last)
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
    with tempfile.TemporaryDirectory(prefix="vort-zstd-stdio-") as directory:
        cwd = Path(directory)
        check_modes(prefix, cwd)
        check_early_output(prefix, cwd)
    print(f"zstd_stdio_cli mode={mode} status=ok")


if __name__ == "__main__":
    main()
