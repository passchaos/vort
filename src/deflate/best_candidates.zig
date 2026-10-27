//! Complete candidate arbitration within the caller's compression bounds.
const std = @import("std");

pub fn Candidates(comptime Options: type) type {
    return struct {
        items: [2]Options = undefined,
        len: usize = 0,
        pub fn slice(self: *const @This()) []const Options {
            return self.items[0..self.len];
        }
    };
}

pub fn build(options: anytype, defaults: @TypeOf(options)) Candidates(@TypeOf(options)) {
    var result: Candidates(@TypeOf(options)) = .{};
    if (options.strategy != .default or options.parser != .optimal) return result;
    var fallback = defaults;
    fallback.block_selection = options.block_selection;
    const original = options.lz77_options;
    fallback.lz77_options.window_len = @min(fallback.lz77_options.window_len, original.window_len);
    fallback.lz77_options.max_chain = @min(fallback.lz77_options.max_chain, original.max_chain);
    fallback.lz77_options.nice_len = @min(fallback.lz77_options.nice_len, original.nice_len);
    fallback.lz77_options.max_candidates = @min(fallback.lz77_options.max_candidates, original.max_candidates);
    fallback.lz77_options.lazy_min_gain = @max(fallback.lz77_options.lazy_min_gain, original.lazy_min_gain);
    fallback.lz77_options.min_match = @max(fallback.lz77_options.min_match, original.min_match);
    fallback.lz77_options.max_match = @min(fallback.lz77_options.max_match, original.max_match);
    fallback.lz77_options.min_savings_bits = @max(fallback.lz77_options.min_savings_bits, original.min_savings_bits);
    fallback.lz77_options.new_distance_penalty_bits = original.new_distance_penalty_bits;
    fallback.split_options.max_block_len = @min(defaults.split_options.max_block_len, options.split_options.max_block_len);
    fallback.split_options.min_block_len = @min(fallback.split_options.max_block_len, @max(defaults.split_options.min_block_len, options.split_options.min_block_len));
    fallback.split_options.sample_len = @min(defaults.split_options.sample_len, options.split_options.sample_len);
    fallback.split_options.search_step = @max(defaults.split_options.search_step, options.split_options.search_step);
    var filtered = options;
    filtered.strategy = .filtered;
    result.items = .{ fallback, filtered };
    result.len = 2;
    return result;
}

/// Ties retain the earlier candidate. Exactly one owned buffer remains.
pub fn keepSmaller(allocator: std.mem.Allocator, selected: *[]u8, candidate: []u8) void {
    if (candidate.len < selected.*.len) {
        allocator.free(selected.*);
        selected.* = candidate;
    } else allocator.free(candidate);
}

pub fn admitsDefaults(options: anytype, defaults: @TypeOf(options)) bool {
    const original = options.lz77_options;
    const proposed = defaults.lz77_options;
    return defaults.block_selection == options.block_selection and
        proposed.window_len <= original.window_len and
        proposed.max_chain <= original.max_chain and
        proposed.nice_len <= original.nice_len and
        proposed.max_candidates <= original.max_candidates and
        proposed.lazy_min_gain >= original.lazy_min_gain and
        proposed.min_match >= original.min_match and
        proposed.max_match <= original.max_match and
        proposed.min_savings_bits >= original.min_savings_bits and
        proposed.new_distance_penalty_bits == original.new_distance_penalty_bits and
        defaults.split_options.min_block_len >= options.split_options.min_block_len and
        defaults.split_options.max_block_len <= options.split_options.max_block_len and
        defaults.split_options.sample_len <= options.split_options.sample_len and
        defaults.split_options.search_step >= options.split_options.search_step;
}

/// Keep ordinary preset calls constant so their existing specialized kernels
/// survive inlining. The bounded path is used only when caller limits require it.
pub inline fn compete(allocator: std.mem.Allocator, selected: *[]u8, options: anytype, comptime defaults: @TypeOf(options), comptime encode: anytype, args: anytype) !void {
    if (options.strategy != .default or options.parser != .optimal) return;
    if (admitsDefaults(options, defaults)) {
        const candidate = try @call(.auto, encode, args ++ .{defaults});
        keepSmaller(allocator, selected, candidate);
    } else {
        const fixed_defaults = comptime blk: {
            var fixed = defaults;
            fixed.block_selection = .stored_fixed;
            break :blk fixed;
        };
        if (admitsDefaults(options, fixed_defaults)) {
            const candidate = try @call(.auto, encode, args ++ .{fixed_defaults});
            keepSmaller(allocator, selected, candidate);
        } else {
            const bounded = build(options, defaults).items[0];
            const candidate = try @call(.auto, encode, args ++ .{bounded});
            keepSmaller(allocator, selected, candidate);
        }
    }
    var filtered = options;
    filtered.strategy = .filtered;
    const candidate = try @call(.auto, encode, args ++ .{filtered});
    keepSmaller(allocator, selected, candidate);
}
