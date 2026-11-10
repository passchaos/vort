//! Policy admission at real completed gzip member boundaries.
const std = @import("std");
const first = "first member retains nonempty history and CRC across policy rejection";

fn feed(encoder: anytype, allocator: std.mem.Allocator, wire: *std.ArrayList(u8), input: []const u8) !void {
    var scratch: [7]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], &scratch);
        offset += result.progress.input_read;
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
    }
}
fn finish(encoder: anytype, allocator: std.mem.Allocator, wire: *std.ArrayList(u8)) !void {
    encoder.finish();
    var scratch: [7]u8 = undefined;
    while (true) {
        const result = try encoder.step("", &scratch);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
    }
}
fn byteHashes(encoder: anytype) [5]u64 {
    return .{
        std.hash.Wyhash.hash(0, encoder.raw.history.items),
        std.hash.Wyhash.hash(0, encoder.raw.plain.items),
        std.hash.Wyhash.hash(0, encoder.raw.pending.items),
        std.hash.Wyhash.hash(0, encoder.raw.state.bytes.items),
        std.hash.Wyhash.hash(0, encoder.pending.items),
    };
}
fn unchanged(before: anytype, encoder: anytype, hashes: [5]u64) !void {
    try std.testing.expectEqualDeep(before.snapshot(), encoder.snapshot());
    try std.testing.expectEqualDeep(before.raw.snapshot(), encoder.raw.snapshot());
    try std.testing.expectEqualDeep(before.options, encoder.options);
    try std.testing.expectEqualDeep(before.raw.options, encoder.raw.options);
    try std.testing.expectEqual(before.raw.expected_input_len, encoder.raw.expected_input_len);
    try std.testing.expectEqualDeep(before.crc, encoder.crc);
    try std.testing.expectEqual(before.raw.state.scratch, encoder.raw.state.scratch);
    try std.testing.expectEqual(before.raw.state.bit_index, encoder.raw.state.bit_index);
    try std.testing.expectEqualDeep(before.raw.matchFinderSnapshot(), encoder.raw.matchFinderSnapshot());
    try std.testing.expectEqual(before.raw.dictionary_available, encoder.raw.dictionary_available);
    try std.testing.expectEqual(before.allocator.ptr, encoder.allocator.ptr);
    try std.testing.expectEqual(before.allocator.vtable, encoder.allocator.vtable);
    try std.testing.expectEqual(before.raw.allocator.ptr, encoder.raw.allocator.ptr);
    try std.testing.expectEqual(before.raw.allocator.vtable, encoder.raw.allocator.vtable);
    try std.testing.expectEqualDeep(hashes, byteHashes(encoder));
    inline for (.{ "plain", "history", "pending", "plan_tokens" }) |field| {
        const old = @field(before.raw, field);
        const now = @field(encoder.raw, field);
        try std.testing.expectEqual(old.items.len, now.items.len);
        try std.testing.expectEqual(old.capacity, now.capacity);
        try std.testing.expectEqual(old.items.ptr, now.items.ptr);
    }
    try std.testing.expectEqual(before.pending.capacity, encoder.pending.capacity);
    try std.testing.expectEqual(before.pending.items.ptr, encoder.pending.items.ptr);
    try std.testing.expectEqual(before.raw.state.bytes.capacity, encoder.raw.state.bytes.capacity);
    try std.testing.expectEqual(before.raw.state.bytes.items.ptr, encoder.raw.state.bytes.items.ptr);
}
fn next(encoder: anytype, options: @TypeOf(encoder.options), comptime exact: bool, pledge: @TypeOf(encoder.total_input)) !void {
    if (exact) try encoder.nextMemberExactSizeWithOptions(options, pledge) else try encoder.nextMemberWithOptions(options);
}
fn rejected(encoder: anytype, options: @TypeOf(encoder.options), comptime exact: bool, expected_error: anyerror) !void {
    const before = encoder.*;
    const hashes = byteHashes(encoder);
    try std.testing.expectError(expected_error, next(encoder, options, exact, first.len + 11));
    try unchanged(before, encoder, hashes);
}

/// Also used by the bounded external libz probe; no expected wire is generated
/// from an option resolver. Verify public rejection, then emit two valid members.
pub fn referenceWire(comptime D: type, allocator: std.mem.Allocator, comptime best: bool, comptime exact: bool) ![]u8 {
    const Encoder = if (best) D.GzipIncrementalBestEncoder else D.GzipIncrementalFixedEncoder;
    var encoder = Encoder.initExactSize(allocator, .{
        .raw = .{ .block_len = 17 },
        .header = .{ .filename = "original.gz", .comment = "original member", .extra = "old-extra", .header_crc = true },
    }, first.len);
    defer encoder.deinit();
    if (best) try encoder.requestParams(.{ .level = 6 });
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    try feed(&encoder, allocator, &wire, first);
    try finish(&encoder, allocator, &wire);
    try std.testing.expect(encoder.done and encoder.pending.items.len == encoder.pending_offset);
    try std.testing.expect(encoder.raw.history.items.len != 0 and encoder.crc.digest() != 0);
    const prefix_len = wire.items.len;
    const saved_prefix = try allocator.dupe(u8, wire.items);
    defer allocator.free(saved_prefix);
    const original: Encoder.Options = .{
        .raw = .{ .block_len = 23 },
        .header = .{ .filename = "rejected.gz", .comment = "rejected member", .extra = "rejected-extra", .header_crc = true },
    };
    inline for (.{ @as(usize, 0), @as(usize, 1), @as(usize, 1024), std.math.maxInt(usize) }) |cap| {
        var invalid = original;
        invalid.raw.compression.max_total_working_memory = cap;
        try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    }
    var profile: D.EncodeMemoryProfile = .{};
    var invalid = original;
    invalid.raw.compression.memory_profile = &profile;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    try std.testing.expect(!profile.available);
    invalid.raw.compression.max_total_working_memory = 0;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    try std.testing.expect(!profile.available);

    invalid = original;
    invalid.raw.block_len = 0;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    invalid = original;
    invalid.raw.lookahead_len = invalid.raw.block_len;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    invalid = original;
    invalid.raw.low_entropy_block_len = invalid.raw.block_len - 1;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    invalid = original;
    invalid.raw.adaptive_blocks = true;
    invalid.raw.compression.split_options = .{ .min_block_len = 2, .max_block_len = 1 };
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    invalid = original;
    invalid.raw.block_len = std.math.maxInt(usize);
    invalid.raw.lookahead_len = 1;
    try rejected(&encoder, invalid, exact, error.IntegerOverflow);
    try std.testing.expectEqual(prefix_len, wire.items.len);
    try std.testing.expectEqualSlices(u8, saved_prefix, wire.items);

    // Completion count admission precedes unsupported policy validation.
    const member_count = encoder.member_count;
    encoder.member_count = std.math.maxInt(@TypeOf(encoder.member_count));
    invalid = original;
    invalid.raw.compression.max_total_working_memory = 0;
    try rejected(&encoder, invalid, exact, error.IntegerOverflow);
    encoder.member_count = member_count;

    const second = if (exact) first ++ " exact tail" else first;
    var valid = original;
    valid.raw.compression = D.optionsForLevel(.fast);
    valid.header.filename = "accepted.gz";
    valid.header.comment = "accepted member";
    valid.header.extra = "accepted-extra";
    try next(&encoder, valid, exact, second.len);
    try std.testing.expectEqual(@as(@TypeOf(encoder.raw.expected_input_len), second.len), encoder.raw.expected_input_len);
    try std.testing.expectEqual(prefix_len, wire.items.len);
    try std.testing.expectEqualSlices(u8, saved_prefix, wire.items);
    try feed(&encoder, allocator, &wire, second);
    try finish(&encoder, allocator, &wire);
    try std.testing.expectEqual(@as(@TypeOf(encoder.member_count), 2), encoder.member_count);
    return wire.toOwnedSlice(allocator);
}

fn priorities(comptime D: type, comptime best: bool, comptime exact: bool) !void {
    const Encoder = if (best) D.GzipIncrementalBestEncoder else D.GzipIncrementalFixedEncoder;
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    // A real step queues a header under caller backpressure; the member is not
    // complete/drained. Even a raw capacity overflow must retain InvalidBlockPlan.
    const progress = try encoder.step(first, &.{});
    try std.testing.expectEqual(@as(usize, 0), progress.progress.input_read);
    try std.testing.expect(encoder.pending.items.len != 0 and !encoder.done);
    var invalid: Encoder.Options = .{ .raw = .{ .block_len = std.math.maxInt(usize), .lookahead_len = 1 } };
    encoder.member_count = std.math.maxInt(@TypeOf(encoder.member_count));
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    invalid.raw.compression.max_total_working_memory = 0;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
    // Focus the drain guard separately after queuing real header bytes.
    encoder.done = true;
    try rejected(&encoder, invalid, exact, error.InvalidBlockPlan);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ false, true }) |best| {
        inline for (.{ false, true }) |exact| {
            const wire = try referenceWire(D, std.testing.allocator, best, exact);
            defer std.testing.allocator.free(wire);
            const plain = try D.decodeGzipConcatenatedAlloc(std.testing.allocator, wire);
            defer std.testing.allocator.free(plain);
            const expected = if (exact) first ++ first ++ " exact tail" else first ++ first;
            try std.testing.expectEqualStrings(expected, plain);
            try priorities(D, best, exact);
        }
    }
}
