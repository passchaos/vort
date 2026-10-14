const std = @import("std");
const block_split_plan = @import("block_split_plan.zig");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");
const dynamic_context_map = @import("dynamic_context_map.zig");
const histogram_model = @import("histogram_model.zig");
const literal_context = @import("literal_context.zig");
const literal_entropy_plan = @import("literal_entropy_plan.zig");

const Histogram = histogram_model.Histogram(256);
const contexts_per_type = literal_entropy_plan.contexts_per_type;

pub const Options = struct {
    max_block_types: u8 = 8,
    max_tree_count: u16 = 64,
    iterations: u8 = 3,
    scratch_budget_bytes: usize = 4 * 1024 * 1024,
};

pub const Error = error{
    InvalidOptions,
    InvalidInput,
    ScratchBudgetExceeded,
    IntegerOverflow,
    SymbolOutOfRange,
    CountOverflow,
    TotalOverflow,
    InvalidHuffmanCode,
};

/// Jointly select one RFC literal context mode per temporal block type, then
/// cluster every populated `(block_type, context)` histogram into one global
/// tree set. The returned plan owns all of its slices; exact complete-wire
/// arbitration remains the caller's final authority.
pub fn chooseAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    commands: []const command_plan.Command,
    block_plan: block_split_plan.Plan,
    options: Options,
) (std.mem.Allocator.Error || block_split_plan.Error || literal_entropy_plan.Error || Error)!?literal_entropy_plan.Plan {
    if (options.max_block_types == 0 or options.max_tree_count < 2 or
        options.max_tree_count > literal_entropy_plan.max_tree_count or
        options.iterations == 0)
        return error.InvalidOptions;
    const literal_count = try countLiterals(input, commands);
    try block_plan.validate(literal_count);
    const type_count: usize = block_plan.type_count;
    if (type_count > options.max_block_types) return null;
    const context_count = std.math.mul(usize, type_count, contexts_per_type) catch
        return error.IntegerOverflow;
    const histogram_bytes = std.math.mul(usize, context_count, @sizeOf(Histogram)) catch
        return error.IntegerOverflow;
    const max_trees = @min(@as(usize, options.max_tree_count), context_count);
    const tree_bytes = std.math.mul(usize, max_trees, @sizeOf(Histogram)) catch
        return error.IntegerOverflow;
    const cost_bytes = std.math.mul(usize, max_trees, @sizeOf([256]u16)) catch
        return error.IntegerOverflow;
    const scratch_bytes = std.math.add(
        usize,
        histogram_bytes,
        tree_bytes + cost_bytes + 3 * context_count + 2 * type_count,
    ) catch return error.IntegerOverflow;
    if (scratch_bytes > options.scratch_budget_bytes) return error.ScratchBudgetExceeded;

    const contexts = try allocator.alloc(Histogram, context_count);
    defer allocator.free(contexts);
    const populated = try allocator.alloc(u16, context_count);
    defer allocator.free(populated);
    const assignment = try allocator.alloc(u8, context_count);
    defer allocator.free(assignment);
    const candidate_assignment = try allocator.alloc(u8, context_count);
    defer allocator.free(candidate_assignment);
    const best_assignment = try allocator.alloc(u8, context_count);
    defer allocator.free(best_assignment);
    const context_modes = try allocator.alloc(u2, type_count);
    defer allocator.free(context_modes);
    const best_mode_costs = try allocator.alloc(u64, type_count);
    defer allocator.free(best_mode_costs);
    const trees = try allocator.alloc(Histogram, max_trees);
    defer allocator.free(trees);
    const symbol_costs = try allocator.alloc([256]u16, max_trees);
    defer allocator.free(symbol_costs);

    @memset(context_modes, 0);
    @memset(best_mode_costs, std.math.maxInt(u64));
    for (0..4) |mode_value| {
        clearHistograms(contexts);
        try collectHistograms(input, commands, block_plan, null, @intCast(mode_value), contexts);
        for (0..type_count) |block_type| {
            var cost: u64 = 0;
            for (contexts[block_type * contexts_per_type ..][0..contexts_per_type]) |*histogram|
                cost +|= histogram.populationCostQ8();
            if (cost < best_mode_costs[block_type]) {
                best_mode_costs[block_type] = cost;
                context_modes[block_type] = @intCast(mode_value);
            }
        }
    }

    clearHistograms(contexts);
    try collectHistograms(input, commands, block_plan, context_modes, null, contexts);
    var populated_count: usize = 0;
    for (contexts, 0..) |histogram, context_index| {
        if (histogram.total == 0) continue;
        populated[populated_count] = @intCast(context_index);
        populated_count += 1;
    }
    if (populated_count < 2) return null;

    const requested_counts = [_]usize{ 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256 };
    var best_score: u64 = std.math.maxInt(u64);
    var best_tree_count: usize = 0;
    for (requested_counts) |requested| {
        if (requested > max_trees or requested > populated_count) continue;
        for ([_]Seed{ .ordered, .interleaved }) |seed| {
            @memset(candidate_assignment, 0);
            for (populated[0..populated_count], 0..) |context_index, rank| {
                candidate_assignment[context_index] = @intCast(switch (seed) {
                    .ordered => rank * requested / populated_count,
                    .interleaved => rank % requested,
                });
            }
            aggregateTrees(contexts, candidate_assignment, requested, trees);
            for (0..options.iterations) |_| {
                for (trees[0..requested], symbol_costs[0..requested]) |*tree, *costs|
                    costs.* = tree.symbolCostsQ8();
                var changed = false;
                for (populated[0..populated_count]) |context_index| {
                    var best_tree: usize = 0;
                    var best_cost = assignmentCost(&contexts[context_index], &symbol_costs[0]);
                    for (1..requested) |tree| {
                        const cost = assignmentCost(&contexts[context_index], &symbol_costs[tree]);
                        if (cost < best_cost) {
                            best_cost = cost;
                            best_tree = tree;
                        }
                    }
                    if (candidate_assignment[context_index] != best_tree) {
                        candidate_assignment[context_index] = @intCast(best_tree);
                        changed = true;
                    }
                }
                aggregateTrees(contexts, candidate_assignment, requested, trees);
                if (!changed) break;
            }

            var remap: [literal_entropy_plan.max_tree_count]u8 = @splat(0xff);
            var tree_count: usize = 0;
            for (trees[0..requested], 0..) |tree, old_tree| {
                if (tree.total == 0) continue;
                remap[old_tree] = @intCast(tree_count);
                if (tree_count != old_tree) trees[tree_count] = tree;
                tree_count += 1;
            }
            if (tree_count < 2) continue;
            @memset(assignment, 0);
            for (populated[0..populated_count]) |context_index|
                assignment[context_index] = remap[candidate_assignment[context_index]];

            var score: u64 = 2 * type_count;
            for (trees[0..tree_count]) |*tree| score +|= try treeBitCost(allocator, tree);
            const map_plan = try dynamic_context_map.choose(allocator, assignment, tree_count);
            score +|= map_plan.bit_cost;
            map_plan.deinit(allocator);
            if (score < best_score) {
                best_score = score;
                best_tree_count = tree_count;
                @memcpy(best_assignment, assignment);
            }
        }
    }
    if (best_tree_count < 2) return null;
    return try literal_entropy_plan.Plan.initCopy(
        allocator,
        block_plan,
        context_modes,
        best_assignment,
        @intCast(best_tree_count),
        literal_count,
    );
}

const Seed = enum { ordered, interleaved };

fn countLiterals(input: []const u8, commands: []const command_plan.Command) Error!usize {
    var literal_count: usize = 0;
    for (commands) |command| {
        if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start)
            return error.InvalidInput;
        literal_count = std.math.add(usize, literal_count, command.insert_len) catch
            return error.IntegerOverflow;
    }
    return literal_count;
}

fn clearHistograms(histograms: []Histogram) void {
    for (histograms) |*histogram| histogram.* = Histogram.init();
}

fn collectHistograms(
    input: []const u8,
    commands: []const command_plan.Command,
    block_plan: block_split_plan.Plan,
    context_modes: ?[]const u2,
    fixed_mode: ?u2,
    histograms: []Histogram,
) !void {
    var block_index: usize = 0;
    var block_end: usize = block_plan.lengths[0];
    var literal_index: usize = 0;
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |literal, position| {
            while (literal_index >= block_end) {
                block_index += 1;
                if (block_index >= block_plan.blockCount()) return error.InvalidInput;
                block_end = std.math.add(usize, block_end, block_plan.lengths[block_index]) catch
                    return error.IntegerOverflow;
            }
            const block_type: usize = block_plan.types[block_index];
            const mode = fixed_mode orelse context_modes.?[block_type];
            const previous = if (position == 0) 0 else input[position - 1];
            const second_previous = if (position < 2) 0 else input[position - 2];
            const context = literal_context.value(mode, previous, second_previous);
            try histograms[block_type * contexts_per_type + context].add(literal);
            literal_index += 1;
        }
    }
    if (block_index + 1 != block_plan.blockCount() or block_end != literal_index)
        return error.InvalidInput;
}

fn aggregateTrees(contexts: []const Histogram, assignment: []const u8, tree_count: usize, trees: []Histogram) void {
    clearHistograms(trees[0..tree_count]);
    for (contexts, assignment) |*context, tree| {
        if (context.total == 0) continue;
        trees[tree].addHistogram(context) catch unreachable;
    }
}

fn assignmentCost(context: *const Histogram, costs: *const [256]u16) u64 {
    var result: u64 = 0;
    for (context.counts, costs) |frequency, cost|
        result +|= @as(u64, frequency) * cost;
    return result;
}

fn treeBitCost(allocator: std.mem.Allocator, histogram: *const Histogram) !u64 {
    var alphabet: command_plan.PrefixAlphabetFor(256) = undefined;
    try command_plan.alphabetFromFrequenciesInto(256, &alphabet, &histogram.counts);
    const lengths = try alphabet.codeLengths(&histogram.counts);
    var payload_bits: u64 = 0;
    for (histogram.counts, lengths) |frequency, length|
        payload_bits += @as(u64, frequency) * length;
    if (alphabet.len <= 4) {
        return payload_bits + 4 + @as(u64, alphabet.len) * 8 + @intFromBool(alphabet.len == 4);
    }
    var highest: usize = 0;
    for (alphabet.symbols[0..alphabet.len]) |symbol| highest = @max(highest, symbol);
    return payload_bits + try complex_prefix.bitCost(allocator, 256, &lengths, highest + 1);
}

test "joint literal clustering selects multiple global context trees" {
    var payload: [4096]u8 = undefined;
    for (payload[0..2048], 0..) |*byte, index| byte.* = @intCast(index & 15);
    for (payload[2048..], 0..) |*byte, index| byte.* = @intCast(224 + (index & 15));
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = payload.len }};
    const lengths = [_]u32{ 2048, 2048 };
    const types = [_]u8{ 0, 1 };
    const block_plan: block_split_plan.Plan = .{
        .lengths = @constCast(&lengths),
        .types = @constCast(&types),
        .type_count = 2,
        .estimated_bits = 0,
    };
    const plan = (try chooseAlloc(std.testing.allocator, &payload, &commands, block_plan, .{})) orelse
        return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);
    try plan.validate(payload.len);
    try std.testing.expect(plan.tree_count >= 2);
    try std.testing.expectEqual(@as(usize, 128), plan.context_map.len);
}

test "joint literal clustering is deterministic and cleans allocation failures" {
    var payload: [4096]u8 = undefined;
    for (&payload, 0..) |*byte, index| byte.* = @intCast((index * 37) & 255);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = payload.len }};
    const lengths = [_]u32{ 1024, 2048, 1024 };
    const types = [_]u8{ 0, 1, 0 };
    const block_plan: block_split_plan.Plan = .{
        .lengths = @constCast(&lengths),
        .types = @constCast(&types),
        .type_count = 2,
        .estimated_bits = 0,
    };
    const first = (try chooseAlloc(std.testing.allocator, &payload, &commands, block_plan, .{})) orelse
        return error.TestUnexpectedResult;
    defer first.deinit(std.testing.allocator);
    const second = (try chooseAlloc(std.testing.allocator, &payload, &commands, block_plan, .{})) orelse
        return error.TestUnexpectedResult;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u2, first.context_modes, second.context_modes);
    try std.testing.expectEqualSlices(u8, first.context_map, second.context_map);
    try std.testing.expectEqual(first.tree_count, second.tree_count);

    const Test = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8, stream: []const command_plan.Command, plan: block_split_plan.Plan) !void {
            const candidate = try chooseAlloc(allocator, input, stream, plan, .{});
            if (candidate) |owned| owned.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ payload[0..], commands[0..], block_plan },
    );
}
