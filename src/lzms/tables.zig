const std = @import("std");

pub const max_match_length: u32 = 1_073_809_578;
pub const max_match_offset: u32 = 1_180_427_428;
pub const max_buffer_size: usize = 1 << 30;
pub const max_offset_symbols: usize = 799;

const BitRun = struct {
    bits: u8,
    count: usize,
};

const offset_bit_runs = [_]BitRun{
    .{ .bits = 0, .count = 8 },
    .{ .bits = 2, .count = 9 },
    .{ .bits = 3, .count = 7 },
    .{ .bits = 4, .count = 10 },
    .{ .bits = 5, .count = 15 },
    .{ .bits = 6, .count = 15 },
    .{ .bits = 7, .count = 20 },
    .{ .bits = 8, .count = 20 },
    .{ .bits = 9, .count = 30 },
    .{ .bits = 10, .count = 33 },
    .{ .bits = 11, .count = 40 },
    .{ .bits = 12, .count = 42 },
    .{ .bits = 13, .count = 45 },
    .{ .bits = 14, .count = 60 },
    .{ .bits = 15, .count = 73 },
    .{ .bits = 16, .count = 80 },
    .{ .bits = 17, .count = 85 },
    .{ .bits = 18, .count = 95 },
    .{ .bits = 19, .count = 105 },
    .{ .bits = 20, .count = 6 },
    .{ .bits = 30, .count = 1 },
};

pub const extra_offset_bits = buildExtraOffsetBits();
pub const offset_slot_base = buildOffsetSlotBases();

fn buildExtraOffsetBits() [max_offset_symbols]u8 {
    var result: [max_offset_symbols]u8 = undefined;
    var index: usize = 0;
    for (offset_bit_runs) |run| {
        for (0..run.count) |_| {
            result[index] = run.bits;
            index += 1;
        }
    }
    std.debug.assert(index == result.len);
    return result;
}

fn buildOffsetSlotBases() [max_offset_symbols + 1]u32 {
    var result: [max_offset_symbols + 1]u32 = undefined;
    var base: u32 = 1;
    for (extra_offset_bits, 0..) |bits, index| {
        result[index] = base;
        base += @as(u32, 1) << @intCast(bits);
    }
    result[max_offset_symbols] = base;
    std.debug.assert(base == max_match_offset + 1);
    return result;
}

pub const length_slot_base = [_]u32{
    0x00000001, 0x00000002, 0x00000003, 0x00000004,
    0x00000005, 0x00000006, 0x00000007, 0x00000008,
    0x00000009, 0x0000000a, 0x0000000b, 0x0000000c,
    0x0000000d, 0x0000000e, 0x0000000f, 0x00000010,
    0x00000011, 0x00000012, 0x00000013, 0x00000014,
    0x00000015, 0x00000016, 0x00000017, 0x00000018,
    0x00000019, 0x0000001a, 0x0000001b, 0x0000001d,
    0x0000001f, 0x00000021, 0x00000023, 0x00000027,
    0x0000002b, 0x0000002f, 0x00000033, 0x00000037,
    0x0000003b, 0x00000043, 0x0000004b, 0x00000053,
    0x0000005b, 0x0000006b, 0x0000007b, 0x0000008b,
    0x0000009b, 0x000000ab, 0x000000cb, 0x000000eb,
    0x0000012b, 0x000001ab, 0x000002ab, 0x000004ab,
    0x000008ab, 0x000108ab, 0x400108ab,
};

pub const extra_length_bits = [_]u8{
    0, 0, 0, 0,  0,  0,  0, 0,
    0, 0, 0, 0,  0,  0,  0, 0,
    0, 0, 0, 0,  0,  0,  0, 0,
    0, 0, 1, 1,  1,  1,  2, 2,
    2, 2, 2, 2,  3,  3,  3, 3,
    4, 4, 4, 4,  4,  5,  5, 6,
    7, 8, 9, 10, 16, 30,
};

pub fn numOffsetSlots(uncompressed_size: usize) usize {
    if (uncompressed_size < 2) return 0;
    return findSlot(@intCast(uncompressed_size - 1), &offset_slot_base);
}

fn findSlot(value: u32, bases: []const u32) usize {
    var low: usize = 0;
    var high = bases.len - 2;
    while (true) {
        const slot = (low + high) / 2;
        if (value < bases[slot]) {
            high = slot - 1;
        } else if (value >= bases[slot + 1]) {
            low = slot + 1;
        } else {
            return slot + 1;
        }
    }
}

test "LZMS generated offset tables preserve format boundaries" {
    try std.testing.expectEqual(@as(u32, 1), offset_slot_base[0]);
    try std.testing.expectEqual(@as(u32, 9), offset_slot_base[8]);
    try std.testing.expectEqual(max_match_offset + 1, offset_slot_base[max_offset_symbols]);
    try std.testing.expectEqual(@as(usize, 1), numOffsetSlots(2));
    try std.testing.expectEqual(@as(usize, 9), numOffsetSlots(10));
    try std.testing.expectEqual(max_match_length + 1, length_slot_base[length_slot_base.len - 1]);
}
