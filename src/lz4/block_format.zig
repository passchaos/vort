const std = @import("std");

/// LZ4 block format terminal constraints.
///
/// The final sequence must contain only literals, with at least five literal
/// bytes for blocks large enough to contain matches. The final match must also
/// start at least twelve bytes before the end. These constants are wire-format
/// requirements rather than parser tuning knobs; keeping them together avoids
/// letting independent and linked encoders silently diverge.
pub const last_literals: usize = 5;
pub const match_find_limit: usize = 12;
pub const min_match_len: usize = 4;

pub inline fn hasMatchSearchRoom(position: usize, input_len: usize) bool {
    return position <= input_len and
        match_find_limit <= input_len - position;
}

/// Maximum match length that still leaves the required final literal-only
/// sequence. Callers invoke this only after `hasMatchSearchRoom` succeeds.
pub inline fn maxMatchLen(match_start: usize, input_len: usize) usize {
    std.debug.assert(hasMatchSearchRoom(match_start, input_len));
    return input_len - last_literals - match_start;
}

test "LZ4 terminal policy preserves match and final literal margins" {
    try std.testing.expect(!hasMatchSearchRoom(0, 11));
    try std.testing.expect(hasMatchSearchRoom(0, 12));
    try std.testing.expect(hasMatchSearchRoom(20, 32));
    try std.testing.expect(!hasMatchSearchRoom(21, 32));
    try std.testing.expectEqual(@as(usize, 7), maxMatchLen(20, 32));
    try std.testing.expect(maxMatchLen(20, 32) >= min_match_len);
}
