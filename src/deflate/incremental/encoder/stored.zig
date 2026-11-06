const std = @import("std");
const core = @import("../../../core.zig");

/// Incremental raw-DEFLATE stored-block encoder. One RFC 1951 stored block is
/// retained; encoded bytes drain through arbitrary caller output. Block, sync,
/// and full flushes write a non-final block, while finish writes the only
/// BFINAL block. A retained bit writer also supports the non-byte-aligned empty
/// fixed marker required by zlib-compatible partial flush.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        state: Codec.State = .{},
        plain: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        flush_mode: FlushMode = .none,
        partial_boundary_written: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: core.StreamCount = 0,
        total_output: core.StreamCount = 0,
        expected_input_len: ?core.StreamCount = null,

        const Self = @This();
        const FlushMode = enum { none, block, partial, sync, full };
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_input_len: core.StreamCount = std.math.maxInt(core.StreamCount),
            block_len: usize = Codec.max_block_len,
        };
        pub const Snapshot = struct {
            input_read: core.StreamCount,
            output_written: core.StreamCount,
            buffered_input: usize,
            pending_output: usize,
            pending_bits: u3,
            flushing: bool,
            finishing: bool,
            done: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: core.StreamCount) Self {
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len };
        }
        pub fn deinit(self: *Self) void {
            Codec.deinitState(&self.state, self.allocator);
            self.plain.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.plain.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.flush_mode = .none;
            self.partial_boundary_written = false;
            Codec.resetState(&self.state);
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .pending_bits = self.state.bit_index,
                .flushing = self.flush_mode != .none,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        /// End and publish the accepted input as a non-final stored block.
        /// Stored blocks are inherently byte-aligned, so this adds no separate
        /// empty sync-flush marker.
        pub fn blockFlush(self: *Self) void {
            if (!self.finishing and !self.done and self.flush_mode == .none)
                self.flush_mode = .block;
        }
        pub fn partialFlush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .sync or
                self.flush_mode == .full)
                return;
            if (!self.partial_boundary_written) self.flush_mode = .partial;
        }
        pub fn flush(self: *Self) void {
            if (self.finishing or self.done or self.flush_mode == .sync or self.flush_mode == .full) return;
            self.flush_mode = .sync;
        }
        pub fn fullFlush(self: *Self) void {
            if (!self.finishing and !self.done and self.flush_mode != .full) self.flush_mode = .full;
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.options.block_len == 0 or self.options.block_len > Codec.max_block_len) return error.InvalidBlockPlan;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_mode != .none) and input.len != 0) return error.TrailingData;
            const offered_total = try core.stream_count.addLocal(self.total_input, input.len);
            if (offered_total > self.options.max_input_len) return error.OutputLimitExceeded;
            if (self.expected_input_len) |expected| {
                if (expected > self.options.max_input_len) return error.OutputLimitExceeded;
                if (offered_total > expected or (self.finishing and offered_total != expected))
                    return error.SizeMismatch;
            }
            // Keep every drain in this step within one countable caller
            // window. A final countable prefix is returned normally; a later
            // attempt to drain its retained suffix fails before copying.
            const output_limit = core.stream_count.bounded(std.math.maxInt(core.StreamCount) - self.total_output, output.len);
            if (output.len != 0 and output_limit == 0) {
                const will_publish = input.len != 0 or (self.finishing and !self.final_written) or
                    (self.flush_mode != .none and
                        (self.plain.items.len != 0 or
                            (self.flush_mode == .partial and !self.partial_boundary_written) or
                            ((self.flush_mode == .sync or self.flush_mode == .full) and self.state.bit_index != 0)));
                if (self.pending_offset != self.pending.items.len or will_publish)
                    return error.IntegerOverflow;
            }

            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output_limit - output_written, remaining.len);
                    const total_output = try core.stream_count.addLocal(self.total_output, n);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output = total_output;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output_limit and output.len != 0) return result(input_read, output_written, .need_output);
                }

                const room = self.options.block_len - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const total_input = try core.stream_count.addLocal(self.total_input, n);
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    self.partial_boundary_written = false;
                    input_read += n;
                    self.total_input = total_input;
                }
                if (self.plain.items.len == self.options.block_len and input_read < input.len) {
                    try self.writeBlock(false);
                    continue;
                }
                if (self.flush_mode != .none) {
                    if (self.plain.items.len != 0) {
                        try self.writeBlock(false);
                        continue;
                    }
                    if (self.flush_mode == .partial) {
                        if (!self.partial_boundary_written) {
                            try Codec.writePartialFlush(self.allocator, &self.pending, &self.state);
                            self.partial_boundary_written = true;
                            continue;
                        }
                        self.flush_mode = .none;
                        continue;
                    }
                    if ((self.flush_mode == .sync or self.flush_mode == .full) and
                        self.state.bit_index != 0)
                    {
                        try Codec.writeSyncFlush(self.allocator, &self.pending, &self.state);
                        continue;
                    }
                    self.flush_mode = .none;
                    continue;
                }
                if (self.finishing and !self.final_written) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    try self.writeBlock(true);
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

        fn writeBlock(self: *Self, final: bool) Error!void {
            try Codec.writeBlock(self.allocator, &self.pending, &self.state, self.plain.items, final);
            self.plain.clearRetainingCapacity();
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
