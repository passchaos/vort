const classifier = @import("record_classifier.zig");
const abi = @import("record_optimal_abi.zig");
const std = @import("std");

const empty = std.math.maxInt(u32);

export fn vortBrStableFixedWidthRecord(input: [*]const u8, input_len: usize) callconv(.c) u8 {
    return @intFromBool(classifier.isStableFixedWidth(input[0..input_len]));
}

export fn vortBrRecordOptimalPlan(
    input_ptr: [*]const u8,
    input_len: usize,
    head_ptr: [*]u32,
    head_initialized_ptr: [*]u64,
    prev_ptr: [*]u32,
    costs_ptr: [*]u32,
    steps_ptr: [*]u32,
    tokens_ptr: [*]abi.Token,
    stats: *abi.Stats,
) callconv(.c) u8 {
    if (input_len < 4 * 1024 or input_len > 64 * 1024 or input_len > empty) return 0;
    const input = input_ptr[0..input_len];
    if (!classifier.isStableFixedWidth(input)) return 0;
    const head = head_ptr[0..abi.hash_head_len];
    const head_initialized = head_initialized_ptr[0..abi.hash_head_init_words];
    const prev = prev_ptr[0..input_len];
    const costs = costs_ptr[0 .. input_len + 1];
    const steps = steps_ptr[0..input_len];
    const tokens = tokens_ptr[0..input_len];
    @memset(head_initialized, 0);
    for (0..input_len) |position| {
        if (position + 3 > input_len) continue;
        const hash = hash3(input[position..][0..3]) & (abi.hash_head_len - 1);
        const mask = @as(u64, 1) << @intCast(hash & 63);
        const word = &head_initialized[hash / 64];
        prev[position] = if (word.* & mask == 0) empty else head[hash];
        head[hash] = @intCast(position);
        word.* |= mask;
    }

    const literal_cost: u32 = @intCast(alphabetWidthLiteralCost(input));
    costs[input_len] = 0;
    var position = input_len;
    while (position > 0) {
        position -= 1;
        costs[position] = literal_cost + costs[position + 1];
        steps[position] = 0;
        if (position + 4 > input_len) continue;
        const maximum = @min(abi.max_match_len, input_len - position);
        var best_choices: [abi.max_match_len + 1]u32 = undefined;
        var built_through: usize = 3;
        var chain = prev[position];
        var checked: usize = 0;
        var candidates_seen: usize = 0;
        while (chain != empty and checked < 256) : (checked += 1) {
            const candidate: usize = chain;
            const distance = position - candidate;
            if (distance == 0 or distance > 32 * 1024) break;
            if (std.mem.readInt(u32, input[candidate..][0..4], .little) != std.mem.readInt(u32, input[position..][0..4], .little)) {
                chain = prev[candidate];
                continue;
            }
            const distance_cost = fixedDistanceCost(distance);
            if (built_through >= 4 and built_through < maximum and
                input[candidate + built_through] != input[position + built_through] and
                choiceCost(best_choices[built_through]) + distance_cost >= costs[position])
            {
                candidates_seen += 1;
                if (candidates_seen >= 128) break;
                chain = prev[candidate];
                continue;
            }
            const length = matchLength(input, candidate, position, maximum);
            if (length >= 4) {
                extendLengthChoices(costs, position, built_through, length, &best_choices);
                built_through = @max(built_through, length);
                const choice = best_choices[length];
                const cost: u32 = choiceCost(choice) + @as(u32, @intCast(distance_cost));
                if (cost < costs[position]) {
                    costs[position] = cost;
                    steps[position] = (@as(u32, choiceLength(choice)) << 16) | @as(u32, @intCast(distance));
                }
                candidates_seen += 1;
                if (length == maximum or candidates_seen >= 128) break;
            }
            chain = prev[candidate];
        }
    }

    stats.* = .{};
    position = 0;
    while (position < input_len) {
        const step = steps[position];
        if (step == 0) {
            tokens[stats.token_count] = .{ .kind = 0, .literal = input[position], .length = 0, .distance = 0 };
            stats.literal_count += 1;
            position += 1;
        } else {
            const length: u16 = @intCast(step >> 16);
            const distance: u16 = @truncate(step);
            tokens[stats.token_count] = .{ .kind = 1, .literal = 0, .length = length, .distance = distance };
            stats.match_count += 1;
            stats.matched_bytes += length;
            position += length;
        }
        stats.token_count += 1;
    }
    return 1;
}

/// Preserve the chosen literal/match boundaries while replacing a copy with
/// the current last distance when it reproduces the same bytes. This is a
/// single forward pass with no additional state allocation.
export fn vortBrRefineRecordDistances(input_ptr: [*]const u8, input_len: usize, tokens_ptr: [*]abi.Token, token_count: usize) callconv(.c) u8 {
    if (token_count == 0 or token_count > input_len) return 0;
    const input = input_ptr[0..input_len];
    const tokens = tokens_ptr[0..token_count];
    var rep0: u16 = 4;
    var input_position: usize = 0;
    for (tokens) |*token| {
        if (token.kind == 0) {
            if (input_position >= input_len or token.literal != input[input_position]) return 0;
            input_position += 1;
            continue;
        }
        if (token.kind != 1 or token.length < 4 or token.distance == 0 or token.distance > input_position or input_position + token.length > input_len) return 0;
        if (rep0 <= input_position and rep0 <= 32 * 1024 and rep0 != token.distance and matchLength(input, input_position - rep0, input_position, token.length) == token.length)
            token.distance = rep0
        else if (token.distance != rep0)
            rep0 = token.distance;
        input_position += token.length;
    }
    return @intFromBool(input_position == input_len);
}

fn extendLengthChoices(costs: []const u32, position: usize, built_through: usize, maximum: usize, best_choices: *[abi.max_match_len + 1]u32) void {
    var best_choice = if (built_through >= 4) best_choices[built_through] else std.math.maxInt(u32);
    var length = @max(@as(usize, 4), built_through + 1);
    while (length <= maximum) : (length += 1) {
        const choice = (@as(u32, @intCast(fixedLengthCost(length) + costs[position + length])) << 9) | @as(u32, @intCast(abi.max_match_len - length));
        if (choice < best_choice) best_choice = choice;
        best_choices[length] = best_choice;
    }
}

inline fn choiceCost(choice: u32) u32 {
    return choice >> 9;
}

inline fn choiceLength(choice: u32) u16 {
    return @intCast(abi.max_match_len - (choice & 0x1ff));
}

fn alphabetWidthLiteralCost(input: []const u8) usize {
    var seen: [4]u64 = @splat(0);
    for (input) |byte| seen[byte >> 6] |= @as(u64, 1) << @intCast(byte & 63);
    var distinct: usize = 0;
    for (seen) |word| distinct += @popCount(word);
    return @max(@as(usize, 1), std.math.log2_int_ceil(usize, distinct));
}

fn hash3(bytes: *const [3]u8) usize {
    const value = (@as(usize, bytes[0]) << 16) | (@as(usize, bytes[1]) << 8) | bytes[2];
    return (value *% 2654435761) >> 16;
}

fn matchLength(input: []const u8, left_start: usize, right_start: usize, maximum: usize) usize {
    var length: usize = 0;
    while (length + 32 <= maximum) : (length += 32) {
        const left: @Vector(32, u8) = input[left_start + length ..][0..32].*;
        const right: @Vector(32, u8) = input[right_start + length ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return length + @ctz(differing);
    }
    while (length + 8 <= maximum) : (length += 8) {
        const left = std.mem.readInt(u64, input[left_start + length ..][0..8], .little);
        const right = std.mem.readInt(u64, input[right_start + length ..][0..8], .little);
        if (left != right) return length + @ctz(left ^ right) / 8;
    }
    while (length < maximum and input[left_start + length] == input[right_start + length]) length += 1;
    return length;
}

fn fixedLengthCost(length: usize) usize {
    if (length <= 10) return 7;
    if (length <= 18) return 8;
    if (length <= 34) return 9;
    if (length <= 66) return 10;
    if (length <= 130) return 11;
    if (length <= 257) return 12;
    return 8;
}

fn fixedDistanceCost(distance: usize) usize {
    if (distance <= 4) return 5;
    return 4 + std.math.log2_int(usize, distance - 1);
}

test "rep0 refinement preserves token boundaries" {
    const input = "abcdabcdabcd";
    var tokens = [_]abi.Token{
        .{ .kind = 0, .literal = 'a', .length = 0, .distance = 0 },
        .{ .kind = 0, .literal = 'b', .length = 0, .distance = 0 },
        .{ .kind = 0, .literal = 'c', .length = 0, .distance = 0 },
        .{ .kind = 0, .literal = 'd', .length = 0, .distance = 0 },
        .{ .kind = 1, .literal = 0, .length = 4, .distance = 4 },
        .{ .kind = 1, .literal = 0, .length = 4, .distance = 8 },
    };
    try std.testing.expectEqual(@as(u8, 1), vortBrRefineRecordDistances(input.ptr, input.len, &tokens, tokens.len));
    try std.testing.expectEqual(@as(u16, 4), tokens[5].distance);
    try std.testing.expectEqual(@as(u16, 4), tokens[5].length);
}

test "rep0 refinement keeps a non-equivalent distance" {
    const input = "abcdefghabcdefg";
    var tokens: [9]abi.Token = undefined;
    for (input[0..8], 0..) |byte, index| tokens[index] = .{ .kind = 0, .literal = byte, .length = 0, .distance = 0 };
    tokens[8] = .{ .kind = 1, .literal = 0, .length = 7, .distance = 8 };
    tokens[0].literal = 'a';
    try std.testing.expectEqual(@as(u8, 1), vortBrRefineRecordDistances(input.ptr, input.len, &tokens, tokens.len));
    try std.testing.expectEqual(@as(u16, 8), tokens[8].distance);
}

test "rep0 refinement rejects literal mismatch" {
    const input = "abcd";
    var tokens = [_]abi.Token{
        .{ .kind = 0, .literal = 'x', .length = 0, .distance = 0 },
    };
    try std.testing.expectEqual(@as(u8, 0), vortBrRefineRecordDistances(input.ptr, input.len, &tokens, tokens.len));
}
