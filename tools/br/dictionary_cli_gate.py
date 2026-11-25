#!/usr/bin/env python3
"""Black-box checks for the Brotli file CLI's RAW dictionary on native and WASI."""

import argparse
import os
from pathlib import Path
import random
import subprocess
import tempfile


ONE_SHOT = "encode-br-file"
STREAM = "encode-br-stream-file"
DECODE = "decode-br-file-to"
DEFAULT_CAP = 32 << 20
TIMEOUT = 15
SENTINEL = b"\x00keep the existing output\xff\n"

# Upstream RAW fixture from src/br/decode/tests/fixtures.zig, cross-checked
# with Brotli 1.2.0. This stream copies the entire shared prefix. Without it,
# the same distance resolves to a static dictionary word, not the source.
UPSTREAM_WIRE = bytes.fromhex("a1a800c02f0110c4440900")
UPSTREAM_PLAIN = b"Kot lomom kolol slona!"


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def describe(result):
    return (f"argv={result.args!r}, exit={result.returncode}, stdout={len(result.stdout)} bytes "
            f"(first 32: {result.stdout[:32]!r}), stderr={result.stderr!r}")


def success(label, result, *allowed_stdout):
    require(result.returncode == 0 and result.stderr == b"",
            f"{label}: {describe(result)}")
    if allowed_stdout:
        require(result.stdout in allowed_stdout, f"{label}: wrong stdout; {describe(result)}")
    return result.stdout


def failure(label, result, error):
    require(result.returncode > 0 and not result.stdout
            and f"error: {error}".encode() in result.stderr.splitlines(),
            f"{label}: expected {error} and empty stdout; {describe(result)}")


def summary(wire, plain, target):
    return f"br_compressed_bytes={len(wire)} decoded_bytes={len(plain)} path={target.name}\n".encode()


def seed(target):
    target.write_bytes(SENTINEL)
    return target.stat().st_ino


def replaced(label, target, old_inode, expected):
    require(target.read_bytes() == expected, f"{label}: wrong named output")
    if os.name == "posix":
        require(target.stat().st_ino != old_inode, f"{label}: destination overwritten in place")


def rejected_target(label, target, error, run):
    old_inode = seed(target)
    failure(label, run(target.name), error)
    require(target.read_bytes() == SENTINEL and target.stat().st_ino == old_inode,
            f"{label}: existing destination changed")


def require_dependency(label, decode, wire, plain, wrong_name):
    # RAW Brotli has neither a dictionary ID nor an identity checksum. A
    # different distance interpretation can be valid but yield wrong bytes.
    for options in ((), ("--dictionary", wrong_name)):
        result = decode("-", "-", *options, data=wire)
        rejected = result.returncode > 0 and any(line.startswith(b"error: ") for line in result.stderr.splitlines())
        different = result.returncode == 0 and result.stderr == b"" and result.stdout != plain
        require(rejected or different,
                f"{label}: expected rejection or different bytes without the matching RAW dictionary; {describe(result)}")


def check_encode(round_trip, invoke, cwd, command, plain, dictionary):
    source = cwd / "input.raw"
    target = cwd / "encoded.br"
    quality = "--quality=5"
    cap = f"--max-dictionary-bytes={len(dictionary)}"
    equal = "--dictionary=payload.dict"
    split = ("--dictionary", "payload.dict")
    empty = ("--dictionary=empty.dict", "--max-dictionary-bytes=0")
    source.write_bytes(plain)

    def encode(src, dst, *options, data=b""):
        return invoke(command, src, dst, quality, *options, data=data)

    def named(label, *options):
        inode = seed(target)
        result = encode(source.name, target.name, *options)
        success(label, result)
        wire = target.read_bytes()
        require(wire != SENTINEL, f"{label}: destination not published")
        if os.name == "posix":
            require(target.stat().st_ino != inode, f"{label}: destination overwritten in place")
        success(label, result, b"", summary(wire, plain, target))
        return wire

    if command == STREAM:
        baseline = success("streaming control pipe", encode("-", "-", data=plain))
        wire = success("dictionary encoding from stdin to stdout", encode("-", "-", equal, data=plain))
        success("file to stdout, split flag and inclusive cap", encode(source.name, "-", cap, *split), wire)
        inode = seed(target)
        success("stdin to file is quiet", encode("-", target.name, *split, data=plain), b"")
        replaced("dictionary encoding from stdin to file", target, inode, wire)
        require(named("streaming named paths", equal) == wire, "streaming named paths: changed wire")
        success("streaming empty dictionary is a no-op", encode("-", "-", *empty, data=plain), baseline)
    else:
        baseline = named("one-shot control")
        wire = named("one-shot with dictionary", equal)
        require(named("one-shot split flag and inclusive cap", *split, cap) == wire,
                "one-shot split flag: changed wire")
        require(named("one-shot empty dictionary", *empty) == baseline, "one-shot empty dictionary: changed wire")

    require(0 < len(wire) < len(baseline),
            f"{command}: RAW dictionary did not shorten wire ({len(wire)} vs {len(baseline)})")
    success(f"{command} RAW round trip", round_trip("-", "-", equal, data=wire), plain)
    success(f"{command} control round trip", round_trip("-", "-", data=baseline), plain)
    success(f"{command} empty dictionary decode is a no-op", round_trip("-", "-", *empty, data=baseline), plain)
    require_dependency(command, round_trip, wire, plain, "wrong-payload.dict")
    check_limits(encode, source, target, "payload.dict", len(dictionary), plain if command == STREAM else None)


def check_limits(run, source, target, dictionary_name, size, stdin):
    dictionary = f"--dictionary={dictionary_name}"
    exact = f"--max-dictionary-bytes={size}"
    low = (dictionary, f"--max-dictionary-bytes={size - 1}")
    cases = (
        ("dictionary aliases are singleton", (dictionary, "--dictionary", dictionary_name), "DuplicateBrotliOption"),
        ("dictionary cap is singleton", (dictionary, exact, exact), "DuplicateBrotliOption"),
        ("cap without a dictionary", (exact,), "MissingBrotliDictionary"),
        ("dictionary exceeds explicit cap", low, "OutputLimitExceeded"),
        ("dictionary exceeds default cap", ("--dictionary=oversize.dict",), "OutputLimitExceeded"),
    )
    for label, options, error in cases:
        rejected_target(label, target, error, lambda dst: run(source.name, dst, *options))
    if stdin is not None:
        failure("dictionary cap rejection sends no stdout", run("-", "-", *low, data=stdin), "OutputLimitExceeded")
        rejected_target("dictionary cap preserves a mixed-route target", target, "OutputLimitExceeded",
                        lambda dst: run("-", dst, *low, data=stdin))


def check_upstream(decode, cwd):
    source = cwd / "upstream.br"
    target = cwd / "decoded.raw"
    source.write_bytes(UPSTREAM_WIRE)
    (cwd / "upstream.dict").write_bytes(UPSTREAM_PLAIN)
    (cwd / "wrong-upstream.dict").write_bytes(bytes(byte ^ 0xff for byte in UPSTREAM_PLAIN))
    equal = "--dictionary=upstream.dict"
    split = ("--dictionary", "upstream.dict")
    cap = f"--max-dictionary-bytes={len(UPSTREAM_PLAIN)}"
    plaintext_cap = str(len(UPSTREAM_PLAIN))

    success("upstream stdin to stdout", decode("-", "-", equal, data=UPSTREAM_WIRE), UPSTREAM_PLAIN)
    success("upstream file to stdout with both caps", decode(source.name, "-", cap, *split, plaintext_cap), UPSTREAM_PLAIN)
    inode = seed(target)
    success("upstream stdin to file is quiet", decode("-", target.name, *split, data=UPSTREAM_WIRE), b"")
    replaced("upstream stdin to file", target, inode, UPSTREAM_PLAIN)
    seed(target)
    success("upstream named paths", decode(source.name, target.name, *split),
            b"", summary(UPSTREAM_WIRE, UPSTREAM_PLAIN, target))
    require(target.read_bytes() == UPSTREAM_PLAIN, "upstream named paths: wrong payload")
    require_dependency("upstream fixture", decode, UPSTREAM_WIRE, UPSTREAM_PLAIN, "wrong-upstream.dict")

    rejected_target("trailing data preserves a mixed-route target", target, "TrailingData",
                    lambda dst: decode("-", dst, equal, data=UPSTREAM_WIRE + b"\x00"))
    check_limits(decode, source, target, "upstream.dict", len(UPSTREAM_PLAIN), UPSTREAM_WIRE)

    # The fixture refers to the suffix by distance, so prefix padding doesn't
    # change its output. This covers the exact default on an actual RAW copy.
    with (cwd / "default-cap.dict").open("wb") as dictionary:
        dictionary.seek(DEFAULT_CAP - len(UPSTREAM_PLAIN))
        dictionary.write(UPSTREAM_PLAIN)
    success("default cap is inclusive", decode(source.name, "-", "--dictionary=default-cap.dict"), UPSTREAM_PLAIN)


def check_native_auxiliary(prefix, cwd, decode):
    def invoke(*args):
        return subprocess.run([*prefix, *args], cwd=cwd, capture_output=True, timeout=TIMEOUT)

    option = "--dictionary=upstream.dict"
    size = invoke("size-br-file", "upstream.br", option)
    success("dictionary-aware size inspection", size,
            f"br_compressed_bytes={len(UPSTREAM_WIRE)} decoded_bytes={len(UPSTREAM_PLAIN)}\n".encode())
    decoded = success("decode dictionary-backed hex", invoke("decode-br-hex", UPSTREAM_WIRE.hex(), option))
    require(decoded.endswith(b" text=" + UPSTREAM_PLAIN + b"\n"), "hex decoding lost the RAW dictionary")
    encoded = success("encode hex with RAW dictionary", invoke("encode-br-hex", UPSTREAM_PLAIN.decode(), option))
    wire = bytes.fromhex(encoded.decode())
    success("decode dictionary-aware hex encoder output", decode("-", "-", option, data=wire), UPSTREAM_PLAIN)
    target = cwd / "stored.br"
    rejected_target("stored encoding rejects a dictionary", target, "UnsupportedBrotliStoredOption",
                    lambda dst: invoke("encode-br-stored-file", "input.raw", dst, option))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=Path, help="built Vort CLI executable or WASI probe")
    parser.add_argument("--wasi-runner", type=Path, help="Node WASI runner for the probe")
    args = parser.parse_args()
    prefix = [str(args.cli.resolve())]
    mode = "native"
    if args.wasi_runner is not None:
        mode = "wasi"
        prefix[:0] = ["node", "--no-warnings", str(args.wasi_runner.resolve())]

    # The WASI runner preopens its working directory as '.'.
    with tempfile.TemporaryDirectory(prefix="vort-br-dictionary-cli-") as directory:
        cwd = Path(directory)

        def invoke(command, src, dst, *options, data=b""):
            return subprocess.run([*prefix, command, src, dst, *options], cwd=cwd, input=data,
                                  capture_output=True, timeout=TIMEOUT)

        def decode(src, dst, *options, data=b""):
            return invoke(DECODE, src, dst, *options, data=data)

        rng = random.Random(105)
        dictionary = bytes(rng.getrandbits(8) for _ in range(1024))
        # High-entropy binary input makes this long interior RAW match useful.
        plain = dictionary[97:929]
        (cwd / "payload.dict").write_bytes(dictionary)
        (cwd / "wrong-payload.dict").write_bytes(bytes(byte ^ 0xff for byte in dictionary))
        (cwd / "empty.dict").write_bytes(b"")
        with (cwd / "oversize.dict").open("wb") as oversized:
            oversized.truncate(DEFAULT_CAP + 1)

        check_upstream(decode, cwd)
        check_encode(decode, invoke, cwd, STREAM, plain, dictionary)
        check_encode(decode, invoke, cwd, ONE_SHOT, plain, dictionary)
        if mode == "native":
            check_native_auxiliary(prefix, cwd, decode)
    print(f"br_dictionary_cli mode={mode} status=ok")


if __name__ == "__main__":
    main()
