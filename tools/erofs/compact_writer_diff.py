import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from writer_matrix import writer_modes, combined_metabox_modes, payloads, xattrs


def run(*args, check=True):
    return subprocess.run([str(arg) for arg in args], check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def verify_cli(cli, fsck, temp, runner=run):
    if cli is None:
        return 0, 0
    expected = b"compact CLI payload 0123456789\n" * 4096
    source = temp / "compact-cli-input"
    source.write_bytes(expected)
    valid = 0
    malformed = 0
    for index_format in ("full", "compact-4byte", "compact"):
        for codec in ("lz4", "lzma", "deflate", "zstd"):
            image = temp / f"compact-cli-{index_format}-{codec}.erofs"
            runner(cli, "create-erofs-file", image, "file", source, codec, 65536, 8192, f"--compressed-index-format={index_format}", "--output-chunk-size=17")
            output = temp / f"compact-cli-{index_format}-{codec}.out"
            runner(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17")
            if output.read_bytes() != expected or source.read_bytes() != expected:
                raise AssertionError(f"CLI compact byte mismatch: {index_format}/{codec}")
            if fsck is not None:
                destination = temp / f"compact-cli-{index_format}-{codec}-fsck"
                runner(fsck, f"--extract={destination}", "--no-preserve", image)
                if (destination / "file").read_bytes() != expected:
                    raise AssertionError(f"CLI compact oracle mismatch: {index_format}/{codec}")
            valid += 1
    for index_format in ("compact-4byte", "compact"):
        same = temp / f"compact-cli-same-{index_format}"
        same.write_bytes(expected)
        runner(cli, "create-erofs-file", same, "file", same, "lz4", f"--compressed-index-format={index_format}")
        output = temp / f"compact-cli-same-{index_format}.out"
        runner(cli, "extract-erofs-file", same, "file", output, len(expected))
        if output.read_bytes() != expected:
            raise AssertionError("compact CLI same-path replacement lost input")
        valid += 1
    for name, extra, error in (
        ("invalid-format", ["--compressed-index-format=unknown"], b"InvalidBlockPlan"),
        ("compact-budget", ["--compressed-index-format=compact", "--working-memory-limit=1"], b"WorkingMemoryLimitExceeded"),
        ("compact4-budget", ["--compressed-index-format=compact-4byte", "--working-memory-limit=1"], b"WorkingMemoryLimitExceeded"),
    ):
        image = temp / f"compact-cli-bad-{name}.erofs"
        image.write_bytes(b"keep previous output")
        before = set(temp.iterdir())
        result = runner(cli, "create-erofs-file", image, "file", source, "lz4", *extra, check=False)
        if result.returncode == 0 or error not in result.stderr:
            raise AssertionError(f"compact CLI missing {error!r}: {result.stderr!r}")
        if image.read_bytes() != b"keep previous output" or before != set(temp.iterdir()):
            raise AssertionError(f"compact CLI failure changed output: {name}")
        malformed += 1
    return valid, malformed


def verify_writers(writer, fsck, metabox_fsck, dump, oracle, temp):
    expected = payloads()
    modes = tuple(mode for mode in writer_modes if mode.startswith(("lz4", "lzma", "deflate", "zstd")))
    cases = 0
    external = 0
    ranges = 0
    patched = 0
    for index_format in ("compact4", "compact"):
        for surface in ("", "-source", "-sink", "-encoder"):
            for mode in modes:
                label = f"{index_format}-{mode}{surface}"
                image = temp / f"{label}.erofs"
                repeated = temp / f"{label}-repeat.erofs"
                # The native probe verifies Source whole/range bytes, inode
                # layout/flags and all xattrs through the same public APIs.
                run(writer, image, label)
                run(writer, repeated, label)
                if image.read_bytes() != repeated.read_bytes():
                    raise AssertionError(f"non-deterministic compact output: {label}")
                repeated.unlink()
                if surface and image.read_bytes() != (temp / f"{index_format}-{mode}.erofs").read_bytes():
                    raise AssertionError(f"compact memory/Source/Sink/encoder mismatch: {label}")
                if fsck is not None:
                    destination = temp / f"{label}-fsck"
                    combined = mode in combined_metabox_modes
                    if combined and metabox_fsck is None:
                        raise AssertionError("--metabox-oracle-fsck is required for metabox tail combinations")
                    reference = metabox_fsck if combined else fsck
                    run(reference, f"--extract={destination}", "--no-preserve", "--xattrs", image)
                    for name, value in expected.items():
                        actual = (destination / name).readlink().as_posix().encode() if name == "link" else (destination / name).read_bytes()
                        if actual != value:
                            raise AssertionError(f"compact fsck mismatch: {label}/{name}")
                    if not (destination / "empty").is_dir():
                        raise AssertionError(f"compact directory missing: {label}")
                    if not mode.endswith("-metabox") or combined:
                        import os
                        for name, attrs in xattrs.items():
                            path = destination if name == "/" else destination / name
                            for key, value in attrs.items():
                                if os.getxattr(path, key) != value:
                                    raise AssertionError(f"compact oracle xattr mismatch: {label}/{name}/{key}")
                    shutil.rmtree(destination)
                    external += 1
                    patched += int(combined)
                if oracle is not None and dump is not None and not mode.endswith("-metabox"):
                    for name in ("large.bin", "mixed.bin"):
                        report = run(dump, f"--path=/{name}", image).stdout
                        nid = int(re.search(rb"NID:\s*(\d+)", report)[1])
                        for start in (4093, 8192, len(expected[name]) - 31):
                            result = run(oracle, image, nid, start, 31).stdout
                            if result != expected[name][start:start + 31]:
                                raise AssertionError(f"compact positional oracle mismatch: {label}/{name}/{start}")
                            ranges += 1
                cases += 1
            print(f"compact progress: format={index_format} surface={surface or 'memory'} cases={cases}", flush=True)
    return cases, external, ranges, patched


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--fsck", type=Path)
    parser.add_argument("--metabox-oracle-fsck", type=Path)
    parser.add_argument("--dump", type=Path)
    parser.add_argument("--range-oracle", type=Path)
    parser.add_argument("--cli", type=Path)
    args = parser.parse_args()
    fsck = args.fsck or (Path(found) if (found := shutil.which("fsck.erofs")) else None)
    dump = args.dump
    if dump is None and fsck is not None:
        sibling = fsck.parent.parent / "dump/dump.erofs"
        if sibling.is_file():
            dump = sibling
    with tempfile.TemporaryDirectory(prefix="vort-erofs-compact-") as name:
        temp = Path(name)
        cases, external, ranges, patched = verify_writers(args.writer, fsck, args.metabox_oracle_fsck, dump, args.range_oracle, temp)
        cli_cases, cli_errors = verify_cli(args.cli, fsck, temp)
    print(f"compact_writer={cases} compact_external={external} compact_ranges={ranges} compact_metabox_oracle={patched} compact_cli={cli_cases} compact_cli_errors={cli_errors}")


if __name__ == "__main__":
    main()
