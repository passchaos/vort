const std = @import("std");
const pbzx = @import("../pbzx.zig");

const allocator = std.testing.allocator;

test "PBZX round trips stored XZ and automatic chunks" {
    const input = ("PBZX compressed payload 0123456789\n" ** 180) ++
        ("tail" ** 257);
    inline for (std.enums.values(pbzx.Compression)) |compression| {
        const encoded = try pbzx.encodeAlloc(allocator, input, .{
            .chunk_size = 1024,
            .compression = compression,
        });
        defer allocator.free(encoded);
        const archive = try pbzx.parse(encoded);
        try std.testing.expect(archive.chunk_count > 1);
        try std.testing.expectEqual(input.len, archive.decoded_size);
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const range_offset = 1024 - 29;
        const range_len = 1024 + 73;
        const range = try archive.decodeRangeAllocLimited(
            allocator,
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

test "PBZX supports an optional final zero marker" {
    const input = "PBZX terminator";
    const encoded = try pbzx.encodeAlloc(allocator, input, .{
        .chunk_size = 32,
        .compression = .stored,
        .end_marker = true,
    });
    defer allocator.free(encoded);
    const archive = try pbzx.parse(encoded);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);
}

test "PBZX rejects malformed headers chunks and bounds" {
    try std.testing.expectError(error.TruncatedFrame, pbzx.parse("pbzx"));
    var bad_magic = [_]u8{0} ** 12;
    std.mem.writeInt(u64, bad_magic[4..12], 16, .big);
    try std.testing.expectError(error.InvalidMagic, pbzx.parse(&bad_magic));

    var zero_chunk_size = [_]u8{0} ** 12;
    @memcpy(zero_chunk_size[0..4], "pbzx");
    try std.testing.expectError(
        error.InvalidPbzx,
        pbzx.parse(&zero_chunk_size),
    );

    const encoded = try pbzx.encodeAlloc(allocator, "payload", .{
        .chunk_size = 16,
        .compression = .stored,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        pbzx.parse(encoded[0 .. encoded.len - 1]),
    );
    const archive = try pbzx.parse(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.decodeAllocLimited(allocator, 6),
    );
    try std.testing.expectError(
        error.RangeOutOfBounds,
        archive.decodeRangeAllocLimited(allocator, 6, 2, 2),
    );

    var bad_terminator = try allocator.alloc(u8, encoded.len + 16 + 1);
    defer allocator.free(bad_terminator);
    @memcpy(bad_terminator[0..encoded.len], encoded);
    @memset(bad_terminator[encoded.len..][0..16], 0);
    bad_terminator[bad_terminator.len - 1] = 1;
    try std.testing.expectError(error.InvalidPbzx, pbzx.parse(bad_terminator));
}
