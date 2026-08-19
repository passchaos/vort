pub const max_ops = 286 + 30;

pub const Op = struct {
    symbol: u8,
    extra_bits: u6 = 0,
    extra_value: u8 = 0,
};

pub const Plan = struct {
    items: [max_ops]Op = undefined,
    len: usize = 0,
    frequencies: [19]u32 = @splat(0),
    extra_bit_count: usize = 0,

    pub fn slice(self: *const Plan) []const Op {
        return self.items[0..self.len];
    }

    fn append(self: *Plan, op: Op) error{InvalidBlockPlan}!void {
        // RLE repeat operations always replace multiple raw lengths with one
        // operation, so no valid plan can exceed the source sequence length.
        if (self.len >= self.items.len) return error.InvalidBlockPlan;
        self.items[self.len] = op;
        self.len += 1;
        self.frequencies[op.symbol] += 1;
        self.extra_bit_count += op.extra_bits;
    }
};

/// Plan RFC 1951 code-length RLE across the HLIT/HDIST boundary without first
/// materializing their concatenation. Operation frequencies and extra-bit cost
/// are accumulated in the same pass for the bit-length Huffman tree.
pub fn build(literal_lengths: []const u4, distance_lengths: []const u4) error{InvalidBlockPlan}!Plan {
    var plan: Plan = .{};
    var distance_start: usize = 0;
    var index: usize = 0;
    while (index < literal_lengths.len) {
        const value = literal_lengths[index];
        const end = runEnd(literal_lengths, index, value);
        var run = end - index;
        // RFC 1951 serializes HLIT and HDIST as one sequence. Merge only the
        // one run that can cross their boundary, while keeping both hot scans
        // contiguous and branch-free per element.
        if (end == literal_lengths.len and distance_lengths.len != 0 and distance_lengths[0] == value) {
            distance_start = runEnd(distance_lengths, 0, value);
            run += distance_start;
        }
        try appendRun(&plan, value, run);
        index = end;
    }
    index = distance_start;
    while (index < distance_lengths.len) {
        const value = distance_lengths[index];
        const end = runEnd(distance_lengths, index, value);
        try appendRun(&plan, value, end - index);
        index = end;
    }
    return plan;
}

fn runEnd(lengths: []const u4, start: usize, value: u4) usize {
    var end = start + 1;
    while (end < lengths.len and lengths[end] == value) end += 1;
    return end;
}

fn appendRun(plan: *Plan, value: u4, run: usize) error{InvalidBlockPlan}!void {
    if (value == 0) {
        var remaining = run;
        while (remaining >= 11) {
            const count = @min(remaining, 138);
            try plan.append(.{ .symbol = 18, .extra_bits = 7, .extra_value = @intCast(count - 11) });
            remaining -= count;
        }
        if (remaining >= 3) {
            try plan.append(.{ .symbol = 17, .extra_bits = 3, .extra_value = @intCast(remaining - 3) });
            remaining = 0;
        }
        while (remaining > 0) : (remaining -= 1) try plan.append(.{ .symbol = 0 });
    } else {
        try plan.append(.{ .symbol = value });
        var remaining = run - 1;
        while (remaining >= 3) {
            const count = @min(remaining, 6);
            try plan.append(.{ .symbol = 16, .extra_bits = 2, .extra_value = @intCast(count - 3) });
            remaining -= count;
        }
        while (remaining > 0) : (remaining -= 1) try plan.append(.{ .symbol = value });
    }
}

test "code-length RLE fuses frequency and extra-bit accounting" {
    const literal = [_]u4{0} ** 20 ++ [_]u4{5} ** 7;
    const distance = [_]u4{5} ** 4;
    const plan = try build(&literal, &distance);
    var frequencies: [19]u32 = @splat(0);
    var extra_bits: usize = 0;
    for (plan.slice()) |op| {
        frequencies[op.symbol] += 1;
        extra_bits += op.extra_bits;
    }
    try @import("std").testing.expectEqual(frequencies, plan.frequencies);
    try @import("std").testing.expectEqual(extra_bits, plan.extra_bit_count);
}
