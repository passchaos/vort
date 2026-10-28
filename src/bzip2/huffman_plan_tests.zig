const std = @import("std");
const planner = @import("huffman_plan.zig");
const writer_mod = @import("huffman_writer.zig");
const bit_writer = @import("bit_writer.zig");
const bit_reader = @import("bit_reader.zig");
const allocator = std.testing.allocator;

fn independentlyDecode(plan: *const planner.Plan, symbols: []const u16, encoded: []const u8) !usize {
    var reader = bit_reader.BitReader.init(encoded);
    try std.testing.expectEqual(@as(u32, plan.group_count), try reader.readBits(3));
    try std.testing.expectEqual(@as(u32, @intCast(plan.selectors.len)), try reader.readBits(15));
    var mtf: [6]u8 = .{ 0, 1, 2, 3, 4, 5 };
    for (plan.selectors) |expected| {
        var rank: usize = 0;
        while (try reader.readBit() != 0) : (rank += 1)
            try std.testing.expect(rank + 1 < plan.group_count);
        const selected = mtf[rank];
        try std.testing.expectEqual(expected, selected);
        // A separate slice rotation, rather than the production MTF helper.
        std.mem.copyBackwards(u8, mtf[1 .. rank + 1], mtf[0..rank]);
        mtf[0] = selected;
    }
    var lengths: [6][258]u5 = @splat(@splat(0));
    var codes: [6][258]u32 = @splat(@splat(0));
    for (0..plan.group_count) |group| {
        var current: i32 = @intCast(try reader.readBits(5));
        for (lengths[group][0..plan.alpha_size]) |*length| {
            while (try reader.readBit() != 0) {
                current += if (try reader.readBit() == 0) @as(i32, 1) else -1;
                try std.testing.expect(current >= 1 and current <= 20);
            }
            length.* = @intCast(current);
        }
        try std.testing.expectEqualSlices(u5, plan.lengths[group][0..plan.alpha_size], lengths[group][0..plan.alpha_size]);
        // Canonical construction by visiting increasing lengths and symbols.
        // This is independent of the planner's count/prefix-code formula.
        var code: u32 = 0;
        for (1..21) |length| {
            for (lengths[group][0..plan.alpha_size], 0..) |value, symbol| if (value == length) {
                codes[group][symbol] = code;
                code += 1;
            };
            code <<= 1;
        }
        try std.testing.expectEqualSlices(u32, plan.codes[group][0..plan.alpha_size], codes[group][0..plan.alpha_size]);
    }
    for (plan.selectors, 0..) |group, chunk| {
        const start = chunk * 50;
        for (symbols[start..@min(symbols.len, start + 50)]) |expected| {
            var prefix: u32 = 0;
            var decoded: ?usize = null;
            for (1..21) |length| {
                prefix = (prefix << 1) | try reader.readBit();
                for (lengths[group][0..plan.alpha_size], 0..) |value, symbol| {
                    if (value == length and codes[group][symbol] == prefix) {
                        decoded = symbol;
                        break;
                    }
                }
                if (decoded != null) break;
            }
            try std.testing.expectEqual(@as(?usize, expected), decoded);
        }
    }
    return reader.bit_offset;
}

fn check(plan: *const planner.Plan, symbols: []const u16) !void {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var writer = bit_writer.BitWriter.init(allocator, &encoded);
    try writer_mod.write(&writer, plan, symbols);
    const written_bits = encoded.items.len * 8 + writer.used;
    try std.testing.expectEqual(plan.bit_len, @as(u64, written_bits));
    try writer.finish();
    try std.testing.expectEqual(written_bits, try independentlyDecode(plan, symbols, encoded.items));
    try std.testing.expect(plan.group_count >= 2 and plan.group_count <= 6);
    for (0..plan.group_count) |group| {
        var kraft: u32 = 0;
        for (plan.lengths[group][0..plan.alpha_size]) |length| {
            try std.testing.expect(length >= 1 and length <= 20);
            kraft += @as(u32, 1) << @intCast(20 - length);
        }
        try std.testing.expect(kraft <= 1 << 20);
    }
}

fn fixedBits(symbol_count: usize, alpha_size: usize) u64 {
    var width: u64 = 1;
    while ((@as(u64, 1) << @intCast(width)) < alpha_size) width += 1;
    return 3 + 15 + (symbol_count + 49) / 50 + 2 * (5 + alpha_size) + symbol_count * width;
}

test "Bzip2 Huffman plan preserves exact wire costs and never exceeds fixed groups" {
    var seed: u64 = 0x62a735819caf0241;
    for ([_]usize{ 3, 7, 64, 258 }) |alpha_size| {
        for ([_]usize{ 1, 49, 50, 51, 99, 101, 1024, 4097 }) |size| {
            const symbols = try allocator.alloc(u16, size);
            defer allocator.free(symbols);
            for (symbols, 0..) |*symbol, index| {
                seed ^= seed >> 12;
                seed ^= seed << 25;
                seed ^= seed >> 27;
                symbol.* = @intCast(if (index % 5 == 0) 0 else (seed *% 0x2545f4914f6cdd1d) % alpha_size);
            }
            const plan = try planner.planAlloc(allocator, symbols, alpha_size);
            defer plan.deinit(allocator);
            try std.testing.expect(plan.bit_len <= fixedBits(size, alpha_size));
            try check(&plan, symbols);
            const repeated = try planner.planAlloc(allocator, symbols, alpha_size);
            defer repeated.deinit(allocator);
            try std.testing.expectEqual(plan.group_count, repeated.group_count);
            try std.testing.expectEqual(plan.bit_len, repeated.bit_len);
            try std.testing.expectEqualSlices(u8, plan.selectors, repeated.selectors);
            for (0..plan.group_count) |group|
                try std.testing.expectEqualSlices(u5, plan.lengths[group][0..alpha_size], repeated.lengths[group][0..alpha_size]);
        }
    }
}

test "Bzip2 Huffman plan models nonstationary chunks with multiple groups" {
    const symbols = try allocator.alloc(u16, 50 * 360);
    defer allocator.free(symbols);
    for (symbols, 0..) |*symbol, index| {
        const region = (index / 50) % 6;
        symbol.* = @intCast(region * 8 + if (index % 10 != 0) 0 else (index / 7) % 8);
    }
    const plan = try planner.planAlloc(allocator, symbols, 48);
    defer plan.deinit(allocator);
    try std.testing.expect(plan.group_count >= 3);
    try std.testing.expect(plan.bit_len < fixedBits(symbols.len, 48) / 2);
    try check(&plan, symbols);
}

test "Bzip2 Huffman writer handles all group counts MTF ranks and length deltas" {
    for (2..7) |group_count| {
        const selectors = try allocator.alloc(u8, group_count + 3);
        defer allocator.free(selectors);
        const symbols = try allocator.alloc(u16, selectors.len * 50 - 7);
        defer allocator.free(symbols);
        for (selectors, 0..) |*selector, index| selector.* = @intCast((group_count - 1 + index) % group_count);
        for (symbols, 0..) |*symbol, index| symbol.* = @intCast(index % 4);
        var plan: planner.Plan = .{
            .group_count = @intCast(group_count),
            .alpha_size = 4,
            .lengths = @splat(@splat(0)),
            .codes = @splat(@splat(0)),
            .selectors = selectors,
            .bit_len = 18,
        };
        for (0..group_count) |group| {
            const lengths: [4]u5 = if (group % 2 == 0) .{ 1, 3, 3, 2 } else .{ 2, 1, 3, 3 };
            const codes: [4]u32 = if (group % 2 == 0) .{ 0, 6, 7, 2 } else .{ 2, 0, 6, 7 };
            @memcpy(plan.lengths[group][0..4], &lengths);
            @memcpy(plan.codes[group][0..4], &codes);
            plan.bit_len += planner.tableBits(&lengths);
        }
        var order: [6]u8 = .{ 0, 1, 2, 3, 4, 5 };
        for (selectors, 0..) |group, chunk| {
            const rank = std.mem.indexOfScalar(u8, order[0..group_count], group).?;
            plan.bit_len += rank + 1;
            std.mem.copyBackwards(u8, order[1 .. rank + 1], order[0..rank]);
            order[0] = group;
            for (symbols[chunk * 50 .. @min(symbols.len, chunk * 50 + 50)]) |symbol|
                plan.bit_len += plan.lengths[group][symbol];
        }
        try check(&plan, symbols);
    }
}

test "Bzip2 Huffman plan validates before allocating and unwinds both selector allocations" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    for ([_]usize{ 0, 2, 259 }) |alpha_size|
        try std.testing.expectError(error.InvalidBzip2Stream, planner.planAlloc(failing.allocator(), &.{0}, alpha_size));
    try std.testing.expectError(error.InvalidBzip2Stream, planner.planAlloc(failing.allocator(), &.{}, 3));
    try std.testing.expectError(error.InvalidBzip2Stream, planner.planAlloc(failing.allocator(), &.{3}, 3));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    const Run = struct {
        fn run(a: std.mem.Allocator) !void {
            const plan = try planner.planAlloc(a, &.{ 0, 1, 2, 0, 0, 2 }, 3);
            defer plan.deinit(a);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Run.run, .{});
}

test "Bzip2 Huffman selector refinement prices MTF ties and removes an unused table" {
    var symbols: [100]u16 = @splat(2);
    @memset(symbols[0..50], 1);
    symbols[50] = 0;
    symbols[51] = 0;
    symbols[52] = 1;
    var selectors: [2]u8 = .{ 1, 0 };
    var scratch: [2]u8 = undefined;
    var plan: planner.Plan = .{
        .group_count = 2,
        .alpha_size = 4,
        .lengths = @splat(@splat(0)),
        .codes = undefined,
        .selectors = &selectors,
        .bit_len = 248,
    };
    @memcpy(plan.lengths[0][0..4], &[_]u5{ 1, 3, 3, 2 });
    @memcpy(plan.lengths[1][0..4], &[_]u5{ 2, 1, 3, 3 });
    // Chunk two costs 146 data bits in either table. Reusing table one saves
    // the MTF switch, then compacting the unused table saves the initial rank.
    planner.refineSelectors(&plan, &symbols, &scratch);
    try std.testing.expectEqual(@as(u64, 246), plan.bit_len);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, &selectors);
    try std.testing.expectEqualSlices(u5, &.{ 2, 1, 3, 3 }, plan.lengths[0][0..4]);
    try check(&plan, &symbols);
}

test "Bzip2 Huffman writer emits the largest complete 20-bit canonical codes" {
    var selectors: [1]u8 = .{0};
    const symbols = [_]u16{ 19, 20, 0, 1, 20 };
    var plan: planner.Plan = .{
        .group_count = 2,
        .alpha_size = 21,
        .lengths = @splat(@splat(0)),
        .codes = @splat(@splat(0)),
        .selectors = &selectors,
        .bit_len = 19,
    };
    for (0..2) |group| {
        for (0..19) |symbol| {
            const length: u5 = @intCast(symbol + 1);
            plan.lengths[group][symbol] = length;
            plan.codes[group][symbol] = (@as(u32, 1) << length) - 2;
        }
        plan.lengths[group][19] = 20;
        plan.lengths[group][20] = 20;
        plan.codes[group][19] = 0xffffe;
        plan.codes[group][20] = 0xfffff;
        plan.bit_len += planner.tableBits(plan.lengths[group][0..21]);
    }
    for (symbols) |symbol| plan.bit_len += plan.lengths[0][symbol];
    try check(&plan, &symbols);
}

test "Bzip2 Huffman strategies preserve ordered costs across chunk and training thresholds" {
    var seed: u64 = 0x62a735819caf0241;
    for ([_]usize{ 3, 4, 64, 258 }) |alpha_size| {
        for ([_]usize{ 2, 49, 50, 51, 199, 200, 599, 600, 1199, 1200, 2399, 2400, 4097 }) |size| {
            const symbols = try allocator.alloc(u16, size);
            defer allocator.free(symbols);
            for (symbols) |*symbol| {
                seed ^= seed >> 12;
                seed ^= seed << 25;
                seed ^= seed >> 27;
                symbol.* = @intCast((seed *% 0x2545f4914f6cdd1d) % alpha_size);
            }
            var previous = fixedBits(size, alpha_size);
            for ([_]planner.Strategy{ .fast, .balanced, .ratio }) |strategy| {
                const plan = try planner.planAllocWithStrategy(allocator, symbols, alpha_size, strategy);
                defer plan.deinit(allocator);
                try std.testing.expect(plan.bit_len <= previous);
                previous = plan.bit_len;
                try check(&plan, symbols);
            }
        }
    }
}

test "Bzip2 Huffman single-chunk and all-single frequencies have identical strategy plans" {
    var input: [258]u16 = undefined;
    for (&input, 0..) |*symbol, index| symbol.* = @intCast(index);
    for ([_][]const u16{ input[0..50], &input }) |symbols| {
        const fast = try planner.planAllocWithStrategy(allocator, symbols, 258, .fast);
        defer fast.deinit(allocator);
        for ([_]planner.Strategy{ .balanced, .ratio }) |strategy| {
            const trained = try planner.planAllocWithStrategy(allocator, symbols, 258, strategy);
            defer trained.deinit(allocator);
            try std.testing.expectEqual(fast.group_count, trained.group_count);
            try std.testing.expectEqual(fast.bit_len, trained.bit_len);
            try std.testing.expectEqualSlices(u8, fast.selectors, trained.selectors);
            for (0..fast.group_count) |group|
                try std.testing.expectEqualSlices(u5, fast.lengths[group][0..258], trained.lengths[group][0..258]);
        }
    }
}
