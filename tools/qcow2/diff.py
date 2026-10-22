#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


SECTOR_SIZE = 512
CLUSTER_SIZE = 65536


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


def payload() -> bytes:
    rng = random.Random(0x5146_49FB)
    first = (b"QCOW2 compressed cluster payload 0123456789\n" * 2048)[
        :CLUSTER_SIZE
    ]
    second = rng.randbytes(CLUSTER_SIZE)
    third = bytes(CLUSTER_SIZE)
    fourth = bytearray(CLUSTER_SIZE)
    fourth[2048:6144] = (b"extended L2 allocated subclusters\n" * 128)[:4096]
    return first + second + third + bytes(fourth)


def qemu_convert_to_raw(qemu_img: Path, image: Path, output: Path) -> bytes:
    run(qemu_img, "check", "-f", "qcow2", image)
    run(qemu_img, "convert", "-f", "qcow2", "-O", "raw", image, output)
    return output.read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--qemu-img", type=Path)
    parser.add_argument("--seven-zip", type=Path)
    args = parser.parse_args()
    qemu_img = args.qemu_img or (
        Path(found) if (found := shutil.which("qemu-img")) else None
    )
    seven_zip = args.seven_zip or (
        Path(found)
        if (found := shutil.which("7zz") or shutil.which("7z"))
        else None
    )

    plain = payload()
    if len(plain) % SECTOR_SIZE != 0:
        raise AssertionError("QCOW2 differential payload must be sector aligned")
    self_cases = 0
    external_encode = 0
    external_decode = 0
    layouts = 0
    malformed = 0
    backing_writer_cases = 0

    with tempfile.TemporaryDirectory(prefix="vort-qcow2-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        cases = (
            ("v2-none", "none", 2),
            ("v2-zlib", "zlib", 2),
            ("v3-none", "none", 3),
            ("v3-zlib", "zlib", 3),
            ("v3-zstd", "zstd", 3),
        )
        images: dict[str, Path] = {}
        for name, compression, version in cases:
            image = temp / f"vort-{name}.qcow2"
            decoded = temp / f"vort-{name}.raw"
            ranged = temp / f"vort-{name}.range"
            run(
                args.cli,
                "encode-qcow2",
                source,
                image,
                compression,
                16,
                version,
            )
            summary = run(args.cli, "inspect-qcow2", image).stdout
            if f"version={version}".encode() not in summary:
                raise AssertionError(f"wrong inspect version for {name}")
            run(args.cli, "decode-qcow2", image, decoded, len(plain))
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort QCOW2 round trip mismatch for {name}")
            range_offset = CLUSTER_SIZE - 37
            range_length = CLUSTER_SIZE + 91
            run(
                args.cli,
                "decode-qcow2-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[
                range_offset : range_offset + range_length
            ]:
                raise AssertionError(f"Vort QCOW2 range mismatch for {name}")
            images[name] = image
            self_cases += 1

            if qemu_img is not None:
                output = temp / f"qemu-{name}.raw"
                if qemu_convert_to_raw(qemu_img, image, output) != plain:
                    raise AssertionError(f"QEMU decode of Vort {name} mismatch")
                external_encode += 1
            if seven_zip is not None and compression != "zstd":
                extracted = run(seven_zip, "e", "-so", "-tQCOW", image).stdout
                if extracted != plain:
                    raise AssertionError(f"7-Zip decode of Vort {name} mismatch")
                external_encode += 1

        empty_source = temp / "empty.raw"
        empty_image = temp / "empty.qcow2"
        empty_output = temp / "empty.vort.raw"
        empty_source.write_bytes(b"")
        run(args.cli, "encode-qcow2", empty_source, empty_image, "zstd", 16, 3)
        run(args.cli, "decode-qcow2", empty_image, empty_output, 0)
        if empty_output.read_bytes() != b"":
            raise AssertionError("Vort QCOW2 empty-image round trip mismatch")
        self_cases += 1
        if qemu_img is not None:
            qemu_empty = temp / "empty.qemu.raw"
            if qemu_convert_to_raw(qemu_img, empty_image, qemu_empty) != b"":
                raise AssertionError("QEMU decode of Vort empty QCOW2 mismatch")
            external_encode += 1

        valid = images["v3-zlib"]
        short = temp / "short.qcow2"
        short.write_bytes(valid.read_bytes()[:64])
        expect_failure(args.cli, "inspect-qcow2", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic_bytes = bytearray(valid.read_bytes())
        bad_magic_bytes[0] ^= 1
        bad_magic = temp / "bad-magic.qcow2"
        bad_magic.write_bytes(bad_magic_bytes)
        expect_failure(args.cli, "inspect-qcow2", bad_magic, error_name="InvalidMagic")
        malformed += 1

        encrypted_bytes = bytearray(valid.read_bytes())
        struct.pack_into(">I", encrypted_bytes, 32, 1)
        encrypted = temp / "encrypted.qcow2"
        encrypted.write_bytes(encrypted_bytes)
        expect_failure(
            args.cli, "inspect-qcow2", encrypted, error_name="EncryptedQcow2"
        )
        malformed += 1

        expect_failure(
            args.cli,
            "decode-qcow2",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1

        if qemu_img is not None:
            reference_cases = (
                ("v2-zlib", "compat=0.10,cluster_size=65536"),
                (
                    "v3-zlib",
                    "compat=1.1,cluster_size=65536,compression_type=zlib",
                ),
                (
                    "v3-zstd",
                    "compat=1.1,cluster_size=65536,compression_type=zstd",
                ),
            )
            for name, options in reference_cases:
                image = temp / f"qemu-{name}.qcow2"
                output = temp / f"qemu-{name}.vort.raw"
                run(
                    qemu_img,
                    "convert",
                    "-f",
                    "raw",
                    "-O",
                    "qcow2",
                    "-c",
                    "-o",
                    options,
                    source,
                    image,
                )
                run(args.cli, "decode-qcow2", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of QEMU {name} mismatch")
                external_decode += 1

            extended = temp / "qemu-extended-l2.qcow2"
            extended_output = temp / "qemu-extended-l2.raw"
            run(
                qemu_img,
                "convert",
                "-f",
                "raw",
                "-O",
                "qcow2",
                "-S",
                4096,
                "-o",
                "compat=1.1,cluster_size=65536,extended_l2=on",
                source,
                extended,
            )
            if b"extended_l2=true" not in run(
                args.cli, "inspect-qcow2", extended
            ).stdout:
                raise AssertionError("Vort did not report QEMU extended L2")
            run(args.cli, "decode-qcow2", extended, extended_output, len(plain))
            if extended_output.read_bytes() != plain:
                raise AssertionError("Vort decode of QEMU extended L2 mismatch")
            external_decode += 1
            layouts += 1

        parent_bytes = bytearray(plain)
        parent_bytes[2 * CLUSTER_SIZE : 3 * CLUSTER_SIZE] = (
            b"QCOW2 parent-only cluster\n" * 4096
        )[:CLUSTER_SIZE]
        child_bytes = bytearray(parent_bytes)
        for index in range(CLUSTER_SIZE, 2 * CLUSTER_SIZE):
            child_bytes[index] ^= (index * 13 + 0x51) & 0xFF
        child_bytes[2 * CLUSTER_SIZE : 3 * CLUSTER_SIZE] = bytes(CLUSTER_SIZE)
        parent_source = temp / "parent.raw"
        child_source = temp / "child.raw"
        parent_source.write_bytes(parent_bytes)
        child_source.write_bytes(child_bytes)
        for name, compression, version in (
            ("v2-backing", "none", 2),
            ("v3-backing", "zlib", 3),
        ):
            image = temp / f"vort-{name}.qcow2"
            decoded = temp / f"vort-{name}.raw"
            run(
                args.cli,
                "encode-qcow2",
                child_source,
                image,
                compression,
                16,
                version,
                parent_source,
                parent_source.name,
            )
            summary = run(args.cli, "inspect-qcow2", image).stdout
            if b"backing=parent.raw" not in summary:
                raise AssertionError(f"missing Vort backing metadata for {name}")
            run(
                args.cli,
                "decode-qcow2",
                image,
                decoded,
                len(child_bytes),
                parent_source,
            )
            if decoded.read_bytes() != child_bytes:
                raise AssertionError(f"Vort backing writer mismatch for {name}")
            backing_writer_cases += 1
            self_cases += 1
            if qemu_img is not None:
                qemu_output = temp / f"qemu-{name}.raw"
                if qemu_convert_to_raw(qemu_img, image, qemu_output) != child_bytes:
                    raise AssertionError(f"QEMU backing writer mismatch for {name}")
                info = run(qemu_img, "info", "--output=json", image).stdout
                if b'"backing-filename-format": "raw"' not in info:
                    raise AssertionError(f"QEMU missed raw backing format for {name}")
                external_encode += 1

        if qemu_img is not None:
            backing = temp / "qemu-backing.qcow2"
            backing_output = temp / "qemu-backing.raw"
            run(
                qemu_img,
                "create",
                "-f",
                "qcow2",
                "-F",
                "raw",
                "-b",
                source,
                "-o",
                "compat=1.1,cluster_size=65536",
                backing,
                len(plain),
            )
            expect_failure(
                args.cli,
                "decode-qcow2",
                backing,
                temp / "missing-backing.raw",
                len(plain),
                error_name="MissingQcow2BackingFile",
            )
            malformed += 1
            run(
                args.cli,
                "decode-qcow2",
                backing,
                backing_output,
                len(plain),
                source,
            )
            if backing_output.read_bytes() != plain:
                raise AssertionError("Vort decode of QEMU backing image mismatch")
            external_decode += 1
            layouts += 1

            data_file = temp / "qemu-external.raw"
            external = temp / "qemu-external.qcow2"
            external_output = temp / "qemu-external.vort.raw"
            run(
                qemu_img,
                "convert",
                "-f",
                "raw",
                "-O",
                "qcow2",
                "-o",
                f"compat=1.1,cluster_size=65536,data_file={data_file},data_file_raw=on",
                source,
                external,
            )
            expect_failure(
                args.cli,
                "decode-qcow2",
                external,
                temp / "missing-data-file.raw",
                len(plain),
                error_name="MissingQcow2DataFile",
            )
            malformed += 1
            run(
                args.cli,
                "decode-qcow2",
                external,
                external_output,
                len(plain),
                "-",
                data_file,
            )
            if external_output.read_bytes() != plain:
                raise AssertionError("Vort decode of QEMU external data mismatch")
            external_decode += 1
            layouts += 1

            wide_plain = bytearray(65 * (512 // 8) * 512)
            wide_plain[0] = 0x51
            wide_plain[-1] = 0xFB
            wide_source = temp / "wide-l1.raw"
            wide_image = temp / "wide-l1.qcow2"
            wide_output = temp / "wide-l1.qemu.raw"
            wide_source.write_bytes(wide_plain)
            run(
                args.cli,
                "encode-qcow2",
                wide_source,
                wide_image,
                "none",
                9,
                3,
            )
            if qemu_convert_to_raw(qemu_img, wide_image, wide_output) != wide_plain:
                raise AssertionError("QEMU decode of multi-cluster Vort L1 mismatch")
            external_encode += 1
            layouts += 1

    print(
        f"self={self_cases} qemu_img={qemu_img is not None} "
        f"seven_zip={seven_zip is not None} external_encode={external_encode} "
        f"external_decode={external_decode} layouts={layouts} malformed={malformed}"
        f" backing_writer_cases={backing_writer_cases}"
    )


if __name__ == "__main__":
    main()
