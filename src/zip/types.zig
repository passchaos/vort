pub const CompressionMethod = enum(u16) {
    stored = 0,
    deflate = 8,
    bzip2 = 12,
    _,
};
