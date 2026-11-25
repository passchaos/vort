#!/usr/bin/env python3
"""Black-box checks for streaming Brotli CLI stdin/stdout encoding."""

import argparse
import os
from pathlib import Path
import random
import select
import shutil
import subprocess
import tempfile
import time


COMMAND = "encode-br-stream-file"
DECODE_COMMAND = "decode-br-file-to"
TIMEOUT = 15
SENTINEL = b"\x00keep the existing output\xff\n"
PROFILES = ("--profile", "--memory-profile")
PROFILE_MARKERS = (b"br_hq_profile ", b"br_format_profile ", b"br_parse_profile ",
                   b"br_length_profile ", b"br_memory_profile ")
NODE_DECODER = """
const zlib = require('node:zlib');
const params = process.argv[1] === 'large' ? {[zlib.constants.BROTLI_DECODER_PARAM_LARGE_WINDOW]: 1} : {};
process.stdout.write(zlib.brotliDecompressSync(require('node:fs').readFileSync(0), {params}));
"""


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def describe(result):
    return (f"exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def run(args, cwd, data=b""):
    return subprocess.run(args, cwd=cwd, input=data, capture_output=True, timeout=TIMEOUT)


def success(label, result, *, stdout=None, profiles=False):
    require(result.returncode == 0, f"{label}: {describe(result)}")
    if stdout is not None:
        require(result.stdout == stdout, f"{label}: wrong stdout; {describe(result)}")
    if profiles:
        lines = result.stderr.splitlines()
        require(len(lines) == len(PROFILE_MARKERS)
                and all(line.startswith(marker) for line, marker in zip(lines, PROFILE_MARKERS))
                and b"live_requested_bytes=0 " in lines[-1],
                f"{label}: expected only HQ and memory profiles on stderr; {describe(result)}")
    else:
        require(result.stderr == b"", f"{label}: unexpected stderr; {describe(result)}")
    return result.stdout


def failure(label, result, error, allowed_prefix=b""):
    require(result.returncode > 0 and f"error: {error}".encode() in result.stderr.splitlines()
            and allowed_prefix.startswith(result.stdout),
            f"{label}: expected {error} on stderr and no non-payload stdout; {describe(result)}")


def decoder_for(prefix):
    commands = [[*prefix, DECODE_COMMAND, "-", "-"],
                [*prefix, DECODE_COMMAND, "-", "-", "--large-window"]]
    references = ["vort", "vort"]
    if node := shutil.which("node"):
        probe = subprocess.run([node, "-p", """
const z = require('node:zlib');
[typeof z.brotliDecompressSync, typeof z.constants.BROTLI_DECODER_PARAM_LARGE_WINDOW].join(' ');
"""], capture_output=True, timeout=TIMEOUT)
        if probe.returncode == 0 and probe.stdout.startswith(b"function "):
            commands[0] = [node, "-e", NODE_DECODER, "standard"]
            references[0] = "node"
            if probe.stdout.strip() == b"function number":
                commands[1] = [node, "-e", NODE_DECODER, "large"]
                references[1] = "node"
    return commands, references


def verify_stream(label, decoders, cwd, wire, plain, *, large=False):
    require(bool(wire), f"{label}: empty Brotli wire")
    success(f"{label} round trip", run(decoders[large], cwd, wire), stdout=plain)


def summary(wire, plain, target):
    return f"br_compressed_bytes={len(wire)} decoded_bytes={len(plain)} path={target}\n".encode()


def check_modes(prefix, decoders, cwd):
    def encode(src, dst, *options, data=b""):
        return run([*prefix, COMMAND, src, dst, *options], cwd, data)

    plain = bytes(range(256)) + b"\x00\xff\r\n\x80vort Brotli stdio\x00"
    source = cwd / "input.raw"
    source.write_bytes(plain)
    out = cwd / "output.br"

    wire = success("binary stdin to stdout", encode("-", "-", data=plain))
    verify_stream("binary stdin", decoders, cwd, wire, plain)
    success("file to stdout", encode(source.name, "-"), stdout=wire)
    empty = success("empty stdin", encode("-", "-", "--max-input-len=0"))
    verify_stream("empty stdin", decoders, cwd, empty, b"")

    out.write_bytes(SENTINEL)
    old_inode = out.stat().st_ino
    success("stdin to file", encode("-", out.name, data=plain), stdout=b"")
    require(out.read_bytes() == wire, "stdin to file: different encoded payload than stdout")
    if os.name == "posix":
        require(out.stat().st_ino != old_inode, "stdin to file: destination was overwritten in place")
    success("legacy file to file", encode(source.name, out.name), stdout=summary(wire, plain, out.name))
    require(out.read_bytes() == wire, "legacy file to file: different encoded payload than stdout")

    for input_cap, output_cap in ((len(plain), len(wire)), ((1 << 32) + 1,) * 2):
        success("stdin input/output caps", encode("-", "-", f"--max-input-len={input_cap}",
                f"--max-output-len={output_cap}", data=plain), stdout=wire)
    for flag, size in (("--max-input-len", len(plain)), ("--max-output-len", len(wire))):
        low = f"{flag}={size - 1}"
        failure(f"insufficient {flag} on stdout", encode("-", "-", low, data=plain),
                "OutputLimitExceeded", wire[:-1])
        out.write_bytes(SENTINEL)
        old_inode = out.stat().st_ino
        failure(f"insufficient {flag} with a named output", encode("-", out.name, low, data=plain),
                "OutputLimitExceeded")
        require(out.read_bytes() == SENTINEL and out.stat().st_ino == old_inode,
                f"insufficient {flag}: existing destination changed")

    oversized = cwd / "oversized.raw"
    oversized.write_bytes(plain * 160)
    # Without metadata preflight, the first 32 KiB read would pass the cap
    # and produce multiple blocks on stdout before the later read is rejected.
    block_options = ("--quality=0", "--block-len=8192", "--max-input-len=32768")
    failure("named input size preflight", encode(oversized.name, "-", *block_options), "OutputLimitExceeded")
    out.unlink()
    failure("input cap with a missing output", encode("-", out.name, *block_options, data=oversized.read_bytes()),
            "OutputLimitExceeded")
    require(not out.exists(), "input cap: published a new destination after a partial encode")

    wide = ("--window-bits=25", "--quality=10", "--hq-depth=2", "--hq-beam-width=1", "--hq-iterations=1",
            "--hq-parse-mode=whole_block", "--hq-copy-lengths=complete")
    hq_plain = b"abc abcd\xff\x00abcd " * 3
    failure("wide window needs explicit opt-in", encode("-", "-", *wide, data=hq_plain), "InvalidBlockPlan")
    wide += ("--large-window",)
    large_wire = success("explicit Large Window", encode("-", "-", *wide, data=hq_plain))
    require(int.from_bytes(large_wire[:2], "little") & 0x3FFF == (0x11 | (25 << 8)),
            "missing explicit 25-bit Large Window header")
    verify_stream("explicit Large Window", decoders, cwd, large_wire, hq_plain, large=True)
    failure("strict decoder rejects the Large Window stream",
            run([*prefix, DECODE_COMMAND, "-", "-"], cwd, large_wire), "CorruptFrame")

    source.write_bytes(hq_plain)
    success("profiles on stdin to stdout", encode("-", "-", *wide, *PROFILES, data=hq_plain),
            stdout=large_wire, profiles=True)
    success("profiles on file to stdout", encode(source.name, "-", *wide, *PROFILES),
            stdout=large_wire, profiles=True)
    success("profiles on stdin to file", encode("-", out.name, *wide, *PROFILES, data=hq_plain),
            stdout=b"", profiles=True)
    require(out.read_bytes() == large_wire, "profiles on stdin to file: changed encoded payload")


def check_legacy_one_shot(prefix, decoders, cwd):
    dash = cwd / "-"
    plain = b"one-shot reads a literal filename -\x00\xff"
    dash.write_bytes(plain)
    args = [*prefix, "encode-br-file", "-", "-"]
    failure("one-shot still rejects stream caps", run([*args, "--max-input-len=0"], cwd),
            "UnsupportedBrotliStreamLimit")
    require(dash.read_bytes() == plain, "one-shot stream cap changed the literal file")
    result = run(args, cwd, b"not the input file")
    wire = dash.read_bytes()
    success("one-shot dash operands remain literal paths", result, stdout=summary(wire, plain, dash.name))
    verify_stream("one-shot literal dash", decoders, cwd, wire, plain)


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


def send_prefix(proc, head):
    reader, writer = proc.stdout.fileno(), proc.stdin.fileno()
    limit = min(select.PIPE_BUF, 4093)  # Stay under the pipe's atomic write size after readiness.
    deadline = time.monotonic() + TIMEOUT
    seen = bytearray()
    sent = 0
    # The standard window header is at most a byte. No metadata was requested,
    # so a 32-byte prefix demonstrates actual block output before finish.
    while sent < len(head) or len(seen) < 32:
        delay = deadline - time.monotonic()
        require(delay > 0, "Brotli block bytes not published before stdin EOF")
        reads, writes, _ = select.select([reader], [writer] if sent < len(head) else [], [], delay)
        if reads:
            chunk = os.read(reader, 65536)
            require(chunk, "stdout closed before publishing a Brotli block")
            seen.extend(chunk)
        if writes:
            sent += os.write(writer, head[sent:sent + limit])
    return bytes(seen)


def check_live_pipe(prefix, decoders, cwd):
    # Larger than a configured block, smaller than the pump's 32 KiB read window.
    # A fill-before-return reader would deadlock until the withheld tail or EOF.
    rng = random.Random(105)
    head = bytes(rng.getrandbits(8) for _ in range(2 * 8192 + 121))
    tail = b"\x00\xff\r\n\x80Brotli tail\x00"
    args = [*prefix, COMMAND, "-", "-", "--quality=0", "--block-len=8192"]
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
    label = "fragmented input across Brotli blocks"
    verify_stream(label, decoders, cwd, success(label, result), head + tail)


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
    decoders, references = decoder_for(prefix)
    # The WASI runner preopens the working directory as '.'.
    with tempfile.TemporaryDirectory(prefix="vort-br-encode-stdio-") as directory:
        cwd = Path(directory)
        check_modes(prefix, decoders, cwd)
        check_live_pipe(prefix, decoders, cwd)
        if mode == "native":
            check_legacy_one_shot(prefix, decoders, cwd)
    print(f"br_encode_stdio_cli mode={mode} decoder={references[0]} large_decoder={references[1]} status=ok")


if __name__ == "__main__":
    main()
