const std = @import("std");

/// Incremental Brotli writers can revise the last unpublished reservoir byte
/// before a later allocation fails. Keep that byte and initialized length,
/// while leaving successfully grown capacity owned and correctly budgeted.
pub const Checkpoint = struct {
    len: usize,
    tail: u8,

    pub fn init(output: *const std.ArrayList(u8)) Checkpoint {
        return .{ .len = output.items.len, .tail = if (output.items.len != 0) output.items[output.items.len - 1] else 0 };
    }

    pub fn restore(self: Checkpoint, output: *std.ArrayList(u8)) void {
        output.items.len = self.len;
        if (self.len != 0) output.items[self.len - 1] = self.tail;
    }
};
