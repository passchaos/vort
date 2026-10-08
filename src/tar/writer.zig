const std = @import("std");
const archive = @import("archive.zig");

pub const Error = archive.Error || error{
    InvalidTarEntryName,
    TarNumericOverflow,
};

pub const Kind = archive.Kind;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    link_name: []const u8 = "",
    kind: Kind = .file,
    mode: u32 = 0,
    mtime: u64 = 0,
};

pub fn encodeAlloc(allocator: std.mem.Allocator, entries: []const EncodeEntry) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries);
    return output.toOwnedSlice(allocator);
}

/// Append a complete deterministic POSIX TAR archive transactionally.
pub fn encodeAppend(allocator: std.mem.Allocator, output: *std.ArrayList(u8), entries: []const EncodeEntry) !usize {
    try validateEntries(entries);
    var archive_bytes: std.ArrayList(u8) = .empty;
    defer archive_bytes.deinit(allocator);

    for (entries) |entry| {
        var pax: std.ArrayList(u8) = .empty;
        defer pax.deinit(allocator);
        if (entry.name.len > 100) try appendPaxRecord(allocator, &pax, "path", entry.name);
        if (entry.link_name.len > 100) try appendPaxRecord(allocator, &pax, "linkpath", entry.link_name);
        if (pax.items.len != 0) {
            try appendHeader(allocator, &archive_bytes, .{
                .name = "PaxHeaders.X/vort",
                .data = pax.items,
                .kind = .other,
                .mode = 0o644,
            }, 'x');
        }
        try appendHeader(allocator, &archive_bytes, entry, typeFlag(entry.kind));
    }
    try archive_bytes.appendNTimes(allocator, 0, 1024);

    try output.ensureUnusedCapacity(allocator, archive_bytes.items.len);
    output.appendSliceAssumeCapacity(archive_bytes.items);
    return archive_bytes.items.len;
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidTarEntryName;
        if (std.mem.indexOfScalar(u8, entry.link_name, 0) != null) return error.InvalidTarEntryName;
        switch (entry.kind) {
            .file => if (entry.link_name.len != 0) return error.InvalidTarHeader,
            .directory => if (entry.data.len != 0 or entry.link_name.len != 0) return error.InvalidTarHeader,
            .symbolic_link, .hard_link => if (entry.data.len != 0 or entry.link_name.len == 0) return error.InvalidTarHeader,
            .other => return error.UnsupportedTarEntryType,
        }
    }
}

fn appendHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    type_flag: u8,
) !void {
    var header: [512]u8 = @splat(0);
    const header_name = if (entry.name.len <= 100) entry.name else "PaxEntry";
    @memcpy(header[0..header_name.len], header_name);
    try writeOctal(header[100..108], if (entry.mode != 0) entry.mode else defaultMode(entry.kind));
    try writeOctal(header[108..116], 0);
    try writeOctal(header[116..124], 0);
    try writeOctal(header[124..136], entry.data.len);
    try writeOctal(header[136..148], entry.mtime);
    @memset(header[148..156], ' ');
    header[156] = type_flag;
    const header_link = if (entry.link_name.len <= 100) entry.link_name else "";
    @memcpy(header[157..][0..header_link.len], header_link);
    @memcpy(header[257..263], "ustar\x00");
    @memcpy(header[263..265], "00");
    var checksum: u64 = 0;
    for (header) |byte| checksum += byte;
    try writeChecksum(header[148..156], checksum);
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, entry.data);
    const remainder = entry.data.len % 512;
    if (remainder != 0) try output.appendNTimes(allocator, 0, 512 - remainder);
}

fn appendPaxRecord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    key: []const u8,
    value: []const u8,
) !void {
    var digits: usize = 1;
    while (true) {
        const length = digits + 1 + key.len + 1 + value.len + 1;
        const actual_digits = decimalDigits(length);
        if (actual_digits == digits) {
            var buffer: [32]u8 = undefined;
            const prefix = try std.fmt.bufPrint(&buffer, "{d} ", .{length});
            try output.appendSlice(allocator, prefix);
            try output.appendSlice(allocator, key);
            try output.append(allocator, '=');
            try output.appendSlice(allocator, value);
            try output.append(allocator, '\n');
            return;
        }
        digits = actual_digits;
    }
}

fn decimalDigits(value: usize) usize {
    var remaining = value;
    var digits: usize = 1;
    while (remaining >= 10) : (digits += 1) remaining /= 10;
    return digits;
}

fn defaultMode(kind: Kind) u32 {
    return switch (kind) {
        .file => 0o644,
        .directory => 0o755,
        .symbolic_link, .hard_link => 0o777,
        .other => 0o644,
    };
}

fn typeFlag(kind: Kind) u8 {
    return switch (kind) {
        .file => '0',
        .directory => '5',
        .symbolic_link => '2',
        .hard_link => '1',
        .other => unreachable,
    };
}

fn writeOctal(field: []u8, value_arg: anytype) Error!void {
    var value: u64 = @intCast(value_arg);
    @memset(field, '0');
    field[field.len - 1] = 0;
    var position = field.len - 1;
    while (value != 0 and position != 0) {
        position -= 1;
        field[position] = '0' + @as(u8, @intCast(value & 7));
        value >>= 3;
    }
    if (value != 0) return error.TarNumericOverflow;
}

fn writeChecksum(field: []u8, value: u64) Error!void {
    if (field.len != 8) return error.InvalidTarHeader;
    @memset(field, '0');
    field[6] = 0;
    field[7] = ' ';
    var remaining = value;
    var position: usize = 6;
    while (remaining != 0 and position != 0) {
        position -= 1;
        field[position] = '0' + @as(u8, @intCast(remaining & 7));
        remaining >>= 3;
    }
    if (remaining != 0) return error.TarNumericOverflow;
}

test "TAR writer emits deterministic PAX long paths" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    const entries = [_]EncodeEntry{
        .{ .name = "plain.txt", .data = "plain" },
        .{ .name = long_name, .data = "long path" },
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "link", .kind = .symbolic_link, .link_name = long_name },
    };
    const first = try encodeAlloc(allocator, &entries);
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const decoded = try archive.parse(first);
    try std.testing.expectEqual(entries.len, decoded.entry_count);
    const plain = (try decoded.find("plain.txt")).?;
    try std.testing.expect(plain.path.isSafeRelative());
    const plain_data = try decoded.extractAllocLimited(allocator, plain, 5);
    defer allocator.free(plain_data);
    try std.testing.expectEqualSlices(u8, "plain", plain_data);
    try std.testing.expectError(error.OutputLimitExceeded, decoded.extractAllocLimited(allocator, plain, 4));
    const long_entry = (try decoded.find(long_name)).?;
    try std.testing.expectEqualSlices(u8, "long path", long_entry.data);
    const owned_name = try long_entry.path.alloc(allocator);
    defer allocator.free(owned_name);
    try std.testing.expectEqualStrings(long_name, owned_name);
    const link = (try decoded.find("link")).?;
    try std.testing.expectEqualStrings(long_name, link.link_name);
    var empty: [0]u8 = .{};
    try std.testing.expectError(error.UnsupportedTarEntryType, decoded.extractInto(link, &empty));

    try std.testing.expect(!(archive.Path{ .name = "../escape" }).isSafeRelative());
    try std.testing.expect(!(archive.Path{ .name = "/absolute" }).isSafeRelative());
    try std.testing.expect(!(archive.Path{ .name = "C:/windows" }).isSafeRelative());
    try std.testing.expect(!(archive.Path{ .name = "dir\\windows" }).isSafeRelative());

    var corrupt = try allocator.dupe(u8, first);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(error.InvalidTarChecksum, archive.parse(corrupt));
}
