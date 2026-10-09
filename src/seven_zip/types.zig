pub const Kind = enum {
    file,
    directory,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    kind: Kind = .file,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    creation_time: ?u64 = null,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    access_time: ?u64 = null,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    modification_time: ?u64 = null,
    /// Raw 7z WinAttributes value, including encoded POSIX mode bits when present.
    attributes: ?u32 = null,
};

pub const Method = enum {
    copy,
    deflate,
    bzip2,
    lzma,
    lzma2,
    delta,
    x86,
    powerpc,
    ia64,
    arm,
    arm_thumb,
    sparc,
    bcj2,
};

pub const Entry = struct {
    name: []u8,
    size: u64,
    kind: Kind,
    method: ?Method,
    crc32: ?u32,
    folder_index: ?usize,
    offset_in_folder: u64,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    creation_time: ?u64 = null,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    access_time: ?u64 = null,
    /// Windows FILETIME ticks: 100 ns intervals since 1601-01-01 UTC.
    modification_time: ?u64 = null,
    /// Raw 7z WinAttributes value, including encoded POSIX mode bits when present.
    attributes: ?u32 = null,
};
