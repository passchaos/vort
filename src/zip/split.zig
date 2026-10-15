//! Ordered split/multi-disk ZIP normalization.
//!
//! ZIP offsets are relative to the disk named beside each record. This module
//! validates an ordered set of borrowed disk slices, concatenates them once,
//! and rewrites only disk/offset metadata to the equivalent single-disk view.
//! Local records, payloads, descriptors and central variable fields remain
//! byte-identical, so the established strict parser and codecs own extraction.

const std = @import("std");
const records = @import("records.zig");
const wire = @import("wire.zig");

pub const Error = records.Error || error{
    InvalidZipArchive,
    InvalidZipDiskOrder,
    OutputLimitExceeded,
    IntegerOverflow,
};

pub const Options = struct {
    /// Maximum sum of all part lengths and size of the normalized allocation.
    max_archive_size: usize = std.math.maxInt(usize),
    /// Maximum number of explicitly ordered parts accepted from the caller.
    max_parts: usize = std.math.maxInt(u32),
    /// Require the conventional `PK\x07\x08` marker at offset zero of disk 0.
    require_split_signature: bool = true,
};

const End = struct {
    offset: usize,
    disk: u16,
    central_disk: u16,
    entries_on_disk: u16,
    entry_count: u16,
    central_size: u32,
    central_offset: u32,
};

const Directory = struct {
    disk: usize,
    offset: usize,
    size: usize,
    entry_count: usize,
};

pub fn normalizeAlloc(
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    options: Options,
) (Error || std.mem.Allocator.Error)![]u8 {
    if (parts.len < 2 or parts.len > std.math.maxInt(u32))
        return error.InvalidZipArchive;
    if (parts.len > options.max_parts) return error.OutputLimitExceeded;
    var total_len: usize = 0;
    for (parts) |part| {
        if (part.len == 0) return error.InvalidZipArchive;
        total_len = try checkedAdd(total_len, part.len);
        if (total_len > options.max_archive_size) return error.OutputLimitExceeded;
    }
    if (options.require_split_signature and
        (parts[0].len < 4 or
            std.mem.readInt(u32, parts[0][0..4], .little) != wire.data_descriptor_signature))
        return error.InvalidZipDiskOrder;

    const bases = try allocator.alloc(usize, parts.len);
    defer allocator.free(bases);
    var cursor: usize = 0;
    for (parts, bases) |part, *base| {
        base.* = cursor;
        cursor += part.len;
    }

    const output = try allocator.alloc(u8, total_len);
    errdefer allocator.free(output);
    cursor = 0;
    for (parts) |part| {
        @memcpy(output[cursor..][0..part.len], part);
        cursor += part.len;
    }

    const end = try parseEnd(parts[parts.len - 1], bases[parts.len - 1]);
    var directory: Directory = undefined;
    if (hasZip64Sentinel(end)) {
        directory = try normalizeZip64(output, parts, bases, end);
    } else {
        if (end.disk != parts.len - 1 or end.central_disk >= parts.len or
            end.entries_on_disk > end.entry_count)
            return error.InvalidZipDiskOrder;
        directory = .{
            .disk = end.central_disk,
            .offset = end.central_offset,
            .size = end.central_size,
            .entry_count = end.entry_count,
        };
        std.mem.writeInt(u16, output[end.offset + 4 ..][0..2], 0, .little);
        std.mem.writeInt(u16, output[end.offset + 6 ..][0..2], 0, .little);
        std.mem.writeInt(u16, output[end.offset + 8 ..][0..2], end.entry_count, .little);
        const virtual_central = try diskOffset(bases, parts, directory.disk, directory.offset);
        if (virtual_central >= std.math.maxInt(u32)) return error.UnsupportedZipFeature;
        std.mem.writeInt(
            u32,
            output[end.offset + 16 ..][0..4],
            @intCast(virtual_central),
            .little,
        );
    }

    const central_offset = try diskOffset(
        bases,
        parts,
        directory.disk,
        directory.offset,
    );
    const central_end = try checkedEnd(central_offset, directory.size, end.offset);
    var central_cursor = central_offset;
    for (0..directory.entry_count) |_| {
        central_cursor = try normalizeCentralEntry(
            output,
            parts,
            bases,
            central_cursor,
            central_end,
        );
    }
    if (central_cursor != central_end) return error.InvalidZipArchive;
    return output;
}

fn parseEnd(last_part: []const u8, last_base: usize) Error!End {
    if (last_part.len < wire.end_of_central_len) return error.InvalidZipArchive;
    const search_len = @min(
        last_part.len,
        wire.end_of_central_len + @as(usize, std.math.maxInt(u16)),
    );
    const lower = last_part.len - search_len;
    var offset = last_part.len - wire.end_of_central_len;
    while (true) {
        if (std.mem.readInt(u32, last_part[offset..][0..4], .little) ==
            wire.end_of_central_signature)
        {
            const comment_len = std.mem.readInt(u16, last_part[offset + 20 ..][0..2], .little);
            const record_len = wire.end_of_central_len + @as(usize, comment_len);
            if (record_len <= last_part.len and offset == last_part.len - record_len) {
                return .{
                    .offset = try checkedAdd(last_base, offset),
                    .disk = std.mem.readInt(u16, last_part[offset + 4 ..][0..2], .little),
                    .central_disk = std.mem.readInt(u16, last_part[offset + 6 ..][0..2], .little),
                    .entries_on_disk = std.mem.readInt(u16, last_part[offset + 8 ..][0..2], .little),
                    .entry_count = std.mem.readInt(u16, last_part[offset + 10 ..][0..2], .little),
                    .central_size = std.mem.readInt(u32, last_part[offset + 12 ..][0..4], .little),
                    .central_offset = std.mem.readInt(u32, last_part[offset + 16 ..][0..4], .little),
                };
            }
        }
        if (offset == lower) break;
        offset -= 1;
    }
    return error.InvalidZipArchive;
}

fn normalizeZip64(
    output: []u8,
    parts: []const []const u8,
    bases: []const usize,
    end: End,
) Error!Directory {
    if (end.offset < wire.zip64_end_of_central_locator_len)
        return error.InvalidZipArchive;
    const locator_offset = end.offset - wire.zip64_end_of_central_locator_len;
    if (std.mem.readInt(u32, output[locator_offset..][0..4], .little) !=
        wire.zip64_end_of_central_locator_signature)
        return error.InvalidZipArchive;
    const zip64_disk = std.mem.readInt(u32, output[locator_offset + 4 ..][0..4], .little);
    const zip64_offset_on_disk = std.mem.readInt(u64, output[locator_offset + 8 ..][0..8], .little);
    const disk_count = std.mem.readInt(u32, output[locator_offset + 16 ..][0..4], .little);
    if (zip64_disk >= parts.len or disk_count != parts.len)
        return error.InvalidZipDiskOrder;
    const zip64_offset = try diskOffset(
        bases,
        parts,
        @intCast(zip64_disk),
        try u64ToUsize(zip64_offset_on_disk),
    );
    _ = try checkedEnd(zip64_offset, wire.zip64_end_of_central_len, locator_offset);
    if (std.mem.readInt(u32, output[zip64_offset..][0..4], .little) !=
        wire.zip64_end_of_central_signature)
        return error.InvalidZipArchive;
    const payload_len = try u64ToUsize(
        std.mem.readInt(u64, output[zip64_offset + 4 ..][0..8], .little),
    );
    if (payload_len < 44 or try checkedEnd(zip64_offset, try checkedAdd(12, payload_len), locator_offset) != locator_offset)
        return error.InvalidZipArchive;
    const disk = std.mem.readInt(u32, output[zip64_offset + 16 ..][0..4], .little);
    const central_disk = std.mem.readInt(u32, output[zip64_offset + 20 ..][0..4], .little);
    const entries_on_disk = std.mem.readInt(u64, output[zip64_offset + 24 ..][0..8], .little);
    const entry_count = std.mem.readInt(u64, output[zip64_offset + 32 ..][0..8], .little);
    const central_size = std.mem.readInt(u64, output[zip64_offset + 40 ..][0..8], .little);
    const central_offset_on_disk = std.mem.readInt(u64, output[zip64_offset + 48 ..][0..8], .little);
    if (disk != parts.len - 1 or central_disk >= parts.len or entries_on_disk > entry_count)
        return error.InvalidZipDiskOrder;
    const virtual_central = try diskOffset(
        bases,
        parts,
        @intCast(central_disk),
        try u64ToUsize(central_offset_on_disk),
    );
    std.mem.writeInt(u32, output[zip64_offset + 16 ..][0..4], 0, .little);
    std.mem.writeInt(u32, output[zip64_offset + 20 ..][0..4], 0, .little);
    std.mem.writeInt(u64, output[zip64_offset + 24 ..][0..8], entry_count, .little);
    std.mem.writeInt(u64, output[zip64_offset + 48 ..][0..8], virtual_central, .little);
    std.mem.writeInt(u32, output[locator_offset + 4 ..][0..4], 0, .little);
    std.mem.writeInt(u64, output[locator_offset + 8 ..][0..8], zip64_offset, .little);
    std.mem.writeInt(u32, output[locator_offset + 16 ..][0..4], 1, .little);
    if (end.disk != std.math.maxInt(u16))
        std.mem.writeInt(u16, output[end.offset + 4 ..][0..2], 0, .little);
    if (end.central_disk != std.math.maxInt(u16))
        std.mem.writeInt(u16, output[end.offset + 6 ..][0..2], 0, .little);
    if (end.entries_on_disk != std.math.maxInt(u16))
        std.mem.writeInt(
            u16,
            output[end.offset + 8 ..][0..2],
            if (entry_count >= std.math.maxInt(u16))
                std.math.maxInt(u16)
            else
                @intCast(entry_count),
            .little,
        );
    if (end.central_offset != std.math.maxInt(u32))
        std.mem.writeInt(
            u32,
            output[end.offset + 16 ..][0..4],
            if (virtual_central >= std.math.maxInt(u32))
                std.math.maxInt(u32)
            else
                @intCast(virtual_central),
            .little,
        );
    return .{
        .disk = @intCast(central_disk),
        .offset = try u64ToUsize(central_offset_on_disk),
        .size = try u64ToUsize(central_size),
        .entry_count = try u64ToUsize(entry_count),
    };
}

fn normalizeCentralEntry(
    output: []u8,
    parts: []const []const u8,
    bases: []const usize,
    offset: usize,
    central_end: usize,
) Error!usize {
    _ = try checkedEnd(offset, wire.central_file_header_len, central_end);
    if (std.mem.readInt(u32, output[offset..][0..4], .little) != wire.central_file_signature)
        return error.InvalidZipArchive;
    const name_len: usize = std.mem.readInt(u16, output[offset + 28 ..][0..2], .little);
    const extra_len: usize = std.mem.readInt(u16, output[offset + 30 ..][0..2], .little);
    const comment_len: usize = std.mem.readInt(u16, output[offset + 32 ..][0..2], .little);
    const variable_len = try checkedAdd(name_len, try checkedAdd(extra_len, comment_len));
    const next = try checkedEnd(offset + wire.central_file_header_len, variable_len, central_end);
    const extra_offset = offset + wire.central_file_header_len + name_len;
    const extra = output[extra_offset..][0..extra_len];

    const disk_legacy = std.mem.readInt(u16, output[offset + 34 ..][0..2], .little);
    const local_legacy = std.mem.readInt(u32, output[offset + 42 ..][0..4], .little);
    var disk: usize = disk_legacy;
    var local_offset: usize = local_legacy;
    var zip64_local_offset_pos: ?usize = null;
    var zip64_disk_pos: ?usize = null;
    if (disk_legacy == std.math.maxInt(u16) or local_legacy == std.math.maxInt(u32)) {
        const zip64 = try findExtraWithOffset(extra, wire.zip64_extra_id) orelse
            return error.InvalidZipArchive;
        var payload_cursor: usize = 0;
        if (std.mem.readInt(u32, output[offset + 24 ..][0..4], .little) == std.math.maxInt(u32))
            payload_cursor = try checkedEnd(payload_cursor, 8, zip64.payload.len);
        if (std.mem.readInt(u32, output[offset + 20 ..][0..4], .little) == std.math.maxInt(u32))
            payload_cursor = try checkedEnd(payload_cursor, 8, zip64.payload.len);
        if (local_legacy == std.math.maxInt(u32)) {
            const value_end = try checkedEnd(payload_cursor, 8, zip64.payload.len);
            zip64_local_offset_pos = try checkedAdd(
                extra_offset,
                try checkedAdd(zip64.payload_offset, payload_cursor),
            );
            local_offset = try u64ToUsize(std.mem.readInt(
                u64,
                zip64.payload[payload_cursor..][0..8],
                .little,
            ));
            payload_cursor = value_end;
        }
        if (disk_legacy == std.math.maxInt(u16)) {
            _ = try checkedEnd(payload_cursor, 4, zip64.payload.len);
            zip64_disk_pos = try checkedAdd(
                extra_offset,
                try checkedAdd(zip64.payload_offset, payload_cursor),
            );
            disk = std.mem.readInt(u32, zip64.payload[payload_cursor..][0..4], .little);
        }
    }
    const virtual_local = try diskOffset(bases, parts, disk, local_offset);
    _ = try checkedEnd(virtual_local, 4, offset);
    if (std.mem.readInt(u32, output[virtual_local..][0..4], .little) != wire.local_file_signature)
        return error.InvalidZipDiskOrder;
    if (zip64_local_offset_pos) |position|
        std.mem.writeInt(u64, output[position..][0..8], virtual_local, .little)
    else if (virtual_local < std.math.maxInt(u32))
        std.mem.writeInt(u32, output[offset + 42 ..][0..4], @intCast(virtual_local), .little)
    else
        return error.UnsupportedZipFeature;
    if (zip64_disk_pos) |position|
        std.mem.writeInt(u32, output[position..][0..4], 0, .little)
    else
        std.mem.writeInt(u16, output[offset + 34 ..][0..2], 0, .little);
    return next;
}

const Extra = struct {
    payload: []u8,
    payload_offset: usize,
};

fn findExtraWithOffset(extra: []u8, wanted: u16) Error!?Extra {
    var cursor: usize = 0;
    var result: ?Extra = null;
    while (cursor < extra.len) {
        const payload_offset = try checkedEnd(cursor, 4, extra.len);
        const id = std.mem.readInt(u16, extra[cursor..][0..2], .little);
        const len: usize = std.mem.readInt(u16, extra[cursor + 2 ..][0..2], .little);
        const end = try checkedEnd(payload_offset, len, extra.len);
        if (id == wanted) {
            if (result != null) return error.InvalidZipArchive;
            result = .{
                .payload = extra[payload_offset..end],
                .payload_offset = payload_offset,
            };
        }
        cursor = end;
    }
    return result;
}

fn hasZip64Sentinel(end: End) bool {
    return end.disk == std.math.maxInt(u16) or
        end.central_disk == std.math.maxInt(u16) or
        end.entries_on_disk == std.math.maxInt(u16) or
        end.entry_count == std.math.maxInt(u16) or
        end.central_size == std.math.maxInt(u32) or
        end.central_offset == std.math.maxInt(u32);
}

fn diskOffset(
    bases: []const usize,
    parts: []const []const u8,
    disk: usize,
    offset: usize,
) Error!usize {
    if (disk >= parts.len or offset >= parts[disk].len) return error.InvalidZipDiskOrder;
    return checkedAdd(bases[disk], offset);
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedZipFeature;
}
