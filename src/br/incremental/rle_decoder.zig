const std = @import("std");
const core = @import("../../core.zig");

/// Byte-progressive decoder for the single-command compressed RLE streams
/// emitted by Vort. Only the bounded encoded header is retained. Once it has
/// been validated, decoded bytes are produced directly into caller buffers,
/// so neither compressed payload nor decompressed output scales with run size.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        phase: Phase = .header,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        staged_bits: u64 = 0,
        staged_bit_count: u6 = 0,
        repeated_byte: u8 = 0,
        output_remaining: usize = 0,
        stream_bits: usize = 0,
        total_input: usize = 0,
        total_output: usize = 0,
        finished: bool = false,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
        };
        pub const Phase = enum { header, payload, padding, done };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: usize,
            output_written: usize,
            payload_remaining: usize,
            retained_input_bytes: usize,
            expected_output_len: ?usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init() Self {
            return initWithOptions(.{});
        }
        pub fn initWithOptions(options: Options) Self {
            return .{ .options = options };
        }
        pub fn reset(self: *Self) void {
            self.* = .{ .options = self.options };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = self.output_remaining,
                .retained_input_bytes = self.header_len,
                .expected_output_len = self.options.expected_output_len,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .frame_input_read = snap.input_read,
                .output_written = snap.output_written,
                .expected_output_len = snap.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
            self.finished = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.finished) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return result(0, 0, .done);
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) switch (self.phase) {
                .header => {
                    while (input_read < input.len) {
                        if (self.header_len == self.header_bytes.len)
                            return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_bytes[self.header_len] = input[input_read];
                        self.header_len += 1;
                        input_read += 1;
                        self.total_input += 1;

                        const parsed = Codec.parseHeader(self.header_bytes[0..self.header_len]) catch |err| switch (err) {
                            error.TruncatedFrame => continue,
                            else => return self.fail(.header, err),
                        };
                        if (parsed.header.decoded_len > self.options.max_output_len)
                            return self.fail(.header, error.OutputLimitExceeded);
                        if (self.options.expected_output_len) |expected|
                            if (parsed.header.decoded_len != expected) return self.fail(.header, error.SizeMismatch);

                        const byte_index = parsed.bits_read / 8;
                        const bit_index: u3 = @intCast(parsed.bits_read % 8);
                        const available_bits = self.header_len * 8 - parsed.bits_read;
                        if (available_bits > 63) return self.fail(.header, error.CorruptFrame);
                        self.staged_bits = if (available_bits == 0) 0 else @as(u64, self.header_bytes[byte_index]) >> bit_index;
                        self.staged_bit_count = @intCast(available_bits);
                        self.repeated_byte = parsed.header.repeated_byte;
                        self.output_remaining = parsed.header.decoded_len;
                        self.stream_bits = parsed.bits_read;
                        self.phase = .payload;
                        break;
                    }
                    if (self.phase == .header) return result(input_read, output_written, .need_input);
                },
                .payload => {
                    const n = @min(output.len - output_written, self.output_remaining);
                    @memset(output[output_written..][0..n], self.repeated_byte);
                    output_written += n;
                    self.total_output += n;
                    self.output_remaining -= n;
                    if (self.output_remaining != 0) return result(input_read, output_written, .need_output);
                    self.phase = .padding;
                },
                .padding => {
                    const expected_padding_bits: u3 = @intCast((8 - self.stream_bits % 8) % 8);
                    if (self.staged_bit_count < expected_padding_bits) return result(input_read, output_written, .need_input);
                    if (expected_padding_bits != 0) {
                        const mask = (@as(u64, 1) << expected_padding_bits) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= expected_padding_bits;
                        self.staged_bit_count -= expected_padding_bits;
                    }
                    if (self.staged_bit_count != 0 or input_read != input.len)
                        return self.fail(.padding, error.TrailingData);
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
