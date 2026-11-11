const std = @import("std");
const core = @import("../../../core.zig");
const clone_storage = @import("../clone_storage.zig");
const Count = core.StreamCount;
const stream_count = core.stream_count;
const huffman = @import("../../../huffman.zig");
const bitstream = @import("../../../bitstream.zig");
const semantic = @import("../../semantic/decoder.zig");
const rolling_decoder = @import("../../semantic/rolling_decoder.zig");
const semantic_state = @import("semantic_state.zig");
const step_borrows = @import("step_borrows.zig");
const rewindSemanticLookahead = @import("semantic_bits.zig").rewindLookahead;
pub const SemanticMode = semantic_state.Mode;
pub const SemanticWork = semantic_state.Work;
const compact_tables = @import("compact_tables.zig");
const buildCanonicalLookup = compact_tables.buildCanonicalLookup;
const validCodeLengthAlphabet = compact_tables.validCodeLengthAlphabet;
const validDynamicAlphabet = compact_tables.validDynamicAlphabet;
const tableSymbol = compact_tables.tableSymbol;
const canonicalSymbol = compact_tables.canonicalSymbol;

pub const Format = struct {
    window_len: usize = 32 * 1024,
    distance_symbol_count: usize = 30,
    extended_length_285: bool = false,
};

pub const Decoder = DecoderWithFormat(.{});

/// Byte-progressive raw-DEFLATE/Deflate64 decoder.
/// Huffman code state survives arbitrary input splits; literals stream directly
/// to caller output. A caller-owned format-sized history ring backs length/distance
/// copies, including overlapping matches across arbitrary output boundaries.
pub fn DecoderWithFormat(comptime format: Format) type {
    return DecoderWithMode(format, .rolling, false);
}

/// Compile-time reference and diagnostic routes for differential validation.
/// Public default decoding omits counters and token-progress observations.
pub fn DecoderWithMode(comptime format: Format, comptime mode: SemanticMode, comptime observed: bool) type {
    return struct {
        const Self = @This();
        const supports_semantic_window = format.window_len == 32 * 1024 and
            format.distance_symbol_count == 30 and
            !format.extended_length_285;
        /// Building the large semantic tables and linearizing the history ring
        /// is profitable for substantial contiguous payloads. Tiny streams and
        /// highly fragmented callers stay on the compact resumable tables.
        const semantic_min_contiguous_input: usize = 4 * 1024;
        const SemanticDecoder = if (supports_semantic_window)
            semantic.SemanticDynamicDecoder
        else
            struct {};
        options: Options,
        phase: Phase = .block_header,
        /// One-shot request set by `stepToBlockBoundary`; cleared when the
        /// step returns so ordinary `step` callers are unaffected.
        pause_requested: bool = false,
        bit_buffer: u64 = 0,
        bit_count: u6 = 0,
        code: u16 = 0,
        code_bits: u4 = 0,
        final_block: bool = false,
        history: []u8 = &.{},
        /// Optional two-window caller storage. The first window remains the
        /// compact fallback ring; the complete slice lets a dynamic block run
        /// through bounded semantic generations without hidden allocation.
        semantic_scratch: []u8 = &.{},
        history_pos: usize = 0,
        history_len: usize = 0,
        length_base: usize = 0,
        length_extra_bits: u6 = 0,
        distance_code: u16 = 0,
        distance_code_bits: u3 = 0,
        match_len: usize = 0,
        match_remaining: usize = 0,
        match_distance: usize = 0,
        stored_lengths: [4]u8 = undefined,
        stored_length_received: usize = 0,
        stored_remaining: usize = 0,
        dynamic_hlit: usize = 0,
        dynamic_hdist: usize = 0,
        dynamic_hclen: usize = 0,
        dynamic_code_length_index: usize = 0,
        dynamic_code_lengths: [19]u4 = @splat(0),
        dynamic_code_lookup: [1 << 7]u16 = @splat(0),
        dynamic_literal_lengths: [286]u4 = @splat(0),
        dynamic_literal_lookup: [1 << 11]u16 = @splat(0),
        dynamic_distance_lengths: [format.distance_symbol_count]u4 = @splat(0),
        dynamic_distance_lookup: [1 << 10]u16 = @splat(0),
        /// Precomputed canonical tables for the long-code fallback. The
        /// incremental reader accumulates bits itself, so it scans the
        /// per-length entry groups directly instead of rebuilding canonical
        /// codes per miss.
        dynamic_literal_table: huffman.HuffmanTable(286) = .{},
        dynamic_distance_table: huffman.HuffmanTable(format.distance_symbol_count) = .{},
        semantic_decoder: ?*SemanticDecoder = null,
        semantic_prefix_start: usize = 0,
        semantic_prefix_len: usize = 0,
        semantic_work: if (observed) SemanticWork else void = if (observed) .{} else {},
        semantic_generated_end: usize = 0,
        semantic_delivered: usize = 0,
        semantic_end_of_block: bool = false,
        semantic_blocks_started: Count = 0,
        semantic_blocks_completed: Count = 0,
        dynamic_length_pos: usize = 0,
        dynamic_previous_length: u4 = 0,
        dynamic_repeat_symbol: u5 = 0,
        dynamic_code: u16 = 0,
        dynamic_code_bits: u4 = 0,
        dynamic_block: bool = false,
        input_finished: bool = false,
        total_input: Count = 0,
        total_output: Count = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .block_header,

        pub const Error = core.Error;
        pub const CloneError = clone_storage.Error;
        pub const CloneStorage = struct {
            history: []u8 = &.{},
            semantic_workspace: ?*SemanticWorkspace = null,
        };
        pub const required_history_len: usize = format.window_len;
        pub const SemanticWorkspace = SemanticDecoder;
        /// Supplying this much history provides the two-window scratch used by
        /// the semantic path. Attach `SemanticWorkspace` as the second opt-in;
        /// smaller histories or no workspace retain the compact fallback.
        pub const recommended_history_len: usize = if (supports_semantic_window)
            2 * format.window_len
        else
            format.window_len;
        pub const Options = struct {
            max_output_len: Count = std.math.maxInt(Count),
            expected_output_len: ?Count = null,
            /// Stop at the first final block and leave any suffix unconsumed.
            /// Format wrappers use this to retain ownership of their footer.
            allow_trailing_data: bool = false,
            /// Return need_output at max_output_len, retaining a valid prefix
            /// even when its final stored chunk or match continues beyond it.
            stop_at_output_limit: bool = false,
            /// Optional surrounding-format distance cap within the history ring.
            max_distance: usize = format.window_len,
        };
        pub const Phase = enum { block_header, stored_lengths, stored_payload, dynamic_counts, dynamic_code_lengths, dynamic_lengths, dynamic_repeat, fast_dynamic_block, symbols, length_extra, distance_symbol, distance_extra, match_copy, done };

        pub fn init() Self {
            return initWithOptions(.{});
        }
        pub fn initWithHistory(options: Options, history: []u8) Error!Self {
            if (history.len < format.window_len) return error.OutputTooSmall;
            return .{
                .options = options,
                .history = history[0..format.window_len],
                .semantic_scratch = if (supports_semantic_window and history.len >= recommended_history_len)
                    history[0..recommended_history_len]
                else
                    &.{},
            };
        }
        /// Attach caller-owned semantic table storage. A 64 KiB history and
        /// this workspace are both required before the dynamic fast path is
        /// selected; otherwise decoding keeps the compact fallback footprint.
        /// The workspace must remain alive until detached or until the decoder
        /// itself is discarded. Reset deliberately preserves the attachment.
        /// Keep the decoder at a stable address once decoding starts with this
        /// attachment; use cloneInto to copy its resumable state safely.
        pub fn attachSemanticWorkspace(self: *Self, workspace: *SemanticWorkspace) Error!void {
            if (self.phase == .fast_dynamic_block) return error.InvalidStreamState;
            if (comptime !supports_semantic_window) return error.UnsupportedDeflateFeature;
            self.semantic_decoder = workspace;
        }
        pub fn detachSemanticWorkspace(self: *Self) Error!void {
            if (self.phase == .fast_dynamic_block) return error.InvalidStreamState;
            self.semantic_decoder = null;
        }
        pub fn initWithDictionary(options: Options, history: []u8, dictionary: []const u8) Error!Self {
            var decoder = try initWithHistory(options, history);
            decoder.seedDictionary(dictionary);
            return decoder;
        }
        pub fn initWithOptions(options: Options) Self {
            return .{ .options = options };
        }
        /// Bytes required to preserve this decoder's current history geometry.
        /// An attached workspace also needs an independent SemanticWorkspace.
        pub fn cloneHistoryLen(self: *const Self) usize {
            return @max(self.history.len, self.semantic_scratch.len);
        }

        /// Copy complete resumable state into a stable destination. The copied
        /// history/workspace must remain alive and the destination must not move
        /// while its workspace is attached. Validation makes no writes on error.
        pub fn cloneInto(self: *const Self, destination: *Self, storage: CloneStorage) CloneError!void {
            try self.validateCloneStorage(destination, storage);
            const required = self.cloneHistoryLen();
            const history = storage.history[0..required];
            if (required != 0)
                @memcpy(history, if (self.semantic_scratch.len != 0) self.semantic_scratch else self.history);
            destination.* = self.*;
            destination.history = history[0..self.history.len];
            destination.semantic_scratch = history[0..self.semantic_scratch.len];
            destination.semantic_decoder = storage.semantic_workspace;
            if (self.semantic_decoder) |source_workspace|
                storage.semantic_workspace.?.* = source_workspace.*;
            clone_storage.rebindRaw(destination);
        }

        fn validateCloneStorage(self: *const Self, destination: *Self, storage: CloneStorage) CloneError!void {
            if ((self.history.len != 0 and self.history.len != required_history_len) or
                (!supports_semantic_window and self.semantic_decoder != null) or
                self.history_len > self.history.len or
                (self.history.len == 0 and self.history_pos != 0) or
                (self.history.len != 0 and self.history_pos >= self.history.len) or
                storage.history.len < self.cloneHistoryLen() or
                (self.semantic_decoder == null) != (storage.semantic_workspace == null))
                return error.InvalidCloneStorage;
            if (self.semantic_scratch.len != 0 and
                (!supports_semantic_window or self.semantic_scratch.len != recommended_history_len or
                    self.history.ptr != self.semantic_scratch.ptr))
                return error.InvalidCloneStorage;
            if (self.phase == .fast_dynamic_block) {
                if (comptime !supports_semantic_window) return error.InvalidCloneStorage;
                const workspace = self.semantic_decoder orelse return error.InvalidCloneStorage;
                if (self.semantic_scratch.len != recommended_history_len or
                    self.semantic_prefix_start >= recommended_history_len or
                    self.semantic_prefix_len > format.window_len or
                    self.semantic_generated_end < self.semantic_prefix_len or
                    self.semantic_generated_end > self.semantic_prefix_len + format.window_len or
                    self.semantic_delivered < self.semantic_prefix_len or
                    self.semantic_delivered > self.semantic_generated_end or
                    workspace.compact_literal != &self.dynamic_literal_table or
                    workspace.compact_distance != &self.dynamic_distance_table)
                    return error.InvalidCloneStorage;
            }
            const source_bytes = std.mem.asBytes(self);
            const destination_bytes = std.mem.asBytes(destination);
            const source_history = if (self.semantic_scratch.len != 0) self.semantic_scratch else self.history;
            try clone_storage.disjoint(source_bytes, destination_bytes);
            try clone_storage.disjoint(source_bytes, source_history);
            try clone_storage.disjoint(source_bytes, storage.history);
            try clone_storage.disjoint(destination_bytes, source_history);
            try clone_storage.disjoint(destination_bytes, storage.history);
            try clone_storage.disjoint(source_history, storage.history);
            if (self.semantic_decoder) |workspace| {
                const bytes = std.mem.asBytes(workspace);
                try clone_storage.disjoint(source_bytes, bytes);
                try clone_storage.disjoint(destination_bytes, bytes);
                try clone_storage.disjoint(source_history, bytes);
                try clone_storage.disjoint(storage.history, bytes);
                try clone_storage.disjoint(bytes, std.mem.asBytes(storage.semantic_workspace.?));
            }
            if (storage.semantic_workspace) |workspace| {
                const bytes = std.mem.asBytes(workspace);
                try clone_storage.disjoint(source_bytes, bytes);
                try clone_storage.disjoint(destination_bytes, bytes);
                try clone_storage.disjoint(source_history, bytes);
                try clone_storage.disjoint(storage.history, bytes);
            }
        }
        pub fn reset(self: *Self) void {
            // Lookup tables are rebuilt before their next dynamic block is decoded.
            // Preserve their backing storage instead of clearing the largest part
            // of the reusable decoder on every independent stream.
            self.phase = .block_header;
            self.bit_buffer = 0;
            self.bit_count = 0;
            self.code = 0;
            self.code_bits = 0;
            self.final_block = false;
            self.history_pos = 0;
            self.history_len = 0;
            self.semantic_prefix_start = 0;
            self.semantic_prefix_len = 0;
            if (observed) self.semantic_work = .{};
            self.semantic_generated_end = 0;
            self.semantic_delivered = 0;
            self.semantic_end_of_block = false;
            self.semantic_blocks_started = 0;
            self.semantic_blocks_completed = 0;
            self.length_base = 0;
            self.length_extra_bits = 0;
            self.distance_code = 0;
            self.distance_code_bits = 0;
            self.match_len = 0;
            self.match_remaining = 0;
            self.match_distance = 0;
            self.stored_length_received = 0;
            self.stored_remaining = 0;
            self.dynamic_hlit = 0;
            self.dynamic_hdist = 0;
            self.dynamic_hclen = 0;
            self.dynamic_code_length_index = 0;
            self.dynamic_length_pos = 0;
            self.dynamic_previous_length = 0;
            self.dynamic_repeat_symbol = 0;
            self.dynamic_code = 0;
            self.dynamic_code_bits = 0;
            self.dynamic_block = false;
            self.input_finished = false;
            self.total_input = 0;
            self.total_output = 0;
            self.last_error_name = "";
            self.last_error_phase = .block_header;
        }
        /// Reset raw-DEFLATE block/history state after an external sync-marker
        /// scanner consumed `skipped_input` bytes. Cumulative input/output counters
        /// and output limits remain attached to this logical recovery session.
        pub fn resumeAfterSync(self: *Self, skipped_input: usize) Error!void {
            const resumed_input = try stream_count.addLocal(self.total_input, skipped_input);
            const produced = self.total_output;
            self.reset();
            self.total_input = resumed_input;
            self.total_output = produced;
        }
        /// Seed only while no semantic generation is active (normally after
        /// initialization, reset or sync recovery). Caller storage is replaced.
        pub fn seedDictionary(self: *Self, dictionary: []const u8) void {
            std.debug.assert(self.phase != .fast_dynamic_block);
            if (self.history.len == 0) return;
            const keep = @min(dictionary.len, self.history.len);
            const source = dictionary[dictionary.len - keep ..];
            @memcpy(self.history[0..keep], source);
            self.history_len = keep;
            self.history_pos = if (keep == self.history.len) 0 else keep;
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            return .{
                .phase_name = @tagName(self.phase),
                .frame_input_read = self.total_input,
                .output_written = self.total_output,
                .expected_output_len = self.options.expected_output_len,
                .last_error_name = self.last_error_name,
                .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.UnsupportedDeflateFeature))) "unsupported_feature" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn semanticWork(self: *const Self) SemanticWork {
            return if (observed) self.semantic_work else .{};
        }
        pub fn semanticBlocksStarted(self: *const Self) Count {
            return self.semantic_blocks_started;
        }
        pub fn semanticBlocksCompleted(self: *const Self) Count {
            return self.semantic_blocks_completed;
        }
        /// Advance until the next compressed-block boundary, an input/output
        /// wait, or completion. When the returned `block_boundary` flag is set,
        /// the decoder is positioned at the next block header and `progress`
        /// reports consumed input/output. The caller may persist its own state
        /// and resume with another call.
        pub fn stepToBlockBoundary(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepInternal(input, output, true);
        }
        pub fn atBlockBoundary(self: *const Self) bool {
            return self.phase == .block_header or self.phase == .done;
        }

        pub fn finish(self: *Self) Error!void {
            self.input_finished = true;
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        }

        pub fn step(self: *Self, input: []const u8, provided_output: []u8) Error!core.StepResult {
            return self.stepInternal(input, provided_output, false);
        }

        fn stepInternal(self: *Self, input: []const u8, provided_output: []u8, boundary: bool) Error!core.StepResult {
            const semantic_admitted = try self.admitStep(input, provided_output);
            if (boundary) self.pause_requested = true;
            defer if (boundary) {
                self.pause_requested = false;
            };
            const output = if (self.options.stop_at_output_limit and self.options.max_output_len != std.math.maxInt(Count))
                provided_output[0..stream_count.bounded(self.options.max_output_len -| self.total_output, provided_output.len)]
            else
                provided_output;
            if (self.input_finished) {
                if (input.len != 0 and !self.options.allow_trailing_data)
                    return self.fail(self.phase, error.TrailingData);
                return .{ .status = if (self.phase == .done) .done else .need_input };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            var history_record_start: usize = 0;
            defer {
                if (history_record_start != output_written)
                    self.recordStepOutput(output[history_record_start..output_written]);
            }
            while (!self.options.stop_at_output_limit or
                self.options.max_output_len == std.math.maxInt(Count) or
                self.total_output < self.options.max_output_len or
                self.phase == .fast_dynamic_block)
            {
                if (self.pause_requested and self.phase == .block_header and
                    (input_read != 0 or output_written != 0))
                {
                    var paused = result(input_read, output_written, .need_input);
                    paused.block_boundary = true;
                    return paused;
                }
                switch (self.phase) {
                    .block_header => {
                        const header = (try self.readBits(input, &input_read, 3)) orelse return result(input_read, output_written, .need_input);
                        self.final_block = (header & 1) != 0;
                        const block_type = (header >> 1) & 0x3;
                        switch (block_type) {
                            0 => {
                                self.alignStoredHeader();
                                self.phase = .stored_lengths;
                            },
                            1 => {
                                self.dynamic_block = false;
                                self.phase = .symbols;
                            },
                            2 => {
                                self.dynamic_block = true;
                                self.phase = .dynamic_counts;
                            },
                            else => return self.fail(.block_header, error.InvalidDeflateBlockType),
                        }
                    },
                    .stored_lengths => {
                        while (self.stored_length_received < self.stored_lengths.len) {
                            const byte = (try self.readBits(input, &input_read, 8)) orelse return result(input_read, output_written, .need_input);
                            self.stored_lengths[self.stored_length_received] = @intCast(byte);
                            self.stored_length_received += 1;
                        }
                        const len = std.mem.readInt(u16, self.stored_lengths[0..2], .little);
                        const nlen = std.mem.readInt(u16, self.stored_lengths[2..4], .little);
                        if (nlen != ~len) return self.fail(.stored_lengths, error.StoredLengthMismatch);
                        if (!self.options.stop_at_output_limit or self.options.max_output_len == std.math.maxInt(Count))
                            _ = try self.nextOutput(self.total_output, len, .stored_lengths);
                        if (!self.options.stop_at_output_limit and
                            (self.total_output > self.options.max_output_len or len > self.options.max_output_len - self.total_output))
                            return self.fail(.stored_lengths, error.OutputLimitExceeded);
                        if (self.options.expected_output_len) |expected| {
                            if (self.total_output > expected or len > expected - self.total_output) return self.fail(.stored_lengths, error.SizeMismatch);
                        }
                        self.stored_remaining = len;
                        self.stored_length_received = 0;
                        self.phase = .stored_payload;
                        if (self.stored_remaining == 0) self.completeBlock();
                    },
                    .stored_payload => {
                        if (output_written == output.len) return result(input_read, output_written, .need_output);
                        if (input_read == input.len and self.bit_count == 0) return result(input_read, output_written, .need_input);
                        while (self.stored_remaining != 0 and
                            output_written < output.len and
                            self.bit_count >= 8)
                        {
                            const next_output = try self.nextOutput(self.total_output, 1, .stored_payload);
                            const byte = (try self.readBits(input, &input_read, 8)) orelse return result(input_read, output_written, .need_input);
                            output[output_written] = @intCast(byte);
                            output_written += 1;
                            self.total_output = next_output;
                            self.stored_remaining -= 1;
                        }
                        if (self.stored_remaining != 0 and
                            output_written < output.len and
                            self.bit_count == 0)
                        {
                            const available = @min(
                                self.stored_remaining,
                                @min(input.len - input_read, output.len - output_written),
                            );
                            const n = stream_count.bounded(
                                @min(std.math.maxInt(Count) - self.total_input, std.math.maxInt(Count) - self.total_output),
                                available,
                            );
                            if (available != 0 and n == 0)
                                return self.fail(.stored_payload, error.IntegerOverflow);
                            if (n != 0) {
                                const next_input = stream_count.addLocal(self.total_input, n) catch |err|
                                    return self.fail(.stored_payload, err);
                                const next_output = try self.nextOutput(self.total_output, n, .stored_payload);
                                const produced = output[output_written..][0..n];
                                @memcpy(produced, input[input_read..][0..n]);
                                self.total_output = next_output;
                                input_read += n;
                                self.total_input = next_input;
                                output_written += n;
                                self.stored_remaining -= n;
                            }
                        }
                        if (self.stored_remaining == 0) self.completeBlock();
                    },
                    .dynamic_counts => {
                        const counts = (try self.readBits(input, &input_read, 14)) orelse return result(input_read, output_written, .need_input);
                        self.dynamic_hlit = (counts & 0x1f) + 257;
                        self.dynamic_hdist = ((counts >> 5) & 0x1f) + 1;
                        self.dynamic_hclen = ((counts >> 10) & 0x0f) + 4;
                        if (self.dynamic_hlit > 286 or self.dynamic_hdist > format.distance_symbol_count) return self.fail(.dynamic_counts, error.InvalidDynamicBlockHeader);
                        self.dynamic_code_lengths = @splat(0);
                        self.dynamic_code_length_index = 0;
                        self.phase = .dynamic_code_lengths;
                    },
                    .dynamic_code_lengths => {
                        while (self.dynamic_code_length_index < self.dynamic_hclen) {
                            const length = (try self.readBits(input, &input_read, 3)) orelse return result(input_read, output_written, .need_input);
                            self.dynamic_code_lengths[code_length_order[self.dynamic_code_length_index]] = @intCast(length);
                            self.dynamic_code_length_index += 1;
                        }
                        if (!validCodeLengthAlphabet(self.dynamic_code_lengths)) return self.fail(.dynamic_code_lengths, error.InvalidDynamicBlockHeader);
                        buildCanonicalLookup(7, &self.dynamic_code_lookup, &self.dynamic_code_lengths);
                        self.dynamic_literal_lengths = @splat(0);
                        self.dynamic_distance_lengths = @splat(0);
                        self.dynamic_length_pos = 0;
                        self.dynamic_previous_length = 0;
                        self.phase = .dynamic_lengths;
                    },
                    .dynamic_lengths => {
                        const total = self.dynamic_hlit + self.dynamic_hdist;
                        if (self.dynamic_length_pos == total) {
                            if (try self.prepareDynamicTables(input.len - input_read, semantic_admitted)) {
                                // Commit earlier output before linearizing its history.
                                if (history_record_start != output_written) {
                                    self.recordStepOutput(output[history_record_start..output_written]);
                                    history_record_start = output_written;
                                }
                                try self.beginSemanticBlock();
                                self.phase = .fast_dynamic_block;
                                continue;
                            }
                            self.phase = .symbols;
                            continue;
                        }
                        const symbol = (try self.readCodeLengthSymbol(input, &input_read)) orelse return result(input_read, output_written, .need_input);
                        switch (symbol) {
                            0...15 => {
                                self.setDynamicLength(@intCast(symbol));
                                self.dynamic_previous_length = @intCast(symbol);
                                self.dynamic_length_pos += 1;
                            },
                            16...18 => {
                                if (symbol == 16 and self.dynamic_length_pos == 0) return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
                                self.dynamic_repeat_symbol = @intCast(symbol);
                                self.phase = .dynamic_repeat;
                            },
                            else => return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader),
                        }
                    },
                    .dynamic_repeat => {
                        const extra_bits: u6 = switch (self.dynamic_repeat_symbol) {
                            16 => 2,
                            17 => 3,
                            18 => 7,
                            else => unreachable,
                        };
                        const extra = (try self.readBits(input, &input_read, extra_bits)) orelse return result(input_read, output_written, .need_input);
                        const repeat_base: usize = switch (self.dynamic_repeat_symbol) {
                            16, 17 => 3,
                            18 => 11,
                            else => unreachable,
                        };
                        const count: usize = extra + repeat_base;
                        const total = self.dynamic_hlit + self.dynamic_hdist;
                        if (count > total - self.dynamic_length_pos) return self.fail(.dynamic_repeat, error.InvalidDynamicBlockHeader);
                        const value: u4 = if (self.dynamic_repeat_symbol == 16) self.dynamic_previous_length else 0;
                        for (0..count) |_| {
                            self.setDynamicLength(value);
                            self.dynamic_length_pos += 1;
                        }
                        self.dynamic_previous_length = value;
                        self.phase = .dynamic_lengths;
                    },
                    .fast_dynamic_block => {
                        if (comptime !supports_semantic_window) unreachable;
                        switch (try self.stepSemanticBlock(
                            input,
                            output,
                            &input_read,
                            &output_written,
                            &history_record_start,
                        )) {
                            .need_output => return result(input_read, output_written, .need_output),
                            .need_input => return result(input_read, output_written, .need_input),
                            // `beginSemanticBlock` may already have committed a
                            // step-local prefix into the ring. Cut the step before
                            // compact fallback so it cannot count that prefix both
                            // as retained history and as fresh step output.
                            .fallback => return result(input_read, output_written, .need_output),
                            .counter_fallback => {
                                // With no fresh output the normalized history
                                // can enter compact decoding in this same step,
                                // including an EOB at the counter boundary.
                                if (output_written == 0) continue;
                                return result(input_read, output_written, .need_output);
                            },
                            // End the raw step at the semantic block boundary. Its
                            // delivered bytes are already the retained history;
                            // starting a compact block with the same step-local
                            // output would count that prefix twice as match history.
                            .block_end => return result(input_read, output_written, .need_output),
                            .done => {
                                if (input_read != input.len and !self.options.allow_trailing_data)
                                    return self.fail(.done, error.TrailingData);
                                return result(input_read, output_written, .done);
                            },
                        }
                    },
                    .symbols => {
                        switch (try self.decodeSymbolRun(input, output, &input_read, &output_written)) {
                            .need_input => return result(input_read, output_written, .need_input),
                            .need_output => return result(input_read, output_written, .need_output),
                            .block_end, .done => continue,
                        }
                    },
                    .length_extra => {
                        const extra = (try self.readBits(input, &input_read, self.length_extra_bits)) orelse return result(input_read, output_written, .need_input);
                        self.match_len = self.length_base + extra;
                        self.phase = .distance_symbol;
                    },
                    .distance_symbol => {
                        if (self.match_len == 0) self.match_len = self.length_base;
                        const symbol = (try self.readDistanceSymbol(input, &input_read)) orelse return result(input_read, output_written, .need_input);
                        const distance = distanceBaseAndBitsForFormat(format, symbol) orelse return self.fail(.distance_symbol, error.InvalidHuffmanCode);
                        self.match_distance = distance.base;
                        self.length_extra_bits = distance.bits;
                        self.phase = if (distance.bits == 0) .match_copy else .distance_extra;
                        if (self.phase == .match_copy) try self.beginMatchAt(output_written);
                    },
                    .distance_extra => {
                        const extra = (try self.readBits(input, &input_read, self.length_extra_bits)) orelse return result(input_read, output_written, .need_input);
                        self.match_distance += extra;
                        try self.beginMatchAt(output_written);
                        self.phase = .match_copy;
                    },
                    .match_copy => {
                        // A previous call may have filled the caller's output exactly
                        // while copying the final match byte. Advance to the symbol
                        // phase before checking output space so a zero-length drain can
                        // still consume an already-buffered EOB.
                        if (self.match_remaining == 0) {
                            self.match_len = 0;
                            self.phase = .symbols;
                            continue;
                        }
                        if (output_written == output.len) return result(input_read, output_written, .need_output);
                        const n = stream_count.bounded(std.math.maxInt(Count) - self.total_output, @min(self.match_remaining, output.len - output_written));
                        if (n == 0) return self.fail(.match_copy, error.IntegerOverflow);
                        const next_output = try self.nextOutput(self.total_output, n, .match_copy);
                        self.copyMatchSpanAt(
                            output,
                            output_written,
                            n,
                            self.history.len,
                            self.history_pos,
                            self.history_len,
                            self.match_distance,
                        );
                        output_written += n;
                        self.total_output = next_output;
                        self.match_remaining -= n;
                        if (self.match_remaining == 0) {
                            self.match_len = 0;
                            self.phase = .symbols;
                        }
                    },
                    .done => {
                        // A partial final byte belongs to the stream as padding; bytes
                        // staged by the same input call have already been accounted for.
                        if (input_read != input.len and !self.options.allow_trailing_data)
                            return self.fail(.done, error.TrailingData);
                        if (self.options.expected_output_len) |expected| {
                            if (self.total_output != expected) return self.fail(.done, error.SizeMismatch);
                        }
                        return result(input_read, output_written, .done);
                    },
                }
            }
            return result(input_read, output_written, .need_output);
        }

        const SemanticRunStatus = enum { need_input, need_output, fallback, counter_fallback, block_end, done };

        fn admitStep(self: *const Self, input: []const u8, output: []u8) Error!bool {
            const writers = if (self.input_finished or self.phase == .done)
                output[0..0]
            else
                step_borrows.outputPrefix(self.options, self.total_output, output);
            return step_borrows.rawAdmission(std.mem.asBytes(self), self, input, writers);
        }

        /// Dynamic header work is paid once per block. Keep canonical tree
        /// preparation outside the symbol-heavy step so table building and
        /// semantic admission do not enlarge its hot instruction footprint.
        noinline fn prepareDynamicTables(self: *Self, contiguous_input_len: usize, semantic_admitted: bool) Error!bool {
            if (self.dynamic_literal_lengths[256] == 0) return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
            if (!validDynamicAlphabet(self.dynamic_literal_lengths[0..self.dynamic_hlit]) or
                !validDynamicAlphabet(self.dynamic_distance_lengths[0..self.dynamic_hdist]))
                return self.fail(.dynamic_lengths, error.InvalidDynamicBlockHeader);
            self.dynamic_literal_table = huffman.HuffmanTable(286).init(self.dynamic_literal_lengths[0..self.dynamic_hlit]) catch |err| return self.fail(.dynamic_lengths, err);
            self.dynamic_distance_table = huffman.HuffmanTable(format.distance_symbol_count).init(self.dynamic_distance_lengths[0..self.dynamic_hdist]) catch |err| return self.fail(.dynamic_lengths, err);
            if (comptime supports_semantic_window) {
                if (semantic_admitted and self.semantic_decoder != null and
                    !self.options.stop_at_output_limit and
                    self.options.max_distance == format.window_len and
                    contiguous_input_len >= semantic_min_contiguous_input and
                    stream_count.bounded(std.math.maxInt(Count) - self.total_input, contiguous_input_len) == contiguous_input_len and
                    std.math.maxInt(Count) - self.total_output >= format.window_len and
                    self.semantic_scratch.len >= recommended_history_len and
                    self.semantic_decoder.?.init(
                        &self.dynamic_literal_table,
                        &self.dynamic_distance_table,
                    ))
                {
                    return true;
                }
            }
            self.buildDynamicLookups();
            return false;
        }

        /// The compact run loop needs its own primary lookups, but a block
        /// handled entirely by the semantic workspace does not. Build them at
        /// compact admission or transactional fallback, after the canonical
        /// tables have already validated both dynamic alphabets.
        inline fn buildDynamicLookups(self: *Self) void {
            compact_tables.buildLookupFromTable(11, 286, &self.dynamic_literal_lookup, &self.dynamic_literal_table);
            compact_tables.buildLookupFromTable(10, format.distance_symbol_count, &self.dynamic_distance_lookup, &self.dynamic_distance_table);
        }

        /// Begin one private generation from compact history. History geometry
        /// is isolated from the controller's input/output transaction.
        fn beginSemanticBlock(self: *Self) Error!void {
            std.debug.assert(supports_semantic_window);
            std.debug.assert(self.semantic_scratch.len >= recommended_history_len);
            semantic_state.begin(mode, observed, self) catch |err|
                return self.fail(.dynamic_lengths, err);
        }

        fn stepSemanticBlock(
            self: *Self,
            input: []const u8,
            output: []u8,
            input_read: *usize,
            output_written: *usize,
            history_record_start: *usize,
        ) Error!SemanticRunStatus {
            std.debug.assert(supports_semantic_window);
            while (true) {
                if (self.semantic_delivered != self.semantic_generated_end) {
                    const pending = self.semantic_generated_end - self.semantic_delivered;
                    const available = @min(pending, output.len - output_written.*);
                    const n = stream_count.bounded(std.math.maxInt(Count) - self.total_output, available);
                    if (available != 0 and n == 0)
                        return self.fail(.fast_dynamic_block, error.IntegerOverflow);
                    if (n != 0) {
                        const next_output = try self.nextOutput(self.total_output, n, .fast_dynamic_block);
                        const window = semantic_state.window(self, self.semantic_generated_end);
                        if (observed) {
                            self.semantic_work.delivered_bytes +|= @intCast(n);
                            if (window.physical(self.semantic_delivered) + n > 65536)
                                self.semantic_work.drain_wraps +|= 1;
                        }
                        window.drain(self.semantic_delivered, output[output_written.*..][0..n]);
                        self.semantic_delivered += n;
                        output_written.* += n;
                        self.total_output = next_output;
                        // These bytes already live in the semantic history
                        // window; the ordinary step-end ring recorder must not
                        // append them a second time.
                        history_record_start.* = output_written.*;
                    }
                    if (n != available) return self.fail(.fast_dynamic_block, error.IntegerOverflow);
                    if (self.semantic_delivered != self.semantic_generated_end)
                        return .need_output;
                }

                if (self.semantic_end_of_block) {
                    if (self.options.expected_output_len) |expected| {
                        if (self.final_block and self.total_output != expected)
                            return self.fail(.fast_dynamic_block, error.SizeMismatch);
                    }
                    const completed = stream_count.addLocal(self.semantic_blocks_completed, 1) catch |err|
                        return self.fail(.fast_dynamic_block, err);
                    self.retainSemanticTail();
                    semantic_state.normalize(mode, observed, self);
                    self.semantic_end_of_block = false;
                    self.semantic_blocks_completed = completed;
                    self.phase = if (self.final_block) .done else .block_header;
                    return if (self.phase == .done) .done else .block_end;
                }

                // A full generated window has been delivered. Retain only the
                // last RFC window before producing the next one.
                if (self.semantic_generated_end != self.semantic_prefix_len)
                    self.retainSemanticTail();

                // Semantic decoding stages input and whole private output
                // generations. Near a counter boundary use the compact route
                // so only required bytes and writable output are committed.
                const available_input = input.len - input_read.*;
                if (stream_count.bounded(std.math.maxInt(Count) - self.total_input, available_input) != available_input or
                    std.math.maxInt(Count) - self.total_output < format.window_len)
                {
                    semantic_state.normalize(mode, observed, self);
                    self.buildDynamicLookups();
                    self.phase = .symbols;
                    return .counter_fallback;
                }

                const remaining = self.semanticRemainingOutput();
                const output_end = self.semantic_prefix_len + @min(format.window_len, remaining);
                var reader = bitstream.BufferedBitReader.init(input[input_read.*..]);
                reader.bit_buffer = self.bit_buffer;
                reader.bit_count = self.bit_count;

                const window = semantic_state.window(self, output_end);
                var attempted_end: usize = self.semantic_prefix_len;
                const decoded = (if (observed)
                    rolling_decoder.decodeObserved(semantic.RollingStrategy, &reader, window, self.semantic_decoder.?, &attempted_end)
                else if (mode == .rolling)
                    rolling_decoder.decode(semantic.RollingStrategy, &reader, window, self.semantic_decoder.?)
                else
                    semantic.decodeDynamicBlockIntoWindow(&reader, self.semantic_scratch[0..output_end], self.semantic_prefix_len, self.semantic_decoder.?)) catch |err| switch (err) {
                    // The semantic loop is output-resumable. If this call does
                    // not contain enough compressed bytes, discard its private
                    // speculative window and finish the block through the
                    // established byte-progressive symbol state machine.
                    error.TruncatedFrame,
                    error.InvalidHuffmanCode,
                    error.InvalidMatch,
                    => {
                        if (observed) self.semantic_work.discarded_bytes +|= @intCast(attempted_end - self.semantic_prefix_len);
                        semantic_state.normalize(mode, observed, self);
                        self.buildDynamicLookups();
                        self.phase = .symbols;
                        return .fallback;
                    },
                    else => return self.fail(.fast_dynamic_block, err),
                };

                rewindSemanticLookahead(&reader);
                const next_input = stream_count.addLocal(self.total_input, reader.byte_index) catch |err|
                    return self.fail(.fast_dynamic_block, err);
                self.bit_buffer = reader.bit_buffer;
                self.bit_count = @intCast(reader.bit_count);
                input_read.* += reader.byte_index;
                self.total_input = next_input;

                std.debug.assert(decoded.output_written >= self.semantic_prefix_len);
                const generated = decoded.output_written - self.semantic_prefix_len;
                if (observed) {
                    self.semantic_work.generated_bytes +|= @intCast(generated);
                    if (window.physical(self.semantic_prefix_len) + generated > 65536)
                        self.semantic_work.generation_wraps +|= 1;
                }
                if (generated == 0 and decoded.status == .need_output) {
                    if (self.options.stop_at_output_limit) return .need_output;
                    if (self.total_output >= self.options.max_output_len)
                        return self.fail(.fast_dynamic_block, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |expected| {
                        if (self.total_output >= expected)
                            return self.fail(.fast_dynamic_block, error.SizeMismatch);
                    }
                    return self.fail(.fast_dynamic_block, error.OutputLimitExceeded);
                }
                self.semantic_generated_end = decoded.output_written;
                self.semantic_delivered = self.semantic_prefix_len;
                self.semantic_end_of_block = decoded.status == .end_of_block;
            }
        }

        fn semanticRemainingOutput(self: *const Self) usize {
            var remaining = self.options.max_output_len -| self.total_output;
            if (self.options.expected_output_len) |expected|
                remaining = @min(remaining, expected -| self.total_output);
            return stream_count.bounded(remaining, format.window_len);
        }

        fn retainSemanticTail(self: *Self) void {
            semantic_state.retain(mode, observed, self);
        }

        const RunStatus = enum { need_input, need_output, block_end, done };
        /// Packed `base | extra_bits << 16` metadata indexed by length symbol
        /// (257..285) and distance symbol. Small comptime tables replace the
        /// per-match variable-shift arithmetic in the symbol loop.
        const length_meta = lengthMetaTable(format);
        const distance_meta = distanceMetaTable(format);

        /// Decode a run of dynamic/fixed-block symbols with the bit reservoir,
        /// partial-code state and cursors held in locals. The resumable phase
        /// cases above still own every pause (input exhaustion, output full,
        /// partial match copy); this loop only runs while both input and output
        /// can make progress, and writes all shared state back on return.
        fn decodeSymbolRun(
            self: *Self,
            input: []const u8,
            output: []u8,
            input_read: *usize,
            output_written: *usize,
        ) Error!RunStatus {
            var bit_buffer = self.bit_buffer;
            var bit_count = self.bit_count;
            var code = self.code;
            var code_bits = self.code_bits;
            var dynamic_code = self.dynamic_code;
            var dynamic_code_bits = self.dynamic_code_bits;
            var distance_code = self.distance_code;
            var distance_code_bits = self.distance_code_bits;
            var total_output = self.total_output;
            const history_capacity = self.history.len;
            const history_pos = self.history_pos;
            const history_len = self.history_len;
            const start_input = input_read.*;
            const input_before_step = self.total_input - stream_count.fromLocal(start_input);
            // Constrain speculative bulk loads as well as byte-wise reads to
            // input that can still be represented by the logical counter.
            // Offered suffixes remain available to the controller after EOB.
            const input_end = start_input + stream_count.bounded(std.math.maxInt(Count) - self.total_input, input.len - start_input);
            const counted_input = input[0..input_end];
            defer {
                self.total_output = total_output;
                self.bit_buffer = bit_buffer;
                self.bit_count = bit_count;
                self.code = code;
                self.code_bits = code_bits;
                self.dynamic_code = dynamic_code;
                self.dynamic_code_bits = dynamic_code_bits;
                self.distance_code = distance_code;
                self.distance_code_bits = distance_code_bits;
                // A boundary may also return whole lookahead bytes staged by
                // this step's header parser before the run began.
                self.total_input = stream_count.addLocal(input_before_step, input_read.*) catch unreachable;
            }

            while (true) {
                if (output_written.* == output.len and output.len != 0) {
                    rewindStagedLookahead(&bit_buffer, &bit_count, input_read);
                    return .need_output;
                }
                refillBitsBulk(counted_input, input_read, &bit_buffer, &bit_count);
                const symbol = (try self.readLiteralSymbolRun(
                    counted_input,
                    input_read,
                    &bit_buffer,
                    &bit_count,
                    &code,
                    &code_bits,
                )) orelse return self.runNeedsInput(counted_input.len != input.len);
                if (symbol < 256) {
                    if (output_written.* == output.len) {
                        // A decoded literal cannot be committed without caller
                        // space. Preserve it as a one-symbol continuation.
                        code = @intCast(symbol);
                        code_bits = 15;
                        rewindStagedLookahead(&bit_buffer, &bit_count, input_read);
                        return .need_output;
                    }
                    const next_output = try self.nextOutput(total_output, 1, .symbols);
                    if (total_output >= self.options.max_output_len) return self.fail(.symbols, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |expected| {
                        if (total_output >= expected) return self.fail(.symbols, error.SizeMismatch);
                    }
                    output[output_written.*] = @intCast(symbol);
                    output_written.* += 1;
                    total_output = next_output;
                    // Try one adjacent literal without re-entering the loop.
                    // This pays off on literal runs and costs only a table
                    // load plus a predictable miss on match-heavy streams.
                    if (output_written.* < output.len) {
                        const next_entry: u16 = if (self.dynamic_block) blk: {
                            if (bit_count < 11) break :blk 0;
                            break :blk self.dynamic_literal_lookup[@intCast(bit_buffer & 0x7ff)];
                        } else blk: {
                            if (bit_count < 9) break :blk 0;
                            break :blk fixed_lookup[@intCast(bit_buffer & 0x1ff)];
                        };
                        if (next_entry != 0) {
                            const next_bits: u6 = @intCast(next_entry & 0x0f);
                            const next_symbol = (next_entry >> 4) - 1;
                            if (next_symbol < 256 and bit_count >= next_bits and
                                total_output < self.options.max_output_len and
                                (self.options.expected_output_len == null or total_output < self.options.expected_output_len.?))
                            {
                                const adjacent_output = try self.nextOutput(total_output, 1, .symbols);
                                bit_buffer >>= next_bits;
                                bit_count -= next_bits;
                                output[output_written.*] = @intCast(next_symbol);
                                output_written.* += 1;
                                total_output = adjacent_output;
                            }
                        }
                    }
                    continue;
                }
                if (symbol == 256) {
                    self.phase = if (self.final_block) .done else .block_header;
                    rewindStagedLookahead(&bit_buffer, &bit_count, input_read);
                    if (self.phase == .done) {
                        if (self.options.expected_output_len) |expected| {
                            if (total_output != expected) return self.fail(.done, error.SizeMismatch);
                        }
                        return .done;
                    }
                    return .block_end;
                }
                if (symbol > 285) return self.fail(.symbols, error.InvalidHuffmanCode);
                const length_meta_entry = length_meta[symbol - 257];
                const length_base: usize = @intCast(length_meta_entry & 0xffff);
                const length_extra_bits: u6 = @intCast(length_meta_entry >> 16);
                self.length_base = length_base;
                self.length_extra_bits = length_extra_bits;
                self.match_len = length_base;
                if (length_extra_bits != 0) {
                    const extra = readBitsLocal(counted_input, input_read, &bit_buffer, &bit_count, length_extra_bits) orelse {
                        self.phase = .length_extra;
                        return self.runNeedsInput(counted_input.len != input.len);
                    };
                    self.match_len = length_base + extra;
                }
                const distance_symbol = (try self.readDistanceSymbolRun(
                    counted_input,
                    input_read,
                    &bit_buffer,
                    &bit_count,
                    &dynamic_code,
                    &dynamic_code_bits,
                    &distance_code,
                    &distance_code_bits,
                )) orelse {
                    self.phase = .distance_symbol;
                    return self.runNeedsInput(counted_input.len != input.len);
                };
                if (distance_symbol >= format.distance_symbol_count) return self.fail(.distance_symbol, error.InvalidHuffmanCode);
                const distance_meta_entry = distance_meta[distance_symbol];
                const distance_base: usize = @intCast(distance_meta_entry & 0xffff);
                const distance_extra_bits: u6 = @intCast(distance_meta_entry >> 16);
                self.match_distance = distance_base;
                self.length_extra_bits = distance_extra_bits;
                if (distance_extra_bits != 0) {
                    const extra = readBitsLocal(counted_input, input_read, &bit_buffer, &bit_count, distance_extra_bits) orelse {
                        self.phase = .distance_extra;
                        return self.runNeedsInput(counted_input.len != input.len);
                    };
                    self.match_distance += extra;
                }
                try self.beginMatchWith(history_capacity, history_len, output_written.*, total_output);
                self.phase = .match_copy;
                if (output_written.* == output.len) {
                    rewindStagedLookahead(&bit_buffer, &bit_count, input_read);
                    return .need_output;
                }
                const n = stream_count.bounded(std.math.maxInt(Count) - total_output, @min(self.match_remaining, output.len - output_written.*));
                if (n == 0) return self.fail(.match_copy, error.IntegerOverflow);
                const next_output = try self.nextOutput(total_output, n, .match_copy);
                self.copyMatchSpanAt(
                    output,
                    output_written.*,
                    n,
                    history_capacity,
                    history_pos,
                    history_len,
                    self.match_distance,
                );
                output_written.* += n;
                total_output = next_output;
                self.match_remaining -= n;
                if (self.match_remaining != 0) {
                    rewindStagedLookahead(&bit_buffer, &bit_count, input_read);
                    if (total_output == std.math.maxInt(Count) and output_written.* != output.len)
                        return self.fail(.match_copy, error.IntegerOverflow);
                    return .need_output;
                }
                self.match_len = 0;
                self.phase = .symbols;
            }
        }

        fn runNeedsInput(self: *Self, counter_bound: bool) Error!RunStatus {
            return if (counter_bound) self.fail(self.phase, error.IntegerOverflow) else .need_input;
        }

        fn readLiteralSymbolRun(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            bit_buffer: *u64,
            bit_count: *u6,
            code: *u16,
            code_bits: *u4,
        ) Error!?u16 {
            if (code_bits.* == 15) {
                const symbol = code.*;
                code.* = 0;
                code_bits.* = 0;
                return symbol;
            }
            if (!self.dynamic_block) {
                return lookupSymbolLocal(input, input_read, 9, &fixed_lookup, bit_buffer, bit_count);
            }
            if (code_bits.* == 0) {
                if (lookupSymbolLocal(input, input_read, 11, &self.dynamic_literal_lookup, bit_buffer, bit_count)) |symbol|
                    return symbol;
                if (bit_count.* < 11 and input_read.* == input.len) return null;
            }
            while (code_bits.* < 15) {
                const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                code.* |= @as(u16, @intCast(bit)) << code_bits.*;
                code_bits.* += 1;
                if (tableSymbol(286, &self.dynamic_literal_table, code.*, code_bits.*)) |symbol| {
                    code.* = 0;
                    code_bits.* = 0;
                    return symbol;
                }
            }
            return self.fail(.symbols, error.InvalidHuffmanCode);
        }

        fn readDistanceSymbolRun(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            bit_buffer: *u64,
            bit_count: *u6,
            dynamic_code: *u16,
            dynamic_code_bits: *u4,
            distance_code: *u16,
            distance_code_bits: *u3,
        ) Error!?usize {
            if (!self.dynamic_block) {
                while (distance_code_bits.* < 5) {
                    const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                    distance_code.* |= @as(u16, @intCast(bit)) << distance_code_bits.*;
                    distance_code_bits.* += 1;
                }
                const symbol: usize = @bitReverse(@as(u5, @truncate(distance_code.*)));
                distance_code.* = 0;
                distance_code_bits.* = 0;
                return symbol;
            }
            if (dynamic_code_bits.* == 0) {
                if (lookupSymbolLocal(input, input_read, 10, &self.dynamic_distance_lookup, bit_buffer, bit_count)) |symbol|
                    return symbol;
                if (bit_count.* < 10 and input_read.* == input.len) return null;
            }
            while (dynamic_code_bits.* < 15) {
                const bit = readBitsLocal(input, input_read, bit_buffer, bit_count, 1) orelse return null;
                dynamic_code.* |= @as(u16, @intCast(bit)) << dynamic_code_bits.*;
                dynamic_code_bits.* += 1;
                if (tableSymbol(format.distance_symbol_count, &self.dynamic_distance_table, dynamic_code.*, dynamic_code_bits.*)) |symbol| {
                    dynamic_code.* = 0;
                    dynamic_code_bits.* = 0;
                    return symbol;
                }
            }
            return self.fail(.distance_symbol, error.InvalidHuffmanCode);
        }

        fn readFixedSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (self.code_bits == 15) {
                const symbol = self.code;
                self.code = 0;
                self.code_bits = 0;
                return symbol;
            }
            return self.readLookupSymbol(input, input_read, 9, &fixed_lookup);
        }
        fn readLiteralSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (!self.dynamic_block) return self.readFixedSymbol(input, input_read);
            if (self.code_bits == 15) {
                const symbol = self.code;
                self.code = 0;
                self.code_bits = 0;
                return symbol;
            }
            if (self.code_bits == 0) {
                if (try self.readLookupSymbol(input, input_read, 11, &self.dynamic_literal_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 11 and input_read.* == input.len) return null;
            }
            while (self.code_bits < 15) {
                const bit = (try self.readBits(input, input_read, 1)) orelse return null;
                self.code |= @as(u16, @intCast(bit)) << self.code_bits;
                self.code_bits += 1;
                if (tableSymbol(286, &self.dynamic_literal_table, self.code, self.code_bits)) |symbol| {
                    self.code = 0;
                    self.code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.symbols, error.InvalidHuffmanCode);
        }
        /// Append the bytes produced by one `step` call to the history ring.
        /// Matches inside the step read earlier step output from the caller's
        /// buffer, so the ring only needs one bulk update per call.
        fn recordStepOutput(self: *Self, bytes: []const u8) void {
            std.debug.assert(bytes.len != 0);
            const capacity = self.history.len;
            if (capacity == 0) return;
            if (bytes.len <= capacity) {
                const destination = self.history_pos;
                const first = @min(bytes.len, capacity - destination);
                @memcpy(self.history[destination..][0..first], bytes[0..first]);
                if (first != bytes.len)
                    @memcpy(self.history[0 .. bytes.len - first], bytes[first..]);
                const next = destination + bytes.len;
                self.history_pos = if (next >= capacity) next - capacity else next;
                self.history_len = @min(self.history_len + bytes.len, capacity);
                return;
            }
            const retained = bytes[bytes.len - capacity ..];
            const destination = (self.history_pos + bytes.len - capacity) % capacity;
            const first = @min(retained.len, capacity - destination);
            @memcpy(self.history[destination..][0..first], retained[0..first]);
            if (first != retained.len)
                @memcpy(self.history[0 .. retained.len - first], retained[first..]);
            self.history_pos = (self.history_pos + bytes.len) % capacity;
            self.history_len = capacity;
        }

        /// Copy one match span from the combined history: the pre-step ring
        /// followed by the bytes this step has already written to `step_output`.
        /// `span_start` is the step-local output offset of the span.
        inline fn copyMatchSpanAt(
            self: *Self,
            step_output: []u8,
            span_start: usize,
            span_len: usize,
            history_capacity: usize,
            history_pos: usize,
            history_len: usize,
            match_distance: usize,
        ) void {
            std.debug.assert(span_len != 0);
            std.debug.assert(match_distance != 0);
            std.debug.assert(match_distance <= span_start or match_distance - span_start <= history_len);
            const dest = step_output[span_start..][0..span_len];
            if (match_distance <= span_start) {
                const source = span_start - match_distance;
                if (match_distance >= span_len) {
                    @memcpy(dest, step_output[source..][0..span_len]);
                } else {
                    std.mem.copyForwards(u8, dest, step_output[source..][0..span_len]);
                }
                return;
            }
            // The source starts in the pre-step ring.
            const ring_bytes = @min(span_len, match_distance - span_start);
            var source = history_pos + history_capacity - (match_distance - span_start);
            if (source >= history_capacity) source -= history_capacity;
            const first = @min(ring_bytes, history_capacity - source);
            @memcpy(dest[0..first], self.history[source..][0..first]);
            if (first != ring_bytes)
                @memcpy(dest[first..ring_bytes], self.history[0 .. ring_bytes - first]);
            var written = ring_bytes;
            if (written == span_len) return;
            const prefix_bytes = @min(span_len - written, span_start);
            if (prefix_bytes != 0) {
                std.mem.copyForwards(u8, dest[written..][0..prefix_bytes], step_output[0..prefix_bytes]);
                written += prefix_bytes;
            }
            if (written == span_len) return;
            // `written` is now `match_distance`; repeat the match pattern.
            while (written < span_len) {
                const n = @min(written, span_len - written);
                std.mem.copyForwards(u8, dest[written..][0..n], dest[0..n]);
                written += n;
            }
        }

        fn beginMatchWith(
            self: *Self,
            history_capacity: usize,
            history_len: usize,
            produced: usize,
            total_output: Count,
        ) Error!void {
            if (history_capacity == 0) return self.fail(.match_copy, error.OutputTooSmall);
            if (self.match_distance == 0 or (self.match_distance > produced and self.match_distance - produced > history_len)) return self.fail(.match_copy, error.InvalidMatch);
            if (self.match_distance > self.options.max_distance) return self.fail(.match_copy, error.InvalidMatch);
            if (!self.options.stop_at_output_limit or self.options.max_output_len == std.math.maxInt(Count))
                _ = try self.nextOutput(total_output, self.match_len, .match_copy);
            if (!self.options.stop_at_output_limit and
                (total_output > self.options.max_output_len or self.match_len > self.options.max_output_len - total_output))
                return self.fail(.match_copy, error.OutputLimitExceeded);
            if (self.options.expected_output_len) |expected| {
                if (total_output > expected or self.match_len > expected - total_output) return self.fail(.match_copy, error.SizeMismatch);
            }
            self.match_remaining = self.match_len;
        }

        fn nextOutput(self: *Self, current: Count, amount: usize, phase: Phase) Error!Count {
            return stream_count.addLocal(current, amount) catch |err| self.fail(phase, err);
        }

        fn beginMatchAt(self: *Self, produced: usize) Error!void {
            return self.beginMatchWith(
                self.history.len,
                self.history_len,
                produced,
                self.total_output,
            );
        }

        fn alignStoredHeader(self: *Self) void {
            const drop: u6 = self.bit_count % 8;
            self.bit_buffer >>= drop;
            self.bit_count -= drop;
        }
        fn completeBlock(self: *Self) void {
            self.phase = if (self.final_block) .done else .block_header;
        }
        fn readFixedDistanceSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?usize {
            while (self.distance_code_bits < 5) {
                const bit = (try self.readBits(input, input_read, 1)) orelse return null;
                self.distance_code |= @as(u16, @intCast(bit)) << self.distance_code_bits;
                self.distance_code_bits += 1;
            }
            const symbol: usize = @bitReverse(@as(u5, @truncate(self.distance_code)));
            self.distance_code = 0;
            self.distance_code_bits = 0;
            return symbol;
        }
        fn readDistanceSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?usize {
            if (!self.dynamic_block) return self.readFixedDistanceSymbol(input, input_read);
            if (self.dynamic_code_bits == 0) {
                if (try self.readLookupSymbol(input, input_read, 10, &self.dynamic_distance_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 10 and input_read.* == input.len) return null;
            }
            while (self.dynamic_code_bits < 15) {
                const bit = (try self.readBits(input, input_read, 1)) orelse return null;
                self.dynamic_code |= @as(u16, @intCast(bit)) << self.dynamic_code_bits;
                self.dynamic_code_bits += 1;
                if (tableSymbol(format.distance_symbol_count, &self.dynamic_distance_table, self.dynamic_code, self.dynamic_code_bits)) |symbol| {
                    self.dynamic_code = 0;
                    self.dynamic_code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.distance_symbol, error.InvalidHuffmanCode);
        }
        fn readCodeLengthSymbol(self: *Self, input: []const u8, input_read: *usize) Error!?u16 {
            if (self.dynamic_code_bits == 0) {
                if (try self.readLookupSymbol(input, input_read, 7, &self.dynamic_code_lookup)) |symbol|
                    return symbol;
                if (self.bit_count < 7 and input_read.* == input.len) return null;
            }
            while (self.dynamic_code_bits < 7) {
                const bit = (try self.readBits(input, input_read, 1)) orelse return null;
                self.dynamic_code |= @as(u16, @intCast(bit)) << self.dynamic_code_bits;
                self.dynamic_code_bits += 1;
                if (canonicalSymbol(self.dynamic_code_lengths[0..], self.dynamic_code, self.dynamic_code_bits)) |symbol| {
                    self.dynamic_code = 0;
                    self.dynamic_code_bits = 0;
                    return symbol;
                }
            }
            return self.fail(.dynamic_lengths, error.InvalidHuffmanCode);
        }
        fn readLookupSymbol(
            self: *Self,
            input: []const u8,
            input_read: *usize,
            comptime lookup_bits: u6,
            lookup: *const [@as(usize, 1) << lookup_bits]u16,
        ) Error!?u16 {
            const mask = (@as(u64, 1) << lookup_bits) - 1;
            while (true) {
                const lookup_entry = lookup[@intCast(self.bit_buffer & mask)];
                if (lookup_entry != 0) {
                    const bits: u6 = @intCast(lookup_entry & 0x0f);
                    if (self.bit_count >= bits) {
                        self.bit_buffer >>= bits;
                        self.bit_count -= bits;
                        return (lookup_entry >> 4) - 1;
                    }
                }
                if (self.bit_count >= lookup_bits or input_read.* == input.len)
                    return null;
                const next_input = stream_count.addLocal(self.total_input, 1) catch |err|
                    return self.fail(self.phase, err);
                self.bit_buffer |= @as(u64, input[input_read.*]) << self.bit_count;
                self.bit_count += 8;
                input_read.* += 1;
                self.total_input = next_input;
            }
        }
        fn setDynamicLength(self: *Self, value: u4) void {
            if (self.dynamic_length_pos < self.dynamic_hlit) {
                self.dynamic_literal_lengths[self.dynamic_length_pos] = value;
            } else {
                self.dynamic_distance_lengths[self.dynamic_length_pos - self.dynamic_hlit] = value;
            }
        }
        fn readBits(self: *Self, input: []const u8, input_read: *usize, count: u6) Error!?usize {
            while (self.bit_count < count) {
                if (input_read.* == input.len) return null;
                const next_input = stream_count.addLocal(self.total_input, 1) catch |err|
                    return self.fail(self.phase, err);
                self.bit_buffer |= @as(u64, input[input_read.*]) << self.bit_count;
                self.bit_count += 8;
                input_read.* += 1;
                self.total_input = next_input;
            }
            const mask = (@as(u64, 1) << count) - 1;
            const value: usize = @intCast(self.bit_buffer & mask);
            self.bit_buffer >>= count;
            self.bit_count -= count;
            return value;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

const fixed_table = blk: {
    @setEvalBranchQuota(20_000);
    break :blk buildFixedTable(fixedLengths());
};

const fixed_lookup = blk: {
    var lookup: [1 << 9]u16 = @splat(0);
    for (fixed_table) |entry| {
        const lookup_entry = ((entry.symbol + 1) << 4) | entry.bits;
        const fill = @as(usize, 1) << @intCast(9 - entry.bits);
        for (0..fill) |suffix|
            lookup[entry.code | (suffix << entry.bits)] = lookup_entry;
    }
    break :blk lookup;
};

const FixedEntry = struct { symbol: u16, code: u16, bits: u4 };

fn fixedLengths() [288]u4 {
    var lengths: [288]u4 = undefined;
    for (0..144) |i| lengths[i] = 8;
    for (144..256) |i| lengths[i] = 9;
    for (256..280) |i| lengths[i] = 7;
    for (280..288) |i| lengths[i] = 8;
    return lengths;
}

fn buildFixedTable(lengths: [288]u4) [288]FixedEntry {
    var counts: [16]u16 = @splat(0);
    for (lengths) |bits| counts[bits] += 1;
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    var out: [288]FixedEntry = undefined;
    for (lengths, 0..) |bits, symbol| {
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        out[symbol] = .{ .symbol = @intCast(symbol), .code = @bitReverse(next[bits]) >> shift, .bits = bits };
        next[bits] += 1;
    }
    return out;
}

const BaseBits = struct { base: usize, bits: u6 };

fn lengthBaseAndBitsForFormat(comptime format: Format, symbol: u16) ?BaseBits {
    if (symbol < 257 or symbol > 285) return null;
    if (symbol <= 264) return .{ .base = symbol - 254, .bits = 0 };
    if (symbol == 285) return if (format.extended_length_285)
        .{ .base = 3, .bits = 16 }
    else
        .{ .base = 258, .bits = 0 };
    const bases = [_]usize{ 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227 };
    const bits = [_]u6{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
    const index: usize = symbol - 265;
    return .{ .base = bases[index], .bits = bits[index] };
}

fn distanceBaseAndBitsForFormat(comptime format: Format, symbol: usize) ?BaseBits {
    if (symbol >= format.distance_symbol_count) return null;
    if (symbol < 4) return .{ .base = symbol + 1, .bits = 0 };
    const extra_bits: u6 = @intCast(symbol / 2 - 1);
    const base = ((@as(usize, 2) + (symbol & 1)) << @intCast(extra_bits)) + 1;
    return .{ .base = base, .bits = extra_bits };
}

fn lengthMetaTable(comptime format: Format) [29]u32 {
    var out: [29]u32 = undefined;
    for (0..29) |index| {
        const meta = lengthBaseAndBitsForFormat(format, @intCast(257 + index)).?;
        out[index] = @as(u32, @intCast(meta.base)) | (@as(u32, @intCast(meta.bits)) << 16);
    }
    return out;
}

fn distanceMetaTable(comptime format: Format) [format.distance_symbol_count]u32 {
    var out: [format.distance_symbol_count]u32 = undefined;
    for (0..format.distance_symbol_count) |symbol| {
        const meta = distanceBaseAndBitsForFormat(format, symbol).?;
        out[symbol] = @as(u32, @intCast(meta.base)) | (@as(u32, @intCast(meta.bits)) << 16);
    }
    return out;
}

const code_length_order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

/// Stage as many whole bytes as the reservoir can hold in one unaligned
/// 8-byte load. The symbol loop only calls this when eight input bytes are
/// available, so the byte-at-a-time helpers handle the tail.
inline fn refillBitsBulk(
    input: []const u8,
    input_read: *usize,
    bit_buffer: *u64,
    bit_count: *u6,
) void {
    if (bit_count.* >= 32 or input_read.* + 8 > input.len) return;
    const stage = (63 - bit_count.*) / 8;
    const staged_bits = stage * 8;
    const staged = std.mem.readInt(u64, input[input_read.*..][0..8], .little) << bit_count.*;
    // Discard the lookahead bytes above the staged width so a later refill
    // cannot inherit stale bits from this load.
    const keep = (@as(u64, 1) << @intCast(bit_count.* + staged_bits)) - 1;
    bit_buffer.* = (bit_buffer.* | staged) & keep;
    bit_count.* += staged_bits;
    input_read.* += stage;
}

/// Drop complete unconsumed lookahead bytes before a pause or block boundary
/// and report them as unread, so the caller re-supplies them and progress stays
/// exact. Only safe when no incomplete token depends on those bytes.
inline fn rewindStagedLookahead(bit_buffer: *u64, bit_count: *u6, input_read: *usize) void {
    // Only the most recently staged bytes belong to this call. Older whole
    // bytes were already reported by a previous call and must stay resident.
    const rewind: usize = @min(@as(usize, bit_count.* / 8), input_read.*);
    if (rewind == 0) return;
    bit_count.* -= @intCast(rewind * 8);
    bit_buffer.* &= (@as(u64, 1) << bit_count.*) - 1;
    input_read.* -= rewind;
}

/// BufferedBitReader variant used by the semantic bridge. Only bytes staged
/// from the current caller slice may be returned; older reservoir bytes were
/// already reported by an earlier incremental step.
/// Local-reservoir bit read used by the fused symbol loop. The caller keeps
/// the reservoir in registers and only writes it back at pause boundaries.
inline fn readBitsLocal(
    input: []const u8,
    input_read: *usize,
    bit_buffer: *u64,
    bit_count: *u6,
    count: u6,
) ?usize {
    while (bit_count.* < count) {
        if (input_read.* == input.len) return null;
        bit_buffer.* |= @as(u64, input[input_read.*]) << bit_count.*;
        bit_count.* += 8;
        input_read.* += 1;
    }
    const mask = (@as(u64, 1) << count) - 1;
    const value = bit_buffer.* & mask;
    bit_buffer.* >>= count;
    bit_count.* -= count;
    return @intCast(value);
}

/// Local-reservoir variant of `readLookupSymbol`.
inline fn lookupSymbolLocal(
    input: []const u8,
    input_read: *usize,
    comptime lookup_bits: u6,
    lookup: *const [@as(usize, 1) << lookup_bits]u16,
    bit_buffer: *u64,
    bit_count: *u6,
) ?u16 {
    const mask = (@as(u64, 1) << lookup_bits) - 1;
    while (true) {
        const lookup_entry = lookup[@intCast(bit_buffer.* & mask)];
        if (lookup_entry != 0) {
            const bits: u6 = @intCast(lookup_entry & 0x0f);
            if (bit_count.* >= bits) {
                bit_buffer.* >>= bits;
                bit_count.* -= bits;
                return (lookup_entry >> 4) - 1;
            }
        }
        if (bit_count.* >= lookup_bits or input_read.* == input.len) return null;
        bit_buffer.* |= @as(u64, input[input_read.*]) << bit_count.*;
        bit_count.* += 8;
        input_read.* += 1;
    }
}
