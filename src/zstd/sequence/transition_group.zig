//! Decode the three independent FSE transitions from one bounded field group.
const std = @import("std");
const field_group = @import("field_group.zig");

pub inline fn read(group: *field_group.Group, ll_bits: u8, ml_bits: u8, of_bits: u8) [3]usize {
    std.debug.assert(ll_bits <= 9 and ml_bits <= 9 and of_bits <= 9);
    const joined = group.read(ll_bits + ml_bits + of_bits);
    return .{
        (joined >> @intCast(ml_bits + of_bits)) & ((@as(usize, 1) << @intCast(ll_bits)) - 1),
        (joined >> @intCast(of_bits)) & ((@as(usize, 1) << @intCast(ml_bits)) - 1),
        joined & ((@as(usize, 1) << @intCast(of_bits)) - 1),
    };
}

test "Zstd dense grouped transitions match separate fields at every width and offset" {
    try @import("transition_group_tests.zig").check();
}
