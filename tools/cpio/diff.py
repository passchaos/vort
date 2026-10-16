#!/usr/bin/env python3
"""CPIO header-format and compression-wrapper interoperability harness."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import os
import random
import shutil
import subprocess
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
            raise AssertionError("libbrotli could not compress CPIO fixture")
        return output.raw[: output_size.value]


def brotli_decompress(data: bytes, max_output_len: int) -> bytes:
    try:
        import brotli

        decoded = brotli.decompress(data)
        if len(decoded) > max_output_len:
            raise AssertionError("Brotli CPIO fixture exceeded its output limit")
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
            raise AssertionError("libbrotli could not decompress CPIO fixture")
        return output.raw[: output_size.value]


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
    rng = random.Random(0xC910_0707)
    prefix = bytes(rng.randrange(256) for _ in range(4096))
    return prefix + b"CPIO interoperability payload\n" * 256 + prefix


def reference_create(
    cpio: Path,
    work: Path,
    output: Path,
    format_name: str,
    names: tuple[str, ...],
) -> None:
    with output.open("wb") as archive_file:
        subprocess.run(
            [str(cpio), "-o", "-H", format_name, "--quiet"],
            check=True,
            cwd=work,
            input=("\n".join(names) + "\n").encode(),
            stdout=archive_file,
            stderr=subprocess.PIPE,
        )


def reference_extract(cpio: Path, archive: Path, output_dir: Path) -> bytes:
    output_dir.mkdir()
    run(cpio, "-id", "--quiet", "-F", str(archive), cwd=output_dir)
    return (output_dir / "payload.bin").read_bytes()


def decode_streaming_cpio(
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
    if compression in ("lz4", "lz4-legacy"):
        if lz4_tool is None:
            return None
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
            return None
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
    raise AssertionError(f"unsupported streaming CPIO compression: {compression}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", type=Path)
    parser.add_argument("--incremental-reader", type=Path)
    parser.add_argument("--incremental-compressed-reader", type=Path)
    parser.add_argument("--incremental-auto-reader", type=Path)
    parser.add_argument("--incremental-compressed-writer", type=Path)
    parser.add_argument("--cpio", type=Path)
    args = parser.parse_args()
    cpio_tool = args.cpio or (Path(found) if (found := shutil.which("cpio")) else None)
    payload = make_payload()
    formats = {
        "newc": "newc",
        "crc": "crc",
        "odc": "odc",
        "bin": "binary_little",
        "bin-be": "binary_big",
    }
    reference_formats = ("newc", "crc", "odc", "bin")
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
    writer_external = 0
    reference_writer = 0
    wrapper_cases = 0
    incremental_writer_cases = 0
    incremental_reader_cases = 0
    incremental_compressed_reader_cases = 0
    incremental_compressed_reader_external = 0
    incremental_auto_reader_cases = 0
    incremental_auto_reader_external = 0
    incremental_compressed_writer_cases = 0
    incremental_compressed_writer_external = 0

    with tempfile.TemporaryDirectory(prefix="vort-cpio-diff-") as temp_text:
        temp = Path(temp_text)
        source = temp / "source.bin"
        source.write_bytes(payload)

        for format_name, expected_tag in formats.items():
            first = temp / f"vort-{format_name}-first.cpio"
            second = temp / f"vort-{format_name}-second.cpio"
            output = temp / f"vort-{format_name}.out"
            run(args.cli, "create-cpio-file", str(first), "payload.bin", str(source), format_name)
            run(args.cli, "create-cpio-file", str(second), "payload.bin", str(source), format_name)
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort CPIO {format_name} output is not deterministic")
            listing = run(args.cli, "list-cpio-file", str(first)).stdout
            if f"format={expected_tag}" not in listing or "name=payload.bin" not in listing:
                raise AssertionError(f"Vort CPIO listing mismatch for {format_name}: {listing}")
            run(args.cli, "extract-cpio-file", str(first), "payload.bin", str(output), str(len(payload)))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort CPIO {format_name} self-extraction mismatch")
            if args.incremental_reader is not None:
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_reader,
                        str(first),
                        "payload.bin",
                        str(source),
                        pattern,
                    )
                    incremental_reader_cases += 1
            if args.incremental_auto_reader is not None:
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_auto_reader,
                        str(first),
                        "payload.bin",
                        str(source),
                        "raw_cpio",
                        pattern,
                    )
                incremental_auto_reader_cases += 1
            if cpio_tool is not None:
                listed = run(cpio_tool, "-it", "--quiet", "-F", str(first)).stdout.splitlines()
                if listed != ["payload.bin"]:
                    raise AssertionError(f"GNU cpio rejected Vort {format_name}: {listed}")
                if reference_extract(
                    cpio_tool,
                    first,
                    temp / f"gnu-vort-{format_name}",
                ) != payload:
                    raise AssertionError(f"GNU cpio extraction mismatch for Vort {format_name}")
                writer_external += 1

        for compression in compressions:
            archive = temp / f"wrapper-{compression}.cpio"
            output = temp / f"wrapper-{compression}.out"
            run(
                args.cli,
                "create-cpio-file",
                str(archive),
                "payload.bin",
                str(source),
                "newc",
                compression,
            )
            listing = run(args.cli, "list-cpio-file", str(archive)).stdout
            expected = "zstandard" if compression == "zstd" else (
                "compress_z" if compression == "compress-z" else compression
            )
            if f"compression={expected}" not in listing:
                raise AssertionError(f"Vort mislabeled CPIO wrapper {compression}: {listing}")
            run(args.cli, "extract-cpio-file", str(archive), "payload.bin", str(output), str(len(payload)))
            if output.read_bytes() != payload:
                raise AssertionError(f"Vort CPIO wrapper mismatch for {compression}")
            if compression != "none" and args.incremental_compressed_reader is not None:
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_compressed_reader,
                        str(archive),
                        "payload.bin",
                        str(source),
                        compression,
                        pattern,
                    )
                incremental_compressed_reader_cases += 1
            if args.incremental_auto_reader is not None:
                auto_format = {
                    "none": "raw_cpio",
                    "compress-z": "compress_z",
                    "zstd": "zstandard",
                }.get(compression, compression)
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_auto_reader,
                        str(archive),
                        "payload.bin",
                        str(source),
                        auto_format,
                        pattern,
                    )
                incremental_auto_reader_cases += 1
            wrapper_cases += 1

        raw_reference_path = temp / "vort-newc-first.cpio"
        raw_reference = raw_reference_path.read_bytes()
        lz4_tool = shutil.which("lz4")
        zstd_tool = shutil.which("zstd")
        lzf_tool = shutil.which("lzf")
        lzip_tool = shutil.which("lzip")
        lzop_tool = shutil.which("lzop")
        uncompress_tool = shutil.which("uncompress")
        compress_tool = shutil.which("compress")

        legacy_path = temp / "wrapper-lz4-legacy.cpio"
        run(
            args.cli,
            "encode-lz4-legacy-file",
            str(raw_reference_path),
            str(legacy_path),
            "1024",
        )
        if args.incremental_compressed_reader is not None:
            for pattern in ("one", "micro"):
                run(
                    args.incremental_compressed_reader,
                    str(legacy_path),
                    "payload.bin",
                    str(source),
                    "lz4-legacy",
                    pattern,
                )
            incremental_compressed_reader_cases += 1
        if args.incremental_auto_reader is not None:
            for pattern in ("one", "micro"):
                run(
                    args.incremental_auto_reader,
                    str(legacy_path),
                    "payload.bin",
                    str(source),
                    "lz4_legacy",
                    pattern,
                )
            incremental_auto_reader_cases += 1

        external_inputs = {
            "gzip": __import__("gzip").compress(raw_reference, mtime=0),
            "bzip2": __import__("bz2").compress(raw_reference),
            "brotli": brotli_compress(raw_reference),
            "lzma": __import__("lzma").compress(
                raw_reference, format=__import__("lzma").FORMAT_ALONE
            ),
            "xz": __import__("lzma").compress(raw_reference),
        }
        if compress_tool is not None:
            external_inputs["compress-z"] = subprocess.run(
                [compress_tool, "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if lz4_tool is not None:
            external_inputs["lz4"] = subprocess.run(
                [lz4_tool, "-q", "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
            external_inputs["lz4-legacy"] = subprocess.run(
                [lz4_tool, "-l", "-q", "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if lzf_tool is not None:
            external_inputs["lzf"] = subprocess.run(
                [lzf_tool, "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if lzip_tool is not None:
            external_inputs["lzip"] = subprocess.run(
                [lzip_tool, "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if zstd_tool is not None:
            external_inputs["zstd"] = subprocess.run(
                [zstd_tool, "-q", "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if lzop_tool is not None:
            external_inputs["lzop"] = subprocess.run(
                [lzop_tool, "-c"],
                input=raw_reference,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        if args.incremental_compressed_reader is not None:
            for compression, data in external_inputs.items():
                path = temp / f"external-{compression}.cpio"
                path.write_bytes(data)
                output = temp / f"external-{compression}.out"
                run(
                    args.cli,
                    "extract-cpio-file",
                    str(path),
                    "payload.bin",
                    str(output),
                    str(len(payload)),
                )
                if output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort auto decode failed external CPIO wrapper: {compression}"
                    )
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_compressed_reader,
                        str(path),
                        "payload.bin",
                        str(source),
                        compression,
                        pattern,
                    )
                incremental_compressed_reader_external += 1
        if args.incremental_auto_reader is not None:
            for compression, data in external_inputs.items():
                path = temp / f"external-{compression}.cpio"
                path.write_bytes(data)
                auto_format = {
                    "compress-z": "compress_z",
                    "zstd": "zstandard",
                    "lz4-legacy": "lz4_legacy",
                }.get(compression, compression)
                for pattern in ("one", "micro"):
                    run(
                        args.incremental_auto_reader,
                        str(path),
                        "payload.bin",
                        str(source),
                        auto_format,
                        pattern,
                    )
                incremental_auto_reader_external += 1

        if args.incremental_compressed_writer is not None:
            for compression in (
                "gzip",
                "bzip2",
                "brotli",
                "compress-z",
                "lzma",
                "xz",
                "lz4",
                "lz4-legacy",
                "lzf",
                "lzip",
                "zstd",
                "lzop",
            ):
                one = temp / f"incremental-{compression}-one.cpio"
                micro = temp / f"incremental-{compression}-micro.cpio"
                run(
                    args.incremental_compressed_writer,
                    str(one),
                    compression,
                    str(source),
                    "one",
                )
                run(
                    args.incremental_compressed_writer,
                    str(micro),
                    compression,
                    str(source),
                    "micro",
                )
                if one.read_bytes() != micro.read_bytes():
                    raise AssertionError(
                        f"incremental compressed CPIO wire changed with scheduling: {compression}"
                    )
                decoded_output = temp / f"incremental-{compression}.out"
                run(
                    args.cli,
                    "extract-cpio-file",
                    str(one),
                    "payload.bin",
                    str(decoded_output),
                    str(len(payload)),
                )
                if decoded_output.read_bytes() != payload:
                    raise AssertionError(
                        f"Vort could not extract incremental CPIO: {compression}"
                    )
                raw_stream = decode_streaming_cpio(
                    compression,
                    one,
                    zstd_tool,
                    lz4_tool,
                    lzf_tool,
                    lzip_tool,
                    lzop_tool,
                    uncompress_tool,
                )
                if raw_stream is not None:
                    if raw_stream != raw_reference:
                        raise AssertionError(
                            f"external decoder produced a different raw CPIO: {compression}"
                        )
                    incremental_compressed_writer_external += 1
                incremental_compressed_writer_cases += 1

        if args.writer is not None:
            expected_names = ["plain.txt", "folder", "folder/data.bin", "link"]
            for format_name in formats:
                archive = temp / f"probe-{format_name}.cpio"
                run(args.writer, str(archive), format_name)
                incremental_one = temp / f"probe-{format_name}-incremental-one.cpio"
                incremental_micro = temp / f"probe-{format_name}-incremental-micro.cpio"
                run(args.writer, str(incremental_one), format_name, "incremental-one")
                run(args.writer, str(incremental_micro), format_name, "incremental-micro")
                expected_wire = archive.read_bytes()
                if incremental_one.read_bytes() != expected_wire:
                    raise AssertionError(
                        f"one-byte incremental CPIO wire mismatch for {format_name}"
                    )
                if incremental_micro.read_bytes() != expected_wire:
                    raise AssertionError(
                        f"micro incremental CPIO wire mismatch for {format_name}"
                    )
                incremental_writer_cases += 2
                listing = run(args.cli, "list-cpio-file", str(archive)).stdout
                if "kind=directory" not in listing or "kind=symlink" not in listing:
                    raise AssertionError(f"Vort writer probe metadata mismatch for {format_name}: {listing}")
                if cpio_tool is not None:
                    listed = run(cpio_tool, "-it", "--quiet", "-F", str(archive)).stdout.splitlines()
                    if listed != expected_names:
                        raise AssertionError(f"GNU cpio rejected Vort metadata archive {format_name}: {listed}")

        if cpio_tool is not None:
            reference = temp / "reference"
            reference.mkdir()
            (reference / "payload.bin").write_bytes(payload)
            (reference / "folder").mkdir()
            os.symlink("payload.bin", reference / "link")
            (reference / "hard-a").write_bytes(payload)
            os.link(reference / "hard-a", reference / "hard-b")
            names = ("payload.bin", "folder", "link", "hard-a", "hard-b")
            for format_name in reference_formats:
                archive = temp / f"reference-{format_name}.cpio"
                reference_create(cpio_tool, reference, archive, format_name, names)
                listing = run(args.cli, "list-cpio-file", str(archive)).stdout
                if "name=payload.bin" not in listing or "kind=directory" not in listing or "kind=symlink" not in listing:
                    raise AssertionError(f"Vort misparsed GNU {format_name}: {listing}")
                output = temp / f"reference-{format_name}.out"
                run(args.cli, "extract-cpio-file", str(archive), "payload.bin", str(output), str(len(payload)))
                if output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed GNU cpio {format_name}")
                link_output = temp / f"reference-{format_name}.link"
                run(args.cli, "extract-cpio-file", str(archive), "link", str(link_output), "1024")
                if link_output.read_bytes() != b"payload.bin":
                    raise AssertionError(f"Vort failed GNU cpio {format_name} symlink target")
                hard_output = temp / f"reference-{format_name}.hard"
                run(args.cli, "extract-cpio-file", str(archive), "hard-a", str(hard_output), str(len(payload)))
                if hard_output.read_bytes() != payload:
                    raise AssertionError(f"Vort failed GNU cpio {format_name} hard-link resolution")
                if args.incremental_reader is not None:
                    for pattern in ("one", "micro"):
                        run(
                            args.incremental_reader,
                            str(archive),
                            "payload.bin",
                            str(reference / "payload.bin"),
                            pattern,
                        )
                        incremental_reader_cases += 1
                reference_writer += 1

        crc_archive = temp / "vort-crc-first.cpio"
        corrupt = bytearray(crc_archive.read_bytes())
        payload_offset = corrupt.find(payload)
        if payload_offset < 0:
            raise AssertionError("could not locate CRC payload")
        corrupt[payload_offset] ^= 1
        corrupt_path = temp / "corrupt-crc.cpio"
        corrupt_path.write_bytes(corrupt)
        failed = run(
            args.cli,
            "extract-cpio-file",
            str(corrupt_path),
            "payload.bin",
            str(temp / "corrupt.out"),
            check=False,
        )
        if failed.returncode == 0:
            raise AssertionError("Vort accepted a CPIO CRC archive with corrupt data")

        truncated = temp / "truncated.cpio"
        truncated.write_bytes((temp / "vort-newc-first.cpio").read_bytes()[:100])
        if run(args.cli, "list-cpio-file", str(truncated), check=False).returncode == 0:
            raise AssertionError("Vort accepted a truncated CPIO header")

        trailing = bytearray((temp / "vort-newc-first.cpio").read_bytes())
        trailing[-1] = 1
        trailing_path = temp / "trailing.cpio"
        trailing_path.write_bytes(trailing)
        if run(args.cli, "list-cpio-file", str(trailing_path), check=False).returncode == 0:
            raise AssertionError("Vort accepted nonzero bytes after the CPIO trailer")

    print(
        f"formats={len(formats)} self_writer_cases={len(formats)} "
        f"cpio={cpio_tool is not None} writer_external={writer_external} "
        f"reference_writer={reference_writer} wrapper_cases={wrapper_cases} "
        f"incremental_writer_cases={incremental_writer_cases} "
        f"incremental_reader_cases={incremental_reader_cases} "
        f"incremental_compressed_reader_cases={incremental_compressed_reader_cases} "
        f"incremental_compressed_reader_external={incremental_compressed_reader_external} "
        f"incremental_auto_reader_cases={incremental_auto_reader_cases} "
        f"incremental_auto_reader_external={incremental_auto_reader_external} "
        f"incremental_compressed_writer_cases={incremental_compressed_writer_cases} "
        f"incremental_compressed_writer_external={incremental_compressed_writer_external} "
        "corrupt_crc=True truncated=True trailing=True"
    )


if __name__ == "__main__":
    main()
