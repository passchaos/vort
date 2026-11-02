const std = @import("std");
const controls = @import("../../../encode/controls.zig");

pub fn same(expected: controls.Profile, actual: controls.Profile) !void {
    inline for (@typeInfo(controls.Profile).@"struct".fields) |field| {
        if (comptime !std.mem.eql(u8, field.name, "frontier_choice_preparations") and
            !std.mem.eql(u8, field.name, "frontier_choice_replays") and
            !std.mem.eql(u8, field.name, "frontier_unprepared_edges"))
            try std.testing.expectEqualDeep(@field(expected, field.name), @field(actual, field.name));
    }
}
