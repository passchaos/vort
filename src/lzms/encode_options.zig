const std = @import("std");
const tables = @import("tables.zig");

pub const Strategy = enum { greedy, literals };
pub const Options = struct {
    strategy: Strategy = .greedy,
    /// Fixed hash-table size per LZ/delta family (8...20).
    hash_log: u8 = 15,
    /// Search age is independent of the input's total length.
    max_match_distance: usize = 8 * 1024 * 1024,
    enable_delta: bool = true,
    max_delta_power: u3 = 7,
    /// Live requested allocation bytes, including output and x86 scratch.
    max_working_memory: usize = std.math.maxInt(usize),
    max_output_len: usize = std.math.maxInt(usize),

    pub fn validate(self: Options) error{InvalidLzms}!void {
        if (self.hash_log < 8 or self.hash_log > 20 or
            self.max_match_distance == 0 or self.max_match_distance > tables.max_match_offset) return error.InvalidLzms;
    }
};
