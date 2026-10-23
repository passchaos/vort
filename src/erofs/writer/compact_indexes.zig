const std = @import("std");
const tree = @import("tree.zig");
const indexes = @import("../compression_index.zig");

pub const Error = indexes.Error;

/// Physical progress follows extents rather than logical clusters. A head
/// consumes one block unless the next NONHEAD supplies its CBLKCNT. Packs
/// starting inside an extent inherit the address after its physical blocks.
const Physical = struct {
    block: u32,
    pending_head: bool,

    fn head(self: *Physical) Error!void {
        if (self.pending_head) self.block = std.math.add(u32, self.block, 1) catch return error.IntegerOverflow;
        self.pending_head = true;
    }

    fn count(self: *Physical, blocks: u32) Error!void {
        if (!self.pending_head) return error.InvalidErofs;
        self.block = std.math.add(u32, self.block, blocks) catch return error.IntegerOverflow;
        self.pending_head = false;
    }
};

pub fn write(metadata: []u8, view: indexes.View, records: []const tree.Node.CompressionIndex, first_block: u32, tail_index: ?usize) Error!void {
    if (view.cluster_bits != 12 or first_block == 0 or view.index_start % 8 != 0)
        return error.InvalidErofs;
    const end = try indexes.compactIndexEnd(view, records.len);
    if (end > metadata.len) return error.InvalidErofs;
    const big = view.advise & 2 != 0;
    var physical = Physical{ .block = first_block - @as(u32, @intFromBool(!big)), .pending_head = !big };
    var logical: usize = 0;
    while (logical < records.len) {
        const pack = try indexes.compactPack(view, logical, records.len);
        if (pack.item != 0 or pack.start < view.index_start) return error.InvalidErofs;
        const count: usize = if (pack.size == 8) 2 else 16;
        const actual = @min(count, records.len - logical);
        const data = metadata[pack.start..][0..pack.size];
        @memset(data, 0);
        const bits = (pack.size - 4) * 8 / count;
        var base = physical.block;
        for (records[logical..][0..actual], 0..) |record, item| {
            const index = logical + item;
            var lo: u16 = record.logical_offset;
            if (record.kind == 2) {
                if (index == 0) return error.InvalidErofs;
                const delta0: u16 = @truncate(record.physical_block);
                if (delta0 & 0x800 != 0) {
                    const blocks = delta0 & ~@as(u16, 0x800);
                    if (!big or blocks == 0 or blocks > 256) return error.InvalidErofs;
                    try physical.count(blocks);
                    lo = delta0;
                } else {
                    if (delta0 == 0 or delta0 >= 0x800) return error.InvalidErofs;
                    lo = if (item + 1 == count) @min(@as(u16, @truncate(record.physical_block >> 16)), 0x7ff) else delta0;
                }
            } else {
                if (lo >= 4096) return error.InvalidErofs;
                try physical.head();
                // Big packs beginning with a head resolve a pending previous
                // single-block extent before selecting their shared base.
                if (big and item == 0) base = physical.block;
                if (tail_index == null or index < tail_index.?) {
                    if (record.physical_block != physical.block) return error.InvalidErofs;
                }
            }
            setBits(data[0 .. pack.size - 4], item * bits, bits, (@as(u32, record.kind) << 12) | lo);
        }
        std.mem.writeInt(u32, data[pack.size - 4 ..][0..4], base, .little);
        logical += actual;
    }
}

fn setBits(data: []u8, start: usize, count: usize, value: u32) void {
    for (0..count) |index| {
        const bit = start + index;
        data[bit / 8] |= (@as(u8, @truncate(value >> @intCast(index))) & 1) << @intCast(bit % 8);
    }
}
