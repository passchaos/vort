const std = @import("std");
const index_module = @import("../compression_index.zig");

pub const Error = index_module.Error;

/// Sequential validation proves that each backward chain terminates at the
/// current extent's head. Prior links were already checked, so no saved index
/// table, repeated Source reads or unbounded recursive walk is needed.
pub const Validator = struct {
    cluster_size: usize,
    next_index: usize = 0,
    head_index: ?usize = null,

    pub fn accept(self: *Validator, index: usize, record: index_module.Index) Error!void {
        if (index != self.next_index) return error.InvalidErofs;
        if (record.kind == 2) {
            const head = self.head_index orelse return error.InvalidErofs;
            const distance = record.lookback orelse return error.InvalidErofs;
            if (distance == 0 or distance > index - head) return error.InvalidErofs;
            if (record.compressed_blocks != null and index - head != 1) return error.InvalidErofs;
        } else {
            if (record.logical_offset >= self.cluster_size or record.lookback != null) return error.InvalidErofs;
            self.head_index = index;
        }
        self.next_index = std.math.add(usize, index, 1) catch return error.IntegerOverflow;
    }
};
