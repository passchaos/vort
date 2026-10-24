const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_hq_helpers.zig");
const allocator = std.testing.allocator;

fn bufferedFinal(encoder: *br.IncrementalPlannedStreamEncoder, input: []const u8) !void {
    const accepted = try encoder.step(input, &.{});
    try std.testing.expectEqual(input.len, accepted.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try std.testing.expectEqual(@as(usize, input.len), encoder.snapshot().buffered_input);
    try encoder.finish();
}

fn flushFirst(encoder: *br.IncrementalPlannedStreamEncoder, input: []const u8) ![]u8 {
    const accepted = try encoder.step(input, &.{});
    try std.testing.expectEqual(input.len, accepted.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
    encoder.flush();
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var output: [1]u8 = undefined;
    for (0..4096) |_| {
        const result = try encoder.step("", &output);
        try bytes.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .need_input) return bytes.toOwnedSlice(allocator);
        try std.testing.expectEqual(.need_output, result.status);
    }
    return error.TestUnexpectedResult;
}

test "Brotli HQ incremental selected early middle and publication allocation failures retry identical wire" {
    const input = h.legacy_plain[0..64];
    const options: br.IncrementalPlannedStreamEncoder.Options = .{ .stream = .{ .quality = 10, .hq = .{} } };
    var measure = std.testing.FailingAllocator.init(allocator, .{});
    var baseline = br.IncrementalPlannedStreamEncoder.initWithOptions(measure.allocator(), options);
    defer baseline.deinit();
    try bufferedFinal(&baseline, input);
    const start = measure.alloc_index;
    const expected = try h.drive(allocator, &baseline, input, 1, 1);
    defer allocator.free(expected);
    const allocations = measure.alloc_index - start;
    try std.testing.expect(allocations >= 3);
    for ([_]usize{ 0, allocations / 2, allocations - 1 }) |failure| {
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        var profile: br.HqProfile = .{};
        var profiled = options;
        profiled.stream.hq.?.profile = &profile;
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(failing.allocator(), profiled);
        defer encoder.deinit();
        try bufferedFinal(&encoder, input);
        const before = encoder.snapshot();
        const emitted = profile.emitted();
        const pending = try allocator.dupe(u8, encoder.pending.items);
        defer allocator.free(pending);
        failing.fail_index = failing.alloc_index + failure;
        failing.resize_fail_index = failing.resize_index;
        var destination: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step("", &destination));
        try h.sentinel(&destination);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try std.testing.expectEqualDeep(emitted, profile.emitted());
        failing.fail_index = std.math.maxInt(usize);
        failing.resize_fail_index = std.math.maxInt(usize);
        const recovered = try h.drive(allocator, &encoder, input, 1, 1);
        defer allocator.free(recovered);
        try std.testing.expectEqualSlices(u8, expected, recovered);
        try std.testing.expect(profile.emitted_metablocks > 0);
        const decoded = try br.decodeStreamAlloc(allocator, recovered);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Brotli HQ second meta block OOM retry preserves committed history matcher model cache and profile" {
    const first = h.legacy_plain[0..64];
    var input: [128]u8 = undefined;
    @memcpy(input[0..64], first);
    @memcpy(input[64..], first);
    const options: br.IncrementalPlannedStreamEncoder.Options = .{
        .stream = .{ .quality = 10, .hq = .{ .block_len = 64 } },
    };
    var measure = std.testing.FailingAllocator.init(allocator, .{});
    var baseline = br.IncrementalPlannedStreamEncoder.initWithOptions(measure.allocator(), options);
    defer baseline.deinit();
    const expected_prefix = try flushFirst(&baseline, first);
    defer allocator.free(expected_prefix);
    try bufferedFinal(&baseline, first);
    const start = measure.alloc_index;
    const expected_tail = try h.drive(allocator, &baseline, &input, 1, 1);
    defer allocator.free(expected_tail);
    const allocations = measure.alloc_index - start;
    try std.testing.expect(allocations >= 3);
    for ([_]usize{ 0, allocations / 2, allocations - 1 }) |failure| {
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        var profile: br.HqProfile = .{};
        var profiled = options;
        profiled.stream.hq.?.profile = &profile;
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(failing.allocator(), profiled);
        defer encoder.deinit();
        const prefix = try flushFirst(&encoder, first);
        defer allocator.free(prefix);
        try std.testing.expectEqualSlices(u8, expected_prefix, prefix);
        try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);
        try bufferedFinal(&encoder, first);
        const before = encoder.snapshot();
        const emitted = profile.emitted();
        const pending = try allocator.dupe(u8, encoder.pending.items);
        defer allocator.free(pending);
        failing.fail_index = failing.alloc_index + failure;
        failing.resize_fail_index = failing.resize_index;
        var destination: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step("", &destination));
        try h.sentinel(&destination);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try std.testing.expectEqualDeep(emitted, profile.emitted());
        failing.fail_index = std.math.maxInt(usize);
        failing.resize_fail_index = std.math.maxInt(usize);
        const tail = try h.drive(allocator, &encoder, &input, 1, 1);
        defer allocator.free(tail);
        try std.testing.expectEqualSlices(u8, expected_tail, tail);
        try std.testing.expectEqual(@as(u64, 2), profile.emitted_metablocks);
        try std.testing.expect(profile.emitted_max_distance >= 64);
        const bytes = try std.mem.concat(allocator, u8, &.{ prefix, tail });
        defer allocator.free(bytes);
        const decoded = try br.decodeStreamAlloc(allocator, bytes);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

test "Brotli HQ invalid offered input cannot drain already committed output or change published profile" {
    var profile: br.HqProfile = .{};
    const input = h.legacy_plain[0..32];
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{
        .stream = .{ .quality = 10, .hq = .{ .profile = &profile, .block_len = 32 } },
        .max_input_len = 32,
    });
    defer encoder.deinit();
    try bufferedFinal(&encoder, input);
    const committed = try encoder.step("", &.{});
    try std.testing.expectEqual(@as(usize, 0), committed.progress.output_written);
    try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);
    try std.testing.expect(encoder.snapshot().pending_output > 0);
    const before = encoder.snapshot();
    const emitted = profile.emitted();
    var destination: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.TrailingData, encoder.step("x", &destination));
    try h.sentinel(&destination);
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    const bytes = try h.drive(allocator, &encoder, input, 1, 1);
    defer allocator.free(bytes);
    const decoded = try br.decodeStreamAlloc(allocator, bytes);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Brotli HQ reset clears previous stream history cache and output while retaining independent profile" {
    var profile: br.HqProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{
        .stream = .{ .quality = 10, .hq = .{ .profile = &profile, .block_len = 64 } },
    });
    defer encoder.deinit();
    const first = try h.drive(allocator, &encoder, h.legacy_plain, 31, 17);
    defer allocator.free(first);
    const published = profile.emitted();
    encoder.reset();
    const empty = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), empty.input_read);
    try std.testing.expectEqual(@as(usize, 0), empty.output_written);
    try std.testing.expectEqual(@as(usize, 0), empty.buffered_input);
    try std.testing.expectEqual(@as(usize, 0), empty.pending_output);
    try std.testing.expect(!empty.finishing and !empty.done);
    try std.testing.expectEqualDeep(published, profile.emitted());
    const input = "second second stream has a different recent distance";
    const actual = try h.drive(allocator, &encoder, input, 1, 1);
    defer allocator.free(actual);
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(allocator, &.{input}, .{
        .quality = 10,
        .hq = .{ .block_len = 64 },
    });
    defer allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expect(profile.emitted_metablocks > published.emitted_metablocks);
}
