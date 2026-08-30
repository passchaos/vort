const std = @import("std");
const core = @import("../../core.zig");
const br = @import("../../br.zig");

test "incremental planned encoder mixes compressed and stored blocks" {
    var input: [1024]u8 = undefined;
    @memset(input[0..512], 'a');
    var state: u32 = 0x1234_5678;
    for (input[512..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 512 });
    defer encoder.deinit();
    const encoded = try encodeIncremental(&encoder, &input, 73, 7);
    defer std.testing.allocator.free(encoded);

    const summary = try br.summarizeStream(encoded);
    try std.testing.expectEqual(@as(usize, 2), summary.compressed_meta_block_count + summary.uncompressed_meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.compressed_meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.uncompressed_meta_block_count);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "incremental planned encoder flushes compressed blocks around metadata" {
    const first = "alpha beta gamma delta " ** 32;
    const second = "omega theta lambda " ** 32;
    const metadata = "planned incremental metadata";
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 2048 });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    try feed(&encoder, &encoded, first, &scratch);
    try encoder.writeMetadata(metadata);
    try drainFlush(&encoder, &encoded, &scratch);
    try feed(&encoder, &encoded, second, &scratch);
    try encoder.finish();
    try drainFinish(&encoder, &encoded, &scratch);

    const summary = try br.summarizeStream(encoded.items);
    try std.testing.expectEqual(@as(usize, 2), summary.compressed_meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded.items, first.len + second.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "incremental planned encoder retains planner capacity across streams" {
    const payload = "reusable planned Brotli block payload " ** 32;
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{ .block_len = payload.len });
    defer encoder.deinit();
    const first = try encodeIncremental(&encoder, payload, payload.len, 31);
    defer std.testing.allocator.free(first);
    const retained = encoder.retainedCapacity();
    try std.testing.expect(retained > payload.len);

    try encoder.nextStream(.{ .block_len = payload.len });
    const second = try encodeIncremental(&encoder, payload, payload.len, 31);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqual(retained, encoder.retainedCapacity());

    try encoder.nextStream(.{ .block_len = payload.len });
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    encoder.allocator = failing.allocator();
    var output: [payload.len + 16]u8 = undefined;
    const written = encodeIncrementalInto(&encoder, payload, &output) catch |err| {
        encoder.allocator = std.testing.allocator;
        return err;
    };
    encoder.allocator = std.testing.allocator;
    try std.testing.expectEqualSlices(u8, first, output[0..written]);
}

test "incremental planned encoder matches across block history" {
    var first: [4096]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&first) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const input = first ++ first;
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{ .block_len = first.len });
    defer encoder.deinit();
    const encoded = try encodeIncremental(&encoder, &input, 257, 11);
    defer std.testing.allocator.free(encoded);

    const independent_chunks = [_][]const u8{ &first, &first };
    const independent = try br.encodePlannedStreamChunksAlloc(std.testing.allocator, &independent_chunks);
    defer std.testing.allocator.free(independent);
    try std.testing.expect(encoded.len * 2 < independent.len + 64);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

fn encodeIncremental(encoder: *br.IncrementalPlannedStreamEncoder, input: []const u8, input_chunk_len: usize, output_chunk_len: usize) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + input_chunk_len);
        const result = try encoder.step(input[offset..end], scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    try encoder.finish();
    try drainFinish(encoder, &encoded, scratch);
    return encoded.toOwnedSlice(std.testing.allocator);
}

fn feed(encoder: *br.IncrementalPlannedStreamEncoder, encoded: *std.ArrayList(u8), input: []const u8, scratch: []u8) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
}

fn drainFlush(encoder: *br.IncrementalPlannedStreamEncoder, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
}

fn drainFinish(encoder: *br.IncrementalPlannedStreamEncoder, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
}

fn encodeIncrementalInto(encoder: *br.IncrementalPlannedStreamEncoder, input: []const u8, output: []u8) !usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        const result = try encoder.step(input[input_offset..], output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", output[output_offset..]);
        output_offset += result.progress.output_written;
        if (result.status == .done) return output_offset;
    }
}
