//! Explicit Deflate block-boundary pause/checkpoint contracts.
const std = @import("std");
const deflate = @import("../../../deflate.zig");

const payload = "checkpoint block boundary payload " ** 64;

fn encodeAll(encoder: anytype, allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(u8) {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var scratch: [64]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], &scratch);
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.status == .need_input) return error.TruncatedFrame;
    }
    return encoded;
}

fn drainBoundaries(decoder: anytype, encoded: []const u8, output: []u8) !usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var boundaries: usize = 0;
    while (true) {
        const result = try decoder.stepToBlockBoundary(encoded[input_offset..], output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (result.block_boundary) {
            boundaries += 1;
            if (!decoder.atBlockBoundary()) return error.BadBlockBoundary;
            continue;
        }
        switch (result.status) {
            .need_input => {
                if (input_offset == encoded.len and result.progress.input_read == 0 and result.progress.output_written == 0)
                    return error.TruncatedFrame;
            },
            .need_output => {
                if (output_offset == output.len and result.progress.input_read == 0 and result.progress.output_written == 0)
                    return error.OutputTooSmall;
            },
            .done => break,
        }
    }
    if (boundaries == 0) return error.MissingBlockBoundary;
    return output_offset;
}

fn drainOrdinary(decoder: anytype, encoded: []const u8, output: []u8) !usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const result = try decoder.step(encoded[input_offset..], output[output_offset..]);
        if (result.block_boundary) return error.UnexpectedBlockBoundary;
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        switch (result.status) {
            .need_input => if (input_offset == encoded.len and result.progress.input_read == 0 and result.progress.output_written == 0)
                return error.TruncatedFrame,
            .need_output => if (output_offset == output.len and result.progress.input_read == 0 and result.progress.output_written == 0)
                return error.OutputTooSmall,
            .done => break,
        }
    }
    return output_offset;
}

test "raw deflate stepToBlockBoundary pauses at multiple blocks" {
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 64 });
    defer encoder.deinit();
    var encoded = try encodeAll(&encoder, std.testing.allocator, payload);
    defer encoded.deinit(std.testing.allocator);

    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const written = try drainBoundaries(&decoder, encoded.items, output);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var ordinary = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
    const ordinary_written = try drainOrdinary(&ordinary, encoded.items, output);
    try std.testing.expectEqual(payload.len, ordinary_written);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "zlib incremental stepToBlockBoundary pauses at multiple blocks" {
    var encoder = deflate.ZlibIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{ .raw = .{ .block_len = 64 } });
    defer encoder.deinit();
    var encoded = try encodeAll(&encoder, std.testing.allocator, payload);
    defer encoded.deinit(std.testing.allocator);

    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{ .expected_output_len = payload.len }, &history);
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const written = try drainBoundaries(&decoder, encoded.items, output);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var ordinary = try deflate.ZlibIncrementalDecoder.init(.{ .expected_output_len = payload.len }, &history);
    const ordinary_written = try drainOrdinary(&ordinary, encoded.items, output);
    try std.testing.expectEqual(payload.len, ordinary_written);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "gzip incremental stepToBlockBoundary pauses at multiple blocks" {
    var encoder = deflate.GzipIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{ .raw = .{ .block_len = 64 } });
    defer encoder.deinit();
    var encoded = try encodeAll(&encoder, std.testing.allocator, payload);
    defer encoded.deinit(std.testing.allocator);

    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{ .expected_output_len = payload.len }, &history);
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const written = try drainBoundaries(&decoder, encoded.items, output);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var ordinary = try deflate.GzipIncrementalDecoder.init(.{ .expected_output_len = payload.len }, &history);
    const ordinary_written = try drainOrdinary(&ordinary, encoded.items, output);
    try std.testing.expectEqual(payload.len, ordinary_written);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "stored deflate stepToBlockBoundary pauses at multiple blocks" {
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 64 });
    defer encoder.deinit();
    var encoded = try encodeAll(&encoder, std.testing.allocator, payload);
    defer encoded.deinit(std.testing.allocator);

    var decoder = deflate.RawDeflateIncrementalStoredDecoder.initWithOptions(.{ .expected_output_len = payload.len });
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const written = try drainBoundaries(&decoder, encoded.items, output);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var ordinary = deflate.RawDeflateIncrementalStoredDecoder.initWithOptions(.{ .expected_output_len = payload.len });
    const ordinary_written = try drainOrdinary(&ordinary, encoded.items, output);
    try std.testing.expectEqual(payload.len, ordinary_written);
    try std.testing.expectEqualSlices(u8, payload, output);
}
