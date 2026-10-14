const std = @import("std");
const core = @import("../../core.zig");

/// Allocator-owning facade for the true symbol-progressive Brotli decoder.
/// Only the bounded history ring is owned here; compressed input and decoded
/// output remain caller-provided on every step.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        history: std.ArrayList(u8) = .empty,
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

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_compressed_len: usize = std.math.maxInt(usize),
            expected_compressed_len: ?usize = null,
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            /// Maximum owned history. The default covers every RFC 7932
            /// window; Large Window streams may opt into a larger bound.
            max_history_len: usize = (@as(usize, 1) << 24) - 16,
            decode: Codec.DecodeOptions = .{},
            compressed_header_scratch: []u8 = &.{},
            metadata_output: []u8 = &.{},
            metadata_block_lengths: []usize = &.{},
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
            history_bytes: usize,
            history_capacity: usize,
            total_compressed: usize,
            total_output: usize,
            frame_count: usize,
            frame_index: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }

        pub fn initExactCompressedSize(allocator: std.mem.Allocator, options: Options, expected_compressed_len: usize) Self {
            var exact = options;
            exact.expected_compressed_len = expected_compressed_len;
            return initWithOptions(allocator, exact);
        }

        pub fn deinit(self: *Self) void {
            self.history.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn reset(self: *Self) void {
            self.total_compressed = 0;
            self.total_output = 0;
            self.frame_count = 0;
            self.resetFrame(self.options);
        }

        fn resetFrame(self: *Self, options: Options) void {
            const allocator = self.allocator;
            var history = self.history;
            history.clearRetainingCapacity();
            const total_compressed = self.total_compressed;
            const total_output = self.total_output;
            const frame_count = self.frame_count;
            self.* = .{
                .allocator = allocator,
                .options = options,
                .history = history,
                .total_compressed = total_compressed,
                .total_output = total_output,
                .frame_count = frame_count,
            };
        }

        pub fn nextFrame(self: *Self, options: Options) Error!void {
            if (self.phase != .done) return error.InvalidBlockPlan;
            self.resetFrame(options);
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
                .history_bytes = if (inner) |snap| snap.history_bytes else 0,
                .history_capacity = self.history.items.len,
                .total_compressed = self.total_compressed + if (self.phase == .done) 0 else self.frame_input_read,
                .total_output = self.total_output + if (self.phase == .done) 0 else self.frame_output_written,
                .frame_count = self.frame_count,
                .frame_index = if (self.phase == .done and self.frame_count != 0) self.frame_count - 1 else self.frame_count,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }

        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .frame_input_read = snap.compressed_bytes,
                .output_written = snap.output_written,
                .expected_output_len = snap.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.phase == .done) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
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
                    const inner = self.progressive.?.step(
                        self.window_prefix[self.window_prefix_offset..self.window_prefix_len],
                        output[output_written..],
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
                const inner = self.progressive.?.step(
                    input[input_read..],
                    output[output_written..],
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

        fn prepareProgressive(self: *Self) Error!bool {
            if (self.progressive != null) return true;
            const output_bound = self.options.expected_output_len orelse self.options.max_output_len;
            const plan = (try Codec.historyPlanFromPrefix(
                self.window_prefix[0..self.window_prefix_len],
                output_bound,
                self.options.max_history_len,
                self.options.decode,
            )) orelse return false;
            try self.history.resize(self.allocator, plan.allocation_len);
            self.history_capped = plan.capped;
            self.progressive = Codec.ProgressiveDecoder.initWithOptions(self.history.items, .{
                .max_output_len = self.options.max_output_len,
                .expected_output_len = self.options.expected_output_len,
                .decode = self.options.decode,
                .compressed_header_scratch = self.options.compressed_header_scratch,
                .metadata_output = self.options.metadata_output,
                .metadata_block_lengths = self.options.metadata_block_lengths,
            });
            return true;
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

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
    };
}
