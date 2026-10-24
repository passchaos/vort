const std = @import("std");
const core = @import("../../../core.zig");
const Count = core.StreamCount;
const count = core.stream_count;
const XxHash64 = @import("../../../checksum/xxh64_stream.zig").XxHash64;
const history_mod = @import("history.zig");
const final_transaction = @import("final_transaction.zig");
const allocator_adapter = @import("allocator_adapter.zig");
const total_budget = @import("../../encode/total_budget.zig");
const controls = @import("../../encode/controls.zig");

/// Build an incremental Zstd frame encoder. One bounded block is retained;
/// completed raw, RLE, or entropy-coded blocks drain through arbitrary caller
/// output. The final block bit is delayed until `finish`, as required by Zstd.
pub fn Encoder(comptime Codec: type, comptime BlockEmitter: type) type {
    return struct {
        allocator: std.mem.Allocator,
        allocation: allocator_adapter.Binding,
        options: Codec.Options,
        block: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        hasher: XxHash64 = XxHash64.init(0),
        header_written: bool = false,
        flush_requested: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: Count = 0,
        total_output: Count = 0,
        expected_input_len: ?Count = null,
        dictionary_id: ?u32 = null,
        dictionary: ?Codec.Dictionary = null,
        codec_state: Codec.State = .{},
        history: history_mod.Rolling = .{},
        stream_input: Count = 0,
        stream_output: Count = 0,
        frame_count: Count = 0,
        skippable_only: bool = false,

        const Self = @This();
        const allow_zero_dictionary_id = if (@hasDecl(Codec, "allow_zero_dictionary_id")) Codec.allow_zero_dictionary_id else false;
        pub const Error = Codec.Error;
        pub const Snapshot = struct {
            input_read: Count,
            output_written: Count,
            frame_input: Count,
            frame_output: Count,
            buffered_input: usize,
            pending_output: usize,
            frame_count: Count,
            frame_index: Count,
            finishing: bool,
            done: bool,
        };
        pub fn init(allocator: std.mem.Allocator, options: Codec.Options) Error!Self {
            try Codec.validate(options, null, null);
            return initialState(allocator, options, null, null, null);
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count) Error!Self {
            try Codec.validate(options, expected_input_len, null);
            return initialState(allocator, options, expected_input_len, null, null);
        }
        /// Retained for callers that only need Dictionary_ID metadata in a
        /// raw/RLE stream. Use `initWithPresetDictionary` when blocks should
        /// actually reference preset history.
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary_id: u32) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            if (options.selection != .raw_or_rle) return error.InvalidBlockPlan;
            try Codec.validate(options, null, dictionary_id);
            return initialState(allocator, options, null, dictionary_id, null);
        }
        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count, dictionary_id: u32) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            if (options.selection != .raw_or_rle) return error.InvalidBlockPlan;
            try Codec.validate(options, expected_input_len, dictionary_id);
            return initialState(allocator, options, expected_input_len, dictionary_id, null);
        }
        /// Borrow preset history for the encoder lifetime. Entropy-coded blocks
        /// may reference these bytes, so they must outlive the encoder.
        pub fn initWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary: Codec.Dictionary) Error!Self {
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, null, dictionary.id);
            return initialState(allocator, options, null, dictionary.id, dictionary);
        }
        pub fn initExactSizeWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!Self {
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            return initialState(allocator, options, expected_input_len, dictionary.id, dictionary);
        }
        pub fn initWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initWithPresetDictionary(allocator, options, dictionary);
        }
        pub fn initExactSizeWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initExactSizeWithPresetDictionary(allocator, options, expected_input_len, dictionary);
        }
        pub fn deinit(self: *Self) void {
            const a = self.allocation.current();
            if (@hasDecl(Codec, "deinitState")) Codec.deinitState(&self.codec_state, a);
            self.history.deinit(a);
            self.block.deinit(a);
            self.pending.deinit(a);
            self.allocation.deinit();
            self.* = undefined;
        }
        fn initialState(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: ?Count, dictionary_id: ?u32, dictionary: ?Codec.Dictionary) Error!Self {
            var state: Self = .{ .allocator = allocator, .allocation = try allocator_adapter.Binding.init(allocator), .options = options, .expected_input_len = expected_input_len, .dictionary_id = dictionary_id, .dictionary = dictionary };
            errdefer state.allocation.deinit();
            try state.bindAllocator(options);
            return state;
        }
        fn retainedIoBytes(self: *const Self) Error!usize {
            var bytes = std.math.add(usize, self.block.capacity, self.pending.capacity) catch return error.IntegerOverflow;
            bytes = std.math.add(usize, bytes, self.history.bytes.capacity) catch return error.IntegerOverflow;
            const entries = std.math.add(usize, self.history.index.recent_entries.capacity, self.history.index.long_entries.capacity) catch return error.IntegerOverflow;
            const indexed = std.math.mul(usize, entries, @sizeOf(Count)) catch return error.IntegerOverflow;
            return std.math.add(usize, bytes, indexed) catch error.IntegerOverflow;
        }
        fn bindAllocator(self: *Self, options: Codec.Options) Error!void {
            self.allocator = try self.allocation.activate(Codec, options, &self.codec_state, try self.retainedIoBytes());
        }
        pub fn memorySnapshot(self: *const Self) total_budget.Snapshot {
            return self.allocation.snapshot();
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.stream_input = 0;
            self.stream_output = 0;
            self.frame_count = 0;
            self.resetFrame(self.options, expected_input_len, self.dictionary_id, self.dictionary);
        }
        fn resetFrame(self: *Self, options: Codec.Options, expected_input_len: ?Count, dictionary_id: ?u32, dictionary: ?Codec.Dictionary) void {
            self.options = options;
            self.block.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.hasher = XxHash64.init(0);
            self.header_written = false;
            self.flush_requested = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
            if (@hasDecl(Codec, "resetState")) Codec.resetState(&self.codec_state) else self.codec_state = .{};
            self.history.clearRetainingCapacity();
            self.dictionary_id = dictionary_id;
            self.dictionary = dictionary;
            self.skippable_only = false;
        }
        pub fn nextFrame(self: *Self, options: Codec.Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try Codec.validate(options, null, null);
            try self.bindAllocator(options);
            self.resetFrame(options, null, null, null);
        }
        pub fn nextFrameExactSize(self: *Self, options: Codec.Options, expected_input_len: Count) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try Codec.validate(options, expected_input_len, null);
            try self.bindAllocator(options);
            self.resetFrame(options, expected_input_len, null, null);
        }
        pub fn nextFrameExactSizeWithPresetDictionary(self: *Self, options: Codec.Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            try self.bindAllocator(options);
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
            try self.bindAllocator(self.options);
            const original_len = self.pending.items.len;
            errdefer self.pending.items.len = original_len;
            Codec.writeSkippable(self.allocator, &self.pending, skippable_id, payload) catch |err|
                return @errorCast(self.allocation.mapError(err));
            self.done = false;
            self.skippable_only = true;
        }
        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
            // A call may accept input across several blocks. Refuse an
            // unrepresentable offered slice before draining a frame header or
            // pending block; commit counters only as bytes are accepted below.
            _ = try count.addLocal(self.total_input, input.len);
            _ = try count.addLocal(self.stream_input, input.len);
            try self.bindAllocator(self.options);
            return self.stepImpl(input, output) catch |err| return @errorCast(self.allocation.mapError(err));
        }
        fn stepImpl(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            // Final completion must remain representable before any of this
            // call's pending output is delivered to the caller.
            if (self.finishing and !self.skippable_only) _ = try count.addLocal(self.frame_count, 1);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    const next_output = try count.addLocal(self.total_output, n);
                    const next_stream_output = try count.addLocal(self.stream_output, n);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output = next_output;
                    self.stream_output = next_stream_output;
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
                    const original_len = self.pending.items.len;
                    errdefer self.pending.items.len = original_len;
                    try Codec.writeHeader(self.allocator, &self.pending, self.options, self.expected_input_len, self.dictionary_id);
                    self.header_written = true;
                    continue;
                }
                const room = Codec.blockLen(self.options) - self.block.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const bytes = input[input_read..][0..n];
                    const next_input = try count.addLocal(self.total_input, n);
                    const next_stream = try count.addLocal(self.stream_input, n);
                    if (self.expected_input_len) |expected| if (next_input > expected) return error.SizeMismatch;
                    try self.block.appendSlice(self.allocator, bytes);
                    if (self.options.content_checksum) self.hasher.update(bytes);
                    input_read += n;
                    self.total_input = next_input;
                    self.stream_input = next_stream;
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
                    try final_transaction.append(Codec, BlockEmitter, self.allocator, &self.pending, self.block.items, self.options, &self.codec_state, self.dictionary, self.history.view(), self.total_input - count.fromLocal(self.block.items.len), &self.hasher);
                    self.block.clearRetainingCapacity();
                    self.final_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.frame_count = count.addLocal(self.frame_count, 1) catch unreachable;
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
            const original_len = self.pending.items.len;
            var next_state = self.codec_state;
            const emission = controls.EmissionTransaction.init(if (@hasField(Codec.Options, "control_profile")) self.options.control_profile else null);
            errdefer {
                self.pending.items.len = original_len;
                emission.rollback();
            }
            try self.history.prepareCompletedBlock(self.allocator, self.block.items, Codec.historyLen(self.options));
            try BlockEmitter.write(self.allocator, &self.pending, self.block.items, false, self.options, &next_state, self.dictionary, self.history.view(), self.total_input - count.fromLocal(self.block.items.len));
            self.codec_state = next_state;
            self.history.appendCompletedBlock(self.block.items, Codec.historyLen(self.options));
            self.block.clearRetainingCapacity();
        }
    };
}

test {
    _ = @import("budget_tests.zig");
    _ = @import("counter_tests.zig");
}
