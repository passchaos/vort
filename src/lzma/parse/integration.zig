const std = @import("std");
const types = @import("types.zig");
const range_encoder = @import("../range_encoder.zig");

/// Encode against value snapshots and stage only produced range bytes. Neither
/// caller model/range nor its output changes until the final append succeeds.
/// This transaction's output and bounded prior-history ownership are outside
/// MatchOptions' matcher/parser working-allocation budget.
pub fn prefix(allocator: std.mem.Allocator, model: anytype, range: *range_encoder.Encoder, history: []const u8, input: []const u8, stream_start: usize, options: anytype, final_input: bool, stats: anytype, comptime planFn: anytype) !usize {
    const plan = try planFn(allocator, model, history, input, stream_start, options, final_input);
    defer plan.deinit(allocator);
    if (plan.consumed == 0) return 0;
    var shadow_model = model.*;
    var produced: std.ArrayList(u8) = .empty;
    defer produced.deinit(allocator);
    var shadow_range = range.*;
    shadow_range.output = &produced;
    shadow_range.allocator = allocator;
    var delta: @TypeOf(stats.*) = .{ .input_bytes = plan.consumed, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 };
    for (plan.tokens) |token| switch (token) {
        .literal => delta.literals += 1,
        .match => |match| {
            delta.matches += 1;
            delta.matched_bytes += match.length;
        },
    };
    const profile = if (options.match_options) |match| match.profile else null;
    const consumed = try shadow_model.encodeTokensWithDictionaryProfiled(&shadow_range, input[0..plan.consumed], history, plan.tokens, stream_start, &delta, profile);
    if (consumed != plan.consumed or !std.meta.eql(types.State.fromModel(&shadow_model), plan.final_state)) return error.InvalidBlockPlan;
    delta.output_bytes = produced.items.len;
    var updated_stats = stats.*;
    inline for (.{ "input_bytes", "output_bytes", "literals", "matches", "matched_bytes", "repeat_matches", "new_distance_matches" }) |field|
        @field(updated_stats, field) = std.math.add(usize, @field(stats, field), @field(delta, field)) catch return error.IntegerOverflow;
    try range.output.ensureUnusedCapacity(range.allocator, produced.items.len);
    range.output.appendSliceAssumeCapacity(produced.items);
    model.* = shadow_model;
    range.low = shadow_range.low;
    range.range = shadow_range.range;
    range.cache = shadow_range.cache;
    range.cache_size = shadow_range.cache_size;
    stats.* = updated_stats;
    return consumed;
}

pub fn stream(allocator: std.mem.Allocator, model: anytype, range: *range_encoder.Encoder, dictionary: []const u8, input: []const u8, stream_start: usize, options: anytype, stats: anytype, comptime prefixFn: anytype) !void {
    var joined_history: std.ArrayList(u8) = .empty;
    defer joined_history.deinit(allocator);
    var position: usize = 0;
    while (position < input.len) {
        const history = if (position == 0) dictionary else if (position >= options.dictionary_size) input[position - options.dictionary_size .. position] else if (dictionary.len == 0) input[0..position] else blk: {
            const kept_dictionary = @min(dictionary.len, options.dictionary_size - position);
            joined_history.clearRetainingCapacity();
            try joined_history.ensureTotalCapacityPrecise(allocator, kept_dictionary + position);
            joined_history.appendSliceAssumeCapacity(dictionary[dictionary.len - kept_dictionary ..]);
            joined_history.appendSliceAssumeCapacity(input[0..position]);
            break :blk joined_history.items;
        };
        const absolute = std.math.add(usize, stream_start, position) catch return error.IntegerOverflow;
        const consumed = try prefixFn(allocator, model, range, history, input[position..], absolute, options, true, stats);
        if (consumed == 0 or consumed > input.len - position) return error.InvalidBlockPlan;
        position += consumed;
    }
}
