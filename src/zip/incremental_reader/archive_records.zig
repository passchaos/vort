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
    dos_time: u16,
    modified: types.DosTimestamp,
    extended_timestamp: ?types.ExtendedTimestamp,
    ntfs_timestamp: ?types.NtfsTimestamp,
    name: []const u8,
    unicode_name: ?[]const u8,
    extra: []const u8,
    descriptor_layout: ?descriptor.Layout,
    crc32: ?u32,
    compressed_size: ?usize,
    uncompressed_size: ?usize,
    zip64: bool,
    winzip_aes: ?types.WinZipAesInfo,
    pkware_strong: bool,
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
    const wire_method: CompressionMethod = @enumFromInt(std.mem.readInt(u16, bytes[8..10], .little));
    const dos_time = std.mem.readInt(u16, bytes[10..12], .little);
    const crc32 = std.mem.readInt(u32, bytes[14..18], .little);
    const compressed_u32 = std.mem.readInt(u32, bytes[18..22], .little);
    const uncompressed_u32 = std.mem.readInt(u32, bytes[22..26], .little);
    const name_len: usize = std.mem.readInt(u16, bytes[26..28], .little);
    const extra_len: usize = std.mem.readInt(u16, bytes[28..30], .little);
    const name_end = wire.local_file_header_len + name_len;
    const extra_end = name_end + extra_len;
    const extra = bytes[name_end..extra_end];
    const parsed_aes = try records.parseWinZipAesExtra(extra);
    const name = bytes[wire.local_file_header_len..name_end];
    const unicode_name = try records.parseUnicodePathExtra(extra, name);
    const extended_timestamp = try records.parseExtendedTimestampExtra(extra, .local);
    const ntfs_timestamp = try records.parseNtfsTimestampExtra(extra);
    if (try records.parsePkwareStrongEncryptionExtra(extra) != null)
        return error.InvalidZipArchive;
    if ((wire_method == .aes) != (parsed_aes != null)) return error.InvalidZipArchive;
    if (parsed_aes != null and
        (flags & wire.encrypted_flag == 0 or version_needed < wire.version_51))
        return error.InvalidZipArchive;
    const method = if (parsed_aes) |aes| aes.actual_method else wire_method;
    const pkware_strong = flags & wire.strong_encryption_flag != 0;
    if (pkware_strong and
        (flags & wire.encrypted_flag == 0 or parsed_aes != null))
        return error.InvalidZipArchive;
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
            .dos_time = dos_time,
            .modified = .{
                .time = dos_time,
                .date = std.mem.readInt(u16, bytes[12..14], .little),
            },
            .extended_timestamp = extended_timestamp,
            .ntfs_timestamp = ntfs_timestamp,
            .name = name,
            .unicode_name = unicode_name,
            .extra = extra,
            .descriptor_layout = if (zip64) .zip64 else .zip32,
            .crc32 = null,
            .compressed_size = null,
            .uncompressed_size = null,
            .zip64 = zip64,
            .winzip_aes = if (parsed_aes) |aes| aes.info else null,
            .pkware_strong = pkware_strong,
        };
    }

    const sizes = try records.resolveLocalSizes(extra, compressed_u32, uncompressed_u32);
    return .{
        .version_needed = version_needed,
        .flags = flags,
        .method = method,
        .dos_time = dos_time,
        .modified = .{
            .time = dos_time,
            .date = std.mem.readInt(u16, bytes[12..14], .little),
        },
        .extended_timestamp = extended_timestamp,
        .ntfs_timestamp = ntfs_timestamp,
        .name = name,
        .unicode_name = unicode_name,
        .extra = extra,
        .descriptor_layout = null,
        .crc32 = crc32,
        .compressed_size = sizes.compressed_size,
        .uncompressed_size = sizes.uncompressed_size,
        .zip64 = zip64,
        .winzip_aes = if (parsed_aes) |aes| aes.info else null,
        .pkware_strong = pkware_strong,
    };
}

pub const CentralHeader = struct {
    version_made_by: u16,
    version_needed: u16,
    flags: u16,
    method: CompressionMethod,
    name: []const u8,
    comment: []const u8,
    unicode_name: ?[]const u8,
    unicode_comment: ?[]const u8,
    modified: types.DosTimestamp,
    extended_timestamp: ?types.ExtendedTimestamp,
    ntfs_timestamp: ?types.NtfsTimestamp,
    internal_attributes: u16,
    external_attributes: u32,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    zip64: bool,
    winzip_aes: ?types.WinZipAesInfo,
    pkware_strong_encryption: ?types.PkwareStrongEncryptionInfo,
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
    const version_made_by = std.mem.readInt(u16, bytes[4..6], .little);
    const flags = std.mem.readInt(u16, bytes[8..10], .little);
    const wire_method: CompressionMethod = @enumFromInt(std.mem.readInt(u16, bytes[10..12], .little));
    const crc32 = std.mem.readInt(u32, bytes[16..20], .little);
    const compressed_u32 = std.mem.readInt(u32, bytes[20..24], .little);
    const uncompressed_u32 = std.mem.readInt(u32, bytes[24..28], .little);
    const name_len: usize = std.mem.readInt(u16, bytes[28..30], .little);
    const extra_len: usize = std.mem.readInt(u16, bytes[30..32], .little);
    const comment_len: usize = std.mem.readInt(u16, bytes[32..34], .little);
    const disk_start = std.mem.readInt(u16, bytes[34..36], .little);
    const local_offset_u32 = std.mem.readInt(u32, bytes[42..46], .little);
    const name_end = wire.central_file_header_len + name_len;
    const extra_end = name_end + extra_len;
    const comment_end = extra_end + comment_len;
    const name = bytes[wire.central_file_header_len..name_end];
    const comment = bytes[extra_end..comment_end];
    const values = try records.resolveCentralEntry(
        bytes[name_end..extra_end],
        compressed_u32,
        uncompressed_u32,
        local_offset_u32,
        disk_start,
    );
    const parsed_aes = try records.parseWinZipAesExtra(bytes[name_end..extra_end]);
    const unicode_name = try records.parseUnicodePathExtra(
        bytes[name_end..extra_end],
        name,
    );
    const unicode_comment = try records.parseUnicodeCommentExtra(
        bytes[name_end..extra_end],
        comment,
    );
    const extended_timestamp = try records.parseExtendedTimestampExtra(
        bytes[name_end..extra_end],
        .central,
    );
    const ntfs_timestamp = try records.parseNtfsTimestampExtra(
        bytes[name_end..extra_end],
    );
    const parsed_strong = try records.parsePkwareStrongEncryptionExtra(
        bytes[name_end..extra_end],
    );
    if ((wire_method == .aes) != (parsed_aes != null)) return error.InvalidZipArchive;
    if (parsed_aes != null and
        (flags & wire.encrypted_flag == 0 or version_needed < wire.version_51))
        return error.InvalidZipArchive;
    if (parsed_aes != null and parsed_strong != null) return error.InvalidZipArchive;
    const strong_flag = flags & wire.strong_encryption_flag != 0;
    if (strong_flag != (parsed_strong != null) or
        (strong_flag and flags & wire.encrypted_flag == 0) or
        (parsed_strong != null and version_needed < wire.version_51))
        return error.InvalidZipArchive;
    const method = if (parsed_aes) |aes| aes.actual_method else wire_method;
    if (values.zip64 and version_needed < wire.version_45) return error.InvalidZipArchive;
    if (method == .shrink and version_needed < wire.version_10)
        return error.InvalidZipArchive;
    if ((method == .reduce_1 or method == .reduce_2 or
        method == .reduce_3 or method == .reduce_4) and
        version_needed < wire.version_10)
        return error.InvalidZipArchive;
    if (method == .implode and version_needed < wire.version_10)
        return error.InvalidZipArchive;
    if (method == .bzip2 and version_needed < wire.version_46)
        return error.InvalidZipArchive;
    if (method == .deflate64 and version_needed < wire.version_21)
        return error.InvalidZipArchive;
    if (method == .dcl_implode and version_needed < wire.version_20)
        return error.InvalidZipArchive;
    if ((method == .lzma or method == .xz or method == .ppmd or
        method == .zstandard_legacy or method == .zstandard) and
        version_needed < wire.version_63)
        return error.InvalidZipArchive;
    return .{
        .version_made_by = version_made_by,
        .version_needed = version_needed,
        .flags = flags,
        .method = method,
        .name = name,
        .comment = comment,
        .unicode_name = unicode_name,
        .unicode_comment = unicode_comment,
        .modified = .{
            .time = std.mem.readInt(u16, bytes[12..14], .little),
            .date = std.mem.readInt(u16, bytes[14..16], .little),
        },
        .extended_timestamp = extended_timestamp,
        .ntfs_timestamp = ntfs_timestamp,
        .internal_attributes = std.mem.readInt(u16, bytes[36..38], .little),
        .external_attributes = std.mem.readInt(u32, bytes[38..42], .little),
        .crc32 = crc32,
        .compressed_size = values.compressed_size,
        .uncompressed_size = values.uncompressed_size,
        .local_header_offset = values.local_header_offset,
        .zip64 = values.zip64,
        .winzip_aes = if (parsed_aes) |aes| aes.info else null,
        .pkware_strong_encryption = parsed_strong,
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
