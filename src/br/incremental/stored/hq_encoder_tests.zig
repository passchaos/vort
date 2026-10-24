const std = @import("std");
const br = @import("../../../br.zig");

test "Brotli HQ public encoder defers exact full blocks and drains final output one byte at a time" {
    const payload = "high quality streaming payload 0123456789\n" ** 24;
    for ([_]u4{ 10, 11 }) |quality| {
        var profile: br.HqProfile = .{};
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{
            .stream = .{ .quality = quality, .hq = .{ .block_len = payload.len, .profile = &profile } },
        });
        defer encoder.deinit();
        var offset: usize = 0;
        while (offset != payload.len) {
            const end = @min(payload.len, offset + 31);
            const result = try encoder.step(payload[offset..end], &.{});
            try std.testing.expectEqual(.need_input, result.status);
            try std.testing.expectEqual(end - offset, result.progress.input_read);
            try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
            offset = end;
        }
        try std.testing.expectEqual(payload.len, encoder.snapshot().buffered_input);
        try std.testing.expectEqual(payload.len, encoder.snapshot().input_read);
        try std.testing.expectEqual(@as(u64, 0), profile.emitted_metablocks);
        try encoder.finish();
        const committed = try encoder.step(&.{}, &.{});
        try std.testing.expectEqual(.need_output, committed.status);
        try std.testing.expectEqual(@as(usize, 0), committed.progress.output_written);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
        try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        try drain(&encoder, &encoded);
        const summary = try br.summarizeStream(encoded.items);
        try std.testing.expectEqual(@as(usize, 1), summary.compressed_meta_block_count + summary.uncompressed_meta_block_count);
        if (summary.compressed_meta_block_count != 0)
            try std.testing.expectEqual(@as(usize, 0), summary.empty_meta_block_count);
        const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded.items, payload.len);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "Brotli HQ public encoder retries final allocation failure with identical wire and emitted profile" {
    const payload = "streaming transaction keeps final input and distance state\n" ** 16;
    var profile: br.HqProfile = .{};
    const options: br.IncrementalPlannedStreamEncoder.Options = .{
        .stream = .{ .quality = 10, .hq = .{ .block_len = payload.len, .profile = &profile } },
    };
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, options);
    defer encoder.deinit();
    try std.testing.expectEqual(.need_input, (try encoder.step(payload, &.{})).status);
    const before = encoder.snapshot();
    const before_emitted = profile.emitted();
    const prefix = try std.testing.allocator.dupe(u8, encoder.pending.items);
    defer std.testing.allocator.free(prefix);
    try encoder.finish();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    encoder.allocator = failing.allocator();
    const failed = encoder.step(&.{}, &.{});
    encoder.allocator = std.testing.allocator;
    try std.testing.expectError(error.OutOfMemory, failed);
    try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
    try std.testing.expectEqual(before.buffered_input, encoder.snapshot().buffered_input);
    try std.testing.expectEqual(before.pending_output, encoder.snapshot().pending_output);
    try std.testing.expectEqualSlices(u8, prefix, encoder.pending.items);
    try std.testing.expectEqual(before_emitted, profile.emitted());
    try std.testing.expect(!encoder.final_written);
    try std.testing.expect(!encoder.snapshot().done);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try drain(&encoder, &encoded);
    try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);

    var baseline_options = options;
    baseline_options.stream.hq.?.profile = null;
    var baseline = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, baseline_options);
    defer baseline.deinit();
    _ = try baseline.step(payload, &.{});
    try baseline.finish();
    var baseline_wire: std.ArrayList(u8) = .empty;
    defer baseline_wire.deinit(std.testing.allocator);
    try drain(&baseline, &baseline_wire);
    try std.testing.expectEqualSlices(u8, baseline_wire.items, encoded.items);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded.items, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Brotli HQ public encoder outer block override controls the actual parser target" {
    const payload = "0123456789abcdef" ** 4;
    for ([_]u4{ 10, 11 }) |quality| {
        var profile: br.HqProfile = .{};
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{
            .stream = .{ .quality = quality, .block_len = 32, .hq = .{ .block_len = 16, .profile = &profile } },
            .block_len = 64,
        });
        defer encoder.deinit();
        const accepted = try encoder.step(payload, &.{});
        try std.testing.expectEqual(.need_input, accepted.status);
        try std.testing.expectEqual(payload.len, accepted.progress.input_read);
        try std.testing.expectEqual(payload.len, encoder.snapshot().buffered_input);
        try encoder.finish();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        try drain(&encoder, &encoded);
        try std.testing.expect(profile.passes != 0);
        try std.testing.expectEqual(@as(usize, 64), profile.effective.?.block_len);
        try std.testing.expectEqual(@as(u8, quality), profile.effective.?.quality);
        try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);
        const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded.items, payload.len);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "Brotli HQ public encoder reuses output aliased by input and outer chunk descriptors" {
    const payload = "retained output is the next HQ input\n" ** 2;
    var encoder = br.PlannedStreamEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try encoder.output.appendSlice(std.testing.allocator, payload);
    const input_wire = try encoder.encodeScratchWithOptions(encoder.output.items, .{ .quality = 10, .hq = .{ .block_len = payload.len } });
    const input_decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, input_wire, payload.len);
    defer std.testing.allocator.free(input_decoded);
    try std.testing.expectEqualSlices(u8, payload, input_decoded);

    encoder.output.clearRetainingCapacity();
    try encoder.output.appendSlice(std.testing.allocator, &([_]u8{0} ** 128));
    const descriptors: *[2][]const u8 = @ptrCast(@alignCast(encoder.output.items.ptr));
    const first = "outer chunks alias source";
    @memcpy(encoder.output.items[64..][0..first.len], first);
    descriptors.* = .{ encoder.output.items[64..][0..first.len], " tail" };
    const expected = first ++ " tail";
    const chunk_wire = try encoder.encodeChunksScratchWithOptions(descriptors, .{ .quality = 11, .hq = .{ .block_len = expected.len } });
    const chunk_decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, chunk_wire, expected.len);
    defer std.testing.allocator.free(chunk_decoded);
    try std.testing.expectEqualSlices(u8, expected, chunk_decoded);
}

fn drain(encoder: *br.IncrementalPlannedStreamEncoder, encoded: *std.ArrayList(u8)) !void {
    var output: [1]u8 = undefined;
    while (true) {
        const result = try encoder.step(&.{}, &output);
        try encoded.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        try std.testing.expectEqual(encoded.items.len, encoder.snapshot().output_written);
        if (result.status == .done) return;
        try std.testing.expectEqual(.need_output, result.status);
        try std.testing.expect(result.progress.output_written != 0);
    }
}
