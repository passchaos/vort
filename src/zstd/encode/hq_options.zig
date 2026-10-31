const std = @import("std");

pub const Error = error{InvalidBlockPlan};
pub const max_search_depth: u32 = 65536;
pub const max_nice_len: u32 = 128 * 1024;
pub const ParseMode = enum { bounded, whole_block };
pub const MatchLengthPolicy = enum { sampled, complete };
pub const ParserEngine = enum { local_optimal, beam };

/// Dedicated search and working-allocation controls for the opt-in HQ engines.
/// This depth is independent of the older match_search_budget option. Zero
/// memory is a valid resource limit; nonempty work may reject it before heap use.
pub const HqOptions = struct {
    search_depth: u32 = 64,
    nice_len: u32 = 128,
    min_match: u8 = 3,
    max_working_memory: usize = std.math.maxInt(usize),
    /// Local optimal parsing uses a deterministic single path and adaptive
    /// match-triggered windows. Beam preserves the former multi-state search.
    parser_engine: ParserEngine = .local_optimal,
    /// Whole-block mode gives every position a row; bounded mode limits the
    /// local table to 4096 positions and may end a window on a long match.
    parse_mode: ParseMode = .bounded,
    /// Complete enumerates every legal length of each admitted match/offset
    /// choice. Bounded parsing retains a finite cross-window continuation;
    /// whole-block parsing admits every endpoint into its DP table.
    match_lengths: MatchLengthPolicy = .sampled,
    /// Exact sequence-edge price admissions per actual DP plan, across all
    /// its windows. Matching, literals and final verification are excluded.
    /// Cold btultra2 and safeguard plans each obey this same independent cap.
    max_price_evaluations: ?u64 = null,

    pub fn hasSearchControls(self: HqOptions) bool {
        return self.hasExpandedSearch() or self.max_price_evaluations != null or self.parser_engine != .local_optimal;
    }
    pub fn hasExpandedSearch(self: HqOptions) bool {
        return self.parse_mode != .bounded or self.match_lengths != .sampled;
    }

    pub fn effectiveParserEngine(self: HqOptions) ParserEngine {
        return if (self.hasExpandedSearch()) .beam else self.parser_engine;
    }

    pub fn validate(self: HqOptions) Error!void {
        if (self.search_depth == 0 or self.search_depth > max_search_depth or
            self.min_match < 3 or self.min_match > 7 or
            self.nice_len < self.min_match or self.nice_len > max_nice_len)
            return error.InvalidBlockPlan;
    }
};
