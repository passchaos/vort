//! Compare every proposal field and independently reconstruct its weighted
//! payload cost from command insert spans. The caller injects the splitter;
//! there is no reverse import or dependency on its interval-cache helpers.
const std = @import("std");
const huffman = @import("../../../huffman.zig");
const command_plan = @import("../command_plan.zig");
const literal_context = @import("../literal_context.zig");

const names = [_][]const u8{ "two", "three", "clustered", "alternating_four", "reuse_first_four", "four", "dynamic" };
const cutoffs = [_]?u6{ null, 8, 32, 63 };
const Coverage = struct {
    cases: usize = 0,
    empty: usize = 0,
    invalid: usize = 0,
    fragmented: usize = 0,
    proposals: [names.len]usize = @splat(0),
};

fn weightedCost(frequencies: *const [256]u32) u64 {
    const lengths = huffman.treeCodeLengths(256, frequencies, 15);
    var total: u64 = 0;
    for (frequencies, lengths) |frequency, bits| total += @as(u64, frequency) * bits;
    return total;
}

fn admittedCount(input: []const u8, commands: []const command_plan.Command) ?usize {
    var total: usize = 0;
    for (commands) |command| {
        if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start) return null;
        total = std.math.add(usize, total, command.insert_len) catch return null;
    }
    return total;
}

fn baselineCost(input: []const u8, commands: []const command_plan.Command, cutoff: ?u6) u64 {
    var histograms: [2][256]u32 = @splat(@splat(0));
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |literal, position| {
            const tree: usize = if (cutoff) |value| blk: {
                const previous = if (position == 0) 0 else input[position - 1];
                const second_previous = if (position < 2) 0 else input[position - 2];
                const context = literal_context.value(literal_context.mode_utf8, previous, second_previous);
                break :blk literal_context.utf8SuffixTree(context, value);
            } else 0;
            histograms[tree][literal] += 1;
        }
    }
    return weightedCost(&histograms[0]) + weightedCost(&histograms[1]);
}

fn validTarget(total: usize, target: usize) bool {
    if (target < 512 or total - target < 512) return false;
    return target == total / 6 or target == total / 4 or target == total / 3 or
        target == total / 2 or target == total * 2 / 3 or target == total * 3 / 4 or target == total * 5 / 6;
}

fn validateProposal(comptime Splitter: type, proposal: Splitter.Result, input: []const u8, commands: []const command_plan.Command, total: usize, baseline: u64) !void {
    const regions = proposal.regionCount();
    const types = proposal.typeCount();
    try std.testing.expect(regions >= 2 and regions <= Splitter.max_regions);
    try std.testing.expect(types >= 2 and types <= regions);
    try std.testing.expectEqual(regions >= 3, proposal.second_split != null);
    try std.testing.expectEqual(regions >= 4, proposal.third_split != null);
    try std.testing.expectEqual(regions >= 5, proposal.fourth_split != null);
    try std.testing.expectEqual(regions >= 6, proposal.fifth_split != null);
    try std.testing.expect(!(proposal.alternate_two_types and proposal.reuse_first_for_fourth));
    var previous: usize = 0;
    for (0..regions - 1) |region| {
        const boundary = proposal.boundary(region);
        try std.testing.expect(boundary > previous and boundary < total);
        try std.testing.expect(boundary - previous >= 512);
        try std.testing.expect(validTarget(total, boundary));
        try std.testing.expectEqual(region % types, proposal.blockIndex(previous));
        try std.testing.expectEqual(region % types, proposal.blockIndex(boundary - 1));
        try std.testing.expectEqual((region + 1) % types, proposal.blockIndex(boundary));
        previous = boundary;
    }
    try std.testing.expect(total - previous >= 512);
    try std.testing.expectEqual((regions - 1) % types, proposal.blockIndex(total - 1));

    var pooled: [Splitter.max_regions][256]u32 = @splat(@splat(0));
    var literal_index: usize = 0;
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len]) |literal| {
            pooled[proposal.blockIndex(literal_index)][literal] += 1;
            literal_index += 1;
        }
    }
    try std.testing.expectEqual(total, literal_index);
    var split_cost: u64 = 0;
    for (pooled[0..types]) |*frequencies| split_cost += weightedCost(frequencies);
    try std.testing.expect(split_cost < baseline);
    try std.testing.expectEqual(baseline - split_cost, proposal.savings_bits);
    try std.testing.expect(proposal.savings_bits >= 2048);
}

fn run(comptime Splitter: type, input: []const u8, commands: []const command_plan.Command, cutoff: ?u6, coverage: *Coverage) !Splitter.Proposals {
    const expected = Splitter.chooseProposalsReference(input, commands, cutoff);
    const actual = Splitter.chooseProposals(input, commands, cutoff);
    try std.testing.expectEqualDeep(expected, actual);
    coverage.cases += 1;
    const count = admittedCount(input, commands);
    if (count == null or count.? < 1024 or count.? > 32768) {
        try std.testing.expectEqualDeep(Splitter.Proposals{}, actual);
        if (count == null) coverage.invalid += 1;
        coverage.empty += 1;
        return actual;
    }
    const baseline = baselineCost(input, commands, cutoff);
    var active: usize = 0;
    inline for (names, 0..) |name, index| {
        if (@field(actual, name)) |proposal| {
            try validateProposal(Splitter, proposal, input, commands, count.?, baseline);
            coverage.proposals[index] += 1;
            active += 1;
        }
    }
    if (active == 0) coverage.empty += 1;
    return actual;
}

const Fragmented = struct {
    storage: []u8,
    input: []const u8,
    commands: std.ArrayList(command_plan.Command),

    fn deinit(self: *Fragmented) void {
        self.commands.deinit(std.testing.allocator);
        std.testing.allocator.free(self.storage);
    }
};

fn fragment(literals: []const u8, random: std.Random) !Fragmented {
    const storage = try std.testing.allocator.alloc(u8, literals.len * 2 + 64);
    errdefer std.testing.allocator.free(storage);
    var commands: std.ArrayList(command_plan.Command) = .empty;
    errdefer commands.deinit(std.testing.allocator);
    var position: usize = 0;
    var literal_index: usize = 0;
    var span: usize = 0;
    while (literal_index < literals.len) : (span += 1) {
        // Empty inserts share physical endpoints. Each nonempty span may
        // cross a proposal boundary, and copies leave real history gaps.
        if (span % 3 == 0) try commands.append(std.testing.allocator, .{ .insert_start = position, .insert_len = 0 });
        const count = @min(literals.len - literal_index, random.intRangeAtMost(usize, 17, 257));
        @memcpy(storage[position..][0..count], literals[literal_index..][0..count]);
        const gap = if (literal_index + count == literals.len) 0 else random.intRangeAtMost(usize, 2, 11);
        try commands.append(std.testing.allocator, .{
            .insert_start = position,
            .insert_len = count,
            .has_copy = gap != 0,
            .copy_len = gap,
            .distance = 1,
        });
        position += count;
        if (gap != 0) @memset(storage[position..][0..gap], storage[position - 1]);
        position += gap;
        literal_index += count;
    }
    try commands.append(std.testing.allocator, .{ .insert_start = position, .insert_len = 0 });
    return .{ .storage = storage, .input = storage[0..position], .commands = commands };
}

fn lengthAndEarlyCases(comptime Splitter: type, coverage: *Coverage) !void {
    for ([_]usize{ 0, 1, 11, 1023, 1024, 3072, 4096, 8192, 32768, 32769 }) |length| {
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = length }};
        for (input, 0..) |*byte, index| byte.* = @intCast(index & 31);
        for (cutoffs) |cutoff| {
            const stationary = try run(Splitter, input, &commands, cutoff, coverage);
            try std.testing.expectEqualDeep(Splitter.Proposals{}, stationary);
        }
        for (input, 0..) |*byte, index| byte.* = @intCast((if (index < length / 2) @as(usize, 0) else 240) + (index & 15));
        for (cutoffs) |cutoff| _ = try run(Splitter, input, &commands, cutoff, coverage);
    }
}

fn proposalCases(comptime Splitter: type, random: std.Random, coverage: *Coverage) !void {
    const patterns = [_]struct { length: usize, boundaries: []const usize, types: []const u8, expected: []const u8 }{
        .{ .length = 4096, .boundaries = &.{2048}, .types = &.{ 0, 15 }, .expected = "two" },
        .{ .length = 6144, .boundaries = &.{ 2048, 4096 }, .types = &.{ 0, 7, 15 }, .expected = "three" },
        .{ .length = 6144, .boundaries = &.{ 2048, 4096 }, .types = &.{ 0, 15, 0 }, .expected = "clustered" },
        .{ .length = 8192, .boundaries = &.{ 2048, 4096, 6144 }, .types = &.{ 0, 15, 0, 15 }, .expected = "alternating_four" },
        .{ .length = 8192, .boundaries = &.{ 2048, 4096, 6144 }, .types = &.{ 0, 7, 15, 0 }, .expected = "reuse_first_four" },
        .{ .length = 8192, .boundaries = &.{ 2048, 4096, 6144 }, .types = &.{ 0, 5, 10, 15 }, .expected = "four" },
        .{ .length = 12288, .boundaries = &.{ 2048, 4096, 6144, 8192 }, .types = &.{ 0, 3, 6, 9, 12 }, .expected = "dynamic" },
        .{ .length = 12288, .boundaries = &.{ 2048, 4096, 6144, 8192, 10240 }, .types = &.{ 0, 6, 12, 0, 6, 12 }, .expected = "dynamic" },
    };
    for (patterns) |pattern| {
        const input = try std.testing.allocator.alloc(u8, pattern.length);
        defer std.testing.allocator.free(input);
        var region: usize = 0;
        for (input, 0..) |*byte, index| {
            if (region < pattern.boundaries.len and index == pattern.boundaries[region]) region += 1;
            byte.* = pattern.types[region] * 16 + @as(u8, @intCast(index & 15));
        }
        const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
        const direct = try run(Splitter, input, &commands, null, coverage);
        inline for (names) |name| {
            if (std.mem.eql(u8, pattern.expected, name)) try std.testing.expect(@field(direct, name) != null);
        }
        var pieces = try fragment(input, random);
        defer pieces.deinit();
        for (cutoffs) |cutoff| {
            const actual = try run(Splitter, pieces.input, pieces.commands.items, cutoff, coverage);
            if (cutoff == null) try std.testing.expectEqualDeep(direct, actual);
            coverage.fragmented += 1;
        }
    }
}

fn tieCases(comptime Splitter: type, random: std.Random, coverage: *Coverage) !void {
    var input: [3072]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast(index / 1024);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const first = try run(Splitter, &input, &commands, null, coverage);
    const two = first.two orelse return error.TestUnexpectedResult;
    // Splits 1024 and 2048 have identical entropy and payload costs. Strict
    // traversal ties retain the first candidate, with exactly 2048 bits saved.
    try std.testing.expectEqual(@as(usize, 1024), two.split);
    try std.testing.expectEqual(@as(u64, 2048), two.savings_bits);
    var pieces = try fragment(&input, random);
    defer pieces.deinit();
    const fragmented = try run(Splitter, pieces.input, pieces.commands.items, null, coverage);
    try std.testing.expectEqualDeep(first, fragmented);
    coverage.fragmented += 1;
}

fn randomCases(comptime Splitter: type, random: std.Random, coverage: *Coverage) !void {
    for (0..24) |round| {
        const length = ([_]usize{ 3072, 4096, 8192, 12288, 32768 })[round % 5];
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        const regions = random.intRangeAtMost(usize, 2, 6);
        const types = random.intRangeAtMost(usize, 2, regions);
        for (input, 0..) |*byte, index| {
            const region = @min(regions - 1, index * regions / length);
            const base = (region % types) * 40;
            byte.* = @intCast(base + random.uintLessThan(usize, 17));
        }
        var pieces = try fragment(input, random);
        defer pieces.deinit();
        _ = try run(Splitter, pieces.input, pieces.commands.items, cutoffs[round % cutoffs.len], coverage);
        coverage.fragmented += 1;
        if (round % 4 == 0) {
            pieces.commands.items[pieces.commands.items.len - 1].insert_start = pieces.input.len + 1;
            const invalid = try run(Splitter, pieces.input, pieces.commands.items, cutoffs[round % cutoffs.len], coverage);
            try std.testing.expectEqualDeep(Splitter.Proposals{}, invalid);
        }
    }
}

fn invalidCases(comptime Splitter: type, coverage: *Coverage) !void {
    const input = [_]u8{7} ** 4096;
    const commands = [_]command_plan.Command{
        .{ .insert_start = input.len + 1, .insert_len = 0 },
        .{ .insert_start = 0, .insert_len = input.len + 1 },
        .{ .insert_start = input.len, .insert_len = 1 },
        .{ .insert_start = input.len - 1, .insert_len = 2 },
        .{ .insert_start = std.math.maxInt(usize), .insert_len = 0 },
        .{ .insert_start = 1, .insert_len = std.math.maxInt(usize) },
    };
    for (commands) |command| {
        for (cutoffs) |cutoff| _ = try run(Splitter, &input, &.{command}, cutoff, coverage);
    }
    // Valid repeated spans can exceed the literal-work admission ceiling.
    const repeated = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }} ** 9;
    _ = try run(Splitter, &input, &repeated, null, coverage);
    _ = try run(Splitter, &input, &.{.{ .insert_start = input.len, .insert_len = 0 }}, null, coverage);
    _ = try run(Splitter, &input, &.{}, null, coverage);
}

fn resourceCase(comptime Splitter: type, coverage: *Coverage) !void {
    const input = "a" ** 1024 ++ "b" ** 1024 ++ "c" ** 1024;
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    // Actual proposal evaluation at comptime rules out hidden runtime-only
    // allocation in both paths. Only scalar Result fields leave this block.
    const evaluated = comptime blk: {
        @setEvalBranchQuota(20_000_000);
        const cached = Splitter.chooseProposals(input, &commands, null);
        const reference = Splitter.chooseProposalsReference(input, &commands, null);
        if (!std.meta.eql(cached, reference)) @compileError("comptime interval proposal mismatch");
        break :blk cached;
    };
    const actual = try run(Splitter, input, &commands, null, coverage);
    try std.testing.expectEqualDeep(evaluated, actual);
    try std.testing.expectEqual(@as(usize, 1024), actual.two.?.split);
}

pub fn check(comptime Splitter: type) !void {
    var prng = std.Random.DefaultPrng.init(0x6272_696e_7465_7276);
    const random = prng.random();
    var coverage: Coverage = .{};
    try lengthAndEarlyCases(Splitter, &coverage);
    try proposalCases(Splitter, random, &coverage);
    try tieCases(Splitter, random, &coverage);
    try randomCases(Splitter, random, &coverage);
    try invalidCases(Splitter, &coverage);
    try resourceCase(Splitter, &coverage);
    for (coverage.proposals) |count| try std.testing.expect(count != 0);
    std.debug.print("br_interval cases={d} empty={d} invalid={d} fragmented={d} proposals(two/three/clustered/alternating/reuse/four/dynamic)={any}\n", .{
        coverage.cases, coverage.empty, coverage.invalid, coverage.fragmented, coverage.proposals,
    });
}
