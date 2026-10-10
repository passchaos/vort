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
    method: str | None = None,
    solid: bool | None = None,
) -> int:
    listing = run(cli, "list-rar-file", str(archive)).stdout
    names = [
        line.split(" name=", 1)[1]
        for line in listing.splitlines()
        if line.startswith("index=") and "directory=false" in line
        and (method is None or f"method={method}" in line)
        and (solid is None or f"solid={str(solid).lower()}" in line)
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
    rar29_ppmd_entries = 0
    rar29_vm_entries = 0
    rar50_entries = 0
    rar50_multiblock = 0

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
                run(
                    args.cli,
                    "extract-rar-file",
                    str(compressed),
                    "payload.bin",
                    str(compressed_output),
                    str(len(payload)),
                )
                if compressed_output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed reference compressed {version} data")
                reference_compressed_decoded += 1
                reference_compressed += 1

            large_payload = payload * 80
            large_source = temp / "rar50-large-source.bin"
            large_source.write_bytes(large_payload)
            large_archive = temp / "reference-rar5-large-compress.rar"
            large_output = temp / "reference-rar5-large.out"
            run(args.rars, "rar5", "compress", str(large_archive), str(large_source))
            run(
                args.cli,
                "extract-rar-file",
                str(large_archive),
                "payload.bin",
                str(large_output),
                str(len(large_payload)),
            )
            if large_output.read_bytes() != large_payload:
                raise AssertionError("Vort failed multiblock reference RAR50 data")
            if seven_zip is not None:
                run(seven_zip, "t", str(large_archive))
            rar50_multiblock += 1

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

            ppmd_archives = (
                args.legacy_fixtures / "ppmd" / "ppmd_lorem_rar300.rar",
                args.legacy_fixtures / "ppmd" / "ppmd_escape_rar300.rar",
                args.legacy_fixtures / "ppmd" / "ppmd_lz_match_rar300.rar",
                args.legacy_fixtures / "ppmd" / "ppmd_mixed_rar300.rar",
            )
            for index, archive in enumerate(ppmd_archives):
                rar29_ppmd_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar29-ppmd-{index}",
                    method="rar29",
                )

            solid_ppmd = args.legacy_fixtures / "ppmd" / "ppmd_solid_rar300.rar"
            rar29_ppmd_entries += compare_archive_entries(
                args.cli,
                seven_zip,
                solid_ppmd,
                temp,
                "rar29-ppmd-solid-first",
                method="rar29",
                solid=False,
            )
            solid_ppmd_listing = run(args.cli, "list-rar-file", str(solid_ppmd)).stdout
            solid_ppmd_name = next(
                line.split(" name=", 1)[1]
                for line in solid_ppmd_listing.splitlines()
                if line.startswith("index=")
                and "method=rar29" in line
                and "solid=true" in line
            )
            failed = run(
                args.cli,
                "extract-rar-file",
                str(solid_ppmd),
                solid_ppmd_name,
                str(temp / "solid-ppmd-continuation.out"),
                check=False,
            )
            if failed.returncode == 0 or "UnsupportedRarFeature" not in failed.stderr:
                raise AssertionError(
                    "Vort accepted a solid RAR29 PPMd continuation without session state"
                )

            vm_archives = (
                args.legacy_fixtures / "rar300" / "rarvm_x86_e8_rar300.rar",
                args.legacy_fixtures / "rar300" / "rarvm_x86_e8e9_rar300.rar",
                args.legacy_fixtures / "rar300" / "rarvm_delta_4ch_rar300.rar",
                args.legacy_fixtures / "rar300" / "rarvm_rgb_gradient_rar300.rar",
                args.legacy_fixtures / "rar300" / "rarvm_audio_stereo_rar300.rar",
                args.legacy_fixtures / "rar300" / "rarvm_itanium_synthetic_rar300.rar",
                args.legacy_fixtures / "rarvm" / "delta_64_channels.rar",
                args.legacy_fixtures / "rarvm" / "ppmd_embedded_vm_filter.rar",
                args.legacy_fixtures / "rarvm" / "filter_bsdcat_exe.rar",
                args.legacy_fixtures / "rarvm" / "vm_encoded_u32_filter.rar",
            )
            for index, archive in enumerate(vm_archives):
                rar29_vm_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar29-vm-{index}",
                    method="rar29",
                )

            # This fixture deliberately changes padding so its bytecode no
            # longer matches a standard-program fingerprint. 7-Zip refuses
            # that synthetic archive, so compare the generic VM result with
            # the canonical Itanium fixture carrying the same final payload.
            generic_vm = args.legacy_fixtures / "rarvm" / "generic_delta_padding_mutation.rar"
            generic_output = temp / "rar29-vm-generic.out"
            run(
                args.cli,
                "extract-rar-file",
                str(generic_vm),
                "itanium_synthetic_bundles.bin",
                str(generic_output),
                str(256 * 1024 * 1024),
            )
            generic_reference = temp / "rar29-vm-generic-reference"
            generic_reference.mkdir()
            run(
                seven_zip,
                "x",
                "-y",
                f"-o{generic_reference}",
                str(args.legacy_fixtures / "rar300" / "rarvm_itanium_synthetic_rar300.rar"),
            )
            expected_generic = generic_reference / "itanium_synthetic_bundles.bin"
            if generic_output.read_bytes() != expected_generic.read_bytes():
                raise AssertionError("Vort generic RAR VM output mismatch")
            rar29_vm_entries += 1

            rar50_archives = (
                args.legacy_fixtures.parent / "rar50" / "m1_fastest.rar",
                args.legacy_fixtures.parent / "rar50" / "m3_default.rar",
                args.legacy_fixtures.parent / "rar50" / "m5_max.rar",
                args.legacy_fixtures.parent / "rar50" / "filter_delta.rar",
                args.legacy_fixtures.parent / "rar50" / "filter_e8.rar",
                args.legacy_fixtures.parent / "rar50" / "filter_e8e9.rar",
                args.legacy_fixtures.parent / "rar50" / "filter_arm.rar",
            )
            for index, archive in enumerate(rar50_archives):
                rar50_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar50-{index}",
                    method="rar50",
                )

            zero_fill = args.legacy_fixtures.parent / "rar50" / "zero_fill_out_of_window.rar"
            zero_fill_output = temp / "rar50-zero-fill.out"
            run(
                args.cli,
                "extract-rar-file",
                str(zero_fill),
                "zerofill.bin",
                str(zero_fill_output),
                "1024",
            )
            expected_zero_fill = b"\0" * 8 + b"zero-fill regression payload " * 8
            if zero_fill_output.read_bytes() != expected_zero_fill:
                raise AssertionError("Vort RAR50 out-of-window zero fill mismatch")
            rar50_entries += 1

            missing_tables = args.legacy_fixtures.parent / "rar50" / "first_block_without_tables.rar"
            failed = run(
                args.cli,
                "extract-rar-file",
                str(missing_tables),
                "mid.txt",
                str(temp / "rar50-missing-tables.out"),
                check=False,
            )
            if failed.returncode == 0 or "InvalidRar50Stream" not in failed.stderr:
                raise AssertionError("Vort accepted a first RAR50 block without tables")

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
        f"rar29_ppmd_entries={rar29_ppmd_entries} "
        f"rar29_vm_entries={rar29_vm_entries} "
        f"rar50_entries={rar50_entries} "
        f"rar50_multiblock={rar50_multiblock} "
        f"header_crc=True data_crc=True sfx=True"
    )


if __name__ == "__main__":
    main()
