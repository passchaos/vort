pub const CompressionMethod = enum(u16) {
    stored = 0,
    shrink = 1,
    reduce_1 = 2,
    reduce_2 = 3,
    reduce_3 = 4,
    reduce_4 = 5,
    implode = 6,
    deflate = 8,
    deflate64 = 9,
    dcl_implode = 10,
    bzip2 = 12,
    lzma = 14,
    /// Deprecated PKWARE assignment retained for archives created before
    /// APPNOTE 6.3.8 reassigned Zstandard from method 20 to method 93.
    zstandard_legacy = 20,
    zstandard = 93,
    xz = 95,
    ppmd = 98,
    _,
};
