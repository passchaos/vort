//! Incremental raw Deflate64 compression with stored/fixed/dynamic arbitration.
//! Each instance owns bounded, lazily allocated block/history/output/index
//! storage. Bit packing and 64KiB history continue across calls and blocks;
//! full flush starts an independent byte-aligned history segment. Dynamic trees
//! are planned before output admission. Preset dictionaries remain unsupported.
const std = @import("std");
const core = @import("../core.zig");
const matching = @import("stream_match.zig");
const blocks = @import("stream_blocks.zig");
const choice = @import("block_choice.zig");

pub const Error = core.Error || std.mem.Allocator.Error;
pub const max_block_len: usize = 128 * 1024;
pub const history_limit: usize = matching.window_len;
pub const max_match_len: usize = matching.max_match_len;
pub const Compression = enum { adaptive, fixed, stored, dynamic };

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    state: blocks.State = .{},
    matcher: matching.Matcher = .{},
    plain: std.ArrayList(u8) = .empty,
    history: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    flush_mode: FlushMode = .none,
    flush_boundary: FlushBoundary = .none,
    finishing: bool = false,
    final_written: bool = false,
    done: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    expected_input_len: ?usize = null,
    fatal_error: ?stream_encoder.Error = null,
    failure_progress: ?core.Progress = null,
    last_step_progress: core.Progress = .{},
    block_count: usize = 0,
    fixed_block_count: usize = 0,
    dynamic_block_count: usize = 0,
    stored_block_count: usize = 0,
    match_count: usize = 0,
    max_match_length: usize = 0,
    max_match_distance: usize = 0,

    const Self = @This();
    const FlushMode = enum { none, block, partial, sync, full };
    const FlushBoundary = enum { none, partial, sync };
    pub const Error = stream_encoder.Error;
    pub const Compression = stream_encoder.Compression;
    pub const Options = struct {
        block_len: usize = max_block_len,
        max_input_len: usize = std.math.maxInt(usize),
        /// Limit complete bytes retained for one emission event. The final
        /// partial byte is included on finish; a non-final bit tail is <=7 bits.
        max_pending_output_len: usize = std.math.maxInt(usize),
        compression: stream_encoder.Compression = .adaptive,
        max_chain: usize = 128,
        nice_length: u32 = max_match_len,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        pending_bits: u3,
        history_len: usize,
        block_count: usize,
        fixed_block_count: usize,
        dynamic_block_count: usize,
        stored_block_count: usize,
        match_count: usize,
        max_match_length: usize,
        max_match_distance: usize,
        retained_input_capacity: usize,
        retained_pending_capacity: usize,
        flushing: bool,
        finishing: bool,
        done: bool,
        failed: bool,
        last_error_name: []const u8,
        last_step_progress: core.Progress,
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
    pub fn validateOptions(options: Options) stream_encoder.Error!void {
        if (options.block_len == 0 or options.block_len > max_block_len or
            options.nice_length < 3 or options.nice_length > max_match_len)
            return error.InvalidBlockPlan;
    }
    pub fn deinit(self: *Self) void {
        self.matcher.deinit(self.allocator);
        self.plain.deinit(self.allocator);
        self.history.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }
    /// Reset semantic state while retaining owned capacities and input pledge.
    pub fn reset(self: *Self) void {
        const allocator = self.allocator;
        const options = self.options;
        const expected = self.expected_input_len;
        var plain = self.plain;
        var history = self.history;
        var pending = self.pending;
        var matcher = self.matcher;
        plain.clearRetainingCapacity();
        history.clearRetainingCapacity();
        pending.clearRetainingCapacity();
        matcher.reset();
        self.* = .{ .allocator = allocator, .options = options, .expected_input_len = expected, .plain = plain, .history = history, .pending = pending, .matcher = matcher };
    }
    pub fn resetWithOptions(self: *Self, options: Options) void {
        self.options = options;
        self.reset();
    }
    pub fn resetExactSize(self: *Self, expected_input_len: usize) void {
        self.expected_input_len = expected_input_len;
        self.reset();
    }
    pub fn failedProgress(self: *const Self) ?core.Progress {
        return self.failure_progress;
    }
    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.plain.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .pending_bits = self.state.bit_index,
            .history_len = self.history.items.len,
            .block_count = self.block_count,
            .fixed_block_count = self.fixed_block_count,
            .dynamic_block_count = self.dynamic_block_count,
            .stored_block_count = self.stored_block_count,
            .match_count = self.match_count,
            .max_match_length = self.max_match_length,
            .max_match_distance = self.max_match_distance,
            .retained_input_capacity = self.plain.capacity,
            .retained_pending_capacity = self.pending.capacity,
            .flushing = self.flush_mode != .none,
            .finishing = self.finishing,
            .done = self.done,
            .failed = self.fatal_error != null,
            .last_error_name = if (self.fatal_error) |err| @errorName(err) else "",
            .last_step_progress = self.last_step_progress,
        };
    }
    pub fn blockFlush(self: *Self) void {
        if (self.fatal_error == null and !self.finishing and !self.done and self.flush_mode == .none)
            self.flush_mode = .block;
    }
    pub fn partialFlush(self: *Self) void {
        if (self.fatal_error != null or self.finishing or self.done or self.flush_mode == .sync or self.flush_mode == .full) return;
        if (self.flush_boundary == .none) self.flush_mode = .partial;
    }
    pub fn flush(self: *Self) void {
        self.syncFlush();
    }
    pub fn syncFlush(self: *Self) void {
        if (self.fatal_error != null or self.finishing or self.done or self.flush_mode == .sync or self.flush_mode == .full) return;
        if (self.flush_boundary != .sync) self.flush_mode = .sync;
    }
    pub fn fullFlush(self: *Self) void {
        if (self.fatal_error != null or self.finishing or self.done or self.flush_mode == .full) return;
        if (self.flush_boundary == .sync) {
            self.history.clearRetainingCapacity();
            self.matcher.reset();
            if (self.flush_mode == .sync) self.flush_mode = .full;
            return;
        }
        self.flush_mode = .full;
    }
    pub fn finish(self: *Self) void {
        if (self.fatal_error == null) self.finishing = true;
    }

    /// Offered input limits/pledge and deterministic options are checked before
    /// draining output or consuming input. Any failure is sticky until reset.
    /// failedProgress exposes the first failed call's actual committed progress,
    /// including bytes drained/accepted before a later emission allocation error.
    pub fn step(self: *Self, input: []const u8, output: []u8) stream_encoder.Error!core.StepResult {
        if (self.fatal_error) |err| return err;
        self.last_step_progress = .{};
        return self.stepInner(input, output) catch |err| {
            self.fatal_error = err;
            self.failure_progress = self.last_step_progress;
            return err;
        };
    }
    fn stepInner(self: *Self, input: []const u8, output: []u8) stream_encoder.Error!core.StepResult {
        try validateOptions(self.options);
        if (self.plain.items.len > self.options.block_len) return error.InvalidStreamState;
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return self.result(.done);
        }
        if ((self.finishing or self.flush_mode != .none) and input.len != 0) return error.TrailingData;
        const offered = std.math.add(usize, self.total_input, input.len) catch return error.IntegerOverflow;
        if (self.expected_input_len) |expected| if (offered > expected) return error.SizeMismatch;
        if (offered > self.options.max_input_len) return error.OutputLimitExceeded;

        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const take = @min(output.len - self.last_step_progress.output_written, self.pending.items.len - self.pending_offset);
                const total = std.math.add(usize, self.total_output, take) catch return error.IntegerOverflow;
                @memcpy(output[self.last_step_progress.output_written..][0..take], self.pending.items[self.pending_offset..][0..take]);
                self.pending_offset += take;
                self.total_output = total;
                self.last_step_progress.output_written += take;
                if (self.pending_offset != self.pending.items.len) return self.result(.need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (self.last_step_progress.output_written == output.len and output.len != 0) return self.result(.need_output);
            }

            const room = self.options.block_len - self.plain.items.len;
            const take = @min(room, input.len - self.last_step_progress.input_read);
            if (take != 0) {
                try self.plain.ensureTotalCapacityPrecise(self.allocator, self.options.block_len);
                self.plain.appendSliceAssumeCapacity(input[self.last_step_progress.input_read..][0..take]);
                self.total_input += take; // Offered admission proves this sum.
                self.last_step_progress.input_read += take;
                self.flush_boundary = .none;
            }
            // Retain a completely filled last block until another input byte,
            // flush or finish determines its BFINAL value. Chunking is immaterial.
            if (self.plain.items.len == self.options.block_len and self.last_step_progress.input_read < input.len) {
                try self.writeDataBlock(false);
                continue;
            }
            if (self.flush_mode != .none) {
                if (self.plain.items.len != 0) {
                    try self.writeDataBlock(false);
                    continue;
                }
                switch (self.flush_mode) {
                    .none => unreachable,
                    .block => self.flush_mode = .none,
                    .partial => {
                        if (self.flush_boundary == .none) {
                            try self.writeBoundary(true);
                            self.flush_boundary = .partial;
                            continue;
                        }
                        self.flush_mode = .none;
                    },
                    .sync, .full => {
                        if (self.flush_boundary != .sync) {
                            try self.writeBoundary(false);
                            self.flush_boundary = .sync;
                            if (self.flush_mode == .full) {
                                self.history.clearRetainingCapacity();
                                self.matcher.reset();
                            }
                            continue;
                        }
                        self.flush_mode = .none;
                    },
                }
                continue;
            }
            if (self.finishing and !self.final_written) {
                if (self.expected_input_len) |expected| if (self.total_input != expected) return error.SizeMismatch;
                try self.writeDataBlock(true);
                self.final_written = true;
                continue;
            }
            if (self.finishing) {
                self.done = true;
                return self.result(.done);
            }
            return self.result(.need_input);
        }
    }

    fn preparePending(self: *Self, required: usize) stream_encoder.Error!void {
        std.debug.assert(self.pending.items.len == 0 and self.pending_offset == 0);
        if (required > self.options.max_pending_output_len) return error.OutputLimitExceeded;
        try self.pending.ensureTotalCapacityPrecise(self.allocator, required);
    }
    fn writeDataBlock(self: *Self, final: bool) stream_encoder.Error!void {
        const block = self.plain.items;
        const stored_bits = blocks.storedBits(self.state, block.len);
        var fixed: blocks.Plan = .{ .bits = 10, .stats = .{} };
        var dynamic: ?blocks.DynamicPlan = null;
        if (self.options.compression != .stored) {
            if (block.len != 0) try self.matcher.ensureForSize(self.allocator, self.history.items.len + block.len);
            if (self.options.compression == .fixed or (block.len == 0 and self.options.compression == .adaptive)) {
                fixed = blocks.fixedPlan(&self.matcher, self.history.items, block, self.options.max_chain, self.options.nice_length);
            } else {
                dynamic = try blocks.dynamicPlan(&self.matcher, self.history.items, block, self.options.max_chain, self.options.nice_length);
                fixed = .{ .bits = dynamic.?.fixed_bits, .stats = dynamic.?.stats };
            }
        }
        // Non-final blocks compare continuous bit costs. Final blocks compare
        // padded bytes; ties preserve stored, then fixed, then dynamic.
        const selected: choice.Kind = switch (self.options.compression) {
            .stored => .stored,
            .fixed => .fixed,
            .dynamic => .dynamic,
            .adaptive => choice.adaptive(self.state, stored_bits, fixed.bits, if (dynamic) |plan| plan.bits else fixed.bits, final),
        };
        const use_compressed = selected != .stored;
        const emitted_blocks = if (use_compressed) 1 else blocks.storedBlockCount(block.len);
        const next_blocks = std.math.add(usize, self.block_count, emitted_blocks) catch return error.IntegerOverflow;
        const next_fixed = std.math.add(usize, self.fixed_block_count, @intFromBool(selected == .fixed)) catch return error.IntegerOverflow;
        const next_dynamic = std.math.add(usize, self.dynamic_block_count, @intFromBool(selected == .dynamic)) catch return error.IntegerOverflow;
        const next_stored = std.math.add(usize, self.stored_block_count, if (use_compressed) 0 else emitted_blocks) catch return error.IntegerOverflow;
        const next_matches = std.math.add(usize, self.match_count, if (use_compressed) fixed.stats.match_count else 0) catch return error.IntegerOverflow;
        const selected_bits = switch (selected) {
            .stored => stored_bits,
            .fixed => fixed.bits,
            .dynamic => dynamic.?.bits,
        };
        const required = blocks.pendingBytes(self.state, selected_bits, final);
        try self.preparePending(required);
        if (block.len != 0) try self.history.ensureTotalCapacityPrecise(self.allocator, history_limit);

        var writer: blocks.Writer = .{ .state = self.state, .output = self.pending.allocatedSlice()[0..required] };
        switch (selected) {
            .fixed => blocks.writeFixed(&writer, &self.matcher, self.history.items, block, self.options.max_chain, self.options.nice_length, final),
            .dynamic => blocks.writeDynamic(&writer, &self.matcher, self.history.items, block, self.options.max_chain, self.options.nice_length, final, &dynamic.?),
            .stored => blocks.writeStored(&writer, block, final),
        }
        if (final) writer.alignToByte();
        std.debug.assert(writer.len == required);
        self.pending.items.len = writer.len;
        self.state = writer.state;
        self.block_count = next_blocks;
        self.fixed_block_count = next_fixed;
        self.dynamic_block_count = next_dynamic;
        self.stored_block_count = next_stored;
        self.match_count = next_matches;
        if (use_compressed) {
            self.max_match_length = @max(self.max_match_length, fixed.stats.max_match_length);
            self.max_match_distance = @max(self.max_match_distance, fixed.stats.max_match_distance);
        }
        self.retainHistory(block);
        self.matcher.reset();
        self.plain.clearRetainingCapacity();
    }
    fn writeBoundary(self: *Self, partial: bool) stream_encoder.Error!void {
        const required = if (partial)
            blocks.pendingBytes(self.state, 10, false)
        else
            blocks.pendingBytes(self.state, blocks.storedBits(self.state, 0), false);
        const next_blocks = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
        const next_fixed = std.math.add(usize, self.fixed_block_count, @intFromBool(partial)) catch return error.IntegerOverflow;
        const next_stored = std.math.add(usize, self.stored_block_count, @intFromBool(!partial)) catch return error.IntegerOverflow;
        try self.preparePending(required);
        var writer: blocks.Writer = .{ .state = self.state, .output = self.pending.allocatedSlice()[0..required] };
        if (partial) blocks.writePartial(&writer) else blocks.writeStored(&writer, "", false);
        std.debug.assert(writer.len == required);
        self.pending.items.len = writer.len;
        self.state = writer.state;
        self.block_count = next_blocks;
        self.fixed_block_count = next_fixed;
        self.stored_block_count = next_stored;
    }
    fn retainHistory(self: *Self, block: []const u8) void {
        if (block.len >= history_limit) {
            self.history.clearRetainingCapacity();
            self.history.appendSliceAssumeCapacity(block[block.len - history_limit ..]);
        } else {
            const keep = @min(self.history.items.len, history_limit - block.len);
            std.mem.copyForwards(u8, self.history.items[0..keep], self.history.items[self.history.items.len - keep ..]);
            self.history.items.len = keep;
            self.history.appendSliceAssumeCapacity(block);
        }
    }
    fn result(self: *const Self, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = self.last_step_progress, .status = status };
    }
};

const stream_encoder = @This();

test "Deflate64 incremental compressed encoder complete contracts" {
    try @import("stream_encoder_tests.zig").contracts(@This());
}
