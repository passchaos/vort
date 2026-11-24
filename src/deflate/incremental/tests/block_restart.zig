//! Incremental Deflate restart contracts for trusted block checkpoints.
const std = @import("std");
const t = std.testing;
const core = @import("../../../core.zig");
const deflate = @import("../../../deflate.zig");
const deflate64 = @import("../../../deflate64.zig");
const wide = @import("wide_decode/helpers.zig");

const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;
const Point = deflate.BlockRestartPoint;
const Count = core.StreamCount;

// The 55-bit Z_FIXED prefix from block_boundary_positions.zig followed by a
// final fixed block containing only (length=5, distance=5) and EOB.
const wire = [_]u8{ 0x3a, 0x71, 0xf2, 0xd4, 0xe9, 0x33, 0x80, 0x81, 0x09, 0x00 };
const block = "\xc8\xc9\xca\xcb\xcc";
const point_byte = 6;
const next_byte = point_byte + 1;

fn expectPosition(point: Point, byte: Count, bit: u3, decoded: Count) !void {
    try t.expectEqual(deflate.BlockBoundaryPosition{
        .compressed_byte_offset = byte,
        .compressed_bit_offset = bit,
        .decoded_offset = decoded,
    }, point.position);
}

fn expectSuffix(decoder: anytype, input: []const u8) !void {
    var output: [block.len + 1]u8 = undefined;
    const result = try decoder.step(input, &output);
    try t.expectEqual(.done, result.status);
    try t.expectEqual(input.len, result.progress.input_read);
    try t.expectEqualSlices(u8, block, output[0..result.progress.output_written]);
    try decoder.finish();
}

test "block restart restores non-byte-aligned Deflate and Deflate64 history" {
    inline for (.{ Raw, deflate64.IncrementalDecoder }) |Decoder| {
        var history: [Decoder.required_history_len]u8 = undefined;
        var source = try Decoder.initWithHistory(.{ .max_distance = block.len }, &history);
        var output: [block.len + 1]u8 = undefined;
        try t.expect((try source.stepToBlockBoundary(wire[0..next_byte], &output)).block_boundary);
        var saved: [block.len]u8 = undefined;
        const point = try source.captureBlockRestart(&saved);
        try expectPosition(point, point_byte, 7, block.len);
        try t.expectEqual(Decoder.required_history_len, point.window_size);
        try t.expectEqual(block.len, point.max_distance);
        try t.expectEqualSlices(u8, block, point.history);

        // The checkpoint survives destruction of the source's ring contents.
        @memset(&history, 0xa5);
        var resumed = try Decoder.initWithHistory(.{}, &history);
        const total_len = 2 * block.len;
        try t.expectEqual(@as(Count, next_byte), try resumed.restartAtBlockBoundary(point, wire[point_byte], .{ .expected_output_len = total_len }));
        try t.expectEqual(@as(?deflate.BlockBoundaryPosition, point.position), resumed.blockBoundaryPosition());
        try t.expectEqual(block.len, resumed.options.max_distance);
        try expectSuffix(&resumed, wire[next_byte..]);
        try t.expectEqual(@as(Count, wire.len), resumed.diagnostics().frame_input_read.?);
        try t.expectEqual(@as(Count, total_len), resumed.diagnostics().output_written);
        try t.expectError(error.InvalidStreamState, resumed.captureBlockRestart(&saved));

        // Model the same payload at wide source and plaintext offsets on x86/WASI.
        const base: Count = @as(Count, 1) << 32;
        var wide_point = point;
        wide_point.position.compressed_byte_offset += base;
        wide_point.position.decoded_offset += base;
        try t.expectEqual(base + next_byte, try resumed.restartAtBlockBoundary(wide_point, wire[point_byte], .{ .expected_output_len = base + total_len }));
        try expectSuffix(&resumed, wire[next_byte..]);
        try t.expectEqual(base + wire.len, resumed.diagnostics().frame_input_read.?);
        try t.expectEqual(base + total_len, resumed.diagnostics().output_written);

        _ = try resumed.restartAtBlockBoundary(point, wire[point_byte], .{ .max_distance = block.len - 1 });
        try t.expectError(error.InvalidMatch, resumed.step(wire[next_byte..], &output));
    }
}

test "block restart linearizes wrapped history at a byte-aligned header" {
    const len = Raw.required_history_len + 2;
    const plain = try t.allocator.alloc(u8, len + 1);
    defer t.allocator.free(plain);
    for (plain, 0..) |*byte, i| byte.* = @intCast(i % 251);
    const encoded = try deflate.encodeRawStoredSplitAlloc(t.allocator, plain, len);
    defer t.allocator.free(encoded);
    var history: [Raw.required_history_len]u8 = undefined;
    var decoder = try Raw.initWithHistory(.{}, &history);
    var output: [len + 1]u8 = undefined;
    try t.expect((try decoder.stepToBlockBoundary(encoded, &output)).block_boundary);
    const point = try decoder.captureBlockRestart(&output);
    try expectPosition(point, len + 5, 0, len);
    try t.expectEqualSlices(u8, plain[2..len], point.history);
    try t.expectError(error.InvalidBlockPlan, decoder.restartAtBlockBoundary(point, encoded[len + 5], .{}));
    const next = try decoder.restartAtBlockBoundary(point, null, .{});
    try t.expectEqual(@as(Count, len + 5), next);
    var suffix: [2]u8 = undefined;
    const last = try decoder.step(encoded[@intCast(next)..], &suffix);
    try t.expectEqual(.done, last.status);
    try t.expectEqualSlices(u8, plain[len..], suffix[0..last.progress.output_written]);
}

test "block restart rejects invalid captures and restores transactionally" {
    var history: [Raw.recommended_history_len]u8 = undefined;
    var decoder = try Raw.initWithHistory(.{}, &history);
    const workspace = try t.allocator.create(Raw.SemanticWorkspace);
    defer t.allocator.destroy(workspace);
    try decoder.attachSemanticWorkspace(workspace);
    var output: [block.len + 1]u8 = undefined;
    _ = try decoder.stepToBlockBoundary(wire[0..1], &output);
    try t.expectError(error.InvalidStreamState, decoder.captureBlockRestart(&output));
    try t.expect((try decoder.stepToBlockBoundary(wire[1..next_byte], &output)).block_boundary);

    const untouched: [block.len - 1]u8 = @splat(0xa5);
    var small = untouched;
    try t.expectError(error.OutputTooSmall, decoder.captureBlockRestart(&small));
    try t.expectEqual(untouched, small);
    try t.expectError(error.InvalidBlockPlan, decoder.captureBlockRestart(std.mem.asBytes(&decoder)));
    try t.expectError(error.InvalidBlockPlan, decoder.captureBlockRestart(&history));
    try t.expectError(error.InvalidBlockPlan, decoder.captureBlockRestart(history[Raw.required_history_len..]));
    try t.expectError(error.InvalidBlockPlan, decoder.captureBlockRestart(std.mem.asBytes(workspace)));

    const point = try decoder.captureBlockRestart(&output);
    const initial = wire[point_byte];
    try t.expectError(error.InvalidBlockPlan, decoder.restartAtBlockBoundary(point, null, .{}));
    try t.expectError(error.OutputLimitExceeded, decoder.restartAtBlockBoundary(point, initial, .{ .max_output_len = block.len - 1 }));
    var bad = point;
    bad.window_size *= 2;
    try t.expectError(error.InvalidBlockPlan, decoder.restartAtBlockBoundary(bad, initial, .{}));
    bad = point;
    bad.max_distance = block.len - 1;
    try t.expectError(error.InvalidBlockPlan, decoder.restartAtBlockBoundary(bad, initial, .{}));
    bad = point;
    bad.position.compressed_byte_offset = std.math.maxInt(Count);
    try t.expectError(error.IntegerOverflow, decoder.restartAtBlockBoundary(bad, initial, .{}));
    bad = point;
    bad.history = history[0..block.len];
    try t.expectError(error.InvalidBlockPlan, decoder.restartAtBlockBoundary(bad, initial, .{}));
    try t.expectEqual(@as(?deflate.BlockBoundaryPosition, point.position), decoder.blockBoundaryPosition());
    try expectSuffix(&decoder, wire[next_byte..]);

    _ = try decoder.restartAtBlockBoundary(point, initial, .{});
    try t.expectEqual(@as(?*Raw.SemanticWorkspace, workspace), decoder.semantic_decoder);
    try expectSuffix(&decoder, wire[next_byte..]);
}

test "block restart captures absolute offsets and member-local history in wrappers" {
    const Auto = deflate.ZlibOrGzipIncrementalDecoder;
    const zlib = wide.zlib_header ++ wire ++ [_]u8{ 0x2b, 0x5c, 0x07, 0xe5 };
    const gzip = wide.gzip_header ++ wire ++ [_]u8{ 0x6f, 0x4c, 0x14, 0x2b, 10, 0, 0, 0 };
    const cases = .{
        .{ deflate.ZlibIncrementalDecoder, &zlib, wide.zlib_header.len }, .{ Auto, &zlib, wide.zlib_header.len },
        .{ deflate.GzipIncrementalDecoder, &gzip, wide.gzip_header.len }, .{ Auto, &gzip, wide.gzip_header.len },
    };
    var history: [Raw.required_history_len]u8 = undefined;
    var resumed_history: [Raw.required_history_len]u8 = undefined;
    inline for (cases) |case| {
        const member_wire: []const u8 = case[1];
        const header = case[2];
        var decoder = try case[0].init(.{ .allow_concatenated = true }, &history);
        var resumed = try Raw.initWithHistory(.{}, &resumed_history);
        var saved: [block.len]u8 = undefined;
        for (0..2) |member| {
            try t.expectError(error.InvalidStreamState, decoder.captureBlockRestart(&saved));
            var output: [2 * block.len + 1]u8 = undefined;
            try t.expect((try decoder.stepToBlockBoundary(member_wire[0 .. header + next_byte], &output)).block_boundary);
            const point = try decoder.captureBlockRestart(&saved);
            const base = member * member_wire.len;
            try expectPosition(point, base + header + point_byte, 7, (2 * member + 1) * block.len);
            try t.expectEqualSlices(u8, block, point.history);
            const next = try resumed.restartAtBlockBoundary(point, member_wire[header + point_byte], .{ .expected_output_len = (member + 1) * 2 * block.len });
            try t.expectEqual(@as(Count, base + header + next_byte), next);
            try expectSuffix(&resumed, member_wire[@intCast(next - base) .. header + wire.len]);
            _ = try decoder.step(member_wire[header + next_byte ..], output[block.len..]);
            try t.expectEqualSlices(u8, block ++ block, output[0 .. 2 * block.len]);
        }
        try decoder.finish();
    }
}

test "block restart capture protects a borrowed wrapper dictionary" {
    const zlib = wide.zlib_header ++ wire ++ [_]u8{ 0x2b, 0x5c, 0x07, 0xe5 };
    var history: [Raw.required_history_len]u8 = undefined;
    const sentinel: [block.len]u8 = @splat(0xa5);
    var dictionary = sentinel;
    inline for (.{ deflate.ZlibIncrementalDecoder, deflate.ZlibOrGzipIncrementalDecoder }) |Decoder| {
        var decoder = try Decoder.initWithDictionary(.{}, &history, &dictionary);
        var output: [block.len + 1]u8 = undefined;
        try t.expect((try decoder.stepToBlockBoundary(&zlib, &output)).block_boundary);
        try t.expectError(error.InvalidBlockPlan, decoder.captureBlockRestart(&dictionary));
        try t.expectEqual(sentinel, dictionary);
        try t.expectEqualSlices(u8, block, (try decoder.captureBlockRestart(&output)).history);
    }
}
