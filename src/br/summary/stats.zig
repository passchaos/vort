//! Checked logical output and aggregate counters for Brotli size preflight.
const std = @import("std");
const core = @import("../../core.zig");
const Counter = core.StreamCount;
const types = @import("types.zig");
pub const Error = core.Error;

pub fn addDecoded(current: Counter, len: usize, limit: Counter) Error!Counter {
    const next = try core.stream_count.addLocal(current, len);
    if (next > limit) return error.OutputLimitExceeded;
    return next;
}

pub fn apply(summary: *types.StreamSummary, stats: types.MetaBlockStats) Error!void {
    var next = summary.*;
    if (stats.static_dictionary_copy_count != 0) {
        next.uses_static_dictionary = true;
        next.static_dictionary_copy_count = std.math.add(Counter, next.static_dictionary_copy_count, stats.static_dictionary_copy_count) catch return error.IntegerOverflow;
        next.static_dictionary_bytes = try core.stream_count.addLocal(next.static_dictionary_bytes, stats.static_dictionary_bytes);
    }
    if (stats.shared_dictionary_copy_count != 0) {
        next.uses_shared_dictionary = true;
        next.shared_dictionary_copy_count = std.math.add(Counter, next.shared_dictionary_copy_count, stats.shared_dictionary_copy_count) catch return error.IntegerOverflow;
        next.shared_dictionary_bytes = try core.stream_count.addLocal(next.shared_dictionary_bytes, stats.shared_dictionary_bytes);
    }
    next.command_count = std.math.add(Counter, next.command_count, stats.command_count) catch return error.IntegerOverflow;
    next.zero_insert_command_count = std.math.add(Counter, next.zero_insert_command_count, stats.zero_insert_command_count) catch return error.IntegerOverflow;
    next.single_literal_insert_command_count = try core.stream_count.addLocal(next.single_literal_insert_command_count, stats.single_literal_insert_command_count);
    next.implicit_distance_command_count = std.math.add(Counter, next.implicit_distance_command_count, stats.implicit_distance_command_count) catch return error.IntegerOverflow;
    next.implicit_distance_copy_count = std.math.add(Counter, next.implicit_distance_copy_count, stats.implicit_distance_copy_count) catch return error.IntegerOverflow;
    next.short_distance_copy_count = std.math.add(Counter, next.short_distance_copy_count, stats.short_distance_copy_count) catch return error.IntegerOverflow;
    next.direct_distance_copy_count = std.math.add(Counter, next.direct_distance_copy_count, stats.direct_distance_copy_count) catch return error.IntegerOverflow;
    next.regular_distance_copy_count = std.math.add(Counter, next.regular_distance_copy_count, stats.regular_distance_copy_count) catch return error.IntegerOverflow;
    for (&next.copy_length_log2_histogram, stats.copy_length_log2_histogram) |*total, count|
        total.* = std.math.add(Counter, total.*, count) catch return error.IntegerOverflow;
    next.lz77_copy_count = try core.stream_count.addLocal(next.lz77_copy_count, stats.lz77_copy_count);
    next.lz77_copy_bytes = try core.stream_count.addLocal(next.lz77_copy_bytes, stats.lz77_copy_bytes);
    next.max_lz77_distance = @max(next.max_lz77_distance, stats.max_lz77_distance);
    next.non_overlapping_lz77_copy_count = try core.stream_count.addLocal(next.non_overlapping_lz77_copy_count, stats.non_overlapping_lz77_copy_count);
    next.non_overlapping_lz77_copy_bytes = try core.stream_count.addLocal(next.non_overlapping_lz77_copy_bytes, stats.non_overlapping_lz77_copy_bytes);
    next.short_non_overlapping_lz77_copy_count = try core.stream_count.addLocal(next.short_non_overlapping_lz77_copy_count, stats.short_non_overlapping_lz77_copy_count);
    next.short_non_overlapping_lz77_copy_bytes = try core.stream_count.addLocal(next.short_non_overlapping_lz77_copy_bytes, stats.short_non_overlapping_lz77_copy_bytes);
    for (&next.literal_context_mode_bytes, stats.literal_context_mode_bytes) |*total, count|
        total.* = try core.stream_count.addLocal(total.*, count);
    next.max_literal_block_types = @max(next.max_literal_block_types, stats.max_literal_block_types);
    next.max_literal_context_trees = @max(next.max_literal_context_trees, stats.max_literal_context_trees);
    next.max_command_block_types = @max(next.max_command_block_types, stats.max_command_block_types);
    next.max_distance_block_types = @max(next.max_distance_block_types, stats.max_distance_block_types);
    next.max_distance_context_trees = @max(next.max_distance_context_trees, stats.max_distance_context_trees);
    next.max_distance_postfix_bits = @max(next.max_distance_postfix_bits, stats.max_distance_postfix_bits);
    next.max_direct_distance_codes = @max(next.max_direct_distance_codes, stats.max_direct_distance_codes);
    summary.* = next;
}
