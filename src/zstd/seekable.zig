const std = @import("std");
const core = @import("../core.zig");
const byte_sink = @import("../io/sink.zig");
const wire = @import("seek_table_wire.zig");

pub const Error = core.Error || std.mem.Allocator.Error;
pub const Sink = byte_sink.Sink;

pub const table_skippable_magic: u32 = wire.table_skippable_magic;
pub const footer_magic: u32 = wire.footer_magic;
pub const max_frames: usize = wire.max_frames;
pub const max_frame_decompressed_size: usize = 0x4000_0000;
const footer_len = wire.footer_len;
const header_len = wire.header_len;

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

pub const Entry = wire.Entry;

pub const FrameSize = struct {
    compressed_size: u32,
    decompressed_size: u32,
    checksum: ?u32 = null,
};

/// Caller-owned cumulative index for repeated seek operations. `entries`
/// borrows the storage passed to `buildIndex`; `table` continues to borrow the
/// complete seekable stream.
pub const Index = struct {
    table: Table,
    entries: []const Entry,

    pub fn entry(self: Index, frame_index: u32) Error!Entry {
        const index = std.math.cast(usize, frame_index) orelse return error.IntegerOverflow;
        if (index >= self.entries.len) return error.RangeOutOfBounds;
        return self.entries[index];
    }

    pub fn frameIndexForDecompressedOffset(self: Index, offset: u64) Error!u32 {
        return wire.frameIndexForDecompressedOffset(self.entries, self.table.decompressed_size, offset);
    }
};

pub const Iterator = struct {
    table: Table,
    index: u32 = 0,
    compressed_offset: u64 = 0,
    decompressed_offset: u64 = 0,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.index >= self.table.entry_count) return null;
        if (self.table.entry_size != wire.entrySize(self.table.has_checksums)) return error.CorruptFrame;
        if (self.table.stream.len < footer_len) return error.TruncatedFrame;
        const relative = std.math.mul(usize, @as(usize, self.index), self.table.entry_size) catch return error.IntegerOverflow;
        const entries_offset = std.math.add(usize, self.table.frame_offset, header_len) catch return error.IntegerOverflow;
        const offset = std.math.add(usize, entries_offset, relative) catch return error.IntegerOverflow;
        const entries_end = self.table.stream.len - footer_len;
        if (offset > entries_end or entries_end - offset < self.table.entry_size) return error.TruncatedFrame;

        const entry_value = try wire.readEntryAndAdvance(self.table.stream[offset..][0..self.table.entry_size], self.table.has_checksums, self.index, &self.compressed_offset, &self.decompressed_offset);
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
    if (stream.len < header_len + footer_len) return error.TruncatedFrame;
    const layout = try wire.parseFooter(stream[stream.len - footer_len ..][0..footer_len]);
    const frame_size = std.math.cast(usize, layout.frameSize()) orelse return error.IntegerOverflow;
    const frame_offset: usize = @intCast(try layout.frameOffset(stream.len));
    try wire.validateHeader(stream[frame_offset..][0..header_len], layout);

    var table = Table{
        .stream = stream,
        .frame_offset = frame_offset,
        .frame_size = frame_size,
        .entry_count = layout.entry_count,
        .has_checksums = layout.has_checksums,
        .entry_size = layout.entry_size,
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

pub fn buildIndex(table: Table, storage: []Entry) Error!Index {
    const entry_count = std.math.cast(usize, table.entry_count) orelse return error.IntegerOverflow;
    if (storage.len < entry_count) return error.OutputTooSmall;
    var iterator = table.iterator();
    for (storage[0..entry_count]) |*entry_value|
        entry_value.* = (try iterator.next()) orelse return error.CorruptFrame;
    // `Table` is public for cheap by-value use, so defend the indexed API from
    // a caller-constructed value whose cached totals disagree with its entries.
    if (iterator.compressed_offset != table.compressed_size or
        iterator.decompressed_offset != table.decompressed_size or
        iterator.compressed_offset != table.frame_offset) return error.CorruptFrame;
    return .{ .table = table, .entries = storage[0..entry_count] };
}

pub fn encodedTableBound(entry_count: usize, with_checksums: bool) Error!usize {
    if (entry_count > max_frames) return error.InvalidBlockPlan;
    const entry_size: usize = wire.entrySize(with_checksums);
    const entries_len = std.math.mul(usize, entry_count, entry_size) catch return error.IntegerOverflow;
    const payload_len = std.math.add(usize, entries_len, footer_len) catch return error.IntegerOverflow;
    _ = std.math.cast(u32, payload_len) orelse return error.IntegerOverflow;
    return std.math.add(usize, header_len, payload_len) catch return error.IntegerOverflow;
}

pub fn encodeTableAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), entries: []const FrameSize, with_checksums: bool) Error!void {
    const total_len = try encodedTableBound(entries.len, with_checksums);
    const entry_count = std.math.cast(u32, entries.len) orelse return error.IntegerOverflow;
    try validateChecksums(entries, with_checksums);

    // Write individual fields so growth and partial output on allocation failure
    // are unchanged from the original append path.
    const writer: TableWriter(true) = .{ .out = out, .allocator = allocator };
    try writer.header(@intCast(total_len - header_len));
    try writer.entries(entries, with_checksums);
    try writer.footer(entry_count, with_checksums);
}

pub fn encodeTableAlloc(allocator: std.mem.Allocator, entries: []const FrameSize, with_checksums: bool) Error![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, try encodedTableBound(entries.len, with_checksums));
    errdefer out.deinit(allocator);
    try encodeTableAppend(allocator, &out, entries, with_checksums);
    return out.toOwnedSlice(allocator);
}

pub fn encodeTableInto(entries: []const FrameSize, with_checksums: bool, output: []u8) Error!usize {
    const needed = try encodedTableBound(entries.len, with_checksums);
    try validateChecksums(entries, with_checksums);
    if (output.len < needed) return error.OutputTooSmall;
    var out = std.ArrayList(u8).initBuffer(output);
    const writer: TableWriter(false) = .{ .out = &out, .allocator = {} };
    writer.header(@intCast(needed - header_len)) catch unreachable;
    writer.entries(entries, with_checksums) catch unreachable;
    writer.footer(@intCast(entries.len), with_checksums) catch unreachable;
    return out.items.len;
}

const table_batch_entries = 128;

/// Write the table at `offset` without committing the sink length. Returns the
/// absolute offset immediately after the table. Validation precedes all writes;
/// a sink failure can leave a partial table. Entries must remain unchanged
/// during the call, including from within sink callbacks.
pub fn encodeTableTo(sink: Sink, offset: u64, entries: []const FrameSize, with_checksums: bool) (Error || byte_sink.Error)!u64 {
    const total_len = try encodedTableBound(entries.len, with_checksums);
    const entry_count: u32 = @intCast(entries.len);
    try validateChecksums(entries, with_checksums);
    const end = std.math.add(u64, offset, total_len) catch return error.IntegerOverflow;

    var buffer: [table_batch_entries * wire.checked_entry_len]u8 = undefined;
    var batch = std.ArrayList(u8).initBuffer(&buffer);
    const writer: TableWriter(false) = .{ .out = &batch, .allocator = {} };
    writer.header(@intCast(total_len - header_len)) catch unreachable;
    try sink.writeExact(offset, batch.items);
    var position = offset + batch.items.len;

    var remaining = entries;
    while (remaining.len != 0) {
        const count = @min(table_batch_entries, remaining.len);
        batch.clearRetainingCapacity();
        writer.entries(remaining[0..count], with_checksums) catch unreachable;
        try sink.writeExact(position, batch.items);
        position += batch.items.len;
        remaining = remaining[count..];
    }

    batch.clearRetainingCapacity();
    writer.footer(entry_count, with_checksums) catch unreachable;
    try sink.writeExact(position, batch.items);
    return end;
}

inline fn validateChecksums(entries: []const FrameSize, with_checksums: bool) Error!void {
    if (with_checksums) {
        for (entries) |entry_value| {
            if (entry_value.checksum == null) return error.InvalidBlockPlan;
        }
    }
}

fn TableWriter(comptime growing: bool) type {
    return struct {
        const Self = @This();
        const WriteError = if (growing) std.mem.Allocator.Error else error{};

        out: *std.ArrayList(u8),
        allocator: if (growing) std.mem.Allocator else void,

        inline fn header(self: Self, payload_len: u32) WriteError!void {
            try self.putU32(table_skippable_magic);
            try self.putU32(payload_len);
        }

        inline fn entries(self: Self, sizes: []const FrameSize, with_checksums: bool) WriteError!void {
            for (sizes) |size| {
                try self.putU32(size.compressed_size);
                try self.putU32(size.decompressed_size);
                if (with_checksums) try self.putU32(size.checksum.?);
            }
        }

        inline fn footer(self: Self, entry_count: u32, with_checksums: bool) WriteError!void {
            try self.putU32(entry_count);
            const descriptor: u8 = if (with_checksums) 0x80 else 0;
            if (growing) {
                try self.out.append(self.allocator, descriptor);
            } else {
                self.out.appendAssumeCapacity(descriptor);
            }
            try self.putU32(footer_magic);
        }

        inline fn putU32(self: Self, value: u32) WriteError!void {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, value, .little);
            if (growing) {
                try self.out.appendSlice(self.allocator, &bytes);
            } else {
                self.out.appendSliceAssumeCapacity(&bytes);
            }
        }
    };
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
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

test "caller-owned seek index skips empty frames and checks storage" {
    const frame_sizes = [_]FrameSize{
        .{ .compressed_size = 7, .decompressed_size = 0 },
        .{ .compressed_size = 8, .decompressed_size = 4 },
        .{ .compressed_size = 9, .decompressed_size = 0 },
        .{ .compressed_size = 10, .decompressed_size = 5 },
        .{ .compressed_size = 11, .decompressed_size = 0 },
    };
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    for (frame_sizes) |frame_size|
        try stream.appendNTimes(std.testing.allocator, 0xa5, frame_size.compressed_size);
    try encodeTableAppend(std.testing.allocator, &stream, &frame_sizes, false);

    const table = try inspect(stream.items);
    var short_storage: [frame_sizes.len - 1]Entry = undefined;
    try std.testing.expectError(error.OutputTooSmall, buildIndex(table, &short_storage));

    var storage: [frame_sizes.len]Entry = undefined;
    const index = try buildIndex(table, &storage);
    try std.testing.expectEqual(@as(usize, frame_sizes.len), index.entries.len);
    try std.testing.expectEqual(@as(u64, 7), (try index.entry(1)).compressed_offset);
    try std.testing.expectEqual(@as(u64, 4), (try index.entry(3)).decompressed_offset);
    try std.testing.expectError(error.RangeOutOfBounds, index.entry(frame_sizes.len));

    // Upper-bound lookup deliberately skips zero-output frames at either side
    // of an addressable decompressed offset.
    try std.testing.expectEqual(@as(u32, 1), try index.frameIndexForDecompressedOffset(0));
    try std.testing.expectEqual(@as(u32, 1), try index.frameIndexForDecompressedOffset(3));
    try std.testing.expectEqual(@as(u32, 3), try index.frameIndexForDecompressedOffset(4));
    try std.testing.expectEqual(@as(u32, 3), try index.frameIndexForDecompressedOffset(8));
    try std.testing.expectError(error.RangeOutOfBounds, index.frameIndexForDecompressedOffset(9));
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
    try std.testing.expectError(error.InvalidBlockPlan, encodeTableInto(&missing_checksum, true, &.{}));

    var backing: [4]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&backing);
    const allocator = fixed.allocator();
    try std.testing.expectError(error.OutOfMemory, encodeTableAlloc(allocator, &missing_checksum, true));
    var field: std.ArrayList(u8) = try .initCapacity(allocator, backing.len);
    defer field.deinit(allocator);
    try std.testing.expectError(error.OutOfMemory, encodeTableAppend(allocator, &field, &entries, false));
    try std.testing.expectEqualSlices(u8, &.{ 0x5e, 0x2a, 0x4d, 0x18 }, field.items);
}

test "Zstd source seek table sink writes bounded batches at absolute offsets without finishing" {
    const count = 2 * table_batch_entries + 1;
    const bound = header_len + count * wire.checked_entry_len + footer_len;
    const Context = struct {
        base: u64,
        bytes: [bound]u8 = undefined,
        written: usize = 0,
        largest_request: usize = 0,

        fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (offset != self.base + self.written) return error.SinkWriteFailed;
            const amount = @min(input.len, 37);
            if (amount > self.bytes.len - self.written) return error.SinkWriteFailed;
            @memcpy(self.bytes[self.written..][0..amount], input[0..amount]);
            self.written += amount;
            self.largest_request = @max(self.largest_request, input.len);
            return amount;
        }

        fn setLen(_: *anyopaque, _: u64) error{SinkWriteFailed}!void {
            return error.SinkWriteFailed;
        }
    };

    var entries: [count]FrameSize = undefined;
    for (&entries, 0..) |*entry_value, i| entry_value.* = .{
        .compressed_size = @intCast(i + 3),
        .decompressed_size = @intCast(7 * i),
        .checksum = @as(u32, @intCast(i)) ^ 0x9abc_def0,
    };
    for ([_][]const FrameSize{ &entries, &.{} }) |sizes| {
        for ([_]bool{ false, true }) |with_checksums| {
            var expected: [bound]u8 = undefined;
            const len = try encodeTableInto(sizes, with_checksums, &expected);
            const base = std.math.maxInt(u64) - @as(u64, len);
            var context: Context = .{ .base = base };
            const sink: Sink = .{ .context = &context, .write_at = Context.writeAt, .set_len = Context.setLen };
            try std.testing.expectEqual(std.math.maxInt(u64), try encodeTableTo(sink, base, sizes, with_checksums));
            try std.testing.expectEqual(len, context.written);
            try std.testing.expectEqualSlices(u8, expected[0..len], context.bytes[0..context.written]);
            const largest_request: usize = if (sizes.len == 0) footer_len else table_batch_entries * @as(usize, wire.entrySize(with_checksums));
            try std.testing.expectEqual(largest_request, context.largest_request);
        }
    }
}

test "Zstd source seek table sink rejects invalid tables and overflowing offsets before writes" {
    const Context = struct {
        calls: usize = 0,

        fn writeAt(raw: *anyopaque, _: u64, _: []const u8) error{SinkWriteFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return error.SinkWriteFailed;
        }

        fn setLen(raw: *anyopaque, _: u64) error{SinkWriteFailed}!void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return error.SinkWriteFailed;
        }
    };
    var context: Context = .{};
    const sink: Sink = .{ .context = &context, .write_at = Context.writeAt, .set_len = Context.setLen };
    const missing_checksum: FrameSize = .{ .compressed_size = 2, .decompressed_size = 3 };
    try std.testing.expectError(error.InvalidBlockPlan, encodeTableTo(sink, 0, &.{missing_checksum}, true));
    const offset = std.math.maxInt(u64) - (header_len + footer_len) + 1;
    try std.testing.expectError(error.IntegerOverflow, encodeTableTo(sink, offset, &.{}, true));
    try std.testing.expectEqual(@as(usize, 0), context.calls);
    try std.testing.expectError(error.SinkWriteFailed, encodeTableTo(sink, 0, &.{missing_checksum}, false));
    try std.testing.expectEqual(@as(usize, 1), context.calls);
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
