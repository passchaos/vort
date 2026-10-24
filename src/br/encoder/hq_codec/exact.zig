//! Validate parser-selected symbols without choosing another representation.
const std = @import("std");
const lut = @import("../../command_lut.zig");
const command_encoding = @import("../command_encoding.zig");
const distance = @import("../distance.zig");
const history = @import("../../decoder/distance_history.zig");

pub const Error = error{InvalidBlockPlan};
pub const Selection = struct {
    command: command_encoding.Encoding,
    distance: ?distance.Encoding,
    recent_symbol: ?u4,
    repeated_distances: [4]usize,
};

pub fn resolve(command_symbol: u16, insert_len: usize, copy_len: usize, has_copy: bool, is_static: bool, distance_encoding: ?distance.Encoding, expected_distance: usize, parameters: distance.Parameters, initial_distances: [4]usize) Error!Selection {
    return resolveWithFormat(command_symbol, insert_len, copy_len, has_copy, is_static, distance_encoding, expected_distance, parameters, initial_distances, .standard);
}

pub fn resolveWithFormat(command_symbol: u16, insert_len: usize, copy_len: usize, has_copy: bool, is_static: bool, distance_encoding: ?distance.Encoding, expected_distance: usize, parameters: distance.Parameters, initial_distances: [4]usize, format: distance.Format) Error!Selection {
    if (command_symbol >= lut.entries.len) return error.InvalidBlockPlan;
    const entry = lut.entries[command_symbol];
    if (!inRange(insert_len, entry.insert_base, entry.insert_extra_bits) or
        !inRange(copy_len, entry.copy_base, entry.copy_extra_bits)) return error.InvalidBlockPlan;
    var result: Selection = .{ .command = .{ .symbol = command_symbol, .command = entry }, .distance = distance_encoding, .recent_symbol = null, .repeated_distances = initial_distances };
    if (!has_copy) {
        if (distance_encoding != null) return error.InvalidBlockPlan;
        return result;
    }
    var decoded: usize = undefined;
    if (entry.distance_code == 0) {
        if (distance_encoding != null) return error.InvalidBlockPlan;
        decoded = initial_distances[3];
        result.recent_symbol = 0;
    } else if (entry.distance_code == -1) {
        const encoded = distance_encoding orelse return error.InvalidBlockPlan;
        if (encoded.symbol < 16) {
            if (encoded.extra != 0 or encoded.extra_bits != 0) return error.InvalidBlockPlan;
            history.resolveShortInto(encoded.symbol, &initial_distances, &decoded) catch return error.InvalidBlockPlan;
            result.recent_symbol = @intCast(encoded.symbol);
        } else decoded = distance.decodeWithFormat(encoded, parameters, format) orelse return error.InvalidBlockPlan;
    } else return error.InvalidBlockPlan;
    if (decoded == 0 or decoded != expected_distance) return error.InvalidBlockPlan;
    if (format == .large_window and decoded > distance.safe_max_distance) return error.InvalidBlockPlan;
    if (!is_static and result.recent_symbol != 0) history.push(&result.repeated_distances, decoded);
    return result;
}

fn inRange(value: usize, base: u32, bits: u5) bool {
    return value >= base and value - base < (@as(usize, 1) << bits);
}

test "Brotli HQ exact selectors preserve duplicate repeat choices and direct distances" {
    const cache: [4]usize = .{ 16, 15, 4, 4 };
    const params = distance.Parameters.init(0, 0);
    const entry = command_encoding.forLengths(4, 8, false).?;
    const short = try resolve(entry.symbol, 4, 8, true, false, .{ .symbol = 1 }, 4, params, cache);
    try std.testing.expectEqual(@as(?u4, 1), short.recent_symbol);
    try std.testing.expectEqualSlices(usize, &.{ 15, 4, 4, 4 }, &short.repeated_distances);
    const regular = distance.encodeWithParameters(4, params).?;
    const direct = try resolve(entry.symbol, 4, 8, true, false, regular, 4, params, cache);
    try std.testing.expectEqual(entry.symbol, direct.command.symbol);
    try std.testing.expectEqual(regular, direct.distance.?);
    try std.testing.expectEqual(@as(?u4, null), direct.recent_symbol);
}

test "Brotli HQ exact selectors reject inconsistent fields and preserve static cache" {
    const cache: [4]usize = .{ 16, 15, 11, 4 };
    const params = distance.Parameters.init(0, 0);
    const entry = command_encoding.forLengths(2, 4, false).?;
    try std.testing.expectError(error.InvalidBlockPlan, resolve(entry.symbol, 2, 4, true, false, .{ .symbol = 0 }, 3, params, cache));
    try std.testing.expectError(error.InvalidBlockPlan, resolve(entry.symbol, 1, 4, true, false, .{ .symbol = 0 }, 4, params, cache));
    const selected = try resolve(entry.symbol, 2, 4, true, true, distance.encodeWithParameters(23, params).?, 23, params, cache);
    try std.testing.expectEqualSlices(usize, &cache, &selected.repeated_distances);
}

test "Brotli HQ Large Window exact regular selection preserves the last active prefix and extras" {
    const params = distance.Parameters.init(3, 15);
    const maximum = params.maximumDistanceForFormat(.large_window);
    const encoded = distance.encodeWithFormat(maximum, params, .large_window).?;
    const cache: [4]usize = .{ 16, 15, 11, 4 };
    const entry = command_encoding.forLengths(2, 4, false).?;
    const selected = try resolveWithFormat(entry.symbol, 2, 4, true, true, encoded, maximum, params, cache, .large_window);
    try std.testing.expectEqual(@as(u16, 543), selected.distance.?.symbol);
    try std.testing.expectEqual(encoded, selected.distance.?);
    try std.testing.expectEqual(entry.symbol, selected.command.symbol);
    try std.testing.expectEqualSlices(usize, &cache, &selected.repeated_distances);
    try std.testing.expectError(error.InvalidBlockPlan, resolve(entry.symbol, 2, 4, true, true, encoded, maximum, params, cache));
    var invalid = encoded;
    invalid.extra += 1;
    try std.testing.expectError(error.InvalidBlockPlan, resolveWithFormat(entry.symbol, 2, 4, true, true, invalid, maximum + 1, params, cache, .large_window));
}

test "Brotli HQ Large Window exact short aliases obey the global safety limit independently of regular shape" {
    const params = distance.Parameters.init(0, 1);
    const maximum = params.maximumDistanceForFormat(.large_window);
    const cached = maximum + 1;
    const cache: [4]usize = .{ 16, 15, cached, cached };
    const implicit_entry = command_encoding.forLengths(2, 4, true).?;
    const explicit_entry = command_encoding.forLengths(2, 4, false).?;
    const implicit = try resolveWithFormat(implicit_entry.symbol, 2, 4, true, false, null, cached, params, cache, .large_window);
    try std.testing.expectEqualSlices(usize, &cache, &implicit.repeated_distances);
    const explicit = try resolveWithFormat(explicit_entry.symbol, 2, 4, true, false, .{ .symbol = 1 }, cached, params, cache, .large_window);
    try std.testing.expectEqual(@as(?u4, 1), explicit.recent_symbol);
    try std.testing.expectEqual(distance.Encoding{ .symbol = 1 }, explicit.distance.?);
    try std.testing.expectEqualSlices(usize, &.{ 15, cached, cached, cached }, &explicit.repeated_distances);
    const safe_cache: [4]usize = .{ 16, 15, distance.safe_max_distance, distance.safe_max_distance };
    _ = try resolveWithFormat(explicit_entry.symbol, 2, 4, true, false, .{ .symbol = 1 }, distance.safe_max_distance, params, safe_cache, .large_window);
    const unsafe = distance.safe_max_distance + 1;
    const unsafe_cache: [4]usize = .{ 16, 15, unsafe, unsafe };
    try std.testing.expectError(error.InvalidBlockPlan, resolveWithFormat(implicit_entry.symbol, 2, 4, true, false, null, unsafe, params, unsafe_cache, .large_window));
    try std.testing.expectError(error.InvalidBlockPlan, resolveWithFormat(explicit_entry.symbol, 2, 4, true, false, .{ .symbol = 1 }, unsafe, params, unsafe_cache, .large_window));
}
