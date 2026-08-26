const std = @import("std");
const core = @import("../../core.zig");
const progressive_bits = @import("bit_reader.zig");

/// Progressive decoder for final, single-block-type compressed streams with
/// explicit distances. History is caller-owned, which makes memory use visible
/// and lets overlapping copies resume across arbitrarily small output buffers.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        history: []u8,
        phase: Phase = .header,
        header_bytes: [Codec.max_stream_header_bytes]u8 = undefined,
        header_len: usize = 0,
        header: Codec.Header = undefined,
        staged_bits: u128 = 0,
        staged_bit_count: u8 = 0,
        stream_bits: usize = 0,
        decoded_len: usize = 0,
        pending_literals: usize = 0,
        pending_copy: usize = 0,
        copy_distance: usize = 0,
        implicit_last_distance: bool = false,
        last_distances: [4]usize = .{ 16, 15, 11, 4 },
        previous: [2]u8 = .{ 0, 0 },
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
        pub const Phase = enum { header, command, literals, distance, copy, padding, done };
        pub const Snapshot = struct {
            phase: Phase,
            input_read: usize,
            output_written: usize,
            payload_remaining: usize,
            pending_literals: usize,
            pending_copy: usize,
            retained_input_bytes: usize,
            history_bytes: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(history: []u8) Self {
            return initWithOptions(history, .{});
        }
        pub fn initWithOptions(history: []u8, options: Options) Self {
            return .{ .options = options, .history = history };
        }
        pub fn reset(self: *Self) void {
            const history = self.history;
            const options = self.options;
            self.* = .{ .options = options, .history = history };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .input_read = self.total_input,
                .output_written = self.total_output,
                .payload_remaining = self.decoded_len - self.total_output,
                .pending_literals = self.pending_literals,
                .pending_copy = self.pending_copy,
                .retained_input_bytes = self.header_len,
                .history_bytes = @min(self.total_output, self.history.len),
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
                .expected_output_len = self.options.expected_output_len,
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
            defer self.total_input += input_read;
            while (true) switch (self.phase) {
                .header => {
                    while (input_read < input.len) {
                        if (self.header_len == self.header_bytes.len) return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_bytes[self.header_len] = input[input_read];
                        self.header_len += 1;
                        input_read += 1;
                        const parsed = Codec.parseHeader(self.header_bytes[0..self.header_len]) catch |err| switch (err) {
                            error.TruncatedFrame => continue,
                            else => return self.fail(.header, err),
                        };
                        if (parsed.header.decoded_len > self.options.max_output_len) return self.fail(.header, error.OutputLimitExceeded);
                        if (self.options.expected_output_len) |expected| if (parsed.header.decoded_len != expected) return self.fail(.header, error.SizeMismatch);
                        if (self.history.len == 0) return self.fail(.header, error.OutputTooSmall);
                        const byte_index = parsed.bits_read / 8;
                        const bit_index: u3 = @intCast(parsed.bits_read % 8);
                        const available_bits = self.header_len * 8 - parsed.bits_read;
                        if (available_bits > 127) return self.fail(.header, error.CorruptFrame);
                        self.staged_bits = if (available_bits == 0) 0 else @as(u128, self.header_bytes[byte_index]) >> bit_index;
                        self.staged_bit_count = @intCast(available_bits);
                        self.stream_bits = parsed.bits_read;
                        self.header = parsed.header;
                        self.decoded_len = parsed.header.decoded_len;
                        self.phase = .command;
                        break;
                    }
                    if (self.phase == .header) return result(input_read, output_written, .need_input);
                },
                .command => {
                    if (self.total_output == self.decoded_len) {
                        self.phase = .padding;
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_header = self.header;
                    const command = Codec.readCommand(&self.header, &reader) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            self.header = saved_header;
                            try reader.restoreKeepingInput(saved);
                            return result(input_read, output_written, .need_input);
                        },
                        else => return self.fail(.command, err),
                    };
                    const remaining = self.decoded_len - self.total_output;
                    if (command.insert_len > remaining) return self.fail(.command, error.CorruptFrame);
                    // RFC 7932 ignores the copy half of the final command when
                    // its insert reaches MLEN exactly. Otherwise both spans
                    // must fit before any caller output is mutated.
                    if (command.insert_len < remaining and command.copy_len > remaining - command.insert_len)
                        return self.fail(.command, error.CorruptFrame);
                    self.pending_literals = command.insert_len;
                    self.pending_copy = command.copy_len;
                    self.implicit_last_distance = command.implicit_last_distance;
                    self.phase = if (self.pending_literals == 0) .distance else .literals;
                },
                .literals => {
                    while (self.pending_literals != 0 and output_written < output.len) {
                        var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                        const saved = reader.checkpoint();
                        const saved_header = self.header;
                        const literal = Codec.readLiteral(&self.header, &reader, self.previous[1], self.previous[0]) catch |err| switch (err) {
                            error.TruncatedFrame => {
                                self.header = saved_header;
                                try reader.restoreKeepingInput(saved);
                                return result(input_read, output_written, .need_input);
                            },
                            else => return self.fail(.literals, err),
                        };
                        self.emit(output, &output_written, literal);
                        self.pending_literals -= 1;
                    }
                    if (self.pending_literals != 0) return result(input_read, output_written, .need_output);
                    if (self.total_output == self.decoded_len) {
                        self.pending_copy = 0;
                        self.phase = .padding;
                    } else {
                        self.phase = .distance;
                    }
                },
                .distance => {
                    if (self.implicit_last_distance) {
                        self.copy_distance = self.last_distances[3];
                        self.phase = .copy;
                        continue;
                    }
                    var reader = progressive_bits.Reader.init(input, &input_read, &self.staged_bits, &self.staged_bit_count, &self.stream_bits);
                    const saved = reader.checkpoint();
                    const saved_header = self.header;
                    const decoded = Codec.readDistance(&self.header, &reader, self.pending_copy, &self.last_distances) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            self.header = saved_header;
                            try reader.restoreKeepingInput(saved);
                            return result(input_read, output_written, .need_input);
                        },
                        else => return self.fail(.distance, err),
                    };
                    self.copy_distance = decoded.distance;
                    if (decoded.update_ring) pushLastDistance(&self.last_distances, decoded.distance);
                    self.phase = .copy;
                },
                .copy => {
                    if (self.copy_distance > self.total_output or self.copy_distance > self.history.len) return self.fail(.copy, error.InvalidMatch);
                    while (self.pending_copy != 0 and output_written < output.len) {
                        const source = self.total_output - self.copy_distance;
                        const value = self.history[source % self.history.len];
                        self.emit(output, &output_written, value);
                        self.pending_copy -= 1;
                    }
                    if (self.pending_copy != 0) return result(input_read, output_written, .need_output);
                    self.phase = .command;
                },
                .padding => {
                    const padding_bits: u8 = @intCast((8 - self.stream_bits % 8) % 8);
                    if (self.staged_bit_count < padding_bits) return result(input_read, output_written, .need_input);
                    if (padding_bits != 0) {
                        const mask = (@as(u128, 1) << @intCast(padding_bits)) - 1;
                        if ((self.staged_bits & mask) != 0) return self.fail(.padding, error.CorruptFrame);
                        self.staged_bits >>= @intCast(padding_bits);
                        self.staged_bit_count -= padding_bits;
                    }
                    if (self.staged_bit_count != 0 or input_read != input.len) return self.fail(.padding, error.TrailingData);
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn emit(self: *Self, output: []u8, output_written: *usize, value: u8) void {
            output[output_written.*] = value;
            output_written.* += 1;
            self.history[self.total_output % self.history.len] = value;
            self.previous[0] = self.previous[1];
            self.previous[1] = value;
            self.total_output += 1;
        }
        fn pushLastDistance(last_distances: *[4]usize, distance: usize) void {
            last_distances[0] = last_distances[1];
            last_distances[1] = last_distances[2];
            last_distances[2] = last_distances[3];
            last_distances[3] = distance;
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
