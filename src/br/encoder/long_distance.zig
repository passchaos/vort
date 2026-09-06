const std = @import("std");
const command_plan = @import("command_plan.zig");

pub const min_distance: usize = (@as(usize, 1) << 16) - 16 + 1;
pub const max_distance: usize = (@as(usize, 1) << 17) - 16;
const max_dense_distance: usize = (@as(usize, 1) << 20) - 16;
pub const max_configurable_distance: usize = (@as(usize, 1) << 23) - 16;
const chain_limit = 512;
const min_match = 16;
const max_match = 258;
const hash_size = 1 << 15;
// Delaying each hash insertion until it reaches min_distance lets the
// predecessor ring cover only the requested long-distance band rather than the
// complete Brotli window.

/// Insert Brotli-only long matches into literal runs left by the shared 16-bit
/// LZ77 planner. Existing copies are preserved verbatim; rebuilding absolute
/// insert offsets keeps the command stream independently verifiable.
pub fn augmentAlloc(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !?[]command_plan.Command {
    return augmentAllocWithStride(1, allocator, input, commands, max_distance);
}

/// Extend the shared 16-bit command plan with matches up to
/// `max_backward_distance`. The predecessor ring covers the exact active
/// distance band rounded to a power of two, retaining the compact 64 KiB ring
/// for the default 17-bit path while allowing explicitly larger Brotli windows.
pub fn augmentAllocWithMaxDistance(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, max_backward_distance: usize) !?[]command_plan.Command {
    if (max_backward_distance < min_distance or max_backward_distance > max_configurable_distance)
        return error.InvalidBlockPlan;
    if (max_backward_distance <= max_dense_distance)
        return augmentAllocWithStride(1, allocator, input, commands, max_backward_distance);
    if (max_backward_distance <= (@as(usize, 1) << 21) - 16)
        return augmentAllocWithStride(2, allocator, input, commands, max_backward_distance);
    if (max_backward_distance <= (@as(usize, 1) << 22) - 16)
        return augmentAllocWithStride(4, allocator, input, commands, max_backward_distance);
    return augmentAllocWithStride(8, allocator, input, commands, max_backward_distance);
}

fn augmentAllocWithStride(comptime stride: usize, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, max_backward_distance: usize) !?[]command_plan.Command {
    if (input.len <= min_distance or commands.len == 0) return null;
    const head = try allocator.alloc(i32, hash_size);
    defer allocator.free(head);
    @memset(head, -1);
    const active_distance_count = max_backward_distance - min_distance + 1;
    const sampled_distance_count = (active_distance_count + stride - 1) / stride;
    const prev_len = std.math.ceilPowerOfTwo(usize, sampled_distance_count) catch return error.InvalidBlockPlan;
    const prev = try allocator.alloc(i32, prev_len);
    defer allocator.free(prev);
    const prev_mask = prev.len - 1;

    var output: std.ArrayList(command_plan.Command) = .empty;
    errdefer output.deinit(allocator);
    var found = false;
    var position: usize = 0;
    var indexed_through: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    for (commands) |command| {
        if (command.insert_start != position) return error.InvalidBlockPlan;
        const literal_end = position + command.insert_len;
        while (position < literal_end) {
            // The shared parser already considered nearer matches. Index only
            // positions that have just entered this pass's non-overlapping
            // distance band, so near hash collisions cannot consume its chain
            // budget before a useful long-distance candidate is reached.
            while (indexed_through + min_distance <= position) : (indexed_through += stride)
                insert(stride, input, indexed_through, head, prev, prev_mask);
            const match = find(stride, input, position, literal_end - position, head, prev, prev_mask, max_backward_distance);
            if (match.length >= min_match) {
                try appendCopy(&output, allocator, insert_start, insert_len, match.length, match.distance);
                found = true;
                position += match.length;
                insert_start = position;
                insert_len = 0;
            } else {
                position += 1;
                insert_len += 1;
            }
        }
        if (!command.has_copy) continue;
        try appendCopy(&output, allocator, insert_start, insert_len, command.copy_len, command.distance);
        position += command.copy_len;
        insert_start = position;
        insert_len = 0;
    }
    if (position != input.len) return error.InvalidBlockPlan;
    if (insert_len != 0) try output.append(allocator, .{ .insert_start = insert_start, .insert_len = insert_len });
    if (!found) {
        output.deinit(allocator);
        return null;
    }
    return try output.toOwnedSlice(allocator);
}

const Match = struct { length: usize = 0, distance: usize = 0 };

fn find(comptime stride: usize, input: []const u8, position: usize, available: usize, head: []const i32, prev: []const i32, prev_mask: usize, max_backward_distance: usize) Match {
    if (available < min_match or position + 4 > input.len) return .{};
    var candidate_i = head[hash(input[position..][0..4])];
    var checked: usize = 0;
    var best = Match{};
    const limit = @min(available, max_match);
    while (candidate_i >= 0 and checked < chain_limit) : (checked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = position - candidate;
        if (distance > max_backward_distance) break;
        if (input[candidate + best.length] == input[position + best.length]) {
            var length: usize = 0;
            while (length < limit and input[candidate + length] == input[position + length]) : (length += 1) {}
            if (length > best.length) best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate_i = prev[(candidate / stride) & prev_mask];
    }
    return best;
}

fn insert(comptime stride: usize, input: []const u8, position: usize, head: []i32, prev: []i32, prev_mask: usize) void {
    if (position + 4 > input.len) return;
    const slot = hash(input[position..][0..4]);
    prev[(position / stride) & prev_mask] = head[slot];
    head[slot] = @intCast(position);
}

fn hash(bytes: *const [4]u8) usize {
    return (std.mem.readInt(u32, bytes, .little) *% 0x9e37_79b1) >> 17;
}

fn appendCopy(output: *std.ArrayList(command_plan.Command), allocator: std.mem.Allocator, insert_start: usize, insert_len: usize, copy_len: usize, distance: usize) !void {
    if (insert_len == 0 and output.items.len != 0) {
        const previous = &output.items[output.items.len - 1];
        if (previous.has_copy and previous.dictionary_output_len == 0 and previous.distance == distance) {
            previous.copy_len = std.math.add(usize, previous.copy_len, copy_len) catch return error.IntegerOverflow;
            return;
        }
    }
    try output.append(allocator, .{ .insert_start = insert_start, .insert_len = insert_len, .copy_len = copy_len, .distance = distance, .has_copy = true });
}

test "augments literal runs with Brotli-only long matches" {
    const gap = 80 * 1024;
    const repeated_len = 1024;
    const input = try std.testing.allocator.alloc(u8, gap + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x1234_5678;
    for (input[0..gap]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[gap..], input[0..repeated_len]);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAlloc(std.testing.allocator, input, &original) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command| {
        if (command.has_copy and command.distance == gap) found = true;
    }
    try std.testing.expect(found);
}

test "near hash collisions do not hide eligible long matches" {
    const match_position = 70 * 1024;
    const phrase = "long-distance-key";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x51ed_270b;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[0..phrase.len], phrase);
    // These candidates share the four-byte hash but are all too near for this
    // pass. A chain containing them would exhaust the bounded search before it
    // reached the valid position-zero match.
    var position = match_position - min_distance + 8;
    while (position + phrase.len < match_position) : (position += 16) {
        @memcpy(input[position..][0..4], phrase[0..4]);
        input[position + 4] = phrase[4] ^ 0xff;
    }
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAlloc(std.testing.allocator, input, &original) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command| {
        if (command.has_copy and command.distance == match_position and command.copy_len == phrase.len) found = true;
    }
    try std.testing.expect(found);
}

test "configurable matcher covers exact 18 through 23-bit distance limits" {
    inline for (.{ (@as(usize, 1) << 18) - 16, (@as(usize, 1) << 19) - 16, (@as(usize, 1) << 20) - 16, (@as(usize, 1) << 21) - 16, (@as(usize, 1) << 22) - 16, max_configurable_distance }) |match_position| {
        try expectConfigurableDistanceMatch(match_position, match_position);
    }
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = min_distance + 1 }};
    const input = [_]u8{0} ** (min_distance + 1);
    try std.testing.expectError(error.InvalidBlockPlan, augmentAllocWithMaxDistance(std.testing.allocator, &input, &original, max_configurable_distance + 1));
}

test "sparse matcher advances to the sampled source phase" {
    const match_position = 1280 * 1024 + 1;
    const phrase = "xconfigurable-long-distance-match";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x51a7_21b5;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[1..][0..phrase.len], phrase);
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAllocWithMaxDistance(std.testing.allocator, input, &original, (@as(usize, 1) << 21) - 16) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command|
        if (command.has_copy and command.distance == match_position - 1 and command.copy_len == phrase.len - 1) {
            found = true;
        };
    try std.testing.expect(found);
}

test "stride-four matcher advances through the worst source phase" {
    const match_position = 2560 * 1024 + 3;
    const phrase = "xyzconfigurable-long-distance-match";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x5221_1eaf;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[1..][0..phrase.len], phrase);
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAllocWithMaxDistance(std.testing.allocator, input, &original, (@as(usize, 1) << 22) - 16) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command|
        if (command.has_copy and command.distance == match_position - 1 and command.copy_len == phrase.len - 3) {
            found = true;
        };
    try std.testing.expect(found);
}

test "stride-eight matcher advances through the worst source phase" {
    const match_position = 5 * 1024 * 1024 + 7;
    const phrase = "1234567configurable-long-distance-match";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x5238_1eaf;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[1..][0..phrase.len], phrase);
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAllocWithMaxDistance(std.testing.allocator, input, &original, (@as(usize, 1) << 23) - 16) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command|
        if (command.has_copy and command.distance == match_position - 1 and command.copy_len == phrase.len - 7) {
            found = true;
        };
    try std.testing.expect(found);
}

fn expectConfigurableDistanceMatch(match_position: usize, max_backward_distance: usize) !void {
    const phrase = "configurable-long-distance-match";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x8bad_f00d;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[0..phrase.len], phrase);
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    try std.testing.expect((try augmentAlloc(std.testing.allocator, input, &original)) == null);
    const augmented = try augmentAllocWithMaxDistance(std.testing.allocator, input, &original, max_backward_distance) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command|
        if (command.has_copy and command.distance == match_position and command.copy_len == phrase.len) {
            found = true;
        };
    try std.testing.expect(found);
}
