const std = @import("std");
const core = @import("../../../core.zig");
const rolling_hash = @import("match_finder/rolling_hash.zig");

/// Incremental block-planned raw-DEFLATE encoder. Blocks share retained 32 KiB
/// history and hash-parser levels additionally share a persistent match index;
/// bit packing stays continuous until finish writes BFINAL. The codec adapter
/// chooses fixed-only or stored/fixed/dynamic best emission. Flush emits an
/// empty stored block, matching zlib's sync-flush byte boundary without ending
/// the stream.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        state: Codec.State = .{},
        match_finder: rolling_hash.Matcher = .{},
        plain: std.ArrayList(u8) = .empty,
        history: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        flush_requested: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        dictionary: []const u8 = &.{},

        const Self = @This();
        pub const Error = Codec.Error;
        pub const MatchFinderSnapshot = rolling_hash.Matcher.Snapshot;
        pub const Options = struct {
            max_input_len: usize = std.math.maxInt(usize),
            block_len: usize = 32 * 1024,
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
            self.plain.deinit(self.allocator);
            self.history.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected = self.expected_input_len;
            Codec.resetState(&self.state);
            self.match_finder.reset();
            self.plain.clearRetainingCapacity();
            self.history.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.flush_requested = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected;
        }
        pub fn matchFinderSnapshot(self: *const Self) MatchFinderSnapshot {
            return self.match_finder.snapshot();
        }
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
            self.flush_requested = false;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            const block_target = try self.blockTarget();
            const block_capacity = std.math.add(usize, block_target, self.options.lookahead_len) catch return error.IntegerOverflow;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
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

                const room = block_capacity - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    self.total_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                if (self.plain.items.len == block_capacity and
                    (input_read < input.len or self.options.lookahead_len != 0))
                {
                    try self.writeDataBlock(false);
                    continue;
                }
                if (self.flush_requested) {
                    if (self.plain.items.len != 0) {
                        try self.writeDataBlock(false);
                        continue;
                    }
                    try Codec.writeSyncFlush(self.allocator, &self.pending, &self.state);
                    self.flush_requested = false;
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

        fn writeDataBlock(self: *Self, final: bool) Error!void {
            try self.history.ensureTotalCapacity(self.allocator, Codec.history_len);
            if (self.history.items.len == 0 and self.dictionary.len != 0) {
                const keep = @min(self.dictionary.len, Codec.history_len);
                self.history.appendSliceAssumeCapacity(self.dictionary[self.dictionary.len - keep ..]);
            }
            const selected_len = if (!final and !self.flush_requested and self.options.lookahead_len != 0)
                try Codec.chooseLookaheadLen(
                    self.allocator,
                    self.plain.items,
                    self.history.items,
                    self.plain.items.len - self.options.lookahead_len,
                    self.options.compression,
                )
            else if (self.options.adaptive_blocks and !final and !self.flush_requested)
                try Codec.chooseBlockLen(self.allocator, self.plain.items, self.options.compression)
            else
                self.plain.items.len;
            if ((selected_len == 0 and !(final and self.plain.items.len == 0)) or selected_len > self.plain.items.len) return error.InvalidBlockPlan;
            const block = self.plain.items[0..selected_len];
            try Codec.writeBlock(self.allocator, &self.pending, &self.state, &self.match_finder, block, self.history.items, final, self.options.compression);
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
            if (selected_len == self.plain.items.len) {
                self.plain.clearRetainingCapacity();
            } else {
                std.mem.copyForwards(u8, self.plain.items[0 .. self.plain.items.len - selected_len], self.plain.items[selected_len..]);
                self.plain.items.len -= selected_len;
            }
        }
        fn blockTarget(self: *const Self) Error!usize {
            if (!self.options.adaptive_blocks) {
                if (self.options.block_len == 0) return error.InvalidBlockPlan;
                if (self.options.lookahead_len >= self.options.block_len) return error.InvalidBlockPlan;
                return self.options.block_len;
            }
            const split = self.options.compression.split_options;
            if (split.min_block_len == 0 or split.max_block_len == 0 or split.min_block_len > split.max_block_len) return error.InvalidBlockPlan;
            if (self.options.lookahead_len >= split.max_block_len) return error.InvalidBlockPlan;
            return split.max_block_len;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
