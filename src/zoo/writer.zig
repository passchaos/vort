const std = @import("std");
const archive = @import("archive.zig");
const crc16 = @import("../lha/crc16.zig");
const lh_new = @import("../lha/lh_new.zig");
const lzd = @import("lzd.zig");

pub const Error = archive.Error || std.mem.Allocator.Error || error{
    InvalidZooEntryName,
    ZooFileTooLarge,
    ZooArchiveTooLarge,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    method: archive.Method = .lzd,
};

const HeaderName = struct {
    directory: []const u8,
    base: []const u8,
    short: [13]u8,
    short_len: usize,
    store_long: bool,
};

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

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendNTimes(allocator, 0, archive.header_size);
    writeArchiveHeader(encoded.items[0..archive.header_size]);

    for (entries) |entry| {
        var owned_compressed: ?[]u8 = null;
        defer if (owned_compressed) |bytes| allocator.free(bytes);
        const compressed = switch (entry.method) {
            .stored => entry.data,
            .lzd => blk: {
                const bytes = try lzd.encodeAlloc(allocator, entry.data);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .lh5 => blk: {
                const bytes = try encodeZooLh5Alloc(allocator, entry.data);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .unsupported => unreachable,
        };
        if (entry.data.len > std.math.maxInt(u32) or compressed.len > std.math.maxInt(u32))
            return error.ZooFileTooLarge;

        const name = try makeHeaderName(entry.name);
        const long_len: usize = if (name.store_long) name.base.len + 1 else 0;
        const directory_len: usize = if (name.directory.len != 0) name.directory.len + 1 else 0;
        const variable_len = try checkedAdd(10, try checkedAdd(long_len, directory_len));
        const directory_size = try checkedAdd(archive.type_2_fixed_size, variable_len);
        const directory_offset = encoded.items.len;
        const data_offset = try checkedAdd(
            directory_offset,
            try checkedAdd(directory_size, archive.file_leader.len),
        );
        const next_offset = try checkedAdd(data_offset, compressed.len);
        if (data_offset > std.math.maxInt(u32) or next_offset > std.math.maxInt(u32))
            return error.ZooArchiveTooLarge;

        var directory: std.ArrayList(u8) = .empty;
        defer directory.deinit(allocator);
        try directory.appendNTimes(allocator, 0, directory_size);
        writeLe32(directory.items, 0, archive.zoo_tag);
        directory.items[4] = 2;
        directory.items[5] = methodId(entry.method);
        writeLe32(directory.items, 6, @intCast(next_offset));
        writeLe32(directory.items, 10, @intCast(data_offset));
        writeLe16(directory.items, 14, 0x0021);
        writeLe16(directory.items, 16, 0);
        writeLe16(directory.items, 18, crc16.compute(entry.data));
        writeLe32(directory.items, 20, @intCast(entry.data.len));
        writeLe32(directory.items, 24, @intCast(compressed.len));
        const versions = minimumVersion(entry.method);
        directory.items[28] = versions.major;
        directory.items[29] = versions.minor;
        @memcpy(directory.items[38..51], &name.short);
        writeLe16(directory.items, 51, @intCast(variable_len));
        directory.items[53] = archive.no_timezone;

        const variable = directory.items[archive.type_2_fixed_size..];
        variable[0] = @intCast(long_len);
        variable[1] = @intCast(directory_len);
        var variable_offset: usize = 2;
        if (name.store_long) {
            @memcpy(variable[variable_offset .. variable_offset + name.base.len], name.base);
            variable_offset += name.base.len;
            variable[variable_offset] = 0;
            variable_offset += 1;
        }
        if (name.directory.len != 0) {
            for (name.directory) |byte| {
                variable[variable_offset] = normalizedSeparator(byte);
                variable_offset += 1;
            }
            variable[variable_offset] = 0;
            variable_offset += 1;
        }
        writeLe16(variable, variable_offset, 2);
        variable_offset += 2;
        variable_offset += 3; // portable attributes default to zero
        variable[variable_offset] = 0;
        variable_offset += 1;
        writeLe16(variable, variable_offset, 0);
        variable_offset += 2;
        std.debug.assert(variable_offset == variable.len);
        writeLe16(directory.items, 54, directoryCrc(directory.items));

        try encoded.appendSlice(allocator, directory.items);
        try encoded.appendSlice(allocator, archive.file_leader);
        try encoded.appendSlice(allocator, compressed);
    }

    var terminal: [archive.type_2_fixed_size]u8 = @splat(0);
    writeLe32(&terminal, 0, archive.zoo_tag);
    terminal[4] = 2;
    terminal[53] = archive.no_timezone;
    writeLe16(&terminal, 54, directoryCrc(&terminal));
    try encoded.appendSlice(allocator, &terminal);

    try output.appendSlice(allocator, encoded.items);
    return output.items.len - start;
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
        _ = try splitName(entry.name);
        if (entry.method == .unsupported) return error.UnsupportedZooMethod;
    }
}

fn makeHeaderName(path: []const u8) Error!HeaderName {
    const split = try splitName(path);
    var short: [13]u8 = @splat(0);
    var short_len: usize = 0;
    var store_long = false;
    if (canStoreShort(split.base)) {
        @memcpy(short[0..split.base.len], split.base);
        short_len = split.base.len;
    } else {
        store_long = true;
        const dot = std.mem.lastIndexOfScalar(u8, split.base, '.');
        const root = if (dot) |index| split.base[0..index] else split.base;
        const extension = if (dot) |index| split.base[index + 1 ..] else "";
        for (root) |byte| {
            if (short_len == 8) break;
            if (byte == '.') continue;
            short[short_len] = shortByte(byte);
            short_len += 1;
        }
        if (short_len == 0) {
            short[0] = '_';
            short_len = 1;
        }
        if (extension.len != 0) {
            short[short_len] = '.';
            short_len += 1;
            for (extension[0..@min(extension.len, 3)]) |byte| {
                short[short_len] = shortByte(byte);
                short_len += 1;
            }
        }
    }
    return .{
        .directory = split.directory,
        .base = split.base,
        .short = short,
        .short_len = short_len,
        .store_long = store_long,
    };
}

const SplitName = struct { directory: []const u8, base: []const u8 };

fn splitName(path: []const u8) Error!SplitName {
    if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null or
        isSeparator(path[0]) or isSeparator(path[path.len - 1]))
    {
        return error.InvalidZooEntryName;
    }
    var component_start: usize = 0;
    var last_separator: ?usize = null;
    for (path, 0..) |byte, index| {
        if (!isSeparator(byte)) continue;
        const component = path[component_start..index];
        if (!safeComponent(component)) return error.InvalidZooEntryName;
        component_start = index + 1;
        last_separator = index;
    }
    const base = path[component_start..];
    if (!safeComponent(base) or base.len > 254) return error.InvalidZooEntryName;
    const directory = if (last_separator) |index| path[0..index] else "";
    if (directory.len > 254) return error.InvalidZooEntryName;
    return .{ .directory = directory, .base = base };
}

fn safeComponent(component: []const u8) bool {
    return component.len != 0 and !std.mem.eql(u8, component, ".") and
        !std.mem.eql(u8, component, "..");
}

fn canStoreShort(base: []const u8) bool {
    if (base.len == 0 or base.len > 12) return false;
    for (base) |byte| {
        if (byte < 0x21 or byte > 0x7e or isSeparator(byte)) return false;
    }
    return true;
}

fn shortByte(byte: u8) u8 {
    if ((byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z') or
        (byte >= '0' and byte <= '9') or byte == '_' or byte == '-')
    {
        return byte;
    }
    return '_';
}

fn writeArchiveHeader(header: []u8) void {
    std.debug.assert(header.len == archive.header_size);
    @memcpy(header[0..20], "ZOO 2.10 Archive.\x1a\x00\x00");
    writeLe32(header, 20, archive.zoo_tag);
    writeLe32(header, 24, archive.header_size);
    writeLe32(header, 28, 0 -% @as(u32, archive.header_size));
    header[32] = 2;
    header[33] = 0;
    header[34] = 1;
    header[41] = 3;
}

fn methodId(method: archive.Method) u8 {
    return switch (method) {
        .stored => 0,
        .lzd => 1,
        .lh5 => 2,
        .unsupported => unreachable,
    };
}

fn minimumVersion(method: archive.Method) struct { major: u8, minor: u8 } {
    return switch (method) {
        .stored, .lzd => .{ .major = 1, .minor = 0 },
        .lh5 => .{ .major = 2, .minor = 1 },
        .unsupported => unreachable,
    };
}

fn directoryCrc(directory: []const u8) u16 {
    std.debug.assert(directory.len >= archive.type_2_fixed_size);
    var value = crc16.update(0, directory[0..54]);
    value = crc16.update(value, &.{ 0, 0 });
    return crc16.update(value, directory[56..]);
}

fn encodeZooLh5Alloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    _ = try lh_new.encodeAppend(allocator, &bytes, input, .lh5);
    // Zoo's LH5 stream carries a 16-bit zero block-count EOF marker after the
    // byte-aligned LHA payload. The original huf_encode_end() writes exactly
    // these two bytes after flushing its last partial byte.
    try bytes.appendSlice(allocator, &.{ 0, 0 });
    return bytes.toOwnedSlice(allocator);
}

fn normalizedSeparator(byte: u8) u8 {
    return if (byte == '\\') '/' else byte;
}

fn isSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn writeLe16(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

fn writeLe32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

test "ZOO writer round trips stored LZD and LH5 entries" {
    const allocator = std.testing.allocator;
    const binary = [_]u8{ 0, 1, 2, 0xff, 0x80 } ** 128;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.txt", .data = "stored payload", .method = .stored },
        .{ .name = "docs/really-long-zoo-name.txt", .data = "lzd payload\n" ** 512, .method = .lzd },
        .{ .name = "bin/data.bin", .data = &binary, .method = .lh5 },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const second = try encodeAlloc(allocator, &entries);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, encoded, second);

    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    var iterator = parsed.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        try std.testing.expect(entry.name.eql(entries[index].name));
        try std.testing.expectEqual(entries[index].method, entry.method);
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entries[index].data, decoded);
    }
}

test "ZOO archive rejects truncation and validates both CRC layers" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "checksum payload", .method = .stored }};
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);

    for (0..encoded.len) |length|
        try std.testing.expectError(error.TruncatedFrame, archive.parse(encoded[0..length]));

    const bad_directory = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_directory);
    bad_directory[archive.header_size + 18] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, archive.parse(bad_directory));

    const bad_payload = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_payload);
    const parsed = try archive.parse(bad_payload);
    const entry = try parsed.entryAt(0);
    bad_payload[entry.data_offset] ^= 1;
    const reparsed = try archive.parse(bad_payload);
    const reparsed_entry = try reparsed.entryAt(0);
    var output: ["checksum payload".len]u8 = undefined;
    try std.testing.expectError(
        error.ChecksumMismatch,
        reparsed.extractInto(reparsed_entry, &output),
    );
}

test "ZOO writer rejects unsafe and oversized names" {
    const invalid = [_][]const u8{ "", "/absolute", "trailing/", "a//b", "../escape", "a/../b" };
    for (invalid) |name| {
        const entries = [_]EncodeEntry{.{ .name = name }};
        try std.testing.expectError(
            error.InvalidZooEntryName,
            encodeAlloc(std.testing.allocator, &entries),
        );
    }
    const long_name = "a" ** 255;
    const entries = [_]EncodeEntry{.{ .name = long_name }};
    try std.testing.expectError(
        error.InvalidZooEntryName,
        encodeAlloc(std.testing.allocator, &entries),
    );
}

test "ZOO reader strips archived parent directory components" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "docs/file", .data = "path" }};
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);

    // The variable area is [long-name length, directory length, directory].
    const variable = entry.header_offset + archive.type_2_fixed_size;
    try std.testing.expectEqual(@as(u8, 0), encoded[variable]);
    try std.testing.expectEqual(@as(u8, 5), encoded[variable + 1]);
    @memcpy(encoded[variable + 2 .. variable + 6], "../s");
    writeLe16(
        encoded,
        entry.header_offset + 54,
        directoryCrc(encoded[entry.header_offset .. entry.header_offset + entry.header_size]),
    );
    const sanitized = try archive.parse(encoded);
    const sanitized_entry = try sanitized.entryAt(0);
    try std.testing.expect(sanitized_entry.name.eql("file"));
}
