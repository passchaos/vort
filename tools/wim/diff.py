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
    result = subprocess.run(
        [str(arg) for arg in args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {args}\n"
            f"stdout: {result.stdout.decode(errors='replace')}\n"
            f"stderr: {result.stderr.decode(errors='replace')}"
        )
    return result


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


def resource_header(size: int, flags: int, offset: int, decoded_size: int) -> bytes:
    if size >= 1 << 56:
        raise AssertionError("synthetic WIM resource too large")
    return size.to_bytes(7, "little") + bytes([flags]) + struct.pack(
        "<QQ", offset, decoded_size
    )


def build_encrypted_raw_wim(metadata_input: bytes, xml: bytes, raw: bytes) -> bytes:
    metadata = bytearray(metadata_input)
    stored_security_length = struct.unpack_from("<I", metadata, 0)[0]
    root_offset = 8 if stored_security_length == 0 else (stored_security_length + 7) & ~7
    first_directory = struct.unpack_from("<Q", metadata, root_offset + 16)[0]
    child_directory = struct.unpack_from("<Q", metadata, first_directory + 16)[0]
    file_offset = child_directory
    attributes = struct.unpack_from("<I", metadata, file_offset + 8)[0]
    struct.pack_into("<I", metadata, file_offset + 8, attributes | 0x00004000)
    raw_hash = hashlib.sha1(raw).digest()
    metadata[file_offset + 64 : file_offset + 84] = raw_hash
    metadata_hash = hashlib.sha1(metadata).digest()

    header_size = 208
    raw_offset = header_size
    metadata_offset = raw_offset + len(raw)
    lookup_offset = metadata_offset + len(metadata)
    lookup_size = 2 * 50
    xml_offset = lookup_offset + lookup_size
    raw_resource = resource_header(len(raw), 0, raw_offset, len(raw))
    metadata_resource = resource_header(
        len(metadata), 0x02, metadata_offset, len(metadata)
    )
    lookup = (
        metadata_resource
        + struct.pack("<HI", 1, 1)
        + metadata_hash
        + raw_resource
        + struct.pack("<HI", 1, 1)
        + raw_hash
    )
    header = bytearray(header_size)
    header[0:8] = b"MSWIM\0\0\0"
    struct.pack_into("<I", header, 8, header_size)
    struct.pack_into("<I", header, 12, 0x00010D00)
    header[24:40] = bytes.fromhex("00112233445566778899aabbccddeeff")
    struct.pack_into("<HHI", header, 40, 1, 1, 1)
    header[48:72] = resource_header(len(lookup), 0x02, lookup_offset, len(lookup))
    header[72:96] = resource_header(len(xml), 0x02, xml_offset, len(xml))
    return bytes(header) + raw + bytes(metadata) + lookup + xml


def verify_vort(
    cli: Path,
    image: Path,
    compression: str,
    payloads: dict[str, bytes],
    temp: Path,
    verify_resources: bool = True,
    layout: str = "standard",
) -> None:
    listing = run(cli, "list-wim-file", image).stdout
    if f"compression={compression}".encode() not in listing:
        raise AssertionError(f"WIM compression mismatch: {listing!r}")
    if f"layout={layout}".encode() not in listing:
        raise AssertionError(f"WIM layout mismatch: {listing!r}")
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
    pipable_stream_cases = 0
    encrypted_raw_cases = 0
    encrypted_esd_cases = 0
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

        metadata_out = temp / "fixture-metadata.bin"
        run(
            args.cli,
            "extract-wim-resource",
            fixture,
            "c5071b9147d869a9e7b5efc3e64e7e536e3d64fd",
            metadata_out,
            4096,
        )
        fixture_xml = temp / "fixture.xml"
        run(args.cli, "extract-wim-xml", fixture, fixture_xml, 4096)
        encrypted_raw = b"opaque MS-EFSR EFSRPC raw payload\x00\x01\x02"
        encrypted_image = temp / "encrypted-raw.wim"
        encrypted_image.write_bytes(
            build_encrypted_raw_wim(
                metadata_out.read_bytes(),
                fixture_xml.read_bytes(),
                encrypted_raw,
            )
        )
        encrypted_listing = run(
            args.cli, "list-wim-image", encrypted_image, 1
        ).stdout
        if b"encrypted\t/nested/file.txt" not in encrypted_listing:
            raise AssertionError("synthetic EFSRPC encrypted entry not listed")
        encrypted_out = temp / "encrypted-raw.out"
        run(
            args.cli,
            "extract-wim-encrypted-raw",
            encrypted_image,
            1,
            "/nested/file.txt",
            encrypted_out,
            len(encrypted_raw),
        )
        if encrypted_out.read_bytes() != encrypted_raw:
            raise AssertionError("synthetic EFSRPC raw export mismatch")
        expect_failure(
            args.cli,
            "extract-wim-encrypted-raw",
            encrypted_image,
            1,
            "/nested/file.txt",
            temp / "encrypted-raw-limited.out",
            len(encrypted_raw) - 1,
            error_name="OutputLimitExceeded",
        )
        expect_failure(
            args.cli,
            "extract-wim-path",
            encrypted_image,
            1,
            "/nested/file.txt",
            temp / "encrypted-plaintext.out",
            len(encrypted_raw),
            error_name="UnsupportedWimFile",
        )
        expect_failure(
            args.cli,
            "extract-wim-encrypted-raw",
            fixture,
            1,
            "/nested/file.txt",
            temp / "not-encrypted-raw.out",
            1024,
            error_name="WimNotEncryptedFile",
        )
        encrypted_raw_cases += 1

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

        encrypted_esd = temp / "encrypted-segments.esd"
        encrypted_esd.write_bytes(
            base64.b64decode(
                Path("src/wim/testdata/encrypted-esd-small.esd.b64").read_text()
            )
        )
        encrypted_esd_private = temp / "encrypted-esd-private.blob"
        encrypted_esd_private.write_bytes(
            base64.b64decode(
                Path(
                    "src/wim/testdata/encrypted-esd-test-private.blob.b64"
                ).read_text()
            )
        )
        encrypted_esd_info = run(
            args.cli, "inspect-wim-encrypted-esd", encrypted_esd
        ).stdout
        if b"wrapped_key_bytes=256 ranges=1" not in encrypted_esd_info:
            raise AssertionError("encrypted ESD info mismatch")
        decrypted_esd = temp / "decrypted-private.esd"
        run(
            args.cli,
            "decrypt-wim-encrypted-esd",
            encrypted_esd,
            encrypted_esd_private,
            decrypted_esd,
            encrypted_esd.stat().st_size,
        )
        decrypted_esd_key = temp / "decrypted-key.esd"
        run(
            args.cli,
            "decrypt-wim-encrypted-esd-key",
            encrypted_esd,
            "000102030405060708090a0b0c0d0e0f"
            "101112131415161718191a1b1c1d1e1f",
            decrypted_esd_key,
            encrypted_esd.stat().st_size,
        )
        if decrypted_esd.read_bytes() != decrypted_esd_key.read_bytes():
            raise AssertionError("private-key and direct-key ESD outputs differ")
        decrypted_payload = temp / "decrypted-esd-payload.out"
        run(
            args.cli,
            "extract-wim-resource",
            decrypted_esd,
            "0613af950acadbb268fb9b7d1b58f3ec5ca57101",
            decrypted_payload,
            32,
        )
        expected_decrypted_payload = bytes.fromhex(
            "6bc1bee22e409f96e93d7e117393172a"
            "ae2d8a571e03ac9c9eb76fac45af8e51"
        )
        if decrypted_payload.read_bytes() != expected_decrypted_payload:
            raise AssertionError("encrypted ESD decrypted payload mismatch")
        expect_failure(
            args.cli,
            "decrypt-wim-encrypted-esd",
            encrypted_esd,
            encrypted_esd_private,
            temp / "encrypted-esd-limited.out",
            decrypted_esd.stat().st_size - 1,
            error_name="OutputLimitExceeded",
        )
        invalid_private = bytearray(encrypted_esd_private.read_bytes())
        invalid_private[8] ^= 1
        invalid_private_path = temp / "invalid-private.blob"
        invalid_private_path.write_bytes(invalid_private)
        expect_failure(
            args.cli,
            "decrypt-wim-encrypted-esd",
            encrypted_esd,
            invalid_private_path,
            temp / "encrypted-esd-invalid-key.out",
            encrypted_esd.stat().st_size,
            error_name="InvalidPrivateKeyBlob",
        )
        encrypted_esd_cases += 3

        pipable_fixture = temp / "fixture-pipable.wim"
        pipable_fixture.write_bytes(
            base64.b64decode(
                Path("src/wim/testdata/pipable-xpress.wim.b64").read_text()
            )
        )
        pipable_listing = run(args.cli, "list-wim-file", pipable_fixture).stdout
        if b"layout=pipable compression=xpress" not in pipable_listing:
            raise AssertionError("checked-in pipable WIM header mismatch")
        pipable_out = temp / "fixture-pipable.out"
        run(
            args.cli,
            "extract-wim-path",
            pipable_fixture,
            1,
            "/nested/payload.txt",
            pipable_out,
            len(lzms_expected),
        )
        if pipable_out.read_bytes() != lzms_expected:
            raise AssertionError("checked-in pipable WIM path mismatch")
        pipable_stream_out = temp / "fixture-pipable-stream.out"
        run(
            args.cli,
            "extract-wim-pipable-stream-path",
            pipable_fixture,
            1,
            "/nested/payload.txt",
            pipable_stream_out,
            len(lzms_expected),
            1,
            3,
        )
        if pipable_stream_out.read_bytes() != lzms_expected:
            raise AssertionError("checked-in pipable stream path mismatch")
        pipable_stream_cases += 1
        fixture_cases += 1
        bad_pipable_tail = bytearray(pipable_fixture.read_bytes())
        bad_pipable_tail[-208] ^= 1
        bad_pipable_tail_path = temp / "bad-pipable-tail.wim"
        bad_pipable_tail_path.write_bytes(bad_pipable_tail)
        expect_failure(
            args.cli,
            "list-wim-file",
            bad_pipable_tail_path,
            error_name="InvalidWim",
        )
        malformed += 1
        bad_pipable_lead = bytearray(pipable_fixture.read_bytes())
        bad_pipable_lead[48] = 1
        bad_pipable_lead_path = temp / "bad-pipable-lead.wim"
        bad_pipable_lead_path.write_bytes(bad_pipable_lead)
        expect_failure(
            args.cli,
            "list-wim-file",
            bad_pipable_lead_path,
            error_name="InvalidWim",
        )
        malformed += 1

        source = temp / "tree"
        payloads = write_tree(source)
        if wimlib is not None:
            encrypted_result = run(wimlib, "info", encrypted_esd, check=False)
            if encrypted_result.returncode == 0 or b"encrypted" not in encrypted_result.stderr.lower():
                raise AssertionError(
                    "wimlib did not reject encrypted ESD segments: "
                    f"returncode={encrypted_result.returncode} "
                    f"stdout={encrypted_result.stdout!r} stderr={encrypted_result.stderr!r}"
                )
            run(wimlib, "verify", decrypted_esd)
            encrypted_esd_cases += 2
            run(wimlib, "verify", encrypted_image)
            encrypted_details = run(
                wimlib, "dir", encrypted_image, 1, "--detailed"
            ).stdout
            if b"Raw encrypted data stream" not in encrypted_details:
                raise AssertionError("wimlib did not recognize EFSRPC raw stream")
            encrypted_raw_cases += 1
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

                pipable_image = temp / f"pipable-{expected_name}.wim"
                run(
                    wimlib,
                    "capture",
                    source,
                    pipable_image,
                    "test",
                    f"--compress={cli_name}",
                    "--pipable",
                    "--no-acls",
                )
                run(wimlib, "verify", pipable_image)
                verify_vort(
                    args.cli,
                    pipable_image,
                    expected_name,
                    payloads,
                    temp,
                    layout="pipable",
                )
                pipable_stream_out = temp / f"pipable-stream-{expected_name}.out"
                run(
                    args.cli,
                    "extract-wim-pipable-stream-path",
                    pipable_image,
                    1,
                    "/large.bin",
                    pipable_stream_out,
                    len(payloads["large.bin"]),
                    7,
                    11,
                )
                if pipable_stream_out.read_bytes() != payloads["large.bin"]:
                    raise AssertionError(
                        f"pipable stream extraction mismatch for {expected_name}"
                    )
                pipable_stream_cases += 1
                pipable_empty_out = temp / f"pipable-stream-empty-{expected_name}.out"
                run(
                    args.cli,
                    "extract-wim-pipable-stream-path",
                    pipable_image,
                    1,
                    "/empty.bin",
                    pipable_empty_out,
                    0,
                    5,
                    7,
                )
                if pipable_empty_out.read_bytes() != b"":
                    raise AssertionError(
                        f"pipable empty stream mismatch for {expected_name}"
                    )
                pipable_stream_cases += 1
                pipable_reparse_out = temp / f"pipable-stream-reparse-{expected_name}.out"
                run(
                    args.cli,
                    "extract-wim-pipable-stream-path",
                    pipable_image,
                    1,
                    "/nested/config-link",
                    pipable_reparse_out,
                    4096,
                    9,
                    13,
                    "reparse",
                )
                if pipable_reparse_out.read_bytes() != reparse_bytes:
                    raise AssertionError(
                        f"pipable reparse stream mismatch for {expected_name}"
                    )
                pipable_stream_cases += 1
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
            if (
                b"wim_version=0xe00" not in solid_listing
                or b"layout=standard compression=lzms" not in solid_listing
            ):
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

            pipable_split_input = temp / "pipable-split-input.wim"
            run(
                wimlib,
                "capture",
                split_source,
                pipable_split_input,
                "split",
                "--compress=XPRESS",
                "--pipable",
                "--no-acls",
            )
            pipable_first = temp / "pipable-split.swm"
            run(wimlib, "split", pipable_split_input, pipable_first, 1)
            pipable_second = temp / "pipable-split2.swm"
            pipable_set_output = temp / "pipable-split-set-path.out"
            run(
                args.cli,
                "extract-wim-parts-path",
                1,
                "/large.bin",
                pipable_set_output,
                len(split_payload),
                pipable_first,
                pipable_second,
            )
            if pipable_set_output.read_bytes() != split_payload:
                raise AssertionError("pipable SWM set cross-part extraction mismatch")
            pipable_concat = temp / "pipable-split-concatenated.wim"
            pipable_concat.write_bytes(
                pipable_first.read_bytes() + pipable_second.read_bytes()
            )
            pipable_stream_output = temp / "pipable-split-stream-path.out"
            run(
                args.cli,
                "extract-wim-pipable-stream-path",
                pipable_concat,
                1,
                "/large.bin",
                pipable_stream_output,
                len(split_payload),
                13,
                17,
            )
            if pipable_stream_output.read_bytes() != split_payload:
                raise AssertionError("pipable concatenated stream extraction mismatch")
            pipable_stream_cases += 1
            expect_failure(
                args.cli,
                "extract-wim-pipable-stream-path",
                pipable_first,
                1,
                "/large.bin",
                temp / "pipable-missing-part.out",
                len(split_payload),
                13,
                17,
                error_name="TruncatedFrame",
            )
            pipable_reversed = temp / "pipable-split-reversed.wim"
            pipable_reversed.write_bytes(
                pipable_second.read_bytes() + pipable_first.read_bytes()
            )
            expect_failure(
                args.cli,
                "extract-wim-pipable-stream-path",
                pipable_reversed,
                1,
                "/large.bin",
                temp / "pipable-reversed-part.out",
                len(split_payload),
                13,
                17,
                error_name="InvalidWim",
            )
            malformed += 2
            split_cases += 1

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
        f"split={split_cases} reparse={reparse_cases} "
        f"pipable_stream={pipable_stream_cases} encrypted_raw={encrypted_raw_cases} "
        f"encrypted_esd={encrypted_esd_cases} stream_errors={stream_error_cases} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
