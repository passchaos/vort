const std = @import("std");
const format = @import("wof/format.zig");
const decoder = @import("wof/decoder.zig");
const writer = @import("wof/writer.zig");

pub const Error = format.Error || decoder.Error || writer.Error;
pub const Algorithm = format.Algorithm;
pub const Backing = format.Backing;
pub const Chunk = format.Chunk;
pub const ExternalInfo = format.ExternalInfo;
pub const reparseTag = format.reparse_tag;
pub const parseExternalInfo = format.parseExternalInfo;
pub const parseReparsePoint = format.parseReparsePoint;
pub const encodeExternalInfo = format.encodeExternalInfo;
pub const encodeReparsePoint = format.encodeReparsePoint;
pub const decodeInto = decoder.decodeInto;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodeRangeInto = decoder.decodeRangeInto;
pub const decodeRangeAllocLimited = decoder.decodeRangeAllocLimited;
pub const encodedBound = writer.encodedBound;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = format;
    _ = decoder;
    _ = writer;
}

test "WOF backing streams round trip all file-provider algorithms" {
    const allocator = std.testing.allocator;
    const input = ("WOF compressed payload 0123456789\n" ** 1400) ++
        ("tail" ** 3000);
    inline for (std.enums.values(Algorithm)) |algorithm| {
        const encoded = try encodeAlloc(allocator, input, algorithm);
        defer allocator.free(encoded);
        const backing = try Backing.init(encoded, algorithm, input.len);
        try std.testing.expect(backing.chunk_count > 1);
        if (algorithm == .lzx) {
            try std.testing.expect(encoded.len < input.len / 10);
            try std.testing.expect(!(try backing.chunk(0)).isStored());
        }
        const decoded = try decodeAllocLimited(allocator, backing, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings(input, decoded);
        const range_offset = algorithm.chunkSize() - 17;
        const range_len = @min(algorithm.chunkSize() + 43, input.len - range_offset);
        const range = try decodeRangeAllocLimited(
            allocator,
            backing,
            range_offset,
            range_len,
            range_len,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[range_offset..][0..range_len],
            range,
        );
    }
}

test "WOF rejects malformed cumulative chunk offsets" {
    const allocator = std.testing.allocator;
    const input = "malformed WOF table payload\n" ** 600;
    const encoded = try encodeAlloc(allocator, input, .xpress4k);
    defer allocator.free(encoded);
    var corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    std.mem.writeInt(u32, corrupt[0..4], 0, .little);
    try std.testing.expectError(
        error.InvalidWof,
        Backing.init(corrupt, .xpress4k, input.len),
    );
}

test "WOF decodes pinned wimlib XPRESS4K backing stream" {
    const allocator = std.testing.allocator;
    const encoded_text = @embedFile("wof/testdata/xpress4k-small.wof.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, encoded_text);
    const expected = "WOF pinned XPRESS4K payload 0123456789\n" ** 300;
    const backing = try Backing.init(encoded[0..encoded_len], .xpress4k, expected.len);
    try std.testing.expectEqual(@as(usize, 3), backing.chunk_count);
    for (0..backing.chunk_count) |index|
        try std.testing.expect(!(try backing.chunk(index)).isStored());
    const decoded = try decodeAllocLimited(allocator, backing, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}
