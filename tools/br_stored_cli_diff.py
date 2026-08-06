#!/usr/bin/env python3
"""Black-box smoke for dependency-free Brotli stored-stream CLI workflows."""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path


PAYLOADS = [
    b"",
    b"hello",
    b"hello vort brotli stored stream\n" * 8,
    bytes((i * 37 + 11) & 0xFF for i in range(4096)),
]
WINDOW_BITS = [10, 16, 24]


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)


def node_decode(br_path: Path) -> bytes:
    script = (
        "const fs=require('fs');"
        "const z=require('zlib');"
        "process.stdout.write(z.brotliDecompressSync(fs.readFileSync(process.argv[1])));"
    )
    result = subprocess.run(
        ["node", "-e", script, str(br_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("cli", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    cli = args.cli.resolve()
    with tempfile.TemporaryDirectory(prefix="vort-br-stored-") as td:
        tmp = Path(td)
        cases = 0
        for index, payload in enumerate(PAYLOADS):
            src = tmp / f"case-{index}.bin"
            src.write_bytes(payload)
            for window_bits in WINDOW_BITS:
                br = tmp / f"case-{index}-w{window_bits}.br"
                out = tmp / f"case-{index}-w{window_bits}.out"
                run([str(cli), "encode-br-stored-file", str(src), str(br), str(window_bits)], root)
                run([str(cli), "size-br-file", str(br), str(len(payload))], root)
                run([str(cli), "decode-br-file-to", str(br), str(out), str(len(payload))], root)
                decoded = out.read_bytes()
                if decoded != payload:
                    raise AssertionError(f"vort decode mismatch case={index} window_bits={window_bits}")
                node_decoded = node_decode(br)
                if node_decoded != payload:
                    raise AssertionError(f"node decode mismatch case={index} window_bits={window_bits}")

                too_small = subprocess.run(
                    [str(cli), "decode-br-file-to", str(br), str(out), str(max(0, len(payload) - 1))],
                    cwd=root,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if payload and too_small.returncode == 0:
                    raise AssertionError(f"expected output limit failure case={index} window_bits={window_bits}")
                cases += 1

    print(f"br_stored_cli_diff=ok cases={cases}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
