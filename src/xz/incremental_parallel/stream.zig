//! Caller-visible stream state, independent of worker queue ownership.
const std = @import("std");
const core = @import("../../core.zig");
const writer = @import("../writer.zig");

pub const Error = writer.Error || core.Error || std.mem.Allocator.Error;

pub const State = struct {
    plain: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    records: std.ArrayList(writer.BlockRecord) = .empty,
    header_written: bool = false,
    footer_written: bool = false,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    current_input: usize = 0,
    current_output: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    stream_count: usize = 0,

    /// Copies storage descriptors without allocating or transferring ownership.
    pub fn fromEncoder(source: anytype) State {
        var state: State = undefined;
        inline for (std.meta.fields(State)) |field| {
            @field(state, field.name) = @field(source, field.name);
        }
        return state;
    }

    pub fn writeToEncoder(self: *const State, dest: anytype) void {
        inline for (std.meta.fields(State)) |field| {
            @field(dest, field.name) = @field(self, field.name);
        }
    }

    pub fn reset(self: *State, expected: ?usize, all_counters: bool) void {
        self.plain.clearRetainingCapacity();
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.records.clearRetainingCapacity();
        self.header_written = false;
        self.footer_written = false;
        self.flush_requested = false;
        self.finishing = false;
        self.done = false;
        self.expected_input_len = expected;
        self.current_input = 0;
        self.current_output = 0;
        if (all_counters) {
            self.total_input = 0;
            self.total_output = 0;
            self.block_count = 0;
            self.stream_count = 0;
        }
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.plain.deinit(allocator);
        self.pending.deinit(allocator);
        self.records.deinit(allocator);
        self.* = undefined;
    }

    pub fn retainedBytes(self: *const State) Error!usize {
        const record_bytes = std.math.mul(usize, self.records.capacity, @sizeOf(writer.BlockRecord)) catch return error.IntegerOverflow;
        const buffer_bytes = std.math.add(usize, self.plain.capacity, self.pending.capacity) catch return error.IntegerOverflow;
        return std.math.add(usize, buffer_bytes, record_bytes) catch error.IntegerOverflow;
    }

    pub fn pendingLen(self: *const State) usize {
        return self.pending.items.len - self.pending_offset;
    }

    pub fn appendHeader(self: *State, allocator: std.mem.Allocator, check: writer.Check, max_pending: usize) Error!void {
        const original_len = self.pending.items.len;
        errdefer self.pending.shrinkRetainingCapacity(original_len);
        try writer.appendStreamHeader(allocator, &self.pending, check);
        if (self.pending.items.len > max_pending) return error.OutputLimitExceeded;
        self.header_written = true;
    }

    pub fn appendFooter(self: *State, allocator: std.mem.Allocator, check: writer.Check, max_pending: usize) Error!void {
        const original_len = self.pending.items.len;
        errdefer self.pending.shrinkRetainingCapacity(original_len);
        try writer.appendStreamEnd(allocator, &self.pending, check, self.records.items);
        if (self.pending.items.len > max_pending) return error.OutputLimitExceeded;
        self.footer_written = true;
    }

    /// Validates all counters before publishing any bytes to the caller.
    pub fn drain(self: *State, output: []u8, progress: *core.Progress) Error!void {
        if (self.pending_offset > self.pending.items.len or progress.output_written > output.len)
            return error.InvalidStreamState;
        const remaining = self.pending.items[self.pending_offset..];
        const take = @min(output.len - progress.output_written, remaining.len);
        const next_current = std.math.add(usize, self.current_output, take) catch return error.IntegerOverflow;
        const next_total = std.math.add(usize, self.total_output, take) catch return error.IntegerOverflow;
        const next_written = std.math.add(usize, progress.output_written, take) catch return error.IntegerOverflow;
        @memcpy(output[progress.output_written..][0..take], remaining[0..take]);
        self.pending_offset += take;
        progress.output_written = next_written;
        self.current_output = next_current;
        self.total_output = next_total;
        if (self.pending_offset == self.pending.items.len) {
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
        }
    }

    /// Input limits apply to the current stream; cumulative counters remain
    /// checked across concatenated streams.
    pub fn checkInput(self: *const State, n: usize, max_input: usize) Error!struct { current: usize, total: usize } {
        const current = std.math.add(usize, self.current_input, n) catch return error.IntegerOverflow;
        const total = std.math.add(usize, self.total_input, n) catch return error.IntegerOverflow;
        if (current > max_input) return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected| {
            if (current > expected) return error.SizeMismatch;
        }
        return .{ .current = current, .total = total };
    }

    pub fn commitInput(self: *State, next: anytype) void {
        self.current_input = next.current;
        self.total_input = next.total;
    }

    pub fn acceptCount(self: *State, n: usize, max_input: usize) Error!void {
        self.commitInput(try self.checkInput(n, max_input));
    }

    pub fn markIndexed(self: *State, record: writer.BlockRecord, allocator: std.mem.Allocator, max_block: usize) Error!void {
        if (self.records.items.len >= max_block) return error.OutputLimitExceeded;
        const next_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
        try self.records.ensureUnusedCapacity(allocator, 1);
        self.records.appendAssumeCapacity(record);
        self.block_count = next_count;
    }

    pub fn markDone(self: *State) Error!void {
        const next_count = std.math.add(usize, self.stream_count, 1) catch return error.IntegerOverflow;
        self.stream_count = next_count;
        self.done = true;
    }
};
