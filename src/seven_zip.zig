const std = @import("std");
const archive = @import("seven_zip/archive.zig");
const writer = @import("seven_zip/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Kind = @import("seven_zip/types.zig").Kind;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const DecodeOptions = archive.DecodeOptions;
pub const ParseOptions = archive.ParseOptions;
pub const EncodeEntry = writer.EncodeEntry;
pub const Compression = writer.Compression;
pub const Filter = writer.Filter;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseAlloc = archive.parseAlloc;
pub const parseAllocWithOptions = archive.parseAllocWithOptions;
pub fn extractByNameAlloc(allocator: std.mem.Allocator, input: []const u8, name: []const u8) ![]u8 {
    const parsed = try archive.parseAlloc(allocator, input);
    defer parsed.deinit();
    return parsed.extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    name: []const u8,
    max_output_len: usize,
) ![]u8 {
    const parsed = try archive.parseAlloc(allocator, input);
    defer parsed.deinit();
    return parsed.extractByNameAllocLimited(allocator, name, max_output_len);
}
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeStoredAlloc = writer.encodeStoredAlloc;
pub const encodeStoredAppend = writer.encodeStoredAppend;
pub const encodeStoredInto = writer.encodeStoredInto;

test {
    _ = archive;
    _ = @import("seven_zip/number.zig");
    _ = writer;
}

test "7z stored writer round trips files directories and UTF-8 names" {
    const entries = [_]EncodeEntry{
        .{ .name = "hello.txt", .data = "hello seven zip\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-数据.txt", .data = "payload" },
    };
    const encoded = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(entries.len, parsed.entries.len);
    for (entries, parsed.entries) |expected, actual| {
        try std.testing.expectEqualStrings(expected.name, actual.name);
        try std.testing.expectEqual(expected.kind, actual.kind);
        if (actual.folder_index) |_| {
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, actual);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        } else {
            try std.testing.expectEqual(@as(usize, 0), expected.data.len);
        }
    }

    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractEntryAllocLimited(std.testing.allocator, parsed.entries[0], entries[0].data.len - 1),
    );
    try std.testing.expectError(
        error.EntryHasNoStream,
        parsed.extractEntryAlloc(std.testing.allocator, parsed.entries[2]),
    );

    var bad_start_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_start_crc);
    bad_start_crc[8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parseAlloc(std.testing.allocator, bad_start_crc));

    var bad_header_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header_crc);
    bad_header_crc[28] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parseAlloc(std.testing.allocator, bad_header_crc));
}

test "7z writer round trips compression methods" {
    const payload = "Vort common 7z writer payload\n" ** 128;
    const entries = [_]EncodeEntry{.{ .name = "payload.txt", .data = payload }};
    inline for (.{ Compression.copy, Compression.deflate, Compression.bzip2, Compression.lzma, Compression.lzma2, Compression.lzma2_stored }) |compression| {
        const encoded = try encodeAlloc(std.testing.allocator, &entries, .{ .compression = compression });
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, .{ .compression = compression });
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);
        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entries[0].name);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        if (compression == .deflate or compression == .bzip2 or
            compression == .lzma or compression == .lzma2)
            try std.testing.expect(encoded.len < payload.len);
    }
}

test "7z solid writer shares one folder across files" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = "first solid payload\n" ** 64 },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/second.txt", .data = "second solid payload\n" ** 97 },
        .{ .name = "third.bin", .data = "\x90\xe8\x10\x00\x00\x00tail" ** 128 },
    };
    var total_size: usize = 0;
    for (entries) |entry| total_size += entry.data.len;

    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |compression| {
        const options = EncodeOptions{ .compression = compression, .solid = true };
        const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.streams.folders.len);
        try std.testing.expectEqual(@as(usize, 3), parsed.streams.substream_sizes.len);
        try std.testing.expectEqual(@as(usize, 3), parsed.streams.folders[0].substream_count);
        var expected_offset: u64 = 0;
        for (entries, parsed.entries) |expected, actual| {
            if (expected.data.len == 0) {
                try std.testing.expectEqual(@as(?usize, null), actual.folder_index);
                continue;
            }
            try std.testing.expectEqual(@as(?usize, 0), actual.folder_index);
            try std.testing.expectEqual(expected_offset, actual.offset_in_folder);
            expected_offset += expected.data.len;
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, actual);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        }
        try std.testing.expectEqual(@as(u64, @intCast(total_size)), expected_offset);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            parsed.decodeEntryAllocWithOptions(
                std.testing.allocator,
                parsed.entries[0],
                .{
                    .max_output_len = entries[0].data.len,
                    .max_folder_output_len = total_size - 1,
                },
            ),
        );
    }
}

test "7z solid writer preserves filters across substream boundaries" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = "\x90\xe8\x10\x00\x00\x00" ** 128 },
        .{ .name = "second.bin", .data = "\xe9\xf0\xff\xff\xff\x90" ** 129 },
    };
    const filters = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .solid = true,
        .filters = &filters,
    });
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    for (entries) |entry| {
        const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entry.name);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entry.data, decoded);
    }
}

test "7z writer round trips an LZMA2 Delta and BCJ chain" {
    const branch_bytes = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 256;
    const entries = [_]EncodeEntry{.{ .name = "code.bin", .data = branch_bytes }};
    const filter_chain = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .filters = &filter_chain,
    });
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@import("seven_zip/types.zig").Method.lzma2, parsed.entries[0].method.?);
    const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entries[0].name);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, branch_bytes, decoded);
}
