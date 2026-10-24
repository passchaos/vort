//! AOSP-compatible AArch32 ARM and Thumb-2 branch reference codecs.

const std = @import("std");

pub const ReferenceType = enum(u3) {
    relocation = 0,
    absolute = 1,
    a24 = 2,
    t8 = 3,
    t11 = 4,
    t20 = 5,
    t24 = 6,

    pub fn pool(self: ReferenceType) u8 {
        return switch (self) {
            .relocation => 0,
            .absolute => 1,
            .a24, .t8, .t11, .t20, .t24 => 2,
        };
    }
};

pub const Decoded = struct {
    displacement: i32,
    alignment: u3,
};

pub fn decodeA24(code: u32) ?Decoded {
    const bits: u4 = @truncate(code >> 24);
    if (bits != 0xa and bits != 0xb) return null;
    var displacement = signExtend(24, code & 0x00ff_ffff) * 4;
    const condition: u4 = @truncate(code >> 28);
    if (condition == 0xf) {
        displacement += @as(i32, @intCast((code >> 24) & 1)) * 2;
        return .{ .displacement = displacement, .alignment = 2 };
    }
    return .{ .displacement = displacement, .alignment = 4 };
}

pub fn encodeA24(displacement: i64, code: *u32) bool {
    const bits: u4 = @truncate(code.* >> 24);
    if ((bits != 0xa and bits != 0xb) or !signedFits(26, displacement))
        return false;
    const condition: u4 = @truncate(code.* >> 28);
    var value = code.*;
    if (condition == 0xf) {
        if (@mod(displacement, 2) != 0) return false;
        value = (value & 0xfeff_ffff) |
            (@as(u32, @intCast((dispBits(displacement) >> 1) & 1)) << 24);
    } else if (@mod(displacement, 4) != 0) return false;
    value = (value & 0xff00_0000) | ((dispBits(displacement) >> 2) & 0x00ff_ffff);
    code.* = value;
    return true;
}

pub fn decodeT8(code: u16) ?Decoded {
    if (code & 0xf000 != 0xd000 or code & 0x0f00 == 0x0f00) return null;
    return .{ .displacement = signExtend(8, code & 0xff) * 2, .alignment = 2 };
}

fn encodeT8(displacement: i64, code: *u16) bool {
    if (code.* & 0xf000 != 0xd000 or code.* & 0x0f00 == 0x0f00 or
        @mod(displacement, 2) != 0 or !signedFits(9, displacement))
    {
        return false;
    }
    code.* = (code.* & 0xff00) | @as(u16, @truncate(dispBits(displacement) >> 1));
    return true;
}

pub fn decodeT11(code: u16) ?Decoded {
    if (code & 0xf800 != 0xe000) return null;
    return .{ .displacement = signExtend(11, code & 0x07ff) * 2, .alignment = 2 };
}

fn encodeT11(displacement: i64, code: *u16) bool {
    if (code.* & 0xf800 != 0xe000 or @mod(displacement, 2) != 0 or
        !signedFits(12, displacement))
    {
        return false;
    }
    code.* = (code.* & 0xf800) |
        @as(u16, @truncate((dispBits(displacement) >> 1) & 0x07ff));
    return true;
}

pub fn decodeT20(code: u32) ?Decoded {
    if (code & 0xf800_d000 != 0xf000_8000 or code & 0x03c0_0000 == 0x03c0_0000)
        return null;
    const imm11 = code & 0x7ff;
    const j2 = (code >> 11) & 1;
    const j1 = (code >> 13) & 1;
    const imm6 = (code >> 16) & 0x3f;
    const sign = (code >> 26) & 1;
    const value = (sign << 20) | (j2 << 19) | (j1 << 18) |
        (imm6 << 12) | (imm11 << 1);
    return .{ .displacement = signExtend(21, value), .alignment = 2 };
}

fn encodeT20(displacement: i64, code: *u32) bool {
    if (code.* & 0xf800_d000 != 0xf000_8000 or
        code.* & 0x03c0_0000 == 0x03c0_0000 or
        @mod(displacement, 2) != 0 or !signedFits(21, displacement))
    {
        return false;
    }
    const bits = dispBits(displacement);
    code.* = (code.* & 0xfbc0_d000) |
        (((bits >> 20) & 1) << 26) |
        (((bits >> 12) & 0x3f) << 16) |
        (((bits >> 18) & 1) << 13) |
        (((bits >> 19) & 1) << 11) |
        ((bits >> 1) & 0x7ff);
    return true;
}

pub fn decodeT24(code: u32) ?Decoded {
    const opcode = code & 0xf800_d000;
    if (opcode != 0xf000_9000 and opcode != 0xf000_d000 and opcode != 0xf000_c000)
        return null;
    const imm11 = code & 0x7ff;
    const j2 = (code >> 11) & 1;
    const j1 = (code >> 13) & 1;
    const imm10 = (code >> 16) & 0x3ff;
    const sign = (code >> 26) & 1;
    const value = (sign << 24) | ((j1 ^ sign ^ 1) << 23) |
        ((j2 ^ sign ^ 1) << 22) | (imm10 << 12) | (imm11 << 1);
    if (opcode == 0xf000_c000) {
        if (code & 1 != 0) return null;
        return .{ .displacement = signExtend(25, value), .alignment = 4 };
    }
    return .{ .displacement = signExtend(25, value), .alignment = 2 };
}

fn encodeT24(displacement: i64, code: *u32) bool {
    const opcode = code.* & 0xf800_d000;
    if (opcode != 0xf000_9000 and opcode != 0xf000_d000 and opcode != 0xf000_c000)
        return false;
    if (@mod(displacement, 2) != 0 or !signedFits(25, displacement))
        return false;
    const bits = dispBits(displacement);
    if (opcode == 0xf000_c000 and (bits >> 1) & 1 != 0) return false;
    const sign = (bits >> 24) & 1;
    const immediate1 = (bits >> 23) & 1;
    const immediate2 = (bits >> 22) & 1;
    code.* = (code.* & 0xf800_d000) |
        (sign << 26) |
        (((bits >> 12) & 0x3ff) << 16) |
        ((immediate1 ^ sign ^ 1) << 13) |
        ((immediate2 ^ sign ^ 1) << 11) |
        ((bits >> 1) & 0x7ff);
    return true;
}

pub fn readBranch(
    image: []const u8,
    reference_type: ReferenceType,
    location: u32,
    instruction_rva: u32,
) ?u32 {
    const offset: usize = location;
    const decoded = switch (reference_type) {
        .a24 => decodeA24(readU32(image, offset)),
        .t8 => decodeT8(readU16(image, offset)),
        .t11 => decodeT11(readU16(image, offset)),
        .t20 => decodeT20(fetchThumb32(image, offset)),
        .t24 => decodeT24(fetchThumb32(image, offset)),
        else => null,
    } orelse return null;
    const instruction_alignment: u3 = if (reference_type == .a24) 4 else 2;
    if (instruction_rva & (instruction_alignment - 1) != 0) return null;
    const pc: u32 = if (reference_type == .a24) 8 else 4;
    const target = instruction_rva +% pc +%
        @as(u32, @bitCast(decoded.displacement));
    return target & ~(@as(u32, decoded.alignment) - 1);
}

pub fn writeBranch(
    image: []u8,
    reference_type: ReferenceType,
    location: u32,
    instruction_rva: u32,
    target_rva: u32,
) error{InvalidReference}!void {
    const offset: usize = location;
    const width: usize = switch (reference_type) {
        .t8, .t11 => 2,
        else => 4,
    };
    if (!rangeFits(offset, width, image.len)) return error.InvalidReference;
    const instruction_alignment: u32 = if (reference_type == .a24) 4 else 2;
    if (instruction_rva & (instruction_alignment - 1) != 0)
        return error.InvalidReference;
    const decoded = switch (reference_type) {
        .a24 => decodeA24(readU32(image, offset)),
        .t8 => decodeT8(readU16(image, offset)),
        .t11 => decodeT11(readU16(image, offset)),
        .t20 => decodeT20(fetchThumb32(image, offset)),
        .t24 => decodeT24(fetchThumb32(image, offset)),
        else => null,
    } orelse return error.InvalidReference;
    if (target_rva & (@as(u32, decoded.alignment) - 1) != 0)
        return error.InvalidReference;
    const pc: i64 = if (reference_type == .a24) 8 else 4;
    var displacement = @as(i64, target_rva) - (@as(i64, instruction_rva) + pc);
    const alignment: i64 = decoded.alignment;
    displacement += (-displacement) & (alignment - 1);
    const encoded = switch (reference_type) {
        .a24 => blk: {
            var code = readU32(image, offset);
            if (!encodeA24(displacement, &code)) break :blk false;
            std.mem.writeInt(u32, image[offset..][0..4], code, .little);
            break :blk true;
        },
        .t8 => blk: {
            var code = readU16(image, offset);
            if (!encodeT8(displacement, &code)) break :blk false;
            std.mem.writeInt(u16, image[offset..][0..2], code, .little);
            break :blk true;
        },
        .t11 => blk: {
            var code = readU16(image, offset);
            if (!encodeT11(displacement, &code)) break :blk false;
            std.mem.writeInt(u16, image[offset..][0..2], code, .little);
            break :blk true;
        },
        .t20 => blk: {
            var code = fetchThumb32(image, offset);
            if (!encodeT20(displacement, &code)) break :blk false;
            storeThumb32(image, offset, code);
            break :blk true;
        },
        .t24 => blk: {
            var code = fetchThumb32(image, offset);
            if (!encodeT24(displacement, &code)) break :blk false;
            storeThumb32(image, offset, code);
            break :blk true;
        },
        else => false,
    };
    if (!encoded) return error.InvalidReference;
}

pub fn isThumbSection(
    image: []const u8,
    address: u32,
    offset: u32,
    size: u32,
) bool {
    if (address % 4 != 0 or size % 4 != 0) return true;
    var always: u64 = 0;
    var total: u64 = 0;
    var cursor: usize = offset;
    const end = cursor + size;
    while (cursor < end) : (cursor += 4) {
        if (image[cursor + 3] & 0xf0 == 0xe0) always += 1;
        total += 1;
    }
    return always * 5 < total * 2;
}

pub fn thumbInstructionSize(code: u16) usize {
    return if (code & 0xf000 == 0xf000 or code & 0xf800 == 0xe800) 4 else 2;
}

pub fn fetchThumb32(image: []const u8, offset: usize) u32 {
    return (@as(u32, readU16(image, offset)) << 16) | readU16(image, offset + 2);
}

fn storeThumb32(image: []u8, offset: usize, code: u32) void {
    std.mem.writeInt(u16, image[offset..][0..2], @truncate(code >> 16), .little);
    std.mem.writeInt(u16, image[offset + 2 ..][0..2], @truncate(code), .little);
}

fn signExtend(comptime bits: u6, value: anytype) i32 {
    const raw: u32 = @intCast(value);
    const shift: u5 = @intCast(32 - bits);
    return @as(i32, @bitCast(raw << shift)) >> shift;
}

fn signedFits(comptime bits: u6, value: i64) bool {
    const magnitude: i64 = @as(i64, 1) << @intCast(bits - 1);
    return value >= -magnitude and value < magnitude;
}

fn dispBits(value: i64) u32 {
    return @truncate(@as(u64, @bitCast(value)));
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

test "Zucchini AArch32 branch codecs match AOSP vectors" {
    var bytes = [_]u8{ 0x00, 0x01, 0x02, 0xea };
    try std.testing.expectEqual(
        @as(?u32, 0x0018_3458),
        readBranch(&bytes, .a24, 0, 0x0010_3050),
    );
    try writeBranch(&bytes, .a24, 0, 0x0010_3050, 0x0018_345c);
    try std.testing.expectEqual(@as(u32, 0xea02_0101), readU32(&bytes, 0));

    var thumb16 = [_]u8{ 0xf3, 0xe7 };
    try std.testing.expectEqual(
        @as(?u32, 0x0010_308c),
        readBranch(&thumb16, .t11, 0, 0x0010_30a2),
    );
    try writeBranch(&thumb16, .t11, 0, 0x0010_30a2, 0x0010_308e);
    try std.testing.expectEqual(@as(u16, 0xe7f4), readU16(&thumb16, 0));

    var thumb32 = [_]u8{ 0x00, 0xf0, 0x01, 0xfa };
    try std.testing.expectEqual(
        @as(?u32, 0x0010_34a8),
        readBranch(&thumb32, .t24, 0, 0x0010_30a2),
    );
    try writeBranch(&thumb32, .t24, 0, 0x0010_30a2, 0x0010_34aa);
    try std.testing.expectEqual(@as(u32, 0xf000_fa02), fetchThumb32(&thumb32, 0));

    var t8 = [_]u8{ 0x00, 0xd0 };
    try writeBranch(&t8, .t8, 0, 0x100, 0x108);
    try std.testing.expectEqual(@as(u16, 0xd002), readU16(&t8, 0));
    try std.testing.expectEqual(@as(?u32, 0x108), readBranch(&t8, .t8, 0, 0x100));

    var t20 = [_]u8{ 0x00, 0xf0, 0x00, 0x80 };
    try writeBranch(&t20, .t20, 0, 0x100, 0x108);
    try std.testing.expectEqual(@as(?u32, 0x108), readBranch(&t20, .t20, 0, 0x100));
}
