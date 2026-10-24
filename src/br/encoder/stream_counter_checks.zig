//! Internal serializer checks keep cumulative plaintext coordinates separate
//! from the physical history window. Large wire/input fixtures live in QA.
const std = @import("std");
const core = @import("../../core.zig");

pub fn compareWideContexts(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const history = try a.alloc(u8, 64 * 1024);
    defer a.free(history);
    const pattern = "abcdefgh";
    for (history, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    for ([_]?u4{ null, 0, 1, 2, 4, 11 }) |quality| {
        var low: Codec.State = .{};
        defer Codec.deinitState(&low, a);
        var high: Codec.State = .{};
        defer Codec.deinitState(&high, a);
        var low_wire: std.ArrayList(u8) = .empty;
        defer low_wire.deinit(a);
        var high_wire: std.ArrayList(u8) = .empty;
        defer high_wire.deinit(a);
        const options: Codec.StreamOptions = .{ .quality = quality, .window_bits = 16, .adaptive_blocks = false };
        try Codec.writePrefix(a, &low_wire, &low, options);
        try Codec.writePrefix(a, &high_wire, &high, options);
        for (0..2) |index| {
            const block = history[index * 32 * 1024 ..][0 .. 32 * 1024];
            try Codec.writeBlock(a, &low_wire, &low, block);
            try Codec.writeBlock(a, &high_wire, &high, block);
        }
        try std.testing.expectEqualSlices(u8, low_wire.items, high_wire.items);
        const large_base = (@as(core.StreamCount, 1) << 32) + history.len;
        high.wire_state.output_pos = large_base;
        try Codec.writeBlock(a, &low_wire, &low, pattern ** 8);
        try Codec.writeBlock(a, &high_wire, &high, pattern ** 8);
        try std.testing.expectEqualSlices(u8, low_wire.items, high_wire.items);
        try std.testing.expectEqual(try core.stream_count.addLocal(large_base, pattern.len * 8), high.wire_state.output_pos);
        try std.testing.expectEqual(low.wire_state.last_distances, high.wire_state.last_distances);
    }
}

pub fn refuseOverflowBeforePublication(comptime Codec: type, options: Codec.StreamOptions) !void {
    const a = std.testing.allocator;
    var state: Codec.State = .{};
    defer Codec.deinitState(&state, a);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try Codec.writePrefix(a, &wire, &state, options);
    const prefix = try a.dupe(u8, wire.items);
    defer a.free(prefix);
    const bit_index = state.bit_index;
    const recent = state.wire_state.last_distances;
    state.wire_state.output_pos = std.math.maxInt(core.StreamCount);
    try std.testing.expectError(error.IntegerOverflow, Codec.writeBlock(a, &wire, &state, "time"));
    try std.testing.expectEqualSlices(u8, prefix, wire.items);
    try std.testing.expectEqual(bit_index, state.bit_index);
    try std.testing.expectEqual(recent, state.wire_state.last_distances);
    try std.testing.expectEqual(std.math.maxInt(core.StreamCount), state.wire_state.output_pos);
}
