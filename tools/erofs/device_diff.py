import base64
import struct
from pathlib import Path
from partial_diff import prepare, crc32c


def inode(data, nid):
    location = struct.unpack_from("<I", data, 1064)[0] * 4096 + nid * 32
    encoded = struct.unpack_from("<H", data, location)[0]
    size = 64 if encoded & 1 else 32
    xcount = struct.unpack_from("<H", data, location + 2)[0]
    xsize = 12 + (xcount - 1) * 4 if xcount else 0
    length = struct.unpack_from("<Q" if size == 64 else "<I", data, location + 8)[0]
    return location, (encoded >> 1) & 7, length, (location + size + xsize + 7) & ~7


def offload(original, nid, within=0):
    data = bytearray(original) + bytearray(4096)
    suffix = original[4096:]
    blob = bytearray((len(suffix) + within + 4095) & ~4095)
    blob[within:within + len(suffix)] = suffix
    location, layout, length, header = inode(data, nid)
    if layout in (1, 3) and data[header + 7] & 0x80:
        nid = struct.unpack_from("<Q", data, 1120)[0]
        location, layout, length, header = inode(data, nid)
    def byte_address(old):
        return 64 * 4096 + old - 4096 + within
    if layout in (0, 2):
        old = struct.unpack_from("<I", data, location + 16)[0]
        struct.pack_into("<I", data, location + 16, old + 63)
    else:
        advise = struct.unpack_from("<H", data, header + 4)[0]
        if layout == 1 and advise & 1:
            size = 4 << ((advise >> 1) & 3)
            count = (length + 4095) // 4096 if size <= 8 else struct.unpack_from("<I", data, header)[0]
            start = (header + 8 + size - 1) & ~(size - 1)
            if size == 4:
                struct.pack_into("<Q", data, start, byte_address(struct.unpack_from("<Q", data, start)[0]))
            else:
                for index in range(count):
                    if advise & 0x20 and index + 1 == count:
                        continue
                    offset = start + index * size
                    if not struct.unpack_from("<I", data, offset)[0] & 0x1FFFFF:
                        continue
                    old = struct.unpack_from("<I", data, offset + 4)[0]
                    if size >= 16:
                        old |= struct.unpack_from("<I", data, offset + 8)[0] << 32
                    value = byte_address(old)
                    struct.pack_into("<I", data, offset + 4, value & 0xFFFFFFFF)
                    if size >= 16:
                        struct.pack_into("<I", data, offset + 8, value >> 32)
        elif layout == 1:
            for index in range((length + 4095) // 4096):
                offset = header + 16 + index * 8
                if struct.unpack_from("<H", data, offset)[0] & 3 != 2:
                    old = struct.unpack_from("<I", data, offset + 4)[0]
                    struct.pack_into("<I", data, offset + 4, old + 63)
        else:
            base = header + 8
            count = (length + 4095) // 4096
            initial = ((32 - base % 32) // 4) & 7
            two = (count - initial) // 16 * 16 if advise & 1 and initial < count else 0
            offsets = set()
            for index in range(count):
                if index < initial:
                    position, pack = base + index * 4, 8
                elif index < initial + two:
                    position, pack = base + initial * 4 + (index - initial) * 2, 32
                else:
                    position, pack = base + initial * 4 + two * 2 + (index - initial - two) * 4, 8
                offsets.add((position & ~(pack - 1)) + pack - 4)
            for offset in offsets:
                struct.pack_into("<I", data, offset, struct.unpack_from("<I", data, offset)[0] + 63)
    table = len(original)
    struct.pack_into("<II", data, table + 64, len(blob) // 4096, 64)
    struct.pack_into("<I", data, 1104, struct.unpack_from("<I", data, 1104)[0] | 8)
    struct.pack_into("<HH", data, 1110, 1, table // 128)
    struct.pack_into("<I", data, 1060, len(data) // 4096)
    struct.pack_into("<I", data, 1028, 0)
    struct.pack_into("<I", data, 1028, crc32c(data[1024:4096]))
    return data, blob


def root_entry(data, name):
    root = struct.unpack_from("<H", data, 1038)[0]
    location, layout, length, _ = inode(data, root)
    size = 64 if struct.unpack_from("<H", data, location)[0] & 1 else 32
    xcount = struct.unpack_from("<H", data, location + 2)[0]
    xsize = 12 + (xcount - 1) * 4 if xcount else 0
    start = location + size + xsize if layout == 2 else struct.unpack_from("<I", data, location + 16)[0] * 4096
    count = struct.unpack_from("<H", data, start + 8)[0] // 12
    for index in range(count):
        begin = struct.unpack_from("<H", data, start + index * 12 + 8)[0]
        end = struct.unpack_from("<H", data, start + (index + 1) * 12 + 8)[0] if index + 1 < count else length
        if data[start + begin:start + end] == name.encode():
            return struct.unpack_from("<Q", data, start + index * 12)[0]
    raise AssertionError(f"reference root is missing {name}")


def verify_device_readers(cli, writer, fsck, temp, run):
    if fsck is None:
        return 0
    cases = 0

    def check(original, nid, label, path, within=0):
        nonlocal cases
        data, blob = offload(original, nid, within)
        image = temp / f"device-reader-{label}.erofs"
        device = temp / f"device-reader-{label}.blob"
        image.write_bytes(data)
        device.write_bytes(blob)
        restored = temp / f"device-reader-{label}-fsck"
        run(fsck, f"--device={device}", f"--extract={restored}", "--no-preserve", image)
        expected = (restored / path).read_bytes()
        output = temp / f"device-reader-{label}.out"
        run(cli, "extract-erofs-file", image, path, output, len(expected), "--output-chunk-size=17", "--working-memory-limit=2097152", device)
        if output.read_bytes() != expected:
            raise AssertionError(f"external device extraction mismatch for {label}")
        run(cli, "list-erofs-file", image, "--working-memory-limit=2097152", device)
        run(cli, "list-erofs-xattrs", image, path, "--working-memory-limit=2097152", device)
        cases += 1

    for codec, name in enumerate(("lz4", "lzma", "deflate", "zstd")):
        original = base64.b64decode(Path(f"src/erofs/testdata/partial-extent-{name}.erofs.b64").read_text())
        for size in (4, 8, 16, 32):
            for within in (0, 3, 4093):
                check(prepare(original, codec, size, "partial"), 96, f"{name}-{size}-{within}", "file", within)
        check(prepare(original, codec, 0, "partial"), 96, f"{name}-legacy", "file")
        fragmented = prepare(original, codec, 16, "whole")
        packed = struct.unpack_from("<Q", fragmented, 1120)[0]
        check(fragmented, packed, f"{name}-packed-compact", "file")

    for name in ("stored", "lz4", "lzma", "deflate", "zstd"):
        for variant in ("", "-metabox", "-dirs"):
            if name == "stored" and variant == "-dirs":
                continue
            reference = temp / f"device-reference-{name}{variant}.erofs"
            run(writer, reference, name + variant)
            original = reference.read_bytes()
            if variant == "-metabox":
                nid = struct.unpack_from("<Q", original, 1152)[0]
            elif variant == "-dirs":
                nid = struct.unpack_from("<H", original, 1038)[0]
            else:
                nid = root_entry(original, "large.bin")
            check(original, nid, f"writer-{name}{variant}", "large.bin")
    return cases
