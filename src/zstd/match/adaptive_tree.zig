//! Sized tables for local parsing; long block skips are sparse only without a prefix.
const kernel = @import("hq_tree/kernel.zig");
pub const sized_heads = true;
pub const sparse_skip = true;
pub const Source = kernel.Source;
pub const HqOptions = kernel.HqOptions;
pub const Match = kernel.Match;
pub const Matches = kernel.Matches;
pub const Iterator = kernel.Iterator;
pub const Matcher = kernel.MatcherImpl(sized_heads, sparse_skip);
pub const OwnedMatcher = Matcher;

pub fn requiredWorkingMemory(source: Source, options: HqOptions) !usize {
    return Matcher.requiredWorkingMemory(source, options);
}

test {
    _ = @import("adaptive_tree_tests.zig");
}
