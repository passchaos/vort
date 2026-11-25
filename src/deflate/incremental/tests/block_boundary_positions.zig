//! Exact compressed and decoded coordinates for incremental Deflate checkpoints.
const std = @import("std");
const core = @import("../../../core.zig");
const deflate = @import("../../../deflate.zig");
const deflate64 = @import("../../../deflate64.zig");
const wide = @import("wide_decode/helpers.zig");

const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;
const Position = deflate.BlockBoundaryPosition;

// libz 1.2.11, level 6, Z_FIXED: c8..cc then Z_BLOCK, 'B' then Z_FINISH.
// 3 + 5*9 + 7 = 55 bits for the first block, then 3 + 8 + 7 = 18 bits.
// Set all seven ignored final padding bits to distinguish the EOB from padding.
const fixed = [_]u8{ 0x3a, 0x71, 0xf2, 0xd4, 0xe9, 0x33, 0x80, 0x39, 0x01, 0xfe };
const plain = "\xc8\xc9\xca\xcb\xccB";
const first_output = plain.len - 1;

fn pos(byte: core.StreamCount, bit: u3, decoded: core.StreamCount) Position {
    return .{ .compressed_byte_offset = byte, .compressed_bit_offset = bit, .decoded_offset = decoded };
}

fn expectPosition(decoder: anytype, expected: ?Position) !void {
    try std.testing.expectEqual(expected, decoder.blockBoundaryPosition());
}

fn expectPause(result: core.StepResult, consumed: usize, published: usize) !void {
    try std.testing.expect(result.block_boundary);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(consumed, result.progress.input_read);
    try std.testing.expectEqual(published, result.progress.output_written);
}

test "raw stepToBlockBoundary reports bit coordinates before final padding" {
    inline for (.{ Raw, deflate64.IncrementalDecoder }) |Decoder| {
        var history: [Decoder.required_history_len]u8 = undefined;
        var decoder = try Decoder.initWithHistory(.{}, &history);
        try expectPosition(&decoder, pos(0, 0, 0));

        var output: [plain.len + 1]u8 = undefined;
        const partial = try decoder.stepToBlockBoundary(fixed[0..1], &output);
        try std.testing.expectEqual(.need_input, partial.status);
        try std.testing.expect(!partial.block_boundary);
        try expectPosition(&decoder, null);

        const checkpoint = try decoder.stepToBlockBoundary(fixed[1..7], &output);
        try expectPause(checkpoint, 6, first_output);
        try expectPosition(&decoder, pos(6, 7, first_output));
        const last = try decoder.stepToBlockBoundary(fixed[7..], output[first_output..]);
        try std.testing.expectEqual(.done, last.status);
        try std.testing.expect(!last.block_boundary);
        try std.testing.expectEqual(fixed.len - 7, last.progress.input_read);
        try std.testing.expectEqual(@as(usize, 1), last.progress.output_written);
        try std.testing.expectEqualSlices(u8, plain, output[0..plain.len]);
        try expectPosition(&decoder, pos(9, 1, plain.len));
        try decoder.finish();
        try expectPosition(&decoder, pos(9, 1, plain.len));
        try std.testing.expectError(error.TrailingData, decoder.step("!", &.{}));
        try expectPosition(&decoder, null);
        decoder.reset();
        try expectPosition(&decoder, pos(0, 0, 0));
    }
}

test "stored Deflate block boundary position retains the pending header start" {
    var decoder = deflate.RawDeflateIncrementalStoredDecoder.init();
    var output: [3]u8 = undefined;
    try expectPause(try decoder.stepToBlockBoundary(&wide.prefix, &output), wide.prefix.len, 1);
    try expectPosition(&decoder, pos(wide.prefix.len, 0, 1));

    const next = &wide.final_stored;
    const partial = try decoder.stepToBlockBoundary(next[0..2], output[1..]);
    try std.testing.expectEqual(.need_input, partial.status);
    try std.testing.expect(!partial.block_boundary);
    try std.testing.expectEqual(@as(usize, 2), partial.progress.input_read);
    try expectPosition(&decoder, pos(wide.prefix.len, 0, 1));

    const header = try decoder.step(next[2..5], output[1..]);
    try std.testing.expectEqual(.need_input, header.status);
    try expectPosition(&decoder, null);
    const last = try decoder.stepToBlockBoundary(next[5..], output[1..]);
    try std.testing.expectEqual(.done, last.status);
    try std.testing.expect(!last.block_boundary);
    try std.testing.expectEqualSlices(u8, "xxx", &output);
    try expectPosition(&decoder, pos(wide.prefix.len + next.len, 0, output.len));

    decoder.reset();
    try std.testing.expectError(error.StoredLengthMismatch, decoder.step(&.{ 1, 0, 0, 0, 0 }, &.{}));
    try expectPosition(&decoder, null);
}

test "wrapped stepToBlockBoundary reports absolute member coordinates" {
    const Zlib = deflate.ZlibIncrementalDecoder;
    const Gzip = deflate.GzipIncrementalDecoder;
    const Auto = deflate.ZlibOrGzipIncrementalDecoder;
    const zlib = wide.zlib_header ++ fixed ++ [_]u8{ 0x10, 0x06, 0x04, 0x35 };
    const gzip = wide.gzip_header ++ fixed ++ [_]u8{ 0xed, 0x78, 0xeb, 0xd3, 6, 0, 0, 0 };
    const cases = .{
        .{ Zlib, &zlib, wide.zlib_header.len }, .{ Auto, &zlib, wide.zlib_header.len },
        .{ Gzip, &gzip, wide.gzip_header.len }, .{ Auto, &gzip, wide.gzip_header.len },
    };
    var history: [Raw.required_history_len]u8 = undefined;
    inline for (cases) |case| {
        const wire: []const u8 = case[1];
        const header_len = case[2];
        const footer = header_len + fixed.len;
        var decoder = try case[0].init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
        try expectPosition(&decoder, null);
        for (0..2) |member| {
            const input_base: core.StreamCount = member * wire.len;
            const decoded_base: core.StreamCount = member * plain.len;
            _ = try decoder.step(wire[0..1], &.{});
            try expectPosition(&decoder, null);
            const header = try decoder.step(wire[1..header_len], &.{});
            try std.testing.expect(!header.block_boundary);
            try expectPosition(&decoder, pos(input_base + header_len, 0, decoded_base));

            var output: [plain.len + 1]u8 = undefined;
            const checkpoint = try decoder.stepToBlockBoundary(wire[header_len..][0..7], &output);
            try expectPause(checkpoint, 7, first_output);
            try expectPosition(&decoder, pos(input_base + header_len + 6, 7, decoded_base + first_output));
            const partial_footer = try decoder.stepToBlockBoundary(wire[header_len + 7 .. footer + 1], output[first_output..]);
            try std.testing.expectEqual(.need_input, partial_footer.status);
            try std.testing.expect(!partial_footer.block_boundary);
            try std.testing.expectEqual(@as(usize, 1), partial_footer.progress.output_written);
            try std.testing.expectEqualSlices(u8, plain, output[0..plain.len]);
            try expectPosition(&decoder, null);
            _ = try decoder.step(wire[footer + 1 ..], &.{});
            try std.testing.expectEqual(@as(?core.StreamCount, input_base + wire.len), decoder.memberEndOffset());
            try expectPosition(&decoder, null);
        }

        const probe = try decoder.step(wire[0..1], &.{});
        try std.testing.expectEqual(@as(usize, 1), probe.progress.input_read);
        try expectPosition(&decoder, null);
        const done = try decoder.step("!", &.{});
        try std.testing.expectEqual(.done, done.status);
        try std.testing.expectEqual(@as(usize, 0), done.progress.input_read);
        try std.testing.expectEqualSlices(u8, wire[0..1], decoder.trailingPrefix());
        try expectPosition(&decoder, pos(2 * wire.len, 0, 2 * plain.len));

        decoder.reset();
        _ = try decoder.step(wire[0..header_len], &.{});
        try expectPosition(&decoder, pos(header_len, 0, 0));
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try expectPosition(&decoder, null);
    }
}

test "Deflate block boundary position preserves counts across 4 GiB" {
    var history: [Raw.required_history_len]u8 = undefined;
    var decoder = try Raw.initWithHistory(.{}, &history);
    const blocks = wide.boundary - 2;
    try wide.liftRaw(&decoder, blocks);
    const compressed = blocks * wide.prefix.len;
    try expectPosition(&decoder, pos(compressed, 0, blocks));

    var output: [plain.len + 1]u8 = undefined;
    try expectPause(try decoder.stepToBlockBoundary(fixed[0..7], &output), 7, first_output);
    try expectPosition(&decoder, pos(compressed + 6, 7, blocks + first_output));
    const last = try decoder.step(fixed[7..], output[first_output..]);
    try std.testing.expectEqual(.done, last.status);
    try expectPosition(&decoder, pos(compressed + 9, 1, blocks + plain.len));
}
