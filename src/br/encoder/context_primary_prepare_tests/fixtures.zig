const std = @import("std");
const command_plan = @import("../command_plan.zig");
const command_encoding = @import("../command_encoding.zig");
const distance = @import("../distance.zig");
const history = @import("../../decoder/distance_history.zig");

pub const Fixture = struct {
    input: []u8,
    commands: []command_plan.Command,
    pub fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.input);
        allocator.free(self.commands);
    }
};

pub fn tiny(allocator: std.mem.Allocator, len: usize) !Fixture {
    const input = try allocator.alloc(u8, len);
    errdefer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @intCast('a' + index);
    const commands = try allocator.alloc(command_plan.Command, 1);
    commands[0] = .{ .insert_start = 0, .insert_len = len };
    return .{ .input = input, .commands = commands };
}

pub fn ordinary(allocator: std.mem.Allocator, count: usize, simple: bool) !Fixture {
    var len: usize = 0;
    for (0..count) |index| len += (if (simple or index == 0) @as(usize, 16) else 1 + index % 23) + 2 + index % (if (simple) count else 17);
    const input = try allocator.alloc(u8, len);
    errdefer allocator.free(input);
    const commands = try allocator.alloc(command_plan.Command, count);
    errdefer allocator.free(commands);
    var position: usize = 0;
    for (commands, 0..) |*item, index| {
        const inserts: usize = if (simple or index == 0) 16 else 1 + index % 23;
        const copies = 2 + index % (if (simple) count else 17);
        item.* = .{ .insert_start = position, .insert_len = inserts, .copy_len = copies, .distance = 4, .has_copy = true };
        for (input[position..][0..inserts], 0..) |*byte, k| byte.* = @intCast(32 + (index * 17 + k * 7) % 95);
        position += inserts;
        for (0..copies) |_| {
            input[position] = input[position - 4];
            position += 1;
        }
    }
    try std.testing.expectEqual(input.len, position);
    return .{ .input = input, .commands = commands };
}

/// Force distinct explicit short-distance codes while keeping one ordinary
/// command shape. Exact HQ representations prevent automatic recency aliases
/// from collapsing the 1..4-symbol and complex distance fixtures.
pub fn distanceCodes(allocator: std.mem.Allocator, symbols: usize) !Fixture {
    const input = try allocator.alloc(u8, 20 * symbols);
    errdefer allocator.free(input);
    const commands = try allocator.alloc(command_plan.Command, symbols);
    errdefer allocator.free(commands);
    var repeats: [4]usize = .{ 16, 15, 11, 4 };
    var position: usize = 0;
    const parameters = distance.Parameters.init(0, 15);
    const entry = command_encoding.forLengths(16, 4, false).?;
    for (commands, 0..) |*item, code| {
        var physical: usize = undefined;
        try history.resolveShortInto(@intCast(code), &repeats, &physical);
        item.* = .{ .insert_start = position, .insert_len = 16, .copy_len = 4, .distance = physical, .has_copy = true, .hq_encoding = .{ .command_symbol = entry.symbol, .distance_code = code, .distance_parameters = parameters, .distance_encoding = .{ .symbol = @intCast(code) } } };
        for (input[position..][0..16], 0..) |*byte, k| byte.* = @intCast('A' + (code * 3 + k) % 26);
        position += 16;
        for (0..4) |_| {
            input[position] = input[position - physical];
            position += 1;
        }
        if (code != 0) history.push(&repeats, physical);
    }
    return .{ .input = input, .commands = commands };
}

pub fn exact(allocator: std.mem.Allocator, count: usize) !Fixture {
    const result = try @import("../exact_wire_tests/prepared.zig").fixture(allocator, count);
    return .{ .input = result.input, .commands = result.commands };
}

pub fn fillStructured(input: []u8, kind: usize) void {
    const pattern = if (kind == 0)
        "{\"record\":00000000,\"level\":\"info\",\"message\":\"the quick brown fox jumps over the lazy dog\",\"status\":\"normal\"}\n"
    else if (kind == 1)
        "static inline unsigned value_00000000(void) { return 17; } // repeated declaration alpha beta gamma\n"
    else
        "sensor=00000000 status=nominal location=north pressure=1013 temperature=23; repeated telemetry record\n";
    const digits = std.mem.indexOf(u8, pattern, "00000000").?;
    for (input, 0..) |*byte, index| {
        const offset = index % pattern.len;
        const record = index / pattern.len;
        byte.* = if (offset >= digits and offset < digits + 8)
            "0123456789abcdef"[(record >> @intCast((offset - digits) * 4)) & 15]
        else
            pattern[offset];
    }
}
