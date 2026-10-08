const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const types = @import("types.zig");

pub const Error = core.Error || error{
    InvalidZipEntryName,
    InvalidZipTextEncoding,
    UnsupportedZipCompressionMethod,
    Zip32LimitExceeded,
};

pub const CompressionMethod = types.CompressionMethod;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8,
    method: CompressionMethod = .deflate,
    comment: []const u8 = "",
};

pub const EncodeOptions = struct {
    archive_comment: []const u8 = "",
    data_descriptor: bool = false,
    utf8: bool = true,
    deflate_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
};

const local_file_signature: u32 = 0x0403_4b50;
const central_file_signature: u32 = 0x0201_4b50;
const data_descriptor_signature: u32 = 0x0807_4b50;
const end_of_central_signature: u32 = 0x0605_4b50;
const version_needed: u16 = 20;
const deterministic_dos_time: u16 = 0;
const deterministic_dos_date: u16 = 0x0021;
const descriptor_flag: u16 = 1 << 3;
const utf8_flag: u16 = 1 << 11;

const EncodedEntry = struct {
    source: EncodeEntry,
    flags: u16,
    crc32: u32,
    compressed_size: u32,
    uncompressed_size: u32,
    local_header_offset: u32,
};

/// Encode a deterministic single-disk ZIP32 archive.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try encodeAppend(allocator, &out, entries, options);
    return out.toOwnedSlice(allocator);
}

/// Append one complete ZIP32 archive without changing `out.items` on error.
///
/// Existing bytes are treated as a self-extracting prefix, so local and
/// central-directory offsets remain valid when `out` is non-empty.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try validateInputs(entries, options);
    const archive_base = try zip32Value(out.items.len);

    const encoded_entries = try allocator.alloc(EncodedEntry, entries.len);
    defer allocator.free(encoded_entries);

    var archive: std.ArrayList(u8) = .empty;
    defer archive.deinit(allocator);

    for (entries, encoded_entries) |entry, *encoded| {
        const local_offset = try absoluteOffset(archive_base, archive.items.len);
        const crc = checksum.crc32Best(entry.data);
        const uncompressed_size = try zip32Value(entry.data.len);
        const flags: u16 = (if (options.data_descriptor) descriptor_flag else 0) |
            (if (options.utf8) utf8_flag else 0);

        var owned_compressed: ?[]u8 = null;
        defer if (owned_compressed) |bytes| allocator.free(bytes);
        const compressed = switch (entry.method) {
            .stored => entry.data,
            .deflate => blk: {
                const bytes = try deflate.encodeRawBestAlloc(allocator, entry.data, options.deflate_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            else => return error.UnsupportedZipCompressionMethod,
        };
        const compressed_size = try zip32Value(compressed.len);

        try appendLocalHeader(
            allocator,
            &archive,
            entry,
            flags,
            crc,
            compressed_size,
            uncompressed_size,
        );
        try archive.appendSlice(allocator, compressed);
        if (options.data_descriptor) {
            try appendU32(allocator, &archive, data_descriptor_signature);
            try appendU32(allocator, &archive, crc);
            try appendU32(allocator, &archive, compressed_size);
            try appendU32(allocator, &archive, uncompressed_size);
        }

        encoded.* = .{
            .source = entry,
            .flags = flags,
            .crc32 = crc,
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .local_header_offset = local_offset,
        };
    }

    const central_offset = try absoluteOffset(archive_base, archive.items.len);
    const central_start = archive.items.len;
    for (encoded_entries) |entry| try appendCentralHeader(allocator, &archive, entry);
    const central_size = try zip32Value(archive.items.len - central_start);

    try appendU32(allocator, &archive, end_of_central_signature);
    try appendU16(allocator, &archive, 0);
    try appendU16(allocator, &archive, 0);
    const entry_count: u16 = @intCast(entries.len);
    try appendU16(allocator, &archive, entry_count);
    try appendU16(allocator, &archive, entry_count);
    try appendU32(allocator, &archive, central_size);
    try appendU32(allocator, &archive, central_offset);
    try appendU16(allocator, &archive, @intCast(options.archive_comment.len));
    try archive.appendSlice(allocator, options.archive_comment);

    try out.ensureUnusedCapacity(allocator, archive.items.len);
    out.appendSliceAssumeCapacity(archive.items);
    return archive.items.len;
}

fn validateInputs(entries: []const EncodeEntry, options: EncodeOptions) Error!void {
    if (entries.len >= std.math.maxInt(u16)) return error.Zip32LimitExceeded;
    if (options.archive_comment.len > std.math.maxInt(u16)) return error.Zip32LimitExceeded;
    for (entries) |entry| {
        if (entry.name.len == 0) return error.InvalidZipEntryName;
        if (entry.name.len > std.math.maxInt(u16) or entry.comment.len > std.math.maxInt(u16))
            return error.Zip32LimitExceeded;
        if (entry.data.len >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
        switch (entry.method) {
            .stored, .deflate => {},
            else => return error.UnsupportedZipCompressionMethod,
        }
        if (options.utf8 and
            (!std.unicode.utf8ValidateSlice(entry.name) or
                !std.unicode.utf8ValidateSlice(entry.comment))) return error.InvalidZipTextEncoding;
    }
}

fn appendLocalHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodeEntry,
    flags: u16,
    crc: u32,
    compressed_size: u32,
    uncompressed_size: u32,
) !void {
    const descriptor = flags & descriptor_flag != 0;
    try appendU32(allocator, out, local_file_signature);
    try appendU16(allocator, out, version_needed);
    try appendU16(allocator, out, flags);
    try appendU16(allocator, out, @intFromEnum(entry.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, if (descriptor) 0 else crc);
    try appendU32(allocator, out, if (descriptor) 0 else compressed_size);
    try appendU32(allocator, out, if (descriptor) 0 else uncompressed_size);
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, 0);
    try out.appendSlice(allocator, entry.name);
}

fn appendCentralHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
) !void {
    try appendU32(allocator, out, central_file_signature);
    try appendU16(allocator, out, version_needed);
    try appendU16(allocator, out, version_needed);
    try appendU16(allocator, out, entry.flags);
    try appendU16(allocator, out, @intFromEnum(entry.source.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, entry.crc32);
    try appendU32(allocator, out, entry.compressed_size);
    try appendU32(allocator, out, entry.uncompressed_size);
    try appendU16(allocator, out, @intCast(entry.source.name.len));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, @intCast(entry.source.comment.len));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0);
    const external_attributes: u32 = if (std.mem.endsWith(u8, entry.source.name, "/")) 0x10 else 0;
    try appendU32(allocator, out, external_attributes);
    try appendU32(allocator, out, entry.local_header_offset);
    try out.appendSlice(allocator, entry.source.name);
    try out.appendSlice(allocator, entry.source.comment);
}

fn absoluteOffset(base: u32, relative: usize) Error!u32 {
    const value = std.math.add(usize, base, relative) catch return error.Zip32LimitExceeded;
    return zip32Value(value);
}

fn zip32Value(value: usize) Error!u32 {
    if (value >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
    return @intCast(value);
}

fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

test "ZIP writer rejects ZIP32 sentinel counts and overlong comments" {
    const allocator = std.testing.allocator;
    const too_many = try allocator.alloc(EncodeEntry, std.math.maxInt(u16));
    defer allocator.free(too_many);
    try std.testing.expectError(error.Zip32LimitExceeded, validateInputs(too_many, .{}));

    const overlong_comment = try allocator.alloc(u8, @as(usize, std.math.maxInt(u16)) + 1);
    defer allocator.free(overlong_comment);
    try std.testing.expectError(
        error.Zip32LimitExceeded,
        validateInputs(&.{}, .{ .archive_comment = overlong_comment }),
    );
}
