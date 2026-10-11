#!/usr/bin/env python3
import argparse
import base64
import bz2
import hashlib
import random
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


PINNED = {
    "lzma": "953337865dd9eb514cc02835f4fb6044d0ba2376648b8d347ffd2fbf73a5a4d0",
    "huff": "d019fa6872665ae298c4bb4cd2f7241ac224223c75c1e00d901241f2ca900643",
    "zstd": "0a17f303ea17294ad4e9cdff77c4d286644a28d5461084e48acf26863fca5fcd",
    "parent": "4f93935130269f479bbf7f7262225ec9e8352504470e482acf7ccd1b19967140",
    "child": "a6dc6dfbd4fe4e51f8b672aab47cda2e447c22d81ce454e0dfefcd86bf2dc3dc",
    "shifted-child": "3ee44566f0672e47eb20b20226061e7fdb50bb0eea4173ff707b1f40831439ef",
}
PINNED_RAW_SHA256 = "0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824"
PINNED_SHIFTED_SHA256 = "230a29790c7b8ed672ba4edc49eb47fc9e810d9fb4488809664555a9052a89cb"


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
    rng = random.Random(0x4348_4435)
    first = (b"Vort CHD differential payload 0123456789\n" * 256)[:4096]
    random_hunk = rng.randbytes(4096)
    zeros = bytes(4096)
    structured = bytes((index * 17 + index // 13) & 0xFF for index in range(4096))
    return first + random_hunk + zeros + first + structured + zeros + first + random_hunk


def read_fixture(name: str) -> bytes:
    path = Path(f"src/chd/testdata/chdman-0.289-{name}.chd.bz2.b64")
    image = bz2.decompress(base64.b64decode(path.read_text()))
    if hashlib.sha256(image).hexdigest() != PINNED[name]:
        raise AssertionError(f"pinned {name} CHD digest mismatch")
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--chdman", type=Path)
    args = parser.parse_args()
    chdman = args.chdman or (
        Path(found) if (found := shutil.which("chdman")) else None
    )

    plain = payload()
    self_cases = 0
    pinned = 0
    external_encode = 0
    external_decode = 0
    parent_cases = 0
    malformed = 0
    with tempfile.TemporaryDirectory(prefix="vort-chd-") as temp_text:
        temp = Path(temp_text)
        source = temp / "payload.raw"
        source.write_bytes(plain)
        images: dict[str, Path] = {}
        for compression in ("none", "zlib", "auto"):
            image = temp / f"vort-{compression}.chd"
            output = temp / f"vort-{compression}.raw"
            ranged = temp / f"vort-{compression}.range"
            run(args.cli, "encode-chd", source, image, compression, 4096, 512, 6)
            summary = run(args.cli, "inspect-chd", image).stdout
            expected_codec = b"codec=none" if compression == "none" else b"codec=zlib"
            if expected_codec not in summary or b"hunks=8" not in summary:
                raise AssertionError(f"Vort CHD inspect mismatch for {compression}")
            run(args.cli, "decode-chd", image, output, len(plain))
            if output.read_bytes() != plain:
                raise AssertionError(f"Vort CHD round trip mismatch for {compression}")
            range_offset = 4096 - 37
            range_length = 4096 + 91
            run(
                args.cli,
                "decode-chd-range",
                image,
                ranged,
                range_offset,
                range_length,
            )
            if ranged.read_bytes() != plain[range_offset : range_offset + range_length]:
                raise AssertionError(f"Vort CHD range mismatch for {compression}")
            images[compression] = image
            self_cases += 1

            if chdman is not None:
                run(chdman, "info", "-i", image)
                if compression != "none":
                    run(chdman, "verify", "-i", image)
                external = temp / f"vort-{compression}.chdman.raw"
                run(chdman, "extractraw", "-i", image, "-o", external, "-f")
                if external.read_bytes() != plain:
                    raise AssertionError(f"chdman decode of Vort {compression} mismatch")
                external_encode += 1

        partial_plain = plain + b"partial logical tail"
        partial_source = temp / "partial.raw"
        partial_image = temp / "vort-partial.chd"
        partial_output = temp / "vort-partial.raw"
        partial_source.write_bytes(partial_plain)
        run(args.cli, "encode-chd", partial_source, partial_image, "auto", 4096, 512, 6)
        run(args.cli, "decode-chd", partial_image, partial_output, len(partial_plain))
        if partial_output.read_bytes() != partial_plain:
            raise AssertionError("Vort CHD partial-hunk round trip mismatch")
        self_cases += 1
        if chdman is not None:
            run(chdman, "verify", "-i", partial_image)
            partial_external = temp / "vort-partial.chdman.raw"
            run(
                chdman,
                "extractraw",
                "-i",
                partial_image,
                "-o",
                partial_external,
                "-f",
            )
            if partial_external.read_bytes() != partial_plain:
                raise AssertionError("chdman decode of Vort partial CHD mismatch")
            external_encode += 1

        pinned_paths: dict[str, Path] = {}
        for codec in ("lzma", "huff", "zstd"):
            image = read_fixture(codec)
            path = temp / f"pinned-{codec}.chd"
            output = temp / f"pinned-{codec}.raw"
            path.write_bytes(image)
            run(args.cli, "decode-chd", path, output, len(plain))
            if hashlib.sha256(output.read_bytes()).hexdigest() != PINNED_RAW_SHA256:
                raise AssertionError(f"Vort decode of pinned {codec} CHD mismatch")
            pinned_paths[codec] = path
            pinned += 1
            external_decode += 1

        parent_path = temp / "pinned-parent.chd"
        child_path = temp / "pinned-child.chd"
        parent_path.write_bytes(read_fixture("parent"))
        child_path.write_bytes(read_fixture("child"))
        child_summary = run(args.cli, "inspect-chd", child_path, parent_path).stdout
        if b"metadata=1" not in child_summary or b"parent=true" not in child_summary:
            raise AssertionError("pinned CHD parent metadata mismatch")
        child_output = temp / "pinned-child.raw"
        run(args.cli, "decode-chd", child_path, child_output, len(plain), parent_path)
        if hashlib.sha256(child_output.read_bytes()).hexdigest() != PINNED_RAW_SHA256:
            raise AssertionError("Vort decode of pinned parent CHD mismatch")
        pinned += 2
        external_decode += 1
        parent_cases += 1

        shifted_child_path = temp / "pinned-shifted-child.chd"
        shifted_child_path.write_bytes(read_fixture("shifted-child"))
        shifted_output = temp / "pinned-shifted-child.raw"
        run(
            args.cli,
            "decode-chd",
            shifted_child_path,
            shifted_output,
            len(plain),
            parent_path,
        )
        if hashlib.sha256(shifted_output.read_bytes()).hexdigest() != PINNED_SHIFTED_SHA256:
            raise AssertionError("Vort decode of shifted parent CHD mismatch")
        pinned += 1
        external_decode += 1
        parent_cases += 1

        valid = images["auto"]
        short = temp / "short.chd"
        short.write_bytes(valid.read_bytes()[:16])
        expect_failure(args.cli, "inspect-chd", short, error_name="TruncatedFrame")
        malformed += 1

        bad_magic_bytes = bytearray(valid.read_bytes())
        bad_magic_bytes[0] ^= 1
        bad_magic = temp / "bad-magic.chd"
        bad_magic.write_bytes(bad_magic_bytes)
        expect_failure(args.cli, "inspect-chd", bad_magic, error_name="InvalidMagic")
        malformed += 1

        bad_map_bytes = bytearray(valid.read_bytes())
        map_offset = struct.unpack_from(">Q", bad_map_bytes, 40)[0]
        bad_map_bytes[map_offset + 10] ^= 1
        bad_map = temp / "bad-map.chd"
        bad_map.write_bytes(bad_map_bytes)
        expect_failure(args.cli, "inspect-chd", bad_map, error_name="ChecksumMismatch")
        malformed += 1

        expect_failure(
            args.cli,
            "decode-chd",
            valid,
            temp / "limited.raw",
            len(plain) - 1,
            error_name="OutputLimitExceeded",
        )
        malformed += 1
        expect_failure(
            args.cli,
            "decode-chd-range",
            valid,
            temp / "bad-range.raw",
            len(plain) - 10,
            20,
            error_name="RangeOutOfBounds",
        )
        malformed += 1

        if chdman is not None:
            generated: dict[str, Path] = {}
            for codec in ("none", "zlib", "lzma", "huff", "zstd"):
                image = temp / f"chdman-{codec}.chd"
                output = temp / f"chdman-{codec}.vort.raw"
                run(
                    chdman,
                    "createhd",
                    "-i",
                    source,
                    "-o",
                    image,
                    "-hs",
                    4096,
                    "-ss",
                    512,
                    "-c",
                    codec,
                    "-f",
                )
                run(args.cli, "decode-chd", image, output, len(plain))
                if output.read_bytes() != plain:
                    raise AssertionError(f"Vort decode of chdman {codec} mismatch")
                generated[codec] = image
                external_decode += 1

            child = temp / "chdman-child.chd"
            run(
                chdman,
                "createhd",
                "-i",
                source,
                "-o",
                child,
                "-op",
                generated["zlib"],
                "-hs",
                4096,
                "-ss",
                512,
                "-c",
                "zlib",
                "-f",
            )
            child_raw = temp / "chdman-child.vort.raw"
            run(
                args.cli,
                "decode-chd",
                child,
                child_raw,
                len(plain),
                generated["zlib"],
            )
            if child_raw.read_bytes() != plain:
                raise AssertionError("Vort decode of generated parent CHD mismatch")
            external_decode += 1
            parent_cases += 1

    print(
        f"self={self_cases} pinned={pinned} chdman={chdman is not None} "
        f"external_encode={external_encode} external_decode={external_decode} "
        f"parent={parent_cases} malformed={malformed}"
    )


if __name__ == "__main__":
    main()
