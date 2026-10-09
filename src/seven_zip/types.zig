pub const Kind = enum {
    file,
    directory,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    kind: Kind = .file,
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
};
