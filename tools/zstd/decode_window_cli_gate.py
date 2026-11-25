#!/usr/bin/env python3
"""Verify Zstd CLI decode limits and legacy output on native or WASI."""

import argparse
from dataclasses import dataclass
from pathlib import Path
import subprocess
import tempfile
import zlib


COMMANDS = (
    "decode-zstd-native-hex",
    "decode-zstd-native-file",
    "decode-zstd-native-file-to",
    "size-zstd-native-hex",
    "size-zstd-native-file",
)
WINDOW = "--max-window-size"
LIMIT_DIAGNOSTIC = b"zstd_decode_limit_exceeded"
DEST = "decoded.out"
SENTINEL = b"\x00keep existing destination\xff\n"
MAX_COUNT = (1 << 64) - 1


@dataclass(frozen=True)
class Fixture:
    name: str
    wire: bytes
    plain: bytes = b""

    @property
    def path(self):
        return f"{self.name}.zst"


def raw_last_block(plain):
    return ((len(plain) << 3) | 1).to_bytes(3, "little") + plain


class Gate:
    def __init__(self, prefix, cwd):
        self.prefix = prefix
        self.cwd = cwd
        self.calls = 0

    def check(self, command, fixture, *options, failure=False, window=None):
        by_hex = command.endswith("-hex")
        file_to = command.endswith("-file-to")
        args = [command, fixture.wire.hex() if by_hex else fixture.path]
        if file_to:
            args.append(DEST)
        args.extend(options)

        dst = self.cwd / DEST
        summary = f"zstd_native_compressed_bytes={len(fixture.wire)} decoded_bytes={len(fixture.plain)}"
        expected = summary.encode()
        if file_to:
            expected += f" path={DEST}".encode()
        elif command.startswith("decode-"):
            expected += f" crc32={zlib.crc32(fixture.plain)} text=".encode() + fixture.plain
        expected += b"\n"

        # Check each file-to rejection with both a missing and a seeded output.
        for seed in (None, SENTINEL) if failure and file_to else (None,):
            dst.unlink(missing_ok=True)
            if seed is not None:
                dst.write_bytes(seed)
            result = subprocess.run(
                [*self.prefix, *args], cwd=self.cwd, capture_output=True, timeout=30,
            )
            self.calls += 1

            def require(condition, expected_detail):
                if not condition:
                    raise AssertionError(
                        f"{fixture.name}: {args!r}, destination seeded={seed is not None}: "
                        f"expected {expected_detail}; got exit={result.returncode}, "
                        f"stdout={result.stdout!r}, stderr={result.stderr!r}"
                    )

            if failure:
                require(result.returncode > 0 and result.stdout == b"", "failure with empty stdout")
                if file_to:
                    if seed is None:
                        require(not dst.exists(), "destination not to be created")
                    else:
                        require(dst.is_file() and dst.read_bytes() == seed, "existing destination to be unchanged")
            else:
                require(result.returncode == 0 and result.stdout == expected, f"success with stdout {expected!r}")
                if file_to:
                    require(dst.is_file() and dst.read_bytes() == fixture.plain, "the decoded destination bytes")

            if window is None:
                require(LIMIT_DIAGNOSTIC not in result.stderr, "no window-limit diagnostic")
            else:
                fields = [LIMIT_DIAGNOSTIC, f"max_window_size={window}".encode()]
                lines = [line.split() for line in result.stderr.splitlines() if line.startswith(LIMIT_DIAGNOSTIC)]
                require(len(lines) == 1 and lines[0][:2] == fields, f"one diagnostic with prefix {b' '.join(fields)!r}")


def check_contract(gate):
    magic = bytes.fromhex("28b52ffd")
    narrow_plain, wide_plain = b"one", b"large"
    narrow = Fixture("narrow", magic + b"\x20\x03" + raw_last_block(narrow_plain), narrow_plain)
    # No declared content size: a 1 KiB base plus a 1/8 increment.
    wide_window = 1152
    wide_header = Fixture("wide-header-only", magic + b"\x00\x01")
    wide = Fixture("wide", wide_header.wire + raw_last_block(wide_plain), wide_plain)
    # A frame header inside the skippable payload is not a data frame.
    skip_payload = wide_header.wire
    skip = Fixture("skippable", bytes.fromhex("5d2a4d18") + len(skip_payload).to_bytes(4, "little") + skip_payload)
    concat = Fixture("concatenated", narrow.wire + skip.wire + wide.wire, narrow_plain + wide_plain)
    empty = Fixture("empty", magic + b"\x20\x00" + raw_last_block(b""))
    # A window above 32-bit usize, but only five actual decoded bytes.
    huge_window = (1 << 32) + (1 << 29)
    huge = Fixture("huge", magic + b"\x00\xb1" + raw_last_block(wide_plain), wide_plain)
    # The second member's stored checksum is one bit off; file-to must not
    # publish even the first complete member when verification fails.
    bad_checksum = Fixture("bad-checksum", narrow.wire + bytes.fromhex("28b52ffd240529000068656c6c6fa36d9f89"))
    for fixture in (narrow, wide_header, wide, skip, concat, empty, huge, bad_checksum):
        (gate.cwd / fixture.path).write_bytes(fixture.wire)

    invalid_options = (
        (WINDOW,), (f"{WINDOW}=",), (WINDOW, ""),
        (f"{WINDOW}=-1",), (f"{WINDOW}=+1",), (f"{WINDOW}=1_000",),
        (WINDOW, "0x400"), (WINDOW, "1.0"), (f"{WINDOW}={MAX_COUNT + 1}",),
        (f"{WINDOW}=3", WINDOW, "3"), (WINDOW, "3", f"{WINDOW}=4"),
        ("--max-output=3",), ("3", "--unknown"), ("3", "4"),
    )
    for command in COMMANDS:
        # Existing stdout and positional max_output, without a window cap.
        gate.check(command, concat)
        gate.check(command, concat, str(len(concat.plain)))
        gate.check(command, concat, str(len(concat.plain) - 1), failure=True)

        gate.check(command, narrow, f"{WINDOW}={len(narrow.plain)}")
        gate.check(command, narrow, f"{WINDOW}=2", failure=True, window=2)
        gate.check(command, wide, WINDOW, str(wide_window))
        gate.check(command, concat, str(len(concat.plain)), WINDOW, str(wide_window))
        gate.check(command, concat, f"{WINDOW}={wide_window}", str(len(concat.plain)))
        gate.check(command, concat, WINDOW, str(wide_window - 1), str(len(concat.plain)), failure=True, window=wide_window - 1)
        # The diagnostic applies to OutputLimitExceeded from either limit.
        gate.check(command, concat, str(len(concat.plain) - 1), f"{WINDOW}={wide_window}", failure=True, window=wide_window)

        # A complete oversized header must be rejected before reading a block.
        gate.check(command, wide_header, f"{WINDOW}={wide_window - 1}", failure=True, window=wide_window - 1)
        gate.check(command, wide_header, f"{WINDOW}={wide_window}", failure=True)
        gate.check(command, skip, f"{WINDOW}=0", "0")
        gate.check(command, empty, WINDOW, "0", "0")
        gate.check(command, narrow, f"{WINDOW}=0", failure=True, window=0)

        gate.check(command, huge, WINDOW, str(huge_window))
        gate.check(command, huge, f"{WINDOW}={huge_window - 1}", failure=True, window=huge_window - 1)
        gate.check(command, narrow, f"{WINDOW}={MAX_COUNT}")
        for flags in invalid_options:
            gate.check(command, narrow, *flags, failure=True)
        if command.startswith("decode-"):
            gate.check(command, bad_checksum, f"{WINDOW}=5", failure=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path, help="native CLI executable or WASI probe")
    parser.add_argument("--wasi-runner", type=Path, help="Node WASI runner for a probe artifact")
    options = parser.parse_args()
    prefix = [str(options.cli.resolve())]
    mode = "native"
    if options.wasi_runner is not None:
        mode = "wasi"
        prefix[:0] = ["node", "--no-warnings", str(options.wasi_runner.resolve())]
    # File arguments are relative to this directory in both modes. WASI sees
    # it through the runner's preopen, not through host absolute paths.
    with tempfile.TemporaryDirectory(prefix="vort-zstd-decode-window-") as name:
        gate = Gate(prefix, Path(name))
        check_contract(gate)
    print(f"zstd_decode_window_cli mode={mode} cases={gate.calls} status=ok")


if __name__ == "__main__":
    main()
