const std = @import("std");
const deflate = @import("../../../deflate.zig");
const t = std.testing;
const allocator = t.allocator;

const encoders = .{ deflate.GzipIncrementalFixedEncoder, deflate.GzipIncrementalBestEncoder };
const block_len = 4096;
const payload = "record=alpha message=abcabcabcabcabcabc item=0123456789\n" ** 173 ++
    "record=beta message=qwertyqwertyqwerty item=9876543210\n" ** 149;

fn encode(encoder: anytype, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    var scratch: [257]u8 = undefined;
    const output = scratch[0..output_chunk];
    var read: usize = 0;
    while (read < input.len) {
        const end = @min(input.len, read + input_chunk);
        const result = try encoder.step(input[read..end], output);
        try t.expect(result.status != .done);
        try t.expect(result.progress.input_read <= end - read);
        try t.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
        read += result.progress.input_read;
        try wire.appendSlice(allocator, output[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", output);
        try wire.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) return wire.toOwnedSlice(allocator);
        try t.expectEqual(.need_output, result.status);
        try t.expect(result.progress.output_written != 0);
    }
}

fn expectGzipWire(wire: []const u8, enabled: bool) !void {
    const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;
    var history: [Raw.required_history_len]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{ .expected_output_len = payload.len }, &history);
    var output: [payload.len + 1]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    var previous_boundary: usize = 0;
    var found_marker = false;
    while (true) {
        const result = try decoder.stepToBlockBoundary(wire[read..], output[written..]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        try t.expect(result.block_boundary);
        const position = decoder.blockBoundaryPosition() orelse return error.TestUnexpectedResult;
        const resume_offset: usize = @intCast(position.compressed_byte_offset);
        // Only search at a real empty block end, not inside compressed data.
        if (written == previous_boundary and position.compressed_bit_offset == 0 and resume_offset >= 4 and
            deflate.findRawDeflateSyncPoint(wire[resume_offset - 4 .. resume_offset]) != null)
        {
            try t.expect(enabled);
            if (!found_marker) {
                try t.expect(written > 0 and written < payload.len);
                // Start with no history and stop before the CRC32/ISIZE footer.
                const suffix = try deflate.decodeRawAutoAlloc(allocator, wire[resume_offset .. wire.len - 8]);
                defer allocator.free(suffix);
                try t.expectEqualSlices(u8, payload[written..], suffix);
            }
            found_marker = true;
        }
        previous_boundary = written;
    }
    try decoder.finish();
    try t.expectEqual(wire.len, read);
    try t.expectEqualSlices(u8, payload, output[0..written]);
    try t.expectEqual(enabled, found_marker);
}

test "Deflate rsyncable gzip is deterministic under backpressure and reset" {
    inline for (encoders) |Encoder| {
        const options: Encoder.Options = .{ .raw = .{ .block_len = block_len, .rsyncable = true } };
        var wide = Encoder.initWithOptions(allocator, options);
        defer wide.deinit();
        const expected = try encode(&wide, payload, payload.len, 257);
        defer allocator.free(expected);
        try expectGzipWire(expected, true);

        var tiny = Encoder.initWithOptions(allocator, options);
        defer tiny.deinit();
        const fragmented = try encode(&tiny, payload, 1, 1);
        defer allocator.free(fragmented);
        try t.expectEqualSlices(u8, expected, fragmented);

        wide.reset();
        var scratch: [257]u8 = undefined;
        const partial = try wide.step(payload[payload.len - 113 ..], &scratch);
        try t.expect(partial.progress.input_read != 0);
        wide.reset();
        const replay = try encode(&wide, payload, 73, 3);
        defer allocator.free(replay);
        try t.expectEqualSlices(u8, expected, replay);
    }
}

test "Deflate rsyncable accepts the unconsumed suffix after a large pending block" {
    const Encoder = deflate.GzipIncrementalBestEncoder;
    const plain = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(plain);
    var rng = std.Random.DefaultPrng.init(0xc9a6_b4d7);
    rng.random().bytes(plain);
    var encoder = Encoder.initWithOptions(allocator, .{ .raw = .{ .rsyncable = true } });
    defer encoder.deinit();

    const wide = try encode(&encoder, plain, plain.len, 3);
    defer allocator.free(wide);
    encoder.reset();
    const split = try encode(&encoder, plain, 7777, 257);
    defer allocator.free(split);
    try t.expectEqualSlices(u8, wide, split);
    const decoded = try deflate.decodeGzipAlloc(allocator, wide);
    defer allocator.free(decoded);
    try t.expectEqualSlices(u8, plain, decoded);
}

test "Deflate rsyncable gzip is disabled by default" {
    inline for (encoders) |Encoder| {
        var implicit = Encoder.initWithOptions(allocator, .{ .raw = .{ .block_len = block_len } });
        defer implicit.deinit();
        var explicit = Encoder.initWithOptions(allocator, .{ .raw = .{ .block_len = block_len, .rsyncable = false } });
        defer explicit.deinit();
        const default_wire = try encode(&implicit, payload, payload.len, 257);
        defer allocator.free(default_wire);
        const disabled_wire = try encode(&explicit, payload, payload.len, 257);
        defer allocator.free(disabled_wire);
        try t.expectEqualSlices(u8, default_wire, disabled_wire);
        try expectGzipWire(default_wire, false);
    }
}

test "Deflate rsyncable rejects conflicting plans before writing a gzip header" {
    inline for (encoders) |Encoder| {
        const invalid = [_]Encoder.Options{
            .{ .raw = .{ .block_len = block_len, .rsyncable = true, .adaptive_blocks = true } },
            .{ .raw = .{ .block_len = block_len, .rsyncable = true, .low_entropy_block_len = 2 * block_len } },
            .{ .raw = .{ .block_len = block_len, .rsyncable = true, .lookahead_len = 17 } },
        };
        for (invalid) |options| {
            var encoder = Encoder.initWithOptions(allocator, options);
            defer encoder.deinit();
            const before = encoder.snapshot();
            const sentinel: [32]u8 = @splat(0xa5);
            var output = sentinel;
            try t.expectError(error.InvalidBlockPlan, encoder.step(payload[0..1], &output));
            try t.expectEqualDeep(before, encoder.snapshot());
            try t.expectEqual(sentinel, output);
        }
    }
}
