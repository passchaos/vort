const std = @import("std");
const archive = @import("archive.zig");
const checksum = @import("../checksum.zig");
const ppmd_h = @import("ppmd_h.zig");
const rar29_encoder = @import("rar29_encoder.zig");
const rar50_encoder = @import("rar50_encoder.zig");
const rar4_encryption = @import("rar4_encryption.zig");
const rar4_name = @import("rar4_name.zig");
const rar5_encryption = @import("rar5_encryption.zig");

pub const Error = archive.Error || rar29_encoder.Error || rar50_encoder.Error ||
    rar4_encryption.Error || rar4_name.Error || rar5_encryption.Error ||
    std.mem.Allocator.Error || error{
    InvalidRarEntryName,
    RarFileTooLarge,
    RarHeaderTooLarge,
    UnsupportedRarEncodeOptions,
    InvalidRarVolumeSize,
    InvalidRarHeaderEncryption,
};

pub const Kind = enum { regular, directory };
pub const Compression = enum { stored, rar29, rar29_ppmd, rar50 };
pub const Filter = union(enum) {
    delta: u8,
    e8,
    e8e9,
    arm,
    itanium,
    rgb: struct { width: usize, red_position: u8 = 0 },
    audio: u8,
};
pub const EncryptionOptions = rar5_encryption.Options;
pub const Rar4EncryptionOptions = rar4_encryption.Options;
pub const Rar4HeaderEncryptionOptions = struct {
    password: []const u8,
    salt: [rar4_encryption.salt_len]u8,
};
pub const HeaderEncryptionOptions = struct {
    password: []const u8,
    salt: [rar5_encryption.salt_len]u8,
    kdf_count: u8 = 15,
    include_password_check: bool = true,
    /// One unique unpredictable IV for main, every file/directory, and end
    /// header, in wire order. Its length must equal `entries.len + 2`.
    ivs: []const [rar5_encryption.iv_len]u8,

    fn cryptoOptions(self: HeaderEncryptionOptions) rar5_encryption.HeaderOptions {
        return .{
            .password = self.password,
            .salt = self.salt,
            .kdf_count = self.kdf_count,
            .include_password_check = self.include_password_check,
        };
    }
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    kind: Kind = .regular,
    mode: ?u32 = null,
    /// RAR4 stores a DOS date/time word; RAR5 stores Unix seconds.
    /// The value is therefore native to the selected container generation.
    mtime: ?u32 = null,
    /// RAR5 file-data encryption. Salt and IV must be unique and unpredictable
    /// for each regular entry; generation remains explicitly caller-owned.
    encryption: ?EncryptionOptions = null,
    /// RAR 3.x/4.x AES-128 file-data encryption.
    rar4_encryption: ?Rar4EncryptionOptions = null,
};

pub const EncodeOptions = struct {
    version: archive.Version = .rar5,
    compression: Compression = .stored,
    dictionary_size: usize = 128 * 1024,
    block_size: usize = 64 * 1024,
    filter: ?Filter = null,
    solid: bool = false,
    ppmd_order: u8 = 8,
    ppmd_memory_size: usize = 25 * 1024 * 1024,
    header_encryption: ?HeaderEncryptionOptions = null,
    rar4_header_encryption: ?Rar4HeaderEncryptionOptions = null,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try validateEntries(entries, options, false);
    const start = output.items.len;
    errdefer output.items.len = start;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    switch (options.version) {
        .rar4 => try encodeRar4(allocator, &encoded, entries, options),
        .rar5 => try encodeRar5(allocator, &encoded, entries, options),
    }
    try output.appendSlice(allocator, encoded.items);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub const EncodedVolumes = struct {
    allocator: std.mem.Allocator,
    volumes: [][]u8,

    pub fn deinit(self: *EncodedVolumes) void {
        for (self.volumes) |volume| self.allocator.free(volume);
        self.allocator.free(self.volumes);
        self.* = undefined;
    }
};

pub fn encodeVolumesAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
    max_payload_per_volume: usize,
) Error!EncodedVolumes {
    if (max_payload_per_volume == 0) return error.InvalidRarVolumeSize;
    try validateEntries(entries, options, true);
    if (options.version == .rar4)
        return encodeRar4VolumesAlloc(
            allocator,
            entries,
            options,
            max_payload_per_volume,
        );
    if (options.version != .rar5) return error.UnsupportedRarEncodeOptions;

    var volumes: std.ArrayList([]u8) = .empty;
    errdefer {
        for (volumes.items) |volume| allocator.free(volume);
        volumes.deinit(allocator);
    }
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var volume_index: usize = 0;
    var payload_in_volume: usize = 0;
    var header_writer: ?HeaderWriter = if (options.header_encryption) |encryption|
        try HeaderWriter.init(encryption)
    else
        null;
    defer if (header_writer) |*value| value.deinit();
    const header_writer_ptr: ?*HeaderWriter = if (header_writer) |*value| value else null;
    try startRar5Volume(
        allocator,
        &current,
        volume_index,
        options.solid,
        header_writer_ptr,
    );
    var encoder = rar50_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
        .filter = try rar50Filter(options.filter),
    });
    defer encoder.deinit();

    for (entries) |entry| {
        var compressed: ?[]u8 = null;
        defer if (compressed) |bytes| allocator.free(bytes);
        const use_compression = entry.kind == .regular and options.compression == .rar50;
        if (!use_compression) encoder.reset();
        const solid_continuation = options.solid and encoder.canContinue();
        if (use_compression)
            compressed = try encoder.encodeMemberAlloc(entry.data, solid_continuation);
        const plain_payload = compressed orelse entry.data;
        const compression_info: u64 = if (use_compression)
            try rar50CompressionInfo(options.dictionary_size, solid_continuation)
        else
            0;
        const plain_crc = checksum.crc32(entry.data);
        var encrypted: ?rar5_encryption.Encrypted = if (entry.encryption) |encryption|
            try rar5_encryption.encryptAlloc(
                allocator,
                plain_payload,
                plain_crc,
                encryption,
            )
        else
            null;
        defer if (encrypted) |*value| value.deinit();
        const payload = if (encrypted) |value| value.bytes else plain_payload;
        const final_crc = if (encrypted) |value| value.wire_crc32 else plain_crc;
        var extra: std.ArrayList(u8) = .empty;
        defer extra.deinit(allocator);
        if (encrypted) |value|
            try appendRar5EncryptionRecord(allocator, &extra, value.metadata);

        var offset: usize = 0;
        var split_before = false;
        while (offset < payload.len or (!split_before and payload.len == 0)) {
            if (payload_in_volume == max_payload_per_volume) {
                try finishRar5Volume(allocator, &current, true, header_writer_ptr);
                const owned_volume = try current.toOwnedSlice(allocator);
                volumes.append(allocator, owned_volume) catch |err| {
                    allocator.free(owned_volume);
                    return err;
                };
                volume_index = std.math.add(usize, volume_index, 1) catch
                    return error.IntegerOverflow;
                payload_in_volume = 0;
                try startRar5Volume(
                    allocator,
                    &current,
                    volume_index,
                    options.solid,
                    header_writer_ptr,
                );
            }
            const room = max_payload_per_volume - payload_in_volume;
            const fragment_len = @min(room, payload.len - offset);
            const split_after = offset + fragment_len < payload.len;
            const fragment = payload[offset .. offset + fragment_len];
            const fragment_crc = if (split_after)
                checksum.crc32(fragment)
            else
                final_crc;
            var general_flags: u64 = 0;
            if (split_before) general_flags |= 0x0008;
            if (split_after) general_flags |= 0x0010;
            try appendRar5FileFragment(
                allocator,
                &current,
                entry,
                fragment,
                compression_info,
                fragment_crc,
                general_flags,
                extra.items,
                header_writer_ptr,
            );
            payload_in_volume += fragment_len;
            offset += fragment_len;
            if (!split_after) break;
            split_before = true;
        }
    }

    try finishRar5Volume(allocator, &current, false, header_writer_ptr);
    if (header_writer) |*value|
        if (value.index != value.ivs.len) return error.InvalidRarHeaderEncryption;
    const owned_volume = try current.toOwnedSlice(allocator);
    volumes.append(allocator, owned_volume) catch |err| {
        allocator.free(owned_volume);
        return err;
    };
    return .{
        .allocator = allocator,
        .volumes = try volumes.toOwnedSlice(allocator),
    };
}

fn encodeRar4VolumesAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
    max_payload_per_volume: usize,
) Error!EncodedVolumes {
    var volumes: std.ArrayList([]u8) = .empty;
    errdefer {
        for (volumes.items) |volume| allocator.free(volume);
        volumes.deinit(allocator);
    }
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var header_writer: ?Rar4HeaderWriter = if (options.rar4_header_encryption) |encryption|
        try Rar4HeaderWriter.init(allocator, encryption)
    else
        null;
    defer if (header_writer) |*value| value.deinit();
    const header_writer_ptr: ?*Rar4HeaderWriter = if (header_writer) |*value| value else null;
    var volume_index: usize = 0;
    var payload_in_volume: usize = 0;
    try startRar4Volume(
        allocator,
        &current,
        volume_index,
        options.solid,
        header_writer_ptr,
    );
    var encoder = rar29_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
    });
    defer encoder.deinit();
    var ppmd_encoder = ppmd_h.Encoder.init(allocator, .{
        .order = options.ppmd_order,
        .memory_size = options.ppmd_memory_size,
    });
    defer ppmd_encoder.deinit();

    for (entries) |entry| {
        const use_lz = entry.kind == .regular and options.compression == .rar29;
        const use_ppmd = entry.kind == .regular and options.compression == .rar29_ppmd;
        const use_compression = use_lz or use_ppmd;
        if (!use_lz) encoder.reset();
        if (!use_ppmd) ppmd_encoder.reset();
        const solid_continuation = options.solid and if (use_lz)
            encoder.canContinue()
        else if (use_ppmd)
            ppmd_encoder.canContinue()
        else
            false;
        const compressed: ?[]u8 = if (use_lz)
            if (options.filter) |filter|
                try encoder.encodeFilteredMemberAlloc(
                    entry.data,
                    try rar29Filter(filter),
                    solid_continuation,
                )
            else
                try encoder.encodeMemberAlloc(entry.data, solid_continuation)
        else if (use_ppmd)
            try ppmd_encoder.encodeMemberAlloc(entry.data, solid_continuation)
        else
            null;
        defer if (compressed) |bytes| allocator.free(bytes);
        const plain_payload = compressed orelse entry.data;
        var encrypted: ?rar4_encryption.Encrypted = if (entry.rar4_encryption) |encryption|
            try rar4_encryption.encryptAlloc(allocator, plain_payload, encryption)
        else
            null;
        defer if (encrypted) |*value| value.deinit();
        const payload = if (encrypted) |value| value.bytes else plain_payload;
        const final_crc = checksum.crc32(entry.data);

        var offset: usize = 0;
        var split_before = false;
        while (offset < payload.len or (!split_before and payload.len == 0)) {
            if (payload_in_volume == max_payload_per_volume) {
                try finishRar4Volume(allocator, &current, true, header_writer_ptr);
                const owned_volume = try current.toOwnedSlice(allocator);
                volumes.append(allocator, owned_volume) catch |err| {
                    allocator.free(owned_volume);
                    return err;
                };
                volume_index = std.math.add(usize, volume_index, 1) catch
                    return error.IntegerOverflow;
                payload_in_volume = 0;
                try startRar4Volume(
                    allocator,
                    &current,
                    volume_index,
                    options.solid,
                    header_writer_ptr,
                );
            }
            const room = max_payload_per_volume - payload_in_volume;
            const fragment_len = @min(room, payload.len - offset);
            const split_after = offset + fragment_len < payload.len;
            const fragment = payload[offset .. offset + fragment_len];
            const fragment_crc = if (split_after)
                checksum.crc32(fragment)
            else
                final_crc;
            var general_flags: u16 = 0;
            if (split_before) general_flags |= 0x0001;
            if (split_after) general_flags |= 0x0002;
            try appendRar4FileFragment(
                allocator,
                &current,
                entry,
                fragment,
                use_compression,
                options.dictionary_size,
                solid_continuation,
                fragment_crc,
                general_flags,
                header_writer_ptr,
            );
            payload_in_volume += fragment_len;
            offset += fragment_len;
            if (!split_after) break;
            split_before = true;
        }
    }

    try finishRar4Volume(allocator, &current, false, header_writer_ptr);
    const owned_volume = try current.toOwnedSlice(allocator);
    volumes.append(allocator, owned_volume) catch |err| {
        allocator.free(owned_volume);
        return err;
    };
    return .{
        .allocator = allocator,
        .volumes = try volumes.toOwnedSlice(allocator),
    };
}

fn startRar4Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    volume_index: usize,
    solid: bool,
    header_writer: ?*Rar4HeaderWriter,
) !void {
    try output.appendSlice(allocator, archive.rar4_signature);
    const volume_flags: u16 = 0x0001 | 0x0010 |
        if (volume_index == 0) @as(u16, 0x0100) else 0;
    try appendRar4Main(
        allocator,
        output,
        solid,
        header_writer != null,
        volume_flags,
    );
}

fn finishRar4Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    has_next_volume: bool,
    header_writer: ?*Rar4HeaderWriter,
) !void {
    try appendRar4ShortHeader(
        allocator,
        output,
        0x7b,
        0x4000 | @as(u16, @intFromBool(has_next_volume)),
        header_writer,
    );
}

fn validateEntries(
    entries: []const EncodeEntry,
    options: EncodeOptions,
    volume_mode: bool,
) Error!void {
    switch (options.compression) {
        .stored => if (options.filter != null or options.solid)
            return error.UnsupportedRarEncodeOptions,
        .rar29 => {
            if (options.version != .rar4 or (options.solid and options.filter != null))
                return error.UnsupportedRarEncodeOptions;
            try rar29_encoder.validateOptions(.{
                .dictionary_size = options.dictionary_size,
                .block_size = options.block_size,
            });
            if (options.filter) |filter|
                try rar29_encoder.validateFilter(try rar29Filter(filter));
        },
        .rar29_ppmd => {
            if (options.version != .rar4 or options.filter != null)
                return error.UnsupportedRarEncodeOptions;
            _ = try rar29DictionaryFlags(options.dictionary_size);
            _ = try ppmd_h.validateEncodeOptions(.{
                .order = options.ppmd_order,
                .memory_size = options.ppmd_memory_size,
            });
        },
        .rar50 => {
            if (options.version != .rar5 or options.block_size == 0 or
                options.block_size > rar50_encoder.max_block_size)
                return error.UnsupportedRarEncodeOptions;
            _ = try rar50CompressionInfo(options.dictionary_size, false);
            try rar50_encoder.validateOptions(.{
                .dictionary_size = options.dictionary_size,
                .block_size = options.block_size,
                .filter = try rar50Filter(options.filter),
            });
            if (options.solid and options.filter != null)
                return error.UnsupportedRarEncodeOptions;
        },
    }
    if (options.header_encryption) |header_encryption| {
        if (options.version != .rar5) return error.InvalidRarHeaderEncryption;
        try rar5_encryption.validateHeaderOptions(header_encryption.cryptoOptions());
        if (!volume_mode) {
            const expected_iv_count = std.math.add(usize, entries.len, 2) catch
                return error.IntegerOverflow;
            if (header_encryption.ivs.len != expected_iv_count)
                return error.InvalidRarHeaderEncryption;
        }
        for (header_encryption.ivs, 0..) |iv, index|
            for (header_encryption.ivs[0..index]) |previous|
                if (std.mem.eql(u8, &iv, &previous))
                    return error.InvalidRarHeaderEncryption;
        for (entries) |entry| {
            if (entry.kind == .directory) continue;
            const encryption = entry.encryption orelse
                return error.InvalidRarHeaderEncryption;
            if (!std.mem.eql(u8, encryption.password, header_encryption.password))
                return error.InvalidRarHeaderEncryption;
        }
    }
    if (options.rar4_header_encryption) |header_encryption| {
        if (options.version != .rar4 or options.header_encryption != null or
            !std.unicode.utf8ValidateSlice(header_encryption.password))
            return error.InvalidRarHeaderEncryption;
        for (entries) |entry| {
            if (entry.kind == .directory) continue;
            const encryption = entry.rar4_encryption orelse
                return error.InvalidRarHeaderEncryption;
            if (!std.mem.eql(u8, encryption.password, header_encryption.password) or
                encryption.salt == null or
                !std.mem.eql(u8, &encryption.salt.?, &header_encryption.salt))
                return error.InvalidRarHeaderEncryption;
        }
    }
    for (entries) |entry| {
        if (!archive.isSafePath(entry.name) or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidRarEntryName;
        if (entry.kind == .directory and entry.data.len != 0) return error.UnsupportedRarEntry;
        if (!std.unicode.utf8ValidateSlice(entry.name)) {
            return error.InvalidRarEntryName;
        }
        if (entry.encryption) |encryption| {
            if (options.version != .rar5 or entry.kind != .regular)
                return error.UnsupportedRarEncodeOptions;
            try rar5_encryption.validateOptions(encryption);
        }
        if (entry.rar4_encryption) |encryption| {
            if (options.version != .rar4 or entry.kind != .regular or
                entry.encryption != null or !std.unicode.utf8ValidateSlice(encryption.password))
                return error.UnsupportedRarEncodeOptions;
        }
    }
}

fn encodeRar4(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !void {
    try output.appendSlice(allocator, archive.rar4_signature);
    var header_writer: ?Rar4HeaderWriter = if (options.rar4_header_encryption) |encryption|
        try Rar4HeaderWriter.init(allocator, encryption)
    else
        null;
    defer if (header_writer) |*value| value.deinit();
    const header_writer_ptr: ?*Rar4HeaderWriter = if (header_writer) |*value| value else null;
    try appendRar4Main(
        allocator,
        output,
        options.solid,
        header_writer != null,
        0,
    );
    var encoder = rar29_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
    });
    defer encoder.deinit();
    var ppmd_encoder = ppmd_h.Encoder.init(allocator, .{
        .order = options.ppmd_order,
        .memory_size = options.ppmd_memory_size,
    });
    defer ppmd_encoder.deinit();
    for (entries) |entry| try appendRar4File(
        allocator,
        output,
        entry,
        options,
        &encoder,
        &ppmd_encoder,
        header_writer_ptr,
    );
    try appendRar4ShortHeader(
        allocator,
        output,
        0x7b,
        0x4000,
        header_writer_ptr,
    );
}

const Rar4HeaderWriter = struct {
    salt: [rar4_encryption.salt_len]u8,
    cipher: rar4_encryption.Cipher,

    fn init(
        allocator: std.mem.Allocator,
        options: Rar4HeaderEncryptionOptions,
    ) Error!Rar4HeaderWriter {
        return .{
            .salt = options.salt,
            .cipher = try rar4_encryption.Cipher.init(
                allocator,
                options.password,
                .{ .salt = options.salt },
            ),
        };
    }

    fn append(
        self: *const Rar4HeaderWriter,
        allocator: std.mem.Allocator,
        output: *std.ArrayList(u8),
        clear_header: []const u8,
    ) !void {
        const encrypted = try self.cipher.encryptAlloc(allocator, clear_header);
        defer allocator.free(encrypted);
        try output.appendSlice(allocator, &self.salt);
        try output.appendSlice(allocator, encrypted);
    }

    fn deinit(self: *Rar4HeaderWriter) void {
        self.cipher.deinit();
        self.* = undefined;
    }
};

fn appendRar4Main(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    solid: bool,
    encrypted_headers: bool,
    extra_flags: u16,
) !void {
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, 2);
    try output.append(allocator, 0x73);
    try appendLe16(
        allocator,
        output,
        extra_flags | (if (solid) @as(u16, 0x0008) else 0) |
            (if (encrypted_headers) @as(u16, 0x0080) else 0),
    );
    try appendLe16(allocator, output, 13);
    try appendLe16(allocator, output, 0);
    try appendLe32(allocator, output, 0);
    writeRar4HeaderCrc(output.items, start, output.items.len);
}

fn appendRar4ShortHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    header_type: u8,
    flags: u16,
    header_writer: ?*Rar4HeaderWriter,
) !void {
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.appendNTimes(allocator, 0, 2);
    try header.append(allocator, header_type);
    try appendLe16(allocator, &header, flags);
    try appendLe16(allocator, &header, 7);
    writeRar4HeaderCrc(header.items, 0, header.items.len);
    if (header_writer) |writer|
        try writer.append(allocator, output, header.items)
    else
        try output.appendSlice(allocator, header.items);
}

fn appendRar4File(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    options: EncodeOptions,
    encoder: *rar29_encoder.Encoder,
    ppmd_encoder: *ppmd_h.Encoder,
    header_writer: ?*Rar4HeaderWriter,
) !void {
    const use_lz = entry.kind == .regular and options.compression == .rar29;
    const use_ppmd = entry.kind == .regular and options.compression == .rar29_ppmd;
    const use_compression = use_lz or use_ppmd;
    if (!use_lz) encoder.reset();
    if (!use_ppmd) ppmd_encoder.reset();
    const solid_continuation = options.solid and if (use_lz)
        encoder.canContinue()
    else if (use_ppmd)
        ppmd_encoder.canContinue()
    else
        false;
    const compressed: ?[]u8 = if (use_lz)
        if (options.filter) |filter|
            try encoder.encodeFilteredMemberAlloc(
                entry.data,
                try rar29Filter(filter),
                solid_continuation,
            )
        else
            try encoder.encodeMemberAlloc(entry.data, solid_continuation)
    else if (use_ppmd)
        try ppmd_encoder.encodeMemberAlloc(entry.data, solid_continuation)
    else
        null;
    defer if (compressed) |bytes| allocator.free(bytes);
    const plain_payload = compressed orelse entry.data;
    var encrypted: ?rar4_encryption.Encrypted = if (entry.rar4_encryption) |encryption|
        try rar4_encryption.encryptAlloc(allocator, plain_payload, encryption)
    else
        null;
    defer if (encrypted) |*value| value.deinit();
    const payload = if (encrypted) |value| value.bytes else plain_payload;
    try appendRar4FileFragment(
        allocator,
        output,
        entry,
        payload,
        use_compression,
        options.dictionary_size,
        solid_continuation,
        checksum.crc32(entry.data),
        0,
        header_writer,
    );
}

fn appendRar4FileFragment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    payload: []const u8,
    use_compression: bool,
    dictionary_size: usize,
    solid_continuation: bool,
    data_crc32: u32,
    general_flags: u16,
    header_writer: ?*Rar4HeaderWriter,
) !void {
    const needs_unicode = for (entry.name) |byte| {
        if (byte >= 0x80) break true;
    } else false;
    var encoded_name: ?rar4_name.Encoded = if (needs_unicode)
        try rar4_name.encodeAlloc(allocator, entry.name)
    else
        null;
    defer if (encoded_name) |*value| value.deinit();
    const name_field = if (encoded_name) |value| value.field else entry.name;
    const packed_size = std.math.cast(u32, payload.len) orelse return error.RarFileTooLarge;
    const unpacked_size = std.math.cast(u32, entry.data.len) orelse return error.RarFileTooLarge;
    const name_size = std.math.cast(u16, name_field.len) orelse return error.RarHeaderTooLarge;
    const header_size_usize = std.math.add(
        usize,
        32 + (if (entry.rar4_encryption) |value|
            if (value.salt == null) @as(usize, 0) else rar4_encryption.salt_len
        else
            0),
        name_field.len,
    ) catch
        return error.IntegerOverflow;
    const header_size = std.math.cast(u16, header_size_usize) orelse return error.RarHeaderTooLarge;
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.appendNTimes(allocator, 0, 2);
    try header.append(allocator, 0x74);
    var flags: u16 = 0x8000 | general_flags |
        (if (solid_continuation) @as(u16, 0x0010) else 0) |
        (if (entry.kind == .directory)
            @as(u16, 0x00e0)
        else if (use_compression)
            try rar29DictionaryFlags(dictionary_size)
        else
            0);
    if (entry.rar4_encryption) |encryption| {
        flags |= 0x0004;
        if (encryption.salt != null) flags |= 0x0400;
    }
    if (encoded_name != null) flags |= 0x0200;
    try appendLe16(allocator, &header, flags);
    try appendLe16(allocator, &header, header_size);
    try appendLe32(allocator, &header, packed_size);
    try appendLe32(allocator, &header, unpacked_size);
    try header.append(allocator, 3); // Unix host.
    try appendLe32(allocator, &header, data_crc32);
    try appendLe32(allocator, &header, entry.mtime orelse 0);
    try header.append(allocator, 29);
    try header.append(allocator, if (use_compression) 0x33 else 0x30);
    try appendLe16(allocator, &header, name_size);
    const default_mode: u32 = if (entry.kind == .directory) 0o040755 else 0o100644;
    try appendLe32(allocator, &header, entry.mode orelse default_mode);
    if (encoded_name != null)
        try header.appendSlice(allocator, name_field)
    else for (name_field) |byte| try header.append(allocator, if (byte == '/') '\\' else byte);
    if (entry.rar4_encryption) |encryption|
        if (encryption.salt) |salt| try header.appendSlice(allocator, &salt);
    writeRar4HeaderCrc(header.items, 0, header.items.len);
    if (header_writer) |writer|
        try writer.append(allocator, output, header.items)
    else
        try output.appendSlice(allocator, header.items);
    try output.appendSlice(allocator, payload);
}

fn rar29DictionaryFlags(dictionary_size: usize) Error!u16 {
    const bits: u16 = switch (dictionary_size) {
        64 * 1024 => 0,
        128 * 1024 => 1,
        256 * 1024 => 2,
        512 * 1024 => 3,
        1024 * 1024 => 4,
        2 * 1024 * 1024 => 5,
        4 * 1024 * 1024 => 6,
        else => return error.UnsupportedRarEncodeOptions,
    };
    return bits << 5;
}

fn rar29Filter(filter: Filter) Error!rar29_encoder.Filter {
    return switch (filter) {
        .delta => |channels| .{ .delta = channels },
        .e8 => .e8,
        .e8e9 => .e8e9,
        .itanium => .itanium,
        .rgb => |rgb| .{ .rgb = .{
            .width = rgb.width,
            .red_position = rgb.red_position,
        } },
        .audio => |channels| .{ .audio = channels },
        .arm => error.UnsupportedRarEncodeOptions,
    };
}

fn rar50Filter(filter: ?Filter) Error!?rar50_encoder.Filter {
    const value = filter orelse return null;
    return switch (value) {
        .delta => |channels| .{ .delta = channels },
        .e8 => .e8,
        .e8e9 => .e8e9,
        .arm => .arm,
        .itanium, .rgb, .audio => error.UnsupportedRarEncodeOptions,
    };
}

fn writeRar4HeaderCrc(bytes: []u8, start: usize, end: usize) void {
    const crc: u16 = @truncate(checksum.crc32(bytes[start + 2 .. end]));
    std.mem.writeInt(u16, bytes[start..][0..2], crc, .little);
}

const HeaderWriter = struct {
    prepared: rar5_encryption.PreparedHeaderCipher,
    ivs: []const [rar5_encryption.iv_len]u8,
    index: usize = 0,

    fn init(options: HeaderEncryptionOptions) Error!HeaderWriter {
        return .{
            .prepared = try rar5_encryption.prepareHeader(options.cryptoOptions()),
            .ivs = options.ivs,
        };
    }

    fn deinit(self: *HeaderWriter) void {
        self.prepared.deinit();
        self.* = undefined;
    }

    fn append(
        self: *HeaderWriter,
        allocator: std.mem.Allocator,
        output: *std.ArrayList(u8),
        clear_header: []const u8,
    ) !void {
        if (self.index >= self.ivs.len) return error.InvalidRarHeaderEncryption;
        const iv = self.ivs[self.index];
        const encrypted = try self.prepared.cipher.encryptAlloc(
            allocator,
            clear_header,
            iv,
        );
        defer allocator.free(encrypted);
        try output.appendSlice(allocator, &iv);
        try output.appendSlice(allocator, encrypted);
        self.index += 1;
    }
};

fn encodeRar5(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !void {
    try output.appendSlice(allocator, archive.rar5_signature);
    var header_writer: ?HeaderWriter = if (options.header_encryption) |encryption|
        try HeaderWriter.init(encryption)
    else
        null;
    defer if (header_writer) |*value| value.deinit();
    if (header_writer) |*value|
        try appendRar5ArchiveEncryptionHeader(
            allocator,
            output,
            value.prepared.metadata,
        );
    const header_writer_ptr: ?*HeaderWriter = if (header_writer) |*value| value else null;
    var encoder = rar50_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
        .filter = try rar50Filter(options.filter),
    });
    defer encoder.deinit();
    var main_specific: std.ArrayList(u8) = .empty;
    defer main_specific.deinit(allocator);
    try appendVint(allocator, &main_specific, if (options.solid) @as(u64, 0x0004) else 0);
    try appendRar5BlockInternal(
        allocator,
        output,
        1,
        0,
        null,
        main_specific.items,
        "",
        "",
        header_writer_ptr,
    );
    for (entries) |entry| try appendRar5File(
        allocator,
        output,
        entry,
        options,
        &encoder,
        header_writer_ptr,
    );
    var end_specific: std.ArrayList(u8) = .empty;
    defer end_specific.deinit(allocator);
    try appendVint(allocator, &end_specific, 0);
    try appendRar5BlockInternal(
        allocator,
        output,
        5,
        0,
        null,
        end_specific.items,
        "",
        "",
        header_writer_ptr,
    );
    if (header_writer) |*value|
        if (value.index != value.ivs.len) return error.InvalidRarHeaderEncryption;
}

fn appendRar5ArchiveEncryptionHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: rar5_encryption.HeaderMetadata,
) !void {
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    try appendVint(allocator, &specific, metadata.version);
    try appendVint(allocator, &specific, metadata.flags);
    try specific.append(allocator, metadata.kdf_count);
    try specific.appendSlice(allocator, &metadata.salt);
    if (metadata.password_check) |check| try specific.appendSlice(allocator, &check);
    try appendRar5Block(allocator, output, 4, 0, null, specific.items, "", "");
}

fn startRar5Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    volume_index: usize,
    solid: bool,
    header_writer: ?*HeaderWriter,
) !void {
    try output.appendSlice(allocator, archive.rar5_signature);
    if (header_writer) |value|
        try appendRar5ArchiveEncryptionHeader(
            allocator,
            output,
            value.prepared.metadata,
        );
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    var archive_flags: u64 = 0x0001 | 0x0002;
    if (solid) archive_flags |= 0x0004;
    try appendVint(allocator, &specific, archive_flags);
    try appendVint(allocator, &specific, volume_index);
    try appendRar5BlockInternal(
        allocator,
        output,
        1,
        0,
        null,
        specific.items,
        "",
        "",
        header_writer,
    );
}

fn finishRar5Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    has_next_volume: bool,
    header_writer: ?*HeaderWriter,
) !void {
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    try appendVint(allocator, &specific, @intFromBool(has_next_volume));
    try appendRar5BlockInternal(
        allocator,
        output,
        5,
        0,
        null,
        specific.items,
        "",
        "",
        header_writer,
    );
}

fn appendRar5File(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    options: EncodeOptions,
    encoder: *rar50_encoder.Encoder,
    header_writer: ?*HeaderWriter,
) !void {
    var compressed: ?[]u8 = null;
    defer if (compressed) |bytes| allocator.free(bytes);
    const use_compression = entry.kind == .regular and options.compression == .rar50;
    if (!use_compression) encoder.reset();
    const solid_continuation = options.solid and encoder.canContinue();
    if (use_compression)
        compressed = try encoder.encodeMemberAlloc(entry.data, solid_continuation);
    const payload = compressed orelse entry.data;
    const compression_info: u64 = if (use_compression)
        try rar50CompressionInfo(options.dictionary_size, solid_continuation)
    else
        0;
    const plain_crc = checksum.crc32(entry.data);
    var encrypted: ?rar5_encryption.Encrypted = if (entry.encryption) |encryption|
        try rar5_encryption.encryptAlloc(allocator, payload, plain_crc, encryption)
    else
        null;
    defer if (encrypted) |*value| value.deinit();
    var extra: std.ArrayList(u8) = .empty;
    defer extra.deinit(allocator);
    if (encrypted) |value|
        try appendRar5EncryptionRecord(allocator, &extra, value.metadata);
    try appendRar5FileFragment(
        allocator,
        output,
        entry,
        if (encrypted) |value| value.bytes else payload,
        compression_info,
        if (encrypted) |value| value.wire_crc32 else plain_crc,
        0,
        extra.items,
        header_writer,
    );
}

fn appendRar5FileFragment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    payload: []const u8,
    compression_info: u64,
    data_crc32: u32,
    general_flags: u64,
    extra: []const u8,
    header_writer: ?*HeaderWriter,
) !void {
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    var file_flags: u64 = 0x0004;
    if (entry.kind == .directory) file_flags |= 0x0001;
    if (entry.mtime != null) file_flags |= 0x0002;
    try appendVint(allocator, &specific, file_flags);
    try appendVint(allocator, &specific, entry.data.len);
    const default_mode: u64 = if (entry.kind == .directory) 0o040755 else 0o100644;
    try appendVint(allocator, &specific, entry.mode orelse default_mode);
    if (entry.mtime) |mtime| try appendLe32(allocator, &specific, mtime);
    try appendLe32(allocator, &specific, data_crc32);
    try appendVint(allocator, &specific, compression_info);
    try appendVint(allocator, &specific, 1); // Unix host.
    try appendVint(allocator, &specific, entry.name.len);
    try specific.appendSlice(allocator, entry.name);
    try appendRar5BlockInternal(
        allocator,
        output,
        2,
        0x0002 | (if (extra.len != 0) @as(u64, 0x0001) else 0) | general_flags,
        payload.len,
        specific.items,
        extra,
        payload,
        header_writer,
    );
}

fn appendRar5EncryptionRecord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: rar5_encryption.Metadata,
) !void {
    var record: std.ArrayList(u8) = .empty;
    defer record.deinit(allocator);
    try appendVint(allocator, &record, 1);
    try appendVint(allocator, &record, metadata.version);
    try appendVint(allocator, &record, metadata.flags);
    try record.append(allocator, metadata.kdf_count);
    try record.appendSlice(allocator, &metadata.salt);
    try record.appendSlice(allocator, &metadata.iv);
    if (metadata.password_check) |check| try record.appendSlice(allocator, &check);
    try appendVint(allocator, output, record.items.len);
    try output.appendSlice(allocator, record.items);
}

fn rar50CompressionInfo(dictionary_size: usize, solid_continuation: bool) Error!u64 {
    if (dictionary_size < 128 * 1024 or dictionary_size % (128 * 1024) != 0)
        return error.UnsupportedRarEncodeOptions;
    const multiple = dictionary_size / (128 * 1024);
    if (!std.math.isPowerOfTwo(multiple)) return error.UnsupportedRarEncodeOptions;
    const power = std.math.log2_int(usize, multiple);
    if (power > 15) return error.UnsupportedRarEncodeOptions;
    return (@as(u64, 3) << 7) | (@as(u64, power) << 10) |
        if (solid_continuation) @as(u64, 0x40) else 0;
}

fn appendRar5Block(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    header_type: u64,
    flags: u64,
    data_size: ?usize,
    specific: []const u8,
    extra: []const u8,
    data: []const u8,
) !void {
    return appendRar5BlockInternal(
        allocator,
        output,
        header_type,
        flags,
        data_size,
        specific,
        extra,
        data,
        null,
    );
}

fn appendRar5BlockInternal(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    header_type: u64,
    flags: u64,
    data_size: ?usize,
    specific: []const u8,
    extra: []const u8,
    data: []const u8,
    header_writer: ?*HeaderWriter,
) !void {
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    try appendVint(allocator, &body, header_type);
    try appendVint(allocator, &body, flags);
    if (flags & 0x0001 != 0) try appendVint(allocator, &body, extra.len);
    if (data_size) |size| try appendVint(allocator, &body, size);
    try body.appendSlice(allocator, specific);
    try body.appendSlice(allocator, extra);

    var size_field: std.ArrayList(u8) = .empty;
    defer size_field.deinit(allocator);
    try appendVint(allocator, &size_field, body.items.len);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.appendNTimes(allocator, 0, 4);
    try header.appendSlice(allocator, size_field.items);
    try header.appendSlice(allocator, body.items);
    const crc = checksum.crc32(header.items[4..]);
    std.mem.writeInt(u32, header.items[0..4], crc, .little);
    if (header_writer) |writer|
        try writer.append(allocator, output, header.items)
    else
        try output.appendSlice(allocator, header.items);
    try output.appendSlice(allocator, data);
}

fn appendVint(allocator: std.mem.Allocator, output: *std.ArrayList(u8), raw: anytype) !void {
    var value: u64 = @intCast(raw);
    while (value >= 0x80) {
        try output.append(allocator, @truncate(value | 0x80));
        value >>= 7;
    }
    try output.append(allocator, @truncate(value));
}

fn appendLe16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendLe32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "RAR4 and RAR5 stored writers round trip files and directories" {
    const allocator = std.testing.allocator;
    const binary = [_]u8{ 0, 1, 2, 0xff } ** 64;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.txt", .data = "RAR stored payload" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.bin", .data = &binary, .mode = 0o100600 },
    };
    inline for (std.meta.tags(archive.Version)) |version| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .version = version });
        defer allocator.free(encoded);
        const second = try encodeAlloc(allocator, &entries, .{ .version = version });
        defer allocator.free(second);
        try std.testing.expectEqualSlices(u8, encoded, second);
        const parsed = try archive.parse(encoded);
        try std.testing.expectEqual(version, parsed.version);
        try std.testing.expectEqual(entries.len, parsed.entry_count);
        for (entries, 0..) |expected, index| {
            const entry = try parsed.entryAt(index);
            try std.testing.expect(entry.name.eql(expected.name));
            try std.testing.expectEqual(expected.kind == .directory, entry.directory);
            if (!entry.directory) {
                const decoded = try parsed.extractAlloc(allocator, entry);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }
        }
    }
}

test "RAR29 writer emits deterministic multiblock LZ streams" {
    const allocator = std.testing.allocator;
    const pattern = "RAR29 deterministic LZ payload alpha beta gamma\n";
    const payload = try allocator.alloc(u8, 192 * 1024);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    const entries = [_]EncodeEntry{
        .{ .name = "payload.txt", .data = payload },
        .{ .name = "empty.bin" },
        .{ .name = "folder", .kind = .directory },
    };
    const options = EncodeOptions{
        .version = .rar4,
        .compression = .rar29,
        .dictionary_size = 4 * 1024 * 1024,
        .block_size = 4096,
    };
    const encoded = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const second = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, encoded, second);

    const parsed = try archive.parse(encoded);
    const compressed = try parsed.entryAt(0);
    try std.testing.expectEqual(archive.Method.rar29, compressed.method);
    try std.testing.expectEqual(@as(u8, 0x33), compressed.method_id);
    try std.testing.expectEqual(@as(u8, 29), compressed.compression_version);
    try std.testing.expectEqual(@as(?usize, 4 * 1024 * 1024), compressed.dictionary_size);
    try std.testing.expect(compressed.compressed_size < compressed.uncompressed_size);
    const decoded = try parsed.extractAlloc(allocator, compressed);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const empty = try parsed.entryAt(1);
    try std.testing.expectEqual(archive.Method.rar29, empty.method);
    const empty_decoded = try parsed.extractAlloc(allocator, empty);
    defer allocator.free(empty_decoded);
    try std.testing.expectEqual(@as(usize, 0), empty_decoded.len);
    const directory = try parsed.entryAt(2);
    try std.testing.expectEqual(archive.Method.stored, directory.method);
    try std.testing.expect(directory.directory);
}

test "RAR writer rejects compression and container mismatches" {
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "data" }};
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(std.testing.allocator, &entries, .{
            .version = .rar5,
            .compression = .rar29,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(std.testing.allocator, &entries, .{
            .version = .rar4,
            .compression = .rar50,
        }),
    );
}

test "RAR29 writer stamps every supported dictionary window" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "payload",
        .data = "RAR29 dictionary metadata" ** 8,
    }};
    const dictionaries = [_]usize{
        64 * 1024,
        128 * 1024,
        256 * 1024,
        512 * 1024,
        1024 * 1024,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
    };
    for (dictionaries) |dictionary_size| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29,
            .dictionary_size = dictionary_size,
        });
        defer allocator.free(encoded);
        const parsed = try archive.parse(encoded);
        const entry = try parsed.entryAt(0);
        try std.testing.expectEqual(@as(?usize, dictionary_size), entry.dictionary_size);
    }
}

test "RAR29 solid writer reuses history across members" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(payload);
    var random = std.Random.DefaultPrng.init(0x72617232395f736f);
    random.fill(payload);
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = payload },
        .{ .name = "second.bin", .data = payload },
    };
    const options = EncodeOptions{
        .version = .rar4,
        .compression = .rar29,
        .dictionary_size = 128 * 1024,
        .solid = true,
    };
    const encoded = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expect(parsed.solid);
    const first = try parsed.entryAt(0);
    const second = try parsed.entryAt(1);
    try std.testing.expect(!first.solid);
    try std.testing.expect(second.solid);
    try std.testing.expect(second.compressed_size < first.compressed_size / 4);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        parsed.extractAlloc(allocator, second),
    );

    const decoded = try parsed.extractByNameAllocLimited(
        allocator,
        "second.bin",
        payload.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var session = parsed.extractSession(allocator, .{ .max_output_len = payload.len });
    defer session.deinit();
    const decoded_first = (try session.nextAlloc()) orelse return error.TestExpectedEqual;
    defer allocator.free(decoded_first.data);
    try std.testing.expectEqualSlices(u8, payload, decoded_first.data);
    const decoded_second = (try session.nextAlloc()) orelse return error.TestExpectedEqual;
    defer allocator.free(decoded_second.data);
    try std.testing.expectEqualSlices(u8, payload, decoded_second.data);

    const broken_entries = [_]EncodeEntry{
        entries[0],
        .{ .name = "folder", .kind = .directory },
        entries[1],
    };
    const broken = try encodeAlloc(allocator, &broken_entries, options);
    defer allocator.free(broken);
    const broken_archive = try archive.parse(broken);
    try std.testing.expect(!(try broken_archive.entryAt(2)).solid);

    const empty_entries = [_]EncodeEntry{
        entries[0],
        .{ .name = "empty.bin" },
        entries[1],
    };
    const with_empty = try encodeAlloc(allocator, &empty_entries, options);
    defer allocator.free(with_empty);
    const empty_archive = try archive.parse(with_empty);
    try std.testing.expect((try empty_archive.entryAt(1)).solid);
    try std.testing.expect((try empty_archive.entryAt(2)).solid);
    const after_empty = try empty_archive.extractByNameAllocLimited(
        allocator,
        "second.bin",
        payload.len,
    );
    defer allocator.free(after_empty);
    try std.testing.expectEqualSlices(u8, payload, after_empty);

    const leading_empty_entries = [_]EncodeEntry{
        .{ .name = "empty.bin" },
        entries[1],
    };
    const leading_empty = try encodeAlloc(allocator, &leading_empty_entries, options);
    defer allocator.free(leading_empty);
    const leading_empty_archive = try archive.parse(leading_empty);
    try std.testing.expect(!(try leading_empty_archive.entryAt(1)).solid);
}

test "RAR29 PPMd writer emits deterministic ordinary and solid streams" {
    const allocator = std.testing.allocator;
    const first_payload = "PPMd Variant H writer text alpha beta gamma\n" ** 256 ++ "\x02";
    const second_payload = "PPMd Variant H writer text alpha beta delta\n" ** 128 ++ "\x02";
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = first_payload },
        .{ .name = "second.txt", .data = second_payload },
    };
    const options = EncodeOptions{
        .version = .rar4,
        .compression = .rar29_ppmd,
        .ppmd_memory_size = 1024 * 1024,
        .solid = true,
    };
    const encoded = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const duplicate = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(duplicate);
    try std.testing.expectEqualSlices(u8, encoded, duplicate);

    const parsed = try archive.parse(encoded);
    try std.testing.expect(parsed.solid);
    const first = try parsed.entryAt(0);
    const second = try parsed.entryAt(1);
    try std.testing.expectEqual(archive.Method.rar29, first.method);
    try std.testing.expectEqual(@as(u8, 0x33), first.method_id);
    try std.testing.expect(encoded[first.data_offset] & 0x80 != 0);
    try std.testing.expect(!first.solid);
    try std.testing.expect(second.solid);
    try std.testing.expect(first.compressed_size < first.uncompressed_size);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        parsed.extractAlloc(allocator, second),
    );
    const decoded = try parsed.extractByNameAllocLimited(
        allocator,
        "second.txt",
        @max(first_payload.len, second_payload.len),
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, second_payload, decoded);

    const broken_entries = [_]EncodeEntry{
        entries[0],
        .{ .name = "folder", .kind = .directory },
        entries[1],
    };
    const broken = try encodeAlloc(allocator, &broken_entries, options);
    defer allocator.free(broken);
    const broken_archive = try archive.parse(broken);
    try std.testing.expect(!(try broken_archive.entryAt(2)).solid);

    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar5,
            .compression = .rar29_ppmd,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .filter = .e8,
        }),
    );
    try std.testing.expectError(
        error.InvalidRarPpmdEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .ppmd_memory_size = 512 * 1024,
        }),
    );
}

test "RAR29 writer emits all six standard VM filters" {
    const allocator = std.testing.allocator;
    var payload: [8192]u8 = undefined;
    for (&payload, 0..) |*byte, index| byte.* = @truncate(index *% 53 +% index / 7);
    payload[16] = 0xe8;
    std.mem.writeInt(u32, payload[17..21], 0x1000, .little);
    payload[32] = 0xe9;
    std.mem.writeInt(u32, payload[33..37], 0x2000, .little);
    const entries = [_]EncodeEntry{.{ .name = "filtered.bin", .data = &payload }};
    const filters = [_]Filter{
        .{ .delta = 4 },
        .e8,
        .e8e9,
        .itanium,
        .{ .rgb = .{ .width = 12, .red_position = 1 } },
        .{ .audio = 2 },
    };
    for (filters) |filter| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29,
            .block_size = 1024,
            .filter = filter,
        });
        defer allocator.free(encoded);
        const parsed = try archive.parse(encoded);
        const entry = try parsed.entryAt(0);
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &payload, decoded);
    }

    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29,
            .filter = .arm,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29,
            .filter = .e8,
            .solid = true,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar5,
            .compression = .rar50,
            .filter = .itanium,
        }),
    );
}

test "RAR29 archive extraction detects packed stream corruption" {
    const allocator = std.testing.allocator;
    var payload: [128]u8 = undefined;
    for (&payload, 0..) |*byte, index| byte.* = @intCast(index);
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = &payload }};
    const encoded = try encodeAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29,
    });
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);

    var saw_checksum_mismatch = false;
    find_corruption: for (0..entry.compressed_size) |packed_offset| {
        for (0..8) |bit| {
            const corrupted = try allocator.dupe(u8, encoded);
            defer allocator.free(corrupted);
            corrupted[entry.data_offset + packed_offset] ^=
                @as(u8, 1) << @intCast(bit);
            const corrupt_archive = archive.parse(corrupted) catch continue;
            const corrupt_entry = corrupt_archive.entryAt(0) catch continue;
            if (corrupt_archive.extractAlloc(allocator, corrupt_entry)) |bad| {
                allocator.free(bad);
            } else |err| {
                if (err == error.ChecksumMismatch) {
                    saw_checksum_mismatch = true;
                    break :find_corruption;
                }
            }
        }
    }
    try std.testing.expect(saw_checksum_mismatch);
}

test "RAR50 writer emits deterministic multiblock LZ streams" {
    const allocator = std.testing.allocator;
    const pattern = "RAR50 deterministic LZ payload alpha beta gamma\n";
    const payload = try allocator.alloc(u8, 192 * 1024);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    const entries = [_]EncodeEntry{
        .{ .name = "payload.txt", .data = payload },
        .{ .name = "folder", .kind = .directory },
    };
    const options = EncodeOptions{ .version = .rar5, .compression = .rar50 };
    const encoded = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const second = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, encoded, second);

    const parsed = try archive.parse(encoded);
    const compressed = try parsed.entryAt(0);
    try std.testing.expectEqual(archive.Method.rar50, compressed.method);
    try std.testing.expect(compressed.compressed_size < compressed.uncompressed_size);
    const decoded = try parsed.extractAlloc(allocator, compressed);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const directory = try parsed.entryAt(1);
    try std.testing.expect(directory.directory);
    try std.testing.expectEqual(archive.Method.stored, directory.method);

    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{ .version = .rar4, .compression = .rar50 }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar5,
            .compression = .rar50,
            .dictionary_size = 192 * 1024,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .version = .rar5,
            .compression = .rar50,
            .block_size = rar50_encoder.max_block_size + 1,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{ .filter = .e8 }),
    );
    try std.testing.expectError(
        error.InvalidRar50EncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .rar50,
            .filter = .{ .delta = 33 },
        }),
    );
}

test "RAR50 solid writer reuses history across members" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(payload);
    var state: u64 = 0x2545_f491_4f6c_dd1d;
    for (payload) |*byte| {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        byte.* = @truncate(state);
    }
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = payload },
        .{ .name = "second.bin", .data = payload },
    };
    const encoded = try encodeAlloc(allocator, &entries, .{
        .compression = .rar50,
        .solid = true,
    });
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expect(parsed.solid);
    const first = try parsed.entryAt(0);
    const second = try parsed.entryAt(1);
    try std.testing.expect(!first.solid);
    try std.testing.expect(second.solid);
    try std.testing.expect(second.compressed_size * 10 < first.compressed_size);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        parsed.extractAlloc(allocator, second),
    );
    const decoded = try parsed.extractByNameAllocLimited(
        allocator,
        "second.bin",
        payload.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const broken_entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = payload },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "second.bin", .data = payload },
    };
    const broken = try encodeAlloc(allocator, &broken_entries, .{
        .compression = .rar50,
        .solid = true,
    });
    defer allocator.free(broken);
    const broken_archive = try archive.parse(broken);
    try std.testing.expect(!(try broken_archive.entryAt(2)).solid);

    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .rar50,
            .filter = .e8,
            .solid = true,
        }),
    );
}

test "RAR5 encrypted Stored and RAR50 entries round trip with bounded KDF" {
    const allocator = std.testing.allocator;
    const payload = "RAR5 encrypted archive payload alpha beta gamma\n" ** 97;
    const encryption = EncryptionOptions{
        .password = "correct horse 密码",
        .salt = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        .iv = .{ 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
        .kdf_count = 3,
    };
    const entries = [_]EncodeEntry{.{
        .name = "secret.bin",
        .data = payload,
        .encryption = encryption,
    }};
    inline for (.{ Compression.stored, Compression.rar50 }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .block_size = 1024,
        });
        defer allocator.free(encoded);
        const second = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .block_size = 1024,
        });
        defer allocator.free(second);
        try std.testing.expectEqualSlices(u8, encoded, second);
        const parsed = try archive.parse(encoded);
        const entry = try parsed.entryAt(0);
        try std.testing.expect(entry.encrypted);
        try std.testing.expect(entry.encryption != null);
        try std.testing.expectEqual(@as(usize, 0), entry.compressed_size % 16);
        try std.testing.expect(entry.crc32.? != checksum.crc32(payload));
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(
            error.RarEntryRequiresAllocator,
            parsed.extractInto(entry, &output),
        );
        try std.testing.expectError(
            error.RarPasswordRequired,
            parsed.extractAllocWithOptions(allocator, entry, .{}),
        );
        try std.testing.expectError(
            error.InvalidRarPassword,
            parsed.extractAllocWithOptions(allocator, entry, .{
                .password = "wrong password",
                .max_rar5_kdf_count = 3,
            }),
        );
        try std.testing.expectError(
            error.Rar5KdfLimitExceeded,
            parsed.extractAllocWithOptions(allocator, entry, .{
                .password = encryption.password,
                .max_rar5_kdf_count = 2,
            }),
        );
        const decoded = try parsed.extractAllocWithOptions(allocator, entry, .{
            .password = encryption.password,
            .max_rar5_kdf_count = 3,
        });
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const stored = try encodeAlloc(allocator, &entries, .{});
    defer allocator.free(stored);
    const parsed = try archive.parse(stored);
    const entry = try parsed.entryAt(0);
    stored[entry.data_offset] ^= 1;
    const corrupt = try archive.parse(stored);
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt.extractAllocWithOptions(allocator, try corrupt.entryAt(0), .{
            .password = encryption.password,
            .max_rar5_kdf_count = 3,
        }),
    );
}

test "RAR5 encryption composes with solid RAR50 history" {
    const allocator = std.testing.allocator;
    var payload: [32 * 1024]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x7261_7235_6372_7970);
    random.fill(&payload);
    const entries = [_]EncodeEntry{
        .{
            .name = "first.bin",
            .data = &payload,
            .encryption = .{
                .password = "solid secret",
                .salt = [_]u8{0x11} ** 16,
                .iv = [_]u8{0x21} ** 16,
                .kdf_count = 2,
            },
        },
        .{
            .name = "second.bin",
            .data = &payload,
            .encryption = .{
                .password = "solid secret",
                .salt = [_]u8{0x12} ** 16,
                .iv = [_]u8{0x22} ** 16,
                .kdf_count = 2,
            },
        },
    };
    const encoded = try encodeAlloc(allocator, &entries, .{
        .compression = .rar50,
        .solid = true,
    });
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const second = try parsed.entryAt(1);
    try std.testing.expect(second.encrypted);
    try std.testing.expect(second.solid);
    try std.testing.expectError(
        error.UnsupportedRarFeature,
        parsed.extractAllocWithOptions(allocator, second, .{ .password = "solid secret" }),
    );
    const decoded = try parsed.extractByNameAllocWithOptions(
        allocator,
        "second.bin",
        .{ .password = "solid secret", .max_rar5_kdf_count = 2 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "RAR5 encryption parser validates records before expensive KDF work" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "secret.bin",
        .data = "RAR5 hostile encryption metadata",
        .encryption = .{
            .password = "password",
            .salt = [_]u8{0x51} ** 16,
            .iv = [_]u8{0x61} ** 16,
            .kdf_count = 2,
        },
    }};
    const encoded = try encodeAlloc(allocator, &entries, .{});
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    const kdf_offset = entry.data_offset - (16 + 16 + 12 + 1);

    const excessive = try allocator.dupe(u8, encoded);
    defer allocator.free(excessive);
    excessive[kdf_offset] = 25;
    std.mem.writeInt(
        u32,
        excessive[entry.header_offset..][0..4],
        checksum.crc32(excessive[entry.header_offset + 4 .. entry.data_offset]),
        .little,
    );
    const excessive_archive = try archive.parse(excessive);
    const excessive_entry = try excessive_archive.entryAt(0);
    try std.testing.expectEqual(@as(u8, 25), excessive_entry.encryption.?.kdf_count);
    try std.testing.expectError(
        error.Rar5KdfLimitExceeded,
        excessive_archive.extractAllocWithOptions(allocator, excessive_entry, .{
            .password = "password",
            .max_rar5_kdf_count = 24,
        }),
    );

    const bad_check = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_check);
    bad_check[entry.data_offset - 1] ^= 1;
    std.mem.writeInt(
        u32,
        bad_check[entry.header_offset..][0..4],
        checksum.crc32(bad_check[entry.header_offset + 4 .. entry.data_offset]),
        .little,
    );
    try std.testing.expectError(
        error.CorruptRar5PasswordCheck,
        archive.parse(bad_check),
    );

    const unknown_flags = try allocator.dupe(u8, encoded);
    defer allocator.free(unknown_flags);
    unknown_flags[kdf_offset - 1] |= 4;
    std.mem.writeInt(
        u32,
        unknown_flags[entry.header_offset..][0..4],
        checksum.crc32(unknown_flags[entry.header_offset + 4 .. entry.data_offset]),
        .little,
    );
    try std.testing.expectError(
        error.InvalidRar5Encryption,
        archive.parse(unknown_flags),
    );
}

test "RAR5 encryption without password check relies on keyed content CRC" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "secret.bin",
        .data = "RAR5 checksum-only password validation",
        .encryption = .{
            .password = "correct",
            .salt = [_]u8{0x71} ** 16,
            .iv = [_]u8{0x81} ** 16,
            .kdf_count = 1,
            .include_password_check = false,
        },
    }};
    const encoded = try encodeAlloc(allocator, &entries, .{});
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    try std.testing.expect(entry.encryption.?.password_check == null);
    try std.testing.expectError(
        error.ChecksumMismatch,
        parsed.extractAllocWithOptions(allocator, entry, .{
            .password = "wrong",
            .max_rar5_kdf_count = 1,
        }),
    );
    const decoded = try parsed.extractAllocWithOptions(allocator, entry, .{
        .password = "correct",
        .max_rar5_kdf_count = 1,
    });
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
}

test "RAR5 encryption composes with volumes and releases allocation failures" {
    const volume_set = @import("volume_set.zig");
    const entries = [_]EncodeEntry{.{
        .name = "secret.bin",
        .data = "allocation safe secret",
        .encryption = .{
            .password = "password",
            .salt = [_]u8{0x31} ** 16,
            .iv = [_]u8{0x41} ** 16,
            .kdf_count = 0,
        },
    }};
    var volumes = try encodeVolumesAlloc(std.testing.allocator, &entries, .{}, 8);
    defer volumes.deinit();
    try std.testing.expect(volumes.volumes.len > 1);
    var set = try volume_set.VolumeSet.parseAlloc(
        std.testing.allocator,
        volumes.volumes,
    );
    defer set.deinit();
    const volume_decoded = try set.extractByNameAllocWithOptions(
        std.testing.allocator,
        entries[0].name,
        .{ .password = "password", .max_rar5_kdf_count = 0 },
    );
    defer std.testing.allocator.free(volume_decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, volume_decoded);
    const first_archive = try archive.parse(volumes.volumes[0]);
    const first_fragment = try first_archive.entryAt(0);
    volumes.volumes[0][first_fragment.data_offset] ^= 1;
    var corrupt_set = try volume_set.VolumeSet.parseAlloc(
        std.testing.allocator,
        volumes.volumes,
    );
    defer corrupt_set.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt_set.extractByNameAllocWithOptions(
            std.testing.allocator,
            entries[0].name,
            .{ .password = "password", .max_rar5_kdf_count = 0 },
        ),
    );
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const encoded = try encodeAlloc(allocator, &entries, .{});
            defer allocator.free(encoded);
            const parsed = try archive.parse(encoded);
            const decoded = try parsed.extractAllocWithOptions(
                allocator,
                try parsed.entryAt(0),
                .{ .password = "password", .max_rar5_kdf_count = 0 },
            );
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "RAR5 volume writer round trips stored compressed and solid entries" {
    const volume_set = @import("volume_set.zig");
    const allocator = std.testing.allocator;
    var random: [64 * 1024]u8 = undefined;
    var state: u64 = 0x9e37_79b9_7f4a_7c15;
    for (&random) |*byte| {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        byte.* = @truncate(state);
    }

    const stored_entries = [_]EncodeEntry{.{
        .name = "stored.bin",
        .data = random[0..4096],
    }};
    var stored_volumes = try encodeVolumesAlloc(
        allocator,
        &stored_entries,
        .{},
        1500,
    );
    defer stored_volumes.deinit();
    try std.testing.expectEqual(@as(usize, 3), stored_volumes.volumes.len);
    var stored_set = try volume_set.VolumeSet.parseAlloc(
        allocator,
        stored_volumes.volumes,
    );
    defer stored_set.deinit();
    const stored = try stored_set.extractByNameAllocLimited(
        allocator,
        "stored.bin",
        random.len,
    );
    defer allocator.free(stored);
    try std.testing.expectEqualSlices(u8, random[0..4096], stored);

    const solid_entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = &random },
        .{ .name = "second.bin", .data = &random },
    };
    var solid_volumes = try encodeVolumesAlloc(
        allocator,
        &solid_entries,
        .{ .compression = .rar50, .solid = true },
        20 * 1024,
    );
    defer solid_volumes.deinit();
    try std.testing.expect(solid_volumes.volumes.len >= 4);
    var solid_set = try volume_set.VolumeSet.parseAlloc(
        allocator,
        solid_volumes.volumes,
    );
    defer solid_set.deinit();
    try std.testing.expectEqual(@as(usize, 2), solid_set.entries.len);
    try std.testing.expect(solid_set.entries[1].solid);
    const solid = try solid_set.extractByNameAllocLimited(
        allocator,
        "second.bin",
        random.len,
    );
    defer allocator.free(solid);
    try std.testing.expectEqualSlices(u8, &random, solid);

    try std.testing.expectError(
        error.InvalidRarVolumeSize,
        encodeVolumesAlloc(allocator, &stored_entries, .{}, 0),
    );
    var rar4_volumes = try encodeVolumesAlloc(
        allocator,
        &stored_entries,
        .{ .version = .rar4 },
        1500,
    );
    defer rar4_volumes.deinit();
    var rar4_set = try volume_set.VolumeSet.parseAlloc(allocator, rar4_volumes.volumes);
    defer rar4_set.deinit();
    const rar4_stored = try rar4_set.extractByNameAllocLimited(
        allocator,
        "stored.bin",
        random.len,
    );
    defer allocator.free(rar4_stored);
    try std.testing.expectEqualSlices(u8, random[0..4096], rar4_stored);
}

test "RAR parser accepts SFX prefixes and validates header and data CRCs" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "checksum" }};
    inline for (std.meta.tags(archive.Version)) |version| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .version = version });
        defer allocator.free(encoded);
        var sfx: std.ArrayList(u8) = .empty;
        defer sfx.deinit(allocator);
        try sfx.appendSlice(allocator, "MZ fake SFX prefix");
        try sfx.appendSlice(allocator, encoded);
        const parsed = try archive.parse(sfx.items);
        try std.testing.expectEqual(@as(usize, "MZ fake SFX prefix".len), parsed.prefix_size);
        const entry = try parsed.entryAt(0);
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings("checksum", decoded);

        const corrupt = try allocator.dupe(u8, sfx.items);
        defer allocator.free(corrupt);
        corrupt[entry.data_offset] ^= 1;
        const corrupt_archive = try archive.parse(corrupt);
        const corrupt_entry = try corrupt_archive.entryAt(0);
        var output: ["checksum".len]u8 = undefined;
        try std.testing.expectError(
            error.ChecksumMismatch,
            corrupt_archive.extractInto(corrupt_entry, &output),
        );

        const bad_header = try allocator.dupe(u8, sfx.items);
        defer allocator.free(bad_header);
        bad_header[entry.header_offset] ^= 1;
        try std.testing.expectError(error.ChecksumMismatch, archive.parse(bad_header));
    }
}

test "RAR writer rejects unsafe and invalid UTF-8 names" {
    const invalid = [_][]const u8{ "", "/absolute", "../escape", "a/../b", "a//b" };
    for (invalid) |name| {
        const entries = [_]EncodeEntry{.{ .name = name }};
        try std.testing.expectError(
            error.InvalidRarEntryName,
            encodeAlloc(std.testing.allocator, &entries, .{}),
        );
    }
    const invalid_utf8 = [_]EncodeEntry{.{ .name = &.{0xff} }};
    try std.testing.expectError(
        error.InvalidRarEntryName,
        encodeAlloc(std.testing.allocator, &invalid_utf8, .{ .version = .rar4 }),
    );
}

test "RAR extraction rejects encrypted entries before allocating output" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "secret", .data = "encrypted marker" }};
    const encoded = try encodeAlloc(allocator, &entries, .{ .version = .rar4 });
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    const flags = std.mem.readInt(u16, encoded[entry.header_offset + 3 ..][0..2], .little) | 0x0004;
    std.mem.writeInt(u16, encoded[entry.header_offset + 3 ..][0..2], flags, .little);
    writeRar4HeaderCrc(encoded, entry.header_offset, entry.header_offset + entry.header_size);
    const encrypted = try archive.parse(encoded);
    const encrypted_entry = try encrypted.entryAt(0);
    try std.testing.expect(encrypted_entry.encrypted);
    try std.testing.expectError(
        error.RarPasswordRequired,
        encrypted.extractAllocLimited(allocator, encrypted_entry, 0),
    );

    var encrypted_headers: std.ArrayList(u8) = .empty;
    defer encrypted_headers.deinit(allocator);
    try encrypted_headers.appendSlice(allocator, archive.rar5_signature);
    try appendRar5Block(allocator, &encrypted_headers, 4, 0, null, "", "", "");
    try std.testing.expectError(error.EncryptedRarHeaders, archive.parse(encrypted_headers.items));

    const compressed = try encodeAlloc(allocator, &entries, .{ .version = .rar4 });
    defer allocator.free(compressed);
    const stored_archive = try archive.parse(compressed);
    const stored_entry = try stored_archive.entryAt(0);
    compressed[stored_entry.header_offset + 25] = 0x36;
    writeRar4HeaderCrc(
        compressed,
        stored_entry.header_offset,
        stored_entry.header_offset + stored_entry.header_size,
    );
    const compressed_archive = try archive.parse(compressed);
    const compressed_entry = try compressed_archive.entryAt(0);
    try std.testing.expectError(
        error.UnsupportedRarCompression,
        compressed_archive.extractAllocLimited(allocator, compressed_entry, 0),
    );
}
