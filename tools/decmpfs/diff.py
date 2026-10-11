#!/usr/bin/env python3
import argparse
import base64
import random
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


MAGIC = 0x636D7066
BLOCK_SIZE = 64 * 1024
RESOURCE_MAP = bytes.fromhex(
    "00" * 24
    + "001c0032"
    + "0000"
    + "636d7066"
    + "0000000a"
    + "0001ffff"
    + "00000000"
    + "00000000"
)


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


def header(compression_type: int, decoded_size: int) -> bytes:
    return struct.pack("<IIQ", MAGIC, compression_type, decoded_size)


def zlib_chunk(chunk: bytes) -> bytes:
    compressed = zlib.compress(chunk, level=9)
    return compressed if len(compressed) < len(chunk) + 1 else b"\xff" + chunk


def zlib_resource(plain: bytes) -> bytes:
    chunks = [zlib_chunk(plain[pos : pos + BLOCK_SIZE]) for pos in range(0, len(plain), BLOCK_SIZE)]
    table_size = len(chunks) * 8
    relative = 4 + table_size
    descriptors = bytearray()
    for chunk in chunks:
        descriptors.extend(struct.pack("<II", relative, len(chunk)))
        relative += len(chunk)
    payload = struct.pack("<I", len(chunks)) + descriptors + b"".join(chunks)
    data = struct.pack(">I", len(payload)) + payload
    data_offset = 0x100
    map_offset = data_offset + len(data)
    resource_header = struct.pack(
        ">IIII", data_offset, map_offset, len(data), len(RESOURCE_MAP)
    )
    return (
        resource_header
        + bytes(data_offset - len(resource_header))
        + data
        + RESOURCE_MAP
    )


def offset_resource(chunks: list[bytes]) -> bytes:
    table_size = (len(chunks) + 1) * 4
    offsets = []
    position = table_size
    for chunk in chunks:
        offsets.append(position)
        position += len(chunk)
    offsets.append(position)
    return struct.pack(f"<{len(offsets)}I", *offsets) + b"".join(chunks)


def reference_lzfse(reference: Path, plain: bytes, temp: Path, name: str) -> bytes:
    source = temp / f"{name}.plain"
    encoded = temp / f"{name}.lzfse"
    source.write_bytes(plain)
    run(reference, "-encode", "-i", source, "-o", encoded)
    return encoded.read_bytes()


def reference_lzvn(reference: Path, plain: bytes, temp: Path, name: str) -> bytes:
    stream = reference_lzfse(reference, plain, temp, name)
    if len(stream) < 16 or stream[:4] != b"bvxn" or stream[-4:] != b"bvx$":
        raise AssertionError("Apple reference did not select a single LZVN block")
    raw_size, payload_size = struct.unpack_from("<II", stream, 4)
    if raw_size != len(plain) or 12 + payload_size + 4 != len(stream):
        raise AssertionError("invalid Apple reference LZVN envelope")
    return stream[12 : 12 + payload_size]


def decode_case(
    cli: Path,
    temp: Path,
    name: str,
    compression_type: int,
    plain: bytes,
    payload: bytes = b"",
    resource: bytes | None = None,
) -> None:
    xattr_path = temp / f"{name}.decmpfs"
    resource_path = temp / f"{name}.rsrc"
    output_path = temp / f"{name}.out"
    range_path = temp / f"{name}.range"
    xattr_path.write_bytes(header(compression_type, len(plain)) + payload)
    resource_arg: object = "-"
    if resource is not None:
        resource_path.write_bytes(resource)
        resource_arg = resource_path
    run(cli, "inspect-decmpfs", xattr_path, resource_arg)
    run(cli, "decode-decmpfs", xattr_path, resource_arg, output_path, len(plain))
    if output_path.read_bytes() != plain:
        raise AssertionError(f"decmpfs decode mismatch for {name}")
    if plain:
        offset = min(max(0, BLOCK_SIZE - 31), len(plain) - 1)
        length = min(127, len(plain) - offset)
        run(
            cli,
            "decode-decmpfs-range",
            xattr_path,
            resource_arg,
            range_path,
            offset,
            length,
        )
        if range_path.read_bytes() != plain[offset : offset + length]:
            raise AssertionError(f"decmpfs range mismatch for {name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--lzfse", type=Path)
    args = parser.parse_args()
    reference = args.lzfse or (
        Path(found) if (found := shutil.which("lzfse")) else None
    )

    pinned = 0
    python_zlib = 0
    apple_lzfse = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-decmpfs-") as temp_text:
        temp = Path(temp_text)

        inline = b"external Python zlib decmpfs inline\n" * 80
        decode_case(args.cli, temp, "zlib-inline", 3, inline, zlib.compress(inline, 9))
        python_zlib += 1
        decode_case(args.cli, temp, "zlib-inline-raw", 3, inline, b"\xff" + inline)
        python_zlib += 1

        rng = random.Random(0xDEC0_0F5)
        resource_plain = (
            (b"decmpfs zlib resource chunk\n" * 4096)[:BLOCK_SIZE]
            + rng.randbytes(11_111)
        )
        zlib_rsrc = zlib_resource(resource_plain)
        decode_case(args.cli, temp, "zlib-resource", 4, resource_plain, resource=zlib_rsrc)
        python_zlib += 1

        pinned_resource = base64.b64decode(
            Path("src/decmpfs/testdata/ditto-type8-200k-a.rsrc.b64").read_text()
        )
        pinned_plain = b"A" * 200_000
        decode_case(args.cli, temp, "ditto-type8", 8, pinned_plain, resource=pinned_resource)
        pinned += 1

        if reference is not None:
            lzvn_plain = b"Apple reference LZVN decmpfs inline\n" * 64
            lzvn = reference_lzvn(reference, lzvn_plain, temp, "lzvn-inline")
            decode_case(args.cli, temp, "lzvn-inline", 7, lzvn_plain, lzvn)
            apple_lzfse += 1

            lzfse_plain = b"Apple reference LZFSE decmpfs inline\n" * 4096
            stream = reference_lzfse(reference, lzfse_plain, temp, "lzfse-inline")
            decode_case(args.cli, temp, "lzfse-inline", 11, lzfse_plain, stream)
            apple_lzfse += 1

            resource_plain = (
                (b"external LZFSE resource first chunk\n" * 4096)[:BLOCK_SIZE]
                + b"external LZFSE tail\n" * 1500
            )
            streams = [
                reference_lzfse(
                    reference,
                    resource_plain[pos : pos + BLOCK_SIZE],
                    temp,
                    f"lzfse-resource-{pos // BLOCK_SIZE}",
                )
                for pos in range(0, len(resource_plain), BLOCK_SIZE)
            ]
            decode_case(
                args.cli,
                temp,
                "lzfse-resource",
                12,
                resource_plain,
                resource=offset_resource(streams),
            )
            apple_lzfse += 1

        short = temp / "short.decmpfs"
        short.write_bytes(b"fpmc")
        expect_failure(args.cli, "inspect-decmpfs", short, "-", error_name="TruncatedFrame")
        malformed += 1

        bad_magic = temp / "bad-magic.decmpfs"
        bad_magic.write_bytes(header(9, 0))
        bad = bytearray(bad_magic.read_bytes())
        bad[0] ^= 1
        bad_magic.write_bytes(bad)
        expect_failure(args.cli, "inspect-decmpfs", bad_magic, "-", error_name="InvalidMagic")
        malformed += 1

        resource_xattr = temp / "missing-resource.decmpfs"
        resource_xattr.write_bytes(header(4, 1))
        expect_failure(
            args.cli,
            "inspect-decmpfs",
            resource_xattr,
            "-",
            error_name="MissingDecmpfsResourceFork",
        )
        malformed += 1

        bad_resource = temp / "bad-offset.rsrc"
        bad_resource.write_bytes(struct.pack("<II", 8, 8))
        lzvn_xattr = temp / "bad-offset.decmpfs"
        lzvn_xattr.write_bytes(header(8, 1))
        expect_failure(
            args.cli,
            "inspect-decmpfs",
            lzvn_xattr,
            bad_resource,
            error_name="InvalidDecmpfs",
        )
        malformed += 1

        inline_xattr = temp / "limited.decmpfs"
        inline_xattr.write_bytes(header(9, 4) + b"\xccdata")
        expect_failure(
            args.cli,
            "decode-decmpfs",
            inline_xattr,
            "-",
            temp / "limited.out",
            3,
            error_name="OutputLimitExceeded",
        )
        malformed += 1

    print(
        f"pinned={pinned} python_zlib={python_zlib} "
        f"lzfse={reference is not None} apple_lzfse={apple_lzfse} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
