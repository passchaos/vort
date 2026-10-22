const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");
const encoder = @import("encoder.zig");
const range_encoder = @import("range_encoder.zig");
const wide_match = @import("wide_match.zig");

pub const Error = core.Error || encoder.Error || std.mem.Allocator.Error;
pub const min_destination_size: usize = 6;

pub const Result = struct {
    written: usize,
    consumed: usize,
};

pub const EncodedPrefix = struct {
    bytes: []u8,
    consumed: usize,

    pub fn deinit(self: *EncodedPrefix, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    capacity: usize,
    options: encoder.EncodeOptions,
) Error!EncodedPrefix {
    return encodeAlignedAlloc(allocator, input, capacity, 1, options);
}

pub fn encodeAlignedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    capacity: usize,
    alignment: usize,
    options: encoder.EncodeOptions,
) Error!EncodedPrefix {
    if (alignment == 0) return error.InvalidLzmaOptions;
    if (capacity < min_destination_size) return error.OutputTooSmall;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var range = range_encoder.Encoder.init(allocator, &output);
    var model = try encoder.initModel(options);
    var consumed: usize = 0;
    var checkpoint = Checkpoint{ .range = range };
    var stats = encoder.EncodeStats{
        .input_bytes = input.len,
        .output_bytes = 0,
        .literals = 0,
        .matches = 0,
        .matched_bytes = 0,
        .repeat_matches = 0,
        .new_distance_matches = 0,
    };

    if (options.mode == .literal_only) {
        for (input) |byte| {
            if (!try appendAlignedToken(&range, &model, input, &consumed, capacity, alignment, &checkpoint, &stats, wide_match.Token{ .literal = byte }))
                break;
        }
    } else if (options.dictionary_size > std.math.maxInt(u16)) {
        var plan = try wide_match.planAlloc(allocator, input, &.{}, .{
            .window_len = options.dictionary_size,
            .lazy = options.mode == .lazy,
        });
        defer plan.deinit(allocator);
        try appendTokens(&range, &model, input, &consumed, capacity, alignment, &checkpoint, &stats, plan.tokens);
    } else if (options.mode == .lazy) {
        var plan = try lz77.lazyGreedyPlanAllocWithDictionary(allocator, input, &.{}, .{
            .window_len = options.dictionary_size,
            .max_chain = 64,
            .nice_len = 64,
            .max_candidates = 4,
            .lazy_min_gain = 1,
            .min_match = 3,
            .max_match = lz77.max_match_len,
        });
        defer plan.deinit(allocator);
        try appendTokens(&range, &model, input, &consumed, capacity, alignment, &checkpoint, &stats, plan.tokens);
    } else {
        var plan = try lz77.hashGreedyPlanAllocWithDictionary(allocator, input, &.{}, .{
            .window_len = options.dictionary_size,
            .max_chain = 64,
            .nice_len = 64,
            .max_candidates = 4,
            .min_match = 3,
            .max_match = lz77.max_match_len,
        });
        defer plan.deinit(allocator);
        try appendTokens(&range, &model, input, &consumed, capacity, alignment, &checkpoint, &stats, plan.tokens);
    }
    range = checkpoint.range;
    output.items.len = checkpoint.output_len;
    consumed = checkpoint.consumed;
    try range.finish();
    if (output.items.len > capacity or (alignment == 1 and input.len != 0 and consumed == 0))
        return error.InvalidBlockPlan;
    output.items[0] = ~try encoder.propertyByte(options.properties);
    return .{ .bytes = try output.toOwnedSlice(allocator), .consumed = consumed };
}

const Checkpoint = struct {
    range: range_encoder.Encoder,
    output_len: usize = 0,
    consumed: usize = 0,
};

fn appendTokens(
    range: *range_encoder.Encoder,
    model: *encoder.Model,
    input: []const u8,
    consumed: *usize,
    capacity: usize,
    alignment: usize,
    checkpoint: *Checkpoint,
    stats: *encoder.EncodeStats,
    tokens: anytype,
) Error!void {
    for (tokens) |token|
        if (!try appendAlignedToken(range, model, input, consumed, capacity, alignment, checkpoint, stats, token))
            break;
}

fn appendAlignedToken(
    range: *range_encoder.Encoder,
    model: *encoder.Model,
    input: []const u8,
    consumed: *usize,
    capacity: usize,
    alignment: usize,
    checkpoint: *Checkpoint,
    stats: *encoder.EncodeStats,
    token: anytype,
) Error!bool {
    var remaining: usize = switch (token) {
        .literal => 1,
        .match => |match| match.length,
    };
    while (remaining != 0) {
        const piece_len = if (alignment == 1) remaining else @min(remaining, alignment - consumed.* % alignment);
        var piece = token;
        if (piece_len == 1) {
            if (consumed.* >= input.len) return error.InvalidMatch;
            piece = .{ .literal = input[consumed.*] };
        } else {
            piece.match.length = @intCast(piece_len);
        }
        if (!try appendToken(range, model, input, consumed, capacity, stats, piece)) return false;
        remaining -= piece_len;
        if (consumed.* % alignment == 0 or consumed.* == input.len) {
            checkpoint.* = .{ .range = range.*, .output_len = range.output.items.len, .consumed = consumed.* };
        }
    }
    return true;
}

fn appendToken(
    range: *range_encoder.Encoder,
    model: *encoder.Model,
    input: []const u8,
    consumed: *usize,
    capacity: usize,
    stats: *encoder.EncodeStats,
    token: anytype,
) Error!bool {
    const length: usize = switch (token) {
        .literal => 1,
        .match => |match| match.length,
    };
    const end = std.math.add(usize, consumed.*, length) catch return error.IntegerOverflow;
    if (end > input.len) return error.InvalidMatch;
    const previous_range = range.*;
    const previous_output_len = range.output.items.len;
    const tokens = [_]@TypeOf(token){token};
    _ = try model.encodeTokensWithDictionary(
        range,
        input[consumed.*..end],
        input[0..consumed.*],
        &tokens,
        consumed.*,
        stats,
    );
    if (try range.finishedSize() > capacity) {
        // The probability model is discarded after this rejected symbol.
        // Only the accepted range state and byte prefix are needed to finish.
        range.output.items.len = previous_output_len;
        range.* = previous_range;
        return false;
    }
    consumed.* = end;
    return true;
}
