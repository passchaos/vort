const std = @import("std");
const Codec = @import("zstd/match/hq_parser/sampled_price.zig");
test {
    std.testing.refAllDecls(Codec);
    _ = @import("zstd/match/hq_parser/known_ml_tests.zig");
}
