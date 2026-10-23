const std = @import("std");
const items = @import("item_encoder.zig");
const decoder = @import("decoder.zig");
const literal_encoder = @import("encoder.zig");
const tables = @import("tables.zig");

fn expectDecode(encoder: *items.Encoder, expected: []const u8) !void {
    const encoded = try encoder.finishAlloc();
    defer std.testing.allocator.free(encoded);
    const actual = try decoder.decodeAllocExactSize(std.testing.allocator, encoded, expected.len);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "LZMS item serializer retains literal reference bytes including empty and tiny streams" {
    const allocator = std.testing.allocator;
    const input = "literal-only ASCII reference\n" ** 64;
    for ([_]usize{ 0, 1, 17, input.len }) |size| {
        var encoder = try items.Encoder.init(allocator, size);
        defer encoder.deinit();
        for (input[0..size]) |byte| try encoder.push(.{ .literal = byte });
        const actual = try encoder.finishAlloc();
        defer allocator.free(actual);
        const expected = try literal_encoder.encodeLiteralAlloc(allocator, input[0..size]);
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "LZMS item serializer handles explicit and all delayed LZ repeat selections" {
    const allocator = std.testing.allocator;
    const offsets = [_]u32{ 9, 9, 9, 9, 1, 3, 2, 9, 9 };
    const length = 31;
    const size = 32 + offsets.len * length + 1;
    var expected: [size]u8 = undefined;
    var encoder = try items.Encoder.init(allocator, size);
    defer encoder.deinit();
    for (0..32) |index| {
        expected[index] = @intCast('A' + index % 26);
        try encoder.push(.{ .literal = expected[index] });
    }
    var position: usize = 32;
    for (offsets, 0..) |offset, index| {
        if (index == 3) {
            expected[position] = '.';
            position += 1;
            try encoder.push(.{ .literal = '.' });
        }
        for (0..length) |_| {
            expected[position] = expected[position - offset];
            position += 1;
        }
        try encoder.push(.{ .lz = .{ .offset = offset, .length = length } });
    }
    try std.testing.expectEqual(offsets.len, encoder.summary.lz_matches);
    try std.testing.expect(encoder.summary.lz_repeats >= 4);
    try expectDecode(&encoder, &expected);
}

test "LZMS item serializer handles all delta powers and delayed repeat pairs" {
    const allocator = std.testing.allocator;
    const offsets = [_]u32{ 8, 8, 8, 8, 1, 3, 2, 8, 8 };
    for (0..8) |power| {
        const span: usize = @as(usize, 1) << @intCast(power);
        const seed = 10 * span;
        const length = 3 * span;
        const size = seed + offsets.len * length + 1;
        const expected = try allocator.alloc(u8, size);
        defer allocator.free(expected);
        var encoder = try items.Encoder.init(allocator, size);
        defer encoder.deinit();
        for (0..seed) |index| {
            expected[index] = @truncate(index *% 4 + 7);
            try encoder.push(.{ .literal = expected[index] });
        }
        var position = seed;
        for (offsets, 0..) |raw_offset, index| {
            if (index == 3) {
                expected[position] = 7;
                position += 1;
                try encoder.push(.{ .literal = 7 });
            }
            const offset = raw_offset * span;
            for (0..length) |_| {
                expected[position] = expected[position - offset] +% expected[position - span] -% expected[position - offset - span];
                position += 1;
            }
            try encoder.push(.{ .delta = .{ .power = @intCast(power), .raw_offset = raw_offset, .length = @intCast(length) } });
        }
        try std.testing.expectEqual(offsets.len, encoder.summary.delta_matches);
        try std.testing.expect(encoder.summary.delta_repeats >= 3);
        try expectDecode(&encoder, expected);
    }
}

test "LZMS item serializer covers length slot boundaries and 30-bit extra lengths" {
    const allocator = std.testing.allocator;
    for (tables.length_slot_base[1 .. tables.length_slot_base.len - 1]) |base| {
        if (base > 70000) continue;
        for ([_]u32{ base - 1, base, base + 1 }) |length| {
            if (length < 2) continue;
            const expected = try allocator.alloc(u8, length + 1);
            defer allocator.free(expected);
            @memset(expected, 7);
            var encoder = try items.Encoder.init(allocator, expected.len);
            defer encoder.deinit();
            try encoder.push(.{ .literal = 7 });
            try encoder.push(.{ .lz = .{ .offset = 1, .length = length } });
            try expectDecode(&encoder, expected);
        }
    }
}

test "LZMS item serializer validates reach and power before changing progress and remains sticky" {
    const allocator = std.testing.allocator;
    for ([_]items.Item{
        .{ .lz = .{ .offset = 1, .length = 2 } },
        .{ .lz = .{ .offset = 0, .length = 2 } },
        .{ .delta = .{ .power = 8, .raw_offset = 1, .length = 2 } },
        .{ .delta = .{ .power = 0, .raw_offset = 0, .length = 2 } },
        .{ .delta = .{ .power = 7, .raw_offset = 1, .length = 2 } },
    }) |invalid| {
        var encoder = try items.Encoder.init(allocator, 8);
        defer encoder.deinit();
        try std.testing.expectError(error.InvalidLzms, encoder.push(invalid));
        try std.testing.expectEqual(@as(usize, 0), encoder.position);
        try std.testing.expectEqual(@as(usize, 0), encoder.range.bytes.items.len);
        try std.testing.expectEqual(@as(usize, 0), encoder.bits.words.items.len);
        try std.testing.expectError(error.InvalidLzms, encoder.push(.{ .literal = 7 }));
        try std.testing.expectError(error.InvalidLzms, encoder.finishAlloc());
    }
}

test "LZMS item serializer switches LZ and delta recent histories independently" {
    const allocator = std.testing.allocator;
    const plan = [_]items.Item{
        .{ .lz = .{ .offset = 9, .length = 31 } },
        .{ .delta = .{ .power = 3, .raw_offset = 1, .length = 16 } },
        .{ .lz = .{ .offset = 9, .length = 31 } },
        .{ .delta = .{ .power = 3, .raw_offset = 1, .length = 16 } },
        .{ .delta = .{ .power = 3, .raw_offset = 1, .length = 16 } },
        .{ .lz = .{ .offset = 9, .length = 31 } },
    };
    const size = 32 + 31 * 3 + 16 * 3;
    const expected = [_]u8{7} ** size;
    var encoder = try items.Encoder.init(allocator, size);
    defer encoder.deinit();
    for (0..32) |_| try encoder.push(.{ .literal = 7 });
    for (plan) |item| try encoder.push(item);
    try std.testing.expectEqual(@as(usize, 2), encoder.summary.lz_repeats);
    try std.testing.expectEqual(@as(usize, 1), encoder.summary.delta_repeats);
    try expectDecode(&encoder, &expected);
}

test "LZMS item serializer releases every initialization emission and finishing allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var encoder = try items.Encoder.init(allocator, 4096);
            defer encoder.deinit();
            for (0..512) |_| try encoder.push(.{ .literal = 7 });
            try encoder.push(.{ .delta = .{ .power = 0, .raw_offset = 1, .length = 512 } });
            try encoder.push(.{ .lz = .{ .offset = 1, .length = 3072 } });
            const output = try encoder.finishAlloc();
            defer allocator.free(output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
