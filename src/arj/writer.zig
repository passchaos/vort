const std = @import("std");
const archive = @import("archive.zig");
const checksum = @import("../checksum.zig");
const lha = @import("../lha.zig");
const method4 = @import("method4.zig");
const arj_crypto = @import("vail_archive_crypto").arj;

pub const Error = archive.Error || arj_crypto.Error || error{
    InvalidArjEntryName,
    InvalidArjEncryption,
    ArjFileTooLarge,
};

pub const EntryKind = enum { file, directory };

pub const EncryptionOptions = struct {
    password: []const u8,
    modifier: u8,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    method: archive.Method = .method_1,
    kind: EntryKind = .file,
    encryption: ?EncryptionOptions = null,
};

const deterministic_timestamp: u32 = 0;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
) !usize {
    try validateEntries(entries);
    const start = output.items.len;
    errdefer output.items.len = start;
    var archive_bytes: std.ArrayList(u8) = .empty;
    defer archive_bytes.deinit(allocator);

    var encrypted_archive = false;
    for (entries) |entry|
        encrypted_archive = encrypted_archive or entry.encryption != null;
    try appendMainHeader(allocator, &archive_bytes, encrypted_archive);
    for (entries) |entry| {
        var owned: ?[]u8 = null;
        defer if (owned) |bytes| allocator.free(bytes);
        const compressed = if (entry.kind == .directory)
            ""
        else switch (entry.method) {
            .stored => entry.data,
            .method_1, .method_2, .method_3 => blk: {
                const bytes = try lha.encodeLhAlloc(allocator, entry.data, .lh6);
                owned = bytes;
                break :blk bytes;
            },
            .method_4 => blk: {
                const bytes = try method4.encodeAlloc(allocator, entry.data);
                owned = bytes;
                break :blk bytes;
            },
            .no_data => "",
            .unsupported => unreachable,
        };
        const encrypted: ?[]u8 = if (entry.encryption) |encryption| blk: {
            const bytes = try allocator.dupe(u8, compressed);
            errdefer allocator.free(bytes);
            try arj_crypto.crypt(bytes, encryption.password, encryption.modifier);
            break :blk bytes;
        } else null;
        defer if (encrypted) |bytes| allocator.free(bytes);
        const payload = encrypted orelse compressed;
        if (compressed.len > std.math.maxInt(u32) or entry.data.len > std.math.maxInt(u32))
            return error.ArjFileTooLarge;
        try appendLocalHeader(allocator, &archive_bytes, entry, payload.len);
        try archive_bytes.appendSlice(allocator, payload);
    }
    try archive_bytes.appendSlice(allocator, &.{ 0x60, 0xea, 0, 0 });
    try output.ensureUnusedCapacity(allocator, archive_bytes.items.len);
    output.appendSliceAssumeCapacity(archive_bytes.items);
    return archive_bytes.items.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, entries);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendMainHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    encrypted: bool,
) !void {
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(allocator);
    try data.appendSlice(allocator, &.{ 34, 11, 1, 2, @as(u8, 0x10) | @as(u8, @intFromBool(encrypted)), 0, 2, 0 });
    try appendLe32(allocator, &data, deterministic_timestamp);
    try appendLe32(allocator, &data, 0);
    try appendLe32(allocator, &data, 0);
    try appendLe32(allocator, &data, 0);
    try appendLe16(allocator, &data, 0);
    try appendLe16(allocator, &data, 0);
    try data.appendSlice(allocator, &.{ @intFromBool(encrypted), 0, 0, 0 });
    try appendLe16(allocator, &data, 0);
    try data.appendSlice(allocator, "vort.arj\x00\x00");
    try appendHeader(allocator, output, data.items);
}

fn appendLocalHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
    compressed_size: usize,
) !void {
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(allocator);
    const directory = entry.kind == .directory;
    try data.appendSlice(allocator, &.{
        30,
        11,
        1,
        2,
        0x10 | @as(u8, @intFromBool(entry.encryption != null)),
        if (directory) 0 else methodId(entry.method),
        if (directory) 3 else 0,
        if (entry.encryption) |encryption| encryption.modifier else 0,
    });
    try appendLe32(allocator, &data, deterministic_timestamp);
    try appendLe32(allocator, &data, @intCast(compressed_size));
    try appendLe32(allocator, &data, @intCast(entry.data.len));
    try appendLe32(allocator, &data, checksum.crc32Best(entry.data));
    const spec_position = if (std.mem.lastIndexOfScalar(u8, entry.name, '/')) |index|
        index + 1
    else
        0;
    try appendLe16(allocator, &data, @intCast(spec_position));
    try appendLe16(allocator, &data, if (directory) 0x21ed else 0x11a4);
    try data.appendSlice(allocator, &.{ 0, 0 });
    try data.appendSlice(allocator, entry.name);
    try data.appendSlice(allocator, &.{ 0, 0 });
    try appendHeader(allocator, output, data.items);
}

fn appendHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    data: []const u8,
) !void {
    if (data.len > std.math.maxInt(u16)) return error.ArjFileTooLarge;
    try output.appendSlice(allocator, &.{ 0x60, 0xea });
    try appendLe16(allocator, output, @intCast(data.len));
    try output.appendSlice(allocator, data);
    try appendLe32(allocator, output, checksum.crc32Best(data));
    try appendLe16(allocator, output, 0);
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        if (entry.name.len == 0 or entry.name.len > 2568 or
            std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidArjEntryName;
        if (entry.kind == .directory and entry.data.len != 0)
            return error.InvalidArjEntryName;
        if (entry.method == .unsupported) return error.UnsupportedArjMethod;
        if (entry.method == .no_data and entry.data.len != 0)
            return error.InvalidArjEntryName;
        if (entry.encryption) |encryption| {
            if (entry.kind != .file or entry.method == .no_data or
                encryption.password.len == 0)
                return error.InvalidArjEncryption;
        }
    }
}

fn methodId(method: archive.Method) u8 {
    return switch (method) {
        .stored => 0,
        .method_1 => 1,
        .method_2 => 2,
        .method_3 => 3,
        .method_4 => 4,
        .no_data => 8,
        .unsupported => unreachable,
    };
}

fn appendLe16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendLe32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "ARJ writer round trips methods zero through four and directories" {
    const allocator = std.testing.allocator;
    const payload = "ARJ archive payload\n" ** 128;
    const entries = [_]EncodeEntry{
        .{ .name = "stored.bin", .data = &.{ 0, 1, 2, 3 }, .method = .stored },
        .{ .name = "one.txt", .data = payload, .method = .method_1 },
        .{ .name = "two.txt", .data = payload, .method = .method_2 },
        .{ .name = "three.txt", .data = payload, .method = .method_3 },
        .{ .name = "four.txt", .data = payload, .method = .method_4 },
        .{ .name = "empty/", .kind = .directory, .method = .stored },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, &entries, caller_encoded));
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    try std.testing.expectEqualSlices(u8, "vort.arj", parsed.name);
    for (entries) |source| {
        const entry = (try parsed.find(source.name)).?;
        const decoded = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.data, decoded);
    }
}

test "ARJ Garble encryption round trips stored and compressed entries" {
    const allocator = std.testing.allocator;
    const password = "ARJ-password";
    const entries = [_]EncodeEntry{
        .{
            .name = "stored.bin",
            .data = "encrypted stored ARJ payload",
            .method = .stored,
            .encryption = .{ .password = password, .modifier = 0x31 },
        },
        .{
            .name = "compressed.txt",
            .data = "encrypted compressed ARJ payload\n" ** 64,
            .method = .method_1,
            .encryption = .{ .password = password, .modifier = 0xa7 },
        },
        .{
            .name = "fastest.txt",
            .data = "encrypted fastest ARJ payload\n" ** 32,
            .method = .method_4,
            .encryption = .{ .password = password, .modifier = 0x5c },
        },
        .{ .name = "plain.txt", .data = "plain member in garbled archive", .method = .stored },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const repeated = try encodeAlloc(allocator, &entries);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(@as(u8, 1), parsed.encryption_version);
    try std.testing.expect(parsed.flags & 1 != 0);
    for (entries, 0..) |source, index| {
        const entry = try parsed.entryAt(index);
        if (source.encryption) |encryption| {
            try std.testing.expectEqual(archive.Encryption.garble, entry.encryption.?);
            try std.testing.expectEqual(encryption.modifier, entry.password_modifier);
            try std.testing.expectError(
                error.EncryptedArjEntry,
                parsed.extractAlloc(allocator, entry),
            );
        } else {
            try std.testing.expect(entry.encryption == null);
        }
        const decoded = try parsed.extractAllocWithOptions(
            allocator,
            entry,
            .{ .password = password },
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.data, decoded);
    }
    try std.testing.expectError(
        error.ChecksumMismatch,
        parsed.extractAllocWithOptions(
            allocator,
            try parsed.entryAt(0),
            .{ .password = "wrong" },
        ),
    );

    const unsupported = try allocator.dupe(u8, encoded);
    defer allocator.free(unsupported);
    const main_size = std.mem.readInt(u16, unsupported[2..4], .little);
    unsupported[4 + 28] = 2;
    std.mem.writeInt(
        u32,
        unsupported[4 + main_size ..][0..4],
        checksum.crc32Best(unsupported[4 .. 4 + main_size]),
        .little,
    );
    const gost = try archive.parse(unsupported);
    try std.testing.expectEqual(archive.Encryption.gost40, (try gost.entryAt(0)).encryption.?);
    try std.testing.expectError(
        error.UnsupportedArjEncryption,
        gost.extractAllocWithOptions(
            allocator,
            try gost.entryAt(0),
            .{ .password = password },
        ),
    );
}

test "ARJ append supports prefixes and rejects invalid inputs transactionally" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "prefixed ARJ" }};
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "MZ-VORT-ARJ-SFX\n");
    const prefix_len = output.items.len;
    _ = try encodeAppend(allocator, &output, &entries);
    const parsed = try archive.parse(output.items);
    try std.testing.expectEqual(prefix_len, parsed.prefix_size);
    const decoded = try parsed.extractByNameAllocLimited(
        allocator,
        entries[0].name,
        entries[0].data.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, decoded);

    const before = try allocator.dupe(u8, output.items);
    defer allocator.free(before);
    const invalid = [_]EncodeEntry{.{ .name = "", .data = "bad" }};
    try std.testing.expectError(
        error.InvalidArjEntryName,
        encodeAppend(allocator, &output, &invalid),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);

    const invalid_encryption = [_]EncodeEntry{.{
        .name = "secret",
        .data = "bad",
        .encryption = .{ .password = "", .modifier = 1 },
    }};
    try std.testing.expectError(
        error.InvalidArjEncryption,
        encodeAppend(allocator, &output, &invalid_encryption),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);
}

test "ARJ reader validates header payload entry and output bounds" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{
        .name = "payload",
        .data = "checked ARJ payload",
        .method = .stored,
    }};
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const entry = try parsed.entryAt(0);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractAllocLimited(allocator, entry, entry.uncompressed_size - 1),
    );
    var forged = entry;
    forged.data_offset += 1;
    var output: [entries[0].data.len]u8 = undefined;
    try std.testing.expectError(error.InvalidArjArchive, parsed.extractInto(forged, &output));

    const bad_header = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_header);
    bad_header[4] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, archive.parse(bad_header));

    const bad_payload = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_payload);
    bad_payload[entry.data_offset] ^= 1;
    const corrupt = try archive.parse(bad_payload);
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt.extractInto(try corrupt.entryAt(0), &output),
    );
}
