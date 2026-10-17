//! Caller-owned secondary storage for bounded incremental BCJ2 output.

const std = @import("std");
const core = @import("../../core.zig");
const aes = @import("../aes.zig");
const bcj2 = @import("../bcj2.zig");

pub const Spool = struct {
    context: *anyopaque,
    reset: *const fn (context: *anyopaque) anyerror!void,
    write: *const fn (context: *anyopaque, bytes: []const u8) anyerror!void,
    read_at: *const fn (
        context: *anyopaque,
        offset: u64,
        output: []u8,
    ) anyerror!usize,
};

pub const Error = core.Error || bcj2.Error || aes.IncrementalError ||
    std.mem.Allocator.Error || error{
    SecondarySpoolFailure,
    TruncatedSecondarySpool,
    InvalidSecondarySpool,
};

pub const Stream = struct {
    allocator: std.mem.Allocator,
    spool: Spool,
    max_spool_size: u64,
    range_encoder: bcj2.NoConversionEncoder = .{},
    range_pending: std.ArrayList(u8) = .empty,
    read_buffer: []u8,
    read_len: usize = 0,
    read_offset: usize = 0,
    spool_size: u64 = 0,
    spool_read: u64 = 0,
    packed_size: u64 = 0,
    encryption: ?aes.IncrementalEncryptor = null,
    encryption_finish_sent: bool = false,
    input_finished: bool = false,
    done: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        spool: Spool,
        encryption_options: ?aes.Options,
        encryption_stream_index: u64,
        max_spool_size: u64,
        read_buffer_size: usize,
    ) Error!Stream {
        if (max_spool_size < 5 or read_buffer_size == 0)
            return error.InvalidSecondarySpool;
        spool.reset(spool.context) catch return error.SecondarySpoolFailure;
        const read_buffer = try allocator.alloc(u8, read_buffer_size);
        errdefer allocator.free(read_buffer);
        return .{
            .allocator = allocator,
            .spool = spool,
            .max_spool_size = max_spool_size,
            .read_buffer = read_buffer,
            .encryption = if (encryption_options) |options|
                try aes.IncrementalEncryptor.init(
                    allocator,
                    options,
                    std.math.add(u64, encryption_stream_index, 3) catch
                        return error.IntegerOverflow,
                )
            else
                null,
        };
    }

    pub fn deinit(self: *Stream) void {
        self.range_encoder.deinit(self.allocator);
        self.range_pending.deinit(self.allocator);
        self.allocator.free(self.read_buffer);
        if (self.encryption) |*encryption| encryption.deinit();
        self.* = undefined;
    }

    pub fn accept(self: *Stream, input: []const u8) Error!void {
        if (self.input_finished or self.done) return error.InvalidBlockPlan;
        self.range_pending.clearRetainingCapacity();
        try self.range_encoder.push(
            self.allocator,
            input,
            false,
            &self.range_pending,
        );
        try self.writePending();
    }

    pub fn finishInput(self: *Stream) Error!void {
        if (self.input_finished or self.done) return error.InvalidBlockPlan;
        self.range_pending.clearRetainingCapacity();
        try self.range_encoder.push(
            self.allocator,
            &.{},
            true,
            &self.range_pending,
        );
        try self.writePending();
        self.input_finished = true;
    }

    pub fn plainSize(self: *const Stream) u64 {
        return self.spool_size;
    }

    pub fn packedSize(self: *const Stream) u64 {
        return self.packed_size;
    }

    pub fn stepReplay(self: *Stream, output: []u8) Error!core.StepResult {
        if (!self.input_finished) return error.InvalidBlockPlan;
        if (self.done) return .{ .status = .done };
        return if (self.encryption != null)
            self.stepEncrypted(output)
        else
            self.stepPlain(output);
    }

    fn writePending(self: *Stream) Error!void {
        const next_size = std.math.add(
            u64,
            self.spool_size,
            std.math.cast(u64, self.range_pending.items.len) orelse
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        if (next_size > self.max_spool_size) return error.OutputLimitExceeded;
        if (self.range_pending.items.len != 0)
            self.spool.write(self.spool.context, self.range_pending.items) catch
                return error.SecondarySpoolFailure;
        self.spool_size = next_size;
        self.range_pending.clearRetainingCapacity();
    }

    fn stepPlain(self: *Stream, output: []u8) Error!core.StepResult {
        var output_written: usize = 0;
        while (true) {
            if (self.read_offset != self.read_len) {
                const remaining = self.read_buffer[self.read_offset..self.read_len];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.read_offset += take;
                output_written += take;
                self.packed_size = std.math.add(u64, self.packed_size, @intCast(take)) catch
                    return error.IntegerOverflow;
                if (self.read_offset != self.read_len)
                    return replayResult(output_written, .need_output);
                self.read_offset = 0;
                self.read_len = 0;
                if (output_written == output.len and output.len != 0)
                    return replayResult(output_written, .need_output);
            }
            if (self.spool_read == self.spool_size) {
                self.done = true;
                return replayResult(output_written, .done);
            }
            if (output_written == output.len) return replayResult(output_written, .need_output);
            try self.load();
        }
    }

    fn stepEncrypted(self: *Stream, output: []u8) Error!core.StepResult {
        var output_written: usize = 0;
        while (true) {
            if (self.read_offset != self.read_len) {
                const stepped = try self.encryption.?.step(
                    self.read_buffer[self.read_offset..self.read_len],
                    output[output_written..],
                );
                if (stepped.progress.input_read > self.read_len - self.read_offset or
                    stepped.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                self.read_offset += stepped.progress.input_read;
                output_written += stepped.progress.output_written;
                self.packed_size = std.math.add(
                    u64,
                    self.packed_size,
                    @intCast(stepped.progress.output_written),
                ) catch return error.IntegerOverflow;
                if (stepped.status == .done) return error.InvalidBlockPlan;
                if (self.read_offset != self.read_len) {
                    if (stepped.status != .need_output) return error.InvalidBlockPlan;
                    return replayResult(output_written, .need_output);
                }
                self.read_offset = 0;
                self.read_len = 0;
                if (output_written == output.len and output.len != 0)
                    return replayResult(output_written, .need_output);
            }
            if (self.spool_read != self.spool_size) {
                try self.load();
                continue;
            }
            if (!self.encryption_finish_sent) {
                self.encryption.?.finish();
                self.encryption_finish_sent = true;
            }
            const stepped = try self.encryption.?.step(&.{}, output[output_written..]);
            if (stepped.progress.input_read != 0 or
                stepped.progress.output_written > output.len - output_written)
                return error.InvalidBlockPlan;
            output_written += stepped.progress.output_written;
            self.packed_size = std.math.add(
                u64,
                self.packed_size,
                @intCast(stepped.progress.output_written),
            ) catch return error.IntegerOverflow;
            if (stepped.status == .done) {
                self.done = true;
                return replayResult(output_written, .done);
            }
            if (stepped.status != .need_output) return error.InvalidBlockPlan;
            return replayResult(output_written, .need_output);
        }
    }

    fn load(self: *Stream) Error!void {
        std.debug.assert(self.read_offset == self.read_len and self.spool_read < self.spool_size);
        const remaining = self.spool_size - self.spool_read;
        const wanted = @min(
            self.read_buffer.len,
            std.math.cast(usize, remaining) orelse self.read_buffer.len,
        );
        const amount = self.spool.read_at(
            self.spool.context,
            self.spool_read,
            self.read_buffer[0..wanted],
        ) catch return error.SecondarySpoolFailure;
        if (amount == 0) return error.TruncatedSecondarySpool;
        if (amount > wanted) return error.InvalidSecondarySpool;
        self.spool_read = std.math.add(u64, self.spool_read, @intCast(amount)) catch
            return error.IntegerOverflow;
        self.read_offset = 0;
        self.read_len = amount;
    }
};

fn replayResult(output_written: usize, status: core.StepResult.Status) core.StepResult {
    return .{
        .progress = .{ .output_written = output_written },
        .status = status,
    };
}
