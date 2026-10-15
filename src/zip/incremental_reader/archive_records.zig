const std = @import("std");
const descriptor = @import("descriptor.zig");
const records = @import("../records.zig");
const types = @import("../types.zig");
const wire = @import("../wire.zig");

pub const Error = records.Error || error{InvalidZipArchive};
pub const CompressionMethod = types.CompressionMethod;

pub const LocalHeader = struct {
    version_needed: u16,
    flags: u16,
    method: CompressionMethod,
    name: []const u8,
    extra: []const u8,
    descriptor_layout: ?descriptor.Layout,
    crc32: ?u32,
    compressed_size: ?usize,
    uncompressed_size: ?usize,
    zip64: bool,
};

pub fn localEncodedLen(fixed: *const [wire.local_file_header_len]u8) Error!usize {
    if (std.mem.readInt(u32, fixed[0..4], .little) != wire.local_file_signature)
        return error.InvalidZipArchive;
    return checkedAdd(
        wire.local_file_header_len,
        try checkedAdd(
            std.mem.readInt(u16, fixed[26..28], .little),
            std.mem.readInt(u16, fixed[28..30], .little),
        ),
    );
}

pub fn parseLocal(bytes: []const u8) Error!LocalHeader {
    if (bytes.len < wire.local_file_header_len) return error.InvalidZipArchive;
    const fixed: *const [wire.local_file_header_len]u8 = bytes[0..wire.local_file_header_len];
    if (try localEncodedLen(fixed) != bytes.len) return error.InvalidZipArchive;
    const version_needed = std.mem.readInt(u16, bytes[4..6], .little);
    const flags = std.mem.readInt(u16, bytes[6..8], .little);
    const method: CompressionMethod = @enumFromInt(std.mem.readInt(u16, bytes[8..10], .little));
    const crc32 = std.mem.readInt(u32, bytes[14..18], .little);
    const compressed_u32 = std.mem.readInt(u32, bytes[18..22], .little);
    const uncompressed_u32 = std.mem.readInt(u32, bytes[22..26], .little);
    const name_len: usize = std.mem.readInt(u16, bytes[26..28], .little);
    const extra_len: usize = std.mem.readInt(u16, bytes[28..30], .little);
    const name_end = wire.local_file_header_len + name_len;
    const extra_end = name_end + extra_len;
    const extra = bytes[name_end..extra_end];
    const uses_descriptor = flags & wire.descriptor_flag != 0;
    const has_zip64_extra = try hasZip64Extra(extra);
    const has_zip64_sentinel = compressed_u32 == std.math.maxInt(u32) or
        uncompressed_u32 == std.math.maxInt(u32);
    const zip64 = has_zip64_sentinel or (uses_descriptor and has_zip64_extra);
    if (has_zip64_sentinel and version_needed < wire.version_45)
        return error.InvalidZipArchive;

    if (uses_descriptor) {
        if (has_zip64_sentinel)
            _ = try records.resolveLocalSizes(extra, compressed_u32, uncompressed_u32);
        return .{
            .version_needed = version_needed,
            .flags = flags,
            .method = method,
            .name = bytes[wire.local_file_header_len..name_end],
            .extra = extra,
            .descriptor_layout = if (zip64) .zip64 else .zip32,
            .crc32 = null,
            .compressed_size = null,
            .uncompressed_size = null,
            .zip64 = zip64,
        };
    }

    const sizes = try records.resolveLocalSizes(extra, compressed_u32, uncompressed_u32);
    return .{
        .version_needed = version_needed,
        .flags = flags,
        .method = method,
        .name = bytes[wire.local_file_header_len..name_end],
        .extra = extra,
        .descriptor_layout = null,
        .crc32 = crc32,
        .compressed_size = sizes.compressed_size,
        .uncompressed_size = sizes.uncompressed_size,
        .zip64 = zip64,
    };
}

pub const CentralHeader = struct {
    version_needed: u16,
    flags: u16,
    method: CompressionMethod,
    name: []const u8,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    zip64: bool,
};

pub fn centralEncodedLen(fixed: *const [wire.central_file_header_len]u8) Error!usize {
    if (std.mem.readInt(u32, fixed[0..4], .little) != wire.central_file_signature)
        return error.InvalidZipArchive;
    return checkedAdd(
        wire.central_file_header_len,
        try checkedAdd(
            std.mem.readInt(u16, fixed[28..30], .little),
            try checkedAdd(
                std.mem.readInt(u16, fixed[30..32], .little),
                std.mem.readInt(u16, fixed[32..34], .little),
            ),
        ),
    );
}

pub fn parseCentral(bytes: []const u8) Error!CentralHeader {
    if (bytes.len < wire.central_file_header_len) return error.InvalidZipArchive;
    const fixed: *const [wire.central_file_header_len]u8 = bytes[0..wire.central_file_header_len];
    if (try centralEncodedLen(fixed) != bytes.len) return error.InvalidZipArchive;
    const version_needed = std.mem.readInt(u16, bytes[6..8], .little);
    const flags = std.mem.readInt(u16, bytes[8..10], .little);
    const method: CompressionMethod = @enumFromInt(std.mem.readInt(u16, bytes[10..12], .little));
    const crc32 = std.mem.readInt(u32, bytes[16..20], .little);
    const compressed_u32 = std.mem.readInt(u32, bytes[20..24], .little);
    const uncompressed_u32 = std.mem.readInt(u32, bytes[24..28], .little);
    const name_len: usize = std.mem.readInt(u16, bytes[28..30], .little);
    const extra_len: usize = std.mem.readInt(u16, bytes[30..32], .little);
    const disk_start = std.mem.readInt(u16, bytes[34..36], .little);
    const local_offset_u32 = std.mem.readInt(u32, bytes[42..46], .little);
    const name_end = wire.central_file_header_len + name_len;
    const extra_end = name_end + extra_len;
    const values = try records.resolveCentralEntry(
        bytes[name_end..extra_end],
        compressed_u32,
        uncompressed_u32,
        local_offset_u32,
        disk_start,
    );
    if (values.zip64 and version_needed < wire.version_45) return error.InvalidZipArchive;
    return .{
        .version_needed = version_needed,
        .flags = flags,
        .method = method,
        .name = bytes[wire.central_file_header_len..name_end],
        .crc32 = crc32,
        .compressed_size = values.compressed_size,
        .uncompressed_size = values.uncompressed_size,
        .local_header_offset = values.local_header_offset,
        .zip64 = values.zip64,
    };
}

pub const Zip64End = struct {
    disk: u32,
    central_disk: u32,
    entries_on_disk: u64,
    entry_count: u64,
    central_size: u64,
    central_offset: u64,
};

pub fn zip64EndEncodedLen(prefix: *const [12]u8) Error!usize {
    if (std.mem.readInt(u32, prefix[0..4], .little) != wire.zip64_end_of_central_signature)
        return error.InvalidZipArchive;
    const payload_len = std.mem.readInt(u64, prefix[4..12], .little);
    if (payload_len < 44) return error.InvalidZipArchive;
    return checkedAdd(12, try u64ToUsize(payload_len));
}

pub fn parseZip64End(bytes: []const u8) Error!Zip64End {
    if (bytes.len < wire.zip64_end_of_central_len) return error.InvalidZipArchive;
    if (try zip64EndEncodedLen(bytes[0..12]) != bytes.len) return error.InvalidZipArchive;
    if (std.mem.readInt(u16, bytes[14..16], .little) < wire.version_45)
        return error.InvalidZipArchive;
    return .{
        .disk = std.mem.readInt(u32, bytes[16..20], .little),
        .central_disk = std.mem.readInt(u32, bytes[20..24], .little),
        .entries_on_disk = std.mem.readInt(u64, bytes[24..32], .little),
        .entry_count = std.mem.readInt(u64, bytes[32..40], .little),
        .central_size = std.mem.readInt(u64, bytes[40..48], .little),
        .central_offset = std.mem.readInt(u64, bytes[48..56], .little),
    };
}

pub const Zip64Locator = struct {
    disk: u32,
    end_offset: u64,
    disk_count: u32,
};

pub fn parseZip64Locator(bytes: *const [wire.zip64_end_of_central_locator_len]u8) Error!Zip64Locator {
    if (std.mem.readInt(u32, bytes[0..4], .little) != wire.zip64_end_of_central_locator_signature)
        return error.InvalidZipArchive;
    return .{
        .disk = std.mem.readInt(u32, bytes[4..8], .little),
        .end_offset = std.mem.readInt(u64, bytes[8..16], .little),
        .disk_count = std.mem.readInt(u32, bytes[16..20], .little),
    };
}

pub const End = struct {
    disk: u16,
    central_disk: u16,
    entries_on_disk: u16,
    entry_count: u16,
    central_size: u32,
    central_offset: u32,
    comment: []const u8,
};

pub fn endEncodedLen(fixed: *const [wire.end_of_central_len]u8) Error!usize {
    if (std.mem.readInt(u32, fixed[0..4], .little) != wire.end_of_central_signature)
        return error.InvalidZipArchive;
    return checkedAdd(wire.end_of_central_len, std.mem.readInt(u16, fixed[20..22], .little));
}

pub fn parseEnd(bytes: []const u8) Error!End {
    if (bytes.len < wire.end_of_central_len) return error.InvalidZipArchive;
    const fixed: *const [wire.end_of_central_len]u8 = bytes[0..wire.end_of_central_len];
    if (try endEncodedLen(fixed) != bytes.len) return error.InvalidZipArchive;
    return .{
        .disk = std.mem.readInt(u16, bytes[4..6], .little),
        .central_disk = std.mem.readInt(u16, bytes[6..8], .little),
        .entries_on_disk = std.mem.readInt(u16, bytes[8..10], .little),
        .entry_count = std.mem.readInt(u16, bytes[10..12], .little),
        .central_size = std.mem.readInt(u32, bytes[12..16], .little),
        .central_offset = std.mem.readInt(u32, bytes[16..20], .little),
        .comment = bytes[wire.end_of_central_len..],
    };
}

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedZipFeature;
}

fn hasZip64Extra(extra: []const u8) Error!bool {
    var offset: usize = 0;
    var found = false;
    while (offset < extra.len) {
        const header_end = try checkedAdd(offset, 4);
        if (header_end > extra.len) return error.InvalidZipArchive;
        const id = std.mem.readInt(u16, extra[offset..][0..2], .little);
        const size: usize = std.mem.readInt(u16, extra[offset + 2 ..][0..2], .little);
        const payload_end = try checkedAdd(header_end, size);
        if (payload_end > extra.len) return error.InvalidZipArchive;
        if (id == wire.zip64_extra_id) {
            if (found or size < 16) return error.InvalidZipArchive;
            found = true;
        }
        offset = payload_end;
    }
    return found;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.InvalidZipArchive;
}
