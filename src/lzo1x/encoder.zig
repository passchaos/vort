const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");

pub const Error = core.Error;

pub const Mode = enum {
    literal_only,
    greedy,
};

pub const EncodeOptions = struct {
    mode: Mode = .greedy,
};

pub const EncodeStats = struct {
    input_bytes: usize,
    output_bytes: usize,
    literal_bytes: usize,
    matches: usize,
    long_distance_matches: usize,
};

const m3_max_distance: usize = 16 * 1024;
const max_match_distance: usize = 48 * 1024 - 1;
const end_marker = [_]u8{ 0x11, 0, 0 };

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append one complete LZO1X stream without changing `out.items` on error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return (try encodeAppendWithStats(allocator, out, input, options)).output_bytes;
}

pub fn encodeAppendWithStats(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !EncodeStats {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var stats = EncodeStats{
        .input_bytes = input.len,
        .output_bytes = 0,
        .literal_bytes = 0,
        .matches = 0,
        .long_distance_matches = 0,
    };

    switch (options.mode) {
        .literal_only => {
            try appendLiteralRun(allocator, &encoded, input, true);
            stats.literal_bytes = input.len;
        },
        .greedy => try encodeGreedy(allocator, &encoded, input, &stats),
    }
    try encoded.appendSlice(allocator, &end_marker);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    stats.output_bytes = encoded.items.len;
    return stats;
}

fn encodeGreedy(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    stats: *EncodeStats,
) !void {
    const plan = try lz77.hashGreedyPlanAlloc(allocator, input, .{
        .window_len = max_match_distance,
        .max_chain = 64,
        .nice_len = 64,
        .max_candidates = 4,
        .min_match = 3,
        .max_match = lz77.max_match_len,
    });
    defer plan.deinit(allocator);

    var token_index: usize = 0;
    var input_offset: usize = 0;
    while (token_index < plan.tokens.len and plan.tokens[token_index] == .literal)
        token_index += 1;
    try appendLiteralRun(allocator, output, input[0..token_index], true);
    stats.literal_bytes += token_index;
    input_offset = token_index;

    while (token_index < plan.tokens.len) {
        const match = switch (plan.tokens[token_index]) {
            .match => |value| value,
            .literal => return error.InvalidMatch,
        };
        token_index += 1;
        input_offset = std.math.add(usize, input_offset, match.length) catch
            return error.IntegerOverflow;
        if (input_offset > input.len) return error.InvalidMatch;

        const literal_start = input_offset;
        while (token_index < plan.tokens.len and plan.tokens[token_index] == .literal) {
            token_index += 1;
            input_offset += 1;
        }
        const literal_count = input_offset - literal_start;
        const trailing_count = if (literal_count <= 3) literal_count else 0;
        try appendMatch(allocator, output, match.length, match.distance, trailing_count);
        stats.matches += 1;
        if (match.distance > m3_max_distance) stats.long_distance_matches += 1;

        if (trailing_count != 0) {
            try output.appendSlice(allocator, input[literal_start..input_offset]);
        } else if (literal_count != 0) {
            try appendLiteralRun(allocator, output, input[literal_start..input_offset], false);
        }
        stats.literal_bytes += literal_count;
    }
    if (input_offset != input.len) return error.InvalidMatch;
}

fn appendLiteralRun(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    literals: []const u8,
    initial: bool,
) !void {
    if (literals.len == 0) return;
    if (initial and literals.len <= 238) {
        try output.append(allocator, @intCast(literals.len + 17));
    } else if (literals.len <= 18) {
        if (literals.len < 4) return error.InvalidMatch;
        try output.append(allocator, @intCast(literals.len - 3));
    } else {
        try output.append(allocator, 0);
        try appendExtendedLength(allocator, output, literals.len - 18);
    }
    try output.appendSlice(allocator, literals);
}

fn appendMatch(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    length: usize,
    distance: usize,
    trailing: usize,
) !void {
    if (length < 3 or distance == 0 or distance > max_match_distance or trailing > 3)
        return error.InvalidMatch;

    if (distance <= m3_max_distance) {
        if (length <= 33) {
            try output.append(allocator, @intCast(32 + length - 2));
        } else {
            try output.append(allocator, 32);
            try appendExtendedLength(allocator, output, length - 33);
        }
        const offset: u16 = @intCast(((distance - 1) << 2) | trailing);
        try appendU16(allocator, output, offset);
        return;
    }

    const high_offset: u8 = if (distance >= 32 * 1024) 8 else 0;
    const low_distance = if (high_offset != 0)
        distance - 32 * 1024
    else
        distance - 16 * 1024;
    if (length <= 9) {
        try output.append(allocator, 16 | high_offset | @as(u8, @intCast(length - 2)));
    } else {
        try output.append(allocator, 16 | high_offset);
        try appendExtendedLength(allocator, output, length - 9);
    }
    const offset: u16 = @intCast((low_distance << 2) | trailing);
    try appendU16(allocator, output, offset);
}

fn appendExtendedLength(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    extra: usize,
) !void {
    if (extra == 0) return error.InvalidMatch;
    var remaining = extra;
    while (remaining > std.math.maxInt(u8)) : (remaining -= std.math.maxInt(u8))
        try output.append(allocator, 0);
    try output.append(allocator, @intCast(remaining));
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "LZO1X writer emits canonical empty and literal streams" {
    var empty: std.ArrayList(u8) = .empty;
    defer empty.deinit(std.testing.allocator);
    const empty_stats = try encodeAppendWithStats(std.testing.allocator, &empty, "", .{});
    try std.testing.expectEqualSlices(u8, &end_marker, empty.items);
    try std.testing.expectEqual(@as(usize, 0), empty_stats.matches);

    const encoded = try encodeAlloc(std.testing.allocator, "hello", .{ .mode = .literal_only });
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 22, 'h', 'e', 'l', 'l', 'o', 17, 0, 0 }, encoded);
}

test "LZO1X writer append and caller output are transactional" {
    const input = "transactional LZO1X stream" ** 16;
    const encoded = try encodeAlloc(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(encoded);
    const output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(std.testing.allocator, input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(std.testing.allocator, input, output[0 .. output.len - 1], .{}),
    );
}
