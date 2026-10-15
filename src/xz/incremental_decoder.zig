const std = @import("std");
const container = @import("container.zig");
const core = @import("../core.zig");

/// Block-bounded, caller-output XZ/LZMA2 decoder. A complete block is retained
/// only until its LZMA2 payload, optional filters, and selected check validate;
/// Index/Footer validation is resumed after all block output has drained.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .stream_header,
    buffer: std.ArrayList(u8) = .empty,
    buffer_start: usize = 0,
    retry_at_len: usize = 1,
    stream_flags: [2]u8 = @splat(0),
    check: container.Check = .none,
    block_header: ?container.BlockHeader = null,
    records: std.ArrayList(container.BlockRecord) = .empty,
    pending_output: []u8 = &.{},
    pending_offset: usize = 0,
    validated_output: usize = 0,
    output_written: usize = 0,
    stream_count: usize = 0,
    block_count: usize = 0,
    current_padding_bytes: usize = 0,
    total_padding_bytes: usize = 0,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .stream_header,

    pub const Error = container.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_dictionary_size: usize = std.math.maxInt(usize),
        max_compressed_block_len: usize = 64 * 1024 * 1024,
        max_decoded_block_len: usize = 64 * 1024 * 1024,
        max_index_footer_len: usize = 16 * 1024 * 1024,
        max_block_count: usize = 1024 * 1024,
        expected_output_len: ?usize = null,
        /// Stop after the first validated Index/Footer, before consuming XZ
        /// stream padding or a following container record.
        stop_after_first_stream: bool = false,
        /// Optional retry granularity used only while locating that first
        /// Index/Footer boundary. Zero preserves exponential retry growth.
        first_stream_footer_retry_granularity: usize = 0,
    };
    pub const Phase = enum {
        stream_header,
        block_header,
        block_payload,
        output,
        index_footer,
        stream_padding,
        done,
    };
    pub const Snapshot = struct {
        phase: Phase,
        buffered_input: usize,
        pending_output: usize,
        validated_output: usize,
        output_written: usize,
        stream_count: usize,
        block_count: usize,
        current_stream_records: usize,
        current_dictionary_size: ?u64,
        padding_bytes: usize,
        retained_input_capacity: usize,
        retained_record_capacity: usize,
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
        if (self.pending_output.len != 0) self.allocator.free(self.pending_output);
        self.buffer.deinit(self.allocator);
        self.records.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        if (self.pending_output.len != 0) allocator.free(self.pending_output);
        var buffer = self.buffer;
        var records = self.records;
        buffer.clearRetainingCapacity();
        records.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .buffer = buffer,
            .records = records,
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .buffered_input = self.bufferedLen(),
            .pending_output = self.pending_output.len - self.pending_offset,
            .validated_output = self.validated_output,
            .output_written = self.output_written,
            .stream_count = self.stream_count,
            .block_count = self.block_count,
            .current_stream_records = self.records.items.len,
            .current_dictionary_size = if (self.block_header) |header| header.dictionary_size else null,
            .padding_bytes = self.total_padding_bytes,
            .retained_input_capacity = self.buffer.capacity,
            .retained_record_capacity = self.records.capacity,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .trailing_input_bytes = self.trailingInput().len,
        };
    }

    pub fn trailingInput(self: *const Decoder) []const u8 {
        if (!self.options.stop_after_first_stream or self.phase != .done)
            return &.{};
        return self.buffer.items[self.buffer_start..];
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
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

    /// Declare that no more compressed input will arrive. Parsing, block
    /// output, Index/Footer validation, and final padding checks continue via
    /// `step("", output)` until `.done` or an exact error is returned.
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
            if (self.options.stop_after_first_stream) return .{ .status = .done };
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .stream_header => {
                if (!try self.ensureBuffered(12, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                const parsed = try container.parseStreamHeader(self.buffer.items[self.buffer_start..][0..12]);
                self.stream_flags = parsed.flags;
                self.check = parsed.check;
                self.advanceBuffer(12);
                self.records.clearRetainingCapacity();
                self.block_header = null;
                self.retry_at_len = 1;
                self.phase = .block_header;
            },
            .block_header => {
                if (!try self.ensureBuffered(1, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                const size_byte = self.buffer.items[self.buffer_start];
                if (size_byte == 0) {
                    self.retry_at_len = 16;
                    self.phase = .index_footer;
                    continue;
                }
                const header_len = (@as(usize, size_byte) + 1) * 4;
                if (!try self.ensureBuffered(header_len, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                const parsed = try container.parseIncrementalBlockHeader(
                    self.buffer.items[self.buffer_start..][0..header_len],
                );
                if (parsed.dictionary_size > self.options.max_dictionary_size)
                    return error.OutputLimitExceeded;
                self.advanceBuffer(header_len);
                self.block_header = parsed;
                self.retry_at_len = 1;
                self.phase = .block_payload;
            },
            .block_payload => {
                const force = self.input_finished and input_read == input.len;
                if (force or self.bufferedLen() >= self.retry_at_len) {
                    const decoded_block = container.decodeIncrementalBlockAlloc(
                        self.allocator,
                        self.block_header orelse return error.InvalidXzStream,
                        self.buffer.items[self.buffer_start..],
                        self.check,
                        @min(
                            self.options.max_decoded_block_len,
                            self.options.max_output_len -| self.validated_output,
                        ),
                    ) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            if (force) return error.TruncatedFrame;
                            try self.scheduleRetry(self.options.max_compressed_block_len);
                            continue;
                        },
                        else => |decode_error| return decode_error,
                    };
                    errdefer decoded_block.deinit(self.allocator);
                    if (self.records.items.len >= self.options.max_block_count)
                        return error.OutputLimitExceeded;
                    const next_output = std.math.add(usize, self.validated_output, decoded_block.decoded.len) catch
                        return error.IntegerOverflow;
                    if (next_output > self.options.max_output_len) return error.OutputLimitExceeded;
                    if (self.options.expected_output_len) |expected|
                        if (next_output > expected) return error.SizeMismatch;
                    const next_block_count = std.math.add(usize, self.block_count, 1) catch
                        return error.IntegerOverflow;
                    try self.records.append(self.allocator, decoded_block.record);
                    self.advanceBuffer(decoded_block.consumed);
                    self.pending_output = decoded_block.decoded;
                    self.pending_offset = 0;
                    self.validated_output = next_output;
                    self.block_count = next_block_count;
                    self.block_header = null;
                    self.retry_at_len = 1;
                    self.phase = .output;
                } else {
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.appendRetryInput(
                        self.options.max_compressed_block_len,
                        input,
                        &input_read,
                    );
                }
            },
            .output => {
                const remaining = self.pending_output[self.pending_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.output_written += take;
                if (self.pending_offset != self.pending_output.len)
                    return result(input_read, output_written, .need_output);
                self.allocator.free(self.pending_output);
                self.pending_output = &.{};
                self.pending_offset = 0;
                self.phase = .block_header;
            },
            .index_footer => {
                const force = self.input_finished and input_read == input.len;
                if (force or self.bufferedLen() >= self.retry_at_len) {
                    const consumed = container.validateIncrementalIndexFooter(
                        self.buffer.items[self.buffer_start..],
                        &self.stream_flags,
                        self.records.items,
                    ) catch |err| switch (err) {
                        error.TruncatedFrame => {
                            if (force) return error.TruncatedFrame;
                            try self.scheduleRetry(self.options.max_index_footer_len);
                            continue;
                        },
                        else => |decode_error| return decode_error,
                    };
                    if (consumed > self.options.max_index_footer_len)
                        return error.OutputLimitExceeded;
                    const next_stream_count = std.math.add(usize, self.stream_count, 1) catch
                        return error.IntegerOverflow;
                    self.advanceBuffer(consumed);
                    self.records.clearRetainingCapacity();
                    self.stream_count = next_stream_count;
                    self.current_padding_bytes = 0;
                    if (self.options.stop_after_first_stream) {
                        if (self.options.expected_output_len) |expected|
                            if (self.validated_output != expected) return error.SizeMismatch;
                        self.phase = .done;
                        return result(input_read, output_written, .done);
                    }
                    self.phase = .stream_padding;
                } else {
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.appendRetryInput(
                        self.options.max_index_footer_len,
                        input,
                        &input_read,
                    );
                }
            },
            .stream_padding => {
                while (self.bufferedLen() != 0 and self.buffer.items[self.buffer_start] == 0) {
                    self.advanceBuffer(1);
                    self.current_padding_bytes = std.math.add(usize, self.current_padding_bytes, 1) catch
                        return error.IntegerOverflow;
                    self.total_padding_bytes = std.math.add(usize, self.total_padding_bytes, 1) catch
                        return error.IntegerOverflow;
                }
                if (self.bufferedLen() != 0) {
                    if (self.current_padding_bytes % 4 != 0) return error.InvalidXzStream;
                    self.current_padding_bytes = 0;
                    self.phase = .stream_header;
                    continue;
                }
                while (input_read < input.len and input[input_read] == 0) {
                    input_read += 1;
                    self.current_padding_bytes = std.math.add(usize, self.current_padding_bytes, 1) catch
                        return error.IntegerOverflow;
                    self.total_padding_bytes = std.math.add(usize, self.total_padding_bytes, 1) catch
                        return error.IntegerOverflow;
                }
                if (input_read != input.len) {
                    if (self.current_padding_bytes % 4 != 0) return error.InvalidXzStream;
                    self.current_padding_bytes = 0;
                    self.phase = .stream_header;
                    continue;
                }
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                if (self.current_padding_bytes % 4 != 0) return error.InvalidXzStream;
                if (self.options.expected_output_len) |expected|
                    if (self.validated_output != expected) return error.SizeMismatch;
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn ensureBuffered(
        self: *Decoder,
        target_len: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        if (self.bufferedLen() >= target_len) return true;
        self.compactBuffer();
        const take = @min(target_len - self.bufferedLen(), input.len - input_read.*);
        if (take != 0) {
            try self.buffer.ensureTotalCapacityPrecise(self.allocator, self.buffer.items.len + take);
            try self.buffer.appendSlice(self.allocator, input[input_read.*..][0..take]);
            input_read.* += take;
        }
        return self.bufferedLen() >= target_len;
    }

    fn appendRetryInput(
        self: *Decoder,
        limit: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!void {
        self.compactBuffer();
        const buffered = self.bufferedLen();
        if (buffered >= limit) return error.OutputLimitExceeded;
        const target = @min(self.retry_at_len, limit);
        if (target <= buffered) return error.OutputLimitExceeded;
        const take = @min(target - buffered, input.len - input_read.*);
        if (take == 0) return error.OutputLimitExceeded;
        try self.buffer.ensureTotalCapacityPrecise(self.allocator, self.buffer.items.len + take);
        try self.buffer.appendSlice(self.allocator, input[input_read.*..][0..take]);
        input_read.* += take;
    }

    fn scheduleRetry(self: *Decoder, limit: usize) Error!void {
        const buffered = self.bufferedLen();
        if (buffered >= limit) return error.OutputLimitExceeded;
        const growth = if (self.phase == .index_footer and
            self.options.stop_after_first_stream and
            self.options.first_stream_footer_retry_granularity != 0)
            self.options.first_stream_footer_retry_granularity
        else
            @max(buffered, 64);
        const wanted = std.math.add(usize, buffered, growth) catch limit;
        self.retry_at_len = @min(wanted, limit);
        if (self.retry_at_len <= buffered) return error.OutputLimitExceeded;
    }

    fn advanceBuffer(self: *Decoder, count: usize) void {
        std.debug.assert(count <= self.bufferedLen());
        self.buffer_start += count;
        if (self.buffer_start == self.buffer.items.len) {
            self.buffer.clearRetainingCapacity();
            self.buffer_start = 0;
        }
    }

    fn compactBuffer(self: *Decoder) void {
        if (self.buffer_start == 0) return;
        const remaining = self.buffer.items.len - self.buffer_start;
        std.mem.copyForwards(
            u8,
            self.buffer.items[0..remaining],
            self.buffer.items[self.buffer_start..],
        );
        self.buffer.items.len = remaining;
        self.buffer_start = 0;
    }

    fn bufferedLen(self: *const Decoder) usize {
        return self.buffer.items.len - self.buffer_start;
    }

    fn recordError(self: *Decoder, phase: Phase, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};
