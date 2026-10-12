const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");
const lzma_encoder = @import("encoder.zig");
const range_encoder = @import("range_encoder.zig");
const writer = @import("writer.zig");

/// Symbol-progressive LZMA-Alone encoder. Greedy mode keeps a complete maximum
/// match lookahead and the bounded prior dictionary, so committed token choices
/// do not depend on caller input fragmentation.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    model: lzma_encoder.Model,
    greedy: ?lz77.StreamingHashGreedy = null,
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
        input_buffer_len: usize = 64 * 1024,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,

        fn writerOptions(self: Options) writer.EncodeOptions {
            return .{
                .properties = self.properties,
                .dictionary_size = self.dictionary_size,
                .mode = self.mode,
                .size_mode = self.size_mode,
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
        if (options.mode == .greedy)
            state.greedy = try lz77.StreamingHashGreedy.init(allocator, options.dictionary_size);
        return state;
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        try validateOptions(options, expected_input_len);
        var state = initialState(allocator, options, expected_input_len);
        if (options.mode == .greedy)
            state.greedy = try lz77.StreamingHashGreedy.init(allocator, options.dictionary_size);
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
        input.clearRetainingCapacity();
        history.clearRetainingCapacity();
        pending.clearRetainingCapacity();
        tokens.clearRetainingCapacity();
        if (greedy) |*state| state.reset();
        const allocator = self.allocator;
        const options = self.options;
        const expected = self.expected_input_len;
        self.* = initialState(allocator, options, expected);
        self.input = input;
        self.history = history;
        self.pending = pending;
        self.tokens = tokens;
        self.greedy = greedy;
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
            return .{ .status = .done };
        }
        if (self.finishing and plain.len != 0) return error.TrailingData;

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
                    var range = self.rangeEncoder();
                    if (self.options.size_mode == .end_marker)
                        try self.model.encodeEndMarker(&range, self.encoded_input);
                    try range.finish();
                    self.saveRange(range);
                    try self.checkPendingLimit();
                    self.range_finished = true;
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

    /// Encode the stable token prefix. Returns true when any input was
    /// committed, allowing the caller to drain newly emitted range bytes.
    fn encodeAvailable(self: *Encoder, final_input: bool) Error!bool {
        self.tokens.clearRetainingCapacity();
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
                .greedy => try (&self.greedy.?).next(
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
                ),
            };
            try self.tokens.append(self.allocator, token.token);
            consumed = std.math.add(usize, consumed, token.consumed) catch
                return error.IntegerOverflow;
        }
        if (consumed == 0) return false;

        addTokenStats(&self.stats, self.tokens.items);
        var range = self.rangeEncoder();
        const encoded = try self.model.encodeTokensWithDictionary(
            &range,
            self.input.items,
            self.history.items,
            self.tokens.items,
            self.encoded_input,
            &self.stats,
        );
        if (encoded != consumed) return error.InvalidMatch;
        self.saveRange(range);
        try self.checkPendingLimit();
        try self.commitHistory(self.input.items[0..consumed]);
        const remaining = self.input.items.len - consumed;
        std.mem.copyForwards(u8, self.input.items[0..remaining], self.input.items[consumed..]);
        self.input.items.len = remaining;
        self.encoded_input = std.math.add(usize, self.encoded_input, consumed) catch
            return error.IntegerOverflow;
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
    try writer.validateCoreOptions(options.properties, options.dictionary_size);
    if (options.input_buffer_len == 0 or options.max_pending_output_len == 0)
        return error.InvalidLzmaOptions;
    if (options.mode == .greedy and options.input_buffer_len <= lz77.max_match_len)
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
