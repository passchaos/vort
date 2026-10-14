const std = @import("std");
const block_split_plan = @import("block_split_plan.zig");

pub const max_type_count: u16 = 256;
pub const max_alphabet_size: usize = max_type_count + 2;

pub const Error = block_split_plan.Error || error{
    CountOverflow,
    InvalidBlockSwitchState,
    InvalidBlockSwitchSymbol,
    OutputSizeMismatch,
};

/// The Brotli block-type transition stream and its complete, dense frequency
/// table. `symbols` is allocator-owned and has one entry for every block after
/// the implicit first type-zero block. Only `frequencies[0..alphabet_size]`
/// belongs to the active block-type alphabet.
pub const Model = struct {
    symbols: []u16,
    frequencies: [max_alphabet_size]u32,
    alphabet_size: u16,

    pub fn deinit(self: Model, allocator: std.mem.Allocator) void {
        allocator.free(self.symbols);
    }
};

/// Build the general Brotli block-type transition model. The state starts at
/// `(previous, current) = (1, 0)`, and the first block is implicit. Subsequent
/// block types use symbol zero for `previous`, symbol one for the successor of
/// `current` modulo the declared type count, and `type + 2` otherwise.
pub fn buildAlloc(
    allocator: std.mem.Allocator,
    plan: *const block_split_plan.Plan,
) (std.mem.Allocator.Error || Error)!Model {
    try validateCompletePlan(plan);

    const transition_count = plan.types.len - 1;
    const symbols = try allocator.alloc(u16, transition_count);
    errdefer allocator.free(symbols);

    const alphabet_size: u16 = plan.type_count + 2;
    var frequencies: [max_alphabet_size]u32 = @splat(0);
    var previous: u16 = 1;
    var current: u16 = 0;
    for (plan.types[1..], symbols) |next_byte, *symbol_out| {
        const next: u16 = next_byte;
        const symbol = try encodeTransition(previous, current, next, plan.type_count);
        if (symbol >= alphabet_size or symbol >= max_alphabet_size)
            return error.InvalidBlockSwitchSymbol;

        const symbol_index: usize = symbol;
        frequencies[symbol_index] = std.math.add(u32, frequencies[symbol_index], 1) catch
            return error.CountOverflow;
        symbol_out.* = symbol;
        previous = current;
        current = next;
    }

    return .{
        .symbols = symbols,
        .frequencies = frequencies,
        .alphabet_size = alphabet_size,
    };
}

/// Decode one symbol without mutating state. This is deliberately independent
/// of the encoder so tests and future callers can check a produced transition
/// stream against the Brotli state-machine rules.
pub fn decodeTransition(
    previous: u16,
    current: u16,
    type_count: u16,
    symbol: u16,
) Error!u16 {
    try validateTypeCount(type_count);
    if (current >= type_count) return error.InvalidBlockSwitchState;

    const alphabet_size = type_count + 2;
    if (symbol >= alphabet_size) return error.InvalidBlockSwitchSymbol;

    const next = switch (symbol) {
        0 => previous,
        1 => if (current + 1 == type_count) 0 else current + 1,
        else => symbol - 2,
    };
    if (next >= type_count or next == current)
        return error.InvalidBlockSwitchSymbol;
    return next;
}

/// Apply a complete transition stream into caller-owned block-type storage.
/// The output includes the implicit first type zero, so it must contain exactly
/// one more entry than `symbols`.
pub fn applyTransitions(
    type_count: u16,
    symbols: []const u16,
    block_types: []u8,
) Error!void {
    try validateTypeCount(type_count);
    const expected_len = std.math.add(usize, symbols.len, 1) catch
        return error.IntegerOverflow;
    if (block_types.len != expected_len) return error.OutputSizeMismatch;

    block_types[0] = 0;
    var previous: u16 = 1;
    var current: u16 = 0;
    for (symbols, block_types[1..]) |symbol, *block_type| {
        const next = try decodeTransition(previous, current, type_count, symbol);
        block_type.* = @intCast(next);
        previous = current;
        current = next;
    }
}

fn validateCompletePlan(plan: *const block_split_plan.Plan) block_split_plan.Error!void {
    var symbol_count: usize = 0;
    for (plan.lengths) |length| {
        const converted = std.math.cast(usize, length) orelse
            return error.IntegerOverflow;
        symbol_count = std.math.add(usize, symbol_count, converted) catch
            return error.IntegerOverflow;
    }
    try plan.validate(symbol_count);
}

fn validateTypeCount(type_count: u16) Error!void {
    if (type_count == 0 or type_count > max_type_count)
        return error.InvalidBlockSwitchState;
}

fn encodeTransition(
    previous: u16,
    current: u16,
    next: u16,
    type_count: u16,
) Error!u16 {
    try validateTypeCount(type_count);
    if (previous >= type_count or current >= type_count or next >= type_count or next == current)
        return error.InvalidBlockSwitchState;

    if (next == previous) return 0;
    const successor: u16 = if (current + 1 == type_count) 0 else current + 1;
    if (next == successor) return 1;
    const symbol = next + 2;
    if (symbol >= type_count + 2 or symbol >= max_alphabet_size)
        return error.InvalidBlockSwitchSymbol;
    return symbol;
}

test "block switch model handles A-B-A-C-A precedence" {
    var lengths = [_]u32{ 2, 3, 5, 7, 11 };
    var types = [_]u8{ 0, 1, 0, 2, 0 };
    const plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 3,
        .estimated_bits = 0,
    };

    const model = try buildAlloc(std.testing.allocator, &plan);
    defer model.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u16, &.{ 0, 0, 4, 0 }, model.symbols);
    try std.testing.expectEqual(@as(u16, 5), model.alphabet_size);
    try std.testing.expectEqual(@as(u32, 3), model.frequencies[0]);
    try std.testing.expectEqual(@as(u32, 1), model.frequencies[4]);

    var decoded: [types.len]u8 = undefined;
    try applyTransitions(plan.type_count, model.symbols, &decoded);
    try std.testing.expectEqualSlices(u8, &types, &decoded);
}

test "block switch model applies successor wrap and direct symbols" {
    var wrap_lengths = [_]u32{ 1, 1, 1, 1 };
    var wrap_types = [_]u8{ 0, 1, 2, 0 };
    const wrap_plan: block_split_plan.Plan = .{
        .lengths = &wrap_lengths,
        .types = &wrap_types,
        .type_count = 3,
        .estimated_bits = 0,
    };
    const wrap_model = try buildAlloc(std.testing.allocator, &wrap_plan);
    defer wrap_model.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u16, &.{ 0, 1, 1 }, wrap_model.symbols);

    var direct_lengths = [_]u32{ 4, 6, 2 };
    var direct_types = [_]u8{ 0, 2, 1 };
    const direct_plan: block_split_plan.Plan = .{
        .lengths = &direct_lengths,
        .types = &direct_types,
        .type_count = 3,
        .estimated_bits = 0,
    };
    const direct_model = try buildAlloc(std.testing.allocator, &direct_plan);
    defer direct_model.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u16, &.{ 4, 3 }, direct_model.symbols);

    var decoded: [direct_types.len]u8 = undefined;
    try applyTransitions(direct_plan.type_count, direct_model.symbols, &decoded);
    try std.testing.expectEqualSlices(u8, &direct_types, &decoded);
}

test "block switch model supports 256 types and symbol 257" {
    var lengths: [256]u32 = @splat(1);
    var types: [256]u8 = undefined;
    types[0] = 0;
    types[1] = 255;
    for (types[2..], 1..) |*block_type, value| block_type.* = @intCast(value);
    const plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 256,
        .estimated_bits = 0,
    };

    const model = try buildAlloc(std.testing.allocator, &plan);
    defer model.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 258), model.alphabet_size);
    try std.testing.expectEqual(@as(usize, 255), model.symbols.len);
    try std.testing.expectEqual(@as(u16, 257), model.symbols[0]);
    try std.testing.expectEqual(@as(u32, 1), model.frequencies[257]);

    var decoded: [types.len]u8 = undefined;
    try applyTransitions(plan.type_count, model.symbols, &decoded);
    try std.testing.expectEqualSlices(u8, &types, &decoded);
}

test "single block has no transitions" {
    var lengths = [_]u32{13};
    var types = [_]u8{0};
    const plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 1,
        .estimated_bits = 9,
    };

    const model = try buildAlloc(std.testing.allocator, &plan);
    defer model.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), model.symbols.len);
    try std.testing.expectEqual(@as(u16, 3), model.alphabet_size);
    try std.testing.expectEqual([_]u32{0} ** max_alphabet_size, model.frequencies);

    var decoded: [1]u8 = undefined;
    try applyTransitions(plan.type_count, model.symbols, &decoded);
    try std.testing.expectEqualSlices(u8, &types, &decoded);
}

test "block switch model rejects invalid plans and transition inputs" {
    var lengths = [_]u32{ 1, 1 };
    var missing_type = [_]u8{ 0, 1 };
    const invalid_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &missing_type,
        .type_count = 3,
        .estimated_bits = 0,
    };
    try std.testing.expectError(
        error.InvalidBlockPlan,
        buildAlloc(std.testing.allocator, &invalid_plan),
    );

    try std.testing.expectError(
        error.InvalidBlockSwitchSymbol,
        decodeTransition(1, 0, 3, 5),
    );
    try std.testing.expectError(
        error.InvalidBlockSwitchSymbol,
        decodeTransition(1, 0, 3, 2),
    );
    try std.testing.expectError(
        error.InvalidBlockSwitchState,
        decodeTransition(1, 3, 3, 0),
    );
    var too_short: [1]u8 = undefined;
    try std.testing.expectError(
        error.OutputSizeMismatch,
        applyTransitions(3, &.{0}, &too_short),
    );
}

test "block switch model reports allocation failure" {
    var lengths = [_]u32{ 1, 1 };
    var types = [_]u8{ 0, 1 };
    const plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 2,
        .estimated_bits = 0,
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, buildAlloc(failing.allocator(), &plan));
}
