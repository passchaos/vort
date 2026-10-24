const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_large_window_helpers.zig");
const a = std.testing.allocator;

fn extendedDecode(bytes: []const u8, input: []const u8) !void {
    const decoded = try br.decodeStreamAllocWithOptions(a, bytes, .{ .allow_large_window = true });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Brotli large window actual command wire preserves implicit explicit zero and aliased nonzero cache semantics" {
    const input = "aaaaaaaa";
    for ([_]struct { command: u16, code: usize, symbol: ?u16, starting: [4]usize }{
        .{ .command = 34, .code = 0, .symbol = null, .starting = .{ 16, 15, 11, 4 } },
        .{ .command = 162, .code = 0, .symbol = 0, .starting = .{ 16, 15, 11, 4 } },
        .{ .command = 162, .code = 1, .symbol = 1, .starting = .{ 16, 15, 4, 4 } },
    }) |sample| {
        const parameters = br.HqDistanceParameters.init(3, 15);
        const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(a, input, &.{.{
            .insert_start = 0,
            .insert_len = 4,
            .copy_len = 4,
            .distance = 4,
            .has_copy = true,
            .hq_encoding = .{ .command_symbol = sample.command, .distance_code = sample.code, .distance_encoding = if (sample.symbol) |symbol| .{ .symbol = symbol } else null, .distance_parameters = parameters, .format = .large_window },
        }}, .{ .large_window = true, .window_bits = 25, .distance_parameters = parameters, .starting_last_distances = sample.starting });
        defer a.free(encoded.bytes);
        const semantic = [4]usize{ sample.starting[3], sample.starting[2], sample.starting[1], sample.starting[0] };
        const actual = try h.singleCommandWire(encoded.bytes, semantic);
        try std.testing.expect(actual.large_window);
        try std.testing.expectEqual(@as(usize, 25), actual.window_bits);
        try std.testing.expectEqual(@as(usize, sample.command), actual.command_symbol);
        try std.testing.expectEqual(if (sample.symbol) |symbol| @as(?usize, symbol) else null, actual.distance_symbol);
        try std.testing.expectEqual(@as(usize, 4), actual.distance);
        try std.testing.expectEqual(@as(u16, 120), actual.ndirect);
        const expected_cache = h.afterDistance(semantic, sample.code, 4, false);
        for (expected_cache, 0..) |distance, index| try std.testing.expectEqual(distance, encoded.last_distances[3 - index]);
        if (sample.code == 0) try extendedDecode(encoded.bytes, input);
    }
}

test "Brotli large window actual static raw four transforms advance one two three five output bytes without cache push" {
    for ([_]struct { transform: usize, output: []const u8 }{
        .{ .transform = 23, .output = "t" },
        .{ .transform = 27, .output = "ti" },
        .{ .transform = 12, .output = "tim" },
        .{ .transform = 1, .output = "time " },
    }) |sample| {
        // RFC word0 at raw length4 is 'time'. This command starts at output0,
        // so static physical distance is transform*1024+1 in either format.
        const address = sample.transform * 1024;
        const physical = address + 1;
        const parameters = br.HqDistanceParameters.init(3, 15);
        const chosen = h.distanceEncoding(physical, 3, 120);
        const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(a, sample.output, &.{.{
            .insert_start = 0,
            .insert_len = 0,
            .copy_len = 4,
            .has_copy = true,
            .source = .static,
            .dictionary_address = address,
            .dictionary_output_len = sample.output.len,
            .hq_encoding = .{ .command_symbol = 130, .distance_code = physical + 15, .distance_encoding = .{ .symbol = chosen.symbol, .extra = @intCast(chosen.extra), .extra_bits = @intCast(chosen.extra_bits) }, .distance_parameters = parameters, .format = .large_window },
        }}, .{ .large_window = true, .window_bits = 25, .distance_parameters = parameters });
        defer a.free(encoded.bytes);
        const actual = try h.singleCommandWire(encoded.bytes, .{ 4, 11, 15, 16 });
        try std.testing.expect(actual.large_window);
        try std.testing.expectEqual(@as(usize, 130), actual.command_symbol);
        try std.testing.expectEqual(@as(usize, 4), actual.raw_copy_len);
        try std.testing.expectEqual(sample.output.len, actual.meta_len);
        try std.testing.expectEqual(physical, actual.distance);
        try std.testing.expectEqual([4]usize{ 16, 15, 11, 4 }, encoded.last_distances);
        try extendedDecode(encoded.bytes, sample.output);
    }
}

test "Brotli large window next stream format changes clear previous caches and preserve reset identity" {
    const input = h.plain;
    const standard: br.IncrementalPlannedStreamEncoder.Options = .{
        .stream = .{ .quality = 10, .hq = .{ .block_len = 32 }, .window_bits = 16 },
        .block_len = 0,
    };
    var large = standard;
    large.stream.large_window = true;
    large.stream.window_bits = 25;
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, standard);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, input, 31, 17);
    defer a.free(first);
    try std.testing.expectEqual(@as(u5, 16), try h.ordinaryWindow(first));
    try encoder.nextStream(large);
    const second = try h.drive(a, &encoder, input, 1, 1);
    defer a.free(second);
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{input}, large.stream);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, second);
    try std.testing.expectEqual(@as(u5, 25), try h.extensionWindow(second));
    try extendedDecode(second, input);
    encoder.reset();
    const after_reset = try h.drive(a, &encoder, input, 17, 1);
    defer a.free(after_reset);
    try std.testing.expectEqualSlices(u8, expected, after_reset);
    try encoder.nextStream(standard);
    const final = try h.drive(a, &encoder, input, 1, 1);
    defer a.free(final);
    try std.testing.expectEqualSlices(u8, first, final);
    const decoded = try br.decodeStreamAlloc(a, final);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Brotli large window failed final allocation preserves extension reservoir and retries the same format" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_moving_growth = true;
    var emitted: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    const options: br.IncrementalPlannedStreamEncoder.Options = .{
        .stream = .{ .quality = 10, .window_bits = 30, .large_window = true, .hq = .{ .profile = &emitted }, .memory_profile = &memory },
        .block_len = 0,
    };
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(tracked.allocator(), options);
    defer encoder.deinit();
    // Drain only the stable byte before injecting an allocation failure. The
    // mutable extension/header tail remains owned by the encoder.
    var prefix: [1]u8 = undefined;
    const drain = try encoder.step("", &prefix);
    try std.testing.expectEqual(@as(usize, 1), drain.progress.output_written);
    const accepted = try encoder.step(h.plain, &.{});
    try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
    try encoder.finish();
    const before = encoder.snapshot();
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    const before_emitted = emitted.emitted();
    tracked.fail_alloc_after = tracked.alloc_attempts;
    var destination: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, encoder.step("", &destination));
    try h.untouched(&destination);
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
    try std.testing.expectEqualDeep(before_emitted, emitted.emitted());
    tracked.clearFailures();
    const tail = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(tail);
    const bytes = try std.mem.concat(a, u8, &.{ &prefix, tail });
    defer a.free(bytes);
    try std.testing.expectEqual(@as(u5, 30), try h.extensionWindow(bytes));
    try extendedDecode(bytes, h.plain);
    var baseline = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = .{ .quality = 10, .window_bits = 30, .large_window = true, .hq = .{} }, .block_len = 0 });
    defer baseline.deinit();
    const expected = try h.drive(a, &baseline, h.plain, 1, 1);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, bytes);
    try std.testing.expectEqual(tracked.live, memory.live_requested_bytes);
}

test "Brotli large window aliased reusable input chunks and dictionary keep the exact extension wire" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_moving_growth = true;
    var encoder = br.PlannedStreamEncoder.init(tracked.allocator());
    defer encoder.deinit();
    try encoder.output.resize(tracked.allocator(), 256);
    @memset(encoder.output.items, 0xa5);
    const payload = h.plain[0..64];
    @memcpy(encoder.output.items[128..192], payload);
    const chunks: *[2][]const u8 = @ptrCast(@alignCast(encoder.output.items.ptr));
    chunks.* = .{ encoder.output.items[128..160], encoder.output.items[160..192] };
    const prefixes: *[1][]const u8 = @ptrCast(@alignCast(encoder.output.items.ptr + 32));
    prefixes.* = .{encoder.output.items[128..192]};
    var memory: br.EncodeMemoryProfile = .{};
    var hq: br.HqProfile = .{};
    const options: br.PlannedStreamChunksOptions = .{ .quality = 11, .window_bits = 25, .large_window = true, .hq = .{ .profile = &hq }, .memory_profile = &memory, .shared_dictionary = .{ .raw_prefixes = prefixes } };
    const encoded = try encoder.encodeChunksScratchWithOptions(chunks, options);
    try std.testing.expectEqual(@as(u5, 25), try h.extensionWindow(encoded));
    try std.testing.expectEqual(tracked.peak, memory.peak_requested_bytes);
    const decoded = try br.decodeStreamAllocWithOptions(a, encoded, .{ .allow_large_window = true, .shared_dictionary = .{ .raw_prefixes = &.{payload} } });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    var independent = options;
    independent.memory_profile = null;
    independent.hq.?.profile = null;
    independent.shared_dictionary = .{ .raw_prefixes = &.{payload} };
    const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{ payload[0..32], payload[32..] }, independent);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, encoded);
}
