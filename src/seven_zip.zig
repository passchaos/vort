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
