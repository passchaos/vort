const std = @import("std");
const B = @import("br");
const wire = [_]u8{ 0xa1, 0xc0, 0x00, 0x00, 0x20, 0xe0, 0x38, 0xbc, 0xde, 0xdd, 0x77, 0x5f, 0x44, 0xa4, 0x1a, 0x24, 0x9f, 0x6a, 0x3c, 0xa7, 0x83, 0xd6, 0xc7, 0x00 };
test "borrow pre-fix cyclic compressed source" {
    var scratch = wire[12..].* ++ wire[0..12].*;
    const before = scratch;
    const chunks = [_][]const u8{ scratch[12..], scratch[0..12] };
    var output: [25]u8 = undefined;
    const result = B.decodeStreamChunksInto(&chunks, &scratch, &output);
    try std.testing.expectEqualSlices(u8, &before, &scratch);
    try std.testing.expectError(error.InvalidBlockPlan, result);
}
test "borrow pre-fix RAW dictionary backing" {
    const raw_wire = [_]u8{ 0xa1, 0xa8, 0x00, 0xc0, 0x2f, 0x01, 0x10, 0xc4, 0x44, 0x09, 0x00 };
    var dictionary = "Kot lomom kolol slona!".*;
    const before = dictionary;
    const prefixes = [_][]const u8{&dictionary};
    var output: [dictionary.len]u8 = undefined;
    const result = B.decodeStreamChunksIntoWithOptions(&.{&raw_wire}, dictionary[0..raw_wire.len], &output, .{ .shared_dictionary = .{ .raw_prefixes = &prefixes } });
    try std.testing.expectEqualSlices(u8, &before, &dictionary);
    try std.testing.expectError(error.InvalidBlockPlan, result);
}
