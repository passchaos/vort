const std = @import("std");
const Codec = @import("zstd/match/hq_parser/row_tags.zig");
test {
    std.testing.refAllDecls(Codec);
    _ = @import("zstd/match/hq_parser/row_tags_cost_tests.zig");
}
