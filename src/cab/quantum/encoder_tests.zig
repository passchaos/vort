const std = @import("std");
const encoder = @import("encoder.zig");
const decoder = @import("decoder.zig");
const literal = @import("literal_encoder.zig");
const tables = @import("tables.zig");

test "Quantum public greedy frames round trip empty tiny structured random and multiframe input" {
    const allocator = std.testing.allocator;
    for ([_]usize{ 0, 1, 2, 3, 4, 5, 259, 32768, 32769, 65536 + 73 }) |length| {
        const input = try allocator.alloc(u8, length);
        defer allocator.free(input);
        for ([_]bool{ false, true }) |random_input| {
            if (random_input) {
                var random = std.Random.DefaultPrng.init(length + 0xd5a7);
                random.random().bytes(input);
            } else {
                const phrase = "Quantum greedy and adaptive match frame corpus\n";
                for (input, 0..) |*byte, index| byte.* = phrase[index % phrase.len];
            }
            const before = try allocator.dupe(u8, input);
            defer allocator.free(before);
            inline for (.{ 10, 18, 21 }) |bits| {
                var encoded = try encoder.encodeWithSummaryAlloc(allocator, input, .{ .window_bits = bits });
                defer encoded.deinit(allocator);
                const decoded = try decoder.decodeAlloc(allocator, encoded.bytes, input.len, bits);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, input, decoded);
                try std.testing.expectEqualSlices(u8, before, input);
                if (!random_input and length > 1000) {
                    try std.testing.expect(encoded.summary.matched_bytes > input.len * 9 / 10);
                    try std.testing.expect(encoded.bytes.len < input.len / 8);
                }
                const repeated = try encoder.encodeAlloc(allocator, input, .{ .window_bits = bits });
                defer allocator.free(repeated);
                try std.testing.expectEqualSlices(u8, encoded.bytes, repeated);
            }
        }
    }
}

test "Quantum literal strategy preserves every reference frame byte" {
    const allocator = std.testing.allocator;
    const input = "Quantum literal reference across adaptive frame boundaries\n" ** 1600;
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    var reference = literal.LiteralEncoder.init();
    var start: usize = 0;
    while (start < input.len) {
        const end = start + @min(input.len - start, tables.frame_size);
        const bytes = try reference.encodeFrameAlloc(allocator, input[start..end]);
        defer allocator.free(bytes);
        try expected.appendSlice(allocator, bytes);
        if (end - start == tables.frame_size) try expected.append(allocator, 0xff);
        start = end;
    }
    var encoded = try encoder.encodeWithSummaryAlloc(allocator, input, .{ .strategy = .literals });
    defer encoded.deinit(allocator);
    try std.testing.expectEqualSlices(u8, expected.items, encoded.bytes);
    try std.testing.expectEqual(input.len, encoded.summary.literals);
    try std.testing.expectEqual(@as(usize, 0), encoded.summary.matched_bytes);
}

test "Quantum resource limits and caller output remain transactional" {
    const allocator = std.testing.allocator;
    const input = "Quantum working memory and output resource limits\n" ** 100;
    var encoded = try encoder.encodeWithSummaryAlloc(allocator, input, .{});
    defer encoded.deinit(allocator);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeAlloc(allocator, input, .{ .max_working_memory = 0 }));
    try std.testing.expectError(error.OutputLimitExceeded, encoder.encodeAlloc(allocator, input, .{ .max_output_len = encoded.bytes.len - 1 }));
    const exact = try encoder.encodeAlloc(allocator, input, .{ .max_output_len = encoded.bytes.len });
    defer allocator.free(exact);
    try std.testing.expectEqualSlices(u8, encoded.bytes, exact);
    var guarded: [8]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeInto(allocator, input, guarded[2..6], .{}));
    try std.testing.expectEqual(@as([8]u8, @splat(0xa5)), guarded);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    try std.testing.expectError(error.OutputLimitExceeded, encoder.encodeAppend(allocator, &output, input, .{ .max_output_len = 0 }));
    try std.testing.expectEqualStrings("prefix", output.items);
    try std.testing.expectEqual(encoded.bytes.len, try encoder.encodeAppend(allocator, &output, input, .{}));
    try std.testing.expectEqualSlices(u8, encoded.bytes, output.items[6..]);
}

test "Quantum frame errors preserve adapted models progress and permit retry" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, frameFailure, .{});
}

fn frameFailure(allocator: std.mem.Allocator) !void {
    const input = "Quantum reusable frame state\n" ** 2300;
    const stable = std.testing.allocator;
    var state = try encoder.Encoder.init(.{ .window_bits = 10 });
    const warm = try state.encodeFrameAlloc(stable, input, 0, tables.frame_size);
    defer stable.free(warm);
    const before = state;
    const bytes = state.encodeFrameAlloc(allocator, input, tables.frame_size, 2 * tables.frame_size) catch |err| {
        try std.testing.expectEqualDeep(before, state);
        const retry = try state.encodeFrameAlloc(stable, input, tables.frame_size, 2 * tables.frame_size);
        defer stable.free(retry);
        try checkFrames(stable, input[0 .. 2 * tables.frame_size], warm, retry);
        return err;
    };
    defer allocator.free(bytes);
    try checkFrames(stable, input[0 .. 2 * tables.frame_size], warm, bytes);
}

fn checkFrames(allocator: std.mem.Allocator, expected: []const u8, warm: []const u8, next: []const u8) !void {
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, warm);
    try joined.append(allocator, 0xff);
    try joined.appendSlice(allocator, next);
    try joined.append(allocator, 0xff);
    const decoded = try decoder.decodeAlloc(allocator, joined.items, expected.len, 10);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "Quantum frame rejects skipped input partial continuation and invalid options" {
    const allocator = std.testing.allocator;
    var state = try encoder.Encoder.init(.{});
    try std.testing.expectError(error.InvalidBlockPlan, state.encodeFrameAlloc(allocator, "abcdef", 1, 6));
    const bytes = try state.encodeFrameAlloc(allocator, "abcdef", 0, 3);
    defer allocator.free(bytes);
    const before = state;
    try std.testing.expectError(error.InvalidBlockPlan, state.encodeFrameAlloc(allocator, "abcdef", 3, 6));
    try std.testing.expectEqualDeep(before, state);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.Encoder.init(.{ .window_bits = 9 }));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.Encoder.init(.{ .hash_log = 7 }));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.Encoder.init(.{ .max_match_distance = 0 }));
}

test "Quantum summary overflow preserves accumulated counts" {
    var summary = encoder.Summary{ .literals = std.math.maxInt(usize), .matched_bytes = 30, .max_offset = 10 };
    const before = summary;
    try std.testing.expectError(error.IntegerOverflow, summary.add(.{ .literals = 1, .matched_bytes = 3, .max_offset = 100 }));
    try std.testing.expectEqualDeep(before, summary);
}

test "Quantum allocating multiframe stream cleans up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, streamFailure, .{});
}

fn streamFailure(allocator: std.mem.Allocator) !void {
    const input = "Quantum allocated stream ownership\n" ** 1100;
    const bytes = try encoder.encodeAlloc(allocator, input, .{});
    defer allocator.free(bytes);
}

test "Quantum bounded caller history frames preserve full-prefix wire and models" {
    const allocator = std.testing.allocator;
    const input = "Quantum bounded caller history across frames\n" ** 1700;
    inline for (.{ 10, 18 }) |bits| {
        var complete = try encoder.Encoder.init(.{ .window_bits = bits });
        var bounded = try encoder.Encoder.init(.{ .window_bits = bits });
        var start: usize = 0;
        while (start < input.len) {
            const end = start + @min(input.len - start, tables.frame_size);
            const expected = try complete.encodeFrameAlloc(allocator, input, start, end);
            defer allocator.free(expected);
            const history_start = start - @min(start, @as(usize, 1) << bits);
            var frame = try bounded.encodeFrameWithHistoryAndSummaryAlloc(allocator, input[history_start..start], input[start..end]);
            defer frame.deinit(allocator);
            try std.testing.expectEqualSlices(u8, expected, frame.bytes);
            try std.testing.expectEqualDeep(complete.models, bounded.models);
            try std.testing.expectEqual(complete.input_read, bounded.input_read);
            start = end;
        }
    }
}

test "Quantum caller history allocation failures preserve adapted state" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, historyFailure, .{});
}

fn historyFailure(allocator: std.mem.Allocator) !void {
    const input = "Quantum small history state and allocation recovery\n" ** 1400;
    const stable = std.testing.allocator;
    var state = try encoder.Encoder.init(.{ .window_bits = 10 });
    const warm = try state.encodeFrameWithHistoryAlloc(stable, "", input[0..tables.frame_size]);
    defer stable.free(warm);
    const before = state;
    const history = input[tables.frame_size - 1024 .. tables.frame_size];
    const frame_input = input[tables.frame_size .. 2 * tables.frame_size];
    const encoded = state.encodeFrameWithHistoryAlloc(allocator, history, frame_input) catch |err| {
        try std.testing.expectEqualDeep(before, state);
        const retry = try state.encodeFrameWithHistoryAlloc(stable, history, frame_input);
        defer stable.free(retry);
        try checkFrames(stable, input[0 .. 2 * tables.frame_size], warm, retry);
        return err;
    };
    defer allocator.free(encoded);
    try checkFrames(stable, input[0 .. 2 * tables.frame_size], warm, encoded);
}
