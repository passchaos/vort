const std = @import("std");
const archive_format = @import("archive.zig");
const checksum = @import("checksum.zig");
const core = @import("../core.zig");
const writer = @import("writer.zig");

pub const Error = core.Error || archive_format.Error || writer.Error;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;

pub const SetEncodeOptions = struct {
    cabinet: EncodeOptions = .{},
    max_cabinet_size: usize = 64 * 1024 * 1024,
    name_prefix: []const u8 = "vort-part-",
    disk_name: []const u8 = "Vort cabinet set",
};

pub const EncodedPart = struct {
    name: []u8,
    bytes: []u8,
};

pub const EncodedSet = struct {
    parts: []EncodedPart,

    pub fn deinit(self: *EncodedSet, allocator: std.mem.Allocator) void {
        for (self.parts) |part| {
            allocator.free(part.name);
            allocator.free(part.bytes);
        }
        allocator.free(self.parts);
        self.* = undefined;
    }
};

const Fragment = struct {
    block_index: usize,
    payload_offset: usize,
    payload_len: usize,
    completes_block: bool,
};

const PartPlan = struct {
    first_fragment: usize,
    fragment_count: usize,
};

const fixed_header_len: usize = 36;
const folder_record_len: usize = 8;
const data_record_len: usize = 8;
const flag_previous: u16 = 0x0001;
const flag_next: u16 = 0x0002;
const continued_from_previous: u16 = 0xfffd;
const continued_to_next: u16 = 0xfffe;
const continued_previous_and_next: u16 = 0xffff;

pub fn encodeSetAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: SetEncodeOptions,
) !EncodedSet {
    if (options.max_cabinet_size > std.math.maxInt(u32) or
        options.name_prefix.len + "00000.cab".len > 256 or
        options.disk_name.len == 0 or
        options.disk_name.len > 256 or
        std.mem.indexOfScalar(u8, options.name_prefix, 0) != null or
        std.mem.indexOfScalar(u8, options.disk_name, 0) != null)
        return error.InvalidCabinetOptions;

    const complete = try writer.encodeAlloc(allocator, entries, options.cabinet);
    defer allocator.free(complete);
    if (complete.len <= options.max_cabinet_size)
        return onePart(allocator, complete, options.name_prefix);
    if (entries.len == 0 or options.cabinet.block_size < 2)
        return error.InvalidCabinetOptions;

    const parsed = try archive_format.parse(complete);
    if (parsed.folder_count != 1) return error.InvalidCabinet;
    const folder = try parsed.folderAt(0);
    const blocks = try allocator.alloc(archive_format.DataBlock, folder.data_block_count);
    defer allocator.free(blocks);
    var block_iterator = parsed.dataBlockIterator(folder);
    var block_index: usize = 0;
    while (try block_iterator.next()) |block| : (block_index += 1) blocks[block_index] = block;
    if (block_index != blocks.len or blocks.len == 0) return error.InvalidCabinet;

    const file_table_len = try encodedFileTableLen(entries);
    const maximum_name_len = options.name_prefix.len + "00000.cab".len;
    const maximum_header_len = fixed_header_len +
        2 * (maximum_name_len + 1 + options.disk_name.len + 1) +
        folder_record_len + file_table_len;
    if (options.max_cabinet_size <= maximum_header_len + data_record_len)
        return error.InvalidCabinetOptions;
    const data_capacity = options.max_cabinet_size - maximum_header_len;

    var fragments: std.ArrayList(Fragment) = .empty;
    defer fragments.deinit(allocator);
    var plans: std.ArrayList(PartPlan) = .empty;
    defer plans.deinit(allocator);
    try planParts(allocator, blocks, data_capacity, &fragments, &plans);
    if (plans.items.len < 2 or plans.items.len > std.math.maxInt(u16))
        return error.CabinetLimitExceeded;

    const names = try allocator.alloc([]u8, plans.items.len);
    var names_initialized: usize = 0;
    defer {
        for (names[0..names_initialized]) |name| allocator.free(name);
        allocator.free(names);
    }
    for (names, 0..) |*name, index| {
        name.* = try cabinetNameAlloc(allocator, options.name_prefix, index);
        names_initialized += 1;
    }

    const parts = try allocator.alloc(EncodedPart, plans.items.len);
    var parts_initialized: usize = 0;
    errdefer {
        for (parts[0..parts_initialized]) |part| {
            allocator.free(part.name);
            allocator.free(part.bytes);
        }
        allocator.free(parts);
    }
    for (parts, plans.items, 0..) |*part, plan, index| {
        const bytes = try encodePart(
            allocator,
            entries,
            options,
            folder.type_compress,
            blocks,
            fragments.items[plan.first_fragment..][0..plan.fragment_count],
            names,
            index,
        );
        const name = allocator.dupe(u8, names[index]) catch |err| {
            allocator.free(bytes);
            return err;
        };
        part.* = .{
            .name = name,
            .bytes = bytes,
        };
        parts_initialized += 1;
    }
    return .{ .parts = parts };
}

fn onePart(
    allocator: std.mem.Allocator,
    complete: []const u8,
    prefix: []const u8,
) !EncodedSet {
    const parts = try allocator.alloc(EncodedPart, 1);
    errdefer allocator.free(parts);
    const name = try cabinetNameAlloc(allocator, prefix, 0);
    errdefer allocator.free(name);
    const bytes = try allocator.dupe(u8, complete);
    parts[0] = .{ .name = name, .bytes = bytes };
    return .{ .parts = parts };
}

fn planParts(
    allocator: std.mem.Allocator,
    blocks: []const archive_format.DataBlock,
    data_capacity: usize,
    fragments: *std.ArrayList(Fragment),
    plans: *std.ArrayList(PartPlan),
) !void {
    var block_index: usize = 0;
    var payload_offset: usize = 0;
    while (block_index < blocks.len) {
        const first_fragment = fragments.items.len;
        var capacity = data_capacity;
        while (block_index < blocks.len) {
            if (capacity <= data_record_len) return error.InvalidCabinetOptions;
            const payload = blocks[block_index].compressed;
            const remaining = payload.len - payload_offset;
            const take = @min(remaining, capacity - data_record_len);
            if (take == 0 or take > std.math.maxInt(u16)) return error.InvalidCabinetOptions;
            const completes = take == remaining;
            try fragments.append(allocator, .{
                .block_index = block_index,
                .payload_offset = payload_offset,
                .payload_len = take,
                .completes_block = completes,
            });
            capacity -= data_record_len + take;
            payload_offset += take;
            if (!completes) break;

            block_index += 1;
            payload_offset = 0;
            if (block_index == blocks.len) break;
            if (capacity <= data_record_len) {
                const last = &fragments.items[fragments.items.len - 1];
                if (last.payload_len <= 1) return error.InvalidCabinetOptions;
                last.payload_len -= 1;
                last.completes_block = false;
                block_index -= 1;
                payload_offset = blocks[block_index].compressed.len - 1;
                break;
            }
        }
        const fragment_count = fragments.items.len - first_fragment;
        if (fragment_count > std.math.maxInt(u16)) return error.CabinetLimitExceeded;
        try plans.append(allocator, .{
            .first_fragment = first_fragment,
            .fragment_count = fragment_count,
        });
    }
}

fn encodePart(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: SetEncodeOptions,
    type_compress: u16,
    blocks: []const archive_format.DataBlock,
    fragments: []const Fragment,
    names: []const []u8,
    index: usize,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendNTimes(allocator, 0, fixed_header_len);
    const has_previous = index != 0;
    const has_next = index + 1 != names.len;
    if (has_previous) {
        try appendString(allocator, &out, names[index - 1]);
        try appendString(allocator, &out, options.disk_name);
    }
    if (has_next) {
        try appendString(allocator, &out, names[index + 1]);
        try appendString(allocator, &out, options.disk_name);
    }

    const folder_record_offset = out.items.len;
    try out.appendNTimes(allocator, 0, folder_record_len);
    const files_offset = out.items.len;
    const raw_folder: u16 = if (has_previous and has_next)
        continued_previous_and_next
    else if (has_previous)
        continued_from_previous
    else
        continued_to_next;
    var folder_offset: usize = 0;
    for (entries) |entry| {
        try appendFile(allocator, &out, entry, folder_offset, raw_folder);
        folder_offset = std.math.add(usize, folder_offset, entry.data.len) catch
            return error.IntegerOverflow;
    }

    const data_offset = out.items.len;
    for (fragments) |fragment| {
        const block = blocks[fragment.block_index];
        const end = fragment.payload_offset + fragment.payload_len;
        if (end > block.compressed.len) return error.InvalidCabinet;
        try appendDataBlock(
            allocator,
            &out,
            block.compressed[fragment.payload_offset..end],
            if (fragment.completes_block) block.uncompressed_size else 0,
            options.cabinet.checksum,
        );
    }
    if (out.items.len > options.max_cabinet_size) return error.CabinetLimitExceeded;

    @memcpy(out.items[0..4], "MSCF");
    std.mem.writeInt(u32, out.items[8..12], @intCast(out.items.len), .little);
    std.mem.writeInt(u32, out.items[16..20], @intCast(files_offset), .little);
    out.items[24] = 3;
    out.items[25] = 1;
    std.mem.writeInt(u16, out.items[26..28], 1, .little);
    std.mem.writeInt(u16, out.items[28..30], @intCast(entries.len), .little);
    const flags = @as(u16, @intFromBool(has_previous)) * flag_previous |
        @as(u16, @intFromBool(has_next)) * flag_next;
    std.mem.writeInt(u16, out.items[30..32], flags, .little);
    std.mem.writeInt(u16, out.items[32..34], options.cabinet.set_id, .little);
    std.mem.writeInt(u16, out.items[34..36], @intCast(index), .little);
    std.mem.writeInt(u32, out.items[folder_record_offset..][0..4], @intCast(data_offset), .little);
    std.mem.writeInt(u16, out.items[folder_record_offset + 4 ..][0..2], @intCast(fragments.len), .little);
    std.mem.writeInt(u16, out.items[folder_record_offset + 6 ..][0..2], type_compress, .little);
    return out.toOwnedSlice(allocator);
}

fn encodedFileTableLen(entries: []const EncodeEntry) Error!usize {
    var len: usize = 0;
    for (entries) |entry|
        len = std.math.add(usize, len, 16 + entry.name.len + 1) catch
            return error.IntegerOverflow;
    return len;
}

fn cabinetNameAlloc(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    index: usize,
) ![]u8 {
    if (index >= 99_999) return error.CabinetLimitExceeded;
    const name = try allocator.alloc(u8, prefix.len + "00000.cab".len);
    @memcpy(name[0..prefix.len], prefix);
    @memcpy(name[prefix.len..], "00000.cab");
    var value = index + 1;
    var digit: usize = 5;
    while (digit != 0) {
        digit -= 1;
        name[prefix.len + digit] = @intCast('0' + value % 10);
        value /= 10;
    }
    return name;
}

fn appendString(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    value: []const u8,
) !void {
    try out.appendSlice(allocator, value);
    try out.append(allocator, 0);
}

fn appendFile(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodeEntry,
    folder_offset: usize,
    raw_folder: u16,
) !void {
    try appendU32(allocator, out, @intCast(entry.data.len));
    try appendU32(allocator, out, @intCast(folder_offset));
    try appendU16(allocator, out, raw_folder);
    try appendU16(allocator, out, entry.date);
    try appendU16(allocator, out, entry.time);
    const utf8_flag: u16 = if (containsNonAscii(entry.name)) 0x0080 else 0;
    try appendU16(allocator, out, (entry.attributes & ~@as(u16, 0x0080)) | utf8_flag);
    try appendString(allocator, out, entry.name);
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

test "CAB set writer deterministically round trips every compression method" {
    const cabinet_set = @import("set.zig");
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 90 * 1024 + 37);
    defer allocator.free(payload);
    var state: u32 = 0x5e7c_ab00;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = payload[0..40_000] },
        .{ .name = "folder/second.bin", .data = payload[40_000..] },
    };

    inline for (.{
        archive_format.Compression.none,
        .mszip,
        .quantum,
        .lzx,
    }) |compression| {
        const options = SetEncodeOptions{
            .cabinet = .{
                .compression = compression,
                .block_size = 32 * 1024,
                .set_id = 0x5e7c,
            },
            .max_cabinet_size = 20_000,
            .name_prefix = "case-",
            .disk_name = "Vort set test",
        };
        var first = try encodeSetAlloc(allocator, &entries, options);
        defer first.deinit(allocator);
        var second = try encodeSetAlloc(allocator, &entries, options);
        defer second.deinit(allocator);
        try std.testing.expect(first.parts.len > 2);
        try std.testing.expectEqual(first.parts.len, second.parts.len);

        const archives = try allocator.alloc(archive_format.Archive, first.parts.len);
        defer allocator.free(archives);
        for (first.parts, second.parts, 0..) |part, duplicate, index| {
            try std.testing.expect(part.bytes.len <= options.max_cabinet_size);
            try std.testing.expectEqualSlices(u8, part.name, duplicate.name);
            try std.testing.expectEqualSlices(u8, part.bytes, duplicate.bytes);
            archives[index] = try archive_format.parse(part.bytes);
            try std.testing.expectEqual(@as(u16, @intCast(index)), archives[index].cabinet_index);
            if (index + 1 != first.parts.len) {
                try std.testing.expectEqualStrings(first.parts[index + 1].name, archives[index].next_cabinet_name.?);
                const folder = try archives[index].folderAt(0);
                var blocks = archives[index].dataBlockIterator(folder);
                var last: ?archive_format.DataBlock = null;
                while (try blocks.next()) |block| last = block;
                try std.testing.expectEqual(@as(usize, 0), last.?.uncompressed_size);
            }
        }

        const set = try cabinet_set.CabinetSet.init(archives);
        for (entries) |entry| {
            const decoded = try set.extractByNameAlloc(allocator, entry.name);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
    }
}

test "CAB set writer keeps small archives single and enforces cabinet limits" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{.{ .name = "tiny", .data = "tiny payload" }};
    var encoded = try encodeSetAlloc(allocator, &entries, .{});
    defer encoded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), encoded.parts.len);
    try std.testing.expectEqualStrings("vort-part-00001.cab", encoded.parts[0].name);

    try std.testing.expectError(
        error.InvalidCabinetOptions,
        encodeSetAlloc(allocator, &entries, .{ .max_cabinet_size = 32 }),
    );
}
