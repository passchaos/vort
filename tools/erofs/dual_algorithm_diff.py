import base64
import struct
from pathlib import Path
from partial_diff import crc32c
from device_diff import offload


CODECS = ("lz4", "lzma", "deflate", "zstd")
FIRST = (b"primary algorithm history and literals\n" * 128)[:4096]
SECOND = (b"secondary algorithm history and literals\n" * 128)[:4096]


def build(primary, secondary, layout):
    inline = layout in ("inline-full", "inline-compact")
    compact = layout in ("compact", "inline-compact")
    partial = layout == "partial"
    data = bytearray(8192 if inline or partial else 12288)
    struct.pack_into("<III", data, 1024, 0xE0F5E1E2, 0, 3)
    data[1036] = 12
    struct.pack_into("<H", data, 1038, 64)
    struct.pack_into("<Q", data, 1040, 2)
    struct.pack_into("<I", data, 1060, len(data) // 4096)
    struct.pack_into("<I", data, 1104, 3 | (0x10 if inline else 0))
    mask = (1 << primary) | (1 << secondary)
    struct.pack_into("<H", data, 1108, mask)
    configuration = 1152
    settings = (struct.pack("<HHH10s", 14, 0xFFFF, 1, bytes(10)),
                bytes((14, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                bytes((6, 0, 15, 0, 0, 0, 0, 0)),
                bytes((6, 0, 0, 5, 0, 0, 0, 0)))
    for codec in range(4):
        if mask & (1 << codec):
            record = settings[codec]
            data[configuration:configuration + len(record)] = record
            configuration += len(record)
    root = 64 * 32
    struct.pack_into("<HHHHI", data, root, 4, 0, 0x41ED, 2, 43)
    struct.pack_into("<I", data, root + 16, 0xFFFFFFFF)
    directory = root + 32
    struct.pack_into("<QHBB", data, directory, 64, 36, 2, 0)
    struct.pack_into("<QHBB", data, directory + 12, 64, 37, 2, 0)
    struct.pack_into("<QHBB", data, directory + 24, 96, 39, 1, 0)
    data[directory + 36:directory + 43] = b"...file"
    node = 96 * 32
    length = 17 if partial else 4219 if inline else 8192
    struct.pack_into("<HHHHI", data, node, 6 if compact else 2, 0, 0x81A4, 1, length)
    struct.pack_into("<I", data, node + 16, 1 if inline or partial else 2)
    header = node + 32
    data[header + 6] = primary | (secondary << 4)
    indices = header + (8 if compact else 16)
    if compact:
        struct.pack_into("<HHI", data, indices, 1 << 12, 3 << 12, 0)
    else:
        struct.pack_into("<HHI", data, indices, 0x8003 if partial else 1, 0, 1)
        if not partial:
            struct.pack_into("<HHI", data, indices + 8, 3, 0, 0 if inline else 2)

    def encoded(codec, name):
        return base64.b64decode(Path(f"src/erofs/testdata/dual-{CODECS[codec]}-{name}.bin.b64").read_text())

    first = encoded(secondary, "second") if partial else encoded(primary, "first")
    data[8192 - len(first):8192] = first
    if not partial:
        last = encoded(secondary, "inline" if inline else "second")
        if inline:
            struct.pack_into("<HH", data, header + 2, len(last), 8)
            offset = indices + (8 if compact else 16)
            data[offset:offset + len(last)] = last
        else:
            data[12288 - len(last):12288] = last
    struct.pack_into("<I", data, 1028, crc32c(data[1024:4096]))
    expected = SECOND[:17] if partial else FIRST + SECOND[:123] if inline else FIRST + SECOND
    return data, expected


def verify_dual_algorithms(cli, fsck, temp, run):
    if fsck is None:
        return 0
    count = 0
    for primary in range(4):
        for secondary in range(4):
            for layout in ("full", "compact", "inline-full", "inline-compact", "partial"):
                label = f"dual-{CODECS[primary]}-{CODECS[secondary]}-{layout}"
                data, expected = build(primary, secondary, layout)
                image = temp / f"{label}.erofs"
                image.write_bytes(data)
                restored = temp / f"{label}-fsck"
                run(fsck, f"--extract={restored}", "--no-preserve", image)
                output = temp / f"{label}.out"
                run(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17", "--working-memory-limit=131072")
                if (restored / "file").read_bytes() != expected or output.read_bytes() != expected:
                    raise AssertionError(f"dual-algorithm output mismatch for {label}")
                count += 1
    for primary in range(4):
        data, expected = build(primary, 0, "full")
        image_bytes, blob = offload(data, 96)
        label = f"dual-external-{CODECS[primary]}-lz4"
        image = temp / f"{label}.erofs"
        device = temp / f"{label}.blob"
        image.write_bytes(image_bytes)
        device.write_bytes(blob)
        restored = temp / f"{label}-fsck"
        run(fsck, f"--device={device}", f"--extract={restored}", "--no-preserve", image)
        output = temp / f"{label}.out"
        run(cli, "extract-erofs-file", image, "file", output, len(expected), device, "--output-chunk-size=17")
        if (restored / "file").read_bytes() != expected or output.read_bytes() != expected:
            raise AssertionError(f"dual external-device output mismatch for {label}")
        count += 1
    return count
