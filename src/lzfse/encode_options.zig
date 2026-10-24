const std = @import("std");

pub const Strategy = enum { auto, lzvn, fse, stored };
pub const FseVersion = enum { v1, v2 };
pub const max_distance: usize = 262139;
pub const max_match_length: usize = 2359;
pub const max_literal_length: usize = 315;
pub const max_plan_raw_size: usize = 10000 * max_match_length + 40000;

pub const Options = struct {
    block_size: usize = 64 * 1024,
    /// Retained compatibility switch: false with no explicit strategy is stored.
    use_lzvn: bool = true,
    /// Null follows the compatibility switch; true now selects the auto policy.
    strategy: ?Strategy = null,
    fse_version: FseVersion = .v2,
    hash_log: u8 = 15,
    max_match_distance: usize = max_distance,
    max_working_memory: usize = std.math.maxInt(usize),
    max_output_len: usize = std.math.maxInt(usize),

    pub fn effectiveStrategy(self: Options) Strategy {
        return self.strategy orelse if (self.use_lzvn) .auto else .stored;
    }
    pub fn historyLimit(self: Options) usize {
        return @min(self.max_match_distance, max_distance);
    }
    pub fn validate(self: Options) !void {
        if (self.block_size == 0 or self.block_size > std.math.maxInt(u32) or
            self.hash_log < 8 or self.hash_log > 20 or self.max_match_distance == 0) return error.InvalidLzfseStream;
    }
};
