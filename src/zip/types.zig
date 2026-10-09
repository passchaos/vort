pub const CompressionMethod = enum(u16) {
    stored = 0,
    deflate = 8,
    bzip2 = 12,
    lzma = 14,
    zstandard = 93,
    xz = 95,
    _,
};
