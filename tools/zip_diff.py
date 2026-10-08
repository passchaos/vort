#!/usr/bin/env python3
"""Black-box ZIP32 stored/deflate compatibility test against Python zipfile."""

from __future__ import annotations

import argparse
import io
import subprocess
import tempfile
import zipfile
from pathlib import Path


class NonSeekableBuffer(io.BytesIO):
    def seekable(self) -> bool:
        return False

    def seek(self, *args: object, **kwargs: object) -> int:
        raise io.UnsupportedOperation("non-seekable ZIP fixture")


def run(cli: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(cli), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()

    payloads = {
        "stored.bin": bytes(range(64)) + b"\x00stored\xff",
        "folder/deflated.txt": (b"Vort ZIP deflate differential.\n" * 256),
        "utf8-目录/数据.txt": "ZIP UTF-8 文件名\n".encode() * 17,
        "empty/": b"",
    }
    sink = NonSeekableBuffer()
    with zipfile.ZipFile(sink, "w", allowZip64=False) as archive:
        archive.comment = b"vort zip differential"
        archive.writestr("stored.bin", payloads["stored.bin"], compress_type=zipfile.ZIP_STORED)
        archive.writestr(
            "folder/deflated.txt",
            payloads["folder/deflated.txt"],
            compress_type=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        )
        archive.writestr(
            "utf8-目录/数据.txt",
            payloads["utf8-目录/数据.txt"],
            compress_type=zipfile.ZIP_DEFLATED,
            compresslevel=1,
        )
        directory = zipfile.ZipInfo("empty/")
        directory.external_attr = 0o40775 << 16
        archive.writestr(directory, b"", compress_type=zipfile.ZIP_STORED)
    fixture = sink.getvalue()

    with tempfile.TemporaryDirectory(prefix="vort-zip-diff-") as temp_text:
        temp = Path(temp_text)
        zip_path = temp / "fixture.zip"
        zip_path.write_bytes(fixture)

        listing = run(args.cli, "list-zip-file", str(zip_path)).stdout
        if "zip_entries=4" not in listing:
            raise AssertionError(f"unexpected ZIP listing header: {listing}")
        for name in payloads:
            if f"name={name}" not in listing:
                raise AssertionError(f"ZIP listing omitted {name!r}: {listing}")

        for index, (name, expected) in enumerate(payloads.items()):
            output = temp / f"output-{index}.bin"
            run(args.cli, "extract-zip-file", str(zip_path), name, str(output))
            if output.read_bytes() != expected:
                raise AssertionError(f"ZIP extraction mismatch for {name!r}")

        with zipfile.ZipFile(zip_path) as archive:
            if archive.comment != b"vort zip differential":
                raise AssertionError("fixture comment changed")
            for name, expected in payloads.items():
                if archive.read(name) != expected:
                    raise AssertionError(f"Python fixture mismatch for {name!r}")

    print(f"zip_diff=ok entries={len(payloads)} bytes={len(fixture)}")


if __name__ == "__main__":
    main()
