const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const Archive = archive_mod.Archive;
const Compression = writer.Compression;
const Entry = writer.Entry;
const encodeAlloc = writer.encodeAlloc;
const block_size: usize = 4096;

test "EROFS writer emits compressed raw and fallback inline tails" {
    const allocator = std.testing.allocator;
    const compressible = "inline-compressed-tail-" ** 300;
    var mixed: [5000]u8 = undefined;
    @memset(mixed[0..4096], 'A');
    fillPseudoRandom(mixed[4096..]);
    var fallback: [4096]u8 = undefined;
    fillPseudoRandom(&fallback);
    const entries = [_]Entry{
        .{ .path = "compressible", .data = compressible },
        .{ .path = "fallback", .data = &fallback },
        .{ .path = "mixed", .data = &mixed },
    };

    inline for (.{ Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .tail_packing = .compressed_inline,
        });
        defer allocator.free(encoded);
        const repeated = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .tail_packing = .compressed_inline,
        });
        defer allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const archive = try Archive.init(encoded);
        try std.testing.expect(
            archive.superblock.feature_incompat & format.feature_incompat_ztailpacking != 0,
        );
        const compressed_inode = try archive.lookup(
            allocator,
            "compressible",
            compressible.len,
            block_size,
        );
        try std.testing.expect(compressed_inode.compressed_inline_size != 0);
        try std.testing.expectEqual(@as(u2, 1), compressed_inode.compressed_inline_kind);
        const compressed_decoded = try archive.readFlatAllocLimited(
            allocator,
            compressed_inode,
            compressible.len,
        );
        defer allocator.free(compressed_decoded);
        try std.testing.expectEqualSlices(u8, compressible, compressed_decoded);

        const mixed_inode = try archive.lookup(allocator, "mixed", mixed.len, block_size);
        try std.testing.expectEqual(@as(usize, 904), mixed_inode.compressed_inline_size);
        try std.testing.expectEqual(@as(u2, 0), mixed_inode.compressed_inline_kind);
        const mixed_decoded = try archive.readFlatAllocLimited(allocator, mixed_inode, mixed.len);
        defer allocator.free(mixed_decoded);
        try std.testing.expectEqualSlices(u8, &mixed, mixed_decoded);

        const fallback_inode = try archive.lookup(
            allocator,
            "fallback",
            fallback.len,
            block_size,
        );
        try std.testing.expectEqual(@as(usize, 0), fallback_inode.compressed_inline_size);
        const fallback_decoded = try archive.readFlatAllocLimited(
            allocator,
            fallback_inode,
            fallback.len,
        );
        defer allocator.free(fallback_decoded);
        try std.testing.expectEqualSlices(u8, &fallback, fallback_decoded);
    }
}

test "EROFS compressed inline writer validates mode and releases allocation failures" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "file", .data = "payload" }}, .{
            .compression = .stored,
            .tail_packing = .compressed_inline,
        }),
    );
    const empty_default = try encodeAlloc(allocator, &.{}, .{ .compression = .lz4 });
    defer allocator.free(empty_default);
    const empty_inline = try encodeAlloc(allocator, &.{}, .{
        .compression = .lz4,
        .tail_packing = .compressed_inline,
    });
    defer allocator.free(empty_inline);
    try std.testing.expectEqualSlices(u8, empty_default, empty_inline);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const payload = "inline OOM payload\n" ** 300;
            const encoded = try encodeAlloc(
                failing_allocator,
                &.{.{ .path = "file", .data = payload }},
                .{ .compression = .lz4, .tail_packing = .compressed_inline },
            );
            defer failing_allocator.free(encoded);
            const archive = try Archive.init(encoded);
            const decoded = try archive.extractByPathAllocLimited(
                failing_allocator,
                "file",
                payload.len,
                block_size,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
