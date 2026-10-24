#!/usr/bin/env python3
"""RAR4/RAR5 codec, encryption, and rejection interoperability harness."""

from __future__ import annotations

import argparse
import base64
import random
import shutil
import subprocess
import tempfile
from pathlib import Path

from ppmd_filter_diff import run_matrix as run_ppmd_filter_matrix


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


def seven_zip_extract(
    tool: Path,
    archive: Path,
    output_dir: Path,
    password: str | None = None,
) -> bytes:
    output_dir.mkdir()
    password_arg = (f"-p{password}",) if password is not None else ()
    run(
        tool,
        "x",
        "-y",
        *password_arg,
        f"-o{output_dir}",
        str(archive),
        "payload.bin",
    )
    return (output_dir / "payload.bin").read_bytes()


def compare_archive_entries(
    cli: Path,
    seven_zip: Path,
    archive: Path,
    root: Path,
    label: str,
    method: str | None = None,
    solid: bool | None = None,
    password: str | None = None,
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
    password_arg = (f"-p{password}",) if password is not None else ()
    run(seven_zip, "x", "-y", *password_arg, f"-o{reference}", str(archive))
    for index, name in enumerate(names):
        output = root / f"decoded-{label}-{index}.out"
        cli_password = (password,) if password is not None else ()
        run(
            cli,
            "extract-rar-file",
            str(archive),
            name,
            str(output),
            str(256 * 1024 * 1024),
            *cli_password,
        )
        expected = reference.joinpath(*name.replace("\\", "/").split("/"))
        if output.read_bytes() != expected.read_bytes():
            raise AssertionError(f"Vort mismatch for {archive.name}:{name}")
    return len(names)


def compare_unrar_entries(
    cli: Path,
    unrar: Path,
    archive: Path,
    root: Path,
    label: str,
    password: str | None = None,
    accepted_exit_codes: tuple[int, ...] = (0,),
) -> int:
    listing = run(cli, "list-rar-file", str(archive)).stdout
    names = [
        line.split(" name=", 1)[1]
        for line in listing.splitlines()
        if line.startswith("index=") and "directory=false" in line
    ]
    reference = root / f"unrar-reference-{label}"
    reference.mkdir()
    password_arg = f"-p{password}" if password is not None else "-p-"
    extracted = run(
        unrar,
        "x",
        "-o+",
        "-idq",
        password_arg,
        str(archive),
        f"{reference}/",
        check=False,
    )
    if extracted.returncode not in accepted_exit_codes:
        raise AssertionError(
            f"unrar failed for {archive.name}: {extracted.returncode}: {extracted.stderr}"
        )
    for index, name in enumerate(names):
        output = root / f"unrar-decoded-{label}-{index}.out"
        cli_password = (password,) if password is not None else ()
        run(
            cli,
            "extract-rar-file",
            str(archive),
            name,
            str(output),
            str(256 * 1024 * 1024),
            *cli_password,
        )
        expected = reference.joinpath(*name.replace("\\", "/").split("/"))
        if output.read_bytes() != expected.read_bytes():
            raise AssertionError(f"Vort/unrar mismatch for {archive.name}:{name}")
    return len(names)


def compare_volume_entries(
    cli: Path,
    seven_zip: Path,
    archives: tuple[Path, ...],
    names: tuple[str, ...],
    root: Path,
    label: str,
) -> int:
    reference = root / f"reference-{label}"
    reference.mkdir()
    run(seven_zip, "x", "-y", f"-o{reference}", str(archives[0]))
    for index, name in enumerate(names):
        output = root / f"decoded-{label}-{index}.out"
        run(
            cli,
            "extract-rar-volumes",
            name,
            str(output),
            str(256 * 1024 * 1024),
            *(str(archive) for archive in archives),
        )
        expected = reference.joinpath(*name.replace("\\", "/").split("/"))
        if output.read_bytes() != expected.read_bytes():
            raise AssertionError(f"Vort volume mismatch for {archives[0].name}:{name}")
    return len(names)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", type=Path)
    parser.add_argument("--7zz", dest="seven_zip", type=Path)
    parser.add_argument("--rar", dest="rar_tool", type=Path)
    parser.add_argument("--rar4", dest="rar4_tool", type=Path)
    parser.add_argument("--unrar", dest="unrar_tool", type=Path)
    parser.add_argument("--rars", type=Path)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--legacy-fixtures", type=Path)
    args = parser.parse_args()
    seven_zip = args.seven_zip
    if seven_zip is None:
        found = shutil.which("7zz") or shutil.which("7z")
        seven_zip = Path(found) if found else None
    rar_tool = args.rar_tool
    if rar_tool is None:
        found = shutil.which("rar")
        rar_tool = Path(found) if found else None
    rar4_tool = args.rar4_tool
    unrar_tool = args.unrar_tool
    if unrar_tool is None:
        found = shutil.which("unrar")
        unrar_tool = Path(found) if found else None
    versions = ("rar4", "rar5")
    payload = make_payload()
    writer_external = 0
    writer_compressed = 0
    writer_compressed_external = 0
    writer_ppmd = 0
    writer_ppmd_external = 0
    writer_ppmd_filtered = 0
    writer_ppmd_filtered_external = 0
    writer_ppmd_filtered_unrar = 0
    writer_ppmd_filtered_solid = 0
    writer_ppmd_filtered_solid_external = 0
    writer_ppmd_filtered_solid_unrar = 0
    writer_ppmd_filtered_encrypted = 0
    writer_ppmd_filtered_encrypted_external = 0
    writer_ppmd_filtered_encrypted_unrar = 0
    writer_rar29_filtered_solid = 0
    writer_rar29_filtered_solid_external = 0
    writer_rar29_filtered_solid_unrar = 0
    writer_rar29_filtered_solid_encrypted = 0
    writer_rar29_filtered_solid_encrypted_external = 0
    writer_rar29_filtered_solid_encrypted_unrar = 0
    writer_filtered = 0
    writer_filtered_external = 0
    writer_solid = 0
    writer_solid_external = 0
    writer_volumes = 0
    writer_volumes_external = 0
    writer_encrypted = 0
    writer_encrypted_external = 0
    reference_encrypted = 0
    writer_encrypted_headers = 0
    writer_encrypted_headers_external = 0
    reference_encrypted_headers = 0
    writer_encrypted_volumes = 0
    writer_encrypted_volumes_external = 0
    reference_encrypted_volumes = 0
    writer_rar4_encrypted = 0
    writer_rar4_encrypted_external = 0
    reference_rar4_encrypted = 0
    writer_rar4_encrypted_headers = 0
    writer_rar4_encrypted_headers_external = 0
    reference_rar4_encrypted_headers = 0
    writer_rar4_encrypted_volumes = 0
    writer_rar4_encrypted_volumes_external = 0
    reference_rar4_encrypted_volumes = 0
    writer_rar4_unicode = 0
    writer_rar4_unicode_external = 0
    writer_redirections = 0
    writer_redirections_external = 0
    writer_comments = 0
    writer_comments_external = 0
    writer_comment_volumes = 0
    writer_comment_volumes_external = 0
    reference_comments = 0
    writer_rar4_comments = 0
    writer_rar4_comments_external = 0
    writer_rar4_comment_volumes = 0
    writer_rar4_comment_volumes_external = 0
    reference_rar4_comments = 0
    reference_rar4_unicode = 0
    reference_stored = 0
    reference_compressed = 0
    reference_compressed_decoded = 0
    fixture_cases = 0
    rar15_entries = 0
    rar20_entries = 0
    rar15_solid_entries = 0
    rar20_solid_entries = 0
    legacy_solid_unrar_entries = 0
    legacy_mixed_solid_unrar_entries = 0
    rar15_encrypted_entries = 0
    rar20_encrypted_entries = 0
    legacy_encrypted_unrar_entries = 0
    rar29_entries = 0
    rar29_ppmd_entries = 0
    rar29_vm_entries = 0
    rar50_entries = 0
    rar50_multiblock = 0
    rar50_solid_entries = 0
    rar50_volume_sets = 0
    rar50_volume_entries = 0

    with tempfile.TemporaryDirectory(prefix="vort-rar-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)
        large_payload = payload * 80
        large_source = temp / "rar50-large-source.bin"
        large_source.write_bytes(large_payload)

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
            rar4_comment_archive = temp / "vort-rar4-comment.rar"
            run(args.writer, str(rar4_comment_archive), "rar4", "rar4-comment")
            rar4_listing = run(
                args.cli,
                "list-rar-file",
                str(rar4_comment_archive),
            ).stdout
            if (
                "has_comment=true" not in rar4_listing
                or "comment_bytes=24" not in rar4_listing
                or "comment_encrypted=false" not in rar4_listing
            ):
                raise AssertionError(f"RAR4 comment listing mismatch: {rar4_listing}")
            writer_rar4_comments += 1
            if rar_tool is not None:
                external_listing = run(
                    rar_tool,
                    "lt",
                    "-p-",
                    str(rar4_comment_archive),
                ).stdout
                if "Vort RAR4 comment 世界" not in external_listing:
                    raise AssertionError("RAR omitted Vort RAR4 archive comment text")
                writer_rar4_comments_external += 1
            elif seven_zip is not None:
                run(seven_zip, "t", str(rar4_comment_archive))
                writer_rar4_comments_external += 1

            rar4_encrypted_comment_archive = temp / "vort-rar4-comment-encrypted.rar"
            rar4_comment_password = "rar4-comment-password"
            run(
                args.writer,
                str(rar4_encrypted_comment_archive),
                "rar4",
                "rar4-comment-encrypted",
            )
            rar4_encrypted_listing = run(
                args.cli,
                "list-rar-file",
                str(rar4_encrypted_comment_archive),
                rar4_comment_password,
            ).stdout
            if (
                "has_comment=true" not in rar4_encrypted_listing
                or "comment_bytes=34" not in rar4_encrypted_listing
                or "comment_encrypted=true" not in rar4_encrypted_listing
                or "encrypted_headers=true" not in rar4_encrypted_listing
            ):
                raise AssertionError(
                    f"RAR4 encrypted comment listing mismatch: {rar4_encrypted_listing}"
                )
            writer_rar4_comments += 1
            if rar_tool is not None:
                external_listing = run(
                    rar_tool,
                    "lt",
                    f"-p{rar4_comment_password}",
                    str(rar4_encrypted_comment_archive),
                ).stdout
                if "Encrypted Vort RAR4 comment 世界" not in external_listing:
                    raise AssertionError("RAR omitted encrypted Vort RAR4 comment text")
                writer_rar4_comments_external += 1
            elif seven_zip is not None:
                run(
                    seven_zip,
                    "t",
                    f"-p{rar4_comment_password}",
                    str(rar4_encrypted_comment_archive),
                )
                writer_rar4_comments_external += 1

            rar4_comment_volume_prefix = temp / "vort-rar4-comment-volumes"
            run(
                args.writer,
                str(rar4_comment_volume_prefix),
                "rar4",
                "rar4-comment-volumes",
            )
            rar4_comment_volumes = tuple(
                sorted(temp.glob("vort-rar4-comment-volumes.part*.rar"))
            )
            if len(rar4_comment_volumes) < 2:
                raise AssertionError("RAR4 comment volume probe did not split file data")
            rar4_volume_comment = "Vort RAR4 comment outside payload budget\n" * 8
            rar4_first_listing = run(
                args.cli,
                "list-rar-file",
                str(rar4_comment_volumes[0]),
            ).stdout
            if (
                f"comment_bytes={len(rar4_volume_comment.encode('utf-8'))}"
                not in rar4_first_listing
                or "compressed=64" not in rar4_first_listing
            ):
                raise AssertionError(
                    f"RAR4 first-volume comment budget mismatch: {rar4_first_listing}"
                )
            for continuation in rar4_comment_volumes[1:]:
                continuation_listing = run(
                    args.cli,
                    "list-rar-file",
                    str(continuation),
                ).stdout
                if "has_comment=false" not in continuation_listing:
                    raise AssertionError(
                        f"RAR4 comment repeated in continuation volume: {continuation_listing}"
                    )
            rar4_comment_volume_output = temp / "vort-rar4-comment-volumes.out"
            rar4_volume_payload = b"RAR4 comment volume payload\n" * 16
            run(
                args.cli,
                "extract-rar-volumes",
                "rar4-comment-volume.txt",
                str(rar4_comment_volume_output),
                str(len(rar4_volume_payload)),
                *(str(volume) for volume in rar4_comment_volumes),
            )
            if rar4_comment_volume_output.read_bytes() != rar4_volume_payload:
                raise AssertionError("RAR4 comment volume payload mismatch")
            writer_rar4_comment_volumes = 1
            if seven_zip is not None:
                run(seven_zip, "t", str(rar4_comment_volumes[0]))
                writer_rar4_comment_volumes_external = 1
            elif rar_tool is not None:
                run(rar_tool, "t", "-idq", "-p-", str(rar4_comment_volumes[0]))
                writer_rar4_comment_volumes_external = 1

            comment_archive = temp / "vort-rar5-comment.rar"
            run(args.writer, str(comment_archive), "rar5", "rar5-comment")
            listing = run(args.cli, "list-rar-file", str(comment_archive)).stdout
            if (
                "has_comment=true" not in listing
                or "comment_bytes=24" not in listing
                or "comment_encrypted=false" not in listing
            ):
                raise AssertionError(f"RAR5 comment listing mismatch: {listing}")
            writer_comments += 1
            if seven_zip is not None:
                run(seven_zip, "t", str(comment_archive))
                writer_comments_external += 1
            elif rar_tool is not None:
                run(rar_tool, "t", "-idq", "-p-", str(comment_archive))
                writer_comments_external += 1

            encrypted_comment_archive = temp / "vort-rar5-comment-encrypted.rar"
            comment_password = "rar5-comment-password"
            run(
                args.writer,
                str(encrypted_comment_archive),
                "rar5",
                "rar5-comment-encrypted",
            )
            encrypted_listing = run(
                args.cli,
                "list-rar-file",
                str(encrypted_comment_archive),
                comment_password,
            ).stdout
            if (
                "has_comment=true" not in encrypted_listing
                or "comment_bytes=29" not in encrypted_listing
                or "comment_encrypted=true" not in encrypted_listing
                or "encrypted_headers=true" not in encrypted_listing
            ):
                raise AssertionError(
                    f"RAR5 encrypted comment listing mismatch: {encrypted_listing}"
                )
            writer_comments += 1
            if seven_zip is not None:
                run(
                    seven_zip,
                    "t",
                    f"-p{comment_password}",
                    str(encrypted_comment_archive),
                )
                writer_comments_external += 1
            elif rar_tool is not None:
                run(
                    rar_tool,
                    "t",
                    "-idq",
                    f"-p{comment_password}",
                    str(encrypted_comment_archive),
                )
                writer_comments_external += 1

            comment_volume_prefix = temp / "vort-rar5-comment-volumes"
            run(
                args.writer,
                str(comment_volume_prefix),
                "rar5",
                "rar5-comment-volumes",
            )
            comment_volumes = tuple(
                sorted(temp.glob("vort-rar5-comment-volumes.part*.rar"))
            )
            if len(comment_volumes) < 2:
                raise AssertionError("RAR5 comment volume probe did not split file data")
            volume_comment = "Vort comment outside payload budget\n" * 8
            first_listing = run(
                args.cli,
                "list-rar-file",
                str(comment_volumes[0]),
            ).stdout
            if (
                f"comment_bytes={len(volume_comment.encode('utf-8'))}" not in first_listing
                or "compressed=64" not in first_listing
                or comment_volumes[0].stat().st_size <= len(volume_comment.encode("utf-8"))
            ):
                raise AssertionError(
                    f"RAR5 first-volume comment budget mismatch: {first_listing}"
                )
            for continuation in comment_volumes[1:]:
                continuation_listing = run(
                    args.cli,
                    "list-rar-file",
                    str(continuation),
                ).stdout
                if "has_comment=false" not in continuation_listing:
                    raise AssertionError(
                        f"RAR5 comment repeated in continuation volume: {continuation_listing}"
                    )
            comment_volume_output = temp / "vort-rar5-comment-volumes.out"
            volume_payload = b"RAR5 comment volume payload\n" * 16
            run(
                args.cli,
                "extract-rar-volumes",
                "comment-volume.txt",
                str(comment_volume_output),
                str(len(volume_payload)),
                *(str(volume) for volume in comment_volumes),
            )
            if comment_volume_output.read_bytes() != volume_payload:
                raise AssertionError("RAR5 comment volume payload mismatch")
            writer_comment_volumes = 1
            if seven_zip is not None:
                run(seven_zip, "t", str(comment_volumes[0]))
                writer_comment_volumes_external = 1
            elif rar_tool is not None:
                run(rar_tool, "t", "-idq", "-p-", str(comment_volumes[0]))
                writer_comment_volumes_external = 1

            redirection_archive = temp / "vort-rar5-redirections.rar"
            run(
                args.writer,
                str(redirection_archive),
                "rar5",
                "rar5-redirections",
            )
            listing = run(args.cli, "list-rar-file", str(redirection_archive)).stdout
            expected_fields = (
                "redirection=unix_symlink redirection_directory=false "
                "redirection_safe=true redirection_target=target.txt name=unix-link",
                "redirection=hard_link redirection_directory=false "
                "redirection_safe=true redirection_target=target.txt name=hard-link",
                "redirection=unix_symlink redirection_directory=true "
                "redirection_safe=true redirection_target=folder name=folder-link",
            )
            for expected in expected_fields:
                if expected not in listing:
                    raise AssertionError(f"RAR5 redirection listing mismatch: {listing}")
                writer_redirections += 1
            if seven_zip is not None:
                run(seven_zip, "t", str(redirection_archive))
                external_listing = run(
                    seven_zip,
                    "l",
                    "-slt",
                    str(redirection_archive),
                ).stdout
                for name in ("unix-link", "hard-link", "folder-link"):
                    if f"Path = {name}" not in external_listing:
                        raise AssertionError(
                            f"7-Zip omitted RAR5 redirection {name!r}"
                        )
                writer_redirections_external = 3

        if rar_tool is not None:
            comment_source = temp / "reference-comment.txt"
            comment_source.write_text("RAR reference payload\n", encoding="utf-8")
            comment_file = temp / "reference-comment-body.txt"
            comment_file.write_text("Reference comment 世界", encoding="utf-8")
            for encrypted_headers in (False, True):
                suffix = "secret" if encrypted_headers else "plain"
                reference_comment_archive = temp / f"reference-comment-{suffix}.rar"
                password_args = ("-hpcomment-password",) if encrypted_headers else ()
                run(
                    rar_tool,
                    "a",
                    "-idq",
                    "-ma5",
                    "-m0",
                    "-ep",
                    *password_args,
                    f"-z{comment_file}",
                    str(reference_comment_archive),
                    str(comment_source),
                )
                cli_password = ("comment-password",) if encrypted_headers else ()
                listing = run(
                    args.cli,
                    "list-rar-file",
                    str(reference_comment_archive),
                    *cli_password,
                ).stdout
                if (
                    "has_comment=true" not in listing
                    or "comment_bytes=24" not in listing
                    or f"comment_encrypted={str(encrypted_headers).lower()}" not in listing
                ):
                    raise AssertionError(
                        f"Vort rejected RAR5 {suffix} reference comment: {listing}"
                    )
                reference_comments += 1

            for encrypted_headers in (False, True):
                suffix = "secret" if encrypted_headers else "plain"
                reference_comment_archive = temp / f"reference-rar4-comment-{suffix}.rar"
                password_args = ("-hpcomment-password",) if encrypted_headers else ()
                created = run(
                    rar_tool,
                    "a",
                    "-idq",
                    "-ma4",
                    "-m0",
                    "-ep",
                    *password_args,
                    f"-z{comment_file}",
                    str(reference_comment_archive),
                    str(comment_source),
                    check=False,
                )
                if created.returncode != 0:
                    continue
                cli_password = ("comment-password",) if encrypted_headers else ()
                listing = run(
                    args.cli,
                    "list-rar-file",
                    str(reference_comment_archive),
                    *cli_password,
                ).stdout
                if (
                    "has_comment=true" not in listing
                    or "comment_bytes=24" not in listing
                    or f"comment_encrypted={str(encrypted_headers).lower()}" not in listing
                ):
                    raise AssertionError(
                        f"Vort rejected RAR4 {suffix} reference comment: {listing}"
                    )
                reference_rar4_comments += 1

        for version, compression in (("rar4", "rar29"), ("rar5", "rar50")):
            compressed_first = temp / f"vort-{compression}-compressed-first.rar"
            compressed_second = temp / f"vort-{compression}-compressed-second.rar"
            compressed_output = temp / f"vort-{compression}-compressed.out"
            run(
                args.cli,
                "create-rar-file",
                str(compressed_first),
                "payload.bin",
                str(large_source),
                version,
                compression,
            )
            run(
                args.cli,
                "create-rar-file",
                str(compressed_second),
                "payload.bin",
                str(large_source),
                version,
                compression,
            )
            if compressed_first.read_bytes() != compressed_second.read_bytes():
                raise AssertionError(
                    f"Vort {compression} compressed output is not deterministic"
                )
            listing = run(args.cli, "list-rar-file", str(compressed_first)).stdout
            if f"method={compression}" not in listing:
                raise AssertionError(f"Vort mislabeled its {compression} output: {listing}")
            run(
                args.cli,
                "extract-rar-file",
                str(compressed_first),
                "payload.bin",
                str(compressed_output),
                str(len(large_payload)),
            )
            if compressed_output.read_bytes() != large_payload:
                raise AssertionError(
                    f"Vort failed its own multiblock {compression} output"
                )
            writer_compressed += 1
            if seven_zip is not None:
                run(seven_zip, "t", str(compressed_first))
                if seven_zip_extract(
                    seven_zip,
                    compressed_first,
                    temp / f"7z-vort-{compression}-compressed",
                ) != large_payload:
                    raise AssertionError(
                        f"7-Zip rejected Vort {compression} compressed output"
                    )
                writer_compressed_external += 1

        encryption_password = "RAR5-test-password"
        encryption_vectors = (
            (
                "stored",
                "000102030405060708090a0b0c0d0e0f",
                "101112131415161718191a1b1c1d1e1f",
            ),
            (
                "rar50",
                "202122232425262728292a2b2c2d2e2f",
                "303132333435363738393a3b3c3d3e3f",
            ),
        )
        for compression, salt_hex, iv_hex in encryption_vectors:
            encrypted_archive = temp / f"vort-rar5-{compression}-encrypted.rar"
            encrypted_output = temp / f"vort-rar5-{compression}-encrypted.out"
            run(
                args.cli,
                "create-rar-file",
                str(encrypted_archive),
                "payload.bin",
                str(source),
                "rar5",
                compression,
                "none",
                "non-solid",
                encryption_password,
                salt_hex,
                iv_hex,
                "3",
            )
            listing = run(args.cli, "list-rar-file", str(encrypted_archive)).stdout
            if "encrypted=true" not in listing or "kdf_count=3" not in listing:
                raise AssertionError(f"Vort lost RAR5 encryption metadata: {listing}")
            run(
                args.cli,
                "extract-rar-file",
                str(encrypted_archive),
                "payload.bin",
                str(encrypted_output),
                str(len(payload)),
                encryption_password,
            )
            if encrypted_output.read_bytes() != payload:
                raise AssertionError(f"Vort failed encrypted {compression} self extraction")
            wrong_password = run(
                args.cli,
                "extract-rar-file",
                str(encrypted_archive),
                "payload.bin",
                str(temp / f"vort-rar5-{compression}-wrong.out"),
                str(len(payload)),
                "wrong-password",
                check=False,
            )
            if wrong_password.returncode == 0 or "InvalidRarPassword" not in wrong_password.stderr:
                raise AssertionError(f"Vort accepted wrong RAR5 {compression} password")
            writer_encrypted += 1
            if seven_zip is not None:
                if seven_zip_extract(
                    seven_zip,
                    encrypted_archive,
                    temp / f"7z-vort-rar5-{compression}-encrypted",
                    encryption_password,
                ) != payload:
                    raise AssertionError(f"7-Zip rejected Vort encrypted {compression}")
                writer_encrypted_external += 1

        header_ivs_hex = (
            "404142434445464748494a4b4c4d4e4f"
            "505152535455565758595a5b5c5d5e5f"
            "606162636465666768696a6b6c6d6e6f"
        )
        for index, (compression, salt_hex, iv_hex) in enumerate(encryption_vectors):
            encrypted_archive = temp / f"vort-rar5-{compression}-encrypted-headers.rar"
            encrypted_output = temp / f"vort-rar5-{compression}-encrypted-headers.out"
            run(
                args.cli,
                "create-rar-file",
                str(encrypted_archive),
                "payload.bin",
                str(source),
                "rar5",
                compression,
                "none",
                "non-solid",
                encryption_password,
                salt_hex,
                iv_hex,
                "3",
                encryption_password,
                f"{index + 4:02x}" * 16,
                header_ivs_hex,
                "3",
            )
            listing = run(
                args.cli,
                "list-rar-file",
                str(encrypted_archive),
                encryption_password,
            ).stdout
            if (
                "encrypted_headers=true" not in listing
                or "header_kdf_count=3" not in listing
                or "encrypted=true" not in listing
            ):
                raise AssertionError(f"Vort lost encrypted-header metadata: {listing}")
            run(
                args.cli,
                "extract-rar-file",
                str(encrypted_archive),
                "payload.bin",
                str(encrypted_output),
                str(len(payload)),
                encryption_password,
            )
            if encrypted_output.read_bytes() != payload:
                raise AssertionError(
                    f"Vort failed encrypted-header {compression} self extraction"
                )
            wrong_password = run(
                args.cli,
                "list-rar-file",
                str(encrypted_archive),
                "wrong-password",
                check=False,
            )
            if wrong_password.returncode == 0 or "InvalidRarPassword" not in wrong_password.stderr:
                raise AssertionError(f"Vort accepted wrong encrypted-header {compression} password")
            writer_encrypted_headers += 1
            if seven_zip is not None:
                if seven_zip_extract(
                    seven_zip,
                    encrypted_archive,
                    temp / f"7z-vort-rar5-{compression}-encrypted-headers",
                    encryption_password,
                ) != payload:
                    raise AssertionError(
                        f"7-Zip rejected Vort encrypted-header {compression}"
                    )
                writer_encrypted_headers_external += 1

        rar4_password = "RAR4-test-password"
        rar4_salt = "0102030405060708"
        for compression in ("stored", "rar29", "rar29-ppmd"):
            archive = temp / f"vort-rar4-{compression}-encrypted.rar"
            output = temp / f"vort-rar4-{compression}-encrypted.out"
            run(
                args.cli,
                "create-rar-file",
                str(archive),
                "payload.bin",
                str(source),
                "rar4",
                compression,
                "none",
                "non-solid",
                rar4_password,
                rar4_salt,
            )
            run(
                args.cli,
                "extract-rar-file",
                str(archive),
                "payload.bin",
                str(output),
                str(len(payload)),
                rar4_password,
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort failed encrypted RAR4 {compression}")
            writer_rar4_encrypted += 1
            if seven_zip is not None:
                if seven_zip_extract(
                    seven_zip,
                    archive,
                    temp / f"7z-vort-rar4-{compression}-encrypted",
                    rar4_password,
                ) != payload:
                    raise AssertionError(f"7-Zip rejected encrypted RAR4 {compression}")
                writer_rar4_encrypted_external += 1

        rar4_long_password = "RAR4-long-password-0123456789-ABCDEFGHIJKLMN"
        long_archive = temp / "vort-rar4-long-password.rar"
        long_output = temp / "vort-rar4-long-password.out"
        run(
            args.cli,
            "create-rar-file",
            str(long_archive),
            "payload.bin",
            str(source),
            "rar4",
            "stored",
            "none",
            "non-solid",
            rar4_long_password,
            rar4_salt,
        )
        run(
            args.cli,
            "extract-rar-file",
            str(long_archive),
            "payload.bin",
            str(long_output),
            str(len(payload)),
            rar4_long_password,
        )
        if long_output.read_bytes() != payload:
            raise AssertionError("Vort failed long-password RAR4 self extraction")
        writer_rar4_encrypted += 1
        if seven_zip is not None:
            if seven_zip_extract(
                seven_zip,
                long_archive,
                temp / "7z-vort-rar4-long-password",
                rar4_long_password,
            ) != payload:
                raise AssertionError("7-Zip rejected Vort long-password RAR4")
            writer_rar4_encrypted_external += 1

        for compression in ("stored", "rar29"):
            archive = temp / f"vort-rar4-{compression}-encrypted-headers.rar"
            output = temp / f"vort-rar4-{compression}-encrypted-headers.out"
            run(
                args.cli,
                "create-rar-file",
                str(archive),
                "payload.bin",
                str(source),
                "rar4",
                compression,
                "none",
                "non-solid",
                rar4_password,
                rar4_salt,
                rar4_password,
                rar4_salt,
            )
            run(
                args.cli,
                "extract-rar-file",
                str(archive),
                "payload.bin",
                str(output),
                str(len(payload)),
                rar4_password,
            )
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort failed RAR4 encrypted headers {compression}")
            writer_rar4_encrypted_headers += 1
            if seven_zip is not None:
                if seven_zip_extract(
                    seven_zip,
                    archive,
                    temp / f"7z-vort-rar4-{compression}-encrypted-headers",
                    rar4_password,
                ) != payload:
                    raise AssertionError(
                        f"7-Zip rejected RAR4 encrypted headers {compression}"
                    )
                writer_rar4_encrypted_headers_external += 1

        unicode_name = "目录/данные.txt"
        unicode_archive = temp / "vort-rar4-unicode.rar"
        unicode_output = temp / "vort-rar4-unicode.out"
        run(
            args.cli,
            "create-rar-file",
            str(unicode_archive),
            unicode_name,
            str(source),
            "rar4",
            "stored",
            "none",
            "non-solid",
        )
        unicode_listing = run(args.cli, "list-rar-file", str(unicode_archive)).stdout
        if f"name={unicode_name}" not in unicode_listing:
            raise AssertionError(f"Vort lost its RAR4 Unicode name: {unicode_listing}")
        run(
            args.cli,
            "extract-rar-file",
            str(unicode_archive),
            unicode_name,
            str(unicode_output),
            str(len(payload)),
        )
        if unicode_output.read_bytes() != payload:
            raise AssertionError("Vort failed RAR4 Unicode self extraction")
        writer_rar4_unicode += 1
        if seven_zip is not None:
            reference = temp / "vort-rar4-unicode-reference"
            reference.mkdir()
            run(seven_zip, "x", "-y", f"-o{reference}", str(unicode_archive))
            if reference.joinpath(*unicode_name.split("/")).read_bytes() != payload:
                raise AssertionError("7-Zip rejected Vort RAR4 Unicode name")
            writer_rar4_unicode_external += 1

        if rar_tool is not None:
            reference_root = temp / "rar5-encrypted-reference"
            reference_root.mkdir()
            reference_source = reference_root / "payload.bin"
            reference_source.write_bytes(payload)
            for compression, method in (("stored", "0"), ("rar50", "5")):
                reference_archive = temp / f"reference-rar5-{compression}-encrypted.rar"
                reference_output = temp / f"reference-rar5-{compression}-encrypted.out"
                run(
                    rar_tool,
                    "a",
                    "-idq",
                    "-ma5",
                    f"-m{method}",
                    "-ep",
                    f"-p{encryption_password}",
                    str(reference_archive),
                    str(reference_source),
                )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(reference_archive),
                    "payload.bin",
                    str(reference_output),
                    str(len(payload)),
                    encryption_password,
                )
                if reference_output.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected RAR encrypted {compression}")
                reference_encrypted += 1

                header_archive = temp / f"reference-rar5-{compression}-encrypted-headers.rar"
                header_output = temp / f"reference-rar5-{compression}-encrypted-headers.out"
                run(
                    rar_tool,
                    "a",
                    "-idq",
                    "-ma5",
                    f"-m{method}",
                    "-ep",
                    f"-hp{encryption_password}",
                    str(header_archive),
                    str(reference_source),
                )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(header_archive),
                    "payload.bin",
                    str(header_output),
                    str(len(payload)),
                    encryption_password,
                )
                if header_output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort rejected RAR encrypted-header {compression}"
                    )
                reference_encrypted_headers += 1

                volume_base = temp / f"reference-rar5-{compression}-encrypted-volumes.rar"
                volume_output = temp / f"reference-rar5-{compression}-encrypted-volumes.out"
                run(
                    rar_tool,
                    "a",
                    "-idq",
                    "-ma5",
                    f"-m{method}",
                    "-ep",
                    f"-hp{encryption_password}",
                    "-v3000b",
                    str(volume_base),
                    str(reference_source),
                )
                reference_volumes = tuple(
                    sorted(
                        temp.glob(
                            f"reference-rar5-{compression}-encrypted-volumes.part*.rar"
                        )
                    )
                )
                if len(reference_volumes) < 2:
                    raise AssertionError(
                        f"RAR encrypted {compression} reference did not split"
                    )
                run(
                    args.cli,
                    "extract-rar-volumes",
                    "payload.bin",
                    str(volume_output),
                    str(len(payload)),
                    f"--password={encryption_password}",
                    *(str(volume) for volume in reference_volumes),
                )
                if volume_output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort rejected RAR encrypted {compression} volumes"
                    )
                reference_encrypted_volumes += 1

        if rar4_tool is not None:
            reference_root = temp / "rar4-encrypted-reference"
            reference_root.mkdir()
            reference_source = reference_root / "payload.bin"
            reference_source.write_bytes(payload)
            for compression, method in (("stored", "0"), ("rar29", "5")):
                archive = temp / f"reference-rar4-{compression}-encrypted.rar"
                output = temp / f"reference-rar4-{compression}-encrypted.out"
                run(
                    rar4_tool,
                    "a",
                    "-idq",
                    "-ma4",
                    f"-m{method}",
                    "-ep",
                    f"-p{rar4_password}",
                    str(archive),
                    str(reference_source),
                )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(archive),
                    "payload.bin",
                    str(output),
                    str(len(payload)),
                    rar4_password,
                )
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort rejected encrypted RAR4 {compression}")
                reference_rar4_encrypted += 1

                header_archive = temp / f"reference-rar4-{compression}-encrypted-headers.rar"
                header_output = temp / f"reference-rar4-{compression}-encrypted-headers.out"
                run(
                    rar4_tool,
                    "a",
                    "-idq",
                    "-ma4",
                    f"-m{method}",
                    "-ep",
                    f"-hp{rar4_password}",
                    str(header_archive),
                    str(reference_source),
                )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(header_archive),
                    "payload.bin",
                    str(header_output),
                    str(len(payload)),
                    rar4_password,
                )
                if header_output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort rejected RAR4 encrypted headers {compression}"
                    )
                reference_rar4_encrypted_headers += 1

                volume_base = temp / f"reference-rar4-{compression}-encrypted-volumes.rar"
                volume_output = temp / f"reference-rar4-{compression}-encrypted-volumes.out"
                run(
                    rar4_tool,
                    "a",
                    "-idq",
                    "-ma4",
                    f"-m{method}",
                    "-ep",
                    f"-hp{rar4_password}",
                    "-v3000b",
                    str(volume_base),
                    str(reference_source),
                )
                reference_volumes = tuple(
                    sorted(
                        temp.glob(
                            f"reference-rar4-{compression}-encrypted-volumes.part*.rar"
                        )
                    )
                )
                if len(reference_volumes) < 2:
                    raise AssertionError(
                        f"RAR4 encrypted {compression} reference did not split"
                    )
                run(
                    args.cli,
                    "extract-rar-volumes",
                    "payload.bin",
                    str(volume_output),
                    str(len(payload)),
                    f"--password={rar4_password}",
                    *(str(volume) for volume in reference_volumes),
                )
                if volume_output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort rejected RAR4 encrypted {compression} volumes"
                    )
                reference_rar4_encrypted_volumes += 1

            long_archive = temp / "reference-rar4-long-password.rar"
            long_output = temp / "reference-rar4-long-password.out"
            run(
                rar4_tool,
                "a",
                "-idq",
                "-ma4",
                "-m0",
                "-ep",
                f"-p{rar4_long_password}",
                str(long_archive),
                str(reference_source),
            )
            run(
                args.cli,
                "extract-rar-file",
                str(long_archive),
                "payload.bin",
                str(long_output),
                str(len(payload)),
                rar4_long_password,
            )
            if long_output.read_bytes() != payload:
                raise AssertionError("Vort rejected RAR4 long-password reference")
            reference_rar4_encrypted += 1

            unicode_name = "目录-данные.txt"
            unicode_source = reference_root / unicode_name
            unicode_source.write_bytes(payload)
            unicode_archive = temp / "reference-rar4-unicode.rar"
            unicode_output = temp / "reference-rar4-unicode.out"
            run(
                rar4_tool,
                "a",
                "-idq",
                "-ma4",
                "-m0",
                "-ep",
                str(unicode_archive),
                str(unicode_source),
            )
            listing = run(args.cli, "list-rar-file", str(unicode_archive)).stdout
            if f"name={unicode_name}" not in listing:
                raise AssertionError(f"Vort misdecoded RAR4 Unicode name: {listing}")
            run(
                args.cli,
                "extract-rar-file",
                str(unicode_archive),
                unicode_name,
                str(unicode_output),
                str(len(payload)),
            )
            if unicode_output.read_bytes() != payload:
                raise AssertionError("Vort rejected RAR4 Unicode reference")
            reference_rar4_unicode += 1

        ppmd_first = temp / "vort-rar29-ppmd-first.rar"
        ppmd_second = temp / "vort-rar29-ppmd-second.rar"
        ppmd_output = temp / "vort-rar29-ppmd.out"
        for archive in (ppmd_first, ppmd_second):
            run(
                args.cli,
                "create-rar-file",
                str(archive),
                "payload.bin",
                str(large_source),
                "rar4",
                "rar29-ppmd",
            )
        if ppmd_first.read_bytes() != ppmd_second.read_bytes():
            raise AssertionError("Vort RAR29 PPMd output is not deterministic")
        ppmd_listing = run(args.cli, "list-rar-file", str(ppmd_first)).stdout
        if "method=rar29" not in ppmd_listing:
            raise AssertionError(f"Vort mislabeled its RAR29 PPMd output: {ppmd_listing}")
        run(
            args.cli,
            "extract-rar-file",
            str(ppmd_first),
            "payload.bin",
            str(ppmd_output),
            str(len(large_payload)),
        )
        if ppmd_output.read_bytes() != large_payload:
            raise AssertionError("Vort failed its own RAR29 PPMd output")
        writer_ppmd += 1
        if seven_zip is not None:
            run(seven_zip, "t", str(ppmd_first))
            if seven_zip_extract(
                seven_zip,
                ppmd_first,
                temp / "7z-vort-rar29-ppmd",
            ) != large_payload:
                raise AssertionError("7-Zip rejected Vort RAR29 PPMd output")
            writer_ppmd_external += 1

        rar29_filter_payload = bytearray(
            (index * 53 + index // 7) & 0xFF for index in range(8192)
        )
        rar29_filter_payload[16] = 0xE8
        rar29_filter_payload[17:21] = (0x1000).to_bytes(4, "little")
        rar29_filter_payload[32] = 0xE9
        rar29_filter_payload[33:37] = (0x2000).to_bytes(4, "little")
        rar29_filter_source = temp / "rar29-filter-source.bin"
        rar29_filter_source.write_bytes(rar29_filter_payload)
        for index, filter_name in enumerate(
            ("delta:4", "e8", "e8e9", "itanium", "rgb:12:1", "audio:2")
        ):
            archive = temp / f"vort-rar29-filter-{index}.rar"
            output = temp / f"vort-rar29-filter-{index}.out"
            run(
                args.cli,
                "create-rar-file",
                str(archive),
                "payload.bin",
                str(rar29_filter_source),
                "rar4",
                "rar29",
                filter_name,
            )
            run(
                args.cli,
                "extract-rar-file",
                str(archive),
                "payload.bin",
                str(output),
                str(len(rar29_filter_payload)),
            )
            if output.read_bytes() != rar29_filter_payload:
                raise AssertionError(f"Vort failed its own RAR29 {filter_name} output")
            writer_filtered += 1
            if seven_zip is not None:
                reference = temp / f"vort-rar29-filter-reference-{index}"
                reference.mkdir()
                run(seven_zip, "x", "-y", f"-o{reference}", str(archive))
                if (reference / "payload.bin").read_bytes() != rar29_filter_payload:
                    raise AssertionError(f"7-Zip rejected Vort RAR29 {filter_name} output")
                writer_filtered_external += 1

        ppmd_filter_counts = run_ppmd_filter_matrix(
            args.cli,
            args.writer,
            seven_zip,
            unrar_tool,
            temp,
            rar29_filter_source,
            bytes(rar29_filter_payload),
            rar4_password,
            rar4_salt,
        )
        writer_ppmd_filtered += ppmd_filter_counts.ordinary
        writer_ppmd_filtered_external += ppmd_filter_counts.ordinary_7zip
        writer_ppmd_filtered_unrar += ppmd_filter_counts.ordinary_unrar
        writer_filtered += ppmd_filter_counts.ordinary
        writer_filtered_external += ppmd_filter_counts.ordinary_7zip
        writer_ppmd_filtered_solid += ppmd_filter_counts.solid
        writer_ppmd_filtered_solid_external += ppmd_filter_counts.solid_7zip
        writer_ppmd_filtered_solid_unrar += ppmd_filter_counts.solid_unrar
        writer_solid += ppmd_filter_counts.solid
        writer_solid_external += ppmd_filter_counts.solid_7zip
        writer_ppmd_filtered_encrypted += ppmd_filter_counts.encrypted
        writer_ppmd_filtered_encrypted_external += ppmd_filter_counts.encrypted_7zip
        writer_ppmd_filtered_encrypted_unrar += ppmd_filter_counts.encrypted_unrar
        writer_rar29_filtered_solid += ppmd_filter_counts.lz_solid
        writer_rar29_filtered_solid_external += ppmd_filter_counts.lz_solid_7zip
        writer_rar29_filtered_solid_unrar += ppmd_filter_counts.lz_solid_unrar
        writer_rar29_filtered_solid_encrypted += ppmd_filter_counts.lz_solid_encrypted
        writer_rar29_filtered_solid_encrypted_external += (
            ppmd_filter_counts.lz_solid_encrypted_7zip
        )
        writer_rar29_filtered_solid_encrypted_unrar += (
            ppmd_filter_counts.lz_solid_encrypted_unrar
        )
        writer_solid += ppmd_filter_counts.lz_solid + ppmd_filter_counts.lz_solid_encrypted
        writer_solid_external += (
            ppmd_filter_counts.lz_solid_7zip
            + ppmd_filter_counts.lz_solid_encrypted_7zip
        )

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

            expected_solid = b"solid history payload alpha beta gamma\n" * 128
            for version, compression in (("rar4", "rar29"), ("rar5", "rar50")):
                solid_archive = temp / f"vort-{compression}-solid.rar"
                solid_output = temp / f"vort-{compression}-solid.out"
                run(args.writer, str(solid_archive), version, "solid")
                solid_listing = run(args.cli, "list-rar-file", str(solid_archive)).stdout
                if (
                    "solid=true" not in solid_listing
                    or "name=second.txt" not in solid_listing
                    or f"method={compression}" not in solid_listing
                ):
                    raise AssertionError(
                        f"Vort {compression} solid writer metadata mismatch: {solid_listing}"
                    )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(solid_archive),
                    "second.txt",
                    str(solid_output),
                    str(1024 * 1024),
                )
                if solid_output.read_bytes() != expected_solid:
                    raise AssertionError(f"Vort failed its own solid {compression} output")
                writer_solid += 1
                if seven_zip is not None:
                    solid_reference = temp / f"vort-{compression}-solid-reference"
                    solid_reference.mkdir()
                    run(
                        seven_zip,
                        "x",
                        "-y",
                        f"-o{solid_reference}",
                        str(solid_archive),
                    )
                    if (solid_reference / "second.txt").read_bytes() != expected_solid:
                        raise AssertionError(
                            f"7-Zip rejected Vort solid {compression} output"
                        )
                    writer_solid_external += 1

            ppmd_solid_archive = temp / "vort-rar29-ppmd-solid.rar"
            ppmd_solid_output = temp / "vort-rar29-ppmd-solid.out"
            run(args.writer, str(ppmd_solid_archive), "rar4", "ppmd-solid")
            ppmd_solid_listing = run(
                args.cli, "list-rar-file", str(ppmd_solid_archive)
            ).stdout
            if (
                "solid=true" not in ppmd_solid_listing
                or "name=second.txt" not in ppmd_solid_listing
                or "method=rar29" not in ppmd_solid_listing
            ):
                raise AssertionError(
                    f"Vort RAR29 PPMd solid metadata mismatch: {ppmd_solid_listing}"
                )
            run(
                args.cli,
                "extract-rar-file",
                str(ppmd_solid_archive),
                "second.txt",
                str(ppmd_solid_output),
                str(1024 * 1024),
            )
            if ppmd_solid_output.read_bytes() != expected_solid:
                raise AssertionError("Vort failed its own solid RAR29 PPMd output")
            writer_solid += 1
            if seven_zip is not None:
                ppmd_solid_reference = temp / "vort-rar29-ppmd-solid-reference"
                ppmd_solid_reference.mkdir()
                run(
                    seven_zip,
                    "x",
                    "-y",
                    f"-o{ppmd_solid_reference}",
                    str(ppmd_solid_archive),
                )
                if (ppmd_solid_reference / "second.txt").read_bytes() != expected_solid:
                    raise AssertionError("7-Zip rejected Vort solid RAR29 PPMd output")
                writer_solid_external += 1

            volume_prefix = temp / "vort-rar50-volume"
            volume_output = temp / "vort-rar50-volume.out"
            run(args.writer, str(volume_prefix), "rar5", "volumes")
            written_volumes = tuple(sorted(temp.glob("vort-rar50-volume.part*.rar")))
            if len(written_volumes) < 2:
                raise AssertionError("Vort volume writer did not split its payload")
            run(
                args.cli,
                "extract-rar-volumes",
                "second.txt",
                str(volume_output),
                str(1024 * 1024),
                *(str(volume) for volume in written_volumes),
            )
            if volume_output.read_bytes() != expected_solid:
                raise AssertionError("Vort failed its own solid volume output")
            writer_volumes += 1
            if seven_zip is not None:
                volume_reference = temp / "vort-rar50-volume-reference"
                volume_reference.mkdir()
                run(
                    seven_zip,
                    "x",
                    "-y",
                    f"-o{volume_reference}",
                    str(written_volumes[0]),
                )
                if (volume_reference / "second.txt").read_bytes() != expected_solid:
                    raise AssertionError("7-Zip rejected Vort solid volume output")
                writer_volumes_external += 1

            encrypted_volume_bytes = bytearray()
            encrypted_volume_state = 0x7261_725F_766F_6C73
            word_mask = (1 << 64) - 1
            for _ in range(4096):
                encrypted_volume_state = (
                    encrypted_volume_state ^ (encrypted_volume_state << 13)
                ) & word_mask
                encrypted_volume_state ^= encrypted_volume_state >> 7
                encrypted_volume_state = (
                    encrypted_volume_state ^ (encrypted_volume_state << 17)
                ) & word_mask
                encrypted_volume_bytes.append(encrypted_volume_state & 0xFF)
            encrypted_volume_payload = bytes(encrypted_volume_bytes)
            for compression in ("stored", "rar50"):
                encrypted_prefix = temp / f"vort-rar5-{compression}-encrypted-volume"
                encrypted_output = temp / f"vort-rar5-{compression}-encrypted-volume.out"
                run(
                    args.writer,
                    str(encrypted_prefix),
                    "rar5",
                    f"encrypted-volumes-{compression}",
                )
                encrypted_volumes = tuple(
                    sorted(temp.glob(f"vort-rar5-{compression}-encrypted-volume.part*.rar"))
                )
                if len(encrypted_volumes) < 2:
                    raise AssertionError(
                        f"Vort encrypted {compression} volume writer did not split"
                    )
                run(
                    args.cli,
                    "extract-rar-volumes",
                    "payload.bin",
                    str(encrypted_output),
                    "8192",
                    "--password=rar-volume-password",
                    *(str(volume) for volume in encrypted_volumes),
                )
                if encrypted_output.read_bytes() != encrypted_volume_payload:
                    raise AssertionError(
                        f"Vort failed encrypted {compression} volume self extraction"
                    )
                writer_encrypted_volumes += 1
                if seven_zip is not None:
                    reference = temp / f"vort-rar5-{compression}-encrypted-volume-reference"
                    reference.mkdir()
                    run(
                        seven_zip,
                        "x",
                        "-y",
                        "-prar-volume-password",
                        f"-o{reference}",
                        str(encrypted_volumes[0]),
                    )
                    if (reference / "payload.bin").read_bytes() != encrypted_volume_payload:
                        raise AssertionError(
                            f"7-Zip rejected Vort encrypted {compression} volumes"
                        )
                    writer_encrypted_volumes_external += 1

            rar4_volume_bytes = bytearray()
            rar4_volume_state = 0x7261_7234_766F_6C73
            word_mask = (1 << 64) - 1
            for _ in range(4096):
                rar4_volume_state = (
                    rar4_volume_state ^ (rar4_volume_state << 13)
                ) & word_mask
                rar4_volume_state ^= rar4_volume_state >> 7
                rar4_volume_state = (
                    rar4_volume_state ^ (rar4_volume_state << 17)
                ) & word_mask
                rar4_volume_bytes.append(rar4_volume_state & 0xFF)
            rar4_volume_payload = bytes(rar4_volume_bytes)
            for compression in ("stored", "rar29"):
                prefix = temp / f"vort-rar4-{compression}-encrypted-volume"
                output = temp / f"vort-rar4-{compression}-encrypted-volume.out"
                run(
                    args.writer,
                    str(prefix),
                    "rar4",
                    f"rar4-encrypted-volumes-{compression}",
                )
                volumes = tuple(
                    sorted(temp.glob(f"vort-rar4-{compression}-encrypted-volume.part*.rar"))
                )
                if len(volumes) < 2:
                    raise AssertionError(
                        f"Vort RAR4 encrypted {compression} writer did not split"
                    )
                run(
                    args.cli,
                    "extract-rar-volumes",
                    "payload.bin",
                    str(output),
                    "8192",
                    "--password=rar4-volume-password",
                    *(str(volume) for volume in volumes),
                )
                if output.read_bytes() != rar4_volume_payload:
                    raise AssertionError(
                        f"Vort failed RAR4 encrypted {compression} volume self extraction"
                    )
                writer_rar4_encrypted_volumes += 1
                if seven_zip is not None:
                    reference = temp / f"vort-rar4-{compression}-encrypted-volume-reference"
                    reference.mkdir()
                    run(
                        seven_zip,
                        "x",
                        "-y",
                        "-prar4-volume-password",
                        f"-o{reference}",
                        str(volumes[0]),
                    )
                    if (reference / "payload.bin").read_bytes() != rar4_volume_payload:
                        raise AssertionError(
                            f"7-Zip rejected Vort RAR4 encrypted {compression} volumes"
                        )
                    writer_rar4_encrypted_volumes_external += 1

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

            rar15_solid = args.legacy_fixtures / "solid_flag_cleared_rar15.rar"
            rar15_solid_entries += compare_archive_entries(
                args.cli,
                seven_zip,
                rar15_solid,
                temp,
                "rar15-solid",
                method="rar15",
            )
            rar20_solid = args.legacy_fixtures / "rar250" / "SOLID.RAR"
            rar20_solid_entries += compare_archive_entries(
                args.cli,
                seven_zip,
                rar20_solid,
                temp,
                "rar20-solid",
                method="rar20",
            )

            rar15_encrypted = args.legacy_fixtures / "rar154" / "readme_154_password.rar"
            rar20_encrypted = args.legacy_fixtures / "rar202" / "comment_psw.rar"
            rar20_encrypted_entries += compare_archive_entries(
                args.cli,
                seven_zip,
                rar20_encrypted,
                temp,
                "rar20-encrypted",
                method="rar20",
                password="password",
            )
            if unrar_tool is not None:
                legacy_solid_unrar_entries += compare_unrar_entries(
                    args.cli,
                    unrar_tool,
                    rar15_solid,
                    temp,
                    "rar15-solid",
                )
                legacy_solid_unrar_entries += compare_unrar_entries(
                    args.cli,
                    unrar_tool,
                    rar20_solid,
                    temp,
                    "rar20-solid",
                )
                rar15_unrar_entries = compare_unrar_entries(
                    args.cli,
                    unrar_tool,
                    rar15_encrypted,
                    temp,
                    "rar15-encrypted",
                    password="password",
                )
                rar15_encrypted_entries += rar15_unrar_entries
                legacy_encrypted_unrar_entries += rar15_unrar_entries
                legacy_encrypted_unrar_entries += compare_unrar_entries(
                    args.cli,
                    unrar_tool,
                    rar20_encrypted,
                    temp,
                    "rar20-encrypted",
                    password="password",
                    accepted_exit_codes=(0, 3),
                )
                mixed_solid = temp / "rar15-rar20-mixed-solid.rar"
                encoded_fixture = (
                    Path(__file__).resolve().parents[2]
                    / "src/rar/testdata/rar15-rar20-mixed-solid.rar.b64"
                )
                mixed_solid.write_bytes(base64.b64decode(encoded_fixture.read_bytes()))
                legacy_mixed_solid_unrar_entries += compare_unrar_entries(
                    args.cli,
                    unrar_tool,
                    mixed_solid,
                    temp,
                    "rar15-rar20-mixed-solid",
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
                "rar29-ppmd-solid",
                method="rar29",
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

            rar50_root = args.legacy_fixtures.parent / "rar50"
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

            filter_writer_cases = (
                (rar50_root / "filter_delta.rar", "delta_4ch_ramp.bin", "delta:4"),
                (rar50_root / "filter_e8.rar", "x86_e8_stream.bin", "e8"),
                (rar50_root / "filter_e8e9.rar", "x86_e8e9_stream.bin", "e8e9"),
                (rar50_root / "filter_arm.rar", "arm_synthetic.bin", "arm"),
            )
            for index, (reference_archive, name, filter_name) in enumerate(filter_writer_cases):
                source_dir = temp / f"rar50-filter-writer-source-{index}"
                source_dir.mkdir()
                run(seven_zip, "x", "-y", f"-o{source_dir}", str(reference_archive))
                source_path = source_dir / name
                written_archive = temp / f"vort-rar50-filter-{index}.rar"
                self_output = temp / f"vort-rar50-filter-{index}.out"
                run(
                    args.cli,
                    "create-rar-file",
                    str(written_archive),
                    name,
                    str(source_path),
                    "rar5",
                    "rar50",
                    filter_name,
                )
                run(
                    args.cli,
                    "extract-rar-file",
                    str(written_archive),
                    name,
                    str(self_output),
                    str(source_path.stat().st_size),
                )
                if self_output.read_bytes() != source_path.read_bytes():
                    raise AssertionError(f"Vort failed its own RAR50 {filter_name} output")
                writer_filtered += 1
                external_dir = temp / f"rar50-filter-writer-external-{index}"
                external_dir.mkdir()
                run(seven_zip, "x", "-y", f"-o{external_dir}", str(written_archive))
                if (external_dir / name).read_bytes() != source_path.read_bytes():
                    raise AssertionError(f"7-Zip rejected Vort RAR50 {filter_name} output")
                writer_filtered_external += 1

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

            rar50_solid_archives = (
                args.legacy_fixtures.parent / "rar50" / "solid.rar",
                args.legacy_fixtures.parent / "rar50" / "wild" / "rarfile_solid.rar",
                args.legacy_fixtures.parent / "rar50" / "wild" / "libarchive_solid.rar",
                args.legacy_fixtures.parent
                / "rar50"
                / "wild"
                / "libarchive_multiple_files_solid.rar",
                args.legacy_fixtures.parent / "rar50" / "wild" / "rarfile_solid_qo.rar",
            )
            for index, archive in enumerate(rar50_solid_archives):
                rar50_solid_entries += compare_archive_entries(
                    args.cli,
                    seven_zip,
                    archive,
                    temp,
                    f"rar50-solid-{index}",
                    method="rar50",
                )

            volume_cases = (
                (
                    tuple(rar50_root / f"multivol.part{index}.rar" for index in range(1, 4)),
                    ("random_4k.bin",),
                    "rar50-volume-compressed",
                ),
                (
                    tuple(rar50_root / f"stored_multivol.part{index}.rar" for index in range(1, 4)),
                    ("random_4k.bin",),
                    "rar50-volume-stored",
                ),
                (
                    tuple(
                        rar50_root / f"solid_multivol.part{index:02}.rar"
                        for index in range(1, 7)
                    ),
                    ("tiny.txt", "bigtext_64k.bin"),
                    "rar50-volume-solid",
                ),
                (
                    tuple(rar50_root / f"multivol_rev.part{index}.rar" for index in range(1, 6)),
                    ("random_16k.bin",),
                    "rar50-volume-recovery",
                ),
            )
            for archives, names, label in volume_cases:
                rar50_volume_entries += compare_volume_entries(
                    args.cli,
                    seven_zip,
                    archives,
                    names,
                    temp,
                    label,
                )
                rar50_volume_sets += 1

            missing_volume = run(
                args.cli,
                "extract-rar-volumes",
                "random_4k.bin",
                str(temp / "rar50-missing-volume.out"),
                "10000",
                str(rar50_root / "multivol.part1.rar"),
                str(rar50_root / "multivol.part3.rar"),
                check=False,
            )
            if missing_volume.returncode == 0 or "InvalidRarVolumeSet" not in missing_volume.stderr:
                raise AssertionError("Vort accepted a RAR50 set with a missing volume")

            reversed_volumes = run(
                args.cli,
                "extract-rar-volumes",
                "random_4k.bin",
                str(temp / "rar50-reversed-volumes.out"),
                "10000",
                str(rar50_root / "multivol.part2.rar"),
                str(rar50_root / "multivol.part1.rar"),
                check=False,
            )
            if reversed_volumes.returncode == 0 or "InvalidRarVolumeSet" not in reversed_volumes.stderr:
                raise AssertionError("Vort accepted reversed RAR50 volumes")

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

            failed = run(
                args.cli,
                "extract-rar-file",
                str(rar15_encrypted),
                "README.md",
                str(temp / "encrypted.out"),
                check=False,
            )
            if failed.returncode == 0 or "RarPasswordRequired" not in failed.stderr:
                raise AssertionError("Vort accepted encrypted RAR15 data without a password")

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
        f"writer_compressed={writer_compressed} "
        f"writer_compressed_external={writer_compressed_external} "
        f"writer_ppmd={writer_ppmd} "
        f"writer_ppmd_external={writer_ppmd_external} "
        f"writer_ppmd_filtered={writer_ppmd_filtered} "
        f"writer_ppmd_filtered_external={writer_ppmd_filtered_external} "
        f"writer_ppmd_filtered_unrar={writer_ppmd_filtered_unrar} "
        f"writer_ppmd_filtered_solid={writer_ppmd_filtered_solid} "
        f"writer_ppmd_filtered_solid_external={writer_ppmd_filtered_solid_external} "
        f"writer_ppmd_filtered_solid_unrar={writer_ppmd_filtered_solid_unrar} "
        f"writer_ppmd_filtered_encrypted={writer_ppmd_filtered_encrypted} "
        f"writer_ppmd_filtered_encrypted_external={writer_ppmd_filtered_encrypted_external} "
        f"writer_ppmd_filtered_encrypted_unrar={writer_ppmd_filtered_encrypted_unrar} "
        f"writer_rar29_filtered_solid={writer_rar29_filtered_solid} "
        f"writer_rar29_filtered_solid_external={writer_rar29_filtered_solid_external} "
        f"writer_rar29_filtered_solid_unrar={writer_rar29_filtered_solid_unrar} "
        f"writer_rar29_filtered_solid_encrypted={writer_rar29_filtered_solid_encrypted} "
        f"writer_rar29_filtered_solid_encrypted_external={writer_rar29_filtered_solid_encrypted_external} "
        f"writer_rar29_filtered_solid_encrypted_unrar={writer_rar29_filtered_solid_encrypted_unrar} "
        f"writer_filtered={writer_filtered} "
        f"writer_filtered_external={writer_filtered_external} "
        f"writer_solid={writer_solid} "
        f"writer_solid_external={writer_solid_external} "
        f"writer_volumes={writer_volumes} "
        f"writer_volumes_external={writer_volumes_external} "
        f"writer_encrypted={writer_encrypted} "
        f"writer_encrypted_external={writer_encrypted_external} "
        f"reference_encrypted={reference_encrypted} "
        f"writer_encrypted_headers={writer_encrypted_headers} "
        f"writer_encrypted_headers_external={writer_encrypted_headers_external} "
        f"reference_encrypted_headers={reference_encrypted_headers} "
        f"writer_encrypted_volumes={writer_encrypted_volumes} "
        f"writer_encrypted_volumes_external={writer_encrypted_volumes_external} "
        f"reference_encrypted_volumes={reference_encrypted_volumes} "
        f"writer_rar4_encrypted={writer_rar4_encrypted} "
        f"writer_rar4_encrypted_external={writer_rar4_encrypted_external} "
        f"reference_rar4_encrypted={reference_rar4_encrypted} "
        f"writer_rar4_encrypted_headers={writer_rar4_encrypted_headers} "
        f"writer_rar4_encrypted_headers_external={writer_rar4_encrypted_headers_external} "
        f"reference_rar4_encrypted_headers={reference_rar4_encrypted_headers} "
        f"writer_rar4_encrypted_volumes={writer_rar4_encrypted_volumes} "
        f"writer_rar4_encrypted_volumes_external={writer_rar4_encrypted_volumes_external} "
        f"reference_rar4_encrypted_volumes={reference_rar4_encrypted_volumes} "
        f"writer_rar4_unicode={writer_rar4_unicode} "
        f"writer_rar4_unicode_external={writer_rar4_unicode_external} "
        f"writer_redirections={writer_redirections} "
        f"writer_redirections_external={writer_redirections_external} "
        f"writer_comments={writer_comments} "
        f"writer_comments_external={writer_comments_external} "
        f"writer_comment_volumes={writer_comment_volumes} "
        f"writer_comment_volumes_external={writer_comment_volumes_external} "
        f"reference_comments={reference_comments} "
        f"writer_rar4_comments={writer_rar4_comments} "
        f"writer_rar4_comments_external={writer_rar4_comments_external} "
        f"writer_rar4_comment_volumes={writer_rar4_comment_volumes} "
        f"writer_rar4_comment_volumes_external={writer_rar4_comment_volumes_external} "
        f"reference_rar4_comments={reference_rar4_comments} "
        f"reference_rar4_unicode={reference_rar4_unicode} "
        f"reference_stored={reference_stored} reference_compressed={reference_compressed} "
        f"reference_compressed_decoded={reference_compressed_decoded} "
        f"fixture_cases={fixture_cases} rar15_entries={rar15_entries} "
        f"rar20_entries={rar20_entries} rar29_entries={rar29_entries} "
        f"rar15_solid_entries={rar15_solid_entries} "
        f"rar20_solid_entries={rar20_solid_entries} "
        f"legacy_solid_unrar_entries={legacy_solid_unrar_entries} "
        f"legacy_mixed_solid_unrar_entries={legacy_mixed_solid_unrar_entries} "
        f"rar15_encrypted_entries={rar15_encrypted_entries} "
        f"rar20_encrypted_entries={rar20_encrypted_entries} "
        f"legacy_encrypted_unrar_entries={legacy_encrypted_unrar_entries} "
        f"rar29_ppmd_entries={rar29_ppmd_entries} "
        f"rar29_vm_entries={rar29_vm_entries} "
        f"rar50_entries={rar50_entries} "
        f"rar50_multiblock={rar50_multiblock} "
        f"rar50_solid_entries={rar50_solid_entries} "
        f"rar50_volume_sets={rar50_volume_sets} "
        f"rar50_volume_entries={rar50_volume_entries} "
        f"header_crc=True data_crc=True sfx=True"
    )


if __name__ == "__main__":
    main()
