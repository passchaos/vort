const std = @import("std");

pub const Error = error{InvalidBlockPlan};
pub const max_search_depth: u32 = 65536;
pub const max_nice_len: u32 = 128 * 1024;

/// Dedicated search and working-allocation controls for the opt-in HQ engines.
/// This depth is independent of the older match_search_budget option. Zero
/// memory is a valid resource limit; nonempty work may reject it before heap use.
pub const HqOptions = struct {
    search_depth: u32 = 64,
    nice_len: u32 = 128,
    min_match: u8 = 3,
    max_working_memory: usize = std.math.maxInt(usize),

    pub fn validate(self: HqOptions) Error!void {
        if (self.search_depth == 0 or self.search_depth > max_search_depth or
            self.min_match < 3 or self.min_match > 7 or
            self.nice_len < self.min_match or self.nice_len > max_nice_len)
            return error.InvalidBlockPlan;
    }
};
