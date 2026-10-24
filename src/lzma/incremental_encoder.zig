const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");
const lzma_encoder = @import("encoder.zig");
const range_encoder = @import("range_encoder.zig");
const writer = @import("writer.zig");
const settings = @import("encode_options.zig");

/// Symbol-progressive LZMA-Alone encoder. Greedy mode keeps a complete maximum
/// match lookahead and the bounded prior dictionary, so committed token choices
/// do not depend on caller input fragmentation.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    model: lzma_encoder.Model,
    greedy: ?lz77.StreamingHashGreedy = null,
    greedy_journal: lz77.StreamingHashGreedyJournal = .{},
    tokens: std.ArrayList(lz77.Token) = .empty,
    input: std.ArrayList(u8) = .empty,
    history: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    range_low: u64 = 0,
    range_value: u32 = 0xffff_ffff,
    range_cache: u8 = 0,
    range_cache_size: usize = 1,
    header_written: bool = false,
    finishing: bool = false,
    range_finished: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    accepted_input: usize = 0,
    encoded_input: usize = 0,
    output_written: usize = 0,
    stats: lzma_encoder.EncodeStats,

    pub const Error = writer.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        properties: lzma_encoder.Properties = .{},
        dictionary_size: u32 = 32 * 1024,
        mode: lzma_encoder.Mode = .greedy,
        size_mode: writer.SizeMode = .end_marker,
        match_options: ?settings.MatchOptions = null,
        input_buffer_len: usize = 64 * 1024,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,

        pub fn fromPreset(level: u32, extreme: bool) Error!Options {
            const preset = try settings.resolvePreset(level, extreme);
            return .{ .properties = preset.properties, .dictionary_size = preset.dictionary_size, .mode = preset.mode, .match_options = preset.match_options };
        }

        /// Scalar validation for frontends before opening a destination. Known
        /// input length validation remains the responsibility of initExactSize.
        pub fn validate(self: Options) Error!void {
            try validateOptions(self, if (self.size_mode == .known) 0 else null);
        }

        fn writerOptions(self: Options) writer.EncodeOptions {
            return .{
                .properties = self.properties,
                .dictionary_size = self.dictionary_size,
                .mode = self.mode,
                .size_mode = self.size_mode,
                .match_options = self.match_options,
            };
        }
    };
    pub const Snapshot = struct {
        input_read: usize,
        input_encoded: usize,
        output_written: usize,
        buffered_input: usize,
        history_bytes: usize,
        pending_output: usize,
        literals: usize,
        matches: usize,
        matched_bytes: usize,
        repeat_matches: usize,
        new_distance_matches: usize,
        finishing: bool,
        done: bool,
        retained_input_capacity: usize,
        retained_history_capacity: usize,
        retained_output_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options, null);
        var state = initialState(allocator, options, null);
        if (options.mode == .greedy and !usesAdvanced(options))
            state.greedy = try lz77.StreamingHashGreedy.init(allocator, options.dictionary_size);
        recordEffectiveSettings(options);
        return state;
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        try validateOptions(options, expected_input_len);
        var state = initialState(allocator, options, expected_input_len);
        if (options.mode == .greedy and !usesAdvanced(options))
            state.greedy = try lz77.StreamingHashGreedy.init(allocator, options.dictionary_size);
        recordEffectiveSettings(options);
        return state;
    }

    fn initialState(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: ?usize,
    ) Encoder {
        return .{
            .allocator = allocator,
            .options = options,
            .model = .{
                .properties = options.properties,
                .dictionary_size = options.dictionary_size,
            },
            .expected_input_len = expected_input_len,
            .stats = emptyStats(),
        };
    }

    pub fn deinit(self: *Encoder) void {
        if (self.greedy) |*greedy| greedy.deinit(self.allocator);
        self.greedy_journal.deinit(self.allocator);
        self.tokens.deinit(self.allocator);
        self.input.deinit(self.allocator);
        self.history.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        var input = self.input;
        var history = self.history;
        var pending = self.pending;
        var tokens = self.tokens;
        var greedy = self.greedy;
        var greedy_journal = self.greedy_journal;
        input.clearRetainingCapacity();
        history.clearRetainingCapacity();
        pending.clearRetainingCapacity();
        tokens.clearRetainingCapacity();
        if (greedy) |*state| state.reset();
        greedy_journal.commit();
        const allocator = self.allocator;
        const options = self.options;
        const expected = self.expected_input_len;
        self.* = initialState(allocator, options, expected);
        self.input = input;
        self.history = history;
        self.pending = pending;
        self.tokens = tokens;
        self.greedy = greedy;
        self.greedy_journal = greedy_journal;
        recordEffectiveSettings(options);
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.accepted_input,
            .input_encoded = self.encoded_input,
            .output_written = self.output_written,
            .buffered_input = self.input.items.len,
            .history_bytes = self.history.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .literals = self.stats.literals,
            .matches = self.stats.matches,
            .matched_bytes = self.stats.matched_bytes,
            .repeat_matches = self.stats.repeat_matches,
            .new_distance_matches = self.stats.new_distance_matches,
            .finishing = self.finishing,
            .done = self.done,
            .retained_input_capacity = self.input.capacity,
            .retained_history_capacity = self.history.capacity,
            .retained_output_capacity = self.pending.capacity,
        };
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) self.finishing = true;
    }

    pub fn step(self: *Encoder, plain: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (plain.len != 0) return error.TrailingData;
            recordEffectiveSettings(self.options);
            return .{ .status = .done };
        }
        if (self.finishing and plain.len != 0) return error.TrailingData;
        recordEffectiveSettings(self.options);

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.output_written = std.math.add(usize, self.output_written, take) catch
                    return error.IntegerOverflow;
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
            }

            if (!self.header_written) {
                const pending_before = self.pending.items.len;
                errdefer self.pending.items.len = pending_before;
                try writer.appendStreamHeader(
                    self.allocator,
                    &self.pending,
                    self.options.writerOptions(),
                    self.expected_input_len,
                );
                try self.checkPendingLimit();
                self.header_written = true;
                continue;
            }

            if (input_read < plain.len) {
                const room = self.options.input_buffer_len - self.input.items.len;
                const take = @min(room, plain.len - input_read);
                const next_input = std.math.add(usize, self.accepted_input, take) catch
                    return error.IntegerOverflow;
                if (next_input > self.options.max_input_len) return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (next_input > expected) return error.SizeMismatch;
                try self.input.appendSlice(self.allocator, plain[input_read..][0..take]);
                input_read += take;
                self.accepted_input = next_input;
            }

            const should_encode = self.finishing or
                (usesAdvanced(self.options) and self.input.items.len >= advanced_lookahead_len) or
                self.input.items.len == self.options.input_buffer_len;
            if (should_encode and self.input.items.len != 0) {
                if (try self.encodeAvailable(self.finishing)) continue;
            }

            if (input_read < plain.len) continue;

            if (self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.accepted_input != expected) return error.SizeMismatch;
                if (self.input.items.len != 0) {
                    if (try self.encodeAvailable(true)) continue;
                    return error.InvalidMatch;
                }
                if (!self.range_finished) {
                    try self.finishRange();
                    continue;
                }
                self.stats.input_bytes = self.accepted_input;
                self.stats.output_bytes = self.output_written;
                self.done = true;
                return result(input_read, output_written, .done);
            }

            return result(input_read, output_written, .need_input);
        }
    }

    fn finishRange(self: *Encoder) Error!void {
        var produced: std.ArrayList(u8) = .empty;
        defer produced.deinit(self.allocator);
        var model = self.model;
        var range = self.rangeEncoder();
        range.output = &produced;
        if (self.options.size_mode == .end_marker)
            try model.encodeEndMarker(&range, self.encoded_input);
        try range.finish();
        const pending_len = std.math.add(usize, self.pending.items.len, produced.items.len) catch return error.IntegerOverflow;
        if (pending_len > self.options.max_pending_output_len) return error.OutputLimitExceeded;
        try self.pending.ensureUnusedCapacity(self.allocator, produced.items.len);
        self.pending.appendSliceAssumeCapacity(produced.items);
        self.model = model;
        self.saveRange(range);
        self.range_finished = true;
    }

    /// Encode the stable token prefix. Returns true when any input was
    /// committed, allowing the caller to drain newly emitted range bytes.
    fn encodeAvailable(self: *Encoder, final_input: bool) Error!bool {
        if (usesAdvanced(self.options)) return self.encodeAdvancedAvailable(final_input);
        self.tokens.clearRetainingCapacity();
        // Matcher insertion joins the coding/history transaction. The undo
        // journal protects all early returns without copying the hash tables.
        if (self.options.mode == .greedy) {
            try self.greedy_journal.ensureCapacity(self.allocator, self.input.items.len);
            try self.greedy_journal.begin();
        }
        defer if (self.options.mode == .greedy) self.greedy_journal.rollback(&self.greedy.?);
        var consumed: usize = 0;
        while (consumed < self.input.items.len) {
            if (!final_input and self.options.mode == .greedy and
                consumed + lz77.max_match_len > self.input.items.len)
                break;
            const token = switch (self.options.mode) {
                .literal_only => lz77.StreamingHashGreedy.Result{
                    .token = .{ .literal = self.input.items[consumed] },
                    .consumed = 1,
                },
                .greedy => try (&self.greedy.?).nextWithJournal(
                    self.history.items,
                    self.input.items,
                    consumed,
                    self.encoded_input,
                    .{
                        .window_len = self.options.dictionary_size,
                        .max_chain = 64,
                        .nice_len = 64,
                        .max_candidates = 4,
                        .min_match = 3,
                        .max_match = lz77.max_match_len,
                    },
                    &self.greedy_journal,
                ),
                .lazy, .fast, .normal => return error.InvalidLzmaOptions,
            };
            try self.tokens.append(self.allocator, token.token);
            consumed = std.math.add(usize, consumed, token.consumed) catch
                return error.IntegerOverflow;
        }
        if (consumed == 0) return false;

        const next_encoded = std.math.add(usize, self.encoded_input, consumed) catch return error.IntegerOverflow;
        const history_capacity = @min(@as(usize, self.options.dictionary_size), std.math.add(usize, self.history.items.len, consumed) catch return error.IntegerOverflow);
        try self.history.ensureTotalCapacityPrecise(self.allocator, history_capacity);
        var produced: std.ArrayList(u8) = .empty;
        defer produced.deinit(self.allocator);
        var model = self.model;
        var stats = self.stats;
        addTokenStats(&stats, self.tokens.items);
        var range = self.rangeEncoder();
        range.output = &produced;
        const encoded = try model.encodeTokensWithDictionaryProfiled(
            &range,
            self.input.items,
            self.history.items,
            self.tokens.items,
            self.encoded_input,
            &stats,
            if (self.options.match_options) |match| match.profile else null,
        );
        if (encoded != consumed) return error.InvalidMatch;
        const pending_len = std.math.add(usize, self.pending.items.len, produced.items.len) catch return error.IntegerOverflow;
        if (pending_len > self.options.max_pending_output_len) return error.OutputLimitExceeded;
        try self.pending.ensureUnusedCapacity(self.allocator, produced.items.len);
        try self.commitHistory(self.input.items[0..consumed]);
        self.pending.appendSliceAssumeCapacity(produced.items);
        self.model = model;
        self.stats = stats;
        self.saveRange(range);
        if (self.options.mode == .greedy) self.greedy_journal.commit();
        const remaining = self.input.items.len - consumed;
        std.mem.copyForwards(u8, self.input.items[0..remaining], self.input.items[consumed..]);
        self.input.items.len = remaining;
        self.encoded_input = next_encoded;
        return true;
    }

    fn encodeAdvancedAvailable(self: *Encoder, final_input: bool) Error!bool {
        const count = @min(self.input.items.len, advanced_lookahead_len);
        const final_prefix = final_input and count == self.input.items.len;
        if (!final_prefix and count < advanced_lookahead_len) return false;
        const history_capacity = @min(@as(usize, self.options.dictionary_size), std.math.add(usize, self.history.items.len, count) catch return error.IntegerOverflow);
        // Reserve prior to mutating the coding model/range, so committing an
        // accepted prefix cannot fail while expanding its persistent history.
        try self.history.ensureTotalCapacityPrecise(self.allocator, history_capacity);
        const model_before = self.model;
        const stats_before = self.stats;
        const pending_before = self.pending.items.len;
        var range = self.rangeEncoder();
        const consumed = lzma_encoder.encodeAdvancedPrefix(
            self.allocator,
            &self.model,
            &range,
            self.history.items,
            self.input.items[0..count],
            self.encoded_input,
            .{ .properties = self.options.properties, .dictionary_size = self.options.dictionary_size, .mode = self.options.mode, .match_options = self.options.match_options },
            final_prefix,
            &self.stats,
        ) catch |err| {
            self.model = model_before;
            self.stats = stats_before;
            self.pending.items.len = pending_before;
            return err;
        };
        if (consumed == 0) return false;
        self.checkPendingLimit() catch |err| {
            self.model = model_before;
            self.stats = stats_before;
            self.pending.items.len = pending_before;
            return err;
        };
        try self.commitHistory(self.input.items[0..consumed]);
        self.saveRange(range);
        const remaining = self.input.items.len - consumed;
        std.mem.copyForwards(u8, self.input.items[0..remaining], self.input.items[consumed..]);
        self.input.items.len = remaining;
        self.encoded_input = std.math.add(usize, self.encoded_input, consumed) catch return error.IntegerOverflow;
        return true;
    }

    fn commitHistory(self: *Encoder, bytes: []const u8) Error!void {
        const limit = self.options.dictionary_size;
        if (bytes.len >= limit) {
            try self.history.resize(self.allocator, limit);
            @memcpy(self.history.items, bytes[bytes.len - limit ..]);
            return;
        }
        const keep = @min(self.history.items.len, limit - bytes.len);
        if (keep != self.history.items.len)
            std.mem.copyForwards(
                u8,
                self.history.items[0..keep],
                self.history.items[self.history.items.len - keep ..],
            );
        self.history.items.len = keep;
        try self.history.appendSlice(self.allocator, bytes);
    }

    fn rangeEncoder(self: *Encoder) range_encoder.Encoder {
        var range = range_encoder.Encoder.init(self.allocator, &self.pending);
        range.low = self.range_low;
        range.range = self.range_value;
        range.cache = self.range_cache;
        range.cache_size = self.range_cache_size;
        return range;
    }

    fn saveRange(self: *Encoder, range: range_encoder.Encoder) void {
        self.range_low = range.low;
        self.range_value = range.range;
        self.range_cache = range.cache;
        self.range_cache_size = range.cache_size;
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len > self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

fn validateOptions(options: Encoder.Options, expected_input_len: ?usize) Encoder.Error!void {
    try writer.validateOptions(options.writerOptions());
    if (options.mode == .lazy and !usesAdvanced(options)) return error.InvalidLzmaOptions;
    if (options.input_buffer_len == 0 or options.max_pending_output_len == 0)
        return error.InvalidLzmaOptions;
    if (usesAdvanced(options) and options.input_buffer_len < advanced_lookahead_len) return error.InvalidLzmaOptions;
    if (options.mode == .greedy and !usesAdvanced(options) and options.input_buffer_len <= lz77.max_match_len)
        return error.InvalidLzmaOptions;
    if (options.size_mode == .known and expected_input_len == null)
        return error.InvalidBlockPlan;
    if (expected_input_len) |expected|
        if (expected > options.max_input_len) return error.OutputLimitExceeded;
}

fn emptyStats() lzma_encoder.EncodeStats {
    return .{
        .input_bytes = 0,
        .output_bytes = 0,
        .literals = 0,
        .matches = 0,
        .matched_bytes = 0,
        .repeat_matches = 0,
        .new_distance_matches = 0,
    };
}

fn addTokenStats(stats: *lzma_encoder.EncodeStats, tokens: []const lz77.Token) void {
    for (tokens) |token| switch (token) {
        .literal => stats.literals += 1,
        .match => |match| {
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
}

const advanced_lookahead_len: usize = lzma_encoder.advanced_input_min;
fn recordEffectiveSettings(options: Encoder.Options) void {
    if (options.match_options) |match| match.recordEffectiveSettings();
}

fn usesAdvanced(options: Encoder.Options) bool {
    if (options.mode == .literal_only) return false;
    return options.match_options != null or options.mode == .fast or options.mode == .normal or
        (options.mode == .greedy and options.dictionary_size > std.math.maxInt(u16));
}
