#!/usr/bin/env python3
"""Black-box CAB compatibility checks against public libmspack fixtures."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import hashlib
import random
import shutil
import subprocess
import tempfile
from pathlib import Path


def libarchive_extract(path: Path) -> dict[str, bytes]:
    library_path = ctypes.util.find_library("archive")
    if library_path is None:
        raise AssertionError("libarchive is required for CAB writer differential")
    library = ctypes.CDLL(library_path)
    library.archive_read_new.restype = ctypes.c_void_p
    library.archive_read_support_format_cab.argtypes = [ctypes.c_void_p]
    library.archive_read_open_filename.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
    library.archive_read_next_header.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
    library.archive_entry_pathname_utf8.argtypes = [ctypes.c_void_p]
    library.archive_entry_pathname_utf8.restype = ctypes.c_char_p
    library.archive_read_data.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
    library.archive_read_data.restype = ctypes.c_ssize_t
    library.archive_error_string.argtypes = [ctypes.c_void_p]
    library.archive_error_string.restype = ctypes.c_char_p
    library.archive_read_free.argtypes = [ctypes.c_void_p]

    archive = library.archive_read_new()
    if not archive:
        raise AssertionError("libarchive allocation failed")
    try:
        if library.archive_read_support_format_cab(archive) != 0:
            raise AssertionError("libarchive CAB support is unavailable")
        if library.archive_read_open_filename(archive, str(path).encode(), 64 * 1024) != 0:
            message = library.archive_error_string(archive)
            raise AssertionError(f"libarchive could not open CAB: {message!r}")
        files: dict[str, bytes] = {}
        while True:
            entry = ctypes.c_void_p()
            status = library.archive_read_next_header(archive, ctypes.byref(entry))
            if status == 1:
                break
            if status != 0:
                message = library.archive_error_string(archive)
                raise AssertionError(f"libarchive CAB header error: {message!r}")
            raw_name = library.archive_entry_pathname_utf8(entry)
            if raw_name is None:
                raise AssertionError("libarchive returned a CAB entry without a name")
            output = bytearray()
            buffer = ctypes.create_string_buffer(64 * 1024)
            while True:
                count = library.archive_read_data(archive, buffer, len(buffer))
                if count == 0:
                    break
                if count < 0:
                    message = library.archive_error_string(archive)
                    raise AssertionError(f"libarchive CAB data error: {message!r}")
                output.extend(buffer.raw[:count])
            files[raw_name.decode("utf-8")] = bytes(output)
        return files
    finally:
        library.archive_read_free(archive)


EXPECTED = {
    "simple": {
        "sha256": "590791307b407a6ec6d885542952b7eb6575defde68e06d25bac4f41a9b634fd",
        "files": {
            "hello.c": b'#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf("Hello, world!\\n");\r\n}\r\n',
            "welcome.c": b'#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf("Welcome!\\n");\r\n}\r\n\r\n',
        },
    },
    "mixed": {
        "sha256": "0ce0b55fe705b744d41bb361170c0467db30da0c7f9bdd386d5dade71a78e171",
        "files": {
            "mszip.txt": b"If you can read this, the MSZIP decompressor is working!\n",
            "lzx.txt": (
                b"-----------------------------------------------------------------\n"
                b"If you can read this, the LZX decompressor is working!\n"
                b"-----------------------------------------------------------------\n"
            ),
            "qtm.txt": b"If you can read this, the Quantum decompressor is working!\n",
        },
    },
    "large-files-cab": {
        "sha256": "7137966abdffca1c3cfcf4119bc5a6d2f91f2e546e98f3a2ee013f9aa33b93df",
        "files": {},
        "large_file": {
            "name": "large-files.cab",
            "size": 14_689_228,
            "md5": "ac923e14971324651015ba44ceb59b36",
        },
    },
    "lzx-main-tree-no-lengths": {
        "sha256": "fd0ce6a326f735e4ad4bad8704f515a9eea9a0317e2a3b3c535ae3a15ca7d434",
        "files": {},
        "malformed_entry": "file.txt",
    },
    "lzx-premature-matches": {
        "sha256": "09f25f73b76058196f27486dbb3ca4ff8f57d5cba5f548db727844155b911244",
        "files": {},
        "malformed_entry": "file.txt",
    },
    "qtm-flush": {
        "sha256": "78bb4c9540e36d3d4228e22cdff0a5677f9c2dddc4239c322277d0b9125d8364",
        "files": {},
        "malformed_entry": "zeroes",
        "malformed_errors": ("InvalidQuantumStream",),
    },
    "qtm-infinite-loop": {
        "sha256": "2e6f57d26e12f3f1c0f1f968d7ebb92e77ea7720ea6f9e18f11eb00ef0e845ad",
        "files": {},
        "malformed_archive": "InvalidCabinet",
    },
    "qtm-max-size-block": {
        "sha256": "3ba0c719d8fb12dc531e2a7790c2d15c12d8840de8e4ddc60572c4145181fbf4",
        "files": {},
        "malformed_entry": "test1.bin",
        "malformed_errors": ("InvalidMatch",),
    },
}

SPLIT_CAB_SHA256 = (
    "802de38233dbdeb5ff006c14e62c504740320385f16f1db63bcef4811c768413",
    "e364408c0549b8845d929e1d5b85cd8ae53dc7216382fd935f8adad9a1e5f55f",
    "567fff7f7029129643072f62b9ef1256dbfd1e45f8707936cd30f8b735571a71",
    "a3589cdf11e420c39b3e32162d7b59135bb0863dab54eb19a2abb987a7c1f266",
    "fc9ed6b84b2d766019cc8b314ce0199d06f907225fe3604fbfbfafafdb449447",
)

SPLIT_FILES = {
    "small1.bin": (2_000, "2ad5ba0f497f1e597ab187a2dfaa2e29"),
    "small2.bin": (8_000, "1f862f9e36a32a74202c1120b9f06af7"),
    "medium1.bin": (40_000, "0a7bd124a4c03a30329bd9ff06f71df7"),
    "medium2.bin": (50_000, "b4b0a02ad6a1170d4b3db18cec616fcc"),
    "small3.bin": (128, "bbaecacfeba976165e9d77bbecb0cbde"),
    "medium3.bin": (40_000, "b98fe17e8afbcf05aefc5b2c4badbc28"),
}


def run(cli: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(cli), *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def fixture(root: Path, name: str) -> bytes:
    encoded = (root / f"libmspack-{name}.cab.hex").read_text(encoding="ascii")
    data = bytes.fromhex(encoded)
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED[name]["sha256"]:
        raise AssertionError(f"CAB fixture digest mismatch for {name}: {digest}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("src/cab/testdata"),
    )
    args = parser.parse_args()

    extracted = 0
    writer_cases = 0
    set_writer_cases = 0
    with tempfile.TemporaryDirectory(prefix="vort-cab-diff-") as temp_text:
        temp = Path(temp_text)
        for fixture_name, expected in EXPECTED.items():
            cab_path = temp / f"{fixture_name}.cab"
            cab_path.write_bytes(fixture(args.fixtures, fixture_name))
            if "malformed_archive" in expected:
                malformed = run(args.cli, "list-cab-file", str(cab_path), check=False)
                if (
                    malformed.returncode == 0
                    or expected["malformed_archive"] not in malformed.stderr
                ):
                    raise AssertionError(
                        f"malformed CAB fixture was not rejected: {malformed.stderr}"
                    )
                continue
            listing = run(args.cli, "list-cab-file", str(cab_path)).stdout
            if "malformed_entry" in expected:
                name = expected["malformed_entry"]
                malformed = run(
                    args.cli,
                    "extract-cab-file",
                    str(cab_path),
                    name,
                    str(temp / f"{fixture_name}.out"),
                    check=False,
                )
                malformed_errors = expected.get(
                    "malformed_errors",
                    ("InvalidLzxStream", "InvalidMatch"),
                )
                if malformed.returncode == 0 or not any(
                    error in malformed.stderr for error in malformed_errors
                ):
                    raise AssertionError(
                        f"malformed CAB fixture was not rejected: {malformed.stderr}"
                    )
                continue
            for name in expected["files"]:
                if f"name={name}" not in listing:
                    raise AssertionError(f"CAB listing omitted {name!r}: {listing}")
            for index, (name, payload) in enumerate(expected["files"].items()):
                output = temp / f"{fixture_name}-{index}.out"
                run(
                    args.cli,
                    "extract-cab-file",
                    str(cab_path),
                    name,
                    str(output),
                    "1048576",
                    "1048576",
                )
                if output.read_bytes() != payload:
                    raise AssertionError(f"CAB extraction mismatch for {name!r}")
                extracted += 1
            if "large_file" in expected:
                large = expected["large_file"]
                name = large["name"]
                if f"name={name}" not in listing:
                    raise AssertionError(f"CAB listing omitted {name!r}: {listing}")
                output = temp / "large-files-cab.out"
                run(
                    args.cli,
                    "extract-cab-file",
                    str(cab_path),
                    name,
                    str(output),
                    "20000000",
                    "20000000",
                )
                data = output.read_bytes()
                if len(data) != large["size"] or hashlib.md5(data).hexdigest() != large["md5"]:
                    raise AssertionError("aligned multi-frame LZX extraction mismatch")
                extracted += 1

        split_paths: list[Path] = []
        for index, expected_sha256 in enumerate(SPLIT_CAB_SHA256, 1):
            encoded = (args.fixtures / f"libmspack-split-{index}.cab.hex").read_text(
                encoding="ascii"
            )
            data = bytes.fromhex(encoded)
            digest = hashlib.sha256(data).hexdigest()
            if digest != expected_sha256:
                raise AssertionError(f"split CAB {index} digest mismatch: {digest}")
            path = temp / f"split-{index}.cab"
            path.write_bytes(data)
            listing = run(args.cli, "list-cab-file", str(path)).stdout
            if f"cabinet_index={index - 1}" not in listing:
                raise AssertionError(f"split CAB listing mismatch: {listing}")
            split_paths.append(path)

        for name, (expected_size, expected_md5) in SPLIT_FILES.items():
            output = temp / f"split-{name}"
            run(
                args.cli,
                "extract-cab-set",
                name,
                str(output),
                *(str(path) for path in split_paths),
            )
            data = output.read_bytes()
            if len(data) != expected_size or hashlib.md5(data).hexdigest() != expected_md5:
                raise AssertionError(f"split CAB extraction mismatch for {name!r}")
            extracted += 1

        rng = random.Random(0xCAB5EED)
        prefix = bytes(rng.randrange(256) for _ in range(32 * 1024))
        payload = prefix * 3 + b"CAB writer differential tail\n"
        source = temp / "writer-input.bin"
        source.write_bytes(payload)
        cabextract = shutil.which("cabextract")
        quantum_external = "skipped"
        for mode in ("stored", "mszip", "lzx", "quantum"):
            first = temp / f"vort-{mode}-first.cab"
            second = temp / f"vort-{mode}-second.cab"
            entry_name = "folder/payload.bin"
            run(args.cli, "create-cab-file", str(first), entry_name, str(source), mode, "32768")
            run(args.cli, "create-cab-file", str(second), entry_name, str(source), mode, "32768")
            if first.read_bytes() != second.read_bytes():
                raise AssertionError(f"Vort {mode} CAB output is not deterministic")
            listing = run(args.cli, "list-cab-file", str(first)).stdout
            expected_method = mode
            if f"method={expected_method}" not in listing or f"name={entry_name}" not in listing:
                raise AssertionError(f"unexpected Vort CAB listing: {listing}")
            vort_output = temp / f"vort-{mode}.out"
            run(
                args.cli,
                "extract-cab-file",
                str(first),
                entry_name,
                str(vort_output),
                "200000",
                "200000",
            )
            if vort_output.read_bytes() != payload:
                raise AssertionError(f"Vort could not read its {mode} CAB")
            if mode == "quantum":
                if cabextract is not None:
                    destination = temp / "cabextract-quantum"
                    destination.mkdir()
                    result = subprocess.run(
                        [cabextract, "-q", "-d", str(destination), str(first)],
                        check=False,
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                    )
                    external_path = destination / entry_name
                    if result.returncode != 0 or not external_path.is_file():
                        raise AssertionError(
                            f"cabextract could not read Vort Quantum CAB: {result.stderr}"
                        )
                    if external_path.read_bytes() != payload:
                        raise AssertionError("cabextract Quantum extraction mismatch")
                    quantum_external = "ok"
            else:
                external = libarchive_extract(first)
                if external.get(entry_name) != payload:
                    raise AssertionError(f"libarchive could not read Vort {mode} CAB")
            writer_cases += 1

        for mode in ("stored", "mszip", "lzx", "quantum"):
            first_dir = temp / f"vort-set-{mode}-first"
            second_dir = temp / f"vort-set-{mode}-second"
            entry_name = "folder/payload.bin"
            run(
                args.cli,
                "create-cab-set",
                str(first_dir),
                entry_name,
                str(source),
                "30000",
                mode,
            )
            run(
                args.cli,
                "create-cab-set",
                str(second_dir),
                entry_name,
                str(source),
                "30000",
                mode,
            )
            first_parts = sorted(first_dir.glob("*.cab"))
            second_parts = sorted(second_dir.glob("*.cab"))
            if len(first_parts) < 2 or len(first_parts) != len(second_parts):
                raise AssertionError(f"unexpected Vort {mode} cabinet set size")
            for first_part, second_part in zip(first_parts, second_parts):
                first_bytes = first_part.read_bytes()
                if len(first_bytes) > 30_000 or first_bytes != second_part.read_bytes():
                    raise AssertionError(f"Vort {mode} cabinet set is not deterministic or bounded")

            vort_output = temp / f"vort-set-{mode}.out"
            run(
                args.cli,
                "extract-cab-set",
                entry_name,
                str(vort_output),
                *(str(path) for path in first_parts),
            )
            if vort_output.read_bytes() != payload:
                raise AssertionError(f"Vort could not read its {mode} cabinet set")

            if cabextract is not None:
                destination = temp / f"cabextract-set-{mode}"
                destination.mkdir()
                result = subprocess.run(
                    [cabextract, "-q", "-d", str(destination), str(first_parts[0])],
                    check=False,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                external_path = destination / entry_name
                if result.returncode != 0 or not external_path.is_file():
                    raise AssertionError(
                        f"cabextract could not read Vort {mode} cabinet set: {result.stderr}"
                    )
                if external_path.read_bytes() != payload:
                    raise AssertionError(f"cabextract {mode} cabinet set mismatch")
            set_writer_cases += 1

    print(
        f"cab_diff=ok fixtures=13 extracted={extracted} writer_cases={writer_cases} "
        f"set_writer_cases={set_writer_cases} "
        "libarchive=ok malformed_lzx=2 malformed_quantum=3 lzx_writer=ok "
        f"quantum_writer=ok cabextract_quantum={quantum_external} "
        "lzx_aligned_frames=449 split_cabinets=5 quantum=ok"
    )


if __name__ == "__main__":
    main()
