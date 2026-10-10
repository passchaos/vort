#!/usr/bin/env python3
"""LZF ZV stream interoperability against the optional upstream CLI."""

from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run_cli(cli: Path, *args: str) -> str:
    return subprocess.run(
        [str(cli), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def reference_filter(tool: str, mode: str, payload: bytes) -> bytes:
    return subprocess.run(
        [tool, mode],
        input=payload,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def make_cases() -> dict[str, bytes]:
    rng = random.Random(0x1F2E3D4C)
    random_payload = bytes(rng.randrange(256) for _ in range(96 * 1024))
    prefix = bytes(rng.randrange(256) for _ in range(7000))
    return {
        "empty": b"",
        "tiny": b"LZF",
        "text": b"LZF interoperability payload.\n" * 4096,
        "random": random_payload,
        "mixed": random_payload[:32_000] + b"A" * 40_000 + random_payload[32_000:],
        "long-distance": prefix + b"gap" + prefix,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--reference", type=Path)
    args = parser.parse_args()
    reference = str(args.reference) if args.reference else shutil.which("lzf")
    cases = make_cases()
    external_directions = 0
    encoded_bytes = 0

    with tempfile.TemporaryDirectory(prefix="vort-lzf-diff-") as temp_text:
        temp = Path(temp_text)
        for name, payload in cases.items():
            source = temp / f"{name}.bin"
            first = temp / f"{name}-first.lzf"
            second = temp / f"{name}-second.lzf"
            decoded = temp / f"{name}.out"
            source.write_bytes(payload)
            first_report = run_cli(
                args.cli,
                "encode-lzf-file",
                str(source),
                str(first),
                "32768",
                "no-eof",
            )
            run_cli(
                args.cli,
                "encode-lzf-file",
                str(source),
                str(second),
                "32768",
                "no-eof",
            )
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort LZF output is not deterministic for {name}")
            run_cli(args.cli, "decode-lzf-file", str(first), str(decoded))
            if decoded.read_bytes() != payload:
                raise AssertionError(f"Vort LZF self round-trip mismatch for {name}")
            size_report = run_cli(args.cli, "size-lzf-file", str(first))
            if f"decoded_bytes={len(payload)}" not in size_report:
                raise AssertionError(f"Vort LZF size report mismatch for {name}")
            inspect_report = run_cli(args.cli, "inspect-lzf-file", str(first))
            if "lzf_blocks=" not in inspect_report or "blocks=" not in first_report:
                raise AssertionError(f"Vort LZF metadata report missing for {name}")
            encoded = first.read_bytes()
            encoded_bytes += len(encoded)

            if reference is not None:
                if reference_filter(reference, "-d", encoded) != payload:
                    raise AssertionError(f"upstream lzf could not decode Vort output for {name}")
                external_directions += 1
                reference_encoded = reference_filter(reference, "-c", payload)
                external_path = temp / f"{name}-external.lzf"
                external_output = temp / f"{name}-external.out"
                external_path.write_bytes(reference_encoded)
                run_cli(
                    args.cli,
                    "decode-lzf-file",
                    str(external_path),
                    str(external_output),
                )
                if external_output.read_bytes() != payload:
                    raise AssertionError(f"Vort could not decode upstream lzf output for {name}")
                external_directions += 1

        marker_source = temp / "marker.bin"
        marker_stream = temp / "marker.lzf"
        marker_output = temp / "marker.out"
        marker_payload = b"optional LZF EOF marker\n" * 64
        marker_source.write_bytes(marker_payload)
        run_cli(
            args.cli,
            "encode-lzf-file",
            str(marker_source),
            str(marker_stream),
            "65535",
            "eof",
        )
        if not marker_stream.read_bytes().endswith(b"\x00"):
            raise AssertionError("Vort LZF writer omitted the requested EOF marker")
        run_cli(args.cli, "decode-lzf-file", str(marker_stream), str(marker_output))
        if marker_output.read_bytes() != marker_payload:
            raise AssertionError("Vort LZF EOF-marker round trip mismatch")

    print(
        "lzf_diff=ok "
        f"cases={len(cases)} self_cases={len(cases)} "
        f"reference={reference is not None} external_directions={external_directions} "
        f"encoded_bytes={encoded_bytes} eof_marker=True"
    )


if __name__ == "__main__":
    main()
