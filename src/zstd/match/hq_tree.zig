//! Full-indexed BT4/short3 matcher with its original public behavior.
const kernel = @import("hq_tree/kernel.zig");
pub const Source = kernel.Source;
pub const HqOptions = kernel.HqOptions;
pub const Match = kernel.Match;
pub const Matches = kernel.Matches;
pub const Iterator = kernel.Iterator;
pub const OwnedMatcher = kernel.MatcherImpl(false, false);
pub const Matcher = OwnedMatcher;

pub fn requiredWorkingMemory(source: Source, options: HqOptions) !usize {
    return Matcher.requiredWorkingMemory(source, options);
}

test {
    _ = @import("hq_tree/tests.zig");
}
