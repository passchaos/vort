const std = @import("std");
const core = @import("../core.zig");

pub const poll_interval: usize = 4096;

/// Borrowed cooperative-cancellation hook for bounded one-shot decode calls.
/// Vort invokes `is_cancelled` only while the decode call is active and never
/// retains either the function pointer or `context` after the call returns.
pub const Cancellation = struct {
    context: ?*anyopaque = null,
    is_cancelled: *const fn (context: ?*anyopaque) bool,
};

/// Resource and cooperative-cancellation policy for allocating decode calls.
///
/// `max_input_len` covers the complete caller-provided wrapper bytes, including
/// any trailing bytes. `max_output_len` covers decoded payload bytes.
/// `max_work_units` counts compressed wrapper/DEFLATE bytes logically consumed,
/// decoded bytes emitted, and decoded bytes scanned for wrapper checksum
/// verification. Cancellation is polled immediately, after roughly every 4096
/// work units inside inflate/checksum work, and once before success returns.
pub const Control = struct {
    max_input_len: usize = std.math.maxInt(usize),
    max_output_len: usize = std.math.maxInt(usize),
    max_work_units: usize = std.math.maxInt(usize),
    cancellation: ?Cancellation = null,
};

pub const Tracker = struct {
    control: Control,
    work_units: usize = 0,
    input_read: usize = 0,
    units_since_poll: usize = 0,

    pub fn poll(self: *Tracker) core.Error!void {
        const cancellation = self.control.cancellation orelse return;
        if (cancellation.is_cancelled(cancellation.context)) return error.Cancelled;
    }

    pub fn charge(self: *Tracker, units: usize) core.Error!void {
        if (units > self.control.max_work_units - self.work_units) return error.WorkLimitExceeded;
        self.work_units += units;
        if (self.control.cancellation == null or units == 0) return;

        const until_poll = poll_interval - self.units_since_poll;
        if (units < until_poll) {
            self.units_since_poll += units;
            return;
        }
        self.units_since_poll = (units - until_poll) % poll_interval;
        try self.poll();
    }

    pub fn observeInput(self: *Tracker, input_read: usize) core.Error!void {
        std.debug.assert(input_read >= self.input_read);
        const additional = input_read - self.input_read;
        self.input_read = input_read;
        try self.charge(additional);
    }
};
