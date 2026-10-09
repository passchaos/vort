pub const CompressionMethod = enum(u16) {
    stored = 0,
    deflate = 8,
    deflate64 = 9,
    bzip2 = 12,
    lzma = 14,
    /// Deprecated PKWARE assignment retained for archives created before
    /// APPNOTE 6.3.8 reassigned Zstandard from method 20 to method 93.
    zstandard_legacy = 20,
    zstandard = 93,
    xz = 95,
    _,
};
