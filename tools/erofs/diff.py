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
            f"missing {error_name}: {result.stderr.decode(errors='replace')}"
        )


def write_tree(root: Path) -> dict[str, bytes]:
    (root / "nested").mkdir(parents=True)
    state = 0x1234_5678
    random_data = bytearray()
    for _ in range(80_000):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        random_data.append(state & 0xFF)
    payloads = {
        "small.txt": b"small erofs payload\n",
        "nested/data.txt": b"nested erofs payload\n",
        "large.bin": (b"EROFS differential payload 0123456789\n" * 9000)[:250_000],
        "mixed.bin": b"compressible EROFS extent\n" * 3000
        + bytes(random_data)
        + b"compressible tail\n" * 3000,
        "link": b"nested/data.txt",
    }
    for name, payload in payloads.items():
        if name == "link":
            continue
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    (root / "link").symlink_to("nested/data.txt")
    return payloads


def make_image(mkfs: Path, source: Path, image: Path, compressor: str | None, legacy: bool) -> None:
    command: list[object] = [mkfs, "-T0", "--all-root"]
    if compressor is not None:
        command.append(f"-z{compressor}")
    if legacy:
        command.extend(("-E", "legacy-compress"))
    command.extend((image, source))
    run(*command)


def verify_vort(cli: Path, image: Path, payloads: dict[str, bytes], label: str, temp: Path) -> None:
    listing = run(cli, "list-erofs-file", image).stdout
    for required in (b"large.bin", b"mixed.bin", b"nested/data.txt", b"small.txt", b"link"):
        if required not in listing:
            raise AssertionError(f"EROFS listing missing {required!r} for {label}")
    for name, expected in payloads.items():
        output = temp / f"{label}-{name.replace('/', '-')}.out"
        run(cli, "extract-erofs-file", image, name, output, len(expected))
        if output.read_bytes() != expected:
            raise AssertionError(f"EROFS extraction mismatch for {label}/{name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--mkfs", type=Path)
    parser.add_argument("--fsck", type=Path)
    args = parser.parse_args()
    mkfs = args.mkfs or (Path(found) if (found := shutil.which("mkfs.erofs")) else None)
    fsck = args.fsck or (Path(found) if (found := shutil.which("fsck.erofs")) else None)
    if (mkfs is None) != (fsck is None):
        raise AssertionError("both EROFS oracle tools are required")

    fixture_cases = 0
    plain_cases = 0
    lz4_cases = 0
    modern_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-erofs-") as temp_text:
        temp = Path(temp_text)
        fixture = temp / "fixture.erofs"
        fixture.write_bytes(
            base64.b64decode(Path("src/erofs/testdata/lz4-compact-big.erofs.b64").read_text())
        )
        fixture_out = temp / "fixture.out"
        fixture_expected = (b"EROFS compact two-byte index payload 0123456789\n" * 6000)[:250_000]
        run(args.cli, "extract-erofs-file", fixture, "big.bin", fixture_out, 250_000)
        if fixture_out.read_bytes() != fixture_expected:
            raise AssertionError("checked-in EROFS fixture mismatch")
        fixture_cases += 1

        source = temp / "tree"
        payloads = write_tree(source)
        primary = fixture
        if mkfs is not None:
            assert fsck is not None
            help_text = run(mkfs, "--help", check=False).stderr + run(
                mkfs, "--help", check=False
            ).stdout
            cases: list[tuple[str, str | None, bool]] = [
                ("plain", None, False),
                ("lz4-compact", "lz4", False),
                ("lz4-full", "lz4", True),
            ]
            if b"deflate" in help_text:
                cases.extend(
                    (
                        ("deflate-compact", "deflate", False),
                        ("deflate-full", "deflate", True),
                    )
                )
            if b"zstd" in help_text:
                cases.append(("zstd-compact", "zstd", False))
            for label, compressor, legacy in cases:
                image = temp / f"{label}.erofs"
                make_image(mkfs, source, image, compressor, legacy)
                extracted = temp / f"{label}-fsck"
                run(fsck, f"--extract={extracted}", "--no-preserve", image)
                if (extracted / "large.bin").read_bytes() != payloads["large.bin"]:
                    raise AssertionError(f"fsck.erofs extraction mismatch for {label}")
                verify_vort(args.cli, image, payloads, label, temp)
                primary = image
                if compressor is None:
                    plain_cases += 1
                elif compressor == "lz4":
                    lz4_cases += 1
                else:
                    modern_cases += 1

        expect_failure(
            args.cli,
            "extract-erofs-file",
            primary,
            "large.bin" if primary != fixture else "big.bin",
            temp / "limited.out",
            1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        original = primary.read_bytes()
        bad_magic = bytearray(original)
        bad_magic[1024:1028] = b"bad!"
        bad_checksum = bytearray(original)
        bad_checksum[1024 + 20] ^= 1
        bad_feature = bytearray(original)
        bad_feature[1024 + 80 : 1024 + 84] = struct.pack("<I", 0x8000_0000)
        malformed_cases = [
            ("truncated", original[:1024], "TruncatedFrame"),
            ("bad-magic", bytes(bad_magic), "InvalidMagic"),
            ("bad-checksum", bytes(bad_checksum), "ChecksumMismatch"),
            ("bad-feature", bytes(bad_feature), "UnsupportedErofsFeature"),
        ]
        for name, data, error_name in malformed_cases:
            image = temp / f"{name}.erofs"
            image.write_bytes(data)
            expect_failure(args.cli, "list-erofs-file", image, error_name=error_name)
            malformed += 1
        if len(original) > 4096 + 16:
            corrupt_data = bytearray(original)
            corrupt_data[4096 + 8] ^= 0x5A
            corrupt_image = temp / "corrupt-data.erofs"
            corrupt_image.write_bytes(corrupt_data)
            expect_failure(
                args.cli,
                "extract-erofs-file",
                corrupt_image,
                "large.bin" if primary != fixture else "big.bin",
                temp / "corrupt-data.out",
                512 * 1024 * 1024,
            )
            malformed += 1
        expect_failure(
            args.cli,
            "extract-erofs-file",
            primary,
            "missing/path",
            temp / "missing.out",
            1024,
            error_name="ErofsEntryNotFound",
        )
        malformed += 1

    print(
        f"fixture_cases={fixture_cases} tools={mkfs is not None} "
        f"plain={plain_cases} lz4={lz4_cases} modern={modern_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
