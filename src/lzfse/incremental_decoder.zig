const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const history_mod = @import("incremental/history.zig");
const fse_mod = @import("incremental/fse_cursor.zig");
const lzvn_mod = @import("incremental/lzvn_cursor.zig");
const options_mod = @import("incremental/options.zig");
const working = @import("../io/working_allocator.zig");

/// Resumable LZFSE stream decoder. Raw/LZVN input is byte-progressive;
/// reverse FSE retains only the bounded suffix its declared symbols can read.
/// Output history is caller-bounded and no decoded block is materialized.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    budget: working.WorkingAllocator,
    history: history_mod.Ring,
    compressed: std.ArrayList(u8) = .empty,
    header_bytes: [@max(format.v1_header_size, format.v2_max_header_size)]u8 = undefined,
    header_len: usize = 0,
    header_target: usize = 4,
    phase: Phase = .header,
    kind: ?Kind = null,
    fse_header: ?format.CompressedHeader = null,
    retained: fse_mod.Retained = .{ .literal = 0, .lmd = 0 },
    prefix_remaining: usize = 0,
    tail_remaining: usize = 0,
    raw_remaining: usize = 0,
    fse_cursor: ?fse_mod.Cursor = null,
    lzvn_cursor: ?lzvn_mod.Cursor = null,
    input_read: usize = 0,
    output_written: usize = 0,
    stream_input_read: usize = 0,
    stream_output_written: usize = 0,
    stream_count: usize = 0,
    blocks_completed: usize = 0,
    payload_prefix_skipped: usize = 0,
    input_finished: bool = false,
    failure: ?Error = null,
    last_error_phase: Phase = .header,
    error_input_offset: ?usize = null,
    error_output_offset: ?usize = null,
    last_step_progress: core.Progress = .{},

    pub const Options = options_mod.Options;
    pub const Error = core.Error || format.Error || std.mem.Allocator.Error || error{
        InvalidLzfseStream,
        InvalidLzvnStream,
        CompressedBufferLimitExceeded,
        HistoryLimitExceeded,
        WorkingMemoryLimitExceeded,
    };
    pub const Phase = enum { header, raw, lzvn, skip_literal, literal_tail, skip_lmd, lmd_tail, fse_output, done, failed };
    pub const Kind = enum { raw, lzvn, fse_v1, fse_v2 };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        input_read: usize,
        output_written: usize,
        stream_input_read: usize,
        stream_output_written: usize,
        stream_count: usize,
        blocks_completed: usize,
        buffered_compressed_bytes: usize,
        retained_compressed_capacity: usize,
        history_len: usize,
        history_capacity: usize,
        working_bytes: usize,
        peak_working_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        error_input_offset: ?usize,
        error_output_offset: ?usize,
        last_step_progress: core.Progress,
        payload_prefix_skipped: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }
    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory), .history = history_mod.Ring.init(options.max_history_len) };
    }
    pub fn deinit(self: *Decoder) void {
        self.fse_cursor = null;
        self.history.deinit(self.budget.allocator());
        self.compressed.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
        self.* = undefined;
    }
    pub fn reset(self: *Decoder) void {
        const allocator = self.allocator;
        const options = self.options;
        var history = self.history;
        var compressed = self.compressed;
        var budget = self.budget;
        history.reset();
        compressed.clearRetainingCapacity();
        budget.peak = budget.live;
        budget.hit_limit = false;
        budget.last_failure_was_limit = false;
        self.* = initWithOptions(allocator, options);
        self.history = history;
        self.compressed = compressed;
        self.budget = budget;
    }
    pub fn resetWithOptions(self: *Decoder, options: Options) Error!void {
        try options.validate();
        const allocator = self.allocator;
        self.deinitBuffers();
        self.* = initWithOptions(allocator, options);
    }
    fn deinitBuffers(self: *Decoder) void {
        self.fse_cursor = null;
        self.history.deinit(self.budget.allocator());
        self.compressed.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
    }
    pub fn nextStream(self: *Decoder) Error!void {
        if (self.phase != .done or !self.options.stop_after_end_marker) return error.InvalidLzfseStream;
        const read = self.input_read;
        const written = self.output_written;
        const count = self.stream_count;
        const blocks = self.blocks_completed;
        const skipped = self.payload_prefix_skipped;
        const peak = self.budget.peak;
        self.reset();
        self.input_read = read;
        self.output_written = written;
        self.stream_count = count;
        self.blocks_completed = blocks;
        self.payload_prefix_skipped = skipped;
        self.budget.peak = @max(self.budget.peak, peak);
    }
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }
    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .input_read = self.input_read,
            .output_written = self.output_written,
            .stream_input_read = self.stream_input_read,
            .stream_output_written = self.stream_output_written,
            .stream_count = self.stream_count,
            .blocks_completed = self.blocks_completed,
            .buffered_compressed_bytes = self.compressed.items.len,
            .retained_compressed_capacity = self.compressed.capacity,
            .history_len = self.history.bytes.items.len,
            .history_capacity = self.history.bytes.capacity,
            .working_bytes = self.budget.live,
            .peak_working_bytes = self.budget.peak,
            .input_finished = self.input_finished,
            .last_error_name = if (self.failure) |err| @errorName(err) else "",
            .last_error_phase = self.last_error_phase,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
            .last_step_progress = self.last_step_progress,
            .payload_prefix_skipped = self.payload_prefix_skipped,
        };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .input_read = self.input_read,
            .header_received = self.header_len,
            .frame_input_read = self.stream_input_read,
            .output_written = self.output_written,
            .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
            .last_error_name = if (self.failure) |err| @errorName(err) else "",
            .last_error_phase_name = if (self.failure != null) @tagName(self.last_error_phase) else "",
            .error_input_offset = core.stream_count.fromOptionalLocal(self.error_input_offset),
            .error_output_offset = core.stream_count.fromOptionalLocal(self.error_output_offset),
            .last_step_progress = self.last_step_progress,
            .recoverability_hint_name = if (self.failure) |err| switch (err) {
                error.TruncatedFrame => "truncated_input",
                error.HistoryLimitExceeded => "raise_history_limit",
                error.CompressedBufferLimitExceeded => "raise_compressed_buffer_limit",
                error.WorkingMemoryLimitExceeded => "raise_working_memory_limit",
                error.OutputLimitExceeded => "raise_output_limit",
                error.OutOfMemory => "allocation_failure",
                else => "payload_corrupt",
            } else "none",
        };
    }
    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        self.last_step_progress = .{};
        if (self.failure) |err| return err;
        const before = core.Progress{ .input_read = self.input_read, .output_written = self.output_written };
        const result = self.stepInternal(input, output) catch |original| {
            const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
            self.last_step_progress = .{ .input_read = self.input_read - before.input_read, .output_written = self.output_written - before.output_written };
            self.last_error_phase = self.phase;
            self.error_input_offset = self.input_read;
            self.error_output_offset = self.output_written;
            self.failure = err;
            self.phase = .failed;
            return err;
        };
        self.last_step_progress = result.progress;
        return result;
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        try self.options.validate();
        if (self.phase == .done) {
            if (!self.options.stop_after_end_marker and input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        var read: usize = 0;
        var written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const take = @min(self.header_target - self.header_len, input.len - read);
                try self.note(take, 0);
                @memcpy(self.header_bytes[self.header_len..][0..take], input[read..][0..take]);
                self.header_len += take;
                read += take;
                if (self.header_len != self.header_target) return self.needInput(read, written);
                if (self.header_target == 4) {
                    const magic = std.mem.readInt(u32, self.header_bytes[0..4], .little);
                    if (magic == format.end_of_stream_magic) {
                        if (self.options.expected_output_len) |expected| if (expected != self.stream_output_written) return error.SizeMismatch;
                        self.stream_count = try add(self.stream_count, 1);
                        self.phase = .done;
                        if (!self.options.stop_after_end_marker and read != input.len) return error.TrailingData;
                        return res(read, written, .done);
                    }
                    self.header_target = switch (magic) {
                        format.uncompressed_magic => 8,
                        format.compressed_lzvn_magic => 12,
                        format.compressed_v1_magic => format.v1_header_size,
                        format.compressed_v2_magic => format.v2_fixed_header_size,
                        else => return error.InvalidMagic,
                    };
                    continue;
                }
                const magic = std.mem.readInt(u32, self.header_bytes[0..4], .little);
                if (magic == format.compressed_v2_magic and self.header_target == format.v2_fixed_header_size) {
                    const size = std.mem.readInt(u32, self.header_bytes[24..28], .little);
                    if (size < format.v2_fixed_header_size or size > format.v2_max_header_size) return error.InvalidLzfseStream;
                    if (size != self.header_target) {
                        self.header_target = size;
                        continue;
                    }
                }
                try self.acceptHeader(magic);
            },
            .raw => {
                if (self.raw_remaining == 0) {
                    try self.completeBlock();
                    continue;
                }
                if (read == input.len) return self.needInput(read, written);
                if (written == output.len) return res(read, written, .need_output);
                const take = @min(self.raw_remaining, @min(input.len - read, output.len - written));
                try self.history.reserve(self.budget.allocator(), take);
                try self.note(take, take);
                @memcpy(output[written..][0..take], input[read..][0..take]);
                self.history.recordAssumeCapacity(output[written..][0..take]);
                self.raw_remaining -= take;
                read += take;
                written += take;
            },
            .lzvn => {
                const cursor = &self.lzvn_cursor.?;
                try self.history.reserve(self.budget.allocator(), @min(output.len - written, cursor.raw_size - cursor.decoded_len));
                const old_read = cursor.input_consumed;
                const old_written = cursor.decoded_len;
                const result = cursor.step(input[read..], self.history.view(), output[written..]) catch |err| {
                    const accepted = cursor.input_consumed - old_read;
                    const emitted = cursor.decoded_len - old_written;
                    try self.note(accepted, emitted);
                    self.history.recordAssumeCapacity(output[written..][0..emitted]);
                    return err;
                };
                try self.note(result.progress.input_read, result.progress.output_written);
                self.history.recordAssumeCapacity(output[written..][0..result.progress.output_written]);
                read += result.progress.input_read;
                written += result.progress.output_written;
                if (result.status == .done) {
                    try self.completeBlock();
                    continue;
                }
                if (result.status == .need_input) return self.needInput(read, written);
                return res(read, written, .need_output);
            },
            .skip_literal, .skip_lmd => {
                const take = @min(self.prefix_remaining, input.len - read);
                try self.note(take, 0);
                self.payload_prefix_skipped = try add(self.payload_prefix_skipped, take);
                self.prefix_remaining -= take;
                read += take;
                if (self.prefix_remaining != 0) return self.needInput(read, written);
                self.phase = if (self.phase == .skip_literal) .literal_tail else .lmd_tail;
                self.tail_remaining = if (self.phase == .literal_tail) self.retained.literal else self.retained.lmd;
            },
            .literal_tail, .lmd_tail => {
                const take = @min(self.tail_remaining, input.len - read);
                try self.compressed.appendSlice(self.budget.allocator(), input[read..][0..take]);
                try self.note(take, 0);
                self.tail_remaining -= take;
                read += take;
                if (self.tail_remaining != 0) return self.needInput(read, written);
                if (self.phase == .literal_tail) {
                    self.phase = .skip_lmd;
                    self.prefix_remaining = self.fse_header.?.lmd_payload_size - self.retained.lmd;
                } else {
                    self.fse_cursor = try fse_mod.Cursor.init(self.fse_header.?, self.compressed.items[0..self.retained.literal], self.compressed.items[self.retained.literal..], self.stream_output_written);
                    self.phase = .fse_output;
                }
            },
            .fse_output => {
                const cursor = &self.fse_cursor.?;
                try self.history.reserve(self.budget.allocator(), @min(output.len - written, cursor.raw_size - cursor.decoded_len));
                const old_written = cursor.decoded_len;
                const result = cursor.step(self.history.view(), output[written..]) catch |err| {
                    const emitted = cursor.decoded_len - old_written;
                    try self.note(0, emitted);
                    self.history.recordAssumeCapacity(output[written..][0..emitted]);
                    return err;
                };
                try self.note(0, result.progress.output_written);
                self.history.recordAssumeCapacity(output[written..][0..result.progress.output_written]);
                written += result.progress.output_written;
                if (result.status == .done) {
                    try self.completeBlock();
                    continue;
                }
                return res(read, written, .need_output);
            },
            .done => return res(read, written, .done),
            .failed => return self.failure.?,
        };
    }

    fn acceptHeader(self: *Decoder, magic: u32) Error!void {
        const raw_size = if (magic == format.compressed_v1_magic or magic == format.compressed_v2_magic) blk: {
            self.fse_header = try format.parseCompressedHeader(self.header_bytes[0..self.header_len]);
            break :blk self.fse_header.?.raw_size;
        } else std.mem.readInt(u32, self.header_bytes[4..8], .little);
        if (try add(self.output_written, raw_size) > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected| if (try add(self.stream_output_written, raw_size) > expected) return error.SizeMismatch;
        switch (magic) {
            format.uncompressed_magic => {
                self.kind = .raw;
                self.raw_remaining = raw_size;
                self.phase = .raw;
            },
            format.compressed_lzvn_magic => {
                self.kind = .lzvn;
                self.lzvn_cursor = lzvn_mod.Cursor.init(std.mem.readInt(u32, self.header_bytes[8..12], .little), raw_size, self.stream_output_written);
                self.phase = .lzvn;
            },
            else => {
                self.kind = if (magic == format.compressed_v1_magic) .fse_v1 else .fse_v2;
                self.retained = try fse_mod.retainedSizes(self.fse_header.?);
                const size = try add(self.retained.literal, self.retained.lmd);
                if (size > self.options.max_compressed_buffer_len) return error.CompressedBufferLimitExceeded;
                self.compressed.clearRetainingCapacity();
                if (size > self.compressed.capacity) try self.compressed.ensureTotalCapacityPrecise(self.budget.allocator(), size);
                self.prefix_remaining = self.fse_header.?.literal_payload_size - self.retained.literal;
                self.phase = .skip_literal;
            },
        }
    }
    fn completeBlock(self: *Decoder) Error!void {
        self.blocks_completed = try add(self.blocks_completed, 1);
        self.fse_cursor = null;
        self.lzvn_cursor = null;
        self.fse_header = null;
        self.compressed.clearRetainingCapacity();
        self.header_len = 0;
        self.header_target = 4;
        self.phase = .header;
    }
    fn note(self: *Decoder, read: usize, written: usize) Error!void {
        const next_read = try add(self.input_read, read);
        const stream_read = try add(self.stream_input_read, read);
        const next_written = try add(self.output_written, written);
        const stream_written = try add(self.stream_output_written, written);
        self.input_read = next_read;
        self.stream_input_read = stream_read;
        self.output_written = next_written;
        self.stream_output_written = stream_written;
    }
    fn needInput(self: *const Decoder, read: usize, written: usize) Error!core.StepResult {
        if (self.input_finished) return error.TruncatedFrame;
        return res(read, written, .need_input);
    }
};

fn res(read: usize, written: usize, status: core.StepResult.Status) core.StepResult {
    return .{ .progress = .{ .input_read = read, .output_written = written }, .status = status };
}
fn add(a: usize, b: usize) Decoder.Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

test {
    _ = @import("incremental_decoder_tests.zig");
}
