//! Bounded incremental lzip v1 decoder with per-member trailer validation.

const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const container = @import("container.zig");
const lzma = @import("../lzma.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header: [header_size]u8 = undefined,
    header_len: usize = 0,
    trailer: [trailer_size]u8 = undefined,
    trailer_len: usize = 0,
    lzma_decoder: lzma.IncrementalDecoder,
    lzma_started: bool = false,
    lzma_finish_called: bool = false,
    member_input: usize = 0,
    member_lzma_accepted: usize = 0,
    member_payload_size: usize = 0,
    member_output: usize = 0,
    member_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    total_input: usize = 0,
    total_output: usize = 0,
    member_count: usize = 0,
    saw_empty_member: bool = false,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const header_size: usize = 6;
    const trailer_size: usize = 20;
    const min_member_size: usize = 36;

    pub const Error = container.Error || lzma.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_member_output_len: usize = std.math.maxInt(usize),
        max_dictionary_size: usize = 512 * 1024 * 1024,
        max_compressed_buffer_len: usize = 1024 * 1024,
        max_members: usize = 1024 * 1024,
        expected_output_len: ?usize = null,
        /// Stop after one validated lzip member and leave the next outer
        /// member unconsumed instead of parsing lzip concatenation.
        stop_after_first_member: bool = false,
    };
    pub const Phase = enum { header, payload, trailer, done };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        trailer_received: usize,
        member_input_read: usize,
        member_output_written: usize,
        input_read: usize,
        output_written: usize,
        member_count: usize,
        current_dictionary_size: ?u32,
        pending_output: usize,
        retained_compressed_capacity: usize,
        retained_dictionary_capacity: usize,
        retained_output_capacity: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{
            .allocator = allocator,
            .options = options,
            .lzma_decoder = lzma.IncrementalDecoder.init(allocator),
        };
    }

    pub fn deinit(self: *Decoder) void {
        self.lzma_decoder.deinit();
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        var inner = self.lzma_decoder;
        inner.reset();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .lzma_decoder = inner,
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        const inner = self.lzma_decoder.snapshot();
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .trailer_received = self.trailer_len,
            .member_input_read = self.member_input,
            .member_output_written = self.member_output,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .member_count = self.member_count,
            .current_dictionary_size = if (self.lzma_started)
                inner.dictionary_size
            else
                null,
            .pending_output = inner.pending_output,
            .retained_compressed_capacity = inner.retained_compressed_capacity,
            .retained_dictionary_capacity = inner.retained_dictionary_capacity,
            .retained_output_capacity = inner.retained_output_capacity,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = snap.header_received,
            .frame_input_read = snap.input_read,
            .output_written = snap.output_written,
            .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0)
                ""
            else
                @tagName(snap.last_error_phase),
        };
    }

    /// Declares lzip EOF. Pending LZMA output and trailer validation remain
    /// resumable through `step("", output)`.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInner(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            return err;
        };
    }

    fn stepInner(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                if (self.saw_empty_member and input_read != input.len)
                    return error.InvalidLzipStream;
                const take = @min(header_size - self.header_len, input.len - input_read);
                @memcpy(
                    self.header[self.header_len..][0..take],
                    input[input_read..][0..take],
                );
                self.header_len += take;
                input_read += take;
                try self.recordInput(take);
                self.member_input = try checkedAdd(self.member_input, take);
                if (self.header_len != header_size) {
                    if (self.input_finished) {
                        if (self.header_len == 0 and self.member_count != 0) {
                            try self.complete();
                            return result(input_read, output_written, .done);
                        }
                        return error.TruncatedFrame;
                    }
                    return result(input_read, output_written, .need_input);
                }
                try self.startMember();
                self.phase = .payload;
            },
            .payload => {
                const drained = try self.lzma_decoder.step("", output[output_written..]);
                try self.accountInner(drained, output[output_written..], &output_written);
                if (drained.status == .done) {
                    try self.captureTrailerPrefix();
                    self.phase = .trailer;
                    continue;
                }
                if (drained.status == .need_output)
                    return result(input_read, output_written, .need_output);

                if (input_read != input.len) {
                    const supplied = try self.lzma_decoder.step(
                        input[input_read..],
                        output[output_written..],
                    );
                    input_read += supplied.progress.input_read;
                    try self.recordInput(supplied.progress.input_read);
                    self.member_input = try checkedAdd(
                        self.member_input,
                        supplied.progress.input_read,
                    );
                    self.member_lzma_accepted = try checkedAdd(
                        self.member_lzma_accepted,
                        supplied.progress.input_read,
                    );
                    try self.accountInner(
                        supplied,
                        output[output_written..],
                        &output_written,
                    );
                    if (supplied.status == .done) {
                        try self.captureTrailerPrefix();
                        self.phase = .trailer;
                        continue;
                    }
                    if (supplied.status == .need_output)
                        return result(input_read, output_written, .need_output);
                    if (input_read != input.len) {
                        if (supplied.progress.input_read == 0 and
                            supplied.progress.output_written == 0)
                            return error.InvalidLzipStream;
                        continue;
                    }
                }

                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                if (!self.lzma_finish_called) {
                    self.lzma_decoder.finish();
                    self.lzma_finish_called = true;
                    continue;
                }
                return error.TruncatedFrame;
            },
            .trailer => {
                const take = @min(trailer_size - self.trailer_len, input.len - input_read);
                @memcpy(
                    self.trailer[self.trailer_len..][0..take],
                    input[input_read..][0..take],
                );
                self.trailer_len += take;
                input_read += take;
                try self.recordInput(take);
                self.member_input = try checkedAdd(self.member_input, take);
                if (self.trailer_len != trailer_size) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.validateTrailer();
                if (self.options.stop_after_first_member) {
                    try self.complete();
                } else {
                    self.finishMember();
                    self.phase = .header;
                }
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn startMember(self: *Decoder) Error!void {
        if (self.member_count == self.options.max_members)
            return error.OutputLimitExceeded;
        const parsed = try container.parseHeader(&self.header);
        const remaining_output = self.options.max_output_len -| self.total_output;
        self.lzma_decoder.resetWithOptions(.{
            .max_output_len = @min(remaining_output, self.options.max_member_output_len),
            .max_dictionary_size = self.options.max_dictionary_size,
            .max_compressed_buffer_len = self.options.max_compressed_buffer_len,
            .stop_after_end_marker = true,
            .end_marker_input_guard = trailer_size,
        });
        var synthetic: [13]u8 = undefined;
        synthetic[0] = 0x5d; // lc=3, lp=0, pb=2
        std.mem.writeInt(u32, synthetic[1..5], parsed.dictionary_size, .little);
        @memset(synthetic[5..13], 0xff);
        const primed = try self.lzma_decoder.step(&synthetic, &.{});
        if (primed.progress.input_read != synthetic.len or
            primed.progress.output_written != 0 or primed.status != .need_input)
            return error.InvalidLzipStream;
        self.lzma_started = true;
        self.lzma_finish_called = false;
        self.member_lzma_accepted = 0;
        self.member_payload_size = 0;
        self.member_output = 0;
        self.member_crc = checksum.Crc32Best.init();
        self.trailer_len = 0;
    }

    fn accountInner(
        self: *Decoder,
        stepped: core.StepResult,
        output: []const u8,
        output_written: *usize,
    ) Error!void {
        const produced = output[0..stepped.progress.output_written];
        self.member_crc.update(produced);
        self.member_output = try checkedAdd(self.member_output, produced.len);
        self.total_output = try checkedAdd(self.total_output, produced.len);
        if (self.total_output > self.options.max_output_len or
            self.member_output > self.options.max_member_output_len)
            return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (self.total_output > expected) return error.SizeMismatch;
        output_written.* = try checkedAdd(output_written.*, produced.len);
    }

    fn captureTrailerPrefix(self: *Decoder) Error!void {
        const suffix = self.lzma_decoder.trailingInput();
        if (suffix.len > trailer_size or suffix.len > self.member_lzma_accepted)
            return error.InvalidLzipStream;
        @memcpy(self.trailer[0..suffix.len], suffix);
        self.trailer_len = suffix.len;
        self.member_payload_size = self.member_lzma_accepted - suffix.len;
    }

    fn validateTrailer(self: *Decoder) Error!void {
        const expected_crc = std.mem.readInt(u32, self.trailer[0..4], .little);
        const expected_data_size = std.mem.readInt(u64, self.trailer[4..12], .little);
        const expected_member_size = std.mem.readInt(u64, self.trailer[12..20], .little);
        if (expected_crc != self.member_crc.digest()) return error.ChecksumMismatch;
        if (expected_data_size != self.member_output) return error.SizeMismatch;
        const actual_member_size = std.math.add(
            u64,
            header_size + trailer_size,
            self.member_payload_size,
        ) catch return error.IntegerOverflow;
        if (expected_member_size != actual_member_size) return error.SizeMismatch;
        try validateTrailerConsistency(
            expected_crc,
            expected_data_size,
            expected_member_size,
        );
        const next_count = try checkedAdd(self.member_count, 1);
        if (next_count > 1 and (self.saw_empty_member or self.member_output == 0))
            return error.InvalidLzipStream;
        self.member_count = next_count;
        self.saw_empty_member = self.saw_empty_member or self.member_output == 0;
    }

    fn finishMember(self: *Decoder) void {
        self.header_len = 0;
        self.trailer_len = 0;
        self.lzma_started = false;
        self.lzma_finish_called = false;
        self.member_input = 0;
        self.member_lzma_accepted = 0;
        self.member_payload_size = 0;
        self.member_output = 0;
    }

    fn complete(self: *Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.total_output != expected) return error.SizeMismatch;
        self.phase = .done;
    }

    fn recordInput(self: *Decoder, count: usize) Error!void {
        self.total_input = try checkedAdd(self.total_input, count);
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{
                .input_read = input_read,
                .output_written = output_written,
            },
            .status = status,
        };
    }
};

fn validateTrailerConsistency(crc32: u32, data_size: u64, member_size: u64) Decoder.Error!void {
    if ((crc32 == 0) != (data_size == 0)) return error.InvalidLzipStream;
    if (member_size < Decoder.min_member_size) return error.InvalidLzipStream;
    const maximum_member_size = (@as(u128, 9) * data_size + 7) / 8 + Decoder.min_member_size;
    if (maximum_member_size > data_size and member_size > maximum_member_size)
        return error.InvalidLzipStream;
    const maximum_data_size = @as(u128, 7090) * (member_size - 26) - 1;
    if (maximum_data_size > member_size and data_size > maximum_data_size)
        return error.InvalidLzipStream;
}
