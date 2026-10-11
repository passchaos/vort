const std = @import("std");
const xar = @import("../xar.zig");

const allocator = std.testing.allocator;

const entries = [_]xar.EncodeEntry{
    .{ .path = "root", .kind = .directory, .mode = 0o755 },
    .{ .path = "root/readme & notes.txt", .data = "XAR nested payload\n" ** 64 },
    .{ .path = "root/random.bin", .data = &random_bytes },
    .{ .path = "root/empty", .data = "" },
    .{ .path = "root/link", .kind = .symlink, .link_target = "readme & notes.txt" },
};

const random_bytes = makeRandomBytes();

fn makeRandomBytes() [1024]u8 {
    @setEvalBranchQuota(5000);
    var output: [1024]u8 = undefined;
    var state: u32 = 0x7861_7221;
    for (&output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    return output;
}

test "XAR writer and reader round trip common codecs" {
    inline for (std.enums.values(xar.Compression)) |compression| {
        const encoded = try xar.encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .checksum = .sha256,
            .copy_if_larger = false,
        });
        defer allocator.free(encoded);
        var archive = try xar.parseAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(@as(usize, 5), archive.entries.len);
        const readme = try archive.extractByPathAllocLimited(
            allocator,
            "root/readme & notes.txt",
            4096,
        );
        defer allocator.free(readme);
        try std.testing.expectEqualStrings(entries[1].data, readme);
        const random = try archive.extractByPathAllocLimited(
            allocator,
            "root/random.bin",
            random_bytes.len,
        );
        defer allocator.free(random);
        try std.testing.expectEqualSlices(u8, &random_bytes, random);
        const empty = try archive.extractByPathAllocLimited(
            allocator,
            "root/empty",
            0,
        );
        defer allocator.free(empty);
        try std.testing.expectEqual(@as(usize, 0), empty.len);
        const link_index = archive.find("root/link").?;
        try std.testing.expectEqualStrings(
            "readme & notes.txt",
            archive.entries[link_index].link_target.?,
        );
    }
}

test "XAR supports all standard TOC checksum algorithms" {
    inline for (std.enums.values(xar.ChecksumAlgorithm)) |algorithm| {
        const encoded = try xar.encodeAlloc(allocator, entries[0..2], .{
            .compression = .zlib,
            .checksum = algorithm,
        });
        defer allocator.free(encoded);
        var archive = try xar.parseAlloc(allocator, encoded, .{});
        defer archive.deinit();
        const decoded = try archive.extractByPathAllocLimited(
            allocator,
            "root/readme & notes.txt",
            4096,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings(entries[1].data, decoded);
    }
}

test "XAR decodes a pinned Apple xar Bzip2 archive" {
    const encoded_text = @embedFile("testdata/apple-xar-bzip2.xar.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(bytes);
    const bytes_len = try base64.decode(bytes, encoded_text);
    var archive = try xar.parseAlloc(allocator, bytes[0..bytes_len], .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), archive.entries.len);
    try std.testing.expectEqual(xar.EntryKind.file, archive.entries[0].kind);
    try std.testing.expectEqual(xar.Encoding.bzip2, archive.entries[0].data.?.encoding);
    const decoded = try archive.extractByPathAllocLimited(allocator, "f1", 16);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hellohellohello\n", decoded);
}

test "XAR verifies TOC archived and extracted checksums" {
    const encoded = try xar.encodeAlloc(allocator, entries[0..2], .{
        .compression = .zlib,
        .checksum = .sha256,
    });
    defer allocator.free(encoded);
    const header = try xar.parseHeader(encoded);

    var bad_toc = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_toc);
    const heap_offset = try header.heapOffset();
    bad_toc[heap_offset] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        xar.parseAlloc(allocator, bad_toc, .{}),
    );

    var bad_heap = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_heap);
    bad_heap[heap_offset + header.checksum_algorithm.digestSize()] ^= 1;
    var archive = try xar.parseAlloc(allocator, bad_heap, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive.extractByPathAllocLimited(
            allocator,
            "root/readme & notes.txt",
            4096,
        ),
    );
}

test "XAR rejects unsafe paths duplicate entries and output overages" {
    try std.testing.expectError(
        error.InvalidXar,
        xar.encodeAlloc(allocator, &.{.{ .path = "../escape", .data = "x" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidXar,
        xar.encodeAlloc(allocator, &.{
            .{ .path = "same", .data = "a" },
            .{ .path = "same", .data = "b" },
        }, .{}),
    );
    const encoded = try xar.encodeAlloc(allocator, entries[0..2], .{});
    defer allocator.free(encoded);
    var archive = try xar.parseAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.extractByPathAllocLimited(
            allocator,
            "root/readme & notes.txt",
            entries[1].data.len - 1,
        ),
    );
    try std.testing.expectError(
        error.UnsupportedXarEntry,
        archive.extractByPathAllocLimited(allocator, "root", 0),
    );
}
