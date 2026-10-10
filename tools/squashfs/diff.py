#!/usr/bin/env python3
import argparse
import base64
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


def run(*args: object, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def expect_failure(*args: object, error_name: str | None = None) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name is not None and error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name} diagnostic: {result.stderr.decode(errors='replace')}"
        )


def write_tree(root: Path) -> dict[str, bytes]:
    (root / "nested").mkdir(parents=True)
    (root / "wide").mkdir()
    payloads = {
        "small.txt": b"small fragment payload\n",
        "nested/data.txt": b"nested squashfs payload\n",
        "large.bin": (b"large squashfs block payload 0123456789\n" * 9000)[:350_000],
        "wide/item-299.txt": b"wide directory item 299\n",
    }
    for name, payload in payloads.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    for index in range(300):
        path = root / "wide" / f"item-{index:03}.txt"
        if not path.exists():
            path.write_bytes(f"wide directory item {index}\n".encode())
    sparse = root / "sparse.bin"
    with sparse.open("wb") as output:
        output.seek(200_000)
        output.write(b"end")
    payloads["sparse.bin"] = sparse.read_bytes()
    (root / "link").symlink_to("nested/data.txt")
    payloads["link"] = b"nested/data.txt"
    return payloads


def make_image(mksquashfs: Path, source: Path, output: Path, codec: str, extra: list[str]) -> None:
    run(
        mksquashfs,
        source,
        output,
        "-noappend",
        "-no-progress",
        "-processors",
        "1",
        "-comp",
        codec,
        "-no-xattrs",
        "-all-root",
        "-mkfs-time",
        "0",
        "-all-time",
        "0",
        *extra,
    )


def verify_vort(cli: Path, image: Path, payloads: dict[str, bytes], codec: str, temp: Path) -> None:
    listing = run(cli, "list-squashfs-file", image).stdout
    expected_codec = "zstandard" if codec == "zstd" else codec
    if f"compression={expected_codec}".encode() not in listing:
        raise AssertionError(f"SquashFS compression mismatch: {listing!r}")
    for name in (
        "large.bin",
        "small.txt",
        "nested/data.txt",
        "link",
        "sparse.bin",
        "wide/item-299.txt",
    ):
        output = temp / f"{codec}-{name.replace('/', '-')}.out"
        run(cli, "extract-squashfs-file", image, name, output, len(payloads[name]))
        if output.read_bytes() != payloads[name]:
            raise AssertionError(f"SquashFS extraction mismatch for {codec}/{name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--mksquashfs", type=Path)
    parser.add_argument("--unsquashfs", type=Path)
    args = parser.parse_args()
    mksquashfs = args.mksquashfs or (
        Path(found) if (found := shutil.which("mksquashfs")) else None
    )
    unsquashfs = args.unsquashfs or (
        Path(found) if (found := shutil.which("unsquashfs")) else None
    )
    if (mksquashfs is None) != (unsquashfs is None):
        raise AssertionError("both SquashFS oracle tools are required")

    fixture_cases = 0
    codec_cases = 0
    variant_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-squashfs-") as temp_text:
        temp = Path(temp_text)
        fixture_text = Path("src/squashfs/testdata/gzip-tree.sqfs.b64").read_text()
        fixture = temp / "fixture.sqfs"
        fixture.write_bytes(base64.b64decode(fixture_text))
        fixture_small = temp / "fixture-small.out"
        run(
            args.cli,
            "extract-squashfs-file",
            fixture,
            "small.txt",
            fixture_small,
            1024,
        )
        if fixture_small.read_bytes() != b"small fragment payload\n":
            raise AssertionError("checked-in SquashFS fixture mismatch")
        fixture_cases += 1

        source = temp / "tree"
        payloads = write_tree(source)
        primary: Path = fixture
        if mksquashfs is not None:
            assert unsquashfs is not None
            for codec in ("gzip", "lzma", "lzo", "xz", "lz4", "zstd"):
                image = temp / f"{codec}.sqfs"
                make_image(mksquashfs, source, image, codec, [])
                run(unsquashfs, "-s", image)
                if run(unsquashfs, "-cat", image, "large.bin").stdout != payloads["large.bin"]:
                    raise AssertionError(f"unsquashfs oracle mismatch for {codec}")
                verify_vort(args.cli, image, payloads, codec, temp)
                codec_cases += 1
                if codec == "gzip":
                    primary = image

            for label, extra in (
                ("uncompressed", ["-noD", "-noI", "-noF"]),
                ("no-fragments", ["-no-fragments", "-b", "4096"]),
            ):
                image = temp / f"{label}.sqfs"
                make_image(mksquashfs, source, image, "gzip", extra)
                verify_vort(args.cli, image, payloads, "gzip", temp)
                variant_cases += 1

        expect_failure(
            args.cli,
            "extract-squashfs-file",
            primary,
            "large.bin",
            temp / "limited.out",
            len(payloads["large.bin"]) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        original = primary.read_bytes()
        inode_start = struct.unpack_from("<Q", original, 64)[0]
        corrupt_metadata = bytearray(original)
        if inode_start + 2 < len(corrupt_metadata):
            corrupt_metadata[inode_start + 2] ^= 0xFF
        bad_version = bytearray(original)
        bad_version[28:30] = struct.pack("<H", 3)
        bad_block = bytearray(original)
        bad_block[12:16] = struct.pack("<I", 12345)
        malformed_cases = [
            ("bad-magic", b"not!" + bytes(92), "InvalidMagic"),
            ("truncated", original[:95], "TruncatedFrame"),
            ("bad-version", bytes(bad_version), "UnsupportedSquashfsVersion"),
            ("bad-block", bytes(bad_block), "InvalidSquashfs"),
            ("corrupt-metadata", bytes(corrupt_metadata), None),
        ]
        for name, data, error_name in malformed_cases:
            image = temp / f"{name}.sqfs"
            image.write_bytes(data)
            expect_failure(
                args.cli,
                "list-squashfs-file",
                image,
                error_name=error_name,
            )
            malformed += 1
        expect_failure(
            args.cli,
            "extract-squashfs-file",
            primary,
            "missing/path",
            temp / "missing.out",
            1024,
            error_name="SquashfsEntryNotFound",
        )
        malformed += 1

    print(
        f"fixture_cases={fixture_cases} tools={mksquashfs is not None} "
        f"codec_cases={codec_cases} variants={variant_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
