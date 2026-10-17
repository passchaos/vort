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


def xorshift_bytes(seed: int, size: int) -> bytes:
    state = seed
    output = bytearray()
    for _ in range(size):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        output.append(state & 0xFF)
    return bytes(output)


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
    parser.add_argument("--writer", required=True, type=Path)
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
    writer_cases = 0
    writer_wimlib_cases = 0
    writer_stream_cases = 0
    writer_stream_wimlib_cases = 0
    writer_inode_cases = 0
    writer_inode_wimlib_cases = 0
    writer_multi_cases = 0
    writer_multi_wimlib_cases = 0
    writer_solid_cases = 0
    writer_solid_wimlib_cases = 0
    writer_append_cases = 0
    writer_append_wimlib_cases = 0
    writer_solid_append_cases = 0
    writer_solid_append_wimlib_cases = 0
    writer_reference_append_cases = 0
    writer_reference_append_wimlib_cases = 0
    writer_delete_cases = 0
    writer_delete_wimlib_cases = 0
    writer_solid_delete_cases = 0
    writer_solid_delete_wimlib_cases = 0
    writer_reference_delete_cases = 0
    writer_reference_delete_wimlib_cases = 0
    writer_replace_cases = 0
    writer_replace_wimlib_cases = 0
    writer_solid_replace_cases = 0
    writer_solid_replace_wimlib_cases = 0
    writer_reference_replace_cases = 0
    writer_reference_replace_wimlib_cases = 0
    writer_split_cases = 0
    writer_split_wimlib_cases = 0
    writer_pipable_cases = 0
    writer_pipable_wimlib_cases = 0
    writer_pipable_integrity_cases = 0
    writer_pipable_integrity_wimlib_cases = 0
    writer_pipable_split_cases = 0
    writer_pipable_split_wimlib_cases = 0
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
        writer_random = bytearray()
        writer_random_state = 0x5749_4D31
        for _ in range(70_000):
            writer_random_state ^= (writer_random_state << 13) & 0xFFFF_FFFF
            writer_random_state ^= writer_random_state >> 17
            writer_random_state ^= (writer_random_state << 5) & 0xFFFF_FFFF
            writer_random.append(writer_random_state & 0xFF)
        writer_payloads = {
            "nested/config.txt": b"Vort WIM writer interop\n",
            "large.bin": b"Vort WIM writer multichunk payload 0123456789\n"
            * 4096,
            "random.bin": bytes(writer_random),
            "empty.bin": b"",
            "unicode/文件.txt": "UTF-8 WIM path\n".encode(),
        }
        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            writer_image = temp / f"vort-writer-{writer_compression}.wim"
            run(args.writer, writer_image, writer_compression)
            verify_vort(
                args.cli,
                writer_image,
                expected_compression,
                writer_payloads,
                temp,
            )
            writer_cases += 1
            if wimlib is not None:
                run(wimlib, "verify", writer_image)
                writer_extract = temp / f"vort-writer-{writer_compression}-extract"
                run(
                    wimlib,
                    "extract",
                    writer_image,
                    1,
                    f"--dest-dir={writer_extract}",
                )
                for name, expected in writer_payloads.items():
                    if (writer_extract / name).read_bytes() != expected:
                        raise AssertionError(
                            "wimlib extraction mismatch for "
                            f"Vort writer {writer_compression}/{name}"
                        )
                writer_wimlib_cases += 1

        symlink_payload = struct.pack("<HHHHI", 0, 20, 22, 20, 1) + (
            "config.txt\0config.txt\0".encode("utf-16le")
        )
        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            stream_image = temp / f"vort-writer-streams-{writer_compression}.wim"
            run(args.writer, stream_image, writer_compression, "streams")
            stream_listing = run(args.cli, "list-wim-file", stream_image).stdout
            if f"compression={expected_compression}".encode() not in stream_listing:
                raise AssertionError("Vort writer stream compression mismatch")

            stream_default = temp / f"writer-stream-default-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-path",
                stream_image,
                1,
                "/streamed.txt",
                stream_default,
                1024,
            )
            if stream_default.read_bytes() != b"ordinary stream\n":
                raise AssertionError("Vort writer default stream mismatch")
            zone = temp / f"writer-stream-zone-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-stream",
                stream_image,
                1,
                "/streamed.txt",
                "Zone.Identifier",
                zone,
                1024,
            )
            if zone.read_bytes() != b"[ZoneTransfer]\r\nZoneId=3\r\n":
                raise AssertionError("Vort writer named stream mismatch")
            directory_ads = temp / f"writer-stream-directory-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-stream",
                stream_image,
                1,
                "/ads-dir",
                "directory.meta",
                directory_ads,
                1024,
            )
            if directory_ads.read_bytes() != b"directory alternate data":
                raise AssertionError("Vort writer directory ADS mismatch")
            reparse = temp / f"writer-stream-reparse-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-reparse",
                stream_image,
                1,
                "/link",
                reparse,
                1024,
            )
            if reparse.read_bytes() != symlink_payload:
                raise AssertionError("Vort writer reparse stream mismatch")
            encrypted_raw = temp / f"writer-stream-efs-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-encrypted-raw",
                stream_image,
                1,
                "/secret.dat",
                encrypted_raw,
                1024,
            )
            if encrypted_raw.read_bytes() != b"opaque EFSRPC raw file data":
                raise AssertionError("Vort writer EFSRPC stream mismatch")
            encrypted_directory = temp / f"writer-stream-efs-dir-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-encrypted-raw",
                stream_image,
                1,
                "/encrypted-dir",
                encrypted_directory,
                1024,
            )
            if encrypted_directory.read_bytes() != b"opaque EFSRPC raw directory data":
                raise AssertionError("Vort writer directory EFSRPC stream mismatch")
            writer_stream_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", stream_image)
                details = run(wimlib, "dir", stream_image, 1, "--detailed").stdout
                for marker in (
                    b'Named data stream "Zone.Identifier"',
                    b"Reparse point stream:",
                    b"Raw encrypted data stream:",
                ):
                    if marker not in details:
                        raise AssertionError(
                            f"wimlib did not recognize Vort writer stream {marker!r}"
                        )
                link_extract = temp / f"writer-stream-link-{writer_compression}"
                run(
                    wimlib,
                    "extract",
                    stream_image,
                    1,
                    "/link",
                    f"--dest-dir={link_extract}",
                )
                link = link_extract / "link"
                if not link.is_symlink() or link.readlink() != Path("config.txt"):
                    raise AssertionError("wimlib did not restore Vort writer symlink")
                writer_stream_wimlib_cases += 1

        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            inode_image = temp / f"vort-writer-inode-{writer_compression}.wim"
            run(args.writer, inode_image, writer_compression, "inode")
            inode_listing = run(args.cli, "list-wim-file", inode_image).stdout
            if f"compression={expected_compression}".encode() not in inode_listing:
                raise AssertionError("Vort writer inode compression mismatch")
            image_tree = run(args.cli, "list-wim-image", inode_image, 1).stdout
            for required in (b"/hard/a.txt", b"/hard/b.txt", b"/independent.txt"):
                if required not in image_tree:
                    raise AssertionError(f"Vort writer inode tree missing {required!r}")
            for link_name in ("a.txt", "b.txt"):
                output = temp / f"writer-inode-{writer_compression}-{link_name}"
                run(
                    args.cli,
                    "extract-wim-path",
                    inode_image,
                    1,
                    f"/hard/{link_name}",
                    output,
                    1024,
                )
                if output.read_bytes() != b"hard linked writer payload\n":
                    raise AssertionError("Vort writer hard-link payload mismatch")
            writer_inode_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", inode_image)
                details = run(wimlib, "dir", inode_image, 1, "--detailed").stdout
                for marker in (
                    b"Link Group ID       = 0x0000000000004242",
                    b"Link Count          = 2",
                    b"Security Descriptor = 01000480",
                    b"Security Descriptor = 01000080",
                ):
                    if marker not in details:
                        raise AssertionError(
                            f"wimlib did not recognize Vort inode metadata {marker!r}"
                        )
                inode_extract = temp / f"writer-inode-extract-{writer_compression}"
                run(
                    wimlib,
                    "extract",
                    inode_image,
                    1,
                    f"--dest-dir={inode_extract}",
                    "--no-acls",
                )
                first = inode_extract / "hard/a.txt"
                second = inode_extract / "hard/b.txt"
                first_stat = first.stat()
                second_stat = second.stat()
                if (
                    first.read_bytes() != b"hard linked writer payload\n"
                    or second.read_bytes() != first.read_bytes()
                    or first_stat.st_ino != second_stat.st_ino
                    or first_stat.st_nlink < 2
                ):
                    raise AssertionError("wimlib did not restore Vort hard links")
                writer_inode_wimlib_cases += 1

        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            multi_image = temp / f"vort-writer-multi-{writer_compression}.wim"
            run(args.writer, multi_image, writer_compression, "multi")
            multi_listing = run(args.cli, "list-wim-file", multi_image).stdout
            if (
                f"compression={expected_compression}".encode() not in multi_listing
                or b"images=4" not in multi_listing
            ):
                raise AssertionError("Vort writer multi-image header mismatch")
            for image_index, unique_name, unique_payload in (
                (1, "first.txt", b"first image payload\n"),
                (2, "second.txt", b"second image payload\n"),
            ):
                unique_output = temp / (
                    f"writer-multi-{writer_compression}-{unique_name}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    multi_image,
                    image_index,
                    f"/{unique_name}",
                    unique_output,
                    1024,
                )
                if unique_output.read_bytes() != unique_payload:
                    raise AssertionError("Vort writer multi-image mapping mismatch")
                shared_output = temp / (
                    f"writer-multi-{writer_compression}-shared-{image_index}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    multi_image,
                    image_index,
                    "/shared.txt",
                    shared_output,
                    1024,
                )
                if shared_output.read_bytes() != b"shared multi-image payload\n":
                    raise AssertionError("Vort writer cross-image blob mismatch")
            for image_index in (3, 4):
                empty_tree = run(
                    args.cli,
                    "list-wim-image",
                    multi_image,
                    image_index,
                ).stdout
                if empty_tree != (
                    f"image={image_index} security_descriptors=0\n".encode()
                ):
                    raise AssertionError("Vort writer empty image mismatch")
            writer_multi_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", multi_image)
                info = run(wimlib, "info", multi_image).stdout
                for marker in (
                    b"Image Count:    4",
                    b"Boot Index:     2",
                    b"Name:                   first",
                    b"Name:                   second",
                    b"Name:                   empty-a",
                    b"Name:                   empty-b",
                ):
                    if marker not in info:
                        raise AssertionError(
                            f"wimlib did not recognize Vort multi-image {marker!r}"
                        )
                for image_index, unique_name, unique_payload in (
                    (1, "first.txt", b"first image payload\n"),
                    (2, "second.txt", b"second image payload\n"),
                ):
                    destination = temp / (
                        f"writer-multi-wimlib-{writer_compression}-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        multi_image,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes() != unique_payload
                        or (destination / "shared.txt").read_bytes()
                        != b"shared multi-image payload\n"
                    ):
                        raise AssertionError("wimlib multi-image extraction mismatch")
                writer_multi_wimlib_cases += 1

        solid_image = temp / "vort-writer-solid-lzms.esd"
        run(args.writer, solid_image, "lzms", "solid")
        solid_listing = run(args.cli, "list-wim-file", solid_image).stdout
        for marker in (b"compression=lzms", b"images=2"):
            if marker not in solid_listing:
                raise AssertionError(
                    f"Vort solid writer header missing {marker!r}"
                )
        solid_phrase = b"Vort solid LZMS writer payload 0123456789\n"
        solid_repeated = (solid_phrase * (70_000 // len(solid_phrase) + 1))[
            :70_000
        ]
        solid_random = xorshift_bytes(0x534F_4C49, 70_000)
        solid_shared = b"shared packed LZMS stream\n" * 1024
        for image_index, path, expected in (
            (1, "/repeat.bin", solid_repeated),
            (1, "/shared.bin", solid_shared),
            (2, "/random.bin", solid_random),
            (2, "/shared.bin", solid_shared),
        ):
            output = temp / (
                f"writer-solid-{image_index}-{path[1:].replace('/', '-')}"
            )
            run(
                args.cli,
                "extract-wim-path",
                solid_image,
                image_index,
                path,
                output,
                len(expected),
            )
            if output.read_bytes() != expected:
                raise AssertionError("Vort solid LZMS extraction mismatch")
        writer_solid_cases += 1

        if wimlib is not None:
            run(wimlib, "verify", solid_image)
            for image_index, unique_name, expected in (
                (1, "repeat.bin", solid_repeated),
                (2, "random.bin", solid_random),
            ):
                destination = temp / f"writer-solid-wimlib-{image_index}"
                run(
                    wimlib,
                    "extract",
                    solid_image,
                    image_index,
                    f"--dest-dir={destination}",
                    "--no-acls",
                )
                if (
                    (destination / unique_name).read_bytes() != expected
                    or (destination / "shared.bin").read_bytes() != solid_shared
                ):
                    raise AssertionError("wimlib solid LZMS extraction mismatch")
            writer_solid_wimlib_cases += 1

        append_shared = b"shared appended WIM payload\n" * 1024
        append_old = b"old image payload\n" * 2048
        append_new = b"new image payload\n" * 2048
        for append_mode, expected_compression in (
            ("append", "xpress"),
            ("solid-append", "lzms"),
        ):
            append_image = temp / f"vort-writer-{append_mode}.wim"
            run(args.writer, append_image, expected_compression, append_mode)
            listing = run(args.cli, "list-wim-file", append_image).stdout
            for marker in (
                f"compression={expected_compression}".encode(),
                b"images=2",
            ):
                if marker not in listing:
                    raise AssertionError(
                        f"Vort appended WIM header missing {marker!r}"
                    )
            for image_index, path, expected in (
                (1, "/old.bin", append_old),
                (1, "/shared.bin", append_shared),
                (2, "/new.bin", append_new),
                (2, "/shared.bin", append_shared),
            ):
                output = temp / (
                    f"writer-{append_mode}-{image_index}-"
                    f"{path[1:].replace('/', '-')}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    append_image,
                    image_index,
                    path,
                    output,
                    len(expected),
                )
                if output.read_bytes() != expected:
                    raise AssertionError("Vort appended WIM extraction mismatch")
            if append_mode == "append":
                writer_append_cases += 1
            else:
                writer_solid_append_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", append_image)
                for image_index, unique_name, expected in (
                    (1, "old.bin", append_old),
                    (2, "new.bin", append_new),
                ):
                    destination = temp / (
                        f"writer-{append_mode}-wimlib-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        append_image,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes() != expected
                        or (destination / "shared.bin").read_bytes()
                        != append_shared
                    ):
                        raise AssertionError(
                            "wimlib appended WIM extraction mismatch"
                        )
                if append_mode == "append":
                    writer_append_wimlib_cases += 1
                else:
                    writer_solid_append_wimlib_cases += 1

        reference_append = temp / "vort-writer-reference-append.wim"
        run(
            args.writer,
            reference_append,
            "xpress",
            "append-existing",
            fixture,
        )
        reference_old = temp / "writer-reference-append-old.out"
        run(
            args.cli,
            "extract-wim-path",
            reference_append,
            1,
            "/nested/file.txt",
            reference_old,
            1024,
        )
        if reference_old.read_bytes() != b"hello WIM XPRESS payload\n":
            raise AssertionError("Vort reference append lost the old image")
        reference_new = temp / "writer-reference-append-new.out"
        reference_new_bytes = b"Vort appended to a wimlib archive\n"
        run(
            args.cli,
            "extract-wim-path",
            reference_append,
            2,
            "/added.txt",
            reference_new,
            len(reference_new_bytes),
        )
        if reference_new.read_bytes() != reference_new_bytes:
            raise AssertionError("Vort reference append new image mismatch")
        writer_reference_append_cases += 1
        if wimlib is not None:
            run(wimlib, "verify", reference_append)
            destination = temp / "writer-reference-append-wimlib"
            run(
                wimlib,
                "extract",
                reference_append,
                2,
                f"--dest-dir={destination}",
                "--no-acls",
            )
            if (destination / "added.txt").read_bytes() != reference_new_bytes:
                raise AssertionError("wimlib reference append mismatch")
            writer_reference_append_wimlib_cases += 1

        delete_shared = b"shared deleted WIM payload\n" * 1024
        delete_first = b"first remains after delete\n" * 1024
        delete_third = b"third becomes second\n" * 1024
        for delete_mode, expected_compression in (
            ("delete", "xpress"),
            ("solid-delete", "lzms"),
        ):
            delete_image = temp / f"vort-writer-{delete_mode}.wim"
            run(args.writer, delete_image, expected_compression, delete_mode)
            listing = run(args.cli, "list-wim-file", delete_image).stdout
            for marker in (
                f"compression={expected_compression}".encode(),
                b"images=2",
            ):
                if marker not in listing:
                    raise AssertionError(
                        f"Vort deleted WIM header missing {marker!r}"
                    )
            for image_index, path, expected in (
                (1, "/first.bin", delete_first),
                (1, "/shared.bin", delete_shared),
                (2, "/third.bin", delete_third),
                (2, "/shared.bin", delete_shared),
            ):
                output = temp / (
                    f"writer-{delete_mode}-{image_index}-"
                    f"{path[1:].replace('/', '-')}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    delete_image,
                    image_index,
                    path,
                    output,
                    len(expected),
                )
                if output.read_bytes() != expected:
                    raise AssertionError("Vort deleted WIM extraction mismatch")
            expect_failure(
                args.cli,
                "extract-wim-path",
                delete_image,
                2,
                "/deleted.bin",
                temp / f"writer-{delete_mode}-deleted.out",
                64 * 1024,
                error_name="WimPathNotFound",
            )
            if delete_mode == "delete":
                writer_delete_cases += 1
            else:
                writer_solid_delete_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", delete_image)
                for image_index, unique_name, expected in (
                    (1, "first.bin", delete_first),
                    (2, "third.bin", delete_third),
                ):
                    destination = temp / (
                        f"writer-{delete_mode}-wimlib-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        delete_image,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes() != expected
                        or (destination / "shared.bin").read_bytes()
                        != delete_shared
                    ):
                        raise AssertionError(
                            "wimlib deleted WIM extraction mismatch"
                        )
                if delete_mode == "delete":
                    writer_delete_wimlib_cases += 1
                else:
                    writer_solid_delete_wimlib_cases += 1

        reference_delete = temp / "vort-writer-reference-delete.wim"
        run(
            args.writer,
            reference_delete,
            "xpress",
            "delete-existing",
            fixture,
        )
        reference_survivor = temp / "writer-reference-delete-survivor.out"
        reference_survivor_bytes = b"surviving appended image\n"
        run(
            args.cli,
            "extract-wim-path",
            reference_delete,
            1,
            "/survivor.txt",
            reference_survivor,
            len(reference_survivor_bytes),
        )
        if reference_survivor.read_bytes() != reference_survivor_bytes:
            raise AssertionError("Vort reference delete survivor mismatch")
        writer_reference_delete_cases += 1
        if wimlib is not None:
            run(wimlib, "verify", reference_delete)
            destination = temp / "writer-reference-delete-wimlib"
            run(
                wimlib,
                "extract",
                reference_delete,
                1,
                f"--dest-dir={destination}",
                "--no-acls",
            )
            if (
                (destination / "survivor.txt").read_bytes()
                != reference_survivor_bytes
            ):
                raise AssertionError("wimlib reference delete mismatch")
            writer_reference_delete_wimlib_cases += 1

        replace_shared = b"shared replaced WIM payload\n" * 1024
        replace_first = b"first remains after replace\n" * 1024
        replace_new = b"new replacement image payload\n" * 1024
        replace_third = b"third remains after replace\n" * 1024
        for replace_mode, expected_compression in (
            ("replace", "xpress"),
            ("solid-replace", "lzms"),
        ):
            replace_image = temp / f"vort-writer-{replace_mode}.wim"
            run(args.writer, replace_image, expected_compression, replace_mode)
            listing = run(args.cli, "list-wim-file", replace_image).stdout
            for marker in (
                f"compression={expected_compression}".encode(),
                b"images=3",
            ):
                if marker not in listing:
                    raise AssertionError(
                        f"Vort replaced WIM header missing {marker!r}"
                    )
            for image_index, path, expected in (
                (1, "/first.bin", replace_first),
                (1, "/shared.bin", replace_shared),
                (2, "/new.bin", replace_new),
                (2, "/shared.bin", replace_shared),
                (3, "/third.bin", replace_third),
                (3, "/shared.bin", replace_shared),
            ):
                output = temp / (
                    f"writer-{replace_mode}-{image_index}-"
                    f"{path[1:].replace('/', '-')}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    replace_image,
                    image_index,
                    path,
                    output,
                    len(expected),
                )
                if output.read_bytes() != expected:
                    raise AssertionError("Vort replaced WIM extraction mismatch")
            expect_failure(
                args.cli,
                "extract-wim-path",
                replace_image,
                2,
                "/old.bin",
                temp / f"writer-{replace_mode}-old.out",
                64 * 1024,
                error_name="WimPathNotFound",
            )
            if replace_mode == "replace":
                writer_replace_cases += 1
            else:
                writer_solid_replace_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", replace_image)
                for image_index, unique_name, expected in (
                    (1, "first.bin", replace_first),
                    (2, "new.bin", replace_new),
                    (3, "third.bin", replace_third),
                ):
                    destination = temp / (
                        f"writer-{replace_mode}-wimlib-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        replace_image,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes() != expected
                        or (destination / "shared.bin").read_bytes()
                        != replace_shared
                    ):
                        raise AssertionError(
                            "wimlib replaced WIM extraction mismatch"
                        )
                if replace_mode == "replace":
                    writer_replace_wimlib_cases += 1
                else:
                    writer_solid_replace_wimlib_cases += 1

        reference_replace = temp / "vort-writer-reference-replace.wim"
        run(
            args.writer,
            reference_replace,
            "xpress",
            "replace-existing",
            fixture,
        )
        reference_replacement = temp / "writer-reference-replace.out"
        reference_replacement_bytes = b"Vort replaced a wimlib archive image\n"
        run(
            args.cli,
            "extract-wim-path",
            reference_replace,
            1,
            "/replacement.txt",
            reference_replacement,
            len(reference_replacement_bytes),
        )
        if reference_replacement.read_bytes() != reference_replacement_bytes:
            raise AssertionError("Vort reference replacement mismatch")
        expect_failure(
            args.cli,
            "extract-wim-path",
            reference_replace,
            1,
            "/nested/file.txt",
            temp / "writer-reference-replace-old.out",
            1024,
            error_name="WimPathNotFound",
        )
        writer_reference_replace_cases += 1
        if wimlib is not None:
            run(wimlib, "verify", reference_replace)
            destination = temp / "writer-reference-replace-wimlib"
            run(
                wimlib,
                "extract",
                reference_replace,
                1,
                f"--dest-dir={destination}",
                "--no-acls",
            )
            if (
                (destination / "replacement.txt").read_bytes()
                != reference_replacement_bytes
            ):
                raise AssertionError("wimlib reference replacement mismatch")
            writer_reference_replace_wimlib_cases += 1

        split_expected = {
            (1, "/first.bin"): xorshift_bytes(0x1111_1111, 70_000),
            (1, "/shared.bin"): xorshift_bytes(0x3333_3333, 70_000),
            (2, "/second.bin"): xorshift_bytes(0x2222_2222, 70_000),
            (2, "/shared.bin"): xorshift_bytes(0x3333_3333, 70_000),
        }
        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            split_prefix = temp / f"vort-writer-split-{writer_compression}"
            run(args.writer, split_prefix, writer_compression, "split")
            split_parts = sorted(
                temp.glob(f"{split_prefix.name}.part*"),
                key=lambda path: int(path.name.rsplit("part", 1)[1]),
            )
            if len(split_parts) < 3:
                raise AssertionError("Vort SWM writer did not create enough parts")
            for index, part in enumerate(split_parts, 1):
                listing = run(args.cli, "list-wim-file", part).stdout
                for marker in (
                    f"compression={expected_compression}".encode(),
                    b"images=2",
                    f"part={index}/{len(split_parts)}".encode(),
                ):
                    if marker not in listing:
                        raise AssertionError(
                            f"Vort SWM part header missing {marker!r}"
                        )
            for (image_index, path), expected in split_expected.items():
                output = temp / (
                    f"writer-split-{writer_compression}-{image_index}-"
                    f"{path[1:].replace('/', '-')}"
                )
                run(
                    args.cli,
                    "extract-wim-parts-path",
                    image_index,
                    path,
                    output,
                    len(expected),
                    *split_parts,
                )
                if output.read_bytes() != expected:
                    raise AssertionError("Vort SWM set extraction mismatch")
            writer_split_cases += 1

            if wimlib is not None:
                joined = temp / f"vort-writer-joined-{writer_compression}.wim"
                run(wimlib, "join", joined, *split_parts, "--check")
                run(wimlib, "verify", joined)
                for image_index, unique_name in ((1, "first.bin"), (2, "second.bin")):
                    destination = temp / (
                        f"writer-split-wimlib-{writer_compression}-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        joined,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes()
                        != split_expected[(image_index, f"/{unique_name}")]
                        or (destination / "shared.bin").read_bytes()
                        != split_expected[(image_index, "/shared.bin")]
                    ):
                        raise AssertionError("wimlib joined SWM extraction mismatch")
                writer_split_wimlib_cases += 1

        pipable_large = b"Vort pipable writer multi-chunk payload\n" * 4096
        pipable_random = xorshift_bytes(0x5049_5045, 70_000)
        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            pipable_image = temp / f"vort-writer-pipable-{writer_compression}.wim"
            run(args.writer, pipable_image, writer_compression, "pipable")
            listing = run(args.cli, "list-wim-file", pipable_image).stdout
            for marker in (
                b"layout=pipable",
                f"compression={expected_compression}".encode(),
                b"images=2",
            ):
                if marker not in listing:
                    raise AssertionError(
                        f"Vort pipable writer header missing {marker!r}"
                    )
            for image_index, path, expected in (
                (1, "/large.bin", pipable_large),
                (1, "/random.bin", pipable_random),
                (2, "/second.txt", b"second pipable image\n"),
                (2, "/random.bin", pipable_random),
            ):
                output = temp / (
                    f"writer-pipable-{writer_compression}-{image_index}-"
                    f"{path[1:].replace('/', '-')}"
                )
                run(
                    args.cli,
                    "extract-wim-path",
                    pipable_image,
                    image_index,
                    path,
                    output,
                    len(expected),
                )
                if output.read_bytes() != expected:
                    raise AssertionError("Vort pipable seekable extraction mismatch")
            progressive = temp / f"writer-pipable-progressive-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-pipable-stream-path",
                pipable_image,
                1,
                "/large.bin",
                progressive,
                len(pipable_large),
                7,
                11,
            )
            if progressive.read_bytes() != pipable_large:
                raise AssertionError("Vort pipable progressive extraction mismatch")
            empty = temp / f"writer-pipable-empty-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-pipable-stream-path",
                pipable_image,
                1,
                "/empty",
                empty,
                0,
                5,
                7,
            )
            if empty.read_bytes() != b"":
                raise AssertionError("Vort pipable empty extraction mismatch")
            writer_pipable_cases += 1

            if wimlib is not None:
                run(wimlib, "verify", pipable_image)
                info = run(wimlib, "info", pipable_image).stdout
                if b"Image Count:    2" not in info or b"Boot Index:     2" not in info:
                    raise AssertionError("wimlib pipable image mapping mismatch")
                for image_index, unique_name, unique_payload in (
                    (1, "large.bin", pipable_large),
                    (2, "second.txt", b"second pipable image\n"),
                ):
                    destination = temp / (
                        f"writer-pipable-wimlib-{writer_compression}-{image_index}"
                    )
                    run(
                        wimlib,
                        "extract",
                        pipable_image,
                        image_index,
                        f"--dest-dir={destination}",
                        "--no-acls",
                    )
                    if (
                        (destination / unique_name).read_bytes() != unique_payload
                        or (destination / "random.bin").read_bytes() != pipable_random
                    ):
                        raise AssertionError("wimlib pipable extraction mismatch")
                writer_pipable_wimlib_cases += 1

            integrity_image = temp / (
                f"vort-writer-pipable-integrity-{writer_compression}.wim"
            )
            run(
                args.writer,
                integrity_image,
                writer_compression,
                "pipable-integrity",
            )
            integrity_output = temp / (
                f"writer-pipable-integrity-{writer_compression}.out"
            )
            run(
                args.cli,
                "extract-wim-path",
                integrity_image,
                1,
                "/random.bin",
                integrity_output,
                len(pipable_random),
            )
            if integrity_output.read_bytes() != pipable_random:
                raise AssertionError("Vort pipable integrity seekable mismatch")
            writer_pipable_integrity_cases += 1
            if wimlib is not None:
                run(wimlib, "verify", integrity_image)
                writer_pipable_integrity_wimlib_cases += 1

        for writer_compression, expected_compression in (
            ("stored", "none"),
            ("xpress", "xpress"),
            ("lzx", "lzx"),
            ("lzms", "lzms"),
        ):
            split_prefix = temp / (
                f"vort-writer-pipable-split-{writer_compression}"
            )
            run(args.writer, split_prefix, writer_compression, "pipable-split")
            split_parts = sorted(
                temp.glob(f"{split_prefix.name}.part*"),
                key=lambda path: int(path.name.rsplit("part", 1)[1]),
            )
            if len(split_parts) < 3:
                raise AssertionError("Vort pipable SWM writer part count mismatch")
            concatenated = temp / (
                f"vort-writer-pipable-concat-{writer_compression}.wim"
            )
            concatenated.write_bytes(
                b"".join(part.read_bytes() for part in split_parts)
            )
            for index, part in enumerate(split_parts, 1):
                listing = run(args.cli, "list-wim-file", part).stdout
                for marker in (
                    b"layout=pipable",
                    f"compression={expected_compression}".encode(),
                    f"part={index}/{len(split_parts)}".encode(),
                ):
                    if marker not in listing:
                        raise AssertionError(
                            f"Vort pipable SWM header missing {marker!r}"
                        )
            set_output = temp / f"writer-pipable-split-set-{writer_compression}.out"
            run(
                args.cli,
                "extract-wim-parts-path",
                2,
                "/second.bin",
                set_output,
                70_000,
                *split_parts,
            )
            if set_output.read_bytes() != split_expected[(2, "/second.bin")]:
                raise AssertionError("Vort pipable SWM set extraction mismatch")
            progressive = temp / (
                f"writer-pipable-split-progressive-{writer_compression}.out"
            )
            run(
                args.cli,
                "extract-wim-pipable-stream-path",
                concatenated,
                2,
                "/second.bin",
                progressive,
                70_000,
                13,
                17,
            )
            if progressive.read_bytes() != split_expected[(2, "/second.bin")]:
                raise AssertionError("Vort concatenated pipable SWM mismatch")
            writer_pipable_split_cases += 1

            if wimlib is not None:
                joined = temp / (
                    f"vort-writer-pipable-split-joined-{writer_compression}.wim"
                )
                run(wimlib, "join", joined, *split_parts, "--check")
                run(wimlib, "verify", joined)
                destination = temp / (
                    f"writer-pipable-split-wimlib-{writer_compression}"
                )
                run(
                    wimlib,
                    "extract",
                    joined,
                    2,
                    f"--dest-dir={destination}",
                    "--no-acls",
                )
                if (
                    (destination / "second.bin").read_bytes()
                    != split_expected[(2, "/second.bin")]
                    or (destination / "shared.bin").read_bytes()
                    != split_expected[(2, "/shared.bin")]
                ):
                    raise AssertionError("wimlib pipable SWM join mismatch")
                writer_pipable_split_wimlib_cases += 1
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
        f"writer={writer_cases} writer_wimlib={writer_wimlib_cases} "
        f"writer_stream={writer_stream_cases} "
        f"writer_stream_wimlib={writer_stream_wimlib_cases} "
        f"writer_inode={writer_inode_cases} "
        f"writer_inode_wimlib={writer_inode_wimlib_cases} "
        f"writer_multi={writer_multi_cases} "
        f"writer_multi_wimlib={writer_multi_wimlib_cases} "
        f"writer_solid={writer_solid_cases} "
        f"writer_solid_wimlib={writer_solid_wimlib_cases} "
        f"writer_append={writer_append_cases} "
        f"writer_append_wimlib={writer_append_wimlib_cases} "
        f"writer_solid_append={writer_solid_append_cases} "
        f"writer_solid_append_wimlib={writer_solid_append_wimlib_cases} "
        f"writer_reference_append={writer_reference_append_cases} "
        f"writer_reference_append_wimlib={writer_reference_append_wimlib_cases} "
        f"writer_delete={writer_delete_cases} "
        f"writer_delete_wimlib={writer_delete_wimlib_cases} "
        f"writer_solid_delete={writer_solid_delete_cases} "
        f"writer_solid_delete_wimlib={writer_solid_delete_wimlib_cases} "
        f"writer_reference_delete={writer_reference_delete_cases} "
        f"writer_reference_delete_wimlib={writer_reference_delete_wimlib_cases} "
        f"writer_replace={writer_replace_cases} "
        f"writer_replace_wimlib={writer_replace_wimlib_cases} "
        f"writer_solid_replace={writer_solid_replace_cases} "
        f"writer_solid_replace_wimlib={writer_solid_replace_wimlib_cases} "
        f"writer_reference_replace={writer_reference_replace_cases} "
        f"writer_reference_replace_wimlib={writer_reference_replace_wimlib_cases} "
        f"writer_split={writer_split_cases} "
        f"writer_split_wimlib={writer_split_wimlib_cases} "
        f"writer_pipable={writer_pipable_cases} "
        f"writer_pipable_wimlib={writer_pipable_wimlib_cases} "
        f"writer_pipable_integrity={writer_pipable_integrity_cases} "
        f"writer_pipable_integrity_wimlib={writer_pipable_integrity_wimlib_cases} "
        f"writer_pipable_split={writer_pipable_split_cases} "
        f"writer_pipable_split_wimlib={writer_pipable_split_wimlib_cases} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
