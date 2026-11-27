//! Exact round assignment with four sparse contexts sharing each price row.
//! max_active_price must bound every initialized active tree price. Sparse
//! totals are ignored; real frequency sums certify unsigned 32-bit arithmetic.
const std = @import("std");
const reference = @import("../assignment_costs.zig");

pub const Choice = reference.Choice;
pub const Costs = reference.Costs;
pub const Stats = struct { narrow_contexts: usize = 0, wide_contexts: usize = 0, light_contexts: usize = 0 };
const contexts_per_tile = 4;
const trees_per_group = 8;
const Prices = @Vector(trees_per_group, u32);

pub noinline fn chooseAll(sparse_contexts: anytype, populated: []const u8, costs: *const Costs, tree_count: usize, max_active_price: u16, choices: *[64]Choice) Stats {
    std.debug.assert(tree_count != 0 and tree_count <= reference.max_trees and populated.len <= 64);
    var stats: Stats = .{};
    if (max_active_price == 0) {
        for (populated) |context| {
            std.debug.assert(context < choices.len);
            choices[context] = .{ .tree = 0, .cost = 0 };
        }
        stats.narrow_contexts = populated.len;
        return stats;
    }
    var position: usize = 0;
    while (position < populated.len) {
        if (tree_count < trees_per_group or populated.len - position < contexts_per_tile) {
            for (populated[position..]) |context| {
                std.debug.assert(context < choices.len);
                choices[context] = reference.choose(&sparse_contexts[context], costs, tree_count);
                stats.light_contexts += 1;
            }
            break;
        }
        const contexts = populated[position..][0..contexts_per_tile];
        position += contexts_per_tile;
        var safe: [contexts_per_tile]bool = undefined;
        var safe_count: usize = 0;
        for (contexts, 0..) |context, slot| {
            std.debug.assert(context < choices.len);
            const sparse = &sparse_contexts[context];
            std.debug.assert(sparse.len <= 256);
            var total: u64 = 0;
            for (sparse.frequencies[0..sparse.len]) |frequency| total += frequency;
            safe[slot] = total <= std.math.maxInt(u32) and total * max_active_price <= std.math.maxInt(u32);
            if (safe[slot]) {
                safe_count += 1;
                stats.narrow_contexts += 1;
            } else {
                choices[context] = reference.choose(sparse, costs, tree_count);
                stats.wide_contexts += 1;
            }
        }
        if (safe_count == 0) continue;

        var frequencies: [256][contexts_per_tile]u32 = @splat(@splat(0));
        var symbols: [256]u8 = undefined;
        var symbol_count: usize = 0;
        var seen: [4]u64 = @splat(0);
        for (contexts, safe, 0..) |context, enabled, slot| {
            if (!enabled) continue;
            const sparse = &sparse_contexts[context];
            for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency| {
                if (frequency == 0) continue;
                frequencies[symbol][slot] += frequency;
                const bucket = symbol / 64;
                const bit = @as(u64, 1) << @as(u6, @intCast(symbol % 64));
                if (seen[bucket] & bit == 0) {
                    seen[bucket] |= bit;
                    symbols[symbol_count] = symbol;
                    symbol_count += 1;
                }
            }
        }
        var best_costs: [contexts_per_tile]u32 = @splat(std.math.maxInt(u32));
        var best_trees: [contexts_per_tile]usize = @splat(0);
        var tree: usize = 0;
        while (tree < tree_count) : (tree += trees_per_group) {
            const active = @min(trees_per_group, tree_count - tree);
            var totals: [contexts_per_tile]Prices = @splat(@splat(0));
            for (symbols[0..symbol_count]) |symbol| {
                var row: [trees_per_group]u16 = @splat(0);
                @memcpy(row[0..active], costs[symbol][tree..][0..active]);
                const prices: Prices = @intCast(@as(@Vector(trees_per_group, u16), row));
                for (0..contexts_per_tile) |slot| {
                    if (!safe[slot]) continue;
                    totals[slot] += @as(Prices, @splat(frequencies[symbol][slot])) * prices;
                }
            }
            for (0..contexts_per_tile) |slot| {
                if (!safe[slot]) continue;
                const values: [trees_per_group]u32 = totals[slot];
                for (values[0..active], 0..) |cost, lane| {
                    if (cost < best_costs[slot]) {
                        best_costs[slot] = cost;
                        best_trees[slot] = tree + lane;
                    }
                }
            }
        }
        for (contexts, safe, 0..) |context, enabled, slot| {
            if (enabled) choices[context] = .{ .tree = best_trees[slot], .cost = best_costs[slot] };
        }
    }
    return stats;
}
