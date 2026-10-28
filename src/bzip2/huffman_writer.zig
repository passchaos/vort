//! Standard Bzip2 selector MTF, delta lengths and canonical Huffman data.
const bits = @import("bit_writer.zig");
const planner = @import("huffman_plan.zig");

pub fn write(writer: *bits.BitWriter, plan: *const planner.Plan, symbols: []const u16) !void {
    try writer.writeBits(3, plan.group_count);
    try writer.writeBits(15, plan.selectors.len);
    var mtf: [planner.max_groups]u8 = .{ 0, 1, 2, 3, 4, 5 };
    for (plan.selectors) |group| {
        var position: usize = 0;
        while (mtf[position] != group) : (position += 1) {}
        for (0..position) |_| try writer.writeBit(1);
        try writer.writeBit(0);
        planner.moveToFront(&mtf, position);
    }
    for (0..plan.group_count) |group| {
        var current: u5 = plan.lengths[group][0];
        try writer.writeBits(5, current);
        for (plan.lengths[group][0..plan.alpha_size]) |length| {
            while (current < length) : (current += 1) try writer.writeBits(2, 0b10);
            while (current > length) : (current -= 1) try writer.writeBits(2, 0b11);
            try writer.writeBit(0);
        }
    }
    for (plan.selectors, 0..) |group, chunk| {
        const start = chunk * planner.group_size;
        for (symbols[start..@min(symbols.len, start + planner.group_size)]) |symbol|
            try writer.writeBits(plan.lengths[group][symbol], plan.codes[group][symbol]);
    }
}
