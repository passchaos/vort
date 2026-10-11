#!/usr/bin/env python3
import argparse
import random
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


ZSTD_MAGIC = bytes.fromhex("28b52ffd")


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


def build_openzfs_probe(openzfs_dir: Path, output: Path) -> Path:
    run(
        "cc",
        "-O2",
        "-std=c11",
        "-Itools/zfs/openzfs_stub",
        f"-I{openzfs_dir}",
        "tools/zfs/openzfs_probe.c",
        "-o",
        output,
    )
    return output


def payload() -> bytes:
    data = bytearray(32 * 1024)
    for index in range(512):
        offset = index * 48
        if offset + 24 <= len(data):
            data[offset : offset + 24] = b"ZFS-block-reference-data"
    return bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--openzfs-dir", type=Path)
    parser.add_argument("--openzfs-probe", type=Path)
    parser.add_argument("--zstd", type=Path)
    args = parser.parse_args()
    zstd_cli = args.zstd or (Path(found) if (found := shutil.which("zstd")) else None)
    try:
        import lz4.block as lz4_block
    except ImportError:
        lz4_block = None

    self_cases = 0
    external_encode = 0
    external_decode = 0
    malformed = 0
    plain = payload()
    with tempfile.TemporaryDirectory(prefix="vort-zfs-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        probe = args.openzfs_probe
        if probe is None and args.openzfs_dir is not None:
            probe = build_openzfs_probe(args.openzfs_dir, temp / "openzfs-probe")

        algorithms = (
            "lzjb",
            "gzip_1",
            "gzip_6",
            "gzip_9",
            "zle",
            "lz4",
            "zstd",
        )
        encoded_paths: dict[str, Path] = {}
        for algorithm in algorithms:
            encoded = temp / f"vort-{algorithm}.zfs"
            decoded = temp / f"vort-{algorithm}.raw"
            run(args.cli, "encode-zfs-block", source, encoded, algorithm)
            run(args.cli, "inspect-zfs-block", encoded, algorithm)
            run(
                args.cli,
                "decode-zfs-block",
                encoded,
                decoded,
                algorithm,
                len(plain),
            )
            if decoded.read_bytes() != plain:
                raise AssertionError(f"Vort ZFS round trip mismatch for {algorithm}")
            encoded_paths[algorithm] = encoded
            self_cases += 1

        if probe is not None:
            for algorithm in ("lzjb", "zle"):
                reference = temp / f"reference-{algorithm}.zfs"
                output = temp / f"reference-{algorithm}.raw"
                run(probe, "encode", algorithm, source, reference)
                run(
                    args.cli,
                    "decode-zfs-block",
                    reference,
                    output,
                    algorithm,
                    len(plain),
                )
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of OpenZFS {algorithm} mismatch")
                external_decode += 1

                output = temp / f"openzfs-{algorithm}.raw"
                run(
                    probe,
                    "decode",
                    algorithm,
                    encoded_paths[algorithm],
                    output,
                    len(plain),
                )
                if output.read_bytes() != plain:
                    raise AssertionError(f"OpenZFS decode of Vort {algorithm} mismatch")
                external_encode += 1

        zlib_decoded = zlib.decompress(encoded_paths["gzip_6"].read_bytes())
        if zlib_decoded != plain:
            raise AssertionError("Python zlib decode of Vort ZFS gzip mismatch")
        external_encode += 1
        reference_zlib = temp / "reference-gzip.zfs"
        reference_zlib.write_bytes(zlib.compress(plain, 6))
        output = temp / "reference-gzip.raw"
        run(
            args.cli,
            "decode-zfs-block",
            reference_zlib,
            output,
            "gzip_6",
            len(plain),
        )
        if output.read_bytes() != plain:
            raise AssertionError("Vort decode of Python ZFS gzip mismatch")
        external_decode += 1

        if lz4_block is not None:
            vort_lz4 = encoded_paths["lz4"].read_bytes()
            compressed_size = struct.unpack_from(">I", vort_lz4)[0]
            if lz4_block.decompress(
                vort_lz4[4 : 4 + compressed_size],
                uncompressed_size=len(plain),
            ) != plain:
                raise AssertionError("python-lz4 decode of Vort ZFS LZ4 mismatch")
            external_encode += 1
            compressed = lz4_block.compress(plain, store_size=False)
            reference_lz4 = temp / "reference-lz4.zfs"
            reference_lz4.write_bytes(struct.pack(">I", len(compressed)) + compressed)
            output = temp / "reference-lz4.raw"
            run(
                args.cli,
                "decode-zfs-block",
                reference_lz4,
                output,
                "lz4",
                len(plain),
            )
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode of python-lz4 ZFS block mismatch")
            external_decode += 1

        if zstd_cli is not None:
            vort_zstd = encoded_paths["zstd"].read_bytes()
            compressed_size = struct.unpack_from(">I", vort_zstd)[0]
            standard = temp / "vort-standard.zst"
            standard.write_bytes(ZSTD_MAGIC + vort_zstd[8 : 8 + compressed_size])
            if run(zstd_cli, "-q", "-d", "-c", standard).stdout != plain:
                raise AssertionError("system zstd decode of Vort ZFS Zstd mismatch")
            external_encode += 1

            standard_bytes = run(zstd_cli, "-q", "-3", "-c", source).stdout
            if not standard_bytes.startswith(ZSTD_MAGIC):
                raise AssertionError("system zstd produced invalid frame")
            body = standard_bytes[4:]
            reference_zstd = temp / "reference-zstd.zfs"
            reference_zstd.write_bytes(
                struct.pack(">II", len(body), (3 << 24) | 10507) + body
            )
            output = temp / "reference-zstd.raw"
            run(
                args.cli,
                "decode-zfs-block",
                reference_zstd,
                output,
                "zstd",
                len(plain),
            )
            if output.read_bytes() != plain:
                raise AssertionError("Vort decode of system ZFS Zstd mismatch")
            external_decode += 1

        bad_lzjb = temp / "bad-lzjb.zfs"
        bad_lzjb.write_bytes(b"\x01\x00\x00")
        expect_failure(
            args.cli,
            "decode-zfs-block",
            bad_lzjb,
            temp / "bad-lzjb.raw",
            "lzjb",
            3,
            error_name="InvalidMatch",
        )
        malformed += 1

        bad_zle = temp / "bad-zle.zfs"
        bad_zle.write_bytes(b"\x01x")
        expect_failure(
            args.cli,
            "decode-zfs-block",
            bad_zle,
            temp / "bad-zle.raw",
            "zle",
            2,
            error_name="TruncatedFrame",
        )
        malformed += 1

        bad_lz4 = temp / "bad-lz4.zfs"
        bad_lz4.write_bytes(struct.pack(">I", 100) + b"x")
        expect_failure(
            args.cli,
            "decode-zfs-block",
            bad_lz4,
            temp / "bad-lz4.raw",
            "lz4",
            len(plain),
            error_name="InvalidZfsBlock",
        )
        malformed += 1

        bad_zstd = bytearray(encoded_paths["zstd"].read_bytes())
        bad_zstd[4] = 0
        bad_zstd_path = temp / "bad-zstd.zfs"
        bad_zstd_path.write_bytes(bad_zstd)
        expect_failure(
            args.cli,
            "decode-zfs-block",
            bad_zstd_path,
            temp / "bad-zstd.raw",
            "zstd",
            len(plain),
            error_name="InvalidZfsBlock",
        )
        malformed += 1

        rng = random.Random(0xBAD5_F500)
        random_source = temp / "random.raw"
        random_source.write_bytes(rng.randbytes(4096))
        expect_failure(
            args.cli,
            "encode-zfs-block",
            random_source,
            temp / "random-lzjb.zfs",
            "lzjb",
            error_name="IncompressibleZfsBlock",
        )
        malformed += 1

    print(
        f"self={self_cases} openzfs={probe is not None} "
        f"python_lz4={lz4_block is not None} zstd={zstd_cli is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
