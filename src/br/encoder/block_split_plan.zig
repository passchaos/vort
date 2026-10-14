const std = @import("std");

pub const Error = error{
    InvalidBlockPlan,
    IntegerOverflow,
};

/// An allocator-owned, run-length encoded assignment of symbols to entropy
/// block types. Types are normalized by first appearance: the first block is
/// type zero, adjacent blocks have different types, and every declared type is
/// used at least once.
pub const Plan = struct {
    lengths: []u32,
    types: []u8,
    type_count: u16,
    estimated_bits: u64,

    /// Copies and validates a complete plan. The returned plan owns both
    /// slices, independently of the caller's input storage.
    pub fn initCopy(
        allocator: std.mem.Allocator,
        lengths: []const u32,
        types: []const u8,
        type_count: u16,
        symbol_count: usize,
        estimated_bits: u64,
    ) (std.mem.Allocator.Error || Error)!Plan {
        if (lengths.len != types.len) return error.InvalidBlockPlan;

        const owned_lengths = try allocator.dupe(u32, lengths);
        errdefer allocator.free(owned_lengths);
        const owned_types = try allocator.dupe(u8, types);
        errdefer allocator.free(owned_types);

        const plan: Plan = .{
            .lengths = owned_lengths,
            .types = owned_types,
            .type_count = type_count,
            .estimated_bits = estimated_bits,
        };
        try plan.validate(symbol_count);
        return plan;
    }

    pub fn clone(self: Plan, allocator: std.mem.Allocator, symbol_count: usize) (std.mem.Allocator.Error || Error)!Plan {
        return initCopy(
            allocator,
            self.lengths,
            self.types,
            self.type_count,
            symbol_count,
            self.estimated_bits,
        );
    }

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.lengths);
        allocator.free(self.types);
    }

    pub fn blockCount(self: Plan) usize {
        return self.lengths.len;
    }

    /// Validates both the structural invariants and the exact number of
    /// symbols covered by the blocks. Summation is checked in `usize`, the
    /// indexing type used by payload slices.
    pub fn validate(self: Plan, symbol_count: usize) Error!void {
        if (self.lengths.len == 0 or self.lengths.len != self.types.len) return error.InvalidBlockPlan;
        if (self.type_count == 0 or self.type_count > 256) return error.InvalidBlockPlan;
        if (self.types[0] != 0) return error.InvalidBlockPlan;

        var used: [256]bool = @splat(false);
        for (self.lengths, self.types, 0..) |length, block_type, block_index| {
            if (length == 0) return error.InvalidBlockPlan;
            if (@as(u16, block_type) >= self.type_count) return error.InvalidBlockPlan;
            if (block_index != 0 and block_type == self.types[block_index - 1]) return error.InvalidBlockPlan;
            used[block_type] = true;
        }

        const total = try sumLengths(usize, self.lengths);
        if (total != symbol_count) return error.InvalidBlockPlan;
        for (used[0..@as(usize, self.type_count)]) |is_used|
            if (!is_used) return error.InvalidBlockPlan;
    }

    /// Returns a cursor that visits each block once. After `validate`, callers
    /// can traverse payload slices in O(symbol_count + blockCount()) by
    /// processing `payload[region.start..region.end]` for every region.
    pub fn cursor(self: *const Plan) Cursor {
        return .{ .plan = self };
    }
};

pub const Region = struct {
    block_index: usize,
    block_type: u8,
    start: usize,
    end: usize,

    pub fn length(self: Region) usize {
        return self.end - self.start;
    }
};

pub const Cursor = struct {
    plan: *const Plan,
    next_block_index: usize = 0,
    next_symbol_start: usize = 0,

    pub fn next(self: *Cursor) Error!?Region {
        if (self.plan.lengths.len != self.plan.types.len) return error.InvalidBlockPlan;
        if (self.next_block_index == self.plan.lengths.len) return null;
        if (self.plan.type_count == 0 or self.plan.type_count > 256) return error.InvalidBlockPlan;

        const block_index = self.next_block_index;
        const length = self.plan.lengths[block_index];
        const block_type = self.plan.types[block_index];
        if (length == 0 or @as(u16, block_type) >= self.plan.type_count) return error.InvalidBlockPlan;
        if (block_index == 0) {
            if (block_type != 0) return error.InvalidBlockPlan;
        } else if (block_type == self.plan.types[block_index - 1]) {
            return error.InvalidBlockPlan;
        }

        const end = std.math.add(usize, self.next_symbol_start, length) catch return error.IntegerOverflow;
        const region: Region = .{
            .block_index = block_index,
            .block_type = block_type,
            .start = self.next_symbol_start,
            .end = end,
        };
        self.next_block_index += 1;
        self.next_symbol_start = end;
        return region;
    }
};

fn sumLengths(comptime Sum: type, lengths: []const u32) error{IntegerOverflow}!Sum {
    var total: Sum = 0;
    for (lengths) |length| {
        const converted = std.math.cast(Sum, length) orelse return error.IntegerOverflow;
        total = std.math.add(Sum, total, converted) catch return error.IntegerOverflow;
    }
    return total;
}

test "block split plan copies owned storage and preserves metadata" {
    var lengths = [_]u32{ 2, 3, 1 };
    var types = [_]u8{ 0, 1, 0 };
    const plan = try Plan.initCopy(std.testing.allocator, &lengths, &types, 2, 6, 91);
    defer plan.deinit(std.testing.allocator);

    lengths[0] = 6;
    types[0] = 1;
    try std.testing.expectEqualSlices(u32, &.{ 2, 3, 1 }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0 }, plan.types);
    try std.testing.expectEqual(@as(usize, 3), plan.blockCount());
    try std.testing.expectEqual(@as(u16, 2), plan.type_count);
    try std.testing.expectEqual(@as(u64, 91), plan.estimated_bits);
}

test "block split plan accepts one block and u32 boundary length" {
    var lengths = [_]u32{std.math.maxInt(u32)};
    var types = [_]u8{0};
    const plan: Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 1,
        .estimated_bits = std.math.maxInt(u64),
    };
    try plan.validate(std.math.maxInt(u32));

    var cursor = plan.cursor();
    const region = (try cursor.next()).?;
    try std.testing.expectEqual(@as(usize, 0), region.start);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u32)), region.end);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u32)), region.length());
    try std.testing.expect((try cursor.next()) == null);
}

test "block split plan supports all 256 type values" {
    var lengths: [256]u32 = @splat(1);
    var types: [256]u8 = undefined;
    for (&types, 0..) |*block_type, index| block_type.* = @intCast(index);

    const plan: Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 256,
        .estimated_bits = 0,
    };
    try plan.validate(256);

    var cursor = plan.cursor();
    var count: usize = 0;
    while (try cursor.next()) |region| {
        try std.testing.expectEqual(count, region.block_index);
        try std.testing.expectEqual(@as(u8, @intCast(count)), region.block_type);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 256), count);
}

test "block split plan rejects invalid structures" {
    var good_lengths = [_]u32{ 1, 1 };
    var good_types = [_]u8{ 0, 1 };

    var empty_lengths = [_]u32{};
    var empty_types = [_]u8{};
    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &empty_lengths,
        .types = &empty_types,
        .type_count = 0,
        .estimated_bits = 0,
    }).validate(0));

    var short_types = [_]u8{0};
    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &short_types,
        .type_count = 1,
        .estimated_bits = 0,
    }).validate(2));

    var zero_lengths = [_]u32{ 0, 2 };
    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &zero_lengths,
        .types = &good_types,
        .type_count = 2,
        .estimated_bits = 0,
    }).validate(2));

    var nonzero_first = [_]u8{ 1, 0 };
    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &nonzero_first,
        .type_count = 2,
        .estimated_bits = 0,
    }).validate(2));

    var repeated_types = [_]u8{ 0, 0 };
    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &repeated_types,
        .type_count = 1,
        .estimated_bits = 0,
    }).validate(2));

    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &good_types,
        .type_count = 1,
        .estimated_bits = 0,
    }).validate(2));

    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &good_types,
        .type_count = 3,
        .estimated_bits = 0,
    }).validate(2));

    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &good_types,
        .type_count = 257,
        .estimated_bits = 0,
    }).validate(2));

    try std.testing.expectError(error.InvalidBlockPlan, (Plan{
        .lengths = &good_lengths,
        .types = &good_types,
        .type_count = 2,
        .estimated_bits = 0,
    }).validate(3));
}

test "block split plan checks total and cursor arithmetic overflow" {
    const overflowing = [_]u32{ std.math.maxInt(u32), 1 };
    try std.testing.expectError(error.IntegerOverflow, sumLengths(u32, &overflowing));

    var lengths = [_]u32{1};
    var types = [_]u8{0};
    const plan: Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 1,
        .estimated_bits = 0,
    };
    var cursor: Cursor = .{
        .plan = &plan,
        .next_symbol_start = std.math.maxInt(usize),
    };
    try std.testing.expectError(error.IntegerOverflow, cursor.next());
}

test "block split plan cursor traverses payload exactly once" {
    var lengths = [_]u32{ 2, 3, 1, 2 };
    var types = [_]u8{ 0, 2, 1, 2 };
    const plan: Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 3,
        .estimated_bits = 0,
    };
    try plan.validate(8);

    const payload = "abcdefgh";
    var per_type: [3]usize = @splat(0);
    var visited: usize = 0;
    var cursor = plan.cursor();
    while (try cursor.next()) |region| {
        for (payload[region.start..region.end]) |_| {
            per_type[region.block_type] += 1;
            visited += 1;
        }
    }

    try std.testing.expectEqual(payload.len, visited);
    try std.testing.expectEqualSlices(usize, &.{ 2, 1, 5 }, &per_type);
    try std.testing.expect((try cursor.next()) == null);
}
