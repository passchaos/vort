const std = @import("std");
const core = @import("../../core.zig");
const working = @import("../../io/working_allocator.zig");

/// Allocator-owning facade for the true symbol-progressive Brotli decoder.
/// It owns the bounded history ring and, only for an entropy header larger than
/// the embedded capacity, bounded grow-on-demand header scratch. Compressed
/// input and decoded output remain caller-provided on every step.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        budget: working.WorkingAllocator,
        history: std.ArrayList(u8) = .empty,
        compressed_header: std.ArrayList(u8) = .empty,
        progressive: ?Codec.ProgressiveDecoder = null,
        window_prefix: [2]u8 = undefined,
        window_prefix_len: u2 = 0,
        window_prefix_offset: u2 = 0,
        decode_options_validated: bool = false,
        history_capped: bool = false,
        phase: Phase = .input,
        last_status: core.StepResult.Status = .need_input,
        frame_input_read: usize = 0,
        frame_output_written: usize = 0,
        total_compressed: usize = 0,
        total_output: usize = 0,
        frame_count: usize = 0,
        input_finished: bool = false,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .input,
        fatal_error: ?Error = null,
        error_input_offset: ?usize = null,
        error_output_offset: ?usize = null,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_compressed_len: usize = std.math.maxInt(usize),
            expected_compressed_len: ?usize = null,
            max_output_len: usize = std.math.maxInt(usize),
            /// Cap on total decoded output across nextFrame calls. Only reset
            /// or resetWithOptions begins a new operation.
            max_total_output_len: usize = std.math.maxInt(usize),
            /// Live requested heap bytes, including retained capacities and
            /// old/new buffers simultaneously alive during replacement. Inline
            /// state and caller-owned dictionaries and scratch are excluded.
            max_working_memory: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            /// Maximum owned history. The default covers every RFC 7932
            /// window; Large Window streams may opt into a larger bound.
            max_history_len: usize = (@as(usize, 1) << 24) - 16,
            /// Maximum header bytes the owned facade may allocate on demand.
            /// The embedded 16 KiB remains available even when this is lower;
            /// raise the bound for unusually large but legal entropy headers.
            max_compressed_header_len: usize = 1024 * 1024,
            decode: Codec.DecodeOptions = .{},
            compressed_header_scratch: []u8 = &.{},
            metadata_output: []u8 = &.{},
            metadata_block_lengths: []usize = &.{},
            allow_trailing_data: bool = false,
        };
        pub const Phase = enum { input, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            compressed_bytes: usize,
            expected_compressed_len: ?usize,
            output_written: usize,
            expected_output_len: ?usize,
            payload_remaining: usize,
            retained_input_bytes: usize,
            compressed_header_capacity: usize,
            owned_compressed_header_capacity: usize,
            history_bytes: usize,
            history_capacity: usize,
            total_compressed: usize,
            total_output: usize,
            frame_count: usize,
            frame_index: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
            trailing_input_bytes: usize,
            working_bytes: usize,
            peak_working_bytes: usize,
            error_input_offset: ?usize,
            error_output_offset: ?usize,
            last_step_progress: core.Progress,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory) };
        }

        pub fn initExactCompressedSize(allocator: std.mem.Allocator, options: Options, expected_compressed_len: usize) Self {
            var exact = options;
            exact.expected_compressed_len = expected_compressed_len;
            return initWithOptions(allocator, exact);
        }

        pub fn deinit(self: *Self) void {
            self.deinitBuffers();
            self.* = undefined;
        }

        fn deinitBuffers(self: *Self) void {
            self.progressive = null;
            self.history.deinit(self.budget.allocator());
            self.compressed_header.deinit(self.budget.allocator());
            std.debug.assert(self.budget.live == 0);
        }

        /// Retain allocations and start a new operation with the current caps.
        pub fn reset(self: *Self) void {
            self.total_compressed = 0;
            self.total_output = 0;
            self.frame_count = 0;
            self.budget.peak = self.budget.live;
            self.budget.hit_limit = false;
            self.budget.last_failure_was_limit = false;
            self.resetFrame(self.options);
        }

        /// Explicit reconfiguration releases retained memory, allowing a lower
        /// working cap, and starts a new operation. Validation is transactional.
        pub fn resetWithOptions(self: *Self, options: Options) Error!void {
            try Codec.validateDecodeOptions(options.decode);
            const allocator = self.allocator;
            self.deinitBuffers();
            self.* = initWithOptions(allocator, options);
        }

        pub fn workingMemoryBytes(self: *const Self) usize {
            return self.budget.live;
        }

        pub fn peakWorkingMemoryBytes(self: *const Self) usize {
            return self.budget.peak;
        }

        fn resetFrame(self: *Self, options: Options) void {
            const allocator = self.allocator;
            var history = self.history;
            history.clearRetainingCapacity();
            const compressed_header = self.compressed_header;
            const total_compressed = self.total_compressed;
            const total_output = self.total_output;
            const frame_count = self.frame_count;
            var budget = self.budget;
            budget.limit = options.max_working_memory;
            self.* = .{
                .allocator = allocator,
                .options = options,
                .budget = budget,
                .history = history,
                .compressed_header = compressed_header,
                .total_compressed = total_compressed,
                .total_output = total_output,
                .frame_count = frame_count,
            };
        }

        /// Frame settings may change, while operation caps may only tighten.
        /// A cap below retained live memory is rejected without changing state.
        pub fn nextFrame(self: *Self, options: Options) Error!void {
            if (self.fatal_error) |err| return err;
            if (self.phase != .done) return error.InvalidBlockPlan;
            var next = options;
            next.max_working_memory = @min(self.options.max_working_memory, next.max_working_memory);
            next.max_total_output_len = @min(self.options.max_total_output_len, next.max_total_output_len);
            if (self.budget.live > next.max_working_memory) return error.WorkingMemoryLimitExceeded;
            if (self.total_output > next.max_total_output_len) return error.OutputLimitExceeded;
            self.resetFrame(next);
        }

        pub fn nextFrameExactCompressedSize(self: *Self, options: Options, expected_compressed_len: usize) Error!void {
            var exact = options;
            exact.expected_compressed_len = expected_compressed_len;
            return self.nextFrame(exact);
        }

        pub fn snapshot(self: *const Self) Snapshot {
            const inner = if (self.progressive) |*decoder| decoder.snapshot() else null;
            return .{
                .phase = self.phase,
                .compressed_bytes = self.frame_input_read,
                .expected_compressed_len = self.options.expected_compressed_len,
                .output_written = self.frame_output_written,
                .expected_output_len = self.options.expected_output_len,
                .payload_remaining = if (inner) |snap| snap.payload_remaining else self.options.expected_output_len orelse 0,
                .retained_input_bytes = if (inner) |snap| snap.retained_input_bytes else 0,
                .compressed_header_capacity = if (inner) |snap|
                    snap.compressed_header_capacity
                else
                    Codec.ProgressiveDecoder.embedded_compressed_header_capacity,
                .owned_compressed_header_capacity = self.compressed_header.capacity,
                .history_bytes = if (inner) |snap| snap.history_bytes else 0,
                .history_capacity = self.history.capacity,
                .total_compressed = self.total_compressed + if (self.phase == .done) 0 else self.frame_input_read,
                .total_output = self.total_output + if (self.phase == .done) 0 else self.frame_output_written,
                .frame_count = self.frame_count,
                .frame_index = if (self.phase == .done and self.frame_count != 0) self.frame_count - 1 else self.frame_count,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
                .trailing_input_bytes = self.trailingInput().len,
                .working_bytes = self.budget.live,
                .peak_working_bytes = self.budget.peak,
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
                .last_step_progress = self.last_step_progress,
            };
        }

        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .input_read = snap.total_compressed,
                .error_input_offset = snap.error_input_offset,
                .error_output_offset = snap.error_output_offset,
                .last_step_progress = snap.last_step_progress,
                .frame_input_read = snap.compressed_bytes,
                .output_written = snap.output_written,
                .expected_output_len = snap.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.WorkingMemoryLimitExceeded))) "raise_working_memory_limit" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutputLimitExceeded))) "raise_output_limit" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.last_step_progress = .{};
            if (self.fatal_error) |err| return err;
            const before_input = self.frame_input_read;
            const before_output = self.frame_output_written;
            const stepped = self.stepImpl(input, output) catch |original| {
                const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit)
                    error.WorkingMemoryLimitExceeded
                else
                    original;
                self.last_step_progress = .{
                    .input_read = self.frame_input_read - before_input,
                    .output_written = self.frame_output_written - before_output,
                };
                self.publishFailure(err);
                return err;
            };
            self.last_step_progress = stepped.progress;
            return stepped;
        }

        fn stepImpl(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.phase == .done) {
                if (input.len != 0 and !self.options.allow_trailing_data)
                    return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
            }
            if (self.options.expected_output_len) |expected| {
                if (expected > self.options.max_output_len or expected > self.options.max_total_output_len -| self.total_output)
                    return self.fail(.input, error.OutputLimitExceeded);
            }
            if (!self.decode_options_validated) {
                Codec.validateDecodeOptions(self.options.decode) catch |err|
                    return self.fail(.input, err);
                self.decode_options_validated = true;
            }
            if (self.input_finished and input.len != 0) return self.fail(self.phase, error.TrailingData);
            if (self.options.expected_compressed_len) |expected| {
                if (self.frame_input_read > expected or input.len > expected - self.frame_input_read)
                    return self.fail(.input, error.SizeMismatch);
            }
            const offered_end = std.math.add(usize, self.frame_input_read, input.len) catch
                return self.fail(.input, error.IntegerOverflow);
            _ = std.math.add(usize, self.total_compressed, offered_end) catch
                return self.fail(.input, error.IntegerOverflow);
            if (offered_end > self.options.max_compressed_len)
                return self.fail(.input, error.OutputLimitExceeded);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.progressive == null) {
                    while (input_read < input.len and self.window_prefix_len < self.window_prefix.len) {
                        self.window_prefix[self.window_prefix_len] = input[input_read];
                        self.window_prefix_len += 1;
                        input_read += 1;
                        const ready = self.prepareProgressive() catch |err|
                            return self.failWithProgress(.input, err, input_read, output_written);
                        if (ready) break;
                    }
                    if (self.progressive == null) {
                        if (self.window_prefix_len == self.window_prefix.len)
                            return self.failWithProgress(.input, error.CorruptFrame, input_read, output_written);
                        return self.completeStep(input_read, output_written, .need_input);
                    }
                }

                if (self.window_prefix_offset < self.window_prefix_len) {
                    const inner = self.stepProgressive(
                        self.window_prefix[self.window_prefix_offset..self.window_prefix_len],
                        output[output_written..],
                        &input_read,
                        &output_written,
                        true,
                    ) catch |err| return self.failWithProgress(self.phase, self.mapHistoryError(err), input_read, output_written);
                    self.window_prefix_offset += @intCast(inner.progress.input_read);
                    output_written += inner.progress.output_written;
                    if (inner.status == .done or inner.status == .need_output)
                        return self.completeStep(input_read, output_written, inner.status);
                    if (self.window_prefix_offset < self.window_prefix_len) {
                        if (inner.progress.input_read == 0 and inner.progress.output_written == 0)
                            return self.failWithProgress(.input, error.CorruptFrame, input_read, output_written);
                        continue;
                    }
                }

                if (input_read == input.len and self.last_status != .need_output and !self.input_finished)
                    return self.completeStep(input_read, output_written, .need_input);
                self.ensureCompressedHeaderCapacity(input.len - input_read) catch |err|
                    return self.failWithProgress(.input, err, input_read, output_written);
                const input_end = input_read + @min(
                    input.len - input_read,
                    self.progressiveInputChunkLen(),
                );
                const inner = self.stepProgressive(
                    input[input_read..input_end],
                    output[output_written..],
                    &input_read,
                    &output_written,
                    false,
                ) catch |err| return self.failWithProgress(self.phase, self.mapHistoryError(err), input_read, output_written);
                input_read += inner.progress.input_read;
                output_written += inner.progress.output_written;
                if (inner.status == .need_input and input_read < input.len) {
                    if (inner.progress.input_read == 0 and inner.progress.output_written == 0)
                        return self.failWithProgress(.input, error.CorruptFrame, input_read, output_written);
                    continue;
                }
                return self.completeStep(input_read, output_written, inner.status);
            }
        }

        pub fn finish(self: *Self) Error!void {
            self.last_step_progress = .{};
            if (self.fatal_error) |err| return err;
            self.finishImpl() catch |original| {
                const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit)
                    error.WorkingMemoryLimitExceeded
                else
                    original;
                self.publishFailure(err);
                return err;
            };
        }

        fn finishImpl(self: *Self) Error!void {
            if (self.phase == .done) return;
            if (self.options.expected_compressed_len) |expected| {
                if (self.frame_input_read != expected) return self.fail(.input, error.SizeMismatch);
            }
            self.input_finished = true;
            if (self.last_status == .need_output) return;
            const ready = self.prepareProgressive() catch |err| return self.fail(.input, err);
            if (!ready) return self.fail(.input, error.TruncatedFrame);
            while (self.window_prefix_offset < self.window_prefix_len) {
                const inner = self.progressive.?.step(
                    self.window_prefix[self.window_prefix_offset..self.window_prefix_len],
                    &.{},
                ) catch |err| return self.fail(.input, self.mapHistoryError(err));
                self.window_prefix_offset += @intCast(inner.progress.input_read);
                if (inner.status == .need_output) return;
                if (inner.status == .done) {
                    self.phase = .done;
                    self.commitFrame();
                    return;
                }
                if (inner.progress.input_read == 0 and inner.progress.output_written == 0)
                    return self.fail(.input, error.TruncatedFrame);
            }
            self.progressive.?.finish() catch |err| return self.fail(self.phase, self.mapHistoryError(err));
            if (self.progressive.?.snapshot().phase == .done) {
                self.phase = .done;
                self.commitFrame();
            }
        }

        pub fn trailingInput(self: *const Self) []const u8 {
            return if (self.progressive) |*decoder| decoder.trailingInput() else &.{};
        }

        fn prepareProgressive(self: *Self) Error!bool {
            if (self.progressive != null) return true;
            const output_bound = @min(
                self.options.expected_output_len orelse self.options.max_output_len,
                self.options.max_total_output_len -| self.total_output,
            );
            const plan = (try Codec.historyPlanFromPrefix(
                self.window_prefix[0..self.window_prefix_len],
                output_bound,
                self.options.max_history_len,
                self.options.decode,
            )) orelse return false;
            try self.history.ensureTotalCapacityPrecise(self.budget.allocator(), plan.allocation_len);
            self.history.items.len = plan.allocation_len;
            self.history_capped = plan.capped;
            const header_limit = self.compressedHeaderLimit();
            const header_scratch: []u8 = if (self.options.compressed_header_scratch.len >
                Codec.ProgressiveDecoder.embedded_compressed_header_capacity)
                self.options.compressed_header_scratch[0..@min(
                    self.options.compressed_header_scratch.len,
                    header_limit,
                )]
            else if (self.compressed_header.items.len >
                Codec.ProgressiveDecoder.embedded_compressed_header_capacity)
                self.compressed_header.items[0..@min(
                    self.compressed_header.items.len,
                    header_limit,
                )]
            else
                self.history.items[0..0];
            self.progressive = Codec.ProgressiveDecoder.initWithOptions(self.history.items, .{
                .max_output_len = self.options.max_output_len,
                .max_total_output_len = self.options.max_total_output_len -| self.total_output,
                .expected_output_len = self.options.expected_output_len,
                .decode = self.options.decode,
                .compressed_header_scratch = header_scratch,
                .metadata_output = self.options.metadata_output,
                .metadata_block_lengths = self.options.metadata_block_lengths,
                .allow_trailing_data = self.options.allow_trailing_data,
            });
            return true;
        }

        const progressive_input_chunk_len: usize = 4096;

        fn compressedHeaderLimit(self: *const Self) usize {
            return @max(
                Codec.ProgressiveDecoder.embedded_compressed_header_capacity,
                self.options.max_compressed_header_len,
            );
        }

        fn progressiveInputChunkLen(self: *const Self) usize {
            const snap = self.progressive.?.snapshot();
            if (snap.phase != .compressed_header) return progressive_input_chunk_len;
            return @min(progressive_input_chunk_len, snap.compressed_header_capacity - snap.retained_input_bytes);
        }

        fn ensureCompressedHeaderCapacity(self: *Self, available_input: usize) Error!void {
            const decoder = if (self.progressive) |*value| value else return;
            const snap = decoder.snapshot();
            if (snap.phase != .compressed_header or available_input == 0) return;
            // The caller chunk never exceeds available header storage. Grow
            // only after the parser has actually exhausted its current buffer,
            // so offered payload bytes cannot falsely exhaust a header bound.
            if (snap.retained_input_bytes < snap.compressed_header_capacity) return;
            const limit = self.compressedHeaderLimit();
            if (snap.compressed_header_capacity >= limit) return error.OutputLimitExceeded;
            const doubled = std.math.mul(usize, snap.compressed_header_capacity, 2) catch limit;
            const target = @min(limit, doubled);
            var replacement: std.ArrayList(u8) = .empty;
            const allocator = self.budget.allocator();
            errdefer replacement.deinit(allocator);
            try replacement.ensureTotalCapacityPrecise(allocator, target);
            replacement.items.len = target;
            try decoder.replaceCompressedHeaderScratch(replacement.items);
            self.compressed_header.deinit(allocator);
            self.compressed_header = replacement;
        }

        fn stepProgressive(self: *Self, input: []const u8, output: []u8, input_read: *usize, output_written: *usize, prefix: bool) Error!core.StepResult {
            const before = self.progressive.?.snapshot();
            return self.progressive.?.step(input, output) catch |err| {
                const after = self.progressive.?.snapshot();
                const consumed = after.input_read - before.input_read;
                if (prefix) {
                    // These prefix bytes already belong to the outer cursor.
                    self.window_prefix_offset += @intCast(consumed);
                } else {
                    input_read.* += consumed;
                }
                output_written.* += after.output_written - before.output_written;
                return self.mapHistoryError(err);
            };
        }

        fn mapHistoryError(self: *const Self, err: Error) Error {
            return if (self.history_capped and err == error.InvalidMatch)
                error.OutputLimitExceeded
            else
                err;
        }

        fn completeStep(self: *Self, input_read: usize, output_written: usize, initial_status: core.StepResult.Status) Error!core.StepResult {
            self.frame_input_read += input_read;
            self.frame_output_written += output_written;
            var status = initial_status;
            if (self.options.expected_compressed_len) |expected| {
                if (self.frame_input_read == expected) self.input_finished = true;
                if (status == .done and self.frame_input_read != expected)
                    return self.fail(.done, error.SizeMismatch);
            }
            if (self.input_finished and status == .need_input) {
                self.progressive.?.finish() catch |err| return self.fail(.input, self.mapHistoryError(err));
                status = .done;
            }
            self.last_status = status;
            self.phase = switch (status) {
                .need_input => .input,
                .need_output => .output,
                .done => .done,
            };
            if (status == .done) self.commitFrame();
            return result(input_read, output_written, status);
        }

        fn failWithProgress(self: *Self, phase: Phase, err: Error, input_read: usize, output_written: usize) Error {
            self.frame_input_read += input_read;
            self.frame_output_written += output_written;
            return self.fail(phase, err);
        }

        fn commitFrame(self: *Self) void {
            self.total_compressed += self.frame_input_read;
            self.total_output += self.frame_output_written;
            self.frame_count += 1;
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }

        fn publishFailure(self: *Self, err: Error) void {
            self.fatal_error = err;
            self.last_error_name = @errorName(err);
            self.error_input_offset = self.snapshot().total_compressed;
            self.error_output_offset = self.snapshot().total_output;
        }

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
    };
}
