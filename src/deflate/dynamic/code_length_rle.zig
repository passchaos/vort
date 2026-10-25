const std = @import("std");

pub const max_ops = 286 + 30;

pub const Op = struct {
    symbol: u8,
    extra_bits: u6 = 0,
    extra_value: u8 = 0,
};

pub const Plan = PlanFor(max_ops);

pub fn PlanFor(comptime capacity: usize) type {
    return struct {
        items: [capacity]Op = undefined,
        len: usize = 0,
        frequencies: [19]u32 = @splat(0),
        extra_bit_count: usize = 0,

        const Self = @This();

        pub fn slice(self: *const Self) []const Op {
            return self.items[0..self.len];
        }

        fn append(self: *Self, op: Op) error{InvalidBlockPlan}!void {
            // RLE repeat operations always replace multiple raw lengths with
            // one operation, so output never exceeds admitted source length.
            if (self.len >= self.items.len) return error.InvalidBlockPlan;
            self.items[self.len] = op;
            self.len += 1;
            self.frequencies[op.symbol] += 1;
            self.extra_bit_count += op.extra_bits;
        }
    };
}

/// Plan RFC 1951 code-length RLE across the HLIT/HDIST boundary without first
/// materializing their concatenation. Operation frequencies and extra-bit cost
/// are accumulated in the same pass for the bit-length Huffman tree.
pub fn build(literal_lengths: []const u4, distance_lengths: []const u4) error{InvalidBlockPlan}!Plan {
    return buildFor(max_ops, literal_lengths, distance_lengths);
}

/// Deflate64 can supply 286 literal/length plus 32 distance code lengths.
/// Admission precedes source reads, including checked concatenation geometry.
pub fn buildFor(comptime capacity: usize, literal_lengths: []const u4, distance_lengths: []const u4) error{InvalidBlockPlan}!PlanFor(capacity) {
    const source_len = std.math.add(usize, literal_lengths.len, distance_lengths.len) catch return error.InvalidBlockPlan;
    if (source_len > capacity) return error.InvalidBlockPlan;
    var plan: PlanFor(capacity) = .{};
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

fn appendRun(plan: anytype, value: u4, run: usize) error{InvalidBlockPlan}!void {
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
    try std.testing.expectEqual(frequencies, plan.frequencies);
    try std.testing.expectEqual(extra_bits, plan.extra_bit_count);
}

/// Independent decoder of emitted operations, with per-symbol accounting.
fn expectExpansion(comptime capacity: usize, literals: []const u4, distances: []const u4, plan: *const PlanFor(capacity)) !void {
    var expanded: [capacity]u4 = undefined;
    var written: usize = 0;
    var frequencies: [19]u32 = @splat(0);
    var extra_bits: usize = 0;
    for (plan.slice()) |op| {
        try std.testing.expect(op.symbol < 19);
        frequencies[op.symbol] += 1;
        extra_bits += op.extra_bits;
        var value: u4 = 0;
        var count: usize = 1;
        switch (op.symbol) {
            0...15 => {
                value = @intCast(op.symbol);
                try std.testing.expectEqual(@as(u6, 0), op.extra_bits);
                try std.testing.expectEqual(@as(u8, 0), op.extra_value);
            },
            16 => {
                try std.testing.expect(written != 0);
                try std.testing.expectEqual(@as(u6, 2), op.extra_bits);
                try std.testing.expect(op.extra_value <= 3);
                value = expanded[written - 1];
                count = 3 + @as(usize, op.extra_value);
            },
            17 => {
                try std.testing.expectEqual(@as(u6, 3), op.extra_bits);
                try std.testing.expect(op.extra_value <= 7);
                count = 3 + @as(usize, op.extra_value);
            },
            18 => {
                try std.testing.expectEqual(@as(u6, 7), op.extra_bits);
                try std.testing.expect(op.extra_value <= 127);
                count = 11 + @as(usize, op.extra_value);
            },
            else => unreachable,
        }
        try std.testing.expect(count <= expanded.len - written);
        @memset(expanded[written..][0..count], value);
        written += count;
    }
    try std.testing.expectEqual(literals.len + distances.len, written);
    try std.testing.expectEqualSlices(u4, literals, expanded[0..literals.len]);
    try std.testing.expectEqualSlices(u4, distances, expanded[literals.len..written]);
    try std.testing.expectEqualSlices(u32, &frequencies, &plan.frequencies);
    try std.testing.expectEqual(extra_bits, plan.extra_bit_count);
}

test "code-length RLE 318 capacity preserves alternating worst case and ordinary wrapper" {
    var lengths: [318]u4 = undefined;
    for (&lengths, 0..) |*value, index| value.* = @intCast(1 + index % 2);
    const plan = try buildFor(318, lengths[0..286], lengths[286..]);
    try std.testing.expectEqual(@as(usize, 318), plan.len);
    try std.testing.expectEqual(@as(u32, 159), plan.frequencies[1]);
    try std.testing.expectEqual(@as(u32, 159), plan.frequencies[2]);
    try expectExpansion(318, lengths[0..286], lengths[286..], &plan);
    const ordinary = try build(lengths[0..286], lengths[286..316]);
    const explicit = try buildFor(316, lengths[0..286], lengths[286..316]);
    try std.testing.expectEqualDeep(ordinary.slice(), explicit.slice());
    try std.testing.expectEqual(ordinary.frequencies, explicit.frequencies);
    try expectExpansion(316, lengths[0..286], lengths[286..316], &ordinary);
    try std.testing.expectError(error.InvalidBlockPlan, build(lengths[0..286], lengths[286..]));
    const oversized: [319]u4 = @splat(0);
    try std.testing.expectError(error.InvalidBlockPlan, buildFor(318, oversized[0..286], oversized[286..]));
}

test "code-length RLE 318 repeats fuse across literal and distance alphabets" {
    const nonzero = [_]u4{5} ** 4;
    const repeated = try buildFor(318, nonzero[0..2], nonzero[2..]);
    try std.testing.expectEqual(@as(usize, 2), repeated.len);
    try std.testing.expectEqual(@as(u8, 16), repeated.items[1].symbol);
    try expectExpansion(318, nonzero[0..2], nonzero[2..], &repeated);
    const zero_short = [_]u4{0} ** 3;
    const short = try buildFor(318, zero_short[0..2], zero_short[2..]);
    try std.testing.expectEqual(@as(usize, 1), short.len);
    try std.testing.expectEqual(@as(u8, 17), short.items[0].symbol);
    try expectExpansion(318, zero_short[0..2], zero_short[2..], &short);
    const zero_long = [_]u4{0} ** 11;
    const long = try buildFor(318, zero_long[0..5], zero_long[5..]);
    try std.testing.expectEqual(@as(usize, 1), long.len);
    try std.testing.expectEqual(@as(u8, 18), long.items[0].symbol);
    try expectExpansion(318, zero_long[0..5], zero_long[5..], &long);
    var lengths: [318]u4 = undefined;
    for ([_]u4{ 0, 5, 15 }) |value| {
        @memset(&lengths, value);
        const plan = try buildFor(318, lengths[0..286], lengths[286..]);
        try expectExpansion(318, lengths[0..286], lengths[286..], &plan);
    }
}

test "code-length RLE generalized run boundaries and empty alphabets expand exactly" {
    var lengths: [318]u4 = undefined;
    for ([_]usize{ 0, 1, 2, 3, 4, 6, 7, 10, 11, 12, 138, 139, 276, 318 }) |length| {
        for ([_]u4{ 0, 1, 15 }) |value| {
            @memset(&lengths, value);
            for ([_]usize{ 0, length / 2, length }) |boundary| {
                const plan = try buildFor(318, lengths[0..boundary], lengths[boundary..length]);
                try expectExpansion(318, lengths[0..boundary], lengths[boundary..length], &plan);
            }
        }
    }
    const empty = try buildFor(0, &.{}, &.{});
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}
