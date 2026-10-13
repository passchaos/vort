const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const literal_context = @import("literal_context.zig");

const min_literal_count: usize = 128;
const min_payload_savings_bits: u64 = 128;
pub const max_trees: usize = 4;
const cluster_iterations: usize = 4;

/// One bounded multi-tree literal-context proposal. The complete Brotli writer
/// still arbitrates this proposal by exact encoded byte length, so this module
/// only needs to reject clearly unprofitable histogram shapes.
pub const Candidate = struct {
    mode: u2,
    tree_count: u3,
    context_map: [64]u8,
    savings_bits: u64,

    pub fn suffix(mode: u2, cutoff: u6, savings_bits: u64) Candidate {
        std.debug.assert(cutoff != 0 and cutoff < 64);
        var context_map: [64]u8 = undefined;
        for (&context_map, 0..) |*tree, context|
            tree.* = literal_context.suffixTree(context, cutoff);
        return .{
            .mode = mode,
            .tree_count = 2,
            .context_map = context_map,
            .savings_bits = savings_bits,
        };
    }

    pub fn treeFor(self: Candidate, context: usize) u8 {
        return self.context_map[context];
    }

    pub fn eql(a: Candidate, b: Candidate) bool {
        return a.mode == b.mode and a.tree_count == b.tree_count and
            std.mem.eql(u8, &a.context_map, &b.context_map);
    }

    pub fn suffixCutoff(self: Candidate) ?u6 {
        if (self.tree_count != 2) return null;
        var cutoff: usize = 0;
        while (cutoff < self.context_map.len and self.context_map[cutoff] == 0) : (cutoff += 1) {}
        if (cutoff == 0 or cutoff == self.context_map.len) return null;
        for (self.context_map[cutoff..]) |tree| if (tree != 1) return null;
        return @intCast(cutoff);
    }
};

/// Evaluate all four RFC 7932 literal context modes. Each mode gets its best
/// contiguous two-tree partition plus bounded two-, three-, and four-tree
/// clustering with both ordered and interleaved seeds.
/// Keeping the search in a separate noinline routine prevents the 64 KiB
/// context histogram from inflating the already large Brotli wire encoder
/// frame.
pub noinline fn choose(input: []const u8, commands: []const command_plan.Command) ?Candidate {
    return chooseWithClusters(input, commands, true);
}

pub noinline fn chooseSuffix(input: []const u8, commands: []const command_plan.Command) ?Candidate {
    return chooseWithClusters(input, commands, false);
}

fn chooseWithClusters(input: []const u8, commands: []const command_plan.Command, include_clusters: bool) ?Candidate {
    var best: ?Candidate = null;
    for (0..4) |mode_value| {
        const candidate = chooseModeWithClusters(input, commands, @intCast(mode_value), include_clusters) orelse continue;
        if (best == null or candidate.savings_bits > best.?.savings_bits) best = candidate;
    }
    return best;
}

fn chooseMode(input: []const u8, commands: []const command_plan.Command, mode: u2) ?Candidate {
    return chooseModeWithClusters(input, commands, mode, true);
}

fn chooseModeWithClusters(input: []const u8, commands: []const command_plan.Command, mode: u2, include_clusters: bool) ?Candidate {
    var by_context: [64][256]u32 = @splat(@splat(0));
    var total: [256]u32 = @splat(0);
    var literal_count: usize = 0;
    for (commands) |command| {
        const end = std.math.add(usize, command.insert_start, command.insert_len) catch return null;
        if (end > input.len) return null;
        for (input[command.insert_start..end], command.insert_start..) |literal, position| {
            const previous = if (position == 0) 0 else input[position - 1];
            const second_previous = if (position < 2) 0 else input[position - 2];
            const context = literal_context.value(mode, previous, second_previous);
            by_context[context][literal] += 1;
            total[literal] += 1;
            literal_count += 1;
        }
    }
    if (literal_count < min_literal_count) return null;

    const baseline_lengths = huffman.treeCodeLengths(256, &total, 15);
    const baseline_bits = weightedBits(&total, &baseline_lengths);
    var left: [256]u32 = @splat(0);
    var left_count: usize = 0;
    var best: ?Candidate = null;
    var best_cutoff: u6 = 1;
    var best_bits = baseline_bits;
    for (1..64) |cutoff| {
        for (&left, &by_context[cutoff - 1]) |*sum, count| sum.* += count;
        for (by_context[cutoff - 1]) |count| left_count += count;
        if (left_count == 0 or left_count == literal_count) continue;
        var right: [256]u32 = undefined;
        for (&right, &total, &left) |*remaining, all, used| remaining.* = all - used;
        const left_lengths = huffman.treeCodeLengths(256, &left, 15);
        const right_lengths = huffman.treeCodeLengths(256, &right, 15);
        const bits = weightedBits(&left, &left_lengths) + weightedBits(&right, &right_lengths);
        if (bits < best_bits) {
            best_bits = bits;
            best_cutoff = @intCast(cutoff);
        }
    }
    const savings = baseline_bits - best_bits;
    if (savings >= min_payload_savings_bits)
        best = Candidate.suffix(mode, best_cutoff, savings);

    if (!include_clusters) return best;
    for (2..max_trees + 1) |requested_tree_count| {
        for ([_]Seed{ .ordered, .interleaved }) |seed| {
            const clustered = clusterContexts(
                mode,
                &by_context,
                baseline_bits,
                requested_tree_count,
                seed,
            ) orelse continue;
            if (best == null or clustered.savings_bits > best.?.savings_bits or
                (clustered.savings_bits == best.?.savings_bits and clustered.tree_count < best.?.tree_count))
                best = clustered;
        }
    }
    return best;
}

const Seed = enum { ordered, interleaved };

fn clusterContexts(
    mode: u2,
    by_context: *const [64][256]u32,
    baseline_bits: u64,
    requested_tree_count: usize,
    seed: Seed,
) ?Candidate {
    var populated: [64]u8 = undefined;
    var populated_count: usize = 0;
    for (by_context, 0..) |histogram, context| {
        if (histogramCount(&histogram) == 0) continue;
        populated[populated_count] = @intCast(context);
        populated_count += 1;
    }
    if (populated_count < requested_tree_count) return null;

    var context_map: [64]u8 = @splat(0);
    for (populated[0..populated_count], 0..) |context, rank| {
        context_map[context] = @intCast(switch (seed) {
            .ordered => rank * requested_tree_count / populated_count,
            .interleaved => rank % requested_tree_count,
        });
    }

    for (0..cluster_iterations) |_| {
        var tree_histograms: [max_trees][256]u32 = @splat(@splat(0));
        var tree_totals: [max_trees]u32 = @splat(0);
        aggregateTrees(by_context, &context_map, requested_tree_count, &tree_histograms, &tree_totals);
        var changed = false;
        for (populated[0..populated_count]) |context| {
            var best_tree: usize = 0;
            var best_cost = assignmentCost(&by_context[context], &tree_histograms[0], tree_totals[0]);
            for (1..requested_tree_count) |tree| {
                const cost = assignmentCost(&by_context[context], &tree_histograms[tree], tree_totals[tree]);
                if (cost < best_cost) {
                    best_cost = cost;
                    best_tree = tree;
                }
            }
            if (context_map[context] != best_tree) {
                context_map[context] = @intCast(best_tree);
                changed = true;
            }
        }
        if (!changed) break;
    }

    var tree_histograms: [max_trees][256]u32 = @splat(@splat(0));
    var tree_totals: [max_trees]u32 = @splat(0);
    aggregateTrees(by_context, &context_map, requested_tree_count, &tree_histograms, &tree_totals);
    var remap: [max_trees]u8 = @splat(0xff);
    var tree_count: usize = 0;
    for (tree_totals[0..requested_tree_count], 0..) |total, tree| {
        if (total == 0) continue;
        remap[tree] = @intCast(tree_count);
        if (tree_count != tree) {
            tree_histograms[tree_count] = tree_histograms[tree];
            tree_totals[tree_count] = total;
        }
        tree_count += 1;
    }
    if (tree_count < 2) return null;
    for (&context_map, by_context) |*tree, histogram| {
        if (histogramCount(&histogram) == 0) {
            tree.* = 0;
        } else {
            tree.* = remap[tree.*];
        }
    }

    var payload_bits: u64 = 0;
    for (tree_histograms[0..tree_count]) |*histogram| {
        const lengths = huffman.treeCodeLengths(256, histogram, 15);
        payload_bits += weightedBits(histogram, &lengths);
    }
    const savings = baseline_bits -| payload_bits;
    const required_savings = min_payload_savings_bits * (tree_count - 1);
    if (savings < required_savings) return null;
    return .{
        .mode = mode,
        .tree_count = @intCast(tree_count),
        .context_map = context_map,
        .savings_bits = savings,
    };
}

fn aggregateTrees(
    by_context: *const [64][256]u32,
    context_map: *const [64]u8,
    tree_count: usize,
    tree_histograms: *[max_trees][256]u32,
    tree_totals: *[max_trees]u32,
) void {
    for (by_context, context_map) |histogram, tree_u8| {
        const tree: usize = tree_u8;
        std.debug.assert(tree < tree_count);
        for (&tree_histograms[tree], histogram) |*sum, count| sum.* += count;
        tree_totals[tree] += histogramCount(&histogram);
    }
}

fn assignmentCost(context: *const [256]u32, tree: *const [256]u32, tree_total: u32) u64 {
    const model_log = fastLog2Q8(tree_total + 256);
    var cost: u64 = 0;
    for (context, tree) |count, modeled| {
        if (count == 0) continue;
        cost += @as(u64, count) * (model_log - fastLog2Q8(modeled + 1));
    }
    return cost;
}

fn histogramCount(histogram: *const [256]u32) u32 {
    var count: u32 = 0;
    for (histogram) |frequency| count += frequency;
    return count;
}

fn fastLog2Q8(value: u32) u64 {
    std.debug.assert(value != 0);
    const floor = std.math.log2_int(u32, value);
    const base = @as(u64, 1) << @intCast(floor);
    const fraction = ((@as(u64, value) - base) << 8) / base;
    return @as(u64, floor) * 256 + fraction;
}

fn weightedBits(frequencies: *const [256]u32, lengths: *const [256]u4) u64 {
    var bits: u64 = 0;
    for (frequencies, lengths) |frequency, length| bits += @as(u64, frequency) * length;
    return bits;
}

test "literal context split finds a predictive RFC mode" {
    const input = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++
        ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const candidate = choose(input, &commands) orelse return error.TestUnexpectedResult;
    try std.testing.expect(candidate.mode <= literal_context.mode_signed);
    try std.testing.expect(candidate.tree_count >= 2 and candidate.tree_count <= max_trees);
    try std.testing.expect(candidate.savings_bits >= min_payload_savings_bits);
}

test "literal context split rejects stationary literals" {
    const input = "a" ** min_literal_count;
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    try std.testing.expectEqual(@as(?Candidate, null), choose(input, &commands));
}

test "literal context split builds candidates for every RFC mode" {
    const second_samples = [_]u8{ 0, 8, 32, 80, 128, 200, 244, 255 };
    const literal_count = 256 * second_samples.len;
    const input = try std.testing.allocator.alloc(u8, literal_count * 3);
    defer std.testing.allocator.free(input);
    const commands = try std.testing.allocator.alloc(command_plan.Command, literal_count);
    defer std.testing.allocator.free(commands);
    const cases = [_]struct { mode: u2, cutoff: u6 }{
        .{ .mode = literal_context.mode_lsb6, .cutoff = 32 },
        .{ .mode = literal_context.mode_msb6, .cutoff = 32 },
        .{ .mode = literal_context.mode_utf8, .cutoff = 32 },
        .{ .mode = literal_context.mode_signed, .cutoff = 29 },
    };
    for (cases) |case| {
        var command_index: usize = 0;
        for (0..256) |previous_usize| {
            const previous: u8 = @intCast(previous_usize);
            for (second_samples) |second_previous| {
                const position = command_index * 3 + 2;
                input[position - 2] = second_previous;
                input[position - 1] = previous;
                const context = literal_context.value(case.mode, previous, second_previous);
                const symbol: u8 = @intCast(command_index & 15);
                input[position] = if (context >= case.cutoff) 240 + symbol else symbol;
                commands[command_index] = .{
                    .insert_start = position,
                    .insert_len = 1,
                };
                command_index += 1;
            }
        }
        const candidate = chooseMode(input, commands, case.mode) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(case.mode, candidate.mode);
    }
}

test "literal context split clusters interleaved contexts into four trees" {
    const repetitions = 32;
    const literal_count = 64 * repetitions;
    const input = try std.testing.allocator.alloc(u8, literal_count * 2);
    defer std.testing.allocator.free(input);
    const commands = try std.testing.allocator.alloc(command_plan.Command, literal_count);
    defer std.testing.allocator.free(commands);
    var command_index: usize = 0;
    for (0..64) |context| {
        for (0..repetitions) |repetition| {
            const position = command_index * 2 + 1;
            input[position - 1] = @intCast(context);
            input[position] = @intCast((context % 4) * 64 + repetition);
            commands[command_index] = .{
                .insert_start = position,
                .insert_len = 1,
            };
            command_index += 1;
        }
    }
    const candidate = choose(input, commands) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(literal_context.mode_lsb6, candidate.mode);
    try std.testing.expectEqual(@as(u3, 4), candidate.tree_count);
    for (0..64) |context|
        try std.testing.expectEqual(@as(u8, @intCast(context % 4)), candidate.context_map[context]);
}
