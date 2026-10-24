import base64
import struct
from pathlib import Path


def crc32c(data):
    value = 0xFFFFFFFF
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = (value >> 1) ^ (0x82F63B78 if value & 1 else 0)
    return value


def prepare(original, codec, size, kind, prefix_len=17):
    data = bytearray(original)
    meta = struct.unpack_from("<I", data, 1064)[0] * 4096
    location = meta + 96 * 32
    inode_size = 64 if struct.unpack_from("<H", data, location)[0] & 1 else 32
    xcount = struct.unpack_from("<H", data, location + 2)[0]
    xsize = 12 + (xcount - 1) * 4 if xcount else 0
    header = (location + inode_size + xsize + 7) & ~7
    prefix = 4096 if size in (4, 8) else 17
    leading = 4096 if size in (4, 8) else 5
    length = {"partial": prefix_len, "whole": 9, "mixed": prefix + 9, "holes": leading + prefix + 7}[kind]
    struct.pack_into("<Q" if inode_size == 64 else "<I", data, location + 8, length)
    data[header:header + 160] = bytes(160)
    if not size:
        data[header + 6] = codec
        struct.pack_into("<HI", data, header + 16, 0x8001, 0)
        struct.pack_into("<I", data, header + 20, 1)
    else:
        count = {"partial": 1, "whole": 1, "mixed": 2, "holes": 3}[kind]
        advise = 1 | ({4: 0, 8: 1, 16: 2, 32: 3}[size] << 1)
        if kind in ("whole", "mixed"):
            advise |= 0x20
        struct.pack_into("<IHH", data, header, count, advise, 0)
        start = (header + 8 + size - 1) & ~(size - 1)
        if size == 4:
            struct.pack_into("<Q", data, start, 4096)
            start += 8

        def record(index, plen, physical, logical):
            offset = start + index * size
            struct.pack_into("<I", data, offset, plen)
            if size >= 8:
                struct.pack_into("<I", data, offset + 4, physical & 0xFFFFFFFF)
            if size >= 16:
                struct.pack_into("<II", data, offset + 8, physical >> 32, logical & 0xFFFFFFFF)
            if size == 32:
                struct.pack_into("<I", data, offset + 16, logical >> 32)

        word = 4096 | ((codec + 1) << 28) | (1 << 27)
        if kind == "partial":
            record(0, word, 4096, 0)
        elif kind == "whole":
            record(0, 8, 0, 0)
        elif kind == "mixed":
            record(0, word, 4096, 0)
            record(1, 8, 0, prefix)
        else:
            record(0, 0, 0xFFFFFFFFFFFFFFFF, 0)
            record(1, word, 4096, leading)
            record(2, 0, 0xFFFFFFFFFFFFFFFF, leading + prefix)
    struct.pack_into("<I", data, 1028, 0)
    struct.pack_into("<I", data, 1028, crc32c(data[1024:4096]))
    return data


def verify_partial_extents(cli, fsck, temp, run):
    if fsck is None:
        return 0, 0
    cases = 0
    failures = 0
    for codec, name in enumerate(("lz4", "lzma", "deflate", "zstd")):
        original = base64.b64decode(Path(f"src/erofs/testdata/partial-extent-{name}.erofs.b64").read_text())
        reference = temp / f"partial-reference-{name}.erofs"
        reference.write_bytes(prepare(original, codec, 0, "partial", 4096))
        extracted = temp / f"partial-reference-{name}"
        run(fsck, f"--extract={extracted}", "--no-preserve", reference)
        full = (extracted / "file").read_bytes()
        if len(full) != 4096:
            raise AssertionError(f"unexpected reference prefix length for {name}")
        for size in (0, 4, 8, 16, 32):
            for kind in ("partial", "whole", "mixed", "holes"):
                if not size and kind != "partial":
                    continue
                lengths = (17, 1, 33, 258, 4096) if size == 16 and kind == "partial" else (17,)
                for requested in lengths:
                    label = f"partial-{name}-{size}-{kind}-{requested}"
                    image = temp / f"{label}.erofs"
                    image.write_bytes(prepare(original, codec, size, kind, requested))
                    prefix = 4096 if size in (4, 8) else 17
                    leading = 4096 if size in (4, 8) else 5
                    expected = {
                        "partial": full[:requested],
                        "whole": full[8:17],
                        "mixed": full[:prefix] + full[8:17],
                        "holes": bytes(leading) + full[:prefix] + bytes(7),
                    }[kind]
                    decoded = temp / label
                    run(fsck, f"--extract={decoded}", "--no-preserve", "--xattrs", image)
                    output = temp / f"{label}.out"
                    run(cli, "extract-erofs-file", image, "file", output, len(expected), "--output-chunk-size=17", "--working-memory-limit=1048576")
                    if output.read_bytes() != expected or (decoded / "file").read_bytes() != expected:
                        raise AssertionError(f"partial/fragment extent mismatch for {label}")
                    attrs = run(cli, "list-erofs-xattrs", image, "file").stdout
                    if b"xattr\tuser.vort.repeat\t66696c652d76616c7565\n" not in attrs:
                        raise AssertionError(f"xattrs changed for {label}")
                    cases += 1
        gap = prepare(original, codec, 0, "partial", 4096)
        location = struct.unpack_from("<I", gap, 1064)[0] * 4096 + 96 * 32
        inode_size = 64 if struct.unpack_from("<H", gap, location)[0] & 1 else 32
        xcount = struct.unpack_from("<H", gap, location + 2)[0]
        header = (location + inode_size + (12 + (xcount - 1) * 4 if xcount else 0) + 7) & ~7
        struct.pack_into("<Q" if inode_size == 64 else "<I", gap, location + 8, 4097)
        struct.pack_into("<HHI", gap, header + 24, 0, 0, 1024)
        gap.extend(bytes(1025 * 4096 - len(gap)))
        gap[1024 * 4096] = ord("B")
        struct.pack_into("<I", gap, 1060, 1025)
        struct.pack_into("<I", gap, 1028, 0)
        struct.pack_into("<I", gap, 1028, crc32c(gap[1024:4096]))
        image = temp / f"partial-noncontiguous-{name}.erofs"
        image.write_bytes(gap)
        extracted = temp / f"partial-noncontiguous-{name}"
        run(fsck, f"--extract={extracted}", "--no-preserve", image)
        output = temp / f"partial-noncontiguous-{name}.out"
        run(cli, "extract-erofs-file", image, "file", output, 4097, "--output-chunk-size=17", "--working-memory-limit=131072")
        if output.read_bytes() != full + b"B" or (extracted / "file").read_bytes() != full + b"B":
            raise AssertionError(f"noncontiguous partial reference mismatch for {name}")
        cases += 1
        malformed = prepare(original, codec, 16, "whole")
        location = struct.unpack_from("<I", malformed, 1064)[0] * 4096 + 96 * 32
        inode_size = 64 if struct.unpack_from("<H", malformed, location)[0] & 1 else 32
        xcount = struct.unpack_from("<H", malformed, location + 2)[0]
        header = (location + inode_size + (12 + (xcount - 1) * 4 if xcount else 0) + 7) & ~7
        record = (header + 8 + 15) & ~15
        malformed[record:record + 8] = b"\xff" * 8
        struct.pack_into("<I", malformed, 1028, 0)
        struct.pack_into("<I", malformed, 1028, crc32c(malformed[1024:4096]))
        image = temp / f"partial-bad-offset-{name}.erofs"
        image.write_bytes(malformed)
        output = temp / f"partial-bad-offset-{name}.out"
        output.write_bytes(b"preserve existing output")
        before = set(temp.iterdir())
        result = run(cli, "extract-erofs-file", image, "file", output, 9, "--output-chunk-size=17", check=False)
        if result.returncode == 0 or b"IntegerOverflow" not in result.stderr:
            raise AssertionError(f"missing fragment offset overflow for {name}: {result.stderr!r}")
        if output.read_bytes() != b"preserve existing output" or set(temp.iterdir()) != before:
            raise AssertionError(f"failed fragment extraction changed output or leaked a temporary file for {name}")
        failures += 1
    return cases, failures
