const std = @import("std");
const xz = @import("../../xz.zig");
const h = @import("test_helpers.zig");
const allocator = std.testing.allocator;

fn rejectAtomic(workspace: *xz.DecodeWorkspace, input: []const u8, output: []u8, mode: xz.DecodeWorkspace.Mode, expected: ?anyerror) !void {
    @memset(output, 0xa5);
    const result = if (mode == .single) workspace.decodeInto(input, output) else workspace.decodeConcatenatedInto(input, output);
    if (result) |_| return error.TestExpectedError else |err| {
        if (expected) |wanted| try std.testing.expectEqual(wanted, err);
    }
    try h.expectSentinel(output);
    try std.testing.expect(!workspace.snapshot().prepared);
}

test "XZ one-shot contracts independently generated checks and every supported filter decode into caller storage" {
    var workspace = xz.DecodeWorkspace.init(allocator);
    defer workspace.deinit();
    for (h.fixtures) |fixture| {
        const frame = try h.decodeHex(allocator, fixture.hex);
        defer allocator.free(frame);
        const plain = try h.patternAlloc(allocator, fixture.pattern, fixture.raw_len);
        defer allocator.free(plain);
        const output = try allocator.alloc(u8, plain.len + 17);
        defer allocator.free(output);
        @memset(output, 0xa5);
        try std.testing.expectEqual(plain.len, try workspace.decodeInto(frame, output));
        try std.testing.expectEqualSlices(u8, plain, output[0..plain.len]);
        try h.expectSentinel(output[plain.len..]);
        @memset(output, 0xa5);
        try std.testing.expectEqual(plain.len, try xz.decodeInto(allocator, frame, output));
        try std.testing.expectEqualSlices(u8, plain, output[0..plain.len]);
        try h.expectSentinel(output[plain.len..]);
        try std.testing.expectEqual(plain.len, try workspace.decodedSize(frame));
        const info = try workspace.inspect(frame);
        try std.testing.expectEqual(fixture.check, info.check);
        try std.testing.expectEqual(@as(usize, 1), info.block_count);
        try std.testing.expectEqual(plain.len, info.uncompressed_size);
        try std.testing.expectEqual(frame.len, info.compressed_size);
        try h.expectLedger(&workspace, null);
    }
}

test "XZ one-shot contracts variable block dictionaries probability shapes and three filter stages validate all metadata" {
    const frame = try h.decodeHex(allocator, h.variable_hex);
    defer allocator.free(frame);
    const plain = try h.variablePlainAlloc(allocator);
    defer allocator.free(plain);
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    var workspace = xz.DecodeWorkspace.init(allocator);
    defer workspace.deinit();
    try std.testing.expectEqual(plain.len, try workspace.decodeInto(frame, output));
    try std.testing.expectEqualSlices(u8, plain, output);
    const info = try workspace.inspect(frame);
    try std.testing.expectEqual(@as(usize, 6), info.block_count);
    try std.testing.expectEqual(@as(u64, 65536), info.max_dictionary_size);
    try std.testing.expectEqual(@as(usize, 4), info.delta_filter_blocks);
    try std.testing.expectEqual(@as(usize, 5), info.bcj_filter_blocks);
    try std.testing.expectEqual(@as(usize, 1), info.x86_filter_blocks);
    try std.testing.expectEqual(@as(usize, 1), info.ia64_filter_blocks);
    try std.testing.expectEqual(@as(usize, 1), info.arm_thumb_filter_blocks);
    try std.testing.expectEqual(@as(usize, 1), info.sparc_filter_blocks);
    try std.testing.expectEqual(xz.Check.sha256, info.check);
}

test "XZ one-shot contracts concatenation padding and trailing rules never publish an invalid stream prefix" {
    const first = try h.decodeHex(allocator, h.fixtures[2].hex);
    defer allocator.free(first);
    const second = try h.decodeHex(allocator, h.fixtures[6].hex);
    defer allocator.free(second);
    const a = try h.patternAlloc(allocator, h.fixtures[2].pattern, h.fixtures[2].raw_len);
    defer allocator.free(a);
    const b = try h.patternAlloc(allocator, h.fixtures[6].pattern, h.fixtures[6].raw_len);
    defer allocator.free(b);
    const stream = try std.mem.concat(allocator, u8, &.{ first, &.{ 0, 0, 0, 0 }, second, &.{ 0, 0, 0, 0, 0, 0, 0, 0 } });
    defer allocator.free(stream);
    const output = try allocator.alloc(u8, a.len + b.len);
    defer allocator.free(output);
    var workspace = xz.DecodeWorkspace.init(allocator);
    defer workspace.deinit();
    try rejectAtomic(&workspace, stream, output, .single, error.TrailingData);
    try std.testing.expectEqual(output.len, try workspace.decodeConcatenatedInto(stream, output));
    try std.testing.expectEqualSlices(u8, a, output[0..a.len]);
    try std.testing.expectEqualSlices(u8, b, output[a.len..]);
    try std.testing.expectEqual(@as(usize, 2), workspace.snapshot().stream_count);
    try std.testing.expectEqual(output.len, try workspace.decodedSizeConcatenated(stream));
    const bad_padding = try std.mem.concat(allocator, u8, &.{ first, &.{ 0, 0, 0 }, second });
    defer allocator.free(bad_padding);
    try rejectAtomic(&workspace, bad_padding, output, .concatenated, error.InvalidXzStream);
    const trailing = try std.mem.concat(allocator, u8, &.{ first, "unrecognized trailer" });
    defer allocator.free(trailing);
    try rejectAtomic(&workspace, trailing, output, .single, error.TrailingData);
    try rejectAtomic(&workspace, trailing, output, .concatenated, null);
    const corrupt = try allocator.dupe(u8, stream);
    defer allocator.free(corrupt);
    corrupt[first.len + 4 + second.len - 12] ^= 1;
    try rejectAtomic(&workspace, corrupt, output, .concatenated, error.ChecksumMismatch);
}

test "XZ one-shot contracts late block checks Index Footer and truncation keep the entire caller buffer unchanged" {
    const frame = try h.decodeHex(allocator, h.variable_hex);
    defer allocator.free(frame);
    const plain = try h.variablePlainAlloc(allocator);
    defer allocator.free(plain);
    const output = try allocator.alloc(u8, plain.len + 31);
    defer allocator.free(output);
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    var locations: [16]h.Location = undefined;
    const count = try h.locations(frame, &locations);
    try std.testing.expectEqual(@as(usize, 6), count);
    var workspace = xz.DecodeWorkspace.init(allocator);
    defer workspace.deinit();
    for ([_]usize{ locations[1].check, locations[count - 1].check, frame.len - 16, frame.len - 12 }) |at| {
        @memcpy(corrupt, frame);
        corrupt[at] ^= 1;
        try rejectAtomic(&workspace, corrupt, output, .single, error.ChecksumMismatch);
        try std.testing.expectError(error.ChecksumMismatch, workspace.decodedSize(corrupt));
    }
    @memcpy(corrupt, frame);
    corrupt[frame.len - 1] ^= 1;
    try rejectAtomic(&workspace, corrupt, output, .single, error.InvalidXzStream);
    for ([_]usize{ 0, 3, 11, 12, locations[1].data + 2, frame.len - 16, frame.len - 12, frame.len - 1 }) |cut| {
        try rejectAtomic(&workspace, frame[0..cut], output, .single, null);
    }
    // A block-prevalidated incremental path may publish earlier valid blocks;
    // it is not a substitute for the whole-stream one-shot transaction.
    @memcpy(corrupt, frame);
    corrupt[locations[1].check] ^= 1;
    var incremental = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = .prevalidated_block });
    defer incremental.deinit();
    @memset(output, 0xa5);
    try std.testing.expectError(error.ChecksumMismatch, incremental.step(corrupt, output));
    const published = incremental.snapshot().output_written;
    try std.testing.expect(published != 0);
    try std.testing.expectEqualSlices(u8, plain[0..published], output[0..published]);
}

test "XZ one-shot contracts output and dictionary limits preserve error precedence and atomicity" {
    const frame = try h.decodeHex(allocator, h.fixtures[2].hex);
    defer allocator.free(frame);
    const output = try allocator.alloc(u8, h.fixtures[2].raw_len);
    defer allocator.free(output);
    var workspace = xz.DecodeWorkspace.init(allocator);
    defer workspace.deinit();
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    corrupt[frame.len - 12] ^= 1;
    try rejectAtomic(&workspace, corrupt, output[0..1], .single, error.OutputTooSmall);
    try workspace.resetWithOptions(.{ .max_output_len = 1 });
    try rejectAtomic(&workspace, frame, output, .single, error.OutputLimitExceeded);
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodedSize(frame));
    try workspace.resetWithOptions(.{ .max_dictionary_size = 4095 });
    try rejectAtomic(&workspace, frame, output, .single, error.OutputLimitExceeded);
    try workspace.resetWithOptions(.{});
    try std.testing.expectEqual(output.len, try workspace.decodeInto(frame, output));
}

test "XZ one-shot contracts prepared replay forbids borrowed alias while overlap-aware Into warms a budgeted compressed copy" {
    const frame = try h.decodeHex(allocator, h.fixtures[2].hex);
    defer allocator.free(frame);
    const plain = try h.patternAlloc(allocator, h.fixtures[2].pattern, h.fixtures[2].raw_len);
    defer allocator.free(plain);
    const shared = try allocator.alloc(u8, plain.len + 17);
    defer allocator.free(shared);
    @memset(shared, 0xa5);
    @memcpy(shared[0..frame.len], frame);
    const original = try allocator.dupe(u8, shared);
    defer allocator.free(original);
    var tracking = std.testing.FailingAllocator.init(allocator, .{});
    var workspace = xz.DecodeWorkspace.init(tracking.allocator());
    defer workspace.deinit();
    _ = try workspace.prepare(shared[0..frame.len], .single);
    try std.testing.expectError(error.InvalidBlockPlan, workspace.replayInto(shared[0..plain.len]));
    try std.testing.expectEqualSlices(u8, original, shared);
    try std.testing.expectEqual(plain.len, try workspace.prepareInto(shared[0..frame.len], shared[0..plain.len], .single));
    try std.testing.expectEqualSlices(u8, original, shared);
    try std.testing.expect(workspace.snapshot().retained_input_capacity >= frame.len);
    const calls = tracking.alloc_index;
    tracking.fail_index = calls;
    try std.testing.expectEqual(plain.len, try workspace.replayInto(shared));
    try std.testing.expectEqual(calls, tracking.alloc_index);
    try std.testing.expectEqualSlices(u8, plain, shared[0..plain.len]);
    try h.expectSentinel(shared[plain.len..]);
    try h.expectLedger(&workspace, tracking.allocator());
}

test "XZ one-shot contracts dictionary and integrity errors precede overlap copying without changing aliased caller bytes" {
    const frame = try h.decodeHex(allocator, h.fixtures[2].hex);
    defer allocator.free(frame);
    const shared = try allocator.alloc(u8, h.fixtures[2].raw_len + 17);
    defer allocator.free(shared);
    @memset(shared, 0xa5);
    @memcpy(shared[0..frame.len], frame);
    const before = try allocator.dupe(u8, shared);
    defer allocator.free(before);
    var workspace = try xz.DecodeWorkspace.initWithOptions(allocator, .{ .max_dictionary_size = 4095 });
    defer workspace.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodeInto(shared[0..frame.len], shared));
    try std.testing.expectEqualSlices(u8, before, shared);
    try std.testing.expectEqual(@as(usize, 0), workspace.snapshot().retained_input_capacity);
    try workspace.resetWithOptions(.{});
    shared[frame.len - 12] ^= 1;
    @memcpy(before, shared);
    try std.testing.expectError(error.ChecksumMismatch, workspace.decodeInto(shared[0..frame.len], shared));
    try std.testing.expectEqualSlices(u8, before, shared);
    try std.testing.expectEqual(@as(usize, 0), workspace.snapshot().retained_input_capacity);
}
