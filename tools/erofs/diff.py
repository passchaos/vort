#!/usr/bin/env python3
import argparse
import base64
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
from final_big_diff import verify_final_big_pclusters
from file_source_diff import verify_file_sources
from source_reader_diff import verify_source_readers
from directory_diff import verify_directory_streams
from prefix_diff import verify_packed_prefixes
from partial_diff import verify_partial_extents
from device_diff import verify_device_readers
from metadata_zone_diff import verify_metadata_zones
from dual_algorithm_diff import verify_dual_algorithms


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


def write_tree(root: Path) -> tuple[dict[str, bytes], dict[str, dict[bytes, bytes]]]:
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
    xattrs = {
        "/": {b"user.vort.root": b"oracle-root"},
        "small.txt": {
            b"user.vort.unique": b"oracle-inline",
            b"user.vort.repeat": b"oracle-shared",
        },
        "nested/data.txt": {b"user.vort.repeat": b"oracle-shared"},
        "large.bin": {b"user.vort.repeat": b"oracle-shared"},
        "nested": {b"user.vort.directory": b"oracle-directory"},
    }
    for name, attributes in xattrs.items():
        path = root if name == "/" else root / name
        for key, value in attributes.items():
            os.setxattr(path, key, value)
    return payloads, xattrs


def make_image(
    mkfs: Path,
    source: Path,
    image: Path,
    compressor: str | None,
    legacy: bool,
    xattr_prefix: str | None = None,
    features: tuple[str, ...] = (),
    chunksize: int | None = None,
    blobdev: Path | None = None,
    metabox: str | None = None,
    compress_directories: bool = False,
    pcluster_size: int | None = None,
) -> None:
    command: list[object] = [mkfs, "-T0", "--all-root"]
    if compressor is not None:
        command.append(f"-z{compressor}")
    if pcluster_size is not None:
        command.append(f"-C{pcluster_size}")
    if legacy:
        command.extend(("-E", "legacy-compress"))
    if xattr_prefix is not None:
        command.append(f"--xattr-prefix={xattr_prefix}")
    for feature in features:
        command.extend(("-E", feature))
    if chunksize is not None:
        command.append(f"--chunksize={chunksize}")
    if blobdev is not None:
        command.append(f"--blobdev={blobdev}")
    if metabox is not None:
        command.extend(("-m4096", f"--MZ={metabox}"))
    if compress_directories:
        command.append("--zD")
    command.extend((image, source))
    run(*command)


def verify_vort(
    cli: Path,
    image: Path,
    payloads: dict[str, bytes],
    label: str,
    temp: Path,
    devices: tuple[Path, ...] = (),
) -> None:
    listing = run(cli, "list-erofs-file", image).stdout
    for required in (b"large.bin", b"mixed.bin", b"nested/data.txt", b"small.txt", b"link"):
        if required not in listing:
            raise AssertionError(f"EROFS listing missing {required!r} for {label}")
    for name, expected in payloads.items():
        output = temp / f"{label}-{name.replace('/', '-')}.out"
        run(cli, "extract-erofs-file", image, name, output, len(expected), *devices)
        if output.read_bytes() != expected:
            raise AssertionError(f"EROFS extraction mismatch for {label}/{name}")


def verify_vort_xattrs(
    cli: Path,
    image: Path,
    expected: dict[str, dict[bytes, bytes]],
    label: str,
) -> None:
    for path, attributes in expected.items():
        output = run(cli, "list-erofs-xattrs", image, path).stdout
        for name, value in attributes.items():
            required = b"xattr\t" + name + b"\t" + value.hex().encode() + b"\n"
            if required not in output:
                raise AssertionError(
                    f"EROFS xattr missing for {label}/{path}: {required!r} in {output!r}"
                )


def verify_extracted_xattrs(
    root: Path,
    expected: dict[str, dict[bytes, bytes]],
    label: str,
) -> None:
    for name, attributes in expected.items():
        path = root if name == "/" else root / name
        for key, value in attributes.items():
            actual = os.getxattr(path, key)
            if actual != value:
                raise AssertionError(
                    f"EROFS extracted xattr mismatch for {label}/{name}/{key!r}"
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--directory-writer", type=Path)
    parser.add_argument("--metadata-zone-writer", type=Path)
    parser.add_argument("--mkfs", type=Path)
    parser.add_argument("--fsck", type=Path)
    parser.add_argument("--dump", type=Path)
    parser.add_argument("--metabox-oracle-fsck", "--metabox-inline-fsck", dest="metabox_oracle_fsck", type=Path,
                        help="separate erofs-utils oracle with metabox-inline-oracle.patch applied")
    args = parser.parse_args()
    mkfs = args.mkfs or (Path(found) if (found := shutil.which("mkfs.erofs")) else None)
    fsck = args.fsck or (Path(found) if (found := shutil.which("fsck.erofs")) else None)
    dump = args.dump or (Path(found) if (found := shutil.which("dump.erofs")) else None)
    if dump is None and fsck is not None:
        sibling = fsck.parent.parent / "dump" / "dump.erofs"
        if sibling.is_file():
            dump = sibling
    if (mkfs is None) != (fsck is None):
        raise AssertionError("both EROFS oracle tools are required")

    fixture_cases = 0
    plain_cases = 0
    lz4_cases = 0
    lzma_cases = 0
    modern_cases = 0
    writer_cases = 0
    external_writer = 0
    xattr_reader_cases = 0
    xattr_writer_cases = 0
    long_prefix_reader_cases = 0
    fragment_reader_cases = 0
    fragment_writer_cases = 0
    ztailpacking_reader_cases = 0
    ztailpacking_writer_cases = 0
    chunk_reader_cases = 0
    external_chunk_reader_cases = 0
    chunk_writer_cases = 0
    external_chunk_writer_cases = 0
    address48_reader_cases = 0
    address48_writer_cases = 0
    metabox_reader_cases = 0
    metabox_writer_cases = 0
    shared_xattr_writer_cases = 0
    directory_reader_cases = 0
    directory_writer_cases = 0
    extended_inode_reader_cases = 0
    extended_inode_writer_cases = 0
    lzma_writer_cases = 0
    final_big_pcluster_reader_cases = 0
    grouped_writer_cases = 0
    bounded_writer_cases = 0
    source_writer_cases = 0
    sink_writer_cases = 0
    encoder_writer_cases = 0
    file_source_writer_cases = 0
    source_reader_cases = 0
    resumable_reader_cases = 0
    directory_stream_cases = 0
    packed_prefix_reader_cases = 0
    partial_extent_reader_cases = 0
    partial_extent_error_cases = 0
    device_reader_cases = 0
    metadata_zone_writer_cases = 0
    metabox_inline_oracle_cases = 0
    metabox_combined_oracle_cases = 0
    original_fsck_writer_cases = 0
    dual_algorithm_reader_cases = 0
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
        payloads, source_xattrs = write_tree(source)
        primary = fixture

        writer_large = b"EROFS writer probe multi-block payload 0123456789\n" * 4096
        state = 0x1234_5678
        writer_random = bytearray()
        for _ in range(8193):
            state ^= (state << 13) & 0xFFFF_FFFF
            state ^= state >> 17
            state ^= (state << 5) & 0xFFFF_FFFF
            state &= 0xFFFF_FFFF
            writer_random.append(state & 0xFF)
        expected_writer = {
            "etc/config": b"writer probe configuration\n",
            "large.bin": writer_large,
            "random.bin": bytes(writer_random),
            "mixed.bin": bytes(writer_random[:8192]) * 2,
            "small": b"inline payload",
            "link": b"etc/config",
        }
        expected_writer_xattrs = {
            "/": {
                b"user.vort.root": b"root-xattr",
                b"user.vort.shared": b"shared-xattr",
            },
            "etc/config": {
                b"user.vort.config": b"config-xattr",
                b"user.vort.shared": b"shared-xattr",
            },
            "small": {
                b"user.vort.small": b"small-xattr",
                b"user.vort.shared": b"shared-xattr",
            },
            "empty": {
                b"user.vort.directory": b"directory-xattr",
                b"user.vort.shared": b"shared-xattr",
            },
        }
        grouped_modes = tuple(
            f"{codec}-clusters{suffix}"
            for codec in ("lz4", "lzma", "deflate", "zstd")
            for suffix in ("", "-fragments", "-ztailpacking", "-48bit", "-metabox", "-dirs", "-extended", "-dirs-extended-metabox")
        )
        bounded_modes = tuple(
            f"{codec}-bounded{suffix}"
            for codec in ("lz4", "lzma", "deflate", "zstd")
            for suffix in ("", "-fragments", "-ztailpacking", "-48bit", "-metabox", "-dirs", "-extended", "-dirs-extended-metabox", "8", "12")
        )
        combined_metabox_modes = ("chunk-local-metabox", "chunk-external-metabox") + tuple(
            f"{codec}{group}{tail}-metabox"
            for codec in ("lz4", "lzma", "deflate", "zstd")
            for group in ("", "-clusters", "-bounded")
            for tail in ("-fragments", "-ztailpacking")
        )
        file_source_writer_cases += verify_file_sources(args.cli, fsck, temp, expected_writer["mixed.bin"], run)
        writer_modes = (
            "stored",
            "lz4",
            "deflate",
            "zstd",
            "lz4-fragments",
            "deflate-fragments",
            "zstd-fragments",
            "lz4-ztailpacking",
            "deflate-ztailpacking",
            "zstd-ztailpacking",
            "chunk-local",
            "chunk-external",
            "stored-48bit",
            "lz4-48bit",
            "deflate-48bit",
            "zstd-48bit",
            "chunk-local-48bit",
            "chunk-external-48bit",
            "stored-metabox",
            "lz4-metabox",
            "deflate-metabox",
            "zstd-metabox",
            "lz4-dirs",
            "deflate-dirs",
            "zstd-dirs",
            "stored-extended",
            "lz4-extended",
            "deflate-extended",
            "zstd-extended",
            "lzma",
            "lzma-fragments",
            "lzma-ztailpacking",
            "lzma-48bit",
            "lzma-metabox",
            "lzma-dirs",
            "lzma-extended",
        ) + grouped_modes + bounded_modes + combined_metabox_modes
        for mode in writer_modes + tuple(f"{name}-source" for name in writer_modes) + tuple(f"{name}-sink" for name in writer_modes) + tuple(f"{name}-encoder" for name in writer_modes):
            source_mode = mode.endswith("-source")
            sink_mode = mode.endswith("-sink")
            encoder_mode = mode.endswith("-encoder")
            layout_mode = mode.removesuffix("-source").removesuffix("-sink").removesuffix("-encoder")
            image = temp / f"writer-{mode}.erofs"
            repeated = temp / f"writer-{mode}-repeat.erofs"
            device = temp / f"writer-{mode}.blob"
            repeated_device = temp / f"writer-{mode}-repeat.blob"
            is_external_chunk = mode.startswith("chunk-external")
            if is_external_chunk:
                run(args.writer, image, mode, device)
                run(args.writer, repeated, mode, repeated_device)
            else:
                run(args.writer, image, mode)
                run(args.writer, repeated, mode)
            if image.read_bytes() != repeated.read_bytes():
                raise AssertionError(f"non-deterministic EROFS writer output for {mode}")
            if (source_mode or sink_mode or encoder_mode) and image.read_bytes() != (temp / f"writer-{layout_mode}.erofs").read_bytes():
                raise AssertionError(f"EROFS source/sink/memory wire mismatch for {mode}")
            if is_external_chunk and device.read_bytes() != repeated_device.read_bytes():
                raise AssertionError(f"non-deterministic EROFS external chunks for {mode}")
            if (source_mode or sink_mode or encoder_mode) and is_external_chunk and device.read_bytes() != (temp / f"writer-{layout_mode}.blob").read_bytes():
                raise AssertionError(f"EROFS source/sink/memory device mismatch for {mode}")
            listing = run(args.cli, "list-erofs-file", image).stdout
            for required in (b"etc/config", b"large.bin", b"random.bin", b"mixed.bin", b"small", b"link", b"empty"):
                if required not in listing:
                    raise AssertionError(f"EROFS writer listing missing {required!r} for {mode}")
            for name, expected in expected_writer.items():
                output = temp / f"writer-{mode}-{name.replace('/', '-')}.out"
                command: list[object] = [
                    args.cli,
                    "extract-erofs-file",
                    image,
                    name,
                    output,
                    len(expected),
                ]
                if is_external_chunk:
                    command.append(device)
                run(*command)
                if output.read_bytes() != expected:
                    raise AssertionError(f"Vort writer self decode mismatch for {mode}/{name}")
            verify_vort_xattrs(args.cli, image, expected_writer_xattrs, f"writer-{mode}")
            if mode in (
                "stored", "lz4", "lzma", "deflate", "zstd",
                "lz4-fragments", "lzma-fragments", "deflate-ztailpacking", "zstd-ztailpacking",
                "lz4-metabox", "lzma-metabox", "zstd-dirs",
                "lz4-bounded", "lzma-bounded", "deflate-bounded", "zstd-bounded",
                "chunk-local", "chunk-external",
            ):
                output = temp / f"resumable-{mode}.out"
                command = [args.cli, "extract-erofs-file", image, "large.bin", output, len(expected_writer["large.bin"])]
                if is_external_chunk:
                    command.append(device)
                command.append("--output-chunk-size=17")
                run(*command)
                if output.read_bytes() != expected_writer["large.bin"]:
                    raise AssertionError(f"resumable file extraction mismatch for {mode}")
                resumable_reader_cases += 1
            if b"$vort-packed" in listing:
                raise AssertionError(f"hidden EROFS packed inode was listed for {mode}")
            if layout_mode.endswith("-fragments"):
                fragment_writer_cases += 1
            if layout_mode.endswith("-ztailpacking"):
                ztailpacking_writer_cases += 1
            if mode.startswith("chunk-local") or is_external_chunk:
                chunk_writer_cases += 1
            if is_external_chunk:
                external_chunk_writer_cases += 1
            if layout_mode.endswith("-48bit"):
                address48_writer_cases += 1
            if layout_mode.endswith("-metabox"):
                metabox_writer_cases += 1
            if "-dirs" in mode:
                directory_writer_cases += 1
            if "-extended" in mode:
                extended_inode_writer_cases += 1
            shared_xattr_writer_cases += 1
            if mode.startswith("lzma"):
                lzma_writer_cases += 1
            if "-clusters" in mode:
                grouped_writer_cases += 1
            if "-bounded" in mode:
                bounded_writer_cases += 1
            if source_mode:
                source_writer_cases += 1
            if sink_mode:
                sink_writer_cases += 1
            if encoder_mode:
                encoder_writer_cases += 1
            writer_cases += 1
            if fsck is not None:
                extracted = temp / f"writer-{mode}-fsck"
                metabox_inline = layout_mode.endswith("-ztailpacking-metabox")
                metabox_combined = layout_mode in combined_metabox_modes
                oracle = fsck
                if metabox_combined:
                    if args.metabox_oracle_fsck is None:
                        raise AssertionError("--metabox-oracle-fsck is required for metabox combination cases; see tools/erofs/metabox-inline-oracle.md")
                    oracle = args.metabox_oracle_fsck
                    metabox_combined_oracle_cases += 1
                    if metabox_inline:
                        metabox_inline_oracle_cases += 1
                fsck_command: list[object] = [
                    oracle,
                    f"--extract={extracted}",
                    "--no-preserve",
                    "--xattrs",
                ]
                if is_external_chunk:
                    fsck_command.append(f"--device={device}")
                fsck_command.append(image)
                run(*fsck_command)
                # fsck.erofs 1.9.4 currently creates zero-filled regular files
                # for flat-inline payloads whose inode lives in a metabox.  Its
                # dump --cat path and Vort both read the same wire correctly,
                # so keep fsck coverage on physical extents and directories and
                # rely on the self-decode checks above for these inline tails.
                checked_names = (
                    ("large.bin", "mixed.bin")
                    if layout_mode == "stored-metabox"
                    else ("etc/config", "large.bin", "random.bin", "mixed.bin", "small")
                )
                for name in checked_names:
                    if (extracted / name).read_bytes() != expected_writer[name]:
                        raise AssertionError(f"fsck.erofs writer mismatch for {mode}/{name}")
                if (extracted / "link").readlink().as_posix() != "etc/config":
                    raise AssertionError(f"fsck.erofs symlink mismatch for {mode}")
                if not (extracted / "empty").is_dir():
                    raise AssertionError(f"fsck.erofs empty directory missing for {mode}")
                if not layout_mode.endswith("-metabox") or layout_mode in combined_metabox_modes:
                    verify_extracted_xattrs(extracted, expected_writer_xattrs, f"writer-{mode}")
                    xattr_writer_cases += 1
                if not metabox_inline:
                    if metabox_combined:
                        original_extract = temp / f"writer-{mode}-original-fsck"
                        original_command = [fsck, f"--extract={original_extract}", "--no-preserve", "--xattrs"]
                        if is_external_chunk:
                            original_command.append(f"--device={device}")
                        run(*original_command, image)
                        for name in ("etc/config", "large.bin", "random.bin", "mixed.bin", "small"):
                            if (original_extract / name).read_bytes() != expected_writer[name]:
                                raise AssertionError(f"original fsck.erofs writer mismatch for {mode}/{name}")
                    original_fsck_writer_cases += 1
                external_writer += 1

        if mkfs is not None:
            assert fsck is not None
            help_text = run(mkfs, "--help", check=False).stderr + run(
                mkfs, "--help", check=False
            ).stdout
            cases: list[tuple[str, str | None, bool, str | None, tuple[str, ...]]] = [
                ("plain", None, False, None, ()),
                ("plain-48bit", None, False, None, ("48bit",)),
                ("plain-long-prefix", None, False, "user.vort.", ()),
                ("plain-extended", None, False, None, ("force-inode-extended",)),
                ("lz4-compact", "lz4", False, None, ()),
                ("lz4-full", "lz4", True, None, ()),
                ("lz4-48bit", "lz4", False, None, ("48bit",)),
                ("lz4-fragments", "lz4", False, None, ("fragments",)),
                ("lz4-all-fragments", "lz4", False, None, ("all-fragments",)),
                ("lz4-ztailpacking", "lz4", False, None, ("ztailpacking",)),
                ("lz4-extended", "lz4", False, None, ("force-inode-extended",)),
            ]
            if b"deflate" in help_text:
                cases.extend(
                    (
                        ("deflate-compact", "deflate", False, None, ()),
                        ("deflate-full", "deflate", True, None, ()),
                        ("deflate-48bit", "deflate", False, None, ("48bit",)),
                        ("deflate-fragments", "deflate", False, None, ("fragments",)),
                        ("deflate-ztailpacking", "deflate", False, None, ("ztailpacking",)),
                        ("deflate-extended", "deflate", False, None, ("force-inode-extended",)),
                    )
                )
            if b"lzma" in help_text:
                cases.extend(
                    (
                        ("lzma-compact", "lzma", False, None, ()),
                        ("lzma-full", "lzma", True, None, ()),
                    )
                )
            if b"zstd" in help_text:
                cases.extend(
                    (
                        ("zstd-compact", "zstd", False, None, ()),
                        ("zstd-48bit", "zstd", False, None, ("48bit",)),
                        ("zstd-fragments", "zstd", False, None, ("fragments",)),
                        ("zstd-ztailpacking", "zstd", False, None, ("ztailpacking",)),
                        ("zstd-extended", "zstd", False, None, ("force-inode-extended",)),
                    )
                )
            for label, compressor, legacy, xattr_prefix, features in cases:
                image = temp / f"{label}.erofs"
                make_image(
                    mkfs,
                    source,
                    image,
                    compressor,
                    legacy,
                    xattr_prefix,
                    features,
                )
                extracted = temp / f"{label}-fsck"
                run(fsck, f"--extract={extracted}", "--no-preserve", "--xattrs", image)
                if (extracted / "large.bin").read_bytes() != payloads["large.bin"]:
                    raise AssertionError(f"fsck.erofs extraction mismatch for {label}")
                verify_vort(args.cli, image, payloads, label, temp)
                verify_vort_xattrs(args.cli, image, source_xattrs, label)
                verify_extracted_xattrs(extracted, source_xattrs, label)
                xattr_reader_cases += 1
                if xattr_prefix is not None:
                    long_prefix_reader_cases += 1
                if "fragments" in features or "all-fragments" in features:
                    fragment_reader_cases += 1
                if "ztailpacking" in features:
                    ztailpacking_reader_cases += 1
                if "48bit" in features:
                    address48_reader_cases += 1
                if "force-inode-extended" in features:
                    extended_inode_reader_cases += 1
                if not features and xattr_prefix is None:
                    primary = image
                if compressor is None:
                    plain_cases += 1
                elif compressor == "lz4":
                    lz4_cases += 1
                elif compressor == "lzma":
                    lzma_cases += 1
                else:
                    modern_cases += 1

            directory_codecs = ["lz4"]
            if b"deflate" in help_text:
                directory_codecs.append("deflate")
            if b"zstd" in help_text:
                directory_codecs.append("zstd")
            for compressor in directory_codecs:
                label = f"{compressor}-directories"
                image = temp / f"{label}.erofs"
                make_image(
                    mkfs,
                    source,
                    image,
                    compressor,
                    False,
                    compress_directories=True,
                )
                extracted = temp / f"{label}-fsck"
                run(fsck, f"--extract={extracted}", "--no-preserve", "--xattrs", image)
                verify_vort(args.cli, image, payloads, label, temp)
                verify_vort_xattrs(args.cli, image, source_xattrs, label)
                verify_extracted_xattrs(extracted, source_xattrs, label)
                directory_reader_cases += 1
                xattr_reader_cases += 1

            final_big_pcluster_reader_cases += verify_final_big_pclusters(
                args.cli, mkfs, fsck, temp, help_text, make_image, run
            )

            chunk_cases = (
                ("chunk-local-map", (), None),
                ("chunk-local-index", ("force-chunk-indexes",), None),
                ("chunk-local-48bit", ("48bit", "force-chunk-indexes"), None),
                ("chunk-external", (), temp / "chunk-external.blob"),
                ("chunk-external-48bit", ("48bit",), temp / "chunk-external-48bit.blob"),
            )
            for label, features, blobdev in chunk_cases:
                image = temp / f"{label}.erofs"
                if blobdev is not None:
                    blobdev.touch()
                make_image(
                    mkfs,
                    source,
                    image,
                    None,
                    False,
                    features=features,
                    chunksize=4096,
                    blobdev=blobdev,
                )
                extracted = temp / f"{label}-fsck"
                fsck_args: list[object] = [
                    fsck,
                    f"--extract={extracted}",
                    "--no-preserve",
                    "--xattrs",
                ]
                if blobdev is not None:
                    fsck_args.append(f"--device={blobdev}")
                fsck_args.append(image)
                run(*fsck_args)
                verify_vort(
                    args.cli,
                    image,
                    payloads,
                    label,
                    temp,
                    (blobdev,) if blobdev is not None else (),
                )
                verify_vort_xattrs(args.cli, image, source_xattrs, label)
                verify_extracted_xattrs(extracted, source_xattrs, label)
                chunk_reader_cases += 1
                if blobdev is not None:
                    expect_failure(
                        args.cli,
                        "extract-erofs-file",
                        image,
                        "large.bin",
                        temp / "chunk-missing-device.out",
                        len(payloads["large.bin"]),
                        error_name="ErofsMissingDevice",
                    )
                    external_chunk_reader_cases += 1
                if "48bit" in features:
                    address48_reader_cases += 1

            for label, metabox in (("metabox-inodes", "i"), ("metabox-inodes-dirs", "id")):
                image = temp / f"{label}.erofs"
                make_image(
                    mkfs,
                    source,
                    image,
                    "lz4",
                    False,
                    metabox=metabox,
                )
                extracted = temp / f"{label}-fsck"
                run(
                    fsck,
                    f"--extract={extracted}",
                    "--no-preserve",
                    "--xattrs",
                    image,
                )
                verify_vort(args.cli, image, payloads, label, temp)
                verify_vort_xattrs(args.cli, image, source_xattrs, label)
                if (extracted / "large.bin").read_bytes() != payloads["large.bin"]:
                    raise AssertionError(f"fsck.erofs metabox extraction mismatch for {label}")
                metabox_reader_cases += 1

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

        source_reader_cases += verify_source_readers(args.cli, temp, run)
        directory_stream_cases += verify_directory_streams(args.cli, args.directory_writer, fsck, temp, run)
        packed_prefix_reader_cases += verify_packed_prefixes(args.cli, mkfs, fsck, temp, run)
        partial_extent_reader_cases, partial_extent_error_cases = verify_partial_extents(args.cli, fsck, temp, run)
        device_reader_cases = verify_device_readers(args.cli, args.writer, fsck, temp, run)
        metadata_zone_writer_cases = verify_metadata_zones(args.cli, args.metadata_zone_writer, fsck, dump, temp, run)
        dual_algorithm_reader_cases = verify_dual_algorithms(args.cli, fsck, temp, run)

    print(
        f"fixture_cases={fixture_cases} tools={mkfs is not None} "
        f"plain={plain_cases} lz4={lz4_cases} lzma={lzma_cases} "
        f"modern={modern_cases} "
        f"writer={writer_cases} external_writer={external_writer} "
        f"xattr_reader={xattr_reader_cases} xattr_writer={xattr_writer_cases} "
        f"long_prefix_reader={long_prefix_reader_cases} "
        f"fragment_reader={fragment_reader_cases} "
        f"fragment_writer={fragment_writer_cases} "
        f"ztailpacking_reader={ztailpacking_reader_cases} "
        f"ztailpacking_writer={ztailpacking_writer_cases} "
        f"chunk_reader={chunk_reader_cases} "
        f"external_chunk_reader={external_chunk_reader_cases} "
        f"chunk_writer={chunk_writer_cases} "
        f"external_chunk_writer={external_chunk_writer_cases} "
        f"address48_reader={address48_reader_cases} "
        f"address48_writer={address48_writer_cases} "
        f"metabox_reader={metabox_reader_cases} "
        f"metabox_writer={metabox_writer_cases} "
        f"shared_xattr_writer={shared_xattr_writer_cases} "
        f"directory_reader={directory_reader_cases} "
        f"directory_writer={directory_writer_cases} "
        f"extended_inode_reader={extended_inode_reader_cases} "
        f"extended_inode_writer={extended_inode_writer_cases} "
        f"lzma_writer={lzma_writer_cases} "
        f"final_big_pcluster_reader={final_big_pcluster_reader_cases} "
        f"grouped_writer={grouped_writer_cases} "
        f"bounded_writer={bounded_writer_cases} "
        f"source_writer={source_writer_cases} "
        f"sink_writer={sink_writer_cases} "
        f"encoder_writer={encoder_writer_cases} "
        f"file_source_writer={file_source_writer_cases} "
        f"source_reader={source_reader_cases} "
        f"resumable_reader={resumable_reader_cases} "
        f"directory_stream={directory_stream_cases} "
        f"packed_prefix_reader={packed_prefix_reader_cases} "
        f"partial_extent_reader={partial_extent_reader_cases} "
        f"partial_extent_errors={partial_extent_error_cases} "
        f"device_reader={device_reader_cases} "
        f"metadata_zone_writer={metadata_zone_writer_cases} "
        f"metabox_inline_oracle={metabox_inline_oracle_cases} "
        f"metabox_combined_oracle={metabox_combined_oracle_cases} "
        f"original_fsck_writer={original_fsck_writer_cases} "
        f"dual_algorithm_reader={dual_algorithm_reader_cases} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
