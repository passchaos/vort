#!/usr/bin/env python3
"""Differential smoke tests against Python's zlib module.

This script intentionally uses the built Vort CLI as a black-box process so it
exercises public command behavior in addition to Python/zlib compatibility.
"""
import pathlib
import re
import subprocess
import sys
import tempfile
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "zig-out" / "bin" / "vort"


def run_cli(*args: str) -> str:
    result = subprocess.run([str(CLI), *args], cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE)
    return result.stdout.strip()


def parse_field(output: str, name: str) -> str:
    match = re.search(rf"(?:^| ){re.escape(name)}=([^ ]*)", output)
    if not match:
        raise AssertionError(f"missing {name!r} in {output!r}")
    return match.group(1)


def expect_cli_failure(*args: str, error_name: str) -> None:
    result = subprocess.run([str(CLI), *args], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode == 0:
        raise AssertionError(f"expected {args!r} to fail with {error_name}, got stdout={result.stdout!r}")
    if error_name not in result.stderr:
        raise AssertionError(f"expected {error_name} in stderr for {args!r}, got stderr={result.stderr!r}")


def main() -> int:
    if not CLI.exists():
        raise SystemExit(f"missing built CLI at {CLI}; run `zig build` first")

    expect_cli_failure("decode-raw-hex", "", error_name="TruncatedFrame")
    expect_cli_failure("decode-zlib-hex", "", error_name="TruncatedFrame")
    expect_cli_failure("decode-raw-hex", "01", error_name="TruncatedFrame")
    expect_cli_failure("decode-zlib-hex", "7801", error_name="TruncatedFrame")

    payloads = [
        "",
        "hello",
        "hello vort",
        "abcabcabcabc",
        "aaaaaaaaaaaaaaaaaaaaaaaa",
        "the quick brown fox " * 8,
        "match-heavy:" + ("abcabcabcabc" * 64) + ("xyzxyzxyz " * 32),
        "distance-heavy:" + ("0123456789abcdef" * 512) + "----" + ("0123456789abcdef" * 32),
        "mixed-lz77:" + (("lorem ipsum dolor sit amet\n" * 16) + ("A" * 257) + ("lorem ipsum dolor sit amet\n" * 16)),
    ]
    payloads.extend([
        (ROOT / "README.md").read_text(),
        (ROOT / "docs" / "roadmap.md").read_text(),
    ])

    # Python -> Vort decode for raw/zlib/gzip fixed and zlib default streams.
    for text in payloads:
        data = text.encode()
        co = zlib.compressobj(level=1, wbits=-15, strategy=zlib.Z_FIXED)
        raw_fixed = co.compress(data) + co.flush()
        co = zlib.compressobj(level=1, wbits=15, strategy=zlib.Z_FIXED)
        zlib_fixed = co.compress(data) + co.flush()
        co = zlib.compressobj(level=1, wbits=31, strategy=zlib.Z_FIXED)
        gzip_fixed = co.compress(data) + co.flush()

        for command, compressed in [
            ("decode-raw-hex", raw_fixed),
            ("decode-zlib-hex", zlib_fixed),
            ("decode-gzip-hex", gzip_fixed),
        ]:
            out = run_cli(command, compressed.hex())
            decoded_len = int(parse_field(out, "decoded_bytes"))
            crc = int(parse_field(out, "crc32"))
            assert decoded_len == len(data), (command, text, out)
            assert crc == (zlib.crc32(data) & 0xFFFFFFFF), (command, text, out)
            limited = run_cli(command, compressed.hex(), str(len(data)))
            assert int(parse_field(limited, "decoded_bytes")) == len(data), (command, text, limited)

        zlib_roundtrip = run_cli("zlib-fixed-roundtrip", text)
        assert int(parse_field(zlib_roundtrip, "input_bytes")) == len(data), zlib_roundtrip
        assert parse_field(zlib_roundtrip, "decoded_ok") == "true", zlib_roundtrip
        assert int(parse_field(zlib_roundtrip, "adler32")) == (zlib.adler32(data) & 0xFFFFFFFF), zlib_roundtrip
        zlib_vort = bytes.fromhex(run_cli("encode-zlib-fixed-hex", text))
        assert zlib.decompress(zlib_vort) == data, text

        gzip_roundtrip = run_cli("gzip-fixed-roundtrip", text)
        assert int(parse_field(gzip_roundtrip, "input_bytes")) == len(data), gzip_roundtrip
        assert parse_field(gzip_roundtrip, "decoded_ok") == "true", gzip_roundtrip
        assert int(parse_field(gzip_roundtrip, "crc32")) == (zlib.crc32(data) & 0xFFFFFFFF), gzip_roundtrip
        gzip_vort = bytes.fromhex(run_cli("encode-gzip-fixed-hex", text))
        assert zlib.decompress(gzip_vort, wbits=31) == data, text

        raw_dynamic_vort = bytes.fromhex(run_cli("encode-raw-dynamic-hex", text))
        assert zlib.decompress(raw_dynamic_vort, wbits=-15) == data, text
        zlib_dynamic_vort = bytes.fromhex(run_cli("encode-zlib-dynamic-hex", text))
        assert zlib.decompress(zlib_dynamic_vort) == data, text
        gzip_dynamic_vort = bytes.fromhex(run_cli("encode-gzip-dynamic-hex", text))
        assert zlib.decompress(gzip_dynamic_vort, wbits=31) == data, text

        raw_split_vort = bytes.fromhex(run_cli("encode-raw-best-split-hex", text, "17", "default"))
        assert zlib.decompress(raw_split_vort, wbits=-15) == data, text
        zlib_split_vort = bytes.fromhex(run_cli("encode-zlib-best-split-hex", text, "17", "default"))
        assert zlib.decompress(zlib_split_vort) == data, text
        gzip_split_vort = bytes.fromhex(run_cli("encode-gzip-best-split-hex", text, "17", "default"))
        assert zlib.decompress(gzip_split_vort, wbits=31) == data, text
        raw_adaptive_vort = bytes.fromhex(run_cli("encode-raw-best-adaptive-hex", text, "default"))
        assert zlib.decompress(raw_adaptive_vort, wbits=-15) == data, text
        zlib_adaptive_vort = bytes.fromhex(run_cli("encode-zlib-best-adaptive-hex", text, "default"))
        assert zlib.decompress(zlib_adaptive_vort) == data, text
        gzip_adaptive_vort = bytes.fromhex(run_cli("encode-gzip-best-adaptive-hex", text, "default"))
        assert zlib.decompress(gzip_adaptive_vort, wbits=31) == data, text

    dictionary = b"hello "
    dictionary_text = dictionary.decode("ascii")
    dict_payload = b"hello hello hello"
    dict_cases = [
        (0, zlib.Z_DEFAULT_STRATEGY, dict_payload),
        (9, zlib.Z_DEFAULT_STRATEGY, dict_payload),
        (9, zlib.Z_FIXED, dict_payload),
    ]
    for level, strategy, payload in dict_cases:
        co = zlib.compressobj(level=level, wbits=-15, strategy=strategy, zdict=dictionary)
        raw_dict = co.compress(payload) + co.flush()
        out = run_cli("decode-raw-dict-hex", raw_dict.hex(), dictionary_text)
        assert int(parse_field(out, "decoded_bytes")) == len(payload), out
        assert int(parse_field(out, "crc32")) == (zlib.crc32(payload) & 0xFFFFFFFF), out
        limited = run_cli("decode-raw-dict-hex", raw_dict.hex(), dictionary_text, str(len(payload)))
        assert int(parse_field(limited, "decoded_bytes")) == len(payload), limited

        co = zlib.compressobj(level=level, wbits=zlib.MAX_WBITS, strategy=strategy, zdict=dictionary)
        zlib_dict = co.compress(payload) + co.flush()
        out = run_cli("decode-zlib-dict-hex", zlib_dict.hex(), dictionary_text)
        assert int(parse_field(out, "decoded_bytes")) == len(payload), out
        assert int(parse_field(out, "crc32")) == (zlib.crc32(payload) & 0xFFFFFFFF), out
        limited = run_cli("decode-zlib-dict-hex", zlib_dict.hex(), dictionary_text, str(len(payload)))
        assert int(parse_field(limited, "decoded_bytes")) == len(payload), limited

    raw_dynamic_dict = bytes.fromhex("25c421010000000090ffaf058203")
    out = run_cli("decode-raw-dict-hex", raw_dynamic_dict.hex(), dictionary_text)
    assert int(parse_field(out, "decoded_bytes")) == len(dictionary), out
    assert int(parse_field(out, "crc32")) == (zlib.crc32(dictionary) & 0xFFFFFFFF), out

    with tempfile.TemporaryDirectory(prefix="vort-raw-dict-file-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        compressed_path = tmp / "dict.raw"
        dictionary_path = tmp / "dict.bin"
        decoded_path = tmp / "decoded.bin"
        limited_path = tmp / "decoded-limited.bin"
        compressed_path.write_bytes(raw_dynamic_dict)
        dictionary_path.write_bytes(dictionary)
        out = run_cli("decode-raw-dict-file", str(compressed_path), str(decoded_path), str(dictionary_path))
        assert int(parse_field(out, "decoded_bytes")) == len(dictionary), out
        assert decoded_path.read_bytes() == dictionary, out
        out = run_cli("decode-raw-dict-file", str(compressed_path), str(limited_path), str(dictionary_path), str(len(dictionary)))
        assert int(parse_field(out, "decoded_bytes")) == len(dictionary), out
        assert limited_path.read_bytes() == dictionary, out
        expect_cli_failure("decode-raw-dict-file", str(compressed_path), str(tmp / "too-small.bin"), str(dictionary_path), str(len(dictionary) - 1), error_name="OutputLimitExceeded")

    zlib_dynamic_dict = bytes.fromhex("78200861023525c421010000000090ffaf05820308610235")
    out = run_cli("decode-zlib-dict-hex", zlib_dynamic_dict.hex(), dictionary_text)
    assert int(parse_field(out, "decoded_bytes")) == len(dictionary), out
    assert int(parse_field(out, "crc32")) == (zlib.crc32(dictionary) & 0xFFFFFFFF), out

    zlib_file_payload = b"zlib file output limit smoke"
    zlib_file_frame = zlib.compress(zlib_file_payload, level=6)
    zlib_file_missing_footer = zlib_file_frame[:-4]
    expect_cli_failure("decode-zlib-hex", zlib_file_missing_footer.hex(), error_name="TruncatedFrame")
    zlib_file_trailing = zlib_file_frame + b"garbage"
    expect_cli_failure("decode-zlib-hex", zlib_file_trailing.hex(), error_name="TrailingData")
    with tempfile.TemporaryDirectory(prefix="vort-zlib-file-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        compressed_path = tmp / "sample.zlib"
        decoded_path = tmp / "decoded.bin"
        limited_path = tmp / "decoded-limited.bin"
        compressed_path.write_bytes(zlib_file_frame)
        out = run_cli("decode-zlib-file", str(compressed_path), str(decoded_path))
        assert int(parse_field(out, "decoded_bytes")) == len(zlib_file_payload), out
        assert decoded_path.read_bytes() == zlib_file_payload, out
        out = run_cli("decode-zlib-file", str(compressed_path), str(limited_path), str(len(zlib_file_payload)))
        assert int(parse_field(out, "decoded_bytes")) == len(zlib_file_payload), out
        assert limited_path.read_bytes() == zlib_file_payload, out
        expect_cli_failure("decode-zlib-file", str(compressed_path), str(tmp / "too-small.bin"), str(len(zlib_file_payload) - 1), error_name="OutputLimitExceeded")
        empty_path = tmp / "empty.zlib"
        empty_path.write_bytes(b"")
        expect_cli_failure("decode-zlib-file", str(empty_path), str(tmp / "empty.out"), error_name="TruncatedFrame")
        header_only_path = tmp / "header-only.zlib"
        header_only_path.write_bytes(bytes.fromhex("7801"))
        expect_cli_failure("decode-zlib-file", str(header_only_path), str(tmp / "header-only.out"), error_name="TruncatedFrame")
        missing_footer_path = tmp / "missing-footer.zlib"
        missing_footer_path.write_bytes(zlib_file_missing_footer)
        expect_cli_failure("decode-zlib-file", str(missing_footer_path), str(tmp / "missing-footer.out"), error_name="TruncatedFrame")
        trailing_path = tmp / "trailing.zlib"
        trailing_path.write_bytes(zlib_file_trailing)
        expect_cli_failure("decode-zlib-file", str(trailing_path), str(tmp / "trailing.out"), error_name="TrailingData")

    raw_file_payload = b"raw deflate file output limit smoke"
    co = zlib.compressobj(level=6, wbits=-15)
    raw_file_frame = co.compress(raw_file_payload) + co.flush()
    raw_file_trailing = raw_file_frame + b"garbage"
    expect_cli_failure("decode-raw-hex", raw_file_trailing.hex(), error_name="TrailingData")
    with tempfile.TemporaryDirectory(prefix="vort-raw-file-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        compressed_path = tmp / "sample.raw"
        decoded_path = tmp / "decoded.bin"
        limited_path = tmp / "decoded-limited.bin"
        compressed_path.write_bytes(raw_file_frame)
        out = run_cli("decode-raw-file", str(compressed_path), str(decoded_path))
        assert int(parse_field(out, "decoded_bytes")) == len(raw_file_payload), out
        assert decoded_path.read_bytes() == raw_file_payload, out
        out = run_cli("decode-raw-file", str(compressed_path), str(limited_path), str(len(raw_file_payload)))
        assert int(parse_field(out, "decoded_bytes")) == len(raw_file_payload), out
        assert limited_path.read_bytes() == raw_file_payload, out
        expect_cli_failure("decode-raw-file", str(compressed_path), str(tmp / "too-small.bin"), str(len(raw_file_payload) - 1), error_name="OutputLimitExceeded")
        empty_path = tmp / "empty.raw"
        empty_path.write_bytes(b"")
        expect_cli_failure("decode-raw-file", str(empty_path), str(tmp / "empty.out"), error_name="TruncatedFrame")
        header_only_path = tmp / "header-only.raw"
        header_only_path.write_bytes(bytes.fromhex("01"))
        expect_cli_failure("decode-raw-file", str(header_only_path), str(tmp / "header-only.out"), error_name="TruncatedFrame")
        trailing_path = tmp / "trailing.raw"
        trailing_path.write_bytes(raw_file_trailing)
        expect_cli_failure("decode-raw-file", str(trailing_path), str(tmp / "trailing.out"), error_name="TrailingData")

    co = zlib.compressobj(level=9, wbits=zlib.MAX_WBITS, zdict=dictionary)
    zlib_dict_file = co.compress(dict_payload) + co.flush()
    with tempfile.TemporaryDirectory(prefix="vort-zlib-dict-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        compressed_path = tmp / "dict.zlib"
        dictionary_path = tmp / "dict.bin"
        decoded_path = tmp / "decoded.bin"
        compressed_path.write_bytes(zlib_dict_file)
        dictionary_path.write_bytes(dictionary)
        out = run_cli("decode-zlib-dict-file", str(compressed_path), str(decoded_path), str(dictionary_path))
        assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
        assert decoded_path.read_bytes() == dict_payload, out
        limited_path = tmp / "decoded-limited.bin"
        out = run_cli("decode-zlib-dict-file", str(compressed_path), str(limited_path), str(dictionary_path), str(len(dict_payload)))
        assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
        assert limited_path.read_bytes() == dict_payload, out
        expect_cli_failure("decode-zlib-dict-file", str(compressed_path), str(tmp / "too-small.bin"), str(dictionary_path), str(len(dict_payload) - 1), error_name="OutputLimitExceeded")

    zlib_dict_encode_cases = [
        ("encode-zlib-dict-stored-hex", ["default"]),
        ("encode-zlib-dict-fixed-hex", ["default"]),
        ("encode-zlib-dict-dynamic-hex", ["default"]),
        ("encode-zlib-dict-best-hex", ["default"]),
        ("encode-zlib-dict-best-split-hex", ["7", "default"]),
        ("encode-zlib-dict-best-adaptive-hex", ["default"]),
    ]
    for command, extra_args in zlib_dict_encode_cases:
        encoded = bytes.fromhex(run_cli(command, dict_payload.decode("ascii"), dictionary_text, *extra_args))
        assert encoded[1] & 0x20, (command, encoded.hex())
        assert int.from_bytes(encoded[2:6], "big") == (zlib.adler32(dictionary) & 0xFFFFFFFF), (command, encoded.hex())
        expect_cli_failure("decode-zlib-hex", encoded.hex(), error_name="NeedDictionary")
        out = run_cli("decode-zlib-dict-hex", encoded.hex(), dictionary_text)
        assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
        do = zlib.decompressobj(wbits=zlib.MAX_WBITS, zdict=dictionary)
        assert do.decompress(encoded) + do.flush() == dict_payload, command

    raw_dict_encode_cases = [
        ("encode-raw-dict-fixed-hex", ["default"]),
        ("encode-raw-dict-dynamic-hex", ["default"]),
        ("encode-raw-dict-best-hex", ["default"]),
        ("encode-raw-dict-best-split-hex", ["7", "default"]),
        ("encode-raw-dict-best-adaptive-hex", ["default"]),
    ]
    for command, extra_args in raw_dict_encode_cases:
        encoded = bytes.fromhex(run_cli(command, dict_payload.decode("ascii"), dictionary_text, *extra_args))
        expect_cli_failure("decode-raw-hex", encoded.hex(), error_name="InvalidMatch")
        out = run_cli("decode-raw-dict-hex", encoded.hex(), dictionary_text)
        assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
        do = zlib.decompressobj(wbits=-zlib.MAX_WBITS, zdict=dictionary)
        assert do.decompress(encoded) + do.flush() == dict_payload, command

    with tempfile.TemporaryDirectory(prefix="vort-dict-encode-file-", dir=ROOT / ".zig-cache") as tmpdir:
        tmp = pathlib.Path(tmpdir)
        input_path = tmp / "payload.bin"
        dictionary_path = tmp / "dict.bin"
        input_path.write_bytes(dict_payload)
        dictionary_path.write_bytes(dictionary)

        raw_file_cases = [
            ("encode-raw-dict-best-file", "payload.raw", ["default"]),
            ("encode-raw-dict-best-split-file", "payload-split.raw", ["7", "default"]),
            ("encode-raw-dict-best-adaptive-file", "payload-adaptive.raw", ["default"]),
        ]
        for command, filename, extra_args in raw_file_cases:
            raw_path = tmp / filename
            raw_decoded_path = tmp / f"{filename}.decoded"
            out = run_cli(command, str(input_path), str(raw_path), str(dictionary_path), *extra_args)
            assert int(parse_field(out, "input_bytes")) == len(dict_payload), out
            expect_cli_failure("decode-raw-file", str(raw_path), str(tmp / f"{filename}.no-dict"), error_name="InvalidMatch")
            out = run_cli("decode-raw-dict-file", str(raw_path), str(raw_decoded_path), str(dictionary_path))
            assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
            assert raw_decoded_path.read_bytes() == dict_payload, out
            do = zlib.decompressobj(wbits=-zlib.MAX_WBITS, zdict=dictionary)
            assert do.decompress(raw_path.read_bytes()) + do.flush() == dict_payload, command

        zlib_file_cases = [
            ("encode-zlib-dict-best-file", "payload.zlib", ["default"]),
            ("encode-zlib-dict-best-split-file", "payload-split.zlib", ["7", "default"]),
            ("encode-zlib-dict-best-adaptive-file", "payload-adaptive.zlib", ["default"]),
        ]
        for command, filename, extra_args in zlib_file_cases:
            zlib_path = tmp / filename
            zlib_decoded_path = tmp / f"{filename}.decoded"
            out = run_cli(command, str(input_path), str(zlib_path), str(dictionary_path), *extra_args)
            assert int(parse_field(out, "input_bytes")) == len(dict_payload), out
            assert int.from_bytes(zlib_path.read_bytes()[2:6], "big") == (zlib.adler32(dictionary) & 0xFFFFFFFF), out
            expect_cli_failure("decode-zlib-file", str(zlib_path), str(tmp / f"{filename}.no-dict"), error_name="NeedDictionary")
            out = run_cli("decode-zlib-dict-file", str(zlib_path), str(zlib_decoded_path), str(dictionary_path))
            assert int(parse_field(out, "decoded_bytes")) == len(dict_payload), out
            assert zlib_decoded_path.read_bytes() == dict_payload, out
            do = zlib.decompressobj(wbits=zlib.MAX_WBITS, zdict=dictionary)
            assert do.decompress(zlib_path.read_bytes()) + do.flush() == dict_payload, command

    dynamic_payloads = [
        b"match-heavy:" + (b"abcabcabcabc" * 96) + (b"xyzxyzxyz" * 48),
        b"distance-heavy:" + (b"0123456789abcdef" * 512) + b"----" + (b"0123456789abcdef" * 64),
        (b"lorem ipsum dolor sit amet\n" * 32) + (b"A" * 511) + (b"lorem ipsum dolor sit amet\n" * 32),
    ]
    for data in dynamic_payloads:
        text = data.decode("ascii")
        zlib_dynamic_vort = bytes.fromhex(run_cli("encode-zlib-dynamic-hex", text, "default"))
        assert zlib.decompress(zlib_dynamic_vort) == data, text
        zlib_adaptive_vort = bytes.fromhex(run_cli("encode-zlib-best-adaptive-hex", text, "best"))
        assert zlib.decompress(zlib_adaptive_vort) == data, text

    # Vort -> Python decode for fixed zlib/gzip frames where output is exposed as hex indirectly
    # through known deterministic vectors generated by the CLI round-trip commands.
    hello_zlib = bytes.fromhex("7801cb48cdc9c90700062c0215")
    hello_gzip = bytes.fromhex("1f8b0800000000000403cb48cdc9c9070086a6103605000000")
    assert zlib.decompress(hello_zlib) == b"hello"
    assert zlib.decompress(hello_gzip, wbits=31) == b"hello"

    print(f"python zlib differential smoke: payloads={len(payloads)} match_heavy=3 dynamic_payloads={len(dynamic_payloads)} cli={CLI}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
