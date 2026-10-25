//! Independent weighted-bit certificates. Tiny optimal costs come from an
//! exhaustive Kraft length enumeration, never a production Huffman planner.
const std = @import("std");
const bound = @import("weighted_bound.zig");

fn enumerateLengths(frequencies: []const u32, max_bits: u4, index: usize, kraft: usize, cost: u64, best: *u64) void {
    const capacity = @as(usize, 1) << max_bits;
    if (index == frequencies.len) {
        if (kraft <= capacity) best.* = @min(best.*, cost);
        return;
    }
    var bits: u4 = 1;
    while (bits <= max_bits) : (bits += 1) {
        const next_kraft = kraft + (@as(usize, 1) << @intCast(max_bits - bits));
        if (next_kraft <= capacity)
            enumerateLengths(frequencies, max_bits, index + 1, next_kraft, cost + @as(u64, frequencies[index]) * bits, best);
    }
}

fn exhaustiveOptimum(frequencies: []const u32, max_bits: u4) u64 {
    var best: u64 = std.math.maxInt(u64);
    enumerateLengths(frequencies, max_bits, 0, 0, 0, &best);
    std.debug.assert(best != std.math.maxInt(u64));
    return best;
}

fn vector(index: usize, active: usize) [4]u32 {
    var result: [4]u32 = @splat(0);
    var digits = index;
    for (result[0..active]) |*frequency| {
        frequency.* = @intCast(1 + digits % 3);
        digits /= 3;
    }
    return result;
}

fn wideVector(small: []const u32) [256]u32 {
    const symbols = [_]usize{ 0, 17, 129, 255 };
    var result: [256]u32 = @splat(0);
    for (small, 0..) |frequency, index| result[symbols[index]] = frequency;
    return result;
}

fn weightedCost(frequencies: *const [256]u32, lengths: *const [256]u4) u64 {
    var cost: u64 = 0;
    for (frequencies, lengths) |frequency, bits| cost += @as(u64, frequency) * bits;
    return cost;
}

pub fn tinyExhaustive() !void {
    var saw_positive = false;
    var saw_negative = false;
    var saw_equal_total = false;
    inline for (.{ 3, 4 }) |max_bits| {
        inline for (.{ 2, 3, 4 }) |active| {
            const Cert = bound.Certificate(active, max_bits);
            const cases = std.math.pow(usize, 3, active);
            var optima: [81]u64 = undefined;
            for (0..cases) |index| {
                const frequencies = vector(index, active);
                optima[index] = exhaustiveOptimum(frequencies[0..active], max_bits);
            }
            for (0..cases) |old_index| {
                const old_values = vector(old_index, active);
                const old: [active]u32 = old_values[0..active].*;
                const certificate = try Cert.init(&old, optima[old_index]);
                try std.testing.expectEqual(@as(?u64, optima[old_index]), try certificate.bitLowerBound(&old));
                for (0..cases) |new_index| {
                    const new_values = vector(new_index, active);
                    const current: [active]u32 = new_values[0..active].*;
                    const analysis = try certificate.analyze(&current);
                    const lower = analysis.bit_lower_bound orelse return error.TestUnexpectedResult;
                    try std.testing.expect(analysis.same_support);
                    try std.testing.expectEqual(@as(usize, active), analysis.current_active_symbols);
                    var old_total: u32 = 0;
                    var current_total: u32 = 0;
                    var negative: u32 = 0;
                    for (old, current) |previous, frequency| {
                        old_total += previous;
                        current_total += frequency;
                        negative += previous -| frequency;
                        saw_positive = saw_positive or frequency > previous;
                        saw_negative = saw_negative or frequency < previous;
                    }
                    saw_equal_total = saw_equal_total or (old_index != new_index and old_total == current_total);
                    try std.testing.expectEqual(current_total, analysis.current_total);
                    try std.testing.expectEqual(negative, analysis.negative_delta);
                    try std.testing.expect(lower >= current_total);
                    // This optimum comes from enumerating all feasible lengths
                    // for g, rather than recomputing the certificate formula.
                    try std.testing.expect(lower <= optima[new_index]);
                    try std.testing.expectEqual(@as(?u64, lower), try certificate.bitLowerBound(&current));
                }
            }
        }
    }
    try std.testing.expect(saw_positive and saw_negative and saw_equal_total);
}

fn expectTotalRejected(operation: anytype) !void {
    if (operation) |_| return error.TestUnexpectedResult else |err| try std.testing.expect(err == error.InvalidFrequencyTotal or err == error.IntegerOverflow);
}

pub fn resources() !void {
    const Cert = bound.Certificate(4, 4);
    try std.testing.expect(@sizeOf(Cert) < 2 * 1024);
    try std.testing.expectEqual(@as(u32, 131072), bound.max_total_frequency);
    const old = [_]u32{ 1, 2, 3, 4 };
    var certificate = try Cert.init(&old, exhaustiveOptimum(&old, 4));
    const original = certificate;
    const invalid_support = [_][4]u32{ .{ 0, 0, 0, 0 }, .{ 1, 0, 0, 0 } };
    for (invalid_support) |frequencies| {
        try std.testing.expectError(error.InvalidSupport, Cert.init(&frequencies, 1));
        try std.testing.expectError(error.InvalidSupport, certificate.publish(&frequencies, 1));
        try std.testing.expectEqualDeep(original, certificate);
    }
    try std.testing.expectError(error.InvalidSupport, bound.Certificate(4, 1).init(&old, 10));
    try std.testing.expectError(error.InvalidCertificateCost, Cert.init(&old, 9));
    try std.testing.expectError(error.InvalidCertificateCost, Cert.init(&old, 41));
    for ([_]u64{ 0, 9, 41, std.math.maxInt(u64) }) |cost| {
        try std.testing.expectError(error.InvalidCertificateCost, certificate.publish(&old, cost));
        try std.testing.expectEqualDeep(original, certificate);
    }
    for ([_][4]u32{ .{ 131072, 1, 0, 0 }, .{ std.math.maxInt(u32), 1, 0, 0 }, .{ std.math.maxInt(u32), std.math.maxInt(u32), 1, 0 } }) |frequencies| {
        try expectTotalRejected(Cert.init(&frequencies, 131072));
        try expectTotalRejected(certificate.publish(&frequencies, 131072));
        try std.testing.expectEqualDeep(original, certificate);
        try expectTotalRejected(certificate.analyze(&frequencies));
        try std.testing.expectEqualDeep(original, certificate);
    }
    for ([_][4]u32{ .{ 0, 2, 3, 4 }, .{ 0, 0, 0, 0 }, .{ 1, 0, 0, 0 } }) |current| {
        const analysis = try certificate.analyze(&current);
        try std.testing.expect(!analysis.same_support);
        try std.testing.expectEqual(@as(?u64, null), analysis.bit_lower_bound);
        try std.testing.expectEqual(@as(?u64, null), try certificate.bitLowerBound(&current));
    }
    const refreshed = [_]u32{ 4, 3, 2, 1 };
    const refreshed_cost = exhaustiveOptimum(&refreshed, 4);
    try certificate.publish(&refreshed, refreshed_cost);
    try std.testing.expectEqual(@as(?u64, refreshed_cost), try certificate.bitLowerBound(&refreshed));

    // The module checks numeric bounds; it cannot prove optimality for an
    // arbitrary caller scalar. A feasible non-optimal tree is an upper bound.
    // Deliberately show why it MUST NOT be published as trusted_lower_bits.
    const skew = [_]u32{ 10, 1, 1 };
    const optimum = exhaustiveOptimum(&skew, 3);
    const arbitrary_feasible_upper: u64 = 10 * 2 + 1 * 2 + 1 * 2;
    try std.testing.expectEqual(@as(u64, 14), optimum);
    try std.testing.expectEqual(@as(u64, 24), arbitrary_feasible_upper);
    try std.testing.expect(arbitrary_feasible_upper > optimum);
    const trusted = try bound.Certificate(3, 3).init(&skew, optimum);
    try std.testing.expectEqual(@as(?u64, optimum), try trusted.bitLowerBound(&skew));
    // No safety assertion feeds the arbitrary feasible upper cost to init:
    // doing so would violate the certificate's explicit caller precondition.
}

pub fn realistic(comptime Codec: type) !void {
    const Cert = bound.Certificate(256, 11);
    try std.testing.expect(@sizeOf(Cert) < 2 * 1024);
    for ([_]usize{ 2, 3, 65, 77, 88, 127, 256 }) |active| {
        var old: [256]u32 = @splat(0);
        for (0..active) |index| old[(index * 149 + 41) % 256] = @intCast(2 + (index * 13) % 29);
        const plan = Codec.treeCodeLengthsFullWidth(256, &old, 11);
        const old_optimum = weightedCost(&old, &plan);
        var certificate = try Cert.init(&old, old_optimum);
        try std.testing.expectEqual(@as(?u64, old_optimum), try certificate.bitLowerBound(&old));
        for (0..12) |step| {
            var current = old;
            for (&current, 0..) |*frequency, symbol| {
                if (frequency.* == 0) continue;
                const delta = (symbol + step) % 5;
                frequency.* = if (symbol % 2 == 0) frequency.* + @as(u32, @intCast(delta)) else @max(1, frequency.* -| @as(u32, @intCast(delta)));
            }
            const current_plan = Codec.treeCodeLengthsFullWidth(256, &current, 11);
            const current_optimum = weightedCost(&current, &current_plan);
            const lower = (try certificate.bitLowerBound(&current)) orelse return error.TestUnexpectedResult;
            try std.testing.expect(lower <= current_optimum);
            // Refresh only with another independently optimal weighted value.
            try certificate.publish(&current, current_optimum);
            try std.testing.expectEqual(@as(?u64, current_optimum), try certificate.bitLowerBound(&current));
        }
        var missing = old;
        for (&missing) |*frequency| if (frequency.* != 0) {
            frequency.* = 0;
            break;
        };
        try std.testing.expectEqual(@as(?u64, null), try certificate.bitLowerBound(&missing));
    }
    // The format's largest legal total remains exact; individual u32 counters
    // never justify silently accepting totals outside the block domain.
    var largest: [256]u32 = @splat(0);
    largest[0] = 131071;
    largest[255] = 1;
    const largest_plan = Codec.treeCodeLengthsFullWidth(256, &largest, 11);
    const largest_cost = weightedCost(&largest, &largest_plan);
    const certificate = try Cert.init(&largest, largest_cost);
    const balanced_small = [_]u32{ 65536, 65536 };
    const balanced = wideVector(&balanced_small);
    // Same cardinality alone is insufficient: symbols 0/17 replace 0/255.
    try std.testing.expectEqual(@as(?u64, null), try certificate.bitLowerBound(&balanced));
    largest[0] = 65536;
    largest[255] = 65536;
    const balanced_plan = Codec.treeCodeLengthsFullWidth(256, &largest, 11);
    try std.testing.expect((try certificate.bitLowerBound(&largest)).? <= weightedCost(&largest, &balanced_plan));
}
