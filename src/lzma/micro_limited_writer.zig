const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");
const encoder = @import("encoder.zig");
const range_encoder = @import("range_encoder.zig");
const wide_match = @import("wide_match.zig");

pub const Error = core.Error || encoder.Error || std.mem.Allocator.Error;
pub const min_destination_size: usize = 6;
pub const Options = encoder.EncodeOptions;

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
    if (options.match_options) |match| match.recordEffectiveSettings();
    var consumed: usize = 0;
    var checkpoint = Checkpoint{ .range = range };
    var stats: EmissionStats = .{ .profile = if (options.match_options) |match| match.profile else null };

    if (options.mode != .literal_only and (options.match_options != null or options.mode == .fast or options.mode == .normal)) {
        try appendAdvancedPrefixes(allocator, &range, &model, input, &consumed, capacity, alignment, &checkpoint, &stats, options);
    } else if (options.mode == .literal_only) {
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
    const bytes = try output.toOwnedSlice(allocator);
    return .{ .bytes = bytes, .consumed = consumed };
}

fn appendAdvancedPrefixes(
    allocator: std.mem.Allocator,
    range: *range_encoder.Encoder,
    model: *encoder.Model,
    input: []const u8,
    consumed: *usize,
    capacity: usize,
    alignment: usize,
    checkpoint: *Checkpoint,
    stats: *EmissionStats,
    options: encoder.EncodeOptions,
) Error!void {
    const lookahead: usize = encoder.advanced_input_min;
    while (consumed.* < input.len) {
        const start = consumed.*;
        const end = start + @min(input.len - start, lookahead);
        const history_begin = start - @min(start, options.dictionary_size);
        var plan = try encoder.advancedPlanPrefix(allocator, model, input[history_begin..start], input[start..end], start, options, end == input.len);
        defer plan.deinit(allocator);
        try appendTokens(range, model, input, consumed, capacity, alignment, checkpoint, stats, plan.tokens);
        if (consumed.* - start != plan.consumed) break;
        if (plan.consumed == 0) return error.InvalidMatch;
    }
}

const Checkpoint = struct {
    range: range_encoder.Encoder,
    output_len: usize = 0,
    consumed: usize = 0,
};

const EmissionStats = struct {
    coding: encoder.EncodeStats = .{ .input_bytes = 0, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 },
    profile: ?*encoder.EncodeWorkProfile = null,
};

fn appendTokens(
    range: *range_encoder.Encoder,
    model: *encoder.Model,
    input: []const u8,
    consumed: *usize,
    capacity: usize,
    alignment: usize,
    checkpoint: *Checkpoint,
    stats: *EmissionStats,
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
    stats: *EmissionStats,
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
            const short_rep = switch (piece) {
                .literal => false,
                .match => |match| match.length == 1 and match.distance == model.reps[0] + 1,
            };
            // Alignment can replace tiny pieces of a long match with literals,
            // changing the planned rep cache. Preserve a short rep only when it
            // is still the actual model's rep0; a literal remains lossless.
            if (!short_rep) piece = .{ .literal = input[consumed.*] };
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
    stats: *EmissionStats,
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
    _ = try model.encodeTokensWithDictionaryProfiled(
        range,
        input[consumed.*..end],
        input[0..consumed.*],
        &tokens,
        consumed.*,
        &stats.coding,
        stats.profile,
    );
    switch (token) {
        .literal => stats.coding.literals += 1,
        .match => |match| {
            stats.coding.matches += 1;
            stats.coding.matched_bytes += match.length;
        },
    }
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
