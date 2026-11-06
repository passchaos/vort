const std = @import("std");
const lz77 = @import("../../lz77.zig");

/// Borrowed pieces of suffix_W(dictionary ++ input[0..chunk_start]), followed
/// by the chunk. Keeping the input piece contiguous avoids copying ordinary
/// split blocks, including blocks whose preset dictionary has expired.
pub const View = struct {
    dictionary: []const u8,
    input: []const u8,
    input_history_len: usize,

    pub fn init(
        input: []const u8,
        dictionary: ?[]const u8,
        chunk_start: usize,
        chunk_len: usize,
        window_len: usize,
    ) !View {
        if (chunk_start > input.len or chunk_len > input.len - chunk_start)
            return error.InvalidBlockPlan;
        // LZ77 distances cannot address a larger history even when custom
        // options request one. Match the existing preset dictionary cap.
        const effective_window_len = @min(window_len, lz77.max_window_len);
        const history_len = @min(chunk_start, effective_window_len);
        const dict = dictionary orelse "";
        const dictionary_len = @min(dict.len, effective_window_len - history_len);
        return .{
            .dictionary = dict[dict.len - dictionary_len ..],
            .input = input[chunk_start - history_len ..][0 .. history_len + chunk_len],
            .input_history_len = history_len,
        };
    }
};

/// Plan the same effective history for both block selection and emission.
/// Parsing history before trimming preserves the ordinary optimal parser and
/// discovers matches spanning the dictionary/input or input/block seams.
pub fn planChunkAlloc(
    comptime C: type,
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: ?[]const u8,
    chunk_start: usize,
    chunk_len: usize,
    options: C.Options,
) !lz77.GreedyPlan {
    const normalized = C.normalize(options);
    const view = try View.init(input, dictionary, chunk_start, chunk_len, normalized.lz77_options.window_len);
    if (chunk_len == 0) return C.plan(allocator, "", options);

    const copied: ?[]u8 = if (view.dictionary.len == 0)
        null
    else blk: {
        const len = std.math.add(usize, view.dictionary.len, view.input.len) catch
            return error.IntegerOverflow;
        const bytes = try allocator.alloc(u8, len);
        @memcpy(bytes[0..view.dictionary.len], view.dictionary);
        @memcpy(bytes[view.dictionary.len..], view.input);
        break :blk bytes;
    };
    defer if (copied) |bytes| allocator.free(bytes);
    const combined = copied orelse view.input;
    const history_len = view.dictionary.len + view.input_history_len;
    if (history_len == 0) return C.plan(allocator, combined, options);

    const plan = try C.plan(allocator, combined, options);
    defer plan.deinit(allocator);
    const trimmed = try trimPlanToSuffixAlloc(allocator, combined, plan.tokens, history_len);
    errdefer allocator.free(trimmed);
    var stats: lz77.PlanStats = .{};
    for (trimmed) |token| switch (token) {
        .literal => stats.literals += 1,
        .match => |match| {
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
    return .{ .tokens = trimmed, .stats = stats };
}

pub fn trimPlanToSuffixAlloc(
    allocator: std.mem.Allocator,
    combined: []const u8,
    tokens: []const lz77.Token,
    skip: usize,
) ![]lz77.Token {
    if (skip > combined.len) return error.InvalidBlockPlan;
    var out: std.ArrayList(lz77.Token) = .empty;
    errdefer out.deinit(allocator);
    var consumed: usize = 0;
    for (tokens) |token| {
        const token_len: usize = switch (token) {
            .literal => 1,
            .match => |match| match.length,
        };
        if (token_len == 0 or token_len > combined.len - consumed)
            return error.InvalidBlockPlan;
        const end = consumed + token_len;
        if (end <= skip) {
            consumed = end;
            continue;
        }
        if (consumed < skip) {
            switch (token) {
                .literal => return error.InvalidBlockPlan,
                .match => |match| {
                    const remaining = end - skip;
                    if (remaining >= 3) {
                        try out.append(allocator, .{ .match = .{
                            .length = @intCast(remaining),
                            .distance = match.distance,
                        } });
                    } else {
                        for (combined[skip..end]) |byte|
                            try out.append(allocator, .{ .literal = byte });
                    }
                },
            }
        } else {
            try out.append(allocator, token);
        }
        consumed = end;
    }
    if (consumed != combined.len) return error.InvalidBlockPlan;
    return out.toOwnedSlice(allocator);
}
