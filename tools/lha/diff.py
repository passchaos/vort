#!/usr/bin/env python3
"""LHA/LZH interoperability for stored and new-style LH methods."""

from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(program: Path | str, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def lhasa_extract(tool: str, archive: Path, name: str) -> bytes:
    return subprocess.run(
        [tool, "pq", str(archive), name],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def make_payload() -> bytes:
    rng = random.Random(0x1A5A7001)
    prefix = bytes(rng.randrange(256) for _ in range(40_000))
    return prefix + b"LHA interoperability\n" * 512 + prefix


def fixture_cases(root: Path) -> tuple[tuple[Path, str, int], ...]:
    return (
        (root / "explzh_723" / "h0_lh5.lzh", "lh5", 0),
        (root / "explzh_723" / "h1_lh6.lzh", "lh6", 1),
        (root / "explzh_723" / "h2_lh7.lzh", "lh7", 2),
        (root / "explzh_723" / "h1_subdir.lzh", "stored", 1),
        (root / "explzh_723" / "h2_subdir.lzh", "stored", 2),
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--fixtures", type=Path)
    args = parser.parse_args()
    reference = str(args.reference) if args.reference else shutil.which("lha")
    payload = make_payload()
    writer_external = 0
    reader_fixtures = 0

    with tempfile.TemporaryDirectory(prefix="vort-lha-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.bin"
        source.write_bytes(payload)
        for method in ("stored", "lh5", "lh6", "lh7"):
            first = temp / f"vort-{method}-first.lzh"
            second = temp / f"vort-{method}-second.lzh"
            output = temp / f"vort-{method}.out"
            run(args.cli, "create-lha-file", str(first), "payload.bin", str(source), method)
            run(args.cli, "create-lha-file", str(second), "payload.bin", str(source), method)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort LHA {method} output is not deterministic")
            listing = run(args.cli, "list-lha-file", str(first)).stdout
            if f"method={method if method != 'stored' else 'stored'}" not in listing:
                raise AssertionError(f"Vort LHA listing mislabeled {method}: {listing}")
            run(
                args.cli,
                "extract-lha-file",
                str(first),
                "payload.bin",
                str(output),
                str(len(payload)),
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort LHA {method} self-extraction mismatch")
            if reference is not None:
                if lhasa_extract(reference, first, "payload.bin") != payload:
                    raise AssertionError(f"lhasa could not decode Vort LHA {method} output")
                writer_external += 1

        if args.fixtures is not None:
            for fixture, method, level in fixture_cases(args.fixtures):
                if not fixture.is_file():
                    raise AssertionError(f"missing lhasa fixture: {fixture}")
                listing = run(args.cli, "list-lha-file", str(fixture)).stdout
                if f"method={method}" not in listing or f"level={level}" not in listing:
                    raise AssertionError(f"Vort misparsed {fixture.name}: {listing}")
                name = (
                    "subdir/subdir2/hello.txt"
                    if fixture.name.endswith("_subdir.lzh")
                    else "gpl-2"
                )
                output = temp / f"fixture-{reader_fixtures}.out"
                run(
                    args.cli,
                    "extract-lha-file",
                    str(fixture),
                    name,
                    str(output),
                    str(1024 * 1024),
                )
                if reference is not None:
                    expected = lhasa_extract(reference, fixture, name)
                    if output.read_bytes() != expected:
                        raise AssertionError(f"Vort fixture extraction mismatch for {fixture}")
                reader_fixtures += 1

    print(
        "lha_diff=ok methods=4 self_writer_cases=4 "
        f"reference={reference is not None} writer_external={writer_external} "
        f"reader_fixtures={reader_fixtures} levels=3"
    )


if __name__ == "__main__":
    main()
