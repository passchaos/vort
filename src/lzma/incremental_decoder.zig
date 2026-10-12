const std = @import("std");
const core = @import("../core.zig");
const lzma_decoder = @import("decoder.zig");

/// True symbol-progressive LZMA-Alone decoder. The compressed staging window is
/// bounded and compacted as range-coded bytes are consumed; decoded staging is
/// limited to one committed literal/match before caller-output backpressure.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header_bytes: [13]u8 = undefined,
    header_len: usize = 0,
    header: ?lzma_decoder.Header = null,
    declared_size: ?usize = null,
    compressed: std.ArrayList(u8) = .empty,
    compressed_start: usize = 0,
    decoder: ?std.compress.lzma.Decode = null,
    range_decoder: ?std.compress.lzma.RangeDecoder = null,
    dictionary: ?lzma_decoder.CircularBuffer = null,
    staging: std.Io.Writer.Allocating,
    staging_offset: usize = 0,
    validated_output: usize = 0,
    output_written: usize = 0,
    input_finished: bool = false,
    saw_end_marker: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const header_size: usize = 13;
    const range_prefix_len: usize = 5;
    // One LZMA symbol reads at most the match/length flags, a 10-bit length
    // tree, a 6-bit position slot, 26 direct bits, and a 4-bit align tree.
    // Range normalization consumes at most one byte per bit, so 64 bytes is a
    // conservative non-final transaction guard.
    const symbol_input_guard: usize = 64;

    pub const Error = lzma_decoder.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_dictionary_size: usize = std.math.maxInt(usize),
        max_compressed_buffer_len: usize = 1024 * 1024,
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum {
        header,
        range_prefix,
        decode,
        output,
        known_size_complete,
        end_marker,
        done,
    };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        buffered_compressed_bytes: usize,
        pending_output: usize,
        validated_output: usize,
        output_written: usize,
        declared_output_len: ?usize,
        dictionary_size: ?u32,
        retained_compressed_capacity: usize,
        retained_dictionary_capacity: usize,
        retained_output_capacity: usize,
        input_finished: bool,
        saw_end_marker: bool,
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
            .staging = std.Io.Writer.Allocating.init(allocator),
        };
    }

    pub fn deinit(self: *Decoder) void {
        if (self.decoder) |*state| state.deinit(self.allocator);
        if (self.dictionary) |*dictionary| dictionary.deinit(self.allocator);
        self.staging.deinit();
        self.compressed.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        if (self.decoder) |*state| state.deinit(allocator);
        if (self.dictionary) |*dictionary| dictionary.deinit(allocator);
        var staging = self.staging;
        var compressed = self.compressed;
        staging.clearRetainingCapacity();
        compressed.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .staging = staging,
            .compressed = compressed,
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .buffered_compressed_bytes = self.bufferedCompressedLen(),
            .pending_output = self.staging.writer.buffered().len - self.staging_offset,
            .validated_output = self.validated_output,
            .output_written = self.output_written,
            .declared_output_len = self.declared_size,
            .dictionary_size = if (self.header) |header| header.dictionary_size else null,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_dictionary_capacity = if (self.dictionary) |dictionary| dictionary.bytes.capacity else 0,
            .retained_output_capacity = self.staging.writer.buffer.len,
            .input_finished = self.input_finished,
            .saw_end_marker = self.saw_end_marker,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = snap.header_received,
            .output_written = snap.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame)))
                "truncated_input"
            else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutputLimitExceeded)))
                "raise_input_output_or_dictionary_limit"
            else if (snap.last_error_name.len == 0)
                "none"
            else
                "payload_corrupt",
        };
    }

    /// Declare that no more compressed input will arrive. Remaining range
    /// symbols and caller-output staging drain through `step("", output)`.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInternal(input, output) catch |err| {
            self.recordError(self.phase, err);
            return err;
        };
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const take = @min(header_size - self.header_len, input.len - input_read);
                @memcpy(self.header_bytes[self.header_len..][0..take], input[input_read..][0..take]);
                self.header_len += take;
                input_read += take;
                if (self.header_len != header_size) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.acceptHeader();
                self.phase = .range_prefix;
            },
            .range_prefix => {
                if (!try self.ensureCompressed(range_prefix_len, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                var reader: std.Io.Reader = .fixed(self.compressed.items[self.compressed_start..]);
                self.range_decoder = std.compress.lzma.RangeDecoder.init(&reader) catch |err| switch (err) {
                    error.EndOfStream => return error.TruncatedFrame,
                    else => return error.InvalidLzmaStream,
                };
                self.advanceCompressed(reader.seek);
                self.phase = .decode;
            },
            .decode => {
                const dictionary = &(self.dictionary orelse return error.InvalidLzmaStream);
                if (self.declared_size) |size| {
                    if (dictionary.len == size) {
                        self.phase = .known_size_complete;
                        continue;
                    }
                }

                if (!self.input_finished and self.bufferedCompressedLen() < symbol_input_guard) {
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.appendCompressedGuard(input, &input_read);
                    continue;
                }

                var reader: std.Io.Reader = .fixed(self.compressed.items[self.compressed_start..]);
                var bytes_read: u64 = 0;
                const status = (&self.decoder.?).process(
                    &reader,
                    &self.staging,
                    dictionary,
                    &self.range_decoder.?,
                    &bytes_read,
                ) catch |err| switch (err) {
                    error.EndOfStream => if (self.input_finished)
                        return error.TruncatedFrame
                    else
                        return error.InvalidLzmaStream,
                    error.OutputLimitExceeded => if (self.declared_size != null or self.options.expected_output_len != null)
                        return error.SizeMismatch
                    else
                        return error.OutputLimitExceeded,
                    error.OutOfMemory, error.WriteFailed => return error.OutOfMemory,
                    error.Overflow => return error.IntegerOverflow,
                    else => return error.InvalidLzmaStream,
                };
                self.advanceCompressed(reader.seek);
                switch (status) {
                    .more => {
                        if (self.staging.written().len == 0) return error.InvalidLzmaStream;
                        self.validated_output = dictionary.len;
                        self.staging_offset = 0;
                        self.phase = .output;
                    },
                    .finished => {
                        self.saw_end_marker = true;
                        self.validated_output = dictionary.len;
                        if (self.declared_size) |size|
                            if (dictionary.len != size) return error.SizeMismatch;
                        if (self.bufferedCompressedLen() != 0 or input_read != input.len)
                            return error.TrailingData;
                        self.phase = .end_marker;
                    },
                }
            },
            .output => {
                const remaining = self.staging.written()[self.staging_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.staging_offset += take;
                output_written += take;
                self.output_written += take;
                if (self.staging_offset != self.staging.written().len)
                    return result(input_read, output_written, .need_output);
                self.staging.clearRetainingCapacity();
                self.staging_offset = 0;
                self.phase = .decode;
            },
            .known_size_complete => {
                self.compressed.clearRetainingCapacity();
                self.compressed_start = 0;
                input_read = input.len;
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                try self.validateFinalSize();
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .end_marker => {
                if (input.len != input_read) return error.TrailingData;
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                try self.validateFinalSize();
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn acceptHeader(self: *Decoder) Error!void {
        const parsed = try lzma_decoder.parseHeader(&self.header_bytes);
        if (parsed.dictionary_size > self.options.max_dictionary_size)
            return error.OutputLimitExceeded;
        const declared_size: ?usize = if (parsed.uncompressed_size) |size|
            std.math.cast(usize, size) orelse return error.OutputLimitExceeded
        else
            null;
        if (declared_size) |size| {
            if (size > self.options.max_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |expected|
                if (size != expected) return error.SizeMismatch;
        } else if (self.options.expected_output_len) |expected| {
            if (expected > self.options.max_output_len) return error.OutputLimitExceeded;
        }
        const output_limit = declared_size orelse self.options.expected_output_len orelse self.options.max_output_len;
        const state = std.compress.lzma.Decode.init(self.allocator, .{
            .lc = parsed.lc,
            .lp = parsed.lp,
            .pb = parsed.pb,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Overflow => return error.IntegerOverflow,
        };
        self.decoder = state;
        self.dictionary = lzma_decoder.CircularBuffer.init(parsed.dictionary_size, output_limit);
        self.header = parsed;
        self.declared_size = declared_size;
    }

    fn validateFinalSize(self: *Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.validated_output != expected) return error.SizeMismatch;
        if (self.declared_size == null and !self.saw_end_marker)
            return error.InvalidLzmaStream;
    }

    fn ensureCompressed(
        self: *Decoder,
        target: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        if (self.bufferedCompressedLen() >= target) return true;
        self.compactCompressed();
        const take = @min(target - self.bufferedCompressedLen(), input.len - input_read.*);
        if (take != 0) {
            if (self.bufferedCompressedLen() + take > self.options.max_compressed_buffer_len)
                return error.OutputLimitExceeded;
            try self.compressed.ensureTotalCapacityPrecise(self.allocator, self.compressed.items.len + take);
            try self.compressed.appendSlice(self.allocator, input[input_read.*..][0..take]);
            input_read.* += take;
        }
        return self.bufferedCompressedLen() >= target;
    }

    fn appendCompressedGuard(
        self: *Decoder,
        input: []const u8,
        input_read: *usize,
    ) Error!void {
        self.compactCompressed();
        const buffered = self.bufferedCompressedLen();
        if (buffered >= self.options.max_compressed_buffer_len)
            return error.OutputLimitExceeded;
        const target = @min(symbol_input_guard, self.options.max_compressed_buffer_len);
        if (target <= buffered) return error.OutputLimitExceeded;
        const take = @min(target - buffered, input.len - input_read.*);
        if (take == 0) return error.OutputLimitExceeded;
        try self.compressed.ensureTotalCapacityPrecise(self.allocator, self.compressed.items.len + take);
        try self.compressed.appendSlice(self.allocator, input[input_read.*..][0..take]);
        input_read.* += take;
    }

    fn advanceCompressed(self: *Decoder, count: usize) void {
        std.debug.assert(count <= self.bufferedCompressedLen());
        self.compressed_start += count;
        if (self.compressed_start == self.compressed.items.len) {
            self.compressed.clearRetainingCapacity();
            self.compressed_start = 0;
        }
    }

    fn compactCompressed(self: *Decoder) void {
        if (self.compressed_start == 0) return;
        const remaining = self.compressed.items.len - self.compressed_start;
        std.mem.copyForwards(
            u8,
            self.compressed.items[0..remaining],
            self.compressed.items[self.compressed_start..],
        );
        self.compressed.items.len = remaining;
        self.compressed_start = 0;
    }

    fn bufferedCompressedLen(self: *const Decoder) usize {
        return self.compressed.items.len - self.compressed_start;
    }

    fn recordError(self: *Decoder, phase: Phase, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};
