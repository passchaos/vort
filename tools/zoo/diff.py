#!/usr/bin/env python3
"""ZOO stored/LZD/LH5 interoperability against Zoo 2.10 and unarc-rs."""

from __future__ import annotations

import argparse
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(
    program: Path | str,
    *args: str,
    check: bool = True,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def make_payload() -> bytes:
    rng = random.Random(0x20101986)
    prefix = bytes(rng.randrange(256) for _ in range(8_000))
    return prefix + b"ZOO interoperability payload\n" * 1024 + b"A" * 4096 + prefix


def original_extract(tool: Path, archive: Path, name: str, output_dir: Path) -> bytes:
    output_dir.mkdir()
    run(tool, "-extract", str(archive), name, cwd=output_dir)
    return (output_dir / name).read_bytes()


def unarc_extract(tool: Path, archive: Path, name: str, output_dir: Path) -> bytes:
    output_dir.mkdir()
    run(tool, "extract", "-f", "-o", str(output_dir), str(archive), name)
    return (output_dir / name).read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--zoo", type=Path)
    parser.add_argument("--unarc", type=Path)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--license", type=Path)
    args = parser.parse_args()
    zoo_tool = args.zoo or (Path(found) if (found := shutil.which("zoo")) else None)
    unarc_tool = args.unarc or (Path(found) if (found := shutil.which("unarc")) else None)
    payload = make_payload()
    methods = ("stored", "lzd", "lh5")
    writer_external = 0
    reference_writer = 0
    writer_unarc = 0
    reader_fixtures = 0
    corrupt_crc = False
    directory_crc = False

    with tempfile.TemporaryDirectory(prefix="vort-zoo-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)

        for method in methods:
            first = temp / f"vort-{method}-first.zoo"
            second = temp / f"vort-{method}-second.zoo"
            output = temp / f"vort-{method}.out"
            run(args.cli, "create-zoo-file", str(first), "PAYLOAD.BIN", str(source), method)
            run(args.cli, "create-zoo-file", str(second), "PAYLOAD.BIN", str(source), method)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort ZOO {method} output is not deterministic")
            listing = run(args.cli, "list-zoo-file", str(first)).stdout
            if f"method={method}" not in listing:
                raise AssertionError(f"Vort ZOO listing mislabeled {method}: {listing}")
            run(
                args.cli,
                "extract-zoo-file",
                str(first),
                "PAYLOAD.BIN",
                str(output),
                str(len(payload)),
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort ZOO {method} self-extraction mismatch")

            if zoo_tool is not None:
                run(zoo_tool, "-test", str(first))
                extracted = original_extract(
                    zoo_tool,
                    first,
                    "PAYLOAD.BIN",
                    temp / f"original-vort-{method}",
                )
                if extracted != payload:
                    raise AssertionError(f"Zoo rejected Vort {method} payload")
                writer_external += 1

            # unarc-rs currently hard-codes a 12-bit/4096-entry variable LZW
            # table, while Zoo 2.10 defines and emits 13-bit/8192-entry LZD.
            if unarc_tool is not None and method != "lzd":
                if unarc_extract(
                    unarc_tool,
                    first,
                    "PAYLOAD.BIN",
                    temp / f"unarc-vort-{method}",
                ) != payload:
                    raise AssertionError(f"unarc-rs rejected Vort {method}")
                writer_unarc += 1

        long_name = "docs/sub/really-long-zoo-name.txt"
        long_archive = temp / "vort-long-name.zoo"
        run(args.cli, "create-zoo-file", str(long_archive), long_name, str(source), "stored")
        long_listing = run(args.cli, "list-zoo-file", str(long_archive)).stdout
        if f"name={long_name}" not in long_listing:
            raise AssertionError(f"Vort lost its own ZOO long path: {long_listing}")
        if zoo_tool is not None:
            if original_extract(
                zoo_tool,
                long_archive,
                long_name,
                temp / "original-vort-long-name",
            ) != payload:
                raise AssertionError("Zoo rejected Vort long-name metadata")
            writer_external += 1

        if zoo_tool is not None:
            reference_dir = temp / "reference"
            reference_dir.mkdir()
            reference_source = reference_dir / "PAYLOAD.BIN"
            reference_source.write_bytes(payload)
            commands = {"stored": "af", "lzd": "a", "lh5": "ah"}
            for method, command in commands.items():
                archive = reference_dir / f"reference-{method}.zoo"
                run(zoo_tool, command, archive.name, reference_source.name, cwd=reference_dir)
                listing = run(args.cli, "list-zoo-file", str(archive)).stdout
                if f"method={method}" not in listing:
                    raise AssertionError(f"Vort misparsed reference {method}: {listing}")
                output = temp / f"reference-{method}.out"
                run(
                    args.cli,
                    "extract-zoo-file",
                    str(archive),
                    "PAYLOAD.BIN",
                    str(output),
                    str(len(payload)),
                )
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed reference Zoo {method}")
                reference_writer += 1

            long_source = reference_dir / long_name
            long_source.parent.mkdir(parents=True)
            long_source.write_bytes(payload)
            long_reference = reference_dir / "reference-long-name.zoo"
            run(zoo_tool, "af", long_reference.name, long_name, cwd=reference_dir)
            long_listing = run(args.cli, "list-zoo-file", str(long_reference)).stdout
            if f"name={long_name}" not in long_listing:
                raise AssertionError(f"Vort lost reference Zoo long path: {long_listing}")
            long_output = temp / "reference-long-name.out"
            run(
                args.cli,
                "extract-zoo-file",
                str(long_reference),
                long_name,
                str(long_output),
                str(len(payload)),
            )
            if long_output.read_bytes() != payload:
                raise AssertionError("Vort failed reference Zoo long-name metadata")
            reference_writer += 1

        if args.fixtures is not None:
            expected = args.license.read_bytes() if args.license is not None else None
            cases = (
                ("store.zoo", "stored"),
                ("default.zoo", "lzd"),
                ("high_per.zoo", "lh5"),
            )
            for filename, method in cases:
                fixture = args.fixtures / filename
                listing = run(args.cli, "list-zoo-file", str(fixture)).stdout
                if f"method={method}" not in listing:
                    raise AssertionError(f"Vort misparsed {filename}: {listing}")
                output = temp / f"fixture-{method}.out"
                run(args.cli, "extract-zoo-file", str(fixture), "license", str(output))
                decoded = output.read_bytes()
                if expected is not None and decoded != expected:
                    raise AssertionError(f"Vort fixture extraction mismatch for {filename}")
                if zoo_tool is not None:
                    run(zoo_tool, "-test", str(fixture))
                reader_fixtures += 1

            wrong = args.fixtures / "wrongcrc16.zoo"
            failed = run(
                args.cli,
                "extract-zoo-file",
                str(wrong),
                "license",
                str(temp / "wrong-crc.out"),
                check=False,
            )
            if failed.returncode == 0:
                raise AssertionError("Vort accepted a ZOO entry with a bad content CRC-16")
            corrupt_crc = True

        directory_bad = bytearray((temp / "vort-stored-first.zoo").read_bytes())
        directory_bad[60] ^= 1
        directory_bad_path = temp / "bad-directory-crc.zoo"
        directory_bad_path.write_bytes(directory_bad)
        failed = run(args.cli, "list-zoo-file", str(directory_bad_path), check=False)
        if failed.returncode == 0:
            raise AssertionError("Vort accepted a ZOO entry with a bad directory CRC-16")
        directory_crc = True

    print(
        f"methods={len(methods)} self_writer_cases={len(methods)} "
        f"zoo={zoo_tool is not None} writer_external={writer_external} "
        f"reference_writer={reference_writer} unarc={unarc_tool is not None} "
        f"writer_unarc={writer_unarc} reader_fixtures={reader_fixtures} "
        f"corrupt_crc={corrupt_crc} directory_crc={directory_crc}"
    )


if __name__ == "__main__":
    main()
