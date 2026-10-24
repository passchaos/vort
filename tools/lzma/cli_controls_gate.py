#!/usr/bin/env python3
"""Verify real LZMA/XZ/MicroLZMA CLI options through the thin or full CLI."""
import argparse
import json
import lzma
from pathlib import Path
import re
import subprocess
import tempfile


def run(cli, command, source, target, positional=(), flags=()):
    return subprocess.run(
        [str(cli), command, str(source), str(target), *positional, *flags],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def decoded_payload(command, encoded, log):
    if command == "encode-lzma-file":
        return lzma.decompress(encoded, format=lzma.FORMAT_ALONE)
    if command.startswith("encode-xz"):
        return lzma.decompress(encoded, format=lzma.FORMAT_XZ)
    prop = (~encoded[0]) & 255
    lc, prop = prop % 9, prop // 9
    lp, pb = prop % 5, prop // 5
    dictionary = int(re.search(rb"dictionary=(\d+)", log)[1])
    decoder = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{
        "id": lzma.FILTER_LZMA1, "dict_size": dictionary,
        "lc": lc, "lp": lp, "pb": pb,
    }])
    return decoder.decompress(b"\0" + encoded[1:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", type=Path, required=True)
    args = parser.parse_args()
    cli = args.cli.resolve()
    plain = b"LZMA preset CLI payload abcdefghijklmnopqrstuvwxyz\n" * 96
    layouts = (
        ("encode-lzma-file", ()),
        ("encode-xz-file", ()),
        ("encode-microlzma-file", ()),
        ("encode-microlzma-prefix-file", ("256",)),
        ("encode-microlzma-aligned-prefix-file", ("256", "16")),
    )
    valid = invalid = order_checks = profile_checks = 0
    with tempfile.TemporaryDirectory(prefix="vort-lzma-cli-") as directory:
        folder = Path(directory)
        source = folder / "input.raw"
        source.write_bytes(plain)
        target = folder / "output.bin"

        def success(command, positional=(), flags=()):
            nonlocal valid
            result = run(cli, command, source, target, positional, flags)
            if result.returncode:
                raise AssertionError(f"failed {command} {flags}: {result.stderr.decode(errors='replace')}")
            decoded = decoded_payload(command, target.read_bytes(), result.stdout)
            consumed = re.search(rb"consumed=(\d+)", result.stdout)
            expected = plain[:int(consumed[1])] if consumed else plain
            assert decoded == expected, (command, flags, len(decoded), len(expected))
            if command == "encode-microlzma-aligned-prefix-file" and len(expected) < len(plain):
                assert len(expected) % int(positional[1]) == 0
            assert (b"lzma_profile " in result.stdout) == ("--profile" in flags)
            valid += 1
            return target.read_bytes(), result.stdout

        def failure(command, positional, flags, source_path=source):
            nonlocal invalid
            sentinel = b"existing output must survive rejected controls\n"
            target.write_bytes(sentinel)
            result = run(cli, command, source_path, target, positional, flags)
            assert result.returncode != 0, (command, flags)
            assert target.read_bytes() == sentinel, (command, flags)
            invalid += 1
            return result

        for command, positional in layouts:
            success(command, positional)
            success(command, positional, ("--preset=0",))
            success(command, positional, ("--preset=6", "--dict-size=4096"))
            success(command, positional, ("--preset=9", "--extreme", "--dict-size=4096", "--profile"))
            flags = (
                "--preset=9", "--extreme", "--dict-size=4096", "--mode=fast",
                "--match-finder=bt2", "--nice-len=2", "--depth=17",
                "--lc=2", "--lp=1", "--pb=0", "--match-memory=1048576", "--profile",
            )
            first, _ = success(command, positional, flags)
            second, _ = success(command, positional, tuple(reversed(flags)))
            assert first == second, (command, "flag order changed output")
            unprofiled, _ = success(command, positional, tuple(flag for flag in flags if flag != "--profile"))
            assert first == unprofiled, (command, "explicit controls profile changed output")
            preset_plain, _ = success(command, positional, ("--preset=6", "--dict-size=4096"))
            preset_profiled, _ = success(command, positional, ("--preset=6", "--dict-size=4096", "--profile"))
            assert preset_plain == preset_profiled, (command, "preset profile changed output")
            profile_checks += 2
            for mode in ("fast", "normal"):
                mode_plain, _ = success(command, positional, (f"--mode={mode}",))
                mode_profiled, log = success(command, positional, (f"--mode={mode}", "--profile"))
                assert mode_plain == mode_profiled, (command, mode, "mode-only profile changed output")
                expected_finder = "bt4" if mode == "normal" else "hc4"
                expected_depth = 48 if mode == "normal" else 20
                assert f"finder={expected_finder}".encode() in log
                assert f"depth={expected_depth}".encode() in log
                profile_checks += 1
            if command == "encode-lzma-file":
                assert first[0] == 11 and int.from_bytes(first[1:5], "little") == 4096
            elif command.startswith("encode-microlzma"):
                assert first[0] == (11 ^ 255)
            order_checks += 1
            for bad in (
                ("--extreme",), ("--preset=10",), ("--preset=2", "--preset=2"),
                ("--nice-len=1",), ("--nice-len=274",), ("--match-finder=bt5",),
                ("--depth=4294967296",), ("--dict-size=4095",), ("--dict-size=67108865",),
                ("--mode=adaptive",), ("--lc=4", "--lp=1"), ("--pb=5",),
                ("--unknown=1",), ("--preset=",), ("--profile", "--profile"), ("--profile",),
                ("--preset=0", "--match-memory=0"), ("--preset=0", "extra"),
            ):
                failure(command, positional, bad)
            missing_input = failure(command, positional, ("--lc=4", "--lp=1"), folder / "absent.raw")
            assert b"InvalidLzmaOptions" in missing_input.stderr, missing_input.stderr

        for level in range(10):
            for extreme in (False, True):
                preset_flags = (f"--preset={level}", "--dict-size=4096")
                if extreme:
                    preset_flags += ("--extreme",)
                success("encode-lzma-file", (), preset_flags)

        for finder in ("hc3", "hc4", "bt2", "bt3", "bt4"):
            for mode in ("fast", "normal"):
                _, log = success("encode-lzma-file", (), (
                    f"--match-finder={finder}", f"--mode={mode}", "--nice-len=2", "--depth=0", "--profile",
                ))
                assert f"finder={finder}".encode() in log
                assert int(re.search(rb"positions=(\d+)", log)[1]) > 0
        success("encode-lzma-file", ("known",))
        success("encode-xz-file", ("crc32", "1024", "delta:1", "4096", "lazy"))
        success("encode-xz-stored-file", ("none", "1024", "none", "4096", "greedy"))
        success("encode-microlzma-file", ("4096", "2", "1", "0", "lazy"))
        failure("encode-microlzma-prefix-file", ("5",), ())
        failure("encode-microlzma-aligned-prefix-file", ("256", "0"), ())

    print(json.dumps({"valid_round_trips": valid, "rejected_output_preserved": invalid, "flag_order_checks": order_checks, "profile_wire_checks": profile_checks}))


if __name__ == "__main__":
    main()
