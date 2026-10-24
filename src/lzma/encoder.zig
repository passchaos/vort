const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../lz77.zig");
const range_encoder = @import("range_encoder.zig");
const wide_match = @import("wide_match.zig");
const settings = @import("encode_options.zig");
const advanced_types = @import("parse/types.zig");
const advanced_planner = @import("parse/planner.zig");
const advanced_integration = @import("parse/integration.zig");

const lazy_text_section = switch (builtin.object_format) {
    .elf => ".vort_lzma_lazy",
    .macho => "__TEXT,__vort_lzma_lazy",
    .coff => ".text$vort_lzma_lazy",
    else => ".text",
};

pub const Error = lz77.Error || error{ InvalidLzmaOptions, WorkingMemoryLimitExceeded, CompressedPayloadLimitExceeded };
pub const Properties = settings.Properties;
pub const Mode = settings.Mode;
pub const MatchOptions = settings.MatchOptions;
pub const EncodeWorkProfile = settings.EncodeWorkProfile;

pub const EncodeOptions = struct {
    properties: Properties = .{},
    dictionary_size: usize = 4096,
    mode: Mode = .greedy,
    end_marker: bool = false,
    match_options: ?MatchOptions = null,

    pub fn fromPreset(level: u32, extreme: bool) Error!EncodeOptions {
        const preset = try settings.resolvePreset(level, extreme);
        return .{ .properties = preset.properties, .dictionary_size = preset.dictionary_size, .mode = preset.mode, .match_options = preset.match_options };
    }
};

pub const AdvancedToken = advanced_types.Token;
pub const AdvancedPlan = advanced_types.Plan;
pub const advanced_window_len = advanced_types.window_len;
pub const advanced_guard_len = advanced_types.guard_len;
pub const advanced_input_min = advanced_window_len + advanced_guard_len;

pub fn resolvedMatchOptions(options: EncodeOptions) MatchOptions {
    return options.match_options orelse .{ .finder = if (options.mode == .normal) .bt4 else .hc4 };
}

fn recordEffectiveSettings(options: EncodeOptions) void {
    resolvedMatchOptions(options).recordEffectiveSettings();
}

/// Stable, owned numeric token plan shared by one-shot, streaming and bounded
/// MicroLZMA writers. It does not change the supplied model or finish a range.
pub fn advancedPlanPrefix(allocator: std.mem.Allocator, model: *const Model, history: []const u8, input: []const u8, stream_start: usize, options: EncodeOptions, final_input: bool) !AdvancedPlan {
    try validateOptions(options);
    if (options.mode == .literal_only or history.len > stream_start or model.dictionary_size != options.dictionary_size or !std.meta.eql(model.properties, options.properties)) return error.InvalidLzmaOptions;
    recordEffectiveSettings(options);
    return advanced_planner.plan(allocator, model, history, input, stream_start, options.dictionary_size, options.mode, resolvedMatchOptions(options), final_input);
}

test {
    _ = @import("parse/tests.zig");
}

/// Non-final calls need advanced_input_min lookahead. Return the exact committed
/// prefix at a complete symbol boundary, preserving model/range/output on error.
pub fn encodeAdvancedPrefix(allocator: std.mem.Allocator, model: *Model, range: *range_encoder.Encoder, history: []const u8, input: []const u8, stream_start: usize, options: EncodeOptions, final_input: bool, stats: *EncodeStats) !usize {
    return advanced_integration.prefix(allocator, model, range, history, input, stream_start, options, final_input, stats, advancedPlanPrefix);
}

pub const EncodeStats = struct {
    input_bytes: usize,
    output_bytes: usize,
    literals: usize,
    matches: usize,
    matched_bytes: usize,
    repeat_matches: usize,
    new_distance_matches: usize,
};

pub const max_dictionary_size: usize = settings.max_dictionary_size;
pub const WideStreamPlanner = wide_match.StreamPlanner;
pub const WideStreamPlan = wide_match.StreamPlan;

pub fn initModel(options: EncodeOptions) Error!Model {
    try validateOptions(options);
    return .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
    };
}

const max_states: usize = 12;
const max_position_states: usize = 16;
const max_literal_contexts: usize = 16;
const literal_tree_size: usize = 0x300;

const LengthEncoder = struct {
    choice: u16 = 0x400,
    choice2: u16 = 0x400,
    low: [max_position_states][8]u16 = @splat(@splat(0x400)),
    mid: [max_position_states][8]u16 = @splat(@splat(0x400)),
    high: [256]u16 = @splat(0x400),

    fn encode(
        self: *LengthEncoder,
        range: *range_encoder.Encoder,
        symbol: usize,
        position_state: usize,
    ) !void {
        if (symbol < 8) {
            try range.encodeBit(&self.choice, false);
            try range.encodeBitTree(&self.low[position_state], symbol, 3);
        } else if (symbol < 16) {
            try range.encodeBit(&self.choice, true);
            try range.encodeBit(&self.choice2, false);
            try range.encodeBitTree(&self.mid[position_state], symbol - 8, 3);
        } else {
            if (symbol >= 272) return error.InvalidMatch;
            try range.encodeBit(&self.choice, true);
            try range.encodeBit(&self.choice2, true);
            try range.encodeBitTree(&self.high, symbol - 16, 8);
        }
    }
};

pub const Model = struct {
    properties: Properties,
    dictionary_size: usize,
    literal_probabilities: [max_literal_contexts][literal_tree_size]u16 = @splat(@splat(0x400)),
    position_slots: [4][64]u16 = @splat(@splat(0x400)),
    alignment: [16]u16 = @splat(0x400),
    positions: [115]u16 = @splat(0x400),
    is_match: [max_states * max_position_states]u16 = @splat(0x400),
    is_rep: [max_states]u16 = @splat(0x400),
    is_rep_g0: [max_states]u16 = @splat(0x400),
    is_rep_g1: [max_states]u16 = @splat(0x400),
    is_rep_g2: [max_states]u16 = @splat(0x400),
    is_rep_0long: [max_states * max_position_states]u16 = @splat(0x400),
    state: usize = 0,
    reps: [4]usize = @splat(0),
    length: LengthEncoder = .{},
    rep_length: LengthEncoder = .{},

    fn encodeTokens(
        self: *Model,
        range: *range_encoder.Encoder,
        input: []const u8,
        tokens: anytype,
        stats: *EncodeStats,
    ) !void {
        const consumed = try self.encodeTokensWithDictionary(
            range,
            input,
            &.{},
            tokens,
            0,
            stats,
        );
        if (consumed != input.len) return error.InvalidMatch;
    }

    pub fn encodeTokensWithDictionary(
        self: *Model,
        range: *range_encoder.Encoder,
        input: []const u8,
        dictionary: []const u8,
        tokens: anytype,
        stream_start: usize,
        stats: *EncodeStats,
    ) !usize {
        return self.encodeTokensWithDictionaryProfiled(range, input, dictionary, tokens, stream_start, stats, null);
    }

    pub fn encodeTokensWithDictionaryProfiled(
        self: *Model,
        range: *range_encoder.Encoder,
        input: []const u8,
        dictionary: []const u8,
        tokens: anytype,
        stream_start: usize,
        stats: *EncodeStats,
        profile: ?*EncodeWorkProfile,
    ) !usize {
        var position: usize = 0;
        for (tokens) |token| switch (token) {
            .literal => |byte| {
                if (position >= input.len or input[position] != byte) return error.InvalidMatch;
                const stream_position = std.math.add(usize, stream_start, position) catch
                    return error.IntegerOverflow;
                if (profile) |p| p.literals +|= 1;
                try self.encodeLiteral(range, dictionary, input, position, stream_position, byte);
                position += 1;
            },
            .match => |match| {
                const length: usize = match.length;
                const distance: usize = match.distance;
                const end = std.math.add(usize, position, length) catch return error.InvalidMatch;
                if (length == 0 or length > 273 or distance == 0 or
                    distance > dictionary.len + position or distance > self.dictionary_size or end > input.len)
                    return error.InvalidMatch;
                for (0..length) |index|
                    if (input[position + index] != byteAt(dictionary, input, dictionary.len + position + index - distance))
                        return error.InvalidMatch;
                const stream_position = std.math.add(usize, stream_start, position) catch
                    return error.IntegerOverflow;
                if (length == 1 and distance != self.reps[0] + 1) return error.InvalidMatch;
                if (profile) |p| {
                    p.matches +|= 1;
                    p.matched_bytes +|= @as(u64, @intCast(length));
                    if (findRep(self.reps, distance - 1) != null) p.repeat_matches +|= 1;
                    if (length == 1) p.short_reps +|= 1;
                }
                if (length == 1) {
                    try self.encodeShortRep(range, stream_position, stats);
                } else try self.encodeMatch(range, stream_position, length, distance, stats);
                position = end;
            },
        };
        return position;
    }

    fn encodeLiteral(
        self: *Model,
        range: *range_encoder.Encoder,
        dictionary: []const u8,
        input: []const u8,
        position: usize,
        stream_position: usize,
        byte: u8,
    ) !void {
        const position_state = stream_position & ((@as(usize, 1) << self.properties.pb) - 1);
        try range.encodeBit(&self.is_match[(self.state << 4) + position_state], false);
        const previous: usize = if (position == 0)
            if (dictionary.len == 0) 0 else dictionary[dictionary.len - 1]
        else
            input[position - 1];
        const literal_context = ((stream_position & ((@as(usize, 1) << self.properties.lp) - 1)) << self.properties.lc) +
            (previous >> (8 - self.properties.lc));
        const probabilities = &self.literal_probabilities[literal_context];
        var tree_index: usize = 1;
        var remaining_bits: u4 = 8;

        if (self.state >= 7) {
            const distance = self.reps[0] + 1;
            if (distance > dictionary.len + position) return error.InvalidMatch;
            var match_byte: usize = byteAt(
                dictionary,
                input,
                dictionary.len + position - distance,
            );
            while (tree_index < 0x100) {
                remaining_bits -= 1;
                const match_bit = match_byte >> 7 & 1;
                match_byte <<= 1;
                const bit = @as(usize, byte) >> @intCast(remaining_bits) & 1;
                try range.encodeBit(&probabilities[((1 + match_bit) << 8) + tree_index], bit != 0);
                tree_index = (tree_index << 1) | bit;
                if (match_bit != bit) break;
            }
        }
        while (tree_index < 0x100) {
            remaining_bits -= 1;
            const bit = @as(usize, byte) >> @intCast(remaining_bits) & 1;
            try range.encodeBit(&probabilities[tree_index], bit != 0);
            tree_index = (tree_index << 1) | bit;
        }
        self.state = if (self.state < 4)
            0
        else if (self.state < 10)
            self.state - 3
        else
            self.state - 6;
    }

    fn encodeMatch(
        self: *Model,
        range: *range_encoder.Encoder,
        position: usize,
        match_length: usize,
        distance: usize,
        stats: *EncodeStats,
    ) !void {
        const position_state = position & ((@as(usize, 1) << self.properties.pb) - 1);
        try range.encodeBit(&self.is_match[(self.state << 4) + position_state], true);
        const distance_minus_one = distance - 1;
        const rep_index = findRep(self.reps, distance_minus_one);
        if (rep_index) |index| {
            stats.repeat_matches += 1;
            try range.encodeBit(&self.is_rep[self.state], true);
            if (index == 0) {
                try range.encodeBit(&self.is_rep_g0[self.state], false);
                try range.encodeBit(&self.is_rep_0long[(self.state << 4) + position_state], true);
            } else {
                try range.encodeBit(&self.is_rep_g0[self.state], true);
                if (index == 1) {
                    try range.encodeBit(&self.is_rep_g1[self.state], false);
                } else {
                    try range.encodeBit(&self.is_rep_g1[self.state], true);
                    try range.encodeBit(&self.is_rep_g2[self.state], index == 3);
                }
                const selected = self.reps[index];
                var current = index;
                while (current != 0) : (current -= 1) self.reps[current] = self.reps[current - 1];
                self.reps[0] = selected;
            }
            try self.rep_length.encode(range, match_length - 2, position_state);
            self.state = if (self.state < 7) 8 else 11;
            return;
        }

        stats.new_distance_matches += 1;
        try range.encodeBit(&self.is_rep[self.state], false);
        self.reps[3] = self.reps[2];
        self.reps[2] = self.reps[1];
        self.reps[1] = self.reps[0];
        self.reps[0] = distance_minus_one;
        try self.length.encode(range, match_length - 2, position_state);
        self.state = if (self.state < 7) 7 else 10;
        try self.encodeDistance(range, match_length - 2, distance_minus_one);
    }

    fn encodeShortRep(self: *Model, range: *range_encoder.Encoder, position: usize, stats: *EncodeStats) !void {
        const position_state = position & ((@as(usize, 1) << self.properties.pb) - 1);
        try range.encodeBit(&self.is_match[(self.state << 4) + position_state], true);
        try range.encodeBit(&self.is_rep[self.state], true);
        try range.encodeBit(&self.is_rep_g0[self.state], false);
        try range.encodeBit(&self.is_rep_0long[(self.state << 4) + position_state], false);
        self.state = if (self.state < 7) 9 else 11;
        stats.repeat_matches += 1;
    }

    fn encodeDistance(
        self: *Model,
        range: *range_encoder.Encoder,
        length_symbol: usize,
        distance: usize,
    ) !void {
        const length_state = @min(length_symbol, 3);
        const slot = distanceSlot(distance);
        try range.encodeBitTree(&self.position_slots[length_state], slot, 6);
        if (slot < 4) return;

        const direct_bits = (slot >> 1) - 1;
        const base = (2 | (slot & 1)) << @intCast(direct_bits);
        const remainder = distance - base;
        if (slot < 14) {
            try range.encodeReverseBitTree(&self.positions, base - slot, remainder, direct_bits);
        } else {
            try range.encodeDirectBits(remainder >> 4, direct_bits - 4);
            try range.encodeReverseBitTree(&self.alignment, 0, remainder & 0x0f, 4);
        }
    }

    pub fn encodeEndMarker(self: *Model, range: *range_encoder.Encoder, position: usize) !void {
        const position_state = position & ((@as(usize, 1) << self.properties.pb) - 1);
        try range.encodeBit(&self.is_match[(self.state << 4) + position_state], true);
        try range.encodeBit(&self.is_rep[self.state], false);
        try self.length.encode(range, 0, position_state);
        self.state = if (self.state < 7) 7 else 10;
        try self.encodeDistance(range, 0, std.math.maxInt(u32));
    }
};

pub fn encodeChunkAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return (try encodeChunkAppendWithStats(allocator, output, input, options)).output_bytes;
}

pub fn encodeChunkAppendWithStats(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !EncodeStats {
    return encodeChunkAppendWithDictionaryStats(
        allocator,
        output,
        input,
        &.{},
        0,
        options,
    );
}

/// Encode one raw LZMA chunk with caller-provided preceding dictionary bytes.
/// `stream_start` is the absolute uncompressed position of `input[0]`; it
/// keeps position-state and literal-context modeling correct when an outer
/// format such as LZMA2 resets the probability model but retains history.
pub fn encodeChunkAppendWithDictionary(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
) !usize {
    return (try encodeChunkAppendWithDictionaryStats(
        allocator,
        output,
        input,
        dictionary,
        stream_start,
        options,
    )).output_bytes;
}

pub fn encodeChunkAppendWithDictionaryStats(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
) !EncodeStats {
    return encodeChunkAppendWithDictionaryStatsAndPlan(
        allocator,
        output,
        input,
        dictionary,
        stream_start,
        options,
        null,
        null,
        null,
    );
}

pub fn encodeChunkAppendWithWidePlan(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
    wide_plan: WideStreamPlan,
) !usize {
    if (options.mode != .greedy or options.dictionary_size <= std.math.maxInt(u16))
        return error.InvalidLzmaOptions;
    return (try encodeChunkAppendWithDictionaryStatsAndPlan(
        allocator,
        output,
        input,
        dictionary,
        stream_start,
        options,
        wide_plan,
        null,
        null,
    )).output_bytes;
}

pub fn encodeChunkAppendWithModel(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
    wide_plan: ?WideStreamPlan,
    model: *Model,
) !usize {
    if (model.dictionary_size != options.dictionary_size or
        !std.meta.eql(model.properties, options.properties))
        return error.InvalidLzmaOptions;
    return (try encodeChunkAppendWithDictionaryStatsAndPlan(
        allocator,
        output,
        input,
        dictionary,
        stream_start,
        options,
        wide_plan,
        model,
        null,
    )).output_bytes;
}

/// Bound a candidate compressed payload, including its range-coder flush.
/// Only CompressedPayloadLimitExceeded means that a stored chunk may be used;
/// allocation and matcher budget errors propagate. Caller output and model
/// are committed together only after the candidate is completely encoded.
pub fn encodeChunkAppendWithModelLimit(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
    wide_plan: ?WideStreamPlan,
    model: *Model,
    max_payload_size: usize,
) !usize {
    if (model.dictionary_size != options.dictionary_size or
        !std.meta.eql(model.properties, options.properties)) return error.InvalidLzmaOptions;
    return (try encodeChunkAppendWithDictionaryStatsAndPlan(
        allocator,
        output,
        input,
        dictionary,
        stream_start,
        options,
        wide_plan,
        model,
        max_payload_size,
    )).output_bytes;
}

fn encodeChunkAppendWithDictionaryStatsAndPlan(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    options: EncodeOptions,
    prepared_wide_plan: ?WideStreamPlan,
    external_model: ?*Model,
    max_payload_size: ?usize,
) !EncodeStats {
    try validateOptions(options);
    if (dictionary.len > stream_start) return error.InvalidLzmaOptions;
    recordEffectiveSettings(options);
    const active_dictionary = dictionary[dictionary.len - @min(dictionary.len, options.dictionary_size) ..];
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var range = range_encoder.Encoder.init(allocator, &encoded);
    range.byte_limit = max_payload_size;
    var local_model = if (external_model) |model| model.* else Model{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
    };
    const model = &local_model;
    var stats = EncodeStats{
        .input_bytes = input.len,
        .output_bytes = 0,
        .literals = 0,
        .matches = 0,
        .matched_bytes = 0,
        .repeat_matches = 0,
        .new_distance_matches = 0,
    };

    const advanced = options.mode == .fast or options.mode == .normal or (options.match_options != null and options.mode != .literal_only);
    if (advanced) {
        if (prepared_wide_plan != null) return error.InvalidLzmaOptions;
        stats.input_bytes = 0;
        try advanced_integration.stream(allocator, model, &range, active_dictionary, input, stream_start, options, &stats, encodeAdvancedPrefix);
    } else switch (options.mode) {
        .literal_only => {
            var position: usize = 0;
            while (position < input.len) : (position += 1) {
                const absolute_position = std.math.add(usize, stream_start, position) catch
                    return error.IntegerOverflow;
                if (options.match_options) |match| if (match.profile) |profile| {
                    profile.literals +|= 1;
                };
                try model.encodeLiteral(
                    &range,
                    active_dictionary,
                    input,
                    position,
                    absolute_position,
                    input[position],
                );
            }
            stats.literals = input.len;
        },
        .greedy => {
            if (prepared_wide_plan) |plan| {
                if (options.dictionary_size <= std.math.maxInt(u16))
                    return error.InvalidLzmaOptions;
                try encodeGreedyPlan(
                    model,
                    &range,
                    input,
                    active_dictionary,
                    plan.tokens,
                    stream_start,
                    &stats,
                    plan.stats,
                );
            } else if (options.dictionary_size <= std.math.maxInt(u16)) {
                var plan = try lz77.hashGreedyPlanAllocWithDictionary(allocator, input, active_dictionary, .{
                    .window_len = options.dictionary_size,
                    .max_chain = 64,
                    .nice_len = 64,
                    .max_candidates = 4,
                    .min_match = 3,
                    .max_match = lz77.max_match_len,
                });
                defer plan.deinit(allocator);
                try encodeGreedyPlan(
                    model,
                    &range,
                    input,
                    active_dictionary,
                    plan.tokens,
                    stream_start,
                    &stats,
                    plan.stats,
                );
            } else {
                var plan = try wide_match.planAlloc(allocator, input, active_dictionary, .{
                    .window_len = options.dictionary_size,
                });
                defer plan.deinit(allocator);
                try encodeGreedyPlan(
                    model,
                    &range,
                    input,
                    active_dictionary,
                    plan.tokens,
                    stream_start,
                    &stats,
                    plan.stats,
                );
            }
        },
        .lazy => try encodeLazyPlan(
            allocator,
            model,
            &range,
            input,
            active_dictionary,
            stream_start,
            &stats,
            options,
            prepared_wide_plan,
        ),
        .fast, .normal => unreachable,
    }
    if (options.end_marker) {
        const end_position = std.math.add(usize, stream_start, input.len) catch
            return error.IntegerOverflow;
        try model.encodeEndMarker(&range, end_position);
    }
    try range.finish();

    try output.ensureUnusedCapacity(allocator, encoded.items.len);
    output.appendSliceAssumeCapacity(encoded.items);
    if (external_model) |target| target.* = local_model;
    stats.output_bytes = encoded.items.len;
    return stats;
}

pub fn validateOptions(options: EncodeOptions) Error!void {
    _ = try propertyByte(options.properties);
    if (options.dictionary_size == 0 or options.dictionary_size > max_dictionary_size)
        return error.InvalidLzmaOptions;
    if (options.match_options) |match| try match.validate();
}

fn encodeGreedyPlan(
    model: *Model,
    range: *range_encoder.Encoder,
    input: []const u8,
    dictionary: []const u8,
    tokens: anytype,
    stream_start: usize,
    stats: *EncodeStats,
    plan_stats: lz77.PlanStats,
) !void {
    stats.literals = plan_stats.literals;
    stats.matches = plan_stats.matches;
    stats.matched_bytes = plan_stats.matched_bytes;
    const consumed = try model.encodeTokensWithDictionary(
        range,
        input,
        dictionary,
        tokens,
        stream_start,
        stats,
    );
    if (consumed != input.len) return error.InvalidMatch;
}

noinline fn encodeLazyPlan(
    allocator: std.mem.Allocator,
    model: *Model,
    range: *range_encoder.Encoder,
    input: []const u8,
    dictionary: []const u8,
    stream_start: usize,
    stats: *EncodeStats,
    options: EncodeOptions,
    prepared_wide_plan: ?WideStreamPlan,
) linksection(lazy_text_section) !void {
    if (prepared_wide_plan) |plan| {
        return encodeGreedyPlan(
            model,
            range,
            input,
            dictionary,
            plan.tokens,
            stream_start,
            stats,
            plan.stats,
        );
    }
    if (options.dictionary_size > std.math.maxInt(u16)) {
        var plan = try wide_match.planAlloc(allocator, input, dictionary, .{
            .window_len = options.dictionary_size,
            .lazy = true,
        });
        defer plan.deinit(allocator);
        return encodeGreedyPlan(model, range, input, dictionary, plan.tokens, stream_start, stats, plan.stats);
    }
    var plan = try lz77.lazyGreedyPlanAllocWithDictionary(allocator, input, dictionary, .{
        .window_len = options.dictionary_size,
        .max_chain = 64,
        .nice_len = 64,
        .max_candidates = 4,
        .lazy_min_gain = 1,
        .min_match = 3,
        .max_match = lz77.max_match_len,
    });
    defer plan.deinit(allocator);
    return encodeGreedyPlan(
        model,
        range,
        input,
        dictionary,
        plan.tokens,
        stream_start,
        stats,
        plan.stats,
    );
}

fn byteAt(dictionary: []const u8, input: []const u8, position: usize) u8 {
    return if (position < dictionary.len)
        dictionary[position]
    else
        input[position - dictionary.len];
}

test "LZMA chunk encoder uses bounded preset dictionary history" {
    var dictionary: [4096]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&dictionary) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    const input = dictionary[dictionary.len - 1024 ..];

    var independent: std.ArrayList(u8) = .empty;
    defer independent.deinit(std.testing.allocator);
    _ = try encodeChunkAppend(std.testing.allocator, &independent, input, .{});

    var dependent: std.ArrayList(u8) = .empty;
    defer dependent.deinit(std.testing.allocator);
    const stats = try encodeChunkAppendWithDictionaryStats(
        std.testing.allocator,
        &dependent,
        input,
        &dictionary,
        dictionary.len,
        .{},
    );
    try std.testing.expect(stats.matches != 0);
    try std.testing.expectEqual(input.len, stats.matched_bytes);
    try std.testing.expect(dependent.items.len + 512 < independent.items.len);

    const before_invalid = dependent.items.len;
    try std.testing.expectError(
        error.InvalidLzmaOptions,
        encodeChunkAppendWithDictionary(
            std.testing.allocator,
            &dependent,
            input,
            &dictionary,
            dictionary.len - 1,
            .{},
        ),
    );
    try std.testing.expectEqual(before_invalid, dependent.items.len);
}

pub fn propertyByte(properties: Properties) Error!u8 {
    if (properties.lc > 8 or properties.lp > 4 or properties.pb > 4 or
        properties.lc + properties.lp > 4)
        return error.InvalidLzmaOptions;
    return @intCast((@as(u16, properties.pb) * 5 + properties.lp) * 9 + properties.lc);
}

fn findRep(reps: [4]usize, distance: usize) ?usize {
    for (reps, 0..) |rep, index| if (rep == distance) return index;
    return null;
}

fn distanceSlot(distance: usize) usize {
    if (distance < 4) return distance;
    const highest_bit = @bitSizeOf(usize) - 1 - @clz(distance);
    return (highest_bit << 1) | (distance >> @intCast(highest_bit - 1) & 1);
}

test "LZMA distance slots cover low and modeled distance ranges" {
    const expected = [_]usize{ 0, 1, 2, 3, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 };
    for (expected, 0..) |slot, distance|
        try std.testing.expectEqual(slot, distanceSlot(distance));
    try std.testing.expectEqual(@as(usize, 23), distanceSlot(4095));
}

test "LZMA greedy chunk emits new-distance and repeat matches" {
    var input: [1200]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (input[0..300]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[300..600], input[0..300]);
    @memcpy(input[600..900], input[0..300]);
    @memcpy(input[900..1200], input[0..300]);

    var greedy: std.ArrayList(u8) = .empty;
    defer greedy.deinit(std.testing.allocator);
    const stats = try encodeChunkAppendWithStats(std.testing.allocator, &greedy, &input, .{});
    try std.testing.expect(stats.matches != 0);
    try std.testing.expect(stats.new_distance_matches != 0);
    try std.testing.expect(stats.repeat_matches != 0);
    try std.testing.expectEqual(stats.matches, stats.new_distance_matches + stats.repeat_matches);

    var literals: std.ArrayList(u8) = .empty;
    defer literals.deinit(std.testing.allocator);
    _ = try encodeChunkAppend(std.testing.allocator, &literals, &input, .{ .mode = .literal_only });
    try std.testing.expect(greedy.items.len < literals.items.len);
}
