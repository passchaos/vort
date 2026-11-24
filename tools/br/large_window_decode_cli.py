#!/usr/bin/env python3
"""Exercise the explicit Brotli Large Window decode opt-in at the CLI boundary."""

import subprocess
import sys
import tempfile
from pathlib import Path


# libbrotli 1.2.0, BrotliEncoderCompress(6, 25, BROTLI_MODE_GENERIC, ...).
# Verified with a reference streaming decoder enabling LARGE_WINDOW.
PLAIN = b"wide streaming checkpoint\n" * 128
WIRE = bytes.fromhex(
    "1159fc33001098c87942b9b5cb61030ed88328e00975d8183bcb23f28b00a9b0b"
    "d8338c7e00f4a000005"
)


def run(cli, args, error=None):
    proc = subprocess.run([cli, *args], capture_output=True, check=False)
    if error is None:
        if proc.returncode != 0:
            raise AssertionError(f"{args[0]} failed: {proc.stderr!r}")
    elif proc.returncode == 0 or f"error: {error}".encode() not in proc.stderr:
        raise AssertionError(f"{args[0]} expected {error}, got {proc.returncode}: {proc.stderr!r}")
    return proc.stdout


def main():
    cli = sys.argv[1]
    limit = str(len(PLAIN))
    low_limit = str(len(PLAIN) - 1)
    size_report = f"decoded_bytes={len(PLAIN)}".encode()
    with tempfile.TemporaryDirectory(prefix="vort-br-large-decode-") as directory:
        source = Path(directory) / "upstream.br"
        destination = Path(directory) / "out"
        source.write_bytes(WIRE)
        destination.write_bytes(b"old output")

        decode_file = ["decode-br-file-to", str(source), str(destination)]
        size_file = ["size-br-file", str(source)]
        decode_hex = ["decode-br-hex", WIRE.hex()]
        for command in (decode_file, size_file, decode_hex):
            run(cli, command, "CorruptFrame")
        run(cli, decode_file + ["--large-window", low_limit], "OutputLimitExceeded")
        run(cli, decode_file + ["--large-window", "--large-window"], "DuplicateBrotliOption")
        run(cli, decode_file + ["--unknown"], "UnknownBrotliOption")
        assert destination.read_bytes() == b"old output"

        assert size_report in run(cli, decode_file + [limit, "--large-window"])
        assert destination.read_bytes() == PLAIN
        assert size_report in run(cli, size_file + ["--large-window", limit])
        run(cli, size_file + [low_limit, "--large-window"], "OutputLimitExceeded")
        text = run(cli, decode_hex + ["--large-window"])
        assert size_report in text and text.partition(b"text=")[2] == PLAIN + b"\n"

    print(f"upstream_large_window_cli_ok compressed={len(WIRE)} decoded={len(PLAIN)} modes=3")


if __name__ == "__main__":
    main()
