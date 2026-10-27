//! Compare a warm command/distance descriptor with independent full writers.
const std = @import("std");
const lz77 = @import("../../lz77.zig");
const command_plan = @import("command_plan.zig");
const context = @import("literal_context_split.zig");
const prepared = @import("prepared_command_distance.zig");

pub fn run(comptime Options: type, comptime Stats: type, comptime encode: anytype, comptime encode_into: anytype) !void {
    const allocator = std.testing.allocator;
    const text = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++ ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    var mixed: [8192]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    var position: usize = 0;
    var record: usize = 0;
    const repeated = " repeated common value: the quick brown fox jumps over the lazy dog";
    while (position < mixed.len) : (record += 1) {
        for (0..4 + record % 19) |_| {
            if (position == mixed.len) break;
            state = state *% 1664525 +% 1013904223;
            mixed[position] = @truncate(state >> 24);
            position += 1;
        }
        for (0..4 + (record * 7) % 60) |index| {
            if (position == mixed.len) break;
            mixed[position] = repeated[index];
            position += 1;
        }
    }
    for ([_][]const u8{ text, &mixed }) |input| {
        const tokens = try lz77.hashGreedyPlanAlloc(allocator, input, .{ .min_match = 4, .max_chain = 64, .max_candidates = 4 });
        defer tokens.deinit(allocator);
        const plan = try command_plan.buildAlloc(allocator, input, tokens.tokens);
        defer plan.deinit(allocator);
        var options: Options = .{ .use_recent_distances = true, .literal_context_candidate = context.Candidate.suffix(2, 56, 0) };
        var common = prepared.Prepared.init(options, plan.commands);
        options.prepared_common = &common;
        var first_stats: Stats = .{};
        const first = try encode(allocator, input, plan.commands, null, &first_stats, options);
        defer allocator.free(first);
        try std.testing.expect(common.ready);
        if (input.len == mixed.len) {
            try std.testing.expect(plan.commands.len > 128);
            try std.testing.expect(common.command_alphabet.len > 4);
        }
        for (0..8) |mode| {
            options.literal_context_candidate = if (mode < 4) context.Candidate.suffix(@intCast(mode), @intCast(16 + mode * 12), 0) else null;
            options.use_utf8_text_contexts = mode == 5 or mode == 7;
            options.optimize_literal_tree_wire = mode == 6 or mode == 7;
            var plain_options = options;
            plain_options.prepared_common = null;
            var plain_heap = std.testing.FailingAllocator.init(allocator, .{});
            var cached_heap = std.testing.FailingAllocator.init(allocator, .{});
            var plain_stats: Stats = .{};
            var cached_stats: Stats = .{};
            const expected = try encode(plain_heap.allocator(), input, plan.commands, null, &plain_stats, plain_options);
            const actual = try encode(cached_heap.allocator(), input, plan.commands, null, &cached_stats, options);
            const encoded_len = actual.len;
            try std.testing.expectEqualSlices(u8, expected, actual);
            try std.testing.expectEqualDeep(plain_stats, cached_stats);
            try std.testing.expectEqual(plain_heap.allocated_bytes, cached_heap.allocated_bytes);
            plain_heap.allocator().free(expected);
            cached_heap.allocator().free(actual);
            try std.testing.expectEqual(plain_heap.allocated_bytes, plain_heap.freed_bytes);
            try std.testing.expectEqual(cached_heap.allocated_bytes, cached_heap.freed_bytes);

            const output_a = try allocator.alloc(u8, encoded_len - 1);
            defer allocator.free(output_a);
            const output_b = try allocator.alloc(u8, encoded_len - 1);
            defer allocator.free(output_b);
            @memset(output_a, 0xa5);
            @memset(output_b, 0xa5);
            plain_stats = .{};
            cached_stats = .{};
            try std.testing.expectError(error.OutOfMemory, encode_into(allocator, output_a, input, plan.commands, &plain_stats, plain_options));
            try std.testing.expectError(error.OutOfMemory, encode_into(allocator, output_b, input, plan.commands, &cached_stats, options));
            try std.testing.expectEqualSlices(u8, output_a, output_b);
            try std.testing.expectEqualDeep(plain_stats, cached_stats);
            for (0..12) |fail_index| {
                var expected_heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
                var observed_heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
                var expected_stats: Stats = .{};
                var observed_stats: Stats = .{};
                var expected_error: ?anyerror = null;
                var observed_error: ?anyerror = null;
                const expected_wire = encode(expected_heap.allocator(), input, plan.commands, null, &expected_stats, plain_options) catch |err| blk: {
                    expected_error = err;
                    break :blk null;
                };
                const observed_wire = encode(observed_heap.allocator(), input, plan.commands, null, &observed_stats, options) catch |err| blk: {
                    observed_error = err;
                    break :blk null;
                };
                try std.testing.expectEqual(expected_error, observed_error);
                if (expected_wire) |wire| {
                    try std.testing.expectEqualSlices(u8, wire, observed_wire.?);
                    expected_heap.allocator().free(wire);
                    observed_heap.allocator().free(observed_wire.?);
                }
                try std.testing.expectEqualDeep(expected_stats, observed_stats);
                try std.testing.expectEqual(expected_heap.alloc_index, observed_heap.alloc_index);
                try std.testing.expectEqual(expected_heap.resize_index, observed_heap.resize_index);
                try std.testing.expectEqual(expected_heap.allocated_bytes, observed_heap.allocated_bytes);
                try std.testing.expectEqual(expected_heap.freed_bytes, observed_heap.freed_bytes);
                try std.testing.expectEqual(expected_heap.has_induced_failure, observed_heap.has_induced_failure);
                try std.testing.expectEqual(expected_heap.allocated_bytes, expected_heap.freed_bytes);
                try std.testing.expectEqual(observed_heap.allocated_bytes, observed_heap.freed_bytes);
            }
        }
        // An independent descriptor also covers the smaller ordinary 0/0
        // distance shape. A different prepared key must never be borrowed.
        var smaller: Options = .{ .use_recent_distances = true };
        smaller.distance_parameters = @import("distance.zig").Parameters.init(0, 0);
        var small_common = prepared.Prepared.init(smaller, plan.commands);
        smaller.prepared_common = &small_common;
        var small_stats: Stats = .{};
        const small_wire = try encode(allocator, input, plan.commands, null, &small_stats, smaller);
        defer allocator.free(small_wire);
        try std.testing.expect(small_common.ready);
        var wrong_key = smaller;
        wrong_key.prepared_common = &common;
        var wrong_stats: Stats = .{};
        const wrong_wire = try encode(allocator, input, plan.commands, null, &wrong_stats, wrong_key);
        defer allocator.free(wrong_wire);
        try std.testing.expectEqualSlices(u8, small_wire, wrong_wire);
        try std.testing.expectEqualDeep(small_stats, wrong_stats);
    }
}
