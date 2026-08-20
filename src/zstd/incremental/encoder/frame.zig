const std = @import("std");
const core = @import("../../../core.zig");
const history_mod = @import("history.zig");

/// Build an incremental Zstd frame encoder. One bounded block is retained;
/// completed raw, RLE, or entropy-coded blocks drain through arbitrary caller
/// output. The final block bit is delayed until `finish`, as required by Zstd.
pub fn Encoder(comptime Codec: type, comptime BlockEmitter: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Codec.Options,
        block: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        hasher: std.hash.XxHash64 = std.hash.XxHash64.init(0),
        header_written: bool = false,
        flush_requested: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        dictionary_id: ?u32 = null,
        dictionary: ?Codec.Dictionary = null,
        codec_state: Codec.State = .{},
        history: history_mod.Rolling = .{},
        stream_input: usize = 0,
        stream_output: usize = 0,
        frame_count: usize = 0,
        skippable_only: bool = false,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            frame_input: usize,
            frame_output: usize,
            buffered_input: usize,
            pending_output: usize,
            frame_count: usize,
            frame_index: usize,
            finishing: bool,
            done: bool,
        };
        pub fn init(allocator: std.mem.Allocator, options: Codec.Options) Error!Self {
            try Codec.validate(options, null, null);
            return .{ .allocator = allocator, .options = options };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize) Error!Self {
            try Codec.validate(options, expected_input_len, null);
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len };
        }
        /// Retained for callers that only need Dictionary_ID metadata in a
        /// raw/RLE stream. Use `initWithPresetDictionary` when blocks should
        /// actually reference preset history.
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary_id: u32) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            if (options.selection != .raw_or_rle) return error.InvalidBlockPlan;
            try Codec.validate(options, null, dictionary_id);
            return .{ .allocator = allocator, .options = options, .dictionary_id = dictionary_id };
        }
        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize, dictionary_id: u32) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            if (options.selection != .raw_or_rle) return error.InvalidBlockPlan;
            try Codec.validate(options, expected_input_len, dictionary_id);
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len, .dictionary_id = dictionary_id };
        }
        /// Borrow preset history for the encoder lifetime. Entropy-coded blocks
        /// may reference these bytes, so they must outlive the encoder.
        pub fn initWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary: Codec.Dictionary) Error!Self {
            if (dictionary.id == 0) return error.NeedDictionary;
            try Codec.validate(options, null, dictionary.id);
            return .{ .allocator = allocator, .options = options, .dictionary_id = dictionary.id, .dictionary = dictionary };
        }
        pub fn initExactSizeWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize, dictionary: Codec.Dictionary) Error!Self {
            if (dictionary.id == 0) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len, .dictionary_id = dictionary.id, .dictionary = dictionary };
        }
        pub fn initWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initWithPresetDictionary(allocator, options, dictionary);
        }
        pub fn initExactSizeWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initExactSizeWithPresetDictionary(allocator, options, expected_input_len, dictionary);
        }
        pub fn deinit(self: *Self) void {
            self.history.deinit(self.allocator);
            self.block.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.stream_input = 0;
            self.stream_output = 0;
            self.frame_count = 0;
            self.resetFrame(self.options, expected_input_len, self.dictionary_id, self.dictionary);
        }
        fn resetFrame(self: *Self, options: Codec.Options, expected_input_len: ?usize, dictionary_id: ?u32, dictionary: ?Codec.Dictionary) void {
            self.options = options;
            self.block.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.hasher = std.hash.XxHash64.init(0);
            self.header_written = false;
            self.flush_requested = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
            self.codec_state = .{};
            self.history.clearRetainingCapacity();
            self.dictionary_id = dictionary_id;
            self.dictionary = dictionary;
            self.skippable_only = false;
        }
        pub fn nextFrame(self: *Self, options: Codec.Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try Codec.validate(options, null, null);
            self.resetFrame(options, null, null, null);
        }
        pub fn nextFrameExactSize(self: *Self, options: Codec.Options, expected_input_len: usize) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try Codec.validate(options, expected_input_len, null);
            self.resetFrame(options, expected_input_len, null, null);
        }
        pub fn nextFrameExactSizeWithPresetDictionary(self: *Self, options: Codec.Options, expected_input_len: usize, dictionary: Codec.Dictionary) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            if (dictionary.id == 0) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            self.resetFrame(options, expected_input_len, dictionary.id, dictionary);
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.stream_input,
                .output_written = self.stream_output,
                .frame_input = self.total_input,
                .frame_output = self.total_output,
                .buffered_input = self.block.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .frame_count = self.frame_count,
                .frame_index = if (self.done and self.frame_count != 0) self.frame_count - 1 else self.frame_count,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
            self.flush_requested = false;
        }
        /// End the current non-final block and make all accepted input
        /// decodable without ending the frame. Repeated calls with no new input
        /// are idempotent; the request drains through the normal tiny-output
        /// path and callers may resume input once `need_input` is returned.
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }
        /// Queue a standard Zstd skippable frame after a drained data frame.
        /// Start the next data frame with `nextFrame` after this drains.
        pub fn writeSkippable(self: *Self, skippable_id: u4, payload: []const u8) Error!void {
            if (payload.len > std.math.maxInt(u32)) return error.IntegerOverflow;
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try Codec.writeSkippable(self.allocator, &self.pending, skippable_id, payload);
            self.done = false;
            self.skippable_only = true;
        }
        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output += n;
                    self.stream_output += n;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (self.skippable_only) {
                    self.skippable_only = false;
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                if (!self.header_written) {
                    try Codec.writeHeader(self.allocator, &self.pending, self.options, self.expected_input_len, self.dictionary_id);
                    self.header_written = true;
                    continue;
                }
                const room = Codec.blockLen(self.options) - self.block.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const bytes = input[input_read..][0..n];
                    try self.block.appendSlice(self.allocator, bytes);
                    if (self.options.content_checksum) self.hasher.update(bytes);
                    input_read += n;
                    self.total_input += n;
                    self.stream_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                // A full block can be emitted only when another input byte proves
                // it is not final; otherwise retain it until finish.
                if (self.block.items.len == Codec.blockLen(self.options) and input_read < input.len) {
                    try self.writeNonFinalBlock();
                    continue;
                }
                if (self.flush_requested) {
                    if (self.block.items.len != 0) {
                        try self.writeNonFinalBlock();
                        continue;
                    }
                    self.flush_requested = false;
                    // `need_input` is the flush-complete acknowledgement: no
                    // pending encoded bytes remain and the next call may resume
                    // normal input without a separate status enum.
                    return result(input_read, output_written, .need_input);
                }
                if (self.finishing and !self.final_written) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    try BlockEmitter.write(self.allocator, &self.pending, self.block.items, true, self.options, &self.codec_state, self.dictionary, self.history.view(), self.total_input - self.block.items.len);
                    self.block.clearRetainingCapacity();
                    try Codec.writeChecksum(self.allocator, &self.pending, self.options, &self.hasher);
                    self.final_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.frame_count += 1;
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
        fn writeNonFinalBlock(self: *Self) Error!void {
            std.debug.assert(self.block.items.len != 0);
            try self.history.prepareCompletedBlock(self.allocator, self.block.items, Codec.historyLen(self.options));
            try BlockEmitter.write(self.allocator, &self.pending, self.block.items, false, self.options, &self.codec_state, self.dictionary, self.history.view(), self.total_input - self.block.items.len);
            self.history.appendCompletedBlock(self.block.items, Codec.historyLen(self.options));
            self.block.clearRetainingCapacity();
        }
    };
}
