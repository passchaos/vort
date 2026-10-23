const std = @import("std");
const encoder = @import("encoder.zig");
const decoder = @import("decoder.zig");

fn expectRoundTrip(input: []const u8, options: encoder.Options) !encoder.Summary {
    const allocator = std.testing.allocator;
    var encoded = try encoder.encodeWithSummaryAlloc(allocator, input, options);
    defer encoded.deinit(allocator);
    const reference = try encoder.encodeLiteralAlloc(allocator, input);
    defer allocator.free(reference);
    try std.testing.expect(encoded.bytes.len <= reference.len);
    const output = try decoder.decodeAllocExactSize(allocator, encoded.bytes, input.len);
    defer allocator.free(output);
    try std.testing.expectEqualSlices(u8, input, output);
    return encoded.summary;
}

test "LZMS greedy public APIs use LZ matches and improve literal reference output" {
    const allocator = std.testing.allocator;
    const input = "LZMS repeated source payload 0123456789\n" ** 1000;
    var result = try encoder.encodeWithSummaryAlloc(allocator, input, .{ .enable_delta = false });
    defer result.deinit(allocator);
    const reference = try encoder.encodeLiteralAlloc(allocator, input);
    defer allocator.free(reference);
    try std.testing.expect(!result.used_literal_reference);
    try std.testing.expect(result.summary.lz_matches != 0);
    try std.testing.expect(result.summary.matched_bytes > input.len / 2);
    try std.testing.expect(result.bytes.len * 10 < reference.len);
    _ = try expectRoundTrip(input, .{ .enable_delta = false });
    _ = try expectRoundTrip(input, .{});
    const ordinary = try encoder.encodeAlloc(allocator, input);
    defer allocator.free(ordinary);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    try std.testing.expectEqual(ordinary.len, try encoder.encodeAppend(allocator, &appended, input));
    try std.testing.expectEqualSlices(u8, ordinary, appended.items[6..]);
    const into = try allocator.alloc(u8, ordinary.len);
    defer allocator.free(into);
    try std.testing.expectEqual(ordinary.len, try encoder.encodeInto(allocator, input, into));
    try std.testing.expectEqualSlices(u8, ordinary, into);
}

test "LZMS greedy delta matching compresses arithmetic data through the public encoder" {
    var input: [16384]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index *% 4 + 7);
    const summary = try expectRoundTrip(&input, .{});
    try std.testing.expect(summary.delta_matches != 0);
    try std.testing.expect(summary.delta_repeats != 0);
    try std.testing.expect(summary.delta_power_mask != 0);
    try std.testing.expect(summary.matched_bytes > input.len / 2);
}

test "LZMS literal strategy preserves reference bytes and greedy never expands real input families" {
    const allocator = std.testing.allocator;
    var random: [8192]u8 = undefined;
    var generator = std.Random.DefaultPrng.init(0x4c5a_4d53_4d41_5443);
    generator.random().bytes(&random);
    for ([_][]const u8{ &.{}, "a", "aa", "aaa", &random, "structured JSON source\n" ** 200, @embedFile("decoder.zig") }) |input| {
        _ = try expectRoundTrip(input, .{});
        const reference = try encoder.encodeLiteralAlloc(allocator, input);
        defer allocator.free(reference);
        const actual = try encoder.encodeWithOptionsAlloc(allocator, input, .{ .strategy = .literals });
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, reference, actual);
    }
}

test "LZMS greedy matching honors its history cap and fixed hash-table choice" {
    const allocator = std.testing.allocator;
    var input: [12288]u8 = undefined;
    var generator = std.Random.DefaultPrng.init(0x4849_5354_4f52_5900);
    generator.random().bytes(input[0..6144]);
    @memcpy(input[6144..], input[0..6144]);
    var wide = try encoder.encodeWithSummaryAlloc(allocator, &input, .{ .hash_log = 12, .max_match_distance = 8192, .enable_delta = false });
    defer wide.deinit(allocator);
    var narrow = try encoder.encodeWithSummaryAlloc(allocator, &input, .{ .hash_log = 12, .max_match_distance = 128, .enable_delta = false });
    defer narrow.deinit(allocator);
    try std.testing.expect(wide.bytes.len < narrow.bytes.len);
    try std.testing.expect(wide.summary.max_lz_offset <= 8192);
    try std.testing.expect(narrow.summary.max_lz_offset <= 128);
    for ([_]u8{ 8, 12, 16 }) |hash_log| _ = try expectRoundTrip(&input, .{ .hash_log = hash_log, .max_delta_power = 3 });
}

test "LZMS greedy limits errors preserve caller output and distinguish memory denial" {
    const allocator = std.testing.allocator;
    const input = "LZMS limits input\n" ** 100;
    try std.testing.expectError(error.InvalidLzms, encoder.encodeWithOptionsAlloc(allocator, input, .{ .hash_log = 7 }));
    try std.testing.expectError(error.InvalidLzms, encoder.encodeWithOptionsAlloc(allocator, input, .{ .hash_log = 21 }));
    try std.testing.expectError(error.InvalidLzms, encoder.encodeWithOptionsAlloc(allocator, input, .{ .max_match_distance = 0 }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeWithOptionsAlloc(allocator, input, .{ .max_working_memory = 1 }));
    try std.testing.expectError(error.OutputLimitExceeded, encoder.encodeWithOptionsAlloc(allocator, input, .{ .max_output_len = 1 }));
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeWithOptionsInto(allocator, input, &output, .{}));
    try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
    var append: std.ArrayList(u8) = .empty;
    defer append.deinit(allocator);
    try append.appendSlice(allocator, "keep");
    try std.testing.expectError(error.OutputLimitExceeded, encoder.encodeWithOptionsAppend(allocator, &append, input, .{ .max_output_len = 1 }));
    try std.testing.expectEqualStrings("keep", append.items);
}

test "LZMS greedy arbitration and matching release every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, delta: bool) !void {
            const input = "greedy allocation input\n" ** 40;
            const encoded = try encoder.encodeWithOptionsAlloc(allocator, input, .{ .hash_log = 8, .enable_delta = delta });
            defer allocator.free(encoded);
            const decoded = try decoder.decodeAllocExactSize(allocator, encoded, input.len);
            defer allocator.free(decoded);
            try std.testing.expectEqualStrings(input, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{false});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{true});
}
