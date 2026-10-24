//! Pure canonical parameter query for full-feature Zstd 1.6.0.
//! The versioned level table is data from lib/compress/clevels.h; size
//! refinement follows the public ZSTD_getCParams() contract. No codec, index,
//! entropy state, allocation, or legacy automatic dispatch is changed here.
const std = @import("std");
const controls = @import("controls.zig");

pub const Error = controls.Error || error{IntegerOverflow};
pub const Strategy = controls.Strategy;
pub const reference_version = "1.6.0";
pub const default_level: c_int = 3;
pub const window_log_max: u32 = if (@sizeOf(usize) == 4) 30 else 31;
pub const hash_log_max: u32 = @min(window_log_max, 30);
pub const chain_log_max: u32 = if (@sizeOf(usize) == 4) 29 else 30;

/// Like public ZSTD_getCParams(), zero and maxInt(u64) source hints mean
/// unknown. Dictionary size zero means unused. Known empty input is not
/// represented by this public-query convention.
pub const Options = struct {
    level: c_int = default_level,
    source_size_hint: u64 = 0,
    dictionary_size: usize = 0,
};

pub const Parameters = struct {
    window_log: u32,
    hash_log: u32,
    chain_log: u32,
    search_log: u32,
    min_match: u32,
    target_length: u32,
    strategy: Strategy,

    /// Negative canonical levels use target_length as Fast's real sampling
    /// acceleration. Positive-level tables set Fast target_length to zero.
    pub fn fastAcceleration(self: Parameters) ?u32 {
        return if (self.strategy == .fast and self.target_length != 0) self.target_length else null;
    }

    /// Convert only the five deep-search strategies to current Vort controls.
    /// Search depth is 2^search_log. A zero target uses Vort's 128-byte default;
    /// canonical deep-search entries currently all have nonzero targets.
    /// hash_log and chain_log remain reference metadata: HqOptions has no
    /// corresponding allocation controls. This method promises no reference
    /// index layout, compressed bytes, ratio, or throughput equivalence.
    pub fn hqOptions(self: Parameters) Error!?controls.HqOptions {
        switch (self.strategy) {
            .lazy2, .btlazy2, .btopt, .btultra, .btultra2 => {},
            else => return null,
        }
        if (self.search_log < 1 or self.search_log > 16) return error.InvalidBlockPlan;
        const hq = controls.HqOptions{
            .search_depth = @as(u32, 1) << @intCast(self.search_log),
            .nice_len = if (self.target_length == 0) 128 else self.target_length,
            .min_match = std.math.cast(u8, self.min_match) orelse return error.InvalidBlockPlan,
        };
        try hq.validate();
        return hq;
    }

    /// Reference minimum emitted/search match, distinct from its primary
    /// min_match hash hint. btopt+ can use three bytes; other entries use four.
    pub fn referenceMinimumMatch(self: Parameters) u32 {
        return switch (self.strategy) {
            .btopt, .btultra, .btultra2 => if (self.min_match == 3) 3 else 4,
            else => 4,
        };
    }
};

/// This API rejects levels outside Vort's existing -131072...22 range.
/// Reference ZSTD_getCParams() instead clamps high levels and negative
/// acceleration. Arithmetic overflow is also rejected, rather than allowing
/// an impossible known-size or dictionary hint to select a wrapped table row.
pub fn resolveCanonicalCompressionParameters(level: c_int, source_size_hint: u64, dictionary_size: usize) Error!Parameters {
    return resolve(.{ .level = level, .source_size_hint = source_size_hint, .dictionary_size = dictionary_size });
}

pub fn resolve(options: Options) Error!Parameters {
    if (options.level < controls.min_level or options.level > controls.max_level) return error.InvalidBlockPlan;
    const unknown = options.source_size_hint == 0 or options.source_size_hint == std.math.maxInt(u64);
    const dictionary: u64 = @intCast(options.dictionary_size);
    // Reference adds its unknown sentinel (-1), dictionary, and 500. Spell
    // the intended dictionary+499 result without unsigned wrap.
    const row_size = if (unknown)
        (if (dictionary == 0) std.math.maxInt(u64) else try sizeAdd(dictionary, 499))
    else
        try sizeAdd(options.source_size_hint, dictionary);
    const table: usize = if (row_size <= 16 * 1024) 3 else if (row_size <= 128 * 1024) 2 else if (row_size <= 256 * 1024) 1 else 0;
    const row: usize = if (options.level < 0) 0 else @intCast(if (options.level == 0) default_level else options.level);
    var parameters = parameter_tables[table][row];
    if (options.level < 0) parameters.target_length = @intCast(-options.level);
    return refine(parameters, if (unknown) null else options.source_size_hint, dictionary);
}

fn refine(original: Parameters, source: ?u64, dictionary: u64) Error!Parameters {
    var result = original;
    const max_resize = @as(u64, 1) << @intCast(window_log_max - 1);
    if (source) |size| {
        if (size <= max_resize and dictionary <= max_resize) {
            const total = try sizeAdd(size, dictionary);
            result.window_log = @min(result.window_log, @max(@as(u32, 6), ceilLog2(total)));
        }
        const combined_log = try dictionaryAndWindowLog(result.window_log, size, dictionary);
        result.hash_log = @min(result.hash_log, combined_log + 1);
        const binary_tree: u32 = switch (result.strategy) {
            .btlazy2, .btopt, .btultra, .btultra2 => 1,
            else => 0,
        };
        const cycle_log = result.chain_log - binary_tree;
        if (cycle_log > combined_log) result.chain_log -= cycle_log - combined_log;
    }
    // Apply the frame minimum after index refinement: tiny inputs can retain
    // seven-bit indexes while advertising the ten-bit minimum window.
    result.window_log = @max(result.window_log, 10);
    switch (result.strategy) {
        .greedy, .lazy, .lazy2 => result.hash_log = @min(result.hash_log, 24 + std.math.clamp(result.search_log, 4, 6)),
        else => {},
    }
    return result;
}

fn dictionaryAndWindowLog(window_log: u32, source: u64, dictionary: u64) Error!u32 {
    if (dictionary == 0) return window_log;
    const window = @as(u64, 1) << @intCast(window_log);
    if (window >= try sizeAdd(dictionary, source)) return window_log;
    const combined = try sizeAdd(dictionary, window);
    return if (combined >= (@as(u64, 1) << @intCast(window_log_max))) window_log_max else ceilLog2(combined);
}

fn ceilLog2(value: u64) u32 {
    return if (value <= 1) 0 else @intCast(64 - @clz(value - 1));
}

fn sizeAdd(a: u64, b: u64) Error!u64 {
    return std.math.add(u64, a, b) catch error.IntegerOverflow;
}

fn p(w: u32, c: u32, h: u32, s: u32, m: u32, t: u32, strategy: Strategy) Parameters {
    return .{ .window_log = w, .chain_log = c, .hash_log = h, .search_log = s, .min_match = m, .target_length = t, .strategy = strategy };
}

// Column order follows reference data: window, chain, hash, search, min,
// target, strategy. Row zero is the negative-level base, not public level0.
const parameter_tables = [4][23]Parameters{
    .{
        p(19, 12, 13, 1, 6, 1, .fast), // negative base
        p(19, 13, 14, 1, 7, 0, .fast), // level 1
        p(20, 15, 16, 1, 6, 0, .fast), // level 2
        p(21, 16, 17, 1, 5, 0, .double_fast), // level 3
        p(21, 18, 18, 1, 5, 0, .double_fast), // level 4
        p(21, 18, 19, 3, 5, 2, .greedy), // level 5
        p(21, 18, 19, 3, 5, 4, .lazy), // level 6
        p(21, 19, 20, 4, 5, 8, .lazy), // level 7
        p(21, 19, 20, 4, 5, 16, .lazy2), // level 8
        p(22, 20, 21, 4, 5, 16, .lazy2), // level 9
        p(22, 21, 22, 5, 5, 16, .lazy2), // level 10
        p(22, 21, 22, 6, 5, 16, .lazy2), // level 11
        p(22, 22, 23, 6, 5, 32, .lazy2), // level 12
        p(22, 22, 22, 4, 5, 32, .btlazy2), // level 13
        p(22, 22, 23, 5, 5, 32, .btlazy2), // level 14
        p(22, 23, 23, 6, 5, 32, .btlazy2), // level 15
        p(22, 22, 22, 5, 5, 48, .btopt), // level 16
        p(23, 23, 22, 5, 4, 64, .btopt), // level 17
        p(23, 23, 22, 6, 3, 64, .btultra), // level 18
        p(23, 24, 22, 7, 3, 256, .btultra2), // level 19
        p(25, 25, 23, 7, 3, 256, .btultra2), // level 20
        p(26, 26, 24, 7, 3, 512, .btultra2), // level 21
        p(27, 27, 25, 9, 3, 999, .btultra2), // level 22
    },
    .{
        p(18, 12, 13, 1, 5, 1, .fast), // negative base
        p(18, 13, 14, 1, 6, 0, .fast), // level 1
        p(18, 14, 14, 1, 5, 0, .double_fast), // level 2
        p(18, 16, 16, 1, 4, 0, .double_fast), // level 3
        p(18, 16, 17, 3, 5, 2, .greedy), // level 4
        p(18, 17, 18, 5, 5, 2, .greedy), // level 5
        p(18, 18, 19, 3, 5, 4, .lazy), // level 6
        p(18, 18, 19, 4, 4, 4, .lazy), // level 7
        p(18, 18, 19, 4, 4, 8, .lazy2), // level 8
        p(18, 18, 19, 5, 4, 8, .lazy2), // level 9
        p(18, 18, 19, 6, 4, 8, .lazy2), // level 10
        p(18, 18, 19, 5, 4, 12, .btlazy2), // level 11
        p(18, 19, 19, 7, 4, 12, .btlazy2), // level 12
        p(18, 18, 19, 4, 4, 16, .btopt), // level 13
        p(18, 18, 19, 4, 3, 32, .btopt), // level 14
        p(18, 18, 19, 6, 3, 128, .btopt), // level 15
        p(18, 19, 19, 6, 3, 128, .btultra), // level 16
        p(18, 19, 19, 8, 3, 256, .btultra), // level 17
        p(18, 19, 19, 6, 3, 128, .btultra2), // level 18
        p(18, 19, 19, 8, 3, 256, .btultra2), // level 19
        p(18, 19, 19, 10, 3, 512, .btultra2), // level 20
        p(18, 19, 19, 12, 3, 512, .btultra2), // level 21
        p(18, 19, 19, 13, 3, 999, .btultra2), // level 22
    },
    .{
        p(17, 12, 12, 1, 5, 1, .fast), // negative base
        p(17, 12, 13, 1, 6, 0, .fast), // level 1
        p(17, 13, 15, 1, 5, 0, .fast), // level 2
        p(17, 15, 16, 2, 5, 0, .double_fast), // level 3
        p(17, 17, 17, 2, 4, 0, .double_fast), // level 4
        p(17, 16, 17, 3, 4, 2, .greedy), // level 5
        p(17, 16, 17, 3, 4, 4, .lazy), // level 6
        p(17, 16, 17, 3, 4, 8, .lazy2), // level 7
        p(17, 16, 17, 4, 4, 8, .lazy2), // level 8
        p(17, 16, 17, 5, 4, 8, .lazy2), // level 9
        p(17, 16, 17, 6, 4, 8, .lazy2), // level 10
        p(17, 17, 17, 5, 4, 8, .btlazy2), // level 11
        p(17, 18, 17, 7, 4, 12, .btlazy2), // level 12
        p(17, 18, 17, 3, 4, 12, .btopt), // level 13
        p(17, 18, 17, 4, 3, 32, .btopt), // level 14
        p(17, 18, 17, 6, 3, 256, .btopt), // level 15
        p(17, 18, 17, 6, 3, 128, .btultra), // level 16
        p(17, 18, 17, 8, 3, 256, .btultra), // level 17
        p(17, 18, 17, 10, 3, 512, .btultra), // level 18
        p(17, 18, 17, 5, 3, 256, .btultra2), // level 19
        p(17, 18, 17, 7, 3, 512, .btultra2), // level 20
        p(17, 18, 17, 9, 3, 512, .btultra2), // level 21
        p(17, 18, 17, 11, 3, 999, .btultra2), // level 22
    },
    .{
        p(14, 12, 13, 1, 5, 1, .fast), // negative base
        p(14, 14, 15, 1, 5, 0, .fast), // level 1
        p(14, 14, 15, 1, 4, 0, .fast), // level 2
        p(14, 14, 15, 2, 4, 0, .double_fast), // level 3
        p(14, 14, 14, 4, 4, 2, .greedy), // level 4
        p(14, 14, 14, 3, 4, 4, .lazy), // level 5
        p(14, 14, 14, 4, 4, 8, .lazy2), // level 6
        p(14, 14, 14, 6, 4, 8, .lazy2), // level 7
        p(14, 14, 14, 8, 4, 8, .lazy2), // level 8
        p(14, 15, 14, 5, 4, 8, .btlazy2), // level 9
        p(14, 15, 14, 9, 4, 8, .btlazy2), // level 10
        p(14, 15, 14, 3, 4, 12, .btopt), // level 11
        p(14, 15, 14, 4, 3, 24, .btopt), // level 12
        p(14, 15, 14, 5, 3, 32, .btultra), // level 13
        p(14, 15, 15, 6, 3, 64, .btultra), // level 14
        p(14, 15, 15, 7, 3, 256, .btultra), // level 15
        p(14, 15, 15, 5, 3, 48, .btultra2), // level 16
        p(14, 15, 15, 6, 3, 128, .btultra2), // level 17
        p(14, 15, 15, 7, 3, 256, .btultra2), // level 18
        p(14, 15, 15, 8, 3, 256, .btultra2), // level 19
        p(14, 15, 15, 8, 3, 512, .btultra2), // level 20
        p(14, 15, 15, 9, 3, 512, .btultra2), // level 21
        p(14, 15, 15, 10, 3, 999, .btultra2), // level 22
    },
};

test {
    _ = @import("canonical_presets_tests.zig");
}
