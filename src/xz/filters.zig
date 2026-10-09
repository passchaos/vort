const std = @import("std");

pub const Error = error{
    InvalidXzHeader,
    UnsupportedXzFeature,
};

pub const Kind = enum {
    delta,
    x86,
    powerpc,
    ia64,
    arm,
    arm_thumb,
    sparc,
    arm64,
    riscv,
};

pub const Filter = struct {
    kind: Kind,
    parameter: u32,

    pub fn delta(distance: u32) Error!Filter {
        if (distance == 0 or distance > 256) return error.InvalidXzHeader;
        return .{ .kind = .delta, .parameter = distance };
    }

    pub fn x86(start_offset: u32) Filter {
        return .{ .kind = .x86, .parameter = start_offset };
    }

    pub fn powerpc(start_offset: u32) Error!Filter {
        return aligned(.powerpc, start_offset, 4);
    }

    pub fn ia64(start_offset: u32) Error!Filter {
        return aligned(.ia64, start_offset, 16);
    }

    pub fn arm(start_offset: u32) Error!Filter {
        return aligned(.arm, start_offset, 4);
    }

    pub fn armThumb(start_offset: u32) Error!Filter {
        return aligned(.arm_thumb, start_offset, 2);
    }

    pub fn sparc(start_offset: u32) Error!Filter {
        return aligned(.sparc, start_offset, 4);
    }

    pub fn arm64(start_offset: u32) Error!Filter {
        return aligned(.arm64, start_offset, 4);
    }

    pub fn riscv(start_offset: u32) Error!Filter {
        return aligned(.riscv, start_offset, 2);
    }

    fn aligned(kind: Kind, start_offset: u32, alignment: u32) Error!Filter {
        if (start_offset & (alignment - 1) != 0) return error.InvalidXzHeader;
        return .{ .kind = kind, .parameter = start_offset };
    }
};

pub fn parse(filter_id: u64, properties: []const u8) Error!Filter {
    return switch (filter_id) {
        0x03 => blk: {
            if (properties.len != 1) return error.InvalidXzHeader;
            break :blk .{ .kind = .delta, .parameter = @as(u32, properties[0]) + 1 };
        },
        0x04 => parseBcj(.x86, properties, 1),
        0x05 => parseBcj(.powerpc, properties, 4),
        0x06 => parseBcj(.ia64, properties, 16),
        0x07 => parseBcj(.arm, properties, 4),
        0x08 => parseBcj(.arm_thumb, properties, 2),
        0x09 => parseBcj(.sparc, properties, 4),
        0x0a => parseBcj(.arm64, properties, 4),
        0x0b => parseBcj(.riscv, properties, 2),
        else => error.UnsupportedXzFeature,
    };
}

fn parseBcj(kind: Kind, properties: []const u8, alignment: u32) Error!Filter {
    if (properties.len != 0 and properties.len != 4) return error.InvalidXzHeader;
    const start_offset = if (properties.len == 0) 0 else std.mem.readInt(u32, properties[0..4], .little);
    if (start_offset & (alignment - 1) != 0) return error.InvalidXzHeader;
    return .{ .kind = kind, .parameter = start_offset };
}

pub fn validateChain(chain: []const Filter) Error!void {
    if (chain.len > 3) return error.UnsupportedXzFeature;
    for (chain) |filter| switch (filter.kind) {
        .delta => if (filter.parameter == 0 or filter.parameter > 256) return error.InvalidXzHeader,
        .x86 => {},
        .powerpc, .arm, .sparc, .arm64 => if (filter.parameter & 3 != 0) return error.InvalidXzHeader,
        .ia64 => if (filter.parameter & 15 != 0) return error.InvalidXzHeader,
        .arm_thumb, .riscv => if (filter.parameter & 1 != 0) return error.InvalidXzHeader,
    };
}

pub fn encodeChain(bytes: []u8, chain: []const Filter) void {
    for (chain) |filter| apply(bytes, filter, true);
}

pub fn decodeChain(bytes: []u8, chain: []const Filter) void {
    var index = chain.len;
    while (index != 0) {
        index -= 1;
        const filter = chain[index];
        apply(bytes, filter, false);
    }
}

pub fn id(filter: Filter) u64 {
    return switch (filter.kind) {
        .delta => 0x03,
        .x86 => 0x04,
        .powerpc => 0x05,
        .ia64 => 0x06,
        .arm => 0x07,
        .arm_thumb => 0x08,
        .sparc => 0x09,
        .arm64 => 0x0a,
        .riscv => 0x0b,
    };
}

pub fn propertiesSize(filter: Filter) usize {
    return switch (filter.kind) {
        .delta => 1,
        else => if (filter.parameter == 0) 0 else 4,
    };
}

pub fn writeProperties(filter: Filter, output: []u8) void {
    switch (filter.kind) {
        .delta => output[0] = @intCast(filter.parameter - 1),
        else => if (output.len != 0) std.mem.writeInt(u32, output[0..4], filter.parameter, .little),
    }
}

fn apply(bytes: []u8, filter: Filter, encode: bool) void {
    switch (filter.kind) {
        .delta => transformDelta(bytes, @intCast(filter.parameter), encode),
        .x86 => transformX86(bytes, filter.parameter, encode),
        .powerpc => transformPowerPc(bytes, filter.parameter, encode),
        .ia64 => transformIa64(bytes, filter.parameter, encode),
        .arm => transformArm(bytes, filter.parameter, encode),
        .arm_thumb => transformArmThumb(bytes, filter.parameter, encode),
        .sparc => transformSparc(bytes, filter.parameter, encode),
        .arm64 => transformArm64(bytes, filter.parameter, encode),
        .riscv => transformRiscV(bytes, filter.parameter, encode),
    }
}

fn transformDelta(bytes: []u8, distance: usize, encode: bool) void {
    if (!encode) {
        for (distance..bytes.len) |index| bytes[index] +%= bytes[index - distance];
        return;
    }
    var history: [256]u8 = @splat(0);
    var position: u8 = 0;
    for (bytes) |*byte| {
        const original = byte.*;
        byte.* -%= history[position +% @as(u8, @intCast(distance))];
        history[position] = original;
        position -%= 1;
    }
}

fn transformX86(bytes: []u8, start_offset: u32, encode: bool) void {
    const mask_to_bit_number = [_]u5{ 0, 1, 2, 2, 3 };
    var previous_mask: u32 = 0;
    var previous_position: u32 = 0xffff_fffb;
    if (bytes.len < 5) return;
    if (start_offset -% previous_position > 5) previous_position = start_offset -% 5;

    const limit = bytes.len - 5;
    var position: usize = 0;
    while (position <= limit) {
        var high_byte = bytes[position];
        if (high_byte != 0xe8 and high_byte != 0xe9) {
            position += 1;
            continue;
        }

        const absolute_position = start_offset +% @as(u32, @truncate(position));
        const offset = absolute_position -% previous_position;
        previous_position = absolute_position;
        if (offset > 5) {
            previous_mask = 0;
        } else {
            for (0..offset) |_| {
                previous_mask &= 0x77;
                previous_mask <<= 1;
            }
        }

        high_byte = bytes[position + 4];
        if (testX86MsByte(high_byte) and
            previous_mask >> 1 <= 4 and
            previous_mask >> 1 != 3)
        {
            var source = (@as(u32, high_byte) << 24) |
                (@as(u32, bytes[position + 3]) << 16) |
                (@as(u32, bytes[position + 2]) << 8) |
                bytes[position + 1];
            var destination: u32 = undefined;
            while (true) {
                destination = if (encode)
                    source +% (absolute_position +% 5)
                else
                    source -% (absolute_position +% 5);
                if (previous_mask == 0) break;
                const bit_number = mask_to_bit_number[previous_mask >> 1];
                high_byte = @truncate(destination >> @intCast(24 - bit_number * 8));
                if (!testX86MsByte(high_byte)) break;
                const mask: u32 = switch (bit_number) {
                    1 => 0x00ff_ffff,
                    2 => 0x0000_ffff,
                    3 => 0x0000_00ff,
                    else => unreachable,
                };
                source = destination ^ mask;
            }

            bytes[position + 4] = if (destination & 0x0100_0000 != 0) 0xff else 0;
            bytes[position + 3] = @truncate(destination >> 16);
            bytes[position + 2] = @truncate(destination >> 8);
            bytes[position + 1] = @truncate(destination);
            position += 5;
            previous_mask = 0;
        } else {
            position += 1;
            previous_mask |= 1;
            if (testX86MsByte(high_byte)) previous_mask |= 0x10;
        }
    }
}

fn transformPowerPc(bytes: []u8, start_offset: u32, encode: bool) void {
    const size = bytes.len & ~@as(usize, 3);
    var position: usize = 0;
    while (position < size) : (position += 4) {
        if (bytes[position] >> 2 != 0x12 or bytes[position + 3] & 3 != 1) continue;
        const source = (@as(u32, bytes[position]) & 3) << 24 |
            @as(u32, bytes[position + 1]) << 16 |
            @as(u32, bytes[position + 2]) << 8 |
            (@as(u32, bytes[position + 3]) & ~@as(u32, 3));
        const absolute_position = start_offset +% @as(u32, @truncate(position));
        const destination = if (encode) source +% absolute_position else source -% absolute_position;
        bytes[position] = 0x48 | (@as(u8, @truncate(destination >> 24)) & 3);
        bytes[position + 1] = @truncate(destination >> 16);
        bytes[position + 2] = @truncate(destination >> 8);
        bytes[position + 3] = (bytes[position + 3] & 3) | @as(u8, @truncate(destination));
    }
}

fn transformIa64(bytes: []u8, start_offset: u32, encode: bool) void {
    const branch_table = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        4, 4, 6, 6, 0, 0, 7, 7,
        4, 4, 0, 0, 4, 4, 0, 0,
    };
    const size = bytes.len & ~@as(usize, 15);
    var position: usize = 0;
    while (position < size) : (position += 16) {
        const mask = branch_table[bytes[position] & 0x1f];
        var bit_position: usize = 5;
        for (0..3) |slot| {
            defer bit_position += 41;
            if (mask >> @intCast(slot) & 1 == 0) continue;
            const byte_position = bit_position >> 3;
            const bit_remainder: u6 = @intCast(bit_position & 7);
            var instruction: u64 = 0;
            for (0..6) |index|
                instruction |= @as(u64, bytes[position + byte_position + index]) << @intCast(8 * index);
            var normalized = instruction >> bit_remainder;
            if (normalized >> 37 & 0x0f != 5 or normalized >> 9 & 7 != 0) continue;

            var source: u32 = @truncate(normalized >> 13 & 0x000f_ffff);
            source |= @as(u32, @truncate(normalized >> 36 & 1)) << 20;
            source <<= 4;
            const absolute_position = start_offset +% @as(u32, @truncate(position));
            var destination = if (encode) source +% absolute_position else source -% absolute_position;
            destination >>= 4;
            normalized &= ~(@as(u64, 0x008f_ffff) << 13);
            normalized |= @as(u64, destination & 0x000f_ffff) << 13;
            normalized |= @as(u64, destination & 0x0010_0000) << 16;
            instruction &= (@as(u64, 1) << bit_remainder) - 1;
            instruction |= normalized << bit_remainder;
            for (0..6) |index|
                bytes[position + byte_position + index] = @truncate(instruction >> @intCast(8 * index));
        }
    }
}

fn transformArm(bytes: []u8, start_offset: u32, encode: bool) void {
    const size = bytes.len & ~@as(usize, 3);
    var position: usize = 0;
    while (position < size) : (position += 4) {
        if (bytes[position + 3] != 0xeb) continue;
        var source = @as(u32, bytes[position + 2]) << 16 |
            @as(u32, bytes[position + 1]) << 8 |
            bytes[position];
        source <<= 2;
        const absolute_position = start_offset +% @as(u32, @truncate(position)) +% 8;
        var destination = if (encode) source +% absolute_position else source -% absolute_position;
        destination >>= 2;
        bytes[position + 2] = @truncate(destination >> 16);
        bytes[position + 1] = @truncate(destination >> 8);
        bytes[position] = @truncate(destination);
    }
}

fn transformArmThumb(bytes: []u8, start_offset: u32, encode: bool) void {
    if (bytes.len < 4) return;
    const limit = bytes.len - 4;
    var position: usize = 0;
    while (position <= limit) : (position += 2) {
        if (bytes[position + 1] & 0xf8 != 0xf0 or bytes[position + 3] & 0xf8 != 0xf8) continue;
        var source = (@as(u32, bytes[position + 1]) & 7) << 19 |
            @as(u32, bytes[position]) << 11 |
            (@as(u32, bytes[position + 3]) & 7) << 8 |
            bytes[position + 2];
        source <<= 1;
        const absolute_position = start_offset +% @as(u32, @truncate(position)) +% 4;
        var destination = if (encode) source +% absolute_position else source -% absolute_position;
        destination >>= 1;
        bytes[position + 1] = 0xf0 | (@as(u8, @truncate(destination >> 19)) & 7);
        bytes[position] = @truncate(destination >> 11);
        bytes[position + 3] = 0xf8 | (@as(u8, @truncate(destination >> 8)) & 7);
        bytes[position + 2] = @truncate(destination);
        position += 2;
    }
}

fn transformSparc(bytes: []u8, start_offset: u32, encode: bool) void {
    const size = bytes.len & ~@as(usize, 3);
    var position: usize = 0;
    while (position < size) : (position += 4) {
        if (!((bytes[position] == 0x40 and bytes[position + 1] & 0xc0 == 0) or
            (bytes[position] == 0x7f and bytes[position + 1] & 0xc0 == 0xc0))) continue;
        var source = @as(u32, bytes[position]) << 24 |
            @as(u32, bytes[position + 1]) << 16 |
            @as(u32, bytes[position + 2]) << 8 |
            bytes[position + 3];
        source <<= 2;
        const absolute_position = start_offset +% @as(u32, @truncate(position));
        var destination = if (encode) source +% absolute_position else source -% absolute_position;
        destination >>= 2;
        const sign_fill: u32 = 0 -% (destination >> 22 & 1);
        destination = (sign_fill << 22 & 0x3fff_ffff) |
            (destination & 0x003f_ffff) |
            0x4000_0000;
        bytes[position] = @truncate(destination >> 24);
        bytes[position + 1] = @truncate(destination >> 16);
        bytes[position + 2] = @truncate(destination >> 8);
        bytes[position + 3] = @truncate(destination);
    }
}

fn transformArm64(bytes: []u8, start_offset: u32, encode: bool) void {
    const flag: u32 = 1 << 20;
    const mask: u32 = (1 << 24) - (flag << 1);
    const size = bytes.len & ~@as(usize, 3);
    var position: usize = 0;
    while (position < size) : (position += 4) {
        var value = std.mem.readInt(u32, bytes[position..][0..4], .little);
        const absolute_position = start_offset +% @as(u32, @truncate(position));
        if ((value -% 0x9400_0000) & 0xfc00_0000 == 0) {
            const pc = absolute_position >> 2;
            value = if (encode) value +% pc else value -% pc;
            value = (value & 0x03ff_ffff) | 0x9400_0000;
            std.mem.writeInt(u32, bytes[position..][0..4], value, .little);
            continue;
        }

        value -%= 0x9000_0000;
        if (value & 0x9f00_0000 != 0) continue;
        value +%= flag;
        if (value & mask != 0) continue;
        var transformed = (value & 0xffff_ffe0) | (value >> 26);
        const pc = (absolute_position >> 9) & ~@as(u32, 7);
        transformed = if (encode) transformed +% pc else transformed -% pc;
        value = (value & 0x1f) | 0x9000_0000;
        value |= transformed << 26;
        value |= 0x00ff_ffe0 & ((transformed & ((flag << 1) - 1)) -% flag);
        std.mem.writeInt(u32, bytes[position..][0..4], value, .little);
    }
}

fn transformRiscV(bytes: []u8, start_offset: u32, encode: bool) void {
    const aligned_size = bytes.len & ~@as(usize, 1);
    if (aligned_size <= 6) return;
    const limit = aligned_size - 6;
    var position: usize = 0;
    while (position < limit) {
        var candidate = (@as(u32, readU16Le(bytes, position)) ^ 0x10) +% 1;
        if (candidate & 0x77 != 0) {
            position += 2;
            continue;
        }
        const pc = start_offset +% @as(u32, @truncate(position));
        if (encode) {
            var instruction = readU32Le(bytes, position);
            if (candidate & 8 == 0) {
                if ((candidate -% 0x100) & 0xd80 != 0) {
                    position += 2;
                    continue;
                }
                var value = ((instruction & (@as(u32, 1) << 31)) >> 11) |
                    ((instruction & (0x3ff << 21)) >> 20) |
                    ((instruction & (1 << 20)) >> 9) |
                    (instruction & (0xff << 12));
                value +%= pc;
                bytes[position + 1] = @truncate(((value >> 13) & 0xf0) | ((instruction >> 8) & 0x0f));
                bytes[position + 2] = @truncate(value >> 9);
                bytes[position + 3] = @truncate(value >> 1);
                position += 4;
                continue;
            }

            if (candidate & 0xe80 != 0) {
                const following = readU32Le(bytes, position + 4);
                if (riscVCheck1(candidate, following)) {
                    writeU32Le(bytes, position, (following << 12) | 0x117);
                    instruction &= 0xffff_f000;
                    const signed_following: i32 = @bitCast(following);
                    instruction +%= @as(u32, @bitCast(signed_following >> 20));
                    instruction +%= pc;
                    std.mem.writeInt(u32, bytes[position + 4 ..][0..4], instruction, .big);
                    position += 8;
                } else {
                    position += 6;
                }
            } else {
                var register = instruction >> 27;
                if (riscVCheck2(candidate, register)) {
                    const following = readU32Le(bytes, position + 4);
                    register = (register << 7) +% 0x17 +% (following & 0xffff_f000);
                    instruction = (instruction >> 12) | (following << 20);
                    writeU32Le(bytes, position, register);
                    writeU32Le(bytes, position + 4, instruction);
                    position += 8;
                } else {
                    position += 4;
                }
            }
            continue;
        }

        if (candidate & 8 == 0) {
            candidate -%= 0x81;
            if (candidate & 0xd80 != 0) {
                position += 2;
                continue;
            }
            const instruction_low = (candidate +% 0x70) & 0xfff;
            var value = (@as(u32, bytes[position + 3]) << 1) |
                (@as(u32, bytes[position + 2]) << 9) |
                ((candidate & 0xf000) << 5);
            value -%= pc;
            const instruction = instruction_low |
                ((value << 11) & (@as(u32, 1) << 31)) |
                ((value << 20) & (0x3ff << 21)) |
                ((value << 9) & (1 << 20)) |
                (value & (0xff << 12));
            writeU32Le(bytes, position, instruction);
            position += 4;
            continue;
        }

        var instruction = readU32Le(bytes, position);
        if (candidate & 0xe80 == 0) {
            const register = instruction >> 27;
            if (riscVCheck2(candidate, register)) {
                var value = std.mem.readInt(u32, bytes[position + 4 ..][0..4], .big);
                candidate = instruction >> 12;
                value -%= pc;
                instruction = (register << 7) +% 0x17;
                instruction +%= (value +% 0x800) & 0xffff_f000;
                candidate |= value << 20;
                writeU32Le(bytes, position, instruction);
                writeU32Le(bytes, position + 4, candidate);
                position += 8;
            } else {
                position += 4;
            }
        } else {
            const following = readU32Le(bytes, position + 4);
            if (!riscVCheck1(candidate, following)) {
                position += 6;
            } else {
                candidate = (instruction & 0xffff_f000) | (following >> 20);
                instruction = (following << 12) | 0x117;
                writeU32Le(bytes, position, instruction);
                writeU32Le(bytes, position + 4, candidate);
                position += 8;
            }
        }
    }
}

fn riscVCheck1(value: u32, following: u32) bool {
    return (((following -% 3) ^ (value << 8)) & 0x000f_8003) == 0;
}

fn riscVCheck2(value: u32, register: u32) bool {
    return ((value -% 0x3108) << 18) < (register & 0x1d);
}

fn readU16Le(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32Le(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn writeU32Le(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

fn testX86MsByte(byte: u8) bool {
    return byte == 0 or byte == 0xff;
}

test "XZ delta inverse handles distance one and four" {
    var distance_one = [_]u8{ 1, 1, 1, 1 };
    transformDelta(&distance_one, 1, false);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, &distance_one);

    var distance_four = [_]u8{ 1, 2, 3, 4, 4, 4, 4, 4 };
    transformDelta(&distance_four, 4, false);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6, 7, 8 }, &distance_four);
}

test "XZ modern BCJ filters validate aligned start offsets" {
    try std.testing.expectError(error.InvalidXzHeader, Filter.arm64(2));
    try std.testing.expectError(error.InvalidXzHeader, Filter.riscv(1));
    try std.testing.expectError(
        error.InvalidXzHeader,
        parse(0x0a, &.{ 2, 0, 0, 0 }),
    );
    try std.testing.expectError(
        error.InvalidXzHeader,
        parse(0x0b, &.{ 1, 0, 0, 0 }),
    );
}

test "XZ preprocessing filters round trip representative instruction bytes" {
    const cases = [_]struct { filter: Filter, bytes: []const u8 }{
        .{ .filter = Filter.x86(0x1000), .bytes = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" },
        .{ .filter = try Filter.powerpc(0x1000), .bytes = "\x48\x00\x00\x01\x4b\xff\xff\xfd" },
        .{ .filter = try Filter.ia64(0x1000), .bytes = "\x16\x00\x00\x00\x00\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" },
        .{ .filter = try Filter.arm(0x1000), .bytes = "\x04\x00\x00\xeb\xfc\xff\xff\xeb" },
        .{ .filter = try Filter.armThumb(0x1000), .bytes = "\x00\xf0\x00\xf8\xff\xf7\xff\xff" },
        .{ .filter = try Filter.sparc(0x1000), .bytes = "\x40\x00\x00\x00\x7f\xff\xff\xff" },
        .{ .filter = try Filter.arm64(0x1000), .bytes = "\x00\x00\x00\x94\x00\x00\x00\x90" },
        .{ .filter = try Filter.riscv(0x1000), .bytes = "\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00" },
    };
    for (cases) |case| {
        const original = try std.testing.allocator.dupe(u8, case.bytes);
        defer std.testing.allocator.free(original);
        const transformed = try std.testing.allocator.dupe(u8, case.bytes);
        defer std.testing.allocator.free(transformed);
        encodeChain(transformed, &.{case.filter});
        if (case.filter.kind == .arm64 or case.filter.kind == .riscv)
            try std.testing.expect(!std.mem.eql(u8, original, transformed));
        decodeChain(transformed, &.{case.filter});
        try std.testing.expectEqualSlices(u8, original, transformed);
    }
}
