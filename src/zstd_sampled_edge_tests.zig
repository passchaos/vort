const std = @import("std");
const Codec = @import("zstd/match/hq_parser/search_edges.zig");

test {
    std.testing.refAllDecls(Codec);
    _ = @import("zstd/match/hq_parser/search_edges_tests.zig");
}
