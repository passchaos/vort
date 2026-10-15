const std = @import("std");
const core = @import("../core.zig");
const decoder = @import("decoder.zig");

/// Caller-output Bzip2 decoder that retains at most one bounded compressed
/// block plus transformed/decoded block scratch. Block CRCs are checked before
/// decoded bytes become visible; the stream combined CRC is checked at each
/// member terminator.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header: [4]u8 = undefined,
    header_len: usize = 0,
    block_limit: usize = 0,
    compressed: std.ArrayList(u8) = .empty,
    compressed_start: usize = 0,
    bit_offset: usize = 0,
    retry_at_len: usize = marker_len,
    transformed: std.ArrayList(u8) = .empty,
    decoded: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    combined_crc: u32 = 0,
    validated_output: usize = 0,
    output_written: usize = 0,
    stream_count: usize = 0,
    block_count: usize = 0,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const marker_len: usize = 6;
    pub const Error = decoder.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_compressed_block_len: usize = 4 * 1024 * 1024,
        max_decoded_block_len: usize = 64 * 1024 * 1024,
        expected_output_len: ?usize = null,
        /// Stop after the first validated Bzip2 stream and retain any bytes
        /// already buffered beyond its terminator for an outer container.
        stop_after_first_stream: bool = false,
        /// Optional retry granularity while locating the first stream end.
        /// Outer containers set this to their smallest descriptor width to
        /// bound accepted suffix bytes. Zero preserves exponential retries.
        first_stream_retry_granularity: usize = 0,
    };
    pub const Phase = enum {
        header,
        input,
        output,
        between_streams,
        done,
    };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        buffered_compressed_bytes: usize,
        buffered_bit_offset: usize,
        pending_output: usize,
        validated_output: usize,
        output_written: usize,
        stream_count: usize,
        block_count: usize,
        block_size_limit: usize,
        retained_compressed_capacity: usize,
        retained_transformed_capacity: usize,
        retained_decoded_capacity: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        trailing_input_bytes: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Decoder) void {
        self.compressed.deinit(self.allocator);
        self.transformed.deinit(self.allocator);
        self.decoded.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        var compressed = self.compressed;
        var transformed = self.transformed;
        var decoded = self.decoded;
        compressed.clearRetainingCapacity();
        transformed.clearRetainingCapacity();
        decoded.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .compressed = compressed,
            .transformed = transformed,
            .decoded = decoded,
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .buffered_compressed_bytes = self.bufferedCompressedLen(),
            .buffered_bit_offset = self.bit_offset,
            .pending_output = self.decoded.items.len - self.decoded_offset,
            .validated_output = self.validated_output,
            .output_written = self.output_written,
            .stream_count = self.stream_count,
            .block_count = self.block_count,
            .block_size_limit = self.block_limit,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_transformed_capacity = self.transformed.capacity,
            .retained_decoded_capacity = self.decoded.capacity,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .trailing_input_bytes = self.trailingInput().len,
        };
    }

    /// Bytes accepted from the latest caller slice but proven to follow the
    /// first stream. This is non-empty only with `stop_after_first_stream` and
    /// remains borrowed until the next mutating call, reset, or deinit.
    pub fn trailingInput(self: *const Decoder) []const u8 {
        if (!self.options.stop_after_first_stream or self.phase != .done or self.bit_offset != 0)
            return &.{};
        return self.compressed.items[self.compressed_start..];
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
                "raise_input_or_output_limit"
            else if (snap.last_error_name.len == 0)
                "none"
            else
                "payload_corrupt",
        };
    }

    /// Declare that no more compressed input will arrive. Parsing and pending
    /// output remain resumable through `step("", output)`; that final drain
    /// reports truncation, CRC failure, size mismatch, or `.done`.
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
                std.debug.assert(self.bit_offset == 0);
                self.fillHeaderFromBuffer();
                if (self.header_len != self.header.len) {
                    const take = @min(self.header.len - self.header_len, input.len - input_read);
                    @memcpy(self.header[self.header_len..][0..take], input[input_read..][0..take]);
                    self.header_len += take;
                    input_read += take;
                }
                if (self.header_len != self.header.len) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.acceptHeader();
                self.phase = .input;
            },
            .input => {
                const force = self.input_finished and input_read == input.len;
                if (force or self.bufferedCompressedLen() >= self.retry_at_len) {
                    const part = decoder.decodeIncrementalPart(
                        self.allocator,
                        self.compressed.items[self.compressed_start..],
                        self.bit_offset,
                        self.block_limit,
                        @min(
                            self.options.max_decoded_block_len,
                            self.options.max_output_len -| self.validated_output,
                        ),
                        &self.transformed,
                        &self.decoded,
                    ) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            if (force) return error.TruncatedFrame;
                            try self.scheduleRetry();
                            continue;
                        },
                        else => |decode_error| return decode_error,
                    };
                    self.retry_at_len = marker_len;
                    self.transformed.clearRetainingCapacity();
                    switch (part) {
                        .block => |block| {
                            self.advanceCompressed(block.next_bit_offset);
                            const next_output = std.math.add(usize, self.validated_output, self.decoded.items.len) catch
                                return error.IntegerOverflow;
                            if (next_output > self.options.max_output_len) return error.OutputLimitExceeded;
                            if (self.options.expected_output_len) |expected|
                                if (next_output > expected) return error.SizeMismatch;
                            self.validated_output = next_output;
                            self.combined_crc = std.math.rotl(u32, self.combined_crc, 1) ^ block.crc32;
                            self.block_count = std.math.add(usize, self.block_count, 1) catch
                                return error.IntegerOverflow;
                            self.decoded_offset = 0;
                            self.phase = .output;
                            continue;
                        },
                        .end => |end| {
                            self.advanceCompressed(end.next_bit_offset);
                            if (end.combined_crc32 != self.combined_crc) return error.ChecksumMismatch;
                            self.stream_count = std.math.add(usize, self.stream_count, 1) catch
                                return error.IntegerOverflow;
                            self.phase = .between_streams;
                            continue;
                        },
                    }
                }

                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
                try self.appendCompressedInput(input, &input_read);
            },
            .output => {
                const remaining = self.decoded.items[self.decoded_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.decoded_offset += take;
                output_written += take;
                self.output_written += take;
                if (self.decoded_offset != self.decoded.items.len)
                    return result(input_read, output_written, .need_output);
                self.decoded.clearRetainingCapacity();
                self.decoded_offset = 0;
                self.phase = .input;
            },
            .between_streams => {
                if (self.options.stop_after_first_stream) {
                    if (self.options.expected_output_len) |expected|
                        if (self.validated_output != expected) return error.SizeMismatch;
                    self.phase = .done;
                    return result(input_read, output_written, .done);
                }
                self.header_len = 0;
                self.combined_crc = 0;
                self.block_limit = 0;
                if (self.bufferedCompressedLen() != 0 or input_read != input.len) {
                    self.phase = .header;
                    continue;
                }
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                if (self.options.expected_output_len) |expected|
                    if (self.validated_output != expected) return error.SizeMismatch;
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn acceptHeader(self: *Decoder) Error!void {
        if (!std.mem.eql(u8, self.header[0..3], "BZh")) return error.InvalidMagic;
        if (self.header[3] < '1' or self.header[3] > '9') return error.InvalidBzip2Header;
        self.block_limit = @as(usize, self.header[3] - '0') * 100_000;
        self.combined_crc = 0;
        self.retry_at_len = marker_len;
    }

    fn fillHeaderFromBuffer(self: *Decoder) void {
        const available = self.compressed.items[self.compressed_start..];
        const take = @min(self.header.len - self.header_len, available.len);
        @memcpy(self.header[self.header_len..][0..take], available[0..take]);
        self.header_len += take;
        self.compressed_start += take;
        if (self.compressed_start == self.compressed.items.len) {
            self.compressed.clearRetainingCapacity();
            self.compressed_start = 0;
        }
    }

    fn appendCompressedInput(self: *Decoder, input: []const u8, input_read: *usize) Error!void {
        self.compactCompressed();
        const buffered = self.bufferedCompressedLen();
        if (buffered >= self.options.max_compressed_block_len) return error.OutputLimitExceeded;
        const target = @min(self.retry_at_len, self.options.max_compressed_block_len);
        if (target <= buffered) return error.OutputLimitExceeded;
        const take = @min(target - buffered, input.len - input_read.*);
        if (take == 0) return error.OutputLimitExceeded;
        try self.compressed.ensureTotalCapacityPrecise(self.allocator, self.compressed.items.len + take);
        try self.compressed.appendSlice(self.allocator, input[input_read.*..][0..take]);
        input_read.* += take;
    }

    fn scheduleRetry(self: *Decoder) Error!void {
        const buffered = self.bufferedCompressedLen();
        if (buffered >= self.options.max_compressed_block_len) return error.OutputLimitExceeded;
        const growth = if (self.options.stop_after_first_stream and
            self.options.first_stream_retry_granularity != 0)
            self.options.first_stream_retry_granularity
        else
            @max(buffered, 64);
        const wanted = std.math.add(usize, buffered, growth) catch
            self.options.max_compressed_block_len;
        self.retry_at_len = @min(wanted, self.options.max_compressed_block_len);
        if (self.retry_at_len <= buffered) return error.OutputLimitExceeded;
    }

    fn advanceCompressed(self: *Decoder, next_bit_offset: usize) void {
        self.compressed_start += next_bit_offset / 8;
        self.bit_offset = next_bit_offset & 7;
        if (self.compressed_start == self.compressed.items.len and self.bit_offset == 0) {
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
