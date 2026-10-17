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
    const branch_count: usize = 3;
    const record_header_len: u64 = 5;

    allocator: std.mem.Allocator,
    spool: Spool,
    max_spool_size: u64,
    converter: bcj2.ConversionEncoder,
    main_pending: std.ArrayList(u8) = .empty,
    main_offset: usize = 0,
    branch_pending: [branch_count]std.ArrayList(u8) = @splat(.empty),
    read_buffer: []u8,
    read_len: usize = 0,
    read_offset: usize = 0,
    spool_size: u64 = 0,
    branch_plain_sizes: [branch_count]u64 = @splat(0),
    branch_packed_sizes: [branch_count]u64 = @splat(0),
    encryptions: [branch_count]?aes.IncrementalEncryptor = @splat(null),
    encryption_finish_sent: [branch_count]bool = @splat(false),
    active_branch: usize = 0,
    scan_offset: u64 = 0,
    record_remaining: u64 = 0,
    branch_read_size: u64 = 0,
    input_finished: bool = false,
    main_finish_sent: bool = false,
    done: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        spool: Spool,
        encryption_options: ?aes.Options,
        encryption_stream_index: u64,
        start_ip: u32,
        max_spool_size: u64,
        read_buffer_size: usize,
    ) Error!Stream {
        if (max_spool_size < 5 or read_buffer_size == 0)
            return error.InvalidSecondarySpool;
        spool.reset(spool.context) catch return error.SecondarySpoolFailure;
        const read_buffer = try allocator.alloc(u8, read_buffer_size);
        var result = Stream{
            .allocator = allocator,
            .spool = spool,
            .max_spool_size = max_spool_size,
            .converter = bcj2.ConversionEncoder.init(start_ip),
            .read_buffer = read_buffer,
        };
        errdefer result.deinit();
        if (encryption_options) |options| {
            for (0..branch_count) |branch_index|
                result.encryptions[branch_index] = try aes.IncrementalEncryptor.init(
                    allocator,
                    options,
                    std.math.add(
                        u64,
                        encryption_stream_index,
                        @as(u64, @intCast(branch_index)) + 1,
                    ) catch return error.IntegerOverflow,
                );
        }
        return result;
    }

    pub fn deinit(self: *Stream) void {
        self.converter.deinit(self.allocator);
        self.main_pending.deinit(self.allocator);
        for (&self.branch_pending) |*pending| pending.deinit(self.allocator);
        self.allocator.free(self.read_buffer);
        for (&self.encryptions) |*encryption|
            if (encryption.*) |*state| state.deinit();
        self.* = undefined;
    }

    pub fn accept(self: *Stream, input: []const u8) Error!void {
        if (self.input_finished or self.done or self.hasMain()) return error.InvalidBlockPlan;
        try self.convert(input, false);
    }

    pub fn finishInput(self: *Stream) Error!void {
        if (self.input_finished or self.done) return error.InvalidBlockPlan;
        try self.convert(&.{}, true);
        self.input_finished = true;
    }

    pub fn hasMain(self: *const Stream) bool {
        return self.main_offset != self.main_pending.items.len;
    }

    pub fn mainBytes(self: *const Stream) []const u8 {
        return self.main_pending.items[self.main_offset..];
    }

    pub fn consumeMain(self: *Stream, count: usize) Error!void {
        if (count > self.main_pending.items.len - self.main_offset)
            return error.InvalidBlockPlan;
        self.main_offset += count;
        if (self.main_offset == self.main_pending.items.len) {
            self.main_pending.clearRetainingCapacity();
            self.main_offset = 0;
        }
    }

    pub fn inputFinished(self: *const Stream) bool {
        return self.input_finished;
    }

    pub fn mainFinishSent(self: *const Stream) bool {
        return self.main_finish_sent;
    }

    pub fn markMainFinishSent(self: *Stream) void {
        std.debug.assert(self.input_finished and !self.hasMain() and !self.main_finish_sent);
        self.main_finish_sent = true;
    }

    pub fn mainSize(self: *const Stream) u64 {
        return self.converter.main_size;
    }

    pub fn branchPlainSize(self: *const Stream, branch_index: usize) u64 {
        return self.branch_plain_sizes[branch_index];
    }

    pub fn branchPackedSize(self: *const Stream, branch_index: usize) u64 {
        return self.branch_packed_sizes[branch_index];
    }

    pub fn stepReplay(self: *Stream, output: []u8) Error!core.StepResult {
        if (!self.input_finished or !self.main_finish_sent or self.hasMain())
            return error.InvalidBlockPlan;
        if (self.done) return .{ .status = .done };

        var output_written: usize = 0;
        while (self.active_branch < branch_count) {
            if (self.read_offset != self.read_len) {
                const status = try self.emitReadBuffer(output, &output_written);
                if (status) |value| return replayResult(output_written, value);
                continue;
            }
            if (self.record_remaining != 0) {
                try self.loadRecordPayload();
                continue;
            }
            if (self.scan_offset != self.spool_size) {
                try self.scanRecord();
                continue;
            }
            if (self.branch_read_size != self.branch_plain_sizes[self.active_branch])
                return error.InvalidSecondarySpool;
            if (self.encryptions[self.active_branch]) |*encryption| {
                if (!self.encryption_finish_sent[self.active_branch]) {
                    encryption.finish();
                    self.encryption_finish_sent[self.active_branch] = true;
                }
                const stepped = try encryption.step(&.{}, output[output_written..]);
                if (stepped.progress.input_read != 0 or
                    stepped.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                output_written += stepped.progress.output_written;
                self.branch_packed_sizes[self.active_branch] = std.math.add(
                    u64,
                    self.branch_packed_sizes[self.active_branch],
                    @intCast(stepped.progress.output_written),
                ) catch return error.IntegerOverflow;
                if (stepped.status != .done) {
                    if (stepped.status != .need_output) return error.InvalidBlockPlan;
                    return replayResult(output_written, .need_output);
                }
            }
            self.active_branch += 1;
            self.scan_offset = 0;
            self.record_remaining = 0;
            self.branch_read_size = 0;
            if (output_written == output.len and output.len != 0)
                return replayResult(output_written, .need_output);
        }
        self.done = true;
        return replayResult(output_written, .done);
    }

    fn convert(self: *Stream, input: []const u8, finish: bool) Error!void {
        for (&self.branch_pending) |*pending| pending.clearRetainingCapacity();
        try self.converter.push(
            self.allocator,
            input,
            finish,
            &self.main_pending,
            &self.branch_pending[0],
            &self.branch_pending[1],
            &self.branch_pending[2],
        );
        for (&self.branch_pending, 0..) |*pending, branch_index| {
            if (pending.items.len == 0) continue;
            try self.writeRecord(branch_index, pending.items);
            self.branch_plain_sizes[branch_index] = std.math.add(
                u64,
                self.branch_plain_sizes[branch_index],
                @intCast(pending.items.len),
            ) catch return error.IntegerOverflow;
            pending.clearRetainingCapacity();
        }
    }

    fn writeRecord(self: *Stream, branch_index: usize, bytes: []const u8) Error!void {
        const payload_len = std.math.cast(u32, bytes.len) orelse return error.IntegerOverflow;
        const record_len = std.math.add(u64, record_header_len, payload_len) catch
            return error.IntegerOverflow;
        const next_size = std.math.add(u64, self.spool_size, record_len) catch
            return error.IntegerOverflow;
        if (next_size > self.max_spool_size) return error.OutputLimitExceeded;
        var header: [5]u8 = undefined;
        header[0] = @intCast(branch_index);
        std.mem.writeInt(u32, header[1..5], payload_len, .little);
        self.spool.write(self.spool.context, &header) catch
            return error.SecondarySpoolFailure;
        self.spool.write(self.spool.context, bytes) catch
            return error.SecondarySpoolFailure;
        self.spool_size = next_size;
    }

    fn scanRecord(self: *Stream) Error!void {
        var header: [5]u8 = undefined;
        try self.readExactAt(self.scan_offset, &header);
        self.scan_offset = std.math.add(u64, self.scan_offset, record_header_len) catch
            return error.IntegerOverflow;
        const branch_index = header[0];
        if (branch_index >= branch_count) return error.InvalidSecondarySpool;
        const payload_len = std.mem.readInt(u32, header[1..5], .little);
        if (payload_len == 0) return error.InvalidSecondarySpool;
        const record_end = std.math.add(u64, self.scan_offset, payload_len) catch
            return error.IntegerOverflow;
        if (record_end > self.spool_size) return error.TruncatedSecondarySpool;
        if (branch_index == self.active_branch)
            self.record_remaining = payload_len
        else
            self.scan_offset = record_end;
    }

    fn loadRecordPayload(self: *Stream) Error!void {
        std.debug.assert(self.read_offset == self.read_len and self.record_remaining != 0);
        const wanted = @min(
            self.read_buffer.len,
            std.math.cast(usize, self.record_remaining) orelse self.read_buffer.len,
        );
        try self.readExactAt(self.scan_offset, self.read_buffer[0..wanted]);
        self.scan_offset = std.math.add(u64, self.scan_offset, @intCast(wanted)) catch
            return error.IntegerOverflow;
        self.record_remaining -= wanted;
        self.read_offset = 0;
        self.read_len = wanted;
    }

    fn emitReadBuffer(
        self: *Stream,
        output: []u8,
        output_written: *usize,
    ) Error!?core.StepResult.Status {
        const remaining = self.read_buffer[self.read_offset..self.read_len];
        if (self.encryptions[self.active_branch]) |*encryption| {
            const stepped = try encryption.step(remaining, output[output_written.*..]);
            if (stepped.progress.input_read > remaining.len or
                stepped.progress.output_written > output.len - output_written.*)
                return error.InvalidBlockPlan;
            self.read_offset += stepped.progress.input_read;
            self.branch_read_size = std.math.add(
                u64,
                self.branch_read_size,
                @intCast(stepped.progress.input_read),
            ) catch return error.IntegerOverflow;
            output_written.* += stepped.progress.output_written;
            self.branch_packed_sizes[self.active_branch] = std.math.add(
                u64,
                self.branch_packed_sizes[self.active_branch],
                @intCast(stepped.progress.output_written),
            ) catch return error.IntegerOverflow;
            if (stepped.status == .done) return error.InvalidBlockPlan;
            if (self.read_offset != self.read_len) {
                if (stepped.status != .need_output) return error.InvalidBlockPlan;
                return .need_output;
            }
        } else {
            const take = @min(remaining.len, output.len - output_written.*);
            @memcpy(output[output_written.*..][0..take], remaining[0..take]);
            self.read_offset += take;
            self.branch_read_size = std.math.add(u64, self.branch_read_size, @intCast(take)) catch
                return error.IntegerOverflow;
            self.branch_packed_sizes[self.active_branch] = std.math.add(
                u64,
                self.branch_packed_sizes[self.active_branch],
                @intCast(take),
            ) catch return error.IntegerOverflow;
            output_written.* += take;
            if (self.read_offset != self.read_len) return .need_output;
        }
        self.read_offset = 0;
        self.read_len = 0;
        if (output_written.* == output.len and output.len != 0) return .need_output;
        return null;
    }

    fn readExactAt(self: *Stream, offset: u64, output: []u8) Error!void {
        var written: usize = 0;
        while (written < output.len) {
            const absolute = std.math.add(u64, offset, @intCast(written)) catch
                return error.IntegerOverflow;
            const amount = self.spool.read_at(
                self.spool.context,
                absolute,
                output[written..],
            ) catch return error.SecondarySpoolFailure;
            if (amount == 0) return error.TruncatedSecondarySpool;
            if (amount > output.len - written) return error.InvalidSecondarySpool;
            written += amount;
        }
    }
};

fn replayResult(output_written: usize, status: core.StepResult.Status) core.StepResult {
    return .{
        .progress = .{ .output_written = output_written },
        .status = status,
    };
}
