const std = @import("std");

pub const Error = error{
    InvalidQuality,
    InvalidSchedule,
    InvalidWindowBits,
};

pub const Quality = enum(u4) {
    q0 = 0,
    q1 = 1,
    q2 = 2,
    q3 = 3,
    q4 = 4,
    q5 = 5,
    q6 = 6,
    q7 = 7,
    q8 = 8,
    q9 = 9,
    q10 = 10,
    q11 = 11,

    pub fn fromInt(value: u8) Error!Quality {
        if (value > 11) return error.InvalidQuality;
        return @enumFromInt(value);
    }

    pub fn int(self: Quality) u8 {
        return @intFromEnum(self);
    }
};

pub const Mode = enum(u2) {
    generic,
    text,
    font,
};

/// Maps directly onto the three established planned encoder pipelines.
/// Qualities 10 and 11 remain in the ratio family and deepen the existing
/// bounded optimal search rather than implying an unimplemented HQ pipeline.
pub const LevelFamily = enum {
    fast,
    balanced,
    ratio,
};

/// Dedicated block-local parser selected before the general family planner.
/// Null keeps the schedule on the general lazy/hash path.
pub const FragmentParser = enum {
    q0,
    q1,
};

pub const WindowPolicy = struct {
    default_bits: u5,
    min_bits: u5,
    max_bits: u5,

    pub fn resolve(self: WindowPolicy, requested: ?u5) Error!u5 {
        const bits = requested orelse self.default_bits;
        if (bits < self.min_bits or bits > self.max_bits)
            return error.InvalidWindowBits;
        return bits;
    }
};

pub const LazyBudget = struct {
    max_chain: u16,
    nice_len: u16,
    min_gain: u8,
};

pub const OptimalBudget = struct {
    enabled: bool,
    entropy_feedback: bool = false,
    command_state_max_input_len: u32 = 0,
    max_chain: u16,
    nice_len: u16,
    max_candidates: u16,
    max_input_len: u32,
};

pub const ContextFlags = struct {
    literal_contexts: bool,
    cluster_contexts: bool,
    joint_block_contexts: bool,
};

pub const DictionaryFlags = struct {
    static_dictionary: bool,
    extended_search: bool,
    max_probes: u16,
};

pub const SplitFlags = struct {
    literal: bool,
    command: bool,
    distance: bool,
    adaptive_literal: bool,
    adaptive_command: bool,
    adaptive_distance: bool,
};

pub const Schedule = struct {
    quality: Quality,
    mode: Mode,
    family: LevelFamily,
    fragment_parser: ?FragmentParser,
    window: WindowPolicy,
    lazy: LazyBudget,
    optimal: OptimalBudget,
    context: ContextFlags,
    dictionary: DictionaryFlags,
    split: SplitFlags,
    use_recent_distances: bool,
    search_distance_parameters: bool,
    /// Default bounded multi-meta-block planning size. q0 favors latency;
    /// qualities with a 32 KiB optimal ceiling stay there; the remaining
    /// schedules amortize headers at 64 KiB. Callers may still override it.
    stream_block_len: u32,
    /// Inspect both 32 KiB halves before committing a 64 KiB stream block.
    stream_entropy_split: bool,

    pub fn validate(self: Schedule) Error!void {
        const expected_fragment: ?FragmentParser = switch (self.quality) {
            .q0 => .q0,
            .q1 => .q1,
            else => null,
        };
        if (self.fragment_parser != expected_fragment or
            (self.fragment_parser != null and self.family != .fast))
        {
            return error.InvalidSchedule;
        }
        if (self.window.min_bits < 10 or self.window.max_bits > 24 or
            self.window.min_bits > self.window.default_bits or
            self.window.default_bits > self.window.max_bits)
        {
            return error.InvalidSchedule;
        }
        if (self.family != .ratio and self.window.max_bits > 16)
            return error.InvalidSchedule;
        if (self.lazy.max_chain == 0 or self.lazy.nice_len == 0 or
            self.lazy.nice_len > 258 or self.lazy.min_gain == 0)
        {
            return error.InvalidSchedule;
        }
        if (self.optimal.enabled) {
            if (self.optimal.max_chain == 0 or self.optimal.nice_len == 0 or
                self.optimal.nice_len > 258 or
                self.optimal.max_candidates == 0 or
                self.optimal.max_candidates > 512 or
                self.optimal.max_input_len == 0 or
                self.optimal.max_input_len > 64 * 1024)
            {
                return error.InvalidSchedule;
            }
            if ((self.optimal.command_state_max_input_len != 0 and
                (!self.optimal.entropy_feedback or
                    self.optimal.command_state_max_input_len > self.optimal.max_input_len)))
            {
                return error.InvalidSchedule;
            }
        } else if (self.optimal.entropy_feedback or self.optimal.max_chain != 0 or self.optimal.nice_len != 0 or
            self.optimal.max_candidates != 0 or self.optimal.max_input_len != 0 or
            self.optimal.command_state_max_input_len != 0)
        {
            return error.InvalidSchedule;
        }
        if (self.dictionary.max_probes > 4096 or
            (!self.dictionary.static_dictionary and
                (self.dictionary.extended_search or
                    self.dictionary.max_probes != 0)) or
            (self.dictionary.extended_search != (self.dictionary.max_probes != 0)))
        {
            return error.InvalidSchedule;
        }
        if ((self.split.adaptive_literal and !self.split.literal) or
            (self.split.adaptive_command and !self.split.command) or
            (self.split.adaptive_distance and !self.split.distance))
        {
            return error.InvalidSchedule;
        }
        if (self.context.cluster_contexts and !self.context.literal_contexts)
            return error.InvalidSchedule;
        if (self.context.joint_block_contexts and
            (!self.context.cluster_contexts or !self.split.literal))
            return error.InvalidSchedule;
        if (self.stream_block_len < 16 * 1024 or
            self.stream_block_len > 64 * 1024 or
            !std.math.isPowerOfTwo(self.stream_block_len))
            return error.InvalidSchedule;
        if (self.stream_entropy_split and self.stream_block_len != 64 * 1024)
            return error.InvalidSchedule;
    }
};

const BaseRow = struct {
    lazy: LazyBudget,
    optimal: OptimalBudget = .{
        .enabled = false,
        .max_chain = 0,
        .nice_len = 0,
        .max_candidates = 0,
        .max_input_len = 0,
    },
    dictionary_probes: u16,
};

/// Budgets follow the current Vort parser limits: match length tops out at
/// 258, optimal candidates at 512, and the present full optimal table is used
/// only through 64 KiB. q10/q11 add a second shortest-path proposal learned
/// from the first plan's literal, copy-length, and distance-prefix entropy;
/// this remains a bounded Vort engine rather than libbrotli algorithm parity.
const base_rows = [12]BaseRow{
    .{ .lazy = .{ .max_chain = 1, .nice_len = 16, .min_gain = 4 }, .dictionary_probes = 0 },
    .{ .lazy = .{ .max_chain = 2, .nice_len = 24, .min_gain = 3 }, .dictionary_probes = 0 },
    .{ .lazy = .{ .max_chain = 4, .nice_len = 32, .min_gain = 3 }, .dictionary_probes = 0 },
    .{ .lazy = .{ .max_chain = 8, .nice_len = 48, .min_gain = 2 }, .dictionary_probes = 0 },
    .{ .lazy = .{ .max_chain = 16, .nice_len = 64, .min_gain = 2 }, .dictionary_probes = 0 },
    .{ .lazy = .{ .max_chain = 32, .nice_len = 96, .min_gain = 1 }, .dictionary_probes = 0 },
    .{
        .lazy = .{ .max_chain = 64, .nice_len = 128, .min_gain = 1 },
        .optimal = .{ .enabled = true, .max_chain = 64, .nice_len = 128, .max_candidates = 16, .max_input_len = 32 * 1024 },
        .dictionary_probes = 0,
    },
    .{
        .lazy = .{ .max_chain = 96, .nice_len = 160, .min_gain = 1 },
        .optimal = .{ .enabled = true, .max_chain = 96, .nice_len = 160, .max_candidates = 32, .max_input_len = 32 * 1024 },
        .dictionary_probes = 768,
    },
    .{
        .lazy = .{ .max_chain = 128, .nice_len = 192, .min_gain = 1 },
        .optimal = .{ .enabled = true, .max_chain = 128, .nice_len = 192, .max_candidates = 64, .max_input_len = 64 * 1024 },
        .dictionary_probes = 1024,
    },
    .{
        .lazy = .{ .max_chain = 256, .nice_len = 258, .min_gain = 1 },
        .optimal = .{ .enabled = true, .max_chain = 192, .nice_len = 258, .max_candidates = 128, .max_input_len = 64 * 1024 },
        .dictionary_probes = 1536,
    },
    .{
        .lazy = .{ .max_chain = 384, .nice_len = 258, .min_gain = 1 },
        .optimal = .{ .enabled = true, .entropy_feedback = true, .command_state_max_input_len = 8 * 1024, .max_chain = 256, .nice_len = 258, .max_candidates = 128, .max_input_len = 64 * 1024 },
        .dictionary_probes = 3072,
    },
    .{
        .lazy = .{ .max_chain = 512, .nice_len = 258, .min_gain = 1 },
        .optimal = .{ .enabled = true, .entropy_feedback = true, .command_state_max_input_len = 8 * 1024, .max_chain = 512, .nice_len = 258, .max_candidates = 256, .max_input_len = 32 * 1024 },
        .dictionary_probes = 4096,
    },
};

pub const matrix: [12][3]Schedule = blk: {
    var result: [12][3]Schedule = undefined;
    for (0..12) |quality_index| {
        for (0..3) |mode_index| {
            result[quality_index][mode_index] = makeSchedule(
                @enumFromInt(quality_index),
                @enumFromInt(mode_index),
            );
        }
    }
    break :blk result;
};

pub fn get(quality: Quality, mode: Mode) Schedule {
    return matrix[quality.int()][@intFromEnum(mode)];
}

pub fn getInt(quality: u8, mode: Mode) Error!Schedule {
    return get(try Quality.fromInt(quality), mode);
}

fn makeSchedule(quality: Quality, mode: Mode) Schedule {
    const q = quality.int();
    const row = base_rows[q];
    const family: LevelFamily = if (q <= 1)
        .fast
    else if (q <= 5)
        .balanced
    else
        .ratio;
    // libbrotli does not use its public generic/text/font selector to change
    // parser, context, or dictionary budgets. Keep the Vort preset policy the
    // same for all three modes; the encoder adds font's q4+ (1, 12) distance
    // candidate separately and retains it only when the complete wire wins.
    const context_threshold: u8 = 5;
    const dictionary_threshold: u8 = 2;
    const extended_threshold: u8 = 7;
    const dictionary_enabled = q >= dictionary_threshold;
    const literal_contexts = q >= context_threshold;
    const split_enabled = q >= 4;

    return .{
        .quality = quality,
        .mode = mode,
        .family = family,
        .fragment_parser = switch (quality) {
            .q0 => .q0,
            .q1 => .q1,
            else => null,
        },
        .window = .{
            .default_bits = 16,
            .min_bits = 10,
            .max_bits = if (family == .ratio) 24 else 16,
        },
        .lazy = row.lazy,
        .optimal = row.optimal,
        .context = .{
            .literal_contexts = literal_contexts,
            .cluster_contexts = literal_contexts and q >= 7,
            .joint_block_contexts = literal_contexts and q >= 10,
        },
        .dictionary = .{
            .static_dictionary = dictionary_enabled,
            .extended_search = dictionary_enabled and q >= extended_threshold,
            .max_probes = if (dictionary_enabled) row.dictionary_probes else 0,
        },
        .split = .{
            .literal = split_enabled,
            .command = split_enabled,
            .distance = split_enabled,
            .adaptive_literal = q >= 8,
            .adaptive_command = q >= 9,
            .adaptive_distance = q >= 7,
        },
        .use_recent_distances = q >= 3,
        .search_distance_parameters = q >= 4,
        .stream_block_len = if (q == 0)
            16 * 1024
        else if (q == 1 or q == 6 or q == 7 or q == 11)
            32 * 1024
        else
            64 * 1024,
        .stream_entropy_split = (q >= 2 and q <= 5) or (q >= 8 and q <= 10),
    };
}

fn flagDoesNotRegress(previous: bool, current: bool) bool {
    return !previous or current;
}

test "quality rejects values outside zero through eleven" {
    for (0..12) |value| {
        const quality = try Quality.fromInt(@intCast(value));
        try std.testing.expectEqual(@as(u8, @intCast(value)), quality.int());
    }
    try std.testing.expectError(error.InvalidQuality, Quality.fromInt(12));
    try std.testing.expectError(error.InvalidQuality, Quality.fromInt(255));
    try std.testing.expectError(error.InvalidQuality, getInt(200, .generic));
}

test "quality stream block sizes follow latency and optimal-search policy" {
    for (0..12) |quality_index| {
        const quality = try Quality.fromInt(@intCast(quality_index));
        const expected: u32 = if (quality == .q0)
            16 * 1024
        else if (quality == .q1 or quality == .q6 or quality == .q7 or quality == .q11)
            32 * 1024
        else
            64 * 1024;
        inline for (std.meta.tags(Mode)) |mode| {
            const schedule = get(quality, mode);
            try std.testing.expectEqual(expected, schedule.stream_block_len);
            try std.testing.expectEqual(
                (quality.int() >= 2 and quality.int() <= 5) or
                    (quality.int() >= 8 and quality.int() <= 10),
                schedule.stream_entropy_split,
            );
        }
    }
}

test "quality schedule covers the deterministic twelve by three matrix" {
    for (0..12) |quality_index| {
        for (0..3) |mode_index| {
            const quality = try Quality.fromInt(@intCast(quality_index));
            const mode: Mode = @enumFromInt(mode_index);
            const selected = get(quality, mode);
            try selected.validate();
            try std.testing.expectEqual(quality, selected.quality);
            try std.testing.expectEqual(mode, selected.mode);
            try std.testing.expectEqual(
                switch (quality) {
                    .q0 => FragmentParser.q0,
                    .q1 => FragmentParser.q1,
                    else => null,
                },
                selected.fragment_parser,
            );
            try std.testing.expectEqualDeep(selected, try getInt(@intCast(quality_index), mode));
            try std.testing.expectEqualDeep(selected, matrix[quality_index][mode_index]);
        }
    }

    const generic = get(.q6, .generic);
    var text = get(.q6, .text);
    var font = get(.q6, .font);
    text.mode = .generic;
    font.mode = .generic;
    try std.testing.expectEqualDeep(generic, text);
    try std.testing.expectEqualDeep(generic, font);
}

test "quality schedules increase budgets and never retract enabled work" {
    inline for (std.meta.tags(Mode)) |mode| {
        var previous = get(.q0, mode);
        for (1..12) |quality_index| {
            const current = get(try Quality.fromInt(@intCast(quality_index)), mode);
            try std.testing.expect(current.lazy.max_chain > previous.lazy.max_chain);
            try std.testing.expect(current.lazy.nice_len >= previous.lazy.nice_len);
            try std.testing.expect(current.lazy.min_gain <= previous.lazy.min_gain);
            try std.testing.expect(current.optimal.max_chain >= previous.optimal.max_chain);
            try std.testing.expect(current.optimal.nice_len >= previous.optimal.nice_len);
            try std.testing.expect(current.optimal.max_candidates >= previous.optimal.max_candidates);
            // q11 deliberately limits its deeper second candidate to 32 KiB;
            // the encoder separately retains the complete q10 candidate up
            // through 64 KiB, so final q11 output remains no larger than q10.
            if (current.quality != .q11)
                try std.testing.expect(current.optimal.max_input_len >= previous.optimal.max_input_len);
            try std.testing.expect(current.dictionary.max_probes >= previous.dictionary.max_probes);
            try std.testing.expect(current.window.max_bits >= previous.window.max_bits);
            try std.testing.expect(flagDoesNotRegress(previous.optimal.enabled, current.optimal.enabled));
            try std.testing.expect(flagDoesNotRegress(previous.optimal.entropy_feedback, current.optimal.entropy_feedback));
            try std.testing.expect(flagDoesNotRegress(
                previous.optimal.command_state_max_input_len != 0,
                current.optimal.command_state_max_input_len != 0,
            ));
            try std.testing.expect(flagDoesNotRegress(previous.context.literal_contexts, current.context.literal_contexts));
            try std.testing.expect(flagDoesNotRegress(previous.context.cluster_contexts, current.context.cluster_contexts));
            try std.testing.expect(flagDoesNotRegress(previous.context.joint_block_contexts, current.context.joint_block_contexts));
            try std.testing.expect(flagDoesNotRegress(previous.dictionary.static_dictionary, current.dictionary.static_dictionary));
            try std.testing.expect(flagDoesNotRegress(previous.dictionary.extended_search, current.dictionary.extended_search));
            try std.testing.expect(flagDoesNotRegress(previous.split.literal, current.split.literal));
            try std.testing.expect(flagDoesNotRegress(previous.split.command, current.split.command));
            try std.testing.expect(flagDoesNotRegress(previous.split.distance, current.split.distance));
            try std.testing.expect(flagDoesNotRegress(previous.split.adaptive_literal, current.split.adaptive_literal));
            try std.testing.expect(flagDoesNotRegress(previous.split.adaptive_command, current.split.adaptive_command));
            try std.testing.expect(flagDoesNotRegress(previous.split.adaptive_distance, current.split.adaptive_distance));
            try std.testing.expect(flagDoesNotRegress(previous.use_recent_distances, current.use_recent_distances));
            try std.testing.expect(flagDoesNotRegress(previous.search_distance_parameters, current.search_distance_parameters));
            previous = current;
        }
    }
}

test "quality ten and eleven use distinct bounded optimal searches" {
    inline for (std.meta.tags(Mode)) |mode| {
        const q10 = get(.q10, mode);
        const q11 = get(.q11, mode);
        try std.testing.expectEqual(@as(u16, 256), q10.optimal.max_chain);
        try std.testing.expectEqual(@as(u16, 128), q10.optimal.max_candidates);
        try std.testing.expectEqual(@as(u32, 64 * 1024), q10.optimal.max_input_len);
        try std.testing.expect(q10.optimal.entropy_feedback);
        try std.testing.expectEqual(@as(u32, 8 * 1024), q10.optimal.command_state_max_input_len);
        try std.testing.expectEqual(@as(u16, 512), q11.optimal.max_chain);
        try std.testing.expectEqual(@as(u16, 256), q11.optimal.max_candidates);
        try std.testing.expectEqual(@as(u32, 32 * 1024), q11.optimal.max_input_len);
        try std.testing.expect(q11.optimal.entropy_feedback);
        try std.testing.expectEqual(@as(u32, 8 * 1024), q11.optimal.command_state_max_input_len);
    }
}

test "quality window policy preserves current planned limits" {
    inline for (std.meta.tags(Mode)) |mode| {
        const balanced = get(.q5, mode);
        try std.testing.expectEqual(@as(u5, 16), try balanced.window.resolve(null));
        try std.testing.expectEqual(@as(u5, 10), try balanced.window.resolve(10));
        try std.testing.expectEqual(@as(u5, 16), try balanced.window.resolve(16));
        try std.testing.expectError(error.InvalidWindowBits, balanced.window.resolve(9));
        try std.testing.expectError(error.InvalidWindowBits, balanced.window.resolve(17));

        const ratio = get(.q6, mode);
        try std.testing.expectEqual(@as(u5, 24), try ratio.window.resolve(24));
        try std.testing.expectError(error.InvalidWindowBits, ratio.window.resolve(25));
    }
}

test "quality schedule validator rejects inconsistent policies" {
    var invalid = get(.q8, .generic);
    invalid.lazy.max_chain = 0;
    try std.testing.expectError(error.InvalidSchedule, invalid.validate());

    invalid = get(.q8, .generic);
    invalid.split.literal = false;
    try std.testing.expectError(error.InvalidSchedule, invalid.validate());

    invalid = get(.q11, .text);
    invalid.optimal.max_candidates = 0;
    try std.testing.expectError(error.InvalidSchedule, invalid.validate());

    invalid = get(.q0, .generic);
    invalid.fragment_parser = null;
    try std.testing.expectError(error.InvalidSchedule, invalid.validate());

    invalid = get(.q8, .generic);
    invalid.fragment_parser = .q0;
    try std.testing.expectError(error.InvalidSchedule, invalid.validate());
}
