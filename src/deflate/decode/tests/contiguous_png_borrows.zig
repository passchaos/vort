//! Scalar PNG setup must not mutate its receiver through decoded/row borrows.
const std = @import("std");

pub fn contracts(comptime D: type) !void {
    const payload = "\x00abc\x02def";
    const encoded = try D.encodeZlibStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var output: [80]u8 = @splat(0xa5);
    var filtered: [80]u8 = @splat(0xb6);
    var previous: [80]u8 = @splat(0xc7);
    var decoder = try D.PngZlibScanlineDecoder.init(encoded, &output, &filtered, &previous, 3, 2, 1);
    const info = try @import("../../../png.zig").pngImageInfo(3, 2, 8, .grayscale);
    inline for (.{ "input", "output", "filtered", "previous" }) |kind| {
        const snapshot = decoder.snapshot();
        const output_before = output;
        const filtered_before = filtered;
        const previous_before = previous;
        const receiver = std.mem.asBytes(&decoder);
        const input: []const u8 = if (comptime std.mem.eql(u8, kind, "input")) receiver[0..2] else encoded;
        const out: []u8 = if (comptime std.mem.eql(u8, kind, "output")) receiver else &output;
        const row: []u8 = if (comptime std.mem.eql(u8, kind, "filtered")) receiver else &filtered;
        const prior: []u8 = if (comptime std.mem.eql(u8, kind, "previous")) receiver else &previous;
        try std.testing.expectError(error.InvalidBlockPlan, decoder.reset(input, out, row, prior, 3, 2, 1));
        try std.testing.expect(std.meta.eql(snapshot, decoder.snapshot()));
        try std.testing.expectError(error.InvalidBlockPlan, decoder.resetWithInfoAndOptions(input, out, row, prior, info, .{}));
        try std.testing.expect(std.meta.eql(snapshot, decoder.snapshot()));
        try std.testing.expectEqualSlices(u8, &output_before, &output);
        try std.testing.expectEqualSlices(u8, &filtered_before, &filtered);
        try std.testing.expectEqualSlices(u8, &previous_before, &previous);
        try decoder.reset(encoded, &output, &filtered, &previous, 3, 2, 1);
        try std.testing.expectEqualSlices(u8, payload, decoder.zlib.decoded);
    }
}
