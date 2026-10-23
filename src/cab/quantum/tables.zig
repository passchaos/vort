pub const min_window_bits: u5 = 10;
pub const max_window_bits: u5 = 21;
pub const frame_size: usize = 32 * 1024;

pub const position_base = [_]usize{
    0,      1,      2,      3,      4,      6,       8,
    12,     16,     24,     32,     48,     64,      96,
    128,    192,    256,    384,    512,    768,     1024,
    1536,   2048,   3072,   4096,   6144,   8192,    12288,
    16384,  24576,  32768,  49152,  65536,  98304,   131072,
    196608, 262144, 393216, 524288, 786432, 1048576, 1572864,
};

pub const position_extra = [_]u5{
    0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,
    6,  6,  7,  7,  8,  8,  9,  9,  10, 10, 11, 11, 12, 12,
    13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19,
};

pub const length_base = [_]usize{
    0,  1,  2,  3,   4,   5,   6,   8,   10,
    12, 14, 18, 22,  26,  30,  38,  46,  54,
    62, 78, 94, 110, 126, 158, 190, 222, 254,
};

pub const length_extra = [_]u5{
    0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
};

pub fn positionSlot(offset: u32, entries: usize) !u8 {
    if (offset == 0 or entries == 0 or entries > position_base.len) return error.InvalidBlockPlan;
    const value = offset - 1;
    for (position_base[0..entries], position_extra[0..entries], 0..) |base, extra, slot| {
        if (value >= base and value - base < @as(usize, 1) << extra) return @intCast(slot);
    }
    return error.InvalidBlockPlan;
}

pub fn lengthSlot(length: u16) !u8 {
    if (length < 5 or length > 259) return error.InvalidBlockPlan;
    const value = length - 5;
    for (length_base, length_extra, 0..) |base, extra, slot| {
        if (value >= base and value - base < @as(usize, 1) << extra) return @intCast(slot);
    }
    return error.InvalidBlockPlan;
}
