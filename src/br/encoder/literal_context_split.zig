const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");
const context_map_encoder = @import("context_map.zig");
const literal_context = @import("literal_context.zig");

const min_literal_count: usize = 128;
const min_payload_savings_bits: u64 = 128;
pub const max_trees: usize = 64;

/// One bounded multi-tree literal-context proposal. The complete Brotli writer
/// still arbitrates this proposal by exact encoded byte length, so this module
/// only needs to reject clearly unprofitable histogram shapes.
pub const Candidate = struct {
    mode: u2,
    tree_count: u7,
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

pub const Proposals = struct {
    suffix: ?Candidate = null,
    up_to_16: ?Candidate = null,
    full: ?Candidate = null,
};

const mode_count: usize = 4;
const ContextHistograms = [64][256]u32;
const SparseContext = struct {
    symbols: [256]u8,
    frequencies: [256]u32,
    len: u16,
    total: u32,
};
const SparseContexts = [64]SparseContext;
const ActiveSymbols = struct {
    symbols: [256]u8,
    len: u16,
};
const TreeHistograms = [max_trees][256]u32;
const TreeTotals = [max_trees]u32;
const assignment_log_cache_limit: usize = 4096;
const assignment_log_cache: [assignment_log_cache_limit + 1]u16 = blk: {
    @setEvalBranchQuota(100000);
    var values: [assignment_log_cache_limit + 1]u16 = undefined;
    values[0] = 0;
    for (1..values.len) |value|
        values[value] = @intCast(fastLog2Q8(@intCast(value)));
    break :blk values;
};
const SuffixMapCosts = [64]u64;
const scored_map_capacity: usize = 22;
const ScoredMapEntry = struct {
    hash: u64,
    tree_count: u7,
    context_map: [64]u8,
    bit_cost: u64,
};
const ScoredMapCache = struct {
    entries: [scored_map_capacity]ScoredMapEntry = undefined,
    len: usize = 0,
    hits: usize = 0,

    fn get(self: *ScoredMapCache, context_map: *const [64]u8, tree_count: usize) ?u64 {
        const hash = contextMapHash(context_map, tree_count);
        for (self.entries[0..self.len]) |entry| {
            if (entry.hash == hash and entry.tree_count == tree_count and
                std.mem.eql(u8, &entry.context_map, context_map))
            {
                self.hits += 1;
                return entry.bit_cost;
            }
        }
        return null;
    }

    fn put(self: *ScoredMapCache, context_map: *const [64]u8, tree_count: usize, bit_cost: u64) void {
        std.debug.assert(self.len < self.entries.len);
        self.entries[self.len] = .{
            .hash = contextMapHash(context_map, tree_count),
            .tree_count = @intCast(tree_count),
            .context_map = context_map.*,
            .bit_cost = bit_cost,
        };
        self.len += 1;
    }
};
const Analysis = struct {
    by_mode: [mode_count]ContextHistograms,
    total: [256]u32,
    literal_count: usize,
};

/// Evaluate all four RFC 7932 literal context modes. Each mode gets its best
/// contiguous two-tree partition plus bounded clustering through all 64 literal
/// contexts
/// with both ordered and interleaved seeds.
/// Keeping the search in a separate noinline routine prevents the 64 KiB
/// context histogram from inflating the already large Brotli wire encoder
/// frame.
pub noinline fn choose(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !?Candidate {
    return (try chooseProposals(allocator, input, commands)).full;
}

pub noinline fn chooseUpTo(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, max_tree_count: usize) !?Candidate {
    if (max_tree_count < 2 or max_tree_count > max_trees) return null;
    if (max_tree_count == 16) return (try chooseProposals(allocator, input, commands)).up_to_16;
    if (max_tree_count == max_trees) return (try chooseProposals(allocator, input, commands)).full;
    return chooseWithClusters(allocator, input, commands, true, max_tree_count);
}

pub noinline fn chooseSuffix(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !?Candidate {
    return (try chooseProposals(allocator, input, commands)).suffix;
}

pub noinline fn chooseProposals(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !Proposals {
    const analysis = try collectAnalysis(allocator, input, commands) orelse return .{};
    defer allocator.destroy(analysis);
    const baseline_bits = try treeBitCost(allocator, &analysis.total);
    var active_symbols: ActiveSymbols = undefined;
    buildActiveSymbols(&analysis.total, &active_symbols);
    var suffix_map_costs: SuffixMapCosts = undefined;
    try buildSuffixMapCosts(allocator, &suffix_map_costs);
    var proposals: Proposals = .{};
    for (&analysis.by_mode, 0..) |*by_context, mode_value| {
        const mode_proposals = try chooseModeFromHistograms(
            allocator,
            @intCast(mode_value),
            by_context,
            &analysis.total,
            analysis.literal_count,
            baseline_bits,
            &active_symbols,
            &suffix_map_costs,
            true,
            max_trees,
        );
        retainBetter(&proposals.suffix, mode_proposals.suffix);
        retainBetter(&proposals.up_to_16, mode_proposals.up_to_16);
        retainBetter(&proposals.full, mode_proposals.full);
    }
    return proposals;
}

fn collectAnalysis(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !?*Analysis {
    const analysis = try allocator.create(Analysis);
    errdefer allocator.destroy(analysis);
    @memset(std.mem.asBytes(analysis), 0);
    for (commands) |command| {
        const end = std.math.add(usize, command.insert_start, command.insert_len) catch {
            allocator.destroy(analysis);
            return null;
        };
        if (end > input.len) {
            allocator.destroy(analysis);
            return null;
        }
        for (input[command.insert_start..end], command.insert_start..) |literal, position| {
            const previous = if (position == 0) 0 else input[position - 1];
            const second_previous = if (position < 2) 0 else input[position - 2];
            analysis.total[literal] += 1;
            inline for (0..mode_count) |mode_value| {
                const context = literal_context.value(@intCast(mode_value), previous, second_previous);
                analysis.by_mode[mode_value][context][literal] += 1;
            }
            analysis.literal_count += 1;
        }
    }
    if (analysis.literal_count < min_literal_count) {
        allocator.destroy(analysis);
        return null;
    }
    return analysis;
}

fn chooseWithClusters(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, include_clusters: bool, max_tree_count: usize) !?Candidate {
    var best: ?Candidate = null;
    for (0..4) |mode_value| {
        const mode_proposals = try chooseModeProposals(allocator, input, commands, @intCast(mode_value), include_clusters, max_tree_count);
        const candidate = if (!include_clusters)
            mode_proposals.suffix
        else if (max_tree_count <= 16)
            mode_proposals.up_to_16
        else
            mode_proposals.full;
        retainBetter(&best, candidate);
    }
    return best;
}

fn chooseMode(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, mode: u2) !?Candidate {
    return (try chooseModeProposals(allocator, input, commands, mode, true, max_trees)).full;
}

fn chooseModeProposals(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, mode: u2, include_clusters: bool, max_tree_count: usize) !Proposals {
    var by_context: [64][256]u32 = @splat(@splat(0));
    var total: [256]u32 = @splat(0);
    var literal_count: usize = 0;
    for (commands) |command| {
        const end = std.math.add(usize, command.insert_start, command.insert_len) catch return .{};
        if (end > input.len) return .{};
        for (input[command.insert_start..end], command.insert_start..) |literal, position| {
            const previous = if (position == 0) 0 else input[position - 1];
            const second_previous = if (position < 2) 0 else input[position - 2];
            const context = literal_context.value(mode, previous, second_previous);
            by_context[context][literal] += 1;
            total[literal] += 1;
            literal_count += 1;
        }
    }
    if (literal_count < min_literal_count) return .{};

    const baseline_bits = try treeBitCost(allocator, &total);
    var active_symbols: ActiveSymbols = undefined;
    buildActiveSymbols(&total, &active_symbols);
    var suffix_map_costs: SuffixMapCosts = undefined;
    try buildSuffixMapCosts(allocator, &suffix_map_costs);
    return chooseModeFromHistograms(
        allocator,
        mode,
        &by_context,
        &total,
        literal_count,
        baseline_bits,
        &active_symbols,
        &suffix_map_costs,
        include_clusters,
        max_tree_count,
    );
}

fn chooseModeFromHistograms(
    allocator: std.mem.Allocator,
    mode: u2,
    by_context: *const ContextHistograms,
    total: *const [256]u32,
    literal_count: usize,
    baseline_bits: u64,
    active_symbols: *const ActiveSymbols,
    suffix_map_costs: *const SuffixMapCosts,
    include_clusters: bool,
    max_tree_count: usize,
) !Proposals {
    var left: [256]u32 = @splat(0);
    var left_count: usize = 0;
    var payload_bits: ?u64 = null;
    var best: ?Candidate = null;
    for (1..64) |cutoff| {
        var context_count: usize = 0;
        for (&left, &by_context[cutoff - 1]) |*sum, count| {
            sum.* += count;
            context_count += count;
        }
        left_count += context_count;
        if (left_count == 0 or left_count == literal_count) continue;
        if (context_count != 0 or payload_bits == null)
            payload_bits = try suffixPayloadBitCost(allocator, total, &left);
        const candidate = Candidate.suffix(mode, @intCast(cutoff), 0);
        const candidate_bits = payload_bits.? + suffix_map_costs[cutoff];
        const savings = baseline_bits -| candidate_bits;
        if (savings < min_payload_savings_bits) continue;
        if (best == null or savings > best.?.savings_bits) {
            var retained = candidate;
            retained.savings_bits = savings;
            best = retained;
        }
    }

    var proposals = Proposals{ .suffix = best, .up_to_16 = best, .full = best };
    if (!include_clusters) return proposals;
    var sparse_contexts: SparseContexts = undefined;
    buildSparseContexts(by_context, &sparse_contexts);
    var score_cache: ScoredMapCache = .{};
    for ([_]usize{ 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64 }) |requested_tree_count| {
        if (requested_tree_count > max_tree_count) continue;
        for ([_]Seed{ .ordered, .interleaved }) |seed| {
            const clustered = try clusterContexts(
                allocator,
                mode,
                &sparse_contexts,
                active_symbols,
                &score_cache,
                baseline_bits,
                requested_tree_count,
                seed,
            ) orelse continue;
            retainBetter(&proposals.full, clustered);
            if (requested_tree_count <= 16) retainBetter(&proposals.up_to_16, clustered);
        }
    }
    return proposals;
}

fn suffixPayloadBitCost(
    allocator: std.mem.Allocator,
    total: *const [256]u32,
    left: *const [256]u32,
) !u64 {
    var right: [256]u32 = undefined;
    for (&right, total, left) |*remaining, all, used| remaining.* = all - used;
    const left_bits = try treeBitCost(allocator, left);
    const right_bits = try treeBitCost(allocator, &right);
    return left_bits + right_bits;
}

fn retainBetter(slot: *?Candidate, candidate: ?Candidate) void {
    const proposed = candidate orelse return;
    if (slot.* == null or proposed.savings_bits > slot.*.?.savings_bits or
        (proposed.savings_bits == slot.*.?.savings_bits and proposed.tree_count < slot.*.?.tree_count))
        slot.* = proposed;
}

fn contextMapHash(context_map: *const [64]u8, tree_count: usize) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    hash = (hash ^ @as(u64, @intCast(tree_count))) *% 0x0000_0100_0000_01b3;
    for (context_map) |tree| hash = (hash ^ @as(u64, tree)) *% 0x0000_0100_0000_01b3;
    return hash;
}

const Seed = enum { ordered, interleaved };

fn clusterContexts(
    allocator: std.mem.Allocator,
    mode: u2,
    sparse_contexts: *const SparseContexts,
    active_symbols: *const ActiveSymbols,
    score_cache: *ScoredMapCache,
    baseline_bits: u64,
    requested_tree_count: usize,
    seed: Seed,
) !?Candidate {
    var populated: [64]u8 = undefined;
    var populated_count: usize = 0;
    for (sparse_contexts, 0..) |sparse, context| {
        if (sparse.total == 0) continue;
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

    const cluster_iterations: usize = if (requested_tree_count <= 16)
        4
    else if (requested_tree_count <= 32)
        2
    else
        1;
    var tree_histograms: TreeHistograms = undefined;
    var tree_totals: TreeTotals = undefined;
    initializeTreeWorkspace(requested_tree_count, &tree_histograms, &tree_totals);
    aggregateTreesSparse(sparse_contexts, &context_map, requested_tree_count, &tree_histograms, &tree_totals);
    for (0..cluster_iterations) |_| {
        var symbol_costs: [max_trees][256]u16 = undefined;
        prepareAssignmentCosts(&tree_histograms, &tree_totals, requested_tree_count, active_symbols, &symbol_costs);
        var changed = false;
        for (populated[0..populated_count]) |context| {
            var best_tree: usize = 0;
            var best_cost = assignmentCostSparse(&sparse_contexts[context], &symbol_costs[0]);
            for (1..requested_tree_count) |tree| {
                const cost = assignmentCostSparse(&sparse_contexts[context], &symbol_costs[tree]);
                if (cost < best_cost) {
                    best_cost = cost;
                    best_tree = tree;
                }
            }
            const previous_tree: usize = context_map[context];
            if (previous_tree != best_tree) {
                // Assignment costs stay frozen for the complete round. Moving
                // the frequencies here only prepares the exact histogram for
                // the next round, without changing any decision in this one.
                moveContextSparse(
                    &sparse_contexts[context],
                    previous_tree,
                    best_tree,
                    &tree_histograms,
                    &tree_totals,
                );
                context_map[context] = @intCast(best_tree);
                changed = true;
            }
        }
        if (!changed) break;
    }

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
    for (&context_map, sparse_contexts) |*tree, sparse| {
        if (sparse.total == 0) {
            tree.* = 0;
        } else {
            tree.* = remap[tree.*];
        }
    }

    const candidate_bits = score_cache.get(&context_map, tree_count) orelse blk: {
        var bits: u64 = 0;
        for (tree_histograms[0..tree_count]) |*histogram|
            bits += try treeBitCost(allocator, histogram);
        const map_plan = try context_map_encoder.choose(allocator, &context_map, tree_count);
        bits += map_plan.bit_cost;
        score_cache.put(&context_map, tree_count, bits);
        break :blk bits;
    };
    const savings = baseline_bits -| candidate_bits;
    if (savings < min_payload_savings_bits) return null;
    return .{
        .mode = mode,
        .tree_count = @intCast(tree_count),
        .context_map = context_map,
        .savings_bits = savings,
    };
}

fn initializeTreeWorkspace(
    tree_count: usize,
    tree_histograms: *TreeHistograms,
    tree_totals: *TreeTotals,
) void {
    std.debug.assert(tree_count > 0 and tree_count <= max_trees);
    @memset(tree_histograms[0..tree_count], @splat(0));
    @memset(tree_totals[0..tree_count], 0);
}

fn aggregateTreesSparse(
    sparse_contexts: *const SparseContexts,
    context_map: *const [64]u8,
    tree_count: usize,
    tree_histograms: *[max_trees][256]u32,
    tree_totals: *[max_trees]u32,
) void {
    for (sparse_contexts, context_map) |*sparse, tree_u8| {
        const tree: usize = tree_u8;
        std.debug.assert(tree < tree_count);
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency|
            tree_histograms[tree][symbol] += frequency;
        tree_totals[tree] += sparse.total;
    }
}

fn moveContextSparse(
    sparse: *const SparseContext,
    previous_tree: usize,
    next_tree: usize,
    tree_histograms: *TreeHistograms,
    tree_totals: *TreeTotals,
) void {
    std.debug.assert(previous_tree != next_tree);
    for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency| {
        std.debug.assert(tree_histograms[previous_tree][symbol] >= frequency);
        tree_histograms[previous_tree][symbol] -= frequency;
        tree_histograms[next_tree][symbol] += frequency;
    }
    std.debug.assert(tree_totals[previous_tree] >= sparse.total);
    tree_totals[previous_tree] -= sparse.total;
    tree_totals[next_tree] += sparse.total;
}

fn aggregateTreesDense(
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

fn buildSparseContexts(histograms: *const ContextHistograms, sparse_contexts: *SparseContexts) void {
    for (histograms, sparse_contexts) |*histogram, *sparse| {
        sparse.len = 0;
        sparse.total = 0;
        for (histogram, 0..) |frequency, symbol| {
            if (frequency == 0) continue;
            sparse.symbols[sparse.len] = @intCast(symbol);
            sparse.frequencies[sparse.len] = frequency;
            sparse.len += 1;
            sparse.total += frequency;
        }
    }
}

fn buildActiveSymbols(total: *const [256]u32, active: *ActiveSymbols) void {
    active.len = 0;
    for (total, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        active.symbols[active.len] = @intCast(symbol);
        active.len += 1;
    }
}

fn buildSuffixMapCosts(allocator: std.mem.Allocator, costs: *SuffixMapCosts) !void {
    costs[0] = 0;
    for (1..64) |cutoff| {
        const candidate = Candidate.suffix(0, @intCast(cutoff), 0);
        const plan = try context_map_encoder.choose(allocator, &candidate.context_map, candidate.tree_count);
        costs[cutoff] = plan.bit_cost;
    }
}

fn prepareAssignmentCosts(
    tree_histograms: *const [max_trees][256]u32,
    tree_totals: *const [max_trees]u32,
    tree_count: usize,
    active_symbols: *const ActiveSymbols,
    costs: *[max_trees][256]u16,
) void {
    for (tree_histograms[0..tree_count], tree_totals[0..tree_count], costs[0..tree_count]) |*tree, tree_total, *tree_costs| {
        const model_log = fastLog2Q8(tree_total + 256);
        for (active_symbols.symbols[0..active_symbols.len]) |symbol| {
            const modeled = tree[symbol];
            const symbol_cost = model_log - assignmentLog2Q8(modeled + 1);
            std.debug.assert(symbol_cost <= std.math.maxInt(u16));
            tree_costs[symbol] = @intCast(symbol_cost);
        }
    }
}

fn assignmentCostPrepared(context: *const [256]u32, symbol_costs: *const [256]u16) u64 {
    var cost: u64 = 0;
    for (context, symbol_costs) |count, symbol_cost| {
        if (count != 0) cost += @as(u64, count) * symbol_cost;
    }
    return cost;
}

fn assignmentCostSparse(sparse: *const SparseContext, symbol_costs: *const [256]u16) u64 {
    var cost: u64 = 0;
    for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency|
        cost += @as(u64, frequency) * symbol_costs[symbol];
    return cost;
}

fn assignmentCostReference(context: *const [256]u32, tree: *const [256]u32, tree_total: u32) u64 {
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

fn assignmentLog2Q8(value: u32) u64 {
    if (value <= assignment_log_cache_limit) return assignment_log_cache[value];
    return fastLog2Q8(value);
}

fn treeBitCost(allocator: std.mem.Allocator, frequencies: *const [256]u32) !u64 {
    var alphabet: command_plan.PrefixAlphabetFor(256) = undefined;
    try command_plan.alphabetFromFrequenciesInto(256, &alphabet, frequencies);
    const lengths = try alphabet.codeLengths(frequencies);
    var cost = weightedBits(frequencies, &lengths);
    if (alphabet.len <= 4) {
        cost += 4 + @as(u64, alphabet.len) * 8 + @intFromBool(alphabet.len == 4);
    } else {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol| highest = @max(highest, symbol);
        cost += try complex_prefix.bitCost(allocator, 256, &lengths, highest + 1);
    }
    return cost;
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
    const candidate = try choose(std.testing.allocator, input, &commands) orelse return error.TestUnexpectedResult;
    try std.testing.expect(candidate.mode <= literal_context.mode_signed);
    try std.testing.expect(candidate.tree_count >= 2 and candidate.tree_count <= max_trees);
    try std.testing.expect(candidate.savings_bits >= min_payload_savings_bits);
}

test "literal context split reports exact tree and map savings" {
    const input = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++
        ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const candidate = try chooseMode(std.testing.allocator, input, &commands, literal_context.mode_utf8) orelse
        return error.TestUnexpectedResult;
    var total: [256]u32 = @splat(0);
    var trees: [max_trees][256]u32 = @splat(@splat(0));
    for (input, 0..) |literal, position| {
        const previous = if (position == 0) 0 else input[position - 1];
        const second_previous = if (position < 2) 0 else input[position - 2];
        const context = literal_context.value(candidate.mode, previous, second_previous);
        total[literal] += 1;
        trees[candidate.treeFor(context)][literal] += 1;
    }
    const baseline_bits = try treeBitCost(std.testing.allocator, &total);
    var candidate_bits: u64 = 0;
    for (trees[0..candidate.tree_count]) |*histogram|
        candidate_bits += try treeBitCost(std.testing.allocator, histogram);
    const map_plan = try context_map_encoder.choose(std.testing.allocator, &candidate.context_map, candidate.tree_count);
    candidate_bits += map_plan.bit_cost;
    try std.testing.expectEqual(baseline_bits - candidate_bits, candidate.savings_bits);
}

test "literal context proposals match independent stage selection" {
    const input = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++
        ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const proposals = try chooseProposals(std.testing.allocator, input, &commands);
    const independent = [_]?Candidate{
        try chooseWithClusters(std.testing.allocator, input, &commands, false, 2),
        try chooseWithClusters(std.testing.allocator, input, &commands, true, 16),
        try chooseWithClusters(std.testing.allocator, input, &commands, true, max_trees),
    };
    const combined = [_]?Candidate{ proposals.suffix, proposals.up_to_16, proposals.full };
    for (combined, independent) |actual, expected| {
        try std.testing.expectEqual(expected == null, actual == null);
        if (expected) |expected_candidate| {
            try std.testing.expect(Candidate.eql(expected_candidate, actual.?));
            try std.testing.expectEqual(expected_candidate.savings_bits, actual.?.savings_bits);
        }
    }
}

test "literal context single-pass analysis cleans up allocation failures" {
    const input = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++
        ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const Test = struct {
        fn run(allocator: std.mem.Allocator, payload: []const u8, plan: []const command_plan.Command) !void {
            const proposals = try chooseProposals(allocator, payload, plan);
            try std.testing.expect(proposals.full != null);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ input[0..], commands[0..] },
    );
}

test "literal context prepared assignment costs match reference" {
    var trees: [max_trees][256]u32 = @splat(@splat(0));
    var totals: [max_trees]u32 = @splat(0);
    var context: [256]u32 = @splat(0);
    for (0..4) |tree| {
        for (0..256) |symbol| {
            const frequency: u32 = @intCast((symbol * (tree + 3) + tree * 11) % 29);
            trees[tree][symbol] = frequency;
            totals[tree] += frequency;
            if ((symbol + tree) % 7 == 0) context[symbol] = @intCast(symbol % 13 + 1);
        }
    }
    var costs: [max_trees][256]u16 = undefined;
    var active_symbols: ActiveSymbols = undefined;
    buildActiveSymbols(&context, &active_symbols);
    prepareAssignmentCosts(&trees, &totals, 4, &active_symbols, &costs);
    var contexts: ContextHistograms = @splat(@splat(0));
    contexts[0] = context;
    var sparse_contexts: SparseContexts = undefined;
    buildSparseContexts(&contexts, &sparse_contexts);
    for (0..4) |tree| {
        const reference = assignmentCostReference(&context, &trees[tree], totals[tree]);
        const prepared = assignmentCostPrepared(&context, &costs[tree]);
        const sparse = assignmentCostSparse(&sparse_contexts[0], &costs[tree]);
        try std.testing.expectEqual(reference, prepared);
        try std.testing.expectEqual(reference, sparse);
    }
}

test "literal context assignment log table matches direct Q8 logs" {
    for (1..assignment_log_cache_limit + 1) |value|
        try std.testing.expectEqual(fastLog2Q8(@intCast(value)), assignmentLog2Q8(@intCast(value)));
    for ([_]u32{ assignment_log_cache_limit + 1, 65535, std.math.maxInt(u32) }) |value|
        try std.testing.expectEqual(fastLog2Q8(value), assignmentLog2Q8(value));
}

test "literal context active alphabet covers all byte symbols" {
    var total: [256]u32 = @splat(1);
    var active: ActiveSymbols = undefined;
    buildActiveSymbols(&total, &active);
    try std.testing.expectEqual(@as(u16, 256), active.len);
    for (active.symbols, 0..) |symbol, expected|
        try std.testing.expectEqual(@as(u8, @intCast(expected)), symbol);
    total[17] = 0;
    buildActiveSymbols(&total, &active);
    try std.testing.expectEqual(@as(u16, 255), active.len);
    try std.testing.expect(std.mem.indexOfScalar(u8, active.symbols[0..active.len], 17) == null);
}

test "literal context suffix map costs match independent planning" {
    var costs: SuffixMapCosts = undefined;
    try buildSuffixMapCosts(std.testing.allocator, &costs);
    try std.testing.expectEqual(@as(u64, 0), costs[0]);
    for (1..64) |cutoff| {
        const candidate = Candidate.suffix(literal_context.mode_signed, @intCast(cutoff), 0);
        const plan = try context_map_encoder.choose(std.testing.allocator, &candidate.context_map, candidate.tree_count);
        try std.testing.expectEqual(plan.bit_cost, costs[cutoff]);
    }
}

test "literal context suffix payload reuse matches independent scoring" {
    var contexts: ContextHistograms = @splat(@splat(0));
    contexts[7][11] = 32;
    contexts[19][23] = 48;
    contexts[43][37] = 64;
    var total: [256]u32 = @splat(0);
    for (contexts) |histogram| {
        for (&total, histogram) |*sum, frequency| sum.* += frequency;
    }
    const literal_count: usize = histogramCount(&total);

    var left: [256]u32 = @splat(0);
    var left_count: usize = 0;
    var cached: ?u64 = null;
    var valid_cutoffs: usize = 0;
    var recomputed: usize = 0;
    for (1..64) |cutoff| {
        var context_count: usize = 0;
        for (&left, &contexts[cutoff - 1]) |*sum, frequency| {
            sum.* += frequency;
            context_count += frequency;
        }
        left_count += context_count;
        if (left_count == 0 or left_count == literal_count) continue;
        valid_cutoffs += 1;
        if (context_count != 0 or cached == null) {
            cached = try suffixPayloadBitCost(std.testing.allocator, &total, &left);
            recomputed += 1;
        }
        const independent = try suffixPayloadBitCost(std.testing.allocator, &total, &left);
        try std.testing.expectEqual(independent, cached.?);
    }
    try std.testing.expect(valid_cutoffs > recomputed);
    try std.testing.expectEqual(@as(usize, 2), recomputed);
}

test "literal context scored map cache hits and rejects collisions" {
    var contexts: ContextHistograms = @splat(@splat(0));
    var total: [256]u32 = @splat(0);
    for (&contexts, 0..) |*histogram, context| {
        const symbol = context % 4;
        histogram[symbol] = 32;
        total[symbol] += 32;
    }
    var sparse_contexts: SparseContexts = undefined;
    buildSparseContexts(&contexts, &sparse_contexts);
    var active_symbols: ActiveSymbols = undefined;
    buildActiveSymbols(&total, &active_symbols);
    const baseline_bits = try treeBitCost(std.testing.allocator, &total);
    var cache: ScoredMapCache = .{};
    const first = try clusterContexts(
        std.testing.allocator,
        literal_context.mode_lsb6,
        &sparse_contexts,
        &active_symbols,
        &cache,
        baseline_bits,
        4,
        .interleaved,
    ) orelse return error.TestUnexpectedResult;
    const second = try clusterContexts(
        std.testing.allocator,
        literal_context.mode_lsb6,
        &sparse_contexts,
        &active_symbols,
        &cache,
        baseline_bits,
        4,
        .interleaved,
    ) orelse return error.TestUnexpectedResult;
    try std.testing.expect(Candidate.eql(first, second));
    try std.testing.expectEqual(first.savings_bits, second.savings_bits);
    try std.testing.expectEqual(@as(usize, 1), cache.len);
    try std.testing.expectEqual(@as(usize, 1), cache.hits);

    const map_a: [64]u8 = @splat(0);
    var map_b = map_a;
    map_b[63] = 1;
    var collision: ScoredMapCache = .{};
    collision.put(&map_a, 2, 123);
    collision.entries[0].hash = contextMapHash(&map_b, 2);
    try std.testing.expectEqual(@as(?u64, null), collision.get(&map_b, 2));
    try std.testing.expectEqual(@as(usize, 0), collision.hits);
}

test "literal context sparse tree aggregation matches dense reference" {
    var contexts: ContextHistograms = @splat(@splat(0));
    var context_map: [64]u8 = undefined;
    for (&contexts, &context_map, 0..) |*histogram, *tree, context| {
        tree.* = @intCast(context % 7);
        for (histogram, 0..) |*frequency, symbol| {
            if ((symbol * 3 + context * 5) % 17 == 0) {
                frequency.* = @intCast((symbol + context) % 11 + 1);
            }
        }
    }
    var sparse_contexts: SparseContexts = undefined;
    buildSparseContexts(&contexts, &sparse_contexts);
    var dense_trees: [max_trees][256]u32 = @splat(@splat(0));
    var sparse_trees: [max_trees][256]u32 = @splat(@splat(0));
    var dense_totals: [max_trees]u32 = @splat(0);
    var sparse_totals: [max_trees]u32 = @splat(0);
    aggregateTreesDense(&contexts, &context_map, 7, &dense_trees, &dense_totals);
    aggregateTreesSparse(&sparse_contexts, &context_map, 7, &sparse_trees, &sparse_totals);
    try std.testing.expectEqualSlices(u32, dense_totals[0..7], sparse_totals[0..7]);
    for (0..7) |tree|
        try std.testing.expectEqualSlices(u32, &dense_trees[tree], &sparse_trees[tree]);
}

test "literal context incremental tree moves match full aggregation" {
    var contexts: ContextHistograms = @splat(@splat(0));
    var context_map: [64]u8 = undefined;
    for (&contexts, &context_map, 0..) |*histogram, *tree, context| {
        tree.* = @intCast(context % 7);
        for (histogram, 0..) |*frequency, symbol| {
            if ((symbol * 5 + context * 11) % 23 == 0)
                frequency.* = @intCast((symbol + context * 3) % 17 + 1);
        }
    }
    var sparse_contexts: SparseContexts = undefined;
    buildSparseContexts(&contexts, &sparse_contexts);
    var incremental_trees: TreeHistograms = @splat(@splat(0));
    var incremental_totals: TreeTotals = @splat(0);
    aggregateTreesSparse(&sparse_contexts, &context_map, 7, &incremental_trees, &incremental_totals);
    for (0..64) |context| {
        if (context % 3 != 0) continue;
        const previous_tree: usize = context_map[context];
        const next_tree = (previous_tree + 3) % 7;
        moveContextSparse(
            &sparse_contexts[context],
            previous_tree,
            next_tree,
            &incremental_trees,
            &incremental_totals,
        );
        context_map[context] = @intCast(next_tree);
    }

    var rebuilt_trees: TreeHistograms = @splat(@splat(0));
    var rebuilt_totals: TreeTotals = @splat(0);
    aggregateTreesDense(&contexts, &context_map, 7, &rebuilt_trees, &rebuilt_totals);
    try std.testing.expectEqualSlices(u32, rebuilt_totals[0..7], incremental_totals[0..7]);
    for (0..7) |tree|
        try std.testing.expectEqualSlices(u32, &rebuilt_trees[tree], &incremental_trees[tree]);
}

test "literal context tree workspace clears only requested prefix" {
    const histogram_poison: u32 = 0xa5a5_a5a5;
    const total_poison: u32 = 0x5a5a_5a5a;
    var trees: TreeHistograms = @splat(@splat(histogram_poison));
    var totals: TreeTotals = @splat(total_poison);
    initializeTreeWorkspace(7, &trees, &totals);
    for (trees[0..7], totals[0..7]) |tree, total| {
        try std.testing.expectEqual(@as(u32, 0), total);
        for (tree) |frequency|
            try std.testing.expectEqual(@as(u32, 0), frequency);
    }
    for (trees[7..], totals[7..]) |tree, total| {
        try std.testing.expectEqual(total_poison, total);
        for (tree) |frequency|
            try std.testing.expectEqual(histogram_poison, frequency);
    }
}

test "literal context split rejects stationary literals" {
    const input = "a" ** min_literal_count;
    const commands = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    try std.testing.expectEqual(@as(?Candidate, null), try choose(std.testing.allocator, input, &commands));
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
        const candidate = try chooseMode(std.testing.allocator, input, commands, case.mode) orelse return error.TestUnexpectedResult;
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
    const candidate = try chooseMode(std.testing.allocator, input, commands, literal_context.mode_lsb6) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(literal_context.mode_lsb6, candidate.mode);
    try std.testing.expectEqual(@as(u7, 4), candidate.tree_count);
    for (0..64) |context|
        try std.testing.expectEqual(@as(u8, @intCast(context % 4)), candidate.context_map[context]);
}

test "literal context split clusters interleaved contexts into eight trees" {
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
            input[position] = @intCast((context % 8) * 32 + repetition);
            commands[command_index] = .{
                .insert_start = position,
                .insert_len = 1,
            };
            command_index += 1;
        }
    }
    const candidate = try choose(std.testing.allocator, input, commands) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(literal_context.mode_lsb6, candidate.mode);
    try std.testing.expectEqual(@as(u7, 8), candidate.tree_count);
    for (0..64) |context|
        try std.testing.expectEqual(@as(u8, @intCast(context % 8)), candidate.context_map[context]);
}

test "literal context split clusters interleaved contexts into sixteen trees" {
    const repetitions = 16;
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
            input[position] = @intCast((context % 16) * 16 + repetition);
            commands[command_index] = .{
                .insert_start = position,
                .insert_len = 1,
            };
            command_index += 1;
        }
    }
    const candidate = try choose(std.testing.allocator, input, commands) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(literal_context.mode_lsb6, candidate.mode);
    try std.testing.expectEqual(@as(u7, 16), candidate.tree_count);
    for (0..64) |context|
        try std.testing.expectEqual(@as(u8, @intCast(context % 16)), candidate.context_map[context]);
}

test "literal context split clusters every literal context independently" {
    const repetitions = 128;
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
            input[position] = @intCast(context * 4 + (repetition & 3));
            commands[command_index] = .{
                .insert_start = position,
                .insert_len = 1,
            };
            command_index += 1;
        }
    }
    const candidate = try choose(std.testing.allocator, input, commands) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(literal_context.mode_lsb6, candidate.mode);
    try std.testing.expectEqual(@as(u7, 64), candidate.tree_count);
    for (0..64) |context|
        try std.testing.expectEqual(@as(u8, @intCast(context)), candidate.context_map[context]);
}
