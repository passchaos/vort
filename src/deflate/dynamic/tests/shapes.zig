const std = @import("std");
const admission = @import("../admission.zig");
const huffman = @import("../../../huffman.zig");
pub fn contracts() !void {
    const t = std.testing;
    try admission.validate(.code_lengths, &.{ 1, 1 });
    try admission.validate(.literal_lengths, &.{ 1, 1 });
    try admission.validate(.literal_lengths, &.{1});
    try admission.validate(.distances, &.{1});
    try admission.validate(.distances, &.{ 0, 0 });
    inline for (.{ admission.Alphabet.code_lengths, admission.Alphabet.literal_lengths, admission.Alphabet.distances }) |kind| {
        try t.expectError(error.InvalidHuffmanCode, admission.validate(kind, &.{ 1, 1, 1 }));
        try t.expectError(error.InvalidHuffmanCode, admission.validate(kind, &.{ 2, 2 }));
        try t.expectError(error.InvalidHuffmanCode, admission.validate(kind, &.{7}));
    }
    try t.expectError(error.InvalidHuffmanCode, admission.validate(.code_lengths, &.{1}));
    try t.expectError(error.InvalidHuffmanCode, admission.validate(.code_lengths, &.{0}));
    // Shape admission counts every leaf, including unused reserved symbols.
    // Their actual use remains a codec symbol-decoding error.
    try admission.validate(.distances, &([_]u4{5} ** 32));
    var fixed: [288]u4 = undefined;
    @memset(fixed[0..144], 8);
    @memset(fixed[144..256], 9);
    @memset(fixed[256..280], 7);
    @memset(fixed[280..], 8);
    try admission.validate(.literal_lengths, &fixed);
    // Other codecs and semantic kernel oracles keep the generic builder's
    // incomplete-tree capability, independent of Deflate wire admission.
    _ = try huffman.HuffmanTable(2).init(&.{ 2, 2 });
    _ = try huffman.HuffmanTable(2).Encoder.init(&.{ 2, 2 });
}
