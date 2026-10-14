const std = @import("std");
const core = @import("../../../core.zig");
const rolling_hash = @import("match_finder/rolling_hash.zig");

/// Incremental block-planned raw-DEFLATE encoder. Blocks share retained 32 KiB
/// history and hash-parser levels additionally share a persistent match index;
/// bit packing stays continuous until finish writes BFINAL. The codec adapter
/// chooses fixed-only or stored/fixed/dynamic best emission. Block flush ends
/// the current block without alignment; flush emits an empty stored block,
/// matching zlib's sync-flush byte boundary without ending the stream. Full
/// flush additionally starts a new independent match-history segment after
/// that byte boundary.
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
        flush_boundary_written: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        low_entropy_expanded: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        dictionary: []const u8 = &.{},
        dictionary_available: bool = true,

        const Self = @This();
        const FlushMode = enum { none, block, sync, full };
        pub const Error = Codec.Error;
        pub const MatchFinderSnapshot = rolling_hash.Matcher.Snapshot;
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            buffered_input: usize,
            pending_output: usize,
            pending_bits: u3,
            retained_token_capacity: usize,
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
            self.flush_boundary_written = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.low_entropy_expanded = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected;
            self.dictionary_available = true;
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
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .pending_bits = self.state.bit_index,
                .retained_token_capacity = self.plan_tokens.capacity,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        /// End and publish a non-final block without adding a sync-flush
        /// marker or aligning the bit stream. Match history remains available
        /// to later blocks.
        pub fn blockFlush(self: *Self) void {
            if (!self.finishing and !self.done and self.flush_mode == .none)
                self.flush_mode = .block;
        }
        pub fn flush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .sync or self.flush_mode == .full) return;
            if (!self.flush_boundary_written) self.flush_mode = .sync;
        }
        pub fn fullFlush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .full) return;
            if (self.flush_boundary_written) {
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
            const base_block_target = try self.blockTarget();
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_mode != .none) and input.len != 0) return error.TrailingData;
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

                const block_target = self.activeBlockTarget(base_block_target);
                const block_capacity = std.math.add(usize, block_target, self.options.lookahead_len) catch return error.IntegerOverflow;
                const room = block_capacity - self.plain.items.len;
                if (self.canWriteDirectBlock(input[input_read..], base_block_target, block_capacity)) {
                    // The complete non-final block already lives contiguously
                    // in caller input. Plan and emit it in place instead of
                    // copying it into `plain`; retainHistory copies the owned
                    // window before this call returns. Low-entropy prefixes
                    // still take the buffered coalescing path.
                    const block = input[input_read..][0..block_capacity];
                    try self.writeDirectBlock(block);
                    self.flush_boundary_written = false;
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
                    self.flush_boundary_written = false;
                    input_read += n;
                    self.total_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                const active_capacity = std.math.add(usize, self.activeBlockTarget(base_block_target), self.options.lookahead_len) catch return error.IntegerOverflow;
                if (self.plain.items.len == active_capacity and
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
                    if (!self.flush_boundary_written) {
                        try Codec.writeSyncFlush(self.allocator, &self.pending, &self.state);
                        self.flush_boundary_written = true;
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
            try Codec.writeBlock(self.allocator, &self.pending, &self.state, &self.match_finder, &self.plan_tokens, block, self.history.items, false, self.options.compression);
            self.retainHistory(block);
        }

        fn writeDataBlock(self: *Self, final: bool) Error!void {
            try self.prepareHistory();
            const selected_len = if (!final and self.flush_mode == .none and self.options.lookahead_len != 0)
                try Codec.chooseLookaheadLen(
                    self.allocator,
                    self.plain.items,
                    self.history.items,
                    self.plain.items.len - self.options.lookahead_len,
                    self.options.compression,
                )
            else if (self.options.adaptive_blocks and !final and self.flush_mode == .none)
                try Codec.chooseBlockLen(self.allocator, self.plain.items, self.options.compression)
            else
                self.plain.items.len;
            if ((selected_len == 0 and !(final and self.plain.items.len == 0)) or selected_len > self.plain.items.len) return error.InvalidBlockPlan;
            const block = self.plain.items[0..selected_len];
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
        fn blockTarget(self: *const Self) Error!usize {
            if (!self.options.adaptive_blocks) {
                if (self.options.block_len == 0) return error.InvalidBlockPlan;
                if (self.options.lookahead_len >= self.options.block_len) return error.InvalidBlockPlan;
                if (self.options.low_entropy_block_len != 0 and
                    self.options.low_entropy_block_len < self.options.block_len) return error.InvalidBlockPlan;
                return self.options.block_len;
            }
            const split = self.options.compression.split_options;
            if (split.min_block_len == 0 or split.max_block_len == 0 or split.min_block_len > split.max_block_len) return error.InvalidBlockPlan;
            if (self.options.lookahead_len >= split.max_block_len) return error.InvalidBlockPlan;
            return split.max_block_len;
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
    };
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
