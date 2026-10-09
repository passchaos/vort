#!/usr/bin/env python3
"""Bidirectional TAR and tarball compatibility tests."""

from __future__ import annotations

import argparse
import io
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path


def run(program: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(program), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def add_bytes(archive: tarfile.TarFile, name: str, payload: bytes, mode: int = 0o644) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(payload)
    info.mode = mode
    info.mtime = 0
    archive.addfile(info, io.BytesIO(payload))


def python_archive(format_id: int) -> tuple[bytes, dict[str, bytes]]:
    payloads = {
        "plain.txt": b"Python TAR payload\n",
        "utf8-目录/数据.txt": "Python TAR UTF-8\n".encode(),
        "nested/" + "long-component-" * 12 + "file.txt": b"Python long path\n",
    }
    sink = io.BytesIO()
    with tarfile.open(fileobj=sink, mode="w", format=format_id) as archive:
        for name, payload in payloads.items():
            add_bytes(archive, name, payload)
        directory = tarfile.TarInfo("empty/")
        directory.type = tarfile.DIRTYPE
        directory.mode = 0o755
        directory.mtime = 0
        archive.addfile(directory)
        link = tarfile.TarInfo("link")
        link.type = tarfile.SYMTYPE
        link.linkname = next(name for name in payloads if len(name) > 100)
        link.mtime = 0
        archive.addfile(link)
    return sink.getvalue(), payloads


def validate_with_vort(cli: Path, archive_path: Path, payloads: dict[str, bytes]) -> None:
    listing = run(cli, "list-tar-file", str(archive_path)).stdout
    if "tar_entries=5" not in listing:
        raise AssertionError(f"unexpected TAR listing: {listing}")
    for index, (name, payload) in enumerate(payloads.items()):
        if f"name={name}" not in listing:
            raise AssertionError(f"TAR listing omitted {name!r}")
        output = archive_path.with_name(f"{archive_path.stem}-{index}.out")
        run(cli, "extract-tar-file", str(archive_path), name, str(output))
        if output.read_bytes() != payload:
            raise AssertionError(f"Vort TAR extraction mismatch for {name!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--lzip", type=Path)
    parser.add_argument("--lzop", type=Path)
    args = parser.parse_args()
    compressions = ("none", "gzip", "bzip2", "xz", "lzip", "zstd", "lzop")

    with tempfile.TemporaryDirectory(prefix="vort-tar-diff-") as temp_text:
        temp = Path(temp_text)
        for format_name, format_id in (("pax", tarfile.PAX_FORMAT), ("gnu", tarfile.GNU_FORMAT)):
            raw, payloads = python_archive(format_id)
            path = temp / f"python-{format_name}.tar"
            path.write_bytes(raw)
            validate_with_vort(args.cli, path, payloads)

        first = temp / "vort-first.tar"
        second = temp / "vort-second.tar"
        run(args.writer, str(first))
        run(args.writer, str(second))
        if first.read_bytes() != second.read_bytes():
            raise AssertionError("Vort TAR output is not deterministic")
        with tarfile.open(first, mode="r:") as archive:
            names = archive.getnames()
            if len(names) != 5:
                raise AssertionError(f"unexpected Vort TAR entries: {names!r}")
            if archive.extractfile("plain.txt").read() != b"Vort TAR payload\n":
                raise AssertionError("Python could not extract Vort TAR payload")
            if archive.getmember("link").linkname != "nested/" + "long-component-" * 12 + "file.txt":
                raise AssertionError("Vort TAR long link mismatch")

        payload = (b"tarball compression matrix\n" * 2048) + bytes(range(256))
        source = temp / "payload.bin"
        source.write_bytes(payload)
        zstd_tool = shutil.which("zstd")
        lzip_tool = str(args.lzip) if args.lzip else shutil.which("lzip")
        lzop_tool = str(args.lzop) if args.lzop else shutil.which("lzop")
        for compression in compressions:
            archive_path = temp / f"vort.tar.{compression}"
            output = temp / f"vort-{compression}.out"
            run(args.cli, "create-tar-file", str(archive_path), "payload.bin", str(source), compression)
            run(args.cli, "extract-tar-file", str(archive_path), "payload.bin", str(output), "1048576")
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort tarball round trip mismatch for {compression}")
            if compression == "zstd":
                if zstd_tool is None:
                    raise AssertionError("zstd CLI is required for tar.zst differential")
                raw = subprocess.run(
                    [zstd_tool, "-q", "-d", "-c", str(archive_path)],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError("Python could not read Vort tar.zst")
            elif compression in {"lzip", "lzop"}:
                tool = lzip_tool if compression == "lzip" else lzop_tool
                if tool is not None:
                    raw = subprocess.run(
                        [tool, "-dc", str(archive_path)],
                        check=True,
                        stdout=subprocess.PIPE,
                    ).stdout
                    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                        if archive.extractfile("payload.bin").read() != payload:
                            raise AssertionError(f"Python could not read Vort tar.{compression}")
            else:
                mode = "r:" if compression == "none" else {"gzip": "r:gz", "bzip2": "r:bz2", "xz": "r:xz"}[compression]
                with tarfile.open(archive_path, mode=mode) as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError(f"Python could not read Vort tarball {compression}")

        python_tar, payloads = python_archive(tarfile.PAX_FORMAT)
        compressed_inputs = {
            "none": python_tar,
            "gzip": __import__("gzip").compress(python_tar, mtime=0),
            "bzip2": __import__("bz2").compress(python_tar),
            "xz": __import__("lzma").compress(python_tar),
        }
        if zstd_tool is not None:
            compressed_inputs["zstd"] = subprocess.run(
                [zstd_tool, "-q", "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lzip_tool is not None:
            compressed_inputs["lzip"] = subprocess.run(
                [lzip_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lzop_tool is not None:
            compressed_inputs["lzop"] = subprocess.run(
                [lzop_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        for compression, data in compressed_inputs.items():
            path = temp / f"python.tar.{compression}"
            path.write_bytes(data)
            validate_with_vort(args.cli, path, payloads)

    print(f"tar_diff=ok raw_formats=2 compressions={len(compressions)} entries=5")


if __name__ == "__main__":
    main()
