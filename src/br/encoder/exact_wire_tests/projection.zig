//! Narrow runtime contracts call both the actual split projector and writer.
const std = @import("std");
const enc = @import("../command_encoding.zig");
const distance = @import("../distance.zig");
const history = @import("../../decoder/distance_history.zig");
const command_plan = @import("../command_plan.zig");
const types = @import("../hq_types.zig");
const params = distance.Parameters.init(0, 15);
pub const Error = error{SymbolProjectionMismatch};

fn check(value: bool) Error!void {
    if (!value) return error.SymbolProjectionMismatch;
}

fn exactCommand(insert_start: usize, insert_len: usize, copy_len: usize, physical: usize, code: usize, has_copy: bool) command_plan.Command {
    const entry = enc.forLengths(insert_len, copy_len, false).?;
    return .{
        .insert_start = insert_start,
        .insert_len = insert_len,
        .copy_len = copy_len,
        .distance = physical,
        .has_copy = has_copy,
        .hq_encoding = .{
            .command_symbol = entry.symbol,
            .distance_code = if (has_copy) code else 0,
            .distance_parameters = params,
            .distance_encoding = if (!has_copy) null else if (code < 16) distance.Encoding{ .symbol = @intCast(code) } else distance.encodeWithFormat(physical, params, .standard).?,
        },
    };
}

pub fn selectors(comptime Br: type) !void {
    const S = Br.SymbolProjectionTestSupport;
    const cache: [4]usize = .{ 16, 15, 4, 4 };
    const explicit_zero = exactCommand(0, 4, 8, 4, 0, true);
    const zero = try S.project(explicit_zero, true, .{}, cache);
    try check(zero.command.command.distance_code == -1 and zero.distance.?.symbol == 0 and std.mem.eql(usize, &zero.repeats, &cache));
    const regular = exactCommand(0, 4, 8, 4, 19, true);
    const full = try S.project(regular, true, .{}, cache);
    try check(full.distance.?.symbol == 19 and std.mem.eql(usize, &full.repeats, &.{ 15, 4, 4, 4 }));
    for ([_]usize{ 1, 10 }) |code| {
        var physical: usize = undefined;
        try history.resolveShortInto(@intCast(code), &cache, &physical);
        const projected = try S.project(exactCommand(0, 4, 8, physical, code, true), true, .{}, cache);
        var expected = cache;
        history.push(&expected, physical);
        try check(projected.distance.?.symbol == code and std.mem.eql(usize, &projected.repeats, &expected));
    }
    // Decoder stops after terminal inserts, irrespective of dummy copy shape.
    const terminal = try S.project(exactCommand(0, 7, 258, 0, 0, false), true, .{}, cache);
    try check(terminal.distance == null and std.mem.eql(usize, &terminal.repeats, &cache));
    // Both exact choices and legacy code-zero canonicalization are intentional.
    var ordinary = explicit_zero;
    ordinary.hq_encoding = null;
    const canonical = try S.project(ordinary, true, .{}, cache);
    try check(canonical.command.command.distance_code == 0 and canonical.distance == null and std.mem.eql(usize, &canonical.repeats, &cache));
    ordinary.distance = 32;
    const canonical_regular = try S.project(ordinary, false, .{}, cache);
    const expected_encoding = enc.forLengths(4, 8, false).?;
    try check(canonical_regular.command.symbol == expected_encoding.symbol and std.meta.eql(canonical_regular.distance.?, distance.encodeWithFormat(32, params, .standard).?));
}

pub const Fixture = struct {
    input: []u8,
    commands: []command_plan.Command,
    pub fn deinit(self: Fixture, a: std.mem.Allocator) void {
        a.free(self.commands);
        a.free(self.input);
    }
};

pub fn fixture(a: std.mem.Allocator) !Fixture {
    const count = 4096;
    const input = try a.alloc(u8, 16 + count * 4 + 3);
    errdefer a.free(input);
    @memset(input, 'a');
    const commands = try a.alloc(command_plan.Command, count + 1);
    errdefer a.free(commands);
    var position: usize = 0;
    var repeats = types.initial_recent;
    for (commands[0..count], 0..) |*command, index| {
        const inserts: usize = if (index == 0) 16 else 0;
        const code: usize = if (index < 2048) index % 4 else 19 + index % 12;
        var physical: usize = if (index < 2048) undefined else code - 15;
        if (index < 2048) try history.resolveShortInto(@intCast(code), &repeats, &physical);
        command.* = exactCommand(position, inserts, 4, physical, code, true);
        if (code != 0) history.push(&repeats, physical);
        position += inserts + 4;
    }
    commands[count] = exactCommand(position, 3, 258, 0, 0, false);
    return .{ .input = input, .commands = commands };
}

pub fn writer(comptime Br: type, a: std.mem.Allocator) !usize {
    const S = Br.SymbolProjectionTestSupport;
    const data = try fixture(a);
    defer data.deinit(a);
    var repeats = types.initial_recent;
    var distance_count: usize = 0;
    for (data.commands, 0..) |command, index| {
        const projected = try S.project(command, true, .{}, repeats);
        try check(projected.command.symbol == command.hq_encoding.?.command_symbol);
        if (index < 4096) {
            try check(projected.distance.?.symbol == if (index < 2048) @as(u16, @intCast(index % 4)) else @as(u16, @intCast(19 + index % 12)));
            distance_count += 1;
        } else try check(projected.distance == null);
        repeats = projected.repeats;
    }
    try check(distance_count == 4096);
    var splits = try S.choose(a, data.commands, .{});
    defer S.deinit(&splits, a);
    const split = &(splits.adaptive_distance orelse return error.SymbolProjectionMismatch);
    var total: usize = 0;
    for (split.lengths) |length| total += length;
    try check(total == distance_count and split.type_count >= 2);
    const bytes = try S.write(a, data.input, data.commands, .{}, null, split);
    defer a.free(bytes);
    const plain = try Br.decodeStreamAllocExactSize(a, bytes, data.input.len);
    defer a.free(plain);
    try check(std.mem.eql(u8, data.input, plain));
    const summary = try Br.summarizeStreamAlloc(a, bytes);
    try check(summary.command_count == 4097 and summary.short_distance_copy_count == 2048 and summary.direct_distance_copy_count == 2048 and summary.max_distance_block_types >= 2);
    const storage = try a.alloc(u8, bytes.len + 32);
    defer a.free(storage);
    @memset(storage, 0xa5);
    const written = try S.writeInto(a, storage[16 .. 16 + bytes.len], data.input, data.commands, .{}, null, split);
    try check(written == bytes.len and std.mem.eql(u8, bytes, storage[16 .. 16 + written]));
    for (storage[0..16]) |byte| try check(byte == 0xa5);
    for (storage[16 + written ..]) |byte| try check(byte == 0xa5);
    // Clear exact commands and verify ordinary projection ordinals against the
    // previous canonical rule independently, including terminal no-distance.
    var ring = types.initial_recent;
    for (data.commands) |*command| {
        command.hq_encoding = null;
        const projected = try S.project(command.*, true, .{}, ring);
        const short = if (command.has_copy) history.symbolForDistance(command.distance, &ring) else null;
        const canonical = enc.forLengths(command.insert_len, command.copy_len, short == 0) orelse enc.forLengths(command.insert_len, command.copy_len, false).?;
        try check(canonical.symbol == projected.command.symbol);
        if (command.has_copy and short != 0) history.push(&ring, command.distance);
        try check(std.mem.eql(usize, &ring, &projected.repeats));
    }
    return distance_count;
}

pub fn saveFixtureWire(comptime Br: type, a: std.mem.Allocator) ![]u8 {
    const data = try fixture(a);
    defer data.deinit(a);
    var splits = try Br.SymbolProjectionTestSupport.choose(a, data.commands, .{});
    defer Br.SymbolProjectionTestSupport.deinit(&splits, a);
    return Br.SymbolProjectionTestSupport.write(a, data.input, data.commands, .{}, null, &(splits.adaptive_distance orelse return error.SymbolProjectionMismatch));
}
