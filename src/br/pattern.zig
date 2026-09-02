/// Return the shortest 2...4-byte period whose full repetitions exactly cover
/// `input`. Symbols must be distinct so the compact simple Brotli literal tree
/// remains valid without deduplicating or remapping the seed.
pub fn repeatedDistinctPrefixLength(input: []const u8) ?usize {
    for (2..5) |period| {
        if (input.len < period * 2 or input.len % period != 0) continue;
        var distinct = true;
        for (input[0..period], 0..) |byte, i| {
            for (input[0..i]) |previous| {
                if (byte == previous) {
                    distinct = false;
                    break;
                }
            }
            if (!distinct) break;
        }
        if (!distinct) continue;

        var matches = true;
        for (input, 0..) |byte, i| {
            if (byte != input[i % period]) {
                matches = false;
                break;
            }
        }
        if (matches) return period;
    }
    return null;
}

test "repeated distinct prefix detection" {
    const std = @import("std");
    try std.testing.expectEqual(@as(?usize, 2), repeatedDistinctPrefixLength("abab"));
    try std.testing.expectEqual(@as(?usize, 3), repeatedDistinctPrefixLength("abcabcabc"));
    try std.testing.expectEqual(@as(?usize, 4), repeatedDistinctPrefixLength("abcdabcd"));
    try std.testing.expectEqual(@as(?usize, null), repeatedDistinctPrefixLength("aaaa"));
    try std.testing.expectEqual(@as(?usize, null), repeatedDistinctPrefixLength("abcaabca"));
    try std.testing.expectEqual(@as(?usize, null), repeatedDistinctPrefixLength("abcdabc"));
}
