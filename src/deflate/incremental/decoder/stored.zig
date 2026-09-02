const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive raw-DEFLATE decoder for stored blocks. Headers may be split
/// at any byte, payload bytes copy directly caller-to-caller, and no complete
/// frame or output buffer is retained.
pub const Decoder = struct {
    options: Options,
    phase: Phase = .header,
    header: [5]u8 = undefined,
    header_received: usize = 0,
    payload_remaining: usize = 0,
    final_block: bool = false,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    pub const Error = core.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum { header, payload, done };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        header_received: usize,
        payload_remaining: usize,
        final_block: bool,
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
            .header_received = self.header_received,
            .payload_remaining = self.payload_remaining,
            .final_block = self.final_block,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .header_received = self.header_received,
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = self.payload_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
        };
    }
    pub fn finish(self: *Decoder) Error!void {
        self.input_finished = true;
        if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        if (self.options.expected_output_len) |expected| {
            if (self.total_output != expected) return self.fail(.done, error.SizeMismatch);
        }
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.input_finished) {
            if (input.len != 0) return self.fail(self.phase, error.TrailingData);
            return .{ .status = if (self.phase == .done) .done else .need_input };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const needed = self.header.len - self.header_received;
                const n = @min(needed, input.len - input_read);
                if (n != 0) {
                    @memcpy(self.header[self.header_received..][0..n], input[input_read..][0..n]);
                    self.header_received += n;
                    input_read += n;
                    self.total_input += n;
                }
                if (self.header_received != self.header.len) return result(input_read, output_written, .need_input);
                try self.parseHeader();
                if (self.payload_remaining == 0) {
                    self.completeBlock();
                    continue;
                }
                self.phase = .payload;
            },
            .payload => {
                if (output_written == output.len) return result(input_read, output_written, .need_output);
                if (input_read == input.len) return result(input_read, output_written, .need_input);
                const n = @min(self.payload_remaining, @min(input.len - input_read, output.len - output_written));
                @memcpy(output[output_written..][0..n], input[input_read..][0..n]);
                input_read += n;
                output_written += n;
                self.total_input += n;
                self.total_output += n;
                self.payload_remaining -= n;
                if (self.payload_remaining == 0) self.completeBlock();
            },
            .done => {
                if (input_read != input.len) return self.fail(.done, error.TrailingData);
                if (self.options.expected_output_len) |expected| {
                    if (self.total_output != expected) return self.fail(.done, error.SizeMismatch);
                }
                return result(input_read, output_written, .done);
            },
        };
    }

    fn parseHeader(self: *Decoder) Error!void {
        if ((self.header[0] & 0x06) != 0) return self.fail(.header, error.InvalidDeflateBlockType);
        const len = std.mem.readInt(u16, self.header[1..3], .little);
        const nlen = std.mem.readInt(u16, self.header[3..5], .little);
        if (nlen != ~len) return self.fail(.header, error.StoredLengthMismatch);
        if (self.total_output > self.options.max_output_len or len > self.options.max_output_len - self.total_output) return self.fail(.header, error.OutputLimitExceeded);
        if (self.options.expected_output_len) |expected| {
            if (self.total_output > expected or len > expected - self.total_output) return self.fail(.header, error.SizeMismatch);
        }
        self.final_block = (self.header[0] & 1) != 0;
        self.payload_remaining = len;
    }
    fn completeBlock(self: *Decoder) void {
        self.header_received = 0;
        self.phase = if (self.final_block) .done else .header;
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
