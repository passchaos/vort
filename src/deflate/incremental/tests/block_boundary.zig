//! Explicit Deflate block-boundary pause/checkpoint contracts.
const std = @import("std");
const core = @import("../../../core.zig");
const deflate = @import("../../../deflate.zig");

const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;

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

// libz 1.2.11: level=6, Z_FIXED, compress c8..cd, Z_BLOCK,
// then compress 42 and Z_FINISH. The first EOB begins with seven bits
// left in byte 8, so it can complete without any new byte progress.
const fixed_wire = [_]u8{ 0x3a, 0x71, 0xf2, 0xd4, 0xe9, 0x33, 0x67, 0x01, 0x73, 0x02, 0x00 };
const fixed_output = [_]u8{ 200, 201, 202, 203, 204, 205, 66 };
const fixed_first_input = 8;
const fixed_first_output = 6;

fn expectBoundary(decoder: anytype, result: core.StepResult, input_read: usize, output_written: usize) !void {
    try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
    try std.testing.expect(result.block_boundary);
    try std.testing.expect(decoder.atBlockBoundary());
    try std.testing.expectEqual(input_read, result.progress.input_read);
    try std.testing.expectEqual(output_written, result.progress.output_written);
}

fn expectFixedRemainder(decoder: anytype, wire: []const u8, output: []u8) !void {
    // An ordinary step after the checkpoint must continue rather than repeat it.
    const last = try decoder.step(wire, output[fixed_first_output..]);
    try std.testing.expectEqual(core.StepResult.Status.done, last.status);
    try std.testing.expect(!last.block_boundary);
    try std.testing.expectEqual(wire.len, last.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), last.progress.output_written);
    try std.testing.expectEqualSlices(u8, &fixed_output, output[0..fixed_output.len]);
    try decoder.finish();
}

test "stepToBlockBoundary reports a buffered EOB with zero byte progress" {
    var history: [Raw.required_history_len]u8 = undefined;
    var decoder = try Raw.initWithHistory(.{}, &history);
    var output: [fixed_output.len + 1]u8 = @splat(0);
    const first = try decoder.stepToBlockBoundary(&fixed_wire, output[0..fixed_first_output]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try std.testing.expect(!first.block_boundary);
    try std.testing.expectEqual(@as(usize, fixed_first_input), first.progress.input_read);
    try std.testing.expectEqual(@as(usize, fixed_first_output), first.progress.output_written);

    const rest = fixed_wire[fixed_first_input..];
    const checkpoint = try decoder.stepToBlockBoundary(rest, output[fixed_first_output..]);
    try expectBoundary(&decoder, checkpoint, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), output[fixed_first_output]);
    try expectFixedRemainder(&decoder, rest, &output);
}

test "wrapped stepToBlockBoundary preserves a buffered EOB while draining" {
    const Zlib = deflate.ZlibIncrementalDecoder;
    const Gzip = deflate.GzipIncrementalDecoder;
    const Auto = deflate.ZlibOrGzipIncrementalDecoder;
    const zlib_wire = [_]u8{ 0x78, 0x01 } ++ fixed_wire ++ [_]u8{ 0x15, 0x93, 0x05, 0x02 };
    const gzip_wire = [_]u8{ 0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0x04, 0x03 } ++ fixed_wire ++
        [_]u8{ 0x08, 0x3e, 0xa3, 0x28, 0x07, 0, 0, 0 };
    const cases = .{
        .{ Zlib, &zlib_wire, 2 },  .{ Auto, &zlib_wire, 2 },
        .{ Gzip, &gzip_wire, 10 }, .{ Auto, &gzip_wire, 10 },
    };
    var history: [Raw.required_history_len]u8 = undefined;
    inline for (cases) |case| {
        var decoder = try case[0].init(.{}, &history);
        var output: [fixed_output.len + 1]u8 = @splat(0);
        const first = try decoder.stepToBlockBoundary(case[1], output[0..fixed_first_output]);
        const first_input = case[2] + fixed_first_input;
        try expectBoundary(&decoder, first, first_input, fixed_first_output);
        try expectFixedRemainder(&decoder, case[1][first_input..], &output);
    }
}

test "stepToBlockBoundary reports empty and nonempty stored block ends" {
    const wire = [_]u8{ 0, 0, 0, 0xff, 0xff } ++ // Non-final empty block
        [_]u8{ 0, 1, 0, 0xfe, 0xff, 'a' } ++
        [_]u8{ 1, 1, 0, 0xfe, 0xff, 'b' };
    var history: [Raw.required_history_len]u8 = undefined;
    var decoder = try Raw.initWithHistory(.{}, &history);
    var output: [2]u8 = undefined;
    try expectBoundary(&decoder, try decoder.stepToBlockBoundary(&wire, output[0..0]), 5, 0);
    try expectBoundary(&decoder, try decoder.stepToBlockBoundary(wire[5..], output[0..1]), 6, 1);
    const last = try decoder.stepToBlockBoundary(wire[11..], output[1..]);
    try std.testing.expectEqual(core.StepResult.Status.done, last.status);
    try std.testing.expect(!last.block_boundary);
    try std.testing.expectEqual(@as(usize, 6), last.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), last.progress.output_written);
    try std.testing.expectEqualSlices(u8, "ab", &output);
}

const dynamic_block_len = 12 * 1024;
const dynamic_block_count = 3;

fn dynamicBoundaryOffsets(decoder: anytype, raw: *const Raw, wire: []const u8, plain: []const u8, output: []u8, output_chunk_len: usize, semantic: bool) ![dynamic_block_count - 1]usize {
    var offsets: [dynamic_block_count - 1]usize = undefined;
    var boundary_count: usize = 0;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const output_end = @min(output.len, output_offset + output_chunk_len);
        const stepped = try decoder.stepToBlockBoundary(wire[input_offset..], output[output_offset..output_end]);
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.block_boundary) {
            try std.testing.expect(boundary_count < offsets.len);
            offsets[boundary_count] = input_offset;
            boundary_count += 1;
            try std.testing.expectEqual(core.StepResult.Status.need_input, stepped.status);
            try std.testing.expect(decoder.atBlockBoundary());
            try std.testing.expectEqual(boundary_count * dynamic_block_len, output_offset);
            try std.testing.expectEqual(@as(core.StreamCount, if (semantic) boundary_count else 0), raw.semanticBlocksCompleted());
        } else if (stepped.status == .done) {
            break;
        } else {
            try std.testing.expectEqual(core.StepResult.Status.need_output, stepped.status);
            try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
        }
    }
    try decoder.finish();
    try std.testing.expectEqual(offsets.len, boundary_count);
    try std.testing.expectEqual(wire.len, input_offset);
    try std.testing.expectEqual(plain.len, output_offset);
    try std.testing.expectEqualSlices(u8, plain, output[0..output_offset]);
    try std.testing.expectEqual(@as(core.StreamCount, if (semantic) dynamic_block_count else 0), raw.semanticBlocksCompleted());
    return offsets;
}

test "stepToBlockBoundary reports every semantic block end with or without output backpressure" {
    const allocator = std.testing.allocator;
    const plain = try allocator.alloc(u8, dynamic_block_count * dynamic_block_len);
    defer allocator.free(plain);
    var prng = std.Random.DefaultPrng.init(0x2c93_2026_cdc4_ab31);
    for (plain, 0..) |*byte, i| {
        const roll = prng.random().int(u8);
        byte.* = if (i >= dynamic_block_len and i % dynamic_block_len < 2048)
            plain[i - dynamic_block_len]
        else
            ' ' + roll % 95;
    }
    const output = try allocator.alloc(u8, plain.len + 1);
    defer allocator.free(output);
    const history = try allocator.alloc(u8, Raw.recommended_history_len);
    defer allocator.free(history);
    const workspace = try allocator.create(Raw.SemanticWorkspace);
    defer allocator.destroy(workspace);
    const cases = .{
        .{ Raw, deflate.encodeRawDynamicSplitAlloc },
        .{ deflate.ZlibIncrementalDecoder, deflate.encodeZlibDynamicSplitAlloc },
        .{ deflate.GzipIncrementalDecoder, deflate.encodeGzipDynamicSplitAlloc },
    };
    inline for (cases) |case| {
        const wire = try case[1](allocator, plain, dynamic_block_len, deflate.optionsForLevel(.default));
        defer allocator.free(wire);
        var decoder = if (case[0] == Raw) try Raw.initWithHistory(.{}, history) else try case[0].init(.{}, history);
        const raw = if (case[0] == Raw) &decoder else &decoder.raw;

        const compact = try dynamicBoundaryOffsets(&decoder, raw, wire, plain, output, output.len, false);
        decoder.reset();
        try raw.attachSemanticWorkspace(workspace);
        for ([_]usize{ output.len, 257 }) |chunk_len| {
            const semantic = try dynamicBoundaryOffsets(&decoder, raw, wire, plain, output, chunk_len, true);
            try std.testing.expectEqualSlices(usize, &compact, &semantic);
            decoder.reset();
        }
        const ordinary_written = try drainOrdinary(&decoder, wire, output);
        try std.testing.expectEqual(plain.len, ordinary_written);
        try std.testing.expectEqualSlices(u8, plain, output[0..ordinary_written]);
        try std.testing.expectEqual(@as(core.StreamCount, dynamic_block_count), raw.semanticBlocksCompleted());
    }
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
