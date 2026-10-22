const std = @import("std");
const archive = @import("archive.zig");
const format = @import("format.zig");

const payload_len = 16 * 1024;

fn fixtureAlloc(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, text);
    return allocator.realloc(bytes, written);
}

fn expectedPayload() [payload_len]u8 {
    var payload: [payload_len]u8 = undefined;
    var state: u32 = 0x8f12_3456;
    for (payload[0 .. payload_len / 2]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(payload[payload_len / 2 ..], payload[0 .. payload_len / 2]);
    return payload;
}

test "EROFS final big pclusters use explicit physical counts for full and compact indexes" {
    const allocator = std.testing.allocator;
    const expected = expectedPayload();
    inline for (.{ "full", "compact" }) |layout| {
        const bytes = try fixtureAlloc(allocator, @embedFile("testdata/lz4-" ++ layout ++ "-final-big.erofs.b64"));
        defer allocator.free(bytes);
        const parsed = try archive.Archive.init(bytes);
        const inode_value = try parsed.lookup(allocator, "tail.bin", payload_len, 4096);
        try std.testing.expect(inode_value.compressed_advise & 2 != 0);
        try std.testing.expectEqual(
            if (std.mem.eql(u8, layout, "full")) format.Layout.compressed_full else format.Layout.compressed_compact,
            inode_value.layout,
        );
        const decoded = try parsed.readFlatAllocLimited(allocator, inode_value, payload_len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &expected, decoded);
        try std.testing.expectError(error.OutputLimitExceeded, parsed.readFlatAllocLimited(allocator, inode_value, payload_len - 1));
    }
}

test "EROFS rejects zero missing excessive and out of image pcluster counts" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/lz4-full-final-big.erofs.b64"));
    defer allocator.free(bytes);
    const parsed = try archive.Archive.init(bytes);
    const inode_value = try parsed.lookup(allocator, "tail.bin", payload_len, 4096);
    const count_offset = inode_value.compressed_index_start + 8 + 4;
    try std.testing.expectEqual(@as(u16, 0x803), format.readU16(bytes, count_offset));
    for ([_]u16{ 0x800, 0x901, 1 }) |invalid| {
        std.mem.writeInt(u16, bytes[count_offset..][0..2], invalid, .little);
        try std.testing.expectError(error.InvalidErofs, parsed.readFlatAllocLimited(allocator, inode_value, payload_len));
    }
    std.mem.writeInt(u16, bytes[count_offset..][0..2], 0x804, .little);
    try std.testing.expectError(error.TruncatedFrame, parsed.readFlatAllocLimited(allocator, inode_value, payload_len));
    std.mem.writeInt(u16, bytes[count_offset..][0..2], 0x803, .little);
    var unsupported = inode_value;
    unsupported.compressed_advise &= ~@as(u16, 6);
    try std.testing.expectError(error.InvalidErofs, parsed.readFlatAllocLimited(allocator, unsupported, payload_len));
}

test "EROFS final big pcluster extraction releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const bytes = try fixtureAlloc(allocator, @embedFile("testdata/lz4-compact-final-big.erofs.b64"));
            defer allocator.free(bytes);
            const parsed = try archive.Archive.init(bytes);
            const decoded = try parsed.extractByPathAllocLimited(allocator, "tail.bin", payload_len, 4096);
            defer allocator.free(decoded);
            const expected = expectedPayload();
            try std.testing.expectEqualSlices(u8, &expected, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
