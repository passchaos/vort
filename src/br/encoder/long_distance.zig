const std = @import("std");
const command_plan = @import("command_plan.zig");

pub const min_distance: usize = (@as(usize, 1) << 16) - 16 + 1;
pub const max_distance: usize = (@as(usize, 1) << 17) - 16;
const chain_limit = 512;
const min_match = 16;
const max_match = 258;
const hash_size = 1 << 15;
const history_size = 1 << 17;

/// Insert Brotli-only long matches into literal runs left by the shared 16-bit
/// LZ77 planner. Existing copies are preserved verbatim; rebuilding absolute
/// insert offsets keeps the command stream independently verifiable.
pub fn augmentAlloc(allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command) !?[]command_plan.Command {
    if (input.len <= min_distance or commands.len == 0) return null;
    const head = try allocator.alloc(i32, hash_size);
    defer allocator.free(head);
    @memset(head, -1);
    const prev = try allocator.alloc(i32, history_size);
    defer allocator.free(prev);

    var output: std.ArrayList(command_plan.Command) = .empty;
    errdefer output.deinit(allocator);
    var found = false;
    var position: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    for (commands) |command| {
        if (command.insert_start != position) return error.InvalidBlockPlan;
        const literal_end = position + command.insert_len;
        while (position < literal_end) {
            const match = find(input, position, literal_end - position, head, prev);
            if (match.length >= min_match) {
                try appendCopy(&output, allocator, insert_start, insert_len, match.length, match.distance);
                found = true;
                const end = position + match.length;
                while (position < end) : (position += 1) insert(input, position, head, prev);
                insert_start = position;
                insert_len = 0;
            } else {
                insert(input, position, head, prev);
                position += 1;
                insert_len += 1;
            }
        }
        if (!command.has_copy) continue;
        try appendCopy(&output, allocator, insert_start, insert_len, command.copy_len, command.distance);
        const copy_end = position + command.copy_len;
        while (position < copy_end) : (position += 1) insert(input, position, head, prev);
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

fn find(input: []const u8, position: usize, available: usize, head: []const i32, prev: []const i32) Match {
    if (available < min_match or position + 4 > input.len) return .{};
    var candidate_i = head[hash(input[position..][0..4])];
    var checked: usize = 0;
    var best = Match{};
    const limit = @min(available, max_match);
    while (candidate_i >= 0 and checked < chain_limit) : (checked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = position - candidate;
        if (distance > max_distance) break;
        if (distance >= min_distance and input[candidate + best.length] == input[position + best.length]) {
            var length: usize = 0;
            while (length < limit and input[candidate + length] == input[position + length]) : (length += 1) {}
            if (length > best.length) best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate_i = prev[candidate & (history_size - 1)];
    }
    return best;
}

fn insert(input: []const u8, position: usize, head: []i32, prev: []i32) void {
    if (position + 4 > input.len) return;
    const slot = hash(input[position..][0..4]);
    prev[position & (history_size - 1)] = head[slot];
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
