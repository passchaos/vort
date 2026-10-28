const std = @import("std");
const Codec = @import("zstd/match/hq_parser/state.zig");

test "zstd hq state key wrapper" {
    std.testing.refAllDecls(Codec);
}
