const std = @import("std");
pub const deflate = @import("../../../../deflate.zig");
pub const checksum = @import("../../../../checksum.zig");
pub const Raw = deflate.RawDeflateIncrementalFixedLiteralDecoder;
pub const Raw64 = @import("../../../../deflate64.zig").IncrementalDecoder;
pub const Zlib = deflate.ZlibIncrementalDecoder;
pub const Auto = deflate.ZlibOrGzipIncrementalDecoder;
pub const fixtures = @import("fixtures.zig");

pub fn fill(bytes: []u8) void {
    for (bytes, 0..) |*byte, index| byte.* = @truncate(index * 73 + index / 11);
}

pub fn seed(decoder: anytype, dictionary: []const u8) !void {
    try decoder.seedDictionary(dictionary);
}

pub fn zlib(decoder: anytype) *Zlib {
    return if (@TypeOf(decoder.*) == Zlib) decoder else &decoder.active.zlib;
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

pub fn request(decoder: anytype, frame: []const u8) !void {
    var output: [10]u8 = @splat(0x81);
    try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &output));
    try std.testing.expectEqual(@as(usize, 6), decoder.snapshot().last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().last_step_progress.output_written);
    try std.testing.expectEqualSlices(u8, &(@as([10]u8, @splat(0x81))), &output);
}
