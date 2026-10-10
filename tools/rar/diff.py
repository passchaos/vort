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


def compare_archive_entries(
    cli: Path,
    seven_zip: Path,
    archive: Path,
    root: Path,
    label: str,
) -> int:
    listing = run(cli, "list-rar-file", str(archive)).stdout
    names = [
        line.split(" name=", 1)[1]
        for line in listing.splitlines()
        if line.startswith("index=") and "directory=false" in line
    ]
    reference = root / f"reference-{label}"
    reference.mkdir()
    run(seven_zip, "x", "-y", f"-o{reference}", str(archive))
    for index, name in enumerate(names):
        output = root / f"decoded-{label}-{index}.out"
        run(cli, "extract-rar-file", str(archive), name, str(output), str(256 * 1024 * 1024))
        expected = reference.joinpath(*name.replace("\\", "/").split("/"))
        if output.read_bytes() != expected.read_bytes():
            raise AssertionError(f"Vort mismatch for {archive.name}:{name}")
    return len(names)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", type=Path)
    parser.add_argument("--7zz", dest="seven_zip", type=Path)
    parser.add_argument("--rars", type=Path)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--legacy-fixtures", type=Path)
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
    reference_compressed_decoded = 0
    fixture_cases = 0
    rar15_entries = 0
    rar20_entries = 0
    rar29_entries = 0

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
                compressed_output = temp / f"compressed-{version}.out"
                if version == "rar4":
                    run(
                        args.cli,
                        "extract-rar-file",
                        str(compressed),
                        "payload.bin",
                        str(compressed_output),
                        str(len(payload)),
                    )
                    if compressed_output.read_bytes() != payload:
                        raise AssertionError("Vort failed reference RAR29 LZ data")
                    reference_compressed_decoded += 1
                else:
                    failed = run(
                        args.cli,
                        "extract-rar-file",
                        str(compressed),
                        "payload.bin",
                        str(compressed_output),
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

        if args.legacy_fixtures is not None and seven_zip is not None:
            rar15_archives = (
                args.legacy_fixtures / "rar154" / "readme_154_normal.rar",
                args.legacy_fixtures / "rar154" / "doc_154_best.rar",
                args.legacy_fixtures / "rar154" / "audio_dos_names_unpack15.rar",
                args.legacy_fixtures / "rar154" / "audio_win_names_unpack15.rar",
            )
            for index, archive in enumerate(rar15_archives):
                rar15_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar15-{index}",
                )

            rar20_archives = (
                args.legacy_fixtures / "rar250" / "BIGLZ.RAR",
                args.legacy_fixtures / "rar250" / "AUDIO.RAR",
                args.legacy_fixtures / "rar250" / "AUTOREJ.RAR",
                args.legacy_fixtures / "rar250" / "unpack20_audio_text.rar",
                args.legacy_fixtures / "rar250" / "unpack20_keep_tables.rar",
                args.legacy_fixtures / "rar250" / "unpack20_multiblock.rar",
            )
            for index, archive in enumerate(rar20_archives):
                rar20_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar20-{index}",
                )

            rar29_archives = (
                args.legacy_fixtures / "rar300" / "compressed_text_rar300.rar",
                args.legacy_fixtures / "rars_generated" / "compressed.rar",
            )
            for index, archive in enumerate(rar29_archives):
                rar29_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar29-{index}",
                )

            unsupported_cases = (
                (
                    args.legacy_fixtures / "ppmd" / "ppmd_lorem_rar300.rar",
                    "UnsupportedRar29Ppmd",
                    "ppmd",
                ),
                (
                    args.legacy_fixtures / "rar300" / "rarvm_x86_e8_rar300.rar",
                    "UnsupportedRar29Filter",
                    "filter",
                ),
            )
            for archive, expected_error, label in unsupported_cases:
                listing = run(args.cli, "list-rar-file", str(archive)).stdout
                name = next(
                    line.split(" name=", 1)[1]
                    for line in listing.splitlines()
                    if line.startswith("index=") and "directory=false" in line
                )
                failed = run(
                    args.cli,
                    "extract-rar-file",
                    str(archive),
                    name,
                    str(temp / f"unsupported-{label}.out"),
                    str(256 * 1024 * 1024),
                    check=False,
                )
                if failed.returncode == 0 or expected_error not in failed.stderr:
                    raise AssertionError(f"Vort did not explicitly reject RAR29 {label}")

            encrypted = args.legacy_fixtures / "rar154" / "readme_154_password.rar"
            failed = run(
                args.cli,
                "extract-rar-file",
                str(encrypted),
                "README.md",
                str(temp / "encrypted.out"),
                check=False,
            )
            if failed.returncode == 0 or "EncryptedRarEntry" not in failed.stderr:
                raise AssertionError("Vort accepted encrypted RAR15 data")

            solid = args.legacy_fixtures / "rar250" / "SOLID.RAR"
            solid_listing = run(args.cli, "list-rar-file", str(solid)).stdout
            solid_name = next(
                line.split(" name=", 1)[1]
                for line in solid_listing.splitlines()
                if line.startswith("index=") and "solid=true" in line
            )
            failed = run(
                args.cli,
                "extract-rar-file",
                str(solid),
                solid_name,
                str(temp / "solid.out"),
                check=False,
            )
            if failed.returncode == 0 or "UnsupportedRarFeature" not in failed.stderr:
                raise AssertionError("Vort accepted a solid RAR20 continuation without session state")

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
        f"reference_compressed_decoded={reference_compressed_decoded} "
        f"fixture_cases={fixture_cases} rar15_entries={rar15_entries} "
        f"rar20_entries={rar20_entries} rar29_entries={rar29_entries} "
        f"header_crc=True data_crc=True sfx=True"
    )


if __name__ == "__main__":
    main()
