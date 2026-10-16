const std = @import("std");
const archive = @import("archive.zig");

pub const Error = archive.Error || error{
    InvalidTarEntryName,
    TarNumericOverflow,
};

pub const Kind = archive.Kind;

pub const SparseDataExtent = struct {
    offset: usize,
    data: []const u8,
};

pub const SparseWriteFormat = enum {
    pax_1_0,
    gnu_old,
};

pub const SparseOptions = struct {
    logical_size: usize,
    extents: []const SparseDataExtent,
    format: SparseWriteFormat = .pax_1_0,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    link_name: []const u8 = "",
    kind: Kind = .file,
    mode: u32 = 0,
    mtime: u64 = 0,
    sparse: ?SparseOptions = null,
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
        if (entry.sparse) |sparse_options| switch (sparse_options.format) {
            .pax_1_0 => {
                try appendPaxRecord(allocator, &pax, "GNU.sparse.major", "1");
                try appendPaxRecord(allocator, &pax, "GNU.sparse.minor", "0");
                try appendPaxRecord(allocator, &pax, "GNU.sparse.name", entry.name);
                var size_buffer: [32]u8 = undefined;
                const logical_size = try std.fmt.bufPrint(
                    &size_buffer,
                    "{d}",
                    .{sparse_options.logical_size},
                );
                try appendPaxRecord(allocator, &pax, "GNU.sparse.realsize", logical_size);
            },
            .gnu_old => {},
        } else if (entry.name.len > 100) {
            try appendPaxRecord(allocator, &pax, "path", entry.name);
        }
        if (entry.link_name.len > 100) try appendPaxRecord(allocator, &pax, "linkpath", entry.link_name);
        if (pax.items.len != 0) {
            try appendHeader(allocator, &archive_bytes, .{
                .name = "PaxHeaders.X/vort",
                .data = pax.items,
                .kind = .other,
                .mode = 0o644,
            }, 'x');
        }
        if (entry.sparse) |sparse_options| {
            switch (sparse_options.format) {
                .pax_1_0 => {
                    var payload: std.ArrayList(u8) = .empty;
                    defer payload.deinit(allocator);
                    try appendSparsePayload(allocator, &payload, sparse_options);
                    try appendHeader(allocator, &archive_bytes, .{
                        .name = "./GNUSparseFile.vort/entry",
                        .data = payload.items,
                        .kind = .file,
                        .mode = entry.mode,
                        .mtime = entry.mtime,
                    }, '0');
                },
                .gnu_old => try appendOldGnuSparse(
                    allocator,
                    &archive_bytes,
                    entry,
                    sparse_options,
                ),
            }
        } else {
            try appendHeader(allocator, &archive_bytes, entry, typeFlag(entry.kind));
        }
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
        if (entry.sparse) |sparse_options| {
            if (entry.kind != .file or entry.data.len != 0 or entry.link_name.len != 0)
                return error.InvalidTarHeader;
            if (sparse_options.format == .gnu_old and entry.name.len > 100)
                return error.InvalidTarEntryName;
            var previous_end: usize = 0;
            for (sparse_options.extents) |extent| {
                if (extent.data.len == 0) return error.InvalidTarHeader;
                const end = std.math.add(usize, extent.offset, extent.data.len) catch
                    return error.TarNumericOverflow;
                if (extent.offset < previous_end or end > sparse_options.logical_size)
                    return error.InvalidTarHeader;
                previous_end = end;
            }
            continue;
        }
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

fn appendDecimalLine(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: usize,
) !void {
    var buffer: [32]u8 = undefined;
    const encoded = try std.fmt.bufPrint(&buffer, "{d}\n", .{value});
    try output.appendSlice(allocator, encoded);
}

const NormalizedSparseExtent = struct {
    offset: usize,
    len: usize,
};

fn appendSparsePayload(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: SparseOptions,
) !void {
    const normalized = try normalizedSparseExtentsAlloc(allocator, options);
    defer allocator.free(normalized);

    const map_entry_count = std.math.add(usize, normalized.len, 1) catch
        return error.TarNumericOverflow;
    try appendDecimalLine(allocator, output, map_entry_count);
    for (normalized) |extent| {
        try appendDecimalLine(allocator, output, extent.offset);
        try appendDecimalLine(allocator, output, extent.len);
    }
    try appendDecimalLine(allocator, output, options.logical_size);
    try appendDecimalLine(allocator, output, 0);
    const map_remainder = output.items.len % 512;
    if (map_remainder != 0)
        try output.appendNTimes(allocator, 0, 512 - map_remainder);
    try appendNormalizedSparseData(allocator, output, options, normalized);
}

fn normalizedSparseExtentsAlloc(
    allocator: std.mem.Allocator,
    options: SparseOptions,
) ![]NormalizedSparseExtent {
    var normalized: std.ArrayList(NormalizedSparseExtent) = .empty;
    errdefer normalized.deinit(allocator);
    for (options.extents) |extent| {
        const start = extent.offset / 512 * 512;
        const unaligned_end = std.math.add(usize, extent.offset, extent.data.len) catch
            return error.TarNumericOverflow;
        const rounded_end = std.math.add(usize, unaligned_end, 511) catch
            return error.TarNumericOverflow;
        const end = @min(options.logical_size, rounded_end / 512 * 512);
        if (normalized.items.len != 0) {
            const previous = &normalized.items[normalized.items.len - 1];
            const previous_end = previous.offset + previous.len;
            if (start <= previous_end) {
                previous.len = @max(previous_end, end) - previous.offset;
                continue;
            }
        }
        try normalized.append(allocator, .{ .offset = start, .len = end - start });
    }
    return normalized.toOwnedSlice(allocator);
}

fn appendNormalizedSparseData(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: SparseOptions,
    normalized: []const NormalizedSparseExtent,
) !void {
    var source_index: usize = 0;
    for (normalized) |normalized_extent| {
        const destination = output.items.len;
        try output.appendNTimes(allocator, 0, normalized_extent.len);
        const normalized_end = normalized_extent.offset + normalized_extent.len;
        while (source_index < options.extents.len) {
            const source = options.extents[source_index];
            const source_end = source.offset + source.data.len;
            if (source.offset >= normalized_end) break;
            if (source_end > normalized_extent.offset) {
                @memcpy(
                    output.items[destination + source.offset - normalized_extent.offset ..][0..source.data.len],
                    source.data,
                );
            }
            source_index += 1;
        }
    }
}

fn appendOldGnuSparse(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    options: SparseOptions,
) !void {
    const normalized = try normalizedSparseExtentsAlloc(allocator, options);
    defer allocator.free(normalized);
    const map_entry_count = std.math.add(usize, normalized.len, 1) catch
        return error.TarNumericOverflow;
    var physical_size: usize = 0;
    for (normalized) |extent|
        physical_size = std.math.add(usize, physical_size, extent.len) catch
            return error.TarNumericOverflow;

    var header: [512]u8 = @splat(0);
    @memcpy(header[0..entry.name.len], entry.name);
    try writeOctal(header[100..108], if (entry.mode != 0) entry.mode else defaultMode(.file));
    try writeOctal(header[108..116], 0);
    try writeOctal(header[116..124], 0);
    try writeOctal(header[124..136], physical_size);
    try writeOctal(header[136..148], entry.mtime);
    @memset(header[148..156], ' ');
    header[156] = 'S';
    @memcpy(header[257..263], "ustar ");
    @memcpy(header[263..265], " \x00");
    const main_count = @min(map_entry_count, 4);
    for (0..main_count) |index|
        try writeOldGnuSparseSlot(
            header[386 + index * 24 ..][0..24],
            normalized,
            options.logical_size,
            index,
        );
    header[482] = @intFromBool(map_entry_count > 4);
    try writeOctal(header[483..495], options.logical_size);
    var checksum: u64 = 0;
    for (header) |byte| checksum += byte;
    try writeChecksum(header[148..156], checksum);
    try output.appendSlice(allocator, &header);

    var map_index: usize = 4;
    while (map_index < map_entry_count) {
        var extension: [512]u8 = @splat(0);
        const take = @min(map_entry_count - map_index, 21);
        for (0..take) |slot|
            try writeOldGnuSparseSlot(
                extension[slot * 24 ..][0..24],
                normalized,
                options.logical_size,
                map_index + slot,
            );
        map_index += take;
        extension[504] = @intFromBool(map_index < map_entry_count);
        try output.appendSlice(allocator, &extension);
    }
    try appendNormalizedSparseData(allocator, output, options, normalized);
    const remainder = physical_size % 512;
    if (remainder != 0) try output.appendNTimes(allocator, 0, 512 - remainder);
}

fn writeOldGnuSparseSlot(
    slot: *[24]u8,
    normalized: []const NormalizedSparseExtent,
    logical_size: usize,
    index: usize,
) Error!void {
    const offset = if (index < normalized.len) normalized[index].offset else logical_size;
    const len = if (index < normalized.len) normalized[index].len else 0;
    try writeOctal(slot[0..12], offset);
    try writeOctal(slot[12..24], len);
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

test "TAR writer emits deterministic GNU PAX sparse 1.0 files" {
    const allocator = std.testing.allocator;
    const extents = [_]SparseDataExtent{
        .{ .offset = 0, .data = "HEAD" },
        .{ .offset = 4096, .data = "MIDDLE" },
        .{ .offset = 8188, .data = "TAIL" },
    };
    const entries = [_]EncodeEntry{.{
        .name = "images/sparse.bin",
        .sparse = .{ .logical_size = 8192, .extents = &extents },
        .mode = 0o640,
    }};
    const first = try encodeAlloc(allocator, &entries);
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const decoded = try archive.parse(first);
    const entry = (try decoded.find(entries[0].name)).?;
    try std.testing.expectEqual(@as(usize, 8192), entry.size);
    try std.testing.expectEqual(@as(u32, 0o640), entry.mode);
    try std.testing.expectEqual(archive.SparseFormat.pax_1_0, entry.sparse.?.format);
    try std.testing.expectEqual(extents.len + 1, entry.sparse.?.extent_count);
    try std.testing.expectEqual(@as(usize, 1536), entry.data.len);
    const output = try decoded.extractAlloc(allocator, entry);
    defer allocator.free(output);
    try std.testing.expectEqualSlices(u8, "HEAD", output[0..4]);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 16), output[4..20]);
    try std.testing.expectEqualSlices(u8, "MIDDLE", output[4096..4102]);
    try std.testing.expectEqualSlices(u8, "TAIL", output[8188..8192]);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decoded.extractAllocLimited(allocator, entry, 8191),
    );
}

test "TAR writer emits deterministic old GNU sparse files" {
    const allocator = std.testing.allocator;
    const extents = [_]SparseDataExtent{
        .{ .offset = 0, .data = "HEAD" },
        .{ .offset = 4096, .data = "MIDDLE" },
        .{ .offset = 8188, .data = "TAIL" },
    };
    const entries = [_]EncodeEntry{.{
        .name = "old-sparse.bin",
        .sparse = .{
            .logical_size = 8192,
            .extents = &extents,
            .format = .gnu_old,
        },
    }};
    const first = try encodeAlloc(allocator, &entries);
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    const decoded = try archive.parse(first);
    const entry = (try decoded.find(entries[0].name)).?;
    try std.testing.expectEqual(archive.SparseFormat.gnu_old, entry.sparse.?.format);
    const output = try decoded.extractAlloc(allocator, entry);
    defer allocator.free(output);
    try std.testing.expectEqualSlices(u8, "HEAD", output[0..4]);
    try std.testing.expectEqualSlices(u8, "MIDDLE", output[4096..4102]);
    try std.testing.expectEqualSlices(u8, "TAIL", output[8188..]);
}

test "TAR old GNU sparse writer emits chained extension headers" {
    const allocator = std.testing.allocator;
    var extents: [25]SparseDataExtent = undefined;
    for (&extents, 0..) |*extent, index|
        extent.* = .{ .offset = index * 1024, .data = "X" };
    const logical_size = 26 * 1024;
    const bytes = try encodeAlloc(allocator, &.{.{
        .name = "many-sparse.bin",
        .sparse = .{
            .logical_size = logical_size,
            .extents = &extents,
            .format = .gnu_old,
        },
    }});
    defer allocator.free(bytes);
    const decoded = try archive.parse(bytes);
    const entry = (try decoded.find("many-sparse.bin")).?;
    try std.testing.expectEqual(@as(usize, 26), entry.sparse.?.extent_count);
    try std.testing.expectEqual(@as(usize, 3 * 512), entry.data_offset);
    const output = try decoded.extractAlloc(allocator, entry);
    defer allocator.free(output);
    for (0..extents.len) |index| {
        try std.testing.expectEqual(@as(u8, 'X'), output[index * 1024]);
        try std.testing.expectEqual(@as(u8, 0), output[index * 1024 + 1]);
    }

    const bad_padding = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_padding);
    bad_padding[512 + 505] = 1;
    try std.testing.expectError(error.InvalidTarHeader, archive.parse(bad_padding));

    const bad_overlap = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_overlap);
    @memcpy(bad_overlap[512..524], "00000000000\x00");
    try std.testing.expectError(error.InvalidTarHeader, archive.parse(bad_overlap));
}

test "TAR writer rejects invalid sparse layouts" {
    const allocator = std.testing.allocator;
    const overlapping = [_]SparseDataExtent{
        .{ .offset = 0, .data = "1234" },
        .{ .offset = 3, .data = "56" },
    };
    try std.testing.expectError(
        error.InvalidTarHeader,
        encodeAlloc(allocator, &.{.{
            .name = "overlap.bin",
            .sparse = .{ .logical_size = 16, .extents = &overlapping },
        }}),
    );
    const outside = [_]SparseDataExtent{.{ .offset = 15, .data = "12" }};
    try std.testing.expectError(
        error.InvalidTarHeader,
        encodeAlloc(allocator, &.{.{
            .name = "outside.bin",
            .sparse = .{ .logical_size = 16, .extents = &outside },
        }}),
    );
    const zero = [_]SparseDataExtent{.{ .offset = 0, .data = "" }};
    try std.testing.expectError(
        error.InvalidTarHeader,
        encodeAlloc(allocator, &.{.{
            .name = "zero.bin",
            .sparse = .{ .logical_size = 16, .extents = &zero },
        }}),
    );
    try std.testing.expectError(
        error.InvalidTarHeader,
        encodeAlloc(allocator, &.{.{
            .name = "conflict.bin",
            .data = "dense",
            .sparse = .{ .logical_size = 16, .extents = &.{} },
        }}),
    );
    try std.testing.expectError(
        error.InvalidTarEntryName,
        encodeAlloc(allocator, &.{.{
            .name = "x" ** 101,
            .sparse = .{
                .logical_size = 16,
                .extents = &.{.{ .offset = 0, .data = "data" }},
                .format = .gnu_old,
            },
        }}),
    );
}

test "TAR sparse writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const extents = [_]SparseDataExtent{
                .{ .offset = 0, .data = "HEAD" },
                .{ .offset = 4096, .data = "TAIL" },
            };
            const bytes = try encodeAlloc(allocator, &.{.{
                .name = "sparse.bin",
                .sparse = .{ .logical_size = 8192, .extents = &extents },
            }});
            defer allocator.free(bytes);
            const decoded = try archive.parse(bytes);
            const output = try decoded.extractByNameAlloc(allocator, "sparse.bin");
            defer allocator.free(output);
            try std.testing.expectEqual(@as(usize, 8192), output.len);
            try std.testing.expectEqualSlices(u8, "HEAD", output[0..4]);
            try std.testing.expectEqualSlices(u8, "TAIL", output[4096..4100]);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
