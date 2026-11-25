#!/usr/bin/env python3
"""Black-box checks for Zstd seekable range dictionary catalogs on native and WASI."""

import argparse
from pathlib import Path
import struct
import tempfile

from encode_stdio_cli_gate import MAGIC, SENTINEL, describe, failure, require, run, success
from seekable_cli_gate import FOOTER_MAGIC, TABLE_MAGIC, assert_destination
from seekable_range_cli_gate import COMMAND


# Frozen upstream Zstd 1.6.0 fixtures (commit 01b7154f1172432f8abe9b3bb9909e14a1176b7d)
# from src/tests/zstd_source_decode/seekable_dictionary.zig. The reproducer is
# tools/zstd/source_seekable_dictionary_fixture.c; no upstream tool is needed here.
PLAIN_A = b"alpha/warehouse/temperature=301.25K;pressure=1000hPa;" * 3
DICT_A = bytes.fromhex(
    "37a430ec78563412251030bcd101f01769c35fa40d7f9136fc59f6db6fbffdf6db3f48b3"
    "f796524a2931eddd4c0df30400000034c5cd06000004808a02800fc0cccec11400302800"
    "0000002071000000800100000000000000f0060000000000d412eb232439218488888888"
    "888888882449920e010000000400000008000000653d313030306850613b3a6275636b65"
    "743d303b73657269616c3d30313739363b0a69643d3039322f30343b616c7068612f653d"
    "313030306850613b3a6275636b65743d333b73657269616c3d30313332313b0a69643d30"
    "36372f30313b616c7068612f653d313030306850613b3a6275636b65743d343b73657269"
    "616c3d30"
)
FRAME_A = bytes.fromhex(
    "28b52ffd27785634129f9d0100340277617265686f7573652f74656d7065726174757265"
    "3d3330312e32354b3b707265737304f00763525e7fed88ab6039fe034e7d2bc3"
)
PLAIN_B = b"bravo/drive/events=write,append,commit;sector=65536;" * 3
DICT_B = bytes.fromhex(
    "37a430ec89674523251030bcd101f01769c35fa40d7f9136fc59f6db6fbffdf6db3f48b3"
    "e596526e2931eddd4c0d1305000000b4451d00000004a08a02400f00cb10d60000001400"
    "0000208100000080010000000000000000de000000000000d432eb232039218488888888"
    "888888882449920e010000000400000008000000746f723d36353533363b3a6275636b65"
    "743d323b73657269616c3d30313536383b0a69643d3038302f30333b627261766f2f746f"
    "723d36353533363b3a6275636b65743d333b73657269616c3d30313332313b0a69643d30"
    "36372f30313b627261766f2f746f723d36353533363b3a6275636b65743d313b73657269"
    "616c3d30"
)
FRAME_B = bytes.fromhex(
    "28b52ffd27896745239c950100440264726976652f6576656e74733d77726974652c6170"
    "70656e642c636f6d6d69743b73656303f0e56202c004b06008fe0327cebb27"
)

DICT_METADATA_SIZE = 128  # Includes the standard entropy tables and initial repeat offsets.
DEFAULT_MAX_DICTIONARY_BYTES = 32 << 20
MAX_DICTIONARY_FILES = 64
PLAIN_IDLESS = b"\x00\xffno dictionary\r\n"
CROSS_OFFSET = len(PLAIN_A) - 7
CROSS_BYTES = PLAIN_A[-7:] + PLAIN_B[:19]


def make_archive(path):
    # Plain raw block with a single-segment frame header, no ID, and no checksum.
    raw_block = ((len(PLAIN_IDLESS) << 3) | 1).to_bytes(3, "little")
    idless = MAGIC + bytes((0x20, len(PLAIN_IDLESS))) + raw_block + PLAIN_IDLESS
    members = ((FRAME_A, PLAIN_A), (FRAME_B, PLAIN_B), (idless, PLAIN_IDLESS))
    entries = b"".join(struct.pack("<II", len(frame), len(plain)) for frame, plain in members)
    footer = struct.pack("<IBI", len(members), 0, FOOTER_MAGIC)
    table = struct.pack("<II", TABLE_MAGIC, len(entries) + len(footer)) + entries + footer
    path.write_bytes(b"".join(frame for frame, _ in members) + table)


def write_dictionary(cwd, name, data):
    (cwd / name).write_bytes(data)
    return f"--dictionary={name}"


def check_routing(decode, cwd, a, b):
    def crossing(dst, *options):
        return decode(dst, CROSS_OFFSET, len(CROSS_BYTES), *options)

    # The frames are A then B, so positional selection would fail.
    success("cross-frame range resolves reversed dictionary options",
            crossing("-", b, a), stdout=CROSS_BYTES)
    failure("missing dictionary on first selected frame", crossing("-", b), "NeedDictionary")
    failure("missing dictionary on later selected frame writes no stdout",
            crossing("-", a), "NeedDictionary")
    success("dictionary for an unselected later frame is not required",
            decode("-", CROSS_OFFSET, 7, a), stdout=PLAIN_A[-7:])
    success("dictionary for an unselected earlier frame is not required",
            decode("-", len(PLAIN_A), 19, b), stdout=PLAIN_B[:19])
    success("ID-less frame is unaffected by a supplied catalog",
            decode("-", len(PLAIN_A) + len(PLAIN_B), len(PLAIN_IDLESS), b, a), stdout=PLAIN_IDLESS)

    out = cwd / "output.raw"
    out.write_bytes(SENTINEL)
    inode = out.stat().st_ino
    label = "missing later dictionary preserves the named destination"
    failure(label, crossing(out.name, a), "NeedDictionary")
    assert_destination(label, out, inode, SENTINEL, replaced=False)

    # Modify only B's dictionary history. Its ID, entropy, and repeat offsets
    # still pass preflight; B's frame checksum must detect the bad decoded bytes.
    wrong_history = bytes(byte ^ 0x80 for byte in DICT_B[DICT_METADATA_SIZE:])
    wrong_b = write_dictionary(cwd, "wrong-b.dict", DICT_B[:DICT_METADATA_SIZE] + wrong_history)
    label = "late same-ID dictionary failure publishes only the verified A intersection"
    result = crossing("-", wrong_b, a)
    failure(label, result, "ChecksumMismatch", PLAIN_A[-7:])
    require(result.stdout == PLAIN_A[-7:], f"{label}: missing verified output; {describe(result)}")
    label = "late same-ID dictionary failure preserves the named destination"
    failure(label, crossing(out.name, wrong_b, a), "ChecksumMismatch")
    assert_destination(label, out, inode, SENTINEL, replaced=False)
    new = cwd / "unpublished.raw"
    failure("late same-ID dictionary failure does not create a destination",
            crossing(new.name, wrong_b, a), "ChecksumMismatch")
    require(not new.exists(), "late same-ID dictionary failure published a new destination")

    label = "valid catalog atomically replaces a named destination"
    success(label, crossing(out.name, b, a))
    assert_destination(label, out, inode, CROSS_BYTES, replaced=True)


def check_catalog(decode, cwd, a, b):
    def crossing(*options):
        return decode("-", CROSS_OFFSET, len(CROSS_BYTES), *options)

    total = len(DICT_A) + len(DICT_B)
    exact = f"--max-dictionary-bytes={total}"
    success("exact aggregate dictionary byte limit", crossing(b, exact, a), stdout=CROSS_BYTES)
    failure("aggregate dictionary limit one byte too low",
            crossing(b, a, f"--max-dictionary-bytes={total - 1}"), "OutputLimitExceeded")
    failure("dictionary byte limit is a singleton option",
            crossing(b, a, exact, exact), "DuplicateZstdOption")

    # Each file is under 32 MiB, but together they exceed the default by one.
    # Extend the dictionary history with a hole before the original suffix.
    padded = cwd / "padded-a.dict"
    with padded.open("wb") as out:
        out.write(DICT_A[:DICT_METADATA_SIZE])
        out.seek(DEFAULT_MAX_DICTIONARY_BYTES + 1 - total + DICT_METADATA_SIZE)
        out.write(DICT_A[DICT_METADATA_SIZE:])
    failure("default aggregate dictionary byte limit", crossing(b, f"--dictionary={padded.name}"),
            "OutputLimitExceeded")

    # The duplicate has a different path and contents, but has A's wire ID.
    duplicate = write_dictionary(cwd, "duplicate-a.dict", DICT_B[:4] + DICT_A[4:8] + DICT_B[8:])
    failure("duplicate embedded dictionary ID", crossing(b, a, duplicate), "DuplicateDictionaryId")
    raw = write_dictionary(cwd, "raw.dict", b"raw content is not a standard dictionary")
    truncated = write_dictionary(cwd, "truncated.dict", DICT_A[:7])
    failure("raw-content dictionary", crossing(b, a, raw), "InvalidMagic")
    failure("truncated standard dictionary", crossing(b, a, truncated), "TruncatedFrame")

    extras = [
        write_dictionary(cwd, f"extra-{i}.dict", DICT_A[:4] + struct.pack("<I", i) + DICT_A[8:])
        for i in range(1, MAX_DICTIONARY_FILES)
    ]
    success("exactly 64 dictionary files", crossing(b, a, *extras[:-1]), stdout=CROSS_BYTES)
    failure("65 dictionary files exceed the fixed catalog limit",
            crossing(b, a, *extras), "OutputLimitExceeded")


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
    with tempfile.TemporaryDirectory(prefix="vort-zstd-seekable-dictionary-cli-") as directory:
        cwd = Path(directory)
        archive = cwd / "input.zst"
        make_archive(archive)
        a = write_dictionary(cwd, "a.dict", DICT_A)
        b = write_dictionary(cwd, "b.dict", DICT_B)

        def decode(dst, offset, length, *options):
            return run([*prefix, COMMAND, archive.name, dst, str(offset), str(length), *options], cwd)

        check_routing(decode, cwd, a, b)
        check_catalog(decode, cwd, a, b)
    print(f"zstd_seekable_dictionary_cli mode={mode} status=ok")


if __name__ == "__main__":
    main()
