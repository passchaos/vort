const std = @import("std");
const tables = @import("tables.zig");

pub const Strategy = enum { greedy, literals };
pub const Options = struct {
    window_bits: u5 = 18,
    strategy: Strategy = .greedy,
    hash_log: u8 = 15,
    max_match_distance: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    max_output_len: usize = std.math.maxInt(usize),

    pub fn validate(self: Options) !void {
        if (self.window_bits < tables.min_window_bits or self.window_bits > tables.max_window_bits or
            self.hash_log < 8 or self.hash_log > 20 or self.max_match_distance == 0) return error.InvalidBlockPlan;
    }
    pub fn historyLimit(self: Options) usize {
        return @min(self.max_match_distance, @as(usize, 1) << self.window_bits);
    }
};
