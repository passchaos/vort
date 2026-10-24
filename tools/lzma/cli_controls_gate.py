#!/usr/bin/env python3
"""Verify encoder CLI options through the thin LZMA validation probe."""
import argparse
import json
import lzma
from pathlib import Path
import re
import subprocess
import tempfile


MAX_DICTIONARY_SIZE = 1610612736
MAX_CHUNK_SIZE = 2097152


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


def xz_first_block_chunks(encoded):
    """Inspect the first raw LZMA2 payload, stopping at its end marker."""
    assert encoded[:6] == b"\xfd7zXZ\0"
    offset = 12 + (encoded[12] + 1) * 4
    chunks = []
    while True:
        control = encoded[offset]
        offset += 1
        if control == 0:
            return chunks
        if control in (1, 2):
            size = int.from_bytes(encoded[offset:offset + 2], "big") + 1
            offset += 2
            chunks.append({"compressed": False, "uncompressed_size": size, "payload_size": size})
        else:
            assert control >= 128, control
            size = ((control & 31) << 16) + int.from_bytes(encoded[offset:offset + 2], "big") + 1
            payload_size = int.from_bytes(encoded[offset + 2:offset + 4], "big") + 1
            offset += 4 + int(control >= 192)
            chunks.append({"compressed": True, "uncompressed_size": size, "payload_size": payload_size})
            size = payload_size
        assert offset + size <= len(encoded)
        offset += size


def large_cases(cli, folder):
    # An explicit 2 MiB XZ block prevents the default 1 MiB block boundary
    # from silently limiting the requested LZMA2 chunk.
    seed = b"XZ large chunk CLI payload abcdefghijklmnopqrstuvwxyz\n"
    plain = (seed * ((MAX_CHUNK_SIZE + len(seed) - 1) // len(seed)))[:MAX_CHUNK_SIZE]
    source = folder / "large.raw"
    source.write_bytes(plain)
    target = folder / "large.xz"
    positional = ("crc64", str(MAX_CHUNK_SIZE))
    flags = ("--mode=fast", "--dict-size=4096", f"--chunk-size={MAX_CHUNK_SIZE}")
    encodings = []
    for profile in (False, True):
        result = run(cli, "encode-xz-file", source, target, positional, flags + (("--profile",) if profile else ()))
        assert result.returncode == 0, result.stderr.decode(errors="replace")
        encoded = target.read_bytes()
        assert lzma.decompress(encoded, format=lzma.FORMAT_XZ) == plain
        chunks = xz_first_block_chunks(encoded)
        assert len(chunks) == 1 and chunks[0]["compressed"], chunks
        assert chunks[0]["uncompressed_size"] == MAX_CHUNK_SIZE, chunks
        assert 1 <= chunks[0]["payload_size"] <= 65536, chunks
        assert b"blocks=1" in result.stdout
        encodings.append(encoded)
    assert encodings[0] == encodings[1], "2 MiB chunk profile changed wire"

    # Decode the actual large-dictionary header with Vort's public workspace,
    # using a real working allocator budget; never ask Python to allocate it.
    tiny = bytes(range(64))
    source = folder / "huge-dictionary.raw"
    source.write_bytes(tiny)
    target = folder / "huge-dictionary.lzma"
    result = run(cli, "encode-lzma-file", source, target, ("known",), (
        f"--dict-size={MAX_DICTIONARY_SIZE}", "--mode=fast", "--match-memory=4194304", "--profile",
    ))
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    encoded = target.read_bytes()
    encoder_peak = int(re.search(rb"peak_working_memory=(\d+)", result.stdout)[1])
    assert 0 < encoder_peak <= 4194304, encoder_peak
    assert int.from_bytes(encoded[1:5], "little") == MAX_DICTIONARY_SIZE
    assert int.from_bytes(encoded[5:13], "little") == len(tiny)
    output = folder / "huge-dictionary-decoded.raw"
    budget = 65536
    decoded = subprocess.run([
        str(cli), "decode-lzma-bounded-file", str(target), str(output),
        str(len(tiny)), str(MAX_DICTIONARY_SIZE), str(budget),
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert decoded.returncode == 0, decoded.stderr.decode(errors="replace")
    assert output.read_bytes() == tiny
    peak = int(re.search(rb"peak_working_memory=(\d+)", decoded.stdout)[1])
    assert 0 < peak <= budget, (peak, budget)

    # This separately proves that liblzma recognizes the large header and
    # enforces its memory limit. It is not an upstream full-frame round trip.
    reference = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE, memlimit=1024 * 1024)
    try:
        reference.decompress(encoded)
    except lzma.LZMAError as error:
        assert "Memory usage limit exceeded" in str(error), str(error)
    else:
        raise AssertionError("reference accepted the huge header below its memory requirement")
    return {
        "large_xz_round_trips": 2,
        "large_xz_payload_limit_checks": 2,
        "large_xz_profile_wire_checks": 1,
        "huge_known_vort_bounded_round_trips": 1,
        "huge_known_encoder_budget": 4194304,
        "huge_known_encoder_peak": encoder_peak,
        "huge_known_decoder_budget": budget,
        "huge_known_decoder_peak": peak,
        "huge_header_reference_memlimit_checks": 1,
    }


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
            legacy, _ = success(command, positional)
            if command == "encode-xz-file":
                explicit_chunk_default, _ = success(command, positional, ("--chunk-size=65536",))
                assert legacy == explicit_chunk_default, "explicit default chunk changed legacy wire"
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
                ("--depth=4294967296",), ("--dict-size=4095",), (f"--dict-size={MAX_DICTIONARY_SIZE + 1}",),
                ("--mode=adaptive",), ("--lc=4", "--lp=1"), ("--pb=5",),
                ("--unknown=1",), ("--preset=",), ("--profile", "--profile"), ("--profile",),
                ("--preset=0", "--match-memory=0"), ("--preset=0", "extra"),
            ):
                failure(command, positional, bad)
            missing_input = failure(command, positional, ("--lc=4", "--lp=1"), folder / "absent.raw")
            assert b"InvalidLzmaOptions" in missing_input.stderr, missing_input.stderr
            if command == "encode-xz-file":
                for bad_chunk in (("--chunk-size=0",), (f"--chunk-size={MAX_CHUNK_SIZE + 1}",), ("--chunk-size=65536", "--chunk-size=65536"), ("--chunk-size=",)):
                    failure(command, positional, bad_chunk)
                early = failure(command, positional, ("--chunk-size=0",), folder / "absent.raw")
                assert b"InvalidBlockPlan" in early.stderr
            else:
                rejected = failure(command, positional, ("--chunk-size=65536",))
                assert b"UnsupportedLzmaChunkSize" in rejected.stderr
                early = failure(command, positional, ("--chunk-size=65536",), folder / "absent.raw")
                assert b"UnsupportedLzmaChunkSize" in early.stderr

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
        stored_legacy, _ = success("encode-xz-stored-file", ("none", "1024", "none", "4096", "greedy"))
        stored_explicit, _ = success("encode-xz-stored-file", ("none", "1024", "none", "4096", "greedy"), ("--chunk-size=65536",))
        assert stored_legacy == stored_explicit, "stored explicit default chunk changed wire"
        failure("encode-xz-stored-file", (), ("--chunk-size=0",))
        failure("encode-xz-stored-file", (), (f"--chunk-size={MAX_CHUNK_SIZE + 1}",))
        success("encode-microlzma-file", ("4096", "2", "1", "0", "lazy"))
        failure("encode-microlzma-prefix-file", ("5",), ())
        failure("encode-microlzma-aligned-prefix-file", ("256", "0"), ())
        large_report = large_cases(cli, folder)

    print(json.dumps({"valid_round_trips": valid, "rejected_output_preserved": invalid, "flag_order_checks": order_checks, "profile_wire_checks": profile_checks, **large_report}))


if __name__ == "__main__":
    main()
