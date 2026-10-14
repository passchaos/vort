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

    const chunks = [_][]const u8{ &first, &first };
    const chunked = try br.encodePlannedStreamChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(chunked);
    // The reusable chunked path now shares the same history-aware block core,
    // so identical block boundaries must produce the same cross-block wire.
    try std.testing.expectEqualSlices(u8, encoded, chunked);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "incremental planned encoder bounds history to the advertised window" {
    const block_len = 8 * 1024;
    const input_len = block_len * 2;
    const input = try std.testing.allocator.alloc(u8, input_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0xa341_316c;
    for (input[0..block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[block_len..], input[0..block_len]);

    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(std.testing.allocator, .{
        .stream = .{ .window_bits = 10 },
        .block_len = block_len,
    });
    defer encoder.deinit();
    const encoded = try encodeIncremental(&encoder, input, 509, 13);
    defer std.testing.allocator.free(encoded);
    const summary = try br.summarizeStream(encoded);
    try std.testing.expectEqual(@as(u5, 10), summary.window_bits);
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    // WBITS=10 retains only 1008 bytes, so a block-sized distance cannot be
    // emitted even though the second block duplicates the first.
    try std.testing.expect(encoded.len > block_len);
}

test "chunked and incremental planned encoders honor quality policies" {
    const block_len = 8 * 1024;
    const input = try std.testing.allocator.alloc(u8, block_len * 2);
    defer std.testing.allocator.free(input);
    const phrase = "quality-aware multi-meta-block Brotli source payload 0123456789\n";
    var random_state: u32 = 0x6d2b_79f5;
    for (input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 97 < 79)
            phrase[(index + index / block_len * 11) % phrase.len]
        else
            @truncate(random_state >> 24);
    }
    const chunks = [_][]const u8{ input[0..block_len], input[block_len..] };

    const q0 = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 0, .mode = .text },
    );
    defer std.testing.allocator.free(q0);
    const q8 = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 8, .mode = .text },
    );
    defer std.testing.allocator.free(q8);
    const q10 = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 10, .mode = .font },
    );
    defer std.testing.allocator.free(q10);
    const q11 = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 11, .mode = .font },
    );
    defer std.testing.allocator.free(q11);

    try std.testing.expect(!std.mem.eql(u8, q0, q8));
    try std.testing.expect(q11.len <= q10.len);
    for ([_][]const u8{ q0, q8, q10, q11 }) |encoded| {
        const decoded = try br.decodeStreamAllocExactSize(
            std.testing.allocator,
            encoded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(
        std.testing.allocator,
        .{
            .stream = .{ .quality = 8, .mode = .text },
            .block_len = block_len,
        },
    );
    defer incremental.deinit();
    const incremental_q8 = try encodeIncremental(&incremental, input, 257, 13);
    defer std.testing.allocator.free(incremental_q8);
    try std.testing.expectEqualSlices(u8, q8, incremental_q8);
}

test "planned stream quality options reject invalid chunked combinations before output" {
    const chunks = [_][]const u8{"invalid options must not publish a prefix"};
    try std.testing.expectError(
        error.InvalidBlockPlan,
        br.encodedPlannedStreamChunksBoundWithOptions(&chunks, .{ .quality = 12 }),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        br.encodePlannedStreamChunksWithOptionsAlloc(
            std.testing.allocator,
            &chunks,
            .{ .mode = .text },
        ),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        br.encodePlannedStreamChunksWithOptionsAlloc(
            std.testing.allocator,
            &chunks,
            .{ .level = .ratio, .quality = 8 },
        ),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        br.encodePlannedStreamChunksWithOptionsAlloc(
            std.testing.allocator,
            &chunks,
            .{ .quality = 4, .window_bits = 24 },
        ),
    );
}

test "quality-aware planned blocks consider static dictionary without LZ77 matches" {
    const payload = "information";
    const chunks = [_][]const u8{payload};
    const encoded = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 2 },
    );
    defer std.testing.allocator.free(encoded);
    const summary = try br.summarizeStream(encoded);
    try std.testing.expect(summary.static_dictionary_copy_count > 0);
    const decoded = try br.decodeStreamAllocExactSize(
        std.testing.allocator,
        encoded,
        payload.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "planned stream policies select quality-specific block sizes" {
    const input_len = 96 * 1024;
    const input = try std.testing.allocator.alloc(u8, input_len);
    defer std.testing.allocator.free(input);
    const phrase = "quality-specific Brotli block sizing amortizes headers while preserving latency\n";
    for (input, 0..) |*byte, index|
        byte.* = phrase[(index + index / (16 * 1024) * 5) % phrase.len];

    const Case = struct {
        options: br.PlannedStreamChunksOptions,
        expected_blocks: usize,
    };
    const cases = [_]Case{
        .{ .options = .{ .level = .fast }, .expected_blocks = 3 },
        .{ .options = .{ .level = .balanced }, .expected_blocks = 2 },
        .{ .options = .{ .level = .ratio }, .expected_blocks = 2 },
        .{ .options = .{ .quality = 0 }, .expected_blocks = 6 },
        .{ .options = .{ .quality = 1 }, .expected_blocks = 3 },
        .{ .options = .{ .quality = 2 }, .expected_blocks = 2 },
        .{ .options = .{ .quality = 6 }, .expected_blocks = 3 },
        .{ .options = .{ .quality = 10 }, .expected_blocks = 2 },
        .{ .options = .{ .quality = 11 }, .expected_blocks = 3 },
        .{ .options = .{ .quality = 8, .block_len = 24 * 1024 }, .expected_blocks = 4 },
    };
    const chunks = [_][]const u8{input};
    for (cases) |case| {
        const encoded = try br.encodePlannedStreamChunksWithOptionsAlloc(
            std.testing.allocator,
            &chunks,
            case.options,
        );
        defer std.testing.allocator.free(encoded);
        const summary = try br.summarizeStream(encoded);
        try std.testing.expectEqual(
            case.expected_blocks,
            summary.compressed_meta_block_count + summary.uncompressed_meta_block_count,
        );
        const decoded = try br.decodeStreamAllocExactSize(
            std.testing.allocator,
            encoded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    try std.testing.expectError(
        error.InvalidBlockPlan,
        br.encodedPlannedStreamChunksBoundWithOptions(
            &chunks,
            .{ .block_len = 64 * 1024 + 1 },
        ),
    );
}

test "incremental auto block sizing matches chunked quality wire" {
    const input_len = 96 * 1024;
    const input = try std.testing.allocator.alloc(u8, input_len);
    defer std.testing.allocator.free(input);
    const phrase = "incremental and chunked auto block sizing share one policy core 0123456789\n";
    for (input, 0..) |*byte, index| byte.* = phrase[index % phrase.len];
    const chunks = [_][]const u8{input};
    const chunked = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = 2, .mode = .text },
    );
    defer std.testing.allocator.free(chunked);

    var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(
        std.testing.allocator,
        .{ .stream = .{ .quality = 2, .mode = .text } },
    );
    defer incremental.deinit();
    const encoded = try encodeIncremental(&incremental, input, 509, 17);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, chunked, encoded);
    const summary = try br.summarizeStream(encoded);
    try std.testing.expectEqual(
        @as(usize, 2),
        summary.compressed_meta_block_count + summary.uncompressed_meta_block_count,
    );
}

test "oversized planned input applies quality policy to every meta block" {
    const input_len = br.max_uncompressed_meta_block_len + 17;
    const input = try std.testing.allocator.alloc(u8, input_len);
    defer std.testing.allocator.free(input);
    const phrase = "large quality-aware Brotli stream crosses the meta-block limit 0123456789\n";
    for (input, 0..) |*byte, index|
        byte.* = phrase[(index + index / (32 * 1024) * 7) % phrase.len];

    const q0 = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        .{ .quality = 0, .mode = .text },
    );
    defer std.testing.allocator.free(q0);
    const q2 = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        .{ .quality = 2, .mode = .text },
    );
    defer std.testing.allocator.free(q2);

    try std.testing.expect(!std.mem.eql(u8, q0, q2));
    try std.testing.expect(q0.len < input.len / 100);
    try std.testing.expect(q2.len < input.len / 100);
    try std.testing.expect(q0.len <= try br.encodedPlannedStreamBoundWithOptions(
        input.len,
        .{ .quality = 0, .mode = .text },
    ));
    try std.testing.expect(q2.len <= try br.encodedPlannedStreamBoundWithOptions(
        input.len,
        .{ .quality = 2, .mode = .text },
    ));
    for ([_][]const u8{ q0, q2 }) |encoded| {
        const summary = try br.summarizeStream(encoded);
        try std.testing.expect(summary.compressed_meta_block_count > 1);
        const decoded = try br.decodeStreamAllocExactSize(
            std.testing.allocator,
            encoded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
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
