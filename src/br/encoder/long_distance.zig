const std = @import("std");
const command_plan = @import("command_plan.zig");
const encoder_distance = @import("distance.zig");

pub const min_distance: usize = (@as(usize, 1) << 16) - 16 + 1;
pub const max_distance: usize = (@as(usize, 1) << 17) - 16;
const max_dense_distance: usize = (@as(usize, 1) << 20) - 16;
pub const max_configurable_distance: usize = (@as(usize, 1) << 24) - 16;
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
    return augmentAllocWithStride(1, allocator, "", input, commands, max_distance);
}

/// Extend the shared 16-bit command plan with matches up to
/// `max_backward_distance`. The predecessor ring covers the exact active
/// distance band rounded to a power of two, retaining the compact 64 KiB ring
/// for the default 17-bit path while allowing explicitly larger Brotli windows.
pub fn augmentAllocWithMaxDistance(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, max_backward_distance: usize) !?[]command_plan.Command {
    return augmentAllocWithHistoryAndMaxDistance(
        allocator,
        "",
        input,
        commands,
        max_backward_distance,
    );
}

pub fn augmentAllocWithMaxDistanceForFormat(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, max_backward_distance: usize, format: encoder_distance.Format) !?[]command_plan.Command {
    return augmentAllocWithHistoryAndMaxDistanceForFormat(allocator, "", input, commands, max_backward_distance, format);
}

/// Extend a block-local command plan with matches into retained bytes from the
/// same Brotli stream. `history` must be the suffix immediately preceding
/// `input`; bytes older than `max_backward_distance` are ignored. The returned
/// commands keep input-relative insert offsets while their copy distances span
/// the combined history/input view.
pub fn augmentAllocWithHistoryAndMaxDistance(
    allocator: std.mem.Allocator,
    history: []const u8,
    input: []const u8,
    commands: []const command_plan.Command,
    max_backward_distance: usize,
) !?[]command_plan.Command {
    return augmentAllocWithHistoryAndMaxDistanceForFormat(allocator, history, input, commands, max_backward_distance, .standard);
}

/// Large Window accepts the advertised safe distance, then sizes the existing
/// sampled predecessor ring from actual reachable input/history. Standard
/// calls retain their prior validation and sampling exactly.
pub fn augmentAllocWithHistoryAndMaxDistanceForFormat(
    allocator: std.mem.Allocator,
    history: []const u8,
    input: []const u8,
    commands: []const command_plan.Command,
    max_backward_distance: usize,
    format: encoder_distance.Format,
) !?[]command_plan.Command {
    const limit = if (format == .standard) max_configurable_distance else encoder_distance.safe_max_distance;
    if (max_backward_distance < min_distance or max_backward_distance > limit)
        return error.InvalidBlockPlan;
    const active_history = history[history.len - @min(history.len, max_backward_distance) ..];
    const combined_len = std.math.add(usize, active_history.len, input.len) catch
        return error.IntegerOverflow;
    if (format == .large_window and combined_len > std.math.maxInt(i32))
        return error.InvalidBlockPlan;
    if (input.len < min_match or combined_len - min_match < min_distance or
        commands.len == 0)
    {
        return null;
    }
    const reachable_max_distance = @min(
        max_backward_distance,
        combined_len - min_match,
    );
    if (reachable_max_distance <= max_dense_distance)
        return augmentAllocWithStride(1, allocator, active_history, input, commands, reachable_max_distance);
    if (reachable_max_distance <= (@as(usize, 1) << 21) - 16)
        return augmentAllocWithStride(2, allocator, active_history, input, commands, reachable_max_distance);
    if (reachable_max_distance <= (@as(usize, 1) << 22) - 16)
        return augmentAllocWithStride(4, allocator, active_history, input, commands, reachable_max_distance);
    if (reachable_max_distance <= (@as(usize, 1) << 23) - 16)
        return augmentAllocWithStride(8, allocator, active_history, input, commands, reachable_max_distance);
    return augmentAllocWithStride(16, allocator, active_history, input, commands, reachable_max_distance);
}

fn augmentAllocWithStride(
    comptime stride: usize,
    allocator: std.mem.Allocator,
    history: []const u8,
    input: []const u8,
    commands: []const command_plan.Command,
    max_backward_distance: usize,
) !?[]command_plan.Command {
    const combined_len = std.math.add(usize, history.len, input.len) catch
        return error.IntegerOverflow;
    if (input.len < min_match or combined_len - min_match < min_distance or
        commands.len == 0)
    {
        return null;
    }
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
            const absolute_position = history.len + position;
            if (absolute_position >= min_distance) {
                while (indexed_through <= absolute_position - min_distance) : (indexed_through += stride)
                    insert(stride, history, input, indexed_through, head, prev, prev_mask);
            }
            const match = find(
                stride,
                history,
                input,
                absolute_position,
                literal_end - position,
                head,
                prev,
                prev_mask,
                max_backward_distance,
            );
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
        const copy_output_len = command.outputLen();
        if (copy_output_len == 0 or copy_output_len > input.len - position) return error.InvalidBlockPlan;
        if (command.isLz77()) {
            try appendCopy(&output, allocator, insert_start, insert_len, command.copy_len, command.distance);
        } else {
            var copied = command;
            copied.insert_start = insert_start;
            copied.insert_len = insert_len;
            try output.append(allocator, copied);
        }
        position += copy_output_len;
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

fn find(
    comptime stride: usize,
    history: []const u8,
    input: []const u8,
    position: usize,
    available: usize,
    head: []const i32,
    prev: []const i32,
    prev_mask: usize,
    max_backward_distance: usize,
) Match {
    const combined_len = history.len + input.len;
    if (available < min_match or position + 4 > combined_len) return .{};
    var candidate_i = head[hashAt(history, input, position)];
    var checked: usize = 0;
    var best = Match{};
    const limit = @min(available, max_match);
    while (candidate_i >= 0 and checked < chain_limit) : (checked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = position - candidate;
        if (distance > max_backward_distance) break;
        if (byteAt(history, input, candidate + best.length) ==
            byteAt(history, input, position + best.length))
        {
            var length: usize = 0;
            while (length < limit and
                byteAt(history, input, candidate + length) ==
                    byteAt(history, input, position + length)) : (length += 1)
            {}
            if (length > best.length) best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate_i = prev[(candidate / stride) & prev_mask];
    }
    return best;
}

fn insert(
    comptime stride: usize,
    history: []const u8,
    input: []const u8,
    position: usize,
    head: []i32,
    prev: []i32,
    prev_mask: usize,
) void {
    if (position + 4 > history.len + input.len) return;
    const slot = hashAt(history, input, position);
    prev[(position / stride) & prev_mask] = head[slot];
    head[slot] = @intCast(position);
}

fn hashAt(history: []const u8, input: []const u8, position: usize) usize {
    if (position + 4 <= history.len)
        return hash(history[position..][0..4]);
    if (position >= history.len)
        return hash(input[position - history.len ..][0..4]);
    const bytes = [4]u8{
        byteAt(history, input, position),
        byteAt(history, input, position + 1),
        byteAt(history, input, position + 2),
        byteAt(history, input, position + 3),
    };
    return hash(&bytes);
}

fn byteAt(history: []const u8, input: []const u8, position: usize) u8 {
    return if (position < history.len)
        history[position]
    else
        input[position - history.len];
}

fn hash(bytes: *const [4]u8) usize {
    return (std.mem.readInt(u32, bytes, .little) *% 0x9e37_79b1) >> 17;
}

fn appendCopy(output: *std.ArrayList(command_plan.Command), allocator: std.mem.Allocator, insert_start: usize, insert_len: usize, copy_len: usize, distance: usize) !void {
    if (insert_len == 0 and output.items.len != 0) {
        const previous = &output.items[output.items.len - 1];
        if (previous.has_copy and previous.isLz77() and previous.distance == distance) {
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

test "long-distance augmentation preserves dictionary command sources" {
    const literal_len = min_distance + 32;
    const static_output_len = 5;
    const compound_output_len = 7;
    const input = [_]u8{'a'} ** (literal_len + static_output_len + compound_output_len);
    const original = [_]command_plan.Command{
        .{
            .insert_start = 0,
            .insert_len = literal_len,
            .copy_len = 4,
            .has_copy = true,
            .source = .static,
            .dictionary_output_len = static_output_len,
            .dictionary_address = 17,
        },
        .{
            .insert_start = literal_len + static_output_len,
            .insert_len = 0,
            .copy_len = compound_output_len,
            .has_copy = true,
            .source = .compound,
            .dictionary_address = 29,
        },
    };
    const augmented = try augmentAlloc(std.testing.allocator, &input, &original) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);

    var static_count: usize = 0;
    var compound_count: usize = 0;
    for (augmented) |command| {
        if (command.isStatic()) {
            static_count += 1;
            try std.testing.expectEqual(@as(usize, 4), command.copy_len);
            try std.testing.expectEqual(static_output_len, command.dictionary_output_len);
            try std.testing.expectEqual(@as(usize, 17), command.dictionary_address);
        }
        if (command.isCompound()) {
            compound_count += 1;
            try std.testing.expectEqual(compound_output_len, command.copy_len);
            try std.testing.expectEqual(@as(usize, 0), command.dictionary_output_len);
            try std.testing.expectEqual(@as(usize, 29), command.dictionary_address);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), static_count);
    try std.testing.expectEqual(@as(usize, 1), compound_count);
}

test "long-distance augmentation reaches retained stream history" {
    const history_len = 80 * 1024;
    const phrase = "retained-history-long-distance-match";
    const history = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(history);
    var state: u32 = 0x7a11_5eed;
    for (history) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(history[0..phrase.len], phrase);
    const input = phrase ++ "-tail";
    const original = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const augmented = try augmentAllocWithHistoryAndMaxDistance(
        std.testing.allocator,
        history,
        input,
        &original,
        (@as(usize, 1) << 17) - 16,
    ) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);

    try std.testing.expect(augmented.len >= 2);
    try std.testing.expect(augmented[0].has_copy);
    try std.testing.expectEqual(history_len, augmented[0].distance);
    try std.testing.expectEqual(phrase.len, augmented[0].copy_len);
    try std.testing.expectEqual(@as(usize, 0), augmented[0].insert_len);
}

test "long-distance history matcher ignores bytes outside the window" {
    const max_backward_distance = (@as(usize, 1) << 17) - 16;
    const phrase = "expired-history-long-distance-match";
    const history = try std.testing.allocator.alloc(
        u8,
        max_backward_distance + phrase.len,
    );
    defer std.testing.allocator.free(history);
    var state: u32 = 0x0dd5_eed5;
    for (history) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(history[0..phrase.len], phrase);
    const original = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = phrase.len,
    }};
    try std.testing.expect((try augmentAllocWithHistoryAndMaxDistance(
        std.testing.allocator,
        history,
        phrase,
        &original,
        max_backward_distance,
    )) == null);
}

test "long-distance history hashes matches across the block boundary" {
    const history_len = 8;
    const copy_len = 16;
    const match_position = min_distance - 1;
    const history = [history_len]u8{ 17, 31, 47, 63, 79, 95, 111, 127 };
    const input = try std.testing.allocator.alloc(u8, match_position + copy_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0xb0a1_da7a;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    input[match_position] = history[history.len - 1];
    @memcpy(
        input[match_position + 1 ..][0 .. copy_len - 1],
        input[0 .. copy_len - 1],
    );
    const original = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = input.len,
    }};
    const augmented = try augmentAllocWithHistoryAndMaxDistance(
        std.testing.allocator,
        &history,
        input,
        &original,
        (@as(usize, 1) << 17) - 16,
    ) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);

    var found = false;
    for (augmented) |command| {
        if (command.has_copy and command.insert_start == 0 and
            command.insert_len == match_position and
            command.copy_len == copy_len and
            command.distance == min_distance)
        {
            found = true;
        }
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

test "configurable matcher covers exact 18 through 24-bit distance limits" {
    inline for (.{ (@as(usize, 1) << 18) - 16, (@as(usize, 1) << 19) - 16, (@as(usize, 1) << 20) - 16, (@as(usize, 1) << 21) - 16, (@as(usize, 1) << 22) - 16, (@as(usize, 1) << 23) - 16, max_configurable_distance }) |match_position| {
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

test "stride-sixteen matcher advances through the worst source phase" {
    const match_position = 10 * 1024 * 1024 + 15;
    const phrase = "123456789abcdefconfigurable-long-distance-match";
    const input = try std.testing.allocator.alloc(u8, match_position + phrase.len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x524f_1eaf;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[1..][0..phrase.len], phrase);
    @memcpy(input[match_position..], phrase);
    const original = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const augmented = try augmentAllocWithMaxDistance(std.testing.allocator, input, &original, max_configurable_distance) orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(augmented);
    var found = false;
    for (augmented) |command|
        if (command.has_copy and command.distance == match_position - 1 and command.copy_len == phrase.len - 15) {
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
