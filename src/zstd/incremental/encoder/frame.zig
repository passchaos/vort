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
const prefix = @import("../../prefix/binding.zig");
const prefix_errors = @import("prefix_errors.zig");

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
        prefix_state: prefix.State = .{},
        prefix_failure: ?Codec.Error = null,
        codec_state: Codec.State = .{},
        history: history_mod.Rolling = .{},
        stream_input: Count = 0,
        stream_output: Count = 0,
        frame_count: Count = 0,
        skippable_only: bool = false,

        const Self = @This();
        const allow_zero_dictionary_id = if (@hasDecl(Codec, "allow_zero_dictionary_id")) Codec.allow_zero_dictionary_id else false;
        pub const Error = Codec.Error;
        pub const PrefixSnapshot = prefix.Snapshot;
        pub const Directive = prefix.Directive;
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
        /// Borrow preset history. Persistent bindings survive session reset;
        /// dictionary_usage=.prefix borrows through only the first active frame.
        pub fn initWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary: Codec.Dictionary) Error!Self {
            if (prefixUsage(options)) return initPrefixDictionary(allocator, options, null, dictionary);
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, null, dictionary.id);
            return initialState(allocator, options, null, dictionary.id, dictionary);
        }
        pub fn initExactSizeWithPresetDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!Self {
            if (prefixUsage(options)) return initPrefixDictionary(allocator, options, expected_input_len, dictionary);
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            return initialState(allocator, options, expected_input_len, dictionary.id, dictionary);
        }
        /// Prefix bytes are borrowed through one frame, including output drain.
        pub fn initWithPrefix(allocator: std.mem.Allocator, options: Codec.Options, bytes: []const u8) Error!Self {
            return initPrefixDictionary(allocator, options, null, Codec.rawPrefix(bytes));
        }
        pub fn initExactSizeWithPrefix(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: Count, bytes: []const u8) Error!Self {
            return initPrefixDictionary(allocator, options, expected_input_len, Codec.rawPrefix(bytes));
        }
        fn prefixUsage(options: Codec.Options) bool {
            return if (@hasField(Codec.Options, "dictionary_usage")) options.dictionary_usage == .prefix else false;
        }
        fn withPrefix(options: Codec.Options, id: u32) Codec.Options {
            var selected = options;
            if (@hasField(Codec.Options, "dictionary_usage")) selected.dictionary_usage = .prefix;
            if (@hasField(Codec.Options, "dictionary_id")) selected.dictionary_id = id;
            return selected;
        }
        fn initPrefixDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected: ?Count, dictionary: Codec.Dictionary) Error!Self {
            const selected = if (prefix.hasBytes(dictionary)) @as(?Codec.Dictionary, dictionary) else null;
            const id: ?u32 = if (selected) |dict| dict.id else null;
            const configured = withPrefix(options, id orelse 0);
            try Codec.validate(configured, expected, id);
            var self = try initialState(allocator, configured, expected, id, selected);
            self.prefix_state.install(dictionary);
            return self;
        }
        fn setterEligible(self: *const Self) bool {
            return self.prefix_failure == null and !self.prefix_state.busy and
                (self.done or (!self.header_written and !self.finishing and !self.flush_requested and self.block.items.len == 0)) and
                self.pending_offset == self.pending.items.len;
        }
        pub fn prefixSnapshot(self: *const Self) prefix.Snapshot {
            var observed = self.prefix_state.snapshot();
            observed.setter_eligible = self.setterEligible();
            return observed;
        }
        pub fn setPrefix(self: *Self, bytes: []const u8) Error!void {
            try self.setPrefixWithDictionary(Codec.rawPrefix(bytes));
        }
        pub fn setPrefixWithDictionary(self: *Self, dictionary: Codec.Dictionary) Error!void {
            if (!self.setterEligible()) return error.InvalidStreamState;
            self.clearBinding();
            self.dictionary = if (prefix.hasBytes(dictionary)) dictionary else null;
            self.dictionary_id = if (self.dictionary) |dict| dict.id else null;
            self.options = withPrefix(self.options, self.dictionary_id orelse 0);
            self.prefix_state.install(dictionary);
        }
        pub fn setDictionary(self: *Self, dictionary: Codec.Dictionary) Error!void {
            if (!self.setterEligible()) return error.InvalidStreamState;
            if (prefix.hasBytes(dictionary)) {
                if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
                if (@hasDecl(Codec, "validatePrefixMetadata")) try Codec.validatePrefixMetadata(dictionary);
            }
            self.clearBinding();
            self.dictionary = if (prefix.hasBytes(dictionary)) dictionary else null;
            self.dictionary_id = if (self.dictionary) |dict| dict.id else null;
            if (@hasField(Codec.Options, "dictionary_id")) self.options.dictionary_id = self.dictionary_id orelse 0;
            if (@hasField(Codec.Options, "dictionary_usage")) self.options.dictionary_usage = .persistent;
        }
        pub fn clearDictionary(self: *Self) Error!void {
            if (!self.setterEligible()) return error.InvalidStreamState;
            self.clearBinding();
        }
        fn clearCodingState(self: *Self) void {
            if (@hasDecl(Codec, "resetState")) Codec.resetState(&self.codec_state) else self.codec_state = .{};
        }
        fn clearBinding(self: *Self) void {
            self.prefix_state.clear(&self.dictionary);
            self.dictionary_id = null;
            if (@hasField(Codec.Options, "dictionary_id")) self.options.dictionary_id = 0;
            self.clearCodingState();
        }
        fn completePrefix(self: *Self) void {
            const consumed = self.prefix_state.phase == .active;
            self.prefix_state.complete(&self.dictionary);
            if (consumed) {
                self.dictionary_id = null;
                if (@hasField(Codec.Options, "dictionary_id")) self.options.dictionary_id = 0;
                self.clearCodingState();
            }
        }
        fn failedPrefix(self: *Self, err: Error) Error {
            if (!prefix_errors.retryable(err) and self.prefix_state.phase == .active) {
                self.completePrefix();
                self.prefix_failure = err;
            }
            return err;
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
            self.resetSession();
        }
        /// Keep pending prefixes; aborting an active frame drops its prefix.
        /// Caller-selected codec policy and safety limits stay configured.
        pub fn resetSession(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.completePrefix();
            self.prefix_failure = null;
            self.stream_input = 0;
            self.stream_output = 0;
            self.frame_count = 0;
            self.resetFrame(self.options, expected_input_len, self.dictionary_id, self.dictionary);
        }
        /// Clear bindings at a fresh or drained boundary, retaining Zig policy.
        pub fn resetParameters(self: *Self) Error!void {
            if (!self.setterEligible()) return error.InvalidStreamState;
            self.clearBinding();
        }
        pub fn resetAll(self: *Self) void {
            self.resetSession();
            self.clearBinding();
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
            self.prefix_failure = null;
        }
        pub fn nextFrame(self: *Self, options: Codec.Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try self.advanceFrame(options, null);
        }
        pub fn nextFrameExactSize(self: *Self, options: Codec.Options, expected_input_len: Count) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            try self.advanceFrame(options, expected_input_len);
        }
        fn advanceFrame(self: *Self, options: Codec.Options, expected: ?Count) Error!void {
            const retained = self.prefix_state.phase == .pending;
            const id = if (retained) self.dictionary_id else null;
            const dictionary = if (retained) self.dictionary else null;
            const configured = if (retained) withPrefix(options, id orelse 0) else options;
            try Codec.validate(configured, expected, id);
            try self.bindAllocator(configured);
            self.resetFrame(configured, expected, id, dictionary);
            if (!retained) self.prefix_state = .{};
        }
        pub fn nextFrameWithPresetDictionary(self: *Self, options: Codec.Options, dictionary: Codec.Dictionary) Error!void {
            try self.nextFramePreset(options, null, dictionary);
        }
        pub fn nextFrameExactSizeWithPresetDictionary(self: *Self, options: Codec.Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!void {
            try self.nextFramePreset(options, expected_input_len, dictionary);
        }
        fn nextFramePreset(self: *Self, options: Codec.Options, expected_input_len: ?Count, dictionary: Codec.Dictionary) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            if (prefixUsage(options)) {
                const selected = if (prefix.hasBytes(dictionary)) @as(?Codec.Dictionary, dictionary) else null;
                const id: ?u32 = if (selected) |dict| dict.id else null;
                const configured = withPrefix(options, id orelse 0);
                try Codec.validate(configured, expected_input_len, id);
                try self.bindAllocator(configured);
                self.resetFrame(configured, expected_input_len, id, selected);
                self.prefix_state.install(dictionary);
                return;
            }
            if (dictionary.id == 0 and !allow_zero_dictionary_id) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary.id);
            try self.bindAllocator(options);
            self.resetFrame(options, expected_input_len, dictionary.id, dictionary);
            self.prefix_state = .{};
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
        /// Queue a standard Zstd skippable frame at a fresh or drained boundary.
        /// Start the next data frame with `nextFrame` after this drains.
        pub fn writeSkippable(self: *Self, skippable_id: u4, payload: []const u8) Error!void {
            if (@hasField(Codec.Options, "format")) {
                if (self.options.format == .magicless) return error.InvalidBlockPlan;
            }
            if (payload.len > std.math.maxInt(u32)) return error.IntegerOverflow;
            if ((!self.done and !prefixUsage(self.options)) or !self.setterEligible()) return error.InvalidBlockPlan;
            _ = self.prefix_state.activate(.skippable);
            self.prefix_state.busy = true;
            errdefer self.completePrefix();
            try self.bindAllocator(self.options);
            const original_len = self.pending.items.len;
            errdefer self.pending.items.len = original_len;
            Codec.writeSkippable(self.allocator, &self.pending, skippable_id, payload) catch |err|
                return @errorCast(self.allocation.mapError(err));
            self.done = false;
            self.skippable_only = true;
        }
        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepCommon(input, output, null);
        }
        /// A completed frame requires explicit nextFrame before another frame.
        /// Invalid directives and stages leave the selected prefix untouched.
        pub fn stepWithDirective(self: *Self, input: []const u8, output: []u8, directive: prefix.Directive) Error!core.StepResult {
            switch (directive) {
                .@"continue", .flush, .end => {},
                _ => return error.InvalidStreamState,
            }
            if ((self.done and input.len != 0) or ((self.finishing or self.flush_requested or self.skippable_only) and input.len != 0) or (self.finishing and directive == .flush)) return error.InvalidStreamState;
            return self.stepCommon(input, output, directive);
        }
        fn stepCommon(self: *Self, input: []const u8, output: []u8, directive: ?prefix.Directive) Error!core.StepResult {
            if (self.prefix_failure) |err| return err;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested or self.skippable_only) and input.len != 0) return error.TrailingData;
            const activated = self.prefix_state.activate(if (self.skippable_only) .skippable else .frame);
            self.prefix_state.busy = true;
            if (activated and !self.skippable_only) if (@hasDecl(Codec, "validatePrefixMetadata")) {
                if (self.dictionary) |dictionary| Codec.validatePrefixMetadata(dictionary) catch |err| return self.failedPrefix(err);
            };
            // A call may accept input across several blocks. Refuse an
            // unrepresentable offered slice before draining a frame header or
            // pending block; commit counters only as bytes are accepted below.
            _ = count.addLocal(self.total_input, input.len) catch |err| return self.failedPrefix(err);
            _ = count.addLocal(self.stream_input, input.len) catch |err| return self.failedPrefix(err);
            self.bindAllocator(self.options) catch |err| return self.failedPrefix(err);
            return self.stepImpl(input, output, directive) catch |err| return self.failedPrefix(@errorCast(self.allocation.mapError(err)));
        }
        fn stepImpl(self: *Self, input: []const u8, output: []u8, directive: ?prefix.Directive) Error!core.StepResult {
            // Final completion must remain representable before any of this
            // call's pending output is delivered to the caller.
            if ((self.finishing or directive == .end) and !self.skippable_only) _ = try count.addLocal(self.frame_count, 1);
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
                    self.completePrefix();
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
                if (input_read == input.len) if (directive) |requested| switch (requested) {
                    .end => {
                        self.finishing = true;
                        self.flush_requested = false;
                    },
                    .flush => if (!self.finishing) {
                        self.flush_requested = true;
                    },
                    .@"continue" => {},
                    _ => unreachable,
                };
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
                    self.completePrefix();
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
