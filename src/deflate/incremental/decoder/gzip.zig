const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive gzip decoder with opt-in concatenated-member support. Raw
/// input is offered one byte at a time so footer ownership remains outside the
/// DEFLATE bit reservoir. Each member gets independent header, history, CRC-32,
/// and ISIZE state while stream output limits remain cumulative.
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
        member_output: usize = 0,
        member_count: usize = 0,
        member_offset: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,
        last_error_member_index: ?usize = null,
        last_error_member_offset: ?usize = null,
        last_error_input_offset: ?usize = null,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            max_header_metadata_len: usize = 1 << 20,
            allow_concatenated: bool = false,
        };
        pub const Phase = enum { header, extra_len, extra_payload, filename, comment, header_crc, raw, footer, between_members, done };
        pub const Snapshot = struct {
            phase: Phase,
            total_input: usize,
            total_output: usize,
            member_output: usize,
            /// Number of members whose footer has been fully validated.
            member_count: usize,
            /// Zero-based active member, or the last validated member at EOF.
            member_index: usize,
            /// Compressed-stream offset of the active or last validated member.
            member_offset: usize,
            member_input: usize,
            header_received: usize,
            footer_received: usize,
            last_error_name: []const u8,
            last_error_phase: ?Phase,
            last_error_member_index: ?usize,
            last_error_member_offset: ?usize,
            /// Cumulative compressed offset at which the error was detected.
            last_error_input_offset: ?usize,
            done: bool,
        };

        pub fn init(options: Options, history: []u8) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
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
            self.member_output = 0;
            self.member_count = 0;
            self.member_offset = 0;
            self.configureRawForMember();
            self.last_error_name = "";
            self.last_error_phase = .header;
            self.last_error_member_index = null;
            self.last_error_member_offset = null;
            self.last_error_input_offset = null;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .total_input = self.total_input,
                .total_output = self.total_output,
                .member_output = self.member_output,
                .member_count = self.member_count,
                .member_index = self.diagnosticMemberIndex(self.phase),
                .member_offset = self.member_offset,
                .member_input = self.total_input - self.member_offset,
                .header_received = self.header_received,
                .footer_received = self.footer_received,
                .last_error_name = self.last_error_name,
                .last_error_phase = if (self.last_error_name.len == 0) null else self.last_error_phase,
                .last_error_member_index = self.last_error_member_index,
                .last_error_member_offset = self.last_error_member_offset,
                .last_error_input_offset = self.last_error_input_offset,
                .done = self.phase == .done,
            };
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
            if (self.options.allow_concatenated and self.phase == .between_members) {
                try self.validateExpectedOutput();
                self.phase = .done;
                return;
            }
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
            try self.validateExpectedOutput();
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
                    // Drain symbols already present in the raw bit reservoir
                    // before offering another byte. Dynamic EOB codes can end
                    // there; pre-supplying a byte in that case would make the
                    // strict raw decoder mistake the first footer byte for raw
                    // trailing data.
                    const drained = self.raw.step("", output[output_written..]) catch |err| return self.failRaw(err);
                    self.recordRawProgress(drained, output, &input_read, &output_written);
                    if (drained.status == .done) {
                        self.phase = .footer;
                        continue;
                    }
                    if (drained.status == .need_output) {
                        if (drained.progress.output_written != 0) continue;
                        // The raw decoder can retain one decoded literal when
                        // passed an empty output slice. If the cumulative cap is
                        // already exhausted, surface the limit now rather than
                        // asking the caller for output that may not be written.
                        if (self.options.allow_concatenated and self.remainingRawLimit() == 0)
                            return self.fail(.raw, self.cumulativeLimitError());
                        return result(input_read, output_written, .need_output);
                    }
                    if (input_read == input.len) return result(input_read, output_written, .need_input);

                    const supplied = self.raw.step(input[input_read .. input_read + 1], output[output_written..]) catch |err| return self.failRaw(err);
                    self.recordRawProgress(supplied, output, &input_read, &output_written);
                    if (supplied.status == .done) {
                        self.phase = .footer;
                        continue;
                    }
                    // Re-enter the raw phase once so an EOB already buffered
                    // behind an exactly filled caller output can advance to the
                    // footer. A pending literal or match immediately returns
                    // need_output from the drain at the top of this phase.
                    if (supplied.status == .need_output) continue;
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
                    if (std.mem.readInt(u32, self.footer[4..8], .little) != @as(u32, @truncate(self.member_output))) return self.fail(.footer, error.SizeMismatch);
                    self.member_count += 1;
                    self.phase = if (self.options.allow_concatenated) .between_members else .done;
                },
                .between_members => {
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                    self.beginMember();
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
        fn beginMember(self: *Self) void {
            // RFC 1952 members are independent streams: a later member cannot
            // reference the prior member's DEFLATE window. Only wrapper-wide
            // byte accounting and limits survive this reset.
            self.raw.reset();
            self.configureRawForMember();
            self.phase = .header;
            self.header_received = 0;
            self.header_crc = Codec.Crc32.init();
            self.flags = 0;
            self.xlen_received = 0;
            self.optional_remaining = 0;
            self.header_crc_received = 0;
            self.footer_received = 0;
            self.crc = Codec.Crc32.init();
            self.member_output = 0;
            self.member_offset = self.total_input;
        }
        fn configureRawForMember(self: *Self) void {
            self.raw.options.max_output_len = self.remainingRawLimit();
            // In concatenated mode no individual member is required to fill
            // the stream's exact size. The wrapper checks that cumulative size
            // only once EOF is declared through finish().
            self.raw.options.expected_output_len = if (self.options.allow_concatenated) null else self.options.expected_output_len;
        }
        fn remainingRawLimit(self: *const Self) usize {
            return rawLimit(self.options, self.total_output);
        }
        fn cumulativeLimitError(self: *const Self) Error {
            if (self.options.expected_output_len) |expected| {
                if (expected <= self.options.max_output_len) return error.SizeMismatch;
            }
            return error.OutputLimitExceeded;
        }
        fn validateExpectedOutput(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected| {
                if (self.total_output != expected) return self.fail(self.phase, error.SizeMismatch);
            }
        }
        fn recordRawProgress(self: *Self, raw_result: core.StepResult, output: []const u8, input_read: *usize, output_written: *usize) void {
            input_read.* += raw_result.progress.input_read;
            self.total_input += raw_result.progress.input_read;
            if (raw_result.progress.output_written == 0) return;
            const produced = output[output_written.*..][0..raw_result.progress.output_written];
            self.crc.update(produced);
            output_written.* += produced.len;
            self.total_output += produced.len;
            self.member_output += produced.len;
        }
        fn failRaw(self: *Self, err: Error) Error {
            if (self.options.allow_concatenated and err == error.OutputLimitExceeded)
                return self.fail(.raw, self.cumulativeLimitError());
            return self.fail(.raw, err);
        }
        fn diagnosticMemberIndex(self: *const Self, phase: Phase) usize {
            if ((phase == .between_members or phase == .done) and self.member_count != 0)
                return self.member_count - 1;
            return self.member_count;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            self.last_error_member_index = self.diagnosticMemberIndex(phase);
            self.last_error_member_offset = self.member_offset;
            self.last_error_input_offset = self.total_input;
            return err;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

fn initialRawLimit(options: anytype) usize {
    return rawLimit(options, 0);
}

fn rawLimit(options: anytype, total_output: usize) usize {
    const max_remaining = if (total_output < options.max_output_len) options.max_output_len - total_output else 0;
    if (!options.allow_concatenated) return max_remaining;
    if (options.expected_output_len) |expected| {
        const expected_remaining = if (total_output < expected) expected - total_output else 0;
        return @min(max_remaining, expected_remaining);
    }
    return max_remaining;
}
