import struct
from dual_algorithm_diff import build
from partial_diff import crc32c


def refresh(data):
    struct.pack_into("<I", data, 1028, 0)
    struct.pack_into("<I", data, 1028, crc32c(data[1024:4096]))


def verify_configurations(cli, fsck, temp, run):
    if fsck is None:
        return 0, 0
    valid = 0
    malformed = 0
    # Valid smaller histories and reserved single-block LZ4 defaults still
    # decode reference data from independent system codec implementations.
    for codec in range(4):
        data, expected = build(codec, codec, "full")
        if codec == 0:
            struct.pack_into("<H", data, 1156, 0)
        elif codec == 1:
            struct.pack_into("<I", data, 1154, 4096)
        elif codec == 2:
            data[1154] = 8
        else:
            data[1155] = 2
        refresh(data)
        image = temp / f"configuration-valid-{codec}.erofs"
        image.write_bytes(data)
        restored = temp / f"configuration-valid-{codec}-fsck"
        run(fsck, f"--extract={restored}", "--no-preserve", image)
        output = temp / f"configuration-valid-{codec}.out"
        run(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17")
        if output.read_bytes() != expected or (restored / "file").read_bytes() != expected:
            raise AssertionError(f"configured history output mismatch for codec {codec}")
        valid += 1

    original, expected = build(2, 0, "full")
    # Shift the metadata block and physical data by one block, leaving enough
    # primary address space for a configuration extension spanning block zero.
    extended = bytearray(len(original) + 4096)
    extended[0:4096] = original[0:4096]
    extended[4096:] = original
    struct.pack_into("<I", extended, 1064, 1)
    struct.pack_into("<I", extended, 1060, len(extended) // 4096)
    struct.pack_into("<H", extended, 1152, 2943)
    extended[1168:4097] = b"\x7d" * (4097 - 1168)
    extended[4100:4108] = original[1168:1176]
    indices = 4096 + 96 * 32 + 32 + 16
    struct.pack_into("<I", extended, indices + 4, 2)
    struct.pack_into("<I", extended, indices + 12, 3)
    refresh(extended)
    image = temp / "configuration-extension.erofs"
    image.write_bytes(extended)
    restored = temp / "configuration-extension-fsck"
    run(fsck, f"--extract={restored}", "--no-preserve", image)
    output = temp / "configuration-extension.out"
    run(cli, "extract-erofs-file", image, "file", output, len(expected))
    if output.read_bytes() != expected or (restored / "file").read_bytes() != expected:
        raise AssertionError("cross-block configuration extension changed file bytes")
    valid += 1

    cases = []
    for length in (0, 1, 13, 65535):
        data = bytearray(original)
        struct.pack_into("<H", data, 1152, length)
        cases.append((f"lz4-length-{length}", data, "TruncatedFrame" if length == 65535 else "InvalidErofs"))
    data = bytearray(original)
    struct.pack_into("<H", data, 1108, 0x8005)
    cases.append(("unknown-algorithm", data, "UnsupportedErofsCompression"))
    data = bytearray(original)
    data[1152:1160] = original[1168:1176]
    struct.pack_into("<H", data, 1108, 4)
    cases.append(("undeclared-secondary", data, "InvalidErofs"))
    for label, data, error in cases:
        refresh(data)
        image = temp / f"configuration-bad-{label}.erofs"
        image.write_bytes(data)
        oracle = run(fsck, image, check=False)
        if oracle.returncode == 0:
            raise AssertionError(f"fsck accepted malformed configuration {label}")
        output = temp / f"configuration-bad-{label}.out"
        output.write_bytes(b"preserve previous output")
        before = set(temp.iterdir())
        result = run(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17", check=False)
        if result.returncode == 0 or error.encode() not in result.stderr:
            raise AssertionError(f"missing {error} for configuration {label}: {result.stderr!r}")
        if output.read_bytes() != b"preserve previous output" or before != set(temp.iterdir()):
            raise AssertionError(f"malformed configuration changed output or leaked temporary data: {label}")
        malformed += 1
    return valid, malformed
