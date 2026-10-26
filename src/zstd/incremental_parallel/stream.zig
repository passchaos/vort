//! Caller-visible counters and one whole publication unit.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
pub const Count = core.StreamCount;
pub const Error = core.Error;
pub const Unit = enum { none, header, job, footer, skippable };

pub const State = struct {
    front: std.ArrayList(u8) = .empty,
    front_offset: usize = 0,
    unit: Unit = .none,
    header_written: bool = false,
    flushing: bool = false,
    finishing: bool = false,
    final_job_sealed: bool = false,
    done: bool = false,
    skippable_only: bool = false,
    expected_input_len: ?Count = null,
    total_input: Count = 0,
    total_output: Count = 0,
    frame_input: Count = 0,
    frame_output: Count = 0,
    frame_count: Count = 0,

    pub const InputCommit = struct { total: Count, frame: Count };

    pub fn checkInput(self: *const State, amount: usize, limit: Count) Error!InputCommit {
        const total = try count.addLocal(self.total_input, amount);
        const frame = try count.addLocal(self.frame_input, amount);
        if (total > limit) return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected| if (frame > expected) return error.SizeMismatch;
        return .{ .total = total, .frame = frame };
    }

    pub fn commitInput(self: *State, next: InputCommit) void {
        self.total_input = next.total;
        self.frame_input = next.frame;
    }

    pub fn pendingLen(self: *const State) usize {
        std.debug.assert(self.front_offset <= self.front.items.len);
        return self.front.items.len - self.front_offset;
    }

    pub fn checkPending(self: *const State, limit: usize) Error!void {
        // An already delivered prefix never shrinks the unit's admission size.
        if (self.front.items.len > limit) return error.OutputLimitExceeded;
    }

    pub fn drain(self: *State, output: []u8, progress: *core.Progress, limit: Count) Error!bool {
        if (progress.output_written > output.len) return error.InvalidStreamState;
        const wanted = @min(output.len - progress.output_written, self.pendingLen());
        _ = try count.addLocal(self.total_output, wanted);
        _ = try count.addLocal(self.frame_output, wanted);
        if (wanted == 0) return self.pendingLen() == 0;
        const available = if (self.total_output >= limit) 0 else count.bounded(limit - self.total_output, wanted);
        const next_total = try count.addLocal(self.total_output, available);
        const next_frame = try count.addLocal(self.frame_output, available);
        const next_written = std.math.add(usize, progress.output_written, available) catch return error.IntegerOverflow;
        @memcpy(output[progress.output_written..][0..available], self.front.items[self.front_offset..][0..available]);
        self.front_offset += available;
        progress.output_written = next_written;
        self.total_output = next_total;
        self.frame_output = next_frame;
        if (available != wanted) return error.OutputLimitExceeded;
        return self.pendingLen() == 0;
    }

    pub fn nextFrameCount(self: *const State) Error!Count {
        return count.addLocal(self.frame_count, 1);
    }

    pub fn clearFront(self: *State) void {
        self.front.clearRetainingCapacity();
        self.front_offset = 0;
        self.unit = .none;
    }

    pub fn resetFrame(self: *State, expected: ?Count, clear_totals: bool) void {
        self.clearFront();
        self.header_written = false;
        self.flushing = false;
        self.finishing = false;
        self.final_job_sealed = false;
        self.done = false;
        self.skippable_only = false;
        self.expected_input_len = expected;
        self.frame_input = 0;
        self.frame_output = 0;
        if (clear_totals) {
            self.total_input = 0;
            self.total_output = 0;
            self.frame_count = 0;
        }
    }

    pub fn completeFrame(self: *State) Error!void {
        const frames = try self.nextFrameCount();
        self.clearFront();
        self.frame_count = frames;
        self.done = true;
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.front.deinit(allocator);
        self.* = .{};
    }
};
