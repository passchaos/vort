const std = @import("std");
const core = @import("../../core.zig");

/// Build a split-input Brotli decoder facade. Input is accumulated under an
/// explicit bound; `finish` performs the codec's complete validation/decode
/// pass, after which output can be drained in arbitrary caller-owned chunks.
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
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .input,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_compressed_len: usize = std.math.maxInt(usize),
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
        };
        pub const Phase = enum { input, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            compressed_bytes: usize,
            output_written: usize,
            expected_output_len: ?usize,
            payload_remaining: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn deinit(self: *Self) void {
            self.compressed.deinit(self.allocator);
            self.decoded.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const allocator = self.allocator;
            const options = self.options;
            var compressed = self.compressed;
            var decoded = self.decoded;
            compressed.clearRetainingCapacity();
            decoded.clearRetainingCapacity();
            self.* = .{ .allocator = allocator, .options = options, .compressed = compressed, .decoded = decoded };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .compressed_bytes = self.compressed.items.len,
                .output_written = self.decoded_offset,
                .expected_output_len = if (self.phase == .input) self.options.expected_output_len else self.decoded.items.len,
                .payload_remaining = self.decoded.items.len - self.decoded_offset,
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
            switch (self.phase) {
                .input => {
                    const total = std.math.add(usize, self.compressed.items.len, input.len) catch return self.fail(.input, error.IntegerOverflow);
                    if (total > self.options.max_compressed_len) return self.fail(.input, error.OutputLimitExceeded);
                    try self.compressed.appendSlice(self.allocator, input);
                    return .{ .progress = .{ .input_read = input.len }, .status = .need_input };
                },
                .output => {
                    if (input.len != 0) return self.fail(.output, error.TrailingData);
                    const remaining = self.decoded.items[self.decoded_offset..];
                    const n = @min(output.len, remaining.len);
                    @memcpy(output[0..n], remaining[0..n]);
                    self.decoded_offset += n;
                    if (self.decoded_offset == self.decoded.items.len) self.phase = .done;
                    return .{
                        .progress = .{ .output_written = n },
                        .status = if (self.phase == .done) .done else .need_output,
                    };
                },
                .done => {
                    if (input.len != 0) return self.fail(.done, error.TrailingData);
                    return .{ .status = .done };
                },
            }
        }

        pub fn finish(self: *Self) Error!void {
            if (self.phase != .input) return;
            const decoded_len = Codec.decodedSizeLimited(self.compressed.items, self.options.max_output_len) catch |err| return self.fail(.input, err);
            if (self.options.expected_output_len) |expected| {
                if (decoded_len != expected) return self.fail(.input, error.SizeMismatch);
            }
            try self.decoded.resize(self.allocator, decoded_len);
            const written = Codec.decodeInto(self.compressed.items, self.decoded.items) catch |err| {
                self.decoded.clearRetainingCapacity();
                return self.fail(.input, err);
            };
            if (written != decoded_len) return self.fail(.input, error.SizeMismatch);
            self.phase = if (decoded_len == 0) .done else .output;
        }

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
    };
}
