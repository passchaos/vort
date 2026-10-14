const std = @import("std");
const block_split_plan = @import("block_split_plan.zig");
const histogram_model = @import("histogram_model.zig");

pub const max_type_count: usize = 50;

/// Build a deterministic, format-independent temporal entropy splitter.
///
/// The returned plan owns its `lengths` and `types` slices. Symbol-to-type
/// assignments are used only as scratch storage and are not retained in the
/// public result. Repeated type values in the plan make non-cyclic patterns
/// such as A-B-A-C-A directly representable.
pub fn Splitter(comptime Symbol: type, comptime alphabet_size: usize) type {
    if (alphabet_size == 0) @compileError("an adaptive splitter needs a non-empty alphabet");
    switch (@typeInfo(Symbol)) {
        .int, .@"enum" => {},
        else => @compileError("adaptive splitter symbols must be integers or enums"),
    }

    return struct {
        const Self = @This();
        const Histogram = histogram_model.Histogram(alphabet_size);
        const unassigned_type = std.math.maxInt(u8);

        pub const Options = struct {
            /// Maximum number of temporal entropy types considered. Empty
            /// types are removed after every Viterbi pass. One is valid and
            /// always produces no split.
            type_count: u8 = 5,
            /// Number of cost/assignment/rebuild passes.
            iterations: u8 = 3,
            /// Cost paid whenever adjacent symbols use different types.
            /// Costs use the same Q8 units as `histogram_model`.
            switch_cost_q8: u32 = 13 * histogram_model.cost_scale +
                histogram_model.cost_scale / 2,
            /// Inputs below this policy threshold are treated as stationary.
            min_symbols: usize = 2,
            /// Bounds both work and the u32 lengths used by `Plan`.
            max_symbols: usize = std.math.maxInt(u32),
            /// Upper bound for temporary allocations made by this splitter.
            /// The allocator-owned output plan is not charged to this budget.
            scratch_budget_bytes: usize = std.math.maxInt(usize),
        };

        pub const Error = error{
            InvalidOptions,
            InvalidSymbol,
            InputTooLarge,
            ScratchBudgetExceeded,
        };

        /// Returns null when the input is too small, only one type survives,
        /// or the multi-type model does not beat the stationary model.
        pub fn splitAlloc(
            allocator: std.mem.Allocator,
            symbols: []const Symbol,
            options: Options,
        ) (std.mem.Allocator.Error || block_split_plan.Error || Error)!?block_split_plan.Plan {
            if (options.type_count == 0 or options.type_count > max_type_count or
                options.iterations == 0 or options.min_symbols > options.max_symbols)
            {
                return error.InvalidOptions;
            }
            if (symbols.len > options.max_symbols or symbols.len > std.math.maxInt(u32))
                return error.InputTooLarge;

            // Validate before allocating so malformed input has a stable error
            // independent of allocator state.
            for (symbols) |symbol| {
                const symbol_index = symbolIndex(symbol) orelse return error.InvalidSymbol;
                if (symbol_index >= alphabet_size) return error.InvalidSymbol;
            }
            if (symbols.len < options.min_symbols or symbols.len < 2 or options.type_count == 1)
                return null;

            const initial_type_count = @min(@as(usize, options.type_count), symbols.len);
            const backpointer_count = std.math.mul(
                usize,
                symbols.len,
                initial_type_count,
            ) catch return error.InputTooLarge;
            const cost_count = std.math.mul(
                usize,
                initial_type_count,
                alphabet_size,
            ) catch return error.InputTooLarge;
            const scratch_bytes = scratchBytes(
                symbols.len,
                initial_type_count,
                backpointer_count,
                cost_count,
            ) catch return error.InputTooLarge;
            if (scratch_bytes > options.scratch_budget_bytes)
                return error.ScratchBudgetExceeded;

            const histograms = try allocator.alloc(Histogram, initial_type_count);
            defer allocator.free(histograms);
            const symbol_costs_q8 = try allocator.alloc(u16, cost_count);
            defer allocator.free(symbol_costs_q8);
            const backpointers = try allocator.alloc(u8, backpointer_count);
            defer allocator.free(backpointers);
            const assignment = try allocator.alloc(u8, symbols.len);
            defer allocator.free(assignment);
            const previous_costs = try allocator.alloc(u64, initial_type_count);
            defer allocator.free(previous_costs);
            const next_costs = try allocator.alloc(u64, initial_type_count);
            defer allocator.free(next_costs);
            const type_remap = try allocator.alloc(u8, initial_type_count);
            defer allocator.free(type_remap);

            for (histograms) |*histogram| histogram.* = Histogram.init();
            var stationary_histogram = Histogram.init();
            for (symbols, 0..) |symbol, symbol_position| {
                const symbol_index = symbolIndex(symbol).?;
                // Equal-width temporal seeds avoid random state and make the
                // first pass bit-for-bit reproducible.
                const seed_type = symbol_position * initial_type_count / symbols.len;
                addKnownSymbol(&histograms[seed_type], symbol_index);
                addKnownSymbol(&stationary_histogram, symbol_index);
            }

            var active_type_count = initial_type_count;
            for (0..options.iterations) |_| {
                fillSymbolCosts(histograms[0..active_type_count], symbol_costs_q8);
                _ = viterbiAssign(
                    symbols,
                    active_type_count,
                    initial_type_count,
                    symbol_costs_q8,
                    options.switch_cost_q8,
                    backpointers,
                    assignment,
                    previous_costs,
                    next_costs,
                );
                active_type_count = rebuildHistograms(
                    symbols,
                    assignment,
                    histograms,
                    active_type_count,
                    type_remap,
                );
                if (active_type_count == 1) return null;
            }

            const stationary_cost_q8 = stationary_histogram.populationCostQ8();
            const split_cost_q8 = assignmentCostQ8(
                histograms[0..active_type_count],
                assignment,
                options.switch_cost_q8,
            );
            if (split_cost_q8 >= stationary_cost_q8) return null;

            return try planFromAssignment(
                allocator,
                assignment,
                active_type_count,
                q8BitsCeil(split_cost_q8),
            );
        }

        fn symbolIndex(symbol: Symbol) ?usize {
            return switch (@typeInfo(Symbol)) {
                .int => std.math.cast(usize, symbol),
                .@"enum" => std.math.cast(usize, @intFromEnum(symbol)),
                else => unreachable,
            };
        }

        fn addKnownSymbol(histogram: *Histogram, symbol: usize) void {
            // `splitAlloc` caps the total at maxInt(u32), so neither field can
            // overflow while building histograms from one input slice.
            histogram.counts[symbol] += 1;
            histogram.total += 1;
        }

        fn fillSymbolCosts(histograms: []const Histogram, costs: []u16) void {
            for (histograms, 0..) |*histogram, type_index| {
                const model = histogram.costModel();
                const start = type_index * alphabet_size;
                @memcpy(costs[start..][0..alphabet_size], &model.symbol_costs_q8);
            }
        }

        /// Finds the least-cost assignment in O(symbol_count * type_count).
        /// Ties favor staying in the current type, then the lowest type index.
        fn viterbiAssign(
            symbols: []const Symbol,
            type_count: usize,
            backpointer_stride: usize,
            costs_q8: []const u16,
            switch_cost_q8: u32,
            backpointers: []u8,
            assignment: []u8,
            previous: []u64,
            next: []u64,
        ) u64 {
            std.debug.assert(symbols.len != 0);
            std.debug.assert(type_count != 0 and type_count <= max_type_count);
            std.debug.assert(costs_q8.len >= type_count * alphabet_size);
            std.debug.assert(backpointers.len >= symbols.len * backpointer_stride);
            std.debug.assert(assignment.len >= symbols.len);
            std.debug.assert(previous.len >= type_count and next.len >= type_count);

            const first_symbol = symbolIndex(symbols[0]).?;
            for (previous[0..type_count], 0..) |*cost, type_index| {
                cost.* = costs_q8[type_index * alphabet_size + first_symbol];
            }

            for (symbols[1..], 1..) |symbol, symbol_position| {
                const minima = twoLowest(previous[0..type_count]);
                const symbol_index = symbolIndex(symbol).?;
                for (next[0..type_count], 0..) |*next_cost, type_index| {
                    const alternative = if (minima.first_type != type_index)
                        minima.first_cost
                    else
                        minima.second_cost;
                    const changed_cost = saturatingAdd(alternative, switch_cost_q8);
                    const stayed_cost = previous[type_index];
                    const predecessor = if (changed_cost < stayed_cost)
                        (if (minima.first_type != type_index)
                            minima.first_type
                        else
                            minima.second_type)
                    else
                        type_index;
                    backpointers[symbol_position * backpointer_stride + type_index] =
                        @intCast(predecessor);
                    next_cost.* = saturatingAdd(
                        @min(stayed_cost, changed_cost),
                        costs_q8[type_index * alphabet_size + symbol_index],
                    );
                }
                @memcpy(previous[0..type_count], next[0..type_count]);
            }

            var final_type: usize = 0;
            for (1..type_count) |type_index| {
                if (previous[type_index] < previous[final_type]) final_type = type_index;
            }
            const result_cost = previous[final_type];
            assignment[symbols.len - 1] = @intCast(final_type);
            var symbol_position = symbols.len - 1;
            while (symbol_position != 0) {
                final_type = backpointers[symbol_position * backpointer_stride + final_type];
                symbol_position -= 1;
                assignment[symbol_position] = @intCast(final_type);
            }
            return result_cost;
        }

        const TwoLowest = struct {
            first_cost: u64,
            first_type: usize,
            second_cost: u64,
            second_type: usize,
        };

        fn twoLowest(costs: []const u64) TwoLowest {
            std.debug.assert(costs.len >= 2);
            var result: TwoLowest = .{
                .first_cost = std.math.maxInt(u64),
                .first_type = 0,
                .second_cost = std.math.maxInt(u64),
                .second_type = 0,
            };
            for (costs, 0..) |cost, type_index| {
                if (cost < result.first_cost or
                    (cost == result.first_cost and type_index < result.first_type))
                {
                    result.second_cost = result.first_cost;
                    result.second_type = result.first_type;
                    result.first_cost = cost;
                    result.first_type = type_index;
                } else if (cost < result.second_cost or
                    (cost == result.second_cost and type_index < result.second_type))
                {
                    result.second_cost = cost;
                    result.second_type = type_index;
                }
            }
            return result;
        }

        /// Rebuilds models and renumbers types by first temporal appearance.
        /// Consequently all remaining types are dense and type zero owns the
        /// first output block, matching `block_split_plan.Plan` invariants.
        fn rebuildHistograms(
            symbols: []const Symbol,
            assignment: []u8,
            histograms: []Histogram,
            old_type_count: usize,
            remap: []u8,
        ) usize {
            @memset(remap[0..old_type_count], unassigned_type);
            var new_type_count: usize = 0;
            for (assignment) |*assigned_type| {
                const old_type = assigned_type.*;
                if (remap[old_type] == unassigned_type) {
                    remap[old_type] = @intCast(new_type_count);
                    new_type_count += 1;
                }
                assigned_type.* = remap[old_type];
            }

            for (histograms) |*histogram| histogram.clear();
            for (symbols, assignment) |symbol, assigned_type| {
                addKnownSymbol(&histograms[assigned_type], symbolIndex(symbol).?);
            }
            return new_type_count;
        }

        fn assignmentCostQ8(
            histograms: []const Histogram,
            assignment: []const u8,
            switch_cost_q8: u32,
        ) u64 {
            var total: u64 = 0;
            for (histograms) |*histogram|
                total = saturatingAdd(total, histogram.populationCostQ8());
            for (assignment[1..], assignment[0 .. assignment.len - 1]) |current, previous| {
                if (current != previous)
                    total = saturatingAdd(total, switch_cost_q8);
            }
            return total;
        }

        fn planFromAssignment(
            allocator: std.mem.Allocator,
            assignment: []const u8,
            type_count: usize,
            estimated_bits: u64,
        ) (std.mem.Allocator.Error || block_split_plan.Error)!block_split_plan.Plan {
            std.debug.assert(assignment.len != 0);
            var block_count: usize = 1;
            for (assignment[1..], assignment[0 .. assignment.len - 1]) |current, previous| {
                block_count += @intFromBool(current != previous);
            }

            const lengths = try allocator.alloc(u32, block_count);
            errdefer allocator.free(lengths);
            const types = try allocator.alloc(u8, block_count);
            errdefer allocator.free(types);

            var block_index: usize = 0;
            var block_start: usize = 0;
            for (1..assignment.len + 1) |symbol_position| {
                if (symbol_position != assignment.len and
                    assignment[symbol_position] == assignment[block_start])
                {
                    continue;
                }
                lengths[block_index] = @intCast(symbol_position - block_start);
                types[block_index] = assignment[block_start];
                block_index += 1;
                block_start = symbol_position;
            }

            const plan: block_split_plan.Plan = .{
                .lengths = lengths,
                .types = types,
                .type_count = @intCast(type_count),
                .estimated_bits = estimated_bits,
            };
            try plan.validate(assignment.len);
            return plan;
        }

        fn scratchBytes(
            symbol_count: usize,
            type_count: usize,
            backpointer_count: usize,
            cost_count: usize,
        ) error{Overflow}!usize {
            var total: usize = 0;
            total = try addAllocationSize(total, type_count, @sizeOf(Histogram));
            total = try addAllocationSize(total, cost_count, @sizeOf(u16));
            total = try addAllocationSize(total, backpointer_count, @sizeOf(u8));
            total = try addAllocationSize(total, symbol_count, @sizeOf(u8));
            total = try addAllocationSize(total, type_count, @sizeOf(u64));
            total = try addAllocationSize(total, type_count, @sizeOf(u64));
            total = try addAllocationSize(total, type_count, @sizeOf(u8));
            return total;
        }

        fn addAllocationSize(total: usize, count: usize, element_size: usize) error{Overflow}!usize {
            const bytes = std.math.mul(usize, count, element_size) catch return error.Overflow;
            return std.math.add(usize, total, bytes) catch return error.Overflow;
        }

        fn saturatingAdd(left: u64, right: anytype) u64 {
            return std.math.add(u64, left, @as(u64, right)) catch std.math.maxInt(u64);
        }

        fn q8BitsCeil(cost_q8: u64) u64 {
            return cost_q8 / histogram_model.cost_scale +
                @intFromBool(cost_q8 % histogram_model.cost_scale != 0);
        }
    };
}

fn bruteForceCost(
    comptime alphabet_size: usize,
    symbols: []const u8,
    type_count: usize,
    costs_q8: []const u16,
    switch_cost_q8: u32,
) u64 {
    var path_count: usize = 1;
    for (symbols) |_| path_count *= type_count;
    var best: u64 = std.math.maxInt(u64);
    for (0..path_count) |ordinal| {
        var encoded_path = ordinal;
        var previous_type: usize = 0;
        var total: u64 = 0;
        for (symbols, 0..) |symbol, symbol_position| {
            const type_index = encoded_path % type_count;
            encoded_path /= type_count;
            total += costs_q8[type_index * alphabet_size + symbol];
            if (symbol_position != 0 and type_index != previous_type)
                total += switch_cost_q8;
            previous_type = type_index;
        }
        best = @min(best, total);
    }
    return best;
}

test "adaptive splitter Viterbi cost matches a small exhaustive oracle" {
    const S = Splitter(u8, 4);
    const all_symbols = [_]u8{ 3, 1, 0, 2, 1 };
    const all_costs = [_]u16{
        71, 13, 55, 21,
        19, 61, 7,  47,
        43, 17, 67, 11,
    };

    for (2..4) |type_count| {
        for (1..all_symbols.len + 1) |symbol_count| {
            var backpointers: [all_symbols.len * 3]u8 = undefined;
            var assignment: [all_symbols.len]u8 = undefined;
            var previous: [3]u64 = undefined;
            var next: [3]u64 = undefined;
            const actual = S.viterbiAssign(
                all_symbols[0..symbol_count],
                type_count,
                3,
                all_costs[0 .. type_count * 4],
                29,
                &backpointers,
                &assignment,
                &previous,
                &next,
            );
            const expected = bruteForceCost(
                4,
                all_symbols[0..symbol_count],
                type_count,
                all_costs[0 .. type_count * 4],
                29,
            );
            try std.testing.expectEqual(expected, actual);
        }
    }
}

fn fillOffGridInput(input: []u8, split: usize) void {
    for (input[0..split], 0..) |*symbol, index| symbol.* = @intCast(index % 4);
    for (input[split..], 0..) |*symbol, index| symbol.* = @intCast(4 + index % 4);
}

test "adaptive splitter is deterministic and finds an off-grid boundary" {
    const S = Splitter(u8, 8);
    var symbols: [120]u8 = undefined;
    fillOffGridInput(&symbols, 47);
    const options: S.Options = .{
        .type_count = 2,
        .switch_cost_q8 = 2 * histogram_model.cost_scale,
    };

    const first = (try S.splitAlloc(std.testing.allocator, &symbols, options)) orelse
        return error.TestUnexpectedResult;
    defer first.deinit(std.testing.allocator);
    const second = (try S.splitAlloc(std.testing.allocator, &symbols, options)) orelse
        return error.TestUnexpectedResult;
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ 47, 73 }, first.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, first.types);
    try std.testing.expectEqualSlices(u32, first.lengths, second.lengths);
    try std.testing.expectEqualSlices(u8, first.types, second.types);
    try std.testing.expectEqual(first.type_count, second.type_count);
    try std.testing.expectEqual(first.estimated_bits, second.estimated_bits);
}

test "adaptive splitter preserves a non-cyclic reused type" {
    const S = Splitter(u8, 3);
    var symbols: [160]u8 = undefined;
    @memset(symbols[0..32], 0);
    @memset(symbols[32..64], 1);
    @memset(symbols[64..96], 0);
    @memset(symbols[96..128], 2);
    @memset(symbols[128..160], 0);

    const plan = (try S.splitAlloc(std.testing.allocator, &symbols, .{
        .type_count = 5,
        .switch_cost_q8 = histogram_model.cost_scale,
    })) orelse return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ 32, 32, 32, 32, 32 }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 2, 0 }, plan.types);
    try std.testing.expectEqual(@as(u16, 3), plan.type_count);
}

test "adaptive splitter rejects invalid symbols and stationary input" {
    const S = Splitter(u8, 4);
    try std.testing.expectError(
        error.InvalidSymbol,
        S.splitAlloc(std.testing.allocator, &.{ 0, 4 }, .{}),
    );
    try std.testing.expectError(
        error.InvalidSymbol,
        S.splitAlloc(std.testing.allocator, &.{4}, .{}),
    );

    const stationary = [_]u8{3} ** 96;
    try std.testing.expect((try S.splitAlloc(std.testing.allocator, &stationary, .{})) == null);

    try std.testing.expectError(
        error.InvalidOptions,
        S.splitAlloc(std.testing.allocator, &stationary, .{ .type_count = 51 }),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        S.splitAlloc(std.testing.allocator, &stationary, .{ .iterations = 0 }),
    );
}

test "adaptive splitter enforces its scratch budget and allocator failures" {
    const S = Splitter(u8, 8);
    var symbols: [120]u8 = undefined;
    fillOffGridInput(&symbols, 47);

    try std.testing.expectError(
        error.ScratchBudgetExceeded,
        S.splitAlloc(std.testing.allocator, &symbols, .{
            .type_count = 2,
            .scratch_budget_bytes = 1,
        }),
    );

    // Seven scratch allocations and two final-plan allocations all unwind
    // cleanly when their individual allocation is forced to fail.
    for (0..9) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        try std.testing.expectError(
            error.OutOfMemory,
            S.splitAlloc(failing.allocator(), &symbols, .{
                .type_count = 2,
                .switch_cost_q8 = 2 * histogram_model.cost_scale,
            }),
        );
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
