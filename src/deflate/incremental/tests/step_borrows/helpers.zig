const std = @import("std");
pub const deflate = @import("../../../../deflate.zig");
const checksum = @import("../../../../checksum.zig");
pub const allocator = std.testing.allocator;
pub const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;
pub const Zlib = deflate.ZlibIncrementalDecoder;
pub const Gzip = deflate.GzipIncrementalDecoder;
pub const Stored = deflate.RawDeflateIncrementalStoredDecoder;
pub const Auto = deflate.ZlibOrGzipIncrementalDecoder;
pub const Raw64 = @import("../../../../deflate64.zig").IncrementalDecoder;
pub const stored = [_]u8{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f' };
// Two fixed literals followed by a length-four, distance-one recurrence.
pub const fixed = [_]u8{ 0x4b, 0x4c, 0x04, 0x01, 0x00 };

pub const Wire = struct {
    bytes: [64]u8 = @splat(0xa5),
    len: usize,
    prefix: usize,
    pub fn slice(self: *const Wire) []const u8 {
        return self.bytes[0..self.len];
    }
};

pub fn wrap(comptime D: type, compressed: []const u8, payload: []const u8) Wire {
    const prefix: usize = if (D == Raw or D == Raw64 or D == Stored) 0 else if (D == Zlib) 2 else 10;
    const suffix: usize = if (D == Raw or D == Raw64 or D == Stored) 0 else if (D == Zlib) 4 else 8;
    var wire = Wire{ .len = prefix + compressed.len + suffix, .prefix = prefix };
    if (D == Zlib) @memcpy(wire.bytes[0..2], &[_]u8{ 0x78, 0x01 });
    if (D == Gzip) @memcpy(wire.bytes[0..10], &[_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 });
    @memcpy(wire.bytes[prefix..][0..compressed.len], compressed);
    const footer = prefix + compressed.len;
    if (D == Zlib) std.mem.writeInt(u32, wire.bytes[footer..][0..4], checksum.Adler32.hash(payload), .big);
    if (D == Gzip) {
        std.mem.writeInt(u32, wire.bytes[footer..][0..4], checksum.Crc32.hash(payload), .little);
        std.mem.writeInt(u32, wire.bytes[footer + 4 ..][0..4], @intCast(payload.len), .little);
    }
    return wire;
}

pub fn init(comptime D: type, history: []u8) !D {
    return if (D == Raw or D == Raw64) D.initWithHistory(.{}, history) else if (D == Stored) D.init() else D.init(.{}, history);
}

pub fn raw(decoder: anytype) *Raw {
    return if (@TypeOf(decoder.*) == Raw) decoder else &decoder.raw;
}

fn retainedHistory(decoder: anytype) []u8 {
    return if (@TypeOf(decoder.*) == Stored)
        &.{}
    else if (@TypeOf(decoder.*) == Auto)
        decoder.history[0..32768]
    else if (@TypeOf(decoder.*) == Raw64)
        decoder.history
    else
        raw(decoder).history;
}

/// Compare the complete object representation so pause, diagnostics, reservoir,
/// checksum and wrapper progress fields are covered by the same transaction.
pub fn reject(decoder: anytype, input: []const u8, output: []u8, boundary: bool) !void {
    const state = try allocator.dupe(u8, std.mem.asBytes(decoder));
    defer allocator.free(state);
    const history = try allocator.dupe(u8, retainedHistory(decoder));
    defer allocator.free(history);
    const input_before = try allocator.dupe(u8, input);
    defer allocator.free(input_before);
    const output_before = try allocator.dupe(u8, output);
    defer allocator.free(output_before);
    if (boundary)
        try std.testing.expectError(error.InvalidBlockPlan, decoder.stepToBlockBoundary(input, output))
    else
        try std.testing.expectError(error.InvalidBlockPlan, decoder.step(input, output));
    try std.testing.expectEqualSlices(u8, state, std.mem.asBytes(decoder));
    try std.testing.expectEqualSlices(u8, history, retainedHistory(decoder));
    try std.testing.expectEqualSlices(u8, input_before, input);
    try std.testing.expectEqualSlices(u8, output_before, output);
}

pub fn drain(decoder: anytype, input: []const u8, output: []u8) !void {
    var consumed: usize = 0;
    var written: usize = 0;
    for (0..16) |_| {
        const result = try decoder.step(input[consumed..], output[written..]);
        consumed += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) {
            try std.testing.expectEqual(input.len, consumed);
            try std.testing.expectEqual(output.len, written);
            return;
        }
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}
