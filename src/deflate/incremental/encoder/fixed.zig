const std = @import("std");
const core = @import("../../../core.zig");
const rolling_hash = @import("match_finder/rolling_hash.zig");

/// Incremental block-planned raw-DEFLATE encoder. Blocks share retained 32 KiB
/// history and hash-parser levels additionally share a persistent match index;
/// bit packing stays continuous until finish writes BFINAL. The codec adapter
/// chooses fixed-only or stored/fixed/dynamic best emission. Block flush ends
/// the current block without alignment; partial flush adds zlib's ten-bit
/// empty fixed block; sync flush emits an empty stored byte boundary. Full
/// flush additionally starts a new independent match-history segment.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        state: Codec.State = .{},
        match_finder: rolling_hash.Matcher = .{},
        plan_tokens: std.ArrayList(Codec.Token) = .empty,
        plain: std.ArrayList(u8) = .empty,
        history: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        flush_mode: FlushMode = .none,
        flush_boundary: FlushBoundary = .none,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        low_entropy_expanded: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        dictionary: []const u8 = &.{},
        dictionary_available: bool = true,
        active_params: ?Codec.ResolvedParams = null,
        requested_params: ?Codec.ResolvedParams = null,
        params_boundary_pending: bool = false,
        params_change_count: usize = 0,
        stored_only: bool = false,

        const Self = @This();
        const FlushMode = enum { none, block, partial, sync, full };
        const FlushBoundary = enum { none, partial, sync };
        pub const Error = Codec.Error;
        pub const supports_runtime_params = Codec.supports_params;
        pub const MatchFinderSnapshot = rolling_hash.Matcher.Snapshot;
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            buffered_input: usize,
            pending_output: usize,
            pending_bits: u3,
            retained_token_capacity: usize,
            active_params: ?Codec.Params,
            requested_params: ?Codec.Params,
            params_boundary_pending: bool,
            params_change_count: usize,
            stored_only: bool,
            flushing: bool,
            finishing: bool,
            done: bool,
        };
        pub const Options = struct {
            max_input_len: usize = std.math.maxInt(usize),
            block_len: usize = 32 * 1024,
            /// Optional larger bounded buffer for low-entropy input. When the
            /// first block-sized prefix has very low byte diversity, delay the
            /// block boundary up to this cap so dynamic-tree header cost is
            /// amortized. Zero preserves the fixed block_len policy.
            low_entropy_block_len: usize = 0,
            compression: Codec.CompressionOptions = .{},
            /// Enable costed block sizing within `compression.split_options`.
            /// Input buffering remains bounded by that policy's max block size.
            adaptive_blocks: bool = false,
            /// Retain this many bytes past a normal block target so matches that
            /// begin near the boundary can be planned with next-call lookahead.
            /// Flush and finish still publish every accepted byte immediately.
            lookahead_len: usize = 0,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: usize) Self {
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len };
        }
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Options, dictionary: []const u8) Self {
            return .{ .allocator = allocator, .options = options, .dictionary = dictionary };
        }
        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Options, expected_input_len: usize, dictionary: []const u8) Self {
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len, .dictionary = dictionary };
        }
        /// Validate all block-buffer controls without consuming input or
        /// allocating. Adapters that publish an outer header before calling
        /// `step` use this to reject deterministic configuration errors first.
        pub fn validateOptions(options: Options) Error!void {
            _ = try baseBlockTarget(options);
            _ = try maxBufferedInput(options);
        }

        /// Maximum caller input retained for one planned block, excluding the
        /// fixed 32 KiB match history and encoded pending output.
        pub fn maxBufferedInput(options: Options) Error!usize {
            const base = try baseBlockTarget(options);
            const active = if (!options.adaptive_blocks and options.low_entropy_block_len != 0)
                @max(base, options.low_entropy_block_len)
            else
                base;
            return std.math.add(usize, active, options.lookahead_len) catch
                error.IntegerOverflow;
        }
        pub fn deinit(self: *Self) void {
            Codec.deinitState(&self.state, self.allocator);
            self.match_finder.deinit(self.allocator);
            self.plan_tokens.deinit(self.allocator);
            self.plain.deinit(self.allocator);
            self.history.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected = self.expected_input_len;
            Codec.resetState(&self.state);
            self.match_finder.reset();
            self.plan_tokens.clearRetainingCapacity();
            self.plain.clearRetainingCapacity();
            self.history.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.flush_mode = .none;
            self.flush_boundary = .none;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.low_entropy_expanded = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected;
            self.dictionary_available = true;
            self.requested_params = null;
            self.params_boundary_pending = false;
            self.params_change_count = 0;
        }
        /// Reset the stream with caller-supplied raw options. Unlike `reset`,
        /// this explicitly replaces runtime parameter state because the new
        /// compression options do not necessarily correspond to a public
        /// zlib-compatible level and strategy pair.
        pub fn resetWithOptions(self: *Self, options: Options) void {
            self.options = options;
            self.active_params = null;
            self.stored_only = false;
            self.reset();
        }
        /// Reset the stream while changing its pledged input size. Wrapper
        /// encoders use this between independent gzip members.
        pub fn resetExactSize(self: *Self, expected_input_len: usize) void {
            self.expected_input_len = expected_input_len;
            self.reset();
        }
        pub fn resetDictionary(self: *Self, dictionary: []const u8) void {
            self.dictionary = dictionary;
            self.reset();
        }
        pub fn resetExactSizeDictionary(self: *Self, expected_input_len: usize, dictionary: []const u8) void {
            self.expected_input_len = expected_input_len;
            self.dictionary = dictionary;
            self.reset();
        }
        pub fn matchFinderSnapshot(self: *const Self) MatchFinderSnapshot {
            return self.match_finder.snapshot();
        }
        pub fn snapshot(self: *const Self) Snapshot {
            const managed_valid = if (self.active_params) |params|
                self.stored_only == params.stored_only and
                    std.meta.eql(self.options.compression, params.compression)
            else
                true;
            const managed_active = if (managed_valid)
                if (self.active_params) |params| params.params else null
            else
                null;
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .pending_bits = self.state.bit_index,
                .retained_token_capacity = self.plan_tokens.capacity,
                .active_params = managed_active,
                .requested_params = if (managed_valid)
                    if (self.requested_params) |params| params.params else null
                else
                    null,
                .params_boundary_pending = managed_valid and self.params_boundary_pending,
                .params_change_count = self.params_change_count,
                .stored_only = self.stored_only,
                .flushing = self.flush_mode != .none or (managed_valid and self.params_boundary_pending),
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        /// Request zlib-compatible compression parameters for subsequent
        /// input. Changes within one algorithm family and strategy take effect
        /// immediately. Other changes are committed after the already accepted
        /// input has been published as a non-final block. Repeated requests are
        /// idempotent and a newer request replaces an uncommitted one.
        pub fn requestParams(self: *Self, params: Codec.Params) Codec.ParamsError!void {
            if (!Codec.supports_params) return error.UnsupportedOperation;
            if (self.finishing or self.done)
                return error.InvalidEncoderState;

            self.syncExternallyModifiedCompression();
            const resolved = try Codec.resolveParams(params);
            if (self.requested_params) |requested| {
                if (paramsEqual(requested, resolved)) return;
            }
            if (self.active_params) |active| {
                if (paramsEqual(active, resolved)) {
                    self.requested_params = null;
                    self.params_boundary_pending = false;
                    return;
                }
            }
            // With no accepted bytes there is no old-parameter block to
            // terminate, even when reset retained a parameter identity from a
            // prior stream. Match zlib by replacing the active parameters
            // immediately before the first input byte.
            if (self.total_input == 0) {
                self.applyParams(resolved);
                return;
            }
            if (self.active_params) |active| {
                if (active.family == resolved.family and
                    active.params.strategy == resolved.params.strategy)
                {
                    self.applyParams(resolved);
                    return;
                }
            }

            self.requested_params = resolved;
            self.params_boundary_pending = true;
        }
        /// End and publish a non-final block without adding a sync-flush
        /// marker or aligning the bit stream. Match history remains available
        /// to later blocks.
        pub fn blockFlush(self: *Self) void {
            if (!self.finishing and !self.done and self.flush_mode == .none)
                self.flush_mode = .block;
        }
        /// Publish all accepted input and append zlib's ten-bit empty fixed
        /// block without byte-aligning the stream. Match history is retained.
        pub fn partialFlush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .sync or
                self.flush_mode == .full or self.flush_boundary == .sync)
                return;
            if (self.flush_boundary != .partial) self.flush_mode = .partial;
        }
        pub fn flush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .sync or self.flush_mode == .full) return;
            if (self.flush_boundary != .sync) self.flush_mode = .sync;
        }
        pub fn fullFlush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .full) return;
            if (self.flush_boundary == .sync) {
                // A completed sync boundary can be upgraded in place: its wire
                // marker is identical to full flush, so only match history
                // changes. If the marker is still pending, retain the request
                // until all of that output has drained.
                self.resetMatchHistory();
                if (self.flush_mode == .sync) self.flush_mode = .full;
                return;
            }
            self.flush_mode = .full;
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.syncExternallyModifiedCompression();
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_mode != .none or self.params_boundary_pending) and input.len != 0)
                return error.TrailingData;
            const base_block_target = try self.blockTarget();
            const offered_total = std.math.add(usize, self.total_input, input.len) catch return error.IntegerOverflow;
            if (offered_total > self.options.max_input_len) return error.OutputLimitExceeded;

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
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }

                if (self.params_boundary_pending) {
                    if (self.plain.items.len != 0)
                        try self.writeDataBlock(false);
                    const requested = self.requested_params orelse unreachable;
                    self.applyParams(requested);
                    continue;
                }

                const block_target = self.activeBlockTarget(base_block_target);
                const block_capacity = std.math.add(usize, block_target, self.options.lookahead_len) catch return error.IntegerOverflow;
                const room = if (self.plain.items.len < block_capacity)
                    block_capacity - self.plain.items.len
                else
                    0;
                if (self.canWriteDirectBlock(input[input_read..], base_block_target, block_capacity)) {
                    // The complete non-final block already lives contiguously
                    // in caller input. Plan and emit it in place instead of
                    // copying it into `plain`; retainHistory copies the owned
                    // window before this call returns. Low-entropy prefixes
                    // still take the buffered coalescing path.
                    const block = input[input_read..][0..block_capacity];
                    try self.writeDirectBlock(block);
                    self.flush_boundary = .none;
                    input_read += block.len;
                    self.total_input += block.len;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                    continue;
                }
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    self.flush_boundary = .none;
                    input_read += n;
                    self.total_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                const active_capacity = std.math.add(usize, self.activeBlockTarget(base_block_target), self.options.lookahead_len) catch return error.IntegerOverflow;
                if (self.plain.items.len >= active_capacity and
                    (input_read < input.len or self.options.lookahead_len != 0))
                {
                    try self.writeDataBlock(false);
                    continue;
                }
                if (self.flush_mode != .none) {
                    if (self.plain.items.len != 0) {
                        try self.writeDataBlock(false);
                        continue;
                    }
                    if (self.flush_mode == .block) {
                        self.flush_mode = .none;
                        continue;
                    }
                    if (self.flush_mode == .partial) {
                        if (self.flush_boundary == .none) {
                            try Codec.writePartialFlush(self.allocator, &self.pending, &self.state);
                            self.flush_boundary = .partial;
                            continue;
                        }
                        self.flush_mode = .none;
                        continue;
                    }
                    if (self.flush_boundary != .sync) {
                        try Codec.writeSyncFlush(self.allocator, &self.pending, &self.state);
                        self.flush_boundary = .sync;
                        if (self.flush_mode == .full) self.resetMatchHistory();
                        continue;
                    }
                    self.flush_mode = .none;
                    continue;
                }
                if (self.finishing and !self.final_written) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    try self.writeDataBlock(true);
                    try Codec.finishState(self.allocator, &self.pending, &self.state);
                    self.final_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn canWriteDirectBlock(self: *Self, input: []const u8, base_target: usize, block_capacity: usize) bool {
            if (self.plain.items.len != 0 or
                self.options.adaptive_blocks or
                self.options.lookahead_len != 0 or
                block_capacity != base_target or
                input.len <= block_capacity) return false;
            if (self.options.low_entropy_block_len == 0) return true;
            if (uniqueByteCount(input[0..block_capacity]) > 4) return true;
            self.low_entropy_expanded = true;
            return false;
        }

        fn writeDirectBlock(self: *Self, block: []const u8) Error!void {
            try self.prepareHistory();
            if (self.stored_only)
                try Codec.writeStoredOnlyBlock(self.allocator, &self.pending, &self.state, &self.match_finder, block, self.history.items, false)
            else
                try Codec.writeBlock(self.allocator, &self.pending, &self.state, &self.match_finder, &self.plan_tokens, block, self.history.items, false, self.options.compression);
            self.retainHistory(block);
        }

        fn writeDataBlock(self: *Self, final: bool) Error!void {
            try self.prepareHistory();
            const selected_len = if (self.stored_only)
                self.plain.items.len
            else if (!final and self.flush_mode == .none and !self.params_boundary_pending and self.options.lookahead_len != 0)
                try Codec.chooseLookaheadLen(
                    self.allocator,
                    self.plain.items,
                    self.history.items,
                    self.plain.items.len - self.options.lookahead_len,
                    self.options.compression,
                )
            else if (self.options.adaptive_blocks and !final and self.flush_mode == .none and !self.params_boundary_pending)
                try Codec.chooseBlockLen(self.allocator, self.plain.items, self.options.compression)
            else
                self.plain.items.len;
            if ((selected_len == 0 and !(final and self.plain.items.len == 0)) or selected_len > self.plain.items.len) return error.InvalidBlockPlan;
            const block = self.plain.items[0..selected_len];
            if (self.stored_only)
                try Codec.writeStoredOnlyBlock(self.allocator, &self.pending, &self.state, &self.match_finder, block, self.history.items, final)
            else
                try Codec.writeBlock(self.allocator, &self.pending, &self.state, &self.match_finder, &self.plan_tokens, block, self.history.items, final, self.options.compression);
            self.retainHistory(block);
            self.low_entropy_expanded = false;
            if (selected_len == self.plain.items.len) {
                self.plain.clearRetainingCapacity();
            } else {
                std.mem.copyForwards(u8, self.plain.items[0 .. self.plain.items.len - selected_len], self.plain.items[selected_len..]);
                self.plain.items.len -= selected_len;
            }
        }
        fn prepareHistory(self: *Self) Error!void {
            try self.history.ensureTotalCapacity(self.allocator, Codec.history_len);
            if (self.history.items.len == 0 and self.dictionary_available and self.dictionary.len != 0) {
                const keep = @min(self.dictionary.len, Codec.history_len);
                self.history.appendSliceAssumeCapacity(self.dictionary[self.dictionary.len - keep ..]);
            }
        }
        fn resetMatchHistory(self: *Self) void {
            self.history.clearRetainingCapacity();
            self.match_finder.reset();
            self.dictionary_available = false;
        }
        fn retainHistory(self: *Self, block: []const u8) void {
            if (block.len >= Codec.history_len) {
                self.history.clearRetainingCapacity();
                self.history.appendSliceAssumeCapacity(block[block.len - Codec.history_len ..]);
            } else {
                const keep = @min(self.history.items.len, Codec.history_len - block.len);
                const start = self.history.items.len - keep;
                std.mem.copyForwards(u8, self.history.items[0..keep], self.history.items[start..]);
                self.history.items.len = keep;
                self.history.appendSliceAssumeCapacity(block);
            }
        }
        fn applyParams(self: *Self, params: Codec.ResolvedParams) void {
            self.options.compression = params.compression;
            self.active_params = params;
            self.requested_params = null;
            self.params_boundary_pending = false;
            self.stored_only = params.stored_only;
            if (self.params_change_count != std.math.maxInt(usize))
                self.params_change_count += 1;
        }
        fn syncExternallyModifiedCompression(self: *Self) void {
            const active = self.active_params orelse return;
            if (self.stored_only == active.stored_only and
                std.meta.eql(self.options.compression, active.compression)) return;
            self.active_params = null;
            self.requested_params = null;
            self.params_boundary_pending = false;
            self.stored_only = false;
        }
        fn blockTarget(self: *const Self) Error!usize {
            return baseBlockTarget(self.options);
        }
        fn activeBlockTarget(self: *Self, base: usize) usize {
            const expanded = self.options.low_entropy_block_len;
            if (expanded == 0 or self.options.adaptive_blocks or self.options.lookahead_len != 0) return base;
            if (self.plain.items.len < base) return base;
            if (self.low_entropy_expanded) return expanded;
            // A 32 KiB prefix is enough to distinguish byte runs and tiny
            // alphabets from text/source without another parser or allocation.
            // Once expanded, retain that decision until the block is emitted.
            if (uniqueByteCount(self.plain.items[0..base]) > 4) return base;
            self.low_entropy_expanded = true;
            return expanded;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }

        fn baseBlockTarget(options: Options) Error!usize {
            if (!options.adaptive_blocks) {
                if (options.block_len == 0) return error.InvalidBlockPlan;
                if (options.lookahead_len >= options.block_len) return error.InvalidBlockPlan;
                if (options.low_entropy_block_len != 0 and
                    options.low_entropy_block_len < options.block_len) return error.InvalidBlockPlan;
                return options.block_len;
            }
            const split = options.compression.split_options;
            if (split.min_block_len == 0 or split.max_block_len == 0 or
                split.min_block_len > split.max_block_len)
                return error.InvalidBlockPlan;
            if (options.lookahead_len >= split.max_block_len) return error.InvalidBlockPlan;
            return split.max_block_len;
        }
    };
}

fn paramsEqual(a: anytype, b: @TypeOf(a)) bool {
    return a.params.level == b.params.level and
        a.params.strategy == b.params.strategy;
}

fn uniqueByteCount(input: []const u8) usize {
    if (input.len != 0 and allBytesEqual(input, input[0])) return 1;
    var seen: [256]bool = @splat(false);
    var count: usize = 0;
    for (input) |byte| {
        if (!seen[byte]) {
            seen[byte] = true;
            count += 1;
            if (count > 4) break;
        }
    }
    return count;
}

fn allBytesEqual(input: []const u8, byte: u8) bool {
    // Long byte runs dominate low-entropy admission. Compare a cache-line half
    // at a time before the word/scalar tails instead of clearing and updating
    // the general 256-entry distinct-byte set for the common uniform case.
    const repeated: @Vector(32, u8) = @splat(byte);
    var cursor: usize = 0;
    while (cursor + 32 <= input.len) : (cursor += 32) {
        const values: @Vector(32, u8) = input[cursor..][0..32].*;
        if (@as(u32, @bitCast(values == repeated)) != std.math.maxInt(u32)) return false;
    }
    while (cursor + 8 <= input.len) : (cursor += 8) {
        const value = std.mem.readInt(u64, input[cursor..][0..8], .little);
        if (value != @as(u64, byte) * 0x0101_0101_0101_0101) return false;
    }
    for (input[cursor..]) |value| if (value != byte) return false;
    return true;
}

test "saturated unique byte count handles uniform and mixed inputs" {
    try std.testing.expectEqual(@as(usize, 0), uniqueByteCount(""));
    try std.testing.expectEqual(@as(usize, 1), uniqueByteCount("aaaaaaaaaaaaaaaa"));
    try std.testing.expectEqual(@as(usize, 4), uniqueByteCount("abacabadabacaba"));
    try std.testing.expectEqual(@as(usize, 5), uniqueByteCount("abcdeeeeeeeeeeee"));

    var bytes: [97]u8 = @splat('x');
    for (0..bytes.len + 1) |len|
        try std.testing.expect(allBytesEqual(bytes[0..len], 'x'));
    for (&bytes) |*value| {
        value.* = 'y';
        try std.testing.expect(!allBytesEqual(&bytes, 'x'));
        try std.testing.expectEqual(@as(usize, 2), uniqueByteCount(&bytes));
        value.* = 'x';
    }
}
