const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const input_module = @import("reader/input.zig");

pub const Error = core.Error || format.Error || input_module.Error;
pub const Index = struct {
    kind: u2,
    logical_offset: usize,
    physical_block: u32,
    compressed_blocks: ?u32 = null,
    partial: bool = false,
    /// Normalized backward lcluster distance for NONHEAD records. Compact
    /// pack-final entries derive it from the previous item, not their own lo.
    lookback: ?usize = null,
};

pub const View = struct {
    index_start: usize,
    cluster_bits: u8,
    advise: u16,
    block_size: usize,
};

pub fn readFull(metadata: []const u8, view: View, cluster_index: usize) Error!Index {
    return readFullInput(.{ .slice = metadata }, view, cluster_index);
}

pub fn readFullInput(metadata: input_module.Input, view: View, cluster_index: usize) Error!Index {
    const index_offset = std.math.add(
        usize,
        view.index_start,
        std.math.mul(usize, cluster_index, 8) catch return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    var record: [8]u8 = undefined;
    try metadata.read(index_offset, &record);
    const kind: u2 = @truncate(format.readU16(&record, 0) & 3);
    const delta = format.readU16(&record, 4);
    return .{
        .kind = kind,
        .partial = kind != 2 and format.readU16(&record, 0) & 0x8000 != 0,
        .logical_offset = format.readU16(&record, 2),
        .physical_block = format.readU32(&record, 4),
        .compressed_blocks = if (kind == 2)
            try blockCount(delta, view)
        else
            null,
        .lookback = if (kind == 2) if (delta & 0x800 != 0) 1 else delta else null,
    };
}

pub fn readCompact(metadata: []const u8, view: View, cluster_index: usize, cluster_count: usize) Error!Index {
    return readCompactInput(.{ .slice = metadata }, view, cluster_index, cluster_count);
}

const Pack = struct { start: usize, size: usize, item: usize };

fn packFor(view: View, cluster_index: usize, cluster_count: usize) Error!Pack {
    const entry_base = view.index_start;
    const initial_4byte = ((32 - entry_base % 32) / 4) & 7;
    const compact_2byte = if (view.advise & 1 != 0 and
        initial_4byte < cluster_count)
        (cluster_count - initial_4byte) / 16 * 16
    else
        0;
    var relative_index = cluster_index;
    var position = entry_base;
    var shift: u3 = 2;
    if (relative_index >= initial_4byte) {
        position = std.math.add(usize, position, initial_4byte * 4) catch return error.IntegerOverflow;
        relative_index -= initial_4byte;
        if (relative_index < compact_2byte) {
            shift = 1;
        } else {
            const size = std.math.mul(usize, compact_2byte, 2) catch return error.IntegerOverflow;
            position = std.math.add(usize, position, size) catch return error.IntegerOverflow;
            relative_index -= compact_2byte;
        }
    }
    const relative = std.math.mul(usize, relative_index, @as(usize, 1) << shift) catch return error.IntegerOverflow;
    position = std.math.add(usize, position, relative) catch return error.IntegerOverflow;
    const entry_size: usize = @as(usize, 1) << shift;
    const value_count: usize = if (entry_size == 4) 2 else 16;
    const pack_size = value_count * entry_size;
    const pack_start = position & ~(pack_size - 1);
    const item_index = (position & (pack_size - 1)) >> shift;
    return .{ .start = pack_start, .size = pack_size, .item = item_index };
}

pub fn compactIndexEnd(view: View, cluster_count: usize) Error!usize {
    if (cluster_count == 0) return view.index_start;
    const pack = try packFor(view, cluster_count - 1, cluster_count);
    return std.math.add(usize, pack.start, pack.size) catch return error.IntegerOverflow;
}

/// Byte position of the shared physical-block base for a compact index pack.
pub fn compactPhysicalBaseOffset(view: View, cluster_index: usize, cluster_count: usize) Error!usize {
    const pack = try packFor(view, cluster_index, cluster_count);
    return std.math.add(usize, pack.start, pack.size - 4) catch return error.IntegerOverflow;
}

pub fn readCompactInput(metadata: input_module.Input, view: View, cluster_index: usize, cluster_count: usize) Error!Index {
    const pack = try packFor(view, cluster_index, cluster_count);
    var buffer: [32]u8 = undefined;
    const data = buffer[0..pack.size];
    try metadata.read(pack.start, data);
    const pack_size = pack.size;
    const item_index = pack.item;
    const value_count: usize = if (pack_size == 8) 2 else 16;
    const logical_bits = @max(view.cluster_bits, 12);
    if (logical_bits > 14) return error.UnsupportedErofsFeature;
    const encoded_bits: usize = (pack_size - 4) * 8 / value_count;
    const value = readPackedBits(
        data[0 .. pack_size - 4],
        encoded_bits * item_index,
        encoded_bits,
    );
    const logical_mask = (@as(u32, 1) << @intCast(logical_bits)) - 1;
    const kind: u2 = @truncate((value >> @intCast(logical_bits)) & 3);
    const lo = value & logical_mask;
    var lookback: ?usize = null;
    if (kind == 2) {
        if (lo & 0x800 != 0) {
            lookback = 1;
        } else if (item_index + 1 != value_count) {
            lookback = lo;
        } else {
            const prior = readPackedBits(data[0 .. pack_size - 4], encoded_bits * (item_index - 1), encoded_bits);
            const prior_kind = (prior >> @intCast(logical_bits)) & 3;
            const prior_lo = prior & logical_mask;
            lookback = if (prior_kind != 2) 1 else if (prior_lo & 0x800 != 0) 2 else prior_lo + 1;
        }
    }
    var physical = format.readU32(data, pack_size - 4);
    if (kind != 2) {
        var scan_index: isize = @intCast(item_index);
        var physical_delta: u32 = if (view.advise & 2 != 0) 0 else 1;
        while (scan_index > 0) {
            scan_index -= 1;
            const previous = readPackedBits(
                data[0 .. pack_size - 4],
                encoded_bits * @as(usize, @intCast(scan_index)),
                encoded_bits,
            );
            const previous_kind = (previous >> @intCast(logical_bits)) & 3;
            const previous_value = previous & logical_mask;
            if (view.advise & 2 != 0) {
                if (previous_kind == 2) {
                    if (previous_value & 0x800 != 0) {
                        scan_index -= 1;
                        physical_delta += previous_value & ~@as(u32, 0x800);
                        continue;
                    }
                    if (previous_value <= 1) return error.InvalidErofs;
                    scan_index -= @intCast(previous_value - 2);
                    continue;
                }
                physical_delta += 1;
            } else {
                if (previous_kind == 2)
                    scan_index -= @intCast(previous_value);
                if (scan_index >= 0) physical_delta += 1;
            }
        }
        physical = std.math.add(u32, physical, physical_delta) catch
            return error.IntegerOverflow;
    }
    return .{
        .kind = kind,
        .logical_offset = value & logical_mask,
        .physical_block = physical,
        .compressed_blocks = if (kind == 2)
            try blockCount(@intCast(lo), view)
        else
            null,
        .lookback = lookback,
    };
}

fn blockCount(delta: u16, view: View) Error!?u32 {
    if (delta & 0x800 == 0) return null;
    if (view.advise & 6 == 0 or view.block_size == 0) return error.InvalidErofs;
    const blocks = delta & ~@as(u16, 0x800);
    // Fragment/inline tails legitimately use zero physical blocks. The
    // extraction path rejects zero for extents stored in the primary image.
    if (blocks > (1024 * 1024) / view.block_size)
        return error.InvalidErofs;
    return blocks;
}

fn readPackedBits(input: []const u8, bit_offset: usize, bit_count: usize) u32 {
    var value: u32 = 0;
    for (0..bit_count) |index| {
        const bit = bit_offset + index;
        value |= @as(u32, (input[bit / 8] >> @intCast(bit & 7)) & 1) <<
            @intCast(index);
    }
    return value;
}
