#!/usr/bin/env python3
"""Validate native Zstd HQ CLI controls without timing or reference-speed claims."""
import argparse
import ctypes
import ctypes.util
import hashlib
import json
from pathlib import Path
import random
import subprocess
import tempfile


HQ_STRATEGIES = ("lazy2", "btlazy2", "btopt", "btultra", "btultra2")


def samples():
    rng = random.Random(0x51544D)
    return {
        "empty": b"", "tiny": b"a", "rle": b"Q" * 257,
        "random": rng.randbytes(384), "repeated": b"abcd xyz-0123456789\n" * 48,
        "json": json.dumps([{"id": i, "name": "alpha-beta-" + str(i % 4)} for i in range(16)], separators=(",", ":")).encode(),
        "mixed": b"header-prefix-" + rng.randbytes(128) + b"block-prefix-alpha-beta\n" * 12 + rng.randbytes(128),
    }


class Reference:
    def __init__(self):
        self.library = ctypes.CDLL(ctypes.util.find_library("zstd"))
        self.library.ZSTD_versionString.restype = ctypes.c_char_p
        self.version = self.library.ZSTD_versionString().decode()
        self.library.ZSTD_decompress.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
        self.library.ZSTD_decompress.restype = ctypes.c_size_t
        self.library.ZSTD_isError.argtypes = (ctypes.c_size_t,)
        self.library.ZSTD_isError.restype = ctypes.c_uint

    def decode(self, frame, expected):
        output = ctypes.create_string_buffer(max(1, len(expected)))
        source = ctypes.create_string_buffer(frame)
        size = self.library.ZSTD_decompress(output, len(expected), source, len(frame))
        assert not self.library.ZSTD_isError(size), "upstream Zstd rejected frame"
        assert output.raw[:size] == expected, (size, len(expected))


def run(cli, command, positional, flags=()):
    return subprocess.run([str(cli), command, *map(str, positional), *flags], stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def profile_from(log):
    line = next(line for line in log.decode().splitlines() if line.startswith("zstd_profile "))
    result = {}
    for field in line.split()[1:]:
        key, value = field.split("=", 1)
        result[key] = (value == "true") if value in ("true", "false") else (int(value) if value.isdecimal() else value)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--legacy-baseline", type=Path, default=Path(__file__).parent / "testdata/hq_cli_legacy_wire.json")
    args = parser.parse_args()
    cli = args.cli.resolve()
    reference = Reference()
    corpus = samples()
    legacy = json.loads(args.legacy_baseline.read_text())
    assert legacy["samples"] == {name: hashlib.sha256(data).hexdigest() for name, data in corpus.items()}
    valid = old_wire = profile_wire = rejected = 0
    totals = {name: {"tree_nodes": 0, "price_evaluations": 0, "hq_passes": 0, "refinement_passes": 0} for name in HQ_STRATEGIES}
    with tempfile.TemporaryDirectory(prefix="vort-zstd-hq-cli-") as text:
        folder = Path(text)
        paths = {}
        for name, data in corpus.items():
            paths[name] = folder / (name + ".raw")
            paths[name].write_bytes(data)
        output = folder / "output.zst"

        def encode(command, positional, flags, expected):
            nonlocal valid
            result = run(cli, command, positional, flags)
            assert result.returncode == 0, result.stderr.decode(errors="replace")
            frame = bytes.fromhex(result.stdout.decode().splitlines()[0]) if command.endswith("hex") else output.read_bytes()
            reference.decode(frame, expected)
            assert (b"zstd_profile " in result.stdout) == ("--profile" in flags)
            valid += 1
            return frame, result.stdout

        # Frozen pre-HQ wire is independent of the new encoder and profile.
        for row in legacy["rows"]:
            for instrumented in (False, True):
                flags = tuple(row["args"]) + (("--profile",) if instrumented else ())
                frame, _ = encode("encode-zstd-native-file", (paths[row["sample"]], output), flags, corpus[row["sample"]])
                assert len(frame) == row["bytes"] and hashlib.sha256(frame).hexdigest() == row["sha256"], row
                old_wire += 1

        for strategy in HQ_STRATEGIES:
            base = (f"--strategy={strategy}", "--hq-depth=64", "--hq-nice-len=128", "--hq-min-match=3", "--hq-memory=33554432")
            for name, data in corpus.items():
                for command, level in (("encode-zstd-native-file", ()), ("encode-zstd-level-file", ("--level=12",))):
                    flags = base + level
                    plain, _ = encode(command, (paths[name], output), flags, data)
                    profiled, log = encode(command, (paths[name], output), flags + ("--profile",), data)
                    assert plain == profiled, (strategy, name, command, "profile changed wire")
                    metadata = profile_from(log)
                    assert metadata["hq_used"] and metadata["hq_depth"] == 64 and metadata["hq_nice_len"] == 128
                    assert metadata["hq_min_match"] == 3 and metadata["hq_memory"] == 33554432
                    if metadata["controls_used"] or metadata["hq_passes"]:
                        assert metadata["strategy"] == strategy
                    for key in totals[strategy]:
                        totals[strategy][key] += metadata[key]
                    profile_wire += 1
            for command, positional, data in (
                ("encode-zstd-native-hex", ("HQ alpha beta alpha beta payload",), b"HQ alpha beta alpha beta payload"),
                ("encode-zstd-native-bytes-hex", (corpus["mixed"].hex(),), corpus["mixed"]),
                ("encode-zstd-native-file-hex", (paths["json"],), corpus["json"]),
            ):
                plain, _ = encode(command, positional, base, data)
                profiled, _ = encode(command, positional, base + ("--profile",), data)
                assert plain == profiled
                profile_wire += 1

        for strategy, counters in totals.items():
            assert counters["hq_passes"] > 0, (strategy, counters)
            if strategy != "lazy2":
                assert counters["tree_nodes"] > 0, (strategy, counters)
            if strategy in ("btopt", "btultra", "btultra2"):
                assert counters["price_evaluations"] > 0, (strategy, counters)
            if strategy == "btultra2":
                assert counters["refinement_passes"] > 0, counters

        def failure(command, flags, source=paths["repeated"], scalar=False):
            nonlocal rejected
            sentinel = b"existing output must survive rejected HQ controls\n"
            output.write_bytes(sentinel)
            result = run(cli, command, (source, output), flags)
            assert result.returncode != 0, (command, flags)
            assert output.read_bytes() == sentinel, (command, flags)
            if scalar:
                assert b"InvalidBlockPlan" in result.stderr, result.stderr
            rejected += 1

        scalar_cases = [(f"--strategy={name}", "--hq-depth=16") for name in ("auto", "fast", "double_fast", "greedy", "lazy", "optimal")]
        scalar_cases += [(f"--strategy={name}", f"--level={level}") for name in HQ_STRATEGIES for level in (0, -1, -131072)]
        scalar_cases += [(f"--strategy={name}", "--fast-acceleration=2") for name in HQ_STRATEGIES]
        scalar_cases += [("--strategy=btopt", value) for value in ("--hq-depth=0", "--hq-depth=65537", "--hq-nice-len=2", "--hq-nice-len=131073", "--hq-min-match=2", "--hq-min-match=8")]
        scalar_cases += [("--strategy=btopt", "--hq-nice-len=3", "--hq-min-match=7"), ("raw_or_rle", "--strategy=btopt"), ("literal_only", "--strategy=btopt")]
        for command in ("encode-zstd-native-file", "encode-zstd-level-file"):
            for flags in scalar_cases:
                failure(command, flags, scalar=True)
                failure(command, flags, folder / "absent.raw", scalar=True)
            for flags in (("--strategy=btopt", "--hq-depth=64", "--hq-depth=64"), ("--strategy=btopt", "--hq-memory"), ("--hq-unknown=2",), ("--profile", "--profile")):
                failure(command, flags)
            for strategy in HQ_STRATEGIES:
                for limit in (0, 1):
                    failure(command, (f"--strategy={strategy}", f"--hq-memory={limit}"))

    print(json.dumps({"round_trips": valid, "legacy_wire_checks": old_wire, "hq_profile_wire_checks": profile_wire, "rejected_output_preserved": rejected, "hq_work_totals": totals, "reference_zstd": reference.version, "dictionary_cli_cases": 0}))


if __name__ == "__main__":
    main()
