const std = @import("std");
const core = @import("../../core.zig");

/// Build a split-input Brotli decoder facade. Input is accumulated under an
/// explicit bound; `finish`, or reaching a pledged compressed length, performs
/// the codec's complete validation/decode pass, after which output can be
/// drained in arbitrary caller-owned chunks.
/// Keeping this state machine independent lets the future byte-progressive
/// Brotli core replace only the narrow Codec interface.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        phase: Phase = .input,
        compressed: std.ArrayList(u8) = .empty,
        decoded: std.ArrayList(u8) = .empty,
        decoded_offset: usize = 0,
        total_compressed: usize = 0,
        total_output: usize = 0,
        frame_count: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .input,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_compressed_len: usize = std.math.maxInt(usize),
            /// When present, reaching this many compressed bytes completes the
            /// input side automatically. This is useful for framed transports
            /// that already carry a Brotli payload length and avoids a separate
            /// `finish` call at an otherwise known boundary.
            expected_compressed_len: ?usize = null,
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            decode: Codec.DecodeOptions = .{},
        };
        pub const Phase = enum { input, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            compressed_bytes: usize,
            expected_compressed_len: ?usize,
            output_written: usize,
            expected_output_len: ?usize,
            payload_remaining: usize,
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
            var exact_options = options;
            exact_options.expected_compressed_len = expected_compressed_len;
            return initWithOptions(allocator, exact_options);
        }
        pub fn deinit(self: *Self) void {
            self.compressed.deinit(self.allocator);
            self.decoded.deinit(self.allocator);
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
            var compressed = self.compressed;
            var decoded = self.decoded;
            compressed.clearRetainingCapacity();
            decoded.clearRetainingCapacity();
            const total_compressed = self.total_compressed;
            const total_output = self.total_output;
            const frame_count = self.frame_count;
            self.* = .{
                .allocator = allocator,
                .options = options,
                .compressed = compressed,
                .decoded = decoded,
                .total_compressed = total_compressed,
                .total_output = total_output,
                .frame_count = frame_count,
            };
        }
        /// Reuse allocations for another independently framed Brotli payload.
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
            return .{
                .phase = self.phase,
                .compressed_bytes = self.compressed.items.len,
                .expected_compressed_len = self.options.expected_compressed_len,
                .output_written = self.decoded_offset,
                .expected_output_len = if (self.phase == .input) self.options.expected_output_len else self.decoded.items.len,
                .payload_remaining = self.decoded.items.len - self.decoded_offset,
                .total_compressed = self.total_compressed + if (self.phase == .done) 0 else self.compressed.items.len,
                .total_output = self.total_output + if (self.phase == .done) 0 else self.decoded_offset,
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
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) switch (self.phase) {
                .input => {
                    if (self.options.expected_compressed_len) |expected| {
                        if (self.compressed.items.len > expected) return self.fail(.input, error.SizeMismatch);
                        const remaining = expected - self.compressed.items.len;
                        if (input.len > remaining) return self.fail(.input, error.SizeMismatch);
                    }
                    const total = std.math.add(usize, self.compressed.items.len, input.len) catch return self.fail(.input, error.IntegerOverflow);
                    if (total > self.options.max_compressed_len) return self.fail(.input, error.OutputLimitExceeded);
                    try self.compressed.appendSlice(self.allocator, input);
                    input_read = input.len;
                    if (self.options.expected_compressed_len) |expected| {
                        if (total == expected) {
                            try self.completeInput();
                            continue;
                        }
                    }
                    return result(input_read, output_written, .need_input);
                },
                .output => {
                    if (input_read != input.len) return self.fail(.output, error.TrailingData);
                    const remaining = self.decoded.items[self.decoded_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.decoded_offset += n;
                    output_written += n;
                    if (self.decoded_offset == self.decoded.items.len) {
                        self.phase = .done;
                        self.total_compressed += self.compressed.items.len;
                        self.total_output += self.decoded.items.len;
                        self.frame_count += 1;
                    }
                    return result(input_read, output_written, if (self.phase == .done) .done else .need_output);
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        pub fn finish(self: *Self) Error!void {
            if (self.phase != .input) return;
            if (self.options.expected_compressed_len) |expected| {
                if (self.compressed.items.len != expected) return self.fail(.input, error.SizeMismatch);
            }
            try self.completeInput();
        }

        fn completeInput(self: *Self) Error!void {
            const decoded_len = Codec.decodedSizeLimited(self.compressed.items, self.options.max_output_len, self.options.decode) catch |err| return self.fail(.input, err);
            if (self.options.expected_output_len) |expected| {
                if (decoded_len != expected) return self.fail(.input, error.SizeMismatch);
            }
            try self.decoded.resize(self.allocator, decoded_len);
            const written = Codec.decodeInto(self.compressed.items, self.decoded.items, self.options.decode) catch |err| {
                self.decoded.clearRetainingCapacity();
                return self.fail(.input, err);
            };
            if (written != decoded_len) return self.fail(.input, error.SizeMismatch);
            if (decoded_len == 0) {
                self.phase = .done;
                self.total_compressed += self.compressed.items.len;
                self.frame_count += 1;
            } else {
                self.phase = .output;
            }
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
