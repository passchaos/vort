const std = @import("std");
const lz77 = @import("../../lz77.zig");
const command_plan = @import("command_plan.zig");
const command_encoding = @import("command_encoding.zig");
const distance = @import("distance.zig");
const distance_history = @import("../decoder/distance_history.zig");
const histogram_model = @import("histogram_model.zig");
const length = @import("../length.zig");

const LiteralHistogram = histogram_model.Histogram(256);
const CopyCodeHistogram = histogram_model.Histogram(24);
const DistanceHistogram = histogram_model.Histogram(64);
const CommandHistogram = histogram_model.Histogram(704);
const q8 = histogram_model.cost_scale;

/// Allocator-owned entropy costs learned from one complete Brotli command
/// proposal. This deliberately models separable literal, copy-length, and
/// regular-distance terms; complete wire arbitration remains authoritative
/// because command pairing, recent-distance state, trees, and block splitting
/// are not separable at this layer.
pub const Model = struct {
    literal: [256]u16,
    length: [lz77.max_match_len + 1]u16,
    distance: []u16,
    command: [704]u16,
    distance_symbol: [64]u16,

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        allocator.free(self.distance);
        self.* = undefined;
    }

    pub fn lz77Model(self: *const Model) lz77.OptimalCostModel {
        return .{
            .literal = &self.literal,
            .length = &self.length,
            .distance = self.distance,
        };
    }
};

pub fn build(
    allocator: std.mem.Allocator,
    input: []const u8,
    commands: []const command_plan.Command,
    window_len: usize,
) (std.mem.Allocator.Error || error{InvalidBlockPlan})!Model {
    return buildWithStartingDistances(
        allocator,
        input,
        commands,
        window_len,
        .{ 16, 15, 11, 4 },
    );
}

pub fn buildWithStartingDistances(
    allocator: std.mem.Allocator,
    input: []const u8,
    commands: []const command_plan.Command,
    window_len: usize,
    starting_last_distances: [4]usize,
) (std.mem.Allocator.Error || error{InvalidBlockPlan})!Model {
    if (input.len == 0 or window_len == 0 or window_len > lz77.default_window_len)
        return error.InvalidBlockPlan;
    for (starting_last_distances) |value|
        if (value == 0) return error.InvalidBlockPlan;

    var literals: LiteralHistogram = .{};
    var copy_codes: CopyCodeHistogram = .{};
    var regular_distances: DistanceHistogram = .{};
    var wire_distances: DistanceHistogram = .{};
    var command_symbols: CommandHistogram = .{};
    var last_distances = starting_last_distances;
    var cursor: usize = 0;
    var match_count: usize = 0;
    for (commands) |command| {
        if (command.insert_start != cursor or command.insert_len > input.len - cursor)
            return error.InvalidBlockPlan;
        for (input[cursor..][0..command.insert_len]) |byte|
            literals.add(byte) catch return error.InvalidBlockPlan;
        cursor += command.insert_len;
        if (!command.has_copy) {
            const encoding = command_encoding.forLengths(command.insert_len, 2, false) orelse
                return error.InvalidBlockPlan;
            command_symbols.add(encoding.symbol) catch return error.InvalidBlockPlan;
            continue;
        }
        if (!command.isLz77() or command.copy_len < lz77.min_match_len or
            command.distance == 0 or
            command.distance > @min(window_len, cursor) or command.copy_len > input.len - cursor)
        {
            return error.InvalidBlockPlan;
        }
        const copy_code = length.codeForValue(command.copy_len, false) orelse
            return error.InvalidBlockPlan;
        const encoded_distance = distance.encodeWithParameters(
            command.distance,
            distance.Parameters.init(0, 0),
        ) orelse return error.InvalidBlockPlan;
        copy_codes.add(copy_code) catch return error.InvalidBlockPlan;
        regular_distances.add(encoded_distance.symbol) catch return error.InvalidBlockPlan;
        const recent_symbol = distance_history.symbolForDistance(command.distance, &last_distances);
        const command_encoding_value = command_encoding.forLengths(
            command.insert_len,
            command.copy_len,
            recent_symbol == 0,
        ) orelse command_encoding.forLengths(
            command.insert_len,
            command.copy_len,
            false,
        ) orelse return error.InvalidBlockPlan;
        command_symbols.add(command_encoding_value.symbol) catch return error.InvalidBlockPlan;
        if (command_encoding_value.command.distance_code == -1) {
            const symbol: usize = recent_symbol orelse encoded_distance.symbol;
            wire_distances.add(symbol) catch return error.InvalidBlockPlan;
        }
        if (recent_symbol != 0) distance_history.push(&last_distances, command.distance);
        cursor += command.copy_len;
        match_count += 1;
    }
    if (cursor != input.len or match_count == 0) return error.InvalidBlockPlan;

    const literal_model = literals.costModel();
    const copy_model = copy_codes.costModel();
    const distance_model = regular_distances.costModel();
    const command_model = command_symbols.costModel();
    const wire_distance_model = wire_distances.costModel();
    var result = Model{
        .literal = undefined,
        .length = @splat(q8),
        .distance = try allocator.alloc(u16, window_len + 1),
        .command = undefined,
        .distance_symbol = undefined,
    };
    errdefer allocator.free(result.distance);

    for (&result.literal, literal_model.symbol_costs_q8) |*cost, learned|
        cost.* = @max(q8, learned);
    for (&result.command, command_model.symbol_costs_q8) |*cost, learned|
        cost.* = @max(q8, learned);
    for (&result.distance_symbol, wire_distance_model.symbol_costs_q8) |*cost, learned|
        cost.* = @max(q8, learned);
    for (lz77.min_match_len..lz77.max_match_len + 1) |copy_len| {
        const code = length.codeForValue(copy_len, false) orelse unreachable;
        const spec = length.copySpec(code);
        result.length[copy_len] = addExtraBits(copy_model.symbol_costs_q8[code], spec.extra_bits);
    }
    result.distance[0] = q8;
    for (1..result.distance.len) |match_distance| {
        const encoded = distance.encodeWithParameters(
            match_distance,
            distance.Parameters.init(0, 0),
        ) orelse return error.InvalidBlockPlan;
        result.distance[match_distance] = addExtraBits(
            distance_model.symbol_costs_q8[encoded.symbol],
            encoded.extra_bits,
        );
    }
    return result;
}

fn addExtraBits(learned: u16, extra_bits: u5) u16 {
    const base = @max(q8, learned);
    return std.math.add(u16, base, @as(u16, extra_bits) * q8) catch
        std.math.maxInt(u16);
}

test "entropy feedback learns literal length and distance shapes" {
    const input = "abcabcabcabcabcabcXabcXabcXabcX";
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .match = .{ .length = 15, .distance = 3 } },
        .{ .literal = 'X' },
        .{ .match = .{ .length = 3, .distance = 4 } },
        .{ .literal = 'X' },
        .{ .match = .{ .length = 3, .distance = 4 } },
        .{ .literal = 'X' },
        .{ .match = .{ .length = 3, .distance = 4 } },
        .{ .literal = 'X' },
    };
    const commands = try command_plan.buildAlloc(std.testing.allocator, input, &tokens);
    defer commands.deinit(std.testing.allocator);
    var model = try build(std.testing.allocator, input, commands.commands, input.len);
    defer model.deinit(std.testing.allocator);

    try std.testing.expect(model.literal['X'] < model.literal['z']);
    try std.testing.expect(model.length[3] < model.length[4]);
    try std.testing.expect(model.distance[4] < model.distance[9]);
    _ = model.lz77Model();
}

test "entropy feedback rejects incomplete and non-lz77 plans" {
    const incomplete = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = 3 }};
    try std.testing.expectError(
        error.InvalidBlockPlan,
        build(std.testing.allocator, "abcdef", &incomplete, 6),
    );
    const compound = [_]command_plan.Command{.{
        .insert_start = 0,
        .insert_len = 3,
        .copy_len = 3,
        .has_copy = true,
        .source = .compound,
    }};
    try std.testing.expectError(
        error.InvalidBlockPlan,
        build(std.testing.allocator, "abcdef", &compound, 6),
    );
}

test "entropy feedback inherits the caller recent-distance ring" {
    const input = "abcdabcd";
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .literal = 'd' },
        .{ .match = .{ .length = 4, .distance = 4 } },
    };
    const commands = try command_plan.buildAlloc(std.testing.allocator, input, &tokens);
    defer commands.deinit(std.testing.allocator);
    var implicit = try buildWithStartingDistances(
        std.testing.allocator,
        input,
        commands.commands,
        input.len,
        .{ 16, 15, 11, 4 },
    );
    defer implicit.deinit(std.testing.allocator);
    var explicit = try buildWithStartingDistances(
        std.testing.allocator,
        input,
        commands.commands,
        input.len,
        .{ 16, 15, 11, 99 },
    );
    defer explicit.deinit(std.testing.allocator);
    const implicit_encoding = command_encoding.forLengths(4, 4, true).?;
    const explicit_encoding = command_encoding.forLengths(4, 4, false).?;
    try std.testing.expect(
        implicit.command[implicit_encoding.symbol] < explicit.command[implicit_encoding.symbol],
    );
    try std.testing.expect(
        explicit.command[explicit_encoding.symbol] < implicit.command[explicit_encoding.symbol],
    );
}
