#!/usr/bin/env python3
"""RAR4/RAR5 stored-container interoperability and rejection harness."""

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
    rng = random.Random(0x5241_5235)
    prefix = bytes(rng.randrange(256) for _ in range(8192))
    return prefix + b"RAR interoperability payload\n" * 512 + prefix


def seven_zip_extract(tool: Path, archive: Path, output_dir: Path) -> bytes:
    output_dir.mkdir()
    run(tool, "x", "-y", f"-o{output_dir}", str(archive), "payload.bin")
    return (output_dir / "payload.bin").read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", type=Path)
    parser.add_argument("--7zz", dest="seven_zip", type=Path)
    parser.add_argument("--rars", type=Path)
    parser.add_argument("--fixtures", type=Path)
    args = parser.parse_args()
    seven_zip = args.seven_zip
    if seven_zip is None:
        found = shutil.which("7zz") or shutil.which("7z")
        seven_zip = Path(found) if found else None
    versions = ("rar4", "rar5")
    payload = make_payload()
    writer_external = 0
    reference_stored = 0
    reference_compressed = 0
    fixture_cases = 0

    with tempfile.TemporaryDirectory(prefix="vort-rar-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)

        for version in versions:
            first = temp / f"vort-{version}-first.rar"
            second = temp / f"vort-{version}-second.rar"
            output = temp / f"vort-{version}.out"
            run(args.cli, "create-rar-file", str(first), "payload.bin", str(source), version)
            run(args.cli, "create-rar-file", str(second), "payload.bin", str(source), version)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort {version} output is not deterministic")
            listing = run(args.cli, "list-rar-file", str(first)).stdout
            if f"version={version}" not in listing or "method=stored" not in listing:
                raise AssertionError(f"Vort mislabeled {version}: {listing}")
            run(args.cli, "extract-rar-file", str(first), "payload.bin", str(output), str(len(payload)))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort {version} self-extraction mismatch")
            if seven_zip is not None:
                run(seven_zip, "t", str(first))
                if seven_zip_extract(seven_zip, first, temp / f"7z-vort-{version}") != payload:
                    raise AssertionError(f"7-Zip rejected Vort {version}")
                writer_external += 1

        if args.writer is not None:
            for version in versions:
                archive = temp / f"probe-{version}.rar"
                run(args.writer, str(archive), version)
                listing = run(args.cli, "list-rar-file", str(archive)).stdout
                if "directory=true" not in listing or "name=folder" not in listing:
                    raise AssertionError(f"Vort writer probe metadata mismatch for {version}: {listing}")
                if version == "rar5" and "name=目录/数据.txt" not in listing:
                    raise AssertionError(f"Vort RAR5 UTF-8 name mismatch: {listing}")
                if seven_zip is not None:
                    run(seven_zip, "t", str(archive))

        if args.rars is not None:
            for version in versions:
                stored = temp / f"reference-{version}-store.rar"
                compressed = temp / f"reference-{version}-compress.rar"
                run(args.rars, version, "store", str(stored), str(source))
                run(args.rars, version, "compress", str(compressed), str(source))
                listing = run(args.cli, "list-rar-file", str(stored)).stdout
                if "method=stored" not in listing:
                    raise AssertionError(f"Vort misparsed reference stored {version}: {listing}")
                output = temp / f"reference-{version}.out"
                run(args.cli, "extract-rar-file", str(stored), "payload.bin", str(output), str(len(payload)))
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed reference stored {version}")
                reference_stored += 1

                listing = run(args.cli, "list-rar-file", str(compressed)).stdout
                expected_method = "rar29" if version == "rar4" else "rar50"
                if f"method={expected_method}" not in listing:
                    raise AssertionError(f"Vort misparsed reference compressed {version}: {listing}")
                failed = run(
                    args.cli,
                    "extract-rar-file",
                    str(compressed),
                    "payload.bin",
                    str(temp / f"unsupported-{version}.out"),
                    str(len(payload)),
                    check=False,
                )
                if failed.returncode == 0 or "UnsupportedRarCompression" not in failed.stderr:
                    raise AssertionError(f"Vort did not explicitly reject compressed {version}")
                reference_compressed += 1

        if args.fixtures is not None:
            acid = args.fixtures.parent.parent / "acid-70a.rar"
            if acid.exists():
                listing = run(args.cli, "list-rar-file", str(acid)).stdout
                if "rar_entries=28" not in listing or "method=rar20" not in listing:
                    raise AssertionError(f"Vort misparsed RAR2 fixture: {listing[:1000]}")
                fixture_cases += 1
            first_volume = args.fixtures / "unarc.part1.rar"
            if first_volume.exists():
                listing = run(args.cli, "list-rar-file", str(first_volume)).stdout
                if "version=rar5" not in listing or "volume=true" not in listing or "split_after=true" not in listing:
                    raise AssertionError(f"Vort misparsed RAR5 volume: {listing}")
                failed = run(
                    args.cli,
                    "extract-rar-file",
                    str(first_volume),
                    "unarc",
                    str(temp / "split.out"),
                    check=False,
                )
                if failed.returncode == 0 or "SplitRarEntry" not in failed.stderr:
                    raise AssertionError("Vort accepted an incomplete split RAR entry")
                fixture_cases += 1

        original = temp / "vort-rar5-first.rar"
        sfx = temp / "sfx.rar"
        sfx.write_bytes(b"MZ deterministic prefix" + original.read_bytes())
        sfx_listing = run(args.cli, "list-rar-file", str(sfx)).stdout
        if "prefix_bytes=23" not in sfx_listing:
            raise AssertionError(f"Vort lost RAR SFX prefix: {sfx_listing}")

        header_bad = bytearray(original.read_bytes())
        header_bad[8] ^= 1
        header_bad_path = temp / "header-bad.rar"
        header_bad_path.write_bytes(header_bad)
        if run(args.cli, "list-rar-file", str(header_bad_path), check=False).returncode == 0:
            raise AssertionError("Vort accepted a corrupt RAR header CRC")

        data_bad = bytearray(original.read_bytes())
        data_offset = data_bad.find(payload)
        if data_offset < 0:
            raise AssertionError("could not locate RAR payload")
        data_bad[data_offset] ^= 1
        data_bad_path = temp / "data-bad.rar"
        data_bad_path.write_bytes(data_bad)
        failed = run(
            args.cli,
            "extract-rar-file",
            str(data_bad_path),
            "payload.bin",
            str(temp / "crc.out"),
            check=False,
        )
        if failed.returncode == 0 or "ChecksumMismatch" not in failed.stderr:
            raise AssertionError("Vort accepted corrupt stored RAR data")

    print(
        f"versions={len(versions)} self_writer_cases={len(versions)} "
        f"seven_zip={seven_zip is not None} writer_external={writer_external} "
        f"reference_stored={reference_stored} reference_compressed={reference_compressed} "
        f"fixture_cases={fixture_cases} header_crc=True data_crc=True sfx=True"
    )


if __name__ == "__main__":
    main()
