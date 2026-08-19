const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive single-member gzip decoder for the standard ten-byte
/// header. Raw input is offered one byte at a time so footer ownership remains
/// outside the DEFLATE bit reservoir. Optional header fields are rejected until
/// the metadata state slice is enabled.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        raw: Codec.RawDecoder,
        phase: Phase = .header,
        header: [10]u8 = undefined,
        header_received: usize = 0,
        header_crc: Codec.Crc32 = Codec.Crc32.init(),
        flags: u8 = 0,
        xlen_bytes: [2]u8 = undefined,
        xlen_received: usize = 0,
        optional_remaining: usize = 0,
        header_crc_bytes: [2]u8 = undefined,
        header_crc_received: usize = 0,
        footer: [8]u8 = undefined,
        footer_received: usize = 0,
        crc: Codec.Crc32 = Codec.Crc32.init(),
        input_finished: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            max_header_metadata_len: usize = 1 << 20,
        };
        pub const Phase = enum { header, extra_len, extra_payload, filename, comment, header_crc, raw, footer, done };

        pub fn init(options: Options, history: []u8) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = options.max_output_len,
                    .expected_output_len = options.expected_output_len,
                }, history),
            };
        }
        pub fn reset(self: *Self) void {
            self.raw.reset();
            self.phase = .header;
            self.header_received = 0;
            self.footer_received = 0;
            self.header_crc = Codec.Crc32.init();
            self.flags = 0;
            self.xlen_received = 0;
            self.optional_remaining = 0;
            self.header_crc_received = 0;
            self.crc = Codec.Crc32.init();
            self.input_finished = false;
            self.total_input = 0;
            self.total_output = 0;
            self.last_error_name = "";
            self.last_error_phase = .header;
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            return .{
                .phase_name = @tagName(self.phase),
                .header_received = self.header_received,
                .frame_input_read = self.total_input,
                .output_written = self.total_output,
                .expected_output_len = self.options.expected_output_len,
                .last_error_name = self.last_error_name,
                .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.BadGzipHeader))) "corrupt_header" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.input_finished = true;
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.input_finished) {
                if (input.len != 0) return self.fail(self.phase, error.TrailingData);
                return .{ .status = if (self.phase == .done) .done else .need_input };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) switch (self.phase) {
                .header => {
                    const n = @min(self.header.len - self.header_received, input.len - input_read);
                    if (n != 0) {
                        @memcpy(self.header[self.header_received..][0..n], input[input_read..][0..n]);
                        self.header_received += n;
                        input_read += n;
                        self.total_input += n;
                    }
                    if (self.header_received != self.header.len) return result(input_read, output_written, .need_input);
                    try self.validateHeader();
                    self.header_crc.update(&self.header);
                    self.flags = self.header[3];
                    self.advanceOptionalPhase();
                },
                .extra_len => {
                    while (self.xlen_received < 2) {
                        if (input_read == input.len) return result(input_read, output_written, .need_input);
                        const byte = input[input_read];
                        self.xlen_bytes[self.xlen_received] = byte;
                        self.header_crc.update(input[input_read .. input_read + 1]);
                        self.xlen_received += 1;
                        input_read += 1;
                        self.total_input += 1;
                    }
                    self.optional_remaining = std.mem.readInt(u16, &self.xlen_bytes, .little);
                    if (self.optional_remaining > self.options.max_header_metadata_len) return self.fail(.extra_len, error.OutputLimitExceeded);
                    self.phase = .extra_payload;
                },
                .extra_payload => {
                    const n = @min(self.optional_remaining, input.len - input_read);
                    if (n != 0) {
                        self.header_crc.update(input[input_read..][0..n]);
                        self.optional_remaining -= n;
                        input_read += n;
                        self.total_input += n;
                    }
                    if (self.optional_remaining != 0) return result(input_read, output_written, .need_input);
                    self.flags &= ~@as(u8, 0x04);
                    self.advanceOptionalPhase();
                },
                .filename, .comment => {
                    while (input_read < input.len) {
                        const byte = input[input_read];
                        self.header_crc.update(input[input_read .. input_read + 1]);
                        input_read += 1;
                        self.total_input += 1;
                        self.optional_remaining += 1;
                        if (self.optional_remaining > self.options.max_header_metadata_len) return self.fail(self.phase, error.OutputLimitExceeded);
                        if (byte == 0) {
                            self.flags &= if (self.phase == .filename) ~@as(u8, 0x08) else ~@as(u8, 0x10);
                            self.optional_remaining = 0;
                            self.advanceOptionalPhase();
                            break;
                        }
                    }
                    if (self.phase == .filename or self.phase == .comment) return result(input_read, output_written, .need_input);
                },
                .header_crc => {
                    while (self.header_crc_received < 2) {
                        if (input_read == input.len) return result(input_read, output_written, .need_input);
                        self.header_crc_bytes[self.header_crc_received] = input[input_read];
                        self.header_crc_received += 1;
                        input_read += 1;
                        self.total_input += 1;
                    }
                    const expected = std.mem.readInt(u16, &self.header_crc_bytes, .little);
                    if (expected != @as(u16, @truncate(self.header_crc.digest()))) return self.fail(.header_crc, error.BadGzipHeader);
                    self.flags &= ~@as(u8, 0x02);
                    self.phase = .raw;
                },
                .raw => {
                    const raw_input = if (input_read < input.len) input[input_read .. input_read + 1] else "";
                    const raw_result = self.raw.step(raw_input, output[output_written..]) catch |err| return self.fail(.raw, err);
                    input_read += raw_result.progress.input_read;
                    self.total_input += raw_result.progress.input_read;
                    if (raw_result.progress.output_written != 0) {
                        const produced = output[output_written..][0..raw_result.progress.output_written];
                        self.crc.update(produced);
                        output_written += produced.len;
                        self.total_output += produced.len;
                    }
                    if (raw_result.status == .done) {
                        self.phase = .footer;
                        continue;
                    }
                    if (raw_result.status == .need_output) return result(input_read, output_written, .need_output);
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                },
                .footer => {
                    const n = @min(self.footer.len - self.footer_received, input.len - input_read);
                    if (n != 0) {
                        @memcpy(self.footer[self.footer_received..][0..n], input[input_read..][0..n]);
                        self.footer_received += n;
                        input_read += n;
                        self.total_input += n;
                    }
                    if (self.footer_received != self.footer.len) return result(input_read, output_written, .need_input);
                    if (std.mem.readInt(u32, self.footer[0..4], .little) != self.crc.digest()) return self.fail(.footer, error.ChecksumMismatch);
                    if (std.mem.readInt(u32, self.footer[4..8], .little) != @as(u32, @truncate(self.total_output))) return self.fail(.footer, error.SizeMismatch);
                    self.phase = .done;
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn validateHeader(self: *Self) Error!void {
            if (!std.mem.eql(u8, self.header[0..2], &.{ 0x1f, 0x8b })) return self.fail(.header, error.BadGzipHeader);
            if (self.header[2] != 8 or (self.header[3] & 0xe0) != 0) return self.fail(.header, error.BadGzipHeader);
        }
        fn advanceOptionalPhase(self: *Self) void {
            if ((self.flags & 0x04) != 0) {
                self.phase = .extra_len;
            } else if ((self.flags & 0x08) != 0) {
                self.phase = .filename;
            } else if ((self.flags & 0x10) != 0) {
                self.phase = .comment;
            } else if ((self.flags & 0x02) != 0) {
                self.phase = .header_crc;
            } else {
                self.phase = .raw;
            }
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
