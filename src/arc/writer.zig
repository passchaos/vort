const std = @import("std");
const archive = @import("archive.zig");
const crushed = @import("crushed.zig");
const distilled = @import("distilled.zig");
const lzw = @import("lzw.zig");
const old_crunch = @import("old_crunch.zig");
const rle = @import("rle.zig");
const squeeze = @import("squeeze.zig");

pub const Error = archive.Error || error{
    InvalidArcEntryName,
    ArcFileTooLarge,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8,
    method: archive.Method = .crunched_8,
};

const deterministic_date: u16 = 0x0021;
const deterministic_time: u16 = 0;

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
        var owned: ?[]u8 = null;
        defer if (owned) |bytes| allocator.free(bytes);
        const compressed = switch (entry.method) {
            .stored_1, .stored_2 => entry.data,
            .packed_rle => blk: {
                const bytes = try rle.encodeAlloc(allocator, entry.data);
                owned = bytes;
                break :blk bytes;
            },
            .squeezed => blk: {
                const bytes = try squeeze.encodeAlloc(allocator, entry.data);
                owned = bytes;
                break :blk bytes;
            },
            .crunched_5 => blk: {
                const bytes = try old_crunch.encodeAlloc(allocator, entry.data, .method_5);
                owned = bytes;
                break :blk bytes;
            },
            .crunched_6 => blk: {
                const bytes = try old_crunch.encodeAlloc(allocator, entry.data, .method_6);
                owned = bytes;
                break :blk bytes;
            },
            .crunched_7 => blk: {
                const bytes = try old_crunch.encodeAlloc(allocator, entry.data, .method_7);
                owned = bytes;
                break :blk bytes;
            },
            .crunched_8 => blk: {
                const bytes = try lzw.encodeAlloc(allocator, entry.data, .crunched);
                owned = bytes;
                break :blk bytes;
            },
            .squashed => blk: {
                const bytes = try lzw.encodeAlloc(allocator, entry.data, .squashed);
                owned = bytes;
                break :blk bytes;
            },
            .crushed => blk: {
                const bytes = try crushed.encodeAlloc(allocator, entry.data);
                owned = bytes;
                break :blk bytes;
            },
            .distilled => blk: {
                const bytes = try distilled.encodeAlloc(allocator, entry.data);
                owned = bytes;
                break :blk bytes;
            },
            .unsupported => return error.UnsupportedArcMethod,
        };
        if (compressed.len > std.math.maxInt(u32) or entry.data.len > std.math.maxInt(u32))
            return error.ArcFileTooLarge;
        try archive_bytes.append(allocator, 0x1a);
        try archive_bytes.append(allocator, methodId(entry.method));
        var name: [13]u8 = @splat(0);
        @memcpy(name[0..entry.name.len], entry.name);
        try archive_bytes.appendSlice(allocator, &name);
        try appendLe32(allocator, &archive_bytes, @intCast(compressed.len));
        try appendLe16(allocator, &archive_bytes, deterministic_date);
        try appendLe16(allocator, &archive_bytes, deterministic_time);
        try appendLe16(allocator, &archive_bytes, archive.crc16(entry.data));
        if (entry.method != .stored_1)
            try appendLe32(allocator, &archive_bytes, @intCast(entry.data.len));
        try archive_bytes.appendSlice(allocator, compressed);
    }
    try archive_bytes.appendSlice(allocator, &.{ 0x1a, 0 });
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
        if (entry.name.len == 0 or entry.name.len > 12 or
            std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidArcEntryName;
        if (entry.method == .unsupported) return error.UnsupportedArcMethod;
    }
}

fn methodId(method: archive.Method) u8 {
    return switch (method) {
        .stored_1 => 1,
        .stored_2 => 2,
        .packed_rle => 3,
        .squeezed => 4,
        .crunched_5 => 5,
        .crunched_6 => 6,
        .crunched_7 => 7,
        .crunched_8 => 8,
        .squashed => 9,
        .crushed => 10,
        .distilled => 11,
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

test "ARC writer round trips methods one through eleven" {
    const allocator = std.testing.allocator;
    const payload = "ARC archive payload\n" ** 128;
    const entries = [_]EncodeEntry{
        .{ .name = "ONE", .data = payload, .method = .stored_1 },
        .{ .name = "TWO", .data = payload, .method = .stored_2 },
        .{ .name = "PACKED", .data = payload, .method = .packed_rle },
        .{ .name = "SQUEEZED", .data = payload, .method = .squeezed },
        .{ .name = "CRUNCH5", .data = payload, .method = .crunched_5 },
        .{ .name = "CRUNCH6", .data = payload, .method = .crunched_6 },
        .{ .name = "CRUNCH7", .data = payload, .method = .crunched_7 },
        .{ .name = "CRUNCH8", .data = payload, .method = .crunched_8 },
        .{ .name = "SQUASHED", .data = payload, .method = .squashed },
        .{ .name = "CRUSHED", .data = payload, .method = .crushed },
        .{ .name = "DISTILLED", .data = payload, .method = .distilled },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, &entries, caller_encoded));
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    for (entries) |source| {
        const entry = (try parsed.find(source.name)).?;
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.data, decoded);
    }
}

test "ARC append supports prefixes and rejects invalid names transactionally" {
    const allocator = std.testing.allocator;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "MZ-VORT-ARC\n");
    const prefix_len = output.items.len;
    const entries = [_]EncodeEntry{.{ .name = "PAYLOAD", .data = "prefixed ARC" }};
    _ = try encodeAppend(allocator, &output, &entries);
    const parsed = try archive.parse(output.items);
    try std.testing.expectEqual(prefix_len, parsed.prefix_size);
    const decoded = try parsed.extractByNameAllocLimited(
        allocator,
        entries[0].name,
        entries[0].data.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, decoded);

    const before = try allocator.dupe(u8, output.items);
    defer allocator.free(before);
    const invalid = [_]EncodeEntry{.{ .name = "NAME-TOO-LONG", .data = "bad" }};
    try std.testing.expectError(
        error.InvalidArcEntryName,
        encodeAppend(allocator, &output, &invalid),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);
}

test "ARC writer emits a parseable empty archive" {
    const encoded = try encodeAlloc(std.testing.allocator, &.{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 0x1a, 0 }, encoded);
    try std.testing.expectEqual(@as(usize, 0), (try archive.parse(encoded)).entry_count);
}

test "ARC reader rejects forged entries corrupt data and output overages" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "PAYLOAD",
        .data = "checked ARC payload",
        .method = .stored_2,
    }};
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractAllocLimited(allocator, entry, entry.uncompressed_size - 1),
    );
    var forged = entry;
    forged.data_offset += 1;
    var output: [entries[0].data.len]u8 = undefined;
    try std.testing.expectError(error.InvalidArcArchive, parsed.extractInto(forged, &output));

    const corrupt_bytes = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt_bytes);
    corrupt_bytes[entry.data_offset] ^= 1;
    const corrupt = try archive.parse(corrupt_bytes);
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt.extractInto(try corrupt.entryAt(0), &output),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive.parse(encoded[0 .. encoded.len - 3]),
    );
}
