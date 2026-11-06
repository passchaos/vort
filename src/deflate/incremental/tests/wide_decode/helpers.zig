const std = @import("std");
pub const core = @import("../../../../core.zig");
pub const counts = core.stream_count;
pub const Count = core.StreamCount;
pub const checksum = @import("../../../../checksum.zig");
pub const allocator = std.testing.allocator;
pub const boundary: Count = @as(Count, 1) << 32;

// RFC 1951: nonfinal stored block, LEN=1, NLEN=~1, payload 'x'.
// Every repetition ends byte aligned at the next block header.
pub const prefix = [_]u8{ 0, 1, 0, 0xfe, 0xff, 'x' };
pub const final_stored = [_]u8{ 1, 2, 0, 0xfd, 0xff, 'x', 'x' };
pub const empty_final_stored = [_]u8{ 1, 0, 0, 0xff, 0xff };
pub const zlib_header = [_]u8{ 0x78, 0x01 };
pub const gzip_header = [_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 };

pub fn step(decoder: anytype, wire: []const u8, output: []u8) !core.StepResult {
    const before_input = decoder.total_input;
    const before_output = decoder.total_output;
    const result = try decoder.step(wire, output);
    try std.testing.expectEqual(result.progress.input_read, try counts.toLocal(decoder.total_input - before_input));
    try std.testing.expectEqual(result.progress.output_written, try counts.toLocal(decoder.total_output - before_output));
    if (@hasField(@TypeOf(decoder.*), "last_step_progress"))
        try std.testing.expectEqualDeep(result.progress, decoder.last_step_progress);
    return result;
}

pub fn firstRaw(decoder: anytype) !void {
    var output: [1]u8 = undefined;
    const result = try step(decoder, &prefix, &output);
    try std.testing.expectEqual(@as(usize, prefix.len), result.progress.input_read);
    try std.testing.expectEqualSlices(u8, "x", &output);
    try std.testing.expect(decoder.atBlockBoundary());
    if (@hasField(@TypeOf(decoder.*), "bit_count")) {
        try std.testing.expectEqual(@as(u6, 0), decoder.bit_count);
        try std.testing.expect(decoder.history_len != 0);
        const last = (decoder.history_pos + decoder.history.len - 1) % decoder.history.len;
        try std.testing.expectEqual(@as(u8, 'x'), decoder.history[last]);
    }
}

/// Summarize N copies of the same complete block, starting from a real first
/// block. This never claims that all N blocks have physically been decoded.
/// At this boundary every parser field is invariant; only cumulative totals
/// and the suffix of the all-'x' ring differ from the actual first block.
pub fn liftRaw(decoder: anytype, blocks: Count) !void {
    try std.testing.expect(blocks != 0);
    try firstRaw(decoder);
    applyRaw(decoder, blocks);
}

pub fn applyRaw(decoder: anytype, blocks: Count) void {
    decoder.total_input = blocks * prefix.len;
    decoder.total_output = blocks;
    if (@hasField(@TypeOf(decoder.*), "history")) {
        decoder.history_len = counts.bounded(blocks, decoder.history.len);
        decoder.history_pos = counts.ringIndex(blocks, decoder.history.len);
        @memset(decoder.history[0..decoder.history_len], 'x');
    }
}

pub fn expectSameRaw(actual: anytype, model: anytype) !void {
    try std.testing.expectEqual(actual.total_input, model.total_input);
    try std.testing.expectEqual(actual.total_output, model.total_output);
    try std.testing.expectEqual(actual.phase, model.phase);
    try std.testing.expectEqual(actual.final_block, model.final_block);
    if (@hasField(@TypeOf(actual.*), "history")) {
        try std.testing.expectEqual(actual.bit_count, model.bit_count);
        try std.testing.expectEqual(actual.bit_buffer, model.bit_buffer);
        try std.testing.expectEqual(actual.history_len, model.history_len);
        try std.testing.expectEqual(actual.history_pos, model.history_pos);
        try std.testing.expectEqualSlices(u8, actual.history[0..actual.history_len], model.history[0..model.history_len]);
        try std.testing.expectEqual(actual.code_bits, model.code_bits);
        try std.testing.expectEqual(actual.stored_remaining, model.stored_remaining);
        try std.testing.expectEqual(actual.stored_length_received, model.stored_length_received);
    } else {
        try std.testing.expectEqual(actual.header_received, model.header_received);
        try std.testing.expectEqual(actual.payload_remaining, model.payload_remaining);
    }
}

/// Adler's independent closed recurrence for N bytes with value 120.
pub fn repeatedAdler(blocks: Count) u32 {
    const n: u128 = blocks;
    const modulus = checksum.adler32_modulus;
    const a: u32 = @intCast((1 + 120 * n) % modulus);
    const b: u32 = @intCast((n + 120 * n * (n + 1) / 2) % modulus);
    return (b << 16) | a;
}

/// Binary exponentiation of concatenation, using the public checksum combine
/// operation. Its small-N results are checked against physically decoded bytes.
pub fn repeatedCrc(blocks: Count) u32 {
    var remaining = blocks;
    var digest: u32 = 0;
    var power = checksum.Crc32.hash("x");
    var power_len: u64 = 1;
    while (remaining != 0) {
        if ((remaining & 1) != 0) digest = checksum.crc32Combine(digest, power, power_len);
        remaining >>= 1;
        if (remaining != 0) {
            power = checksum.crc32Combine(power, power, power_len);
            power_len *= 2;
        }
    }
    return digest;
}

pub fn liftWrapper(decoder: anytype, comptime gzip: bool, blocks: Count) !void {
    const header = if (gzip) &gzip_header else &zlib_header;
    const accepted = try step(decoder, header, &.{});
    try std.testing.expectEqual(header.len, accepted.progress.input_read);
    var output: [1]u8 = undefined;
    const result = try step(decoder, &prefix, &output);
    try std.testing.expectEqual(prefix.len, result.progress.input_read);
    try std.testing.expectEqualSlices(u8, "x", &output);
    try std.testing.expect(decoder.atBlockBoundary());
    applyRaw(&decoder.raw, blocks);
    decoder.total_input = blocks * prefix.len + header.len;
    decoder.total_output = blocks;
    if (gzip) {
        decoder.member_output = blocks;
        decoder.crc.value = ~repeatedCrc(blocks);
    } else {
        decoder.stream_output = blocks;
        const adler = repeatedAdler(blocks);
        decoder.adler = .{ .a = adler & 0xffff, .b = adler >> 16 };
    }
}

pub fn footer(comptime gzip: bool, blocks: Count, suffix: []const u8) [if (gzip) 8 else 4]u8 {
    var bytes: [if (gzip) 8 else 4]u8 = undefined;
    if (gzip) {
        const crc = checksum.crc32Combine(repeatedCrc(blocks), checksum.Crc32.hash(suffix), suffix.len);
        std.mem.writeInt(u32, bytes[0..4], crc, .little);
        std.mem.writeInt(u32, bytes[4..8], @truncate(blocks + suffix.len), .little);
    } else {
        const adler = checksum.adler32Combine(repeatedAdler(blocks), checksum.Adler32.hash(suffix), suffix.len);
        std.mem.writeInt(u32, &bytes, adler, .big);
    }
    return bytes;
}

pub fn drain(decoder: anytype, wire: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !void {
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    @memset(output, 0xa5);
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try step(decoder, wire[read..@min(wire.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        // Concatenating wrappers remain between members until finish sees EOF.
        if (read == wire.len and written == expected.len and decoder.atBlockBoundary()) break;
        if (read == wire.len and written == expected.len and
            (@hasField(@TypeOf(decoder.*), "member_count") or @hasField(@TypeOf(decoder.*), "stream_count"))) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
}

pub fn localAndWideTypes(comptime Decoder: type) !void {
    try std.testing.expectEqual(Count, @FieldType(Decoder, "total_input"));
    try std.testing.expectEqual(Count, @FieldType(Decoder, "total_output"));
    try std.testing.expectEqual(Count, @FieldType(Decoder.Options, "max_output_len"));
    try std.testing.expectEqual(?Count, @FieldType(Decoder.Options, "expected_output_len"));
    if (@hasField(Decoder, "history_pos")) {
        try std.testing.expectEqual(usize, @FieldType(Decoder, "history_pos"));
        try std.testing.expectEqual(usize, @FieldType(Decoder, "history_len"));
        try std.testing.expectEqual(usize, @FieldType(Decoder, "semantic_generated_end"));
        try std.testing.expectEqual(usize, @FieldType(Decoder, "semantic_delivered"));
    }
}
