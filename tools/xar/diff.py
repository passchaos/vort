#!/usr/bin/env python3
import argparse
import ctypes
import ctypes.util
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


AE_IFREG = 0o100000
ARCHIVE_OK = 0
ARCHIVE_EOF = 1


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def expect_failure(*args: object, error_name: str) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name}: {result.stderr.decode(errors='replace')}"
        )


class LibArchive:
    def __init__(self, library: str):
        self.lib = ctypes.CDLL(library)
        L = self.lib
        L.archive_error_string.argtypes = [ctypes.c_void_p]
        L.archive_error_string.restype = ctypes.c_char_p
        L.archive_write_new.restype = ctypes.c_void_p
        L.archive_write_set_format_xar.argtypes = [ctypes.c_void_p]
        L.archive_write_set_format_option.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_char_p,
        ]
        L.archive_write_open_filename.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        L.archive_write_header.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        L.archive_write_data.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
        L.archive_write_data.restype = ctypes.c_ssize_t
        L.archive_write_finish_entry.argtypes = [ctypes.c_void_p]
        L.archive_write_close.argtypes = [ctypes.c_void_p]
        L.archive_write_free.argtypes = [ctypes.c_void_p]
        L.archive_entry_new.restype = ctypes.c_void_p
        L.archive_entry_free.argtypes = [ctypes.c_void_p]
        L.archive_entry_set_pathname.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        L.archive_entry_set_filetype.argtypes = [ctypes.c_void_p, ctypes.c_uint]
        L.archive_entry_set_perm.argtypes = [ctypes.c_void_p, ctypes.c_int]
        L.archive_entry_set_size.argtypes = [ctypes.c_void_p, ctypes.c_longlong]

        L.archive_read_new.restype = ctypes.c_void_p
        L.archive_read_support_filter_all.argtypes = [ctypes.c_void_p]
        L.archive_read_support_format_xar.argtypes = [ctypes.c_void_p]
        L.archive_read_open_filename.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_size_t,
        ]
        L.archive_read_next_header.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
        L.archive_read_data.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
        L.archive_read_data.restype = ctypes.c_ssize_t
        L.archive_read_data_skip.argtypes = [ctypes.c_void_p]
        L.archive_read_close.argtypes = [ctypes.c_void_p]
        L.archive_read_free.argtypes = [ctypes.c_void_p]
        L.archive_entry_pathname.argtypes = [ctypes.c_void_p]
        L.archive_entry_pathname.restype = ctypes.c_char_p
        L.archive_entry_filetype.argtypes = [ctypes.c_void_p]
        L.archive_entry_filetype.restype = ctypes.c_uint

    def check(self, archive: int, result: int, operation: str) -> None:
        if result >= ARCHIVE_OK:
            return
        message = self.lib.archive_error_string(archive)
        detail = message.decode(errors="replace") if message else "unknown error"
        raise AssertionError(f"libarchive {operation}: {detail} ({result})")

    def write_xar(self, path: Path, name: str, data: bytes, compression: str) -> None:
        L = self.lib
        archive = L.archive_write_new()
        if not archive:
            raise MemoryError("archive_write_new")
        entry = None
        try:
            self.check(archive, L.archive_write_set_format_xar(archive), "set xar")
            self.check(
                archive,
                L.archive_write_set_format_option(
                    archive, b"xar", b"compression", compression.encode()
                ),
                "set compression",
            )
            self.check(
                archive,
                L.archive_write_set_format_option(
                    archive, b"xar", b"toc-checksum", b"sha1"
                ),
                "set toc checksum",
            )
            self.check(
                archive,
                L.archive_write_open_filename(archive, str(path).encode()),
                "open output",
            )
            entry = L.archive_entry_new()
            L.archive_entry_set_pathname(entry, name.encode())
            L.archive_entry_set_filetype(entry, AE_IFREG)
            L.archive_entry_set_perm(entry, 0o644)
            L.archive_entry_set_size(entry, len(data))
            self.check(archive, L.archive_write_header(archive, entry), "write header")
            if data:
                buffer = ctypes.create_string_buffer(data)
                written = L.archive_write_data(archive, buffer, len(data))
                if written != len(data):
                    self.check(archive, int(written), "write data")
                    raise AssertionError(f"libarchive short write: {written}/{len(data)}")
            self.check(archive, L.archive_write_finish_entry(archive), "finish entry")
            self.check(archive, L.archive_write_close(archive), "close writer")
        finally:
            if entry:
                L.archive_entry_free(entry)
            L.archive_write_free(archive)

    def read_xar(self, path: Path) -> dict[str, bytes]:
        L = self.lib
        archive = L.archive_read_new()
        if not archive:
            raise MemoryError("archive_read_new")
        files: dict[str, bytes] = {}
        try:
            self.check(archive, L.archive_read_support_filter_all(archive), "filters")
            self.check(archive, L.archive_read_support_format_xar(archive), "xar reader")
            self.check(
                archive,
                L.archive_read_open_filename(archive, str(path).encode(), 10240),
                "open input",
            )
            while True:
                entry = ctypes.c_void_p()
                result = L.archive_read_next_header(archive, ctypes.byref(entry))
                if result == ARCHIVE_EOF:
                    break
                self.check(archive, result, "next header")
                raw_name = L.archive_entry_pathname(entry)
                name = raw_name.decode(errors="surrogateescape") if raw_name else ""
                if L.archive_entry_filetype(entry) != AE_IFREG:
                    self.check(archive, L.archive_read_data_skip(archive), "skip")
                    continue
                output = bytearray()
                buffer = ctypes.create_string_buffer(65536)
                while True:
                    count = L.archive_read_data(archive, buffer, len(buffer))
                    if count == 0:
                        break
                    if count < 0:
                        self.check(archive, int(count), "read data")
                    output.extend(buffer.raw[:count])
                files[name] = bytes(output)
            self.check(archive, L.archive_read_close(archive), "close reader")
            return files
        finally:
            L.archive_read_free(archive)


def payload() -> bytes:
    rng = random.Random(0x5841_5221)
    return b"Apple XAR payload 0123456789\n" * 200 + rng.randbytes(257)


def assert_7zip(seven_zip: Path, archive: Path, expected: bytes, temp: Path, name: str) -> None:
    output_dir = temp / f"7zip-{name}"
    output_dir.mkdir()
    result = run(
        seven_zip,
        "e",
        "-tXar",
        "-y",
        "-bso0",
        "-bsp0",
        f"-o{output_dir}",
        archive,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr.decode(errors="replace"))
    files = [path for path in output_dir.rglob("*") if path.is_file()]
    if not any(path.read_bytes() == expected for path in files):
        raise AssertionError(f"7-Zip XAR mismatch for {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--seven-zip", type=Path)
    parser.add_argument("--libarchive")
    args = parser.parse_args()
    seven_zip = args.seven_zip or (
        Path(found)
        if (found := shutil.which("7zz") or shutil.which("7z"))
        else None
    )
    library = args.libarchive or ctypes.util.find_library("archive")
    libarchive = LibArchive(library) if library else None

    self_cases = 0
    external_encode = 0
    external_decode = 0
    malformed = 0
    plain = payload()
    with tempfile.TemporaryDirectory(prefix="vort-xar-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        for codec in ("copy", "zlib", "bzip2", "lzma", "xz"):
            archive = temp / f"vort-{codec}.xar"
            output = temp / f"vort-{codec}.raw"
            run(
                args.cli,
                "encode-xar-file",
                source,
                archive,
                "payload.bin",
                codec,
                "sha1",
            )
            run(args.cli, "inspect-xar", archive)
            run(
                args.cli,
                "extract-xar-entry",
                archive,
                output,
                "payload.bin",
                len(plain),
            )
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort XAR round trip mismatch for {codec}")
            self_cases += 1
            if libarchive is not None:
                files = libarchive.read_xar(archive)
                if files.get("payload.bin") != plain:
                    raise AssertionError(f"libarchive XAR decode mismatch for {codec}")
                external_encode += 1
            if seven_zip is not None and codec in {"copy", "zlib", "bzip2"}:
                assert_7zip(seven_zip, archive, plain, temp, codec)
                external_encode += 1

        if libarchive is not None:
            for codec in ("none", "gzip", "bzip2", "lzma", "xz"):
                archive = temp / f"reference-{codec}.xar"
                output = temp / f"reference-{codec}.raw"
                libarchive.write_xar(archive, "payload.bin", plain, codec)
                run(
                    args.cli,
                    "extract-xar-entry",
                    archive,
                    output,
                    "payload.bin",
                    len(plain),
                )
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of libarchive XAR {codec} mismatch")
                external_decode += 1

        valid = temp / "vort-zlib.xar"
        short = temp / "short.xar"
        short.write_bytes(b"xar!")
        expect_failure(args.cli, "inspect-xar", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic = bytearray(valid.read_bytes())
        bad_magic[0] ^= 1
        bad_magic_path = temp / "bad-magic.xar"
        bad_magic_path.write_bytes(bad_magic)
        expect_failure(args.cli, "inspect-xar", bad_magic_path, error_name="InvalidMagic")
        malformed += 1

        header_size, packed_size, _, algorithm = struct.unpack_from(">H2xQQI", valid.read_bytes(), 4)
        heap_offset = header_size + packed_size
        digest_size = {0: 0, 1: 20, 2: 16, 3: 32, 4: 64}[algorithm]
        bad_toc = bytearray(valid.read_bytes())
        bad_toc[heap_offset] ^= 1
        bad_toc_path = temp / "bad-toc.xar"
        bad_toc_path.write_bytes(bad_toc)
        expect_failure(args.cli, "inspect-xar", bad_toc_path, error_name="ChecksumMismatch")
        malformed += 1

        bad_data = bytearray(valid.read_bytes())
        bad_data[heap_offset + digest_size] ^= 1
        bad_data_path = temp / "bad-data.xar"
        bad_data_path.write_bytes(bad_data)
        expect_failure(
            args.cli,
            "extract-xar-entry",
            bad_data_path,
            temp / "bad-data.raw",
            "payload.bin",
            len(plain),
            error_name="ChecksumMismatch",
        )
        malformed += 1

        expect_failure(
            args.cli,
            "extract-xar-entry",
            valid,
            temp / "limited.raw",
            "payload.bin",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1

    print(
        f"self={self_cases} libarchive={libarchive is not None} "
        f"seven_zip={seven_zip is not None} external_encode={external_encode} "
        f"external_decode={external_decode} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
