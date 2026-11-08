const std = @import("std");

/// Magicless frames have the same descriptor and body as ordinary Zstd frames,
/// with the four-byte frame magic omitted. The mode is always caller-selected.
pub const FrameFormat = enum { standard, magicless };
pub const Error = error{ TruncatedFrame, InvalidMagic };
pub const Prefix = union(enum) { data, skippable: u32 };

pub const data_magic: u32 = 0xfd2f_b528;
pub const skippable_magic_min: u32 = 0x184d_2a50;
pub const skippable_magic_max: u32 = 0x184d_2a5f;

pub fn classifyMagic(value: u32) Error!Prefix {
    if (value == data_magic) return .data;
    if (value >= skippable_magic_min and value <= skippable_magic_max)
        return .{ .skippable = value };
    return error.InvalidMagic;
}

pub fn magicLen(format: FrameFormat) usize {
    return if (format == .standard) 4 else 0;
}

pub fn minimumPrefixLen(format: FrameFormat) usize {
    return if (format == .standard) 4 else 1;
}

pub fn consumePrefix(input: []const u8, offset: *usize, format: FrameFormat) Error!Prefix {
    if (offset.* > input.len or input.len - offset.* < minimumPrefixLen(format))
        return error.TruncatedFrame;
    if (format == .magicless) return .data;
    const value = std.mem.readInt(u32, input[offset.*..][0..4], .little);
    offset.* += 4;
    return classifyMagic(value);
}

pub fn hasDataPrefix(input: []const u8, format: FrameFormat) bool {
    if (input.len < minimumPrefixLen(format)) return false;
    return format == .magicless or std.mem.readInt(u32, input[0..4], .little) == data_magic;
}

pub fn skippableMagic(input: []const u8, format: FrameFormat) ?u32 {
    if (format != .standard or input.len < 4) return null;
    const value = std.mem.readInt(u32, input[0..4], .little);
    return if (value >= skippable_magic_min and value <= skippable_magic_max) value else null;
}
