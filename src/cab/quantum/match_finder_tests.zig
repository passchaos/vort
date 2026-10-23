const std = @import("std");
const matcher = @import("match_finder.zig");
const item_stream = @import("item_stream.zig");
const item_encoder = @import("item_encoder.zig");
const literal_encoder = @import("literal_encoder.zig");
const decoder = @import("decoder.zig");
const encode_options = @import("encode_options.zig");
const model = @import("model.zig");
const tables = @import("tables.zig");

const allocator = std.testing.allocator;

fn expectPlan(input: []const u8, start: usize, end: usize, options: encode_options.Options, plan: matcher.Plan) !item_stream.Summary {
    var position = start;
    for (plan.items.items) |item| {
        switch (item) {
            .literal => |byte| {
                try std.testing.expect(position < end);
                try std.testing.expectEqual(input[position], byte);
                position += 1;
            },
            .match => |match| {
                try std.testing.expect(match.length >= 3 and match.length <= 259);
                try std.testing.expect(match.offset > 0 and match.offset <= options.historyLimit());
                try std.testing.expect(match.offset <= position);
                try std.testing.expect(match.length <= end - position);
                _ = try tables.positionSlot(match.offset, item_stream.positionEntries(options.window_bits, match.length));
                for (0..match.length) |index|
                    try std.testing.expectEqual(input[position + index], input[position - match.offset + index]);
                position += match.length;
            },
        }
    }
    try std.testing.expectEqual(end, position);
    return (try item_stream.validate(plan.items.items, start, options.window_bits)).summary;
}

test "Quantum greedy matcher reduces actual frame bytes and keeps input immutable" {
    var input: [8192]u8 = undefined;
    const pattern = "Quantum compression keeps library state explicit; 0123456789.\n";
    for (&input, 0..) |*byte, position| byte.* = pattern[position % pattern.len];
    const original = input;
    const options = encode_options.Options{ .window_bits = 10 };
    var plan = try matcher.planAlloc(allocator, &input, 0, input.len, options);
    defer plan.deinit(allocator);
    const summary = try expectPlan(&input, 0, input.len, options, plan);
    try std.testing.expect(summary.matched_bytes > input.len * 9 / 10);
    try std.testing.expect(summary.variable_matches > 0);
    try std.testing.expectEqualSlices(u8, &original, &input);

    const encoded = try item_encoder.encode(allocator, plan.items.items, 0, options.window_bits, model.initialState(options.window_bits));
    defer allocator.free(encoded.bytes);
    var reference = literal_encoder.LiteralEncoder.init();
    const literal_bytes = try reference.encodeFrameAlloc(allocator, &input);
    defer allocator.free(literal_bytes);
    try std.testing.expect(encoded.bytes.len * 4 < literal_bytes.len);
    const decoded = try decoder.decodeAlloc(allocator, encoded.bytes, input.len, options.window_bits);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);

    var repeated = try matcher.planAlloc(allocator, &input, 0, input.len, options);
    defer repeated.deinit(allocator);
    try std.testing.expectEqualDeep(plan.items.items, repeated.items.items);
}

test "Quantum greedy matcher rolls a one KiB window across a full frame" {
    const input = try allocator.alloc(u8, tables.frame_size);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x1dc5_d601_9384_c78b);
    random.random().bytes(input[0..512]);
    for (input[512..], 512..) |*byte, index| byte.* = input[index % 512];
    const options = encode_options.Options{ .window_bits = 10, .hash_log = 12 };
    var plan = try matcher.planAlloc(allocator, input, 0, input.len, options);
    defer plan.deinit(allocator);
    const summary = try expectPlan(input, 0, input.len, options, plan);
    try std.testing.expect(summary.matched_bytes > 30 * 1024);
    try std.testing.expect(summary.max_offset <= 1024);
    var encoder = try item_encoder.Encoder.init(options.window_bits);
    const encoded = try encoder.encodeFrameAlloc(allocator, plan.items.items);
    defer allocator.free(encoded.bytes);
    const wire = try allocator.alloc(u8, encoded.bytes.len + 1);
    defer allocator.free(wire);
    @memcpy(wire[0..encoded.bytes.len], encoded.bytes);
    wire[encoded.bytes.len] = 0xff;
    const decoded = try decoder.decodeAlloc(allocator, wire, input.len, options.window_bits);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Quantum greedy matcher refreshes expired anchors while retaining a better older candidate" {
    var input: [1296]u8 = @splat(0);
    var pattern: [96]u8 = undefined;
    for (&pattern, 0..) |*byte, index| byte.* = @intCast(index + 65);
    @memcpy(input[0..3], pattern[0..3]);
    @memcpy(input[900..996], &pattern);
    @memcpy(input[1100..1103], pattern[0..3]);
    @memcpy(input[1200..], &pattern);
    const options = encode_options.Options{ .window_bits = 10, .hash_log = 15 };
    var plan = try matcher.planAlloc(allocator, &input, 0, input.len, options);
    defer plan.deinit(allocator);
    _ = try expectPlan(&input, 0, input.len, options, plan);
    var position: usize = 0;
    var retained_long_match = false;
    for (plan.items.items) |item| {
        switch (item) {
            .literal => position += 1,
            .match => |match| {
                if (position == 1200) {
                    // Position zero expired, and the latest three-byte copy
                    // at 1100 loses to the renewed anchor at 900.
                    try std.testing.expectEqual(@as(u16, 96), match.length);
                    try std.testing.expectEqual(@as(u32, 300), match.offset);
                    retained_long_match = true;
                }
                position += match.length;
            },
        }
    }
    try std.testing.expect(retained_long_match);
}

test "Quantum greedy matcher reconstructs mixed and random frames across all windows" {
    const input = try allocator.alloc(u8, tables.frame_size);
    defer allocator.free(input);
    for (10..22) |bits| {
        var random = std.Random.DefaultPrng.init(0x1fba_b391_9b53_2f61 + bits);
        random.random().bytes(input);
        const options = encode_options.Options{ .window_bits = @intCast(bits), .hash_log = if (bits == 21) 20 else 8 };
        for ([_]bool{ false, true }) |mixed| {
            if (mixed) {
                for (1024..input.len) |position| {
                    if (position % 193 < 97) input[position] = input[position - 1024];
                }
            }
            var plan = try matcher.planAlloc(allocator, input, 0, input.len, options);
            defer plan.deinit(allocator);
            _ = try expectPlan(input, 0, input.len, options, plan);
        }
    }
}

test "Quantum greedy matcher borrows long history and respects explicit distance limits" {
    const start = 4 * tables.frame_size;
    const input = try allocator.alloc(u8, start + 259);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..259], 0..) |*byte, index| byte.* = @intCast(index % 251 + 1);
    @memcpy(input[start..], input[0..259]);
    const options = encode_options.Options{ .window_bits = 18, .hash_log = 15 };
    var distant = try matcher.planAlloc(allocator, input, start, input.len, options);
    defer distant.deinit(allocator);
    const summary = try expectPlan(input, start, input.len, options, distant);
    try std.testing.expectEqual(@as(usize, 259), summary.matched_bytes);
    try std.testing.expectEqual(start, summary.max_offset);

    var limited_options = options;
    limited_options.max_match_distance = 1024;
    var limited = try matcher.planAlloc(allocator, input, start, input.len, limited_options);
    defer limited.deinit(allocator);
    const limited_summary = try expectPlan(input, start, input.len, limited_options, limited);
    try std.testing.expect(limited_summary.matched_bytes < summary.matched_bytes);
    try std.testing.expect(limited_summary.max_offset <= 1024);
}

test "Quantum greedy matcher enforces fixed short selector distance boundaries" {
    for ([_]struct { length: usize, offset: usize, allowed: bool }{
        .{ .length = 3, .offset = 4096, .allowed = true },
        .{ .length = 3, .offset = 4097, .allowed = false },
        .{ .length = 4, .offset = 262144, .allowed = true },
        .{ .length = 4, .offset = 262145, .allowed = false },
        .{ .length = 5, .offset = 262145, .allowed = true },
    }) |case| {
        // A frame-aligned start allows independent item validation even for
        // offsets immediately beyond a fixed selector's largest slot.
        const start = std.mem.alignForward(usize, case.offset, tables.frame_size);
        const input = try allocator.alloc(u8, start + case.length);
        defer allocator.free(input);
        @memset(input, 0);
        const pattern = "\xa1\xb2\xc3\xd4\xe5";
        @memcpy(input[start - case.offset ..][0..case.length], pattern[0..case.length]);
        @memcpy(input[start..], pattern[0..case.length]);
        const options = encode_options.Options{ .window_bits = 21 };
        var plan = try matcher.planAlloc(allocator, input, start, input.len, options);
        defer plan.deinit(allocator);
        const summary = try expectPlan(input, start, input.len, options, plan);
        try std.testing.expectEqual(if (case.allowed) case.length else 0, summary.matched_bytes);
        if (case.allowed) try std.testing.expectEqual(case.offset, summary.max_offset);
    }
}

test "Quantum greedy matcher allows overlap and maximum match length" {
    const input: [260]u8 = @splat('q');
    const options = encode_options.Options{ .window_bits = 10, .max_match_distance = 1 };
    var plan = try matcher.planAlloc(allocator, &input, 0, input.len, options);
    defer plan.deinit(allocator);
    const summary = try expectPlan(&input, 0, input.len, options, plan);
    try std.testing.expectEqual(@as(usize, 1), summary.literals);
    try std.testing.expectEqual(@as(usize, 259), summary.matched_bytes);
    try std.testing.expectEqual(@as(usize, 1), summary.max_offset);
}

test "Quantum matcher validates frame ranges and options before allocating" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const fail_allocator = failing.allocator();
    const input: [tables.frame_size + 1]u8 = @splat(0);
    try std.testing.expectError(error.InvalidBlockPlan, matcher.planAlloc(fail_allocator, &input, 0, 0, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, matcher.planAlloc(fail_allocator, &input, 2, 1, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, matcher.planAlloc(fail_allocator, &input, 0, input.len + 1, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, matcher.planAlloc(fail_allocator, &input, 0, input.len, .{}));
    for ([_]encode_options.Options{
        .{ .window_bits = 9 }, .{ .window_bits = 22 },       .{ .hash_log = 7 },
        .{ .hash_log = 21 },   .{ .max_match_distance = 0 },
    }) |options| try std.testing.expectError(error.InvalidBlockPlan, matcher.planAlloc(fail_allocator, &input, 0, 1, options));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Quantum matcher literals strategy and tiny frames contain only expected literals" {
    const input = "ab";
    for ([_]encode_options.Strategy{ .greedy, .literals }) |strategy| {
        for (1..3) |length| {
            const options = encode_options.Options{ .strategy = strategy };
            var plan = try matcher.planAlloc(allocator, input, 0, length, options);
            defer plan.deinit(allocator);
            const summary = try expectPlan(input, 0, length, options, plan);
            try std.testing.expectEqual(length, summary.literals);
        }
    }
    const options = encode_options.Options{ .strategy = .literals };
    var plan = try matcher.planAlloc(allocator, "aaaaaaaa", 0, 8, options);
    defer plan.deinit(allocator);
    const summary = try expectPlan("aaaaaaaa", 0, 8, options, plan);
    try std.testing.expectEqual(@as(usize, 8), summary.literals);
}

fn allocationFailure(test_allocator: std.mem.Allocator, strategy: encode_options.Strategy) !void {
    var input: [8192]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xbeac_617e_42a0_764f);
    random.random().bytes(&input);
    const options = encode_options.Options{ .strategy = strategy, .hash_log = 8 };
    var plan = try matcher.planAlloc(test_allocator, &input, 0, input.len, options);
    defer plan.deinit(test_allocator);
    _ = try expectPlan(&input, 0, input.len, options, plan);
}

test "Quantum matcher cleans up every table and item allocation failure" {
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{encode_options.Strategy.greedy});
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{encode_options.Strategy.literals});
}
