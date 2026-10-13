const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const literal_context = @import("literal_context.zig");

const min_literal_count: usize = 128;
const min_payload_savings_bits: u64 = 128;

/// One bounded two-tree literal-context proposal. The complete Brotli writer
/// still arbitrates this proposal by exact encoded byte length, so this module
/// only needs to reject clearly unprofitable histogram shapes.
pub const Candidate = struct {
    mode: u2,
    cutoff: u6,
    savings_bits: u64,
};

/// Evaluate all four RFC 7932 literal context modes. Each mode gets its best
/// contiguous two-tree partition across the complete 1...63 cutoff range.
/// Keeping the search in a separate noinline routine prevents the 64 KiB
/// context histogram from inflating the already large Brotli wire encoder
/// frame.
pub noinline fn choose(input: []const u8, commands: []const command_plan.Command) ?Candidate {
    var best: ?Candidate = null;
    for (0..4) |mode_value| {
        const candidate = chooseMode(input, commands, @intCast(mode_value)) orelse continue;
        if (best == null or candidate.savings_bits > best.?.savings_bits) best = candidate;
    }
    return best;
}

fn chooseMode(input: []const u8, commands: []const command_plan.Command, mode: u2) ?Candidate {
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
    if (savings < min_payload_savings_bits) return null;
    return .{ .mode = mode, .cutoff = best_cutoff, .savings_bits = savings };
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
    try std.testing.expect(candidate.cutoff > 0 and candidate.cutoff < 64);
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

test "literal context split can select every RFC mode" {
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
        const candidate = choose(input, commands) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(case.mode, candidate.mode);
    }
}
