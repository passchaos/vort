const std = @import("std");
const br = @import("../../br.zig");
const window_format = @import("window_format.zig");
const header_helpers = @import("../../tests/br_large_window_helpers.zig");

const matrix_payload =
    "standard Brotli quality windows preserve deterministic headers and payloads 0123456789\n" ** 12;

fn checkMatrixCase(quality: u4, mode: br.PlannedMode, window_bits: u5) !void {
    const encoded = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        matrix_payload,
        .{ .quality = quality, .mode = mode, .window_bits = window_bits },
    );
    defer std.testing.allocator.free(encoded);

    const summary = try br.summarizeStream(encoded);
    try std.testing.expectEqual(window_bits, summary.window_bits);
    try std.testing.expectEqual(window_bits, try header_helpers.ordinaryWindow(encoded));
    try std.testing.expect(!summary.large_window);
    try std.testing.expect(summary.compressed_meta_block_count > 0);
    try std.testing.expect(encoded.len < matrix_payload.len / 4);
    try std.testing.expect(encoded.len <= try br.encodedPlannedStreamBoundWithOptions(
        matrix_payload.len,
        .{ .quality = quality, .mode = mode, .window_bits = window_bits },
    ));
    if (quality <= 1)
        try std.testing.expect(summary.max_lz77_distance <= window_format.fragment_max_distance);
    const decoded = try br.decodeStreamAllocExactSize(
        std.testing.allocator,
        encoded,
        matrix_payload.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, matrix_payload, decoded);
}

fn checkDefaultWire(quality: u4, mode: br.PlannedMode) !void {
    const implicit = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        matrix_payload,
        .{ .quality = quality, .mode = mode },
    );
    defer std.testing.allocator.free(implicit);
    const explicit = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        matrix_payload,
        .{ .quality = quality, .mode = mode, .window_bits = 16 },
    );
    defer std.testing.allocator.free(explicit);
    try std.testing.expectEqualSlices(u8, implicit, explicit);
}

test "Brotli q0 through q5 accept wide standard windows in every mode" {
    for (0..6) |quality_value| {
        const quality: u4 = @intCast(quality_value);
        inline for (std.meta.tags(br.PlannedMode)) |mode| {
            for ([_]u5{ 17, 18, 22, 24 }) |window_bits|
                try checkMatrixCase(quality, mode, window_bits);
            try checkDefaultWire(quality, mode);
        }
    }
}

fn encodeIncremental(
    encoder: *br.IncrementalPlannedStreamEncoder,
    input: []const u8,
) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [17]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + 997);
        const result = try encoder.step(input[input_offset..input_end], &scratch);
        input_offset += result.progress.input_read;
        try encoded.appendSlice(
            std.testing.allocator,
            scratch[0..result.progress.output_written],
        );
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(
            std.testing.allocator,
            scratch[0..result.progress.output_written],
        );
        if (result.status == .done) break;
        try std.testing.expectEqual(.need_output, result.status);
    }
    return encoded.toOwnedSlice(std.testing.allocator);
}

fn checkFarQuality(input: []const u8, quality: u4, repeated_len: usize) !void {
    const narrow_options: br.PlannedEncodeOptions = .{
        .quality = quality,
        .window_bits = 16,
    };
    const wide_options: br.PlannedEncodeOptions = .{
        .quality = quality,
        .window_bits = 17,
    };
    const narrow = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        narrow_options,
    );
    defer std.testing.allocator.free(narrow);
    const implicit = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        .{ .quality = quality },
    );
    defer std.testing.allocator.free(implicit);
    try std.testing.expectEqualSlices(u8, narrow, implicit);
    const wide = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        wide_options,
    );
    defer std.testing.allocator.free(wide);

    const narrow_summary = try br.summarizeStream(narrow);
    const wide_summary = try br.summarizeStream(wide);
    try std.testing.expect(narrow_summary.max_lz77_distance <=
        try window_format.advertisedDistance(16, false));
    try std.testing.expectEqual(@as(usize, 64 * 1024), wide_summary.max_lz77_distance);
    try std.testing.expect(wide.len + repeated_len / 2 < narrow.len);

    const chunks = [_][]const u8{
        input[0 .. 64 * 1024],
        input[64 * 1024 ..],
    };
    const chunked = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .quality = quality, .window_bits = 17 },
    );
    defer std.testing.allocator.free(chunked);
    const chunked_summary = try br.summarizeStream(chunked);
    try std.testing.expectEqual(@as(usize, 64 * 1024), chunked_summary.max_lz77_distance);

    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(
        std.testing.allocator,
        .{ .stream = .{ .quality = quality, .window_bits = 17 } },
    );
    defer encoder.deinit();
    const incremental = try encodeIncremental(&encoder, input);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, chunked, incremental);

    // A one-byte RAW prefix selects the prepared/shared-dictionary planner
    // without creating a legal dictionary match for this far-copy fixture.
    const shared: br.SharedDictionary = .{ .raw_prefixes = &.{"x"} };
    const prepared = try br.encodePlannedStreamWithOptionsAlloc(
        std.testing.allocator,
        input,
        .{
            .quality = quality,
            .window_bits = 17,
            .shared_dictionary = shared,
        },
    );
    defer std.testing.allocator.free(prepared);
    const prepared_summary = try br.summarizeStreamAllocWithOptions(
        std.testing.allocator,
        prepared,
        .{ .shared_dictionary = shared },
    );
    try std.testing.expectEqual(@as(usize, 64 * 1024), prepared_summary.max_lz77_distance);

    for ([_][]const u8{ wide, chunked, incremental, prepared }, 0..) |wire, index| {
        const decoded = try br.decodeStreamAllocExactSizeWithOptions(
            std.testing.allocator,
            wire,
            input.len,
            if (index == 3) .{ .shared_dictionary = shared } else .{},
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Brotli q2 through q5 use far copies only inside the standard window" {
    const block_len = 64 * 1024;
    const repeated_len = 8 * 1024;
    const input = try std.testing.allocator.alloc(u8, block_len + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x5e17_cafe;
    for (input[0..block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    // Distance 65,536 is outside both the 16-bit wire window and the shared
    // u16 near matcher, so only the explicit 17-bit far pass can select it.
    @memcpy(input[block_len..], input[0..repeated_len]);

    for (2..6) |quality_value|
        try checkFarQuality(input, @intCast(quality_value), repeated_len);
}

test "Brotli legacy balanced wide streams do not gain quality far search" {
    const block_len = 64 * 1024;
    const repeated_len = 8 * 1024;
    const input = try std.testing.allocator.alloc(u8, block_len + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0xbad5_eed1;
    for (input[0..block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[block_len..], input[0..repeated_len]);
    const chunks = [_][]const u8{ input[0..block_len], input[block_len..] };
    const encoded = try br.encodePlannedStreamChunksWithOptionsAlloc(
        std.testing.allocator,
        &chunks,
        .{ .level = .balanced, .window_bits = 17 },
    );
    defer std.testing.allocator.free(encoded);
    const summary = try br.summarizeStream(encoded);
    try std.testing.expect(summary.max_lz77_distance <= std.math.maxInt(u16));
    const decoded = try br.decodeStreamAllocExactSize(
        std.testing.allocator,
        encoded,
        input.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Brotli standard window rejects a source one byte beyond its history" {
    const window17_max = (@as(usize, 1) << 17) - 16;
    const prefix_len = window17_max + 1;
    const repeated_len = 258;
    const input = try std.testing.allocator.alloc(u8, prefix_len + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x17ed_0001;
    for (input[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[prefix_len..], input[0..repeated_len]);

    for ([_]u4{ 2, 5 }) |quality| {
        const expired = try br.encodePlannedStreamWithOptionsAlloc(
            std.testing.allocator,
            input,
            .{ .quality = quality, .window_bits = 17 },
        );
        defer std.testing.allocator.free(expired);
        const reachable = try br.encodePlannedStreamWithOptionsAlloc(
            std.testing.allocator,
            input,
            .{ .quality = quality, .window_bits = 18 },
        );
        defer std.testing.allocator.free(reachable);
        const expired_summary = try br.summarizeStream(expired);
        const reachable_summary = try br.summarizeStream(reachable);
        try std.testing.expect(expired_summary.max_lz77_distance <= window17_max);
        try std.testing.expectEqual(prefix_len, reachable_summary.max_lz77_distance);
        try std.testing.expect(reachable.len + repeated_len / 2 < expired.len);
        for ([_][]const u8{ expired, reachable }) |wire| {
            const decoded = try br.decodeStreamAllocExactSize(
                std.testing.allocator,
                wire,
                input.len,
            );
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
        }
    }
}

test "Brotli q0 and q1 wide headers keep matching fragment local" {
    const block_len = 64 * 1024;
    const input = try std.testing.allocator.alloc(u8, block_len * 2);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x10ca_1bad;
    for (input[0..block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[block_len..], input[0..block_len]);

    for ([_]u4{ 0, 1 }) |quality| {
        const encoded = try br.encodePlannedStreamWithOptionsAlloc(
            std.testing.allocator,
            input,
            .{ .quality = quality, .window_bits = 24 },
        );
        defer std.testing.allocator.free(encoded);
        const summary = try br.summarizeStream(encoded);
        try std.testing.expectEqual(@as(u5, 24), summary.window_bits);
        try std.testing.expect(summary.max_lz77_distance <= window_format.fragment_max_distance);
        const decoded = try br.decodeStreamAllocExactSize(
            std.testing.allocator,
            encoded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}
