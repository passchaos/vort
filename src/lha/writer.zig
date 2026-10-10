const std = @import("std");
const archive = @import("archive.zig");
const crc16 = @import("crc16.zig");
const lh_new = @import("lh_new.zig");

pub const Error = archive.Error || lh_new.Error || error{
    InvalidLhaEntryName,
    LhaHeaderTooLarge,
    LhaFileTooLarge,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    method: archive.Method = .lh5,
};

const deterministic_dos_timestamp: u32 = 0x0021_0000;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
) !usize {
    try validateEntries(entries);
    const start = output.items.len;
    errdefer output.items.len = start;

    var archive_bytes: std.ArrayList(u8) = .empty;
    defer archive_bytes.deinit(allocator);
    for (entries) |entry| {
        var owned_compressed: ?[]u8 = null;
        defer if (owned_compressed) |bytes| allocator.free(bytes);
        const compressed = switch (entry.method) {
            .stored => entry.data,
            .lh5 => blk: {
                const bytes = try lh_new.encodeAlloc(allocator, entry.data, .lh5);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .lh6 => blk: {
                const bytes = try lh_new.encodeAlloc(allocator, entry.data, .lh6);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .lh7 => blk: {
                const bytes = try lh_new.encodeAlloc(allocator, entry.data, .lh7);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .directory => "",
            .unsupported => unreachable,
        };
        if (compressed.len > std.math.maxInt(u32) or entry.data.len > std.math.maxInt(u32))
            return error.LhaFileTooLarge;

        var header: std.ArrayList(u8) = .empty;
        defer header.deinit(allocator);
        try header.appendSlice(allocator, &.{ 0, 0 });
        try header.appendSlice(allocator, methodId(entry.method));
        try appendLe32(allocator, &header, @intCast(compressed.len));
        try appendLe32(allocator, &header, @intCast(entry.data.len));
        try appendLe32(allocator, &header, deterministic_dos_timestamp);
        try header.append(allocator, 0x20);
        try header.append(allocator, 0);
        try header.append(allocator, @intCast(entry.name.len));
        try header.appendSlice(allocator, entry.name);
        try appendLe16(allocator, &header, crc16.compute(entry.data));
        const header_size = header.items.len - 2;
        if (header_size > std.math.maxInt(u8)) return error.LhaHeaderTooLarge;
        header.items[0] = @intCast(header_size);
        var checksum: u8 = 0;
        for (header.items[2..]) |byte| checksum +%= byte;
        header.items[1] = checksum;
        try archive_bytes.appendSlice(allocator, header.items);
        try archive_bytes.appendSlice(allocator, compressed);
    }
    try archive_bytes.append(allocator, 0);
    try output.ensureUnusedCapacity(allocator, archive_bytes.items.len);
    output.appendSliceAssumeCapacity(archive_bytes.items);
    return archive_bytes.items.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, entries);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        if (entry.name.len == 0 or entry.name.len > 233 or
            std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidLhaEntryName;
        if (entry.method == .directory and entry.data.len != 0)
            return error.InvalidLhaEntryName;
        if (entry.method == .unsupported) return error.UnsupportedLhaMethod;
    }
}

fn methodId(method: archive.Method) []const u8 {
    return switch (method) {
        .stored => "-lh0-",
        .lh5 => "-lh5-",
        .lh6 => "-lh6-",
        .lh7 => "-lh7-",
        .directory => "-lhd-",
        .unsupported => unreachable,
    };
}

fn appendLe16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendLe32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "LHA writer round trips stored LH5 LH6 LH7 and directory entries" {
    const allocator = std.testing.allocator;
    const payload = "LHA archive payload\n" ** 64;
    const entries = [_]EncodeEntry{
        .{ .name = "stored.bin", .data = &.{ 0, 1, 2, 3 }, .method = .stored },
        .{ .name = "five.txt", .data = payload, .method = .lh5 },
        .{ .name = "six.txt", .data = payload, .method = .lh6 },
        .{ .name = "seven.txt", .data = payload, .method = .lh7 },
        .{ .name = "empty/", .method = .directory },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, &entries, caller_encoded));
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(allocator, &entries, caller_encoded[0 .. caller_encoded.len - 1]),
    );
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    for (entries) |source| {
        const entry = (try parsed.find(source.name)).?;
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.data, decoded);
    }
}

test "LHA writer rejects invalid names transactionally" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try output.appendSlice(std.testing.allocator, "prefix");
    const before = try std.testing.allocator.dupe(u8, output.items);
    defer std.testing.allocator.free(before);
    const entries = [_]EncodeEntry{.{ .name = "", .data = "bad" }};
    try std.testing.expectError(
        error.InvalidLhaEntryName,
        encodeAppend(std.testing.allocator, &output, &entries),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);
}

test "LHA reader rejects corrupt headers payloads limits and forged entries" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "payload.bin",
        .data = "checked LHA payload",
        .method = .stored,
    }};
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);

    const bad_header = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_header);
    bad_header[2] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, archive.parse(bad_header));
    try std.testing.expectError(
        error.TruncatedFrame,
        archive.parse(encoded[0 .. encoded.len - 2]),
    );

    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractAllocLimited(allocator, entry, entry.uncompressed_size - 1),
    );
    var forged = entry;
    forged.data_offset += 1;
    var output: [entries[0].data.len]u8 = undefined;
    try std.testing.expectError(error.InvalidLhaArchive, parsed.extractInto(forged, &output));

    const bad_payload = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_payload);
    bad_payload[entry.data_offset] ^= 1;
    const corrupt = try archive.parse(bad_payload);
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt.extractInto(try corrupt.entryAt(0), &output),
    );

    const unsupported = try allocator.dupe(u8, encoded);
    defer allocator.free(unsupported);
    @memcpy(unsupported[2..7], "-xx0-");
    var checksum: u8 = 0;
    for (unsupported[2 .. @as(usize, unsupported[0]) + 2]) |byte| checksum +%= byte;
    unsupported[1] = checksum;
    const unsupported_archive = try archive.parse(unsupported);
    try std.testing.expectError(
        error.UnsupportedLhaMethod,
        unsupported_archive.extractInto(try unsupported_archive.entryAt(0), &output),
    );
}
