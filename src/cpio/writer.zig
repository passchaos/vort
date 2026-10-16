const std = @import("std");
const archive = @import("archive.zig");
const wire = @import("wire.zig");

pub const Error = wire.Error;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    kind: archive.Kind = .regular,
    permissions: ?u16 = null,
    uid: u32 = 0,
    gid: u32 = 0,
    mtime: u32 = 0,
    device_major: u32 = 0,
    device_minor: u32 = 0,
    rdevice_major: u32 = 0,
    rdevice_minor: u32 = 0,
};

pub const EncodeOptions = struct {
    format: archive.Format = .newc,
    block_size: usize = 512,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    if (options.block_size > 1024 * 1024) return error.InvalidCpioOptions;
    try validateEntries(entries);
    const start = output.items.len;
    errdefer output.items.len = start;

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    for (entries, 0..) |entry, index| {
        const inode = std.math.cast(u32, index + 1) orelse return error.CpioFieldOverflow;
        try wire.appendEntry(allocator, &encoded, 0, entry.name, entry.data, .{
            .inode = inode,
            .mode = try wire.modeFor(entry.kind, entry.permissions),
            .uid = entry.uid,
            .gid = entry.gid,
            .link_count = 1,
            .mtime = entry.mtime,
            .device_major = entry.device_major,
            .device_minor = entry.device_minor,
            .rdevice_major = entry.rdevice_major,
            .rdevice_minor = entry.rdevice_minor,
        }, options.format);
    }
    try wire.appendEntry(allocator, &encoded, 0, archive.trailer_name, "", .{
        .inode = 0,
        .mode = 0,
        .uid = 0,
        .gid = 0,
        .link_count = 1,
        .mtime = 0,
        .device_major = 0,
        .device_minor = 0,
        .rdevice_major = 0,
        .rdevice_minor = 0,
    }, options.format);
    if (options.block_size != 0)
        try wire.appendPadding(
            allocator,
            &encoded,
            wire.paddingFor(encoded.items.len, options.block_size),
        );

    try output.appendSlice(allocator, encoded.items);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        try wire.validateName(entry.name);
        try wire.validateDataKind(entry.kind, entry.data.len);
    }
}

test "CPIO writer round trips all common header formats" {
    const allocator = std.testing.allocator;
    const binary = [_]u8{ 0, 1, 2, 0xff, 0x80 } ** 32;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.txt", .data = "cpio payload" },
        .{ .name = "dir", .kind = .directory },
        .{ .name = "dir/data.bin", .data = &binary, .permissions = 0o600 },
        .{ .name = "link", .data = "dir/data.bin", .kind = .symlink },
    };
    inline for (std.meta.tags(archive.Format)) |format| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .format = format });
        defer allocator.free(encoded);
        const second = try encodeAlloc(allocator, &entries, .{ .format = format });
        defer allocator.free(second);
        try std.testing.expectEqualSlices(u8, encoded, second);
        const parsed = try archive.parse(encoded);
        try std.testing.expectEqual(format, parsed.format);
        try std.testing.expectEqual(entries.len, parsed.entry_count);
        for (entries, 0..) |expected, index| {
            const entry = try parsed.entryAt(index);
            try std.testing.expectEqualStrings(expected.name, entry.name);
            try std.testing.expectEqual(expected.kind, entry.kind);
            if (entry.isExtractable()) {
                const decoded = try parsed.extractAlloc(allocator, entry);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }
        }
    }
}

test "CPIO parser rejects truncation padding and CRC corruption" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "checksum" }};
    const encoded = try encodeAlloc(allocator, &entries, .{ .format = .crc });
    defer allocator.free(encoded);
    for (0..archive.newc_header_size) |length|
        try std.testing.expectError(error.TruncatedFrame, archive.parse(encoded[0..length]));

    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[entry.data_offset] ^= 1;
    const corrupt_archive = try archive.parse(corrupt);
    const corrupt_entry = try corrupt_archive.entryAt(0);
    var output: ["checksum".len]u8 = undefined;
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt_archive.extractInto(corrupt_entry, &output),
    );

    const bad_padding = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_padding);
    bad_padding[entry.data_offset - 1] = 1;
    try std.testing.expectError(error.InvalidCpioArchive, archive.parse(bad_padding));
}

test "CPIO writer rejects unsafe names and invalid special data" {
    const invalid = [_][]const u8{ "", "/absolute", "../escape", "a/../b", "a//b", archive.trailer_name };
    for (invalid) |name| {
        const entries = [_]EncodeEntry{.{ .name = name }};
        try std.testing.expectError(
            error.InvalidCpioEntryName,
            encodeAlloc(std.testing.allocator, &entries, .{}),
        );
    }
    const directory = [_]EncodeEntry{.{ .name = "dir", .kind = .directory, .data = "bad" }};
    try std.testing.expectError(
        error.InvalidCpioOptions,
        encodeAlloc(std.testing.allocator, &directory, .{}),
    );
}

test "CPIO extraction resolves newc hard-link payload groups" {
    const allocator = std.testing.allocator;
    inline for (.{ archive.Format.newc, .crc }) |format| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        const metadata = wire.Metadata{
            .inode = 7,
            .mode = archive.mode_regular | 0o644,
            .uid = 0,
            .gid = 0,
            .link_count = 2,
            .mtime = 0,
            .device_major = 0,
            .device_minor = 1,
            .rdevice_major = 0,
            .rdevice_minor = 0,
        };
        try wire.appendEntry(allocator, &encoded, 0, "first", "", metadata, format);
        try wire.appendEntry(allocator, &encoded, 0, "second", "hard-link-data", metadata, format);
        try wire.appendEntry(allocator, &encoded, 0, archive.trailer_name, "", .{
            .inode = 0,
            .mode = 0,
            .uid = 0,
            .gid = 0,
            .link_count = 1,
            .mtime = 0,
            .device_major = 0,
            .device_minor = 0,
            .rdevice_major = 0,
            .rdevice_minor = 0,
        }, format);
        const parsed = try archive.parse(encoded.items);
        const first = try parsed.entryAt(0);
        try std.testing.expectEqual(@as(usize, "hard-link-data".len), try parsed.contentSize(first));
        const data = try parsed.extractAlloc(allocator, first);
        defer allocator.free(data);
        try std.testing.expectEqualStrings("hard-link-data", data);
    }
}

test "CPIO reader classifies unsafe archived paths without materializing them" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try wire.appendEntry(allocator, &encoded, 0, "../escape", "data", .{
        .inode = 1,
        .mode = archive.mode_regular | 0o644,
        .uid = 0,
        .gid = 0,
        .link_count = 1,
        .mtime = 0,
        .device_major = 0,
        .device_minor = 0,
        .rdevice_major = 0,
        .rdevice_minor = 0,
    }, .newc);
    try wire.appendEntry(allocator, &encoded, 0, archive.trailer_name, "", .{
        .inode = 0,
        .mode = 0,
        .uid = 0,
        .gid = 0,
        .link_count = 1,
        .mtime = 0,
        .device_major = 0,
        .device_minor = 0,
        .rdevice_major = 0,
        .rdevice_minor = 0,
    }, .newc);
    const parsed = try archive.parse(encoded.items);
    const entry = try parsed.entryAt(0);
    try std.testing.expect(!entry.safe_path);
    const data = try parsed.extractAlloc(allocator, entry);
    defer allocator.free(data);
    try std.testing.expectEqualStrings("data", data);
}
