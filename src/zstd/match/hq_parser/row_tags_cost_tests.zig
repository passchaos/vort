const std = @import("std");
const Codec = @import("row_tags.zig");
const Old = @import("row_tags_cost_reference.zig");

fn Adapter(comptime C: type) type {
    return struct {
        pub const Tags = C.Tags;
        pub const key = C.key;
        pub const init = C.init;
        pub fn insert(row: anytype, tags: *Tags, candidate: @TypeOf(row[0])) bool {
            var expected: [row.len]@TypeOf(candidate) = undefined;
            @memcpy(&expected, row);
            var expected_tags = tags.*;
            const want = Old.insert(&expected, &expected_tags, candidate);
            const got = C.insert(row, tags, candidate);
            std.testing.expectEqual(want, got) catch @panic("cost gate return changed");
            std.testing.expectEqualDeep(expected, row.*) catch @panic("cost gate node changed");
            std.testing.expectEqualDeep(expected_tags, tags.*) catch @panic("cost gate tag changed");
            return got;
        }
    };
}
pub fn contracts(comptime C: type) !void {
    try @import("row_tags_cost_tests/tie_matrix.zig").contracts(C);
    try @import("row_tags_tests/properties.zig").contracts(Adapter(C));
    try @import("row_tags_tests/random.zig").contracts(Adapter(C));
}
test "Zstd HQ search row tag cost gates preserve frozen ties costs and aliases" {
    try contracts(Codec);
}
