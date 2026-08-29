const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const table_skippable_magic: u32 = 0x184d2a5e;
pub const footer_magic: u32 = 0x8f92eab1;
pub const max_frames: usize = 0x0800_0000;
pub const max_frame_decompressed_size: usize = 0x4000_0000;
const footer_len: usize = 9;

/// Parsed metadata for the standardized terminal Zstandard seek table. The
/// retained stream slice is borrowed from the caller and must remain alive and
/// unchanged while entries are queried or iterated.
pub const Table = struct {
    stream: []const u8,
    frame_offset: usize,
    frame_size: usize,
    entry_count: u32,
    has_checksums: bool,
    entry_size: u8,
    compressed_size: u64,
    decompressed_size: u64,

    pub fn iterator(self: Table) Iterator {
        return .{ .table = self };
    }

    pub fn entry(self: Table, frame_index: u32) Error!Entry {
        if (frame_index >= self.entry_count) return error.RangeOutOfBounds;
        var entries = self.iterator();
        var current: Entry = undefined;
        for (0..@as(usize, frame_index) + 1) |_| current = (try entries.next()).?;
        return current;
    }

    pub fn frameIndexForDecompressedOffset(self: Table, offset: u64) Error!u32 {
        if (offset >= self.decompressed_size) return error.RangeOutOfBounds;
        var entries = self.iterator();
        while (try entries.next()) |current| {
            const end = std.math.add(u64, current.decompressed_offset, current.decompressed_size) catch return error.IntegerOverflow;
            if (offset < end) return current.frame_index;
        }
        return error.RangeOutOfBounds;
    }
};

pub const Entry = struct {
    frame_index: u32,
    compressed_offset: u64,
    decompressed_offset: u64,
    compressed_size: u32,
    decompressed_size: u32,
    checksum: ?u32,
};

pub const FrameSize = struct {
    compressed_size: u32,
    decompressed_size: u32,
    checksum: ?u32 = null,
};

pub const Iterator = struct {
    table: Table,
    index: u32 = 0,
    compressed_offset: u64 = 0,
    decompressed_offset: u64 = 0,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.index >= self.table.entry_count) return null;
        if (self.table.entry_size != 8 and self.table.entry_size != 12) return error.CorruptFrame;
        if (self.table.stream.len < footer_len) return error.TruncatedFrame;
        const relative = std.math.mul(usize, @as(usize, self.index), self.table.entry_size) catch return error.IntegerOverflow;
        const entries_offset = std.math.add(usize, self.table.frame_offset, 8) catch return error.IntegerOverflow;
        const offset = std.math.add(usize, entries_offset, relative) catch return error.IntegerOverflow;
        const entries_end = self.table.stream.len - footer_len;
        if (offset > entries_end or entries_end - offset < self.table.entry_size) return error.TruncatedFrame;

        const compressed_size = std.mem.readInt(u32, self.table.stream[offset..][0..4], .little);
        const decompressed_size = std.mem.readInt(u32, self.table.stream[offset + 4 ..][0..4], .little);
        const checksum = if (self.table.has_checksums) std.mem.readInt(u32, self.table.stream[offset + 8 ..][0..4], .little) else null;
        const entry_value = Entry{
            .frame_index = self.index,
            .compressed_offset = self.compressed_offset,
            .decompressed_offset = self.decompressed_offset,
            .compressed_size = compressed_size,
            .decompressed_size = decompressed_size,
            .checksum = checksum,
        };
        self.compressed_offset = std.math.add(u64, self.compressed_offset, compressed_size) catch return error.IntegerOverflow;
        self.decompressed_offset = std.math.add(u64, self.decompressed_offset, decompressed_size) catch return error.IntegerOverflow;
        self.index += 1;
        return entry_value;
    }
};

/// Parse the seek table terminating a complete Zstandard seekable stream. The
/// footer is located from EOF, as required by the contrib seekable format, and
/// the table's cumulative compressed sizes must point exactly at its own
/// skippable header. This rejects a valid-looking footer detached from the
/// frames it claims to index.
pub fn inspect(stream: []const u8) Error!Table {
    if (stream.len < 8 + footer_len) return error.TruncatedFrame;
    const footer = stream[stream.len - footer_len ..];
    if (std.mem.readInt(u32, footer[5..9], .little) != footer_magic) return error.InvalidMagic;

    const descriptor = footer[4];
    if (descriptor & 0x7c != 0) return error.CorruptFrame;
    const has_checksums = descriptor & 0x80 != 0;
    const entry_size: u8 = if (has_checksums) 12 else 8;
    const entry_count = std.mem.readInt(u32, footer[0..4], .little);
    if (entry_count > max_frames) return error.CorruptFrame;
    const entries_len = std.math.mul(usize, @as(usize, entry_count), entry_size) catch return error.IntegerOverflow;
    const frame_len = std.math.add(usize, 8 + footer_len, entries_len) catch return error.IntegerOverflow;
    if (frame_len > stream.len) return error.TruncatedFrame;
    const frame_offset = stream.len - frame_len;
    if (std.mem.readInt(u32, stream[frame_offset..][0..4], .little) != table_skippable_magic) return error.InvalidMagic;
    const declared_payload_len: usize = @intCast(std.mem.readInt(u32, stream[frame_offset + 4 ..][0..4], .little));
    if (declared_payload_len != frame_len - 8) return error.CorruptFrame;

    var table = Table{
        .stream = stream,
        .frame_offset = frame_offset,
        .frame_size = frame_len,
        .entry_count = entry_count,
        .has_checksums = has_checksums,
        .entry_size = entry_size,
        .compressed_size = 0,
        .decompressed_size = 0,
    };
    var entries = table.iterator();
    while (try entries.next()) |_| {}
    if (entries.compressed_offset != frame_offset) return error.CorruptFrame;
    table.compressed_size = entries.compressed_offset;
    table.decompressed_size = entries.decompressed_offset;
    return table;
}

pub fn frameIndexForOffset(table: Table, offset: u64) Error!u32 {
    return table.frameIndexForDecompressedOffset(offset);
}

pub fn encodedTableBound(entry_count: usize, with_checksums: bool) Error!usize {
    if (entry_count > max_frames) return error.InvalidBlockPlan;
    const entry_size: usize = if (with_checksums) 12 else 8;
    const entries_len = std.math.mul(usize, entry_count, entry_size) catch return error.IntegerOverflow;
    const payload_len = std.math.add(usize, entries_len, footer_len) catch return error.IntegerOverflow;
    _ = std.math.cast(u32, payload_len) orelse return error.IntegerOverflow;
    return std.math.add(usize, 8, payload_len) catch return error.IntegerOverflow;
}

pub fn encodeTableAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), entries: []const FrameSize, with_checksums: bool) Error!void {
    const total_len = try encodedTableBound(entries.len, with_checksums);
    const entry_count = std.math.cast(u32, entries.len) orelse return error.IntegerOverflow;
    if (with_checksums) for (entries) |entry_value|
        if (entry_value.checksum == null) return error.InvalidBlockPlan;
    const payload_len = total_len - 8;

    try appendU32(out, allocator, table_skippable_magic);
    try appendU32(out, allocator, @intCast(payload_len));
    for (entries) |entry_value| {
        try appendU32(out, allocator, entry_value.compressed_size);
        try appendU32(out, allocator, entry_value.decompressed_size);
        if (with_checksums) try appendU32(out, allocator, entry_value.checksum.?);
    }
    try appendU32(out, allocator, entry_count);
    try out.append(allocator, if (with_checksums) 0x80 else 0);
    try appendU32(out, allocator, footer_magic);
}

pub fn encodeTableAlloc(allocator: std.mem.Allocator, entries: []const FrameSize, with_checksums: bool) Error![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, try encodedTableBound(entries.len, with_checksums));
    errdefer out.deinit(allocator);
    try encodeTableAppend(allocator, &out, entries, with_checksums);
    return out.toOwnedSlice(allocator);
}

pub fn encodeTableInto(entries: []const FrameSize, with_checksums: bool, output: []u8) Error!usize {
    const needed = try encodedTableBound(entries.len, with_checksums);
    if (with_checksums) for (entries) |entry_value|
        if (entry_value.checksum == null) return error.InvalidBlockPlan;
    if (output.len < needed) return error.OutputTooSmall;
    var out: std.ArrayList(u8) = .{ .items = output[0..0], .capacity = output.len };
    // The exact bound above guarantees all bounded appends.
    appendU32Bounded(&out, table_skippable_magic);
    appendU32Bounded(&out, @intCast(needed - 8));
    for (entries) |entry_value| {
        appendU32Bounded(&out, entry_value.compressed_size);
        appendU32Bounded(&out, entry_value.decompressed_size);
        if (with_checksums) appendU32Bounded(&out, entry_value.checksum.?);
    }
    appendU32Bounded(&out, @intCast(entries.len));
    out.appendAssumeCapacity(if (with_checksums) 0x80 else 0);
    appendU32Bounded(&out, footer_magic);
    return out.items.len;
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32Bounded(out: *std.ArrayList(u8), value: u32) void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    out.appendSliceAssumeCapacity(&bytes);
}

test "seek table parser covers checksum and plain entries" {
    inline for (.{ false, true }) |with_checksums| {
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(std.testing.allocator);
        const compressed_sizes = [_]u32{ 13, 21, 8 };
        const decompressed_sizes = [_]u32{ 5, 34, 0 };
        const checksums = [_]u32{ 0x1234_5678, 0x9abc_def0, 0 };
        for (compressed_sizes) |size| try stream.appendNTimes(std.testing.allocator, 0xa5, size);
        try appendU32(&stream, std.testing.allocator, table_skippable_magic);
        const entry_size: usize = if (with_checksums) 12 else 8;
        try appendU32(&stream, std.testing.allocator, @intCast(compressed_sizes.len * entry_size + footer_len));
        for (compressed_sizes, decompressed_sizes, checksums) |compressed_size, decompressed_size, checksum| {
            try appendU32(&stream, std.testing.allocator, compressed_size);
            try appendU32(&stream, std.testing.allocator, decompressed_size);
            if (with_checksums) try appendU32(&stream, std.testing.allocator, checksum);
        }
        try appendU32(&stream, std.testing.allocator, compressed_sizes.len);
        try stream.append(std.testing.allocator, (if (with_checksums) @as(u8, 0x80) else 0) | 0x03);
        try appendU32(&stream, std.testing.allocator, footer_magic);

        const table = try inspect(stream.items);
        try std.testing.expectEqual(@as(u32, compressed_sizes.len), table.entry_count);
        try std.testing.expectEqual(with_checksums, table.has_checksums);
        try std.testing.expectEqual(@as(usize, 42), table.frame_offset);
        try std.testing.expectEqual(@as(usize, stream.items.len - table.frame_offset), table.frame_size);
        try std.testing.expectEqual(@as(u64, 42), table.compressed_size);
        try std.testing.expectEqual(@as(u64, 39), table.decompressed_size);
        var entries = table.iterator();
        var compressed_offset: u64 = 0;
        var decompressed_offset: u64 = 0;
        for (compressed_sizes, decompressed_sizes, checksums, 0..) |compressed_size, decompressed_size, checksum, i| {
            const entry_value = (try entries.next()) orelse return error.CorruptFrame;
            try std.testing.expectEqual(@as(u32, @intCast(i)), entry_value.frame_index);
            try std.testing.expectEqual(compressed_offset, entry_value.compressed_offset);
            try std.testing.expectEqual(decompressed_offset, entry_value.decompressed_offset);
            try std.testing.expectEqual(compressed_size, entry_value.compressed_size);
            try std.testing.expectEqual(decompressed_size, entry_value.decompressed_size);
            try std.testing.expectEqual(if (with_checksums) checksum else null, entry_value.checksum);
            compressed_offset += compressed_size;
            decompressed_offset += decompressed_size;
        }
        try std.testing.expect((try entries.next()) == null);
        try std.testing.expectEqual(@as(u32, 0), try table.frameIndexForDecompressedOffset(0));
        try std.testing.expectEqual(@as(u32, 1), try frameIndexForOffset(table, 5));
        try std.testing.expectEqual(@as(u32, 1), try table.frameIndexForDecompressedOffset(38));
        try std.testing.expectError(error.RangeOutOfBounds, table.frameIndexForDecompressedOffset(39));
        try std.testing.expectEqual(@as(u64, 13), (try table.entry(1)).compressed_offset);
        try std.testing.expectError(error.RangeOutOfBounds, table.entry(3));
    }
}

test "seek table writers round trip and preserve append errors" {
    const entries = [_]FrameSize{
        .{ .compressed_size = 13, .decompressed_size = 5, .checksum = 0x1234_5678 },
        .{ .compressed_size = 21, .decompressed_size = 34, .checksum = 0x9abc_def0 },
    };
    inline for (.{ false, true }) |with_checksums| {
        const table_bytes = try encodeTableAlloc(std.testing.allocator, &entries, with_checksums);
        defer std.testing.allocator.free(table_bytes);
        try std.testing.expectEqual(try encodedTableBound(entries.len, with_checksums), table_bytes.len);

        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(std.testing.allocator);
        try stream.appendNTimes(std.testing.allocator, 0xa5, 34);
        try encodeTableAppend(std.testing.allocator, &stream, &entries, with_checksums);
        const parsed = try inspect(stream.items);
        try std.testing.expectEqual(@as(u32, entries.len), parsed.entry_count);
        try std.testing.expectEqual(with_checksums, parsed.has_checksums);

        var output: [64]u8 = undefined;
        const written = try encodeTableInto(&entries, with_checksums, &output);
        try std.testing.expectEqualSlices(u8, table_bytes, output[0..written]);
        try std.testing.expectError(error.OutputTooSmall, encodeTableInto(&entries, with_checksums, output[0 .. written - 1]));
    }

    const missing_checksum = [_]FrameSize{.{ .compressed_size = 1, .decompressed_size = 1 }};
    var prefixed: std.ArrayList(u8) = .empty;
    defer prefixed.deinit(std.testing.allocator);
    try prefixed.appendSlice(std.testing.allocator, "prefix");
    try std.testing.expectError(error.InvalidBlockPlan, encodeTableAppend(std.testing.allocator, &prefixed, &missing_checksum, true));
    try std.testing.expectEqualSlices(u8, "prefix", prefixed.items);
}

test "empty seek table is valid and has no addressable output" {
    const encoded = try encodeTableAlloc(std.testing.allocator, &.{}, false);
    defer std.testing.allocator.free(encoded);
    const table = try inspect(encoded);
    try std.testing.expectEqual(@as(u32, 0), table.entry_count);
    try std.testing.expectEqual(@as(u64, 0), table.compressed_size);
    try std.testing.expectEqual(@as(u64, 0), table.decompressed_size);
    try std.testing.expectError(error.RangeOutOfBounds, table.entry(0));
    try std.testing.expectError(error.RangeOutOfBounds, table.frameIndexForDecompressedOffset(0));
    try std.testing.expectError(error.InvalidBlockPlan, encodedTableBound(max_frames + 1, false));
}

test "seek table parser accepts official seekable encoder output" {
    // Generated by zstd contrib/seekable_format `seekable_compression` from
    // `alpha-alpha-alpha-beta-beta-gamma-gamma-delta-delta\n`, frame size 13,
    // level 3, and per-frame checksums enabled.
    const stream = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00, 0x69, 0x00, 0x00, 0x61, 0x6c, 0x70,
        0x68, 0x61, 0x2d, 0x61, 0x6c, 0x70, 0x68, 0x61, 0x2d, 0x61, 0x28, 0xb5,
        0x2f, 0xfd, 0x00, 0x00, 0x69, 0x00, 0x00, 0x6c, 0x70, 0x68, 0x61, 0x2d,
        0x62, 0x65, 0x74, 0x61, 0x2d, 0x62, 0x65, 0x74, 0x28, 0xb5, 0x2f, 0xfd,
        0x00, 0x00, 0x69, 0x00, 0x00, 0x61, 0x2d, 0x67, 0x61, 0x6d, 0x6d, 0x61,
        0x2d, 0x67, 0x61, 0x6d, 0x6d, 0x61, 0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00,
        0x69, 0x00, 0x00, 0x2d, 0x64, 0x65, 0x6c, 0x74, 0x61, 0x2d, 0x64, 0x65,
        0x6c, 0x74, 0x61, 0x0a, 0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x00, 0x01, 0x00,
        0x00, 0x5e, 0x2a, 0x4d, 0x18, 0x45, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00,
        0x00, 0x0d, 0x00, 0x00, 0x00, 0x8f, 0x84, 0xaf, 0xb4, 0x16, 0x00, 0x00,
        0x00, 0x0d, 0x00, 0x00, 0x00, 0x99, 0x62, 0xa6, 0x56, 0x16, 0x00, 0x00,
        0x00, 0x0d, 0x00, 0x00, 0x00, 0xd5, 0xf3, 0x36, 0xe0, 0x16, 0x00, 0x00,
        0x00, 0x0d, 0x00, 0x00, 0x00, 0x35, 0x35, 0x9a, 0x85, 0x09, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x99, 0xe9, 0xd8, 0x51, 0x05, 0x00, 0x00,
        0x00, 0x80, 0xb1, 0xea, 0x92, 0x8f,
    };
    const table = try inspect(&stream);
    try std.testing.expectEqual(@as(u32, 5), table.entry_count);
    try std.testing.expect(table.has_checksums);
    try std.testing.expectEqual(@as(usize, 97), table.frame_offset);
    try std.testing.expectEqual(@as(u64, 97), table.compressed_size);
    try std.testing.expectEqual(@as(u64, 52), table.decompressed_size);
    const last = try table.entry(4);
    try std.testing.expectEqual(@as(u64, 88), last.compressed_offset);
    try std.testing.expectEqual(@as(u64, 52), last.decompressed_offset);
    try std.testing.expectEqual(@as(u32, 9), last.compressed_size);
    try std.testing.expectEqual(@as(u32, 0), last.decompressed_size);
    try std.testing.expectEqual(@as(?u32, 0x51d8_e999), last.checksum);
    try std.testing.expectEqual(@as(u32, 3), try table.frameIndexForDecompressedOffset(51));

    var frame_sizes: [5]FrameSize = undefined;
    var entries = table.iterator();
    for (&frame_sizes) |*frame_size| {
        const entry_value = (try entries.next()).?;
        frame_size.* = .{
            .compressed_size = entry_value.compressed_size,
            .decompressed_size = entry_value.decompressed_size,
            .checksum = entry_value.checksum,
        };
    }
    const rewritten = try encodeTableAlloc(std.testing.allocator, &frame_sizes, true);
    defer std.testing.allocator.free(rewritten);
    try std.testing.expectEqualSlices(u8, stream[table.frame_offset..], rewritten);
}

test "seek table parser rejects malformed terminal tables" {
    const valid = [_]u8{
        0xa5, 0xa5, 0xa5,
        0x5e, 0x2a, 0x4d,
        0x18, 17,   0,
        0,    0,    3,
        0,    0,    0,
        7,    0,    0,
        0,    1,    0,
        0,    0,    0,
        0xb1, 0xea, 0x92,
        0x8f,
    };
    _ = try inspect(&valid);
    try std.testing.expectError(error.TruncatedFrame, inspect(valid[0..16]));
    try std.testing.expectError(error.CorruptFrame, inspect(&.{ 0x5e, 0x2a, 0x4d, 0x18, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0, 0, 0xb1, 0xea, 0x92, 0x8f }));

    var bad_reserved = valid;
    bad_reserved[bad_reserved.len - 5] = 0x04;
    try std.testing.expectError(error.CorruptFrame, inspect(&bad_reserved));
    var bad_footer_magic = valid;
    bad_footer_magic[bad_footer_magic.len - 1] ^= 1;
    try std.testing.expectError(error.InvalidMagic, inspect(&bad_footer_magic));
    var bad_skippable_magic = valid;
    bad_skippable_magic[3] ^= 1;
    try std.testing.expectError(error.InvalidMagic, inspect(&bad_skippable_magic));
    var bad_payload_size = valid;
    bad_payload_size[7] = 1;
    try std.testing.expectError(error.CorruptFrame, inspect(&bad_payload_size));
    var bad_compressed_total = valid;
    bad_compressed_total[11] = 2;
    try std.testing.expectError(error.CorruptFrame, inspect(&bad_compressed_total));
}
