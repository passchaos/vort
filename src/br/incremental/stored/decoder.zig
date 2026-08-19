const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive decoder for the Brotli stored/uncompressed subset emitted
/// by Vort. Only a bounded header prefix is retained; aligned meta-block bytes
/// stream directly from caller input to caller output. Metadata is skipped
/// without buffering. Compressed meta-blocks return UnsupportedBrotliFeature so
/// callers can choose the general incremental facade instead.
pub const Decoder = struct {
    options: Options,
    phase: Phase = .window,
    window_state: WindowState = .first,
    header_state: HeaderState = .is_last,
    length_width: u6 = 0,
    staged: u64 = 0,
    staged_bits: u6 = 0,
    payload_remaining: usize = 0,
    metadata: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .window,

    pub const Error = core.Error;
    pub const Options = struct { max_output_len: usize = std.math.maxInt(usize) };
    pub const Phase = enum { window, header, payload, done };
    const WindowState = enum { first, low3, tail };
    const HeaderState = enum { is_last, last_empty, nibbles, metadata_reserved, metadata_count, metadata_len, block_len, uncompressed, padding };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        payload_remaining: usize,
        metadata: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init() Decoder {
        return initWithOptions(.{});
    }
    pub fn initWithOptions(options: Options) Decoder {
        return .{ .options = options };
    }
    pub fn reset(self: *Decoder) void {
        self.* = .{ .options = self.options };
    }
    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .payload_remaining = self.payload_remaining,
            .metadata = self.metadata,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .frame_input_read = snap.input_read,
            .output_written = snap.output_written,
            .payload_remaining = snap.payload_remaining,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.UnsupportedBrotliFeature))) "unsupported_feature" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
        };
    }

    pub fn finish(self: *Decoder) Error!void {
        if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        self.finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.finished) {
            if (input.len != 0) return self.fail(.done, error.TrailingData);
            return .{ .status = .done };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.phase == .payload) {
                const available_output = if (self.metadata) self.payload_remaining else output.len - output_written;
                const n = @min(self.payload_remaining, @min(input.len - input_read, available_output));
                if (!self.metadata) {
                    @memcpy(output[output_written..][0..n], input[input_read..][0..n]);
                    output_written += n;
                    self.total_output += n;
                }
                input_read += n;
                self.total_input += n;
                self.payload_remaining -= n;
                if (self.payload_remaining != 0) {
                    return result(input_read, output_written, if (!self.metadata and output_written == output.len) .need_output else .need_input);
                }
                self.metadata = false;
                self.phase = .header;
            }

            if (self.phase == .done) {
                if (input_read != input.len) return self.fail(.done, error.TrailingData);
                return result(input_read, output_written, .done);
            }

            if (self.phase == .window) {
                switch (self.window_state) {
                    .first => {
                        const first = self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (first == 0) {
                            self.phase = .header;
                        } else {
                            self.window_state = .low3;
                            continue;
                        }
                    },
                    .low3 => {
                        const low3 = self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                        if (low3 == 0) {
                            self.window_state = .tail;
                            continue;
                        }
                        self.phase = .header;
                    },
                    .tail => {
                        const tail = self.readBits(input, &input_read, 3) orelse return result(input_read, output_written, .need_input);
                        if (tail == 1) return self.fail(.window, error.CorruptFrame);
                        self.phase = .header;
                    },
                }
            }

            if (self.phase == .header) {
                switch (self.header_state) {
                    .is_last => {
                        const is_last = self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        self.header_state = if (is_last != 0) .last_empty else .nibbles;
                        continue;
                    },
                    .last_empty => {
                        const empty = self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (empty == 0) return self.fail(.header, error.UnsupportedBrotliFeature);
                        self.header_state = .padding;
                        self.metadata = false;
                        self.payload_remaining = 0;
                    },
                    .nibbles => {
                        const code = self.readBits(input, &input_read, 2) orelse return result(input_read, output_written, .need_input);
                        if (code == 3) {
                            self.metadata = true;
                            self.header_state = .metadata_reserved;
                        } else {
                            self.metadata = false;
                            self.length_width = @intCast((4 + code) * 4);
                            self.header_state = .block_len;
                        }
                        continue;
                    },
                    .metadata_reserved => {
                        const reserved = self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (reserved != 0) return self.fail(.header, error.CorruptFrame);
                        self.header_state = .metadata_count;
                        continue;
                    },
                    .metadata_count => {
                        const count_bytes = self.readBits(input, &input_read, 2) orelse return result(input_read, output_written, .need_input);
                        self.length_width = @intCast(count_bytes * 8);
                        if (count_bytes == 0) {
                            self.payload_remaining = 0;
                            self.header_state = .padding;
                        } else {
                            self.header_state = .metadata_len;
                        }
                        continue;
                    },
                    .metadata_len => {
                        const len_minus_one = self.readBits(input, &input_read, self.length_width) orelse return result(input_read, output_written, .need_input);
                        const count_bytes = self.length_width / 8;
                        if (count_bytes > 1 and ((len_minus_one >> @intCast((count_bytes - 1) * 8)) & 0xff) == 0) return self.fail(.header, error.CorruptFrame);
                        self.payload_remaining = len_minus_one + 1;
                        self.header_state = .padding;
                    },
                    .block_len => {
                        const len_minus_one = self.readBits(input, &input_read, self.length_width) orelse return result(input_read, output_written, .need_input);
                        const nibbles = self.length_width / 4;
                        if (nibbles > 4 and ((len_minus_one >> @intCast((nibbles - 1) * 4)) & 0xf) == 0) return self.fail(.header, error.CorruptFrame);
                        self.payload_remaining = len_minus_one + 1;
                        self.header_state = .uncompressed;
                        continue;
                    },
                    .uncompressed => {
                        const uncompressed = self.readBits(input, &input_read, 1) orelse return result(input_read, output_written, .need_input);
                        if (uncompressed == 0) return self.fail(.header, error.UnsupportedBrotliFeature);
                        if (self.total_output > self.options.max_output_len or self.payload_remaining > self.options.max_output_len - self.total_output) return self.fail(.header, error.OutputLimitExceeded);
                        self.header_state = .padding;
                    },
                    .padding => {
                        if (!self.zeroPadding()) return self.fail(.header, error.CorruptFrame);
                        if (!self.metadata and self.payload_remaining == 0) {
                            self.phase = .done;
                            continue;
                        }
                        self.normalizeAlignedPayload(&input_read);
                        self.phase = if (self.payload_remaining == 0) .header else .payload;
                        self.header_state = .is_last;
                        continue;
                    },
                }
            }
        }
    }

    /// Rewind input bytes staged past the byte-aligned header boundary so they
    /// are consumed exactly once by the direct payload path. Headers are small,
    /// making this bounded reservoir rewind cheap even at arbitrary split points.
    fn normalizeAlignedPayload(self: *Decoder, input_read: *usize) void {
        if (self.staged_bits == 0) return;
        const staged_bytes = (@as(usize, self.staged_bits) + 7) / 8;
        input_read.* -= staged_bytes;
        self.total_input -= staged_bytes;
        self.staged = 0;
        self.staged_bits = 0;
    }

    fn readBits(self: *Decoder, input: []const u8, input_read: *usize, count: u6) ?usize {
        while (self.staged_bits < count) {
            if (input_read.* == input.len) return null;
            self.staged |= @as(u64, input[input_read.*]) << self.staged_bits;
            self.staged_bits += 8;
            input_read.* += 1;
            self.total_input += 1;
        }
        const mask = (@as(u64, 1) << count) - 1;
        const value: usize = @intCast(self.staged & mask);
        self.staged >>= count;
        self.staged_bits -= count;
        return value;
    }
    fn zeroPadding(self: *Decoder) bool {
        const drop: u6 = self.staged_bits % 8;
        if (drop == 0) return true;
        const mask = (@as(u64, 1) << drop) - 1;
        if ((self.staged & mask) != 0) return false;
        self.staged >>= drop;
        self.staged_bits -= drop;
        return true;
    }
    fn fail(self: *Decoder, phase: Phase, err: Error) Error {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
        return err;
    }
    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};
