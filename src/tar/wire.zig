//! Shared TAR control-record serialization.

const std = @import("std");

pub const block_size: usize = 512;

pub const Error = error{
    InvalidTarHeader,
    TarNumericOverflow,
};

pub const Header = struct {
    name: []const u8,
    link_name: []const u8 = "",
    mode: u32,
    mtime: u64,
    size: usize,
    type_flag: u8,
};

pub const SparseWriteFormat = enum {
    pax_1_0,
    gnu_old,
};

pub const SparseExtent = struct {
    offset: usize,
    len: usize,
};

pub fn appendUstarHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Header,
) !void {
    if (options.name.len > 100 or options.link_name.len > 100)
        return error.InvalidTarHeader;
    var header: [block_size]u8 = @splat(0);
    @memcpy(header[0..options.name.len], options.name);
    try writeOctal(header[100..108], options.mode);
    try writeOctal(header[108..116], 0);
    try writeOctal(header[116..124], 0);
    try writeOctal(header[124..136], options.size);
    try writeOctal(header[136..148], options.mtime);
    @memset(header[148..156], ' ');
    header[156] = options.type_flag;
    @memcpy(header[157..][0..options.link_name.len], options.link_name);
    @memcpy(header[257..263], "ustar\x00");
    @memcpy(header[263..265], "00");
    try finishChecksum(&header);
    try output.appendSlice(allocator, &header);
}

pub fn appendPaxRecord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    key: []const u8,
    value: []const u8,
) !void {
    var digits: usize = 1;
    while (true) {
        const length = std.math.add(
            usize,
            digits + 3 + key.len,
            value.len,
        ) catch return error.TarNumericOverflow;
        const actual_digits = decimalDigits(length);
        if (actual_digits == digits) {
            var buffer: [32]u8 = undefined;
            const prefix = std.fmt.bufPrint(&buffer, "{d} ", .{length}) catch
                return error.TarNumericOverflow;
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

pub fn normalizeSparseExtentsAlloc(
    allocator: std.mem.Allocator,
    logical_size: usize,
    extents: []const SparseExtent,
) ![]SparseExtent {
    var normalized: std.ArrayList(SparseExtent) = .empty;
    errdefer normalized.deinit(allocator);
    for (extents) |extent| {
        if (extent.len == 0) return error.InvalidTarHeader;
        const unaligned_end = std.math.add(usize, extent.offset, extent.len) catch
            return error.TarNumericOverflow;
        if (unaligned_end > logical_size) return error.InvalidTarHeader;
        const start = extent.offset / block_size * block_size;
        const rounded_end = std.math.add(usize, unaligned_end, block_size - 1) catch
            return error.TarNumericOverflow;
        const end = @min(logical_size, rounded_end / block_size * block_size);
        if (normalized.items.len != 0) {
            const previous = &normalized.items[normalized.items.len - 1];
            const previous_end = previous.offset + previous.len;
            if (start < previous.offset) return error.InvalidTarHeader;
            if (start <= previous_end) {
                previous.len = @max(previous_end, end) - previous.offset;
                continue;
            }
        }
        try normalized.append(allocator, .{ .offset = start, .len = end - start });
    }
    return normalized.toOwnedSlice(allocator);
}

pub fn appendPaxSparsePrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    mode: u32,
    mtime: u64,
    logical_size: usize,
    normalized: []const SparseExtent,
) !usize {
    var pax: std.ArrayList(u8) = .empty;
    defer pax.deinit(allocator);
    try appendPaxRecord(allocator, &pax, "GNU.sparse.major", "1");
    try appendPaxRecord(allocator, &pax, "GNU.sparse.minor", "0");
    try appendPaxRecord(allocator, &pax, "GNU.sparse.name", name);
    var size_buffer: [32]u8 = undefined;
    const encoded_size = std.fmt.bufPrint(&size_buffer, "{d}", .{logical_size}) catch
        return error.TarNumericOverflow;
    try appendPaxRecord(allocator, &pax, "GNU.sparse.realsize", encoded_size);
    try appendUstarHeader(allocator, output, .{
        .name = "PaxHeaders.X/vort",
        .mode = 0o644,
        .mtime = 0,
        .size = pax.items.len,
        .type_flag = 'x',
    });
    try output.appendSlice(allocator, pax.items);
    try appendPadding(allocator, output, pax.items.len);

    var map: std.ArrayList(u8) = .empty;
    defer map.deinit(allocator);
    const map_count = std.math.add(usize, normalized.len, 1) catch
        return error.TarNumericOverflow;
    try appendDecimalLine(allocator, &map, map_count);
    for (normalized) |extent| {
        try appendDecimalLine(allocator, &map, extent.offset);
        try appendDecimalLine(allocator, &map, extent.len);
    }
    try appendDecimalLine(allocator, &map, logical_size);
    try appendDecimalLine(allocator, &map, 0);
    const map_size = try paddedSize(map.items.len);
    const physical_size = try sparsePhysicalSize(normalized);
    const stored_size = std.math.add(usize, map_size, physical_size) catch
        return error.TarNumericOverflow;
    try appendUstarHeader(allocator, output, .{
        .name = "./GNUSparseFile.vort/entry",
        .mode = mode,
        .mtime = mtime,
        .size = stored_size,
        .type_flag = '0',
    });
    try output.appendSlice(allocator, map.items);
    try appendPadding(allocator, output, map.items.len);
    return physical_size;
}

pub fn appendOldGnuSparsePrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    mode: u32,
    mtime: u64,
    logical_size: usize,
    normalized: []const SparseExtent,
) !usize {
    if (name.len > 100) return error.InvalidTarHeader;
    const map_entry_count = std.math.add(usize, normalized.len, 1) catch
        return error.TarNumericOverflow;
    const physical_size = try sparsePhysicalSize(normalized);
    var header: [block_size]u8 = @splat(0);
    @memcpy(header[0..name.len], name);
    try writeOctal(header[100..108], mode);
    try writeOctal(header[108..116], 0);
    try writeOctal(header[116..124], 0);
    try writeOctal(header[124..136], physical_size);
    try writeOctal(header[136..148], mtime);
    header[156] = 'S';
    @memcpy(header[257..263], "ustar ");
    @memcpy(header[263..265], " \x00");
    const main_count = @min(map_entry_count, 4);
    for (0..main_count) |index|
        try writeOldGnuSparseSlot(
            header[386 + index * 24 ..][0..24],
            normalized,
            logical_size,
            index,
        );
    header[482] = @intFromBool(map_entry_count > 4);
    try writeOctal(header[483..495], logical_size);
    try finishChecksum(&header);
    try output.appendSlice(allocator, &header);

    var map_index: usize = 4;
    while (map_index < map_entry_count) {
        var extension: [block_size]u8 = @splat(0);
        const take = @min(map_entry_count - map_index, 21);
        for (0..take) |slot|
            try writeOldGnuSparseSlot(
                extension[slot * 24 ..][0..24],
                normalized,
                logical_size,
                map_index + slot,
            );
        map_index += take;
        extension[504] = @intFromBool(map_index < map_entry_count);
        try output.appendSlice(allocator, &extension);
    }
    return physical_size;
}

pub fn writeOctal(field: []u8, value_arg: anytype) Error!void {
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

pub fn finishChecksum(header: *[block_size]u8) Error!void {
    @memset(header[148..156], ' ');
    var checksum: u64 = 0;
    for (header) |byte| checksum += byte;
    try writeChecksum(header[148..156], checksum);
}

pub fn appendPadding(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    data_size: usize,
) !void {
    const remainder = data_size % block_size;
    if (remainder != 0)
        try output.appendNTimes(allocator, 0, block_size - remainder);
}

fn appendDecimalLine(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: usize,
) !void {
    var buffer: [32]u8 = undefined;
    const encoded = std.fmt.bufPrint(&buffer, "{d}\n", .{value}) catch
        return error.TarNumericOverflow;
    try output.appendSlice(allocator, encoded);
}

fn paddedSize(value: usize) Error!usize {
    const remainder = value % block_size;
    return std.math.add(
        usize,
        value,
        if (remainder == 0) 0 else block_size - remainder,
    ) catch error.TarNumericOverflow;
}

fn sparsePhysicalSize(extents: []const SparseExtent) Error!usize {
    var total: usize = 0;
    for (extents) |extent|
        total = std.math.add(usize, total, extent.len) catch
            return error.TarNumericOverflow;
    return total;
}

fn writeOldGnuSparseSlot(
    slot: *[24]u8,
    normalized: []const SparseExtent,
    logical_size: usize,
    index: usize,
) Error!void {
    const offset = if (index < normalized.len) normalized[index].offset else logical_size;
    const len = if (index < normalized.len) normalized[index].len else 0;
    try writeOctal(slot[0..12], offset);
    try writeOctal(slot[12..24], len);
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

fn decimalDigits(value: usize) usize {
    var remaining = value;
    var digits: usize = 1;
    while (remaining >= 10) : (digits += 1) remaining /= 10;
    return digits;
}
