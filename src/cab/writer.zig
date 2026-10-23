const std = @import("std");
const archive_format = @import("archive.zig");
const checksum = @import("checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const decoder = @import("decoder.zig");
const lzx_encoder = @import("lzx/encoder.zig");
const quantum = @import("quantum.zig");
const types = @import("types.zig");

pub const Error = core.Error || archive_format.Error || deflate.Error || lzx_encoder.Error || quantum.Error || error{
    InvalidCabinetEntryName,
    InvalidCabinetOptions,
    CabinetLimitExceeded,
};

pub const Compression = types.Compression;

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8,
    date: u16 = 0x0021,
    time: u16 = 0,
    attributes: u16 = 0x0020,
};

pub const EncodeOptions = struct {
    compression: Compression = .mszip,
    block_size: u16 = 32 * 1024,
    checksum: bool = true,
    set_id: u16 = 0,
    lzx_window_bits: u5 = 15,
    quantum_window_bits: u5 = 18,
    quantum_level: u4 = 1,
};

const fixed_header_len: usize = 36;
const folder_record_len: usize = 8;
const max_folder_size: usize = 0x7fff_8000;
const max_cabinet_size: usize = 0x7fff_ffff;

test {
    _ = lzx_encoder;
    _ = quantum;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    const folder_size = try validateInputs(entries, options);
    var folder_data: std.ArrayList(u8) = .empty;
    defer folder_data.deinit(allocator);
    try folder_data.ensureTotalCapacity(allocator, folder_size);
    for (entries) |entry| folder_data.appendSliceAssumeCapacity(entry.data);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendNTimes(allocator, 0, fixed_header_len);
    const has_folder = entries.len != 0;
    const folder_record_offset = out.items.len;
    if (has_folder) try out.appendNTimes(allocator, 0, folder_record_len);
    const files_offset = out.items.len;

    var folder_offset: usize = 0;
    for (entries) |entry| {
        try appendFile(allocator, &out, entry, folder_offset);
        folder_offset = try checkedAdd(folder_offset, entry.data.len);
    }
    const data_offset = out.items.len;

    const block_count = if (folder_data.items.len == 0)
        0
    else
        1 + (folder_data.items.len - 1) / options.block_size;
    if (block_count > std.math.maxInt(u16)) return error.CabinetLimitExceeded;
    var data_start: usize = 0;
    var quantum_encoder = quantum.LiteralEncoder.init();
    var lzx_state = try lzx_encoder.CabinetEncoder.init(if (options.compression == .lzx) options.lzx_window_bits else 15);
    while (data_start < folder_data.items.len) {
        const data_end = @min(folder_data.items.len, data_start + options.block_size);
        const block = folder_data.items[data_start..data_end];
        switch (options.compression) {
            .none => try appendDataBlock(allocator, &out, block, block.len, options.checksum),
            .mszip => {
                const history_start = data_start -| (32 * 1024);
                const history = folder_data.items[history_start..data_start];
                const stored = try deflate.encodeRawStoredAlloc(allocator, block);
                defer allocator.free(stored);
                const fixed = try deflate.encodeRawFixedWithDictionaryAlloc(
                    allocator,
                    block,
                    history,
                    deflate.optionsForLevel(.default),
                );
                defer allocator.free(fixed);
                const deflated = if (fixed.len < stored.len) fixed else stored;
                var payload: std.ArrayList(u8) = .empty;
                defer payload.deinit(allocator);
                try payload.ensureTotalCapacity(allocator, deflated.len + 2);
                payload.appendSliceAssumeCapacity("CK");
                payload.appendSliceAssumeCapacity(deflated);
                if (payload.items.len > std.math.maxInt(u16))
                    return error.CabinetLimitExceeded;
                try appendDataBlock(allocator, &out, payload.items, block.len, options.checksum);
            },
            .lzx => {
                const encoded = try lzx_state.encodeBlockAlloc(
                    allocator,
                    folder_data.items,
                    data_start,
                    data_end,
                );
                defer allocator.free(encoded);
                try appendDataBlock(allocator, &out, encoded, block.len, options.checksum);
            },
            .quantum => {
                const encoded = try quantum_encoder.encodeFrameAlloc(allocator, block);
                defer allocator.free(encoded);
                try appendDataBlock(allocator, &out, encoded, block.len, options.checksum);
            },
            else => return error.UnsupportedCabinetCompression,
        }
        data_start = data_end;
    }

    if (out.items.len > max_cabinet_size) return error.CabinetLimitExceeded;
    @memcpy(out.items[0..4], "MSCF");
    std.mem.writeInt(u32, out.items[8..12], @intCast(out.items.len), .little);
    std.mem.writeInt(u32, out.items[16..20], @intCast(files_offset), .little);
    out.items[24] = 3;
    out.items[25] = 1;
    std.mem.writeInt(u16, out.items[26..28], @intFromBool(has_folder), .little);
    std.mem.writeInt(u16, out.items[28..30], @intCast(entries.len), .little);
    std.mem.writeInt(u16, out.items[32..34], options.set_id, .little);
    if (has_folder) {
        std.mem.writeInt(u32, out.items[folder_record_offset..][0..4], @intCast(data_offset), .little);
        std.mem.writeInt(u16, out.items[folder_record_offset + 4 ..][0..2], @intCast(block_count), .little);
        const type_compress = @as(u16, @intFromEnum(options.compression)) | switch (options.compression) {
            .lzx => @as(u16, options.lzx_window_bits) << 8,
            .quantum => (@as(u16, options.quantum_window_bits) << 8) |
                (@as(u16, options.quantum_level) << 4),
            else => 0,
        };
        std.mem.writeInt(u16, out.items[folder_record_offset + 6 ..][0..2], type_compress, .little);
    }
    return out.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    try out.ensureUnusedCapacity(allocator, encoded.len);
    out.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn validateInputs(entries: []const EncodeEntry, options: EncodeOptions) Error!usize {
    if (options.compression != .none and
        options.compression != .mszip and
        options.compression != .quantum and
        options.compression != .lzx)
        return error.UnsupportedCabinetCompression;
    if (options.compression == .lzx and
        (options.lzx_window_bits < 15 or options.lzx_window_bits > 21))
        return error.InvalidCabinetOptions;
    if (options.compression == .quantum and
        (options.quantum_window_bits < 10 or
            options.quantum_window_bits > 21 or
            options.quantum_level < 1 or
            options.quantum_level > 7))
        return error.InvalidCabinetOptions;
    if (options.block_size == 0 or options.block_size > 32 * 1024)
        return error.InvalidCabinetOptions;
    if (entries.len > std.math.maxInt(u16)) return error.CabinetLimitExceeded;
    var folder_size: usize = 0;
    for (entries) |entry| {
        if (entry.name.len == 0 or entry.name.len > 256 or
            std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.InvalidCabinetEntryName;
        if (!std.unicode.utf8ValidateSlice(entry.name))
            return error.InvalidCabinetEntryName;
        if (entry.data.len > max_folder_size) return error.CabinetLimitExceeded;
        folder_size = checkedAdd(folder_size, entry.data.len) catch
            return error.CabinetLimitExceeded;
        if (folder_size > max_folder_size) return error.CabinetLimitExceeded;
    }
    if ((options.compression == .lzx or options.compression == .quantum) and
        folder_size > options.block_size and
        options.block_size != 32 * 1024)
        return error.InvalidCabinetOptions;
    return folder_size;
}

fn appendFile(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodeEntry,
    folder_offset: usize,
) !void {
    try appendU32(allocator, out, @intCast(entry.data.len));
    try appendU32(allocator, out, @intCast(folder_offset));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, entry.date);
    try appendU16(allocator, out, entry.time);
    const utf8_flag: u16 = if (containsNonAscii(entry.name)) 0x0080 else 0;
    try appendU16(allocator, out, (entry.attributes & ~@as(u16, 0x0080)) | utf8_flag);
    try out.appendSlice(allocator, entry.name);
    try out.append(allocator, 0);
}

fn appendDataBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    payload: []const u8,
    decoded_len: usize,
    checksum_enabled: bool,
) !void {
    if (payload.len > std.math.maxInt(u16) or decoded_len > 32 * 1024)
        return error.CabinetLimitExceeded;
    const start = out.items.len;
    try appendU32(allocator, out, 0);
    try appendU16(allocator, out, @intCast(payload.len));
    try appendU16(allocator, out, @intCast(decoded_len));
    try out.appendSlice(allocator, payload);
    if (checksum_enabled)
        std.mem.writeInt(u32, out.items[start..][0..4], checksum.compute(out.items[start + 4 ..]), .little);
}

fn containsNonAscii(bytes: []const u8) bool {
    for (bytes) |byte| if (byte >= 0x80) return true;
    return false;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
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

test "CAB writer deterministically round trips all supported methods" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.txt", .data = "plain CAB payload\n" },
        .{ .name = "目录\\数据.txt", .data = "repeated CAB payload\n" ** 512 },
        .{ .name = "empty.bin", .data = "" },
    };
    inline for (.{ Compression.none, .mszip, .quantum, .lzx }) |compression| {
        const options = EncodeOptions{
            .compression = compression,
            .block_size = if (compression == .lzx or compression == .quantum)
                32 * 1024
            else
                4096,
            .set_id = 0x1234,
        };
        const first = try encodeAlloc(allocator, &entries, options);
        defer allocator.free(first);
        const second = try encodeAlloc(allocator, &entries, options);
        defer allocator.free(second);
        try std.testing.expectEqualSlices(u8, first, second);

        const parsed = try archive_format.parse(first);
        try std.testing.expectEqual(entries.len, parsed.file_count);
        try std.testing.expectEqual(@as(u16, 0x1234), parsed.set_id);
        const folder = try parsed.folderAt(0);
        try std.testing.expectEqual(compression, folder.compression);
        if (compression == .lzx)
            try std.testing.expectEqual(@as(u16, 0x0f03), folder.type_compress);
        if (compression == .quantum)
            try std.testing.expectEqual(@as(u16, 0x1212), folder.type_compress);
        var blocks = parsed.dataBlockIterator(folder);
        while (try blocks.next()) |block| try std.testing.expect(block.checksum != 0);

        for (entries) |source| {
            const entry = (try parsed.find(source.name)).?;
            try std.testing.expectEqual(containsNonAscii(source.name), entry.isUtf8());
            const decoded = try decoder.extractAlloc(allocator, parsed, entry);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, source.data, decoded);
        }
    }
}

test "CAB MSZIP writer uses prior block history" {
    const allocator = std.testing.allocator;
    var payload: [3 * 32 * 1024]u8 = undefined;
    var state: u32 = 0xcab0_1234;
    for (payload[0 .. 32 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[32 * 1024 .. 64 * 1024], payload[0 .. 32 * 1024]);
    @memcpy(payload[64 * 1024 ..], payload[0 .. 32 * 1024]);
    const entries = [_]EncodeEntry{.{ .name = "history.bin", .data = &payload }};
    const encoded = try encodeAlloc(allocator, &entries, .{ .compression = .mszip });
    defer allocator.free(encoded);
    const parsed = try archive_format.parse(encoded);
    const folder = try parsed.folderAt(0);
    try std.testing.expectEqual(@as(usize, 3), folder.data_block_count);
    var blocks = parsed.dataBlockIterator(folder);
    const first = (try blocks.next()).?;
    const second = (try blocks.next()).?;
    const third = (try blocks.next()).?;
    try std.testing.expect(first.compressed.len > 32 * 1024);
    try std.testing.expect(second.compressed.len < 1024);
    try std.testing.expect(third.compressed.len < 1024);
    const decoded = try decoder.extractByNameAlloc(allocator, parsed, "history.bin");
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "CAB LZX writer supports every window and odd final CFDATA alignment" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 40 * 1024 + 37);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 29 +% index / 17);
    const entries = [_]EncodeEntry{.{ .name = "odd-blocks.bin", .data = payload }};

    for (15..22) |window_bits| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = .lzx,
            .lzx_window_bits = @intCast(window_bits),
        });
        defer allocator.free(encoded);
        const parsed = try archive_format.parse(encoded);
        const folder = try parsed.folderAt(0);
        try std.testing.expectEqual(
            @as(u16, 3) | (@as(u16, @intCast(window_bits)) << 8),
            folder.type_compress,
        );
        try std.testing.expectEqual(@as(usize, 2), folder.data_block_count);
        var blocks = parsed.dataBlockIterator(folder);
        _ = (try blocks.next()).?;
        const second = (try blocks.next()).?;
        try std.testing.expect(second.compressed.len < payload.len - 32768);

        const decoded = try decoder.extractByNameAlloc(allocator, parsed, "odd-blocks.bin");
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const tiny_entries = [_]EncodeEntry{.{ .name = "tiny", .data = "final-block" }};
    const tiny = try encodeAlloc(allocator, &tiny_entries, .{
        .compression = .lzx,
        .block_size = 16,
    });
    defer allocator.free(tiny);
    const tiny_archive = try archive_format.parse(tiny);
    try std.testing.expectEqual(@as(usize, 1), (try tiny_archive.folderAt(0)).data_block_count);
    const tiny_decoded = try decoder.extractByNameAlloc(allocator, tiny_archive, "tiny");
    defer allocator.free(tiny_decoded);
    try std.testing.expectEqualStrings("final-block", tiny_decoded);
}

test "CAB Quantum writer retains models across frames and supports all windows" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 32 * 1024 + 257);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 11);
    const entries = [_]EncodeEntry{.{ .name = "quantum.bin", .data = payload }};

    for (10..22) |window_bits| {
        const level: u4 = @intCast(1 + (window_bits - 10) % 7);
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = .quantum,
            .quantum_window_bits = @intCast(window_bits),
            .quantum_level = level,
        });
        defer allocator.free(encoded);
        const parsed = try archive_format.parse(encoded);
        const folder = try parsed.folderAt(0);
        try std.testing.expectEqual(
            @as(u16, 2) |
                (@as(u16, @intCast(window_bits)) << 8) |
                (@as(u16, level) << 4),
            folder.type_compress,
        );
        try std.testing.expectEqual(@as(usize, 2), folder.data_block_count);
        const decoded = try decoder.extractByNameAlloc(allocator, parsed, "quantum.bin");
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "CAB writer append and caller output are transactional" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "payload", .data = "transactional CAB" ** 32 }};
    const expected = try encodeAlloc(allocator, &entries, .{});
    defer allocator.free(expected);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try encodeAppend(allocator, &appended, &entries, .{}));
    try std.testing.expectEqualStrings("prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);

    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    try std.testing.expectEqual(expected.len, try encodeInto(allocator, &entries, output, .{}));
    try std.testing.expectEqualSlices(u8, expected, output);
    @memset(output[0 .. output.len - 1], 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(allocator, &entries, output[0 .. output.len - 1], .{}),
    );
    for (output[0 .. output.len - 1]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    const before = try allocator.dupe(u8, appended.items);
    defer allocator.free(before);
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAppend(allocator, &appended, &entries, .{ .block_size = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.UnsupportedCabinetCompression,
        encodeAlloc(allocator, &entries, .{ .compression = @enumFromInt(15) }),
    );
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .lzx,
            .lzx_window_bits = 14,
        }),
    );
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .lzx,
            .block_size = 16,
        }),
    );
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .quantum,
            .quantum_window_bits = 9,
        }),
    );
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .quantum,
            .quantum_level = 0,
        }),
    );
    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeAlloc(allocator, &entries, .{
            .compression = .quantum,
            .block_size = 16,
        }),
    );
    const bad_name = [_]EncodeEntry{.{ .name = "", .data = "x" }};
    try std.testing.expectError(
        error.InvalidCabinetEntryName,
        encodeAlloc(allocator, &bad_name, .{}),
    );
}

test "CAB writer emits an empty cabinet and optional zero checksums" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, &.{}, .{});
    defer allocator.free(empty);
    const empty_archive = try archive_format.parse(empty);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.folder_count);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.file_count);

    const entries = [_]EncodeEntry{.{ .name = "x", .data = "checksum-free" }};
    const encoded = try encodeAlloc(allocator, &entries, .{ .checksum = false });
    defer allocator.free(encoded);
    const parsed = try archive_format.parse(encoded);
    const folder = try parsed.folderAt(0);
    var blocks = parsed.dataBlockIterator(folder);
    while (try blocks.next()) |block| try std.testing.expectEqual(@as(u32, 0), block.checksum);
}
