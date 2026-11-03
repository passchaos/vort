//! Bounded legal command plans, materialized by an independent byte walk.
const std = @import("std");
const command = @import("../command_plan.zig");
pub const Command = command.Command;
const guard_command: Command = .{ .insert_start = 0xabcd, .insert_len = 0x1234, .copy_len = 0x5678, .distance = 0x4321, .has_copy = true, .dictionary_address = 0x8765 };

pub const Fixture = struct {
    input: []u8,
    commands: []Command,
    input_allocation: []u8,
    command_allocation: []Command,

    pub fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.input_allocation);
        allocator.free(self.command_allocation);
    }

    pub fn checkGuards(self: Fixture) !void {
        try std.testing.expectEqualSlices(u8, &@as([17]u8, @splat(0xb3)), self.input_allocation[0..17]);
        try std.testing.expectEqualSlices(u8, &@as([19]u8, @splat(0x6e)), self.input_allocation[17 + self.input.len ..]);
        try std.testing.expectEqualDeep(guard_command, self.command_allocation[0]);
        try std.testing.expectEqualDeep(guard_command, self.command_allocation[self.commands.len + 1]);
    }
};

fn storage(allocator: std.mem.Allocator, input_len: usize, command_count: usize) !Fixture {
    const bytes = try allocator.alloc(u8, input_len + 36);
    errdefer allocator.free(bytes);
    @memset(bytes[0..17], 0xb3);
    @memset(bytes[17 + input_len ..], 0x6e);
    const commands = try allocator.alloc(Command, command_count + 2);
    commands[0] = guard_command;
    commands[command_count + 1] = guard_command;
    return .{
        .input = bytes[17 .. 17 + input_len],
        .commands = commands[1 .. 1 + command_count],
        .input_allocation = bytes,
        .command_allocation = commands,
    };
}

pub fn small(allocator: std.mem.Allocator, symbols: usize) !Fixture {
    var total: usize = 0;
    for (0..symbols) |index| total += 16 + index + 2;
    const data = try storage(allocator, total, symbols);
    var cursor: usize = 0;
    for (data.commands, 0..) |*item, index| {
        item.* = .{ .insert_start = cursor, .insert_len = 16, .copy_len = index + 2, .distance = 4, .has_copy = true };
        for (0..16) |literal| data.input[cursor + literal] = @intCast(0x20 + literal % symbols);
        cursor += 16;
        for (0..item.copy_len) |_| {
            data.input[cursor] = data.input[cursor - item.distance];
            cursor += 1;
        }
    }
    return data;
}

pub fn literalOnly(allocator: std.mem.Allocator, alphabet: usize) !Fixture {
    const data = try storage(allocator, 2 * alphabet, 1);
    for (data.input, 0..) |*byte, index| byte.* = @intCast(index % alphabet);
    data.commands[0] = .{ .insert_start = 0, .insert_len = data.input.len };
    return data;
}

/// 127/128/129 commands straddle the prepared common command-symbol cache.
/// A range of insert/copy lengths and explicit/recent distances creates complex
/// command and distance trees without depending on a production match planner.
pub fn rich(allocator: std.mem.Allocator, count: usize, deep: bool) !Fixture {
    const initial: usize = if (deep) 4096 else 128;
    var total: usize = 0;
    for (0..count) |index| total += if (index + 1 == count) 17 else (if (index == 0) initial else index % 48) + 2 + index % 67;
    const data = try storage(allocator, total, count);
    const deep_distances = [_]usize{ 4, 4, 15, 16, 11, 4, 1, 2, 3, 5, 7, 8, 9, 17, 20, 32, 64, 77, 79, 80, 120, 121, 128, 129, 258, 1024, 4096 };
    const shallow_distances = [_]usize{ 4, 4, 15, 16, 11, 4, 1, 2, 3, 5, 7, 8, 9, 17, 20, 32, 64 };
    var cursor: usize = 0;
    for (data.commands, 0..) |*item, index| {
        const inserts = if (index + 1 == count) @as(usize, 17) else if (index == 0) initial else index % 48;
        const distance = if (deep) deep_distances[index % deep_distances.len] else shallow_distances[index % shallow_distances.len];
        item.* = .{ .insert_start = cursor, .insert_len = inserts, .copy_len = 2 + index % 67, .distance = distance, .has_copy = index + 1 != count };
        for (0..inserts) |literal| {
            data.input[cursor + literal] = @truncate(((cursor + literal) *% 73) ^ ((cursor + literal) >> 5) ^ (index *% 29));
        }
        cursor += inserts;
        if (item.has_copy) {
            for (0..item.copy_len) |_| {
                data.input[cursor] = data.input[cursor - distance];
                cursor += 1;
            }
        }
    }
    std.debug.assert(cursor == data.input.len);
    return data;
}

/// Dictionary geometry is tested against the physical writer. The output
/// literal regions are real; dictionary copy bytes are external frame context.
pub fn dictionary(allocator: std.mem.Allocator, source: Command.Source) !Fixture {
    const data = try storage(allocator, 16, 3);
    @memcpy(data.input[0..3], "abc");
    const word = if (source == .static) @import("../../static_dictionary.zig").baseWord(4, 0).? else "word";
    @memcpy(data.input[3..7], word);
    @memcpy(data.input[7..11], word);
    @memcpy(data.input[11..], "TAIL!");
    data.commands[0] = .{ .insert_start = 0, .insert_len = 3, .copy_len = 4, .has_copy = true, .source = source, .dictionary_address = 0, .dictionary_output_len = if (source == .static) 4 else 0 };
    data.commands[1] = .{ .insert_start = 7, .insert_len = 0, .copy_len = 4, .distance = 4, .has_copy = true };
    data.commands[2] = .{ .insert_start = 11, .insert_len = 5 };
    return data;
}

pub fn stats(comptime Stats: type, data: Fixture) Stats {
    var result: Stats = .{ .input_bytes = data.input.len, .command_count = data.commands.len };
    for (data.commands) |item| {
        result.literal_bytes += item.insert_len;
        result.matched_bytes += item.outputLen();
    }
    result.token_count = result.literal_bytes + data.commands.len;
    // Sentinels detect accidental clearing of caller-owned timing fields.
    result.lz77_ns = 41;
    result.command_plan_ns = 73;
    return result;
}
