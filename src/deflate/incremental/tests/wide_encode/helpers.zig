const std = @import("std");
pub const core = @import("../../../../core.zig");
pub const Count = core.StreamCount;
pub const counts = core.stream_count;
pub const checksum = @import("../../../../checksum.zig");
pub const allocator = std.testing.allocator;
pub const boundary: Count = @as(Count, 1) << 32;
pub const max_count: Count = std.math.maxInt(Count);
pub const prefix = "xxxxxxxx";

pub fn rawOf(encoder: anytype) if (@hasField(@TypeOf(encoder.*), "raw")) @TypeOf(&encoder.raw) else @TypeOf(encoder) {
    return if (@hasField(@TypeOf(encoder.*), "raw")) &encoder.raw else encoder;
}

pub fn step(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    const result = try encoder.step(input, output);
    const after = encoder.snapshot();
    try std.testing.expectEqual(result.progress.input_read, try counts.toLocal(after.input_read - before.input_read));
    try std.testing.expectEqual(result.progress.output_written, try counts.toLocal(after.output_written - before.output_written));
    return result;
}

pub fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), input_chunk: usize, output_chunk: usize) !void {
    var scratch: [4096]u8 = undefined;
    std.debug.assert(input_chunk != 0 and output_chunk != 0 and output_chunk <= scratch.len);
    var read: usize = 0;
    while (read < input.len) {
        const result = try step(encoder, input[read..@min(input.len, read + input_chunk)], scratch[0..output_chunk]);
        read += result.progress.input_read;
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}

pub fn drain(encoder: anytype, wire: *std.ArrayList(u8), output_chunk: usize, finishing: bool) !void {
    var scratch: [4096]u8 = undefined;
    while (true) {
        const result = try step(encoder, "", scratch[0..output_chunk]);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == (if (finishing) core.StepResult.Status.done else .need_input)) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
        try std.testing.expect(result.progress.output_written != 0);
    }
}

pub fn finish(encoder: anytype, wire: *std.ArrayList(u8), output_chunk: usize) !void {
    encoder.finish();
    try drain(encoder, wire, output_chunk, true);
}

pub fn fullPrefix(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    try feed(encoder, prefix, wire, prefix.len, 128);
    encoder.fullFlush();
    try drain(encoder, wire, 128, false);
    const raw = rawOf(encoder);
    try std.testing.expectEqual(@as(usize, 0), raw.plain.items.len);
    try std.testing.expectEqual(@as(usize, 0), raw.pending.items.len);
    try std.testing.expectEqual(@as(u3, 0), raw.state.bit_index);
    if (@hasField(@TypeOf(raw.*), "history")) {
        try std.testing.expectEqual(@as(usize, 0), raw.history.items.len);
        try std.testing.expectEqual(@as(Count, 0), raw.match_finder.absolute_position);
        try std.testing.expect(!raw.match_finder.initialized);
    }
}

pub fn repeatedAdler(byte: u8, n: Count) u32 {
    const wide: u128 = n;
    const modulus = checksum.adler32_modulus;
    const a: u32 = @intCast((1 + byte * wide) % modulus);
    const b: u32 = @intCast((wide + byte * wide * (wide + 1) / 2) % modulus);
    return (b << 16) | a;
}

pub fn repeatedCrc(byte: u8, n: Count) u32 {
    var remaining = n;
    var digest: u32 = 0;
    var power = checksum.Crc32.hash(&.{byte});
    var power_len: u64 = 1;
    while (remaining != 0) {
        if (remaining & 1 != 0) digest = checksum.crc32Combine(digest, power, power_len);
        remaining >>= 1;
        if (remaining != 0) {
            power = checksum.crc32Combine(power, power, power_len);
            power_len *= 2;
        }
    }
    return digest;
}

pub fn commonTypes(comptime Encoder: type) !void {
    inline for (.{ "total_input", "total_output" }) |field|
        try std.testing.expectEqual(Count, @FieldType(Encoder, field));
    inline for (.{ "input_read", "output_written" }) |field|
        try std.testing.expectEqual(Count, @FieldType(Encoder.Snapshot, field));
    try std.testing.expectEqual(usize, @FieldType(Encoder.Snapshot, "pending_output"));
    try std.testing.expectEqual(usize, @FieldType(Encoder, "pending_offset"));
    const Raw = if (@hasField(Encoder, "raw")) @FieldType(Encoder, "raw") else Encoder;
    try std.testing.expectEqual(Count, @FieldType(Raw.Options, "max_input_len"));
    try std.testing.expectEqual(?Count, @FieldType(Raw, "expected_input_len"));
    if (@hasField(Raw.Options, "block_len"))
        try std.testing.expectEqual(usize, @FieldType(Raw.Options, "block_len"));
}
