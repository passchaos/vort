const std = @import("std");
const encoder = @import("fse.zig");
const decoder = @import("../fse.zig");
const format = @import("../format.zig");
const bit_writer = @import("bit_writer.zig");
const allocator = std.testing.allocator;

test "LZFSE encoder normalization preserves support and exact state sums" {
    var counts: [256]u32 = @splat(0);
    var frequencies: [256]u16 = undefined;
    for ([_]usize{ 64, 256, 1024 }) |states| {
        @memset(&counts, 0);
        try encoder.normalize(states, &counts, &frequencies);
        try std.testing.expectEqual(states, frequencies[0]);
        for (frequencies[1..]) |frequency| try std.testing.expectEqual(@as(u16, 0), frequency);
        const used = @min(states, counts.len);
        for (counts[0..used], 0..) |*count, index| count.* = if (index == 0) std.math.maxInt(u32) else @intCast(index + 1);
        try encoder.normalize(states, &counts, &frequencies);
        try decoder.validateFrequencies(&frequencies, states);
        for (counts, frequencies) |count, frequency|
            try std.testing.expectEqual(count != 0, frequency != 0);
        var repeated: [256]u16 = undefined;
        try encoder.normalize(states, &counts, &repeated);
        try std.testing.expectEqualSlices(u16, &frequencies, &repeated);
    }
    @memset(&counts, 1);
    try std.testing.expectError(error.InvalidLzfseStream, encoder.normalize(64, &counts, &frequencies));
    try std.testing.expectError(error.InvalidLzfseStream, encoder.normalize(0, &counts, &frequencies));
    try std.testing.expectError(error.InvalidLzfseStream, encoder.normalize(65, &counts, &frequencies));
    try std.testing.expectError(error.InvalidLzfseStream, encoder.normalize(2048, &counts, &frequencies));
    try std.testing.expectError(error.InvalidLzfseStream, encoder.normalize(1024, &counts, frequencies[0..2]));
}

test "LZFSE encoder transition tables invert contiguous decoder states" {
    for ([_]usize{ 64, 256, 1024 }) |states| {
        const samples = [_]usize{ 0, 1, 3, states / 3, states / 2, states - 1, states };
        for (samples) |frequency| {
            const frequencies = [_]u16{ @intCast(frequency), @intCast(states - frequency) };
            var entries: [2]encoder.Entry = undefined;
            const table = try encoder.initTable(states, &frequencies, &entries);
            var decode_entries: [1024]decoder.DecoderEntry = undefined;
            try decoder.initDecoderTable(states, &frequencies, decode_entries[0..states]);
            for (0..2) |symbol| {
                for ([_]usize{ 0, 1, states / 2, states - 1 }) |initial| {
                    var writer = bit_writer.Writer{};
                    defer writer.deinit(allocator);
                    var state: u16 = @intCast(initial);
                    if (frequencies[symbol] == 0) {
                        try std.testing.expectError(error.InvalidLzfseStream, table.encodeSymbol(allocator, &state, &writer, symbol));
                        continue;
                    }
                    try table.encodeSymbol(allocator, &state, &writer, symbol);
                    const final_bits = try writer.finish(allocator);
                    var reader = try decoder.BitReader.init(writer.bytes.items, final_bits);
                    try std.testing.expectEqual(symbol, try decoder.decodeSymbol(&state, decode_entries[0..states], &reader));
                    try std.testing.expectEqual(initial, state);
                    try std.testing.expectEqual(@as(usize, 0), reader.bit_position);
                }
            }
            var writer = bit_writer.Writer{};
            defer writer.deinit(allocator);
            var invalid_state: u16 = @intCast(states);
            try std.testing.expectError(error.InvalidLzfseStream, table.encodeSymbol(allocator, &invalid_state, &writer, 0));
        }
    }
}

test "LZFSE encoder random symbol streams return every state to zero" {
    var random = std.Random.DefaultPrng.init(0x14e2_cbc9_a483_f713);
    for ([_]usize{ 64, 256, 1024 }) |states| {
        const alphabet: usize = if (states == 64) 20 else 256;
        for (0..12) |_| {
            var symbols: [1024]u8 = undefined;
            var counts: [256]u32 = @splat(0);
            for (&symbols) |*symbol| {
                symbol.* = @intCast(random.random().uintLessThan(usize, alphabet));
                counts[symbol.*] += 1;
            }
            var frequencies: [256]u16 = undefined;
            try encoder.normalize(states, counts[0..alphabet], frequencies[0..alphabet]);
            var entries: [256]encoder.Entry = undefined;
            const table = try encoder.initTable(states, frequencies[0..alphabet], entries[0..alphabet]);
            var decode_entries: [1024]decoder.DecoderEntry = undefined;
            try decoder.initDecoderTable(states, frequencies[0..alphabet], decode_entries[0..states]);
            var writer = bit_writer.Writer{};
            defer writer.deinit(allocator);
            var state: u16 = 0;
            var index = symbols.len;
            while (index != 0) {
                index -= 1;
                try table.encodeSymbol(allocator, &state, &writer, symbols[index]);
            }
            const final_bits = try writer.finish(allocator);
            var reader = try decoder.BitReader.init(writer.bytes.items, final_bits);
            for (symbols) |symbol| try std.testing.expectEqual(symbol, try decoder.decodeSymbol(&state, decode_entries[0..states], &reader));
            try std.testing.expectEqual(@as(u16, 0), state);
            try std.testing.expectEqual(@as(usize, 0), reader.bit_position);
        }
    }
}

test "LZFSE encoder value slots round trip every L M D endpoint and extra width" {
    for ([_]struct { states: usize, bases: []const i32, widths: []const u8 }{
        .{ .states = format.l_state_count, .bases = &format.l_base_value, .widths = &format.l_extra_bits },
        .{ .states = format.m_state_count, .bases = &format.m_base_value, .widths = &format.m_extra_bits },
        .{ .states = format.d_state_count, .bases = &format.d_base_value, .widths = &format.d_extra_bits },
    }) |family| {
        var counts: [64]u32 = @splat(1);
        var frequencies: [64]u16 = undefined;
        try encoder.normalize(family.states, counts[0..family.bases.len], frequencies[0..family.bases.len]);
        var entries: [64]encoder.Entry = undefined;
        const table = try encoder.initTable(family.states, frequencies[0..family.bases.len], entries[0..family.bases.len]);
        var decode_entries: [256]decoder.ValueDecoderEntry = undefined;
        try decoder.initValueDecoderTable(family.states, frequencies[0..family.bases.len], family.widths, family.bases, decode_entries[0..family.states]);
        var values: [128]u32 = undefined;
        for (family.bases, family.widths, 0..) |base, width, symbol| {
            values[2 * symbol] = @intCast(base);
            values[2 * symbol + 1] = @as(u32, @intCast(base)) + (@as(u32, 1) << @intCast(width)) - 1;
            try std.testing.expectEqual(symbol, try encoder.valueSlot(values[2 * symbol], family.bases, family.widths));
            try std.testing.expectEqual(symbol, try encoder.valueSlot(values[2 * symbol + 1], family.bases, family.widths));
        }
        try std.testing.expectError(error.InvalidLzfseStream, encoder.valueSlot(values[2 * family.bases.len - 1] + 1, family.bases, family.widths));
        var writer = bit_writer.Writer{};
        defer writer.deinit(allocator);
        var state: u16 = 0;
        var index = 2 * family.bases.len;
        while (index != 0) {
            index -= 1;
            try table.encodeValue(allocator, &state, &writer, values[index], family.bases, family.widths);
        }
        const final_bits = try writer.finish(allocator);
        var reader = try decoder.BitReader.init(writer.bytes.items, final_bits);
        for (values[0 .. 2 * family.bases.len]) |value|
            try std.testing.expectEqual(@as(i32, @intCast(value)), try decoder.decodeValue(&state, decode_entries[0..family.states], &reader));
        try std.testing.expectEqual(@as(u16, 0), state);
        try std.testing.expectEqual(@as(usize, 0), reader.bit_position);
    }
}
