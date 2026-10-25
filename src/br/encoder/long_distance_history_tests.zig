//! Independent command replay and exact far-source fixtures. No hash, stride
//! calculation or production comparison routine is used to verify copies.
const std = @import("std");
const commands = @import("command_plan.zig");

fn fill(bytes: []u8) void {
    var random: u32 = 0x1234abcd;
    for (bytes) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate((random >> 24) & 127);
    }
}

fn replay(history: []const u8, input: []const u8, plan: []const commands.Command) !void {
    var cursor: usize = 0;
    for (plan) |command| {
        try std.testing.expectEqual(cursor, command.insert_start);
        try std.testing.expect(command.insert_len <= input.len - cursor);
        cursor += command.insert_len;
        if (!command.has_copy) continue;
        const copied = command.outputLen();
        try std.testing.expect(copied != 0 and copied <= input.len - cursor);
        if (command.isLz77()) {
            try std.testing.expect(command.distance != 0 and command.distance <= history.len + cursor);
            for (0..copied) |index| {
                const source = history.len + cursor + index - command.distance;
                const expected = if (source < history.len) history[source] else input[source - history.len];
                try std.testing.expectEqual(expected, input[cursor + index]);
            }
        }
        cursor += copied;
    }
    try std.testing.expectEqual(input.len, cursor);
}

fn exactDistances(comptime Codec: type) !void {
    const marker = [_]u8{ 201, 202, 203 };
    const a = std.testing.allocator;
    for ([_]usize{ 65521, 65535, 65536, 70000, 131056 }) |distance| {
        const history = try a.alloc(u8, distance);
        defer a.free(history);
        fill(history);
        @memcpy(history[0..marker.len], &marker);
        const original = [_]commands.Command{.{ .insert_start = 0, .insert_len = marker.len }};
        const actual = try Codec.augmentLargeWindowHistoryAlloc(a, history, &marker, &original, 131056) orelse return error.TestUnexpectedResult;
        defer a.free(actual);
        try std.testing.expectEqual(@as(usize, 1), actual.len);
        try std.testing.expectEqual(@as(usize, 3), actual[0].copy_len);
        try std.testing.expectEqual(distance, actual[0].distance);
        try std.testing.expectEqual(@as(usize, 0), actual[0].insert_len);
        try replay(history, &marker, actual);
        // The legacy literal-length admission remains at sixteen bytes.
        try std.testing.expectEqual(@as(?[]commands.Command, null), try Codec.augmentAllocWithHistoryAndMaxDistanceForFormat(a, history, &marker, &original, 131056, .large_window));

        const tail = [_]u8{ 0, 201, 202, 203 };
        const tail_plan = [_]commands.Command{.{ .insert_start = 0, .insert_len = tail.len }};
        const last_three = try Codec.augmentLargeWindowHistoryAlloc(a, history, &tail, &tail_plan, 131057) orelse return error.TestUnexpectedResult;
        defer a.free(last_three);
        try std.testing.expectEqual(@as(usize, 1), last_three[0].insert_len);
        try std.testing.expectEqual(@as(usize, 3), last_three[0].copy_len);
        try std.testing.expectEqual(distance + 1, last_three[0].distance);
        try replay(history, &tail, last_three);
    }
}

fn seamsAndWindow(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const history = try a.alloc(u8, 70000);
    defer a.free(history);
    fill(history);
    history[history.len - 1] = 201;
    const position: usize = 65520;
    const input = try a.alloc(u8, position + 3);
    defer a.free(input);
    fill(input);
    input[0] = 202;
    input[1] = 203;
    @memcpy(input[position..], &[_]u8{ 201, 202, 203 });
    const original = [_]commands.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const actual = try Codec.augmentLargeWindowHistoryAlloc(a, history, input, &original, 131056) orelse return error.TestUnexpectedResult;
    defer a.free(actual);
    try replay(history, input, actual);
    var found = false;
    for (actual) |command| {
        if (command.has_copy and command.insert_start + command.insert_len == position and command.distance == 65521 and command.copy_len == 3) found = true;
    }
    try std.testing.expect(found);

    const marker = [_]u8{ 231, 232, 233 };
    const older = try a.alloc(u8, 131060);
    defer a.free(older);
    fill(older);
    @memcpy(older[0..3], &marker);
    const tail = [_]commands.Command{.{ .insert_start = 0, .insert_len = marker.len }};
    try std.testing.expectEqual(@as(?[]commands.Command, null), try Codec.augmentLargeWindowHistoryAlloc(a, older, &marker, &tail, 131056));
    @memcpy(older[4..7], &marker);
    const boundary = try Codec.augmentLargeWindowHistoryAlloc(a, older, &marker, &tail, 131056) orelse return error.TestUnexpectedResult;
    defer a.free(boundary);
    try std.testing.expectEqual(@as(usize, 131056), boundary[0].distance);
    try replay(older, &marker, boundary);
}

fn preserveCopies(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const history = try a.alloc(u8, 70000);
    defer a.free(history);
    fill(history);
    @memcpy(history[0..3], &[_]u8{ 201, 202, 203 });
    const input = [_]u8{ 201, 202, 203, 203, 203, 203, 7, 8, 9, 10, 11, 12, 13 };
    const original = [_]commands.Command{
        .{ .insert_start = 0, .insert_len = 3, .copy_len = 3, .distance = 1, .has_copy = true },
        .{ .insert_start = 6, .insert_len = 0, .copy_len = 4, .has_copy = true, .source = .static, .dictionary_output_len = 3, .dictionary_address = 17 },
        .{ .insert_start = 9, .insert_len = 0, .copy_len = 4, .has_copy = true, .source = .compound, .dictionary_address = 29 },
    };
    const before = original;
    const actual = try Codec.augmentLargeWindowHistoryAlloc(a, history, &input, &original, 131056) orelse return error.TestUnexpectedResult;
    defer a.free(actual);
    try std.testing.expectEqual(@as(usize, 4), actual.len);
    try std.testing.expectEqualDeep(before, original);
    var preserved = original[0];
    preserved.insert_start = 3;
    preserved.insert_len = 0;
    try std.testing.expectEqualDeep(preserved, actual[1]);
    try std.testing.expectEqualDeep(original[1], actual[2]);
    try std.testing.expectEqualDeep(original[2], actual[3]);
    try replay(history, &input, actual);

    const longer = try a.alloc(u8, 600);
    defer a.free(longer);
    @memset(history, 7);
    @memset(longer, 7);
    const literals = [_]commands.Command{.{ .insert_start = 0, .insert_len = longer.len }};
    const bounded = try Codec.augmentLargeWindowHistoryAlloc(a, history, longer, &literals, 131056) orelse return error.TestUnexpectedResult;
    defer a.free(bounded);
    for (bounded) |command| if (command.has_copy) {
        try std.testing.expect(command.copy_len <= 258);
    };
    try replay(history, longer, bounded);
}

fn admissionAndOom(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const history = try a.alloc(u8, 70000);
    defer a.free(history);
    fill(history);
    const marker = [_]u8{ 201, 202, 203 };
    @memcpy(history[0..3], &marker);
    var refusing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    const invalid = [_]commands.Command{.{ .insert_start = 0, .insert_len = std.math.maxInt(usize) }};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, &marker, &invalid, 131056));
    try std.testing.expectEqual(@as(usize, 0), refusing.alloc_index);
    const bad_start = [_]commands.Command{.{ .insert_start = 1, .insert_len = marker.len }};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, &marker, &bad_start, 131056));
    const original = [_]commands.Command{.{ .insert_start = 0, .insert_len = marker.len }};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, &marker, &original, 65520));
    const cached_hq = [_]commands.Command{.{ .insert_start = 0, .insert_len = marker.len, .hq_encoding = .{ .command_symbol = 0 } }};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, &marker, &cached_hq, 131056));
    try std.testing.expectEqual(@as(usize, 0), refusing.alloc_index);
    const copy = [_]commands.Command{.{ .insert_start = 0, .insert_len = 0, .copy_len = 3, .has_copy = true, .distance = 0 }};
    try std.testing.expectError(error.InvalidBlockPlan, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, &marker, &copy, 131056));
    const huge: []const u8 = @as([*]const u8, @ptrFromInt(1))[0..std.math.maxInt(usize)];
    try std.testing.expectError(error.IntegerOverflow, Codec.augmentLargeWindowHistoryAlloc(refusing.allocator(), history, huge, &original, 131056));

    var baseline = std.testing.FailingAllocator.init(a, .{});
    const first = try Codec.augmentLargeWindowHistoryAlloc(baseline.allocator(), history, &marker, &original, 131056) orelse return error.TestUnexpectedResult;
    const expected = try a.dupe(commands.Command, first);
    defer a.free(expected);
    baseline.allocator().free(first);
    const allocations = baseline.alloc_index;
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for (0..allocations) |failure| {
        var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = failure });
        try std.testing.expectError(error.OutOfMemory, Codec.augmentLargeWindowHistoryAlloc(heap.allocator(), history, &marker, &original, 131056));
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try std.testing.expectEqualDeep(@as([3]u8, marker), history[0..3].*);
    }
    const repeated = try Codec.augmentLargeWindowHistoryAlloc(a, history, &marker, &original, 131056) orelse return error.TestUnexpectedResult;
    defer a.free(repeated);
    try std.testing.expectEqualSlices(commands.Command, expected, repeated);
}

pub fn contracts(comptime Codec: type) !void {
    try exactDistances(Codec);
    try seamsAndWindow(Codec);
    try preserveCopies(Codec);
    try admissionAndOom(Codec);
}
