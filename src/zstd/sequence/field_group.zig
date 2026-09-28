const std = @import("std");
const bit_reader = @import("bit_reader.zig");

/// A complete sequence's extra bits and FSE transitions, loaded once.
/// At most 56 payload bits fit regardless of the final byte's alignment.
/// The ordinary reader handles larger groups and the physical stream tail.
/// Successful initialization consumes the whole group from the source reader;
/// callers must read exactly total_bits, in fields of at most 32 bits.
pub const Group = struct {
    bits: u64,
    consumed: u8 = 0,

    pub inline fn init(reader: *bit_reader.Reader, total_bits: u8) ?Group {
        if (total_bits > 56 or reader.remaining_bits < 64) return null;
        std.debug.assert(reader.remaining_bits <= reader.bytes.len * 8);
        const end_byte = (reader.remaining_bits + 7) >> 3;
        const padding: u3 = @intCast(end_byte * 8 - reader.remaining_bits);
        const bits = std.mem.readInt(u64, reader.bytes[end_byte - 8 ..][0..8], .little);
        reader.remaining_bits -= total_bits;
        return .{ .bits = bits << padding };
    }

    pub inline fn read(self: *Group, width: u8) usize {
        std.debug.assert(width <= 32);
        if (width == 0) return 0;
        const consumed = self.consumed + width;
        std.debug.assert(consumed <= 56);
        const value = self.bits >> @intCast(64 - consumed);
        self.consumed = consumed;
        return @intCast(value & ((@as(u64, 1) << @intCast(width)) - 1));
    }
};

test "sequence field group rejects short input and wide groups without progress" {
    const bytes = [_]u8{0xa5} ** 16;
    for (0..bytes.len + 1) |len| {
        for (0..len * 8 + 1) |remaining| {
            for (0..256) |total| {
                var reader: bit_reader.Reader = .{ .bytes = bytes[0..len], .remaining_bits = remaining };
                const group = Group.init(&reader, @intCast(total));
                if (total > 56 or remaining < 64) {
                    try std.testing.expect(group == null);
                    try std.testing.expectEqual(remaining, reader.remaining_bits);
                } else {
                    try std.testing.expect(group != null);
                    try std.testing.expectEqual(remaining - total, reader.remaining_bits);
                }
            }
        }
    }
}

test "sequence field groups match varying six-field sequences and unaligned inputs" {
    var random = std.Random.DefaultPrng.init(0x7389dbea);
    var storage: [40]u8 = undefined;
    for (0..8) |alignment| {
        const bytes = storage[alignment..];
        for (0..256) |_| {
            random.random().bytes(bytes);
            bytes[bytes.len - 1] |= 1;
            var reference = try bit_reader.Reader.init(bytes);
            try reference.skip(random.random().intRangeAtMost(u8, 0, 80));
            var widths: [6]u8 = undefined;
            var total: u8 = 0;
            for (&widths) |*width| {
                width.* = random.random().intRangeAtMost(u8, 0, @min(32, 56 - total));
                total += width.*;
            }
            var reader = reference;
            var group = Group.init(&reader, total) orelse unreachable;
            for (widths) |width| try std.testing.expectEqual(try reference.read(width), group.read(width));
            try std.testing.expectEqual(reference.remaining_bits, reader.remaining_bits);
            try std.testing.expectEqual(try reference.read(8), try reader.read(8));
        }
    }
}

test "sequence field groups match exact reverse reads at every alignment" {
    var bytes: [32]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i * 109 + 37);
    for (8..bytes.len + 1) |len| {
        for (0..8) |marker| {
            bytes[len - 1] = @as(u8, 1) << @intCast(marker);
            for (0..33) |first| {
                for (0..25) |second| {
                    if (first + second > 56) continue;
                    const widths = [_]u8{ @intCast(first), @intCast(second), @intCast(56 - first - second), 0 };
                    var reference = try bit_reader.Reader.init(bytes[0..len]);
                    var reader = reference;
                    var group = Group.init(&reader, 56) orelse continue;
                    // Split an oversized final field to keep each field <= 32.
                    for (widths) |width| {
                        const high = @min(width, 32);
                        try std.testing.expectEqual(try reference.read(high), group.read(high));
                        const low = width - high;
                        try std.testing.expectEqual(try reference.read(low), group.read(low));
                    }
                    try std.testing.expectEqual(reference.remaining_bits, reader.remaining_bits);
                    try std.testing.expectEqual(try reference.read(8), try reader.read(8));
                }
            }
        }
    }
}
