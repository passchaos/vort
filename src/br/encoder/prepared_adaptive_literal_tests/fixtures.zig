const std = @import("std");
const command = @import("../command_plan.zig");
const split = @import("../block_split_plan.zig");

pub const Fixture = struct {
    input: []u8,
    commands: []command.Command,
    plan: split.Plan,
    active: [8]usize = @splat(0),
    literal_count: usize,
    pub fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.input);
        allocator.free(self.commands);
        self.plan.deinit(allocator);
    }
};

pub fn palette(allocator: std.mem.Allocator, type_count: usize, alphabet: usize) !Fixture {
    var lengths: [8]u32 = undefined;
    var types: [8]u8 = undefined;
    const literal_count = type_count * alphabet * 2;
    for (0..type_count) |index| {
        lengths[index] = @intCast(alphabet * 2);
        types[index] = @intCast(index);
    }
    const input = try allocator.alloc(u8, literal_count);
    errdefer allocator.free(input);
    for (input, 0..) |*byte, index| {
        const tree = index / (alphabet * 2);
        byte.* = @intCast((tree * 73 + index % alphabet) % 256);
    }
    const commands = try allocator.alloc(command.Command, 1);
    errdefer allocator.free(commands);
    commands[0] = .{ .insert_start = 0, .insert_len = input.len };
    const plan = try split.Plan.initCopy(allocator, lengths[0..type_count], types[0..type_count], @intCast(type_count), literal_count, 0);
    var active: [8]usize = @splat(0);
    @memset(active[0..type_count], alphabet);
    return .{ .input = input, .commands = commands, .plan = plan, .active = active, .literal_count = literal_count };
}

pub fn tiny(allocator: std.mem.Allocator) !Fixture {
    const input = try allocator.dupe(u8, "ABABCDCD");
    errdefer allocator.free(input);
    const commands = try allocator.alloc(command.Command, 1);
    errdefer allocator.free(commands);
    commands[0] = .{ .insert_start = 0, .insert_len = input.len };
    const plan = try split.Plan.initCopy(allocator, &.{ 4, 4 }, &.{ 0, 1 }, 2, 8, 0);
    return .{ .input = input, .commands = commands, .plan = plan, .active = .{ 2, 2, 0, 0, 0, 0, 0, 0 }, .literal_count = 8 };
}

pub fn rich(allocator: std.mem.Allocator, count: usize) !Fixture {
    const commands = try allocator.alloc(command.Command, count);
    errdefer allocator.free(commands);
    const distances = [_]usize{ 4, 4, 28, 32, 64, 1, 16, 20 };
    var literal_count: usize = 0;
    var total: usize = 0;
    for (commands, 0..) |*item, index| {
        const inserts: usize = if (index == 0) 96 else if (index == 1 or index % 5 == 0) 0 else 1 + index % 17;
        item.* = .{ .insert_start = total, .insert_len = inserts, .copy_len = 2 + index % 13, .distance = distances[index % distances.len], .has_copy = true };
        literal_count += inserts;
        total += inserts + item.copy_len;
    }
    const input = try allocator.alloc(u8, total);
    errdefer allocator.free(input);
    // Three switches inside the initial insert, then one at its boundary.
    // Command 1 has no insert: the boundary switch waits for command 2.
    const plan = try split.Plan.initCopy(allocator, &.{ 17, 13, 41, 25, @intCast(literal_count - 96) }, &.{ 0, 2, 1, 0, 1 }, 3, literal_count, 0);
    var seen: [3]usize = @splat(0);
    var position: usize = 0;
    var literal_index: usize = 0;
    for (commands) |item| {
        for (0..item.insert_len) |_| {
            const tree: usize = if (literal_index < 17) 0 else if (literal_index < 30) 2 else if (literal_index < 71) 1 else if (literal_index < 96) 0 else 1;
            const active = [_]usize{ 5, 4, 3 };
            input[position] = @intCast(tree * 73 + seen[tree] % active[tree]);
            seen[tree] += 1;
            literal_index += 1;
            position += 1;
        }
        for (0..item.copy_len) |_| {
            input[position] = input[position - item.distance];
            position += 1;
        }
    }
    return .{ .input = input, .commands = commands, .plan = plan, .active = .{ 5, 4, 3, 0, 0, 0, 0, 0 }, .literal_count = literal_count };
}

pub fn stats(comptime Stats: type, data: Fixture) Stats {
    var result: Stats = .{ .input_bytes = data.input.len, .command_count = data.commands.len, .literal_bytes = data.literal_count, .token_count = data.literal_count + data.commands.len };
    for (data.commands) |item| result.matched_bytes += item.outputLen();
    return result;
}
