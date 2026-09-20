const std = @import("std");

pub const Error = error{InvalidMatch};

/// Resolve the Zstd OF-code-zero case when the sequence has at least one
/// literal. This selects rep0 without rotating the repeated-offset ring.
pub inline fn positiveLiteralRep0(repeated_offsets: *const [3]usize) Error!usize {
    const offset = repeated_offsets[0];
    if (offset == 0) return error.InvalidMatch;
    return offset;
}

test "positive-literal rep0 preserves repeated offsets" {
    const offsets = [3]usize{ 17, 5, 2 };
    try std.testing.expectEqual(@as(usize, 17), try positiveLiteralRep0(&offsets));
    try std.testing.expectEqual([3]usize{ 17, 5, 2 }, offsets);

    const invalid = [3]usize{ 0, 5, 2 };
    try std.testing.expectError(error.InvalidMatch, positiveLiteralRep0(&invalid));
}
