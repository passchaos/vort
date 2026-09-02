const std = @import("std");
const core = @import("../../../core.zig");

/// Byte-progressive zlib wrapper around the raw stored/fixed/dynamic decoder.
/// The wrapper deliberately offers raw input one byte at a time so the first
/// Adler footer byte is never hidden by raw bit-reservoir prefetch.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        raw: Codec.RawDecoder,
        phase: Phase = .header,
        header: [2]u8 = undefined,
        header_received: usize = 0,
        footer: [4]u8 = undefined,
        footer_received: usize = 0,
        dictid: [4]u8 = undefined,
        dictid_received: usize = 0,
        dictionary: []const u8 = &.{},
        dictionaries: ?Codec.DictionarySet = null,
        adler: Codec.Adler32 = Codec.Adler32.init(),
        input_finished: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        stream_output: usize = 0,
        stream_count: usize = 0,
        stream_offset: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,
        last_error_stream_index: ?usize = null,
        last_error_stream_offset: ?usize = null,
        last_error_input_offset: ?usize = null,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            allow_concatenated: bool = false,
        };
        pub const Phase = enum { header, dictid, raw, footer, between_streams, done };
        pub const Snapshot = struct {
            phase: Phase,
            total_input: usize,
            total_output: usize,
            stream_output: usize,
            stream_count: usize,
            stream_index: usize,
            stream_offset: usize,
            stream_input: usize,
            header_received: usize,
            dictid_received: usize,
            footer_received: usize,
            last_error_name: []const u8,
            last_error_phase: ?Phase,
            last_error_stream_index: ?usize,
            last_error_stream_offset: ?usize,
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
        pub fn initWithDictionary(options: Options, history: []u8, dictionary: []const u8) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithDictionary(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
                }, history, dictionary),
                .dictionary = dictionary,
            };
        }
        pub fn initWithDictionarySet(options: Options, history: []u8, dictionaries: Codec.DictionarySet) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
                }, history),
                .dictionaries = dictionaries,
            };
        }
        pub fn reset(self: *Self) void {
            self.raw.reset();
            self.phase = .header;
            self.header_received = 0;
            self.footer_received = 0;
            self.dictid_received = 0;
            self.adler = Codec.Adler32.init();
            self.input_finished = false;
            self.total_input = 0;
            self.total_output = 0;
            self.stream_output = 0;
            self.stream_count = 0;
            self.stream_offset = 0;
            self.configureRawForStream();
            self.last_error_name = "";
            self.last_error_phase = .header;
            self.last_error_stream_index = null;
            self.last_error_stream_offset = null;
            self.last_error_input_offset = null;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .total_input = self.total_input,
                .total_output = self.total_output,
                .stream_output = self.stream_output,
                .stream_count = self.stream_count,
                .stream_index = self.diagnosticStreamIndex(self.phase),
                .stream_offset = self.stream_offset,
                .stream_input = self.total_input - self.stream_offset,
                .header_received = self.header_received,
                .dictid_received = self.dictid_received,
                .footer_received = self.footer_received,
                .last_error_name = self.last_error_name,
                .last_error_phase = if (self.last_error_name.len == 0) null else self.last_error_phase,
                .last_error_stream_index = self.last_error_stream_index,
                .last_error_stream_offset = self.last_error_stream_offset,
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
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.NeedDictionary))) "retry_with_dictionary" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.input_finished = true;
            if (self.options.allow_concatenated and self.phase == .between_streams) {
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
                    self.phase = if ((self.header[1] & 0x20) != 0) .dictid else .raw;
                },
                .dictid => {
                    const n = @min(self.dictid.len - self.dictid_received, input.len - input_read);
                    if (n != 0) {
                        @memcpy(self.dictid[self.dictid_received..][0..n], input[input_read..][0..n]);
                        self.dictid_received += n;
                        input_read += n;
                        self.total_input += n;
                    }
                    if (self.dictid_received != self.dictid.len) return result(input_read, output_written, .need_input);
                    const id = std.mem.readInt(u32, &self.dictid, .big);
                    if (self.dictionaries) |dictionaries| {
                        self.dictionary = dictionaries.find(id) orelse return self.fail(.dictid, error.NeedDictionary);
                        self.raw.seedDictionary(self.dictionary);
                    } else {
                        if (self.dictionary.len == 0 or id != Codec.Adler32.hash(self.dictionary)) return self.fail(.dictid, error.NeedDictionary);
                        self.raw.seedDictionary(self.dictionary);
                    }
                    self.phase = .raw;
                },
                .raw => {
                    const raw_input = if (input_read < input.len) input[input_read .. input_read + 1] else "";
                    const raw_result = self.raw.step(raw_input, output[output_written..]) catch |err| return self.failRaw(err);
                    input_read += raw_result.progress.input_read;
                    self.total_input += raw_result.progress.input_read;
                    if (raw_result.progress.output_written != 0) {
                        const produced = output[output_written..][0..raw_result.progress.output_written];
                        self.adler.update(produced);
                        output_written += produced.len;
                        self.total_output += produced.len;
                        self.stream_output += produced.len;
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
                    const expected = std.mem.readInt(u32, &self.footer, .big);
                    if (expected != self.adler.digest()) return self.fail(.footer, error.ChecksumMismatch);
                    self.stream_count += 1;
                    self.phase = if (self.options.allow_concatenated) .between_streams else .done;
                },
                .between_streams => {
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                    self.beginStream();
                },
                .done => {
                    if (input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn validateHeader(self: *Self) Error!void {
            const cmf = self.header[0];
            const flg = self.header[1];
            if ((cmf & 0x0f) != 8 or (cmf >> 4) > 7) return self.fail(.header, error.BadZlibHeader);
            if ((@as(u16, cmf) << 8 | flg) % 31 != 0) return self.fail(.header, error.BadZlibHeader);
        }
        fn beginStream(self: *Self) void {
            self.raw.reset();
            self.configureRawForStream();
            self.phase = .header;
            self.header_received = 0;
            self.footer_received = 0;
            self.dictid_received = 0;
            self.dictionary = if (self.dictionaries == null) self.dictionary else "";
            self.adler = Codec.Adler32.init();
            self.stream_output = 0;
            self.stream_offset = self.total_input;
        }
        fn configureRawForStream(self: *Self) void {
            self.raw.options.max_output_len = self.remainingRawLimit();
            self.raw.options.expected_output_len = if (self.options.allow_concatenated) null else self.options.expected_output_len;
        }
        fn remainingRawLimit(self: *const Self) usize {
            return rawLimit(self.options, self.total_output);
        }
        fn validateExpectedOutput(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected|
                if (self.total_output != expected) return self.fail(self.phase, error.SizeMismatch);
        }
        fn cumulativeLimitError(self: *const Self) Error {
            if (self.options.expected_output_len) |expected| {
                if (expected <= self.options.max_output_len) return error.SizeMismatch;
            }
            return error.OutputLimitExceeded;
        }
        fn failRaw(self: *Self, err: Error) Error {
            // In concatenated mode the raw decoder's per-stream limit is the
            // remaining cumulative allowance. Reaching a caller-pledged exact
            // size is a size mismatch, not a configured safety-limit failure.
            if (self.options.allow_concatenated and err == error.OutputLimitExceeded)
                return self.fail(.raw, self.cumulativeLimitError());
            return self.fail(.raw, err);
        }
        fn diagnosticStreamIndex(self: *const Self, phase: Phase) usize {
            if ((phase == .between_streams or phase == .done) and self.stream_count != 0) return self.stream_count - 1;
            return self.stream_count;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            self.last_error_stream_index = self.diagnosticStreamIndex(phase);
            self.last_error_stream_offset = self.stream_offset;
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
