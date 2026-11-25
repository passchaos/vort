//! Range preflight for seekable Zstandard streams.
const std = @import("std");
const core = @import("../../core.zig");
const seekable = @import("../seekable.zig");
const chunk_admission = @import("../frame/chunk_admission.zig");
const count_limit = @import("../frame/count_limit.zig");

pub const Plan = struct {
    end: u64,
    scratch_len: usize,
};

pub const IndexedPlan = struct {
    end: u64,
    first_entry: usize,
    scratch_len: usize,
};

pub fn prepareTable(table: seekable.Table, offset: u64, length: usize, max_window_size: core.StreamCount) core.Error!Plan {
    const end = try rangeEnd(table, offset, length);
    if (length == 0) return .{ .end = end, .scratch_len = 0 };

    var largest: u32 = 0;
    var entries = table.iterator();
    while (entries.next() catch |err| switch (err) {
        error.OutOfMemory => unreachable, // Iteration does not allocate.
        else => |table_error| return table_error,
    }) |entry| {
        const frame_end = std.math.add(u64, entry.decompressed_offset, entry.decompressed_size) catch return error.IntegerOverflow;
        if (frame_end <= offset) continue;
        if (entry.decompressed_offset >= end) break;
        if (entry.decompressed_size == 0) continue;
        try validateEntryWindow(table, entry, max_window_size);
        largest = @max(largest, entry.decompressed_size);
    }
    return .{ .end = end, .scratch_len = std.math.cast(usize, largest) orelse return error.IntegerOverflow };
}

pub fn prepareIndex(index: seekable.Index, offset: u64, length: usize, max_window_size: core.StreamCount) core.Error!IndexedPlan {
    const end = try rangeEnd(index.table, offset, length);
    if (length == 0) return .{ .end = end, .first_entry = 0, .scratch_len = 0 };

    const first = index.frameIndexForDecompressedOffset(offset) catch |err| switch (err) {
        error.OutOfMemory => unreachable, // Lookup does not allocate.
        else => |index_error| return index_error,
    };
    const first_entry = std.math.cast(usize, first) orelse return error.IntegerOverflow;
    var largest: u32 = 0;
    for (index.entries[first_entry..]) |entry| {
        if (entry.decompressed_offset >= end) break;
        if (entry.decompressed_size == 0) continue;
        try validateEntryWindow(index.table, entry, max_window_size);
        largest = @max(largest, entry.decompressed_size);
    }
    return .{
        .end = end,
        .first_entry = first_entry,
        .scratch_len = std.math.cast(usize, largest) orelse return error.IntegerOverflow,
    };
}

pub fn entryBytes(table: seekable.Table, entry: seekable.Entry) core.Error![]const u8 {
    const start = std.math.cast(usize, entry.compressed_offset) orelse return error.IntegerOverflow;
    const size = std.math.cast(usize, entry.compressed_size) orelse return error.IntegerOverflow;
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (table.frame_offset > table.stream.len or end > table.frame_offset) return error.CorruptFrame;
    return table.stream[start..end];
}

fn rangeEnd(table: seekable.Table, offset: u64, length: usize) core.Error!u64 {
    const length_u64 = std.math.cast(u64, length) orelse return error.IntegerOverflow;
    const end = std.math.add(u64, offset, length_u64) catch return error.IntegerOverflow;
    if (offset > table.decompressed_size or end > table.decompressed_size) return error.RangeOutOfBounds;
    return end;
}

fn validateEntryWindow(table: seekable.Table, entry: seekable.Entry, max_window_size: core.StreamCount) core.Error!void {
    if (max_window_size == std.math.maxInt(core.StreamCount)) return;
    try chunk_admission.validate(&.{try entryBytes(table, entry)}, .standard, max_window_size, count_limit.unlimited);
}
