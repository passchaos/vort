const std = @import("std");
const container = @import("container.zig");
const core = @import("../core.zig");
const working = @import("../io/working_allocator.zig");
const options_mod = @import("incremental/options.zig");
const block_mod = @import("incremental/block_decoder.zig");
const checks = @import("incremental/checks.zig");
const index_mod = @import("incremental/index_decoder.zig");

/// Progressive XZ container decoder. LZMA2 symbols, inverse-filter tails, and
/// checks use bounded state; complete-block prevalidation is an explicit policy.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    budget: working.WorkingAllocator,
    phase: Phase = .stream_header,
    buffer: std.ArrayList(u8) = .empty,
    buffer_start: usize = 0,
    stream_flags: [2]u8 = @splat(0),
    check: container.Check = .none,
    block_header: ?container.BlockHeader = null,
    progressive: ?block_mod.Decoder = null,
    records: std.ArrayList(container.BlockRecord) = .empty,
    pending_output: []u8 = &.{},
    pending_offset: usize = 0,
    prevalidated: std.ArrayList(u8) = .empty,
    validation_temporary: [256]u8 = undefined,
    block_padding_remaining: usize = 0,
    block_record: container.BlockRecord = .{ .unpadded_size = 0, .uncompressed_size = 0 },
    check_bytes: [32]u8 = undefined,
    check_received: usize = 0,
    index: index_mod.Decoder = .{},
    validated_output: usize = 0,
    output_written: usize = 0,
    input_read: usize = 0,
    stream_input_read: usize = 0,
    stream_output_written: usize = 0,
    stream_started: bool = false,
    stream_count: usize = 0,
    block_count: usize = 0,
    published_block_count: usize = 0,
    current_padding_bytes: usize = 0,
    total_padding_bytes: usize = 0,
    input_finished: bool = false,
    failure: ?Error = null,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .stream_header,
    error_input_offset: ?usize = null,
    error_output_offset: ?usize = null,
    last_step_progress: core.Progress = .{},

    pub const Error = container.Error || block_mod.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
    pub const Options = options_mod.Options;
    pub const InputPolicy = options_mod.InputPolicy;
    pub const Phase = enum { stream_header, block_header, block_payload, block_padding, block_check, output, index_footer, stream_padding, done };
    pub const Snapshot = struct {
        phase: Phase,
        buffered_input: usize,
        pending_output: usize,
        validated_output: usize,
        output_written: usize,
        input_read: usize,
        stream_input_read: usize,
        stream_output_written: usize,
        stream_count: usize,
        block_count: usize,
        published_block_count: usize,
        current_stream_records: usize,
        current_dictionary_size: ?u64,
        padding_bytes: usize,
        retained_input_capacity: usize,
        retained_compressed_capacity: usize,
        retained_decoded_capacity: usize,
        retained_record_capacity: usize,
        working_bytes: usize,
        peak_working_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        error_input_offset: ?usize,
        error_output_offset: ?usize,
        last_step_progress: core.Progress,
        trailing_input_bytes: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }
    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory) };
    }
    pub fn deinit(self: *Decoder) void {
        self.releaseBlock();
        self.buffer.deinit(self.budget.allocator());
        self.records.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
        self.* = undefined;
    }
    pub fn reset(self: *Decoder) void {
        self.releaseBlock();
        var buffer = self.buffer;
        var records = self.records;
        var budget = self.budget;
        buffer.clearRetainingCapacity();
        records.clearRetainingCapacity();
        budget.peak = budget.live;
        budget.hit_limit = false;
        budget.last_failure_was_limit = false;
        self.* = initWithOptions(self.allocator, self.options);
        self.buffer = buffer;
        self.records = records;
        self.budget = budget;
    }
    /// Existing void API: invalid settings preserve owned state and latch the
    /// validation error. Call Options.validate() first for a fallible check.
    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        options.validate() catch |err| {
            self.recordError(err);
            self.failure = err;
            return;
        };
        const allocator = self.allocator;
        self.deinit();
        self.* = initWithOptions(allocator, options);
    }
    pub fn nextStream(self: *Decoder) Error!void {
        if (!self.options.stop_after_first_stream or self.phase != .done or self.failure != null) return error.InvalidStreamState;
        self.phase = .stream_padding;
        self.input_finished = false;
        self.last_step_progress = .{};
        self.clearError();
    }
    pub fn workingMemoryBytes(self: *const Decoder) usize {
        return self.budget.live;
    }
    pub fn peakWorkingMemoryBytes(self: *const Decoder) usize {
        return self.budget.peak;
    }
    pub fn compressedBufferCapacity(self: *const Decoder) usize {
        return self.buffer.capacity + if (self.progressive) |*block| block.raw.snapshot().retained_compressed_capacity else @as(usize, 0);
    }
    pub fn decodedBufferCapacity(self: *const Decoder) usize {
        return if (self.progressive) |*block| block.staging_budget.live else @as(usize, 0);
    }
    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .buffered_input = self.bufferedLen() + if (self.progressive) |*block| block.raw.snapshot().buffered_compressed_bytes else @as(usize, 0),
            .pending_output = self.pending_output.len - self.pending_offset + if (self.progressive) |*block| block.staged.items.len - block.staged_offset + block.raw.snapshot().pending_output else @as(usize, 0),
            .validated_output = self.validated_output,
            .output_written = self.output_written,
            .input_read = self.input_read,
            .stream_input_read = self.stream_input_read,
            .stream_output_written = self.stream_output_written,
            .stream_count = self.stream_count,
            .block_count = self.block_count,
            .published_block_count = self.published_block_count,
            .current_stream_records = self.records.items.len,
            .current_dictionary_size = if (self.block_header) |header| header.dictionary_size else null,
            .padding_bytes = self.total_padding_bytes,
            .retained_input_capacity = self.buffer.capacity,
            .retained_compressed_capacity = self.compressedBufferCapacity(),
            .retained_decoded_capacity = self.decodedBufferCapacity(),
            .retained_record_capacity = self.records.capacity,
            .working_bytes = self.budget.live,
            .peak_working_bytes = self.budget.peak,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
            .last_step_progress = self.last_step_progress,
            .trailing_input_bytes = self.trailingInput().len,
        };
    }
    pub fn trailingInput(self: *const Decoder) []const u8 {
        if (!self.options.stop_after_first_stream or self.phase != .done) return &.{};
        return self.buffer.items[self.buffer_start..];
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .input_read = self.input_read,
            .frame_input_read = self.stream_input_read,
            .output_written = self.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = self.snapshot().pending_output,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
            .last_step_progress = self.last_step_progress,
            .recoverability_hint_name = if (self.failure) |err| switch (err) {
                error.WorkingMemoryLimitExceeded => "raise_working_memory_limit",
                error.OutputLimitExceeded => "raise_input_output_or_dictionary_limit",
                error.OutOfMemory => "allocation_failure",
                error.TruncatedFrame => "truncated_input",
                else => "payload_corrupt",
            } else "none",
        };
    }
    /// Seal input; step("", output) continues checks, footer, padding and EOF.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
        if (self.progressive) |*block| block.raw.finish();
    }
    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        self.rebindBlock();
        self.last_step_progress = .{};
        if (self.failure) |err| return err;
        self.clearError();
        self.budget.last_failure_was_limit = false;
        const before = core.Progress{ .input_read = self.input_read, .output_written = self.output_written };
        const decoded = self.stepChecked(input, output) catch |original| {
            const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else if (original == error.CompressedBufferLimitExceeded) error.OutputLimitExceeded else original;
            self.last_step_progress = .{ .input_read = self.input_read - before.input_read, .output_written = self.output_written - before.output_written };
            self.recordError(err);
            const short_stopped_pledge = err == error.SizeMismatch and self.options.stop_after_first_stream and self.phase == .done and self.output_written < (self.options.expected_output_len orelse 0);
            if (!short_stopped_pledge) self.failure = err;
            return err;
        };
        self.last_step_progress = decoded.progress;
        return decoded;
    }

    fn stepChecked(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (input.len > std.math.maxInt(usize) - self.input_read) return error.IntegerOverflow;
        return self.stepInternal(input, output);
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        try self.options.validate();
        if (self.phase == .done) {
            if (self.input_finished) try self.checkExpectedOutput();
            if (self.options.stop_after_first_stream or input.len == 0) return .{ .status = .done };
            return error.TrailingData;
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        var read: usize = 0;
        var written: usize = 0;
        while (true) switch (self.phase) {
            .stream_header => {
                if (!self.stream_started) {
                    self.stream_input_read = 0;
                    self.stream_output_written = 0;
                    self.stream_started = true;
                }
                if (!try self.ensureBuffered(12, input, &read)) return self.needInput(read, written);
                const parsed = try container.parseStreamHeader(self.buffer.items[self.buffer_start..][0..12]);
                self.stream_flags = parsed.flags;
                self.check = parsed.check;
                self.advanceBuffer(12);
                self.records.clearRetainingCapacity();
                self.phase = .block_header;
            },
            .block_header => {
                if (!try self.ensureBuffered(1, input, &read)) return self.needInput(read, written);
                const size_byte = self.buffer.items[self.buffer_start];
                if (size_byte == 0) {
                    self.index = .{};
                    self.phase = .index_footer;
                    continue;
                }
                const header_len = (@as(usize, size_byte) + 1) * 4;
                if (!try self.ensureBuffered(header_len, input, &read)) return self.needInput(read, written);
                const header = try container.parseIncrementalBlockHeader(self.buffer.items[self.buffer_start..][0..header_len]);
                if (header.dictionary_size > self.options.max_dictionary_size or self.records.items.len >= self.options.max_block_count) return error.OutputLimitExceeded;
                self.advanceBuffer(header_len);
                self.block_header = header;
                {
                    const output_limit = @min(self.options.max_decoded_block_len, self.options.max_output_len - self.output_written);
                    const expected_remaining = if (self.options.expected_output_len) |size| size - self.output_written else output_limit;
                    self.progressive = try block_mod.Decoder.init(self.budget.allocator(), header, self.check, @min(output_limit, expected_remaining), self.options.expected_output_len != null and expected_remaining < output_limit, self.options.max_compressed_block_len, self.options.max_compressed_buffer_len - self.buffer.capacity, self.options.max_decoded_buffer_len, self.options.max_dictionary_size);
                    if (self.input_finished) self.progressive.?.raw.finish();
                }
                self.phase = .block_payload;
            },
            .block_payload => {
                if (self.progressive) |*block| {
                    const buffered = self.bufferedLen() != 0;
                    const source = if (buffered) self.buffer.items[self.buffer_start..] else input[read..];
                    const before_read = block.input_read;
                    const before_written = block.output_written;
                    const prevalidated = self.options.input_policy == .prevalidated_block;
                    const target = if (prevalidated) &self.validation_temporary else output[written..];
                    const decoded = block.step(source, target) catch |err| {
                        self.acceptBlockProgress(buffered, block.input_read - before_read, if (prevalidated) 0 else block.output_written - before_written, &read, &written);
                        return err;
                    };
                    self.acceptBlockProgress(buffered, decoded.progress.input_read, if (prevalidated) 0 else decoded.progress.output_written, &read, &written);
                    if (prevalidated and decoded.progress.output_written != 0) {
                        const needed = std.math.add(usize, self.prevalidated.items.len, decoded.progress.output_written) catch return error.IntegerOverflow;
                        if (needed > self.options.max_decoded_buffer_len) return error.OutputLimitExceeded;
                        if (needed > self.prevalidated.capacity) {
                            const declared = if (block.header.unpacked_size) |size| std.math.cast(usize, size) orelse return error.OutputLimitExceeded else std.math.maxInt(usize);
                            const limit = @min(self.options.max_decoded_buffer_len, declared);
                            const capacity = @min(limit, @max(needed, std.math.mul(usize, @max(self.prevalidated.capacity, 8), 2) catch limit));
                            self.prevalidated.ensureTotalCapacityPrecise(block.stagingAllocator(), capacity) catch |err| {
                                return if (block.staging_budget.last_failure_was_limit) error.OutputLimitExceeded else err;
                            };
                        }
                        self.prevalidated.appendSliceAssumeCapacity(target[0..decoded.progress.output_written]);
                    }
                    if (self.compressedBufferCapacity() > self.options.max_compressed_buffer_len) return error.OutputLimitExceeded;
                    if (decoded.status == .done) {
                        self.block_padding_remaining = (4 - ((block.header.header_size % 4 + block.input_read % 4) % 4)) % 4;
                        const packed_with_header = std.math.add(u64, block.header.header_size, block.input_read) catch return error.IntegerOverflow;
                        self.block_record = .{ .unpadded_size = std.math.add(u64, packed_with_header, try checks.size(self.check)) catch return error.IntegerOverflow, .uncompressed_size = block.output_written };
                        if (!prevalidated) self.published_block_count += 1;
                        self.check_received = 0;
                        self.phase = .block_padding;
                        continue;
                    }
                    if (decoded.status == .need_input) {
                        if (self.bufferedLen() != 0 or read != input.len) continue;
                        return self.needInput(read, written);
                    }
                    if (prevalidated) continue;
                    return result(read, written, .need_output);
                }
                return error.InvalidXzStream;
            },
            .block_padding => {
                while (self.block_padding_remaining != 0) {
                    const byte = self.takeByte(input, &read) orelse return self.needInput(read, written);
                    if (byte != 0) return error.InvalidXzStream;
                    self.block_padding_remaining -= 1;
                }
                self.phase = .block_check;
            },
            .block_check => {
                const check_len = try checks.size(self.check);
                while (self.check_received != check_len) {
                    self.check_bytes[self.check_received] = self.takeByte(input, &read) orelse return self.needInput(read, written);
                    self.check_received += 1;
                }
                try self.progressive.?.check_state.verify(self.check, self.check_bytes[0..check_len]);
                try self.records.append(self.budget.allocator(), self.block_record);
                self.validated_output += @intCast(self.block_record.uncompressed_size);
                self.block_count += 1;
                self.block_header = null;
                if (self.options.input_policy == .prevalidated_block) {
                    // Keep the ArrayList's capacity and its stable child
                    // allocator alive while this borrowed view drains.
                    self.pending_output = self.prevalidated.items;
                    self.pending_offset = 0;
                    self.phase = .output;
                } else {
                    self.releaseBlock();
                    self.phase = .block_header;
                }
            },
            .output => {
                const n = @min(output.len - written, self.pending_output.len - self.pending_offset);
                @memcpy(output[written..][0..n], self.pending_output[self.pending_offset..][0..n]);
                self.pending_offset += n;
                written += n;
                self.output_written += n;
                self.stream_output_written += n;
                if (self.pending_offset != self.pending_output.len) return result(read, written, .need_output);
                self.releaseBlock();
                self.published_block_count += 1;
                self.phase = .block_header;
            },
            .index_footer => {
                while (true) {
                    if (self.index.length >= self.options.max_index_footer_len) return error.OutputLimitExceeded;
                    const byte = self.takeByte(input, &read) orelse return self.needInput(read, written);
                    if (try self.index.push(byte, self.records.items, self.stream_flags, self.options.max_index_footer_len)) break;
                }
                self.records.clearRetainingCapacity();
                self.stream_count += 1;
                self.current_padding_bytes = 0;
                self.stream_started = false;
                if (self.options.stop_after_first_stream) {
                    self.phase = .done;
                    return result(read, written, .done);
                }
                self.phase = .stream_padding;
            },
            .stream_padding => {
                while (true) {
                    const byte = if (self.bufferedLen() != 0) self.buffer.items[self.buffer_start] else if (read != input.len) input[read] else break;
                    if (byte != 0) {
                        if (self.current_padding_bytes % 4 != 0) return error.InvalidXzStream;
                        self.current_padding_bytes = 0;
                        self.phase = .stream_header;
                        break;
                    }
                    _ = self.takeByte(input, &read);
                    self.current_padding_bytes += 1;
                    self.total_padding_bytes += 1;
                }
                if (self.phase == .stream_header) continue;
                if (!self.input_finished) return result(read, written, .need_input);
                if (self.current_padding_bytes % 4 != 0) return error.InvalidXzStream;
                try self.checkExpectedOutput();
                self.phase = .done;
                return result(read, written, .done);
            },
            .done => return result(read, written, .done),
        };
    }

    fn acceptBlockProgress(self: *Decoder, buffered: bool, read: usize, written: usize, step_read: *usize, step_written: *usize) void {
        if (buffered) self.advanceBuffer(read) else {
            step_read.* += read;
            self.input_read += read;
            self.stream_input_read += read;
        }
        step_written.* += written;
        self.output_written += written;
        self.stream_output_written += written;
    }
    fn releaseBlock(self: *Decoder) void {
        self.rebindBlock();
        if (self.progressive) |*block| {
            self.prevalidated.deinit(block.stagingAllocator());
            self.prevalidated = .empty;
            block.deinit();
        }
        self.progressive = null;
        self.pending_output = &.{};
        self.pending_offset = 0;
    }
    fn rebindBlock(self: *Decoder) void {
        if (self.progressive) |*block| block.rebindAllocator(self.budget.allocator());
    }
    fn checkExpectedOutput(self: *const Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.output_written != expected) return error.SizeMismatch;
    }
    fn needInput(self: *const Decoder, read: usize, written: usize) Error!core.StepResult {
        if (self.input_finished) return error.TruncatedFrame;
        return result(read, written, .need_input);
    }
    fn takeByte(self: *Decoder, input: []const u8, read: *usize) ?u8 {
        if (self.bufferedLen() != 0) {
            const byte = self.buffer.items[self.buffer_start];
            self.advanceBuffer(1);
            return byte;
        }
        if (read.* == input.len) return null;
        const byte = input[read.*];
        read.* += 1;
        self.input_read += 1;
        self.stream_input_read += 1;
        return byte;
    }
    fn ensureBuffered(self: *Decoder, target: usize, input: []const u8, read: *usize) Error!bool {
        if (self.bufferedLen() >= target) return true;
        self.compactBuffer();
        const n = @min(target - self.bufferedLen(), input.len - read.*);
        if (n != 0) try self.appendInput(input[read.*..][0..n], read);
        return self.bufferedLen() >= target;
    }
    fn appendInput(self: *Decoder, bytes: []const u8, read: *usize) Error!void {
        const required = self.buffer.items.len + bytes.len;
        if (required > self.options.max_compressed_buffer_len) return error.OutputLimitExceeded;
        try self.buffer.ensureTotalCapacityPrecise(self.budget.allocator(), required);
        self.buffer.appendSliceAssumeCapacity(bytes);
        read.* += bytes.len;
        self.input_read += bytes.len;
        self.stream_input_read += bytes.len;
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
        const remaining = self.bufferedLen();
        std.mem.copyForwards(u8, self.buffer.items[0..remaining], self.buffer.items[self.buffer_start..]);
        self.buffer.items.len = remaining;
        self.buffer_start = 0;
    }
    fn bufferedLen(self: *const Decoder) usize {
        return self.buffer.items.len - self.buffer_start;
    }
    fn clearError(self: *Decoder) void {
        self.last_error_name = "";
        self.error_input_offset = null;
        self.error_output_offset = null;
    }
    fn recordError(self: *Decoder, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = self.phase;
        self.error_input_offset = self.input_read;
        self.error_output_offset = self.output_written;
    }
    fn result(read: usize, written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = read, .output_written = written }, .status = status };
    }
};
