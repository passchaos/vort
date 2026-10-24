const std = @import("std");
const core = @import("../core.zig");
const working = @import("../io/working_allocator.zig");
const options_mod = @import("incremental/options.zig");

pub const Format = enum { xerial, hadoop };

/// Build a caller-output incremental decoder for Xerial or Hadoop Snappy
/// framing. Raw Snappy chunks remain input-atomic because their decoded-size
/// varint and copy stream must be validated together, while framing headers,
/// chunk payloads, and decoded output may cross arbitrary caller boundaries.
pub fn Decoder(comptime Codec: type, comptime format: Format) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        budget: working.WorkingAllocator,
        phase: Phase = initialPhase(),
        header: [if (format == .xerial) Codec.xerial_header.len else 4]u8 = undefined,
        header_len: usize = 0,
        compressed_len: usize = 0,
        compressed: std.ArrayList(u8) = .empty,
        cursor: ?Codec.BlockCursor = null,
        current_decoded_len: usize = 0,
        required_history_len: usize = 0,
        saw_xerial_header: bool = false,
        hadoop_block_expected: usize = 0,
        hadoop_block_decoded: usize = 0,
        input_finished: bool = false,
        total_output: usize = 0,
        input_read: usize = 0,
        block_count: usize = 0,
        chunk_count: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = initialPhase(),
        failure: ?Error = null,
        last_step_progress: core.Progress = .{},
        error_input_offset: ?usize = null,
        error_output_offset: ?usize = null,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = options_mod.Options;
        pub const Phase = enum { stream_header, outer_header, chunk_header, payload, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            header_received: usize,
            chunk_payload_received: usize,
            chunk_payload_expected: usize,
            payload_remaining: usize,
            output_written: usize,
            input_read: usize,
            block_count: usize,
            chunk_count: usize,
            hadoop_block_expected: usize,
            hadoop_block_decoded: usize,
            input_finished: bool,
            retained_compressed_capacity: usize,
            retained_decoded_capacity: usize,
            retained_history_capacity: usize,
            history_len: usize,
            required_history_len: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
            working_bytes: usize,
            peak_working_bytes: usize,
            last_step_progress: core.Progress,
            error_input_offset: ?usize,
            error_output_offset: ?usize,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory) };
        }

        pub fn deinit(self: *Self) void {
            self.compressed.deinit(self.budget.allocator());
            if (self.cursor) |*cursor| cursor.deinit(self.budget.allocator());
            std.debug.assert(self.budget.live == 0);
            self.* = undefined;
        }

        pub fn reset(self: *Self) void {
            var compressed = self.compressed;
            var cursor = self.cursor;
            var budget = self.budget;
            compressed.clearRetainingCapacity();
            if (cursor) |*active| active.reset(emptyPlan());
            budget.peak = budget.live;
            budget.hit_limit = false;
            budget.last_failure_was_limit = false;
            self.* = initWithOptions(self.allocator, self.options);
            self.compressed = compressed;
            self.cursor = cursor;
            self.budget = budget;
        }

        pub fn resetWithOptions(self: *Self, options: Options) void {
            options.validate() catch |err| {
                self.failure = self.fail(self.phase, err);
                return;
            };
            const allocator = self.allocator;
            self.deinit();
            self.* = initWithOptions(allocator, options);
        }

        pub fn workingMemoryBytes(self: *const Self) usize {
            return self.budget.live;
        }
        pub fn peakWorkingMemoryBytes(self: *const Self) usize {
            return self.budget.peak;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .header_received = self.header_len,
                .chunk_payload_received = self.compressed.items.len,
                .chunk_payload_expected = self.compressed_len,
                .payload_remaining = if (self.phase == .output) self.current_decoded_len - self.cursor.?.decoded_written else 0,
                .output_written = self.total_output,
                .input_read = self.input_read,
                .block_count = self.block_count,
                .chunk_count = self.chunk_count,
                .hadoop_block_expected = self.hadoop_block_expected,
                .hadoop_block_decoded = self.hadoop_block_decoded,
                .input_finished = self.input_finished,
                .retained_compressed_capacity = self.compressed.capacity,
                .retained_decoded_capacity = 0,
                .retained_history_capacity = if (self.cursor) |*cursor| cursor.historyCapacity() else 0,
                .history_len = if (self.cursor) |*cursor| cursor.activeHistoryLen() else 0,
                .required_history_len = self.required_history_len,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
                .working_bytes = self.budget.live,
                .peak_working_bytes = self.budget.peak,
                .last_step_progress = self.last_step_progress,
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
            };
        }

        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .input_read = snap.input_read,
                .frame_input_read = snap.input_read,
                .header_received = snap.header_received,
                .output_written = snap.output_written,
                .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .error_input_offset = core.stream_count.fromOptionalLocal(snap.error_input_offset),
                .error_output_offset = core.stream_count.fromOptionalLocal(snap.error_output_offset),
                .last_step_progress = snap.last_step_progress,
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.WorkingMemoryLimitExceeded))) "raise_working_memory_limit" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutOfMemory))) "allocation_failure" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }

        /// Both formats terminate at a framing boundary rather than with an
        /// explicit marker. Pending decoded bytes may still be drained after
        /// finish. Rejected partial headers/blocks do not seal input, preserving
        /// the existing ability to offer their remaining bytes. A fatal step
        /// failure instead remains sticky until reset/reconfiguration.
        pub fn finish(self: *Self) Error!void {
            if (self.failure) |err| return err;
            if (self.phase == .done) return;
            const valid = switch (self.phase) {
                .chunk_header => if (comptime format == .xerial)
                    self.saw_xerial_header and self.header_len == 0
                else
                    false,
                .outer_header => if (comptime format == .hadoop)
                    self.header_len == 0 and self.hadoop_block_expected == 0
                else
                    false,
                .output => if (comptime format == .xerial)
                    self.saw_xerial_header
                else
                    self.hadoop_block_expected != 0 and self.hadoop_block_decoded == self.hadoop_block_expected,
                else => false,
            };
            if (!valid) return self.fail(self.phase, error.TruncatedFrame);
            self.input_finished = true;
            if (self.phase != .output) self.complete() catch |err| {
                self.failure = err;
                return err;
            };
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.last_step_progress = .{};
            if (self.failure) |err| return err;
            self.clearError();
            self.budget.last_failure_was_limit = false;
            const before = core.Progress{ .input_read = self.input_read, .output_written = self.total_output };
            const stepped = self.stepChecked(input, output) catch |original| {
                const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
                self.last_step_progress = .{ .input_read = self.input_read - before.input_read, .output_written = self.total_output - before.output_written };
                self.failure = err;
                return self.fail(self.phase, err);
            };
            self.last_step_progress = stepped.progress;
            return stepped;
        }

        fn stepChecked(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (input.len > std.math.maxInt(usize) - self.input_read) return error.IntegerOverflow;
            try self.options.validate();
            if (self.phase == .done) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return .{ .status = .done };
            }
            if (self.input_finished and input.len != 0) return self.fail(self.phase, error.TrailingData);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.phase == .output) {
                    const cursor = &self.cursor.?;
                    const before = cursor.decoded_written;
                    const decoded = cursor.step(self.budget.allocator(), self.compressed.items, output[output_written..]) catch |err| {
                        const emitted = cursor.decoded_written - before;
                        self.total_output += emitted;
                        return err;
                    };
                    output_written += decoded.output_written;
                    self.total_output += decoded.output_written;
                    if (!decoded.done)
                        return result(input_read, output_written, .need_output);
                    self.compressed.clearRetainingCapacity();
                    cursor.reset(emptyPlan());
                    self.current_decoded_len = 0;
                    self.required_history_len = 0;
                    try self.advanceAfterChunk();
                    if (self.input_finished) {
                        try self.complete();
                        return result(input_read, output_written, .done);
                    }
                }

                if (comptime format == .xerial) {
                    if (self.phase == .stream_header) {
                        const header_complete = self.fillHeader(input, &input_read, Codec.xerial_header.len);
                        if (!header_complete) return result(input_read, output_written, .need_input);
                        if (!std.mem.eql(u8, self.header[0..Codec.xerial_header.len], &Codec.xerial_header))
                            return self.fail(.stream_header, error.InvalidMagic);
                        self.header_len = 0;
                        self.saw_xerial_header = true;
                        self.phase = .chunk_header;
                    }
                }

                if (self.phase == .outer_header) {
                    if (!self.fillHeader(input, &input_read, 4))
                        return result(input_read, output_written, .need_input);
                    const expected: usize = std.mem.readInt(u32, self.header[0..4], .big);
                    self.header_len = 0;
                    if (expected == 0) return self.fail(.outer_header, invalidStreamError());
                    const stream_end = std.math.add(usize, self.total_output, expected) catch
                        return self.fail(.outer_header, error.IntegerOverflow);
                    if (stream_end > self.options.max_output_len)
                        return self.fail(.outer_header, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |pledged| if (stream_end > pledged)
                        return self.fail(.outer_header, error.SizeMismatch);
                    self.hadoop_block_expected = expected;
                    self.hadoop_block_decoded = 0;
                    self.phase = .chunk_header;
                }

                if (self.phase == .chunk_header) {
                    if (!self.fillHeader(input, &input_read, 4))
                        return result(input_read, output_written, .need_input);
                    self.compressed_len = std.mem.readInt(u32, self.header[0..4], .big);
                    self.header_len = 0;
                    if (self.compressed_len == 0) return self.fail(.chunk_header, invalidStreamError());
                    if (self.compressed_len > self.options.max_compressed_chunk_len)
                        return self.fail(.chunk_header, error.OutputLimitExceeded);
                    self.compressed.clearRetainingCapacity();
                    try self.compressed.ensureTotalCapacityPrecise(self.budget.allocator(), self.compressed_len);
                    self.phase = .payload;
                }

                if (self.phase == .payload) {
                    const count = @min(self.compressed_len - self.compressed.items.len, input.len - input_read);
                    self.compressed.appendSliceAssumeCapacity(input[input_read..][0..count]);
                    input_read += count;
                    self.input_read += count;
                    if (self.compressed.items.len != self.compressed_len)
                        return result(input_read, output_written, .need_input);
                    self.decodeChunk() catch |err| return self.fail(.payload, err);
                    self.phase = .output;
                }
            }
        }

        fn fillHeader(self: *Self, input: []const u8, input_read: *usize, expected: usize) bool {
            const count = @min(expected - self.header_len, input.len - input_read.*);
            @memcpy(self.header[self.header_len..][0..count], input[input_read.*..][0..count]);
            self.header_len += count;
            input_read.* += count;
            self.input_read += count;
            return self.header_len == expected;
        }

        fn decodeChunk(self: *Self) Error!void {
            const plan = try Codec.planBlock(self.compressed.items);
            const decoded_len = plan.decoded_len;
            if (decoded_len > self.options.max_decoded_chunk_len) return error.OutputLimitExceeded;
            const next_hadoop_block_decoded = if (comptime format == .hadoop) blk: {
                const next = std.math.add(usize, self.hadoop_block_decoded, decoded_len) catch
                    return error.IntegerOverflow;
                if (next > self.hadoop_block_expected) return invalidStreamError();
                break :blk next;
            } else 0;
            const stream_end = std.math.add(usize, self.total_output, decoded_len) catch
                return error.IntegerOverflow;
            if (stream_end > self.options.max_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |pledged| if (stream_end > pledged)
                return error.SizeMismatch;
            if (self.cursor) |*cursor| cursor.reset(plan) else self.cursor = Codec.BlockCursor.init(plan);
            self.current_decoded_len = decoded_len;
            self.required_history_len = plan.max_offset;
            if (comptime format == .hadoop)
                self.hadoop_block_decoded = next_hadoop_block_decoded;
            self.chunk_count = std.math.add(usize, self.chunk_count, 1) catch return error.IntegerOverflow;
        }

        fn emptyPlan() Codec.BlockPlan {
            return .{ .decoded_len = 0, .body_offset = 0, .max_offset = 0 };
        }

        fn advanceAfterChunk(self: *Self) Error!void {
            if (comptime format == .hadoop) {
                if (self.hadoop_block_decoded == self.hadoop_block_expected) {
                    self.hadoop_block_expected = 0;
                    self.hadoop_block_decoded = 0;
                    self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
                    self.phase = .outer_header;
                } else {
                    self.phase = .chunk_header;
                }
            } else {
                self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
                self.phase = .chunk_header;
            }
        }

        fn complete(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected| {
                if (self.total_output != expected) return self.fail(self.phase, error.SizeMismatch);
            }
            self.phase = .done;
        }

        fn invalidStreamError() Error {
            return Codec.invalidStreamError(format);
        }

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            self.error_input_offset = self.input_read;
            self.error_output_offset = self.total_output;
            return err;
        }

        fn clearError(self: *Self) void {
            self.last_error_name = "";
            self.last_error_phase = initialPhase();
            self.error_input_offset = null;
            self.error_output_offset = null;
        }

        fn initialPhase() Phase {
            return if (comptime format == .xerial) .stream_header else .outer_header;
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
