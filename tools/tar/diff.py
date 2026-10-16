#!/usr/bin/env python3
"""Bidirectional TAR and tarball compatibility tests."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import io
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path


def brotli_compress(data: bytes) -> bytes:
    try:
        import brotli

        return brotli.compress(data, quality=5)
    except ImportError:
        library_path = ctypes.util.find_library("brotlienc")
        if library_path is None:
            raise AssertionError("Python brotli or libbrotlienc is required")
        library = ctypes.CDLL(library_path)
        maximum_size = library.BrotliEncoderMaxCompressedSize
        maximum_size.argtypes = [ctypes.c_size_t]
        maximum_size.restype = ctypes.c_size_t
        compress = library.BrotliEncoderCompress
        compress.argtypes = [
            ctypes.c_int,
            ctypes.c_int,
            ctypes.c_int,
            ctypes.c_size_t,
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_size_t),
            ctypes.c_void_p,
        ]
        compress.restype = ctypes.c_int
        source = ctypes.create_string_buffer(data, max(1, len(data)))
        bound = maximum_size(len(data))
        output = ctypes.create_string_buffer(max(1, bound))
        output_size = ctypes.c_size_t(bound)
        if compress(5, 22, 0, len(data), source, ctypes.byref(output_size), output) != 1:
            raise AssertionError("libbrotli could not compress TAR fixture")
        return output.raw[: output_size.value]


def brotli_decompress(data: bytes, max_output_len: int) -> bytes:
    try:
        import brotli

        decoded = brotli.decompress(data)
        if len(decoded) > max_output_len:
            raise AssertionError("Brotli TAR fixture exceeded its output limit")
        return decoded
    except ImportError:
        library_path = ctypes.util.find_library("brotlidec")
        if library_path is None:
            raise AssertionError("Python brotli or libbrotlidec is required")
        library = ctypes.CDLL(library_path)
        decompress = library.BrotliDecoderDecompress
        decompress.argtypes = [
            ctypes.c_size_t,
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_size_t),
            ctypes.c_void_p,
        ]
        decompress.restype = ctypes.c_int
        source = ctypes.create_string_buffer(data, max(1, len(data)))
        output = ctypes.create_string_buffer(max_output_len)
        output_size = ctypes.c_size_t(max_output_len)
        if decompress(len(data), source, ctypes.byref(output_size), output) != 1:
            raise AssertionError("libbrotli could not decompress TAR fixture")
        return output.raw[: output_size.value]


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


def validate_with_vort(
    cli: Path,
    archive_path: Path,
    payloads: dict[str, bytes],
    incremental_reader: Path | None = None,
) -> int:
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
        if incremental_reader is not None:
            for pattern in ("one", "micro"):
                run(incremental_reader, str(archive_path), name, str(output), pattern)
    return len(payloads) if incremental_reader is not None else 0


def sparse_payload() -> bytes:
    payload = bytearray(1024 * 1024)
    payload[0:4] = b"HEAD"
    payload[524288:524294] = b"MIDDLE"
    payload[-4:] = b"TAIL"
    return bytes(payload)


def decode_streaming_tarball(
    compression: str,
    archive_path: Path,
    zstd_tool: str | None,
    lz4_tool: str | None,
    lzf_tool: str | None,
    lzip_tool: str | None,
    lzop_tool: str | None,
    uncompress_tool: str | None,
) -> bytes | None:
    encoded = archive_path.read_bytes()
    if compression == "gzip":
        return __import__("gzip").decompress(encoded)
    if compression == "bzip2":
        return __import__("bz2").decompress(encoded)
    if compression == "brotli":
        return brotli_decompress(encoded, 512 * 1024 * 1024)
    if compression == "compress-z":
        if uncompress_tool is None:
            return None
        return subprocess.run(
            [uncompress_tool, "-c", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "lzma":
        return __import__("lzma").decompress(
            encoded, format=__import__("lzma").FORMAT_ALONE
        )
    if compression == "xz":
        return __import__("lzma").decompress(encoded)
    if compression == "lz4":
        if lz4_tool is None:
            raise AssertionError("lz4 CLI is required for incremental tar.lz4 writer")
        return subprocess.run(
            [lz4_tool, "-q", "-d", "-c", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "lz4-legacy":
        if lz4_tool is None:
            raise AssertionError("lz4 CLI is required for incremental legacy LZ4 writer")
        return subprocess.run(
            [lz4_tool, "-q", "-d", "-c", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "lzf":
        if lzf_tool is None:
            return None
        return subprocess.run(
            [lzf_tool, "-d"],
            input=encoded,
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "lzip":
        if lzip_tool is None:
            return None
        return subprocess.run(
            [lzip_tool, "-dc", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "zstd":
        if zstd_tool is None:
            raise AssertionError("zstd CLI is required for incremental tar.zst writer")
        return subprocess.run(
            [zstd_tool, "-q", "-d", "-c", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    if compression == "lzop":
        if lzop_tool is None:
            return None
        return subprocess.run(
            [lzop_tool, "-dc", str(archive_path)],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
    raise AssertionError(f"unsupported streaming tarball compression: {compression}")


def validate_gnu_sparse_with_vort(
    cli: Path,
    incremental_reader: Path,
    tar_tool: str,
    temp: Path,
) -> int:
    source = temp / "gnu-sparse.bin"
    with source.open("wb") as stream:
        stream.truncate(1024 * 1024)
        stream.seek(0)
        stream.write(b"HEAD")
        stream.seek(524288)
        stream.write(b"MIDDLE")
        stream.seek(1048572)
        stream.write(b"TAIL")
    expected = sparse_payload()
    cases = 0
    for version in ("0.0", "0.1", "1.0"):
        archive_path = temp / f"gnu-sparse-{version}.tar"
        output = temp / f"gnu-sparse-{version}.out"
        subprocess.run(
            [
                tar_tool,
                "--format=pax",
                "--sparse",
                f"--sparse-version={version}",
                "-C",
                str(temp),
                "-cf",
                str(archive_path),
                source.name,
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        listing = run(cli, "list-tar-file", str(archive_path)).stdout
        expected_format = version.replace(".", "_")
        if (
            "size=1048576" not in listing
            or f"sparse=pax_{expected_format}" not in listing
            or "extents=4" not in listing
        ):
            raise AssertionError(
                f"Vort sparse {version} metadata mismatch: {listing}"
            )
        run(
            cli,
            "extract-tar-file",
            str(archive_path),
            source.name,
            str(output),
            str(2 * 1024 * 1024),
        )
        if output.read_bytes() != expected:
            raise AssertionError(f"Vort could not extract GNU sparse {version}")
        for pattern in ("one", "micro"):
            run(incremental_reader, str(archive_path), source.name, str(output), pattern)
        cases += 1

    oldgnu_archive = temp / "gnu-sparse-oldgnu.tar"
    oldgnu_output = temp / "gnu-sparse-oldgnu.out"
    subprocess.run(
        [
            tar_tool,
            "--format=gnu",
            "--sparse",
            "-C",
            str(temp),
            "-cf",
            str(oldgnu_archive),
            source.name,
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    listing = run(cli, "list-tar-file", str(oldgnu_archive)).stdout
    if "sparse=gnu_old" not in listing or "size=1048576" not in listing:
        raise AssertionError(f"Vort old GNU sparse metadata mismatch: {listing}")
    run(
        cli,
        "extract-tar-file",
        str(oldgnu_archive),
        source.name,
        str(oldgnu_output),
        str(2 * 1024 * 1024),
    )
    if oldgnu_output.read_bytes() != expected:
        raise AssertionError("Vort could not extract old GNU sparse archive")
    for pattern in ("one", "micro"):
        run(
            incremental_reader,
            str(oldgnu_archive),
            source.name,
            str(oldgnu_output),
            pattern,
        )
    cases += 1

    many_source = temp / "gnu-many-sparse.bin"
    many_expected = bytearray(2 * 1024 * 1024)
    with many_source.open("wb") as stream:
        stream.truncate(len(many_expected))
        for index in range(25):
            offset = index * 65536
            value = bytes([65 + index % 26])
            stream.seek(offset)
            stream.write(value)
            many_expected[offset] = value[0]
    many_archive = temp / "gnu-many-sparse-oldgnu.tar"
    many_output = temp / "gnu-many-sparse-oldgnu.out"
    subprocess.run(
        [
            tar_tool,
            "--format=gnu",
            "--sparse",
            "-C",
            str(temp),
            "-cf",
            str(many_archive),
            many_source.name,
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    run(
        cli,
        "extract-tar-file",
        str(many_archive),
        many_source.name,
        str(many_output),
        str(3 * 1024 * 1024),
    )
    if many_output.read_bytes() != bytes(many_expected):
        raise AssertionError("Vort could not extract chained old GNU sparse headers")
    for pattern in ("one", "micro"):
        run(
            incremental_reader,
            str(many_archive),
            many_source.name,
            str(many_output),
            pattern,
        )
    cases += 1
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--incremental-writer", required=True, type=Path)
    parser.add_argument("--incremental-reader", required=True, type=Path)
    parser.add_argument("--incremental-compressed-reader", required=True, type=Path)
    parser.add_argument("--incremental-auto-reader", required=True, type=Path)
    parser.add_argument("--incremental-compressed-writer", required=True, type=Path)
    parser.add_argument("--lzip", type=Path)
    parser.add_argument("--lzf", type=Path)
    parser.add_argument("--lzop", type=Path)
    args = parser.parse_args()
    tar_tool = shutil.which("tar")
    if tar_tool is None:
        raise AssertionError("GNU tar is required for sparse TAR differential")
    compressions = (
        "none",
        "gzip",
        "bzip2",
        "brotli",
        "compress-z",
        "lzma",
        "xz",
        "lz4",
        "lzip",
        "lzf",
        "zstd",
        "lzop",
    )

    with tempfile.TemporaryDirectory(prefix="vort-tar-diff-") as temp_text:
        temp = Path(temp_text)
        incremental_reader_cases = 0
        incremental_auto_reader_cases = 0
        for format_name, format_id in (("pax", tarfile.PAX_FORMAT), ("gnu", tarfile.GNU_FORMAT)):
            raw, payloads = python_archive(format_id)
            path = temp / f"python-{format_name}.tar"
            path.write_bytes(raw)
            incremental_reader_cases += validate_with_vort(
                args.cli, path, payloads, args.incremental_reader
            )
            name, payload = next(iter(payloads.items()))
            expected_path = temp / f"python-{format_name}-auto-expected.bin"
            expected_path.write_bytes(payload)
            for pattern in ("one", "micro"):
                run(
                    args.incremental_auto_reader,
                    str(path),
                    name,
                    str(expected_path),
                    "raw_tar",
                    pattern,
                )
            incremental_auto_reader_cases += 1
        gnu_sparse_reader_cases = validate_gnu_sparse_with_vort(
            args.cli, args.incremental_reader, tar_tool, temp
        )
        incremental_reader_cases += gnu_sparse_reader_cases

        first = temp / "vort-first.tar"
        second = temp / "vort-second.tar"
        run(args.writer, str(first))
        run(args.writer, str(second))
        if first.read_bytes() != second.read_bytes():
            raise AssertionError("Vort TAR output is not deterministic")
        incremental_one = temp / "vort-incremental-one.tar"
        incremental_micro = temp / "vort-incremental-micro.tar"
        run(args.incremental_writer, str(incremental_one), "one")
        run(args.incremental_writer, str(incremental_micro), "micro")
        if incremental_one.read_bytes() != incremental_micro.read_bytes():
            raise AssertionError("incremental TAR output changed with scheduling")
        if incremental_one.read_bytes() != first.read_bytes():
            raise AssertionError("incremental TAR output differs from one-shot writer")
        plain_expected = temp / "vort-plain-expected.bin"
        plain_expected.write_bytes(b"Vort TAR payload\n")
        sparse_expected = temp / "vort-sparse-expected.bin"
        sparse_expected.write_bytes(sparse_payload())
        for name, expected_path in (
            ("plain.txt", plain_expected),
            ("images/sparse.bin", sparse_expected),
            ("images/sparse-oldgnu.bin", sparse_expected),
        ):
            for pattern in ("one", "micro"):
                run(
                    args.incremental_reader,
                    str(first),
                    name,
                    str(expected_path),
                    pattern,
                )
            incremental_reader_cases += 1
        with tarfile.open(first, mode="r:") as archive:
            names = archive.getnames()
            if len(names) != 7:
                raise AssertionError(f"unexpected Vort TAR entries: {names!r}")
            if archive.extractfile("plain.txt").read() != b"Vort TAR payload\n":
                raise AssertionError("Python could not extract Vort TAR payload")
            if archive.getmember("link").linkname != "nested/" + "long-component-" * 12 + "file.txt":
                raise AssertionError("Vort TAR long link mismatch")
            for sparse_name in ("images/sparse.bin", "images/sparse-oldgnu.bin"):
                sparse = archive.getmember(sparse_name)
                if sparse.sparse is None or archive.extractfile(sparse).read() != sparse_payload():
                    raise AssertionError(
                        f"Python could not extract Vort sparse TAR payload {sparse_name!r}"
                    )
        for sparse_name in ("images/sparse.bin", "images/sparse-oldgnu.bin"):
            gnu_sparse = subprocess.run(
                [tar_tool, "-xOf", str(first), sparse_name],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            if gnu_sparse != sparse_payload():
                raise AssertionError(
                    f"GNU tar could not extract Vort sparse TAR payload {sparse_name!r}"
                )

        payload = (b"tarball compression matrix\n" * 2048) + bytes(range(256))
        source = temp / "payload.bin"
        source.write_bytes(payload)
        zstd_tool = shutil.which("zstd")
        lz4_tool = shutil.which("lz4")
        lzip_tool = str(args.lzip) if args.lzip else shutil.which("lzip")
        lzf_tool = str(args.lzf) if args.lzf else shutil.which("lzf")
        lzop_tool = str(args.lzop) if args.lzop else shutil.which("lzop")
        uncompress_tool = shutil.which("uncompress")
        compress_tool = shutil.which("compress")
        streaming_compressions = {
            "gzip",
            "bzip2",
            "brotli",
            "compress-z",
            "lzma",
            "xz",
            "lz4",
            "lzf",
            "lzip",
            "zstd",
            "lzop",
        }
        streaming_writer_compressions = {
            "gzip",
            "bzip2",
            "brotli",
            "lzma",
            "xz",
            "lz4",
            "zstd",
            "lzop",
            "lzf",
            "lz4-legacy",
            "lzip",
            "compress-z",
        }
        auto_formats = {
            "none": "raw_tar",
            "gzip": "gzip",
            "bzip2": "bzip2",
            "brotli": "brotli",
            "compress-z": "compress_z",
            "lzma": "lzma",
            "xz": "xz",
            "lz4": "lz4",
            "lzip": "lzip",
            "lzf": "lzf",
            "zstd": "zstandard",
            "lzop": "lzop",
            "lz4-legacy": "lz4_legacy",
        }
        incremental_compressed_reader_cases = 0
        incremental_compressed_writer_cases = 0
        incremental_compressed_writer_external = 0
        for compression in compressions:
            archive_path = temp / f"vort.tar.{compression}"
            output = temp / f"vort-{compression}.out"
            run(args.cli, "create-tar-file", str(archive_path), "payload.bin", str(source), compression)
            run(args.cli, "extract-tar-file", str(archive_path), "payload.bin", str(output), "1048576")
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort tarball round trip mismatch for {compression}")
            if compression in streaming_compressions:
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_compressed_reader,
                        str(archive_path),
                        "payload.bin",
                        str(source),
                        compression,
                        pattern,
                    )
                incremental_compressed_reader_cases += 1
            for pattern in ("one", "micro"):
                run(
                    args.incremental_auto_reader,
                    str(archive_path),
                    "payload.bin",
                    str(source),
                    auto_formats[compression],
                    pattern,
                )
            incremental_auto_reader_cases += 1

            if compression == "brotli":
                raw = brotli_decompress(archive_path.read_bytes(), 16 * 1024 * 1024)
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError("Python/libbrotli could not read Vort tar.br")
            elif compression == "zstd":
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
            elif compression == "lz4":
                if lz4_tool is None:
                    raise AssertionError("lz4 CLI is required for tar.lz4 differential")
                raw = subprocess.run(
                    [lz4_tool, "-q", "-d", "-c", str(archive_path)],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError("Python could not read Vort tar.lz4")
            elif compression == "compress-z":
                if uncompress_tool is None:
                    raise AssertionError("uncompress is required for tar.Z differential")
                raw = subprocess.run(
                    [uncompress_tool, "-c", str(archive_path)],
                    check=True,
                    stdout=subprocess.PIPE,
                ).stdout
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError("Python could not read Vort tar.Z")
            elif compression == "lzma":
                raw = __import__("lzma").decompress(
                    archive_path.read_bytes(), format=__import__("lzma").FORMAT_ALONE
                )
                with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError("Python could not read Vort tar.lzma")
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
            elif compression == "lzf":
                if lzf_tool is not None:
                    raw = subprocess.run(
                        [lzf_tool, "-d"],
                        input=archive_path.read_bytes(),
                        check=True,
                        stdout=subprocess.PIPE,
                    ).stdout
                    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as archive:
                        if archive.extractfile("payload.bin").read() != payload:
                            raise AssertionError("Python could not read Vort tar.lzf")
            else:
                mode = "r:" if compression == "none" else {"gzip": "r:gz", "bzip2": "r:bz2", "xz": "r:xz"}[compression]
                with tarfile.open(archive_path, mode=mode) as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError(f"Python could not read Vort tarball {compression}")

        for compression in sorted(streaming_writer_compressions):
            first_stream = temp / f"vort-incremental-{compression}-one.tarball"
            micro_stream = temp / f"vort-incremental-{compression}-micro.tarball"
            run(
                args.incremental_compressed_writer,
                str(first_stream),
                compression,
                str(source),
                "one",
            )
            run(
                args.incremental_compressed_writer,
                str(micro_stream),
                compression,
                str(source),
                "micro",
            )
            if first_stream.read_bytes() != micro_stream.read_bytes():
                raise AssertionError(
                    f"incremental compressed TAR wire changed with scheduling: {compression}"
                )
            decoded_output = temp / f"vort-incremental-{compression}.out"
            run(
                args.cli,
                "extract-tar-file",
                str(first_stream),
                "payload.bin",
                str(decoded_output),
                "1048576",
            )
            if decoded_output.read_bytes() != payload:
                raise AssertionError(
                    f"Vort could not extract incremental tarball: {compression}"
                )
            raw_stream = decode_streaming_tarball(
                compression,
                first_stream,
                zstd_tool,
                lz4_tool,
                lzf_tool,
                lzip_tool,
                lzop_tool,
                uncompress_tool,
            )
            if raw_stream is not None:
                with tarfile.open(fileobj=io.BytesIO(raw_stream), mode="r:") as archive:
                    if archive.extractfile("payload.bin").read() != payload:
                        raise AssertionError(
                            f"external reader could not extract incremental tarball: {compression}"
                        )
                incremental_compressed_writer_external += 1
            incremental_compressed_writer_cases += 1

        legacy_lz4_archive = temp / "vort.tar.lz4-legacy"
        run(
            args.cli,
            "encode-lz4-legacy-file",
            str(first),
            str(legacy_lz4_archive),
            "1024",
        )
        for pattern in ("one", "micro"):
            run(
                args.incremental_compressed_reader,
                str(legacy_lz4_archive),
                "plain.txt",
                str(plain_expected),
                "lz4-legacy",
                pattern,
            )
        incremental_compressed_reader_cases += 1
        for pattern in ("one", "micro"):
            run(
                args.incremental_auto_reader,
                str(legacy_lz4_archive),
                "plain.txt",
                str(plain_expected),
                "lz4_legacy",
                pattern,
            )
        incremental_auto_reader_cases += 1

        python_tar, payloads = python_archive(tarfile.PAX_FORMAT)
        compressed_inputs = {
            "none": python_tar,
            "gzip": __import__("gzip").compress(python_tar, mtime=0),
            "bzip2": __import__("bz2").compress(python_tar),
            "brotli": brotli_compress(python_tar),
            "lzma": __import__("lzma").compress(
                python_tar, format=__import__("lzma").FORMAT_ALONE
            ),
            "xz": __import__("lzma").compress(python_tar),
        }
        if zstd_tool is not None:
            compressed_inputs["zstd"] = subprocess.run(
                [zstd_tool, "-q", "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lz4_tool is not None:
            compressed_inputs["lz4"] = subprocess.run(
                [lz4_tool, "-q", "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if compress_tool is not None:
            compressed_inputs["compress-z"] = subprocess.run(
                [compress_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lzip_tool is not None:
            compressed_inputs["lzip"] = subprocess.run(
                [lzip_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lzf_tool is not None:
            compressed_inputs["lzf"] = subprocess.run(
                [lzf_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        if lz4_tool is not None:
            compressed_inputs["lz4-legacy"] = subprocess.run(
                [lz4_tool, "-l", "-q", "-c"],
                input=python_tar,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if lzop_tool is not None:
            compressed_inputs["lzop"] = subprocess.run(
                [lzop_tool, "-c"], input=python_tar, check=True, stdout=subprocess.PIPE
            ).stdout
        for compression, data in compressed_inputs.items():
            path = temp / f"python.tar.{compression}"
            path.write_bytes(data)
            validate_with_vort(args.cli, path, payloads)
            name, payload = next(iter(payloads.items()))
            expected_path = temp / f"python-{compression}-auto-expected.bin"
            expected_path.write_bytes(payload)
            for pattern in ("one", "micro"):
                run(
                    args.incremental_auto_reader,
                    str(path),
                    name,
                    str(expected_path),
                    auto_formats[compression],
                    pattern,
                )
            incremental_auto_reader_cases += 1
            if compression in streaming_compressions or compression == "lz4-legacy":
                name, payload = next(iter(payloads.items()))
                expected_path = temp / f"python-{compression}-incremental-expected.bin"
                expected_path.write_bytes(payload)
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_compressed_reader,
                        str(path),
                        name,
                        str(expected_path),
                        compression,
                        pattern,
                    )
                incremental_compressed_reader_cases += 1

    print(
        f"tar_diff=ok raw_formats=2 compressions={len(compressions)} "
        f"brotli_directions=2 lzf_directions={2 if lzf_tool is not None else 0} "
        f"entries=7 gnu_sparse_reader_cases={gnu_sparse_reader_cases} "
        f"incremental_reader_cases={incremental_reader_cases} "
        f"incremental_compressed_reader_cases={incremental_compressed_reader_cases} "
        f"incremental_auto_reader_cases={incremental_auto_reader_cases} "
        f"incremental_compressed_writer_cases={incremental_compressed_writer_cases} "
        f"incremental_compressed_writer_external={incremental_compressed_writer_external} "
        "sparse_writer_readers=4 incremental_writer_cases=7"
    )


if __name__ == "__main__":
    main()
