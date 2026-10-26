//! A borrowed immutable input span and one queue-owned encoded result.
const std = @import("std");

pub fn Job(comptime Codec: type) type {
    return struct {
        state: enum { free, queued, active, complete, publishing } = .free,
        start: usize = 0,
        end: usize = 0,
        output: std.ArrayList(u8) = .empty,
        block_count: usize = 0,
        work: Codec.Profile = .{},
        first_error: ?Codec.Error = null,
        merged: bool = false,

        pub fn clear(self: *@This()) void {
            self.state = .free;
            self.start = 0;
            self.end = 0;
            self.output.clearRetainingCapacity();
            self.block_count = 0;
            self.work = .{};
            self.first_error = null;
            self.merged = false;
        }
    };
}
