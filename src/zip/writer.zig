const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const dcl_implode = @import("dcl_implode.zig");
const deflate = @import("../deflate.zig");
const deflate64 = @import("../deflate64.zig");
const implode = @import("implode.zig");
const lzma_writer = @import("../lzma/writer.zig");
const ppmd8 = @import("../ppmd8.zig");
const pkware_strong = @import("pkware_strong.zig");
const reduce = @import("reduce.zig");
const shrink = @import("shrink.zig");
const types = @import("types.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;
const wire = @import("wire.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Error = core.Error || bzip2.Error || dcl_implode.Error || deflate64.Error || implode.Error || lzma_writer.Error || ppmd8.Error || pkware_strong.Error || reduce.Error || shrink.Error || traditional_encryption.Error || winzip_aes.Error || xz.Error || zstd.Error || error{
    InvalidZipEntryName,
    InvalidZipTextEncoding,
    InvalidZipTimestamp,
    UnsupportedZipCompressionMethod,
    Zip32LimitExceeded,
    ConflictingZipEncryption,
};

pub const CompressionMethod = types.CompressionMethod;
pub const CreatorSystem = types.CreatorSystem;
pub const DosTimestamp = types.DosTimestamp;
pub const ExtendedTimestamp = types.ExtendedTimestamp;
pub const NtfsTimestamp = types.NtfsTimestamp;

pub const Zip64Mode = enum {
    auto,
    always,
    never,
};

pub const WinZipAesOptions = struct {
    password: []const u8,
    strength: types.WinZipAesStrength = .aes256,
    salt: []const u8,
    version: types.WinZipAesVendorVersion = .ae2,
};

pub const PkwareStrongEncryptionOptions = pkware_strong.Options;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8,
    method: CompressionMethod = .deflate,
    comment: []const u8 = "",
    unicode_name: ?[]const u8 = null,
    unicode_comment: ?[]const u8 = null,
    /// Validated MS-DOS modification time; defaults preserve deterministic wire.
    modified: DosTimestamp = .deterministic,
    extended_timestamp: ?ExtendedTimestamp = null,
    ntfs_timestamp: ?NtfsTimestamp = null,
    creator_system: CreatorSystem = .fat,
    internal_attributes: u16 = 0,
    /// Null derives only the conventional DOS directory bit from a trailing `/`.
    external_attributes: ?u32 = null,
    traditional_encryption: ?traditional_encryption.Options = null,
    winzip_aes: ?WinZipAesOptions = null,
    pkware_strong_encryption: ?PkwareStrongEncryptionOptions = null,
};

pub const EncodeOptions = struct {
    archive_comment: []const u8 = "",
    archive_extra_data: []const u8 = "",
    data_descriptor: bool = false,
    utf8: bool = true,
    zip64: Zip64Mode = .auto,
    deflate_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
    deflate64_options: deflate64.EncodeOptions = .{},
    dcl_implode_options: dcl_implode.Options = .{},
    implode_options: implode.Options = .{},
    bzip2_options: bzip2.EncodeOptions = .{},
    lzma_options: lzma_writer.ZipEncodeOptions = .{},
    ppmd_options: ppmd8.ZipProperties = .{},
    reduce_options: reduce.Options = .{},
    xz_options: xz.EncodeOptions = .{},
    zstd_level: c_int = zstd.default_compression_level,
    zstd_options: zstd.FrameOptions = .{},
    /// Borrowed preset history for every Zstandard entry in this archive.
    zstd_dictionary: ?zstd.NativeDictionary = null,
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
    if (options.zip64 == .never) _ = try wire.zip32Value(archive_base);

    const encoded_entries = try allocator.alloc(wire.EncodedEntry, entries.len);
    defer allocator.free(encoded_entries);

    var archive: std.ArrayList(u8) = .empty;
    defer archive.deinit(allocator);

    for (entries, encoded_entries) |entry, *encoded| {
        const local_offset = try wire.absoluteOffset(archive_base, archive.items.len);
        const crc = checksum.crc32Best(entry.data);
        const uncompressed_size = try wire.usizeToU64(entry.data.len);
        const flags: u16 = (if (entry.method == .lzma) wire.lzma_end_marker_flag else 0) |
            (if (entry.method == .implode) options.implode_options.flags() else 0) |
            (if (entry.traditional_encryption != null or entry.winzip_aes != null or
                entry.pkware_strong_encryption != null) wire.encrypted_flag else 0) |
            (if (entry.pkware_strong_encryption != null) wire.strong_encryption_flag else 0) |
            (if (options.data_descriptor) wire.descriptor_flag else 0) |
            (if (options.utf8) wire.utf8_flag else 0);

        var owned_compressed: ?[]u8 = null;
        defer if (owned_compressed) |bytes| allocator.free(bytes);
        const codec_payload = switch (entry.method) {
            .stored => entry.data,
            .shrink => blk: {
                const bytes = try shrink.encodeAlloc(allocator, entry.data);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => blk: {
                const bytes = try reduce.encodeAlloc(
                    allocator,
                    entry.data,
                    reduceFactor(entry.method).?,
                    options.reduce_options,
                );
                owned_compressed = bytes;
                break :blk bytes;
            },
            .implode => blk: {
                const bytes = try implode.encodeAlloc(allocator, entry.data, options.implode_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
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
            .dcl_implode => blk: {
                const bytes = try dcl_implode.encodeAlloc(allocator, entry.data, options.dcl_implode_options);
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
            .ppmd => blk: {
                const bytes = try ppmd8.encodeZipAlloc(allocator, entry.data, options.ppmd_options);
                owned_compressed = bytes;
                break :blk bytes;
            },
            .zstandard_legacy, .zstandard => blk: {
                const bytes = if (options.zstd_dictionary) |dictionary|
                    try zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(
                        allocator,
                        entry.data,
                        options.zstd_level,
                        options.zstd_options,
                        dictionary,
                    )
                else
                    try zstd.encodeFrameWithLevelAndOptionsAlloc(
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
        var owned_encrypted: ?[]u8 = null;
        defer if (owned_encrypted) |bytes| {
            std.crypto.secureZero(u8, bytes);
            allocator.free(bytes);
        };
        const compressed = if (entry.traditional_encryption) |encryption| encrypted: {
            const check_byte: u8 = if (options.data_descriptor)
                @truncate(entry.modified.time >> 8)
            else
                @truncate(crc >> 24);
            const bytes = try traditional_encryption.encryptAlloc(
                allocator,
                codec_payload,
                encryption,
                check_byte,
            );
            owned_encrypted = bytes;
            break :encrypted bytes;
        } else if (entry.winzip_aes) |encryption| encrypted: {
            const bytes = try winzip_aes.encryptAlloc(allocator, codec_payload, .{
                .password = encryption.password,
                .strength = encryption.strength,
                .salt = encryption.salt,
            });
            owned_encrypted = bytes;
            break :encrypted bytes;
        } else if (entry.pkware_strong_encryption) |encryption| encrypted: {
            const bytes = try pkware_strong.encryptAlloc(allocator, codec_payload, encryption);
            owned_encrypted = bytes;
            break :encrypted bytes;
        } else codec_payload;
        const compressed_size = try wire.usizeToU64(compressed.len);
        const entry_zip64 = wire.selectEntryZip64(
            options.zip64 == .always,
            compressed_size,
            uncompressed_size,
            local_offset,
        );
        if (entry_zip64 and options.zip64 == .never) return error.Zip32LimitExceeded;

        encoded.* = .{
            .name = entry.name,
            .comment = entry.comment,
            .unicode_name = entry.unicode_name,
            .unicode_comment = entry.unicode_comment,
            .method = entry.method,
            .flags = flags,
            .crc32 = if (entry.winzip_aes) |aes|
                if (aes.version == .ae2) 0 else crc
            else
                crc,
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .local_header_offset = local_offset,
            .zip64 = entry_zip64,
            .modified = entry.modified,
            .extended_timestamp = entry.extended_timestamp,
            .ntfs_timestamp = entry.ntfs_timestamp,
            .creator_system = entry.creator_system,
            .internal_attributes = entry.internal_attributes,
            .external_attributes = entry.external_attributes,
            .winzip_aes = if (entry.winzip_aes) |aes| .{
                .version = aes.version,
                .strength = aes.strength,
            } else null,
            .pkware_strong_encryption = if (entry.pkware_strong_encryption) |strong| .{
                .strength = strong.strength,
            } else null,
        };
        if (wire.localExtraLen(encoded.*) > std.math.maxInt(u16) or
            wire.centralExtraLen(encoded.*) > std.math.maxInt(u16))
        {
            return error.Zip32LimitExceeded;
        }
        try wire.appendLocalHeader(allocator, &archive, encoded.*, .{});
        try archive.appendSlice(allocator, compressed);
        if (options.data_descriptor) try wire.appendDataDescriptor(allocator, &archive, encoded.*);
    }

    const central_offset = try wire.absoluteOffset(archive_base, archive.items.len);
    const central_start = archive.items.len;
    try wire.appendArchiveExtraData(allocator, &archive, options.archive_extra_data);
    for (encoded_entries) |entry| try wire.appendCentralHeader(allocator, &archive, entry);
    const central_size = try wire.usizeToU64(archive.items.len - central_start);
    const entry_count = try wire.usizeToU64(entries.len);
    const archive_zip64 = wire.selectArchiveZip64(
        options.zip64 == .always,
        encoded_entries,
        entry_count,
        central_size,
        central_offset,
    );
    if (archive_zip64 and options.zip64 == .never) return error.Zip32LimitExceeded;

    if (archive_zip64) {
        try wire.appendZip64End(
            allocator,
            &archive,
            archive_base,
            entry_count,
            central_size,
            central_offset,
            options.archive_comment,
        );
    } else {
        try wire.appendLegacyEnd(
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
    if (options.archive_extra_data.len > std.math.maxInt(u32))
        return error.Zip32LimitExceeded;
    for (entries) |entry| {
        if (!entry.modified.isValid()) return error.InvalidZipTimestamp;
        if (entry.extended_timestamp) |timestamp|
            if (!timestamp.isValid()) return error.InvalidZipTimestamp;
        if ((entry.traditional_encryption != null and entry.winzip_aes != null) or
            (entry.traditional_encryption != null and entry.pkware_strong_encryption != null) or
            (entry.winzip_aes != null and entry.pkware_strong_encryption != null))
            return error.ConflictingZipEncryption;
        if (entry.winzip_aes) |aes|
            if (aes.salt.len != aes.strength.saltLen()) return error.InvalidSaltLength;
        if (entry.pkware_strong_encryption) |strong|
            try pkware_strong.validateOptions(strong);
        if (entry.name.len == 0) return error.InvalidZipEntryName;
        if (entry.name.len > std.math.maxInt(u16) or entry.comment.len > std.math.maxInt(u16))
            return error.Zip32LimitExceeded;
        inline for (.{ entry.unicode_name, entry.unicode_comment }) |unicode_text| {
            if (unicode_text) |text| {
                if (options.utf8 or text.len == 0 or
                    text.len > std.math.maxInt(u16) - 5 or
                    !std.unicode.utf8ValidateSlice(text))
                {
                    return error.InvalidZipTextEncoding;
                }
            }
        }
        if (options.zip64 == .never and entry.data.len >= std.math.maxInt(u32))
            return error.Zip32LimitExceeded;
        switch (entry.method) {
            .stored, .shrink, .deflate, .deflate64, .bzip2, .xz, .zstandard_legacy, .zstandard => {},
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => if (options.reduce_options.max_chain == 0)
                return error.InvalidReduceOptions,
            .implode => if (options.implode_options.max_chain == 0)
                return error.InvalidImplodeOptions,
            .dcl_implode => if (options.dcl_implode_options.max_chain == 0)
                return error.InvalidDclOptions,
            .lzma => try lzma_writer.validateZipOptions(options.lzma_options),
            .ppmd => try ppmd8.validateZipProperties(options.ppmd_options),
            else => return error.UnsupportedZipCompressionMethod,
        }
        if (options.utf8 and
            (!std.unicode.utf8ValidateSlice(entry.name) or
                !std.unicode.utf8ValidateSlice(entry.comment))) return error.InvalidZipTextEncoding;
    }
}

fn reduceFactor(method: CompressionMethod) ?reduce.Factor {
    return switch (method) {
        .reduce_1 => .factor_1,
        .reduce_2 => .factor_2,
        .reduce_3 => .factor_3,
        .reduce_4 => .factor_4,
        else => null,
    };
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
