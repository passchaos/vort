"""Focused interoperability matrix for Vort-authored RAR29 VM filter combinations."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import subprocess


@dataclass(frozen=True)
class Counts:
    ordinary: int = 0
    ordinary_7zip: int = 0
    ordinary_unrar: int = 0
    solid: int = 0
    solid_7zip: int = 0
    solid_unrar: int = 0
    encrypted: int = 0
    encrypted_7zip: int = 0
    encrypted_unrar: int = 0
    lz_solid: int = 0
    lz_solid_7zip: int = 0
    lz_solid_unrar: int = 0
    lz_solid_encrypted: int = 0
    lz_solid_encrypted_7zip: int = 0
    lz_solid_encrypted_unrar: int = 0


def run_matrix(
    cli: Path,
    writer: Path | None,
    seven_zip: Path | None,
    unrar: Path | None,
    root: Path,
    source: Path,
    expected: bytes,
    password: str,
    salt_hex: str,
) -> Counts:
    ordinary = ordinary_7zip = ordinary_unrar = 0
    for index, filter_name in enumerate(
        ("delta:4", "e8", "e8e9", "itanium", "rgb:12:1", "audio:2")
    ):
        archive = root / f"vort-rar29-ppmd-filter-{index}.rar"
        _run(
            cli,
            "create-rar-file",
            str(archive),
            "payload.bin",
            str(source),
            "rar4",
            "rar29-ppmd",
            filter_name,
        )
        _expect_cli(cli, archive, expected, root / f"ppmd-filter-{index}.out")
        ordinary += 1
        if seven_zip is not None:
            _expect_7zip(
                seven_zip,
                archive,
                expected,
                root / f"ppmd-filter-7z-{index}",
            )
            ordinary_7zip += 1
        if unrar is not None:
            _expect_unrar(
                unrar,
                archive,
                expected,
                root / f"ppmd-filter-unrar-{index}",
            )
            ordinary_unrar += 1

    encrypted_archive = root / "vort-rar29-ppmd-filtered-encrypted.rar"
    _run(
        cli,
        "create-rar-file",
        str(encrypted_archive),
        "payload.bin",
        str(source),
        "rar4",
        "rar29-ppmd",
        "delta:4",
        "non-solid",
        password,
        salt_hex,
    )
    _expect_cli(
        cli,
        encrypted_archive,
        expected,
        root / "ppmd-filter-encrypted.out",
        password,
    )
    encrypted = 1
    encrypted_7zip = encrypted_unrar = 0
    if seven_zip is not None:
        _expect_7zip(
            seven_zip,
            encrypted_archive,
            expected,
            root / "ppmd-filter-encrypted-7z",
            password,
        )
        encrypted_7zip = 1
    if unrar is not None:
        _expect_unrar(
            unrar,
            encrypted_archive,
            expected,
            root / "ppmd-filter-encrypted-unrar",
            password,
        )
        encrypted_unrar = 1

    solid = solid_7zip = solid_unrar = 0
    lz_solid = lz_solid_7zip = lz_solid_unrar = 0
    lz_solid_encrypted = lz_solid_encrypted_7zip = lz_solid_encrypted_unrar = 0
    if writer is not None:
        solid_expected = b"solid history payload alpha beta gamma\n" * 128
        solid_archive = root / "vort-rar29-ppmd-filtered-solid.rar"
        _run(writer, str(solid_archive), "rar4", "ppmd-filtered-solid")
        _expect_cli(
            cli,
            solid_archive,
            solid_expected,
            root / "ppmd-filter-solid.out",
            entry="second.txt",
        )
        solid = 1
        if seven_zip is not None:
            _expect_7zip(
                seven_zip,
                solid_archive,
                solid_expected,
                root / "ppmd-filter-solid-7z",
                entry="second.txt",
            )
            solid_7zip = 1
        if unrar is not None:
            _expect_unrar(
                unrar,
                solid_archive,
                solid_expected,
                root / "ppmd-filter-solid-unrar",
                entry="second.txt",
            )
            solid_unrar = 1

        for mode, case_password in (
            ("rar29-filtered-solid", None),
            ("rar29-filtered-solid-encrypted", "rar29-filtered-solid-secret"),
        ):
            archive = root / f"vort-{mode}.rar"
            _run(writer, str(archive), "rar4", mode)
            _expect_cli(
                cli,
                archive,
                solid_expected,
                root / f"{mode}.out",
                case_password,
                entry="second.txt",
            )
            if case_password is None:
                lz_solid = 1
            else:
                lz_solid_encrypted = 1
            if seven_zip is not None:
                _expect_7zip(
                    seven_zip,
                    archive,
                    solid_expected,
                    root / f"{mode}-7z",
                    case_password,
                    entry="second.txt",
                )
                if case_password is None:
                    lz_solid_7zip = 1
                else:
                    lz_solid_encrypted_7zip = 1
            if unrar is not None:
                _expect_unrar(
                    unrar,
                    archive,
                    solid_expected,
                    root / f"{mode}-unrar",
                    case_password,
                    entry="second.txt",
                )
                if case_password is None:
                    lz_solid_unrar = 1
                else:
                    lz_solid_encrypted_unrar = 1

    return Counts(
        ordinary=ordinary,
        ordinary_7zip=ordinary_7zip,
        ordinary_unrar=ordinary_unrar,
        solid=solid,
        solid_7zip=solid_7zip,
        solid_unrar=solid_unrar,
        encrypted=encrypted,
        encrypted_7zip=encrypted_7zip,
        encrypted_unrar=encrypted_unrar,
        lz_solid=lz_solid,
        lz_solid_7zip=lz_solid_7zip,
        lz_solid_unrar=lz_solid_unrar,
        lz_solid_encrypted=lz_solid_encrypted,
        lz_solid_encrypted_7zip=lz_solid_encrypted_7zip,
        lz_solid_encrypted_unrar=lz_solid_encrypted_unrar,
    )


def _run(
    program: Path | str,
    *args: str,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _expect_cli(
    cli: Path,
    archive: Path,
    expected: bytes,
    output: Path,
    password: str | None = None,
    entry: str = "payload.bin",
) -> None:
    password_arg = (password,) if password is not None else ()
    _run(
        cli,
        "extract-rar-file",
        str(archive),
        entry,
        str(output),
        str(max(len(expected), 1)),
        *password_arg,
    )
    if output.read_bytes() != expected:
        raise AssertionError(f"Vort failed filtered PPMd output: {archive.name}:{entry}")


def _expect_7zip(
    seven_zip: Path,
    archive: Path,
    expected: bytes,
    output_dir: Path,
    password: str | None = None,
    entry: str = "payload.bin",
) -> None:
    output_dir.mkdir()
    password_arg = (f"-p{password}",) if password is not None else ()
    _run(
        seven_zip,
        "x",
        "-y",
        *password_arg,
        f"-o{output_dir}",
        str(archive),
    )
    if (output_dir / entry).read_bytes() != expected:
        raise AssertionError(f"7-Zip failed filtered PPMd output: {archive.name}:{entry}")


def _expect_unrar(
    unrar: Path,
    archive: Path,
    expected: bytes,
    output_dir: Path,
    password: str | None = None,
    entry: str = "payload.bin",
) -> None:
    output_dir.mkdir()
    password_arg = f"-p{password}" if password is not None else "-p-"
    _run(
        unrar,
        "x",
        "-o+",
        "-idq",
        password_arg,
        str(archive),
        f"{output_dir}/",
    )
    if (output_dir / entry).read_bytes() != expected:
        raise AssertionError(f"unrar failed filtered PPMd output: {archive.name}:{entry}")
