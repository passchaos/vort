//! Exercise the package root's public Raw Deflate borrow admission aliases.
const std = @import("std");

pub fn contracts(comptime R: type) !void {
    const stored = [_]u8{ 0x00, 0x03, 0x00, 0xfc, 0xff, 'a', 'b', 'c', 0x01, 0x03, 0x00, 0xfc, 0xff, 'd', 'e', 'f' };
    var backing: [19]u8 = @splat(0xa5);
    @memcpy(backing[0..stored.len], &stored);
    const before = backing;
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeRawDeflate(backing[0..stored.len], backing[13..19]));
    try std.testing.expectEqualSlices(u8, &before, &backing);
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeRawStoredDeflate(backing[0..stored.len], backing[13..19]));
    try std.testing.expectEqualSlices(u8, &before, &backing);

    const dictionary_wire = [_]u8{ 0x8b, 0x48, 0x44, 0x13, 0x00, 0x00 };
    var preset: [17]u8 = @splat(0xa5);
    @memcpy(preset[0..16], "abcdefghijklmnop");
    const preset_before = preset;
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeRawDeflateWithDictionary(&dictionary_wire, preset[0..16], &preset));
    try std.testing.expectEqualSlices(u8, &preset_before, &preset);

    var recovered = [_]u8{ 0xaa, 0x00, 0x00, 0xff, 0xff, 0x03, 0x00 };
    const recovered_before = recovered;
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeRawDeflateAfterSync(&recovered, recovered[0..1]));
    try std.testing.expectEqualSlices(u8, &recovered_before, &recovered);

    var output: [6]u8 = undefined;
    const result = try R.decodeRawDeflate(backing[0..stored.len], &output);
    try std.testing.expectEqual(stored.len, result.input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}
