#!/usr/bin/env python3
import argparse
import base64
import hashlib
import random
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


def expect_failure(*args: object, error_name: str) -> None:
    result = run(*args, check=False)
    if result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {args}")
    if error_name.encode() not in result.stderr:
        raise AssertionError(
            f"missing {error_name}: {result.stderr.decode(errors='replace')}"
        )


def write_tree(root: Path) -> dict[str, bytes]:
    (root / "nested").mkdir(parents=True)
    rng = random.Random(0x5749_4D)
    payloads = {
        "nested/config.txt": b"WIM nested configuration\n",
        "nested/emoji-😀.txt": "UTF-16LE path round trip 文件\n".encode(),
        "large.bin": (b"WIM multi-chunk payload 0123456789\n" * 5000)[:150_000],
        "random.bin": rng.randbytes(70_000),
        "empty.bin": b"",
    }
    for name, data in payloads.items():
        (root / name).write_bytes(data)
    (root / "nested/config-link").symlink_to("config.txt")
    return payloads


def verify_vort(
    cli: Path,
    image: Path,
    compression: str,
    payloads: dict[str, bytes],
    temp: Path,
    verify_resources: bool = True,
) -> None:
    listing = run(cli, "list-wim-file", image).stdout
    if f"compression={compression}".encode() not in listing:
        raise AssertionError(f"WIM compression mismatch: {listing!r}")
    image_listing = run(cli, "list-wim-image", image, 1).stdout
    for name, expected in payloads.items():
        digest = hashlib.sha1(expected).hexdigest()
        if f"/{name}".encode() not in image_listing:
            raise AssertionError(f"WIM image listing missing {name}")
        if expected and verify_resources:
            if digest.encode() not in listing:
                raise AssertionError(f"WIM lookup missing {name}/{digest}")
            output = temp / f"{compression}-{name.replace('/', '-')}.out"
            run(cli, "extract-wim-resource", image, digest, output, len(expected))
            if output.read_bytes() != expected:
                raise AssertionError(
                    f"WIM extraction mismatch for {compression}/{name}"
                )
        path_output = temp / f"{compression}-path-{name.replace('/', '-')}.out"
        run(cli, "extract-wim-path", image, 1, f"/{name}", path_output, len(expected))
        if path_output.read_bytes() != expected:
            raise AssertionError(
                f"WIM path extraction mismatch for {compression}/{name}"
            )
    xml = temp / f"{compression}.xml"
    run(cli, "extract-wim-xml", image, xml, 16 * 1024 * 1024)
    if b"<WIM>" not in xml.read_bytes().replace(b"\x00", b""):
        raise AssertionError(f"WIM XML mismatch for {compression}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--wimlib-imagex", type=Path)
    args = parser.parse_args()
    wimlib = args.wimlib_imagex or (
        Path(found) if (found := shutil.which("wimlib-imagex")) else None
    )

    fixture_cases = 0
    codec_cases = 0
    image_cases = 0
    solid_cases = 0
    split_cases = 0
    reparse_cases = 0
    stream_error_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-wim-") as temp_text:
        temp = Path(temp_text)
        fixture = temp / "fixture.wim"
        fixture.write_bytes(
            base64.b64decode(Path("src/wim/testdata/xpress-small.wim.b64").read_text())
        )
        fixture_out = temp / "fixture.out"
        fixture_hash = "a541b150d52c83c6e19004c5239d228ccdad70ba"
        run(args.cli, "extract-wim-resource", fixture, fixture_hash, fixture_out, 1024)
        if fixture_out.read_bytes() != b"hello WIM XPRESS payload\n":
            raise AssertionError("checked-in WIM fixture mismatch")
        fixture_listing = run(args.cli, "list-wim-image", fixture, 1).stdout
        if b"/nested/file.txt" not in fixture_listing:
            raise AssertionError("checked-in WIM image tree mismatch")
        fixture_path_out = temp / "fixture-path.out"
        run(
            args.cli,
            "extract-wim-path",
            fixture,
            1,
            "/nested/file.txt",
            fixture_path_out,
            1024,
        )
        if fixture_path_out.read_bytes() != b"hello WIM XPRESS payload\n":
            raise AssertionError("checked-in WIM path extraction mismatch")
        fixture_cases += 1

        lzms_fixture = temp / "fixture.esd"
        lzms_fixture.write_bytes(
            base64.b64decode(Path("src/wim/testdata/lzms-small.esd.b64").read_text())
        )
        lzms_expected = Path("src/lzms/testdata/lzms-small.txt").read_bytes()
        lzms_fixture_out = temp / "fixture-lzms.out"
        run(
            args.cli,
            "extract-wim-path",
            lzms_fixture,
            1,
            "/nested/lzms.txt",
            lzms_fixture_out,
            len(lzms_expected),
        )
        if lzms_fixture_out.read_bytes() != lzms_expected:
            raise AssertionError("checked-in solid LZMS ESD fixture mismatch")
        fixture_cases += 1

        source = temp / "tree"
        payloads = write_tree(source)
        if wimlib is not None:
            rng = random.Random(0x5357_4D)
            for cli_name, expected_name in (
                ("none", "none"),
                ("XPRESS", "xpress"),
                ("LZX", "lzx"),
            ):
                image = temp / f"{expected_name}.wim"
                run(
                    wimlib,
                    "capture",
                    source,
                    image,
                    "test",
                    f"--compress={cli_name}",
                    "--no-acls",
                )
                run(wimlib, "verify", image)
                verify_vort(args.cli, image, expected_name, payloads, temp)
                image_tree = run(args.cli, "list-wim-image", image, 1).stdout
                if b"reparse\t/nested/config-link" not in image_tree:
                    raise AssertionError("WIM symlink reparse entry was not listed")
                reparse_output = temp / f"{expected_name}-reparse.bin"
                run(
                    args.cli,
                    "extract-wim-reparse",
                    image,
                    1,
                    "/nested/config-link",
                    reparse_output,
                    4096,
                )
                reparse_bytes = reparse_output.read_bytes()
                if not reparse_bytes or "config.txt".encode("utf-16le") not in reparse_bytes:
                    raise AssertionError("WIM symlink reparse payload mismatch")
                reparse_cases += 1
                reference = temp / f"wimlib-{expected_name}"
                run(wimlib, "extract", image, 1, f"--dest-dir={reference}")
                for name, expected in payloads.items():
                    if (reference / name).read_bytes() != expected:
                        raise AssertionError(
                            f"wimlib path extraction mismatch for {expected_name}/{name}"
                        )
                link = reference / "nested/config-link"
                if not link.is_symlink() or link.readlink() != Path("config.txt"):
                    raise AssertionError("wimlib symlink restoration mismatch")
                codec_cases += 1

            first_source = temp / "first-image"
            second_source = temp / "second-image"
            first_source.mkdir()
            second_source.mkdir()
            (first_source / "shared.txt").write_bytes(b"first WIM image\n")
            (second_source / "shared.txt").write_bytes(b"second WIM image\n")
            multi = temp / "multi.wim"
            run(
                wimlib,
                "capture",
                first_source,
                multi,
                "first",
                "--compress=XPRESS",
                "--no-acls",
            )
            run(wimlib, "append", second_source, multi, "second", "--no-acls")
            run(wimlib, "verify", multi)
            for image_index, expected in (
                (1, b"first WIM image\n"),
                (2, b"second WIM image\n"),
            ):
                output = temp / f"multi-{image_index}.out"
                run(
                    args.cli,
                    "extract-wim-path",
                    multi,
                    image_index,
                    "/shared.txt",
                    output,
                    1024,
                )
                if output.read_bytes() != expected:
                    raise AssertionError(f"WIM image mapping mismatch for {image_index}")
                image_cases += 1

            solid = temp / "solid.esd"
            run(
                wimlib,
                "capture",
                source,
                solid,
                "test",
                "--compress=LZMS",
                "--solid",
                "--solid-chunk-size=32768",
                "--no-acls",
            )
            solid_listing = run(args.cli, "list-wim-file", solid).stdout
            if b"wim_version=0xe00 compression=lzms" not in solid_listing:
                raise AssertionError("solid ESD header mismatch")
            verify_vort(
                args.cli,
                solid,
                "lzms",
                payloads,
                temp,
                verify_resources=False,
            )
            solid_reference = temp / "wimlib-solid"
            run(wimlib, "extract", solid, 1, f"--dest-dir={solid_reference}")
            for name, expected in payloads.items():
                if (solid_reference / name).read_bytes() != expected:
                    raise AssertionError(f"wimlib solid extraction mismatch for {name}")
            solid_cases += 1

            split_source = temp / "split-tree"
            split_source.mkdir()
            split_payload = rng.randbytes(1_300_000)
            (split_source / "large.bin").write_bytes(split_payload)
            split_input = temp / "split-input.wim"
            run(
                wimlib,
                "capture",
                split_source,
                split_input,
                "split",
                "--compress=XPRESS",
                "--no-acls",
            )
            first_part = temp / "split.swm"
            run(wimlib, "split", split_input, first_part, 1)
            second_part = temp / "split2.swm"
            first_listing = run(args.cli, "list-wim-file", first_part).stdout
            second_listing = run(args.cli, "list-wim-file", second_part).stdout
            if b"part=1/2" not in first_listing or b"part=2/2" not in second_listing:
                raise AssertionError("split SWM header mismatch")
            split_tree = run(args.cli, "list-wim-image", first_part, 1).stdout
            if b"/large.bin" not in split_tree:
                raise AssertionError("split SWM metadata tree mismatch")
            expect_failure(
                args.cli,
                "list-wim-image",
                second_part,
                1,
                error_name="WimResourceInOtherPart",
            )
            expect_failure(
                args.cli,
                "extract-wim-path",
                first_part,
                1,
                "/large.bin",
                temp / "split-path.out",
                len(split_payload),
                error_name="WimResourceInOtherPart",
            )
            set_tree = run(
                args.cli,
                "list-wim-parts-image",
                1,
                first_part,
                second_part,
            ).stdout
            if b"/large.bin" not in set_tree or b"parts=2" not in set_tree:
                raise AssertionError("SWM set metadata tree mismatch")
            set_output = temp / "split-set-path.out"
            run(
                args.cli,
                "extract-wim-parts-path",
                1,
                "/large.bin",
                set_output,
                len(split_payload),
                first_part,
                second_part,
            )
            if set_output.read_bytes() != split_payload:
                raise AssertionError("SWM set cross-part extraction mismatch")
            expect_failure(
                args.cli,
                "list-wim-parts-image",
                1,
                first_part,
                error_name="InvalidWimSet",
            )
            expect_failure(
                args.cli,
                "list-wim-parts-image",
                1,
                second_part,
                first_part,
                error_name="InvalidWimSet",
            )
            split_cases += 6

        original = fixture.read_bytes()
        malformed_cases = []
        bad_magic = bytearray(original)
        bad_magic[0:8] = b"not-wim!"
        malformed_cases.append(("bad-magic", bytes(bad_magic), "InvalidMagic"))
        bad_header = bytearray(original)
        bad_header[8:12] = struct.pack("<I", 96)
        malformed_cases.append(("bad-header", bytes(bad_header), "InvalidWim"))
        bad_version = bytearray(original)
        bad_version[12:16] = struct.pack("<I", 0xDEAD)
        malformed_cases.append(
            ("bad-version", bytes(bad_version), "UnsupportedWimVersion")
        )
        bad_chunk = bytearray(original)
        bad_chunk[20:24] = struct.pack("<I", 12345)
        malformed_cases.append(("bad-chunk", bytes(bad_chunk), "InvalidWim"))
        for name, data, error_name in malformed_cases:
            path = temp / f"{name}.wim"
            path.write_bytes(data)
            expect_failure(args.cli, "list-wim-file", path, error_name=error_name)
            malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-resource",
            fixture,
            fixture_hash,
            temp / "limited.out",
            24,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-stream",
            fixture,
            1,
            "/nested/file.txt",
            "missing",
            temp / "missing-stream.out",
            1024,
            error_name="WimStreamNotFound",
        )
        stream_error_cases += 1
        expect_failure(
            args.cli,
            "extract-wim-reparse",
            fixture,
            1,
            "/nested/file.txt",
            temp / "not-reparse.out",
            1024,
            error_name="WimNotReparsePoint",
        )
        stream_error_cases += 1
        expect_failure(
            args.cli,
            "extract-wim-path",
            fixture,
            1,
            "/nested/missing.txt",
            temp / "missing-path.out",
            1024,
            error_name="WimPathNotFound",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-path",
            fixture,
            1,
            "/nested",
            temp / "directory.out",
            1024,
            error_name="WimNotRegularFile",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-path",
            fixture,
            2,
            "/nested/file.txt",
            temp / "missing-image.out",
            1024,
            error_name="WimImageNotFound",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-path",
            fixture,
            1,
            "/nested/file.txt",
            temp / "limited-path.out",
            24,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "extract-wim-resource",
            fixture,
            "00" * 20,
            temp / "missing.out",
            1024,
            error_name="WimResourceNotFound",
        )
        malformed += 1

    print(
        f"fixture={fixture_cases} wimlib={wimlib is not None} "
        f"codecs={codec_cases} images={image_cases} solid={solid_cases} "
        f"split={split_cases} reparse={reparse_cases} stream_errors={stream_error_cases} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
