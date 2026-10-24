# Shared writer mode catalog for full and compact wire-format differentials.
grouped_modes = tuple(
    f"{codec}-clusters{suffix}"
    for codec in ("lz4", "lzma", "deflate", "zstd")
    for suffix in ("", "-fragments", "-ztailpacking", "-48bit", "-metabox", "-dirs", "-extended", "-dirs-extended-metabox")
)
bounded_modes = tuple(
    f"{codec}-bounded{suffix}"
    for codec in ("lz4", "lzma", "deflate", "zstd")
    for suffix in ("", "-fragments", "-ztailpacking", "-48bit", "-metabox", "-dirs", "-extended", "-dirs-extended-metabox", "8", "12")
)
combined_metabox_modes = ("chunk-local-metabox", "chunk-external-metabox") + tuple(
    f"{codec}{group}{tail}-metabox"
    for codec in ("lz4", "lzma", "deflate", "zstd")
    for group in ("", "-clusters", "-bounded")
    for tail in ("-fragments", "-ztailpacking")
)
writer_modes = (
    "stored",
    "lz4",
    "deflate",
    "zstd",
    "lz4-fragments",
    "deflate-fragments",
    "zstd-fragments",
    "lz4-ztailpacking",
    "deflate-ztailpacking",
    "zstd-ztailpacking",
    "chunk-local",
    "chunk-external",
    "stored-48bit",
    "lz4-48bit",
    "deflate-48bit",
    "zstd-48bit",
    "chunk-local-48bit",
    "chunk-external-48bit",
    "stored-metabox",
    "lz4-metabox",
    "deflate-metabox",
    "zstd-metabox",
    "lz4-dirs",
    "deflate-dirs",
    "zstd-dirs",
    "stored-extended",
    "lz4-extended",
    "deflate-extended",
    "zstd-extended",
    "lzma",
    "lzma-fragments",
    "lzma-ztailpacking",
    "lzma-48bit",
    "lzma-metabox",
    "lzma-dirs",
    "lzma-extended",
) + grouped_modes + bounded_modes + combined_metabox_modes


def payloads():
    writer_large = b"EROFS writer probe multi-block payload 0123456789\n" * 4096
    state = 0x1234_5678
    writer_random = bytearray()
    for _ in range(8193):
        state ^= (state << 13) & 0xFFFF_FFFF
        state ^= state >> 17
        state ^= (state << 5) & 0xFFFF_FFFF
        state &= 0xFFFF_FFFF
        writer_random.append(state & 0xFF)
    expected_writer = {
        "etc/config": b"writer probe configuration\n",
        "large.bin": writer_large,
        "random.bin": bytes(writer_random),
        "mixed.bin": bytes(writer_random[:8192]) * 2,
        "small": b"inline payload",
        "link": b"etc/config",
    }
    return expected_writer


xattrs = {
    "/": {
        b"user.vort.root": b"root-xattr",
        b"user.vort.shared": b"shared-xattr",
    },
    "etc/config": {
        b"user.vort.config": b"config-xattr",
        b"user.vort.shared": b"shared-xattr",
    },
    "small": {
        b"user.vort.small": b"small-xattr",
        b"user.vort.shared": b"shared-xattr",
    },
    "empty": {
        b"user.vort.directory": b"directory-xattr",
        b"user.vort.shared": b"shared-xattr",
    },
}
