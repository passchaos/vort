const std = @import("std");

pub const Error = error{
    InvalidXzHeader,
    UnsupportedXzFeature,
};

pub const Kind = enum {
    delta,
    x86,
};

pub const Filter = struct {
    kind: Kind,
    parameter: u32,
};

pub fn parse(id: u64, properties: []const u8) Error!Filter {
    return switch (id) {
        0x03 => blk: {
            if (properties.len != 1) return error.InvalidXzHeader;
            break :blk .{ .kind = .delta, .parameter = @as(u32, properties[0]) + 1 };
        },
        0x04 => blk: {
            if (properties.len != 0 and properties.len != 4) return error.InvalidXzHeader;
            break :blk .{
                .kind = .x86,
                .parameter = if (properties.len == 0) 0 else std.mem.readInt(u32, properties[0..4], .little),
            };
        },
        else => error.UnsupportedXzFeature,
    };
}

pub fn decodeChain(bytes: []u8, chain: []const Filter) void {
    var index = chain.len;
    while (index != 0) {
        index -= 1;
        const filter = chain[index];
        switch (filter.kind) {
            .delta => decodeDelta(bytes, @intCast(filter.parameter)),
            .x86 => decodeX86(bytes, filter.parameter),
        }
    }
}

fn decodeDelta(bytes: []u8, distance: usize) void {
    for (distance..bytes.len) |index| bytes[index] +%= bytes[index - distance];
}

fn decodeX86(bytes: []u8, start_offset: u32) void {
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
                destination = source -% (absolute_position +% 5);
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

fn testX86MsByte(byte: u8) bool {
    return byte == 0 or byte == 0xff;
}

test "XZ delta inverse handles distance one and four" {
    var distance_one = [_]u8{ 1, 1, 1, 1 };
    decodeDelta(&distance_one, 1);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, &distance_one);

    var distance_four = [_]u8{ 1, 2, 3, 4, 4, 4, 4, 4 };
    decodeDelta(&distance_four, 4);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6, 7, 8 }, &distance_four);
}
