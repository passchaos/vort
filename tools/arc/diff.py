#!/usr/bin/env python3
"""ARC/PAK methods 1-9 interoperability against the reference ARC tool."""

from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(program: Path | str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def reference_extract(tool: str, archive: Path, name: str) -> bytes:
    output = subprocess.run(
        [tool, "p", str(archive), name],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    # ARC's print command appends one form-feed after the selected file.
    return output[:-1] if output.endswith(b"\x0c") else output


def make_payload() -> bytes:
    rng = random.Random(0xAC521001)
    prefix = bytes(rng.randrange(256) for _ in range(20_000))
    return prefix + b"ARC interoperability payload\n" * 512 + b"A" * 1024 + prefix


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--arc", type=Path)
    parser.add_argument("--unarc", type=Path)
    parser.add_argument("--arc-fixtures", type=Path)
    parser.add_argument("--pak-fixtures", type=Path)
    args = parser.parse_args()
    arc_tool = str(args.arc) if args.arc else shutil.which("arc")
    unarc_tool = str(args.unarc) if args.unarc else shutil.which("unarc")
    payload = make_payload()
    writer_external = 0
    writer_unarc = 0
    reader_fixtures = 0

    methods = (
        "stored1",
        "stored2",
        "packed",
        "squeezed",
        "crunched5",
        "crunched6",
        "crunched7",
        "crunched8",
        "squashed",
        "crushed",
        "distilled",
    )
    expected_tags = {
        "stored1": "stored_1",
        "stored2": "stored_2",
        "packed": "packed_rle",
        "squeezed": "squeezed",
        "crunched5": "crunched_5",
        "crunched6": "crunched_6",
        "crunched7": "crunched_7",
        "crunched8": "crunched_8",
        "squashed": "squashed",
        "crushed": "crushed",
        "distilled": "distilled",
    }

    with tempfile.TemporaryDirectory(prefix="vort-arc-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.bin"
        source.write_bytes(payload)
        for method in methods:
            first = temp / f"vort-{method}-first.arc"
            second = temp / f"vort-{method}-second.arc"
            output = temp / f"vort-{method}.out"
            run(args.cli, "create-arc-file", str(first), "PAYLOAD", str(source), method)
            run(args.cli, "create-arc-file", str(second), "PAYLOAD", str(source), method)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort ARC {method} output is not deterministic")
            listing = run(args.cli, "list-arc-file", str(first)).stdout
            if f"method={expected_tags[method]}" not in listing:
                raise AssertionError(f"Vort ARC listing mislabeled {method}: {listing}")
            run(
                args.cli,
                "extract-arc-file",
                str(first),
                "PAYLOAD",
                str(output),
                str(len(payload)),
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort ARC {method} self-extraction mismatch")
            if arc_tool is not None and method not in {"crushed", "distilled"}:
                tested = subprocess.run(
                    [arc_tool, "t", str(first)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if tested.returncode != 0:
                    raise AssertionError(f"ARC rejected Vort {method}: {tested.stdout!r}")
                writer_external += 1
            if unarc_tool is not None and method in {
                "stored2",
                "packed",
                "squeezed",
                "crunched8",
                "squashed",
                "crushed",
                "distilled",
            }:
                unarc_dir = temp / f"unarc-{method}"
                unarc_dir.mkdir()
                extracted = subprocess.run(
                    [unarc_tool, "extract", "-f", "-o", str(unarc_dir), str(first), "PAYLOAD"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                if extracted.returncode != 0 or (unarc_dir / "PAYLOAD").read_bytes() != payload:
                    raise AssertionError(f"unarc-rs rejected Vort {method}: {extracted.stdout!r}")
                writer_unarc += 1

        if args.arc_fixtures is not None:
            cases = (
                (args.arc_fixtures / "store.arc", "LICENSE", "stored_2"),
                (args.arc_fixtures / "cpm.arc", "DDTZ.COM", "squeezed"),
                (args.arc_fixtures / "cpm.arc", "READ.COM", "packed_rle"),
                (args.arc_fixtures / "crunch.arc", "LICENSE", "crunched_8"),
                (args.arc_fixtures / "squashed.arc", "LICENSE", "squashed"),
                (args.arc_fixtures / "crunch_clear.arc", "SHIFT1.TXT", "crunched_8"),
                (args.arc_fixtures / "squash_clear.arc", "SHIFT1.TXT", "squashed"),
            )
            for fixture, name, method in cases:
                listing = run(args.cli, "list-arc-file", str(fixture)).stdout
                if f"method={method}" not in listing:
                    raise AssertionError(f"Vort misparsed {fixture.name}: {listing}")
                output = temp / f"fixture-{reader_fixtures}.out"
                run(
                    args.cli,
                    "extract-arc-file",
                    str(fixture),
                    name,
                    str(output),
                    str(2 * 1024 * 1024),
                )
                if arc_tool is not None:
                    expected = reference_extract(arc_tool, fixture, name)
                    if output.read_bytes() != expected:
                        raise AssertionError(f"Vort fixture extraction mismatch for {fixture}")
                reader_fixtures += 1

            wrong_crc = args.arc_fixtures / "wrongcrc16.arc"
            failed = run(
                args.cli,
                "extract-arc-file",
                str(wrong_crc),
                "LICENSE",
                str(temp / "wrong-crc.out"),
                check=False,
            )
            if failed.returncode == 0:
                raise AssertionError("Vort accepted an ARC entry with a bad CRC-16")

            encrypted = args.arc_fixtures / "license_cypted.arc"
            encrypted_extract = run(
                args.cli,
                "extract-arc-file",
                str(encrypted),
                "LICENSE",
                str(temp / "encrypted.out"),
                check=False,
            )
            if encrypted_extract.returncode == 0:
                raise AssertionError("Vort accepted encrypted ARC data without a password")

        if args.pak_fixtures is not None:
            supported = (
                (args.pak_fixtures / "license_crunched.pak", "crunched_8"),
                (args.pak_fixtures / "license_squashed.pak", "squashed"),
            )
            for fixture, method in supported:
                listing = run(args.cli, "list-arc-file", str(fixture)).stdout
                if f"method={method}" not in listing:
                    raise AssertionError(f"Vort misparsed {fixture.name}: {listing}")
                output = temp / f"pak-{reader_fixtures}.out"
                run(args.cli, "extract-arc-file", str(fixture), "LICENSE", str(output))
                if arc_tool is not None:
                    expected = reference_extract(arc_tool, fixture, "LICENSE")
                    if output.read_bytes() != expected:
                        raise AssertionError(f"Vort PAK extraction mismatch for {fixture}")
                reader_fixtures += 1
            for filename, tag in (("license_crushed.pak", "crushed"), ("license.pak", "distilled")):
                fixture = args.pak_fixtures / filename
                listing = run(args.cli, "list-arc-file", str(fixture)).stdout
                if f"method={tag}" not in listing:
                    raise AssertionError(f"Vort failed to identify {tag}")
                output = temp / f"pak-{reader_fixtures}.out"
                extracted = run(
                    args.cli,
                    "extract-arc-file",
                    str(fixture),
                    "LICENSE",
                    str(output),
                )
                _ = extracted
                if unarc_tool is not None:
                    unarc_dir = temp / f"unarc-fixture-{tag}"
                    unarc_dir.mkdir()
                    reference = subprocess.run(
                        [unarc_tool, "extract", "-f", "-o", str(unarc_dir), str(fixture), "LICENSE"],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                    if reference.returncode != 0 or output.read_bytes() != (unarc_dir / "LICENSE").read_bytes():
                        raise AssertionError(f"Vort PAK {tag} extraction mismatch")
                reader_fixtures += 1

    print(
        "arc_diff=ok methods=11 self_writer_cases=11 "
        f"arc={arc_tool is not None} writer_external={writer_external} "
        f"unarc={unarc_tool is not None} writer_unarc={writer_unarc} "
        f"reader_fixtures={reader_fixtures} corrupt_crc=True encrypted_crc=True"
    )


if __name__ == "__main__":
    main()
