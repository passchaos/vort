const std = @import("std");
const archive = @import("archive.zig");

pub const Error = archive.Error || std.mem.Allocator.Error || error{
    InvalidCpioEntryName,
    InvalidCpioOptions,
    CpioFieldOverflow,
};

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

const Metadata = struct {
    inode: u32,
    mode: u32,
    uid: u32,
    gid: u32,
    link_count: u32,
    mtime: u32,
    device_major: u32,
    device_minor: u32,
    rdevice_major: u32,
    rdevice_minor: u32,
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
        try appendEntry(allocator, &encoded, entry.name, entry.data, .{
            .inode = inode,
            .mode = modeFor(entry),
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
    try appendEntry(allocator, &encoded, archive.trailer_name, "", .{
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
        try appendPadding(allocator, &encoded, paddingFor(encoded.items.len, options.block_size));

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
        if (!archive.isSafePath(entry.name) or
            std.mem.eql(u8, entry.name, archive.trailer_name) or
            std.mem.indexOfScalar(u8, entry.name, 0) != null)
        {
            return error.InvalidCpioEntryName;
        }
        switch (entry.kind) {
            .regular, .symlink => {},
            .directory, .block_device, .character_device, .fifo, .socket => if (entry.data.len != 0) return error.InvalidCpioOptions,
            .unknown => return error.UnsupportedCpioEntry,
        }
    }
}

fn modeFor(entry: EncodeEntry) u32 {
    const type_mode: u32 = switch (entry.kind) {
        .regular => archive.mode_regular,
        .directory => archive.mode_directory,
        .symlink => archive.mode_symlink,
        .block_device => archive.mode_block,
        .character_device => archive.mode_character,
        .fifo => archive.mode_fifo,
        .socket => archive.mode_socket,
        .unknown => unreachable,
    };
    const defaults: u16 = switch (entry.kind) {
        .directory => 0o755,
        .symlink => 0o777,
        else => 0o644,
    };
    return type_mode | (@as(u32, entry.permissions orelse defaults) & 0o7777);
}

fn appendEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    data: []const u8,
    metadata: Metadata,
    format: archive.Format,
) !void {
    const name_size = std.math.add(usize, name.len, 1) catch return error.IntegerOverflow;
    switch (format) {
        .newc, .crc => try appendNewAscii(
            allocator,
            output,
            name,
            name_size,
            data,
            metadata,
            format,
        ),
        .odc => try appendOldAscii(allocator, output, name, name_size, data, metadata),
        .binary_little, .binary_big => try appendBinary(
            allocator,
            output,
            name,
            name_size,
            data,
            metadata,
            format,
        ),
    }
}

fn appendNewAscii(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    name_size: usize,
    data: []const u8,
    metadata: Metadata,
    format: archive.Format,
) !void {
    const name_size_u32 = std.math.cast(u32, name_size) orelse return error.CpioFieldOverflow;
    const data_size = std.math.cast(u32, data.len) orelse return error.CpioFieldOverflow;
    try output.appendSlice(allocator, if (format == .crc) archive.magic_crc else archive.magic_newc);
    inline for (.{
        metadata.inode,
        metadata.mode,
        metadata.uid,
        metadata.gid,
        metadata.link_count,
        metadata.mtime,
        data_size,
        metadata.device_major,
        metadata.device_minor,
        metadata.rdevice_major,
        metadata.rdevice_minor,
        name_size_u32,
        if (format == .crc) archive.byteSum(data) else @as(u32, 0),
    }) |value| try appendNumber(allocator, output, value, 8, 16);
    try appendName(allocator, output, name);
    try appendPadding(allocator, output, paddingFor(output.items.len, 4));
    try output.appendSlice(allocator, data);
    try appendPadding(allocator, output, paddingFor(output.items.len, 4));
}

fn appendOldAscii(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    name_size: usize,
    data: []const u8,
    metadata: Metadata,
) !void {
    if (metadata.device_major != 0 or metadata.rdevice_major != 0)
        return error.CpioFieldOverflow;
    try output.appendSlice(allocator, archive.magic_odc);
    try appendNumber(allocator, output, metadata.device_minor, 6, 8);
    try appendNumber(allocator, output, metadata.inode, 6, 8);
    try appendNumber(allocator, output, metadata.mode, 6, 8);
    try appendNumber(allocator, output, metadata.uid, 6, 8);
    try appendNumber(allocator, output, metadata.gid, 6, 8);
    try appendNumber(allocator, output, metadata.link_count, 6, 8);
    try appendNumber(allocator, output, metadata.rdevice_minor, 6, 8);
    try appendNumber(allocator, output, metadata.mtime, 11, 8);
    try appendNumber(allocator, output, name_size, 6, 8);
    try appendNumber(allocator, output, data.len, 11, 8);
    try appendName(allocator, output, name);
    try output.appendSlice(allocator, data);
}

fn appendBinary(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    name_size: usize,
    data: []const u8,
    metadata: Metadata,
    format: archive.Format,
) !void {
    if (metadata.device_major != 0 or metadata.rdevice_major != 0)
        return error.CpioFieldOverflow;
    const endian: std.builtin.Endian = if (format == .binary_little) .little else .big;
    const inode = std.math.cast(u16, metadata.inode) orelse return error.CpioFieldOverflow;
    const mode = std.math.cast(u16, metadata.mode) orelse return error.CpioFieldOverflow;
    const uid = std.math.cast(u16, metadata.uid) orelse return error.CpioFieldOverflow;
    const gid = std.math.cast(u16, metadata.gid) orelse return error.CpioFieldOverflow;
    const links = std.math.cast(u16, metadata.link_count) orelse return error.CpioFieldOverflow;
    const device = std.math.cast(u16, metadata.device_minor) orelse return error.CpioFieldOverflow;
    const rdevice = std.math.cast(u16, metadata.rdevice_minor) orelse return error.CpioFieldOverflow;
    const names = std.math.cast(u16, name_size) orelse return error.CpioFieldOverflow;
    const size = std.math.cast(u32, data.len) orelse return error.CpioFieldOverflow;
    try appendInt16(allocator, output, archive.binary_magic, endian);
    try appendInt16(allocator, output, device, endian);
    try appendInt16(allocator, output, inode, endian);
    try appendInt16(allocator, output, mode, endian);
    try appendInt16(allocator, output, uid, endian);
    try appendInt16(allocator, output, gid, endian);
    try appendInt16(allocator, output, links, endian);
    try appendInt16(allocator, output, rdevice, endian);
    try appendSplit32(allocator, output, metadata.mtime, endian);
    try appendInt16(allocator, output, names, endian);
    try appendSplit32(allocator, output, size, endian);
    try appendName(allocator, output, name);
    try appendPadding(allocator, output, paddingFor(output.items.len, 2));
    try output.appendSlice(allocator, data);
    try appendPadding(allocator, output, paddingFor(output.items.len, 2));
}

fn appendName(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8) !void {
    try output.appendSlice(allocator, name);
    try output.append(allocator, 0);
}

fn appendNumber(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    raw_value: anytype,
    width: usize,
    radix: u8,
) !void {
    var field: [16]u8 = @splat('0');
    std.debug.assert(width <= field.len);
    var value: u64 = @intCast(raw_value);
    var index = width;
    while (index != 0 and value != 0) {
        index -= 1;
        const digit: u8 = @intCast(value % radix);
        field[index] = if (digit < 10) '0' + digit else 'A' + digit - 10;
        value /= radix;
    }
    if (value != 0) return error.CpioFieldOverflow;
    try output.appendSlice(allocator, field[0..width]);
}

fn appendInt16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
    endian: std.builtin.Endian,
) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, endian);
    try output.appendSlice(allocator, &bytes);
}

fn appendSplit32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
    endian: std.builtin.Endian,
) !void {
    try appendInt16(allocator, output, @truncate(value >> 16), endian);
    try appendInt16(allocator, output, @truncate(value), endian);
}

fn appendPadding(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    count: usize,
) !void {
    try output.appendNTimes(allocator, 0, count);
}

fn paddingFor(offset: usize, alignment: usize) usize {
    if (alignment == 0) return 0;
    return (alignment - offset % alignment) % alignment;
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
        const metadata = Metadata{
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
        try appendEntry(allocator, &encoded, "first", "", metadata, format);
        try appendEntry(allocator, &encoded, "second", "hard-link-data", metadata, format);
        try appendEntry(allocator, &encoded, archive.trailer_name, "", .{
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
    try appendEntry(allocator, &encoded, "../escape", "data", .{
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
    try appendEntry(allocator, &encoded, archive.trailer_name, "", .{
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
