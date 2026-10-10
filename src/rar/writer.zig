const std = @import("std");
const archive = @import("archive.zig");
const checksum = @import("../checksum.zig");
const rar50_encoder = @import("rar50_encoder.zig");

pub const Error = archive.Error || rar50_encoder.Error || std.mem.Allocator.Error || error{
    InvalidRarEntryName,
    RarFileTooLarge,
    RarHeaderTooLarge,
    UnsupportedRarEncodeOptions,
    InvalidRarVolumeSize,
};

pub const Kind = enum { regular, directory };
pub const Compression = enum { stored, rar50 };
pub const Filter = rar50_encoder.Filter;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    kind: Kind = .regular,
    mode: ?u32 = null,
    /// RAR4 stores a DOS date/time word; RAR5 stores Unix seconds.
    /// The value is therefore native to the selected container generation.
    mtime: ?u32 = null,
};

pub const EncodeOptions = struct {
    version: archive.Version = .rar5,
    compression: Compression = .stored,
    dictionary_size: usize = 128 * 1024,
    block_size: usize = 64 * 1024,
    filter: ?Filter = null,
    solid: bool = false,
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
    try validateEntries(entries, options);
    const start = output.items.len;
    errdefer output.items.len = start;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    switch (options.version) {
        .rar4 => try encodeRar4(allocator, &encoded, entries),
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
    if (options.version != .rar5) return error.UnsupportedRarEncodeOptions;
    if (max_payload_per_volume == 0) return error.InvalidRarVolumeSize;
    try validateEntries(entries, options);

    var volumes: std.ArrayList([]u8) = .empty;
    errdefer {
        for (volumes.items) |volume| allocator.free(volume);
        volumes.deinit(allocator);
    }
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var volume_index: usize = 0;
    var payload_in_volume: usize = 0;
    try startRar5Volume(allocator, &current, volume_index, options.solid);
    var encoder = rar50_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
        .filter = options.filter,
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
        const payload = compressed orelse entry.data;
        const compression_info: u64 = if (use_compression)
            try rar50CompressionInfo(options.dictionary_size, solid_continuation)
        else
            0;

        var offset: usize = 0;
        var split_before = false;
        while (offset < payload.len or (!split_before and payload.len == 0)) {
            if (payload_in_volume == max_payload_per_volume) {
                try finishRar5Volume(allocator, &current, true);
                const owned_volume = try current.toOwnedSlice(allocator);
                volumes.append(allocator, owned_volume) catch |err| {
                    allocator.free(owned_volume);
                    return err;
                };
                volume_index = std.math.add(usize, volume_index, 1) catch
                    return error.IntegerOverflow;
                payload_in_volume = 0;
                try startRar5Volume(allocator, &current, volume_index, options.solid);
            }
            const room = max_payload_per_volume - payload_in_volume;
            const fragment_len = @min(room, payload.len - offset);
            const split_after = offset + fragment_len < payload.len;
            const fragment = payload[offset .. offset + fragment_len];
            const fragment_crc = if (split_after)
                checksum.crc32(fragment)
            else
                checksum.crc32(entry.data);
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
            );
            payload_in_volume += fragment_len;
            offset += fragment_len;
            if (!split_after) break;
            split_before = true;
        }
    }

    try finishRar5Volume(allocator, &current, false);
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

fn validateEntries(entries: []const EncodeEntry, options: EncodeOptions) Error!void {
    if (options.compression == .rar50) {
        if (options.version != .rar5 or options.block_size == 0 or
            options.block_size > rar50_encoder.max_block_size)
            return error.UnsupportedRarEncodeOptions;
        _ = try rar50CompressionInfo(options.dictionary_size, false);
        try rar50_encoder.validateOptions(.{
            .dictionary_size = options.dictionary_size,
            .block_size = options.block_size,
            .filter = options.filter,
        });
        if (options.solid and options.filter != null)
            return error.UnsupportedRarEncodeOptions;
    } else if (options.filter != null) {
        return error.UnsupportedRarEncodeOptions;
    } else if (options.solid) {
        return error.UnsupportedRarEncodeOptions;
    }
    for (entries) |entry| {
        if (!archive.isSafePath(entry.name) or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidRarEntryName;
        if (entry.kind == .directory and entry.data.len != 0) return error.UnsupportedRarEntry;
        if (options.version == .rar4) {
            for (entry.name) |byte|
                if (byte >= 0x80) return error.InvalidRarEntryName;
        } else if (!std.unicode.utf8ValidateSlice(entry.name)) {
            return error.InvalidRarEntryName;
        }
    }
}

fn encodeRar4(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
) !void {
    try output.appendSlice(allocator, archive.rar4_signature);
    try appendRar4Main(allocator, output);
    for (entries) |entry| try appendRar4File(allocator, output, entry);
    try appendRar4ShortHeader(allocator, output, 0x7b, 0x4000);
}

fn appendRar4Main(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, 2);
    try output.append(allocator, 0x73);
    try appendLe16(allocator, output, 0);
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
) !void {
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, 2);
    try output.append(allocator, header_type);
    try appendLe16(allocator, output, flags);
    try appendLe16(allocator, output, 7);
    writeRar4HeaderCrc(output.items, start, output.items.len);
}

fn appendRar4File(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
) !void {
    const packed_size = std.math.cast(u32, entry.data.len) orelse return error.RarFileTooLarge;
    const name_size = std.math.cast(u16, entry.name.len) orelse return error.RarHeaderTooLarge;
    const header_size_usize = std.math.add(usize, 32, entry.name.len) catch
        return error.IntegerOverflow;
    const header_size = std.math.cast(u16, header_size_usize) orelse return error.RarHeaderTooLarge;
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, 2);
    try output.append(allocator, 0x74);
    const flags: u16 = 0x8000 | if (entry.kind == .directory) @as(u16, 0x00e0) else 0;
    try appendLe16(allocator, output, flags);
    try appendLe16(allocator, output, header_size);
    try appendLe32(allocator, output, packed_size);
    try appendLe32(allocator, output, packed_size);
    try output.append(allocator, 3); // Unix host.
    try appendLe32(allocator, output, checksum.crc32(entry.data));
    try appendLe32(allocator, output, entry.mtime orelse 0);
    try output.append(allocator, 29);
    try output.append(allocator, 0x30);
    try appendLe16(allocator, output, name_size);
    const default_mode: u32 = if (entry.kind == .directory) 0o040755 else 0o100644;
    try appendLe32(allocator, output, entry.mode orelse default_mode);
    for (entry.name) |byte| try output.append(allocator, if (byte == '/') '\\' else byte);
    writeRar4HeaderCrc(output.items, start, output.items.len);
    try output.appendSlice(allocator, entry.data);
}

fn writeRar4HeaderCrc(bytes: []u8, start: usize, end: usize) void {
    const crc: u16 = @truncate(checksum.crc32(bytes[start + 2 .. end]));
    std.mem.writeInt(u16, bytes[start..][0..2], crc, .little);
}

fn encodeRar5(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !void {
    try output.appendSlice(allocator, archive.rar5_signature);
    var encoder = rar50_encoder.Encoder.init(allocator, .{
        .dictionary_size = options.dictionary_size,
        .block_size = options.block_size,
        .filter = options.filter,
    });
    defer encoder.deinit();
    var main_specific: std.ArrayList(u8) = .empty;
    defer main_specific.deinit(allocator);
    try appendVint(allocator, &main_specific, if (options.solid) @as(u64, 0x0004) else 0);
    try appendRar5Block(allocator, output, 1, 0, null, main_specific.items, "", "");
    for (entries) |entry| try appendRar5File(
        allocator,
        output,
        entry,
        options,
        &encoder,
    );
    var end_specific: std.ArrayList(u8) = .empty;
    defer end_specific.deinit(allocator);
    try appendVint(allocator, &end_specific, 0);
    try appendRar5Block(allocator, output, 5, 0, null, end_specific.items, "", "");
}

fn startRar5Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    volume_index: usize,
    solid: bool,
) !void {
    try output.appendSlice(allocator, archive.rar5_signature);
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    var archive_flags: u64 = 0x0001 | 0x0002;
    if (solid) archive_flags |= 0x0004;
    try appendVint(allocator, &specific, archive_flags);
    try appendVint(allocator, &specific, volume_index);
    try appendRar5Block(allocator, output, 1, 0, null, specific.items, "", "");
}

fn finishRar5Volume(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    has_next_volume: bool,
) !void {
    var specific: std.ArrayList(u8) = .empty;
    defer specific.deinit(allocator);
    try appendVint(allocator, &specific, @intFromBool(has_next_volume));
    try appendRar5Block(allocator, output, 5, 0, null, specific.items, "", "");
}

fn appendRar5File(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    options: EncodeOptions,
    encoder: *rar50_encoder.Encoder,
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
    try appendRar5FileFragment(
        allocator,
        output,
        entry,
        payload,
        compression_info,
        checksum.crc32(entry.data),
        0,
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
    try appendRar5Block(
        allocator,
        output,
        2,
        0x0002 | general_flags,
        payload.len,
        specific.items,
        "",
        payload,
    );
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
    const crc_start = output.items.len;
    try output.appendNTimes(allocator, 0, 4);
    try output.appendSlice(allocator, size_field.items);
    try output.appendSlice(allocator, body.items);
    const crc = checksum.crc32(output.items[crc_start + 4 ..]);
    std.mem.writeInt(u32, output.items[crc_start..][0..4], crc, .little);
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
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        encodeVolumesAlloc(
            allocator,
            &stored_entries,
            .{ .version = .rar4 },
            1500,
        ),
    );
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

test "RAR writer rejects unsafe and non-ASCII RAR4 names" {
    const invalid = [_][]const u8{ "", "/absolute", "../escape", "a/../b", "a//b" };
    for (invalid) |name| {
        const entries = [_]EncodeEntry{.{ .name = name }};
        try std.testing.expectError(
            error.InvalidRarEntryName,
            encodeAlloc(std.testing.allocator, &entries, .{}),
        );
    }
    const unicode = [_]EncodeEntry{.{ .name = "目录/数据.txt" }};
    try std.testing.expectError(
        error.InvalidRarEntryName,
        encodeAlloc(std.testing.allocator, &unicode, .{ .version = .rar4 }),
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
        error.EncryptedRarEntry,
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
