const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const deflate64 = @import("../deflate64.zig");
const lzma_writer = @import("../lzma/writer.zig");
const types = @import("types.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Error = core.Error || bzip2.Error || deflate64.Error || lzma_writer.Error || xz.Error || zstd.Error || error{
    InvalidZipEntryName,
    InvalidZipTextEncoding,
    UnsupportedZipCompressionMethod,
    Zip32LimitExceeded,
};

pub const CompressionMethod = types.CompressionMethod;

pub const Zip64Mode = enum {
    auto,
    always,
    never,
};

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
    zip64: Zip64Mode = .auto,
    deflate_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
    deflate64_options: deflate64.EncodeOptions = .{},
    bzip2_options: bzip2.EncodeOptions = .{},
    lzma_options: lzma_writer.ZipEncodeOptions = .{},
    xz_options: xz.EncodeOptions = .{},
    zstd_level: c_int = zstd.default_compression_level,
    zstd_options: zstd.FrameOptions = .{},
};

const local_file_signature: u32 = 0x0403_4b50;
const central_file_signature: u32 = 0x0201_4b50;
const data_descriptor_signature: u32 = 0x0807_4b50;
const end_of_central_signature: u32 = 0x0605_4b50;
const zip64_end_of_central_signature: u32 = 0x0606_4b50;
const zip64_end_of_central_locator_signature: u32 = 0x0706_4b50;
const zip64_extra_id: u16 = 0x0001;
const version_20: u16 = 20;
const version_21: u16 = 21;
const version_45: u16 = 45;
const deterministic_dos_time: u16 = 0;
const deterministic_dos_date: u16 = 0x0021;
const descriptor_flag: u16 = 1 << 3;
const lzma_end_marker_flag: u16 = 1 << 1;
const utf8_flag: u16 = 1 << 11;

const EncodedEntry = struct {
    source: EncodeEntry,
    flags: u16,
    crc32: u32,
    compressed_size: u64,
    uncompressed_size: u64,
    local_header_offset: u64,
    zip64: bool,
};

/// Encode a deterministic single-disk ZIP archive.
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

/// Append one complete ZIP archive without changing `out.items` on error.
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
    const archive_base = out.items.len;
    if (options.zip64 == .never) _ = try zip32Value(archive_base);

    const encoded_entries = try allocator.alloc(EncodedEntry, entries.len);
    defer allocator.free(encoded_entries);

    var archive: std.ArrayList(u8) = .empty;
    defer archive.deinit(allocator);

    for (entries, encoded_entries) |entry, *encoded| {
        const local_offset = try absoluteOffset(archive_base, archive.items.len);
        const crc = checksum.crc32Best(entry.data);
        const uncompressed_size = try usizeToU64(entry.data.len);
        const flags: u16 = (if (entry.method == .lzma) lzma_end_marker_flag else 0) |
            (if (options.data_descriptor) descriptor_flag else 0) |
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
            .deflate64 => blk: {
                const bytes = try deflate64.encodeAlloc(allocator, entry.data, options.deflate64_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .bzip2 => blk: {
                const bytes = try bzip2.encodeAlloc(allocator, entry.data, options.bzip2_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .lzma => blk: {
                const bytes = try lzma_writer.encodeZipPayloadAlloc(allocator, entry.data, options.lzma_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .xz => blk: {
                const bytes = try xz.encodeAlloc(allocator, entry.data, options.xz_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .zstandard_legacy, .zstandard => blk: {
                const bytes = try zstd.encodeFrameWithLevelAndOptionsAlloc(
                    allocator,
                    entry.data,
                    options.zstd_level,
                    options.zstd_options,
                );
                owned_compressed = bytes;
                break :blk bytes;
            },
            else => return error.UnsupportedZipCompressionMethod,
        };
        const compressed_size = try usizeToU64(compressed.len);
        const entry_zip64 = options.zip64 == .always or
            compressed_size >= std.math.maxInt(u32) or
            uncompressed_size >= std.math.maxInt(u32) or
            local_offset >= std.math.maxInt(u32);
        if (entry_zip64 and options.zip64 == .never) return error.Zip32LimitExceeded;

        try appendLocalHeader(
            allocator,
            &archive,
            entry,
            flags,
            crc,
            compressed_size,
            uncompressed_size,
            entry_zip64,
        );
        try archive.appendSlice(allocator, compressed);
        if (options.data_descriptor) {
            try appendU32(allocator, &archive, data_descriptor_signature);
            try appendU32(allocator, &archive, crc);
            if (entry_zip64) {
                try appendU64(allocator, &archive, compressed_size);
                try appendU64(allocator, &archive, uncompressed_size);
            } else {
                try appendU32(allocator, &archive, @intCast(compressed_size));
                try appendU32(allocator, &archive, @intCast(uncompressed_size));
            }
        }

        encoded.* = .{
            .source = entry,
            .flags = flags,
            .crc32 = crc,
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .local_header_offset = local_offset,
            .zip64 = entry_zip64,
        };
    }

    const central_offset = try absoluteOffset(archive_base, archive.items.len);
    const central_start = archive.items.len;
    for (encoded_entries) |entry| try appendCentralHeader(allocator, &archive, entry);
    const central_size = try usizeToU64(archive.items.len - central_start);
    const entry_count = try usizeToU64(entries.len);
    const archive_zip64 = options.zip64 == .always or
        anyZip64Entry(encoded_entries) or
        entry_count >= std.math.maxInt(u16) or
        central_size >= std.math.maxInt(u32) or
        central_offset >= std.math.maxInt(u32);
    if (archive_zip64 and options.zip64 == .never) return error.Zip32LimitExceeded;

    if (archive_zip64) {
        try appendZip64End(
            allocator,
            &archive,
            archive_base,
            entry_count,
            central_size,
            central_offset,
            options.archive_comment,
        );
    } else {
        try appendLegacyEnd(
            allocator,
            &archive,
            @intCast(entry_count),
            @intCast(central_size),
            @intCast(central_offset),
            options.archive_comment,
        );
    }

    try out.ensureUnusedCapacity(allocator, archive.items.len);
    out.appendSliceAssumeCapacity(archive.items);
    return archive.items.len;
}

fn validateInputs(entries: []const EncodeEntry, options: EncodeOptions) Error!void {
    if (options.zip64 == .never and entries.len >= std.math.maxInt(u16))
        return error.Zip32LimitExceeded;
    if (options.archive_comment.len > std.math.maxInt(u16)) return error.Zip32LimitExceeded;
    for (entries) |entry| {
        if (entry.name.len == 0) return error.InvalidZipEntryName;
        if (entry.name.len > std.math.maxInt(u16) or entry.comment.len > std.math.maxInt(u16))
            return error.Zip32LimitExceeded;
        if (options.zip64 == .never and entry.data.len >= std.math.maxInt(u32))
            return error.Zip32LimitExceeded;
        switch (entry.method) {
            .stored, .deflate, .deflate64, .bzip2, .xz, .zstandard_legacy, .zstandard => {},
            .lzma => try lzma_writer.validateZipOptions(options.lzma_options),
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
    compressed_size: u64,
    uncompressed_size: u64,
    zip64: bool,
) !void {
    const descriptor = flags & descriptor_flag != 0;
    try appendU32(allocator, out, local_file_signature);
    try appendU16(allocator, out, requiredVersion(entry.method, zip64));
    try appendU16(allocator, out, flags);
    try appendU16(allocator, out, @intFromEnum(entry.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, if (descriptor) 0 else crc);
    try appendU32(allocator, out, if (zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(compressed_size));
    try appendU32(allocator, out, if (zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, if (zip64) 20 else 0);
    try out.appendSlice(allocator, entry.name);
    if (zip64) {
        try appendU16(allocator, out, zip64_extra_id);
        try appendU16(allocator, out, 16);
        try appendU64(allocator, out, uncompressed_size);
        try appendU64(allocator, out, compressed_size);
    }
}

fn appendCentralHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
) !void {
    try appendU32(allocator, out, central_file_signature);
    try appendU16(allocator, out, requiredVersion(entry.source.method, entry.zip64));
    try appendU16(allocator, out, requiredVersion(entry.source.method, entry.zip64));
    try appendU16(allocator, out, entry.flags);
    try appendU16(allocator, out, @intFromEnum(entry.source.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, entry.crc32);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.compressed_size));
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.source.name.len));
    try appendU16(allocator, out, if (entry.zip64) 28 else 0);
    try appendU16(allocator, out, @intCast(entry.source.comment.len));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0);
    const external_attributes: u32 = if (std.mem.endsWith(u8, entry.source.name, "/")) 0x10 else 0;
    try appendU32(allocator, out, external_attributes);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.local_header_offset));
    try out.appendSlice(allocator, entry.source.name);
    if (entry.zip64) {
        try appendU16(allocator, out, zip64_extra_id);
        try appendU16(allocator, out, 24);
        try appendU64(allocator, out, entry.uncompressed_size);
        try appendU64(allocator, out, entry.compressed_size);
        try appendU64(allocator, out, entry.local_header_offset);
    }
    try out.appendSlice(allocator, entry.source.comment);
}

fn appendZip64End(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    archive_base: usize,
    entry_count: u64,
    central_size: u64,
    central_offset: u64,
    comment: []const u8,
) !void {
    const record_offset = try absoluteOffset(archive_base, out.items.len);
    try appendU32(allocator, out, zip64_end_of_central_signature);
    try appendU64(allocator, out, 44);
    try appendU16(allocator, out, version_45);
    try appendU16(allocator, out, version_45);
    try appendU32(allocator, out, 0);
    try appendU32(allocator, out, 0);
    try appendU64(allocator, out, entry_count);
    try appendU64(allocator, out, entry_count);
    try appendU64(allocator, out, central_size);
    try appendU64(allocator, out, central_offset);

    try appendU32(allocator, out, zip64_end_of_central_locator_signature);
    try appendU32(allocator, out, 0);
    try appendU64(allocator, out, record_offset);
    try appendU32(allocator, out, 1);
    try appendLegacyEnd(
        allocator,
        out,
        std.math.maxInt(u16),
        std.math.maxInt(u32),
        std.math.maxInt(u32),
        comment,
    );
}

fn appendLegacyEnd(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry_count: u16,
    central_size: u32,
    central_offset: u32,
    comment: []const u8,
) !void {
    try appendU32(allocator, out, end_of_central_signature);
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, entry_count);
    try appendU16(allocator, out, entry_count);
    try appendU32(allocator, out, central_size);
    try appendU32(allocator, out, central_offset);
    try appendU16(allocator, out, @intCast(comment.len));
    try out.appendSlice(allocator, comment);
}

fn anyZip64Entry(entries: []const EncodedEntry) bool {
    for (entries) |entry| if (entry.zip64) return true;
    return false;
}

fn requiredVersion(method: CompressionMethod, zip64: bool) u16 {
    if (method == .deflate64) return if (zip64) version_45 else version_21;
    if (method == .bzip2) return 46;
    if (method == .lzma or method == .xz or isZstandardMethod(method)) return 63;
    return if (zip64) version_45 else version_20;
}

fn isZstandardMethod(method: CompressionMethod) bool {
    return method == .zstandard_legacy or method == .zstandard;
}

fn absoluteOffset(base: usize, relative: usize) Error!u64 {
    const value = std.math.add(usize, base, relative) catch return error.IntegerOverflow;
    return usizeToU64(value);
}

fn zip32Value(value: usize) Error!u32 {
    if (value >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
    return @intCast(value);
}

fn usizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
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

fn appendU64(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

test "ZIP writer rejects ZIP32 sentinel counts and overlong comments" {
    const allocator = std.testing.allocator;
    const too_many = try allocator.alloc(EncodeEntry, std.math.maxInt(u16));
    defer allocator.free(too_many);
    try std.testing.expectError(error.Zip32LimitExceeded, validateInputs(too_many, .{ .zip64 = .never }));

    const overlong_comment = try allocator.alloc(u8, @as(usize, std.math.maxInt(u16)) + 1);
    defer allocator.free(overlong_comment);
    try std.testing.expectError(
        error.Zip32LimitExceeded,
        validateInputs(&.{}, .{ .archive_comment = overlong_comment }),
    );
}
